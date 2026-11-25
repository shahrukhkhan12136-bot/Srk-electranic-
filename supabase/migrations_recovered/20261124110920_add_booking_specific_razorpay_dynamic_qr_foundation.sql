
create table if not exists public.srk_razorpay_qr_codes (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null references public.service_bookings(id) on delete restrict,
  final_bill_id uuid not null references public.srk_booking_final_bills(id) on delete restrict,
  customer_user_id uuid not null,
  final_bill_revision integer not null check (final_bill_revision > 0),
  amount_paise bigint not null check (amount_paise between 100 and 1000000000),
  currency text not null default 'INR' check (currency = 'INR'),
  idempotency_key text not null unique check (length(idempotency_key) between 8 and 160),
  razorpay_qr_code_id text unique,
  image_url text,
  short_url text,
  provider_status text not null default 'creating'
    check (provider_status in ('creating','active','closed','paid','expired','failed','reconciliation_required')),
  usage text not null default 'single_use' check (usage = 'single_use'),
  qr_type text not null default 'upi_qr' check (qr_type = 'upi_qr'),
  fixed_amount boolean not null default true check (fixed_amount),
  payments_amount_received_paise bigint not null default 0 check (payments_amount_received_paise >= 0),
  payments_count_received integer not null default 0 check (payments_count_received >= 0),
  close_by timestamptz,
  closed_at timestamptz,
  close_reason text,
  razorpay_payment_id text unique,
  paid_at timestamptz,
  failure_code text,
  failure_description text,
  provider_payload jsonb not null default '{}'::jsonb check (jsonb_typeof(provider_payload) = 'object'),
  created_at timestamptz not null default clock_timestamp(),
  updated_at timestamptz not null default clock_timestamp(),
  check (razorpay_qr_code_id is null or razorpay_qr_code_id ~ '^qr_[A-Za-z0-9]+$'),
  check (razorpay_payment_id is null or razorpay_payment_id ~ '^pay_[A-Za-z0-9]+$'),
  check (image_url is null or image_url like 'https://%'),
  check (short_url is null or short_url like 'https://%')
);

create index if not exists srk_razorpay_qr_codes_booking_idx
  on public.srk_razorpay_qr_codes(booking_id, created_at desc);
create index if not exists srk_razorpay_qr_codes_bill_idx
  on public.srk_razorpay_qr_codes(final_bill_id, final_bill_revision);
create index if not exists srk_razorpay_qr_codes_status_idx
  on public.srk_razorpay_qr_codes(provider_status, updated_at);

alter table public.srk_razorpay_qr_codes enable row level security;
revoke all on public.srk_razorpay_qr_codes from anon, authenticated;
grant all on public.srk_razorpay_qr_codes to service_role;

alter table public.srk_razorpay_webhook_events
  add column if not exists razorpay_qr_code_id text;
create index if not exists srk_razorpay_webhook_qr_idx
  on public.srk_razorpay_webhook_events(razorpay_qr_code_id)
  where razorpay_qr_code_id is not null;

