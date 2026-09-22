import { corsHeaders } from "../_shared/cors.ts";
import { requireAdmin, serviceRoleClient } from "../_shared/admin.ts";
import { errorResponse, HttpError, jsonResponse, validatedUid } from "../_shared/http.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return errorResponse(405, "Method not allowed");

  try {
    const callerId = await requireAdmin(req);

    const data = (await req.json().catch(() => ({}))) as Record<string, unknown>;
    const uid = validatedUid(data);
    if (uid === callerId) {
      throw new HttpError(400, "Admins cannot delete themselves.");
    }

    const admin = serviceRoleClient();

    const { data: profile } = await admin
      .from("profiles")
      .select("role")
      .eq("id", uid)
      .maybeSingle();
    if (!profile || profile.role === "admin") {
      throw new HttpError(400, "Only standard users can be removed.");
    }

    // Deleting the auth user cascades to the profiles row (FK ON DELETE CASCADE),
    // so no separate profile delete is needed here.
    const { error } = await admin.auth.admin.deleteUser(uid);
    if (error) {
      console.error("delete-roostify-user: deleteUser failed", error);
      throw new HttpError(500, "The account could not be deleted.");
    }

    return jsonResponse(200, { ok: true });
  } catch (error) {
    if (error instanceof HttpError) return errorResponse(error.status, error.message);
    console.error("delete-roostify-user: unexpected error", error);
    return errorResponse(500, "The account could not be deleted.");
  }
});
