import { createClient } from "jsr:@supabase/supabase-js@2";
import { corsHeaders } from "../_shared/cors.ts";
import {
  requireAuthenticatedUser,
  serviceRoleClient,
} from "../_shared/admin.ts";
import {
  errorResponse,
  HttpError,
  jsonResponse,
  requiredString,
} from "../_shared/http.ts";

const policyColumns =
  "created_at, temporary_password_issued_at, temporary_password_first_login_at, password_change_available_at, temporary_password_changed_at";

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
    const data = (await req.json().catch(() => ({}))) as Record<
      string,
      unknown
    >;
    const currentPassword = requiredString(data, "currentPassword", 128);
    const newPassword = requiredString(data, "newPassword", 128);
    if (newPassword.length < 8) {
      throw new HttpError(
        400,
        "New password must contain at least 8 characters.",
      );
    }

    const admin = serviceRoleClient();
    const { data: profile, error: profileErr } = await admin
      .from("profiles")
      .select(`role, ${policyColumns}`)
      .eq("id", caller.id)
      .maybeSingle();
    if (profileErr || !profile) {
      console.error(
        "change-roostify-password: profile read failed",
        profileErr,
      );
      throw new HttpError(404, "Account profile not found.");
    }

    const { data: authData, error: authReadErr } = await admin.auth.admin
      .getUserById(caller.id);
    const authenticationEmail = authData.user?.email;
    if (authReadErr || !authenticationEmail) {
      console.error(
        "change-roostify-password: auth user read failed",
        authReadErr,
      );
      throw new HttpError(500, "Unable to verify this account.");
    }

    // Verify the current password on the server before using the service-role
    // credential to update Auth. The temporary client has no persisted state.
    const verifier = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_ANON_KEY")!,
      { auth: { persistSession: false, autoRefreshToken: false } },
    );
    const { data: verification, error: verificationErr } = await verifier.auth
      .signInWithPassword({
        email: authenticationEmail,
        password: currentPassword,
      });
    if (verificationErr || verification.user?.id !== caller.id) {
      throw new HttpError(400, "Current password is incorrect.");
    }

    const hasPendingTemporaryPassword = profile.temporary_password_issued_at &&
      !profile.temporary_password_changed_at;
    const availableAt = profile.password_change_available_at
      ? new Date(profile.password_change_available_at)
      : null;
    if (hasPendingTemporaryPassword) {
      if (!availableAt) {
        throw new HttpError(
          409,
          "Your temporary-password lock is still being initialized. Sign in again and try later.",
        );
      }
      if (Date.now() < availableAt.getTime()) {
        throw new HttpError(
          403,
          `Your temporary password can be changed starting ${availableAt.toISOString()}.`,
        );
      }
    }

    const { error: updateAuthErr } = await admin.auth.admin.updateUserById(
      caller.id,
      {
        password: newPassword,
      },
    );
    if (updateAuthErr) {
      console.error(
        "change-roostify-password: updateUserById failed",
        updateAuthErr,
      );
      throw new HttpError(500, "The password could not be changed.");
    }

    let policy: Record<string, unknown> = profile;
    if (hasPendingTemporaryPassword) {
      const { data: updatedPolicy, error: policyUpdateErr } = await admin
        .from("profiles")
        .update({
          temporary_password_changed_at: new Date().toISOString(),
          password_change_available_at: null,
        })
        .eq("id", caller.id)
        .select(policyColumns)
        .maybeSingle();
      if (policyUpdateErr || !updatedPolicy) {
        console.error(
          "change-roostify-password: policy update failed",
          policyUpdateErr,
        );
        throw new HttpError(
          500,
          "The password was changed, but its lock state could not be saved.",
        );
      }
      policy = updatedPolicy;
    }

    return jsonResponse(200, policyResponse(policy));
  } catch (error) {
    if (error instanceof HttpError) {
      return errorResponse(error.status, error.message);
    }
    console.error("change-roostify-password: unexpected error", error);
    return errorResponse(500, "Unable to change the password.");
  }
});
