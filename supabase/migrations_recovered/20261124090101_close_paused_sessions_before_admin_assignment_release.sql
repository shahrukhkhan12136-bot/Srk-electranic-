CREATE OR REPLACE FUNCTION public.srk_admin_release_booking_worker(p_assignment_id uuid,p_reason text)
RETURNS public.srk_booking_workers
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'pg_catalog','public','auth'
AS $function$
declare
 v public.srk_booking_workers%rowtype;
 v_session public.srk_worker_work_sessions%rowtype;
 v_now timestamptz:=clock_timestamp();
begin
 if not public.srk_has_admin_permission('bookings.manage') then
  raise exception 'Booking management permission required';
 end if;
 if p_assignment_id is null or length(btrim(coalesce(p_reason,'')))<10 then
  raise exception 'Release reason must be at least 10 characters';
 end if;

 select * into v from public.srk_booking_workers
 where id=p_assignment_id for update;
 if not found then raise exception 'Booking worker assignment not found'; end if;
 if v.assignment_status in ('completed','released','cancelled','rejected') then
  raise exception 'A completed or terminal assignment cannot be released again';
 end if;
 if exists(
  select 1 from public.srk_worker_work_sessions
  where booking_worker_id=p_assignment_id and session_status='running'
 ) then
  raise exception 'Pause or complete the active timer before releasing this worker';
 end if;

 -- Close paused/not-started daily sessions without losing their recorded billable seconds.
 for v_session in
  update public.srk_worker_work_sessions
  set session_status='cancelled',
      ended_at=coalesce(ended_at,v_now),
      last_resumed_at=null,
      pause_minimum_until=null,
      completion_note=coalesce(completion_note,'Admin released assignment: '||btrim(p_reason)),
      updated_at=v_now
  where booking_worker_id=p_assignment_id
    and session_status in ('not_started','paused')
  returning *
 loop
  insert into public.srk_worker_session_events(
   session_id,event_type,event_at,actor_user_id,pause_reason,note,source
  ) values(
   v_session.id,'cancelled',v_now,auth.uid(),v_session.pause_reason,
   'Admin closed this daily session while releasing the assignment: '||btrim(p_reason),
   'admin'
  );
 end loop;

 update public.srk_booking_workers
 set assignment_status='released',released_at=v_now,
     admin_note=btrim(p_reason),updated_at=v_now
 where id=p_assignment_id returning * into v;

 update public.srk_worker_schedule_blocks
 set block_status=case when ends_at<=v_now then 'completed' else 'cancelled' end,
     updated_at=v_now
 where booking_worker_id=p_assignment_id
   and block_status in ('reserved','confirmed','in_progress');

 update public.srk_booking_matching_queue
 set queue_status='pending',next_attempt_at=v_now,updated_at=v_now
 where booking_id=v.booking_id and queue_status<>'cancelled';

 insert into public.srk_app_notifications(user_id,notification_type,title,body,related_booking_id)
 select user_id,'assignment_released','Booking assignment updated',
  'Your assignment was released by Admin. Reason: '||btrim(p_reason),v.booking_id
 from public.srk_worker_profiles where id=v.worker_id;
 return v;
end
$function$;