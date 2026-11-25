create or replace function public.srk_customer_get_booking_payment_cycle(p_booking_id uuid)
returns table(online_required boolean,technician_sequence_number bigint,helper_sequence_number bigint)
language plpgsql stable security definer set search_path to 'pg_catalog','public','auth'
as $function$
begin
 if auth.uid() is null then raise exception 'Authentication required' using errcode='42501'; end if;
 if not exists(select 1 from public.service_bookings b where b.id=p_booking_id and b.customer_user_id=auth.uid() and b.status='completed') then
  raise exception 'Completed customer booking not found' using errcode='42501';
 end if;
 return query
 select
  exists(select 1 from public.srk_technician_booking_sequence s where s.booking_id=p_booking_id and mod(s.sequence_number,3)=0)
  or exists(select 1 from public.srk_helper_booking_sequence s where s.booking_id=p_booking_id and mod(s.sequence_number,3)=0),
  (select max(s.sequence_number) from public.srk_technician_booking_sequence s where s.booking_id=p_booking_id),
  (select max(s.sequence_number) from public.srk_helper_booking_sequence s where s.booking_id=p_booking_id);
end
$function$;
revoke all on function public.srk_customer_get_booking_payment_cycle(uuid) from public,anon;
grant execute on function public.srk_customer_get_booking_payment_cycle(uuid) to authenticated;