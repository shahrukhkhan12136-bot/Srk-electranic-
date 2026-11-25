CREATE OR REPLACE FUNCTION public.srk_process_no_show_reports()
RETURNS integer
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'pg_catalog','public'
AS $function$
declare
 v_candidate record;
 v_report public.srk_booking_no_show_reports%rowtype;
 v_booking public.service_bookings%rowtype;
 v_customer uuid;
 v_count integer:=0;
begin
 -- Lock order is booking -> no-show report -> assignments/queue.
 for v_candidate in
  select r.id,r.booking_id
  from public.srk_booking_no_show_reports r
  where r.status='waiting' and r.review_due_at<=clock_timestamp()
  order by r.review_due_at limit 100
 loop
  select * into v_booking from public.service_bookings
  where id=v_candidate.booking_id for update skip locked;
  if not found then continue; end if;

  select * into v_report from public.srk_booking_no_show_reports
  where id=v_candidate.id and status='waiting' and review_due_at<=clock_timestamp()
  for update skip locked;
  if not found then continue; end if;

  if v_booking.status in ('completed','cancelled') then
   update public.srk_booking_no_show_reports
   set status='resolved',resolved_at=clock_timestamp(),
       resolution_note='Booking was already closed before the no-show processor ran.'
   where id=v_report.id;
   v_count:=v_count+1;
   continue;
  end if;

  if exists(
   select 1 from public.srk_booking_workers bw
   where bw.id=v_report.booking_worker_id and bw.arrived_at is not null
  ) then
   update public.srk_booking_no_show_reports
   set status='resolved',resolved_at=clock_timestamp(),
       resolution_note='Worker arrived during the 10-minute waiting window'
   where id=v_report.id;
  else
   update public.srk_booking_no_show_reports
   set status='cancelled',admin_notified_at=clock_timestamp(),resolved_at=clock_timestamp(),
       resolution_note='No-show confirmed after the 10-minute wait; cancelled without fee'
   where id=v_report.id;

   update public.service_bookings
   set status='cancelled',
       admin_change_reason='No-show auto-cancellation after 10-minute wait; no cancellation fee'
   where id=v_booking.id and status not in ('completed','cancelled');

   update public.srk_booking_matching_queue
   set queue_status='cancelled',updated_at=clock_timestamp()
   where booking_id=v_booking.id;

   update public.srk_booking_workers
   set assignment_status='cancelled',
       admin_note='No-show auto-cancellation after 10-minute wait',
       updated_at=clock_timestamp()
   where booking_id=v_booking.id
     and assignment_status in ('offered','accepted','assigned','working','paused');

   update public.srk_worker_schedule_blocks
   set block_status=case when ends_at<=clock_timestamp() then 'completed' else 'cancelled' end,
       updated_at=clock_timestamp()
   where booking_worker_id in(
    select id from public.srk_booking_workers where booking_id=v_booking.id
   ) and block_status in ('reserved','confirmed','in_progress');

   update public.srk_booking_location_shares
   set ended_at=clock_timestamp()
   where booking_id=v_booking.id and ended_at is null;

   update public.srk_booking_cancellation_fees
   set status='pending',next_booking_id=null,added_to_next_booking_at=null
   where next_booking_id=v_booking.id and status='added_to_next_booking';
   update public.service_bookings set pending_cancellation_fee_amount=0 where id=v_booking.id;

   v_customer:=v_booking.customer_user_id;
   if v_customer is not null then
    insert into public.srk_app_notifications(user_id,notification_type,title,body,related_booking_id)
    values(v_customer,'booking_no_show_cancelled','Booking cancelled due to no-show',
     '10-minute waiting period ended. Booking cancelled without any cancellation fee.',v_booking.id);
   end if;
   insert into public.srk_app_notifications(user_id,notification_type,title,body,related_booking_id)
   select au.user_id,'booking_no_show_cancelled','No-show booking auto-cancelled',
    'Booking '||v_booking.id::text||' cancelled after 10-minute wait. No fee charged.',v_booking.id
   from public.srk_admin_users au;
  end if;
  v_count:=v_count+1;
 end loop;
 return v_count;
end
$function$;