-- SRK ELECTRONIC: Razorpay order/payment ledger bound to immutable payable snapshots.
-- Feature Branch only. Do not apply to shared TEST/Production without approval.
begin;

create table if not exists public.srk_razorpay_orders (
  id uuid primary key default gen_random_uuid(),
  snapshot_id uuid not null unique references public.srk_booking_payable_snapshots(id) on delete restrict,
  booking_id uuid not null references public.service_bookings(id) on delete restrict,
  provider_order_id text unique,
  amount_paise bigint not null check (amount_paise >= 100),
  currency text not null default 'INR' check (currency='INR'),
  status text not null default 'creating' check (status in ('creating','created','paid')),
  creation_token uuid not null,
  lease_expires_at timestamptz not null,
  provider_payment_id text unique,
  created_at timestamptz not null default clock_timestamp(),
  bound_at timestamptz,
  paid_at timestamptz,
  constraint srk_razorpay_order_snapshot_booking_fk
    foreign key (snapshot_id,booking_id)
    references public.srk_booking_payable_snapshots(id,booking_id) on delete restrict,
  constraint srk_razorpay_order_state_shape_check check (
    (status='creating' and provider_order_id is null and bound_at is null and provider_payment_id is null and paid_at is null)
    or (status='created' and provider_order_id is not null and bound_at is not null and provider_payment_id is null and paid_at is null)
    or (status='paid' and provider_order_id is not null and bound_at is not null and provider_payment_id is not null and paid_at is not null)
  )
);

create table if not exists public.srk_razorpay_payments (
  id uuid primary key default gen_random_uuid(),
  provider_payment_id text not null unique,
  provider_order_id text not null unique references public.srk_razorpay_orders(provider_order_id) on delete restrict,
  snapshot_id uuid not null unique references public.srk_booking_payable_snapshots(id) on delete restrict,
  booking_id uuid not null references public.service_bookings(id) on delete restrict,
  amount_paise bigint not null check (amount_paise >= 100),
  currency text not null default 'INR' check (currency='INR'),
  source text not null check (source in ('checkout','webhook')),
  captured_at timestamptz not null default clock_timestamp(),
  constraint srk_razorpay_payment_snapshot_booking_fk
    foreign key (snapshot_id,booking_id)
    references public.srk_booking_payable_snapshots(id,booking_id) on delete restrict
);

create index if not exists srk_razorpay_orders_status_lease_idx
  on public.srk_razorpay_orders(status,lease_expires_at);

alter table public.srk_razorpay_orders enable row level security;
alter table public.srk_razorpay_payments enable row level security;
revoke all on public.srk_razorpay_orders from public,anon,authenticated;
revoke all on public.srk_razorpay_payments from public,anon,authenticated;
grant all on public.srk_razorpay_orders to service_role;
grant all on public.srk_razorpay_payments to service_role;

create or replace function public.srk_guard_razorpay_order_identity()
returns trigger
language plpgsql
set search_path = ''
as $function$
begin
  if row(new.snapshot_id,new.booking_id,new.amount_paise,new.currency,new.created_at)
     is distinct from
     row(old.snapshot_id,old.booking_id,old.amount_paise,old.currency,old.created_at) then
    raise exception 'RAZORPAY_ORDER_FINANCIAL_BINDING_IMMUTABLE' using errcode='55000';
  end if;
  if old.status='paid' and row(new.provider_order_id,new.status,new.creation_token,new.lease_expires_at,new.provider_payment_id,new.bound_at,new.paid_at)
     is distinct from
     row(old.provider_order_id,old.status,old.creation_token,old.lease_expires_at,old.provider_payment_id,old.bound_at,old.paid_at) then
    raise exception 'RAZORPAY_PAID_ORDER_IMMUTABLE' using errcode='55000';
  end if;
  return new;
end
$function$;

drop trigger if exists srk_guard_razorpay_order_identity_trigger on public.srk_razorpay_orders;
create trigger srk_guard_razorpay_order_identity_trigger
before update on public.srk_razorpay_orders
for each row execute function public.srk_guard_razorpay_order_identity();

create or replace function public.srk_reject_razorpay_payment_mutation()
returns trigger
language plpgsql
set search_path = ''
as $function$
begin
  raise exception 'RAZORPAY_PAYMENT_LEDGER_APPEND_ONLY' using errcode='55000';
end
$function$;

drop trigger if exists srk_razorpay_payments_append_only_trigger on public.srk_razorpay_payments;
create trigger srk_razorpay_payments_append_only_trigger
before update or delete on public.srk_razorpay_payments
for each row execute function public.srk_reject_razorpay_payment_mutation();

