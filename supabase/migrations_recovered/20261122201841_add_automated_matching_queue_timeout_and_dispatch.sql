
create table if not exists public.srk_system_settings (
  setting_key text primary key,
  setting_value jsonb not null,
  updated_by uuid,
  updated_at timestamptz not null default now()
);
insert into public.srk_system_settings(setting_key,setting_value)
values('offer_timeout_seconds','null'::jsonb)
on conflict(setting_key) do nothing;

create table if not exists public.srk_booking_matching_queue (
  booking_id uuid primary key references public.service_bookings(id) on delete restrict,
  queue_status text not null default 'pending',
  attempts integer not null default 0,
  next_attempt_at timestamptz not null default now(),
  last_attempt_at timestamptz,
  completed_at timestamptz,
  last_error text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint srk_matching_queue_status_valid check(queue_status in ('pending','searching','waiting','fulfilled','cancelled','failed')),
  constraint srk_matching_queue_attempts_valid check(attempts>=0)
);
create index if not exists srk_matching_queue_due_idx
  on public.srk_booking_matching_queue(queue_status,next_attempt_at);

alter table public.srk_booking_workers
  add column if not exists offer_expires_at timestamptz;

alter table public.srk_system_settings enable row level security;
alter table public.srk_booking_matching_queue enable row level security;

create policy srk_system_settings_admin_read on public.srk_system_settings
for select to authenticated using(public.is_srk_admin());
create policy srk_matching_queue_admin_read on public.srk_booking_matching_queue
for select to authenticated using(public.srk_has_admin_permission('bookings.manage'));

create or replace function public.srk_admin_set_offer_timeout(p_seconds integer)
returns boolean language plpgsql security definer
set search_path=pg_catalog,public
as $$
begin
  if not public.srk_has_admin_permission('bookings.manage') then raise exception 'Booking management permission required'; end if;
  if p_seconds is null or p_seconds not between 30 and 3600 then raise exception 'Offer timeout must be 30 to 3600 seconds'; end if;
  insert into public.srk_system_settings(setting_key,setting_value,updated_by,updated_at)
  values('offer_timeout_seconds',to_jsonb(p_seconds),auth.uid(),clock_timestamp())
  on conflict(setting_key) do update set setting_value=excluded.setting_value,updated_by=excluded.updated_by,updated_at=excluded.updated_at;
  return true;
end $$;

create or replace function public.srk_process_booking_matching_queue()
returns integer
language plpgsql
security definer
set search_path=pg_catalog,public
as $$
declare
  v_queue record;
  v_booking public.service_bookings%rowtype;
  v_timeout integer;
  v_tech_count integer;
  v_helper_count integer;
  v_candidate record;
  v_level uuid;
  v_rate_id uuid;
  v_rate numeric(10,2);
  v_role text;
  v_inserted integer:=0;
