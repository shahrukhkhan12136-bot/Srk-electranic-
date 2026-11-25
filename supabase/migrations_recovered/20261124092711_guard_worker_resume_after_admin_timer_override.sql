alter table public.srk_worker_work_sessions
 drop constraint if exists srk_work_session_pause_reason_valid;
alter table public.srk_worker_work_sessions
 add constraint srk_work_session_pause_reason_valid
 check (pause_reason is null or pause_reason in
 ('food_break','material','customer_permission','technical_problem','other','lunch','market_other','gps_outside_worksite','admin_override'));
alter table public.srk_worker_work_sessions
 drop constraint if exists srk_worker_work_sessions_pause_reason_check;
alter table public.srk_worker_work_sessions
 add constraint srk_worker_work_sessions_pause_reason_check
 check (pause_reason is null or pause_reason in
 ('food_break','material','customer_permission','technical_problem','other','lunch','market_other','gps_outside_worksite','admin_override'));
alter table public.srk_worker_session_events
 drop constraint if exists srk_worker_session_event_pause_reason_valid;
alter table public.srk_worker_session_events
 add constraint srk_worker_session_event_pause_reason_valid
 check (pause_reason is null or pause_reason in
 ('food_break','material','customer_permission','technical_problem','other','lunch','market_other','gps_outside_worksite','admin_override'));
alter table public.srk_worker_session_events
 drop constraint if exists srk_worker_session_events_pause_reason_check;
alter table public.srk_worker_session_events
 add constraint srk_worker_session_events_pause_reason_check
 check (pause_reason is null or pause_reason in
 ('food_break','material','customer_permission','technical_problem','other','lunch','market_other','gps_outside_worksite','admin_override'));

CREATE OR REPLACE FUNCTION public.srk_worker_session_action(
 p_session_id uuid,p_action text,p_pause_reason text DEFAULT NULL::text,
 p_note text DEFAULT NULL::text,p_idempotency_key text DEFAULT NULL::text
) RETURNS public.srk_worker_work_sessions
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'pg_catalog','public','auth'
AS $function$
declare
 v_session public.srk_worker_work_sessions%rowtype;
 v_assignment public.srk_booking_workers%rowtype;
 v_existing_event public.srk_worker_session_events%rowtype;
 v_user_id uuid; v_booking_worker_id uuid; v_booking_id uuid;
 v_now timestamptz:=clock_timestamp(); v_elapsed bigint;
 v_booking public.service_bookings%rowtype; v_expected_event_type text;
 v_auto_resume_distance numeric; v_distance_m numeric;
