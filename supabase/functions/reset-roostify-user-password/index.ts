import { corsHeaders } from "../_shared/cors.ts";
import { requireAdmin, serviceRoleClient } from "../_shared/admin.ts";
import {
  errorResponse,
  HttpError,
  jsonResponse,
  requiredString,
  validatedUid,
} from "../_shared/http.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return errorResponse(405, "Method not allowed");

  try {
    const callerId = await requireAdmin(req);

    const data = (await req.json().catch(() => ({}))) as Record<string, unknown>;
    const uid = validatedUid(data);
    const temporaryPassword = requiredString(data, "temporaryPassword", 128);

    if (uid === callerId) {
      throw new HttpError(400, "Use the profile security page to change your own password.");
    }
    if (temporaryPassword.length < 8) {
      throw new HttpError(400, "Temporary password must contain at least 8 characters.");
    }

    const admin = serviceRoleClient();

    const { data: profile } = await admin
      .from("profiles")
      .select("role")
      .eq("id", uid)
      .maybeSingle();
    if (!profile || profile.role === "admin") {
      throw new HttpError(400, "Only standard users can be reset.");
    }

    const { error: updateAuthErr } = await admin.auth.admin.updateUserById(uid, {
      password: temporaryPassword,
    });
    if (updateAuthErr) {
      console.error("reset-roostify-user-password: updateUserById failed", updateAuthErr);
      throw new HttpError(500, "The password could not be reset.");
    }

    // The profiles_enforce_update_rules trigger sets updated_at itself.
    const { error: updateProfileErr } = await admin
      .from("profiles")
      .update({ password_reset_at: new Date().toISOString() })
      .eq("id", uid);
    if (updateProfileErr) {
      console.error("reset-roostify-user-password: profile update failed", updateProfileErr);
      throw new HttpError(500, "The password could not be reset.");
    }

    return jsonResponse(200, { ok: true });
  } catch (error) {
    if (error instanceof HttpError) return errorResponse(error.status, error.message);
    console.error("reset-roostify-user-password: unexpected error", error);
    return errorResponse(500, "The password could not be reset.");
  }
});
