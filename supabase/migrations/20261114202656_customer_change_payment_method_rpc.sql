-- Customer may switch an unassigned cash booking to Razorpay before dispatch.
-- This only records the payment preference; it does not create an order or collect money.

create or replace function public.srk_customer_change_payment_method(
  p_booking_id uuid,
  p_payment_method text
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_uid uuid := auth.uid();
  v_updated_id uuid;
begin
  if v_uid is null then
    raise exception 'AUTHENTICATION_REQUIRED' using errcode='28000';
  end if;
  if p_booking_id is null
     or p_payment_method is distinct from 'Razorpay à¤à¤¨à¤²à¤¾à¤à¤¨ à¤­à¥à¤à¤¤à¤¾à¤¨' then
    raise exception 'INVALID_PAYMENT_METHOD_CHANGE' using errcode='22023';
  end if;

  update public.service_bookings
     set payment_method='Razorpay à¤à¤¨à¤²à¤¾à¤à¤¨ à¤­à¥à¤à¤¤à¤¾à¤¨'
   where id=p_booking_id
     and customer_user_id=v_uid
     and status in ('new','confirmed')
     and assigned_electrician_id is null
     and payment_status not in ('paid','refunded')
     and coalesce(amount_paid,0)=0
     and razorpay_order_id is null
     and razorpay_payment_id is null
     and lower(coalesce(payment_method,'')) like '%cash%'
  returning id into v_updated_id;

  if not found then
    raise exception 'PAYMENT_METHOD_CHANGE_NOT_ALLOWED' using errcode='42501';
  end if;
  return true;
end;
$function$;

revoke all on function public.srk_customer_change_payment_method(uuid,text) from public,anon;
grant execute on function public.srk_customer_change_payment_method(uuid,text) to authenticated;

comment on function public.srk_customer_change_payment_method(uuid,text) is
  'Allows the booking owner to switch only an unassigned, unpaid new/confirmed cash booking to Razorpay preference. No payment is collected.';
