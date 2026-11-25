
create or replace function public.srk_customer_choose_payment_method(p_booking_id uuid,p_method text)
returns public.service_bookings
language plpgsql security definer
set search_path=pg_catalog,public,auth
as $$
declare v_booking public.service_bookings%rowtype; v_forced_online boolean;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if lower(p_method) not in ('cash','online','upi','card') then raise exception 'Choose Cash, Online, UPI or Card'; end if;
  select * into v_booking from public.service_bookings
  where id=p_booking_id and customer_user_id=auth.uid() for update;
  if not found then raise exception 'Customer booking not found'; end if;
  if v_booking.payment_status='paid' then raise exception 'Payment is already completed'; end if;
  if not exists(select 1 from public.srk_booking_final_bills where booking_id=p_booking_id and status in ('issued','approved')) then
    raise exception 'Payment method can be selected after the final bill is issued';
  end if;
  select exists(
    select 1 from public.srk_booking_workers bw
    join public.srk_technician_booking_cycle c on c.technician_id=bw.worker_id
    where bw.booking_id=p_booking_id and bw.worker_role='technician'
      and (c.completed_booking_count+1) in (3,6)
  ) into v_forced_online;
  if v_forced_online and lower(p_method)='cash' then raise exception 'This technician booking requires online payment'; end if;
  update public.service_bookings set payment_method=case when lower(p_method) in ('upi','card') then initcap(lower(p_method)) else initcap(lower(p_method)) end
  where id=p_booking_id returning * into v_booking;
  return v_booking;
end $$;
revoke all on function public.srk_customer_choose_payment_method(uuid,text) from public,anon;
grant execute on function public.srk_customer_choose_payment_method(uuid,text) to authenticated;
