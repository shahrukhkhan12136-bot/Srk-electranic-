
do $migration$
declare v_def text; v_old text; v_new text;
begin
 v_def:=pg_get_functiondef('public.srk_process_booking_matching_queue()'::regprocedure);
 v_old:='rate_id,hourly_rate_snapshot,skill_level_snapshot_id,offer_expires_at)
   values(v_booking.id,v_candidate.worker_id,v_role,''offered'',v_rate_id,
    case when v_booking.pricing_unit_snapshot in (''per_item'',''motor_hp'') then null else v_rate end,v_level,
    case when v_timeout is null then null else clock_timestamp()+make_interval(secs=>v_timeout) end);';
 v_new:='rate_id,hourly_rate_snapshot,skill_level_snapshot_id,offer_expires_at,worker_custom_settings_snapshot)
   values(v_booking.id,v_candidate.worker_id,v_role,''offered'',v_rate_id,
    case when v_booking.pricing_unit_snapshot in (''per_item'',''motor_hp'') then null else v_rate end,v_level,
    case when v_timeout is null then null else clock_timestamp()+make_interval(secs=>v_timeout) end,
    coalesce((select jsonb_object_agg(setting_key,setting_value) from public.srk_user_custom_settings
      where user_id=(select user_id from public.srk_worker_profiles where id=v_candidate.worker_id)
        and account_role=v_role),''{}''::jsonb));';
 if position(v_old in v_def)=0 then raise exception 'Matching offer insert not found'; end if;
 v_def:=replace(v_def,v_old,v_new);
 execute v_def;
end
$migration$;
