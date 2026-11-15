-- User-triggered SOS backend foundation.
-- Feature Branch source only. No SMS/Push provider is configured by this migration.
-- SOS is delivered only to Main Admin / authorized Support Staff; never to police or 112.

insert into public.srk_admin_permissions(permission_key,description) values
  ('support.sos.read','Read user-triggered SOS cases and minimum required contact context'),
  ('support.sos.acknowledge','Acknowledge an active SOS case')
on conflict (permission_key) do nothing;

insert into public.srk_admin_role_permissions(role_key,permission_key) values
  ('support','support.sos.read'),
  ('support','support.sos.acknowledge')
on conflict (role_key,permission_key) do nothing;

create table if not exists public.srk_sos_alerts (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null references public.service_bookings(id) on delete restrict,
  actor_user_id uuid not null references auth.users(id) on delete restrict,
  actor_role text not null check (actor_role in ('customer','electrician')),
  actor_name text not null check (length(btrim(actor_name)) between 1 and 120),
  actor_phone text not null check (length(btrim(actor_phone)) between 5 and 30),
  reason_code text not null check (reason_code in (
    'customer_at_risk','electrician_at_risk','violence_or_other_emergency'
  )),
  status text not null default 'pending'
    check (status in ('pending','acknowledged')),
  acknowledged_by uuid references auth.users(id) on delete restrict,
  acknowledged_at timestamptz,
  acknowledgement_note text check (
    acknowledgement_note is null or length(btrim(acknowledgement_note)) between 5 and 500
  ),
  -- No live-location consent contract or SMS/Push provider configuration exists yet.
  location_status text not null default 'not_shared'
    check (location_status in ('not_shared','consented_location_pending')),
  sms_delivery_status text not null default 'not_configured'
    check (sms_delivery_status in ('not_configured','queued','sent','failed')),
  push_delivery_status text not null default 'not_configured'
    check (push_delivery_status in ('not_configured','queued','sent','failed')),
  created_at timestamptz not null default clock_timestamp(),
  constraint srk_sos_ack_fields check (
    (status='pending' and acknowledged_by is null and acknowledged_at is null
      and acknowledgement_note is null)
    or (status='acknowledged' and acknowledged_by is not null and acknowledged_at is not null
      and acknowledgement_note is not null)
  )
);

create unique index if not exists srk_sos_one_pending_case_per_booking_uidx
  on public.srk_sos_alerts(booking_id) where status='pending';
create index if not exists srk_sos_alerts_queue_idx
  on public.srk_sos_alerts(status,created_at desc);

create table if not exists public.srk_sos_alert_events (
  id bigint generated always as identity primary key,
  alert_id uuid not null references public.srk_sos_alerts(id) on delete restrict,
  actor_user_id uuid,
  event_type text not null check (event_type in ('created','acknowledged')),
  details jsonb not null default '{}'::jsonb check (jsonb_typeof(details)='object'),
  created_at timestamptz not null default clock_timestamp()
);
create index if not exists srk_sos_alert_events_case_idx
  on public.srk_sos_alert_events(alert_id,created_at,id);

alter table public.srk_sos_alerts enable row level security;
alter table public.srk_sos_alert_events enable row level security;
revoke all on public.srk_sos_alerts from public,anon,authenticated;
revoke all on public.srk_sos_alert_events from public,anon,authenticated;
revoke all on sequence public.srk_sos_alert_events_id_seq from public,anon,authenticated;

create or replace function public.srk_guard_sos_event_immutable()
returns trigger
language plpgsql
set search_path=''
as $function$
begin
  raise exception 'SOS_EVENT_HISTORY_IS_APPEND_ONLY' using errcode='55000';
end;
$function$;
revoke all on function public.srk_guard_sos_event_immutable() from public,anon,authenticated;

drop trigger if exists srk_sos_events_no_row_mutation on public.srk_sos_alert_events;
create trigger srk_sos_events_no_row_mutation
before update or delete on public.srk_sos_alert_events
for each row execute function public.srk_guard_sos_event_immutable();
drop trigger if exists srk_sos_events_no_truncate on public.srk_sos_alert_events;
create trigger srk_sos_events_no_truncate
before truncate on public.srk_sos_alert_events
for each statement execute function public.srk_guard_sos_event_immutable();

create or replace function public.srk_create_sos_alert(p_reason text)
returns jsonb
language plpgsql
security definer
set search_path=''
as $function$
declare
  v_uid uuid:=auth.uid();
  v_customer_count integer:=0;
  v_electrician_count integer:=0;
  v_booking public.service_bookings%rowtype;
  v_profile public.electrician_profiles%rowtype;
  v_actor_role text;
  v_actor_name text;
  v_actor_phone text;
  v_case_id uuid;
