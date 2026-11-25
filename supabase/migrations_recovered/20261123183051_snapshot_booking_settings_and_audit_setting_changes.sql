
alter table public.service_bookings
  add column if not exists operational_settings_snapshot jsonb not null default '{}'::jsonb;

create or replace function public.srk_record_system_setting_history()
returns trigger
language plpgsql
security definer
set search_path to 'pg_catalog','public','auth'
as $function$
declare v_actor uuid;
begin
 if tg_op='UPDATE' and old.setting_value is distinct from new.setting_value then
   v_actor:=coalesce(new.updated_by,auth.uid());
   if v_actor is not null then
     insert into public.srk_system_setting_history(
       setting_key,old_value,new_value,changed_by,change_reason,changed_at,applies_to_new_bookings_only
     ) values(
       new.setting_key,old.setting_value,new.setting_value,v_actor,
       coalesce(nullif(btrim(new.admin_note),''),'Reason recorded in the Admin audit log'),
       clock_timestamp(),true
     );
   end if;
 end if;
 return new;
end
$function$;
drop trigger if exists srk_system_setting_history_trigger on public.srk_system_settings;
create trigger srk_system_setting_history_trigger
after update on public.srk_system_settings
for each row execute function public.srk_record_system_setting_history();
revoke all on function public.srk_record_system_setting_history() from public,anon,authenticated;

do $migration$
declare v_def text; v_old text; v_new text;
begin
 v_def:=pg_get_functiondef('public.srk_customer_create_booking(uuid,uuid,uuid,integer,integer,integer,text,text,text,text,double precision,double precision,double precision,double precision,numeric,uuid)'::regprocedure);
 v_old:=' v_requested_level public.srk_skill_levels%rowtype;
begin';
 v_new:=' v_requested_level public.srk_skill_levels%rowtype;
 v_settings_snapshot jsonb;
begin';
 if position(v_old in v_def)=0 then raise exception 'Booking settings variable insertion point not found'; end if;
 v_def:=replace(v_def,v_old,v_new);

 v_old:=' if p_technician_count is null or p_helper_count is null';
 v_new:=' select coalesce(jsonb_object_agg(setting_key,setting_value),''{}''::jsonb) into v_settings_snapshot
 from public.srk_system_settings
 where setting_key in (''max_technicians_per_booking'',''max_helpers_per_booking'',''minimum_booking_duration_hours'',''maximum_booking_duration_hours'',
 ''normal_daily_billable_hours'',''overtime_multiplier'',''initial_matching_radius_km'',''matching_radius_expansion_step_km'',''maximum_matching_radius_km'',
 ''offer_timeout_seconds'',''max_matching_attempts'',''no_show_wait_minutes'',''cancellation_free_window_minutes'',''cancellation_technician_on_way_fee'',
 ''cancellation_technician_arrived_fee'',''lunch_pause_minimum_minutes'',''other_pause_minimum_minutes'',''pause_auto_resume_distance_meters'');
 if p_technician_count is null or p_helper_count is null';
 if position(v_old in v_def)=0 then raise exception 'Booking settings validation point not found'; end if;
 v_def:=replace(v_def,v_old,v_new);

 v_old:='pricing_unit_snapshot,pricing_quantity,pricing_rule_id,motor_hp
 ) values(';
 v_new:='pricing_unit_snapshot,pricing_quantity,pricing_rule_id,motor_hp,operational_settings_snapshot
 ) values(';
 if position(v_old in v_def)=0 then raise exception 'Booking settings snapshot insert columns not found'; end if;
 v_def:=replace(v_def,v_old,v_new);

 v_old:='case when v_rule.id is not null then v_rule.id else null end,p_motor_hp
 ) returning * into v_booking;';
 v_new:='case when v_rule.id is not null then v_rule.id else null end,p_motor_hp,v_settings_snapshot
 ) returning * into v_booking;';
 if position(v_old in v_def)=0 then raise exception 'Booking settings snapshot insert values not found'; end if;
 v_def:=replace(v_def,v_old,v_new);
 execute v_def;
