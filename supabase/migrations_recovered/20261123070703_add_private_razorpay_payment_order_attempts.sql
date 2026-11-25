
create table if not exists public.srk_razorpay_payment_orders (
 id uuid primary key default gen_random_uuid(),
 booking_id uuid not null references public.service_bookings(id) on delete restrict,
 customer_user_id uuid not null,
 amount_paise bigint not null check (amount_paise > 0 and amount_paise <= 1000000000),
 currency text not null default 'INR' check (currency='INR'),
 idempotency_key text not null unique check (length(idempotency_key) between 8 and 160),
 razorpay_order_id text unique,
 status text not null default 'creating'
   check (status in ('creating','created','paid','failed','expired','reconciliation_required')),
 receipt text not null unique,
 failure_code text,
 failure_description text,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(),
 paid_at timestamptz,
 metadata jsonb not null default '{}'::jsonb
);

create index if not exists srk_razorpay_payment_orders_booking_created_idx
 on public.srk_razorpay_payment_orders(booking_id,created_at desc);

create unique index if not exists srk_razorpay_one_open_order_per_booking
 on public.srk_razorpay_payment_orders(booking_id)
 where status in ('creating','created','reconciliation_required');

alter table public.srk_razorpay_payment_orders enable row level security;
revoke all on public.srk_razorpay_payment_orders from public,anon,authenticated;
grant select,insert,update on public.srk_razorpay_payment_orders to service_role;

comment on table public.srk_razorpay_payment_orders is
'Private server-side Razorpay order attempts. Only service_role can access; amount is frozen in paise from the issued final bill.';
