
create or replace function public.srk_admin_waive_cancellation_fee(p_fee_id uuid,p_reason text)
returns public.srk_booking_cancellation_fees
language plpgsql
security definer
set search_path to 'pg_catalog','public','auth'
as $function$
declare v_fee public.srk_booking_cancellation_fees%rowtype;
begin
 if auth.uid() is null or not public.is_srk_admin() then
   raise exception 'Main Admin permission required' using errcode='42501';
 end if;
 if p_fee_id is null or length(btrim(coalesce(p_reason,'')))<10 then
   raise exception 'Fee and waiver reason are required';
 end if;
 select * into v_fee from public.srk_booking_cancellation_fees where id=p_fee_id for update;
 if not found or v_fee.status not in ('pending','added_to_next_booking') then
   raise exception 'Only pending or attached cancellation fees can be waived';
 end if;
 if v_fee.next_booking_id is not null and exists(
   select 1 from public.srk_booking_final_bills where booking_id=v_fee.next_booking_id and status in ('issued','approved','disputed')
 ) then
   raise exception 'Fee is already part of an issued bill; use the refund/reconciliation workflow';
 end if;
 update public.srk_booking_cancellation_fees
 set status='waived',waived_by=auth.uid(),waiver_reason=btrim(p_reason)
 where id=p_fee_id returning * into v_fee;
 if v_fee.next_booking_id is not null then
   update public.service_bookings
   set pending_cancellation_fee_amount=greatest(0,pending_cancellation_fee_amount-v_fee.fee_amount)
   where id=v_fee.next_booking_id;
 end if;
 return v_fee;
end
$function$;
revoke all on function public.srk_admin_waive_cancellation_fee(uuid,text) from public,anon;
grant execute on function public.srk_admin_waive_cancellation_fee(uuid,text) to authenticated;