end
$migration$;

create or replace function public.srk_worker_session_time_breakdown(
 p_booking_worker_id uuid,p_hourly_rate numeric
)
returns jsonb
language sql
stable
set search_path to 'pg_catalog','public'
as $function$
  with cfg as (
    select
      coalesce((b.operational_settings_snapshot->>'normal_daily_billable_hours')::numeric,
        (select (setting_value #>> '{}')::numeric from public.srk_system_settings where setting_key='normal_daily_billable_hours'),8) as normal_hours,
      coalesce((b.operational_settings_snapshot->>'overtime_multiplier')::numeric,
        (select (setting_value #>> '{}')::numeric from public.srk_system_settings where setting_key='overtime_multiplier'),1.5) as overtime_multiplier
    from public.srk_booking_workers bw
    join public.service_bookings b on b.id=bw.booking_id
    where bw.id=p_booking_worker_id
  ), daily as (
    select s.work_date,sum(s.billable_seconds)::bigint seconds
    from public.srk_worker_work_sessions s
    where s.booking_worker_id=p_booking_worker_id
    group by s.work_date
  ), totals as (
    select
      coalesce(sum(least(d.seconds,(cfg.normal_hours*3600)::bigint)),0)::bigint normal_seconds,
      coalesce(sum(greatest(d.seconds-(cfg.normal_hours*3600)::bigint,0)),0)::bigint overtime_seconds,
      cfg.overtime_multiplier
    from daily d cross join cfg
    group by cfg.overtime_multiplier
  )
  select jsonb_build_object(
    'normal_seconds',normal_seconds,'overtime_seconds',overtime_seconds,
    'overtime_multiplier',overtime_multiplier,
    'gross_amount',round((normal_seconds::numeric/3600)*p_hourly_rate
      +(overtime_seconds::numeric/3600)*p_hourly_rate*overtime_multiplier,2)
  ) from totals
$function$;
revoke execute on function public.srk_worker_session_time_breakdown(uuid,numeric) from public,anon,authenticated;

do $migration$
declare v_def text; v_old text; v_new text;
begin
 v_def:=pg_get_functiondef('public.srk_find_eligible_workers(uuid,text)'::regprocedure);
 v_old:='  select coalesce((select (setting_value #>> ''{}'')::numeric from public.srk_system_settings where setting_key=''initial_matching_radius_km''),30),
         coalesce((select (setting_value #>> ''{}'')::numeric from public.srk_system_settings where setting_key=''matching_radius_expansion_step_km''),30),
         coalesce((select (setting_value #>> ''{}'')::numeric from public.srk_system_settings where setting_key=''maximum_matching_radius_km''),200)
    into v_initial_radius,v_expansion_step,v_max_radius;';
 v_new:='  select coalesce((v_booking.operational_settings_snapshot->>''initial_matching_radius_km'')::numeric,
           (select (setting_value #>> ''{}'')::numeric from public.srk_system_settings where setting_key=''initial_matching_radius_km''),30),
         coalesce((v_booking.operational_settings_snapshot->>''matching_radius_expansion_step_km'')::numeric,
           (select (setting_value #>> ''{}'')::numeric from public.srk_system_settings where setting_key=''matching_radius_expansion_step_km''),30),
         coalesce((v_booking.operational_settings_snapshot->>''maximum_matching_radius_km'')::numeric,
           (select (setting_value #>> ''{}'')::numeric from public.srk_system_settings where setting_key=''maximum_matching_radius_km''),200)
    into v_initial_radius,v_expansion_step,v_max_radius;';
 if position(v_old in v_def)=0 then raise exception 'Matching radius settings lookup not found'; end if;
 v_def:=replace(v_def,v_old,v_new);
 execute v_def;
end
$migration$;
