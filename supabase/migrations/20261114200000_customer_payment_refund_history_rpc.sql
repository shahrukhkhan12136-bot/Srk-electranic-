-- Customer-scoped, paginated payment and refund event history.
-- The original payment remains visible after a refund; the separate refund
-- event records the money returned. No internal/admin notes or provider payloads.

create or replace function public.srk_customer_get_payment_history(
  p_limit integer default 25,
  p_offset integer default 0
)
returns table (
  event_type text,
  booking_id uuid,
  amount numeric(12,2),
  description text,
  status text,
  payment_method text,
  occurred_at timestamptz
)
language plpgsql
stable
security definer
set search_path = pg_catalog, public, auth, pg_temp
as $function$
declare
  v_uid uuid := auth.uid();
  v_limit integer := least(greatest(coalesce(p_limit,25),1),50);
  v_offset integer := greatest(coalesce(p_offset,0),0);
begin
  if v_uid is null then
    raise exception 'AUTHENTICATION_REQUIRED' using errcode='42501';
  end if;

  return query
  select events.event_type,events.booking_id,events.amount,
         events.description,events.status,events.payment_method,events.occurred_at
  from (
    select
      case when b.razorpay_payment_id is null then 'manual_payment' else 'payment' end::text as event_type,
      b.id as booking_id,
      round(b.amount_paid,2)::numeric(12,2) as amount,
      'बुकिंग का सत्यापित भुगतान'::text as description,
      'paid'::text as status,
      case
        when lower(coalesce(b.payment_method,'')) like '%cash%' then 'cash'
        when lower(coalesce(b.payment_method,'')) like '%upi%' then 'upi'
        when lower(coalesce(b.payment_method,'')) like '%card%' then 'card'
        when lower(coalesce(b.payment_method,'')) like '%bank%' then 'bank_transfer'
        when lower(coalesce(b.payment_method,'')) like '%razorpay%'
          or lower(coalesce(b.payment_method,'')) like '%online%' then 'razorpay'
        else 'other'
      end::text as payment_method,
      b.payment_verified_at as occurred_at
    from public.service_bookings b
    where b.customer_user_id=v_uid
      and b.payment_status in ('paid','refunded')
      and b.payment_verified_at is not null
      and coalesce(b.amount_paid,0)>0

    union all

    select 'refund_request'::text,r.booking_id,
      round(r.amount,2)::numeric(12,2),
      'बुकिंग रिफंड अनुरोध'::text,r.status::text,
      null::text,r.created_at
    from public.srk_booking_refund_requests r
    where r.customer_user_id=v_uid

    union all

    select 'refund'::text,rf.booking_id,
      round(rf.amount,2)::numeric(12,2),
      'ऑनलाइन भुगतान का रिफंड'::text,rf.status::text,
      'razorpay'::text,coalesce(rf.processed_at,rf.updated_at,rf.created_at)
    from public.srk_razorpay_refunds rf
    join public.service_bookings b on b.id=rf.booking_id
    where b.customer_user_id=v_uid

    union all

    select 'manual_refund'::text,mr.booking_id,
      round(mr.amount,2)::numeric(12,2),
      'मैनुअल रिफंड दर्ज'::text,'processed'::text,
      null::text,mr.recorded_at
    from public.srk_manual_refund_entries mr
    join public.service_bookings b on b.id=mr.booking_id
    where b.customer_user_id=v_uid
  ) events
  order by events.occurred_at desc nulls last,events.booking_id desc,events.event_type
  limit v_limit offset v_offset;
end;
$function$;

revoke all on function public.srk_customer_get_payment_history(integer,integer) from public,anon;
grant execute on function public.srk_customer_get_payment_history(integer,integer) to authenticated;

comment on function public.srk_customer_get_payment_history(integer,integer) is
'Returns paginated payment/refund events only for auth.uid() customer bookings; excludes admin notes, private provider metadata and other customers.';
