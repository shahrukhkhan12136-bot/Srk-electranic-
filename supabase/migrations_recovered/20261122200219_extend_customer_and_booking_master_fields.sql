
create sequence if not exists public.srk_order_number_seq start 1;

create table if not exists public.srk_customer_profiles (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null unique references auth.users(id) on delete restrict,
  customer_code text unique,
  full_name text not null,
  phone text not null,
  email text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint srk_customer_name_valid check(length(btrim(full_name)) between 2 and 120),
  constraint srk_customer_phone_valid check(length(regexp_replace(phone,'[^0-9]','','g')) between 10 and 15)
);

create or replace function public.srk_assign_customer_code()
returns trigger language plpgsql set search_path=pg_catalog,public as $$
begin
  if new.customer_code is null then
    new.customer_code := 'SRK-CUS-' || lpad(nextval('public.srk_order_number_seq')::text,6,'0');
  end if;
  return new;
end $$;

drop trigger if exists srk_customer_code_trigger on public.srk_customer_profiles;
create trigger srk_customer_code_trigger before insert on public.srk_customer_profiles
for each row execute function public.srk_assign_customer_code();

alter table public.service_bookings
  add column if not exists order_number text,
  add column if not exists category_id uuid references public.srk_service_categories(id) on delete restrict,
  add column if not exists service_type_id uuid references public.srk_service_types(id) on delete restrict,
  add column if not exists selected_skill_id uuid references public.srk_service_skills(id) on delete restrict,
  add column if not exists requested_technician_count integer not null default 1,
  add column if not exists requested_helper_count integer not null default 0,
  add column if not exists requested_duration_hours integer,
  add column if not exists booking_latitude double precision,
  add column if not exists booking_longitude double precision,
  add column if not exists customer_id uuid references public.srk_customer_profiles(id) on delete restrict,
  add column if not exists billable_rate_snapshot jsonb,
  add column if not exists booking_address_confirmed_at timestamptz;

create unique index if not exists service_bookings_order_number_unique
  on public.service_bookings(order_number) where order_number is not null;

create or replace function public.srk_assign_order_number()
returns trigger language plpgsql set search_path=pg_catalog,public as $$
begin
  if new.order_number is null then
    new.order_number := 'SRK-ORD-' || lpad(nextval('public.srk_order_number_seq')::text,6,'0');
  end if;
  return new;
end $$;

drop trigger if exists srk_order_number_trigger on public.service_bookings;
create trigger srk_order_number_trigger before insert on public.service_bookings
for each row execute function public.srk_assign_order_number();

alter table public.service_bookings
  add constraint service_bookings_worker_count_valid
  check(requested_technician_count between 1 and 20 and requested_helper_count between 0 and 20),
  add constraint service_bookings_duration_valid
  check(requested_duration_hours is null or requested_duration_hours between 1 and 1440),
  add constraint service_bookings_booking_lat_valid
  check(booking_latitude is null or booking_latitude between -90 and 90),
  add constraint service_bookings_booking_lng_valid
  check(booking_longitude is null or booking_longitude between -180 and 180);

alter table public.srk_customer_profiles enable row level security;
