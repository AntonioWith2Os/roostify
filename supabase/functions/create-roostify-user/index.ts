import { corsHeaders } from "../_shared/cors.ts";
import { requireAdmin, serviceRoleClient } from "../_shared/admin.ts";
import {
  errorResponse,
  HttpError,
  jsonResponse,
  optionalString,
  requiredString,
} from "../_shared/http.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return errorResponse(405, "Method not allowed");

  try {
    await requireAdmin(req);

    const data = (await req.json().catch(() => ({}))) as Record<string, unknown>;
    const username = requiredString(data, "username", 32).toLowerCase();
    const displayName = requiredString(data, "displayName", 80);
    const temporaryPassword = requiredString(data, "temporaryPassword", 128);
    const email = optionalString(data, "email", 254);
    const farmName = optionalString(data, "farmName", 120);
    const contactNumber = optionalString(data, "contactNumber", 32);
    const address = optionalString(data, "address", 240);

    if (!/^[a-z0-9._-]{3,32}$/.test(username)) {
      throw new HttpError(
        400,
        "Username must be 3–32 lowercase letters, numbers, dots, dashes, or underscores.",
      );
    }
    if (temporaryPassword.length < 8) {
      throw new HttpError(400, "Temporary password must contain at least 8 characters.");
    }
    if (email && !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
      throw new HttpError(400, "Enter a valid recovery email.");
    }

    const admin = serviceRoleClient();

    const { data: duplicate } = await admin
      .from("profiles")
      .select("id")
      .eq("username", username)
      .limit(1);
    if (duplicate && duplicate.length > 0) {
      throw new HttpError(409, "That username already exists.");
    }

    const authenticationEmail = `${username}@roostify.local`;
    const { data: created, error: createErr } = await admin.auth.admin.createUser({
      email: authenticationEmail,
      password: temporaryPassword,
      email_confirm: true,
    });

    if (createErr || !created?.user) {
      if (createErr?.message?.toLowerCase().includes("already")) {
        throw new HttpError(409, "That username already exists.");
      }
      console.error("create-roostify-user: createUser failed", createErr);
      throw new HttpError(500, "The account could not be created.");
    }

    const profile = {
      id: created.user.id,
      username,
      display_name: displayName,
      email,
      role: "user",
      camera_access_enabled: true,
      contact_number: contactNumber,
      address,
      facebook_contact: "",
      farm_name: farmName,
      short_bio: "",
    };

    const { data: savedProfile, error: insertErr } = await admin
      .from("profiles")
      .insert(profile)
      .select()
      .maybeSingle();

    if (insertErr) {
      await admin.auth.admin.deleteUser(created.user.id).catch(() => undefined);
      console.error("create-roostify-user: profile insert failed", insertErr);
      throw new HttpError(500, "The account could not be created.");
    }

    return jsonResponse(200, { uid: created.user.id, profile: savedProfile ?? profile });
  } catch (error) {
    if (error instanceof HttpError) return errorResponse(error.status, error.message);
    console.error("create-roostify-user: unexpected error", error);
    return errorResponse(500, "The account could not be created.");
  }
});
