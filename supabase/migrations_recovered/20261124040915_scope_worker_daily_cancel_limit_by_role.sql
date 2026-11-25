create or replace function public.srk_worker_cancel_booking(p_booking_worker_id uuid, p_reason text)
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
 v_daily_count integer;
 v_request public.srk_worker_cancellation_approval_requests%rowtype;
 v_case public.srk_support_cases%rowtype;
begin
 if auth.uid() is null then raise exception 'Authentication required' using errcode='42501'; end if;
 if p_booking_worker_id is null or length(btrim(coalesce(p_reason,'')))<5 then
   raise exception 'Assignment and cancellation reason are required' using errcode='22023'; end if;
 select bw.* into v_assignment from public.srk_booking_workers bw
 join public.srk_worker_profiles wp on wp.id=bw.worker_id
 where bw.id=p_booking_worker_id and wp.user_id=auth.uid() for update of bw;
 if not found then raise exception 'Booking assignment not found for this worker' using errcode='42501'; end if;
 if v_assignment.assignment_status not in ('offered','accepted','assigned') then
   raise exception 'This assignment cannot be cancelled directly; contact Support'; end if;
 select * into v_booking from public.service_bookings where id=v_assignment.booking_id for update;
 if not found then raise exception 'Booking not found'; end if;
 select * into v_worker from public.srk_worker_profiles where id=v_assignment.worker_id;
 if exists(select 1 from public.srk_worker_work_sessions s where s.booking_worker_id=v_assignment.id
   and (s.billable_seconds>0 or s.session_status in ('running','paused','completed'))) then
   raise exception 'Work has started or timer evidence exists; contact Support for review'; end if;
 select * into v_request from public.srk_worker_cancellation_approval_requests where booking_worker_id=v_assignment.id for update;
 if found and v_request.request_status='pending' then
   update public.srk_booking_workers set cancellation_request_status='pending',updated_at=clock_timestamp()
   where id=v_assignment.id returning * into v_assignment; return v_assignment;
 elsif found and v_request.request_status='rejected' then
   raise exception 'Admin rejected this cancellation request. Contact Support for help';
 elsif found and v_request.request_status='cancelled' then
   raise exception 'This cancellation request is no longer active';
 end if;
 if not (found and v_request.request_status='approved') then
   select count(*) into v_daily_count from public.srk_booking_cancellation_events e
   where e.actor_user_id=auth.uid() and e.actor_role=v_assignment.worker_role
     and (e.cancelled_at at time zone 'Asia/Kolkata')::date=(clock_timestamp() at time zone 'Asia/Kolkata')::date;
   if v_daily_count>=2 then
     insert into public.srk_support_cases(booking_id,raised_by,raised_by_role,category,subject,description,priority)
     values(v_booking.id,auth.uid(),v_assignment.worker_role,'worker_cancellation_approval',
       'Approval required for third daily cancellation',
       'Worker requested cancellation after reaching the daily limit of two. Reason: '||btrim(p_reason),'high')
     returning * into v_case;
     insert into public.srk_support_case_events(case_id,actor_user_id,action,new_status,note)
     values(v_case.id,auth.uid(),'worker_cancellation_approval_requested','open',p_reason);
     insert into public.srk_worker_cancellation_approval_requests(
       booking_worker_id,booking_id,worker_id,worker_user_id,worker_role,cancellation_reason,support_case_id)
     values(v_assignment.id,v_booking.id,v_assignment.worker_id,auth.uid(),v_assignment.worker_role,p_reason,v_case.id)
     returning * into v_request;
     update public.srk_booking_workers set cancellation_request_status='pending',updated_at=clock_timestamp()
     where id=v_assignment.id returning * into v_assignment;
     insert into public.srk_app_notifications(user_id,notification_type,title,body,related_booking_id)
     select au.user_id,'worker_cancellation_approval','Worker cancellation approval required',
       'A '||v_assignment.worker_role||' has requested a third cancellation today. Please review support case '||
       coalesce(v_case.case_number,v_case.id::text)||'.',v_booking.id from public.srk_admin_users au;
     return v_assignment;
   end if;
 end if;
 update public.srk_booking_workers set assignment_status='cancelled',released_at=clock_timestamp(),
   cancellation_request_status=case when v_request.request_status='approved' then 'approved' else null end,
   admin_note='Worker cancellation: '||btrim(p_reason),updated_at=clock_timestamp()
 where id=v_assignment.id returning * into v_assignment;
 update public.srk_worker_schedule_blocks set block_status='cancelled',updated_at=clock_timestamp()
 where booking_worker_id=v_assignment.id and block_status in ('reserved','confirmed','in_progress');
 select count(*) into v_remaining from public.srk_booking_workers
 where booking_id=v_booking.id and worker_role=v_assignment.worker_role
   and assignment_status in ('accepted','assigned','working','paused','completed');
 v_requested:=case when v_assignment.worker_role='technician' then v_booking.requested_technician_count
   else v_booking.requested_helper_count end;
 update public.srk_booking_no_show_reports set status='cancelled',resolved_at=clock_timestamp(),
   resolution_note='Worker assignment cancelled during no-show wait'
 where booking_worker_id=p_booking_worker_id and status='waiting';
 if v_remaining<v_requested then
   update public.srk_booking_matching_queue set queue_status='pending',next_attempt_at=clock_timestamp(),updated_at=clock_timestamp()
   where booking_id=v_booking.id and queue_status<>'cancelled';
   if v_assignment.worker_role='technician' and v_remaining=0 and v_booking.status in ('confirmed','assigned') then
     update public.service_bookings set status='new' where id=v_booking.id; end if;
 end if;
 insert into public.srk_booking_cancellation_events(booking_id,actor_user_id,actor_role,reason)
 values(v_booking.id,auth.uid(),v_assignment.worker_role,p_reason);
 if v_request.request_status='approved' then
   update public.srk_worker_cancellation_approval_requests set completed_at=clock_timestamp() where id=v_request.id; end if;
 select customer_user_id into v_customer_user_id from public.service_bookings where id=v_booking.id;
 if v_customer_user_id is not null then
   insert into public.srk_app_notifications(user_id,notification_type,title,body,related_booking_id,deep_link)
   values(v_customer_user_id,'worker_assignment_cancelled','Worker assignment cancelled',
     'A '||v_assignment.worker_role||' cancelled their assignment. SRK ELECTRONIC is searching for a replacement. Reason: '||btrim(p_reason),
     v_booking.id,'/bookings/'||v_booking.id::text); end if;
 insert into public.srk_app_notifications(user_id,notification_type,title,body,related_booking_id,deep_link)
 select au.user_id,'worker_assignment_cancelled','Worker cancelled an assignment',
   'Worker '||v_worker.worker_code||' cancelled booking '||coalesce(v_booking.order_number,v_booking.id::text)||
   '. Reason: '||btrim(p_reason),v_booking.id,'/admin/bookings/'||v_booking.id::text from public.srk_admin_users au;
 return v_assignment;
end
$function$;