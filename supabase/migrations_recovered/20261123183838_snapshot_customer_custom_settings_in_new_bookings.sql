
alter table public.service_bookings
 add column if not exists user_custom_settings_snapshot jsonb not null default '{}'::jsonb;
alter table public.srk_booking_workers
 add column if not exists worker_custom_settings_snapshot jsonb not null default '{}'::jsonb;

do $migration$
declare v_def text; v_old text; v_new text;
begin
 v_def:=pg_get_functiondef('public.srk_customer_create_booking(uuid,uuid,uuid,integer,integer,integer,text,text,text,text,double precision,double precision,double precision,double precision,numeric,uuid)'::regprocedure);
 v_old:=' v_pending_fee_amount numeric(12,2):=0;';
 v_new:=' v_pending_fee_amount numeric(12,2):=0;
 v_user_settings_snapshot jsonb:=''{}''::jsonb;';
 if position(v_old in v_def)=0 then raise exception 'User settings variable point not found'; end if;
 v_def:=replace(v_def,v_old,v_new);

 v_old:='pause_auto_resume_distance_meters'');
 if p_technician_count is null';
 v_new:='pause_auto_resume_distance_meters'');
 select coalesce(jsonb_object_agg(setting_key,setting_value),''{}''::jsonb)
 into v_user_settings_snapshot
 from public.srk_user_custom_settings
 where user_id=auth.uid() and account_role=''customer'';
 if p_technician_count is null';
 if position(v_old in v_def)=0 then raise exception 'User settings snapshot query point not found'; end if;
 v_def:=replace(v_def,v_old,v_new);

 v_old:='pricing_unit_snapshot,pricing_quantity,pricing_rule_id,motor_hp,operational_settings_snapshot
 ) values(';
 v_new:='pricing_unit_snapshot,pricing_quantity,pricing_rule_id,motor_hp,operational_settings_snapshot,user_custom_settings_snapshot
 ) values(';
 if position(v_old in v_def)=0 then raise exception 'User settings snapshot columns not found'; end if;
 v_def:=replace(v_def,v_old,v_new);

 v_old:='case when v_rule.id is not null then v_rule.id else null end,p_motor_hp,v_settings_snapshot
 ) returning * into v_booking;';
 v_new:='case when v_rule.id is not null then v_rule.id else null end,p_motor_hp,v_settings_snapshot,v_user_settings_snapshot
 ) returning * into v_booking;';
 if position(v_old in v_def)=0 then raise exception 'User settings snapshot values not found'; end if;
 v_def:=replace(v_def,v_old,v_new);
 execute v_def;
end
$migration$;
