
create or replace function public.srk_worker_complete_assignment(p_booking_worker_id uuid,p_note text default null)
returns public.srk_booking_workers
language plpgsql security definer
set search_path=pg_catalog,public,auth
as $$
declare v_assignment public.srk_booking_workers%rowtype; v_remaining integer; v_total_seconds bigint;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  select bw.* into v_assignment from public.srk_booking_workers bw
  join public.srk_worker_profiles wp on wp.id=bw.worker_id
  where bw.id=p_booking_worker_id and wp.user_id=auth.uid() for update of bw;
  if not found then raise exception 'Assignment not found or not yours'; end if;
  if not exists(select 1 from public.srk_worker_work_sessions where booking_worker_id=p_booking_worker_id) then
    raise exception 'At least one work session is required';
  end if;
  if exists(select 1 from public.srk_worker_work_sessions where booking_worker_id=p_booking_worker_id and session_status not in ('completed','cancelled')) then
    raise exception 'Complete or cancel every daily work session first';
  end if;
  select coalesce(sum(billable_seconds),0) into v_total_seconds
  from public.srk_worker_work_sessions where booking_worker_id=p_booking_worker_id;
  if v_total_seconds<=0 then raise exception 'No billable work time recorded; Admin must release this assignment or arrange more work'; end if;

  update public.srk_booking_workers set assignment_status='completed',released_at=clock_timestamp(),
    updated_at=clock_timestamp(),admin_note=coalesce(p_note,admin_note)
  where id=p_booking_worker_id and assignment_status<>'completed' returning * into v_assignment;

  select count(*) into v_remaining from public.srk_booking_workers
  where booking_id=v_assignment.booking_id and assignment_status not in ('completed','released','cancelled','rejected');
  if v_remaining=0 then
    update public.service_bookings set status='in_progress',completion_approval_status='pending',
      completion_requested_at=clock_timestamp(),work_timer_running=false
    where id=v_assignment.booking_id and status<>'completed';
  end if;
  return v_assignment;
end $$;
