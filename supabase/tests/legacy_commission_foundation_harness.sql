-- Minimal legacy commission objects needed to test additive timer integration.
-- Disposable CI database only; this is not a Production schema migration.
begin;

alter table public.electrician_profiles
  add column if not exists display_name text;

create table if not exists public.srk_electrician_payouts (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null unique references public.service_bookings(id) on delete restrict,
  electrician_profile_id uuid not null references public.electrician_profiles(id) on delete restrict,
  razorpay_payment_id text,
  gross_service_amount numeric(12,2) not null check (gross_service_amount >= 0),
  materials_amount numeric(12,2) not null check (materials_amount >= 0),
  platform_commission numeric(12,2) not null check (platform_commission >= 0),
  electrician_payable numeric(12,2) not null check (electrician_payable >= 0),
  payout_status text not null default 'pending'
    check (payout_status in ('pending','paid','blocked','refunded')),
  payout_method text check (payout_method in ('upi','bank')),
  payout_reference text,
  payout_note text,
  paid_by uuid references auth.users(id),
  paid_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint srk_payout_paid_fields_check check (
    payout_status <> 'paid' or
    (payout_method is not null and payout_reference is not null
     and length(btrim(payout_reference)) >= 4 and paid_at is not null and paid_by is not null)
  )
);

commit;
