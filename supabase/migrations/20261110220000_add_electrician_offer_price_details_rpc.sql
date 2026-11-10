-- Add the phone/address-free electrician offer price details RPC.
-- This migration is intentionally isolated from the broader draft quote workflow.

create or replace function public.srk_get_my_offer_price_details()
returns table (
  offer_id uuid,
  booking_id uuid,
  offer_status text,
  customer_suggested_amount numeric,
  electrician_quote_kind text,
  service_charge numeric,
  materials_amount numeric,
  quote_status text,
  quote_note text
)
language sql
stable
security definer
set search_path = pg_catalog, public, auth, pg_temp
as $function$
  select
    o.id,
    b.id,
    o.status,
    b.customer_suggested_amount,
    b.electrician_quote_kind,
    case when b.assigned_electrician_id = p.id then b.service_charge else null end,
    case when b.assigned_electrician_id = p.id then b.materials_amount else null end,
    case when b.assigned_electrician_id = p.id then b.quote_status else null end,
    case when b.assigned_electrician_id = p.id then b.quote_note else null end
  from public.job_offers o
  join public.electrician_profiles p on p.id = o.electrician_id
  join public.service_bookings b on b.id = o.booking_id
  where auth.uid() is not null
    and (p.user_id = auth.uid() or p.auth_user_id = auth.uid())
    and p.verification_status = 'approved'
    and p.active = true
  order by o.created_at desc
  limit 100;
$function$;

revoke all on function public.srk_get_my_offer_price_details() from public, anon;
grant execute on function public.srk_get_my_offer_price_details() to authenticated;