begin
  if v_uid is null then
    raise exception 'AUTHENTICATION_REQUIRED' using errcode='42501';
  end if;
  if p_reason is null or p_reason not in (
    'customer_at_risk','electrician_at_risk','violence_or_other_emergency'
  ) then
    raise exception 'INVALID_SOS_REASON' using errcode='22023';
  end if;

  select count(*) into v_customer_count
    from public.service_bookings b
   where b.customer_user_id=v_uid
     and b.selected_category is not null
     and b.status='in_progress';

  select count(distinct b.id) into v_electrician_count
    from public.service_bookings b
    join public.electrician_profiles ep on ep.id=b.assigned_electrician_id
   where (ep.user_id=v_uid or ep.auth_user_id=v_uid)
     and b.selected_category is not null
     and b.status='in_progress';

  if v_customer_count>1 or v_electrician_count>1
     or (v_customer_count>0 and v_electrician_count>0) then
    raise exception 'SOS_ACTIVE_BOOKING_AMBIGUOUS' using errcode='55000';
  end if;
  if v_customer_count=0 and v_electrician_count=0 then
    raise exception 'SOS_REQUIRES_ONE_ACTIVE_BOOKING' using errcode='55000';
  end if;

  if v_customer_count=1 then
    v_actor_role:='customer';
    select b.* into v_booking
      from public.service_bookings b
     where b.customer_user_id=v_uid
       and b.selected_category is not null
       and b.status='in_progress'
     for update;
    v_actor_name:=coalesce(nullif(btrim(v_booking.customer_name),''),'Customer');
    v_actor_phone:=coalesce(nullif(btrim(v_booking.phone),''),'Unavailable');
  else
    v_actor_role:='electrician';
    select b.*,ep.* into v_booking,v_profile
      from public.service_bookings b
      join public.electrician_profiles ep on ep.id=b.assigned_electrician_id
     where (ep.user_id=v_uid or ep.auth_user_id=v_uid)
       and b.selected_category is not null
       and b.status='in_progress'
     for update of b;
    v_actor_name:=coalesce(nullif(btrim(v_profile.display_name),''),'Electrician');
    v_actor_phone:=coalesce(nullif(btrim(v_profile.phone),''),'Unavailable');
  end if;

  -- Serialize against booking completion/cancellation and duplicate SOS submissions.
  if v_booking.id is null or v_booking.status<>'in_progress'
     or v_booking.selected_category is null then
    raise exception 'SOS_REQUIRES_ACTIVE_WORK' using errcode='55000';
  end if;

  select a.id into v_case_id
    from public.srk_sos_alerts a
   where a.booking_id=v_booking.id and a.status='pending'
   for update;
  if found then
    return jsonb_build_object(
      'success',true,'case_id',v_case_id,'created',false,'status','pending',
      'sms_delivery_status','not_configured','push_delivery_status','not_configured'
    );
  end if;

  insert into public.srk_sos_alerts(
    booking_id,actor_user_id,actor_role,actor_name,actor_phone,reason_code
  ) values (
    v_booking.id,v_uid,v_actor_role,v_actor_name,v_actor_phone,p_reason
  )
  on conflict (booking_id) where status='pending' do nothing
  returning id into v_case_id;

  if v_case_id is null then
    select a.id into v_case_id from public.srk_sos_alerts a
     where a.booking_id=v_booking.id and a.status='pending';
    if v_case_id is null then
      raise exception 'SOS_CASE_NOT_CONFIRMED' using errcode='40001';
    end if;
    return jsonb_build_object(
      'success',true,'case_id',v_case_id,'created',false,'status','pending',
      'sms_delivery_status','not_configured','push_delivery_status','not_configured'
    );
  end if;

  insert into public.srk_sos_alert_events(alert_id,actor_user_id,event_type,details)
  values(v_case_id,v_uid,'created',
    jsonb_build_object('actor_role',v_actor_role,'reason_code',p_reason));

  return jsonb_build_object(
    'success',true,'case_id',v_case_id,'created',true,'status','pending',
    'sms_delivery_status','not_configured','push_delivery_status','not_configured'
  );
end;
$function$;
revoke all on function public.srk_create_sos_alert(text) from public,anon;
grant execute on function public.srk_create_sos_alert(text) to authenticated;

