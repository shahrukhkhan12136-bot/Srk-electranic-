
create or replace function public.srk_find_eligible_workers(p_booking_id uuid, p_worker_type text)
returns table(worker_id uuid, worker_code text, worker_type text, distance_km numeric)
language plpgsql
security definer
set search_path to 'pg_catalog','public'
as $function$
declare v_booking public.service_bookings%rowtype;
begin
  if p_worker_type not in ('technician','helper') then raise exception 'Invalid worker type'; end if;
  select * into v_booking from public.service_bookings where id=p_booking_id;
  if not found then raise exception 'Booking not found'; end if;
  if v_booking.booking_latitude is null or v_booking.booking_longitude is null then raise exception 'Booking GPS required'; end if;
  return query
  select w.id,w.worker_code,w.worker_type,
    round((6371*acos(least(1,greatest(-1,
      cos(radians(v_booking.booking_latitude))*cos(radians(w.location_lat))*cos(radians(w.location_lng)-radians(v_booking.booking_longitude))+
      sin(radians(v_booking.booking_latitude))*sin(radians(w.location_lat))
    ))))::numeric,2)
  from public.srk_worker_profiles w
  where w.worker_type=p_worker_type and w.category_id=v_booking.category_id
    and w.verification_status='approved' and w.is_active and w.is_online
    and w.location_lat is not null and w.location_lng is not null
    and exists(select 1 from public.srk_worker_skills ws where ws.worker_id=w.id and ws.skill_id=v_booking.selected_skill_id and ws.verification_status='approved')
    and (6371*acos(least(1,greatest(-1,
      cos(radians(v_booking.booking_latitude))*cos(radians(w.location_lat))*cos(radians(w.location_lng)-radians(v_booking.booking_longitude))+
      sin(radians(v_booking.booking_latitude))*sin(radians(w.location_lat))
    ))))<=least(30,w.service_radius_km)
    and not exists(
      select 1 from public.srk_worker_work_sessions s
      where s.worker_id=w.id and s.session_status in ('running','paused')
    )
    and not exists(
      select 1 from public.srk_booking_workers bw
      where bw.worker_id=w.id and bw.assignment_status in ('working','paused')
    )
    and not exists(select 1 from public.srk_worker_schedule_blocks sb where sb.worker_id=w.id
      and sb.block_status in ('reserved','confirmed','in_progress')
      and sb.starts_at<=clock_timestamp()+make_interval(hours=>coalesce(v_booking.requested_duration_hours,1))
      and sb.ends_at>clock_timestamp())
  order by 4,w.created_at;
end $function$;

create or replace function public.srk_guard_worker_session()
returns trigger
language plpgsql
set search_path to 'pg_catalog','public'
as $function$
declare v_worker_id uuid;
begin
  select bw.worker_id into v_worker_id
  from public.srk_booking_workers bw
  where bw.id=new.booking_worker_id;
  if v_worker_id is null then raise exception 'Booking worker assignment not found'; end if;

  perform pg_advisory_xact_lock(hashtextextended(v_worker_id::text,0));

  if new.session_status in ('running','paused') then
    if exists(
      select 1
      from public.srk_worker_work_sessions s
      where s.worker_id=v_worker_id
        and s.session_status in ('running','paused')
        and s.id<>coalesce(new.id,'00000000-0000-0000-0000-000000000000'::uuid)
    ) then
      raise exception 'Worker already has an active or paused work session at another booking';
    end if;
  end if;
  return new;
end $function$;

create or replace function public.srk_worker_respond_assignment(p_assignment_id uuid,p_accept boolean)
returns public.srk_booking_workers
language plpgsql
security definer
set search_path to 'pg_catalog','public','auth'
as $function$
declare
 v_assignment public.srk_booking_workers%rowtype;
 v_worker public.srk_worker_profiles%rowtype;
 v_booking public.service_bookings%rowtype;
 v_accepted_count integer;
 v_requested_count integer;
begin
 if auth.uid() is null then raise exception 'Authentication required'; end if;

 select bw.* into v_assignment
 from public.srk_booking_workers bw
 join public.srk_worker_profiles wp on wp.id=bw.worker_id
 where bw.id=p_assignment_id and wp.user_id=auth.uid()
 for update of bw;

 if not found or v_assignment.assignment_status<>'offered' then
  raise exception 'Offer not found or no longer pending';
 end if;

 select * into v_booking from public.service_bookings
 where id=v_assignment.booking_id for update;
 if not found or v_booking.status='cancelled' then
  raise exception 'Booking is no longer available';
 end if;

 select * into v_worker from public.srk_worker_profiles
 where id=v_assignment.worker_id for update;
 if not found then raise exception 'Worker profile not found'; end if;

 if p_accept then
  if v_worker.verification_status<>'approved' or not v_worker.is_active then
   raise exception 'Worker is not currently approved and active';
  end if;

  -- Serialize acceptance with timer start/pause operations for this worker.
  perform pg_advisory_xact_lock(hashtextextended(v_worker.id::text,0));

  if exists(
    select 1 from public.srk_worker_work_sessions s
    where s.worker_id=v_worker.id and s.session_status in ('running','paused')
  ) or exists(
    select 1 from public.srk_booking_workers bw
    where bw.worker_id=v_worker.id and bw.assignment_status in ('working','paused')
  ) then
   raise exception 'Finish or complete the active/paused booking before accepting another booking';
  end if;

  v_requested_count:=case when v_assignment.worker_role='technician'
   then v_booking.requested_technician_count else v_booking.requested_helper_count end;

  select count(*) into v_accepted_count
  from public.srk_booking_workers
  where booking_id=v_assignment.booking_id
   and worker_role=v_assignment.worker_role
   and assignment_status in ('accepted','assigned','working','paused','completed');

  if v_accepted_count>=v_requested_count then
   raise exception 'Requested number of this worker role has already been filled';
  end if;
 end if;

 update public.srk_booking_workers
 set assignment_status=case when p_accept then 'accepted' else 'rejected' end,
  accepted_at=case when p_accept then clock_timestamp() else null end,
  rejected_at=case when p_accept then null else clock_timestamp() end,
  offer_expires_at=null,updated_at=clock_timestamp()
 where id=p_assignment_id returning * into v_assignment;

 if p_accept and v_assignment.worker_role='technician' then
  update public.service_bookings set status='confirmed'
  where id=v_assignment.booking_id and status='new';
 end if;

 update public.srk_booking_matching_queue
 set queue_status='pending',next_attempt_at=clock_timestamp(),updated_at=clock_timestamp()
 where booking_id=v_assignment.booking_id and queue_status not in ('fulfilled','cancelled');

 return v_assignment;
end
$function$;

revoke all on function public.srk_find_eligible_workers(uuid,text) from public,anon;
grant execute on function public.srk_find_eligible_workers(uuid,text) to authenticated;
revoke all on function public.srk_worker_respond_assignment(uuid,boolean) from public,anon;
grant execute on function public.srk_worker_respond_assignment(uuid,boolean) to authenticated;
