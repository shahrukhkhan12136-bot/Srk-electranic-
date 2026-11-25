
alter table public.srk_booking_cancellation_events
  drop constraint if exists srk_booking_cancellation_events_actor_role_check;
alter table public.srk_booking_cancellation_events
  add constraint srk_booking_cancellation_events_actor_role_check
  check (actor_role in ('customer','technician','helper','admin'));

create or replace function public.srk_worker_cancel_booking(p_booking_worker_id uuid,p_reason text)
returns public.srk_booking_workers
language plpgsql
security definer
set search_path to 'pg_catalog','public','auth'
as $function$
declare
 v_assignment public.srk_booking_workers%rowtype;
 v_booking public.service_bookings%rowtype;
 v_worker public.srk_worker_profiles%rowtype;
 v_customer_user_id uuid;
 v_remaining integer;
 v_requested integer;
begin
 if auth.uid() is null then raise exception 'Authentication required' using errcode='42501'; end if;
 if p_booking_worker_id is null or length(btrim(coalesce(p_reason,'')))<5 then
   raise exception 'Assignment and cancellation reason are required' using errcode='22023';
 end if;
 select bw.* into v_assignment
 from public.srk_booking_workers bw
 join public.srk_worker_profiles wp on wp.id=bw.worker_id
 where bw.id=p_booking_worker_id and wp.user_id=auth.uid()
 for update of bw;
 if not found then raise exception 'Booking assignment not found for this worker' using errcode='42501'; end if;
 if v_assignment.assignment_status not in ('offered','accepted','assigned') then
   raise exception 'This assignment cannot be cancelled directly; contact Support';
 end if;
 select * into v_booking from public.service_bookings where id=v_assignment.booking_id for update;
 if not found then raise exception 'Booking not found'; end if;
 select * into v_worker from public.srk_worker_profiles where id=v_assignment.worker_id;
 if exists(select 1 from public.srk_worker_work_sessions s
   where s.booking_worker_id=v_assignment.id
     and (s.billable_seconds>0 or s.session_status in ('running','paused','completed'))) then
   raise exception 'Work has started or timer evidence exists; contact Support for review';
 end if;

 update public.srk_booking_workers
 set assignment_status='cancelled',released_at=clock_timestamp(),
     admin_note='Worker cancellation: '||btrim(p_reason),updated_at=clock_timestamp()
 where id=v_assignment.id returning * into v_assignment;
 update public.srk_worker_schedule_blocks set block_status='cancelled',updated_at=clock_timestamp()
 where booking_worker_id=v_assignment.id and block_status in ('reserved','confirmed','in_progress');

 select count(*) into v_remaining from public.srk_booking_workers
 where booking_id=v_booking.id and worker_role=v_assignment.worker_role
   and assignment_status in ('accepted','assigned','working','paused','completed');
 v_requested:=case when v_assignment.worker_role='technician'
   then v_booking.requested_technician_count else v_booking.requested_helper_count end;

 if v_remaining<v_requested then
   update public.srk_booking_matching_queue
   set queue_status='pending',next_attempt_at=clock_timestamp(),updated_at=clock_timestamp()
   where booking_id=v_booking.id and queue_status not in ('cancelled','fulfilled');
   if v_assignment.worker_role='technician' and v_remaining=0 and v_booking.status in ('confirmed','assigned') then
     update public.service_bookings set status='new' where id=v_booking.id;
   end if;
 end if;

 insert into public.srk_booking_cancellation_events(booking_id,actor_user_id,actor_role,reason)
 values(v_booking.id,auth.uid(),v_worker.worker_type,p_reason);

 select customer_user_id into v_customer_user_id from public.service_bookings where id=v_booking.id;
 if v_customer_user_id is not null then
   insert into public.srk_app_notifications(user_id,notification_type,title,body,related_booking_id,deep_link)
   values(v_customer_user_id,'worker_assignment_cancelled','Worker assignment cancelled',
     'A '||v_worker.worker_type||' cancelled their assignment. SRK ELECTRONIC is searching for a replacement. Reason: '||btrim(p_reason),
     v_booking.id,'/bookings/'||v_booking.id::text);
 end if;
 insert into public.srk_app_notifications(user_id,notification_type,title,body,related_booking_id,deep_link)
 select au.user_id,'worker_assignment_cancelled','Worker cancelled an assignment',
   'Worker '||v_worker.worker_code||' cancelled booking '||coalesce(v_booking.order_number,v_booking.id::text)||'. Reason: '||btrim(p_reason),
   v_booking.id,'/admin/bookings/'||v_booking.id::text
 from public.srk_admin_users au;
 return v_assignment;
end
$function$;
revoke all on function public.srk_worker_cancel_booking(uuid,text) from public,anon;
grant execute on function public.srk_worker_cancel_booking(uuid,text) to authenticated;
