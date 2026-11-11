-- SRK ELECTRONIC: integrity/data-model extension for timer billing.
-- Depends on 202611110001_timer_billing_materials_foundation.sql.
-- Feature Branch only. No RPCs, API callers, or deployments are changed here.

begin;

-- A material revision represents one complete replacement proposal for a bill.
create table if not exists public.srk_bill_material_revisions (
  id uuid primary key default gen_random_uuid(),
  bill_id uuid not null references public.srk_final_bills(id) on delete restrict,
  revision integer not null check (revision > 0),
  status text not null default 'draft'
    check (status in ('draft','pending','approved','rejected')),
  created_by uuid not null references auth.users(id) on delete restrict,
  created_at timestamptz not null default clock_timestamp(),
  submitted_at timestamptz,
  decided_at timestamptz,
  decided_by uuid references auth.users(id) on delete restrict,
  unique (bill_id, revision),
  unique (id, bill_id),
  constraint srk_bill_material_revisions_decision_shape_check check (
    (status in ('draft','pending') and decided_at is null and decided_by is null)
    or
    (status in ('approved','rejected') and decided_at is not null and decided_by is not null)
  ),
  constraint srk_bill_material_revisions_submission_check check (
    (status = 'draft' and submitted_at is null)
    or (status <> 'draft' and submitted_at is not null)
  )
);

-- Backfill revision parents for any rows created under the first foundation
-- schema. The foundation has not been applied to shared environments, but this
-- makes the additive migration safe for an isolated database with test rows.
insert into public.srk_bill_material_revisions
  (bill_id, revision, status, created_by, created_at, submitted_at, decided_at, decided_by)
select
  x.bill_id,
  x.revision,
  case when x.decision = 'approved' then 'approved'
       when x.decision = 'rejected' then 'rejected'
       when x.has_items then 'draft'
       else 'draft' end,
  coalesce(x.actor_id, (select u.id from auth.users u order by u.id limit 1)),
  clock_timestamp(),
  case when x.decision in ('approved','rejected') then clock_timestamp() else null end,
  case when x.decision in ('approved','rejected') then clock_timestamp() else null end,
  case when x.decision in ('approved','rejected') then x.actor_id else null end
from (
  select z.bill_id, z.revision,
         max(z.decision) as decision,
         bool_or(z.has_items) as has_items,
         max(z.actor_id::text)::uuid as actor_id
  from (
    select a.bill_id, a.revision, a.decision, false as has_items, a.customer_user_id as actor_id
    from public.srk_bill_material_approvals a
    union all
    select i.bill_id, 1 as revision, null::text as decision, true as has_items, i.created_by as actor_id
    from public.srk_bill_material_items i
  ) z
  group by z.bill_id, z.revision
) x
where x.actor_id is not null
on conflict (bill_id, revision) do nothing;

alter table public.srk_bill_material_items
  add column if not exists revision_id uuid;

-- Link existing material lines to revision 1 for their bill.
update public.srk_bill_material_items i
set revision_id = r.id
from public.srk_bill_material_revisions r
where r.bill_id = i.bill_id and r.revision = 1 and i.revision_id is null;

alter table public.srk_bill_material_approvals
  add column if not exists revision_id uuid;

update public.srk_bill_material_approvals a
set revision_id = r.id
from public.srk_bill_material_revisions r
where r.bill_id = a.bill_id and r.revision = a.revision and a.revision_id is null;

do $constraints$
begin
  if not exists (select 1 from pg_constraint where conrelid='public.srk_bill_material_items'::regclass and conname='srk_bill_material_items_revision_fk') then
    alter table public.srk_bill_material_items
      add constraint srk_bill_material_items_revision_fk
      foreign key (revision_id, bill_id)
      references public.srk_bill_material_revisions(id, bill_id) on delete restrict;
  end if;
  if not exists (select 1 from pg_constraint where conrelid='public.srk_bill_material_approvals'::regclass and conname='srk_bill_material_approvals_revision_fk') then
    alter table public.srk_bill_material_approvals
      add constraint srk_bill_material_approvals_revision_fk
      foreign key (revision_id, bill_id)
      references public.srk_bill_material_revisions(id, bill_id) on delete restrict;
  end if;