create or replace function public.srk_service_reserve_razorpay_qr(
  p_booking_id uuid,
  p_customer_user_id uuid,
  p_final_bill_id uuid,
  p_idempotency_key text
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_booking public.service_bookings%rowtype;
  v_bill public.srk_booking_final_bills%rowtype;
  v_existing public.srk_razorpay_qr_codes%rowtype;
  v_id uuid;
  v_amount bigint;
begin
  if coalesce(auth.role(),'') <> 'service_role' then
    raise exception 'SERVICE_ROLE_REQUIRED' using errcode='42501';
  end if;
  if p_booking_id is null or p_customer_user_id is null or p_final_bill_id is null
     or p_idempotency_key is null or length(p_idempotency_key) not between 8 and 160 then
    raise exception 'INVALID_QR_RESERVATION_INPUT' using errcode='22023';
  end if;

  select * into v_booking from public.service_bookings
    where id=p_booking_id for update;
  if not found or v_booking.customer_user_id is distinct from p_customer_user_id then
    raise exception 'BOOKING_CUSTOMER_MISMATCH';
  end if;
  if v_booking.status <> 'completed'
     or lower(coalesce(v_booking.payment_status,'')) in ('paid','completed','refunded')
     or lower(coalesce(v_booking.payment_method,'')) not in ('online','upi','card') then
    raise exception 'BOOKING_NOT_PAYABLE';
  end if;

  select * into v_bill from public.srk_booking_final_bills
    where id=p_final_bill_id and booking_id=p_booking_id
      and status in ('issued','approved') for update;
  if not found or v_bill.total_amount is null then
    raise exception 'FINAL_BILL_NOT_PAYABLE';
  end if;
  v_amount := round(v_bill.total_amount * 100)::bigint;
  if v_amount not between 100 and 1000000000 then
    raise exception 'INVALID_FINAL_BILL_AMOUNT';
  end if;

  select * into v_existing from public.srk_razorpay_qr_codes
    where idempotency_key=p_idempotency_key for update;
  if found then
    if v_existing.booking_id <> p_booking_id or v_existing.final_bill_id <> p_final_bill_id
       or v_existing.amount_paise <> v_amount then
      raise exception 'QR_IDEMPOTENCY_KEY_CONFLICT';
    end if;
    return jsonb_build_object('success',true,'existing',true,'qr',to_jsonb(v_existing));
  end if;

  if exists (
    select 1 from public.srk_razorpay_qr_codes q
    where q.booking_id=p_booking_id and q.provider_status in ('creating','active','reconciliation_required')
  ) then
    raise exception 'ACTIVE_QR_ALREADY_EXISTS';
  end if;

  insert into public.srk_razorpay_qr_codes(
    booking_id,final_bill_id,customer_user_id,final_bill_revision,
    amount_paise,idempotency_key,provider_status
  ) values (
    p_booking_id,p_final_bill_id,p_customer_user_id,v_bill.revision_no,
    v_amount,p_idempotency_key,'creating'
  ) returning id into v_id;

  return jsonb_build_object('success',true,'existing',false,'qr_id',v_id,
    'amount_paise',v_amount,'currency','INR','usage','single_use','fixed_amount',true,
    'type','upi_qr','final_bill_revision',v_bill.revision_no);
end;
$$;

create or replace function public.srk_service_attach_razorpay_qr(
  p_qr_id uuid,
  p_razorpay_qr_code_id text,
  p_image_url text,
  p_short_url text,
  p_close_by timestamptz,
  p_provider_payload jsonb
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare v_qr public.srk_razorpay_qr_codes%rowtype;
begin
  if coalesce(auth.role(),'') <> 'service_role' then
    raise exception 'SERVICE_ROLE_REQUIRED' using errcode='42501';
  end if;
  if p_qr_id is null or coalesce(p_razorpay_qr_code_id,'') !~ '^qr_[A-Za-z0-9]+$'
     or p_image_url not like 'https://%' or p_short_url not like 'https://%'
     or p_close_by is null or p_close_by <= clock_timestamp()
     or jsonb_typeof(p_provider_payload) <> 'object' then
    raise exception 'INVALID_QR_PROVIDER_RESPONSE' using errcode='22023';
  end if;
  select * into v_qr from public.srk_razorpay_qr_codes where id=p_qr_id for update;
  if not found then raise exception 'QR_RESERVATION_NOT_FOUND'; end if;
  if v_qr.provider_status <> 'creating' then
    if v_qr.razorpay_qr_code_id=p_razorpay_qr_code_id then
      return jsonb_build_object('success',true,'already_attached',true);
    end if;
    raise exception 'QR_RESERVATION_NOT_ATTACHABLE';
  end if;
  update public.srk_razorpay_qr_codes
  set razorpay_qr_code_id=p_razorpay_qr_code_id,image_url=p_image_url,
      short_url=p_short_url,close_by=p_close_by,provider_status='active',
      provider_payload=p_provider_payload,updated_at=clock_timestamp()
  where id=p_qr_id;
  return jsonb_build_object('success',true,'already_attached',false);
end;
$$;

revoke all on function public.srk_service_reserve_razorpay_qr(uuid,uuid,uuid,text) from public, anon, authenticated;
revoke all on function public.srk_service_attach_razorpay_qr(uuid,text,text,text,timestamptz,jsonb) from public, anon, authenticated;
grant execute on function public.srk_service_reserve_razorpay_qr(uuid,uuid,uuid,text) to service_role;
grant execute on function public.srk_service_attach_razorpay_qr(uuid,text,text,text,timestamptz,jsonb) to service_role;
