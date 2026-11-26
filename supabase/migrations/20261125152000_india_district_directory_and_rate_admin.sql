-- India LGD district directory and district-specific service-rate administration.
-- Keep the sync floor compatible with the checked-in 784-district source snapshot;
-- the 36-state/UT and unique LGD-code checks below provide additional completeness guards.
-- This migration stages Admin controls only; booking/dispatch/billing integration is handled
-- by a subsequent migration before any district rate is used for live bookings.

create table if not exists public.srk_india_districts (
  district_lgd_code text primary key,
  state_lgd_code text not null,
  state_name text not null,
  district_name text not null,
  source_date text not null,
  source_name text not null default 'Ministry of Panchayati Raj — LGD (community mirror)',
  is_active boolean not null default true,
  synced_at timestamptz not null default clock_timestamp(),
  created_at timestamptz not null default clock_timestamp(),
  updated_at timestamptz not null default clock_timestamp(),
  constraint srk_india_districts_district_code_numeric check (district_lgd_code ~ '^[0-9]+$'),
  constraint srk_india_districts_state_code_numeric check (state_lgd_code ~ '^[0-9]+$')
);

create index if not exists srk_india_districts_state_name_idx
  on public.srk_india_districts(state_name, district_name);

alter table public.srk_india_districts enable row level security;
revoke all on public.srk_india_districts from public, anon, authenticated;

create table if not exists public.srk_district_service_rate_overrides (
  id uuid primary key default gen_random_uuid(),
  district_lgd_code text not null references public.srk_india_districts(district_lgd_code),
  service_rate_id uuid references public.srk_service_rates(id),
  pricing_rule_id uuid references public.srk_service_pricing_rules(id),
  technician_rate numeric(12,2),
  helper_rate numeric(12,2),
  fixed_price numeric(12,2),
  hp_tiers jsonb not null default '[]'::jsonb,
  effective_from timestamptz not null default clock_timestamp(),
  effective_to timestamptz,
  created_by uuid not null,
  change_reason text not null,
  created_at timestamptz not null default clock_timestamp(),
  constraint srk_district_rate_one_target check (
    (service_rate_id is not null and pricing_rule_id is null)
    or (service_rate_id is null and pricing_rule_id is not null)
  ),
  constraint srk_district_rate_nonnegative check (
    (technician_rate is null or technician_rate > 0)
    and (helper_rate is null or helper_rate > 0)
    and (fixed_price is null or fixed_price > 0)
  ),
  constraint srk_district_rate_hp_array check (jsonb_typeof(hp_tiers) = 'array')
);

create unique index if not exists srk_district_rate_active_service_uidx
  on public.srk_district_service_rate_overrides(district_lgd_code, service_rate_id)
  where service_rate_id is not null and effective_to is null;

create unique index if not exists srk_district_rate_active_rule_uidx
  on public.srk_district_service_rate_overrides(district_lgd_code, pricing_rule_id)
  where pricing_rule_id is not null and effective_to is null;

create index if not exists srk_district_rate_history_idx
  on public.srk_district_service_rate_overrides(district_lgd_code, effective_from desc);

alter table public.srk_district_service_rate_overrides enable row level security;
revoke all on public.srk_district_service_rate_overrides from public, anon, authenticated;

create table if not exists srk_private.admin_district_rate_audit_log (
  id bigint generated always as identity primary key,
  admin_user_id uuid not null,
  district_lgd_code text not null,
  target_type text not null,
  target_id uuid not null,
  old_values jsonb,
  new_values jsonb not null,
  reason text not null,
  created_at timestamptz not null default clock_timestamp()
);
alter table srk_private.admin_district_rate_audit_log enable row level security;
revoke all on srk_private.admin_district_rate_audit_log from public, anon, authenticated;

create or replace function srk_private.admin_sync_lgd_districts(
  p_districts jsonb,
  p_source_date text
) returns integer
language plpgsql
volatile
security definer
set search_path = pg_catalog, public, auth, srk_private
as $function$
declare
  v_count integer;
