
create or replace function public.srk_service_claim_push_delivery_recipients(p_limit integer default 100)
returns table (
  recipient_id uuid, job_id uuid, notification_id uuid, user_id uuid,
  attempt_number integer, notification_type text, title text, body text,
  related_booking_id uuid, deep_link text, subscription_id uuid,
  endpoint text, p256dh text, auth text
)
language plpgsql
security definer
set search_path=pg_catalog,public
as $function$
declare v_stale record;
begin
  if p_limit is null or p_limit<1 or p_limit>500 then raise exception 'p_limit must be between 1 and 500'; end if;

  for v_stale in
    select r.id,r.attempt_count,r.max_attempts
    from public.srk_push_delivery_recipients r
    where r.status='processing' and r.locked_at<clock_timestamp()-interval '2 minutes'
    order by r.locked_at for update skip locked limit 500
  loop
    update public.srk_push_delivery_recipients
       set status=case when v_stale.attempt_count>=v_stale.max_attempts then 'permanent_failure' else 'retry_wait' end,
           locked_at=null,
           next_attempt_at=case when v_stale.attempt_count>=v_stale.max_attempts then next_attempt_at else clock_timestamp()+interval '1 minute' end,
           last_error_code='DISPATCHER_TIMEOUT',
           last_error_message='Dispatcher timed out; recipient delivery recovered',
           updated_at=clock_timestamp()
     where id=v_stale.id;
    insert into public.srk_push_delivery_recipient_attempts(recipient_id,attempt_number,outcome,error_code,error_message,completed_at)
    values(v_stale.id,v_stale.attempt_count,
      case when v_stale.attempt_count>=v_stale.max_attempts then 'permanent_failure' else 'retryable_failure' end,
      'DISPATCHER_TIMEOUT','Dispatcher did not finish recipient delivery within 2 minutes',clock_timestamp())
    on conflict(recipient_id,attempt_number) do nothing;
  end loop;

  insert into public.srk_push_delivery_recipients(job_id,subscription_id)
  select j.id,s.id
  from public.srk_push_delivery_jobs j
  join public.srk_push_subscriptions s on s.user_id=j.user_id
  where j.status in ('queued','retry_wait') and j.next_attempt_at<=clock_timestamp()
  on conflict on constraint srk_push_delivery_recipients_job_id_subscription_id_key do nothing;

  update public.srk_push_delivery_jobs j
     set status='permanent_failure',locked_at=null,
         last_error_code='NO_SUBSCRIPTION',
         last_error_message='No push subscription existed when delivery was attempted',
         updated_at=clock_timestamp()
   where j.status in ('queued','retry_wait') and j.next_attempt_at<=clock_timestamp()
     and not exists(select 1 from public.srk_push_subscriptions s where s.user_id=j.user_id);

  return query
  with picked as (
    select r.id from public.srk_push_delivery_recipients r
    join public.srk_push_delivery_jobs j on j.id=r.job_id
    where r.status in ('queued','retry_wait') and r.next_attempt_at<=clock_timestamp()
      and r.attempt_count<r.max_attempts and j.status<>'cancelled'
    order by r.next_attempt_at,r.created_at
    for update of r skip locked limit p_limit
  ),
  claimed as (
    update public.srk_push_delivery_recipients r
       set status='processing',attempt_count=r.attempt_count+1,
           locked_at=clock_timestamp(),updated_at=clock_timestamp()
      from picked where r.id=picked.id
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
revoke all on function public.srk_service_claim_push_delivery_recipients(integer) from public,anon,authenticated;
grant execute on function public.srk_service_claim_push_delivery_recipients(integer) to service_role;
