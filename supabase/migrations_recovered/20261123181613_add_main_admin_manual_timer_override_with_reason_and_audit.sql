
alter table public.srk_worker_session_events
  drop constraint if exists srk_worker_session_events_pause_reason_check;
alter table public.srk_worker_session_events
  add constraint srk_worker_session_events_pause_reason_check
  check (pause_reason is null or pause_reason in
    ('food_break','material','customer_permission','technical_problem','other','lunch','market_other'));

create table if not exists public.srk_admin_timer_override_events (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null references public.srk_worker_work_sessions(id) on delete restrict,
  booking_id uuid not null references public.service_bookings(id) on delete restrict,
  booking_worker_id uuid not null references public.srk_booking_workers(id) on delete restrict,
  worker_id uuid not null references public.srk_worker_profiles(id) on delete restrict,
  admin_user_id uuid not null,
  action text not null check (action in ('timer_on','timer_off')),
  reason text not null check (length(btrim(reason))>=10),
  previous_status text not null,
  new_status text not null,
  created_at timestamptz not null default now()
);
create index if not exists srk_admin_timer_override_session_idx
  on public.srk_admin_timer_override_events(session_id,created_at desc);
alter table public.srk_admin_timer_override_events enable row level security;

create or replace function public.srk_admin_override_work_timer(
  p_session_id uuid,p_timer_on boolean,p_reason text
)
returns public.srk_worker_work_sessions
language plpgsql
security definer
set search_path to 'pg_catalog','public','auth'
as $function$
declare
  v_session public.srk_worker_work_sessions%rowtype;
  v_booking_id uuid;
  v_worker_id uuid;
  v_worker_user_id uuid;
  v_customer_user_id uuid;
  v_now timestamptz:=clock_timestamp();
  v_elapsed bigint:=0;
  v_previous_status text;
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
    set session_status='running',
        started_at=coalesce(started_at,v_now),
        last_resumed_at=v_now,
        pause_reason=null,pause_started_at=null,pause_minimum_until=null,
        start_latitude=coalesce(start_latitude,(select location_lat from public.srk_worker_profiles where id=v_worker_id)),
        start_longitude=coalesce(start_longitude,(select location_lng from public.srk_worker_profiles where id=v_worker_id)),
        updated_at=v_now
    where id=p_session_id returning * into v_session;
    update public.srk_booking_workers set assignment_status='working',updated_at=v_now
    where id=v_session.booking_worker_id;
    update public.service_bookings set status='in_progress',work_started_at=coalesce(work_started_at,v_now)
    where id=v_booking_id and status in ('new','confirmed','assigned','in_progress');
  else
    if v_session.session_status<>'running' then
      raise exception 'Only a running timer can be turned off';
    end if;
    v_elapsed:=greatest(0,floor(extract(epoch from(v_now-v_session.last_resumed_at)))::bigint);
    update public.srk_worker_work_sessions
    set session_status='paused',
        billable_seconds=least(5184000,billable_seconds+v_elapsed),
        last_resumed_at=null,pause_reason=null,pause_started_at=v_now,
        pause_minimum_until=null,updated_at=v_now
    where id=p_session_id returning * into v_session;
    update public.srk_booking_workers set assignment_status='paused',updated_at=v_now
    where id=v_session.booking_worker_id;
  end if;

  insert into public.srk_worker_session_events(session_id,event_type,event_at,actor_user_id,note,source)
  values(p_session_id,'admin_adjusted',v_now,auth.uid(),
    case when p_timer_on then 'ADMIN TIMER ON: ' else 'ADMIN TIMER OFF: ' end||btrim(p_reason),'admin');

  insert into public.srk_admin_timer_override_events(
    session_id,booking_id,booking_worker_id,worker_id,admin_user_id,action,reason,previous_status,new_status
  ) values(
    p_session_id,v_booking_id,v_session.booking_worker_id,v_worker_id,auth.uid(),
    case when p_timer_on then 'timer_on' else 'timer_off' end,btrim(p_reason),
    v_previous_status,v_session.session_status
  );

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
revoke all on function public.srk_admin_override_work_timer(uuid,boolean,text) from public,anon;
grant execute on function public.srk_admin_override_work_timer(uuid,boolean,text) to authenticated;