begin
  if auth.uid() is null or not public.is_srk_admin() then
    raise exception 'Main Admin permission required' using errcode='42501';
  end if;
  if jsonb_typeof(p_districts) <> 'array' or jsonb_array_length(p_districts) < 780 then
    raise exception 'District sync rejected: expected a current all-India directory snapshot';
  end if;
  if (select count(distinct state_code) from jsonb_to_recordset(p_districts) as x(code text, name text, state_code text, state_name text)) <> 36 then
    raise exception 'District sync rejected: expected all 36 Indian States/UTs';
  end if;
  if nullif(btrim(p_source_date), '') is null then
    raise exception 'LGD source date is required';
  end if;
  if exists (
    select 1
    from jsonb_to_recordset(p_districts) as x(code text, name text, state_code text, state_name text)
    where coalesce(code,'') !~ '^[0-9]+$'
       or coalesce(state_code,'') !~ '^[0-9]+$'
       or nullif(btrim(name),'') is null
       or nullif(btrim(state_name),'') is null
  ) then
    raise exception 'District directory contains an invalid code or name';
  end if;
  if (select count(*) from jsonb_to_recordset(p_districts) as x(code text, name text, state_code text, state_name text))
     <> (select count(distinct code) from jsonb_to_recordset(p_districts) as x(code text, name text, state_code text, state_name text)) then
    raise exception 'District directory contains duplicate LGD codes';
  end if;

  insert into public.srk_india_districts(
    district_lgd_code,state_lgd_code,state_name,district_name,source_date,is_active,synced_at,updated_at
  )
  select btrim(x.code),btrim(x.state_code),btrim(x.state_name),btrim(x.name),p_source_date,true,clock_timestamp(),clock_timestamp()
  from jsonb_to_recordset(p_districts) as x(code text, name text, state_code text, state_name text)
  on conflict(district_lgd_code) do update set
    state_lgd_code=excluded.state_lgd_code,
    state_name=excluded.state_name,
    district_name=excluded.district_name,
    source_date=excluded.source_date,
    is_active=true,
    synced_at=clock_timestamp(),
    updated_at=clock_timestamp();

  update public.srk_india_districts d
  set is_active=false, updated_at=clock_timestamp()
  where d.is_active
    and not exists (
      select 1 from jsonb_to_recordset(p_districts) as x(code text, name text, state_code text, state_name text)
      where btrim(x.code)=d.district_lgd_code
    );

  get diagnostics v_count = row_count;
  return jsonb_array_length(p_districts);
end;
$function$;

create or replace function srk_private.admin_list_india_districts()
returns table(district_lgd_code text,state_lgd_code text,state_name text,district_name text,source_date text)
language plpgsql
stable
security definer
set search_path = pg_catalog, public, auth, srk_private
as $function$
begin
  if auth.uid() is null or not public.is_srk_admin() then
    raise exception 'Main Admin permission required' using errcode='42501';
  end if;
  return query
  select d.district_lgd_code,d.state_lgd_code,d.state_name,d.district_name,d.source_date
  from public.srk_india_districts d
  where d.is_active
  order by d.state_name,d.district_name;
end;
$function$;