begin
 if auth.uid() is null then raise exception 'Authentication required'; end if;
 if p_idempotency_key is not null and
   (length(btrim(p_idempotency_key))=0 or length(p_idempotency_key)>200) then
  raise exception 'Invalid idempotency key' using errcode='22023';
 end if;
 select booking_worker_id into v_booking_worker_id from public.srk_worker_work_sessions where id=p_session_id;
 if not found then raise exception 'Work session not found'; end if;
 select booking_id into v_booking_id from public.srk_booking_workers where id=v_booking_worker_id;
 if not found then raise exception 'Booking assignment not found'; end if;
 select * into v_booking from public.service_bookings where id=v_booking_id for update;
 if not found then raise exception 'Booking not found'; end if;
 select * into v_assignment from public.srk_booking_workers where id=v_booking_worker_id for update;
 if not found then raise exception 'Booking assignment not found'; end if;
 select * into v_session from public.srk_worker_work_sessions
 where id=p_session_id and booking_worker_id=v_assignment.id for update;
 if not found then raise exception 'Work session not found'; end if;
 select user_id into v_user_id from public.srk_worker_profiles where id=v_assignment.worker_id;
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
  if v_session.start_latitude is null or v_session.start_longitude is null
     or v_session.last_gps_latitude is null or v_session.last_gps_longitude is null
     or v_session.last_gps_at is null or v_session.last_gps_at<v_now-interval '2 minutes' then
   raise exception 'A fresh GPS location is required before starting the work timer';
  end if;
  update public.srk_worker_work_sessions
  set session_status='running',started_at=v_now,last_resumed_at=v_now,updated_at=v_now
  where id=p_session_id returning * into v_session;
  update public.srk_booking_workers set assignment_status='working',updated_at=v_now
  where id=v_assignment.id and assignment_status in ('accepted','assigned','paused');
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
  update public.srk_booking_workers set assignment_status='paused',updated_at=v_now where id=v_assignment.id;
  insert into public.srk_worker_session_events(session_id,event_type,event_at,actor_user_id,pause_reason,note,idempotency_key)
  values(p_session_id,'paused',v_now,auth.uid(),p_pause_reason,p_note,p_idempotency_key);
 elsif p_action='resume' then
  if v_session.session_status<>'paused' then raise exception 'Only a paused session can be resumed'; end if;
  if v_session.pause_minimum_until is not null and v_now<v_session.pause_minimum_until then
   raise exception 'Minimum pause duration has not elapsed';
  end if;
  if v_session.pause_reason in ('gps_outside_worksite','lunch','market_other','admin_override') then
   if v_session.start_latitude is null or v_session.start_longitude is null
      or v_session.last_gps_latitude is null or v_session.last_gps_longitude is null
      or v_session.last_gps_at is null or v_session.last_gps_at<v_now-interval '2 minutes' then
    raise exception 'Fresh GPS location is required to resume inside the work-site radius';
   end if;
   v_auto_resume_distance:=coalesce(
    (v_booking.operational_settings_snapshot->>'pause_auto_resume_distance_meters')::numeric,
    (select (setting_value #>> '{}')::numeric from public.srk_system_settings where setting_key='pause_auto_resume_distance_meters'),100);
   v_distance_m:=6371000*2*asin(sqrt(
    power(sin(radians(v_session.last_gps_latitude-v_session.start_latitude)/2),2)
    +cos(radians(v_session.start_latitude))*cos(radians(v_session.last_gps_latitude))
    *power(sin(radians(v_session.last_gps_longitude-v_session.start_longitude)/2),2)
   ));
   if v_distance_m>v_auto_resume_distance then
    raise exception 'Cannot resume while outside the configured work-site radius';
   end if;
  end if;
  update public.srk_worker_work_sessions set session_status='running',last_resumed_at=v_now,pause_reason=null,
   pause_started_at=null,pause_minimum_until=null,updated_at=v_now
  where id=p_session_id returning * into v_session;
  update public.srk_booking_workers set assignment_status='working',updated_at=v_now where id=v_assignment.id;
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
  where id=v_assignment.id and assignment_status in ('working','paused');
  insert into public.srk_worker_session_events(session_id,event_type,event_at,actor_user_id,note,idempotency_key)
  values(p_session_id,'completed',v_now,auth.uid(),p_note,p_idempotency_key);
 else
  raise exception 'Unsupported session action';
 end if;
 return v_session;
end
$function$;

CREATE OR REPLACE FUNCTION public.srk_admin_override_work_timer(
 p_session_id uuid,p_timer_on boolean,p_reason text
) RETURNS public.srk_worker_work_sessions
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'pg_catalog','public','auth'
AS $function$
declare
 v_session public.srk_worker_work_sessions%rowtype;
 v_booking_id uuid; v_worker_id uuid; v_worker_user_id uuid; v_customer_user_id uuid;
 v_now timestamptz:=clock_timestamp(); v_elapsed bigint; v_previous_status text;
begin
 if auth.uid() is null or not public.is_srk_admin() then
  raise exception 'Main Admin permission required' using errcode='42501';
 end if;
 if p_session_id is null or p_timer_on is null or length(btrim(coalesce(p_reason,'')))<10 then
  raise exception 'Session, timer action and a reason of at least 10 characters are required' using errcode='22023';
 end if;
 select * into v_session from public.srk_worker_work_sessions where id=p_session_id for update;
 if not found then raise exception 'Work session not found'; end if;
 v_previous_status:=v_session.session_status;
 select bw.booking_id,bw.worker_id,wp.user_id,b.customer_user_id
 into v_booking_id,v_worker_id,v_worker_user_id,v_customer_user_id
 from public.srk_booking_workers bw
 join public.srk_worker_profiles wp on wp.id=bw.worker_id
 join public.service_bookings b on b.id=bw.booking_id
 where bw.id=v_session.booking_worker_id;
 if not found then raise exception 'Booking worker assignment not found'; end if;
 if p_timer_on then
  if v_session.session_status not in ('not_started','paused') then
   raise exception 'Timer is already running or session is closed';
  end if;
  update public.srk_worker_work_sessions
  set session_status='running',started_at=coalesce(started_at,v_now),last_resumed_at=v_now,
      pause_reason=null,pause_started_at=null,pause_minimum_until=null,
      start_latitude=case when started_at is null then null else start_latitude end,
      start_longitude=case when started_at is null then null else start_longitude end,
      last_gps_latitude=null,last_gps_longitude=null,last_gps_at=null,updated_at=v_now
  where id=p_session_id returning * into v_session;
  update public.srk_booking_workers set assignment_status='working',updated_at=v_now
  where id=v_session.booking_worker_id;
  update public.service_bookings set status='in_progress',work_started_at=coalesce(work_started_at,v_now)
  where id=v_booking_id and status in ('new','confirmed','assigned','in_progress');
 else
  if v_session.session_status<>'running' then raise exception 'Only a running timer can be turned off'; end if;
  v_elapsed:=greatest(0,floor(extract(epoch from(v_now-v_session.last_resumed_at)))::bigint);
  update public.srk_worker_work_sessions
  set session_status='paused',billable_seconds=least(5184000,billable_seconds+v_elapsed),
      last_resumed_at=null,pause_reason='admin_override',
      pause_started_at=v_now,pause_minimum_until=null,updated_at=v_now
  where id=p_session_id returning * into v_session;
  update public.srk_booking_workers set assignment_status='paused',updated_at=v_now
  where id=v_session.booking_worker_id;
 end if;
 insert into public.srk_worker_session_events(session_id,event_type,event_at,actor_user_id,note,source)
 values(p_session_id,'admin_adjusted',v_now,auth.uid(),
  case when p_timer_on then 'ADMIN TIMER ON: ' else 'ADMIN TIMER OFF: ' end||btrim(p_reason),'admin');
 insert into public.srk_admin_timer_override_events(
  session_id,booking_id,booking_worker_id,worker_id,admin_user_id,action,reason,previous_status,new_status
 ) values(p_session_id,v_booking_id,v_session.booking_worker_id,v_worker_id,auth.uid(),
  case when p_timer_on then 'timer_on' else 'timer_off' end,btrim(p_reason),
  v_previous_status,v_session.session_status);
 if v_customer_user_id is not null then
  insert into public.srk_app_notifications(user_id,notification_type,title,body,related_booking_id,deep_link)
  values(v_customer_user_id,'timer_admin_override','Work timer updated by Admin',
   case when p_timer_on then 'Admin ने कारण सहित काम का टाइमर चालू किया।' else 'Admin ने कारण सहित काम का टाइमर बंद किया।' end,
   v_booking_id,'/bookings/'||v_booking_id::text);
 end if;
 if v_worker_user_id is not null then
  insert into public.srk_app_notifications(user_id,notification_type,title,body,related_booking_id,deep_link)
  values(v_worker_user_id,'timer_admin_override','Work timer updated by Admin',
   case when p_timer_on then 'Admin ने कारण सहित आपका काम का टाइमर चालू किया।' else 'Admin ने कारण सहित आपका काम का टाइमर बंद किया।' end,
   v_booking_id,'/worker/bookings/'||v_booking_id::text);
 end if;
 return v_session;
end
$function$;