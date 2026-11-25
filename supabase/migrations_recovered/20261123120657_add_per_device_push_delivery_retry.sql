
create table if not exists public.srk_push_delivery_recipients (
  id uuid primary key default gen_random_uuid(),
  job_id uuid not null references public.srk_push_delivery_jobs(id) on delete cascade,
  subscription_id uuid not null references public.srk_push_subscriptions(id) on delete cascade,
  status text not null default 'queued'
    check (status in ('queued','processing','sent','retry_wait','permanent_failure','cancelled')),
  attempt_count integer not null default 0 check (attempt_count >= 0),
  max_attempts integer not null default 5 check (max_attempts between 1 and 20),
  next_attempt_at timestamptz not null default now(),
  locked_at timestamptz,
  sent_at timestamptz,
  last_error_code text,
  last_error_message text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(job_id,subscription_id),
  check ((status='processing' and locked_at is not null) or (status<>'processing' and locked_at is null))
);

create table if not exists public.srk_push_delivery_recipient_attempts (
  id uuid primary key default gen_random_uuid(),
  recipient_id uuid not null references public.srk_push_delivery_recipients(id) on delete cascade,
  attempt_number integer not null check (attempt_number>0),
  outcome text not null check (outcome in ('sent','retryable_failure','permanent_failure')),
  provider_status_code integer,
  error_code text,
  error_message text,
  attempted_at timestamptz not null default now(),
  completed_at timestamptz,
  unique(recipient_id,attempt_number)
);

create index if not exists srk_push_recipients_due_idx
  on public.srk_push_delivery_recipients(next_attempt_at,created_at)
  where status in ('queued','retry_wait');
create index if not exists srk_push_recipients_job_idx
  on public.srk_push_delivery_recipients(job_id,status);
create index if not exists srk_push_recipient_attempts_history_idx
  on public.srk_push_delivery_recipient_attempts(recipient_id,attempt_number);

alter table public.srk_push_delivery_recipients enable row level security;
alter table public.srk_push_delivery_recipient_attempts enable row level security;
revoke all on public.srk_push_delivery_recipients from anon,authenticated;
revoke all on public.srk_push_delivery_recipient_attempts from anon,authenticated;
grant all on public.srk_push_delivery_recipients to service_role;
grant all on public.srk_push_delivery_recipient_attempts to service_role;

create or replace function public.srk_service_claim_push_delivery_recipients(p_limit integer default 100)
returns table (
  recipient_id uuid,
  job_id uuid,
  notification_id uuid,
  user_id uuid,
  attempt_number integer,
  notification_type text,
  title text,
  body text,
  related_booking_id uuid,
  deep_link text,
  subscription_id uuid,
  endpoint text,
  p256dh text,
  auth text
)
language plpgsql
security definer
set search_path=pg_catalog,public
as $function$
declare
  v_stale record;
begin
  if p_limit is null or p_limit<1 or p_limit>500 then
    raise exception 'p_limit must be between 1 and 500';
  end if;

  -- Recover recipients whose dispatcher lease expired.
  for v_stale in
    select r.id,r.attempt_count,r.max_attempts
    from public.srk_push_delivery_recipients r
    where r.status='processing' and r.locked_at<clock_timestamp()-interval '2 minutes'
    order by r.locked_at
    for update skip locked
    limit 500
  loop
    update public.srk_push_delivery_recipients
       set status=case when v_stale.attempt_count>=v_stale.max_attempts then 'permanent_failure' else 'retry_wait' end,
           locked_at=null,
           next_attempt_at=case when v_stale.attempt_count>=v_stale.max_attempts then next_attempt_at else clock_timestamp()+interval '1 minute' end,
           last_error_code='DISPATCHER_TIMEOUT',
           last_error_message='Dispatcher timed out; recipient delivery recovered',
           updated_at=clock_timestamp()
     where id=v_stale.id;
    insert into public.srk_push_delivery_recipient_attempts(
      recipient_id,attempt_number,outcome,error_code,error_message,completed_at
    ) values (
      v_stale.id,v_stale.attempt_count,
      case when v_stale.attempt_count>=v_stale.max_attempts then 'permanent_failure' else 'retryable_failure' end,
      'DISPATCHER_TIMEOUT','Dispatcher did not finish recipient delivery within 2 minutes',clock_timestamp()
    ) on conflict(recipient_id,attempt_number) do nothing;
  end loop;

  -- Materialize one recipient row per currently registered device.
  insert into public.srk_push_delivery_recipients(job_id,subscription_id)
  select j.id,s.id
  from public.srk_push_delivery_jobs j
  join public.srk_push_subscriptions s on s.user_id=j.user_id
  where j.status in ('queued','retry_wait')
    and j.next_attempt_at<=clock_timestamp()
  on conflict(job_id,subscription_id) do nothing;

  -- Jobs with no registered devices are recorded explicitly; no blind retry loop.
  update public.srk_push_delivery_jobs j
     set status='permanent_failure',
         locked_at=null,
         last_error_code='NO_SUBSCRIPTION',
         last_error_message='No push subscription existed when delivery was attempted',
         updated_at=clock_timestamp()
   where j.status in ('queued','retry_wait')
     and j.next_attempt_at<=clock_timestamp()
     and not exists(select 1 from public.srk_push_subscriptions s where s.user_id=j.user_id);

  return query
  with picked as (
    select r.id
    from public.srk_push_delivery_recipients r
    join public.srk_push_delivery_jobs j on j.id=r.job_id
    where r.status in ('queued','retry_wait')
      and r.next_attempt_at<=clock_timestamp()
      and r.attempt_count<r.max_attempts
      and j.status<>'cancelled'
    order by r.next_attempt_at,r.created_at
    for update of r skip locked
    limit p_limit
  ),
  claimed as (
    update public.srk_push_delivery_recipients r
       set status='processing',
           attempt_count=r.attempt_count+1,
           locked_at=clock_timestamp(),
           updated_at=clock_timestamp()
      from picked
     where r.id=picked.id
    returning r.id,r.job_id,r.subscription_id,r.attempt_count
  )
  select c.id,j.id,n.id,j.user_id,c.attempt_count,
         n.notification_type,n.title,n.body,n.related_booking_id,n.deep_link,
         s.id,s.endpoint,s.p256dh,s.auth
  from claimed c
  join public.srk_push_delivery_jobs j on j.id=c.job_id
  join public.srk_app_notifications n on n.id=j.notification_id
  join public.srk_push_subscriptions s on s.id=c.subscription_id;