end
$constraints$;

-- Material line numbers are scoped to a revision, not to the entire bill.
do $indexes$
begin
  if exists (select 1 from pg_constraint where conrelid='public.srk_bill_material_items'::regclass and conname='srk_bill_material_items_bill_id_line_number_key') then
    alter table public.srk_bill_material_items drop constraint srk_bill_material_items_bill_id_line_number_key;
  end if;
end
$indexes$;
create unique index if not exists srk_bill_material_items_revision_line_unique
  on public.srk_bill_material_items(revision_id, line_number);
create unique index if not exists srk_bill_material_revisions_one_open_revision
  on public.srk_bill_material_revisions(bill_id)
  where status in ('draft','pending');

-- Durable payable snapshot: order/payment must bind to one immutable calculation.
create table if not exists public.srk_booking_payable_snapshots (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null references public.service_bookings(id) on delete restrict,
  bill_id uuid not null references public.srk_final_bills(id) on delete restrict,
  material_revision_id uuid references public.srk_bill_material_revisions(id) on delete restrict,
  bill_version integer not null check (bill_version > 0),
  labour_amount numeric(12,2) not null check (labour_amount >= 0),
  materials_amount numeric(12,2) not null check (materials_amount >= 0),
  total_amount numeric(12,2) not null check (total_amount = labour_amount + materials_amount),
  amount_paise bigint not null check (amount_paise >= 0),
  currency text not null default 'INR' check (currency = 'INR'),
  calculation_version text not null,
  created_at timestamptz not null default clock_timestamp(),
  created_by uuid references auth.users(id) on delete set null,
  constraint srk_booking_payable_snapshot_amount_check
    check (amount_paise = (total_amount * 100)::bigint)
);
create unique index if not exists srk_booking_payable_snapshot_binding_unique
  on public.srk_booking_payable_snapshots
    (booking_id, bill_id, bill_version, coalesce(material_revision_id, '00000000-0000-0000-0000-000000000000'::uuid));

-- Razorpay event ledger. The unique event ID is the replay/idempotency boundary.
create table if not exists public.srk_payment_webhook_events (
  id uuid primary key default gen_random_uuid(),
  provider text not null check (provider in ('razorpay')),
  provider_event_id text not null,
  payload_sha256 text not null check (length(payload_sha256) = 64),
  event_type text not null,
  provider_order_id text,
  provider_payment_id text,
  processing_status text not null default 'received'
    check (processing_status in ('received','processing','processed','rejected','retryable_error')),
  outcome_code text,
  outcome_detail text,
  received_at timestamptz not null default clock_timestamp(),
  processed_at timestamptz,
  attempt_count integer not null default 0 check (attempt_count >= 0),
  unique (provider, provider_event_id)
);

create index if not exists srk_payment_webhook_events_status_idx
  on public.srk_payment_webhook_events(processing_status, received_at);

-- Cash receipt is explicit evidence from the assigned electrician, tied to
-- the exact payable snapshot. It is not a generic booking status update.
create table if not exists public.srk_cash_receipts (
  id uuid primary key default gen_random_uuid(),
  payable_snapshot_id uuid not null unique references public.srk_booking_payable_snapshots(id) on delete restrict,
  booking_id uuid not null references public.service_bookings(id) on delete restrict,
  confirmed_by uuid not null references auth.users(id) on delete restrict,
  confirmed_at timestamptz not null default clock_timestamp(),
  amount_paise bigint not null check (amount_paise >= 0),
  currency text not null default 'INR' check (currency = 'INR'),
  receipt_note text
);

