-- Admin Staff RBAC foundation.
-- Source-only: do not apply until the complete migration set is reviewed and staging is approved.
-- Main Admin identity remains exclusively in srk_admin_users. Staff are never inserted there.

create table if not exists public.srk_admin_staff (
  user_id uuid primary key references auth.users(id) on delete restrict,
  display_name text not null check (length(btrim(display_name)) between 2 and 100),
  role_key text not null default 'support'
    check (role_key in ('support')),
  status text not null default 'invited'
    check (status in ('invited','active','suspended','disabled')),
  invited_by uuid references auth.users(id) on delete restrict,
  created_at timestamptz not null default clock_timestamp(),
  updated_at timestamptz not null default clock_timestamp(),
  activated_at timestamptz,
  disabled_at timestamptz,
  constraint srk_admin_staff_status_timestamps check (
    (status = 'active' and activated_at is not null and disabled_at is null)
    or (status in ('invited','suspended') and disabled_at is null)
    or (status = 'disabled' and disabled_at is not null)
  )
);

create index if not exists srk_admin_staff_status_role_idx
  on public.srk_admin_staff(status, role_key, created_at desc);

create table if not exists public.srk_admin_permissions (
  permission_key text primary key,
  description text not null,
  created_at timestamptz not null default clock_timestamp()
);

create table if not exists public.srk_admin_role_permissions (
  role_key text not null check (role_key in ('support')),
  permission_key text not null references public.srk_admin_permissions(permission_key) on delete restrict,
  created_at timestamptz not null default clock_timestamp(),
  primary key (role_key, permission_key)
);

create table if not exists public.srk_admin_staff_sessions (
  id uuid primary key default gen_random_uuid(),
  staff_user_id uuid not null references public.srk_admin_staff(user_id) on delete restrict,
  issued_at timestamptz not null default clock_timestamp(),
  last_seen_at timestamptz not null default clock_timestamp(),
  revoked_at timestamptz,
  revoked_by uuid references auth.users(id) on delete restrict,
  revoke_reason text check (revoke_reason is null or length(revoke_reason) <= 500),
  constraint srk_admin_staff_session_revocation_fields check (
    (revoked_at is null and revoked_by is null and revoke_reason is null)
    or (revoked_at is not null and revoked_by is not null)
  )
);
create index if not exists srk_admin_staff_sessions_active_idx
  on public.srk_admin_staff_sessions(staff_user_id, issued_at desc)
  where revoked_at is null;

create table if not exists public.srk_admin_staff_audit_events (
  id bigint generated always as identity primary key,
  actor_user_id uuid references auth.users(id) on delete set null,
  target_user_id uuid references auth.users(id) on delete set null,
  action text not null check (length(btrim(action)) between 3 and 100),
  outcome text not null default 'success'
    check (outcome in ('success','denied','failed')),
  details jsonb not null default '{}'::jsonb
    check (jsonb_typeof(details) = 'object'),
  created_at timestamptz not null default clock_timestamp()
);
create index if not exists srk_admin_staff_audit_target_idx
  on public.srk_admin_staff_audit_events(target_user_id, created_at desc);
create index if not exists srk_admin_staff_audit_actor_idx
  on public.srk_admin_staff_audit_events(actor_user_id, created_at desc);

-- Only the initial Support role is enabled. Future roles are intentionally absent.
insert into public.srk_admin_permissions(permission_key, description) values
  ('support.customer.read', 'Read customer support conversations assigned through the support workflow'),
  ('support.customer.reply', 'Reply to customer support conversations'),
  ('support.customer.update_status', 'Update customer support conversation status'),
  ('support.electrician.read', 'Read electrician support conversations assigned through the support workflow'),
  ('support.electrician.reply', 'Reply to electrician support conversations'),
  ('support.electrician.update_status', 'Update electrician support conversation status'),
  ('booking.read_basic', 'Read minimum booking context explicitly required for a support case')
on conflict (permission_key) do nothing;

insert into public.srk_admin_role_permissions(role_key, permission_key) values
  ('support','support.customer.read'),
  ('support','support.customer.reply'),
  ('support','support.customer.update_status'),
  ('support','support.electrician.read'),
  ('support','support.electrician.reply'),
  ('support','support.electrician.update_status'),
  ('support','booking.read_basic')
on conflict (role_key, permission_key) do nothing;

alter table public.srk_admin_staff enable row level security;
alter table public.srk_admin_permissions enable row level security;
alter table public.srk_admin_role_permissions enable row level security;
alter table public.srk_admin_staff_sessions enable row level security;
alter table public.srk_admin_staff_audit_events enable row level security;

-- No direct table access from browser roles. Access will be through narrowly scoped RPCs.
revoke all on public.srk_admin_staff from public, anon, authenticated;
revoke all on public.srk_admin_permissions from public, anon, authenticated;
revoke all on public.srk_admin_role_permissions from public, anon, authenticated;
revoke all on public.srk_admin_staff_sessions from public, anon, authenticated;
revoke all on public.srk_admin_staff_audit_events from public, anon, authenticated;
revoke all on sequence public.srk_admin_staff_audit_events_id_seq from public, anon, authenticated;

create or replace function public.srk_has_admin_permission(p_permission_key text)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $function$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null or p_permission_key is null or length(p_permission_key) > 120 then
    return false;
  end if;

  -- Main Admin is a separate, full-control identity class.
  if public.is_srk_admin() then
    return true;
  end if;

  return exists (
    select 1
      from public.srk_admin_staff s
      join public.srk_admin_role_permissions rp on rp.role_key = s.role_key
      join public.srk_admin_permissions p on p.permission_key = rp.permission_key
     where s.user_id = v_uid
       and s.status = 'active'
       and p.permission_key = p_permission_key
  );
end;
$function$;

revoke all on function public.srk_has_admin_permission(text) from public, anon;
grant execute on function public.srk_has_admin_permission(text) to authenticated;

create or replace function public.srk_guard_admin_staff_audit_immutable()
returns trigger
language plpgsql
set search_path = ''
as $function$
begin
  raise exception 'ADMIN_STAFF_AUDIT_IS_APPEND_ONLY'
    using errcode = '55000';
end;
$function$;
revoke all on function public.srk_guard_admin_staff_audit_immutable() from public, anon, authenticated;

drop trigger if exists srk_admin_staff_audit_no_row_mutation
  on public.srk_admin_staff_audit_events;
create trigger srk_admin_staff_audit_no_row_mutation
before update or delete on public.srk_admin_staff_audit_events
for each row execute function public.srk_guard_admin_staff_audit_immutable();

drop trigger if exists srk_admin_staff_audit_no_truncate
  on public.srk_admin_staff_audit_events;
create trigger srk_admin_staff_audit_no_truncate
before truncate on public.srk_admin_staff_audit_events
for each statement execute function public.srk_guard_admin_staff_audit_immutable();

comment on table public.srk_admin_staff is
  'Support staff registry. Never add staff identities to srk_admin_users.';
comment on table public.srk_admin_staff_sessions is
  'Session metadata only; never store access tokens, refresh tokens, passwords, or OTPs.';
comment on table public.srk_admin_staff_audit_events is
  'Append-only staff security and activity audit. Sensitive credentials and full private contact details must not be stored.';
comment on function public.srk_has_admin_permission(text) is
  'Main Admin always passes; Support Staff pass only for an active registry record and explicit role permission.';
