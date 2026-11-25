
alter table public.srk_worker_work_sessions
  add column if not exists start_latitude double precision,
  add column if not exists start_longitude double precision,
  add column if not exists last_gps_latitude double precision,
  add column if not exists last_gps_longitude double precision,
  add column if not exists pause_started_at timestamptz,
  add column if not exists pause_minimum_until timestamptz;
alter table public.srk_worker_work_sessions
  drop constraint if exists srk_worker_sessions_start_gps_pair_check;
alter table public.srk_worker_work_sessions
  add constraint srk_worker_sessions_start_gps_pair_check
  check ((start_latitude is null)=(start_longitude is null));
alter table public.srk_worker_work_sessions
  drop constraint if exists srk_worker_sessions_last_gps_pair_check;
alter table public.srk_worker_work_sessions
  add constraint srk_worker_sessions_last_gps_pair_check
  check ((last_gps_latitude is null)=(last_gps_longitude is null));

do $migration$
declare
  v_def text;
  v_old text;
  v_new text;
begin
  v_def:=pg_get_functiondef('public.srk_worker_session_action(uuid,text,text,text,text)'::regprocedure);

  v_old:='if p_pause_reason not in (''food_break'',''material'',''customer_permission'',''technical_problem'',''other'') then raise exception ''Valid pause reason required''; end if;';
  v_new:='if p_pause_reason not in (''lunch'',''market_other'') then raise exception ''Pause must be Lunch or Market/Other Task''; end if;';
  if position(v_old in v_def)=0 then raise exception 'Pause reason validation not found'; end if;
  v_def:=replace(v_def,v_old,v_new);

  v_old:='update public.srk_worker_work_sessions set session_status=''running'',started_at=v_now,last_resumed_at=v_now,updated_at=v_now';
  v_new:='update public.srk_worker_work_sessions set session_status=''running'',started_at=v_now,last_resumed_at=v_now,updated_at=v_now,start_latitude=(select location_lat from public.srk_worker_profiles where id=v_session.worker_id),start_longitude=(select location_lng from public.srk_worker_profiles where id=v_session.worker_id),last_gps_latitude=(select location_lat from public.srk_worker_profiles where id=v_session.worker_id),last_gps_longitude=(select location_lng from public.srk_worker_profiles where id=v_session.worker_id)';
  if position(v_old in v_def)=0 then raise exception 'Session start update not found'; end if;
  v_def:=replace(v_def,v_old,v_new);

  v_old:='update public.srk_worker_work_sessions set session_status=''paused'',billable_seconds=least(5184000,billable_seconds+v_elapsed),';
  v_new:='update public.srk_worker_work_sessions set session_status=''paused'',pause_started_at=v_now,pause_minimum_until=v_now+case when p_pause_reason=''lunch'' then interval ''1 hour'' else interval ''2 hours'' end,billable_seconds=least(5184000,billable_seconds+v_elapsed),';
  if position(v_old in v_def)=0 then raise exception 'Session pause update not found'; end if;
  v_def:=replace(v_def,v_old,v_new);

  v_old:='if v_session.session_status<>''paused'' then raise exception ''Only a paused session can be resumed''; end if;';
  v_new:='if v_session.session_status<>''paused'' then raise exception ''Only a paused session can be resumed''; end if; if v_session.pause_minimum_until is not null and v_now<v_session.pause_minimum_until then raise exception ''Minimum pause duration has not elapsed''; end if;';
  if position(v_old in v_def)=0 then raise exception 'Session resume validation not found'; end if;
  v_def:=replace(v_def,v_old,v_new);

  v_old:='set session_status=''running'',last_resumed_at=v_now,pause_reason=null,updated_at=v_now';
  v_new:='set session_status=''running'',last_resumed_at=v_now,pause_reason=null,pause_started_at=null,pause_minimum_until=null,updated_at=v_now';
  if position(v_old in v_def)=0 then raise exception 'Session resume update not found'; end if;
  v_def:=replace(v_def,v_old,v_new);

  execute v_def;
end
$migration$;

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
  if p_session_id is null or p_latitude not between -90 and 90 or p_longitude not between -180 and 180
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
revoke all on function public.srk_worker_record_session_location(uuid,double precision,double precision,numeric) from public,anon;
grant execute on function public.srk_worker_record_session_location(uuid,double precision,double precision,numeric) to authenticated;
