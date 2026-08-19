# Roostify Firebase setup

The app is configured for Firebase project `roostify-5ff42` on Android and
web. Passwords are authenticated by Firebase Auth, profiles and roles live in
Firestore, and privileged account management runs through callable Cloud
Functions.

## 1. Enable Firebase products

In the Firebase console for **roostify-5ff42**:

1. Authentication → Sign-in method → enable **Email/Password**.
2. Enable **Google** if Google login is required.
3. Add the Android debug/release SHA fingerprints, then run
   `flutterfire configure` again so Google OAuth clients are written to
   `android/app/google-services.json`.
4. Create the default Firestore database in production mode if it does not
   exist.

The current generated Android configuration has no OAuth client entries, so
Google sign-in will not work until step 3 is completed.

## 2. Bootstrap the first admin

Admin creation is deliberately not available to an unauthenticated client.
Create the first account in Firebase Authentication with:

- Email: `admin@roostify.local`
- A strong temporary password

Copy its Auth UID and create `users/{UID}` in Firestore with these fields:

```text
uid: <the Auth UID>
username: admin
displayName: System Admin
email: <recovery email, or an empty string>
role: admin
cameraAccessEnabled: false
contactNumber: ""
address: ""
facebookContact: ""
farmName: ""
shortBio: ""
createdAt: <timestamp now>
updatedAt: <timestamp now>
```

Only this server/console bootstrap may assign `role: admin`. Client Security
Rules prevent users from creating or promoting an admin profile.

## 3. Deploy backend configuration

Use an explicit project ID so a different Firebase CLI default cannot be used:

```bash
npx -y firebase-tools@latest deploy \
  --project roostify-5ff42 \
  --only firestore:rules,firestore:indexes,functions
```

Cloud Functions deployment may require the Blaze plan. Firebase Storage is not
used by this migration; recordings remain on the app's existing recording
server until Storage billing and retention requirements are decided.

## Account behavior

- Username `farmer1` authenticates internally as
  `farmer1@roostify.local`; the recovery/contact email remains in Firestore.
- A successful login loads the role from `users/{uid}`. Selecting the wrong
  Admin/User portal is rejected.
- Google users may create only their own standard `user` profile. Google admin
  access must already be provisioned by an administrator.
- Add User, Remove User, and Reset Password call server-side Admin SDK
  functions so the active admin session is preserved.
- Each ESP32 update replaces `farms/{uid}/status/latest`; history is sampled at
  most once per minute in `farms/{uid}/sensorReadings`.
