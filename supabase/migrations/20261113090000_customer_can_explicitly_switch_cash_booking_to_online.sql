-- Let the authenticated customer explicitly switch an unassigned Cash booking
-- to Online when the assigned electrician's every-third-booking rule requires it.
-- This never silently changes a customer's payment choice and never charges now.

create or replace function public.srk_customer_change_payment_method(
  p_booking_id uuid,
  p_payment_method text
)
returns jsonb
language plpgsql
security definer
set search_path to 'pg_catalog','public','auth','pg_temp'
as $function$
declare
  v_booking public.service_bookings%rowtype;
begin
  if auth.uid() is null then
    raise exception 'ग्राहक लॉगिन आवश्यक है' using errcode = '42501';
  end if;
  if p_booking_id is null
     or p_payment_method is distinct from 'Razorpay ऑनलाइन भुगतान' then
    raise exception 'केवल ग्राहक द्वारा चुना गया Online भुगतान स्वीकार है';
  end if;

  select * into v_booking
    from public.service_bookings
   where id = p_booking_id
     and customer_user_id = auth.uid()
   for update;

  if not found then
    raise exception 'आपकी बुकिंग नहीं मिली' using errcode = '42501';
  end if;
  if v_booking.status not in ('new','confirmed')
     or v_booking.assigned_electrician_id is not null
     or v_booking.payment_status not in ('unpaid','pending')
     or v_booking.payment_verified_at is not null
     or v_booking.razorpay_order_id is not null
     or v_booking.razorpay_payment_id is not null then
    raise exception 'इस बुकिंग में भुगतान तरीका अब नहीं बदला जा सकता';
  end if;
  if lower(coalesce(v_booking.payment_method,'')) not like '%cash%'
     and lower(coalesce(v_booking.payment_method,'')) not like '%नकद%' then
    raise exception 'यह बुकिंग पहले से Cash के रूप में दर्ज नहीं है';
  end if;

  update public.service_bookings
     set payment_method = 'Razorpay ऑनलाइन भुगतान'
   where id = p_booking_id
     and customer_user_id = auth.uid()
     and assigned_electrician_id is null
     and status in ('new','confirmed')
     and payment_status in ('unpaid','pending')
     and payment_verified_at is null
     and razorpay_order_id is null
     and razorpay_payment_id is null;

  if not found then
    raise exception 'भुगतान तरीका अपडेट नहीं हुआ; कृपया Refresh करें';
  end if;

  return jsonb_build_object(
    'success',true,
    'booking_id',p_booking_id,
    'payment_method','Razorpay ऑनलाइन भुगतान',
    'payment_collected',false
  );
end;
$function$;

revoke all on function public.srk_customer_change_payment_method(uuid,text) from public, anon;
grant execute on function public.srk_customer_change_payment_method(uuid,text) to authenticated;

comment on function public.srk_customer_change_payment_method(uuid,text) is
'Customer-only explicit Cash-to-Online choice change for their own unassigned unpaid booking. Does not initiate payment.';
