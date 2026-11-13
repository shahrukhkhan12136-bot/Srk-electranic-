-- Prefer the immutable server-approved labour bill on the customer payment
-- receipt. Keep the legacy fallback only where the full paid amount is exactly
-- the legacy service charge; never infer or include materials.

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
  v_bill public.srk_booking_labour_bills%rowtype;
  v_has_bill boolean := false;
  v_labour_amount numeric(12,2);
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

  select * into v_bill
    from public.srk_booking_labour_bills
   where booking_id = p_booking_id;
  v_has_bill := found;

  if v_has_bill
     and v_bill.labour_amount_paise > 0
     and v_bill.labour_amount_paise = round(v_bill.labour_amount * 100)::bigint
     and v_bill.labour_amount_paise = round(v_booking.amount_paid * 100)::bigint then
    v_labour_amount := v_bill.labour_amount;
  elsif not v_has_bill
     and v_booking.service_charge is not null
     and round(v_booking.service_charge,2) = round(v_booking.amount_paid,2) then
    v_labour_amount := round(v_booking.service_charge,2);
  else
    v_labour_amount := null;
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
    'labour_amount', v_labour_amount,
    'description', 'सत्यापित बुकिंग भुगतान की रसीद',
    'document_type', 'payment_receipt'
  );
end;
$function$;

revoke all on function public.srk_customer_get_payment_receipt(uuid) from public, anon;
grant execute on function public.srk_customer_get_payment_receipt(uuid) to authenticated;

comment on function public.srk_customer_get_payment_receipt(uuid) is
'Returns only the authenticated customer own verified payment receipt. Prefers immutable labour bill and excludes materials; legacy fallback requires service_charge to equal the entire paid amount. Not a tax invoice.';
