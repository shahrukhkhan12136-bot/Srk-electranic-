
alter table public.srk_worker_work_sessions
  drop constraint if exists srk_worker_work_sessions_pause_reason_check;
alter table public.srk_worker_work_sessions
  add constraint srk_worker_work_sessions_pause_reason_check
  check (pause_reason is null or pause_reason in
    ('food_break','material','customer_permission','technical_problem','other','lunch','market_other'));
create or replace function public.srk_worker_record_session_location(
  p_session_id uuid,p_latitude double precision,p_longitude double precision,p_accuracy_m numeric default null
)
returns jsonb
language plpgsql
security definer
set search_path to 'pg_catalog','public','auth'
as $function$
declare
  v_session public.srk_worker_work_sessions%rowtype;
  v_distance_m numeric;
  v_auto_resumed boolean:=false;
begin
  if auth.uid() is null then raise exception 'Authentication required' using errcode='42501'; end if;
  if p_session_id is null or p_latitude is null or p_longitude is null
     or p_latitude not between -90 and 90 or p_longitude not between -180 and 180
     or (p_accuracy_m is not null and p_accuracy_m<0) then
    raise exception 'Valid GPS coordinates are required' using errcode='22023';
  end if;
  select s.* into v_session
  from public.srk_worker_work_sessions s
  join public.srk_booking_workers bw on bw.id=s.booking_worker_id
  join public.srk_worker_profiles wp on wp.id=bw.worker_id
  where s.id=p_session_id and wp.user_id=auth.uid()
  for update of s;
  if not found then raise exception 'Work session not found for this worker' using errcode='42501'; end if;

  update public.srk_worker_work_sessions
  set last_gps_latitude=p_latitude,last_gps_longitude=p_longitude,updated_at=clock_timestamp()
  where id=p_session_id;

  if v_session.session_status='paused'
     and v_session.pause_minimum_until is not null
     and clock_timestamp()>=v_session.pause_minimum_until
     and v_session.start_latitude is not null and v_session.start_longitude is not null then
    v_distance_m:=6371000*2*asin(sqrt(
      power(sin(radians(p_latitude-v_session.start_latitude)/2),2)
      +cos(radians(v_session.start_latitude))*cos(radians(p_latitude))
      *power(sin(radians(p_longitude-v_session.start_longitude)/2),2)
    ));
    if v_distance_m<=100 then
      perform public.srk_worker_session_action(p_session_id,'resume',null,'Automatic GPS resume after minimum pause duration',
        'gps-auto-resume:'||p_session_id::text||':'||to_char(clock_timestamp(),'YYYYMMDDHH24MI'));
      v_auto_resumed:=true;
    end if;
  end if;
  return jsonb_build_object('success',true,'auto_resumed',v_auto_resumed,'distance_from_start_m',v_distance_m);
end
$function$;