begin
  select nullif(setting_value::text,'null')::integer into v_timeout
  from public.srk_system_settings where setting_key='offer_timeout_seconds';

  -- Expire unanswered offers only after Admin configures the timeout.
  if v_timeout is not null then
    update public.srk_booking_workers
      set assignment_status='rejected',rejected_at=clock_timestamp(),admin_note='Offer timed out',updated_at=clock_timestamp()
    where assignment_status='offered' and offer_expires_at is not null and offer_expires_at<=clock_timestamp();
  end if;

  for v_queue in
    select q.* from public.srk_booking_matching_queue q
    where q.queue_status in ('pending','searching','waiting') and q.next_attempt_at<=clock_timestamp()
    order by q.created_at
    for update skip locked
    limit 25
  loop
    select * into v_booking from public.service_bookings where id=v_queue.booking_id for update;
    if not found or v_booking.status='cancelled' then
      update public.srk_booking_matching_queue set queue_status='cancelled',updated_at=clock_timestamp()
      where booking_id=v_queue.booking_id;
      continue;
    end if;

    select count(*) into v_tech_count from public.srk_booking_workers
    where booking_id=v_booking.id and worker_role='technician'
      and assignment_status in ('offered','accepted','assigned','working','paused','completed');
    select count(*) into v_helper_count from public.srk_booking_workers
    where booking_id=v_booking.id and worker_role='helper'
      and assignment_status in ('offered','accepted','assigned','working','paused','completed');

    if v_tech_count>=v_booking.requested_technician_count and v_helper_count>=v_booking.requested_helper_count then
      update public.srk_booking_matching_queue set queue_status='fulfilled',completed_at=coalesce(completed_at,clock_timestamp()),updated_at=clock_timestamp()
      where booking_id=v_booking.id;
      update public.service_bookings set status='confirmed' where id=v_booking.id and status='new';
      continue;
    end if;

    v_role:=case when v_tech_count<v_booking.requested_technician_count then 'technician' else 'helper' end;
    v_candidate:=null;

    for v_candidate in
      select c.* from public.srk_find_eligible_workers(v_booking.id,v_role) c
      where not exists(select 1 from public.srk_booking_workers bw
        where bw.booking_id=v_booking.id and bw.worker_id=c.worker_id)
      order by c.distance_km
    loop
      select ws.skill_level_id into v_level from public.srk_worker_skills ws
      where ws.worker_id=v_candidate.worker_id and ws.skill_id=v_booking.selected_skill_id and ws.verification_status='approved'
      limit 1;

      select r.id,case when v_role='technician' then r.technician_hourly_rate else r.helper_hourly_rate end
      into v_rate_id,v_rate
      from public.srk_service_rates r
      where r.category_id=v_booking.category_id and r.skill_level_id=v_level
        and (r.service_type_id is null or r.service_type_id=v_booking.service_type_id)
        and r.rate_status='approved' and r.effective_from<=clock_timestamp()
        and (r.effective_to is null or r.effective_to>clock_timestamp())
        and (case when v_role='technician' then r.technician_hourly_rate else r.helper_hourly_rate end) is not null
      order by (r.service_type_id is not null) desc,r.effective_from desc limit 1;

      if v_rate is null then continue; end if;

      insert into public.srk_booking_workers(
        booking_id,worker_id,worker_role,assignment_status,rate_id,hourly_rate_snapshot,skill_level_snapshot_id,offer_expires_at
      ) values(
        v_booking.id,v_candidate.worker_id,v_role,'offered',v_rate_id,v_rate,v_level,
        case when v_timeout is null then null else clock_timestamp()+make_interval(secs=>v_timeout) end
      );
      update public.srk_booking_matching_queue set queue_status='searching',attempts=attempts+1,
        last_attempt_at=clock_timestamp(),next_attempt_at=clock_timestamp()+interval '1 minute',
        last_error=null,updated_at=clock_timestamp() where booking_id=v_booking.id;
      v_inserted:=v_inserted+1;
      exit;
    end loop;

    if v_candidate is null then
      update public.srk_booking_matching_queue set queue_status='waiting',attempts=attempts+1,
        last_attempt_at=clock_timestamp(),next_attempt_at=clock_timestamp()+interval '1 minute',
        last_error='No eligible online approved worker found',updated_at=clock_timestamp()
      where booking_id=v_booking.id;
    end if;
  end loop;
  return v_inserted;
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
declare v_customer public.srk_customer_profiles%rowtype; v_service public.srk_service_types%rowtype;
  v_skill public.srk_service_skills%rowtype; v_booking public.service_bookings%rowtype;
