import { createClient, SupabaseClient } from "jsr:@supabase/supabase-js@2";
import { HttpError } from "./http.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

// Privileged client that bypasses RLS - only ever used after requireAdmin
// (or, for ingest-sensor-reading, the device-key check) has authorized the
// caller, mirroring how the Firebase version only did privileged work after
// its own requireAdmin()/device-key check.
export function serviceRoleClient(): SupabaseClient {
  return createClient(SUPABASE_URL, SERVICE_ROLE_KEY);
}

// Verifies the caller's JWT (from the Authorization header Supabase passes
// through automatically on `functions.invoke`) belongs to a signed-in admin.
// Returns the caller's own uid on success.
export async function requireAdmin(req: Request): Promise<string> {
  const authHeader = req.headers.get("Authorization");
  if (!authHeader) {
    throw new HttpError(401, "Sign in as an administrator.");
  }

  const anonClient = createClient(SUPABASE_URL, Deno.env.get("SUPABASE_ANON_KEY")!, {
    global: { headers: { Authorization: authHeader } },
  });
  const { data: { user }, error } = await anonClient.auth.getUser();
  if (error || !user) {
    throw new HttpError(401, "Sign in as an administrator.");
  }

  const admin = serviceRoleClient();
  const { data: profile } = await admin
    .from("profiles")
    .select("role")
    .eq("id", user.id)
    .maybeSingle();
  if (!profile || profile.role !== "admin") {
    throw new HttpError(403, "Administrator access required.");
  }

  return user.id;
}
