
alter table public.srk_worker_profiles
  drop constraint if exists srk_worker_profiles_service_radius_km_check;
alter table public.srk_worker_profiles
  add constraint srk_worker_profiles_service_radius_km_check
  check (service_radius_km>0 and service_radius_km<=200);

insert into public.srk_system_settings(setting_key,setting_value,admin_note)
values
('initial_matching_radius_km','30'::jsonb,'Master Checklist approved initial search radius.'),
('matching_radius_expansion_step_km','30'::jsonb,'Operational expansion step; Main Admin may adjust.'),
('maximum_matching_radius_km','200'::jsonb,'Upper bound for automatic radius expansion; worker-specific radius remains respected.')
on conflict(setting_key) do nothing;

do $migration$
declare v_def text; v_old text; v_new text;
begin
 v_def:=pg_get_functiondef('public.srk_find_eligible_workers(uuid,text)'::regprocedure);
 v_old:='declare v_booking public.service_bookings%rowtype;
begin';
 v_new:='declare v_booking public.service_bookings%rowtype;
  v_search_radius numeric;
  v_attempts integer;
  v_initial_radius numeric;
  v_expansion_step numeric;
  v_max_radius numeric;
begin
  select coalesce(q.attempts,0) into v_attempts
  from public.srk_booking_matching_queue q where q.booking_id=p_booking_id;
  select coalesce((select (setting_value #>> ''{}'')::numeric from public.srk_system_settings where setting_key=''initial_matching_radius_km''),30),
         coalesce((select (setting_value #>> ''{}'')::numeric from public.srk_system_settings where setting_key=''matching_radius_expansion_step_km''),30),
         coalesce((select (setting_value #>> ''{}'')::numeric from public.srk_system_settings where setting_key=''maximum_matching_radius_km''),200)
    into v_initial_radius,v_expansion_step,v_max_radius;
  v_search_radius:=least(v_max_radius,v_initial_radius+coalesce(v_attempts,0)*v_expansion_step);';
 if position(v_old in v_def)=0 then raise exception 'Eligible worker function declaration not found'; end if;
 v_def:=replace(v_def,v_old,v_new);

 v_old:='<=least(30,w.service_radius_km)';
 v_new:='<=least(v_search_radius,w.service_radius_km)';
 if position(v_old in v_def)=0 then raise exception 'Fixed 30km radius expression not found'; end if;
 v_def:=replace(v_def,v_old,v_new);
 execute v_def;
end
$migration$;
