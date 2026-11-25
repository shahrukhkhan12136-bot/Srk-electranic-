
create or replace function public.srk_service_claim_push_delivery_jobs(p_limit integer default 25)
returns table (
  job_id uuid,
  notification_id uuid,
  user_id uuid,
  attempt_number integer,
  notification_type text,
  title text,
  body text,
  related_booking_id uuid,
  deep_link text,
  subscriptions jsonb
)
language plpgsql
security definer
set search_path = pg_catalog, public
as $function$
begin
  if p_limit is null or p_limit < 1 or p_limit > 100 then
    raise exception 'p_limit must be between 1 and 100';
  end if;

  return query
  with picked as (
    select j.id
    from public.srk_push_delivery_jobs j
    where j.status in ('queued','retry_wait')
      and j.next_attempt_at <= clock_timestamp()
      and j.attempt_count < j.max_attempts
    order by j.next_attempt_at, j.created_at
    for update skip locked
    limit p_limit
  ),
  claimed as (
    update public.srk_push_delivery_jobs j
       set status='processing',
           attempt_count=j.attempt_count+1,
           locked_at=clock_timestamp(),
           last_attempt_at=clock_timestamp(),
           updated_at=clock_timestamp()
      from picked
     where j.id=picked.id
    returning j.id,j.notification_id,j.user_id,j.attempt_count
  )
  select c.id,n.id,c.user_id,c.attempt_count,
         n.notification_type,n.title,n.body,n.related_booking_id,n.deep_link,
         coalesce((
           select jsonb_agg(jsonb_build_object(
             'id',s.id,'endpoint',s.endpoint,'p256dh',s.p256dh,'auth',s.auth
           ))
           from public.srk_push_subscriptions s
           where s.user_id=c.user_id
         ),'[]'::jsonb)
  from claimed c
  join public.srk_app_notifications n on n.id=c.notification_id;
end
$function$;

create or replace function public.srk_service_finish_push_delivery(
  p_job_id uuid,
  p_outcome text,
  p_provider_status_code integer default null,
  p_error_code text default null,
  p_error_message text default null
)
returns text
language plpgsql
security definer
set search_path = pg_catalog, public
as $function$
declare
  v_job public.srk_push_delivery_jobs%rowtype;
  v_result text;
  v_delay_seconds integer;
begin
  if p_outcome not in ('sent','retryable_failure','permanent_failure','no_subscription') then
    raise exception 'Invalid push delivery outcome';
  end if;
  select * into v_job
    from public.srk_push_delivery_jobs
   where id=p_job_id
   for update;
  if not found then raise exception 'Push delivery job not found'; end if;
  if v_job.status <> 'processing' then raise exception 'Push delivery job is not processing'; end if;

  insert into public.srk_push_delivery_attempts(
    job_id,attempt_number,outcome,provider_status_code,error_code,error_message,completed_at
  ) values (
    v_job.id,v_job.attempt_count,p_outcome,p_provider_status_code,
    left(p_error_code,120),left(p_error_message,1000),clock_timestamp()
  );

  if p_outcome='sent' then
    update public.srk_push_delivery_jobs
       set status='sent',sent_at=clock_timestamp(),locked_at=null,
           last_error_code=null,last_error_message=null,updated_at=clock_timestamp()
     where id=v_job.id;
    v_result := 'sent';
  elsif p_outcome='no_subscription' or p_outcome='permanent_failure'
        or v_job.attempt_count >= v_job.max_attempts then
    update public.srk_push_delivery_jobs
       set status='permanent_failure',locked_at=null,
           last_error_code=left(p_error_code,120),
           last_error_message=left(p_error_message,1000),
           updated_at=clock_timestamp()
     where id=v_job.id;
    v_result := 'permanent_failure';
  else
    v_delay_seconds := least(3600, 60 * (2 ^ least(v_job.attempt_count-1,6))::integer);
    update public.srk_push_delivery_jobs
       set status='retry_wait',locked_at=null,
           next_attempt_at=clock_timestamp()+make_interval(secs=>v_delay_seconds),
           last_error_code=left(p_error_code,120),
           last_error_message=left(p_error_message,1000),
           updated_at=clock_timestamp()
     where id=v_job.id;
    v_result := 'retry_wait';
  end if;
  return v_result;
end
$function$;

revoke all on function public.srk_service_claim_push_delivery_jobs(integer) from public, anon, authenticated;
revoke all on function public.srk_service_finish_push_delivery(uuid,text,integer,text,text) from public, anon, authenticated;
grant execute on function public.srk_service_claim_push_delivery_jobs(integer) to service_role;
grant execute on function public.srk_service_finish_push_delivery(uuid,text,integer,text,text) to service_role;

comment on function public.srk_service_claim_push_delivery_jobs(integer) is
'Service-role-only atomic queue claim using FOR UPDATE SKIP LOCKED; returns notification and owned push subscriptions.';
comment on function public.srk_service_finish_push_delivery(uuid,text,integer,text,text) is
'Service-role-only delivery completion with immutable attempt record and bounded exponential retry (max 5 attempts by default).';
