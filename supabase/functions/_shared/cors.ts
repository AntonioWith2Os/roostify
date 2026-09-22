// The Flutter web build calls these functions from a browser context, so
// preflight requests need a permissive CORS response. The other targets
// (Android/iOS/desktop) aren't subject to CORS at all - this only matters
// for web.
export const corsHeaders: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, x-device-key",
};
