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


-- Bind staff authorization to the current, still-existing Supabase Auth session.
alter table public.srk_admin_staff_sessions
  add column if not exists auth_session_id uuid;
create unique index if not exists srk_admin_staff_sessions_auth_session_uidx
  on public.srk_admin_staff_sessions(auth_session_id)
  where auth_session_id is not null;

create or replace function public.srk_has_admin_permission(p_permission_key text)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $function$
declare
  v_uid uuid := auth.uid();
  v_session_id uuid;
begin
  if v_uid is null or p_permission_key is null or length(p_permission_key) > 120 then
    return false;
  end if;

  -- Preserve the existing, separate Main Admin authority model.
  if public.is_srk_admin() then
    return true;
  end if;

  if coalesce(auth.jwt() ->> 'session_id','') !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then
    return false;
  end if;
  v_session_id := (auth.jwt() ->> 'session_id')::uuid;

  return exists (
    select 1
      from public.srk_admin_staff s
      join public.srk_admin_role_permissions rp on rp.role_key = s.role_key
      join public.srk_admin_permissions p on p.permission_key = rp.permission_key
     where s.user_id = v_uid
       and s.status = 'active'
       and p.permission_key = p_permission_key
       and exists (
         select 1 from auth.sessions auth_s
          where auth_s.id = v_session_id and auth_s.user_id = v_uid
       )
       and exists (
         select 1 from public.srk_admin_staff_sessions tracked
          where tracked.auth_session_id = v_session_id
            and tracked.staff_user_id = v_uid
            and tracked.revoked_at is null
       )
  );
end;
$function$;
revoke all on function public.srk_has_admin_permission(text) from public, anon;
grant execute on function public.srk_has_admin_permission(text) to authenticated;

create or replace function public.srk_admin_staff_register_session()
returns boolean
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_uid uuid := auth.uid();
  v_session_id uuid;
begin
  if v_uid is null
     or coalesce(auth.jwt() ->> 'session_id','') !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then
    return false;
  end if;
  v_session_id := (auth.jwt() ->> 'session_id')::uuid;

  if not exists (
    select 1 from public.srk_admin_staff s
     where s.user_id = v_uid and s.status = 'active'
  ) or not exists (
    select 1 from auth.sessions a
     where a.id = v_session_id and a.user_id = v_uid
  ) then
    return false;
  end if;

  insert into public.srk_admin_staff_sessions
    (staff_user_id, auth_session_id, issued_at, last_seen_at)
  values (v_uid, v_session_id, clock_timestamp(), clock_timestamp())
  on conflict (auth_session_id) where auth_session_id is not null
  do update set last_seen_at = clock_timestamp()
    where public.srk_admin_staff_sessions.staff_user_id = excluded.staff_user_id
      and public.srk_admin_staff_sessions.revoked_at is null;

  return exists (
    select 1 from public.srk_admin_staff_sessions s
     where s.staff_user_id = v_uid
       and s.auth_session_id = v_session_id
       and s.revoked_at is null
  );
end;
$function$;
revoke all on function public.srk_admin_staff_register_session() from public, anon;
grant execute on function public.srk_admin_staff_register_session() to authenticated;

