create or replace function public.srk_admin_get_booking_contacts()
returns table(booking_id uuid, customer_phone text, electrician_phone text)
language plpgsql stable security definer
set search_path = pg_catalog, public, auth, pg_temp
as $$
begin
  if auth.uid() is null or public.is_srk_admin() is not true then
    raise exception 'Admin access required' using errcode = '42501';
  end if;
  return query
    select b.id, b.phone, ep.phone
    from public.service_bookings b
    left join public.electrician_profiles ep on ep.id = b.assigned_electrician_id
    order by b.created_at desc limit 100;
end;
$$;
revoke all on function public.srk_admin_get_booking_contacts() from public, anon;
grant execute on function public.srk_admin_get_booking_contacts() to authenticated;