create or replace function srk_private.admin_list_district_rate_matrix(p_district_lgd_code text)
returns table(
  target_type text,target_id uuid,category_name text,service_name text,skill_name text,
  pricing_unit text,default_technician_rate numeric,default_helper_rate numeric,
  default_fixed_price numeric,default_hp_tiers jsonb,
  district_technician_rate numeric,district_helper_rate numeric,
  district_fixed_price numeric,district_hp_tiers jsonb,
  override_id uuid,change_reason text,effective_from timestamptz
)
language plpgsql
stable
security definer
set search_path = pg_catalog, public, auth, srk_private
as $function$
begin
  if auth.uid() is null or not public.is_srk_admin() then
    raise exception 'Main Admin permission required' using errcode='42501';
  end if;
  if not exists(select 1 from public.srk_india_districts where district_lgd_code=p_district_lgd_code and is_active) then
    raise exception 'Select a valid active Indian district';
  end if;

  return query
  select 'service_rate'::text,sr.id,c.category_name,st.service_name,l.level_name,'hour'::text,
    sr.technician_hourly_rate,sr.helper_hourly_rate,null::numeric,'[]'::jsonb,
    o.technician_rate,o.helper_rate,null::numeric,'[]'::jsonb,
    o.id,o.change_reason,o.effective_from
  from public.srk_service_rates sr
  join public.srk_service_categories c on c.id=sr.category_id and c.is_active
  join public.srk_service_types st on st.id=sr.service_type_id and st.is_active
  join public.srk_skill_levels l on l.id=sr.skill_level_id and l.is_active
  left join lateral (
    select x.* from public.srk_district_service_rate_overrides x
    where x.district_lgd_code=p_district_lgd_code and x.service_rate_id=sr.id and x.effective_to is null
    order by x.effective_from desc limit 1
  ) o on true
  where sr.rate_status='approved' and sr.effective_from<=clock_timestamp()
    and (sr.effective_to is null or sr.effective_to>clock_timestamp())

  union all

  select 'pricing_rule'::text,r.id,c.category_name,st.service_name,null::text,r.pricing_unit,
    r.technician_rate,r.helper_rate,
    case when r.pricing_unit='per_item' then r.technician_rate else null end,
    coalesce((select jsonb_agg(jsonb_build_object('motor_hp',t.motor_hp,'fixed_price',t.fixed_price) order by t.motor_hp)
      from public.srk_service_pricing_hp_tiers t where t.pricing_rule_id=r.id),'[]'::jsonb),
    o.technician_rate,o.helper_rate,o.fixed_price,coalesce(o.hp_tiers,'[]'::jsonb),
    o.id,o.change_reason,o.effective_from
  from public.srk_service_pricing_rules r
  join public.srk_service_categories c on c.id=r.category_id and c.is_active
  join public.srk_service_types st on st.id=r.service_type_id and st.is_active
  left join lateral (
    select x.* from public.srk_district_service_rate_overrides x
    where x.district_lgd_code=p_district_lgd_code and x.pricing_rule_id=r.id and x.effective_to is null
    order by x.effective_from desc limit 1
  ) o on true
  where r.effective_from<=clock_timestamp() and (r.effective_to is null or r.effective_to>clock_timestamp())
    and (r.pricing_unit in ('per_item','motor_hp') or not exists(
      select 1 from public.srk_service_rates sr
      where sr.category_id=r.category_id and sr.service_type_id=r.service_type_id
        and sr.rate_status='approved' and sr.effective_from<=clock_timestamp()
        and (sr.effective_to is null or sr.effective_to>clock_timestamp())
    ))
  order by 3,4,5 nulls first;
end;
$function$;

create or replace function srk_private.admin_save_district_rate_override(
  p_district_lgd_code text,
  p_service_rate_id uuid,
  p_pricing_rule_id uuid,
  p_technician_rate numeric,
  p_helper_rate numeric,
  p_fixed_price numeric,
  p_hp_tiers jsonb,
  p_change_reason text
) returns uuid
language plpgsql
volatile
security definer
set search_path = pg_catalog, public, auth, srk_private
as $function$
declare
  v_unit text;
  v_existing public.srk_district_service_rate_overrides%rowtype;
  v_new_id uuid;
  v_expected_tiers integer;
