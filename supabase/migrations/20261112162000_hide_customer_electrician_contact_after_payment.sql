-- Once a customer payment is recorded, do not return the electrician's
-- private phone number through the customer contact RPC, regardless of booking status.
create or replace function private.srk_get_customer_call_contacts_impl()
returns table (
  booking_id uuid,
  booking_status text,
  electrician_name text,
  electrician_phone text
)
language plpgsql
stable
security definer
set search_path = public, pg_temp
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
    and b.status in ('assigned','inspection','awaiting_quote_approval','quote_approved','in_progress')
    and b.payment_status is distinct from 'paid';
end;
$function$;
