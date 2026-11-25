
create or replace function public.srk_confirm_cash_payment(
  p_booking_id uuid,
  p_amount numeric,
  p_note text default null
)
returns boolean
language plpgsql
security definer
set search_path to 'pg_catalog','public','auth'
as $function$
declare
  v_role text;
  v_bill numeric(12,2);
  v_customer uuid;
  v_booking_status text;
  v_worker boolean;
  v_customer_confirmed boolean;
  v_worker_confirmed boolean;
  v_forced_online integer;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  select customer_user_id,status
    into v_customer,v_booking_status
  from public.service_bookings
  where id=p_booking_id
  for update;

  if not found then raise exception 'Booking not found'; end if;
  if v_booking_status<>'completed' then
    raise exception 'Customer must confirm completed work before cash payment';
  end if;

  if v_customer=auth.uid() then
    v_role:='customer';
  else
    select exists(
      select 1
      from public.srk_booking_workers bw
      join public.srk_worker_profiles wp on wp.id=bw.worker_id
      where bw.booking_id=p_booking_id
        and bw.worker_role='technician'
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

  -- The cycle counter is incremented when the booking becomes completed.
  -- Therefore do not add one here: completed counts 3 and 6 require online.
  select count(*) into v_forced_online
  from public.srk_booking_workers bw
  join public.srk_worker_profiles wp on wp.id=bw.worker_id
  join public.srk_technician_booking_cycle c on c.technician_id=wp.id
  where bw.booking_id=p_booking_id
    and bw.worker_role='technician'
    and c.completed_booking_count in (3,6);

  if v_forced_online>0 then
    raise exception 'This technician booking requires online payment';
  end if;

  if not exists(
    select 1
    from public.srk_booking_payment_evidence
    where booking_id=p_booking_id
      and payer_role=v_role
      and payment_method='cash'
      and amount=v_bill
      and verification_status='verified'
  ) then
    insert into public.srk_booking_payment_evidence(
      booking_id,submitted_by,payer_role,payment_method,amount,verification_status,note
    )
    values(p_booking_id,auth.uid(),v_role,'cash',p_amount,'verified',p_note);
  end if;

  select
    exists(
      select 1 from public.srk_booking_payment_evidence
      where booking_id=p_booking_id and payer_role='customer'
        and payment_method='cash' and amount=v_bill and verification_status='verified'
    ),
    exists(
      select 1 from public.srk_booking_payment_evidence
      where booking_id=p_booking_id and payer_role='technician'
        and payment_method='cash' and amount=v_bill and verification_status='verified'
    )
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
