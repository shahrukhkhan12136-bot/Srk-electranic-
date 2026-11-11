-- SRK ELECTRONIC: additive foundation for customer-approved timer billing.
-- IMPORTANT: Feature-branch source only. Do not apply to Production.
-- RPCs, immutable-write guards and API/UI cutover are intentionally separate follow-up work.

begin;

alter table public.service_bookings
  add column if not exists service_category_code text,
  add column if not exists service_category_label text,
  add column if not exists hourly_rate_snapshot numeric(12,6),
  add column if not exists electrician_arrived_at timestamptz,
  add column if not exists electrician_arrived_by uuid references auth.users(id) on delete set null,
  add column if not exists timer_state text not null default 'not_requested',
  add column if not exists timer_started_at timestamptz,
  add column if not exists timer_start_approved_at timestamptz,
  add column if not exists timer_stop_requested_at timestamptz,
  add column if not exists timer_stopped_at timestamptz,
  add column if not exists timer_stop_approved_at timestamptz,
  add column if not exists timer_elapsed_seconds bigint,
  add column if not exists timer_billable_minutes bigint,
  add column if not exists final_bill_id uuid;

do $migration$
begin
  if not exists (select 1 from pg_constraint where conrelid = 'public.service_bookings'::regclass and conname = 'service_bookings_service_category_code_check') then
    alter table public.service_bookings add constraint service_bookings_service_category_code_check
      check (service_category_code is null or service_category_code in ('helper','ordinary','skilled','master'));
  end if;
  if not exists (select 1 from pg_constraint where conrelid = 'public.service_bookings'::regclass and conname = 'service_bookings_hourly_rate_snapshot_check') then
    alter table public.service_bookings add constraint service_bookings_hourly_rate_snapshot_check
      check (hourly_rate_snapshot is null or hourly_rate_snapshot > 0);
  end if;
  if not exists (select 1 from pg_constraint where conrelid = 'public.service_bookings'::regclass and conname = 'service_bookings_timer_state_check') then
    alter table public.service_bookings add constraint service_bookings_timer_state_check
      check (timer_state in ('not_requested','start_pending','running','stop_pending','stopped'));
  end if;
  if not exists (select 1 from pg_constraint where conrelid = 'public.service_bookings'::regclass and conname = 'service_bookings_timer_elapsed_nonnegative_check') then
    alter table public.service_bookings add constraint service_bookings_timer_elapsed_nonnegative_check
      check (timer_elapsed_seconds is null or timer_elapsed_seconds >= 0);
  end if;
  if not exists (select 1 from pg_constraint where conrelid = 'public.service_bookings'::regclass and conname = 'service_bookings_timer_minutes_nonnegative_check') then
    alter table public.service_bookings add constraint service_bookings_timer_minutes_nonnegative_check
      check (timer_billable_minutes is null or timer_billable_minutes >= 0);
  end if;
  if not exists (select 1 from pg_constraint where conrelid = 'public.service_bookings'::regclass and conname = 'service_bookings_timer_timestamps_order_check') then
    alter table public.service_bookings add constraint service_bookings_timer_timestamps_order_check
      check (timer_started_at is null or timer_stopped_at is null or timer_stopped_at >= timer_started_at);
  end if;
end
$migration$;

create table if not exists public.srk_booking_timer_decisions (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null references public.service_bookings(id) on delete restrict,
  action text not null check (action in ('start_request','stop_request')),
  requester_user_id uuid not null references auth.users(id) on delete restrict,
  requested_at timestamptz not null default clock_timestamp(),
  decision text not null default 'pending' check (decision in ('pending','approved','rejected')),
  decided_by uuid references auth.users(id) on delete restrict,
  decided_at timestamptz,
  effective_at timestamptz,
  idempotency_key text not null,
  created_at timestamptz not null default clock_timestamp(),
  constraint srk_booking_timer_decisions_idempotency_unique unique (booking_id, action, idempotency_key),
  constraint srk_booking_timer_decisions_decision_shape_check check (
    (decision = 'pending' and decided_by is null and decided_at is null and effective_at is null)
    or
    (decision in ('approved','rejected') and decided_by is not null and decided_at is not null
      and ((decision = 'approved' and effective_at is not null) or (decision = 'rejected' and effective_at is null)))
  )
);

create index if not exists srk_booking_timer_decisions_booking_idx
  on public.srk_booking_timer_decisions (booking_id, requested_at desc);

