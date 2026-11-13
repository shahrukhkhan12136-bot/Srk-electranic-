-- Preserve direct customer/electrician calling access after the electrician has accepted the booking.
-- The accepted relationship does not end merely because the work status becomes completed.
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
    and b.status in ('assigned','inspection','awaiting_quote_approval','quote_approved','in_progress','completed');
end;
$function$;

revoke all on function private.srk_get_customer_call_contacts_impl() from public, anon;
grant usage on schema private to authenticated;
grant execute on function private.srk_get_customer_call_contacts_impl() to authenticated;

create or replace function public.srk_get_customer_call_contacts()
returns table (
  booking_id uuid,
  booking_status text,
  electrician_name text,
  electrician_phone text
)
language sql
stable
security invoker
set search_path = public, private, pg_temp
as $function$
  select * from private.srk_get_customer_call_contacts_impl();
$function$;

revoke all on function public.srk_get_customer_call_contacts() from public, anon;
grant execute on function public.srk_get_customer_call_contacts() to authenticated;
