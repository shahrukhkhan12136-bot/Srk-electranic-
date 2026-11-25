
do $migration$
declare v_def text;
begin
 select pg_get_functiondef('public.srk_process_booking_matching_queue()'::regprocedure) into v_def;
 if position('Motor/Pump HP pricing is not yet enabled in matching' in v_def)=0 then
  v_def:=replace(v_def,
   '  select * into v_rule from public.srk_service_pricing_rules where id=v_booking.pricing_rule_id;'||chr(10)||'  v_offered:=false;',
   '  select * into v_rule from public.srk_service_pricing_rules where id=v_booking.pricing_rule_id;'||chr(10)||
   '  if v_booking.pricing_unit_snapshot=''motor_hp'' then'||chr(10)||
   '   update public.srk_booking_matching_queue set queue_status=''waiting'',attempts=attempts+1,'||
   'last_attempt_at=clock_timestamp(),next_attempt_at=clock_timestamp()+interval ''1 minute'','||
   'last_error=''Motor/Pump HP pricing is not yet enabled in matching'',updated_at=clock_timestamp() '||
   'where booking_id=v_booking.id;'||chr(10)||'   continue;'||chr(10)||'  end if;'||chr(10)||
   '  v_offered:=false;');
  if position('Motor/Pump HP pricing is not yet enabled in matching' in v_def)=0 then
   raise exception 'Could not safely patch matching function';
  end if;
  execute v_def;
 end if;

 select pg_get_functiondef('public.srk_admin_offer_worker_to_booking(uuid,uuid,text,text)'::regprocedure) into v_def;
 if position('Motor/Pump HP pricing is not yet enabled for Admin assignment' in v_def)=0 then
  v_def:=replace(v_def,
   ' v_rate_id:=null; v_rate:=null;'||chr(10)||' select * into v_rule from public.srk_service_pricing_rules where id=v_booking.pricing_rule_id;'||chr(10)||' if v_booking.pricing_unit_snapshot=''per_item'' then',
   ' v_rate_id:=null; v_rate:=null;'||chr(10)||
   ' select * into v_rule from public.srk_service_pricing_rules where id=v_booking.pricing_rule_id;'||chr(10)||
   ' if v_booking.pricing_unit_snapshot=''motor_hp'' then raise exception ''Motor/Pump HP pricing is not yet enabled for Admin assignment''; end if;'||chr(10)||
   ' if v_booking.pricing_unit_snapshot=''per_item'' then');
  if position('Motor/Pump HP pricing is not yet enabled for Admin assignment' in v_def)=0 then
   raise exception 'Could not safely patch Admin assignment function';
  end if;
  execute v_def;
 end if;
end
$migration$;
