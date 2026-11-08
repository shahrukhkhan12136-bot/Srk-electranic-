create table if not exists public.srk_route_transfers (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null references public.service_bookings(id) on delete restrict,
  razorpay_payment_id text not null,
  recipient_type text not null check (recipient_type in ('electrician','platform_commission')),
  recipient_user_id uuid null references auth.users(id) on delete restrict,
  linked_account_id text null,
  transfer_id text null unique,
  idempotency_key text not null unique,
  amount_paise bigint not null check (amount_paise > 0),
  currency text not null default 'INR' check (currency = 'INR'),
  transfer_status text not null default 'not_created'
    check (transfer_status in ('not_created','created','pending','processed','failed','reversed','partially_reversed','manual_review')),
  settlement_status text not null default 'not_settled'
    check (settlement_status in ('not_settled','pending','on_hold','settled','reversed')),
  error_code text null,
  error_message text null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint srk_route_transfers_payment_recipient_uniq unique (razorpay_payment_id, recipient_type),
  constraint srk_route_transfers_recipient_check check (
    (recipient_type = 'electrician' and recipient_user_id is not null)
    or (recipient_type = 'platform_commission' and recipient_user_id is null)
  )
);
create index if not exists srk_route_transfers_booking_idx
  on public.srk_route_transfers (booking_id, created_at desc);
create index if not exists srk_route_transfers_status_idx
  on public.srk_route_transfers (transfer_status, settlement_status);
alter table public.srk_route_transfers enable row level security;
revoke all on table public.srk_route_transfers from anon, authenticated;
grant select, insert, update on table public.srk_route_transfers to service_role;
comment on table public.srk_route_transfers is
  'Server-only reconciliation ledger for Razorpay Route split transfers. No money movement is triggered by database writes.';