begin
  if auth.uid() is null then raise exception 'OTP login required'; end if;
  select * into v_customer from public.srk_customer_profiles where user_id=auth.uid();
  if not found then raise exception 'Complete customer profile before booking'; end if;
  if p_technician_count not between 1 and 20 or p_helper_count not between 0 and 20 then raise exception 'Invalid worker count'; end if;
  if p_duration_hours not between 1 and 1440 then raise exception 'Duration must be 1 hour to 60 days'; end if;
  if p_pincode !~ '^[0-9]{6}$' or nullif(btrim(p_state),'') is null or nullif(btrim(p_district),'') is null or nullif(btrim(p_address),'') is null then
    raise exception 'Complete valid booking address is required';
  end if;
  if p_booking_latitude is null or p_booking_longitude is null or p_booking_latitude not between -90 and 90 or p_booking_longitude not between -180 and 180 then
    raise exception 'Booking Address GPS coordinates are required';
  end if;
  if (p_current_gps_latitude is null)<>(p_current_gps_longitude is null) then raise exception 'Current GPS coordinates must be supplied together'; end if;
  select * into v_service from public.srk_service_types where id=p_service_type_id and category_id=p_category_id and is_active;
  if not found then raise exception 'Service does not belong to active category'; end if;
  select * into v_skill from public.srk_service_skills where id=p_skill_id and service_type_id=p_service_type_id and is_active;
  if not found then raise exception 'Work/skill does not belong to selected service'; end if;

  insert into public.service_bookings(
    customer_name,phone,state,district,pincode,address,service_type,payment_method,status,commission_rate,
    materials_amount,customer_user_id,customer_id,category_id,service_type_id,selected_skill_id,
    requested_technician_count,requested_helper_count,requested_duration_hours,booking_latitude,booking_longitude,
    location_lat,location_lng,booking_address_confirmed_at
  ) values(
    v_customer.full_name,v_customer.phone,btrim(p_state),btrim(p_district),p_pincode,btrim(p_address),
    v_service.service_name,'Cash','new',15.00,0,auth.uid(),v_customer.id,p_category_id,p_service_type_id,p_skill_id,
    p_technician_count,p_helper_count,p_duration_hours,p_booking_latitude,p_booking_longitude,
    p_current_gps_latitude,p_current_gps_longitude,clock_timestamp()
  ) returning * into v_booking;

  insert into public.srk_booking_matching_queue(booking_id,queue_status) values(v_booking.id,'pending');
  return v_booking;
end $$;

create or replace function public.srk_worker_respond_assignment(p_assignment_id uuid,p_accept boolean)
returns public.srk_booking_workers
language plpgsql security definer
set search_path=pg_catalog,public,auth
as $$
declare v_assignment public.srk_booking_workers%rowtype; v_worker public.srk_worker_profiles%rowtype; v_count bigint;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  select bw.* into v_assignment from public.srk_booking_workers bw
  join public.srk_worker_profiles wp on wp.id=bw.worker_id
  where bw.id=p_assignment_id and wp.user_id=auth.uid() for update of bw;
  if not found or v_assignment.assignment_status<>'offered' then raise exception 'Offer not found or no longer pending'; end if;
  select * into v_worker from public.srk_worker_profiles where id=v_assignment.worker_id;
  if p_accept and v_worker.worker_type='technician' then
    select completed_booking_count into v_count from public.srk_technician_booking_cycle where technician_id=v_worker.id;
    if coalesce(v_count,0)+1 in (3,6) then
      update public.service_bookings set payment_method='Online' where id=v_assignment.booking_id;
    end if;
  end if;
  update public.srk_booking_workers set assignment_status=case when p_accept then 'accepted' else 'rejected' end,
    accepted_at=case when p_accept then clock_timestamp() else null end,
    rejected_at=case when p_accept then null else clock_timestamp() end,offer_expires_at=null,updated_at=clock_timestamp()
  where id=p_assignment_id returning * into v_assignment;
  if p_accept and v_worker.worker_type='technician' then
    update public.service_bookings set status='confirmed' where id=v_assignment.booking_id and status='new';
  end if;
  update public.srk_booking_matching_queue set queue_status='pending',next_attempt_at=clock_timestamp(),updated_at=clock_timestamp()
  where booking_id=v_assignment.booking_id and queue_status not in ('fulfilled','cancelled');
  return v_assignment;
end $$;

revoke all on function public.srk_process_booking_matching_queue() from public,anon,authenticated;
grant execute on function public.srk_process_booking_matching_queue() to service_role;
revoke all on function public.srk_admin_set_offer_timeout(integer) from public,anon;
grant execute on function public.srk_admin_set_offer_timeout(integer) to authenticated,service_role;
