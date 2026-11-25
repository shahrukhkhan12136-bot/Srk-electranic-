
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
declare
  v_stale record;
begin
  if p_limit is null or p_limit < 1 or p_limit > 100 then
    raise exception 'p_limit must be between 1 and 100';
  end if;

  -- Recover a dispatcher crash after its claim. Keep the already-counted attempt.
  for v_stale in
    select j.id,j.attempt_count,j.max_attempts
      from public.srk_push_delivery_jobs j
     where j.status='processing'
       and j.locked_at < clock_timestamp() - interval '2 minutes'
     order by j.locked_at
     for update skip locked
     limit 100
  loop
    insert into public.srk_push_delivery_attempts(
      job_id,attempt_number,outcome,error_code,error_message,completed_at
    ) values (
      v_stale.id,v_stale.attempt_count,
      case when v_stale.attempt_count >= v_stale.max_attempts
           then 'permanent_failure' else 'retryable_failure' end,
      'DISPATCHER_TIMEOUT','Dispatcher did not finish the claimed job within 2 minutes',
      clock_timestamp()
    ) on conflict(job_id,attempt_number) do nothing;

    update public.srk_push_delivery_jobs
       set status=case when v_stale.attempt_count >= v_stale.max_attempts
                       then 'permanent_failure' else 'retry_wait' end,
           locked_at=null,
           next_attempt_at=case when v_stale.attempt_count >= v_stale.max_attempts
                                then next_attempt_at
                                else clock_timestamp() + interval '1 minute' end,
           last_error_code='DISPATCHER_TIMEOUT',
           last_error_message='Dispatcher timed out; job recovered safely',
           updated_at=clock_timestamp()
     where id=v_stale.id and status='processing';
  end loop;

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

revoke all on function public.srk_service_claim_push_delivery_jobs(integer) from public, anon, authenticated;
grant execute on function public.srk_service_claim_push_delivery_jobs(integer) to service_role;
comment on function public.srk_service_claim_push_delivery_jobs(integer) is
'Service-role-only atomic queue claim using SKIP LOCKED; recovers dispatcher crashes after a 2-minute lease and returns notification plus owned push subscriptions.';
