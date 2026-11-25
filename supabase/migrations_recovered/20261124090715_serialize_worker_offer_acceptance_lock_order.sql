CREATE OR REPLACE FUNCTION public.srk_worker_respond_assignment(p_assignment_id uuid,p_accept boolean)
RETURNS public.srk_booking_workers
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'pg_catalog','public','auth'
AS $function$
declare
 v_assignment public.srk_booking_workers%rowtype;
 v_worker public.srk_worker_profiles%rowtype;
 v_booking public.service_bookings%rowtype;
 v_booking_id uuid;
 v_worker_id uuid;
 v_accepted_count integer;
 v_requested_count integer;
begin
 if auth.uid() is null then raise exception 'Authentication required'; end if;

 select bw.booking_id,bw.worker_id into v_booking_id,v_worker_id
 from public.srk_booking_workers bw
 join public.srk_worker_profiles wp on wp.id=bw.worker_id
 where bw.id=p_assignment_id and wp.user_id=auth.uid();
 if not found then raise exception 'Offer not found or not yours'; end if;

 -- Global lock order: booking -> assignment -> worker.
 select * into v_booking from public.service_bookings
 where id=v_booking_id for update;
 if not found or v_booking.status='cancelled' then
  raise exception 'Booking is no longer available';
 end if;

 select bw.* into v_assignment
 from public.srk_booking_workers bw
 join public.srk_worker_profiles wp on wp.id=bw.worker_id
 where bw.id=p_assignment_id and wp.user_id=auth.uid()
 for update of bw;
 if not found or v_assignment.assignment_status<>'offered' then
  raise exception 'Offer not found or no longer pending';
 end if;

 if p_accept and v_assignment.offer_expires_at is not null
    and v_assignment.offer_expires_at<=clock_timestamp() then
  raise exception 'Offer has expired; wait for the next eligible assignment';
 end if;

 select * into v_worker from public.srk_worker_profiles
 where id=v_worker_id for update;
 if not found then raise exception 'Worker profile not found'; end if;

 if p_accept then
  if v_worker.verification_status<>'approved' or not v_worker.is_active then
   raise exception 'Worker is not currently approved and active';
  end if;
  perform pg_advisory_xact_lock(hashtextextended(v_worker.id::text,0));

  if exists(select 1 from public.srk_worker_work_sessions s
            where s.worker_id=v_worker.id and s.session_status in ('running','paused'))
     or exists(select 1 from public.srk_booking_workers bw
               where bw.worker_id=v_worker.id and bw.assignment_status in ('working','paused')) then
   raise exception 'Finish or complete the active/paused booking before accepting another booking';
  end if;

  if exists(
   select 1 from public.srk_booking_workers bw
   where bw.worker_id=v_worker.id and bw.id<>v_assignment.id
    and bw.assignment_status in ('accepted','assigned')
    and not exists(
     select 1 from public.srk_worker_schedule_blocks sb
     where sb.booking_worker_id=bw.id and sb.block_status in ('reserved','confirmed','in_progress')
    )
  ) then
   raise exception 'Another accepted booking still needs a customer-confirmed schedule';
  end if;

  if exists(
   select 1 from public.srk_worker_schedule_blocks sb
   where sb.worker_id=v_worker.id and sb.block_status in ('reserved','confirmed','in_progress')
    and sb.starts_at<=clock_timestamp()+make_interval(hours=>coalesce(v_booking.requested_duration_hours,1))
    and sb.ends_at>clock_timestamp()
  ) then
   raise exception 'A confirmed worker schedule conflicts with this booking';
  end if;

  v_requested_count:=case when v_assignment.worker_role='technician'
   then v_booking.requested_technician_count else v_booking.requested_helper_count end;
  select count(*) into v_accepted_count from public.srk_booking_workers
  where booking_id=v_assignment.booking_id and worker_role=v_assignment.worker_role
   and assignment_status in ('accepted','assigned','working','paused','completed');
  if v_accepted_count>=v_requested_count then
   raise exception 'Requested number of this worker role has already been filled';
  end if;
 end if;

 update public.srk_booking_workers
 set assignment_status=case when p_accept then 'accepted' else 'rejected' end,
     accepted_at=case when p_accept then clock_timestamp() else null end,
     rejected_at=case when p_accept then null else clock_timestamp() end,
     offer_expires_at=null,updated_at=clock_timestamp()
 where id=p_assignment_id returning * into v_assignment;

 if p_accept and v_assignment.worker_role='technician' then
  update public.service_bookings set status='confirmed'
  where id=v_assignment.booking_id and status='new';
 end if;
 update public.srk_booking_matching_queue
 set queue_status='pending',next_attempt_at=clock_timestamp(),updated_at=clock_timestamp()
 where booking_id=v_assignment.booking_id and queue_status not in ('fulfilled','cancelled');
 return v_assignment;
end
$function$;