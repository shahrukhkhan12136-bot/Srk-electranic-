
create table if not exists public.srk_worker_offline_timer_events (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null references public.srk_worker_work_sessions(id) on delete restrict,
  worker_id uuid not null references public.srk_worker_profiles(id) on delete restrict,
  action text not null,
  client_event_at timestamptz not null,
  server_received_at timestamptz not null default now(),
  idempotency_key text not null unique,
  payload jsonb not null default '{}'::jsonb,
  review_status text not null default 'pending',
  reviewed_by uuid,
  reviewed_at timestamptz,
  admin_note text,
  constraint srk_offline_timer_action_valid check(action in ('start','pause','resume','complete')),
  constraint srk_offline_timer_review_valid check(review_status in ('pending','accepted','rejected'))
);
create index if not exists srk_offline_timer_pending_idx
  on public.srk_worker_offline_timer_events(review_status,server_received_at);

alter table public.srk_worker_offline_timer_events enable row level security;
create policy srk_offline_timer_participant_read on public.srk_worker_offline_timer_events
for select to authenticated using(
  public.is_srk_admin()
  or exists(select 1 from public.srk_worker_profiles w where w.id=worker_id and w.user_id=(select auth.uid()))
);

create or replace function public.srk_worker_submit_offline_timer_event(
  p_session_id uuid,p_action text,p_client_event_at timestamptz,p_idempotency_key text,p_payload jsonb default '{}'::jsonb
) returns public.srk_worker_offline_timer_events
language plpgsql security definer
set search_path=pg_catalog,public,auth
as $$
declare v_worker uuid; v_event public.srk_worker_offline_timer_events%rowtype;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  select w.id into v_worker
  from public.srk_worker_work_sessions s
  join public.srk_booking_workers bw on bw.id=s.booking_worker_id
  join public.srk_worker_profiles w on w.id=bw.worker_id
  where s.id=p_session_id and w.user_id=auth.uid();
  if v_worker is null then raise exception 'Session not found or not yours'; end if;
  if p_action not in ('start','pause','resume','complete') then raise exception 'Invalid offline timer action'; end if;
  if p_client_event_at is null or p_client_event_at>clock_timestamp()+interval '5 minutes' then
    raise exception 'Invalid client event timestamp';
  end if;
  insert into public.srk_worker_offline_timer_events(session_id,worker_id,action,client_event_at,idempotency_key,payload)
  values(p_session_id,v_worker,p_action,p_client_event_at,p_idempotency_key,coalesce(p_payload,'{}'::jsonb))
  on conflict(idempotency_key) do update set idempotency_key=excluded.idempotency_key
  returning * into v_event;
  return v_event;
end $$;

create or replace function public.srk_admin_reconcile_offline_timer_event(
  p_event_id uuid,p_decision text,p_adjust_seconds bigint,p_note text
) returns public.srk_worker_offline_timer_events
language plpgsql security definer
set search_path=pg_catalog,public,auth
as $$
declare v_event public.srk_worker_offline_timer_events%rowtype; v_session public.srk_worker_work_sessions%rowtype;
begin
  if not public.srk_has_admin_permission('bookings.manage') then raise exception 'Booking management permission required'; end if;
  if p_decision not in ('accepted','rejected') then raise exception 'Invalid offline event decision'; end if;
  if p_decision='accepted' and (p_adjust_seconds is null or p_adjust_seconds not between -5184000 and 5184000) then
    raise exception 'Timer adjustment is outside allowed range';
  end if;
  select * into v_event from public.srk_worker_offline_timer_events where id=p_event_id for update;
  if not found or v_event.review_status<>'pending' then raise exception 'Offline timer event is not pending'; end if;
  if p_decision='accepted' then
    select * into v_session from public.srk_worker_work_sessions where id=v_event.session_id for update;
    if v_session.session_status='running' then raise exception 'Pause/complete live session before reconciliation'; end if;
    if v_session.billable_seconds+p_adjust_seconds<0 or v_session.billable_seconds+p_adjust_seconds>5184000 then
      raise exception 'Reconciled billable time is outside allowed range';
    end if;
    update public.srk_worker_work_sessions set billable_seconds=billable_seconds+p_adjust_seconds,updated_at=clock_timestamp()
    where id=v_event.session_id;
    insert into public.srk_worker_session_events(session_id,event_type,event_at,actor_user_id,note,source)
    values(v_event.session_id,'admin_adjusted',clock_timestamp(),auth.uid(),
      'Offline timer event '||v_event.action||'; adjustment seconds='||p_adjust_seconds||'; '||coalesce(p_note,''),'admin');
  end if;
  update public.srk_worker_offline_timer_events set review_status=p_decision,reviewed_by=auth.uid(),
    reviewed_at=clock_timestamp(),admin_note=p_note where id=p_event_id returning * into v_event;
  return v_event;
end $$;

