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
  add column if not exists work_completed_at timestamptz,
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

-- Admin-approved starter labour rates (materials/parts are always billed separately).
-- These 32 prices are published for customer display; Admin can revise them later.
insert into public.srk_service_hourly_prices
  (category_key, duration_hours, labour_amount, is_published)
values
  ('helper',1,149,true),('helper',2,249,true),('helper',3,349,true),('helper',4,449,true),
  ('helper',5,549,true),('helper',6,649,true),('helper',7,749,true),('helper',8,849,true),
  ('standard',1,199,true),('standard',2,349,true),('standard',3,499,true),('standard',4,649,true),
  ('standard',5,799,true),('standard',6,949,true),('standard',7,1099,true),('standard',8,1249,true),
  ('experienced',1,249,true),('experienced',2,449,true),('experienced',3,649,true),('experienced',4,849,true),
  ('experienced',5,1049,true),('experienced',6,1249,true),('experienced',7,1449,true),('experienced',8,1649,true),
  ('master',1,299,true),('master',2,549,true),('master',3,799,true),('master',4,999,true),
  ('master',5,1249,true),('master',6,1499,true),('master',7,1749,true),('master',8,1999,true)
on conflict (category_key, duration_hours) do update set
  labour_amount = excluded.labour_amount,
  is_published = excluded.is_published,
  updated_at = now();


-- Server-authoritative work timer and prorated labour calculation.
alter table public.service_bookings
  add column if not exists actual_work_minutes integer
    check (actual_work_minutes is null or actual_work_minutes >= 0),
  add column if not exists actual_labour_amount numeric(10,2)
    check (actual_labour_amount is null or actual_labour_amount >= 0);

create or replace function public.srk_get_my_work_timer(p_booking_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = pg_catalog, public, auth, pg_temp
as $function$
declare
  v_profile_id uuid;
  v_booking public.service_bookings%rowtype;
  v_base_amount numeric(10,2);
  v_elapsed_seconds numeric;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;

  select id into v_profile_id
    from public.electrician_profiles
   where (user_id = auth.uid() or auth_user_id = auth.uid())
     and verification_status = 'approved' and active = true
   order by created_at desc limit 1;

  if v_profile_id is null then raise exception 'Approved active electrician required'; end if;

  select * into v_booking
    from public.service_bookings
   where id = p_booking_id and assigned_electrician_id = v_profile_id
   ;

  if not found then raise exception 'Assigned booking not found'; end if;
  if v_booking.status <> 'in_progress' or v_booking.work_started_at is null then
    raise exception 'Work timer is not running';
  end if;

  if v_booking.electrician_category is not null and v_booking.duration_hours is not null then
    select labour_amount into v_base_amount
      from public.srk_service_hourly_prices
     where category_key = v_booking.electrician_category
       and duration_hours = v_booking.duration_hours
       and is_published = true;
  end if;

  if v_base_amount is null then
    v_base_amount := coalesce(v_booking.service_charge, v_booking.quoted_amount, 0);
  end if;

  v_elapsed_seconds := greatest(0, extract(epoch from (coalesce(v_booking.work_completed_at, statement_timestamp()) - v_booking.work_started_at)));

  return jsonb_build_object(
    'booking_id', v_booking.id,
    'work_started_at', v_booking.work_started_at,
    'elapsed_seconds', floor(v_elapsed_seconds)::bigint,
    'elapsed_minutes', ceil(v_elapsed_seconds / 60.0)::integer,
    'duration_hours', v_booking.duration_hours,
    'category_key', v_booking.electrician_category,
    'booked_labour_amount', round(v_base_amount, 2),
    'estimated_labour_amount',
      case
        when v_booking.electrician_category is not null and v_booking.duration_hours is not null
          then round(v_base_amount * ceil(v_elapsed_seconds / 60.0) / (v_booking.duration_hours * 60.0), 2)
        else round(v_base_amount, 2)
      end
  );
end;
$function$;

create or replace function public.srk_update_booking_work_status(p_booking_id uuid, p_status text)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, auth, pg_temp
as $function$
declare
  v_profile_id uuid;
  v_booking public.service_bookings%rowtype;
  v_base_amount numeric(10,2);
  v_elapsed_seconds numeric;
  v_actual_minutes integer;
  v_actual_labour numeric(10,2);
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if p_status not in ('inspection','in_progress','completed') then raise exception 'Invalid work status'; end if;

  select id into v_profile_id
    from public.electrician_profiles
   where (user_id = auth.uid() or auth_user_id = auth.uid())
     and verification_status = 'approved' and active = true
   order by created_at desc limit 1;

  if v_profile_id is null then raise exception 'Approved active electrician required'; end if;

  select * into v_booking
    from public.service_bookings
   where id = p_booking_id and assigned_electrician_id = v_profile_id
   for update;

  if not found then raise exception 'Assigned booking not found'; end if;

  if p_status = 'inspection' and v_booking.status = 'assigned' then
    update public.service_bookings set status = 'inspection' where id = p_booking_id;

  elsif p_status = 'in_progress'
        and v_booking.status = 'quote_approved'
        and v_booking.quote_status = 'approved'
        and v_booking.work_started_at is null then
    update public.service_bookings
       set status = 'in_progress', work_started_at = statement_timestamp()
     where id = p_booking_id;

  elsif p_status = 'completed'
        and v_booking.status = 'in_progress'
        and v_booking.work_started_at is not null
        and v_booking.work_completed_at is null then

    v_elapsed_seconds := greatest(0, extract(epoch from (statement_timestamp() - v_booking.work_started_at)));
    v_actual_minutes := ceil(v_elapsed_seconds / 60.0)::integer;

    if v_booking.electrician_category is not null and v_booking.duration_hours is not null then
      select labour_amount into v_base_amount
        from public.srk_service_hourly_prices
       where category_key = v_booking.electrician_category
         and duration_hours = v_booking.duration_hours
         and is_published = true;

      if v_base_amount is null then
        raise exception 'Published labour price not found for this category and duration';
      end if;

      v_actual_labour := round(
        v_base_amount * v_actual_minutes / (v_booking.duration_hours * 60.0), 2
      );
    else
      -- Legacy bookings without category/duration retain their already-approved quote.
      v_actual_labour := round(coalesce(v_booking.service_charge, 0), 2);
    end if;

    update public.service_bookings
       set status = 'completed',
           work_completed_at = statement_timestamp(),
           actual_work_minutes = v_actual_minutes,
           actual_labour_amount = v_actual_labour,
           service_charge = v_actual_labour,
           quoted_amount = round(v_actual_labour + coalesce(v_booking.materials_amount, 0), 2)
     where id = p_booking_id;

  else
    raise exception 'Invalid booking status transition';
  end if;

  return jsonb_build_object(
    'success', true,
    'status', p_status,
    'actual_work_minutes', case when p_status = 'completed' then v_actual_minutes else null end,
    'actual_labour_amount', case when p_status = 'completed' then v_actual_labour else null end
  );
end;
$function$;

revoke all on function public.srk_get_my_work_timer(uuid) from public, anon;
grant execute on function public.srk_get_my_work_timer(uuid) to authenticated;
revoke all on function public.srk_update_booking_work_status(uuid, text) from public, anon;
grant execute on function public.srk_update_booking_work_status(uuid, text) to authenticated;
