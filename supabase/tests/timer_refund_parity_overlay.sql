-- Disposable-only overlay for exercising the real refund migrations after the Timer
-- release chain has been replayed on the Production-shaped parity fixture.
-- This supplies only the legacy refund-ledger tables not part of the Timer chain.
create table public.srk_razorpay_refunds (
 id uuid primary key default gen_random_uuid(),
 booking_id uuid not null unique references public.service_bookings(id) on delete restrict,
 payment_id text not null,
 refund_id text unique,
 amount numeric(12,2) not null,
 amount_paise bigint not null,
 currency text not null default 'INR',
 idempotency_key text not null unique,
 status text not null default 'requested',
 provider_status text,
 reason text not null,
 admin_user_id uuid not null references auth.users(id),
 previous_payout_note text,
 last_error text,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(),
 processed_at timestamptz
);
alter table public.srk_razorpay_refunds enable row level security;
revoke all on public.srk_razorpay_refunds from public,anon,authenticated;
grant all on public.srk_razorpay_refunds to service_role;

create table public.srk_manual_refund_entries (
 id uuid primary key default gen_random_uuid(),
 booking_id uuid not null unique references public.service_bookings(id) on delete restrict,
 payment_entry_id uuid not null unique references public.srk_manual_payment_entries(id) on delete restrict,
 amount numeric(12,2) not null,
 refund_reference text not null,
 note text,
 recorded_by uuid not null references auth.users(id),
 recorded_at timestamptz not null default now()
);
alter table public.srk_manual_refund_entries enable row level security;
revoke all on public.srk_manual_refund_entries from public,anon,authenticated;
grant all on public.srk_manual_refund_entries to service_role;
