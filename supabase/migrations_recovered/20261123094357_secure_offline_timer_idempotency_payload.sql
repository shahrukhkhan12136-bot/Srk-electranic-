
create or replace function public.srk_worker_submit_offline_timer_event(
  p_session_id uuid,
  p_action text,
  p_client_event_at timestamptz,
  p_idempotency_key text,
  p_payload jsonb default '{}'::jsonb
)
returns public.srk_worker_offline_timer_events
language plpgsql
security definer
set search_path to 'pg_catalog', 'public', 'auth'
as $function$
declare
  v_worker uuid;
  v_event public.srk_worker_offline_timer_events%rowtype;
  v_payload jsonb := coalesce(p_payload, '{}'::jsonb);
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  if p_idempotency_key is null
     or length(btrim(p_idempotency_key)) = 0
     or length(p_idempotency_key) > 200 then
    raise exception 'Invalid idempotency key';
  end if;

  select w.id into v_worker
  from public.srk_worker_work_sessions s
  join public.srk_booking_workers bw on bw.id=s.booking_worker_id
  join public.srk_worker_profiles w on w.id=bw.worker_id
  where s.id=p_session_id and w.user_id=auth.uid();

  if v_worker is null then
    raise exception 'Session not found or not yours';
  end if;

  if p_action not in ('start','pause','resume','complete') then
    raise exception 'Invalid offline timer action';
  end if;

  if p_client_event_at is null
     or p_client_event_at > clock_timestamp()+interval '5 minutes' then
    raise exception 'Invalid client event timestamp';
  end if;

  insert into public.srk_worker_offline_timer_events(
    session_id,worker_id,action,client_event_at,idempotency_key,payload
  )
  values(
    p_session_id,v_worker,p_action,p_client_event_at,
    p_idempotency_key,v_payload
  )
  on conflict(idempotency_key) do nothing
  returning * into v_event;

  if found then
    return v_event;
  end if;

  select * into v_event
  from public.srk_worker_offline_timer_events
  where idempotency_key=p_idempotency_key
  for update;

  if not found then
    raise exception 'Idempotency conflict could not be resolved; retry request';
  end if;

  if v_event.session_id is distinct from p_session_id
     or v_event.worker_id is distinct from v_worker
     or v_event.action is distinct from p_action
     or v_event.client_event_at is distinct from p_client_event_at
     or v_event.payload is distinct from v_payload then
    raise exception 'Idempotency key was already used for a different timer event';
  end if;

  return v_event;
end
$function$;