end
$function$;

create or replace function public.srk_service_finish_push_delivery_recipient(
  p_recipient_id uuid,
  p_outcome text,
  p_provider_status_code integer default null,
  p_error_code text default null,
  p_error_message text default null
)
returns text
language plpgsql
security definer
set search_path=pg_catalog,public
as $function$
declare
  v_recipient public.srk_push_delivery_recipients%rowtype;
  v_result text;
  v_delay_seconds integer;
  v_job_id uuid;
begin
  if p_outcome not in ('sent','retryable_failure','permanent_failure') then
    raise exception 'Invalid recipient outcome';
  end if;
  select * into v_recipient
  from public.srk_push_delivery_recipients
  where id=p_recipient_id
  for update;
  if not found then raise exception 'Push recipient not found'; end if;
  if v_recipient.status<>'processing' then raise exception 'Push recipient is not processing'; end if;

  insert into public.srk_push_delivery_recipient_attempts(
    recipient_id,attempt_number,outcome,provider_status_code,error_code,error_message,completed_at
  ) values (
    v_recipient.id,v_recipient.attempt_count,p_outcome,p_provider_status_code,
    left(p_error_code,120),left(p_error_message,1000),clock_timestamp()
  );

  if p_outcome='sent' then
    update public.srk_push_delivery_recipients
       set status='sent',sent_at=clock_timestamp(),locked_at=null,
           last_error_code=null,last_error_message=null,updated_at=clock_timestamp()
     where id=v_recipient.id;
    v_result:='sent';
  elsif p_outcome='permanent_failure' or v_recipient.attempt_count>=v_recipient.max_attempts then
    update public.srk_push_delivery_recipients
       set status='permanent_failure',locked_at=null,
           last_error_code=left(p_error_code,120),last_error_message=left(p_error_message,1000),
           updated_at=clock_timestamp()
     where id=v_recipient.id;
    v_result:='permanent_failure';
  else
    v_delay_seconds:=least(3600,60*(2^least(v_recipient.attempt_count-1,6))::integer);
    update public.srk_push_delivery_recipients
       set status='retry_wait',locked_at=null,
           next_attempt_at=clock_timestamp()+make_interval(secs=>v_delay_seconds),
           last_error_code=left(p_error_code,120),last_error_message=left(p_error_message,1000),
           updated_at=clock_timestamp()
     where id=v_recipient.id;
    v_result:='retry_wait';
  end if;

  v_job_id:=v_recipient.job_id;
  if not exists(select 1 from public.srk_push_delivery_recipients where job_id=v_job_id and status='processing') then
    update public.srk_push_delivery_jobs j
       set status=case
         when exists(select 1 from public.srk_push_delivery_recipients r where r.job_id=v_job_id and r.status in ('queued','retry_wait')) then 'retry_wait'
         when exists(select 1 from public.srk_push_delivery_recipients r where r.job_id=v_job_id and r.status='sent') then 'sent'
         else 'permanent_failure' end,
         locked_at=null,
         sent_at=case when exists(select 1 from public.srk_push_delivery_recipients r where r.job_id=v_job_id and r.status='sent') then clock_timestamp() else sent_at end,
         updated_at=clock_timestamp()
     where j.id=v_job_id and j.status<>'cancelled';
  else
    update public.srk_push_delivery_jobs
       set status='processing',locked_at=coalesce(locked_at,clock_timestamp()),updated_at=clock_timestamp()
     where id=v_job_id and status<>'cancelled';
  end if;
  return v_result;
end
$function$;

revoke all on function public.srk_service_claim_push_delivery_recipients(integer) from public,anon,authenticated;
revoke all on function public.srk_service_finish_push_delivery_recipient(uuid,text,integer,text,text) from public,anon,authenticated;
grant execute on function public.srk_service_claim_push_delivery_recipients(integer) to service_role;
grant execute on function public.srk_service_finish_push_delivery_recipient(uuid,text,integer,text,text) to service_role;
