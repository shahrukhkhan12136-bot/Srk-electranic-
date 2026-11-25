CREATE OR REPLACE FUNCTION public.srk_guard_worker_session()
RETURNS trigger
LANGUAGE plpgsql
SET search_path TO 'pg_catalog','public'
AS $function$
declare
 v_worker_id uuid;
 v_booking_id uuid;
 v_pricing_unit text;
 v_booking_status text;
 v_work_start_approval text;
begin
 select bw.worker_id,bw.booking_id,b.pricing_unit_snapshot,b.status,b.work_start_approval_status
 into v_worker_id,v_booking_id,v_pricing_unit,v_booking_status,v_work_start_approval
 from public.srk_booking_workers bw
 join public.service_bookings b on b.id=bw.booking_id
 where bw.id=new.booking_worker_id;
 if v_worker_id is null then raise exception 'Booking worker assignment not found'; end if;
 perform pg_advisory_xact_lock(hashtextextended(v_worker_id::text,0));
 if new.session_status in ('running','paused') then
  if v_pricing_unit in ('per_item','motor_hp') then
   raise exception 'Timer is disabled for fixed-price bookings';
  end if;
  if v_booking_status<>'in_progress' or v_work_start_approval<>'approved' then
   raise exception 'Customer work-start approval is required before starting the timer';
  end if;
  if exists(
   select 1 from public.srk_worker_work_sessions s
   where s.worker_id=v_worker_id and s.session_status in ('running','paused')
    and s.id<>coalesce(new.id,'00000000-0000-0000-0000-000000000000'::uuid)
  ) then
   raise exception 'Worker already has an active or paused work session at another booking';
  end if;
 end if;
 return new;
end
$function$;

CREATE OR REPLACE FUNCTION public.srk_worker_request_work_start_approval(
 p_booking_worker_id uuid
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'pg_catalog','public','auth'
AS $function$
declare
 v_booking_id uuid;
 v_worker_id uuid;
 v_booking public.service_bookings%rowtype;
 v_assignment public.srk_booking_workers%rowtype;
 v_tech_count integer;
 v_helper_count integer;
begin
 if auth.uid() is null then raise exception 'Authentication required'; end if;
 select bw.booking_id,bw.worker_id into v_booking_id,v_worker_id
 from public.srk_booking_workers bw
 join public.srk_worker_profiles wp on wp.id=bw.worker_id
 where bw.id=p_booking_worker_id and wp.user_id=auth.uid();
 if not found then raise exception 'Assignment not found or not yours' using errcode='42501'; end if;

 select * into v_booking from public.service_bookings where id=v_booking_id for update;
 if not found then raise exception 'Booking not found'; end if;
 select * into v_assignment from public.srk_booking_workers
 where id=p_booking_worker_id for update;
 if not found or v_assignment.assignment_status not in ('accepted','assigned') then
  raise exception 'Only an accepted or assigned worker can request work-start approval';
 end if;
 if v_booking.status not in ('new','confirmed','assigned') then
  raise exception 'Booking is not ready for work-start approval';
 end if;
 if v_booking.work_start_approval_status in ('pending','approved') then
  raise exception 'Work-start approval is already pending or granted';
 end if;

 select count(*) filter(where worker_role='technician'
  and assignment_status in ('accepted','assigned')),
        count(*) filter(where worker_role='helper'
  and assignment_status in ('accepted','assigned'))
 into v_tech_count,v_helper_count
 from public.srk_booking_workers where booking_id=v_booking_id;
 if v_tech_count<coalesce(v_booking.requested_technician_count,0)
  or v_helper_count<coalesce(v_booking.requested_helper_count,0) then
  raise exception 'All requested Technician and Helper positions must be assigned before work starts';
 end if;
 if exists(
  select 1 from public.srk_booking_workers bw
  where bw.booking_id=v_booking_id and bw.assignment_status in ('accepted','assigned')
   and not exists(select 1 from public.srk_worker_schedule_blocks sb
    where sb.booking_worker_id=bw.id and sb.block_status in ('confirmed','in_progress'))
 ) then
  raise exception 'Every assigned worker must have a customer-confirmed schedule before work starts';
 end if;

 update public.service_bookings
 set status='awaiting_work_start_approval',
  work_start_approval_status='pending',
  work_start_requested_at=clock_timestamp(),
  work_timer_running=false
 where id=v_booking_id;

 insert into public.srk_app_notifications(
  user_id,notification_type,title,body,related_booking_id
 ) values(
  v_booking.customer_user_id,'work_start_request','Work start approval required',
  'Your assigned service team is ready to begin. Please approve or reject the work start.',
  v_booking_id
 );
 return jsonb_build_object('success',true,'status','awaiting_work_start_approval');
end
$function$;