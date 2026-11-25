
create or replace function public.srk_worker_session_action(
  p_session_id uuid,
  p_action text,
  p_pause_reason text default null,
  p_note text default null,
  p_idempotency_key text default null
) returns public.srk_worker_work_sessions
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_session public.srk_worker_work_sessions%rowtype;
  v_worker_id uuid;
  v_user_id uuid;
  v_now timestamptz := clock_timestamp();
  v_elapsed bigint;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  select s.* into v_session
  from public.srk_worker_work_sessions s
  where s.id=p_session_id
  for update;

  if not found then raise exception 'Work session not found'; end if;

  select bw.worker_id, wp.user_id into v_worker_id,v_user_id
  from public.srk_booking_workers bw
  join public.srk_worker_profiles wp on wp.id=bw.worker_id
  where bw.id=v_session.booking_worker_id;

  if v_user_id is distinct from auth.uid() and not coalesce(public.is_srk_admin(),false) then
    raise exception 'Not authorized for this work session';
  end if;

  if p_idempotency_key is not null and exists (
    select 1 from public.srk_worker_session_events e
    where e.idempotency_key=p_idempotency_key
  ) then
    return v_session;
  end if;

  if p_action='start' then
    if v_session.session_status <> 'not_started' then raise exception 'Session cannot be started from current state'; end if;
    update public.srk_worker_work_sessions
      set session_status='running', started_at=v_now, last_resumed_at=v_now,
          updated_at=v_now
      where id=p_session_id returning * into v_session;
    insert into public.srk_worker_session_events(session_id,event_type,event_at,actor_user_id,note,idempotency_key)
      values(p_session_id,'started',v_now,auth.uid(),p_note,p_idempotency_key);

  elsif p_action='pause' then
    if v_session.session_status <> 'running' then raise exception 'Only a running session can be paused'; end if;
    if p_pause_reason not in ('food_break','material','customer_permission','technical_problem','other') then
      raise exception 'A valid pause reason is required';
    end if;
    v_elapsed := greatest(0,floor(extract(epoch from (v_now-v_session.last_resumed_at)))::bigint);
    update public.srk_worker_work_sessions
      set session_status='paused',
          billable_seconds=least(5184000,billable_seconds+v_elapsed),
          last_resumed_at=null,pause_reason=p_pause_reason,updated_at=v_now
      where id=p_session_id returning * into v_session;
    insert into public.srk_worker_session_events(session_id,event_type,event_at,actor_user_id,pause_reason,note,idempotency_key)
      values(p_session_id,'paused',v_now,auth.uid(),p_pause_reason,p_note,p_idempotency_key);

  elsif p_action='resume' then
    if v_session.session_status <> 'paused' then raise exception 'Only a paused session can be resumed'; end if;
    update public.srk_worker_work_sessions
      set session_status='running',last_resumed_at=v_now,pause_reason=null,updated_at=v_now
      where id=p_session_id returning * into v_session;
    insert into public.srk_worker_session_events(session_id,event_type,event_at,actor_user_id,note,idempotency_key)
      values(p_session_id,'resumed',v_now,auth.uid(),p_note,p_idempotency_key);

  elsif p_action='complete' then
    if v_session.session_status not in ('running','paused') then raise exception 'Session cannot be completed from current state'; end if;
    v_elapsed := case when v_session.session_status='running'
      then greatest(0,floor(extract(epoch from (v_now-v_session.last_resumed_at)))::bigint) else 0 end;
    update public.srk_worker_work_sessions
      set session_status='completed',
          billable_seconds=least(5184000,billable_seconds+v_elapsed),
          ended_at=v_now,last_resumed_at=null,completion_note=p_note,updated_at=v_now
      where id=p_session_id returning * into v_session;
    insert into public.srk_worker_session_events(session_id,event_type,event_at,actor_user_id,note,idempotency_key)
      values(p_session_id,'completed',v_now,auth.uid(),p_note,p_idempotency_key);
  else
    raise exception 'Unsupported session action';
  end if;

  return v_session;
end;
$$;

create or replace function public.srk_enforce_technician_payment_cycle()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_worker public.srk_worker_profiles%rowtype;
  v_booking public.service_bookings%rowtype;
  v_count bigint;
  v_next bigint;
  v_method text;
begin
  if new.assignment_status='completed' and old.assignment_status is distinct from 'completed' then
    select * into v_worker from public.srk_worker_profiles where id=new.worker_id;
    select * into v_booking from public.service_bookings where id=new.booking_id;

    if v_worker.worker_type='technician' then
      insert into public.srk_technician_booking_cycle(technician_id)
        values(v_worker.id) on conflict (technician_id) do nothing;

      select completed_booking_count into v_count
      from public.srk_technician_booking_cycle
      where technician_id=v_worker.id for update;

      v_next := v_count+1;
      v_method := lower(coalesce(v_booking.payment_method,''));

      if v_next in (3,6) and v_method not in ('online','upi','card') then
        raise exception 'This is technician completed booking number %, online payment is required',v_next;
      end if;

      update public.srk_technician_booking_cycle
        set completed_booking_count=v_next,last_completed_at=clock_timestamp(),updated_at=clock_timestamp()
        where technician_id=v_worker.id;

      insert into public.srk_technician_booking_sequence
        (technician_id,booking_id,sequence_number,payment_method)
      values(v_worker.id,new.booking_id,v_next,
        case when v_method in ('upi','card') then 'online' when v_method in ('cash','online') then v_method else null end);
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists srk_technician_payment_cycle_trigger on public.srk_booking_workers;
create trigger srk_technician_payment_cycle_trigger
before update of assignment_status on public.srk_booking_workers
for each row execute function public.srk_enforce_technician_payment_cycle();

revoke all on function public.srk_worker_session_action(uuid,text,text,text,text) from public, anon;
grant execute on function public.srk_worker_session_action(uuid,text,text,text,text) to authenticated;
