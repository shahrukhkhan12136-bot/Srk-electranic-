
do $migration$
declare v_def text;
begin
 select pg_get_functiondef('public.srk_worker_respond_assignment(uuid,boolean)'::regprocedure) into v_def;
 if position('if p_accept and v_assignment.worker_role=''technician'' then' in v_def)=0 then
  v_def:=replace(v_def,
   ' update public.srk_booking_workers'||chr(10)||
   ' set assignment_status=case when p_accept then ''accepted'' else ''rejected'' end,',
   ' update public.srk_booking_workers'||chr(10)||
   ' set assignment_status=case when p_accept then ''accepted'' else ''rejected'' end,');
  v_def:=replace(v_def,
   ' -- Queue processor alone confirms a booking after all requested technicians AND helpers accept.'||chr(10)||
   ' update public.srk_booking_matching_queue',
   ' -- First accepted Technician confirms the Booking immediately; later worker acceptances remain independent.'||chr(10)||
   ' if p_accept and v_assignment.worker_role=''technician'' then'||chr(10)||
   '  update public.service_bookings set status=''confirmed'' where id=v_assignment.booking_id and status=''new'';'||chr(10)||
   ' end if;'||chr(10)||
   ' update public.srk_booking_matching_queue');
  v_def:=replace(v_def,
   '  update public.srk_booking_matching_queue'||chr(10)||
   ' set queue_status=''pending'',next_attempt_at=clock_timestamp(),updated_at=clock_timestamp()',
   '  update public.srk_booking_matching_queue'||chr(10)||
   ' set queue_status=''pending'',next_attempt_at=clock_timestamp(),updated_at=clock_timestamp()');
  if position('First accepted Technician confirms the Booking immediately' in v_def)=0 then
   raise exception 'Could not safely patch worker acceptance function';
  end if;
  execute v_def;
 end if;

 select pg_get_functiondef('public.srk_process_booking_matching_queue()'::regprocedure) into v_def;
 if position('A confirmed booking may continue accepting additional requested workers' in v_def)=0 then
  v_def:=replace(v_def,
   '  if v_tech_count>=v_booking.requested_technician_count and v_helper_count>=v_booking.requested_helper_count then',
   '  -- A confirmed booking may continue accepting additional requested workers until its requested counts are filled.'||chr(10)||
   '  if v_tech_count>=1 then'||chr(10)||
   '   update public.service_bookings set status=''confirmed'' where id=v_booking.id and status=''new'';'||chr(10)||
   '  end if;'||chr(10)||
   '  if v_tech_count>=v_booking.requested_technician_count and v_helper_count>=v_booking.requested_helper_count then');
  if position('A confirmed booking may continue accepting additional requested workers' in v_def)=0 then
   raise exception 'Could not safely patch matching queue function';
  end if;
  execute v_def;
 end if;
end
$migration$;
