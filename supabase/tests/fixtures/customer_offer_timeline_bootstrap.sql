-- Disposable minimal baseline for Customer Offer Timeline pgTAP.
-- Runs only inside a fresh local Supabase stack; contains synthetic IDs/data.
create table public.service_bookings (
  id uuid primary key,
  customer_user_id uuid not null
);

create table public.electrician_profiles (
  id uuid primary key
);

create table public.job_offers (
  id uuid primary key,
  booking_id uuid not null references public.service_bookings(id) on delete cascade,
  electrician_id uuid not null references public.electrician_profiles(id),
  status text not null default 'offered'
    check (status in ('offered','accepted','declined','expired','cancelled')),
  match_level text not null default 'pincode'
    check (match_level in ('pincode','district')),
  created_at timestamptz not null default now(),
  responded_at timestamptz
);

create or replace function public.is_srk_admin()
returns boolean
language sql
stable
as $function$ select false; $function$;

insert into public.service_bookings (id,customer_user_id) values
  ('10000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001'),
  ('10000000-0000-4000-8000-000000000002','20000000-0000-4000-8000-000000000002');

insert into public.electrician_profiles (id) values
  ('30000000-0000-4000-8000-000000000001'),
  ('30000000-0000-4000-8000-000000000002');

-- These legacy rows exist before the feature migration to exercise its backfill.
insert into public.job_offers (id,booking_id,electrician_id,status,created_at,responded_at) values
  ('40000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000001','30000000-0000-4000-8000-000000000001','accepted','2026-11-01T10:00:00Z','2026-11-01T10:05:00Z'),
  ('40000000-0000-4000-8000-000000000002','10000000-0000-4000-8000-000000000002','30000000-0000-4000-8000-000000000002','declined','2026-11-02T10:00:00Z','2026-11-02T10:05:00Z');
