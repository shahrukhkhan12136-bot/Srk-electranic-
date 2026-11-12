-- Durable, server-only Razorpay webhook event ledger with recoverable processing leases.
begin;
create table if not exists public.srk_payment_webhook_events (
  id uuid primary key default gen_random_uuid(),
  provider text not null check (provider = 'razorpay'),
  provider_event_id text not null check (length(btrim(provider_event_id)) between 1 and 160),
  payload_sha256 text not null check (payload_sha256 ~ '^[a-f0-9]{64}$'),
  event_type text not null check (length(btrim(event_type)) between 1 and 120),
  provider_order_id text check (provider_order_id is null or provider_order_id ~ '^order_[A-Za-z0-9]+$'),
  provider_payment_id text check (provider_payment_id is null or provider_payment_id ~ '^pay_[A-Za-z0-9]+$'),
  processing_status text not null default 'received'
    check (processing_status in ('received','processing','retryable_error','processed','rejected')),
  attempt_count integer not null default 0 check (attempt_count >= 0),
  processing_started_at timestamptz,
  outcome_code text,
  outcome_detail text check (outcome_detail is null or length(outcome_detail) <= 300),
  created_at timestamptz not null default clock_timestamp(),
  updated_at timestamptz not null default clock_timestamp(),
  processed_at timestamptz,
  constraint srk_payment_webhook_events_provider_event_unique unique(provider,provider_event_id)
);
create index if not exists srk_payment_webhook_events_status_created_idx
  on public.srk_payment_webhook_events(processing_status,created_at);
alter table public.srk_payment_webhook_events enable row level security;
revoke all on public.srk_payment_webhook_events from public,anon,authenticated;
grant select,insert,update on public.srk_payment_webhook_events to service_role;
commit;
