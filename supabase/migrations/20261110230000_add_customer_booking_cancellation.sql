create or replace function public.srk_customer_cancel_my_booking(p_booking_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, auth, pg_temp
as $$
declare
  v_booking public.service_bookings%rowtype;
begin
  if auth.uid() is null then
    raise exception 'Customer login required' using errcode = '42501';
  end if;
  if p_booking_id is null then raise exception 'Booking ID required'; end if;
  select * into v_booking
    from public.service_bookings
   where id = p_booking_id and customer_user_id = auth.uid()
   for update;
  if not found then raise exception 'Booking not found'; end if;
  if v_booking.assigned_electrician_id is not null
     or v_booking.status not in ('new','confirmed') then
    raise exception 'Booking can no longer be cancelled from the customer app';
  end if;
  update public.service_bookings set status = 'cancelled' where id = p_booking_id;
  return jsonb_build_object('success', true, 'status', 'cancelled');
end;
$$;
revoke all on function public.srk_customer_cancel_my_booking(uuid) from public, anon;
grant execute on function public.srk_customer_cancel_my_booking(uuid) to authenticated;
