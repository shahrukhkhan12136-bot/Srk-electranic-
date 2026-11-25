
create or replace function public.srk_admin_reconcile_offline_timer_event(
  p_event_id uuid,
  p_decision text,
  p_adjust_seconds bigint,
  p_note text
)
returns public.srk_worker_offline_timer_events
language plpgsql
security definer
set search_path to 'pg_catalog','public','auth'
as $function$
declare
  v_event public.srk_worker_offline_timer_events%rowtype;
  v_session public.srk_worker_work_sessions%rowtype;
  v_last_action text;
  v_last_at timestamptz;
begin
  if auth.uid() is null or not public.srk_has_admin_permission('bookings.manage') then
    raise exception 'Booking management permission required' using errcode='42501';
  end if;

  if p_decision not in ('accepted','rejected') then
    raise exception 'Invalid offline event decision' using errcode='22023';
  end if;

  if p_decision='accepted'
     and (p_adjust_seconds is null or p_adjust_seconds not between -5184000 and 5184000) then
    raise exception 'Timer adjustment is outside allowed range' using errcode='22023';
  end if;

  select * into v_event
  from public.srk_worker_offline_timer_events
  where id=p_event_id
  for update;

  if not found or v_event.review_status<>'pending' then
    raise exception 'Offline timer event is not pending';
  end if;

  select * into v_session
  from public.srk_worker_work_sessions
  where id=v_event.session_id
  for update;

  if not found then raise exception 'Work session not found'; end if;

  if p_decision='accepted' then
    if v_session.session_status='running' then
      raise exception 'Pause/complete live session before reconciliation';
    end if;

    -- Admin must reconcile offline events in chronological order. This prevents
    -- accepting a pause/resume/complete event while an earlier event is pending.
    if exists (
      select 1
      from public.srk_worker_offline_timer_events e
      where e.session_id=v_event.session_id
        and e.review_status='pending'
        and e.id<>v_event.id
        and (e.client_event_at,e.server_received_at,e.id)
            < (v_event.client_event_at,v_event.server_received_at,v_event.id)
    ) then
      raise exception 'Review earlier pending offline timer events first';
    end if;

    select e.action,e.client_event_at
      into v_last_action,v_last_at
    from public.srk_worker_offline_timer_events e
    where e.session_id=v_event.session_id
      and e.review_status='accepted'
    order by e.client_event_at desc,e.server_received_at desc,e.id desc
    limit 1;

    if v_last_action is null then
      if v_event.action<>'start' then
        raise exception 'First accepted offline timer event must be start';
      end if;
    else
      if v_event.client_event_at<=v_last_at then
        raise exception 'Offline timer event timestamp must be later than the previous accepted event';
      end if;

      if v_last_action in ('start','resume') and v_event.action not in ('pause','complete') then
        raise exception 'After start/resume, next offline event must be pause or complete';
      elsif v_last_action='pause' and v_event.action not in ('resume','complete') then
        raise exception 'After pause, next offline event must be resume or complete';
      elsif v_last_action='complete' then
        raise exception 'No offline timer event is allowed after complete';
      end if;
    end if;

    if v_session.billable_seconds+p_adjust_seconds<0
       or v_session.billable_seconds+p_adjust_seconds>5184000 then
      raise exception 'Reconciled billable time is outside allowed range';
    end if;

    update public.srk_worker_work_sessions
    set billable_seconds=billable_seconds+p_adjust_seconds,
        updated_at=clock_timestamp()
    where id=v_event.session_id;

    insert into public.srk_worker_session_events(
      session_id,event_type,event_at,actor_user_id,note,source
    )
    values(
      v_event.session_id,'admin_adjusted',clock_timestamp(),auth.uid(),
      'Offline timer event '||v_event.action||
      '; client event at='||v_event.client_event_at::text||
      '; adjustment seconds='||p_adjust_seconds||'; '||coalesce(p_note,''),
      'admin'
    );
  end if;

  update public.srk_worker_offline_timer_events
  set review_status=p_decision,
      reviewed_by=auth.uid(),
      reviewed_at=clock_timestamp(),
      admin_note=p_note
  where id=p_event_id
  returning * into v_event;

  return v_event;
end
$function$;

revoke all on function public.srk_admin_reconcile_offline_timer_event(uuid,text,bigint,text) from public,anon;
grant execute on function public.srk_admin_reconcile_offline_timer_event(uuid,text,bigint,text) to authenticated;
