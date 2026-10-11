import { corsHeaders } from "../_shared/cors.ts";
import {
  requireAuthenticatedUser,
  serviceRoleClient,
} from "../_shared/admin.ts";
import { errorResponse, HttpError, jsonResponse } from "../_shared/http.ts";

const policyColumns =
  "created_at, temporary_password_issued_at, temporary_password_first_login_at, password_change_available_at, temporary_password_changed_at";
const temporaryPasswordLockMs = 7 * 24 * 60 * 60 * 1000;

function policyResponse(policy: Record<string, unknown>) {
  return {
    accountCreatedAt: policy.created_at,
    temporaryPasswordIssuedAt: policy.temporary_password_issued_at,
    temporaryPasswordFirstLoginAt: policy.temporary_password_first_login_at,
    passwordChangeAvailableAt: policy.password_change_available_at,
    temporaryPasswordChangedAt: policy.temporary_password_changed_at,
  };
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") return errorResponse(405, "Method not allowed");

  try {
    const caller = await requireAuthenticatedUser(req);
    const admin = serviceRoleClient();
    const { data: profile, error: profileErr } = await admin
      .from("profiles")
      .select(`role, ${policyColumns}`)
      .eq("id", caller.id)
      .maybeSingle();
    if (profileErr || !profile) {
      console.error(
        "record-temporary-password-first-login: profile read failed",
        profileErr,
      );
      throw new HttpError(404, "Account profile not found.");
    }

    // Accounts not created/reset with a temporary password need no policy.
    // An already-started or already-replaced temporary password is also
    // returned unchanged, making this safe on every app launch.
    if (
      profile.role !== "user" ||
      !profile.temporary_password_issued_at ||
      profile.temporary_password_first_login_at ||
      profile.temporary_password_changed_at
    ) {
      return jsonResponse(200, policyResponse(profile));
    }

    const firstLoginAt = new Date();
    const passwordChangeAvailableAt = new Date(
      firstLoginAt.getTime() + temporaryPasswordLockMs,
    );
    const { data: startedPolicy, error: startErr } = await admin
      .from("profiles")
      .update({
        temporary_password_first_login_at: firstLoginAt.toISOString(),
        password_change_available_at: passwordChangeAvailableAt.toISOString(),
      })
      .eq("id", caller.id)
      .is("temporary_password_first_login_at", null)
      .is("temporary_password_changed_at", null)
      .select(policyColumns)
      .maybeSingle();
    if (startErr) {
      console.error(
        "record-temporary-password-first-login: policy update failed",
        startErr,
      );
      throw new HttpError(500, "Unable to start the temporary-password lock.");
    }
    if (startedPolicy) {
      return jsonResponse(200, policyResponse(startedPolicy));
    }

    // A second device can race the first-login request. Read the winner's
    // timestamps rather than moving the unlock date forward.
    const { data: currentPolicy, error: currentErr } = await admin
      .from("profiles")
      .select(policyColumns)
      .eq("id", caller.id)
      .maybeSingle();
    if (currentErr || !currentPolicy) {
      console.error(
        "record-temporary-password-first-login: policy retry read failed",
        currentErr,
      );
      throw new HttpError(500, "Unable to load the temporary-password lock.");
    }
    return jsonResponse(200, policyResponse(currentPolicy));
  } catch (error) {
    if (error instanceof HttpError) {
      return errorResponse(error.status, error.message);
    }
    console.error(
      "record-temporary-password-first-login: unexpected error",
      error,
    );
    return errorResponse(500, "Unable to start the temporary-password lock.");
  }
});
