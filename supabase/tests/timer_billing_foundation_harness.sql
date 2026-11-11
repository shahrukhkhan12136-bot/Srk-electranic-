-- Disposable PostgreSQL harness for the additive timer-billing foundation migration.
-- This is intentionally a minimal synthetic baseline, NOT a replica of Production.
-- Run only in an ephemeral PostgreSQL database (GitHub Actions service container).

do $roles$
begin
  if not exists (select 1 from pg_roles where rolname = 'anon') then create role anon nologin; end if;
  if not exists (select 1 from pg_roles where rolname = 'authenticated') then create role authenticated nologin; end if;
  if not exists (select 1 from pg_roles where rolname = 'service_role') then create role service_role nologin; end if;
end
$roles$;

create schema if not exists auth;
create table if not exists auth.users (
  id uuid primary key,
  phone text
);

create or replace function auth.jwt()
returns jsonb
language sql
stable
as $function$
  select coalesce(nullif(current_setting('request.jwt.claims', true), '')::jsonb, '{}'::jsonb)
$function$;

create or replace function auth.uid()
returns uuid
language sql
stable
as $function$
  select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid
$function$;

create table if not exists public.service_bookings (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz default now(),
  customer_name text not null default '',
  phone text not null default '',
  state text not null default '',
  district text not null default '',
  pincode text not null default '',
  address text not null default '',
  service_type text not null default '',
  preferred_date date,
  preferred_time time,
  work_details text,
  payment_method text not null default 'Cash',
  quoted_amount numeric,
  status text not null default 'new',
  assigned_electrician_id uuid,
  commission_rate numeric not null default 15,
  commission_amount numeric,
  payment_status text not null default 'unpaid',
  razorpay_order_id text,
  razorpay_payment_id text,
  payment_verified_at timestamptz,
  amount_paid numeric,
  customer_user_id uuid,
  location_lat double precision,
  location_lng double precision,
  service_charge numeric,
  materials_amount numeric not null default 0,
  quote_status text not null default 'not_submitted',
  quote_note text,
  quote_submitted_at timestamptz,
  quote_responded_at timestamptz,
  work_started_at timestamptz,
  customer_suggested_amount numeric,
  electrician_quote_kind text
);

create table if not exists public.electrician_profiles (
  id uuid primary key,
  user_id uuid,
  auth_user_id uuid,
  active boolean not null default true,
  verification_status text not null default 'approved'
);

create table if not exists public.job_offers (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null references public.service_bookings(id),
  electrician_id uuid not null references public.electrician_profiles(id),
  status text not null
);

-- Prove that the migration's reverse FK and the bill->booking FK can coexist:
-- insert booking, insert bill referencing booking, then link booking to bill.


-- Test-only Admin predicate. Production already has its own secured helper.
create or replace function public.is_srk_admin()
returns boolean
language sql
stable
as $function$
  select false
$function$;


-- Synthetic broadcast trigger: enabled only by explicit test flag, so existing
-- timer assertions retain their own offer fixtures.
create or replace function public.test_broadcast_new_booking()
returns trigger
language plpgsql
as $function$
begin
  if current_setting('test.broadcast_new_booking', true) = 'on' then
    insert into public.job_offers(booking_id,electrician_id,status)
    select new.id, ep.id, 'pending'
    from public.electrician_profiles ep
    where ep.active=true and ep.verification_status='approved';
  end if;
  return new;
end
$function$;

drop trigger if exists test_broadcast_new_booking on public.service_bookings;
create trigger test_broadcast_new_booking
after insert on public.service_bookings
for each row execute function public.test_broadcast_new_booking();

-- Representative Production legacy record: completed but unpaid, with an
-- approved quote and assigned electrician. It must remain historical/legacy
-- after timer billing migrations; it must not be silently marked paid or
-- receive a timer bill, payable snapshot, or commission payout.
insert into public.electrician_profiles(id,active,verification_status)
values ('21000000-0000-4000-8000-000000000001',false,'approved');

insert into public.service_bookings(
  id,customer_name,phone,state,district,pincode,address,service_type,
  payment_method,quoted_amount,status,assigned_electrician_id,
  commission_rate,payment_status,service_charge,materials_amount,quote_status,
  work_started_at
) values (
  '11000000-0000-4000-8000-000000000001',
  'Legacy preservation fixture','9000000000','Uttar Pradesh','Balrampur',
  '271861','Test address','Electrical repair','Razorpay ऑनलाइन भुगतान',
  20,'completed','21000000-0000-4000-8000-000000000001',
  15,'unpaid',10,10,'approved',now()
);

insert into public.job_offers(booking_id,electrician_id,status)
values (
  '11000000-0000-4000-8000-000000000001',
  '21000000-0000-4000-8000-000000000001',
  'accepted'
);

