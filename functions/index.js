const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {initializeApp} = require("firebase-admin/app");
const {getAuth} = require("firebase-admin/auth");
const {FieldValue, getFirestore} = require("firebase-admin/firestore");

initializeApp();

const db = getFirestore();
const auth = getAuth();

async function requireAdmin(request) {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Sign in as an administrator.");
  }
  const profile = await db.collection("users").doc(request.auth.uid).get();
  if (!profile.exists || profile.get("role") !== "admin") {
    throw new HttpsError("permission-denied", "Administrator access required.");
  }
  return request.auth.uid;
}

function requiredString(data, field, maxLength) {
  const value = typeof data[field] === "string" ? data[field].trim() : "";
  if (!value || value.length > maxLength) {
    throw new HttpsError(
      "invalid-argument",
      `${field} is required and must be at most ${maxLength} characters.`,
    );
  }
  return value;
}

function optionalString(data, field, maxLength) {
  const value = typeof data[field] === "string" ? data[field].trim() : "";
  if (value.length > maxLength) {
    throw new HttpsError(
      "invalid-argument",
      `${field} must be at most ${maxLength} characters.`,
    );
  }
  return value;
}

function validatedUid(data) {
  const uid = requiredString(data, "uid", 128);
  if (!/^[A-Za-z0-9_-]{1,128}$/.test(uid)) {
    throw new HttpsError("invalid-argument", "Invalid user identifier.");
  }
  return uid;
}

exports.createRoostifyUser = onCall(async (request) => {
  await requireAdmin(request);
  const data = request.data || {};
  const username = requiredString(data, "username", 32).toLowerCase();
  const displayName = requiredString(data, "displayName", 80);
  const temporaryPassword = requiredString(data, "temporaryPassword", 128);
  const email = optionalString(data, "email", 254);
  const farmName = optionalString(data, "farmName", 120);
  const contactNumber = optionalString(data, "contactNumber", 32);
  const address = optionalString(data, "address", 240);

  if (!/^[a-z0-9._-]{3,32}$/.test(username)) {
    throw new HttpsError(
      "invalid-argument",
      "Username must be 3–32 lowercase letters, numbers, dots, dashes, or underscores.",
    );
  }
  if (temporaryPassword.length < 8) {
    throw new HttpsError(
      "invalid-argument",
      "Temporary password must contain at least 8 characters.",
    );
  }
  if (email && !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
    throw new HttpsError("invalid-argument", "Enter a valid recovery email.");
  }

  const duplicate = await db
    .collection("users")
    .where("username", "==", username)
    .limit(1)
    .get();
  if (!duplicate.empty) {
    throw new HttpsError("already-exists", "That username already exists.");
  }

  const authenticationEmail = `${username}@roostify.local`;
  let createdUser;
  try {
    createdUser = await auth.createUser({
      email: authenticationEmail,
      password: temporaryPassword,
      displayName,
    });
    const profile = {
      uid: createdUser.uid,
      username,
      displayName,
      email,
      role: "user",
      cameraAccessEnabled: true,
      contactNumber,
      address,
      facebookContact: "",
      farmName,
      shortBio: "",
    };
    await db.collection("users").doc(createdUser.uid).set({
      ...profile,
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });
    return {uid: createdUser.uid, profile};
  } catch (error) {
    if (createdUser) {
      await auth.deleteUser(createdUser.uid).catch(() => undefined);
    }
    if (error && error.code === "auth/email-already-exists") {
      throw new HttpsError("already-exists", "That username already exists.");
    }
    console.error("createRoostifyUser failed", error);
    throw new HttpsError("internal", "The account could not be created.");
  }
});

exports.deleteRoostifyUser = onCall(async (request) => {
  const callerUid = await requireAdmin(request);
  const uid = validatedUid(request.data || {});
  if (uid === callerUid) {
    throw new HttpsError("failed-precondition", "Admins cannot delete themselves.");
  }

  const profile = await db.collection("users").doc(uid).get();
  if (!profile.exists || profile.get("role") === "admin") {
    throw new HttpsError("failed-precondition", "Only standard users can be removed.");
  }
  await auth.deleteUser(uid);
  await db.collection("users").doc(uid).delete();
  return {ok: true};
});

exports.resetRoostifyUserPassword = onCall(async (request) => {
  const callerUid = await requireAdmin(request);
  const data = request.data || {};
  const uid = validatedUid(data);
  const temporaryPassword = requiredString(data, "temporaryPassword", 128);
  if (uid === callerUid) {
    throw new HttpsError(
      "failed-precondition",
      "Use the profile security page to change your own password.",
    );
  }
  if (temporaryPassword.length < 8) {
    throw new HttpsError(
      "invalid-argument",
      "Temporary password must contain at least 8 characters.",
    );
  }

  const profile = await db.collection("users").doc(uid).get();
  if (!profile.exists || profile.get("role") === "admin") {
    throw new HttpsError("failed-precondition", "Only standard users can be reset.");
  }
  await auth.updateUser(uid, {password: temporaryPassword});
  await profile.ref.update({
    passwordResetAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  });
  return {ok: true};
});
