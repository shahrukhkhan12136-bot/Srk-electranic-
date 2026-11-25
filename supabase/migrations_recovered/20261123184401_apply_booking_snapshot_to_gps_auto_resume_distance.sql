
do $migration$
declare v_def text; v_old text; v_new text;
begin
 v_def:=pg_get_functiondef('public.srk_worker_record_session_location(uuid,double precision,double precision,numeric)'::regprocedure);
 v_old:='  v_distance_m numeric;
  v_auto_resumed boolean:=false;';
 v_new:='  v_distance_m numeric;
  v_auto_resume_distance numeric;
  v_booking public.service_bookings%rowtype;
  v_auto_resumed boolean:=false;';
 if position(v_old in v_def)=0 then raise exception 'GPS resume declarations not found'; end if;
 v_def:=replace(v_def,v_old,v_new);

 v_old:='  if not found then raise exception ''Work session not found for this worker'' using errcode=''42501''; end if;

  update public.srk_worker_work_sessions';
 v_new:='  if not found then raise exception ''Work session not found for this worker'' using errcode=''42501''; end if;
  select b.* into v_booking from public.service_bookings b
  join public.srk_booking_workers bw on bw.booking_id=b.id
  where bw.id=v_session.booking_worker_id;
  v_auto_resume_distance:=coalesce((v_booking.operational_settings_snapshot->>''pause_auto_resume_distance_meters'')::numeric,
    (select (setting_value #>> ''{}'')::numeric from public.srk_system_settings where setting_key=''pause_auto_resume_distance_meters''),100);

  update public.srk_worker_work_sessions';
 if position(v_old in v_def)=0 then raise exception 'GPS resume booking snapshot point not found'; end if;
 v_def:=replace(v_def,v_old,v_new);

 v_old:='if v_distance_m<=100 then';
 v_new:='if v_distance_m<=v_auto_resume_distance then';
 if position(v_old in v_def)=0 then raise exception 'GPS auto resume fixed distance not found'; end if;
 v_def:=replace(v_def,v_old,v_new);
 execute v_def;
end
$migration$;
