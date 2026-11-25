
alter table public.srk_razorpay_payment_orders
  add column if not exists final_bill_id uuid references public.srk_booking_final_bills(id) on delete restrict,
  add column if not exists final_bill_revision integer;

alter table public.srk_razorpay_webhook_events
  add column if not exists event_payload jsonb not null default '{}'::jsonb;

create or replace function public.srk_service_start_razorpay_payment_order(
  p_booking_id uuid,
  p_customer_user_id uuid,
  p_idempotency_key text,
  p_lock_token uuid
)
returns public.srk_razorpay_payment_orders
language plpgsql
security definer
set search_path = pg_catalog, public, auth
as $$
declare
  v_booking public.service_bookings%rowtype;
  v_bill public.srk_booking_final_bills%rowtype;
  v_attempt public.srk_razorpay_payment_orders%rowtype;
  v_amount bigint;
begin
  if auth.role() <> 'service_role' then
    raise exception 'Service role required';
  end if;
  if p_booking_id is null or p_customer_user_id is null or p_lock_token is null
     or length(coalesce(p_idempotency_key,'')) < 8 or length(p_idempotency_key)>160 then
    raise exception 'Invalid payment order request';
  end if;
  if not exists (
    select 1 from public.srk_payment_order_locks l
    where l.booking_id=p_booking_id and l.lock_token=p_lock_token and l.locked_until>now()
  ) then
    raise exception 'Payment order lock missing or expired';
  end if;

  select * into v_booking from public.service_bookings
  where id=p_booking_id for update;
  if not found or v_booking.customer_user_id<>p_customer_user_id then
    raise exception 'Customer booking not found';
  end if;
  if v_booking.status<>'completed' or lower(coalesce(v_booking.payment_status,'')) in ('paid','completed','refunded') then
    raise exception 'Booking is not payable';
  end if;
  if lower(coalesce(v_booking.payment_method,'')) not in ('online','upi','card') then
    raise exception 'Booking is not selected for online payment';
  end if;

  select * into v_bill from public.srk_booking_final_bills
  where booking_id=p_booking_id and status in ('issued','approved')
  order by revision_no desc,created_at desc limit 1 for update;
  if not found or v_bill.total_amount is null or v_bill.total_amount<=0 then
    raise exception 'Issued final bill not found';
  end if;
  v_amount:=round(v_bill.total_amount*100)::bigint;
  if v_amount<100 or v_amount>1000000000 then
    raise exception 'Final bill amount is outside Razorpay order limits';
  end if;

  if exists (
    select 1 from public.srk_razorpay_payment_orders
    where booking_id=p_booking_id and status in ('creating','created','reconciliation_required')
  ) then
    raise exception 'An open payment order already exists; reuse or reconcile it';
  end if;

  insert into public.srk_razorpay_payment_orders(
    booking_id,customer_user_id,final_bill_id,final_bill_revision,
    amount_paise,currency,idempotency_key,receipt,status,metadata
  ) values (
    p_booking_id,p_customer_user_id,v_bill.id,v_bill.revision_no,
    v_amount,'INR',p_idempotency_key,
    'srk_'||replace(gen_random_uuid()::text,'-',''),
    'creating',
    jsonb_build_object('billing_basis','final_bill_total','includes_labour_and_materials',
      true,'company_commission_rate_snapshot',v_booking.commission_rate)
  ) returning * into v_attempt;

  return v_attempt;
end;
$$;

create or replace function public.srk_service_attach_razorpay_order(
  p_attempt_id uuid,
  p_razorpay_order_id text,
  p_lock_token uuid
)
returns public.srk_razorpay_payment_orders
language plpgsql
security definer
set search_path = pg_catalog, public, auth
as $$
declare
  v_attempt public.srk_razorpay_payment_orders%rowtype;
begin
  if auth.role() <> 'service_role' then raise exception 'Service role required'; end if;
  if p_attempt_id is null or p_lock_token is null
     or p_razorpay_order_id !~ '^order_[A-Za-z0-9]+$' then
    raise exception 'Invalid Razorpay order attachment';
  end if;

  select * into v_attempt from public.srk_razorpay_payment_orders
  where id=p_attempt_id for update;
  if not found then raise exception 'Payment order attempt not found'; end if;
  if not exists (
    select 1 from public.srk_payment_order_locks l
    where l.booking_id=v_attempt.booking_id and l.lock_token=p_lock_token and l.locked_until>now()
  ) then raise exception 'Payment order lock missing or expired'; end if;

  if v_attempt.status='created' and v_attempt.razorpay_order_id=p_razorpay_order_id then
    return v_attempt;
  end if;
  if v_attempt.status<>'creating' or v_attempt.razorpay_order_id is not null then
    raise exception 'Payment order attempt is not attachable';
  end if;

  update public.srk_razorpay_payment_orders
  set razorpay_order_id=p_razorpay_order_id,status='created',updated_at=now()
  where id=p_attempt_id returning * into v_attempt;

  update public.service_bookings
  set razorpay_order_id=p_razorpay_order_id
  where id=v_attempt.booking_id
    and status='completed'
    and lower(coalesce(payment_status,'')) not in ('paid','completed','refunded')
    and (razorpay_order_id is null or razorpay_order_id=p_razorpay_order_id);
  if not found then raise exception 'Booking changed before Razorpay order could be linked'; end if;

  return v_attempt;
