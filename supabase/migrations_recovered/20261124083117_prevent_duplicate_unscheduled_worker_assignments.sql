CREATE OR REPLACE FUNCTION public.srk_find_eligible_workers(p_booking_id uuid, p_worker_type text)
RETURNS TABLE(worker_id uuid, worker_code text, worker_type text, distance_km numeric)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'public'
AS $function$
declare
  v_booking public.service_bookings%rowtype;
  v_search_radius numeric;
  v_attempts integer;
  v_initial_radius numeric;
  v_expansion_step numeric;
  v_max_radius numeric;
begin
  if p_worker_type not in ('technician','helper') then
    raise exception 'Invalid worker type';
  end if;
  select * into v_booking from public.service_bookings where id=p_booking_id;
  if not found then raise exception 'Booking not found'; end if;

  select coalesce(q.attempts,0) into v_attempts
  from public.srk_booking_matching_queue q where q.booking_id=p_booking_id;

  select
    coalesce((v_booking.operational_settings_snapshot->>'initial_matching_radius_km')::numeric,
      (select (setting_value #>> '{}')::numeric from public.srk_system_settings where setting_key='initial_matching_radius_km'),30),
    coalesce((v_booking.operational_settings_snapshot->>'matching_radius_expansion_step_km')::numeric,
      (select (setting_value #>> '{}')::numeric from public.srk_system_settings where setting_key='matching_radius_expansion_step_km'),30),
    coalesce((v_booking.operational_settings_snapshot->>'maximum_matching_radius_km')::numeric,
      (select (setting_value #>> '{}')::numeric from public.srk_system_settings where setting_key='maximum_matching_radius_km'),200)
  into v_initial_radius,v_expansion_step,v_max_radius;

  v_search_radius:=least(v_max_radius,v_initial_radius+coalesce(v_attempts,0)*v_expansion_step);

  return query
  select w.id,w.worker_code,w.worker_type,
    case when v_booking.booking_latitude is null then null::numeric else
      round((6371*acos(least(1,greatest(-1,
        cos(radians(v_booking.booking_latitude))*cos(radians(w.location_lat))*cos(radians(w.location_lng)-radians(v_booking.booking_longitude))+
        sin(radians(v_booking.booking_latitude))*sin(radians(w.location_lat))
      ))))::numeric,2)
    end
  from public.srk_worker_profiles w
  where w.worker_type=p_worker_type
    and w.category_id=v_booking.category_id
    and w.verification_status='approved' and w.is_active and w.is_online
    and (v_booking.booking_latitude is null or (w.location_lat is not null and w.location_lng is not null))
    and exists(
      select 1 from public.srk_worker_skills ws
      where ws.worker_id=w.id and ws.skill_id=v_booking.selected_skill_id
        and ws.verification_status='approved'
        and (coalesce(v_booking.higher_skill_consent_level_id,v_booking.requested_skill_level_id) is null
          or ws.skill_level_id=coalesce(v_booking.higher_skill_consent_level_id,v_booking.requested_skill_level_id))
    )
    and (
      (v_booking.booking_latitude is not null and
        (6371*acos(least(1,greatest(-1,
          cos(radians(v_booking.booking_latitude))*cos(radians(w.location_lat))*cos(radians(w.location_lng)-radians(v_booking.booking_longitude))+
          sin(radians(v_booking.booking_latitude))*sin(radians(w.location_lat))
        ))))<=least(v_search_radius,w.service_radius_km))
      or (v_booking.booking_latitude is null and
        (w.pincode=v_booking.pincode or
          (lower(trim(w.state))=lower(trim(v_booking.state)) and lower(trim(w.district))=lower(trim(v_booking.district)))))
    )
    and not exists(
      select 1 from public.srk_worker_work_sessions s
      where s.worker_id=w.id and s.session_status in ('running','paused')
    )
    and not exists(
      select 1 from public.srk_booking_workers bw
      where bw.worker_id=w.id and bw.assignment_status in ('working','paused')
    )
    -- Do not send new offers to a worker who has an accepted assignment
    -- that has not yet been given a customer-confirmed schedule.
    and not exists(
      select 1 from public.srk_booking_workers bw
      where bw.worker_id=w.id
        and bw.assignment_status in ('accepted','assigned')
        and not exists(
          select 1 from public.srk_worker_schedule_blocks sb
          where sb.booking_worker_id=bw.id
            and sb.block_status in ('reserved','confirmed','in_progress')
        )
    )
    and not exists(
      select 1 from public.srk_worker_schedule_blocks sb
      where sb.worker_id=w.id and sb.block_status in ('reserved','confirmed','in_progress')
        and sb.starts_at<=clock_timestamp()+make_interval(hours=>coalesce(v_booking.requested_duration_hours,1))
        and sb.ends_at>clock_timestamp()
    )
  order by
    case when v_booking.booking_latitude is null and w.pincode=v_booking.pincode then 0 else 1 end,
    4 nulls last,w.created_at;
end
$function$;

CREATE OR REPLACE FUNCTION public.srk_worker_respond_assignment(p_assignment_id uuid, p_accept boolean)
RETURNS public.srk_booking_workers
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'public', 'auth'
AS $function$
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

  if p_accept and v_assignment.offer_expires_at is not null
     and v_assignment.offer_expires_at<=clock_timestamp() then
    raise exception 'Offer has expired; wait for the next eligible assignment';
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

    -- An accepted assignment without a confirmed schedule is treated as
    -- occupying the worker's next available slot. This prevents two immediate
    -- bookings from being accepted before either has a schedule reservation.
    if exists(
      select 1 from public.srk_booking_workers bw
      where bw.worker_id=v_worker.id
        and bw.id<>v_assignment.id
        and bw.assignment_status in ('accepted','assigned')
        and not exists(
          select 1 from public.srk_worker_schedule_blocks sb
          where sb.booking_worker_id=bw.id
            and sb.block_status in ('reserved','confirmed','in_progress')
        )
    ) then
      raise exception 'Another accepted booking still needs a customer-confirmed schedule';
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