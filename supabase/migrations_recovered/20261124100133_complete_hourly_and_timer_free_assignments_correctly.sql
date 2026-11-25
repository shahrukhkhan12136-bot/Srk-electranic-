CREATE OR REPLACE FUNCTION public.srk_worker_complete_assignment(
 p_booking_worker_id uuid,p_note text DEFAULT NULL
) RETURNS public.srk_booking_workers
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'pg_catalog','public','auth'
AS $function$
declare
 v_assignment public.srk_booking_workers%rowtype;
 v_booking public.service_bookings%rowtype;
 v_booking_id uuid;
 v_total_seconds bigint;
 v_remaining integer;
 v_completion_note text:=nullif(btrim(p_note),'');
begin
 if auth.uid() is null then raise exception 'Authentication required'; end if;
 select bw.booking_id into v_booking_id
 from public.srk_booking_workers bw
 join public.srk_worker_profiles wp on wp.id=bw.worker_id
 where bw.id=p_booking_worker_id and wp.user_id=auth.uid();
 if not found then raise exception 'Assignment not found or not yours'; end if;

 select * into v_booking from public.service_bookings where id=v_booking_id for update;
 if not found then raise exception 'Booking not found'; end if;
 select bw.* into v_assignment
 from public.srk_booking_workers bw
 join public.srk_worker_profiles wp on wp.id=bw.worker_id
 where bw.id=p_booking_worker_id and wp.user_id=auth.uid()
 for update of bw;
 if not found or v_assignment.assignment_status not in ('accepted','assigned','working','paused') then
  raise exception 'Assignment is not active and cannot be completed';
 end if;
 if v_booking.status<>'in_progress' then raise exception 'Booking is not in progress'; end if;

 if v_booking.pricing_unit_snapshot in ('per_item','motor_hp') then
  if v_booking.work_start_approval_status<>'approved' then
   raise exception 'Customer must approve the fixed-price work start before completion';
  end if;
  if v_completion_note is null or length(v_completion_note) not between 5 and 1000 then
   raise exception 'For fixed-price work, enter a completion note of 5 to 1000 characters';
  end if;
  if exists(select 1 from public.srk_worker_work_sessions
   where booking_worker_id=p_booking_worker_id and session_status in ('running','paused')) then
   raise exception 'Fixed-price work must not have a running timer session';
  end if;
  update public.srk_booking_workers
  set assignment_status='completed',released_at=clock_timestamp(),
      worker_completed_at=clock_timestamp(),worker_completion_note=v_completion_note,
      updated_at=clock_timestamp()
  where id=p_booking_worker_id returning * into v_assignment;
 else
  if not exists(select 1 from public.srk_worker_work_sessions where booking_worker_id=p_booking_worker_id) then
   raise exception 'At least one work session is required';
  end if;
  if exists(select 1 from public.srk_worker_work_sessions
   where booking_worker_id=p_booking_worker_id and session_status not in ('completed','cancelled')) then
   raise exception 'Complete or cancel every daily work session first';
  end if;
  select coalesce(sum(billable_seconds),0) into v_total_seconds
  from public.srk_worker_work_sessions where booking_worker_id=p_booking_worker_id;
  if v_total_seconds<=0 then
   raise exception 'No billable work time recorded; Admin must release this assignment or arrange more work';
  end if;
  update public.srk_booking_workers
  set assignment_status='completed',released_at=clock_timestamp(),
      worker_completed_at=clock_timestamp(),worker_completion_note=v_completion_note,
      updated_at=clock_timestamp()
  where id=p_booking_worker_id returning * into v_assignment;
 end if;

 update public.srk_worker_schedule_blocks
 set block_status='completed',updated_at=clock_timestamp()
 where booking_worker_id=p_booking_worker_id
  and block_status in ('reserved','confirmed','in_progress');

 select count(*) into v_remaining from public.srk_booking_workers
 where booking_id=v_assignment.booking_id
  and assignment_status not in ('completed','released','cancelled','rejected');
 if v_remaining=0 then
  update public.service_bookings
  set completion_approval_status='pending',completion_requested_at=clock_timestamp(),
      work_timer_running=false
  where id=v_booking.id and status='in_progress';
 end if;
 return v_assignment;
end
$function$;