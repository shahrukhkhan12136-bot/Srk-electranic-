CREATE OR REPLACE FUNCTION public.srk_worker_session_action(
 p_session_id uuid,p_action text,p_pause_reason text DEFAULT NULL::text,
 p_note text DEFAULT NULL::text,p_idempotency_key text DEFAULT NULL::text
) RETURNS public.srk_worker_work_sessions
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'pg_catalog','public','auth'
AS $function$
declare
 v_session public.srk_worker_work_sessions%rowtype;
 v_existing_event public.srk_worker_session_events%rowtype;
 v_user_id uuid; v_booking_id uuid; v_now timestamptz:=clock_timestamp();
 v_elapsed bigint; v_booking public.service_bookings%rowtype; v_expected_event_type text;
begin
 if auth.uid() is null then raise exception 'Authentication required'; end if;
 if p_idempotency_key is not null and
   (length(btrim(p_idempotency_key))=0 or length(p_idempotency_key)>200) then
   raise exception 'Invalid idempotency key' using errcode='22023';
 end if;
 select * into v_session from public.srk_worker_work_sessions where id=p_session_id for update;
 if not found then raise exception 'Work session not found'; end if;
 select wp.user_id,bw.booking_id into v_user_id,v_booking_id
 from public.srk_booking_workers bw join public.srk_worker_profiles wp on wp.id=bw.worker_id
 where bw.id=v_session.booking_worker_id;
 select * into v_booking from public.service_bookings where id=v_booking_id;
 if v_user_id is distinct from auth.uid() and not coalesce(public.is_srk_admin(),false) then
  raise exception 'Not authorized for this work session';
 end if;

 if p_idempotency_key is not null then
  v_expected_event_type:=case p_action when 'start' then 'started' when 'pause' then 'paused'
   when 'resume' then 'resumed' when 'complete' then 'completed' else null end;
  select * into v_existing_event from public.srk_worker_session_events
  where idempotency_key=p_idempotency_key for share;
  if found then
   if v_existing_event.session_id is distinct from p_session_id
    or v_existing_event.event_type is distinct from v_expected_event_type
    or v_existing_event.actor_user_id is distinct from auth.uid()
    or v_existing_event.pause_reason is distinct from p_pause_reason
    or v_existing_event.note is distinct from p_note
    or v_existing_event.source is distinct from 'app' then
    raise exception 'Idempotency key was already used for a different timer event' using errcode='22023';
   end if;
   return v_session;
  end if;
 end if;

 if p_action='start' then
  if v_session.session_status<>'not_started' then raise exception 'Session cannot be started from current state'; end if;
  update public.srk_worker_work_sessions set session_status='running',started_at=v_now,last_resumed_at=v_now,updated_at=v_now,
   start_latitude=(select location_lat from public.srk_worker_profiles where id=v_session.worker_id),
   start_longitude=(select location_lng from public.srk_worker_profiles where id=v_session.worker_id),
   last_gps_latitude=(select location_lat from public.srk_worker_profiles where id=v_session.worker_id),
   last_gps_longitude=(select location_lng from public.srk_worker_profiles where id=v_session.worker_id)
  where id=p_session_id returning * into v_session;
  update public.srk_booking_workers set assignment_status='working',updated_at=v_now
   where id=v_session.booking_worker_id and assignment_status in ('accepted','assigned','paused');
  update public.service_bookings set status='in_progress',work_started_at=coalesce(work_started_at,v_now)
   where id=v_booking_id and status in ('new','confirmed','assigned','in_progress');
  insert into public.srk_worker_session_events(session_id,event_type,event_at,actor_user_id,note,idempotency_key)
   values(p_session_id,'started',v_now,auth.uid(),p_note,p_idempotency_key);

 elsif p_action='pause' then
  if v_session.session_status<>'running' then raise exception 'Only a running session can be paused'; end if;
  if p_pause_reason not in ('lunch','market_other') then raise exception 'Pause must be Lunch or Market/Other Task'; end if;
  v_elapsed:=greatest(0,floor(extract(epoch from(v_now-v_session.last_resumed_at)))::bigint);
  update public.srk_worker_work_sessions set session_status='paused',pause_started_at=v_now,
   pause_minimum_until=v_now+make_interval(mins=>case when p_pause_reason='lunch'
    then coalesce((v_booking.operational_settings_snapshot->>'lunch_pause_minimum_minutes')::integer,60)
    else coalesce((v_booking.operational_settings_snapshot->>'other_pause_minimum_minutes')::integer,120) end),
   billable_seconds=least(5184000,billable_seconds+v_elapsed),last_resumed_at=null,
   pause_reason=p_pause_reason,updated_at=v_now
  where id=p_session_id returning * into v_session;
  update public.srk_booking_workers set assignment_status='paused',updated_at=v_now where id=v_session.booking_worker_id;
  insert into public.srk_worker_session_events(session_id,event_type,event_at,actor_user_id,pause_reason,note,idempotency_key)
   values(p_session_id,'paused',v_now,auth.uid(),p_pause_reason,p_note,p_idempotency_key);

 elsif p_action='resume' then
  if v_session.session_status<>'paused' then raise exception 'Only a paused session can be resumed'; end if;
  if v_session.pause_minimum_until is not null and v_now<v_session.pause_minimum_until then
   raise exception 'Minimum pause duration has not elapsed';
  end if;
  update public.srk_worker_work_sessions set session_status='running',last_resumed_at=v_now,pause_reason=null,
   pause_started_at=null,pause_minimum_until=null,updated_at=v_now
  where id=p_session_id returning * into v_session;
  update public.srk_booking_workers set assignment_status='working',updated_at=v_now where id=v_session.booking_worker_id;
  insert into public.srk_worker_session_events(session_id,event_type,event_at,actor_user_id,note,idempotency_key)
   values(p_session_id,'resumed',v_now,auth.uid(),p_note,p_idempotency_key);

 elsif p_action='complete' then
  if v_session.session_status not in ('running','paused') then raise exception 'Session cannot be completed from current state'; end if;
  v_elapsed:=case when v_session.session_status='running'
   then greatest(0,floor(extract(epoch from(v_now-v_session.last_resumed_at)))::bigint) else 0 end;
  update public.srk_worker_work_sessions set session_status='completed',
   billable_seconds=least(5184000,billable_seconds+v_elapsed),ended_at=v_now,last_resumed_at=null,
   completion_note=p_note,updated_at=v_now
  where id=p_session_id returning * into v_session;
  update public.srk_booking_workers set assignment_status='assigned',updated_at=v_now
   where id=v_session.booking_worker_id and assignment_status in ('working','paused');
  insert into public.srk_worker_session_events(session_id,event_type,event_at,actor_user_id,note,idempotency_key)
   values(p_session_id,'completed',v_now,auth.uid(),p_note,p_idempotency_key);
 else
  raise exception 'Unsupported session action';
 end if;
 return v_session;
end
$function$;