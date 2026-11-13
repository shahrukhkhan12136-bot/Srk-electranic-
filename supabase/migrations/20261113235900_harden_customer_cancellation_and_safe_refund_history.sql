-- Harden customer self-cancellation and provide a customer-safe refund-request history.
-- Source-only until separately approved for database application.

create or replace function public.srk_customer_cancel_my_booking(p_booking_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, auth, pg_temp
as $function$
declare
  v_booking public.service_bookings%rowtype;
begin
  if auth.uid() is null then
    raise exception 'Customer login required' using errcode = '42501';
  end if;
  if p_booking_id is null then
    raise exception 'Booking ID required' using errcode = '22023';
  end if;

  select * into v_booking
    from public.service_bookings
   where id = p_booking_id
     and customer_user_id = auth.uid()
   for update;

  if not found then
    raise exception 'Booking not found' using errcode = '42501';
  end if;

  if v_booking.assigned_electrician_id is not null
     or v_booking.status not in ('new','confirmed') then
    raise exception 'Booking can no longer be cancelled from the customer app'
      using errcode = '55000';
  end if;

  -- A paid, verified, or in-flight payment must go through the refund workflow.
  if coalesce(v_booking.payment_status, 'unpaid') not in ('unpaid','failed')
     or coalesce(v_booking.amount_paid, 0) > 0
     or v_booking.payment_verified_at is not null
     or v_booking.razorpay_payment_id is not null then
    raise exception 'Payment exists or is pending; submit a refund request instead'
      using errcode = '55000';
  end if;

  update public.service_bookings
     set status = 'cancelled'
   where id = p_booking_id;

  return jsonb_build_object('success', true, 'status', 'cancelled');
end;
$function$;

revoke all on function public.srk_customer_cancel_my_booking(uuid) from public, anon;
grant execute on function public.srk_customer_cancel_my_booking(uuid) to authenticated;


create or replace function public.srk_customer_list_my_booking_refund_requests()
returns table (
  id uuid,
  booking_id uuid,
  amount numeric,
  reason text,
  status text,
  created_at timestamptz,
  updated_at timestamptz,
  processed_at timestamptz
)
language plpgsql
stable
security definer
set search_path = pg_catalog, public, auth, pg_temp
as $function$
begin
  if auth.uid() is null then
    raise exception 'Customer login required' using errcode = '42501';
  end if;

  return query
  select r.id, r.booking_id, r.amount, r.reason, r.status,
         r.created_at, r.updated_at, r.processed_at
    from public.srk_booking_refund_requests r
   where r.customer_user_id = auth.uid()
   order by r.created_at desc
   limit 100;
end;
$function$;

revoke all on function public.srk_customer_list_my_booking_refund_requests() from public, anon;
grant execute on function public.srk_customer_list_my_booking_refund_requests() to authenticated;
