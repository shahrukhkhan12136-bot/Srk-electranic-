CREATE OR REPLACE FUNCTION public.srk_customer_preview_booking_price(
 p_category_id uuid,p_service_type_id uuid,p_skill_id uuid,p_skill_level_id uuid,
 p_technician_count integer,p_helper_count integer,p_duration_hours integer,
 p_motor_hp numeric DEFAULT NULL,p_unit_count integer DEFAULT 1
) RETURNS TABLE(
 pricing_unit text,qualification_level text,technician_rate numeric,helper_rate numeric,
 estimated_base_total numeric,estimated_company_commission numeric,estimated_worker_net numeric,
 overtime_may_apply boolean,materials_included boolean,price_note text
)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'pg_catalog','public','auth'
AS $function$
declare
 v_rule public.srk_service_pricing_rules%rowtype;
 v_level public.srk_skill_levels%rowtype;
 v_tech_rate numeric(12,2);
 v_helper_rate numeric(12,2);
 v_total numeric(12,2);
 v_unit text:='hour';
 v_max_tech integer;
 v_max_helper integer;
 v_min_duration integer;
 v_max_duration integer;
begin
 if auth.uid() is null then raise exception 'Authentication required' using errcode='42501'; end if;
 if not exists(select 1 from public.srk_customer_profiles where user_id=auth.uid() and account_status='active') then
  raise exception 'Active customer profile required';
 end if;
 select coalesce((select (setting_value #>> '{}')::integer from public.srk_system_settings where setting_key='max_technicians_per_booking'),10),
        coalesce((select (setting_value #>> '{}')::integer from public.srk_system_settings where setting_key='max_helpers_per_booking'),10),
        coalesce((select (setting_value #>> '{}')::integer from public.srk_system_settings where setting_key='minimum_booking_duration_hours'),1),
        coalesce((select (setting_value #>> '{}')::integer from public.srk_system_settings where setting_key='maximum_booking_duration_hours'),1440)
 into v_max_tech,v_max_helper,v_min_duration,v_max_duration;
 if p_technician_count not between 1 and v_max_tech or p_helper_count not between 0 and v_max_helper
  or p_duration_hours not between v_min_duration and v_max_duration
  or p_unit_count not between 1 and 100 then
  raise exception 'Requested worker count, duration or unit count is outside configured limits';
 end if;
 if not exists(select 1 from public.srk_service_types s where s.id=p_service_type_id and s.category_id=p_category_id and s.is_active)
  or not exists(select 1 from public.srk_service_skills k where k.id=p_skill_id and k.service_type_id=p_service_type_id and k.is_active) then
  raise exception 'Selected category, service or work skill is invalid';
 end if;
 if p_skill_level_id is not null then
  select * into v_level from public.srk_skill_levels where id=p_skill_level_id and category_id=p_category_id and is_active;
  if not found then raise exception 'Selected qualification is not active for this category'; end if;
 else
  select * into v_level from public.srk_skill_levels where category_id=p_category_id and is_active order by sort_order limit 1;
 end if;
 select * into v_rule from public.srk_service_pricing_rules
 where category_id=p_category_id and service_type_id=p_service_type_id
  and effective_from<=clock_timestamp() and (effective_to is null or effective_to>clock_timestamp())
 order by effective_from desc limit 1;
 if found and v_rule.pricing_unit='motor_hp' then
  select t.fixed_price into v_tech_rate from public.srk_service_pricing_hp_tiers t
  where t.pricing_rule_id=v_rule.id and t.motor_hp=p_motor_hp;
  if v_tech_rate is null then raise exception 'No approved fixed price exists for this Motor/Pump HP'; end if;
  v_unit:='motor_hp'; v_helper_rate:=0; v_total:=v_tech_rate;
 elsif found and v_rule.pricing_unit='per_item' then
  v_tech_rate:=v_rule.technician_rate;
  if v_tech_rate is null then raise exception 'Approved per-item price is missing'; end if;
  v_unit:='per_item'; v_helper_rate:=0; v_total:=v_tech_rate*p_unit_count;
 else
  if v_level.id is null then raise exception 'Approved qualification level is missing'; end if;
  select r.technician_hourly_rate,r.helper_hourly_rate into v_tech_rate,v_helper_rate
  from public.srk_service_rates r
  where r.category_id=p_category_id and r.service_type_id=p_service_type_id
   and r.skill_level_id=v_level.id and r.rate_status='approved'
   and r.effective_from<=clock_timestamp() and (r.effective_to is null or r.effective_to>clock_timestamp())
  order by r.effective_from desc limit 1;
  if v_tech_rate is null then
   if v_rule.id is null or v_rule.technician_rate is null then
    raise exception 'No approved hourly rate exists for this service and qualification';
   end if;
   v_tech_rate:=v_rule.technician_rate; v_helper_rate:=coalesce(v_rule.helper_rate,0);
  end if;
  v_helper_rate:=coalesce(v_helper_rate,0);
  if p_helper_count>0 and v_helper_rate<=0 then
   raise exception 'Helper service is not available for this work because no approved Helper hourly rate is published';
  end if;
  v_unit:='hour';
  v_total:=round((v_tech_rate*p_technician_count+v_helper_rate*p_helper_count)*p_duration_hours,2);
 end if;
 return query select v_unit,v_level.level_name,v_tech_rate,v_helper_rate,
  v_total,round(v_total*0.15,2),round(v_total*0.85,2),
  v_unit='hour' and p_duration_hours>8,false,
  case when v_unit='hour' then 'Base estimate; 1.5x overtime is added only for each worker''s billable time beyond 8 hours in a booking day. Materials are excluded.'
   when v_unit='motor_hp' then 'Fixed Motor/Pump HP price. No timer and no materials.'
   else 'Fixed per-item price. Materials are excluded.' end;
end
$function$;