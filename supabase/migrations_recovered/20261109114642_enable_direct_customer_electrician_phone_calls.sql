create or replace function private.srk_get_customer_call_contacts_impl()
returns table(booking_id uuid, booking_status text, electrician_name text, electrician_phone text)
language plpgsql
stable
security definer
set search_path to 'public', 'pg_temp'
as $function$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'Authentication required';
  end if;

  return query
  select b.id, b.status, ep.display_name, ep.phone
  from public.service_bookings b
  join public.electrician_profiles ep on ep.id = b.assigned_electrician_id
  where b.customer_user_id = v_uid
    and b.assigned_electrician_id is not null
    and b.status in ('assigned','inspection','awaiting_quote_approval','quote_approved','in_progress');
end;
$function$;

create or replace function public.srk_get_my_offer_details()
returns table(
  offer_id uuid, offer_status text, match_level text, offer_created_at timestamp with time zone,
  booking_id uuid, service_type text, state text, district text, pincode text,
  preferred_date date, preferred_time time without time zone, work_details text,
  quoted_amount numeric, booking_status text, customer_name text, customer_phone text,
  address text, location_lat double precision, location_lng double precision,
  service_charge numeric, materials_amount numeric, quote_status text, quote_note text
)
language sql
stable
security definer
set search_path to 'pg_catalog', 'public', 'auth', 'pg_temp'
as $function$
 select o.id,o.status,o.match_level,o.created_at,b.id,b.service_type,b.state,b.district,b.pincode,
 b.preferred_date,b.preferred_time,b.work_details,b.quoted_amount,b.status,
 case when b.assigned_electrician_id=p.id then b.customer_name else null end,
 case when b.assigned_electrician_id=p.id then b.phone else null end,
 case when b.assigned_electrician_id=p.id then b.address else null end,
 case when b.assigned_electrician_id=p.id then b.location_lat else null end,
 case when b.assigned_electrician_id=p.id then b.location_lng else null end,
 case when b.assigned_electrician_id=p.id then b.service_charge else null end,
 case when b.assigned_electrician_id=p.id then b.materials_amount else null end,
 case when b.assigned_electrician_id=p.id then b.quote_status else null end,
 case when b.assigned_electrician_id=p.id then b.quote_note else null end
 from public.job_offers o
 join public.electrician_profiles p on p.id=o.electrician_id
 join public.service_bookings b on b.id=o.booking_id
 where p.user_id=auth.uid() and p.verification_status='approved' and p.active=true
 order by o.created_at desc limit 100;
$function$;