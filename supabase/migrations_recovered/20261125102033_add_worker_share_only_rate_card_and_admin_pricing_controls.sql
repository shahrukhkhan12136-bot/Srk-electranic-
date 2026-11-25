create or replace function public.srk_worker_get_my_rate_card()
returns jsonb
language plpgsql
stable
security definer
set search_path = pg_catalog, public, auth
as $function$
declare
  v_worker_type text;
  v_worker_share numeric(5,2);
  v_result jsonb;
begin
  if auth.uid() is null then
    raise exception 'Authentication required' using errcode='42501';
  end if;

  select wp.worker_type
    into v_worker_type
  from public.srk_worker_profiles wp
  where wp.user_id=auth.uid()
  limit 1;

  if v_worker_type is null or v_worker_type not in ('technician','helper') then
    raise exception 'Approved worker profile is required' using errcode='42501';
  end if;

  select 100 - coalesce((ss.setting_value #>> '{}')::numeric,15.00)
    into v_worker_share
  from (select 1) seed
  left join public.srk_system_settings ss
    on ss.setting_key='company_commission_rate';

  v_worker_share:=coalesce(v_worker_share,85.00);

  with rate_rows as (
    -- Current versioned hourly catalogue rules (these override legacy rates).
    select c.id category_id, s.service_name, null::text skill_level_name,
      'प्रति घंटा'::text rate_label,
      round((case when v_worker_type='helper' then r.helper_rate else r.technician_rate end)
        * v_worker_share / 100,2) worker_rate,
      'प्रति घंटा'::text unit_label, s.sort_order service_sort, 0 skill_sort, 0 detail_sort
    from public.srk_service_pricing_rules r
    join public.srk_service_categories c on c.id=r.category_id and c.is_active
    join public.srk_service_types s on s.id=r.service_type_id and s.is_active
    where r.effective_from<=clock_timestamp()
      and (r.effective_to is null or r.effective_to>clock_timestamp())
      and r.pricing_unit='hour'
      and (case when v_worker_type='helper' then r.helper_rate else r.technician_rate end) is not null

    union all

    -- Fixed HP tiers: only the Technician role has an approved fixed-price rate.
    select c.id, s.service_name, null::text,
      trim(to_char(t.motor_hp,'FM999990.0'))||' HP',
      round(t.fixed_price*v_worker_share/100,2),
      'एक बार का फिक्स चार्ज',s.sort_order,0,t.motor_hp::integer
    from public.srk_service_pricing_rules r
    join public.srk_service_categories c on c.id=r.category_id and c.is_active
    join public.srk_service_types s on s.id=r.service_type_id and s.is_active
    join public.srk_service_pricing_hp_tiers t on t.pricing_rule_id=r.id
    where v_worker_type='technician'
      and r.effective_from<=clock_timestamp()
      and (r.effective_to is null or r.effective_to>clock_timestamp())
      and r.pricing_unit='motor_hp'

    union all

    -- Fixed per-item rates: only the Technician role has an approved rate.
    select c.id,s.service_name,null::text,'प्रति यूनिट',
      round(r.technician_rate*v_worker_share/100,2),
      'प्रति यूनिट फिक्स चार्ज',s.sort_order,0,0
    from public.srk_service_pricing_rules r
    join public.srk_service_categories c on c.id=r.category_id and c.is_active
    join public.srk_service_types s on s.id=r.service_type_id and s.is_active
    where v_worker_type='technician'
      and r.effective_from<=clock_timestamp()
      and (r.effective_to is null or r.effective_to>clock_timestamp())
      and r.pricing_unit='per_item'
      and r.technician_rate is not null

    union all

    -- Legacy hourly rates for active services that do not have a current versioned rule.
    select c.id,s.service_name,l.level_name,'प्रति घंटा',
      round((case when v_worker_type='helper' then sr.helper_hourly_rate
                  else sr.technician_hourly_rate end)*v_worker_share/100,2),
      'प्रति घंटा',s.sort_order,l.sort_order,0
    from public.srk_service_rates sr
    join public.srk_service_categories c on c.id=sr.category_id and c.is_active
    join public.srk_service_types s on s.id=sr.service_type_id and s.is_active
    join public.srk_skill_levels l on l.id=sr.skill_level_id and l.is_active
    where sr.rate_status='approved'
      and sr.effective_from<=clock_timestamp()
      and (sr.effective_to is null or sr.effective_to>clock_timestamp())
      and (case when v_worker_type='helper' then sr.helper_hourly_rate
                else sr.technician_hourly_rate end) is not null
      and not exists (
        select 1 from public.srk_service_pricing_rules r
        where r.category_id=sr.category_id
          and r.service_type_id=sr.service_type_id
          and r.effective_from<=clock_timestamp()
          and (r.effective_to is null or r.effective_to>clock_timestamp())
      )
  )
  select coalesce(jsonb_agg(
    jsonb_build_object(
      'category_code',c.category_code,
      'category_name',c.category_name,
      'rates',coalesce((
        select jsonb_agg(jsonb_build_object(
          'service_name',rr.service_name,
          'skill_level_name',rr.skill_level_name,
          'rate_label',rr.rate_label,
          'worker_rate',rr.worker_rate,
          'unit_label',rr.unit_label
        ) order by rr.service_sort,rr.skill_sort,rr.detail_sort,rr.rate_label)
        from rate_rows rr where rr.category_id=c.id
      ),'[]'::jsonb)
    ) order by c.sort_order
  ),'[]'::jsonb)
  into v_result
  from public.srk_service_categories c
  where c.is_active
    and c.category_code in (
      'electrician','plumber','painter',
      'ac_fridge_technician','motor_pump_technician','cooler_technician'
    );

  return v_result;
end
$function$;

revoke all on function public.srk_worker_get_my_rate_card() from public, anon;
grant execute on function public.srk_worker_get_my_rate_card() to authenticated;

create or replace function public.srk_admin_list_service_pricing_rules()
returns table(
  pricing_rule_id uuid,
  category_id uuid,
  category_code text,
  category_name text,
  service_type_id uuid,
  service_name text,
  pricing_unit text,
  technician_rate numeric,
  helper_rate numeric,
  base_hp numeric,
  base_hp_price numeric,
  hp_step_amount numeric,
  timer_enabled boolean,
  pricing_note text,
  hp_tiers jsonb,
  effective_from timestamptz,
  effective_to timestamptz
)
language plpgsql
stable
security definer
set search_path = pg_catalog, public, auth
as $function$
begin
  if auth.uid() is null or not public.srk_has_admin_permission('catalog.manage') then
    raise exception 'Catalog management permission required' using errcode='42501';
  end if;

  return query
  select r.id,c.id,c.category_code,c.category_name,s.id,s.service_name,
    r.pricing_unit,r.technician_rate,r.helper_rate,r.base_hp,r.base_hp_price,
    r.hp_step_amount,r.timer_enabled,r.pricing_note,
    coalesce((
      select jsonb_agg(jsonb_build_object('motor_hp',t.motor_hp,'fixed_price',t.fixed_price) order by t.motor_hp)
      from public.srk_service_pricing_hp_tiers t where t.pricing_rule_id=r.id
    ),'[]'::jsonb),
    r.effective_from,r.effective_to
  from public.srk_service_pricing_rules r
  join public.srk_service_categories c on c.id=r.category_id
  join public.srk_service_types s on s.id=r.service_type_id
  where r.effective_to is null and c.is_active and s.is_active
  order by c.sort_order,s.sort_order,r.effective_from desc;
end
$function$;

revoke all on function public.srk_admin_list_service_pricing_rules() from public, anon;
grant execute on function public.srk_admin_list_service_pricing_rules() to authenticated;

create or replace function public.srk_admin_get_revenue_split()
returns jsonb
language plpgsql
stable
security definer
set search_path = pg_catalog, public, auth
as $function$
declare v_company numeric(5,2);
begin
  if auth.uid() is null or not public.srk_has_admin_permission('catalog.manage') then
    raise exception 'Catalog management permission required' using errcode='42501';
  end if;
  select coalesce((setting_value #>> '{}')::numeric,15.00)
    into v_company
  from public.srk_system_settings where setting_key='company_commission_rate';
  v_company:=coalesce(v_company,15.00);
  return jsonb_build_object(
    'company_rate',v_company,
    'worker_rate',100.00-v_company
  );
end
$function$;

revoke all on function public.srk_admin_get_revenue_split() from public, anon;
grant execute on function public.srk_admin_get_revenue_split() to authenticated;

create or replace function public.srk_admin_update_revenue_split(
  p_company_rate numeric,
  p_worker_rate numeric,
  p_reason text
)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, auth
as $function$
declare v_result jsonb;
begin
  if auth.uid() is null or not public.srk_has_admin_permission('catalog.manage') then
    raise exception 'Catalog management permission required' using errcode='42501';
  end if;
  if p_company_rate is null or p_worker_rate is null
    or p_company_rate<0 or p_company_rate>100
    or p_worker_rate<0 or p_worker_rate>100
    or p_company_rate<>round(p_company_rate,2)
    or p_worker_rate<>round(p_worker_rate,2)
    or round(p_company_rate+p_worker_rate,2)<>100 then
    raise exception 'Company and worker percentages must total exactly 100';
  end if;
  if length(btrim(coalesce(p_reason,'')))<10 then
    raise exception 'Change reason must contain at least 10 non-space characters';
  end if;
  v_result:=public.srk_admin_set_company_commission_rate(p_company_rate,p_reason);
  return v_result || jsonb_build_object(
    'company_rate',p_company_rate,
    'worker_rate',p_worker_rate,
    'effective_for','new bookings only'
  );
end
$function$;

revoke all on function public.srk_admin_update_revenue_split(numeric,numeric,text) from public, anon;
grant execute on function public.srk_admin_update_revenue_split(numeric,numeric,text) to authenticated;