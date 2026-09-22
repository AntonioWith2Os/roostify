// Called directly by the ESP32 firmware over Wi-Fi (ino_tmp/sketch_sep19a.ino)
// - there's no Supabase Auth session on the device, so this checks a shared
// secret (X-Device-Key) instead and writes with the service-role client,
// which bypasses RLS. ownerUid is still checked against a real farmer
// profile so a leaked key can only ever write into an existing farm, not an
// arbitrary path. verify_jwt is disabled for this function at deploy time.
import { corsHeaders } from "../_shared/cors.ts";
import { serviceRoleClient } from "../_shared/admin.ts";
import { errorResponse, jsonResponse } from "../_shared/http.ts";

const DEVICE_INGEST_KEY = Deno.env.get("DEVICE_INGEST_KEY");

function numberInRange(value: unknown, min: number, max: number): number | null {
  return typeof value === "number" && Number.isFinite(value) && value >= min && value <= max
    ? value
    : null;
}

const HISTORY_SAMPLE_INTERVAL_MS = 60_000;

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return errorResponse(405, "Method not allowed");

  if (!DEVICE_INGEST_KEY || req.headers.get("X-Device-Key") !== DEVICE_INGEST_KEY) {
    return errorResponse(401, "Unauthorized");
  }

  const body = (await req.json().catch(() => ({}))) as Record<string, unknown>;
  const ownerUid = typeof body.ownerUid === "string" ? body.ownerUid.trim() : "";
  if (!ownerUid || !/^[0-9a-fA-F-]{1,128}$/.test(ownerUid)) {
    return errorResponse(400, "Invalid ownerUid");
  }

  const temperature = numberInRange(body.temperature, -50, 100);
  const humidity = numberInRange(body.humidity, 0, 100);
  const airPpm = numberInRange(body.airPpm, 0, 100000);
  const dhtAvailable = typeof body.dhtAvailable === "boolean" ? body.dhtAvailable : null;
  const airAvailable = typeof body.airAvailable === "boolean" ? body.airAvailable : null;
  if (
    temperature === null || humidity === null || airPpm === null ||
    dhtAvailable === null || airAvailable === null
  ) {
    return errorResponse(400, "Invalid sensor payload");
  }

  const admin = serviceRoleClient();

  const { data: profile } = await admin
    .from("profiles")
    .select("role")
    .eq("id", ownerUid)
    .maybeSingle();
  if (!profile || profile.role !== "user") {
    return errorResponse(403, "Unknown farm owner");
  }

  const updatedAt = new Date();
  const values = {
    temperature,
    humidity,
    air_ppm: Math.round(airPpm),
    dht_available: dhtAvailable,
    air_available: airAvailable,
    updated_at: updatedAt.toISOString(),
  };

  const { data: previous } = await admin
    .from("farm_status")
    .select("updated_at")
    .eq("owner_uid", ownerUid)
    .maybeSingle();
  const recentlyRecorded = previous?.updated_at &&
    updatedAt.getTime() - new Date(previous.updated_at).getTime() < HISTORY_SAMPLE_INTERVAL_MS;

  const { error: upsertErr } = await admin
    .from("farm_status")
    .upsert({ owner_uid: ownerUid, ...values });
  if (upsertErr) {
    console.error("ingest-sensor-reading: farm_status upsert failed", upsertErr);
    return errorResponse(500, "Could not record the reading");
  }

  if (!recentlyRecorded) {
    const { error: historyErr } = await admin
      .from("farm_sensor_readings")
      .insert({ owner_uid: ownerUid, ...values });
    if (historyErr) {
      console.error("ingest-sensor-reading: history insert failed", historyErr);
      // The live status write already succeeded - don't fail the whole
      // request over the throttled history log.
    }
  }

  return jsonResponse(200, { ok: true });
});
