
create table if not exists public.srk_razorpay_settlements (
  id uuid primary key default gen_random_uuid(),
  razorpay_settlement_id text not null unique check (length(razorpay_settlement_id) between 6 and 100),
  settlement_status text not null check (settlement_status in ('created','processed','failed','reversed','unknown')),
  currency text not null default 'INR' check (currency = 'INR'),
  gross_amount_paise bigint not null check (gross_amount_paise >= 0),
  fee_amount_paise bigint not null default 0 check (fee_amount_paise >= 0),
  tax_amount_paise bigint not null default 0 check (tax_amount_paise >= 0),
  adjustment_amount_paise bigint not null default 0,
  provider_net_amount_paise bigint check (provider_net_amount_paise is null or provider_net_amount_paise >= 0),
  utr text,
  provider_created_at timestamptz,
  provider_processed_at timestamptz,
  bank_credit_amount_paise bigint check (bank_credit_amount_paise is null or bank_credit_amount_paise >= 0),
  bank_credit_at timestamptz,
  bank_reference text,
  reconciliation_status text not null default 'pending' check (reconciliation_status in ('pending','matched','mismatch','under_review')),
  reconciliation_note text,
  source text not null default 'dashboard' check (source in ('dashboard','webhook','api','report_import','admin_entry')),
  provider_payload jsonb not null default '{}'::jsonb,
  recorded_by uuid references auth.users(id) on delete set null,
  verified_by uuid references auth.users(id) on delete set null,
  verified_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check ((reconciliation_status <> 'matched') or
    (bank_credit_amount_paise is not null and bank_credit_at is not null))
);

create index if not exists srk_razorpay_settlements_status_date_idx
  on public.srk_razorpay_settlements (settlement_status, provider_processed_at desc);
create index if not exists srk_razorpay_settlements_recon_idx
  on public.srk_razorpay_settlements (reconciliation_status, created_at desc);

create table if not exists public.srk_razorpay_settlement_items (
  id uuid primary key default gen_random_uuid(),
  settlement_id uuid not null references public.srk_razorpay_settlements(id) on delete restrict,
  item_type text not null check (item_type in ('payment','refund','fee','tax','adjustment','other')),
  provider_reference text not null check (length(provider_reference) between 1 and 150),
  booking_id uuid references public.service_bookings(id) on delete restrict,
  booking_transaction_id uuid references public.srk_booking_transactions(id) on delete restrict,
  amount_paise bigint not null,
  currency text not null default 'INR' check (currency = 'INR'),
  item_note text,
  provider_item jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  unique (settlement_id, item_type, provider_reference)
);

create index if not exists srk_razorpay_settlement_items_booking_idx
  on public.srk_razorpay_settlement_items (booking_id);
create index if not exists srk_razorpay_settlement_items_transaction_idx
  on public.srk_razorpay_settlement_items (booking_transaction_id);

alter table public.srk_razorpay_settlements enable row level security;
alter table public.srk_razorpay_settlement_items enable row level security;

revoke all on public.srk_razorpay_settlements from public, anon, authenticated;
revoke all on public.srk_razorpay_settlement_items from public, anon, authenticated;
grant select on public.srk_razorpay_settlements to authenticated;
grant select on public.srk_razorpay_settlement_items to authenticated;
grant select, insert, update on public.srk_razorpay_settlements to service_role;
grant select, insert, update on public.srk_razorpay_settlement_items to service_role;

drop policy if exists srk_razorpay_settlements_admin_read on public.srk_razorpay_settlements;
create policy srk_razorpay_settlements_admin_read
  on public.srk_razorpay_settlements for select to authenticated
  using (public.srk_has_admin_permission('payments.read'));

drop policy if exists srk_razorpay_settlement_items_admin_read on public.srk_razorpay_settlement_items;
create policy srk_razorpay_settlement_items_admin_read
  on public.srk_razorpay_settlement_items for select to authenticated
  using (public.srk_has_admin_permission('payments.read'));

comment on table public.srk_razorpay_settlements is
  'Razorpay merchant-account settlement reconciliation only. No Route transfers or worker split payouts. Provider fees/tax, provider net and actual bank credit are recorded separately.';
comment on table public.srk_razorpay_settlement_items is
  'Line items included in a Razorpay merchant settlement (payments, refunds, fees, taxes and adjustments), for reconciliation to SRK booking transactions.';
