CREATE OR REPLACE FUNCTION public.srk_worker_record_session_location(
 p_session_id uuid,p_latitude double precision,p_longitude double precision,
 p_accuracy_m numeric DEFAULT NULL::numeric
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'pg_catalog','public','auth'
AS $function$
declare
 v_session public.srk_worker_work_sessions%rowtype;
 v_assignment public.srk_booking_workers%rowtype;
 v_booking_worker_id uuid;
 v_worker_user_id uuid;
 v_distance_m numeric;
 v_auto_resume_distance numeric;
 v_booking public.service_bookings%rowtype;
 v_auto_resumed boolean:=false;
 v_auto_paused boolean:=false;
 v_now timestamptz:=clock_timestamp();
 v_elapsed bigint;
 v_pause_reason text;
begin
 if auth.uid() is null then raise exception 'Authentication required' using errcode='42501'; end if;
 if p_session_id is null or p_latitude is null or p_longitude is null
  or p_latitude not between -90 and 90 or p_longitude not between -180 and 180
  or (p_accuracy_m is not null and p_accuracy_m<0) then
  raise exception 'Valid GPS coordinates are required' using errcode='22023';
 end if;
 select booking_worker_id into v_booking_worker_id
 from public.srk_worker_work_sessions where id=p_session_id;
 if not found then raise exception 'Work session not found' using errcode='42501'; end if;
 select * into v_assignment from public.srk_booking_workers
 where id=v_booking_worker_id for update;
 if not found then raise exception 'Booking assignment not found' using errcode='42501'; end if;
 select user_id into v_worker_user_id from public.srk_worker_profiles
 where id=v_assignment.worker_id;
 if v_worker_user_id is distinct from auth.uid() then
  raise exception 'Work session not found for this worker' using errcode='42501';
 end if;
 select * into v_session from public.srk_worker_work_sessions
 where id=p_session_id and booking_worker_id=v_assignment.id for update;
 if not found then raise exception 'Work session not found' using errcode='42501'; end if;
 if v_session.session_status in ('completed','cancelled') then
  raise exception 'GPS updates are not accepted for a closed work session';
 end if;

 select * into v_booking from public.service_bookings where id=v_assignment.booking_id;
 v_auto_resume_distance:=coalesce(
  (v_booking.operational_settings_snapshot->>'pause_auto_resume_distance_meters')::numeric,
  (select (setting_value #>> '{}')::numeric from public.srk_system_settings where setting_key='pause_auto_resume_distance_meters'),100);

 update public.srk_worker_work_sessions
 set last_gps_latitude=p_latitude,last_gps_longitude=p_longitude,last_gps_at=v_now,
     start_latitude=case when session_status='not_started' then p_latitude
                         when session_status='running' and start_latitude is null then p_latitude
                         else start_latitude end,
     start_longitude=case when session_status='not_started' then p_longitude
                          when session_status='running' and start_longitude is null then p_longitude
                          else start_longitude end,
     updated_at=v_now
 where id=p_session_id returning * into v_session;

 if v_session.start_latitude is not null and v_session.start_longitude is not null then
  v_distance_m:=6371000*2*asin(sqrt(
   power(sin(radians(p_latitude-v_session.start_latitude)/2),2)
   +cos(radians(v_session.start_latitude))*cos(radians(p_latitude))
   *power(sin(radians(p_longitude-v_session.start_longitude)/2),2)
  ));
 end if;

 if v_session.session_status='running'
    and v_session.start_latitude is not null
    and v_session.start_longitude is not null
    and v_distance_m>v_auto_resume_distance then
  v_elapsed:=greatest(0,floor(extract(epoch from(v_now-v_session.last_resumed_at)))::bigint);
  update public.srk_worker_work_sessions
  set session_status='paused',billable_seconds=least(5184000,billable_seconds+v_elapsed),
      last_resumed_at=null,pause_started_at=v_now,pause_minimum_until=v_now,
      pause_reason='gps_outside_worksite',updated_at=v_now
  where id=p_session_id returning * into v_session;
  update public.srk_booking_workers set assignment_status='paused',updated_at=v_now
  where id=v_assignment.id and assignment_status='working';
  insert into public.srk_worker_session_events(session_id,event_type,event_at,actor_user_id,pause_reason,note,source)
  values(p_session_id,'paused',v_now,auth.uid(),'gps_outside_worksite',
   'Automatically paused because GPS moved outside the configured work-site radius.','system');
  v_auto_paused:=true;

 elsif v_session.session_status='paused'
    and v_session.pause_reason in ('gps_outside_worksite','lunch','market_other')
    and v_session.pause_minimum_until is not null
    and v_now>=v_session.pause_minimum_until
    and v_session.start_latitude is not null
    and v_session.start_longitude is not null
    and v_distance_m<=v_auto_resume_distance then
  v_pause_reason:=v_session.pause_reason;
  update public.srk_worker_work_sessions
  set session_status='running',last_resumed_at=v_now,pause_reason=null,
      pause_started_at=null,pause_minimum_until=null,updated_at=v_now
  where id=p_session_id returning * into v_session;
  update public.srk_booking_workers set assignment_status='working',updated_at=v_now
  where id=v_assignment.id and assignment_status='paused';
  insert into public.srk_worker_session_events(session_id,event_type,event_at,actor_user_id,pause_reason,note,source)
  values(p_session_id,'resumed',v_now,auth.uid(),v_pause_reason,
   'Automatically resumed after the minimum pause duration and return within the configured work-site radius.','system');
  v_auto_resumed:=true;
 end if;

 return jsonb_build_object('success',true,'auto_paused',v_auto_paused,'auto_resumed',v_auto_resumed,
  'distance_from_start_m',v_distance_m,'worksite_radius_m',v_auto_resume_distance);
end
$function$;