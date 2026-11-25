
create table if not exists public.srk_booking_final_bills (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null unique references public.service_bookings(id) on delete restrict,
  bill_number text unique,
  service_amount numeric(12,2) not null default 0,
  materials_amount numeric(12,2) not null default 0,
  discount_amount numeric(12,2) not null default 0,
  tax_amount numeric(12,2) not null default 0,
  total_amount numeric(12,2) generated always as (service_amount + materials_amount - discount_amount + tax_amount) stored,
  status text not null default 'draft',
  prepared_at timestamptz,
  approved_at timestamptz,
  approved_by uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint srk_final_bill_amounts_nonnegative check (
    service_amount >= 0 and materials_amount >= 0 and discount_amount >= 0 and tax_amount >= 0
  ),
  constraint srk_final_bill_discount_cap check (discount_amount <= service_amount + materials_amount),
  constraint srk_final_bill_status_valid check (status in ('draft','issued','approved','disputed','void'))
);

create table if not exists public.srk_booking_final_bill_items (
  id uuid primary key default gen_random_uuid(),
  bill_id uuid not null references public.srk_booking_final_bills(id) on delete restrict,
  item_type text not null,
  description text not null,
  quantity numeric(10,2) not null default 1,
  unit text not null default 'unit',
  unit_price numeric(12,2) not null,
  line_total numeric(12,2) generated always as (quantity * unit_price) stored,
  created_at timestamptz not null default now(),
  constraint srk_bill_item_type_valid check (item_type in ('service','labour','material','discount','other')),
  constraint srk_bill_item_quantity_valid check (quantity > 0),
  constraint srk_bill_item_price_valid check (unit_price >= 0)
);

create table if not exists public.srk_worker_earnings (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null references public.service_bookings(id) on delete restrict,
  booking_worker_id uuid not null unique references public.srk_booking_workers(id) on delete restrict,
  worker_id uuid not null references public.srk_worker_profiles(id) on delete restrict,
  worker_role text not null,
  bill_id uuid references public.srk_booking_final_bills(id) on delete restrict,
  billable_seconds bigint not null default 0,
  gross_service_earning numeric(12,2) not null,
  company_commission_rate numeric(5,2) not null default 15.00,
  company_commission numeric(12,2) not null,
  net_earning numeric(12,2) not null,
  payout_status text not null default 'pending',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint srk_worker_earning_role_valid check (worker_role in ('technician','helper')),
  constraint srk_worker_earning_seconds_valid check (billable_seconds between 0 and 5184000),
  constraint srk_worker_earning_commission_valid check (company_commission_rate=15.00),
  constraint srk_worker_earning_amounts_valid check (
    gross_service_earning >= 0 and company_commission >= 0 and net_earning >= 0
    and company_commission <= gross_service_earning
    and net_earning = gross_service_earning - company_commission
  ),
  constraint srk_worker_earning_payout_status_valid check (payout_status in ('pending','available','partially_paid','paid','held','adjusted'))
);

create table if not exists public.srk_worker_wallet_ledger (
  id uuid primary key default gen_random_uuid(),
  worker_id uuid not null references public.srk_worker_profiles(id) on delete restrict,
  booking_id uuid references public.service_bookings(id) on delete restrict,
  earning_id uuid references public.srk_worker_earnings(id) on delete restrict,
  entry_type text not null,
  amount numeric(12,2) not null,
  balance_effect numeric(12,2) not null,
  description text,
  reference_id text,
  idempotency_key text not null unique,
  created_at timestamptz not null default now(),
  constraint srk_worker_wallet_entry_type_valid check (
    entry_type in ('earning','commission','cash_commission_due','payout_requested','payout_paid','refund_adjustment','admin_adjustment','hold','release')
  )
);

create index if not exists srk_worker_wallet_ledger_worker_time_idx
  on public.srk_worker_wallet_ledger(worker_id,created_at desc);

create table if not exists public.srk_worker_payout_requests (
  id uuid primary key default gen_random_uuid(),
  payout_code text unique,
  worker_id uuid not null references public.srk_worker_profiles(id) on delete restrict,
  requested_amount numeric(12,2) not null,
  approved_amount numeric(12,2),
  status text not null default 'requested',
  payment_method text,
  payment_reference text,
  admin_note text,
  requested_at timestamptz not null default now(),
  reviewed_at timestamptz,
  paid_at timestamptz,
  reviewed_by uuid,
  constraint srk_worker_payout_amount_valid check (requested_amount > 0 and (approved_amount is null or approved_amount > 0)),
  constraint srk_worker_payout_status_valid check (status in ('requested','under_review','approved','rejected','paid','failed','cancelled')),
  constraint srk_worker_payout_method_valid check (payment_method is null or payment_method in ('upi','bank_transfer','phonepe','other'))
);

