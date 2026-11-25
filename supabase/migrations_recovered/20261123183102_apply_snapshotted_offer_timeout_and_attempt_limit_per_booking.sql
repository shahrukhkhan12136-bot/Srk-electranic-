
do $migration$
declare v_def text; v_old text; v_new text;
begin
 v_def:=pg_get_functiondef('public.srk_process_booking_matching_queue()'::regprocedure);
 v_old:='  if not found or v_booking.status=''cancelled'' then';
 v_new:='  if found then
   v_timeout:=coalesce((v_booking.operational_settings_snapshot->>''offer_timeout_seconds'')::integer,v_timeout);
   v_max_attempts:=coalesce((v_booking.operational_settings_snapshot->>''max_matching_attempts'')::integer,v_max_attempts);
  end if;
  if not found or v_booking.status=''cancelled'' then';
 if position(v_old in v_def)=0 then raise exception 'Matching per-booking settings insertion point not found'; end if;
 v_def:=replace(v_def,v_old,v_new);

 v_old:='next_attempt_at=clock_timestamp()+interval ''10 minutes''';
 v_new:='next_attempt_at=clock_timestamp()+make_interval(secs=>coalesce(v_timeout,600))';
 if position(v_old in v_def)=0 then raise exception 'Matching group timeout not found'; end if;
 v_def:=replace(v_def,v_old,v_new);
 execute v_def;
end
$migration$;