create table if not exists public.srk_final_bills (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null unique references public.service_bookings(id) on delete restrict,
  bill_version integer not null default 1 check (bill_version > 0),
  category_code text not null check (category_code in ('helper','ordinary','skilled','master')),
  category_label text not null,
  hourly_rate numeric(12,6) not null check (hourly_rate > 0),
  started_at timestamptz not null,
  stopped_at timestamptz not null,
  elapsed_seconds bigint not null check (elapsed_seconds >= 0),
  billable_minutes bigint not null check (billable_minutes >= 0),
  labour_amount numeric(20,10) not null check (labour_amount >= 0),
  rounding_rule text not null default 'ceil_seconds_to_whole_minutes;round_final_half_up_0.01',
  calculation_version text not null default 'timer-v1',
  generated_at timestamptz not null default clock_timestamp(),
  generated_by uuid references auth.users(id) on delete set null,
  constraint srk_final_bills_time_order_check check (stopped_at >= started_at),
  constraint srk_final_bills_elapsed_matches_check check (
    elapsed_seconds = greatest(0, ceil(extract(epoch from (stopped_at - started_at)))::bigint)
  ),
  constraint srk_final_bills_minutes_match_check check (
    billable_minutes = case when elapsed_seconds = 0 then 0 else ((elapsed_seconds + 59) / 60) end
  )
);

create table if not exists public.srk_bill_material_items (
  id uuid primary key default gen_random_uuid(),
  bill_id uuid not null references public.srk_final_bills(id) on delete restrict,
  line_number integer not null check (line_number > 0),
  description text not null check (length(btrim(description)) between 1 and 240),
  quantity numeric(12,3) not null check (quantity > 0),
  unit_price numeric(12,2) not null check (unit_price >= 0),
  line_total numeric(12,2) not null check (line_total >= 0),
  supplied_by text not null check (supplied_by in ('electrician','customer')),
  receipt_reference text,
  created_by uuid not null references auth.users(id) on delete restrict,
  created_at timestamptz not null default clock_timestamp(),
  unique (bill_id, line_number),
  constraint srk_bill_material_items_total_check check (line_total = round(quantity * unit_price, 2))
);

create table if not exists public.srk_bill_material_approvals (
  id uuid primary key default gen_random_uuid(),
  bill_id uuid not null references public.srk_final_bills(id) on delete restrict,
  revision integer not null check (revision > 0),
  customer_user_id uuid not null references auth.users(id) on delete restrict,
  decision text not null check (decision in ('approved','rejected')),
  decided_at timestamptz not null default clock_timestamp(),
  unique (bill_id, revision)
);

create table if not exists public.srk_booking_cancellation_requests (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null references public.service_bookings(id) on delete restrict,
  requester_user_id uuid not null references auth.users(id) on delete restrict,
  requester_role text not null check (requester_role in ('customer','electrician')),
  reason text not null check (length(btrim(reason)) between 1 and 1000),
  requested_at timestamptz not null default clock_timestamp(),
  arrival_evidence_at_request timestamptz,
  decision text not null default 'pending' check (decision in ('pending','approved','rejected')),
  decided_by uuid references auth.users(id) on delete restrict,
  decided_at timestamptz,
  admin_note text,
  cancellation_fee numeric(12,2) not null default 0 check (cancellation_fee in (0,99)),
  unique (booking_id, id),
  constraint srk_booking_cancellation_decision_shape_check check (
    (decision = 'pending' and decided_by is null and decided_at is null and cancellation_fee = 0)
    or (decision in ('approved','rejected') and decided_by is not null and decided_at is not null)
  )
);

create index if not exists srk_booking_cancellation_requests_booking_idx
  on public.srk_booking_cancellation_requests (booking_id, requested_at desc);

do $migration$
begin
  if not exists (select 1 from pg_constraint where conrelid = 'public.service_bookings'::regclass and conname = 'service_bookings_final_bill_fk') then
    alter table public.service_bookings
      add constraint service_bookings_final_bill_fk
      foreign key (final_bill_id) references public.srk_final_bills(id) on delete restrict;
  end if;
end
$migration$;

-- New workflow tables are not directly writable/readable by browser roles.
-- Follow-up SECURITY DEFINER RPCs will expose only ownership-scoped operations.
alter table public.srk_booking_timer_decisions enable row level security;
alter table public.srk_final_bills enable row level security;
alter table public.srk_bill_material_items enable row level security;
alter table public.srk_bill_material_approvals enable row level security;
alter table public.srk_booking_cancellation_requests enable row level security;

revoke all on public.srk_booking_timer_decisions from anon, authenticated;
revoke all on public.srk_final_bills from anon, authenticated;
revoke all on public.srk_bill_material_items from anon, authenticated;
revoke all on public.srk_bill_material_approvals from anon, authenticated;
revoke all on public.srk_booking_cancellation_requests from anon, authenticated;

grant all on public.srk_booking_timer_decisions to service_role;
grant all on public.srk_final_bills to service_role;
grant all on public.srk_bill_material_items to service_role;
grant all on public.srk_bill_material_approvals to service_role;
grant all on public.srk_booking_cancellation_requests to service_role;

comment on table public.srk_booking_timer_decisions is
  'Append-only decision ledger for customer-approved timer start/stop. Access only through scoped RPCs.';
comment on table public.srk_final_bills is
  'Server-calculated labour-only final bill; materials are stored separately.';
comment on table public.srk_bill_material_items is
  'Itemized material charges kept separate from labour; customer approval is recorded separately.';
comment on table public.srk_booking_cancellation_requests is
  'Cancellation requests and Admin decisions; ₹99 eligibility is enforced by the decision RPC, not client input.';

commit;
