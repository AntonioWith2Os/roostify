# Roostify Supabase setup

The app runs entirely on Supabase: Postgres holds profiles and farm sensor
data, Supabase Auth handles sign-in, and Edge Functions cover the
privileged admin actions (create/delete/reset-password user, and the
ESP32's sensor-ingestion endpoint). There is no Firebase project involved
anymore.

## 1. Create the project

In the [Supabase dashboard](https://supabase.com/dashboard), create a new
organization if needed, then a new project (Postgres 15+). Note its
**project ref** (the subdomain in its API URL) — you'll need it below.

From **Project Settings → API**, copy:

- **Project URL** (`https://<ref>.supabase.co`)
- **anon/publishable key**

## 2. Apply the schema

The schema lives at `supabase/migrations/0001_init.sql` and creates
`profiles`, `farm_status`, `farm_sensor_readings`, their Row Level Security
policies, and enables Realtime on `farm_status`.

```bash
npx -y supabase@latest login          # opens a browser to authenticate
npx -y supabase@latest link --project-ref <your-project-ref>
npx -y supabase@latest db push
```

## 3. Deploy the Edge Functions

```bash
# Generate a random shared secret the ESP32 will send as X-Device-Key.
openssl rand -hex 32

npx -y supabase@latest secrets set DEVICE_INGEST_KEY=<the value above> \
  --project-ref <your-project-ref>

npx -y supabase@latest functions deploy create-roostify-user --project-ref <ref>
npx -y supabase@latest functions deploy delete-roostify-user --project-ref <ref>
npx -y supabase@latest functions deploy reset-roostify-user-password --project-ref <ref>
npx -y supabase@latest functions deploy ingest-sensor-reading --no-verify-jwt --project-ref <ref>
```

`ingest-sensor-reading` must be deployed with `--no-verify-jwt` — the ESP32
has no Supabase Auth session, it authenticates with the shared
`X-Device-Key` header instead (checked inside the function itself).

Copy the same `DEVICE_INGEST_KEY` value into `DEVICE_API_KEY` in
`ino_tmp/sketch_sep19a.ino`, and set `INGEST_URL` there to
`https://<your-project-ref>.supabase.co/functions/v1/ingest-sensor-reading`.

## 4. Bootstrap the first admin

Admin creation is deliberately not available to an unauthenticated client.
Create the first account directly:

1. Supabase dashboard → **Authentication → Users → Add user**. Email
   `admin@roostify.local`, a strong password, and confirm the email.
2. Copy its **User UID**, then insert the matching profile row (**Table
   Editor**, or **SQL Editor**):

   ```sql
   insert into public.profiles (id, username, display_name, role, camera_access_enabled)
   values ('<the user uid>', 'admin', 'System Admin', 'admin', false);
   ```

Only this bootstrap step may create an admin — Row Level Security prevents
users from creating or promoting one through the app.

## 5. Run the app

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://<your-project-ref>.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<your anon/publishable key>
```

Both `--dart-define` values have defaults baked into `lib/main.dart`
pointing at the project already configured for this app — override them
only to point at a different Supabase project (e.g. your own fork).

## Account behavior

- Username `farmer1` authenticates internally as `farmer1@roostify.local`;
  the recovery/contact email is a separate `profiles.email` field.
- A successful login loads the role from `profiles`. Selecting the wrong
  Admin/User portal is rejected.
- Add User, Remove User, and Reset Password call the Edge Functions above
  (using the Postgres service role) so the active admin session is
  preserved and Row Level Security is never a blocker for those actions.
- The ESP32 posts directly to `ingest-sensor-reading` over Wi-Fi — the app
  never relays sensor data itself, it only reads `farm_status` live via
  Supabase Realtime. Each update replaces `farm_status`; history is sampled
  at most once per minute into `farm_sensor_readings` (not currently read
  by the app — an audit trail only).
- There is no Google Sign-In — every account is username/password only.