end;
$$;

create or replace function public.srk_service_mark_razorpay_order_failure(
  p_attempt_id uuid,
  p_failure_code text,
  p_failure_description text,
  p_uncertain boolean default false
)
returns boolean
language plpgsql
security definer
set search_path = pg_catalog, public, auth
as $$
begin
  if auth.role() <> 'service_role' then raise exception 'Service role required'; end if;
  update public.srk_razorpay_payment_orders
  set status=case when p_uncertain then 'reconciliation_required' else 'failed' end,
      failure_code=left(coalesce(p_failure_code,'provider_error'),120),
      failure_description=left(coalesce(p_failure_description,'Razorpay order creation failed'),1000),
      updated_at=now()
  where id=p_attempt_id and status='creating';
  return found;
end;
$$;

create or replace function public.srk_service_finalize_razorpay_payment(
  p_razorpay_order_id text,
  p_razorpay_payment_id text,
  p_amount_paise bigint,
  p_currency text
)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, auth
as $$
declare
  v_attempt public.srk_razorpay_payment_orders%rowtype;
  v_booking public.service_bookings%rowtype;
  v_bill public.srk_booking_final_bills%rowtype;
  v_existing_payment_id text;
begin
  if auth.role() <> 'service_role' then raise exception 'Service role required'; end if;
  if p_razorpay_order_id !~ '^order_[A-Za-z0-9]+$'
     or p_razorpay_payment_id !~ '^pay_[A-Za-z0-9]+$'
     or p_currency<>'INR' or p_amount_paise<100 then
    raise exception 'Invalid captured payment details';
  end if;

  select * into v_attempt from public.srk_razorpay_payment_orders
  where razorpay_order_id=p_razorpay_order_id for update;
  if not found then raise exception 'Razorpay order attempt not found'; end if;
  if v_attempt.amount_paise<>p_amount_paise or v_attempt.currency<>p_currency then
    raise exception 'Captured amount/currency does not match recorded order';
  end if;
  if v_attempt.status='paid' then
    select razorpay_payment_id into v_existing_payment_id from public.service_bookings
    where id=v_attempt.booking_id;
    if v_existing_payment_id=p_razorpay_payment_id then
      return jsonb_build_object('success',true,'already_processed',true);
    end if;
    raise exception 'Different payment already recorded for this order';
  end if;
  if v_attempt.status<>'created' then
    raise exception 'Payment order is not in created state';
  end if;

  select * into v_booking from public.service_bookings
  where id=v_attempt.booking_id for update;
  if not found or v_booking.customer_user_id<>v_attempt.customer_user_id then
    raise exception 'Booking/customer mismatch';
  end if;
  if v_booking.status<>'completed'
     or lower(coalesce(v_booking.payment_status,'')) in ('paid','completed','refunded')
     or lower(coalesce(v_booking.payment_method,'')) not in ('online','upi','card')
     or v_booking.razorpay_order_id<>p_razorpay_order_id then
    raise exception 'Booking is no longer payable with this order';
  end if;

  select * into v_bill from public.srk_booking_final_bills
  where id=v_attempt.final_bill_id and booking_id=v_attempt.booking_id
    and status in ('issued','approved') for update;
  if not found or v_bill.revision_no<>v_attempt.final_bill_revision
     or round(v_bill.total_amount*100)::bigint<>v_attempt.amount_paise then
    raise exception 'Final bill snapshot no longer matches the payment order';
  end if;

  update public.service_bookings
  set payment_status='paid',
      amount_paid=(p_amount_paise::numeric/100),
      razorpay_payment_id=p_razorpay_payment_id,
      payment_verified_at=clock_timestamp()
  where id=v_booking.id;

  update public.srk_razorpay_payment_orders
  set status='paid',paid_at=clock_timestamp(),updated_at=clock_timestamp()
  where id=v_attempt.id;

  return jsonb_build_object('success',true,'already_processed',false,
    'booking_id',v_booking.id,'payment_order_id',v_attempt.id,
    'amount_paise',p_amount_paise,'currency',p_currency);
end;
$$;

revoke all on function public.srk_service_start_razorpay_payment_order(uuid,uuid,text,uuid) from public, anon, authenticated;
revoke all on function public.srk_service_attach_razorpay_order(uuid,text,uuid) from public, anon, authenticated;
revoke all on function public.srk_service_mark_razorpay_order_failure(uuid,text,text,boolean) from public, anon, authenticated;
revoke all on function public.srk_service_finalize_razorpay_payment(text,text,bigint,text) from public, anon, authenticated;
grant execute on function public.srk_service_start_razorpay_payment_order(uuid,uuid,text,uuid) to service_role;
grant execute on function public.srk_service_attach_razorpay_order(uuid,text,uuid) to service_role;
grant execute on function public.srk_service_mark_razorpay_order_failure(uuid,text,text,boolean) to service_role;
grant execute on function public.srk_service_finalize_razorpay_payment(text,text,bigint,text) to service_role;
