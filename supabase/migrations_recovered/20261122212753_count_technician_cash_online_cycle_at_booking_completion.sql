
create or replace function public.srk_customer_choose_payment_method(p_booking_id uuid, p_method text)
returns public.service_bookings
language plpgsql
security definer
set search_path to 'pg_catalog','public','auth'
as $function$
declare
  v_booking public.service_bookings%rowtype;
  v_forced_online boolean;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;
  if lower(p_method) not in ('cash','online','upi','card') then
    raise exception 'Choose Cash, Online, UPI or Card';
  end if;

  select * into v_booking
  from public.service_bookings
  where id=p_booking_id and customer_user_id=auth.uid()
  for update;
  if not found then raise exception 'Customer booking not found'; end if;
  if v_booking.status<>'completed' then
    raise exception 'Payment can be selected after customer confirms completed work';
  end if;
  if lower(coalesce(v_booking.payment_status,'')) in ('paid','completed') then
    raise exception 'Payment is already completed';
  end if;
  if not exists (
    select 1 from public.srk_booking_final_bills
    where booking_id=p_booking_id and status in ('issued','approved')
  ) then
    raise exception 'Final bill is not available';
  end if;

  select exists(
    select 1
    from public.srk_booking_workers bw
    join public.srk_technician_booking_cycle c on c.technician_id=bw.worker_id
    where bw.booking_id=p_booking_id
      and bw.worker_role='technician'
      and c.completed_booking_count in (3,6)
  ) into v_forced_online;

  if v_forced_online and lower(p_method)='cash' then
    raise exception 'This technician booking requires online payment';
  end if;

  update public.service_bookings
  set payment_method=case
    when lower(p_method)='upi' then 'UPI'
    when lower(p_method)='card' then 'Card'
    when lower(p_method)='cash' then 'Cash'
    else 'Online'
  end
  where id=p_booking_id
  returning * into v_booking;

  return v_booking;
end
$function$;

create or replace function public.srk_on_booking_payment_completed()
returns trigger
language plpgsql
security definer
set search_path to 'pg_catalog','public','auth'
as $function$
declare
  v_bw record;
  v_count bigint;
  v_next bigint;
  v_method text;
  v_normalized_method text;
  v_payment_done boolean;
begin
  v_payment_done := new.status='completed'
    and lower(coalesce(new.payment_status,'')) in ('paid','completed');
  v_method := lower(coalesce(new.payment_method,''));
  v_normalized_method := case
    when v_method in ('upi','card','online') then 'online'
    when v_method='cash' then 'cash'
    else null
  end;

  -- Count each technician's successfully completed booking at completion time,
  -- not later when the customer happens to finish payment.
  if new.status='completed' and old.status is distinct from 'completed' then
    for v_bw in
      select bw.worker_id
      from public.srk_booking_workers bw
      join public.srk_worker_profiles wp on wp.id=bw.worker_id
      where bw.booking_id=new.id
        and bw.worker_role='technician'
        and wp.worker_type='technician'
        and bw.assignment_status in ('completed','released')
      order by bw.worker_id
    loop
      insert into public.srk_technician_booking_cycle(technician_id)
      values(v_bw.worker_id)
      on conflict(technician_id) do nothing;

      select completed_booking_count into v_count
      from public.srk_technician_booking_cycle
      where technician_id=v_bw.worker_id
      for update;

      v_next := v_count+1;

      if v_next in (3,6) and v_payment_done and v_normalized_method<>'online' then
        raise exception 'Technician completed booking number % must be paid online',v_next;
      end if;

      update public.srk_technician_booking_cycle
      set completed_booking_count=v_next,
          last_completed_at=clock_timestamp(),
          updated_at=clock_timestamp()
      where technician_id=v_bw.worker_id;

      insert into public.srk_technician_booking_sequence(
        technician_id,booking_id,sequence_number,payment_method
      )
      values(
        v_bw.worker_id,new.id,v_next,
        case when v_payment_done then v_normalized_method else null end
      )
      on conflict(technician_id,booking_id) do nothing;
    end loop;
  end if;

  -- Payment may be completed later. Record its method against the already
  -- assigned completed-booking sequence and only then post earnings.
  if v_payment_done
     and not (old.status='completed' and lower(coalesce(old.payment_status,'')) in ('paid','completed')) then
    if v_normalized_method is null then
      raise exception 'A valid payment method is required before marking payment completed';
    end if;

    if exists(
      select 1
      from public.srk_technician_booking_sequence s
      where s.booking_id=new.id
        and s.sequence_number in (3,6)
        and v_normalized_method<>'online'
    ) then
      raise exception 'Technician booking number 3 or 6 must be paid online';
    end if;

    update public.srk_technician_booking_sequence
    set payment_method=v_normalized_method
    where booking_id=new.id;

    update public.srk_worker_earnings
    set payment_method=v_normalized_method,updated_at=clock_timestamp()
    where booking_id=new.id;

    perform public.srk_post_one_worker_earning(e.id)
    from public.srk_worker_earnings e
    where e.booking_id=new.id;
  end if;

  return new;
end
$function$;
