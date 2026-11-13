-- Customer-owned complaint creation RPC.
-- Source-only: do not apply to the live project without the user's separate approval.

create or replace function public.srk_customer_create_booking_complaint(
  p_booking_id uuid,
  p_category text,
  p_description text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_customer_id uuid := auth.uid();
  v_complaint_id uuid;
begin
  if v_customer_id is null then
    raise exception 'AUTHENTICATION_REQUIRED' using errcode = '28000';
  end if;

  if p_booking_id is null
     or p_category is null
     or p_category not in (
       'service_quality',
       'electrician_behavior',
       'billing_payment',
       'delay_no_show',
       'safety',
       'other'
     )
     or p_description is null
     or pg_catalog.length(pg_catalog.btrim(p_description)) not between 20 and 2000 then
    raise exception 'INVALID_COMPLAINT_INPUT' using errcode = '22023';
  end if;

  -- Serialize each customer's quota check to prevent concurrent requests
  -- from bypassing the 10-complaints-per-24-hours limit.
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(v_customer_id::text, 0)
  );

  perform 1
    from public.service_bookings b
   where b.id = p_booking_id
     and b.customer_user_id = v_customer_id
   for share;

  if not found then
    raise exception 'BOOKING_NOT_OWNED' using errcode = '42501';
  end if;

  if (
    select pg_catalog.count(*)
      from public.srk_booking_complaints c
     where c.customer_user_id = v_customer_id
       and c.created_at >= pg_catalog.now() - interval '24 hours'
  ) >= 10 then
    raise exception 'COMPLAINT_DAILY_LIMIT_REACHED' using errcode = 'P0001';
  end if;

  insert into public.srk_booking_complaints
    (booking_id, customer_user_id, category, description)
  values
    (p_booking_id, v_customer_id, p_category, pg_catalog.btrim(p_description))
  returning id into v_complaint_id;

  insert into public.srk_booking_complaint_events
    (complaint_id, actor_user_id, actor_role, from_status, to_status, note)
  values
    (v_complaint_id, v_customer_id, 'customer', null, 'new', 'ग्राहक ने शिकायत दर्ज की');

  return v_complaint_id;
end;
$function$;

revoke all on function public.srk_customer_create_booking_complaint(uuid,text,text) from public, anon;
grant execute on function public.srk_customer_create_booking_complaint(uuid,text,text) to authenticated;
