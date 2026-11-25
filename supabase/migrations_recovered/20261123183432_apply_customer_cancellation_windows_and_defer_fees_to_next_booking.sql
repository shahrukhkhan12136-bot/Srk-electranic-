
create or replace function public.srk_customer_cancel_booking_v2(p_booking_id uuid,p_reason text)
returns public.service_bookings
language plpgsql
security definer
set search_path to 'pg_catalog','public','auth'
as $function$
declare
 v public.service_bookings%rowtype;
 v_fee_amount numeric(12,2):=0;
 v_fee_basis text;
begin
 if auth.uid() is null then raise exception 'Authentication required' using errcode='42501'; end if;
 if length(coalesce(p_reason,''))<5 then raise exception 'Cancellation reason is required'; end if;
 select * into v from public.service_bookings where id=p_booking_id and customer_user_id=auth.uid() for update;
 if not found then raise exception 'Customer booking not found'; end if;
 if v.status not in ('new','confirmed','assigned') then
   raise exception 'Booking can no longer be cancelled directly; contact Support so timer evidence is preserved';
 end if;
 if exists(select 1 from public.srk_worker_work_sessions s join public.srk_booking_workers bw on bw.id=s.booking_worker_id
   where bw.booking_id=p_booking_id and (s.billable_seconds>0 or s.session_status in ('running','paused'))) then
   raise exception 'Work has started or billable time exists; contact Support for review';
 end if;

 if clock_timestamp()>v.created_at+interval '5 minutes' then
   if exists(select 1 from public.srk_booking_workers bw where bw.booking_id=p_booking_id and bw.arrived_at is not null) then
     v_fee_amount:=99; v_fee_basis:='technician_arrived';
   elsif exists(select 1 from public.srk_booking_workers bw where bw.booking_id=p_booking_id and bw.on_the_way_at is not null) then
     v_fee_amount:=49; v_fee_basis:='technician_on_the_way';
   end if;
 end if;

 update public.service_bookings set status='cancelled',admin_change_reason='Customer cancellation: '||p_reason
 where id=p_booking_id returning * into v;
 update public.srk_booking_matching_queue set queue_status='cancelled',updated_at=clock_timestamp()
 where booking_id=p_booking_id;
 update public.srk_worker_work_sessions set session_status='cancelled',ended_at=clock_timestamp(),updated_at=clock_timestamp()
 where booking_worker_id in(select id from public.srk_booking_workers where booking_id=p_booking_id)
   and session_status='not_started';
 update public.srk_booking_workers set assignment_status='cancelled',admin_note='Customer cancellation: '||p_reason,updated_at=clock_timestamp()
 where booking_id=p_booking_id and assignment_status in ('offered','accepted','assigned');
 update public.srk_worker_schedule_blocks set block_status='cancelled',updated_at=clock_timestamp()
 where booking_worker_id in(select id from public.srk_booking_workers where booking_id=p_booking_id)
   and block_status in ('reserved','confirmed','in_progress');
 update public.srk_booking_location_shares set ended_at=clock_timestamp()
 where booking_id=p_booking_id and ended_at is null;

 insert into public.srk_booking_cancellation_events(booking_id,actor_user_id,actor_role,reason)
 values(p_booking_id,auth.uid(),'customer',p_reason);

 if v_fee_amount>0 then
   insert into public.srk_booking_cancellation_fees(
     cancelled_booking_id,customer_user_id,fee_amount,fee_basis,status
   ) values(p_booking_id,auth.uid(),v_fee_amount,v_fee_basis,'pending')
   on conflict(cancelled_booking_id) do nothing;
 end if;

 -- If this booking carried an unpaid cancellation fee from an earlier order,
 -- return that fee to the pending customer ledger; cancellation never collects it.
 update public.srk_booking_cancellation_fees
 set status='pending',next_booking_id=null,added_to_next_booking_at=null
 where next_booking_id=p_booking_id and status='added_to_next_booking';
 update public.service_bookings set pending_cancellation_fee_amount=0 where id=p_booking_id;

 insert into public.srk_app_notifications(user_id,notification_type,title,body,related_booking_id)
 select w.user_id,'booking_cancelled','Booking cancelled','Customer cancelled the booking. Reason: '||p_reason,p_booking_id
 from public.srk_booking_workers bw join public.srk_worker_profiles w on w.id=bw.worker_id
 where bw.booking_id=p_booking_id;
 return v;
end
$function$;
