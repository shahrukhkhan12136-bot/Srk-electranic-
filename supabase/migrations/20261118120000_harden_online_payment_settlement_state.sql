-- Harden new-Catalogue online settlement against unexpected booking states and replay mismatches.
-- Source-only migration; apply only in the separately approved database phase.
BEGIN;

create or replace function public.srk_service_role_record_online_booking_payment(
  p_booking_id uuid,p_order_id text,p_payment_id text,p_amount_paise bigint
)
returns jsonb language plpgsql security definer set search_path=''
as $$
declare
  v_booking public.service_bookings%rowtype;
  v_labour public.srk_booking_labour_bills%rowtype;
  v_fee bigint;
  v_expected bigint;
  v_item record;
begin
  if coalesce(auth.jwt()->>'role','')<>'service_role' then raise exception 'SERVICE_ROLE_ONLY' using errcode='42501'; end if;
  if p_payment_id is null or p_order_id is null
     or p_payment_id !~ '^pay_[A-Za-z0-9]+$'
     or p_order_id !~ '^order_[A-Za-z0-9]+$' then
    raise exception 'INVALID_PROVIDER_PAYMENT_OR_ORDER_ID';
  end if;
  if p_amount_paise is null or p_amount_paise<1 then
    raise exception 'INVALID_CAPTURED_AMOUNT';
  end if;
  select * into v_booking from public.service_bookings where id=p_booking_id for update;
  if not found then raise exception 'BOOKING_NOT_FOUND'; end if;
  if v_booking.status<>'completed' then raise exception 'BOOKING_NOT_COMPLETED'; end if;
  if v_booking.selected_category is null then raise exception 'NEW_CATALOGUE_BOOKING_REQUIRED'; end if;
  if lower(coalesce(v_booking.payment_method,'')) not like '%razorpay%'
     and lower(coalesce(v_booking.payment_method,'')) not like '%online%' then
    raise exception 'BOOKING_PAYMENT_METHOD_IS_NOT_ONLINE';
  end if;
  select * into v_labour from public.srk_booking_labour_bills where booking_id=p_booking_id;
  if not found then raise exception 'IMMUTABLE_LABOUR_BILL_REQUIRED'; end if;
  select coalesce(sum(amount_paise),0) into v_fee from public.srk_booking_cancellation_fee_items
    where booking_id=p_booking_id and status='reserved';
  v_expected:=v_labour.labour_amount_paise+v_fee;
  if p_amount_paise<>v_expected then raise exception 'CAPTURED_AMOUNT_DOES_NOT_MATCH_LABOUR_PLUS_CANCELLATION_FEES'; end if;
  if v_booking.razorpay_order_id is null or v_booking.razorpay_order_id<>p_order_id then raise exception 'RAZORPAY_ORDER_MISMATCH'; end if;
  if v_booking.payment_status='refunded' then raise exception 'BOOKING_ALREADY_REFUNDED'; end if;
  if v_booking.payment_status='paid' then
    if v_booking.razorpay_payment_id=p_payment_id then
      return jsonb_build_object('success',true,'already_processed',true,'total_amount_paise',v_expected);
    end if;
    raise exception 'BOOKING_ALREADY_PAID_WITH_DIFFERENT_PAYMENT';
  end if;
  if v_booking.payment_status not in ('unpaid','pending') then
    raise exception 'BOOKING_PAYMENT_STATE_NOT_PAYABLE';
  end if;
  if v_booking.razorpay_payment_id is not null or v_booking.payment_verified_at is not null
     or coalesce(v_booking.amount_paid,0)<>0 then
    raise exception 'BOOKING_HAS_UNEXPECTED_EXISTING_PAYMENT_EVIDENCE';
  end if;
  update public.service_bookings set payment_status='paid',amount_paid=p_amount_paise/100.0,
    razorpay_payment_id=p_payment_id,payment_verified_at=now() where id=p_booking_id;

  for v_item in select * from public.srk_booking_cancellation_fee_items
    where booking_id=p_booking_id and status='reserved' order by created_at,id for update
  loop
    insert into public.srk_cancellation_fee_ledger(debt_id,booking_id,source_booking_id,
      customer_user_id,entry_type,direction,amount_paise,payment_reference,idempotency_key,note)
    values(v_item.debt_id,p_booking_id,v_item.source_booking_id,v_booking.customer_user_id,
      'online_collection','credit',v_item.amount_paise,p_payment_id,
      'cancel-fee:online:srk-credit:'||v_item.id::text,
      'Online payment cancellation-fee component credited to SRK cancellation ledger')
    on conflict(idempotency_key) do nothing;
    update public.srk_booking_cancellation_fee_items set status='settled',settled_at=now()
      where id=v_item.id and status='reserved';
    update public.srk_customer_cancellation_fee_debts set status='settled',settled_at=now()
      where id=v_item.debt_id and status='reserved';
  end loop;
  return jsonb_build_object('success',true,'already_processed',false,
    'labour_amount_paise',v_labour.labour_amount_paise,
    'cancellation_fee_amount_paise',v_fee,'total_amount_paise',v_expected);
end;
$$;

REVOKE ALL ON FUNCTION public.srk_service_role_record_online_booking_payment(uuid,text,text,bigint) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.srk_service_role_record_online_booking_payment(uuid,text,text,bigint) TO service_role;

COMMIT;
