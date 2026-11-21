-- Prevent customer-facing complaint history from returning internal Admin notes.
-- Harden related SECURITY DEFINER customer RPCs with an empty search_path.

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
    raise exception 'Customer login required' using errcode='42501';
  end if;
  if p_booking_id is null
     or p_category is null
     or p_category not in ('service_quality','electrician_behavior','billing_payment','delay_no_show','safety','other')
     or p_description is null
     or length(btrim(p_description)) not between 20 and 2000 then
    raise exception 'Valid booking, category and 20-2000 character description are required';
  end if;

  -- Serialize per-customer complaint submissions so concurrent requests
  -- cannot bypass the daily limit through simultaneous count/insert cycles.
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(v_customer_id::text,0)
  );

  perform 1
    from public.service_bookings b
   where b.id=p_booking_id and b.customer_user_id=v_customer_id
   for share;
  if not found then
    raise exception 'Booking not found for this customer' using errcode='42501';
  end if;

  if (
    select count(*) from public.srk_booking_complaints c
    where c.customer_user_id=v_customer_id
      and c.created_at >= pg_catalog.now() - interval '24 hours'
  ) >= 10 then
    raise exception 'Daily complaint limit reached';
  end if;

  insert into public.srk_booking_complaints
    (booking_id,customer_user_id,category,description)
  values
    (p_booking_id,v_customer_id,p_category,btrim(p_description))
  returning id into v_complaint_id;

  insert into public.srk_booking_complaint_events
    (complaint_id,actor_user_id,actor_role,from_status,to_status,note)
  values (v_complaint_id,v_customer_id,'customer',null,'new','ग्राहक ने शिकायत दर्ज की');

  return v_complaint_id;
end;
$function$;

revoke all on function public.srk_customer_create_booking_complaint(uuid,text,text) from public,anon;
grant execute on function public.srk_customer_create_booking_complaint(uuid,text,text) to authenticated;

create or replace function public.srk_customer_list_booking_complaints()
returns table(
  id uuid,booking_id uuid,category text,description text,status text,
  admin_note text,created_at timestamptz,updated_at timestamptz,
  resolved_at timestamptz,activity jsonb
)
language plpgsql
stable
security definer
set search_path = ''
as $function$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'Customer login required' using errcode='42501';
  end if;

  -- Keep the existing response shape for the current UI, but never return
  -- private Admin notes or raw event notes to the customer session.
  return query
    select c.id,c.booking_id,c.category,c.description,c.status,
           null::text,c.created_at,c.updated_at,c.resolved_at,'[]'::jsonb
      from public.srk_booking_complaints c
     where c.customer_user_id=v_uid
     order by c.created_at desc
     limit 100;
end;
$function$;

revoke all on function public.srk_customer_list_booking_complaints() from public,anon;
grant execute on function public.srk_customer_list_booking_complaints() to authenticated;

comment on function public.srk_customer_list_booking_complaints() is
  'Customer-owned complaint list. Internal Admin notes and event notes are intentionally excluded.';
