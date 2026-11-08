-- SRK ELECTRONIC marketplace starter schema (Supabase / PostgreSQL)
-- Run in Supabase SQL Editor. Public website forms must only INSERT; never expose service-role keys.
create extension if not exists pgcrypto;

create table if not exists public.service_bookings (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  customer_name text not null,
  phone text not null check (phone ~ '^[0-9]{10}$'),
  state text not null,
  district text not null,
  pincode text not null check (pincode ~ '^[0-9]{6}$'),
  address text not null,
  service_type text not null,
  preferred_date date,
  preferred_time time,
  work_details text,
  payment_method text not null default 'Cash',
  quoted_amount numeric(12,2) check (quoted_amount is null or quoted_amount >= 0),
  status text not null default 'new' check (status in ('new','confirmed','assigned','in_progress','completed','cancelled')),
  assigned_electrician_id uuid,
  commission_rate numeric(5,2) not null default 15.00 check (commission_rate between 0 and 100),
  commission_amount numeric(12,2),
  payment_status text not null default 'unpaid' check (payment_status in ('unpaid','pending','paid','refunded','failed')),
  razorpay_order_id text unique,
  razorpay_payment_id text unique,
  payment_verified_at timestamptz
);

create table if not exists public.electrician_applications (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  full_name text not null,
  phone text not null check (phone ~ '^[0-9]{10}$'),
  state text not null,
  district text not null,
  pincode text not null check (pincode ~ '^[0-9]{6}$'),
  skills text not null,
  experience_years integer not null default 0 check (experience_years between 0 and 60),
  about text,
  verification_status text not null default 'pending' check (verification_status in ('pending','approved','rejected','suspended')),
  active boolean not null default false
);

create table if not exists public.electrician_profiles (
  id uuid primary key default gen_random_uuid(),
  application_id uuid unique references public.electrician_applications(id),
  display_name text not null,
  phone text not null check (phone ~ '^[0-9]{10}$'),
  state text not null,
  district text not null,
  pincode text not null check (pincode ~ '^[0-9]{6}$'),
  skills text[] not null default '{}',
  active boolean not null default false,
  created_at timestamptz not null default now()
);

create index if not exists bookings_location_status_idx on public.service_bookings(state, district, pincode, status);
create index if not exists electrician_location_active_idx on public.electrician_profiles(state, district, pincode, active);

alter table public.service_bookings enable row level security;
alter table public.electrician_applications enable row level security;
alter table public.electrician_profiles enable row level security;

-- Website visitors may submit a request. They cannot read, edit, or delete customer/provider records.
drop policy if exists "public can submit bookings" on public.service_bookings;
create policy "public can submit bookings" on public.service_bookings for insert to anon, authenticated with check (true);
drop policy if exists "public can apply as electrician" on public.electrician_applications;
create policy "public can apply as electrician" on public.electrician_applications for insert to anon, authenticated with check (true);

-- Do not create public SELECT policies. Admin access should be implemented with Supabase Auth
-- and a server-side role check / service-role Netlify Function. Never put service-role key in browser.

-- Job broadcast queue: every matching approved/active electrician gets an offer row.
alter table public.electrician_profiles
  add column if not exists verification_status text not null default 'pending'
  check (verification_status in ('pending','approved','rejected','suspended'));

create table if not exists public.job_offers (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null references public.service_bookings(id) on delete cascade,
  electrician_id uuid not null references public.electrician_profiles(id) on delete cascade,
  status text not null default 'offered' check (status in ('offered','accepted','declined','expired','cancelled')),
  match_level text not null default 'pincode' check (match_level in ('pincode','district')),
  created_at timestamptz not null default now(),
  responded_at timestamptz,
  unique (booking_id, electrician_id)
);
create index if not exists job_offers_provider_status_idx on public.job_offers(electrician_id, status, created_at desc);
create index if not exists job_offers_booking_idx on public.job_offers(booking_id, created_at desc);
alter table public.job_offers enable row level security;
-- No public read/write policies: all offer creation and access must go through authenticated server functions.
