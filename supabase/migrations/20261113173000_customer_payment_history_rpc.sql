-- Customer-safe, ownership-scoped payment history.
-- Returns a unified read-only timeline from booking payment summaries and
-- recorded payment/refund events. Never returns provider IDs, admin notes,
-- internal errors, idempotency keys, or staff identifiers.

create or replace function public.srk_customer_get_payment_history(
  p_limit integer default 25,
  p_offset integer default 0
)
returns table (
  event_id uuid,
  event_type text,
  booking_id uuid,
  amount numeric,
  status text,
  payment_method text,
  occurred_at timestamptz,
  description text
)
language plpgsql
stable
security definer
set search_path = pg_catalog, public, auth, pg_temp
as $function$
declare
  v_uid uuid := auth.uid();
  v_limit integer := least(greatest(coalesce(p_limit, 25), 1), 50);
  v_offset integer := greatest(coalesce(p_offset, 0), 0);
begin
  if v_uid is null then
    raise exception 'Customer login required' using errcode = '42501';
  end if;

  if v_offset > 10000 then
    raise exception 'Pagination offset is too large' using errcode = '22023';
  end if;

  return query
  with customer_bookings as (
    select b.id, b.payment_method, b.payment_status, b.amount_paid,
           b.payment_verified_at, b.created_at
    from public.service_bookings b
    where b.customer_user_id = v_uid
  ),
  events as (
    -- Booking-level payment record: only show a verified/recorded positive amount.
    select
      b.id as event_id,
      'payment'::text as event_type,
      b.id as booking_id,
      b.amount_paid as amount,
      coalesce(nullif(b.payment_status, ''), 'recorded') as status,
      case
        when lower(coalesce(b.payment_method, '')) in ('cash','upi','card','online','razorpay','bank_transfer')
          then lower(b.payment_method)
        else 'other'
      end as payment_method,
      coalesce(b.payment_verified_at, b.created_at) as occurred_at,
      'बुकिंग भुगतान'::text as description
    from customer_bookings b
    where b.payment_status = 'paid'
      and b.payment_verified_at is not null
      and coalesce(b.amount_paid, 0) > 0

    union all

    -- Customer-submitted refund request state; never expose admin_note.
    select
      r.id,
      'refund_request'::text,
      r.booking_id,
      r.amount,
      r.status,
      null::text,
      coalesce(r.updated_at, r.created_at),
      'रिफंड अनुरोध'::text
    from public.srk_booking_refund_requests r
    join customer_bookings b on b.id = r.booking_id
    where r.customer_user_id = v_uid

    union all

    -- Provider refund status only; exclude provider IDs, errors and admin fields.
    select
      rr.id,
      'refund'::text,
      rr.booking_id,
      rr.amount,
      rr.status,
      'razorpay'::text,
      coalesce(rr.processed_at, rr.updated_at, rr.created_at),
      'ऑनलाइन रिफंड'::text
    from public.srk_razorpay_refunds rr
    join customer_bookings b on b.id = rr.booking_id

    union all

    -- Admin-recorded offline/cash/UPI payment; expose no staff note/reference.
    select
      mp.id,
      'manual_payment'::text,
      mp.booking_id,
      mp.amount,
      'recorded'::text,
      case
        when lower(coalesce(mp.payment_method, '')) in ('cash','upi','card','bank_transfer')
          then lower(mp.payment_method)
        else 'other'
      end,
      mp.recorded_at,
      'दर्ज किया गया भुगतान'::text
    from public.srk_manual_payment_entries mp
    join customer_bookings b on b.id = mp.booking_id

    union all

    -- Manual refund entry linked through its payment entry and owned booking.
    select
      mr.id,
      'manual_refund'::text,
      mp.booking_id,
      mr.amount,
      'recorded'::text,
      null::text,
      mr.recorded_at,
      'दर्ज किया गया रिफंड'::text
    from public.srk_manual_refund_entries mr
    join public.srk_manual_payment_entries mp on mp.id = mr.payment_entry_id
    join customer_bookings b on b.id = mp.booking_id
  )
  select e.event_id, e.event_type, e.booking_id, e.amount, e.status,
         e.payment_method, e.occurred_at, e.description
  from events e
  order by e.occurred_at desc, e.event_id desc
  limit v_limit offset v_offset;
end;
$function$;

revoke all on function public.srk_customer_get_payment_history(integer, integer) from public, anon;
grant execute on function public.srk_customer_get_payment_history(integer, integer) to authenticated;
