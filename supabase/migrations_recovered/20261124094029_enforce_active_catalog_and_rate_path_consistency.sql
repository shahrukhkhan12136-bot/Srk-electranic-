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
 if length(btrim(coalesce(p_reason,'')))<10 then raise exception 'Rate change reason must be at least 10 characters'; end if;
 if p_technician_hourly_rate is null or p_technician_hourly_rate<0
    or p_helper_hourly_rate is null or p_helper_hourly_rate<0 then
  raise exception 'Both hourly rates must be non-negative';
 end if;
 if not exists(select 1 from public.srk_service_categories c where c.id=p_category_id and c.is_active) then
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
 if exists(select 1 from public.srk_service_pricing_rules r
  where r.category_id=p_category_id and r.service_type_id is not distinct from p_service_type_id
   and r.effective_from<=v_changed_at and (r.effective_to is null or r.effective_to>v_changed_at)) then
  raise exception 'This catalog item uses versioned pricing rules; use the versioned pricing manager';
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

CREATE OR REPLACE FUNCTION public.srk_admin_version_service_pricing_rule(
 p_pricing_rule_id uuid,p_pricing_unit text,p_technician_rate numeric,p_helper_rate numeric,
 p_base_hp numeric,p_base_hp_price numeric,p_hp_step_amount numeric,p_timer_enabled boolean,
 p_materials_charged_separately boolean,p_winding_charged_separately boolean,
 p_pricing_note text,p_hp_tiers jsonb,p_change_reason text
) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'pg_catalog','public','auth'
AS $function$
declare
 v_old public.srk_service_pricing_rules%rowtype;
 v_new_id uuid;
 v_now timestamptz:=clock_timestamp();
 v_tier_count integer:=0;
 v_bad_count integer:=0;
begin
 if auth.uid() is null then raise exception 'Authentication required'; end if;
 if not public.srk_has_admin_permission('catalog.manage') then
  raise exception 'Permission denied: catalog.manage required';
 end if;
 if p_pricing_rule_id is null then raise exception 'Pricing rule ID is required'; end if;
 if p_pricing_unit not in ('hour','per_item','motor_hp') then raise exception 'Invalid pricing unit'; end if;
 if p_timer_enabled is null or p_materials_charged_separately is null or p_winding_charged_separately is null then
  raise exception 'Pricing flags are required';
 end if;
 if p_materials_charged_separately is true then
  raise exception 'Material billing is disabled by the approved SRK ELECTRONIC policy';
 end if;
 if p_helper_rate is not null and p_helper_rate<0 then
  raise exception 'Helper rate cannot be negative';
 end if;
 if p_change_reason is null or length(btrim(p_change_reason))<10 then
  raise exception 'Change reason must contain at least 10 non-space characters';
 end if;
 if p_hp_tiers is null or jsonb_typeof(p_hp_tiers)<>'array' then
  raise exception 'HP tiers must be supplied as a JSON array (use [] when not applicable)';
 end if;
 if p_pricing_unit='hour' then
  if p_technician_rate is null or p_technician_rate<=0 or p_timer_enabled is not true
     or p_base_hp is not null or p_base_hp_price is not null or p_hp_step_amount is not null
     or jsonb_array_length(p_hp_tiers)<>0 then
   raise exception 'Hourly pricing requires positive technician rate, timer enabled, and no HP fields/tiers';
  end if;
 elsif p_pricing_unit='per_item' then
  if p_technician_rate is null or p_technician_rate<=0 or p_timer_enabled is not false
     or p_base_hp is not null or p_base_hp_price is not null or p_hp_step_amount is not null
     or jsonb_array_length(p_hp_tiers)<>0 then
   raise exception 'Per-item pricing requires positive item rate, timer disabled, and no HP fields/tiers';
  end if;
 else
  if p_timer_enabled is not false or p_base_hp is null or p_base_hp<0.5
     or p_base_hp_price is null or p_base_hp_price<=0 or p_hp_step_amount is null or p_hp_step_amount<=0
     or p_technician_rate is not null or p_helper_rate is not null
     or jsonb_array_length(p_hp_tiers)=0 then
   raise exception 'Motor HP pricing requires timer disabled, positive HP base values and HP tiers';
  end if;
  if exists(select 1 from jsonb_to_recordset(p_hp_tiers) as x(motor_hp numeric,fixed_price numeric)
   where motor_hp is null or motor_hp<0.5 or fixed_price is null or fixed_price<=0) then
   raise exception 'Every HP tier requires motor_hp >= 0.5 and positive fixed_price';
  end if;
  select count(*) into v_tier_count from jsonb_to_recordset(p_hp_tiers) as x(motor_hp numeric,fixed_price numeric);
  select count(*) into v_bad_count from (
   select x.motor_hp from jsonb_to_recordset(p_hp_tiers) as x(motor_hp numeric,fixed_price numeric)
   group by x.motor_hp having count(*)>1
  ) d;
  if v_tier_count=0 or v_bad_count>0 then raise exception 'HP tiers must be non-empty and have unique HP values'; end if;
 end if;

 perform pg_advisory_xact_lock(hashtextextended(p_pricing_rule_id::text,0));
 select * into v_old from public.srk_service_pricing_rules
 where id=p_pricing_rule_id for update;
 if not found then raise exception 'Pricing rule not found'; end if;
 if v_old.effective_to is not null then raise exception 'Only the current pricing rule version can be changed'; end if;
 if v_now<=v_old.effective_from then raise exception 'Pricing rule effective time conflict'; end if;
 if not exists(select 1 from public.srk_service_categories c where c.id=v_old.category_id and c.is_active)
  or not exists(select 1 from public.srk_service_types s
   where s.id=v_old.service_type_id and s.category_id=v_old.category_id and s.is_active) then
  raise exception 'Only active catalog items can receive a new pricing version';
 end if;

 update public.srk_service_pricing_rules set effective_to=v_now
 where id=v_old.id and effective_to is null;
 insert into public.srk_service_pricing_rules(
  category_id,service_type_id,pricing_unit,technician_rate,helper_rate,
  base_hp,base_hp_price,hp_step_amount,timer_enabled,
  materials_charged_separately,winding_charged_separately,pricing_note,
  effective_from,effective_to,created_by,change_reason
 ) values(
  v_old.category_id,v_old.service_type_id,p_pricing_unit,p_technician_rate,p_helper_rate,
  p_base_hp,p_base_hp_price,p_hp_step_amount,p_timer_enabled,
  false,p_winding_charged_separately,nullif(btrim(p_pricing_note),''),
  v_now,null,auth.uid(),btrim(p_change_reason)
 ) returning id into v_new_id;
 if p_pricing_unit='motor_hp' then
  insert into public.srk_service_pricing_hp_tiers(pricing_rule_id,motor_hp,fixed_price,created_by)
  select v_new_id,x.motor_hp,x.fixed_price,auth.uid()
  from jsonb_to_recordset(p_hp_tiers) as x(motor_hp numeric,fixed_price numeric);
 end if;
 return v_new_id;
end
$function$;