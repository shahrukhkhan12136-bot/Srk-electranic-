
create or replace function public.srk_customer_choose_payment_method(
 p_booking_id uuid,
 p_method text
)
returns public.service_bookings
language plpgsql
security definer
set search_path to 'pg_catalog','public','auth'
as $function$
declare
 v_booking public.service_bookings%rowtype;
 v_method text;
 v_forced_online boolean;
begin
 if auth.uid() is null then raise exception 'Authentication required'; end if;
 v_method:=lower(btrim(coalesce(p_method,'')));
 if v_method not in ('cash','online','upi','card') then
  raise exception 'Choose Cash, Online, UPI or Card';
 end if;
 select * into v_booking from public.service_bookings
 where id=p_booking_id and customer_user_id=auth.uid() for update;
 if not found then raise exception 'Customer booking not found'; end if;
 if v_booking.status<>'completed' then
  raise exception 'Payment can be selected after customer confirms completed work';
 end if;
 if lower(coalesce(v_booking.payment_status,'')) in ('paid','completed','refunded') then
  raise exception 'Payment is already completed or refunded';
 end if;
 if not exists(select 1 from public.srk_booking_final_bills
  where booking_id=p_booking_id and status in ('issued','approved')) then
  raise exception 'Final bill is not available';
 end if;
 select exists(select 1 from public.srk_technician_booking_sequence s
  where s.booking_id=p_booking_id and mod(s.sequence_number,3)=0)
 into v_forced_online;
 if v_forced_online and v_method='cash' then
  raise exception 'This technician booking requires online payment';
 end if;
 if v_booking.razorpay_payment_id is not null then
  raise exception 'A Razorpay payment is already linked; payment method cannot be changed';
 end if;
 if v_booking.razorpay_order_id is not null and
  lower(coalesce(v_booking.payment_method,'')) <>
  (case v_method when 'upi' then 'upi' when 'card' then 'card' when 'cash' then 'cash' else 'online' end) then
  raise exception 'A payment order already exists; payment method cannot be changed until reconciliation';
 end if;
 update public.service_bookings
 set payment_method=case when v_method='upi' then 'UPI'
  when v_method='card' then 'Card' when v_method='cash' then 'Cash' else 'Online' end
 where id=p_booking_id returning * into v_booking;
 return v_booking;
end;
$function$;
revoke all on function public.srk_customer_choose_payment_method(uuid,text) from public,anon;
grant execute on function public.srk_customer_choose_payment_method(uuid,text) to authenticated,service_role;
