-- Complete approved Customer refund requests when a verified manual refund is recorded.
-- This migration never contacts a payment provider; the Admin enters the external refund reference.
create or replace function public.srk_admin_record_manual_refund(
  p_booking_id uuid,p_reference text,p_note text default null
)
returns jsonb
language plpgsql
security definer
set search_path='pg_catalog','public','auth','pg_temp'
as $$
declare
  v_booking public.service_bookings%rowtype;
  v_payment public.srk_manual_payment_entries%rowtype;
  v_payout public.srk_electrician_payouts%rowtype;
  v_request public.srk_booking_refund_requests%rowtype;
  v_reference text:=btrim(coalesce(p_reference,''));
begin
  if auth.uid() is null or not public.is_srk_admin() then
    raise exception 'ADMIN_ACCESS_REQUIRED' using errcode='42501';
  end if;
  if p_booking_id is null or length(v_reference) not between 4 and 120
     or (p_note is not null and length(p_note)>250) then
    raise exception 'INVALID_MANUAL_REFUND_REFERENCE_OR_NOTE' using errcode='22023';
  end if;

  select * into v_booking from public.service_bookings
    where id=p_booking_id for update;
  if not found then raise exception 'BOOKING_NOT_FOUND'; end if;
  if v_booking.payment_status<>'paid' or v_booking.payment_verified_at is null
     or coalesce(v_booking.amount_paid,0)<=0 then
    raise exception 'ONLY_VERIFIED_PAID_BOOKINGS_CAN_BE_REFUNDED';
  end if;
  if v_booking.razorpay_order_id is not null or v_booking.razorpay_payment_id is not null
     or lower(coalesce(v_booking.payment_method,'')) like '%razorpay%'
     or lower(coalesce(v_booking.payment_method,'')) like '%online%' then
    raise exception 'RAZORPAY_REFUNDS_MUST_USE_RAZORPAY_RECONCILIATION';
  end if;

  select * into v_request from public.srk_booking_refund_requests
    where booking_id=p_booking_id for update;
  if found and v_request.status is distinct from 'approved' then
    raise exception 'CUSTOMER_REFUND_REQUEST_REQUIRES_MAIN_ADMIN_APPROVAL' using errcode='55000';
  end if;

  select * into v_payment from public.srk_manual_payment_entries
    where booking_id=p_booking_id for update;
  if not found then raise exception 'MANUAL_PAYMENT_AUDIT_RECORD_NOT_FOUND'; end if;
  if round(v_booking.amount_paid,2)<>round(v_payment.amount,2) then
    raise exception 'RECORDED_PAYMENT_AMOUNT_DOES_NOT_MATCH_BOOKING_AMOUNT';
  end if;
  if exists(select 1 from public.srk_manual_refund_entries r where r.booking_id=p_booking_id) then
    raise exception 'A_REFUND_HAS_ALREADY_BEEN_RECORDED_FOR_THIS_BOOKING';
  end if;

  select * into v_payout from public.srk_electrician_payouts
    where booking_id=p_booking_id for update;
  if found then
    if v_payout.payout_status='paid' then
      raise exception 'ELECTRICIAN_PAYOUT_ALREADY_PAID_RECOVERY_REQUIRED';
    end if;
    if v_payout.payout_status='pending' then
      update public.srk_electrician_payouts
        set payout_status='blocked',payout_note='Manual refund processed',updated_at=clock_timestamp()
        where id=v_payout.id;
    elsif v_payout.payout_status<>'blocked' then
      raise exception 'ELECTRICIAN_PAYOUT_STATE_REQUIRES_ADMIN_RECONCILIATION';
    end if;
  end if;

  insert into public.srk_manual_refund_entries(
    booking_id,payment_entry_id,amount,refund_reference,note,recorded_by
  ) values (
    p_booking_id,v_payment.id,v_payment.amount,v_reference,
    nullif(btrim(coalesce(p_note,'')),''),auth.uid()
  );

  update public.service_bookings set payment_status='refunded'
    where id=p_booking_id and payment_status='paid';
  if not found then
    raise exception 'BOOKING_REFUND_STATE_CHANGED' using errcode='40001';
  end if;

  -- The verified manual refund is now final. Close the previously blocked
  -- unpaid payout exactly as the Razorpay recovery path does.
  if v_payout.id is not null then
    update public.srk_electrician_payouts
       set payout_status='refunded',
           payout_note='Manual refund completed',
           updated_at=clock_timestamp()
     where id=v_payout.id and payout_status='blocked';
    if not found then
      raise exception 'BLOCKED_PAYOUT_COULD_NOT_BE_CLOSED_AS_REFUNDED' using errcode='55000';
    end if;
  end if;

  if v_request.id is not null then
    update public.srk_booking_refund_requests
      set status='processed',processed_at=coalesce(processed_at,clock_timestamp()),
          updated_at=clock_timestamp()
      where id=v_request.id and status='approved';
  end if;

  return jsonb_build_object('success',true,'booking_id',p_booking_id,
    'amount',v_payment.amount,'refund_reference',v_reference,
    'customer_request_status',case when v_request.id is not null then 'processed' else null end);
end;
$$;

revoke all on function public.srk_admin_record_manual_refund(uuid,text,text) from public,anon;
grant execute on function public.srk_admin_record_manual_refund(uuid,text,text) to authenticated;