begin
  if auth.uid() is null or not public.is_srk_admin() then
    raise exception 'Main Admin permission required' using errcode='42501';
  end if;
  if length(btrim(coalesce(p_change_reason,'')))<10 then
    raise exception 'Rate change reason must contain at least 10 characters';
  end if;
  if not exists(select 1 from public.srk_india_districts where district_lgd_code=p_district_lgd_code and is_active) then
    raise exception 'Select a valid active Indian district';
  end if;
  if (p_service_rate_id is null) = (p_pricing_rule_id is null) then
    raise exception 'Exactly one service-rate or pricing-rule target is required';
  end if;

  if p_service_rate_id is not null then
    select 'hour' into v_unit from public.srk_service_rates
    where id=p_service_rate_id and rate_status='approved'
      and effective_from<=clock_timestamp() and (effective_to is null or effective_to>clock_timestamp());
    if v_unit is null then raise exception 'Approved service rate not found'; end if;
    if p_technician_rate is null or p_technician_rate<=0
       or (p_helper_rate is not null and p_helper_rate<=0)
       or p_fixed_price is not null then
      raise exception 'Enter a valid hourly Technician and optional Helper rate';
    end if;
  else
    select pricing_unit into v_unit from public.srk_service_pricing_rules
    where id=p_pricing_rule_id and effective_from<=clock_timestamp()
      and (effective_to is null or effective_to>clock_timestamp());
    if v_unit is null then raise exception 'Active pricing rule not found'; end if;
    if v_unit='hour' then
      if p_technician_rate is null or p_technician_rate<=0
         or (p_helper_rate is not null and p_helper_rate<=0) or p_fixed_price is not null then
        raise exception 'Enter valid hourly rates';
      end if;
    elsif v_unit='per_item' then
      if p_fixed_price is null or p_fixed_price<=0 then raise exception 'Fixed service price is required'; end if;
    elsif v_unit='motor_hp' then
      if jsonb_typeof(p_hp_tiers)<>'array' or jsonb_array_length(p_hp_tiers)=0 then
        raise exception 'Motor/Pump HP rates are required';
      end if;
      select count(*) into v_expected_tiers from public.srk_service_pricing_hp_tiers where pricing_rule_id=p_pricing_rule_id;
      if jsonb_array_length(p_hp_tiers)<>v_expected_tiers then
        raise exception 'Every approved HP tier must be priced; do not add or remove HP tiers';
      end if;
      if exists(select 1 from jsonb_to_recordset(p_hp_tiers) as x(motor_hp numeric,fixed_price numeric)
        where motor_hp is null or fixed_price is null or fixed_price<=0) then
        raise exception 'Every HP tier must have a positive price';
      end if;
    else
      raise exception 'Unsupported pricing unit';
    end if;
  end if;

  if p_service_rate_id is not null then
    select * into v_existing from public.srk_district_service_rate_overrides
    where district_lgd_code=p_district_lgd_code and service_rate_id=p_service_rate_id and effective_to is null
    for update;
  else
    select * into v_existing from public.srk_district_service_rate_overrides
    where district_lgd_code=p_district_lgd_code and pricing_rule_id=p_pricing_rule_id and effective_to is null
    for update;
  end if;

  if found then
    update public.srk_district_service_rate_overrides
    set effective_to=clock_timestamp()
    where id=v_existing.id;
  end if;

  insert into public.srk_district_service_rate_overrides(
    district_lgd_code,service_rate_id,pricing_rule_id,technician_rate,helper_rate,
    fixed_price,hp_tiers,created_by,change_reason
  ) values (
    p_district_lgd_code,p_service_rate_id,p_pricing_rule_id,p_technician_rate,p_helper_rate,
    p_fixed_price,coalesce(p_hp_tiers,'[]'::jsonb),auth.uid(),btrim(p_change_reason)
  ) returning id into v_new_id;

  insert into srk_private.admin_district_rate_audit_log(
    admin_user_id,district_lgd_code,target_type,target_id,old_values,new_values,reason
  ) values (
    auth.uid(),p_district_lgd_code,case when p_service_rate_id is not null then 'service_rate' else 'pricing_rule' end,
    coalesce(p_service_rate_id,p_pricing_rule_id),
    case when v_existing.id is not null then to_jsonb(v_existing) else null end,
    jsonb_build_object('technician_rate',p_technician_rate,'helper_rate',p_helper_rate,
      'fixed_price',p_fixed_price,'hp_tiers',coalesce(p_hp_tiers,'[]'::jsonb)),
    btrim(p_change_reason)
  );

  return v_new_id;
