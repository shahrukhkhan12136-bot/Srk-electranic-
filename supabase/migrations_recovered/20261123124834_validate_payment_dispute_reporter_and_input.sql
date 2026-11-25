create or replace function public.srk_raise_payment_dispute(
  p_booking_id uuid,
  p_dispute_type text,
  p_description text
)
returns public.srk_booking_payment_disputes
language plpgsql
security definer
set search_path = pg_catalog, public, auth
as $function$
declare
  v_role text;
  v public.srk_booking_payment_disputes%rowtype;
  v_description text := nullif(pg_catalog.btrim(p_description), '');
  v_type text := pg_catalog.lower(pg_catalog.btrim(coalesce(p_dispute_type, '')));
begin
  if auth.uid() is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  if p_booking_id is null then
    raise exception 'Booking ID is required';
  end if;

  if v_type not in (
    'not_paid',
    'cash_not_received',
    'amount_mismatch',
    'online_payment_failed',
    'refund_delay',
    'other'
  ) then
    raise exception 'Invalid payment dispute type';
  end if;

  if v_description is null or pg_catalog.length(v_description) > 2000 then
    raise exception 'Dispute description must contain 1 to 2000 characters';
  end if;

  if exists (
    select 1
    from public.service_bookings b
    where b.id = p_booking_id
      and b.customer_user_id = auth.uid()
  ) then
    v_role := 'customer';
  else
    select w.worker_type
      into v_role
    from public.srk_booking_workers bw
    join public.srk_worker_profiles w on w.id = bw.worker_id
    where bw.booking_id = p_booking_id
      and w.user_id = auth.uid()
      and bw.assignment_status in (
        'accepted',
        'assigned',
        'working',
        'paused',
        'completed',
        'released'
      )
    limit 1;

    if v_role is null then
      raise exception 'Only the booking customer or an assigned booking worker can report a payment dispute'
        using errcode = '42501';
    end if;
  end if;

  insert into public.srk_booking_payment_disputes(
    booking_id,
    raised_by,
    raised_by_role,
    dispute_type,
    description
  )
  values (
    p_booking_id,
    auth.uid(),
    v_role,
    v_type,
    v_description
  )
  returning * into v;

  return v;
end
$function$;

revoke all on function public.srk_raise_payment_dispute(uuid,text,text) from public, anon;
grant execute on function public.srk_raise_payment_dispute(uuid,text,text) to authenticated;