
alter table public.service_bookings
  drop constraint if exists service_bookings_assignment_status_requires_electrician;

create or replace function public.srk_worker_session_action(
  p_session_id uuid,p_action text,p_pause_reason text default null,p_note text default null,p_idempotency_key text default null
) returns public.srk_worker_work_sessions
language plpgsql security definer
set search_path=pg_catalog,public,auth
as $$
declare v_session public.srk_worker_work_sessions%rowtype; v_worker_id uuid; v_user_id uuid;
  v_booking_id uuid; v_now timestamptz:=clock_timestamp(); v_elapsed bigint;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  select * into v_session from public.srk_worker_work_sessions where id=p_session_id for update;
  if not found then raise exception 'Work session not found'; end if;
  select bw.worker_id,wp.user_id,bw.booking_id into v_worker_id,v_user_id,v_booking_id
  from public.srk_booking_workers bw join public.srk_worker_profiles wp on wp.id=bw.worker_id
  where bw.id=v_session.booking_worker_id;
  if v_user_id is distinct from auth.uid() and not coalesce(public.is_srk_admin(),false) then
    raise exception 'Not authorized for this work session';
  end if;
  if p_idempotency_key is not null and exists(select 1 from public.srk_worker_session_events where idempotency_key=p_idempotency_key) then
    return v_session;
  end if;

  if p_action='start' then
    if v_session.session_status<>'not_started' then raise exception 'Session cannot be started from current state'; end if;
    update public.srk_worker_work_sessions set session_status='running',started_at=v_now,last_resumed_at=v_now,updated_at=v_now
      where id=p_session_id returning * into v_session;
    update public.srk_booking_workers set assignment_status='working',updated_at=v_now
      where id=v_session.booking_worker_id and assignment_status in ('accepted','assigned','paused');
    update public.service_bookings set status='in_progress',work_started_at=coalesce(work_started_at,v_now)
      where id=v_booking_id and status in ('new','confirmed','assigned','in_progress');
    insert into public.srk_worker_session_events(session_id,event_type,event_at,actor_user_id,note,idempotency_key)
      values(p_session_id,'started',v_now,auth.uid(),p_note,p_idempotency_key);

  elsif p_action='pause' then
    if v_session.session_status<>'running' then raise exception 'Only a running session can be paused'; end if;
    if p_pause_reason not in ('food_break','material','customer_permission','technical_problem','other') then raise exception 'Valid pause reason required'; end if;
    v_elapsed:=greatest(0,floor(extract(epoch from(v_now-v_session.last_resumed_at)))::bigint);
    update public.srk_worker_work_sessions set session_status='paused',
      billable_seconds=least(5184000,billable_seconds+v_elapsed),last_resumed_at=null,
      pause_reason=p_pause_reason,updated_at=v_now where id=p_session_id returning * into v_session;
    update public.srk_booking_workers set assignment_status='paused',updated_at=v_now where id=v_session.booking_worker_id;
    insert into public.srk_worker_session_events(session_id,event_type,event_at,actor_user_id,pause_reason,note,idempotency_key)
      values(p_session_id,'paused',v_now,auth.uid(),p_pause_reason,p_note,p_idempotency_key);

  elsif p_action='resume' then
    if v_session.session_status<>'paused' then raise exception 'Only a paused session can be resumed'; end if;
    update public.srk_worker_work_sessions set session_status='running',last_resumed_at=v_now,pause_reason=null,updated_at=v_now
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
      completion_note=p_note,updated_at=v_now where id=p_session_id returning * into v_session;
    update public.srk_booking_workers set assignment_status='assigned',updated_at=v_now
      where id=v_session.booking_worker_id and assignment_status in ('working','paused');
    insert into public.srk_worker_session_events(session_id,event_type,event_at,actor_user_id,note,idempotency_key)
      values(p_session_id,'completed',v_now,auth.uid(),p_note,p_idempotency_key);
  else
    raise exception 'Unsupported session action';
  end if;
  return v_session;
end $$;

create or replace function public.srk_worker_complete_assignment(p_booking_worker_id uuid,p_note text default null)
returns public.srk_booking_workers
language plpgsql security definer
set search_path=pg_catalog,public,auth
as $$
declare v_assignment public.srk_booking_workers%rowtype; v_remaining integer;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  select bw.* into v_assignment from public.srk_booking_workers bw
  join public.srk_worker_profiles wp on wp.id=bw.worker_id
  where bw.id=p_booking_worker_id and wp.user_id=auth.uid() for update of bw;
  if not found then raise exception 'Assignment not found or not yours'; end if;
  if not exists(select 1 from public.srk_worker_work_sessions where booking_worker_id=p_booking_worker_id) then raise exception 'At least one work session required'; end if;
  if exists(select 1 from public.srk_worker_work_sessions where booking_worker_id=p_booking_worker_id and session_status not in ('completed','cancelled')) then
    raise exception 'Complete or cancel every daily work session first';
  end if;
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

create or replace function public.srk_customer_respond_multi_worker_completion(
  p_booking_id uuid,p_response text,p_note text default null
) returns jsonb
language plpgsql security definer
set search_path=pg_catalog,public,auth
as $$
declare v_booking public.service_bookings%rowtype;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if p_response not in ('approved','rejected','disputed') then raise exception 'Invalid completion response'; end if;
  select * into v_booking from public.service_bookings
  where id=p_booking_id and customer_user_id=auth.uid() for update;
  if not found then raise exception 'Customer booking not found'; end if;
  if not exists(select 1 from public.srk_booking_workers where booking_id=p_booking_id) then
    raise exception 'This is not a multi-worker booking';
  end if;
  if v_booking.completion_approval_status<>'pending' or v_booking.completion_requested_at is null then
    raise exception 'No completion request waiting for response';
  end if;
  if p_response='approved' then
    update public.service_bookings set status='completed',completion_approval_status='approved',
      customer_completed_at=clock_timestamp(),work_timer_running=false
    where id=p_booking_id;
  elsif p_response='rejected' then
    update public.service_bookings set completion_approval_status='rejected',completion_requested_at=null
    where id=p_booking_id;
    insert into public.srk_support_cases(booking_id,raised_by,raised_by_role,category,subject,description,priority)
    values(p_booking_id,auth.uid(),'customer','completion','Customer rejected completion',
      coalesce(p_note,'Customer requested review of completed work.'),'high');
  else
    if length(coalesce(p_note,''))<20 then raise exception 'Dispute reason must be at least 20 characters'; end if;
    update public.service_bookings set completion_approval_status='disputed',work_timer_running=false
    where id=p_booking_id;
    insert into public.srk_support_cases(booking_id,raised_by,raised_by_role,category,subject,description,priority)
    values(p_booking_id,auth.uid(),'customer','completion','Completion dispute',p_note,'high');
  end if;
  return jsonb_build_object('success',true,'response',p_response);
end $$;

revoke all on function public.srk_customer_respond_multi_worker_completion(uuid,text,text) from public,anon;
grant execute on function public.srk_customer_respond_multi_worker_completion(uuid,text,text) to authenticated;
