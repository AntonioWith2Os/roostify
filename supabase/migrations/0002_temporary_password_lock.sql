-- Server-owned state for an administrator-issued temporary password. The
-- client may display this policy but cannot create, start, clear, or extend
-- it: those transitions are performed only by authenticated Edge Functions
-- using the service role.

alter table public.profiles
  add column if not exists temporary_password_issued_at timestamptz,
  add column if not exists temporary_password_first_login_at timestamptz,
  add column if not exists password_change_available_at timestamptz,
  add column if not exists temporary_password_changed_at timestamptz;

comment on column public.profiles.temporary_password_issued_at is
  'Server timestamp when an admin issued a temporary password.';
comment on column public.profiles.temporary_password_first_login_at is
  'Server timestamp of the first completed app login after a temporary password was issued.';
comment on column public.profiles.password_change_available_at is
  'Server timestamp after which the holder may replace an administrator-issued temporary password.';
comment on column public.profiles.temporary_password_changed_at is
  'Server timestamp when the temporary password was replaced by its holder.';

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
  if (
    new.temporary_password_issued_at is distinct from old.temporary_password_issued_at or
    new.temporary_password_first_login_at is distinct from old.temporary_password_first_login_at or
    new.password_change_available_at is distinct from old.password_change_available_at or
    new.temporary_password_changed_at is distinct from old.temporary_password_changed_at
  ) and coalesce(auth.role(), '') <> 'service_role' then
    raise exception 'temporary password policy is managed by the server';
  end if;
  new.updated_at := now();
  return new;
end;
$$;