end;
$function$;

revoke all on function srk_private.admin_sync_lgd_districts(jsonb,text) from public, anon;
revoke all on function srk_private.admin_list_india_districts() from public, anon;
revoke all on function srk_private.admin_list_district_rate_matrix(text) from public, anon;
revoke all on function srk_private.admin_save_district_rate_override(text,uuid,uuid,numeric,numeric,numeric,jsonb,text) from public, anon;
grant usage on schema srk_private to authenticated;
grant execute on function srk_private.admin_sync_lgd_districts(jsonb,text) to authenticated;
grant execute on function srk_private.admin_list_india_districts() to authenticated;
grant execute on function srk_private.admin_list_district_rate_matrix(text) to authenticated;
grant execute on function srk_private.admin_save_district_rate_override(text,uuid,uuid,numeric,numeric,numeric,jsonb,text) to authenticated;

create or replace function public.srk_admin_sync_lgd_districts(p_districts jsonb,p_source_date text)
returns integer language sql volatile security invoker set search_path=pg_catalog,public
as $function$ select srk_private.admin_sync_lgd_districts(p_districts,p_source_date); $function$;

create or replace function public.srk_admin_list_india_districts()
returns table(district_lgd_code text,state_lgd_code text,state_name text,district_name text,source_date text)
language sql stable security invoker set search_path=pg_catalog,public
as $function$ select * from srk_private.admin_list_india_districts(); $function$;

create or replace function public.srk_admin_list_district_rate_matrix(p_district_lgd_code text)
returns table(
  target_type text,target_id uuid,category_name text,service_name text,skill_name text,
  pricing_unit text,default_technician_rate numeric,default_helper_rate numeric,
  default_fixed_price numeric,default_hp_tiers jsonb,
  district_technician_rate numeric,district_helper_rate numeric,
  district_fixed_price numeric,district_hp_tiers jsonb,
  override_id uuid,change_reason text,effective_from timestamptz
)
language sql stable security invoker set search_path=pg_catalog,public
as $function$ select * from srk_private.admin_list_district_rate_matrix(p_district_lgd_code); $function$;

create or replace function public.srk_admin_save_district_rate_override(
  p_district_lgd_code text,p_service_rate_id uuid,p_pricing_rule_id uuid,
  p_technician_rate numeric,p_helper_rate numeric,p_fixed_price numeric,p_hp_tiers jsonb,p_change_reason text
) returns uuid
language sql volatile security invoker set search_path=pg_catalog,public
as $function$ select srk_private.admin_save_district_rate_override(
  p_district_lgd_code,p_service_rate_id,p_pricing_rule_id,p_technician_rate,p_helper_rate,p_fixed_price,p_hp_tiers,p_change_reason
); $function$;

revoke all on function public.srk_admin_sync_lgd_districts(jsonb,text) from public, anon;
revoke all on function public.srk_admin_list_india_districts() from public, anon;
revoke all on function public.srk_admin_list_district_rate_matrix(text) from public, anon;
revoke all on function public.srk_admin_save_district_rate_override(text,uuid,uuid,numeric,numeric,numeric,jsonb,text) from public, anon;
grant execute on function public.srk_admin_sync_lgd_districts(jsonb,text) to authenticated;
grant execute on function public.srk_admin_list_india_districts() to authenticated;
grant execute on function public.srk_admin_list_district_rate_matrix(text) to authenticated;
grant execute on function public.srk_admin_save_district_rate_override(text,uuid,uuid,numeric,numeric,numeric,jsonb,text) to authenticated;
