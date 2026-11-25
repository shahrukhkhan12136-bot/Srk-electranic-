CREATE OR REPLACE FUNCTION public.srk_service_claim_push_delivery_jobs(p_limit integer DEFAULT 25)
RETURNS TABLE(job_id uuid,notification_id uuid,user_id uuid,attempt_number integer,notification_type text,title text,body text,related_booking_id uuid,deep_link text,subscriptions jsonb)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'pg_catalog','public'
AS $function$
declare v_stale record;
begin
 if p_limit is null or p_limit<1 or p_limit>100 then
  raise exception 'p_limit must be between 1 and 100';
 end if;

 for v_stale in
  select j.id,j.attempt_count,j.max_attempts
  from public.srk_push_delivery_jobs j
  where j.status='processing' and j.locked_at<clock_timestamp()-interval '2 minutes'
  order by j.locked_at for update skip locked limit 100
 loop
  insert into public.srk_push_delivery_attempts(job_id,attempt_number,outcome,error_code,error_message,completed_at)
  values(v_stale.id,v_stale.attempt_count,
   case when v_stale.attempt_count>=v_stale.max_attempts then 'permanent_failure' else 'retryable_failure' end,
   'DISPATCHER_TIMEOUT','Dispatcher did not finish the claimed job within 2 minutes',clock_timestamp())
  on conflict on constraint srk_push_delivery_attempts_job_id_attempt_number_key do nothing;

  update public.srk_push_delivery_jobs
  set status=case when v_stale.attempt_count>=v_stale.max_attempts then 'permanent_failure' else 'retry_wait' end,
      locked_at=null,
      next_attempt_at=case when v_stale.attempt_count>=v_stale.max_attempts then next_attempt_at
                           else clock_timestamp()+interval '1 minute' end,
      last_error_code='DISPATCHER_TIMEOUT',
      last_error_message='Dispatcher timed out; job recovered safely',
      updated_at=clock_timestamp()
  where id=v_stale.id and status='processing';
 end loop;

 return query
 with picked as (
  select j.id from public.srk_push_delivery_jobs j
  where j.status in ('queued','retry_wait')
    and j.next_attempt_at<=clock_timestamp()
    and j.attempt_count<j.max_attempts
  order by j.next_attempt_at,j.created_at
  for update skip locked limit p_limit
 ),
 claimed as (
  update public.srk_push_delivery_jobs j
  set status='processing',attempt_count=j.attempt_count+1,
      locked_at=clock_timestamp(),last_attempt_at=clock_timestamp(),updated_at=clock_timestamp()
  from picked where j.id=picked.id
  returning j.id,j.notification_id,j.user_id,j.attempt_count
 )
 select c.id,n.id,c.user_id,c.attempt_count,n.notification_type,n.title,n.body,n.related_booking_id,n.deep_link,
  coalesce((
   select jsonb_agg(jsonb_build_object('id',s.id,'endpoint',s.endpoint,'p256dh',s.p256dh,'auth',s.auth))
   from public.srk_push_subscriptions s where s.user_id=c.user_id
  ),'[]'::jsonb)
 from claimed c join public.srk_app_notifications n on n.id=c.notification_id;
end
$function$;

CREATE OR REPLACE FUNCTION public.srk_service_claim_push_delivery_recipients(p_limit integer DEFAULT 100)
RETURNS TABLE(recipient_id uuid,job_id uuid,notification_id uuid,user_id uuid,attempt_number integer,notification_type text,title text,body text,related_booking_id uuid,deep_link text,subscription_id uuid,endpoint text,p256dh text,auth text)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'pg_catalog','public'
AS $function$
declare v_stale record;
begin
 if p_limit is null or p_limit<1 or p_limit>500 then
  raise exception 'p_limit must be between 1 and 500';
 end if;

 for v_stale in
  select r.id,r.attempt_count,r.max_attempts
  from public.srk_push_delivery_recipients r
  where r.status='processing' and r.locked_at<clock_timestamp()-interval '2 minutes'
  order by r.locked_at for update skip locked limit 500
 loop
  update public.srk_push_delivery_recipients
  set status=case when v_stale.attempt_count>=v_stale.max_attempts then 'permanent_failure' else 'retry_wait' end,
      locked_at=null,
      next_attempt_at=case when v_stale.attempt_count>=v_stale.max_attempts then next_attempt_at
                           else clock_timestamp()+interval '1 minute' end,
      last_error_code='DISPATCHER_TIMEOUT',
      last_error_message='Dispatcher timed out; recipient delivery recovered',
      updated_at=clock_timestamp()
  where id=v_stale.id;
  insert into public.srk_push_delivery_recipient_attempts(recipient_id,attempt_number,outcome,error_code,error_message,completed_at)
  values(v_stale.id,v_stale.attempt_count,
   case when v_stale.attempt_count>=v_stale.max_attempts then 'permanent_failure' else 'retryable_failure' end,
   'DISPATCHER_TIMEOUT','Dispatcher did not finish recipient delivery within 2 minutes',clock_timestamp())
  on conflict on constraint srk_push_delivery_recipient_att_recipient_id_attempt_number_key do nothing;
 end loop;

 insert into public.srk_push_delivery_recipients(job_id,subscription_id)
 select j.id,s.id from public.srk_push_delivery_jobs j
 join public.srk_push_subscriptions s on s.user_id=j.user_id
 where j.status in ('queued','retry_wait') and j.next_attempt_at<=clock_timestamp()
 on conflict on constraint srk_push_delivery_recipients_job_id_subscription_id_key do nothing;

 update public.srk_push_delivery_jobs j
 set status='permanent_failure',locked_at=null,last_error_code='NO_SUBSCRIPTION',
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
 select c.id,j.id,n.id,j.user_id,c.attempt_count,n.notification_type,n.title,n.body,n.related_booking_id,n.deep_link,
        s.id,s.endpoint,s.p256dh,s.auth
 from claimed c
 join public.srk_push_delivery_jobs j on j.id=c.job_id
 join public.srk_app_notifications n on n.id=j.notification_id
 join public.srk_push_subscriptions s on s.id=c.subscription_id;
end
$function$;

CREATE OR REPLACE FUNCTION public.srk_get_current_policy_documents(p_language_code text DEFAULT 'hi'::text)
RETURNS TABLE(id uuid,policy_type text,audience_role text,language_code text,version text,title text,body text,effective_at timestamptz)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path TO 'pg_catalog','public','auth'
AS $function$
declare v_role text;
begin
 if auth.uid() is null then raise exception 'Authentication required' using errcode='42501'; end if;
 if exists(select 1 from public.srk_customer_profiles where user_id=auth.uid()) then
  v_role:='customer';
 else
  select worker_type into v_role from public.srk_worker_profiles where user_id=auth.uid() limit 1;
 end if;
 if v_role is null then raise exception 'Account role not found'; end if;
 return query
 select d.id,d.policy_type,d.audience_role,d.language_code,d.version,d.title,d.body,d.effective_at
 from public.srk_policy_documents d
 where d.audience_role=v_role and d.status='published'
  and d.effective_at<=statement_timestamp()
  and d.language_code in (p_language_code,'hi')
 order by case when d.language_code=p_language_code then 0 else 1 end,d.policy_type;
end
$function$;