CREATE OR REPLACE FUNCTION public.srk_get_public_service_pricing_options(p_service_type_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO 'pg_catalog','public'
AS $function$
declare
 v_result jsonb;
begin
 if p_service_type_id is null then
  raise exception 'Service type ID is required' using errcode='22023';
 end if;

 select jsonb_build_object(
  'category_id',c.id,
  'category_code',c.category_code,
  'category_name',c.category_name,
  'service_type_id',s.id,
  'service_code',s.service_code,
  'service_name',s.service_name,
  'pricing_unit',coalesce(r.pricing_unit,'hour'),
  'technician_rate',r.technician_rate,
  'helper_rate',r.helper_rate,
  'timer_enabled',coalesce(r.timer_enabled,true),
  'materials_charged_separately',false,
  'winding_charged_separately',false,
  'pricing_note',r.pricing_note,
  'hourly_rates',coalesce((
   select jsonb_agg(jsonb_build_object(
    'skill_level_id',l.id,
    'skill_level_code',l.level_code,
    'skill_level_name',l.level_name,
    'technician_hourly_rate',sr.technician_hourly_rate,
    'helper_hourly_rate',sr.helper_hourly_rate
   ) order by l.sort_order)
   from public.srk_service_rates sr
   join public.srk_skill_levels l on l.id=sr.skill_level_id
   where sr.category_id=c.id and sr.service_type_id=s.id
    and sr.rate_status='approved' and sr.effective_from<=clock_timestamp()
    and (sr.effective_to is null or sr.effective_to>clock_timestamp())
    and l.is_active
  ),'[]'::jsonb),
  'hp_tiers',coalesce((
   select jsonb_agg(jsonb_build_object('motor_hp',t.motor_hp,'fixed_price',t.fixed_price) order by t.motor_hp)
   from public.srk_service_pricing_hp_tiers t
   where t.pricing_rule_id=r.id
  ),'[]'::jsonb)
 ) into v_result
 from public.srk_service_types s
 join public.srk_service_categories c on c.id=s.category_id and c.is_active
 left join lateral (
  select pr.* from public.srk_service_pricing_rules pr
  where pr.category_id=c.id and pr.service_type_id=s.id
   and pr.effective_from<=clock_timestamp()
   and (pr.effective_to is null or pr.effective_to>clock_timestamp())
  order by pr.effective_from desc limit 1
 ) r on true
 where s.id=p_service_type_id and s.is_active;

 if v_result is null then
  raise exception 'Active service not found' using errcode='22023';
 end if;
 return v_result;
end
$function$;

REVOKE ALL ON FUNCTION public.srk_get_public_service_pricing_options(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.srk_get_public_service_pricing_options(uuid) TO anon,authenticated;