create index if not exists srk_worker_payout_worker_status_idx
  on public.srk_worker_payout_requests(worker_id,status,requested_at desc);

create table if not exists public.srk_technician_booking_cycle (
  technician_id uuid primary key references public.srk_worker_profiles(id) on delete restrict,
  completed_booking_count bigint not null default 0,
  last_completed_at timestamptz,
  updated_at timestamptz not null default now(),
  constraint srk_technician_cycle_count_nonnegative check (completed_booking_count >= 0)
);

create table if not exists public.srk_technician_booking_sequence (
  id uuid primary key default gen_random_uuid(),
  technician_id uuid not null references public.srk_worker_profiles(id) on delete restrict,
  booking_id uuid not null references public.service_bookings(id) on delete restrict,
  sequence_number bigint not null,
  payment_method text,
  completed_at timestamptz not null default now(),
  constraint srk_technician_booking_sequence_unique unique(technician_id,sequence_number),
  constraint srk_technician_booking_once unique(technician_id,booking_id),
  constraint srk_technician_cycle_payment_method check (payment_method is null or payment_method in ('cash','online'))
);

create table if not exists public.srk_booking_payment_evidence (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null references public.service_bookings(id) on delete restrict,
  submitted_by uuid not null,
  payer_role text not null,
  payment_method text not null,
  amount numeric(12,2) not null,
  reference_number text,
  evidence_storage_path text,
  verification_status text not null default 'pending',
  verified_by uuid,
  verified_at timestamptz,
  note text,
  created_at timestamptz not null default now(),
  constraint srk_payment_evidence_role_valid check (payer_role in ('customer','technician','helper','admin')),
  constraint srk_payment_evidence_method_valid check (payment_method in ('cash','upi','card','online','bank_transfer')),
  constraint srk_payment_evidence_amount_valid check (amount > 0),
  constraint srk_payment_evidence_status_valid check (verification_status in ('pending','verified','rejected','disputed'))
);

create index if not exists srk_booking_payment_evidence_booking_idx
  on public.srk_booking_payment_evidence(booking_id,created_at desc);

create table if not exists public.srk_booking_payment_disputes (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null references public.service_bookings(id) on delete restrict,
  raised_by uuid not null,
  raised_by_role text not null,
  dispute_type text not null,
  description text not null,
  status text not null default 'open',
  assigned_admin uuid,
  resolution text,
  resolved_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint srk_payment_dispute_role_valid check (raised_by_role in ('customer','technician','helper')),
  constraint srk_payment_dispute_type_valid check (dispute_type in ('not_paid','cash_not_received','amount_mismatch','online_payment_failed','refund_delay','other')),
  constraint srk_payment_dispute_status_valid check (status in ('open','under_review','awaiting_evidence','resolved','rejected'))
);

create index if not exists srk_booking_payment_disputes_status_idx
  on public.srk_booking_payment_disputes(status,created_at desc);

create table if not exists public.srk_booking_admin_changes (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid references public.service_bookings(id) on delete restrict,
  admin_user_id uuid not null,
  entity_type text not null,
  entity_id uuid,
  action text not null,
  reason text not null,
  old_values jsonb,
  new_values jsonb,
  created_at timestamptz not null default now()
);

create index if not exists srk_booking_admin_changes_booking_idx
  on public.srk_booking_admin_changes(booking_id,created_at desc);

alter table public.srk_booking_final_bills enable row level security;
alter table public.srk_booking_final_bill_items enable row level security;
alter table public.srk_worker_earnings enable row level security;
alter table public.srk_worker_wallet_ledger enable row level security;
alter table public.srk_worker_payout_requests enable row level security;
alter table public.srk_technician_booking_cycle enable row level security;
alter table public.srk_technician_booking_sequence enable row level security;
alter table public.srk_booking_payment_evidence enable row level security;
alter table public.srk_booking_payment_disputes enable row level security;
alter table public.srk_booking_admin_changes enable row level security;
