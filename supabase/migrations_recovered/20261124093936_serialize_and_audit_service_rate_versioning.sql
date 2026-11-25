CREATE OR REPLACE FUNCTION public.srk_admin_publish_service_rate(
 p_category_id uuid,p_service_type_id uuid,p_skill_level_id uuid,
 p_technician_hourly_rate numeric,p_helper_hourly_rate numeric,p_reason text
) RETURNS public.srk_service_rates
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'pg_catalog','public','auth'
AS $function$
declare
 v_rate public.srk_service_rates%rowtype;
 v_changed_at timestamptz:=clock_timestamp();
begin
 if auth.uid() is null or not public.srk_has_admin_permission('catalog.manage') then
  raise exception 'Catalog management permission required';
 end if;
 if length(btrim(coalesce(p_reason,'')))<10 then
  raise exception 'Rate change reason must be at least 10 characters';
 end if;
 if p_technician_hourly_rate is null or p_technician_hourly_rate<0
    or p_helper_hourly_rate is null or p_helper_hourly_rate<0 then
  raise exception 'Both hourly rates must be non-negative';
 end if;
 if not exists(select 1 from public.srk_service_categories c
  where c.id=p_category_id and c.is_active) then
  raise exception 'Active service category is required';
 end if;
 if not exists(select 1 from public.srk_skill_levels l
  where l.id=p_skill_level_id and l.category_id=p_category_id and l.is_active) then
  raise exception 'Active skill level/category mismatch';
 end if;
 if p_service_type_id is not null and not exists(
  select 1 from public.srk_service_types s
  where s.id=p_service_type_id and s.category_id=p_category_id and s.is_active
 ) then
  raise exception 'Active service type/category mismatch';
 end if;

 perform pg_advisory_xact_lock(hashtextextended(
  p_category_id::text||':'||coalesce(p_service_type_id::text,'<NULL>')||':'||p_skill_level_id::text,0));

 update public.srk_service_rates
 set effective_to=v_changed_at,rate_status='retired',
     change_reason=concat_ws('; ',nullif(change_reason,''),'Superseded: '||btrim(p_reason))
 where category_id=p_category_id and service_type_id is not distinct from p_service_type_id
  and skill_level_id=p_skill_level_id and rate_status='approved' and effective_to is null;

 insert into public.srk_service_rates(
  category_id,service_type_id,skill_level_id,technician_hourly_rate,helper_hourly_rate,
  rate_status,effective_from,created_by,change_reason
 ) values(
  p_category_id,p_service_type_id,p_skill_level_id,p_technician_hourly_rate,p_helper_hourly_rate,
  'approved',v_changed_at,auth.uid(),btrim(p_reason)
 ) returning * into v_rate;
 return v_rate;
end
$function$;

CREATE OR REPLACE FUNCTION public.srk_admin_update_service_rate(
 p_rate_id uuid,p_technician_hourly_rate numeric,p_helper_hourly_rate numeric,p_change_reason text
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'pg_catalog','public','auth'
AS $function$
declare
 v_old public.srk_service_rates%rowtype;
 v_new_id uuid;
 v_changed_at timestamptz:=clock_timestamp();
begin
 if auth.uid() is null or not public.srk_has_admin_permission('catalog.manage') then
  raise exception 'Catalog management permission required';
 end if;
 if p_rate_id is null then raise exception 'Rate ID is required'; end if;
 if p_technician_hourly_rate is null or p_technician_hourly_rate<=0 then
  raise exception 'Technician hourly rate must be positive';
 end if;
 if p_helper_hourly_rate is not null and p_helper_hourly_rate<=0 then
  raise exception 'Helper hourly rate must be positive when supplied';
 end if;
 if length(btrim(coalesce(p_change_reason,'')))<10 then
  raise exception 'Rate change reason must be at least 10 characters';
 end if;

 select * into v_old from public.srk_service_rates where id=p_rate_id;
 if not found then raise exception 'Rate not found'; end if;
 perform pg_advisory_xact_lock(hashtextextended(
  v_old.category_id::text||':'||coalesce(v_old.service_type_id::text,'<NULL>')||':'||v_old.skill_level_id::text,0));

 select * into v_old from public.srk_service_rates
 where id=p_rate_id and effective_to is null and rate_status='approved' for update;
 if not found then
  raise exception 'Current approved legacy rate not found; drafts and retired rates cannot be changed here';
 end if;
 if not exists(select 1 from public.srk_service_categories c
  where c.id=v_old.category_id and c.is_active)
  or not exists(select 1 from public.srk_skill_levels l
   where l.id=v_old.skill_level_id and l.category_id=v_old.category_id and l.is_active)
  or (v_old.service_type_id is not null and not exists(
   select 1 from public.srk_service_types s
   where s.id=v_old.service_type_id and s.category_id=v_old.category_id and s.is_active
  )) then
  raise exception 'Only rates for active catalog items can be changed';
 end if;
 if exists(
  select 1 from public.srk_service_pricing_rules r
  where r.category_id=v_old.category_id and r.service_type_id=v_old.service_type_id
   and r.effective_from<=v_changed_at and (r.effective_to is null or r.effective_to>v_changed_at)
 ) then
  raise exception 'This service uses the versioned pricing rules. Update it through srk_admin_version_service_pricing_rule instead of the legacy hourly-rate manager';
 end if;

 update public.srk_service_rates
 set effective_to=v_changed_at,
     change_reason=concat_ws('; ',nullif(change_reason,''),'Superseded by admin rate adjustment')
 where id=v_old.id;

 insert into public.srk_service_rates(
  category_id,service_type_id,skill_level_id,technician_hourly_rate,
  helper_hourly_rate,rate_status,effective_from,created_by,change_reason
 ) values(
  v_old.category_id,v_old.service_type_id,v_old.skill_level_id,
  p_technician_hourly_rate,p_helper_hourly_rate,'approved',v_changed_at,
  auth.uid(),btrim(p_change_reason)
 ) returning id into v_new_id;

 return jsonb_build_object(
  'success',true,'previous_rate_id',v_old.id,'new_rate_id',v_new_id,
  'technician_hourly_rate',p_technician_hourly_rate,
  'helper_hourly_rate',p_helper_hourly_rate,'effective_from',v_changed_at
 );
end
$function$;

REVOKE ALL ON FUNCTION public.srk_admin_publish_service_rate(uuid,uuid,uuid,numeric,numeric)
FROM PUBLIC,anon,authenticated;