-- Append-oriented business audit events for state changes not represented by
-- the legacy service_bookings status-history trigger.
create table if not exists public.srk_booking_audit_events (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null references public.service_bookings(id) on delete restrict,
  actor_user_id uuid references auth.users(id) on delete set null,
  actor_kind text not null check (actor_kind in ('customer','electrician','admin','system')),
  action text not null,
  entity_type text not null,
  entity_id uuid,
  idempotency_key text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default clock_timestamp()
);
create unique index if not exists srk_booking_audit_event_idempotency_unique
  on public.srk_booking_audit_events(booking_id, actor_user_id, action, idempotency_key)
  where idempotency_key is not null;
create index if not exists srk_booking_audit_events_booking_time_idx
  on public.srk_booking_audit_events(booking_id, created_at desc);

-- Explicit, append-only adjustment proposals are separate from the original
-- labour bill. Authorization/approval rules are enforced by future RPCs.
create table if not exists public.srk_final_bill_adjustments (
  id uuid primary key default gen_random_uuid(),
  bill_id uuid not null references public.srk_final_bills(id) on delete restrict,
  booking_id uuid not null references public.service_bookings(id) on delete restrict,
  adjustment_number integer not null check (adjustment_number > 0),
  amount_delta numeric(12,2) not null check (amount_delta <> 0),
  reason text not null check (length(btrim(reason)) between 1 and 1000),
  proposed_by uuid not null references auth.users(id) on delete restrict,
  proposed_at timestamptz not null default clock_timestamp(),
  decision text not null default 'pending' check (decision in ('pending','approved','rejected')),
  decided_by uuid references auth.users(id) on delete restrict,
  decided_at timestamptz,
  unique (bill_id, adjustment_number),
  constraint srk_final_bill_adjustments_decision_shape_check check (
    (decision = 'pending' and decided_by is null and decided_at is null)
    or (decision in ('approved','rejected') and decided_by is not null and decided_at is not null)
  )
);

-- These tables are not directly accessible to browser roles. Future narrow
-- SECURITY DEFINER RPCs will provide ownership-scoped reads and mutations.
alter table public.srk_bill_material_revisions enable row level security;
alter table public.srk_booking_payable_snapshots enable row level security;
alter table public.srk_payment_webhook_events enable row level security;
alter table public.srk_cash_receipts enable row level security;
alter table public.srk_booking_audit_events enable row level security;
alter table public.srk_final_bill_adjustments enable row level security;

revoke all on public.srk_bill_material_revisions from anon, authenticated;
revoke all on public.srk_booking_payable_snapshots from anon, authenticated;
revoke all on public.srk_payment_webhook_events from anon, authenticated;
revoke all on public.srk_cash_receipts from anon, authenticated;
revoke all on public.srk_booking_audit_events from anon, authenticated;
revoke all on public.srk_final_bill_adjustments from anon, authenticated;
grant all on public.srk_bill_material_revisions to service_role;
grant all on public.srk_booking_payable_snapshots to service_role;
grant all on public.srk_payment_webhook_events to service_role;
grant all on public.srk_cash_receipts to service_role;
grant all on public.srk_booking_audit_events to service_role;
grant all on public.srk_final_bill_adjustments to service_role;

comment on table public.srk_bill_material_revisions is
  'A complete material proposal revision; approvals bind to this exact immutable line set.';
comment on table public.srk_booking_payable_snapshots is
  'Immutable payable calculation binding bill version, approved material revision, amount and currency.';
comment on table public.srk_payment_webhook_events is
  'Durable provider webhook event ledger with unique event ID for replay protection.';
comment on table public.srk_cash_receipts is
  'Electrician-confirmed cash receipt bound to one exact payable snapshot.';
comment on table public.srk_booking_audit_events is
  'Business audit trail for timer, bill, materials, cancellation and payment decisions.';
comment on table public.srk_final_bill_adjustments is
  'Separate audited bill adjustment proposal; original final bill is not overwritten.';

commit;
