-- SRK ELECTRONIC: category-based hourly booking foundation.
-- This migration is intentionally staged in GitHub and is NOT applied to production yet.
-- Price rows remain unpublished until Admin enters and approves every category/duration rate.

create table if not exists public.srk_electrician_categories (
  category_key text primary key check (category_key in ('helper','standard','experienced','master')),
  display_name text not null,
  description text not null,
  minimum_experience_years integer not null default 0 check (minimum_experience_years >= 0),
  daily_salary_amount numeric(10,2) check (daily_salary_amount is null or daily_salary_amount >= 0),
  is_active boolean not null default true,
  sort_order smallint not null unique check (sort_order between 1 and 4),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

insert into public.srk_electrician_categories
  (category_key, display_name, description, minimum_experience_years, sort_order)
values
  ('helper','हेल्पर','अनुभवी इलेक्ट्रिशियन की देखरेख में सहायता और बेसिक काम।',0,1),
  ('standard','सामान्य इलेक्ट्रिशियन','सामान्य फिटिंग, छोटी मरम्मत और बेसिक वायरिंग।',1,2),
  ('experienced','अनुभवी इलेक्ट्रिशियन','फॉल्ट ढूँढना, वायरिंग और कठिन मरम्मत का अनुभव।',3,3),
  ('master','मास्टर इलेक्ट्रिशियन','जटिल वायरिंग, पैनल और उच्च-कौशल वाले कार्य।',5,4)
on conflict (category_key) do update set
  display_name = excluded.display_name,
  description = excluded.description,
  minimum_experience_years = excluded.minimum_experience_years,
  sort_order = excluded.sort_order;

alter table public.electrician_profiles
  add column if not exists category_key text references public.srk_electrician_categories(category_key),
  add column if not exists admin_test_status text not null default 'not_tested'
    check (admin_test_status in ('not_tested','pending','passed','failed')),
  add column if not exists admin_test_score numeric(5,2)
    check (admin_test_score is null or admin_test_score between 0 and 100),
  add column if not exists customer_rating numeric(3,2) not null default 0
    check (customer_rating between 0 and 5),
  add column if not exists completed_jobs_count integer not null default 0
    check (completed_jobs_count >= 0);

create table if not exists public.srk_electrician_category_tests (
  id uuid primary key default gen_random_uuid(),
  electrician_profile_id uuid not null references public.electrician_profiles(id) on delete cascade,
  technical_score numeric(5,2) not null check (technical_score between 0 and 25),
  experience_score numeric(5,2) not null check (experience_score between 0 and 15),
  safety_score numeric(5,2) not null check (safety_score between 0 and 20),
  customer_score numeric(5,2) not null check (customer_score between 0 and 20),
  punctuality_score numeric(5,2) not null check (punctuality_score between 0 and 10),
  rework_score numeric(5,2) not null check (rework_score between 0 and 10),
  total_score numeric(5,2) generated always as
    (technical_score + experience_score + safety_score + customer_score + punctuality_score + rework_score) stored,
  recommended_category text references public.srk_electrician_categories(category_key),
  assigned_category text references public.srk_electrician_categories(category_key),
  result_status text not null default 'pending' check (result_status in ('pending','passed','failed')),
  admin_note text check (admin_note is null or length(admin_note) <= 2000),
  tested_by uuid references auth.users(id),
  tested_at timestamptz,
  created_at timestamptz not null default now()
);

create index if not exists srk_category_tests_profile_created_idx
  on public.srk_electrician_category_tests(electrician_profile_id, created_at desc);

create table if not exists public.srk_electrician_availability (
  id uuid primary key default gen_random_uuid(),
  electrician_profile_id uuid not null references public.electrician_profiles(id) on delete cascade,
  weekday smallint not null check (weekday between 0 and 6),
  start_time time not null,
  end_time time not null,
  is_available boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (end_time > start_time),
  unique (electrician_profile_id, weekday, start_time, end_time)
);

create index if not exists srk_electrician_availability_lookup_idx
  on public.srk_electrician_availability(electrician_profile_id, weekday)
  where is_available = true;

create table if not exists public.srk_service_hourly_prices (
  id uuid primary key default gen_random_uuid(),
  category_key text not null references public.srk_electrician_categories(category_key),
  duration_hours smallint not null check (duration_hours between 1 and 8),
  labour_amount numeric(10,2) check (labour_amount is null or labour_amount >= 0),
  is_published boolean not null default false,
  updated_by uuid references auth.users(id),
  updated_at timestamptz not null default now(),
  unique (category_key, duration_hours)
);

insert into public.srk_service_hourly_prices(category_key, duration_hours)
select c.category_key, d.duration_hours
from public.srk_electrician_categories c
cross join generate_series(1,8) as d(duration_hours)
on conflict (category_key, duration_hours) do nothing;

alter table public.service_bookings
  add column if not exists electrician_category text references public.srk_electrician_categories(category_key),
  add column if not exists duration_hours smallint check (duration_hours between 1 and 8),
  add column if not exists scheduled_end_at timestamptz,
  add column if not exists visit_started_at timestamptz,
  add column if not exists visit_lat double precision,
  add column if not exists visit_lng double precision,
  add column if not exists visit_fee_amount numeric(10,2) check (visit_fee_amount is null or visit_fee_amount >= 0),
  add column if not exists cancellation_status text not null default 'not_requested'
    check (cancellation_status in ('not_requested','requested','approved','rejected')),
  add column if not exists cancellation_reason text,
  add column if not exists cancellation_approved_by uuid references auth.users(id),
  add column if not exists cancellation_approved_at timestamptz;

create table if not exists public.srk_booking_cancellation_requests (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null references public.service_bookings(id) on delete cascade,
  requested_by_user_id uuid not null references auth.users(id),
  requester_role text not null check (requester_role in ('customer','electrician')),
  reason text not null check (length(btrim(reason)) between 10 and 1500),
  status text not null default 'pending' check (status in ('pending','approved','rejected')),
  admin_note text check (admin_note is null or length(admin_note) <= 1500),
  reviewed_by uuid references auth.users(id),
  reviewed_at timestamptz,
  created_at timestamptz not null default now()
);

create index if not exists srk_cancellation_requests_status_created_idx
  on public.srk_booking_cancellation_requests(status, created_at desc);
create index if not exists srk_cancellation_requests_booking_idx
  on public.srk_booking_cancellation_requests(booking_id, created_at desc);

alter table public.srk_electrician_categories enable row level security;
alter table public.srk_electrician_category_tests enable row level security;
alter table public.srk_electrician_availability enable row level security;
alter table public.srk_service_hourly_prices enable row level security;
alter table public.srk_booking_cancellation_requests enable row level security;

drop policy if exists srk_categories_read_active on public.srk_electrician_categories;
create policy srk_categories_read_active on public.srk_electrician_categories
  for select to anon, authenticated using (is_active or (select public.is_srk_admin()));

drop policy if exists srk_categories_admin_manage on public.srk_electrician_categories;
create policy srk_categories_admin_manage on public.srk_electrician_categories
  for all to authenticated using ((select public.is_srk_admin()))
  with check ((select public.is_srk_admin()));

drop policy if exists srk_category_tests_admin_manage on public.srk_electrician_category_tests;
create policy srk_category_tests_admin_manage on public.srk_electrician_category_tests
  for all to authenticated using ((select public.is_srk_admin()))
  with check ((select public.is_srk_admin()));

drop policy if exists srk_category_tests_electrician_read_own on public.srk_electrician_category_tests;
create policy srk_category_tests_electrician_read_own on public.srk_electrician_category_tests
  for select to authenticated using (
    exists (select 1 from public.electrician_profiles e
      where e.id = electrician_profile_id
        and (e.user_id = (select auth.uid()) or e.auth_user_id = (select auth.uid())))
  );

drop policy if exists srk_availability_electrician_read_own on public.srk_electrician_availability;
create policy srk_availability_electrician_read_own on public.srk_electrician_availability
  for select to authenticated using (
    exists (select 1 from public.electrician_profiles e
      where e.id = electrician_profile_id
        and (e.user_id = (select auth.uid()) or e.auth_user_id = (select auth.uid())))
    or (select public.is_srk_admin())
  );

drop policy if exists srk_availability_electrician_insert_own on public.srk_electrician_availability;
create policy srk_availability_electrician_insert_own on public.srk_electrician_availability
  for insert to authenticated with check (
    exists (select 1 from public.electrician_profiles e
      where e.id = electrician_profile_id
        and (e.user_id = (select auth.uid()) or e.auth_user_id = (select auth.uid())))
    or (select public.is_srk_admin())
  );

drop policy if exists srk_availability_electrician_update_own on public.srk_electrician_availability;
create policy srk_availability_electrician_update_own on public.srk_electrician_availability
  for update to authenticated using (
    exists (select 1 from public.electrician_profiles e
      where e.id = electrician_profile_id
        and (e.user_id = (select auth.uid()) or e.auth_user_id = (select auth.uid())))
    or (select public.is_srk_admin())
  ) with check (
    exists (select 1 from public.electrician_profiles e
      where e.id = electrician_profile_id
        and (e.user_id = (select auth.uid()) or e.auth_user_id = (select auth.uid())))
    or (select public.is_srk_admin())
  );

drop policy if exists srk_availability_admin_delete on public.srk_electrician_availability;
create policy srk_availability_admin_delete on public.srk_electrician_availability
  for delete to authenticated using ((select public.is_srk_admin()));

drop policy if exists srk_hourly_prices_read_published on public.srk_service_hourly_prices;
create policy srk_hourly_prices_read_published on public.srk_service_hourly_prices
  for select to anon, authenticated using (is_published or (select public.is_srk_admin()));

drop policy if exists srk_hourly_prices_admin_manage on public.srk_service_hourly_prices;
create policy srk_hourly_prices_admin_manage on public.srk_service_hourly_prices
  for all to authenticated using ((select public.is_srk_admin()))
  with check ((select public.is_srk_admin()));

drop policy if exists srk_cancellation_requests_read_parties_admin on public.srk_booking_cancellation_requests;
create policy srk_cancellation_requests_read_parties_admin on public.srk_booking_cancellation_requests
  for select to authenticated using (
    (select public.is_srk_admin())
    or requested_by_user_id = (select auth.uid())
    or exists (
      select 1 from public.service_bookings b
      join public.electrician_profiles e on e.id = b.assigned_electrician_id
      where b.id = booking_id
        and (e.user_id = (select auth.uid()) or e.auth_user_id = (select auth.uid()))
    )
  );

drop policy if exists srk_cancellation_requests_submit_own on public.srk_booking_cancellation_requests;
create policy srk_cancellation_requests_submit_own on public.srk_booking_cancellation_requests
  for insert to authenticated with check (
    requested_by_user_id = (select auth.uid())
    and (
      (requester_role = 'customer' and exists (
        select 1 from public.service_bookings b
        where b.id = booking_id and b.customer_user_id = (select auth.uid())
      ))
      or
      (requester_role = 'electrician' and exists (
        select 1 from public.service_bookings b
        join public.electrician_profiles e on e.id = b.assigned_electrician_id
        where b.id = booking_id
          and (e.user_id = (select auth.uid()) or e.auth_user_id = (select auth.uid()))
      ))
    )
  );

drop policy if exists srk_cancellation_requests_admin_review on public.srk_booking_cancellation_requests;
create policy srk_cancellation_requests_admin_review on public.srk_booking_cancellation_requests
  for update to authenticated using ((select public.is_srk_admin()))
  with check ((select public.is_srk_admin()));

grant select on public.srk_electrician_categories to anon, authenticated;
grant select, insert, update, delete on public.srk_electrician_categories to authenticated;
grant select on public.srk_service_hourly_prices to anon, authenticated;
grant select, insert, update, delete on public.srk_service_hourly_prices to authenticated;
grant select, insert, update, delete on public.srk_electrician_availability to authenticated;
grant select, insert, update on public.srk_electrician_category_tests to authenticated;
grant select, insert, update on public.srk_booking_cancellation_requests to authenticated;
