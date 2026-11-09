-- Server-only audit trail for verified Razorpay webhook events.
create table if not exists public.srk_razorpay_webhook_events (
  event_id text primary key,
  event_type text not null,
  razorpay_order_id text,
  razorpay_payment_id text,
  payment_amount_paise bigint,
  payment_currency text,
  processing_status text not null default 'received'
    check (processing_status in ('received','reconciled','exception','ignored','processing_error')),
  reconciliation_reason text,
  received_at timestamptz not null default now(),
  processed_at timestamptz,
  updated_at timestamptz not null default now()
);
create index if not exists srk_razorpay_webhook_events_order_idx
  on public.srk_razorpay_webhook_events (razorpay_order_id, received_at desc);
create index if not exists srk_razorpay_webhook_events_status_idx
  on public.srk_razorpay_webhook_events (processing_status, received_at desc);
alter table public.srk_razorpay_webhook_events enable row level security;
revoke all on table public.srk_razorpay_webhook_events from anon, authenticated;
grant all on table public.srk_razorpay_webhook_events to service_role;
