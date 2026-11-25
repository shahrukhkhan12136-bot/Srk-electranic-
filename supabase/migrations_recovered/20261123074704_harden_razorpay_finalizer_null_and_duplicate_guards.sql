
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
  if coalesce(p_razorpay_order_id,'') !~ '^order_[A-Za-z0-9]+$'
     or coalesce(p_razorpay_payment_id,'') !~ '^pay_[A-Za-z0-9]+$'
     or coalesce(p_currency,'')<>'INR' or p_amount_paise is null or p_amount_paise<100 then
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
  if v_booking.razorpay_payment_id is not null and v_booking.razorpay_payment_id<>p_razorpay_payment_id then
    raise exception 'A different Razorpay payment is already linked to this booking';
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
revoke all on function public.srk_service_finalize_razorpay_payment(text,text,bigint,text) from public, anon, authenticated;
grant execute on function public.srk_service_finalize_razorpay_payment(text,text,bigint,text) to service_role;