create or replace function public.srk_claim_razorpay_snapshot_order(
  p_snapshot_id uuid,
  p_creation_token uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_snapshot public.srk_booking_payable_snapshots%rowtype;
  v_booking public.service_bookings%rowtype;
  v_order public.srk_razorpay_orders%rowtype;
begin
  if p_snapshot_id is null or p_creation_token is null then
    raise exception 'SNAPSHOT_AND_CREATION_TOKEN_REQUIRED' using errcode='22023';
  end if;

  select s.* into v_snapshot
  from public.srk_booking_payable_snapshots s
  where s.id=p_snapshot_id
  for update;
  if not found then raise exception 'PAYABLE_SNAPSHOT_NOT_FOUND' using errcode='P0002'; end if;

  select b.* into v_booking
  from public.service_bookings b
  where b.id=v_snapshot.booking_id
  for update;
  if not found then raise exception 'BOOKING_NOT_FOUND' using errcode='P0002'; end if;
  if v_booking.payment_status='paid' then
    raise exception 'BOOKING_ALREADY_PAID' using errcode='55000';
  end if;
  if v_snapshot.amount_paise < 100 then
    raise exception 'RAZORPAY_MINIMUM_AMOUNT_NOT_MET' using errcode='22023';
  end if;

  select o.* into v_order
  from public.srk_razorpay_orders o
  where o.snapshot_id=p_snapshot_id
  for update;
  if found then
    if v_order.status in ('created','paid') then
      return jsonb_build_object(
        'success',true,'claimed',false,'status',v_order.status,
        'provider_order_id',v_order.provider_order_id,
        'amount_paise',v_order.amount_paise,'currency',v_order.currency,
        'provider_payment_id',v_order.provider_payment_id
      );
    end if;
    if v_order.lease_expires_at>clock_timestamp() then
      return jsonb_build_object('success',false,'busy',true,'retry_after_seconds',
        greatest(1,ceil(extract(epoch from (v_order.lease_expires_at-clock_timestamp())))::integer));
    end if;
    update public.srk_razorpay_orders
    set creation_token=p_creation_token,lease_expires_at=clock_timestamp()+interval '5 minutes'
    where id=v_order.id
    returning * into v_order;
  else
    insert into public.srk_razorpay_orders(
      snapshot_id,booking_id,amount_paise,currency,status,creation_token,lease_expires_at
    ) values (
      v_snapshot.id,v_snapshot.booking_id,v_snapshot.amount_paise,v_snapshot.currency,
      'creating',p_creation_token,clock_timestamp()+interval '5 minutes'
    ) returning * into v_order;
  end if;

  return jsonb_build_object(
    'success',true,'claimed',true,'status','creating',
    'snapshot_id',v_snapshot.id,'booking_id',v_snapshot.booking_id,
    'amount_paise',v_snapshot.amount_paise,'currency',v_snapshot.currency,
    'creation_token',p_creation_token
  );
end
$function$;

create or replace function public.srk_bind_razorpay_snapshot_order(
  p_snapshot_id uuid,
  p_creation_token uuid,
  p_provider_order_id text,
  p_amount_paise bigint,
  p_currency text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_order public.srk_razorpay_orders%rowtype;
begin
  if p_snapshot_id is null or p_creation_token is null
     or p_provider_order_id is null or p_provider_order_id !~ '^order_[A-Za-z0-9]+$'
     or p_amount_paise is null or p_currency is null then
    raise exception 'INVALID_RAZORPAY_ORDER_BINDING' using errcode='22023';
  end if;

  select o.* into v_order
  from public.srk_razorpay_orders o
  where o.snapshot_id=p_snapshot_id
  for update;
  if not found then raise exception 'ORDER_CLAIM_NOT_FOUND' using errcode='P0002'; end if;

  if v_order.amount_paise<>p_amount_paise or v_order.currency<>p_currency then
    raise exception 'RAZORPAY_ORDER_AMOUNT_MISMATCH' using errcode='23514';
  end if;
  if v_order.status in ('created','paid') and v_order.provider_order_id=p_provider_order_id then
    return jsonb_build_object('success',true,'provider_order_id',v_order.provider_order_id,'replayed',true);
  end if;
  if v_order.status<>'creating' or v_order.creation_token<>p_creation_token then
    raise exception 'ORDER_CLAIM_TOKEN_MISMATCH' using errcode='55000';
  end if;

  update public.srk_razorpay_orders
  set provider_order_id=p_provider_order_id,status='created',bound_at=clock_timestamp()
  where id=v_order.id
  returning * into v_order;

  return jsonb_build_object(
    'success',true,'provider_order_id',v_order.provider_order_id,
    'amount_paise',v_order.amount_paise,'currency',v_order.currency,'replayed',false
  );
end
$function$;

create or replace function public.srk_reconcile_razorpay_snapshot_payment(
  p_provider_order_id text,
  p_provider_payment_id text,
  p_amount_paise bigint,
  p_currency text,
  p_source text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_order public.srk_razorpay_orders%rowtype;
  v_existing public.srk_razorpay_payments%rowtype;
  v_now timestamptz := clock_timestamp();
begin
  if p_provider_order_id is null or p_provider_order_id !~ '^order_[A-Za-z0-9]+$'
     or p_provider_payment_id is null or p_provider_payment_id !~ '^pay_[A-Za-z0-9]+$'
     or p_amount_paise is null or p_amount_paise <= 0
     or p_currency is distinct from 'INR'
     or p_source is null or p_source not in ('verify','webhook') then
    raise exception 'INVALID_RAZORPAY_PAYMENT_RECONCILIATION' using errcode='22023';
  end if;

  select o.* into v_order
  from public.srk_razorpay_orders o
  where o.provider_order_id=p_provider_order_id
  for update;
  if not found then raise exception 'RAZORPAY_ORDER_NOT_BOUND_TO_SNAPSHOT' using errcode='P0002'; end if;

  if v_order.amount_paise<>p_amount_paise or v_order.currency<>p_currency then
    raise exception 'RAZORPAY_CAPTURE_AMOUNT_MISMATCH' using errcode='23514';
  end if;

  if v_order.status='paid' then
    if v_order.provider_payment_id=p_provider_payment_id then
      return jsonb_build_object('success',true,'replayed',true,'booking_id',v_order.booking_id);
    end if;
    raise exception 'RAZORPAY_ORDER_ALREADY_PAID_BY_DIFFERENT_PAYMENT' using errcode='55000';
  end if;
  if v_order.status<>'created' then raise exception 'RAZORPAY_ORDER_NOT_READY' using errcode='55000'; end if;

  select p.* into v_existing
  from public.srk_razorpay_payments p
  where p.provider_payment_id=p_provider_payment_id
     or p.provider_order_id=p_provider_order_id
  for update;
  if found then
    raise exception 'RAZORPAY_PAYMENT_ALREADY_BOUND' using errcode='55000';
  end if;

  insert into public.srk_razorpay_payments(
    provider_payment_id,provider_order_id,snapshot_id,booking_id,
    amount_paise,currency,source,captured_at
  ) values (
    p_provider_payment_id,p_provider_order_id,v_order.snapshot_id,v_order.booking_id,
    p_amount_paise,p_currency,p_source,v_now
  );

  update public.srk_razorpay_orders
  set status='paid',provider_payment_id=p_provider_payment_id,paid_at=v_now
  where id=v_order.id;

  update public.service_bookings
  set payment_status='paid',
      amount_paid=(p_amount_paise::numeric/100)::numeric(12,2),
      razorpay_order_id=p_provider_order_id,
      razorpay_payment_id=p_provider_payment_id,
      payment_verified_at=v_now,
      status='completed'
  where id=v_order.booking_id
    and payment_status is distinct from 'paid';
  if not found then raise exception 'BOOKING_PAYMENT_STATE_CONFLICT' using errcode='55000'; end if;

  insert into public.srk_booking_audit_events(
    booking_id,actor_user_id,actor_kind,action,entity_type,entity_id,metadata
  ) values (
    v_order.booking_id,null,'system','razorpay.payment_captured',
    'payable_snapshot',v_order.snapshot_id,
    jsonb_build_object(
      'provider_order_id',p_provider_order_id,
      'provider_payment_id',p_provider_payment_id,
      'amount_paise',p_amount_paise,'currency',p_currency,'source',p_source
    )
  );

  return jsonb_build_object('success',true,'replayed',false,'booking_id',v_order.booking_id);
end
$function$;

revoke all on function public.srk_guard_razorpay_order_identity() from public,anon,authenticated;
revoke all on function public.srk_reject_razorpay_payment_mutation() from public,anon,authenticated;
revoke all on function public.srk_claim_razorpay_snapshot_order(uuid,uuid) from public,anon,authenticated;
revoke all on function public.srk_bind_razorpay_snapshot_order(uuid,uuid,text,bigint,text) from public,anon,authenticated;
revoke all on function public.srk_reconcile_razorpay_snapshot_payment(text,text,bigint,text,text) from public,anon,authenticated;
grant execute on function public.srk_claim_razorpay_snapshot_order(uuid,uuid) to service_role;
grant execute on function public.srk_bind_razorpay_snapshot_order(uuid,uuid,text,bigint,text) to service_role;
grant execute on function public.srk_reconcile_razorpay_snapshot_payment(text,text,bigint,text,text) to service_role;

commit;
