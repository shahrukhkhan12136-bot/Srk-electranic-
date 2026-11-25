
create table if not exists public.srk_service_categories (
  id uuid primary key default gen_random_uuid(),
  category_code text not null unique,
  category_name text not null unique,
  is_active boolean not null default true,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint srk_service_categories_code_format
    check (category_code ~ '^[a-z][a-z0-9_]{1,49}$'),
  constraint srk_service_categories_name_nonempty
    check (length(btrim(category_name)) between 2 and 100)
);

create table if not exists public.srk_service_types (
  id uuid primary key default gen_random_uuid(),
  category_id uuid not null references public.srk_service_categories(id) on delete restrict,
  service_code text not null unique,
  service_name text not null,
  is_active boolean not null default true,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint srk_service_types_code_format
    check (service_code ~ '^[a-z][a-z0-9_]{1,59}$'),
  constraint srk_service_types_name_nonempty
    check (length(btrim(service_name)) between 2 and 120),
  constraint srk_service_types_category_name_unique
    unique (category_id, service_name)
);

create table if not exists public.srk_service_skills (
  id uuid primary key default gen_random_uuid(),
  service_type_id uuid not null references public.srk_service_types(id) on delete restrict,
  skill_code text not null unique,
  skill_name text not null,
  is_active boolean not null default true,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint srk_service_skills_code_format
    check (skill_code ~ '^[a-z][a-z0-9_]{1,79}$'),
  constraint srk_service_skills_name_nonempty
    check (length(btrim(skill_name)) between 2 and 150),
  constraint srk_service_skills_service_name_unique
    unique (service_type_id, skill_name)
);

create index if not exists srk_service_types_category_active_idx
  on public.srk_service_types(category_id, is_active, sort_order);

create index if not exists srk_service_skills_service_active_idx
  on public.srk_service_skills(service_type_id, is_active, sort_order);

alter table public.srk_service_categories enable row level security;
alter table public.srk_service_types enable row level security;
alter table public.srk_service_skills enable row level security;

insert into public.srk_service_categories
  (category_code, category_name, sort_order)
values
  ('electrician', 'Electrician', 1),
  ('plumber', 'Plumber', 2),
  ('painter', 'Painter', 3),
  ('ac_fridge_technician', 'AC + Fridge Technician', 4),
  ('motor_pump_technician', 'Motor & Pump Technician', 5),
  ('cooler_technician', 'Cooler Technician', 6)
on conflict (category_code) do update
set category_name = excluded.category_name,
    sort_order = excluded.sort_order,
    updated_at = now();

insert into public.srk_service_types
  (category_id, service_code, service_name, sort_order)
select c.id, v.service_code, v.service_name, v.sort_order
from public.srk_service_categories c
join (values
  ('ac_fridge_technician', 'ac_repair', 'AC Repair', 1),
  ('ac_fridge_technician', 'ac_installation', 'AC Installation', 2),
  ('ac_fridge_technician', 'fridge_repair', 'Fridge Repair', 3)
) as v(category_code, service_code, service_name, sort_order)
  on v.category_code = c.category_code
on conflict (service_code) do update
set category_id = excluded.category_id,
    service_name = excluded.service_name,
    sort_order = excluded.sort_order,
    updated_at = now();