create or replace function public.srk_admin_list_sos_alerts(p_limit integer default 100)
returns table(
  case_id uuid,
  booking_id uuid,
  actor_role text,
  actor_name text,
  actor_phone text,
  reason_code text,
  status text,
  location_status text,
  sms_delivery_status text,
  push_delivery_status text,
  acknowledged_by uuid,
  acknowledged_at timestamptz,
  acknowledgement_note text,
  created_at timestamptz
)
language plpgsql
stable
security definer
set search_path=''
as $function$
begin
  if auth.uid() is null or not public.srk_has_admin_permission('support.sos.read') then
    raise exception 'SOS_READ_PERMISSION_REQUIRED' using errcode='42501';
  end if;
  return query
    select a.id,a.booking_id,a.actor_role,a.actor_name,a.actor_phone,a.reason_code,
           a.status,a.location_status,a.sms_delivery_status,a.push_delivery_status,
           a.acknowledged_by,a.acknowledged_at,a.acknowledgement_note,a.created_at
      from public.srk_sos_alerts a
     order by case a.status when 'pending' then 0 else 1 end,a.created_at desc
     limit greatest(1,least(coalesce(p_limit,100),300));
end;
$function$;
revoke all on function public.srk_admin_list_sos_alerts(integer) from public,anon;
grant execute on function public.srk_admin_list_sos_alerts(integer) to authenticated;

create or replace function public.srk_admin_acknowledge_sos_alert(
  p_case_id uuid,
  p_note text
)
returns jsonb
language plpgsql
security definer
set search_path=''
as $function$
declare
  v_uid uuid:=auth.uid();
  v_alert public.srk_sos_alerts%rowtype;
  v_note text:=btrim(coalesce(p_note,''));
begin
  if v_uid is null or not public.srk_has_admin_permission('support.sos.acknowledge') then
    raise exception 'SOS_ACKNOWLEDGE_PERMISSION_REQUIRED' using errcode='42501';
  end if;
  if p_case_id is null or length(v_note) not between 5 and 500 then
    raise exception 'SOS_ACKNOWLEDGEMENT_NOTE_REQUIRED' using errcode='22023';
  end if;

  select * into v_alert from public.srk_sos_alerts
   where id=p_case_id for update;
  if not found then raise exception 'SOS_CASE_NOT_FOUND' using errcode='P0002'; end if;
  if v_alert.status<>'pending' then
    raise exception 'SOS_CASE_ALREADY_ACKNOWLEDGED' using errcode='55000';
  end if;

  update public.srk_sos_alerts
     set status='acknowledged',acknowledged_by=v_uid,
         acknowledged_at=clock_timestamp(),acknowledgement_note=v_note
   where id=p_case_id;

  insert into public.srk_sos_alert_events(alert_id,actor_user_id,event_type,details)
  values(p_case_id,v_uid,'acknowledged',jsonb_build_object('note',left(v_note,500)));

  insert into public.srk_admin_staff_audit_events(actor_user_id,action,outcome,details)
  values(v_uid,'support.sos.acknowledge','success',
    jsonb_build_object('case_id',p_case_id,'booking_id',v_alert.booking_id));

  return jsonb_build_object(
    'success',true,'case_id',p_case_id,'status','acknowledged',
    'acknowledged_at',clock_timestamp()
  );
end;
$function$;
revoke all on function public.srk_admin_acknowledge_sos_alert(uuid,text) from public,anon;
grant execute on function public.srk_admin_acknowledge_sos_alert(uuid,text) to authenticated;

create or replace function public.srk_admin_list_sos_alert_events(p_case_id uuid,p_limit integer default 100)
returns table(id bigint,actor_user_id uuid,event_type text,details jsonb,created_at timestamptz)
language plpgsql
stable
security definer
set search_path=''
as $function$
begin
  if auth.uid() is null or not public.srk_has_admin_permission('support.sos.read') then
    raise exception 'SOS_READ_PERMISSION_REQUIRED' using errcode='42501';
  end if;
  if p_case_id is null then raise exception 'SOS_CASE_ID_REQUIRED' using errcode='22023'; end if;
  if not exists(select 1 from public.srk_sos_alerts a where a.id=p_case_id) then
    raise exception 'SOS_CASE_NOT_FOUND' using errcode='P0002';
  end if;
  return query select e.id,e.actor_user_id,e.event_type,e.details,e.created_at
    from public.srk_sos_alert_events e where e.alert_id=p_case_id
   order by e.created_at,e.id limit greatest(1,least(coalesce(p_limit,100),300));
end;
$function$;
revoke all on function public.srk_admin_list_sos_alert_events(uuid,integer) from public,anon;
grant execute on function public.srk_admin_list_sos_alert_events(uuid,integer) to authenticated;

comment on table public.srk_sos_alerts is
  'Private user-triggered emergency cases for Main Admin and permissioned Support Staff; never auto-notifies police.';
comment on table public.srk_sos_alert_events is
  'Append-only audit history for SOS creation and acknowledgement.';
comment on function public.srk_create_sos_alert(text) is
  'Creates one pending SOS for exactly one authenticated active-work booking; booking and actor are derived server-side.';
