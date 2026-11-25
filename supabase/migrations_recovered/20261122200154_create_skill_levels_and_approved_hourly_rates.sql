
create table if not exists public.srk_skill_levels (
  id uuid primary key default gen_random_uuid(),
  category_id uuid not null references public.srk_service_categories(id) on delete restrict,
  level_code text not null,
  level_name text not null,
  sort_order integer not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  constraint srk_skill_level_category_code_unique unique(category_id,level_code),
  constraint srk_skill_level_name_valid check(length(btrim(level_name)) between 2 and 100)
);

create table if not exists public.srk_service_rates (
  id uuid primary key default gen_random_uuid(),
  category_id uuid not null references public.srk_service_categories(id) on delete restrict,
  service_type_id uuid references public.srk_service_types(id) on delete restrict,
  skill_level_id uuid not null references public.srk_skill_levels(id) on delete restrict,
  technician_hourly_rate numeric(10,2),
  helper_hourly_rate numeric(10,2),
  rate_status text not null default 'draft',
  effective_from timestamptz not null default now(),
  effective_to timestamptz,
  created_at timestamptz not null default now(),
  created_by uuid,
  constraint srk_service_rate_status_valid check(rate_status in ('draft','approved','retired')),
  constraint srk_service_rate_amounts_valid check(
    (technician_hourly_rate is null or technician_hourly_rate>=0)
    and (helper_hourly_rate is null or helper_hourly_rate>=0)
  ),
  constraint srk_service_rate_effective_valid check(effective_to is null or effective_to>effective_from)
);

create unique index if not exists srk_service_rates_active_unique
  on public.srk_service_rates(category_id,coalesce(service_type_id,'00000000-0000-0000-0000-000000000000'::uuid),skill_level_id)
  where rate_status='approved' and effective_to is null;

insert into public.srk_skill_levels(category_id,level_code,level_name,sort_order)
select c.id,v.level_code,v.level_name,v.sort_order
from public.srk_service_categories c
join (values
 ('electrician','basic','Basic',1),
 ('electrician','residential_office','Residential/Office Wiring',2),
 ('electrician','factory_industrial_expert','Factory/Industrial Wiring Expert',3),
 ('electrician','master_electrician','Master Electrician',4),
 ('plumber','basic','Basic',1),
 ('plumber','expert','Expert',2),
 ('plumber','master_industrial','Master/Industrial',3),
 ('painter','basic','Basic',1),
 ('painter','expert','Expert',2),
 ('painter','master','Master',3),
 ('ac_fridge_technician','ac_technician','AC Technician',1),
 ('ac_fridge_technician','fridge_technician','Fridge Technician',2),
 ('motor_pump_technician','basic','Basic',1),
 ('motor_pump_technician','expert','Expert',2),
 ('motor_pump_technician','master','Master',3),
 ('cooler_technician','basic','Basic',1),
 ('cooler_technician','expert','Expert',2),
 ('cooler_technician','master','Master',3)
) v(category_code,level_code,level_name,sort_order)
on c.category_code=v.category_code
on conflict(category_id,level_code) do update set level_name=excluded.level_name,sort_order=excluded.sort_order;

insert into public.srk_service_rates(category_id,service_type_id,skill_level_id,technician_hourly_rate,helper_hourly_rate,rate_status)
select c.id,null,l.id,v.tech_rate,v.helper_rate,'approved'
from (values
 ('plumber','basic',100::numeric,50::numeric),
 ('plumber','expert',150::numeric,75::numeric),
 ('plumber','master_industrial',225::numeric,100::numeric),
 ('electrician','factory_industrial_expert',300::numeric,125::numeric),
 ('electrician','master_electrician',700::numeric,200::numeric)
) v(category_code,level_code,tech_rate,helper_rate)
join public.srk_service_categories c on c.category_code=v.category_code
join public.srk_skill_levels l on l.category_id=c.id and l.level_code=v.level_code
on conflict do nothing;

insert into public.srk_service_rates(category_id,service_type_id,skill_level_id,technician_hourly_rate,helper_hourly_rate,rate_status)
select c.id,s.id,l.id,250,150,'approved'
from public.srk_service_categories c
join public.srk_service_types s on s.category_id=c.id and s.service_code in ('ac_repair','ac_installation')
join public.srk_skill_levels l on l.category_id=c.id and l.level_code='ac_technician'
where c.category_code='ac_fridge_technician'
on conflict do nothing;

alter table public.srk_skill_levels enable row level security;
alter table public.srk_service_rates enable row level security;