create or replace function public.srk_customer_upsert_profile(p_full_name text,p_phone text)
returns public.srk_customer_profiles
language plpgsql security definer
set search_path=pg_catalog,public,auth
as $$
declare v_profile public.srk_customer_profiles%rowtype; v_auth_phone text;
begin
  if auth.uid() is null then raise exception 'OTP login required'; end if;
  if length(btrim(coalesce(p_full_name,'')))<2 or p_phone !~ '^[0-9]{10}$' then raise exception 'Valid name and 10-digit mobile required'; end if;
  v_auth_phone:=right(regexp_replace(coalesce(auth.jwt()->>'phone',''),'[^0-9]','','g'),10);
  if v_auth_phone is not null and v_auth_phone<>'' and v_auth_phone<>p_phone then raise exception 'Mobile number does not match verified OTP login'; end if;
  insert into public.srk_customer_profiles(user_id,full_name,phone)
  values(auth.uid(),btrim(p_full_name),p_phone)
  on conflict(user_id) do update set full_name=excluded.full_name,phone=excluded.phone,updated_at=clock_timestamp()
  returning * into v_profile;
  return v_profile;
end $$;

create or replace function public.srk_customer_create_booking(
 p_category_id uuid,p_service_type_id uuid,p_skill_id uuid,p_technician_count integer,p_helper_count integer,
 p_duration_hours integer,p_state text,p_district text,p_pincode text,p_address text,
 p_booking_latitude double precision,p_booking_longitude double precision,
 p_current_gps_latitude double precision default null,p_current_gps_longitude double precision default null
) returns public.service_bookings
language plpgsql security definer
set search_path=pg_catalog,public,auth
as $$
declare v_customer public.srk_customer_profiles%rowtype; v_service public.srk_service_types%rowtype; v_booking public.service_bookings%rowtype;
begin
  if auth.uid() is null then raise exception 'OTP login required'; end if;
  select * into v_customer from public.srk_customer_profiles where user_id=auth.uid();
  if not found then raise exception 'Complete customer profile before booking'; end if;
  if v_customer.account_status<>'active' then raise exception 'Customer account is restricted from new bookings'; end if;
  if p_technician_count not between 1 and 20 or p_helper_count not between 0 and 20 then raise exception 'Invalid worker count'; end if;
  if p_duration_hours not between 1 and 1440 then raise exception 'Duration must be 1 hour to 60 days'; end if;
  if p_pincode !~ '^[0-9]{6}$' or nullif(btrim(p_state),'') is null or nullif(btrim(p_district),'') is null or nullif(btrim(p_address),'') is null then
    raise exception 'Complete valid booking address required';
  end if;
  if p_booking_latitude is null or p_booking_longitude is null or p_booking_latitude not between -90 and 90 or p_booking_longitude not between -180 and 180 then
    raise exception 'Booking Address GPS coordinates required';
  end if;
  if (p_current_gps_latitude is null)<>(p_current_gps_longitude is null) then raise exception 'Current GPS coordinates must be supplied together'; end if;
  select * into v_service from public.srk_service_types where id=p_service_type_id and category_id=p_category_id and is_active;
  if not found then raise exception 'Service does not belong to active category'; end if;
  if not exists(select 1 from public.srk_service_skills where id=p_skill_id and service_type_id=p_service_type_id and is_active) then
    raise exception 'Work/skill does not belong to selected service'; end if;

  insert into public.service_bookings(customer_name,phone,state,district,pincode,address,service_type,payment_method,status,
    commission_rate,materials_amount,customer_user_id,customer_id,category_id,service_type_id,selected_skill_id,
    requested_technician_count,requested_helper_count,requested_duration_hours,booking_latitude,booking_longitude,
    location_lat,location_lng,booking_address_confirmed_at)
  values(v_customer.full_name,v_customer.phone,btrim(p_state),btrim(p_district),p_pincode,btrim(p_address),v_service.service_name,
    'Cash','new',15.00,0,auth.uid(),v_customer.id,p_category_id,p_service_type_id,p_skill_id,
    p_technician_count,p_helper_count,p_duration_hours,p_booking_latitude,p_booking_longitude,
    p_current_gps_latitude,p_current_gps_longitude,clock_timestamp())
  returning * into v_booking;
  insert into public.srk_booking_matching_queue(booking_id,queue_status) values(v_booking.id,'pending');
  return v_booking;
end $$;

revoke all on function public.srk_worker_submit_offline_timer_event(uuid,text,timestamptz,text,jsonb) from public,anon;
revoke all on function public.srk_admin_reconcile_offline_timer_event(uuid,text,bigint,text) from public,anon;
grant execute on function public.srk_worker_submit_offline_timer_event(uuid,text,timestamptz,text,jsonb) to authenticated;
grant execute on function public.srk_admin_reconcile_offline_timer_event(uuid,text,bigint,text) to authenticated;
