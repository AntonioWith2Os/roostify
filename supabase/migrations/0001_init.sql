-- Roostify: initial Supabase schema (replaces Firestore/Firebase).
-- Mirrors the data model previously enforced by firestore.rules:
--   users/{uid}                    -> public.profiles
--   farms/{uid}/status/latest      -> public.farm_status
--   farms/{uid}/sensorReadings/*   -> public.farm_sensor_readings

create extension if not exists pgcrypto;

-- ---------------------------------------------------------------------------
-- profiles
-- ---------------------------------------------------------------------------

create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  username text not null unique check (username ~ '^[a-z0-9._-]{3,32}$'),
  display_name text not null check (char_length(display_name) between 1 and 80),
  email text not null default '' check (char_length(email) <= 254),
  role text not null check (role in ('admin', 'user')),
  camera_access_enabled boolean not null default true,
  contact_number text not null default '' check (char_length(contact_number) <= 32),
  address text not null default '' check (char_length(address) <= 240),
  facebook_contact text not null default '' check (char_length(facebook_contact) <= 120),
  farm_name text not null default '' check (char_length(farm_name) <= 120),
  short_bio text not null default '' check (char_length(short_bio) <= 500),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  password_reset_at timestamptz
);

comment on table public.profiles is
  'One row per Roostify account, keyed by the Supabase auth user id. Created/deleted only by the create-roostify-user / delete-roostify-user Edge Functions using the service role.';

alter table public.profiles enable row level security;

-- Security-definer so RLS on profiles itself doesn't block this from
-- checking another user's role while evaluating a policy.
create or replace function public.is_admin()
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid() and role = 'admin'
  );
$$;

-- RLS policies can't restrict *which columns* an UPDATE touches, so the
-- Firestore-rules equivalent of "role/created_at are immutable, and only an
-- admin may change camera_access_enabled" has to be a trigger instead.
create or replace function public.enforce_profile_update_rules()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.role is distinct from old.role then
    raise exception 'role cannot be changed via a profile update';
  end if;
  if new.created_at is distinct from old.created_at then
    raise exception 'created_at is immutable';
  end if;
  if new.camera_access_enabled is distinct from old.camera_access_enabled
     and not public.is_admin() then
    raise exception 'only an admin can change camera_access_enabled';
  end if;
  new.updated_at := now();
  return new;
end;
$$;

create trigger profiles_enforce_update_rules
  before update on public.profiles
  for each row
  execute function public.enforce_profile_update_rules();

create policy "profiles_select_own_or_admin"
  on public.profiles for select
  using (id = auth.uid() or public.is_admin());

create policy "profiles_update_own_or_admin"
  on public.profiles for update
  using (id = auth.uid() or public.is_admin())
  with check (id = auth.uid() or public.is_admin());

-- No insert/delete policy for authenticated/anon: only the service-role
-- client (Edge Functions) creates or deletes profile rows.

-- ---------------------------------------------------------------------------
-- farm_status - one row per farm, the "latest reading" the app reads live.
-- ---------------------------------------------------------------------------

create table public.farm_status (
  owner_uid uuid primary key references public.profiles (id) on delete cascade,
  temperature numeric not null check (temperature between -50 and 100),
  humidity numeric not null check (humidity between 0 and 100),
  air_ppm integer not null check (air_ppm between 0 and 100000),
  dht_available boolean not null,
  air_available boolean not null,
  updated_at timestamptz not null
);

comment on table public.farm_status is
  'Latest environment reading per farm. Written only by the ingest-sensor-reading Edge Function (service role); the app only ever reads it, live via Realtime.';

alter table public.farm_status enable row level security;

create policy "farm_status_select_owner_or_admin"
  on public.farm_status for select
  using (owner_uid = auth.uid() or public.is_admin());

-- No write policy: only the service-role client writes this table.

alter publication supabase_realtime add table public.farm_status;

-- ---------------------------------------------------------------------------
-- farm_sensor_readings - append-only history/audit trail.
-- ---------------------------------------------------------------------------

create table public.farm_sensor_readings (
  id uuid primary key default gen_random_uuid(),
  owner_uid uuid not null references public.profiles (id) on delete cascade,
  temperature numeric not null check (temperature between -50 and 100),
  humidity numeric not null check (humidity between 0 and 100),
  air_ppm integer not null check (air_ppm between 0 and 100000),
  dht_available boolean not null,
  air_available boolean not null,
  created_at timestamptz not null default now()
);

comment on table public.farm_sensor_readings is
  'Append-only sensor history, sampled at most once/minute by ingest-sensor-reading. Not currently queried by the app - audit trail only.';

create index farm_sensor_readings_owner_uid_created_at_idx
  on public.farm_sensor_readings (owner_uid, created_at desc);

alter table public.farm_sensor_readings enable row level security;

create policy "farm_sensor_readings_select_owner_or_admin"
  on public.farm_sensor_readings for select
  using (owner_uid = auth.uid() or public.is_admin());

-- No write policy: only the service-role client writes this table.