create or replace function public.srk_admin_list_staff()
returns table (
  user_id uuid,
  display_name text,
  role_key text,
  status text,
  created_at timestamptz,
  activated_at timestamptz,
  disabled_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $function$
begin
  if auth.uid() is null or not public.is_srk_admin() then
    raise exception 'ADMIN_ONLY' using errcode = '42501';
  end if;
  return query
    select s.user_id, s.display_name, s.role_key, s.status,
           s.created_at, s.activated_at, s.disabled_at
      from public.srk_admin_staff s
     order by s.created_at desc;
end;
$function$;
revoke all on function public.srk_admin_list_staff() from public, anon;
grant execute on function public.srk_admin_list_staff() to authenticated;

create or replace function public.srk_admin_staff_set_status(
  p_staff_user_id uuid,
  p_status text,
  p_reason text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_actor uuid := auth.uid();
  v_old_status text;
begin
  if v_actor is null or not public.is_srk_admin() then
    raise exception 'ADMIN_ONLY' using errcode = '42501';
  end if;
  if p_staff_user_id is null or p_status is null or p_status not in ('active','suspended','disabled')
     or length(btrim(coalesce(p_reason,''))) < 5
     or length(p_reason) > 500 then
    raise exception 'INVALID_STAFF_STATUS_REQUEST' using errcode = '22023';
  end if;

  select status into v_old_status
    from public.srk_admin_staff
   where user_id = p_staff_user_id
   for update;
  if not found then
    raise exception 'STAFF_NOT_FOUND' using errcode = 'P0002';
  end if;

  update public.srk_admin_staff
     set status = p_status,
         activated_at = case when p_status = 'active' then coalesce(activated_at, clock_timestamp()) else activated_at end,
         disabled_at = case when p_status = 'disabled' then clock_timestamp() else null end,
         updated_at = clock_timestamp()
   where user_id = p_staff_user_id;

  if p_status in ('suspended','disabled') then
    update public.srk_admin_staff_sessions
       set revoked_at = coalesce(revoked_at, clock_timestamp()),
           revoked_by = coalesce(revoked_by, v_actor),
           revoke_reason = coalesce(revoke_reason, left(p_reason,500))
     where staff_user_id = p_staff_user_id and revoked_at is null;
  end if;

  insert into public.srk_admin_staff_audit_events
    (actor_user_id,target_user_id,action,outcome,details)
  values
    (v_actor,p_staff_user_id,'staff.status.' || p_status,'success',
     jsonb_build_object('previous_status',v_old_status,'new_status',p_status,'reason',left(p_reason,500)));

  return jsonb_build_object('success',true,'previous_status',v_old_status,'status',p_status);
end;
$function$;
revoke all on function public.srk_admin_staff_set_status(uuid,text,text) from public, anon;
grant execute on function public.srk_admin_staff_set_status(uuid,text,text) to authenticated;

-- Auth Admin API user creation is intentionally service-role-only and called only by the
-- separately authenticated Edge Function. It cannot grant any role except Support.
create or replace function public.srk_admin_staff_register_invited_user(
  p_staff_user_id uuid,
  p_display_name text,
  p_actor_admin_id uuid
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $function$
begin
  if p_staff_user_id is null or p_actor_admin_id is null
     or not exists (select 1 from public.srk_admin_users a where a.user_id = p_actor_admin_id)
     or length(btrim(coalesce(p_display_name,''))) not between 2 and 100 then
    raise exception 'INVALID_STAFF_INVITE' using errcode = '22023';
  end if;

  insert into public.srk_admin_staff(user_id,display_name,role_key,status,invited_by)
  values (p_staff_user_id,btrim(p_display_name),'support','invited',p_actor_admin_id);

  insert into public.srk_admin_staff_audit_events
    (actor_user_id,target_user_id,action,outcome,details)
  values
    (p_actor_admin_id,p_staff_user_id,'staff.invited','success',
     jsonb_build_object('role_key','support'));

  return true;
end;
$function$;
revoke all on function public.srk_admin_staff_register_invited_user(uuid,text,uuid) from public, anon, authenticated;
grant execute on function public.srk_admin_staff_register_invited_user(uuid,text,uuid) to service_role;

comment on column public.srk_admin_staff_sessions.auth_session_id is
  'Supabase Auth session UUID from JWT session_id; never store JWTs or refresh tokens.';


create or replace function public.srk_admin_list_staff_sessions(p_staff_user_id uuid)
returns table (
  session_record_id uuid,
  issued_at timestamptz,
  last_seen_at timestamptz,
  revoked_at timestamptz,
  revoke_reason text
)
language plpgsql
stable
security definer
set search_path = ''
as $function$
begin
  if auth.uid() is null or not public.is_srk_admin() then
    raise exception 'ADMIN_ONLY' using errcode = '42501';
  end if;
  if p_staff_user_id is null then
    raise exception 'STAFF_ID_REQUIRED' using errcode = '22023';
  end if;
  return query
    select s.id,s.issued_at,s.last_seen_at,s.revoked_at,s.revoke_reason
      from public.srk_admin_staff_sessions s
     where s.staff_user_id = p_staff_user_id
     order by s.issued_at desc
     limit 100;
end;
$function$;
revoke all on function public.srk_admin_list_staff_sessions(uuid) from public, anon;
grant execute on function public.srk_admin_list_staff_sessions(uuid) to authenticated;

create or replace function public.srk_admin_staff_revoke_session(
  p_session_record_id uuid,
  p_reason text
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_actor uuid := auth.uid();
  v_staff_user_id uuid;
begin
  if v_actor is null or not public.is_srk_admin() then
    raise exception 'ADMIN_ONLY' using errcode = '42501';
  end if;
  if p_session_record_id is null or length(btrim(coalesce(p_reason,''))) < 5
     or length(p_reason) > 500 then
    raise exception 'INVALID_SESSION_REVOCATION' using errcode = '22023';
  end if;

  update public.srk_admin_staff_sessions
     set revoked_at = coalesce(revoked_at,clock_timestamp()),
         revoked_by = coalesce(revoked_by,v_actor),
         revoke_reason = coalesce(revoke_reason,left(p_reason,500))
   where id = p_session_record_id
   returning staff_user_id into v_staff_user_id;
  if not found then
    raise exception 'STAFF_SESSION_NOT_FOUND' using errcode = 'P0002';
  end if;

  insert into public.srk_admin_staff_audit_events
    (actor_user_id,target_user_id,action,outcome,details)
  values
    (v_actor,v_staff_user_id,'staff.session.revoked','success',
     jsonb_build_object('session_record_id',p_session_record_id,'reason',left(p_reason,500)));

  return true;
end;
$function$;
revoke all on function public.srk_admin_staff_revoke_session(uuid,text) from public, anon;
grant execute on function public.srk_admin_staff_revoke_session(uuid,text) to authenticated;


-- Current ownership map for support cases. A single active owner is allowed per case.
create table if not exists public.srk_admin_support_assignments (
  id uuid primary key default gen_random_uuid(),
  case_type text not null check (case_type in ('customer_complaint','electrician_ticket')),
  case_id uuid not null,
  assigned_staff_user_id uuid not null references public.srk_admin_staff(user_id) on delete restrict,
  assigned_by uuid not null references auth.users(id) on delete restrict,
  assigned_at timestamptz not null default clock_timestamp(),
  updated_at timestamptz not null default clock_timestamp(),
  unique(case_type,case_id)
);
create index if not exists srk_admin_support_assignments_staff_idx
  on public.srk_admin_support_assignments(assigned_staff_user_id,case_type,updated_at desc);
alter table public.srk_admin_support_assignments enable row level security;
revoke all on public.srk_admin_support_assignments from public,anon,authenticated;

-- Staff sender identity is retained on customer conversation messages without changing legacy rows.
alter table public.srk_booking_complaint_messages
  add column if not exists sender_user_id uuid references auth.users(id) on delete set null;

create or replace function public.srk_admin_assign_support_case(
  p_case_type text,
  p_case_id uuid,
  p_staff_user_id uuid,
  p_reason text
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_actor uuid := auth.uid();
  v_previous_staff uuid;
begin
  if v_actor is null or not public.is_srk_admin() then
    raise exception 'MAIN_ADMIN_ONLY' using errcode = '42501';
  end if;
  if p_case_type is null or p_case_type not in ('customer_complaint','electrician_ticket')
     or p_case_id is null or p_staff_user_id is null
     or length(btrim(coalesce(p_reason,''))) < 5 or length(p_reason)>500 then
    raise exception 'INVALID_SUPPORT_ASSIGNMENT' using errcode = '22023';
  end if;
  if not exists (
    select 1 from public.srk_admin_staff s
     where s.user_id=p_staff_user_id and s.role_key='support' and s.status='active'
  ) then
    raise exception 'SUPPORT_STAFF_NOT_ACTIVE' using errcode = '22023';
  end if;
  if p_case_type='customer_complaint' and not exists (
    select 1 from public.srk_booking_complaints c where c.id=p_case_id and c.status<>'closed'
  ) then
    raise exception 'CUSTOMER_COMPLAINT_NOT_FOUND_OR_CLOSED' using errcode = 'P0002';
  end if;
  if p_case_type='electrician_ticket' and not exists (
    select 1 from public.srk_electrician_support_tickets t where t.id=p_case_id and t.status<>'closed'
  ) then
    raise exception 'ELECTRICIAN_TICKET_NOT_FOUND_OR_CLOSED' using errcode = 'P0002';
  end if;

  select a.assigned_staff_user_id into v_previous_staff
    from public.srk_admin_support_assignments a
   where a.case_type=p_case_type and a.case_id=p_case_id
   for update;

  insert into public.srk_admin_support_assignments
    (case_type,case_id,assigned_staff_user_id,assigned_by,assigned_at,updated_at)
  values (p_case_type,p_case_id,p_staff_user_id,v_actor,clock_timestamp(),clock_timestamp())
  on conflict (case_type,case_id) do update
    set assigned_staff_user_id=excluded.assigned_staff_user_id,
        assigned_by=excluded.assigned_by,
        assigned_at=clock_timestamp(),
        updated_at=clock_timestamp();

  insert into public.srk_admin_staff_audit_events
    (actor_user_id,target_user_id,action,outcome,details)
  values
    (v_actor,p_staff_user_id,'support.case.assigned','success',
     jsonb_build_object('case_type',p_case_type,'case_id',p_case_id,
       'previous_staff_user_id',v_previous_staff,'assigned_staff_user_id',p_staff_user_id,
       'reason',left(p_reason,500)));
  return true;
end;
$function$;
revoke all on function public.srk_admin_assign_support_case(text,uuid,uuid,text) from public,anon;
grant execute on function public.srk_admin_assign_support_case(text,uuid,uuid,text) to authenticated;

create or replace function public.srk_admin_staff_list_customer_complaints()
returns table (
  id uuid, booking_id uuid, category text, description text,
  status text, created_at timestamptz, updated_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $function$
begin
  if auth.uid() is null or not public.srk_has_admin_permission('support.customer.read') then
    raise exception 'SUPPORT_CUSTOMER_READ_REQUIRED' using errcode = '42501';
  end if;
  return query
    select c.id,c.booking_id,c.category,c.description,c.status,c.created_at,c.updated_at
      from public.srk_booking_complaints c
      join public.srk_admin_support_assignments a
        on a.case_type='customer_complaint' and a.case_id=c.id
     where a.assigned_staff_user_id=auth.uid()
     order by c.updated_at desc,c.id desc limit 100;
end;
$function$;
revoke all on function public.srk_admin_staff_list_customer_complaints() from public,anon;
grant execute on function public.srk_admin_staff_list_customer_complaints() to authenticated;

create or replace function public.srk_admin_staff_list_customer_messages(p_complaint_id uuid)
returns table(id uuid,sender_role text,body text,created_at timestamptz)
language plpgsql
stable
security definer
set search_path = ''
as $function$
begin
  if auth.uid() is null or not public.srk_has_admin_permission('support.customer.read') then
    raise exception 'SUPPORT_CUSTOMER_READ_REQUIRED' using errcode = '42501';
  end if;
  if not exists (
    select 1 from public.srk_admin_support_assignments a
     where a.case_type='customer_complaint' and a.case_id=p_complaint_id
       and a.assigned_staff_user_id=auth.uid()
  ) then raise exception 'SUPPORT_CASE_NOT_ASSIGNED_TO_YOU' using errcode = '42501'; end if;
  return query
    select m.id,m.sender_role,m.body,m.created_at
      from public.srk_booking_complaint_messages m
     where m.complaint_id=p_complaint_id
     order by m.created_at,m.id limit 200;
end;
$function$;
revoke all on function public.srk_admin_staff_list_customer_messages(uuid) from public,anon;
grant execute on function public.srk_admin_staff_list_customer_messages(uuid) to authenticated;

create or replace function public.srk_admin_staff_send_customer_message(p_complaint_id uuid,p_body text)
returns uuid
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_uid uuid:=auth.uid();
  v_message_id uuid;
begin
  if v_uid is null or not public.srk_has_admin_permission('support.customer.reply') then
    raise exception 'SUPPORT_CUSTOMER_REPLY_REQUIRED' using errcode='42501';
  end if;
  if p_body is null or length(btrim(p_body)) not between 1 and 4000 then
    raise exception 'MESSAGE_MUST_BE_1_TO_4000_CHARACTERS' using errcode='22023';
  end if;
  perform 1 from public.srk_admin_support_assignments a
   where a.case_type='customer_complaint' and a.case_id=p_complaint_id
     and a.assigned_staff_user_id=v_uid for update;
  if not found then raise exception 'SUPPORT_CASE_NOT_ASSIGNED_TO_YOU' using errcode='42501'; end if;
  if exists(select 1 from public.srk_booking_complaints c where c.id=p_complaint_id and c.status='closed') then
    raise exception 'SUPPORT_CASE_CLOSED' using errcode='55000';
  end if;
  insert into public.srk_booking_complaint_messages(complaint_id,sender_role,sender_user_id,body)
  values(p_complaint_id,'admin',v_uid,btrim(p_body))
  returning id into v_message_id;
  insert into public.srk_admin_staff_audit_events(actor_user_id,action,outcome,details)
  values(v_uid,'support.customer.reply','success',
    jsonb_build_object('case_id',p_complaint_id,'message_id',v_message_id));
  return v_message_id;
end;
$function$;
revoke all on function public.srk_admin_staff_send_customer_message(uuid,text) from public,anon;
grant execute on function public.srk_admin_staff_send_customer_message(uuid,text) to authenticated;

create or replace function public.srk_admin_staff_update_customer_complaint(
  p_complaint_id uuid,p_status text,p_reason text
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_uid uuid:=auth.uid();
  v_old_status text;
begin
  if v_uid is null or not public.srk_has_admin_permission('support.customer.update_status') then
    raise exception 'SUPPORT_CUSTOMER_STATUS_REQUIRED' using errcode='42501';
  end if;
  if p_status is null or p_status not in ('in_review','resolved') or p_reason is null
     or length(btrim(p_reason)) not between 5 and 500 then
    raise exception 'INVALID_SUPPORT_STATUS_UPDATE' using errcode='22023';
  end if;
  perform 1 from public.srk_admin_support_assignments a
   where a.case_type='customer_complaint' and a.case_id=p_complaint_id
     and a.assigned_staff_user_id=v_uid for update;
  if not found then raise exception 'SUPPORT_CASE_NOT_ASSIGNED_TO_YOU' using errcode='42501'; end if;
  select c.status into v_old_status from public.srk_booking_complaints c
   where c.id=p_complaint_id for update;
  if not found then raise exception 'CUSTOMER_COMPLAINT_NOT_FOUND' using errcode='P0002'; end if;
  if v_old_status='closed' then raise exception 'SUPPORT_CASE_CLOSED' using errcode='55000'; end if;

  update public.srk_booking_complaints
     set status=p_status,updated_at=clock_timestamp(),updated_by=v_uid,
         resolved_at=case when p_status='resolved' then coalesce(resolved_at,clock_timestamp()) else null end,
         resolved_by=case when p_status='resolved' then coalesce(resolved_by,v_uid) else null end
   where id=p_complaint_id;
  insert into public.srk_booking_complaint_events
    (complaint_id,actor_user_id,actor_role,from_status,to_status,note)
  values(p_complaint_id,v_uid,'admin',v_old_status,p_status,left(p_reason,500));
  insert into public.srk_admin_staff_audit_events(actor_user_id,action,outcome,details)
  values(v_uid,'support.customer.update_status','success',
    jsonb_build_object('case_id',p_complaint_id,'from_status',v_old_status,
      'to_status',p_status,'reason',left(p_reason,500)));
  return true;
end;
$function$;
revoke all on function public.srk_admin_staff_update_customer_complaint(uuid,text,text) from public,anon;
grant execute on function public.srk_admin_staff_update_customer_complaint(uuid,text,text) to authenticated;

create or replace function public.srk_admin_staff_list_electrician_tickets()
returns table (
  id uuid, booking_id uuid, category text, subject text,
  status text, created_at timestamptz, updated_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $function$
begin
  if auth.uid() is null or not public.srk_has_admin_permission('support.electrician.read') then
    raise exception 'SUPPORT_ELECTRICIAN_READ_REQUIRED' using errcode='42501';
  end if;
  return query
    select t.id,t.booking_id,t.category,t.subject,t.status,t.created_at,t.updated_at
      from public.srk_electrician_support_tickets t
      join public.srk_admin_support_assignments a
        on a.case_type='electrician_ticket' and a.case_id=t.id
     where a.assigned_staff_user_id=auth.uid()
     order by t.updated_at desc,t.id desc limit 100;
end;
$function$;
revoke all on function public.srk_admin_staff_list_electrician_tickets() from public,anon;
grant execute on function public.srk_admin_staff_list_electrician_tickets() to authenticated;

create or replace function public.srk_admin_staff_list_electrician_messages(p_ticket_id uuid)
returns table(id uuid,sender_role text,body text,created_at timestamptz)
language plpgsql
stable
security definer
set search_path = ''
as $function$
begin
  if auth.uid() is null or not public.srk_has_admin_permission('support.electrician.read') then
    raise exception 'SUPPORT_ELECTRICIAN_READ_REQUIRED' using errcode='42501';
  end if;
  if not exists(select 1 from public.srk_admin_support_assignments a
    where a.case_type='electrician_ticket' and a.case_id=p_ticket_id
      and a.assigned_staff_user_id=auth.uid()) then
    raise exception 'SUPPORT_CASE_NOT_ASSIGNED_TO_YOU' using errcode='42501';
  end if;
  return query select m.id,m.sender_role,m.body,m.created_at
    from public.srk_electrician_support_messages m
   where m.ticket_id=p_ticket_id order by m.created_at,m.id limit 300;
end;
$function$;
revoke all on function public.srk_admin_staff_list_electrician_messages(uuid) from public,anon;
grant execute on function public.srk_admin_staff_list_electrician_messages(uuid) to authenticated;

create or replace function public.srk_admin_staff_send_electrician_message(p_ticket_id uuid,p_body text)
returns uuid
language plpgsql
security definer
set search_path = ''
as $function$
declare v_uid uuid:=auth.uid(); v_message_id uuid;
begin
  if v_uid is null or not public.srk_has_admin_permission('support.electrician.reply') then
    raise exception 'SUPPORT_ELECTRICIAN_REPLY_REQUIRED' using errcode='42501';
  end if;
  if p_body is null or length(btrim(p_body)) not between 1 and 4000 then
    raise exception 'MESSAGE_MUST_BE_1_TO_4000_CHARACTERS' using errcode='22023';
  end if;
  perform 1 from public.srk_admin_support_assignments a
   where a.case_type='electrician_ticket' and a.case_id=p_ticket_id
     and a.assigned_staff_user_id=v_uid for update;
  if not found then raise exception 'SUPPORT_CASE_NOT_ASSIGNED_TO_YOU' using errcode='42501'; end if;
  if exists(select 1 from public.srk_electrician_support_tickets t where t.id=p_ticket_id and t.status='closed') then
    raise exception 'SUPPORT_CASE_CLOSED' using errcode='55000';
  end if;
  insert into public.srk_electrician_support_messages(ticket_id,sender_role,sender_user_id,body)
  values(p_ticket_id,'admin',v_uid,btrim(p_body)) returning id into v_message_id;
  insert into public.srk_admin_staff_audit_events(actor_user_id,action,outcome,details)
  values(v_uid,'support.electrician.reply','success',
    jsonb_build_object('case_id',p_ticket_id,'message_id',v_message_id));
  return v_message_id;
end;
$function$;
revoke all on function public.srk_admin_staff_send_electrician_message(uuid,text) from public,anon;
grant execute on function public.srk_admin_staff_send_electrician_message(uuid,text) to authenticated;

create or replace function public.srk_admin_staff_update_electrician_ticket(
  p_ticket_id uuid,p_status text,p_reason text
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $function$
declare v_uid uuid:=auth.uid(); v_old_status text;
begin
  if v_uid is null or not public.srk_has_admin_permission('support.electrician.update_status') then
    raise exception 'SUPPORT_ELECTRICIAN_STATUS_REQUIRED' using errcode='42501';
  end if;
  if p_status not in ('in_review','resolved') or p_reason is null
     or length(btrim(p_reason)) not between 5 and 500 then
    raise exception 'INVALID_SUPPORT_STATUS_UPDATE' using errcode='22023';
  end if;
  perform 1 from public.srk_admin_support_assignments a
   where a.case_type='electrician_ticket' and a.case_id=p_ticket_id
     and a.assigned_staff_user_id=v_uid for update;
  if not found then raise exception 'SUPPORT_CASE_NOT_ASSIGNED_TO_YOU' using errcode='42501'; end if;
  select t.status into v_old_status from public.srk_electrician_support_tickets t
   where t.id=p_ticket_id for update;
  if not found then raise exception 'ELECTRICIAN_TICKET_NOT_FOUND' using errcode='P0002'; end if;
  if v_old_status='closed' then raise exception 'SUPPORT_CASE_CLOSED' using errcode='55000'; end if;
  update public.srk_electrician_support_tickets
     set status=p_status,updated_at=clock_timestamp(),updated_by=v_uid
   where id=p_ticket_id;
  insert into public.srk_admin_staff_audit_events(actor_user_id,action,outcome,details)
  values(v_uid,'support.electrician.update_status','success',
    jsonb_build_object('case_id',p_ticket_id,'from_status',v_old_status,
      'to_status',p_status,'reason',left(p_reason,500)));
  return true;
end;
$function$;
revoke all on function public.srk_admin_staff_update_electrician_ticket(uuid,text,text) from public,anon;
grant execute on function public.srk_admin_staff_update_electrician_ticket(uuid,text,text) to authenticated;



create or replace function public.srk_admin_list_support_assignments()
returns table (
  case_type text,
  case_id uuid,
  assigned_staff_user_id uuid,
  assigned_staff_name text,
  assigned_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $function$
begin
  if auth.uid() is null or not public.is_srk_admin() then
    raise exception 'MAIN_ADMIN_ONLY' using errcode='42501';
  end if;
  return query
    select a.case_type,a.case_id,a.assigned_staff_user_id,s.display_name,a.assigned_at
      from public.srk_admin_support_assignments a
      join public.srk_admin_staff s on s.user_id=a.assigned_staff_user_id
     order by a.updated_at desc limit 1000;
end;
$function$;
revoke all on function public.srk_admin_list_support_assignments() from public,anon;
grant execute on function public.srk_admin_list_support_assignments() to authenticated;
