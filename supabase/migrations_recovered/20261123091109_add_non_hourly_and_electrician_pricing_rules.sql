
create table if not exists public.srk_service_pricing_rules (
  id uuid primary key default gen_random_uuid(),
  category_id uuid not null references public.srk_service_categories(id),
  service_type_id uuid not null references public.srk_service_types(id),
  pricing_unit text not null check (pricing_unit in ('hour','per_item','motor_hp')),
  technician_rate numeric(12,2),
  helper_rate numeric(12,2),
  base_hp numeric(6,2),
  base_hp_price numeric(12,2),
  hp_step_amount numeric(12,2),
  timer_enabled boolean not null default true,
  materials_charged_separately boolean not null default true,
  winding_charged_separately boolean not null default false,
  pricing_note text,
  effective_from timestamptz not null default now(),
  effective_to timestamptz,
  created_at timestamptz not null default now(),
  created_by uuid,
  change_reason text,
  constraint srk_pricing_rule_shape check (
    (pricing_unit='hour' and technician_rate is not null and base_hp is null and base_hp_price is null and hp_step_amount is null)
    or (pricing_unit='per_item' and technician_rate is not null and base_hp is null and base_hp_price is null and hp_step_amount is null)
    or (pricing_unit='motor_hp' and base_hp is not null and base_hp_price is not null and hp_step_amount is not null)
  )
);
create index if not exists srk_service_pricing_rules_current_idx
  on public.srk_service_pricing_rules(service_type_id, effective_to)
  where effective_to is null;
alter table public.srk_service_pricing_rules enable row level security;
revoke all on public.srk_service_pricing_rules from anon, authenticated;
grant select on public.srk_service_pricing_rules to authenticated;
drop policy if exists srk_pricing_rules_admin_read on public.srk_service_pricing_rules;
create policy srk_pricing_rules_admin_read on public.srk_service_pricing_rules
  for select to authenticated using (public.srk_has_admin_permission('catalog.manage'));

with wanted as (
  select c.id category_id, s.id service_type_id, c.category_name, s.service_name
  from public.srk_service_categories c
  join public.srk_service_types s on s.category_id=c.id
  where (c.category_name='Electrician' and s.service_name in ('Basic Electrical Work','Residential/Office Wiring'))
     or (c.category_name='Cooler Technician')
     or (c.category_name='Motor & Pump Technician' and s.service_name in ('Motor Repair','Pump Repair','Motor & Pump Installation'))
)
insert into public.srk_service_pricing_rules
(category_id,service_type_id,pricing_unit,technician_rate,helper_rate,base_hp,base_hp_price,hp_step_amount,timer_enabled,materials_charged_separately,winding_charged_separately,pricing_note,change_reason)
select category_id,service_type_id,
 case when category_name='Electrician' then 'hour'
      when category_name='Cooler Technician' then 'per_item'
      else 'motor_hp' end,
 case when category_name='Electrician' and service_name='Basic Electrical Work' then 100
      when category_name='Electrician' and service_name='Residential/Office Wiring' then 150
      when category_name='Cooler Technician' then 500 else null end,
 case when category_name='Electrician' and service_name='Residential/Office Wiring' then 100 else null end,
 case when category_name='Motor & Pump Technician' then 0.5 else null end,
 case when category_name='Motor & Pump Technician' then 500 else null end,
 case when category_name='Motor & Pump Technician' then 100 else null end,
 case when category_name='Cooler Technician' then false else true end,
 true,
 category_name='Motor & Pump Technician',
 case when category_name='Electrician' then 'Hourly labour rate; helper rate applies only where explicitly set.'
      when category_name='Cooler Technician' then 'Fixed charge per cooler; timer disabled; parts/materials separate.'
      else 'Checking and fitting only. Winding and materials charged separately. Price = ₹500 + ₹100 × FLOOR(HP), with minimum supported HP 0.5; examples: 0.5 HP ₹500, 1 HP ₹600, 2 HP ₹700.' end,
 'Approved by user on 2026-11-23'
from wanted w
where not exists (
 select 1 from public.srk_service_pricing_rules r
 where r.service_type_id=w.service_type_id and r.effective_to is null
);
