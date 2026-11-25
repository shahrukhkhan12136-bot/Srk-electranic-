CREATE OR REPLACE FUNCTION public.srk_customer_choose_payment_method(p_booking_id uuid,p_method text)
RETURNS public.service_bookings
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'pg_catalog','public','auth'
AS $function$
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

 select
  exists(select 1 from public.srk_technician_booking_sequence s
   where s.booking_id=p_booking_id and mod(s.sequence_number,3)=0)
  or
  exists(select 1 from public.srk_helper_booking_sequence s
   where s.booking_id=p_booking_id and mod(s.sequence_number,3)=0)
 into v_forced_online;
 if v_forced_online and v_method='cash' then
  raise exception 'This booking requires online payment because the Technician or Helper is on booking number 3 or 6';
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
end
$function$;

CREATE OR REPLACE FUNCTION public.srk_confirm_cash_payment(p_booking_id uuid,p_amount numeric,p_note text DEFAULT NULL::text)
RETURNS boolean
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'pg_catalog','public','auth'
AS $function$
declare
 v_role text;
 v_bill numeric(12,2);
 v_customer uuid;
 v_booking_status text;
 v_payment_method text;
 v_payment_status text;
 v_worker boolean;
 v_customer_confirmed boolean;
 v_worker_confirmed boolean;
 v_forced_online boolean;
begin
 if auth.uid() is null then raise exception 'Authentication required'; end if;
 select customer_user_id,status,payment_method,payment_status
 into v_customer,v_booking_status,v_payment_method,v_payment_status
 from public.service_bookings where id=p_booking_id for update;
 if not found then raise exception 'Booking not found'; end if;
 if v_booking_status<>'completed' then
  raise exception 'Customer must confirm completed work before cash payment';
 end if;
 if lower(btrim(coalesce(v_payment_method,''))) not in ('cash','नकद (cash)','नकद') then
  raise exception 'Cash confirmation is allowed only when Cash was selected for this booking';
 end if;
 if lower(coalesce(v_payment_status,'')) in ('paid','completed','refunded') then
  raise exception 'Booking payment is already completed or refunded';
 end if;

 if v_customer=auth.uid() then
  v_role:='customer';
 else
  select exists(
   select 1 from public.srk_booking_workers bw
   join public.srk_worker_profiles wp on wp.id=bw.worker_id
   where bw.booking_id=p_booking_id and bw.worker_role='technician'
    and wp.user_id=auth.uid()
    and bw.assignment_status in ('assigned','working','paused','completed')
  ) into v_worker;
  if not v_worker then
   raise exception 'Only booking customer or assigned Technician can confirm cash';
  end if;
  v_role:='technician';
 end if;

 select total_amount into v_bill
 from public.srk_booking_final_bills
 where booking_id=p_booking_id and status in ('issued','approved');
 if v_bill is null then raise exception 'Final bill is not issued'; end if;
 if p_amount is null or p_amount<>v_bill then
  raise exception 'Cash confirmation must match final bill amount';
 end if;

 select
  exists(select 1 from public.srk_technician_booking_sequence s
   where s.booking_id=p_booking_id and mod(s.sequence_number,3)=0)
  or
  exists(select 1 from public.srk_helper_booking_sequence s
   where s.booking_id=p_booking_id and mod(s.sequence_number,3)=0)
 into v_forced_online;
 if v_forced_online then
  raise exception 'This booking requires online payment because the Technician or Helper is on booking number 3 or 6';
 end if;

 if not exists(
  select 1 from public.srk_booking_payment_evidence
  where booking_id=p_booking_id and payer_role=v_role
   and payment_method='cash' and amount=v_bill and verification_status='verified'
 ) then
  insert into public.srk_booking_payment_evidence(
   booking_id,submitted_by,payer_role,payment_method,amount,verification_status,note
  ) values(p_booking_id,auth.uid(),v_role,'cash',p_amount,'verified',p_note);
 end if;

 select
  exists(select 1 from public.srk_booking_payment_evidence
   where booking_id=p_booking_id and payer_role='customer'
    and payment_method='cash' and amount=v_bill and verification_status='verified'),
  exists(select 1 from public.srk_booking_payment_evidence
   where booking_id=p_booking_id and payer_role='technician'
    and payment_method='cash' and amount=v_bill and verification_status='verified')
 into v_customer_confirmed,v_worker_confirmed;

 if v_customer_confirmed and v_worker_confirmed then
  update public.service_bookings
  set payment_status='paid',amount_paid=v_bill,payment_verified_at=clock_timestamp()
  where id=p_booking_id;
  return true;
 end if;
 return false;
end
$function$;