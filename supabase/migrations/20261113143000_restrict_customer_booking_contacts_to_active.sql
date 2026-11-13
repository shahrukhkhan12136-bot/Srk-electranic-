-- Remove the independent completed-booking phone-number exposure.
-- Customers may call an assigned, approved electrician only while work is active.
-- This is a feature-branch migration; do not apply to production without approval.

create or replace function public.srk_customer_get_my_booking_contacts()
returns table (
  booking_id uuid,
  electrician_phone text,
  booking_status text
)
language sql
stable
security definer
set search_path = pg_catalog, public, auth, pg_temp
as $function$
  select b.id, ep.phone, b.status
  from public.service_bookings b
  join public.electrician_profiles ep
    on ep.id = b.assigned_electrician_id
  where auth.uid() is not null
    and b.customer_user_id = auth.uid()
    and b.assigned_electrician_id is not null
    and b.status in (
      'assigned',
      'inspection',
      'awaiting_quote_approval',
      'quote_approved',
      'quote_rejected',
      'in_progress'
    )
    and ep.verification_status = 'approved'
    and ep.active = true
  order by b.created_at desc
  limit 100;
$function$;

-- Keep this customer-scoped RPC callable only by authenticated sessions.
revoke all on function public.srk_customer_get_my_booking_contacts() from public, anon;
grant execute on function public.srk_customer_get_my_booking_contacts() to authenticated;
