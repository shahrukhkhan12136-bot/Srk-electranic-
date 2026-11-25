
do $migration$
declare v_def text;
begin
 select pg_get_functiondef('public.srk_process_booking_matching_queue()'::regprocedure) into v_def;
 v_def:=replace(v_def,
  '  if v_booking.pricing_unit_snapshot=''motor_hp'' then'||chr(10)||
  '   update public.srk_booking_matching_queue set queue_status=''waiting'',attempts=attempts+1,last_attempt_at=clock_timestamp(),next_attempt_at=clock_timestamp()+interval ''1 minute'',last_error=''Motor/Pump HP pricing is not yet enabled in matching'',updated_at=clock_timestamp() where booking_id=v_booking.id;'||chr(10)||
  '   continue;'||chr(10)||'  end if;'||chr(10),'');
 v_def:=replace(v_def,
  '   if v_booking.pricing_unit_snapshot=''per_item'' then',
  '   if v_booking.pricing_unit_snapshot=''motor_hp'' then'||chr(10)||
  '    if v_rule.id is null or v_rule.pricing_unit<>''motor_hp'' or not exists(select 1 from public.srk_service_pricing_hp_tiers t where t.pricing_rule_id=v_rule.id and t.motor_hp=v_booking.motor_hp) then continue; end if;'||chr(10)||
  '    v_rate:=null;'||chr(10)||
  '   elsif v_booking.pricing_unit_snapshot=''per_item'' then');
 v_def:=replace(v_def,
  'case when v_booking.pricing_unit_snapshot=''per_item'' then null else v_rate end',
  'case when v_booking.pricing_unit_snapshot in (''per_item'',''motor_hp'') then null else v_rate end');
 if position('srk_service_pricing_hp_tiers' in v_def)=0 then raise exception 'HP matching patch failed'; end if;
 execute v_def;

 select pg_get_functiondef('public.srk_admin_offer_worker_to_booking(uuid,uuid,text,text)'::regprocedure) into v_def;
 v_def:=replace(v_def,
  ' if v_booking.pricing_unit_snapshot=''motor_hp'' then raise exception ''Motor/Pump HP pricing is not yet enabled for Admin assignment''; end if;'||chr(10),'');
 v_def:=replace(v_def,
  ' if v_booking.pricing_unit_snapshot=''per_item'' then',
  ' if v_booking.pricing_unit_snapshot=''motor_hp'' then'||chr(10)||
  '  if v_rule.id is null or v_rule.pricing_unit<>''motor_hp'' or not exists(select 1 from public.srk_service_pricing_hp_tiers t where t.pricing_rule_id=v_rule.id and t.motor_hp=v_booking.motor_hp) then raise exception ''Approved Motor/Pump HP price missing''; end if;'||chr(10)||
  '  v_rate:=null;'||chr(10)||
  ' elsif v_booking.pricing_unit_snapshot=''per_item'' then');
 v_def:=replace(v_def,
  'case when v_booking.pricing_unit_snapshot=''per_item'' then null else v_rate end',
  'case when v_booking.pricing_unit_snapshot in (''per_item'',''motor_hp'') then null else v_rate end');
 if position('Approved Motor/Pump HP price missing' in v_def)=0 then raise exception 'Admin HP assignment patch failed'; end if;
 execute v_def;
end
$migration$;
