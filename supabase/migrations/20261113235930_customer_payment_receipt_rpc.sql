-- Customer-owned receipt for a verified booking payment.
-- This is a payment receipt, not a tax invoice or final labour invoice.

create or replace function public.srk_customer_get_payment_receipt(p_booking_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = pg_catalog, public, auth, pg_temp
as $function$
declare
  v_uid uuid := auth.uid();
  v_booking public.service_bookings%rowtype;
begin
  if v_uid is null then
    raise exception 'Customer login required' using errcode = '42501';
  end if;
  if p_booking_id is null then
    raise exception 'Booking ID required' using errcode = '22023';
  end if;

  select * into v_booking
    from public.service_bookings
   where id = p_booking_id
     and customer_user_id = v_uid;

  if not found then
    raise exception 'Booking not found' using errcode = '42501';
  end if;

  if v_booking.payment_status <> 'paid'
     or v_booking.payment_verified_at is null
     or coalesce(v_booking.amount_paid,0) <= 0 then
    raise exception 'Only verified paid bookings have a payment receipt'
      using errcode = '55000';
  end if;

  return jsonb_build_object(
    'receipt_reference', 'SRK-PAY-' || upper(left(replace(v_booking.id::text,'-',''),12)),
    'booking_id', v_booking.id,
    'customer_name', v_booking.customer_name,
    'service_type', v_booking.service_type,
    'address', v_booking.address,
    'district', v_booking.district,
    'state', v_booking.state,
    'pincode', v_booking.pincode,
    'booking_date', v_booking.created_at,
    'payment_date', v_booking.payment_verified_at,
    'payment_method', case
      when lower(coalesce(v_booking.payment_method,'')) in
        ('cash','upi','card','online','razorpay','bank_transfer','bank transfer')
      then lower(v_booking.payment_method)
      else 'other'
    end,
    'amount_paid', round(v_booking.amount_paid,2),
    'labour_amount', case when v_booking.service_charge is not null
      and round(v_booking.service_charge,2) = round(v_booking.amount_paid,2)
      then round(v_booking.service_charge,2) else null end,
    'description', 'सत्यापित बुकिंग भुगतान की रसीद',
    'document_type', 'payment_receipt'
  );
end;
$function$;

revoke all on function public.srk_customer_get_payment_receipt(uuid) from public, anon;
grant execute on function public.srk_customer_get_payment_receipt(uuid) to authenticated;

comment on function public.srk_customer_get_payment_receipt(uuid) is
'Returns only the authenticated customer own verified payment receipt. This is not a tax invoice; it exposes no material names, material amounts, phone numbers, provider IDs, internal notes, or staff identifiers.';
