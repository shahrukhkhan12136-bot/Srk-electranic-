-- Add a versioned electrician-offer RPC that exposes only the non-sensitive order number.
-- Existing RPC remains untouched for backward compatibility.
begin;

create or replace function public.srk_get_my_offer_details_v2()
returns table(
  offer_id uuid,
  offer_status text,
  match_level text,
  offer_created_at timestamptz,
  booking_id uuid,
  service_type text,
  state text,
  district text,
  pincode text,
  preferred_date date,
  preferred_time time,
  work_details text,
  quoted_amount numeric,
  booking_status text,
  customer_name text,
  customer_phone text,
  address text,
  location_lat double precision,
  location_lng double precision,
  service_charge numeric,
  materials_amount numeric,
  quote_status text,
  quote_note text,
  order_number text
)
language sql
stable
security definer
set search_path to 'pg_catalog', 'public', 'auth', 'pg_temp'
as $function$
  select
    o.id,
    o.status,
    o.match_level,
    o.created_at,
    b.id,
    b.service_type,
    b.state,
    b.district,
    b.pincode,
    b.preferred_date,
    b.preferred_time,
    b.work_details,
    b.quoted_amount,
    b.status,
    case when b.assigned_electrician_id = p.id
      and b.status in ('assigned','inspection','awaiting_quote_approval','quote_approved','in_progress','completed')
      then b.customer_name else null end,
    case when b.assigned_electrician_id = p.id
      and b.status in ('assigned','inspection','awaiting_quote_approval','quote_approved','in_progress','completed')
      then b.phone else null end,
    case when b.assigned_electrician_id = p.id
      and b.status in ('assigned','inspection','awaiting_quote_approval','quote_approved','in_progress','completed')
      then b.address else null end,
    case when b.assigned_electrician_id = p.id
      and b.status in ('assigned','inspection','awaiting_quote_approval','quote_approved','in_progress','completed')
      then b.location_lat else null end,
    case when b.assigned_electrician_id = p.id
      and b.status in ('assigned','inspection','awaiting_quote_approval','quote_approved','in_progress','completed')
      then b.location_lng else null end,
    case when b.assigned_electrician_id = p.id
      and b.status in ('assigned','inspection','awaiting_quote_approval','quote_approved','in_progress','completed')
      then b.service_charge else null end,
    case when b.assigned_electrician_id = p.id
      and b.status in ('assigned','inspection','awaiting_quote_approval','quote_approved','in_progress','completed')
      then b.materials_amount else null end,
    case when b.assigned_electrician_id = p.id
      and b.status in ('assigned','inspection','awaiting_quote_approval','quote_approved','in_progress','completed')
      then b.quote_status else null end,
    case when b.assigned_electrician_id = p.id
      and b.status in ('assigned','inspection','awaiting_quote_approval','quote_approved','in_progress','completed')
      then b.quote_note else null end,
    b.order_number
  from public.job_offers o
  join public.electrician_profiles p on p.id = o.electrician_id
  join public.service_bookings b on b.id = o.booking_id
  where p.user_id = auth.uid()
    and p.verification_status = 'approved'
    and p.active = true
  order by o.created_at desc
  limit 100;
$function$;

revoke all on function public.srk_get_my_offer_details_v2() from public, anon;
grant execute on function public.srk_get_my_offer_details_v2() to authenticated;

commit;
