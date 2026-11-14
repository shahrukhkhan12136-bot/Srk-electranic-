-- Durable, provider-event-level idempotency for signed Razorpay webhooks.
create table if not exists public.srk_razorpay_webhook_events (
  event_id text primary key,
  event_type text not null,
  payload_sha256 text not null,
  state text not null check (state in ('processing','processed','ignored','retryable')),
  attempt_count integer not null default 0 check (attempt_count >= 0),
  claim_token uuid,
  lease_expires_at timestamptz,
  first_received_at timestamptz not null default clock_timestamp(),
  last_received_at timestamptz not null default clock_timestamp(),
  completed_at timestamptz,
  last_error text,
  constraint srk_razorpay_webhook_event_id_length check (length(event_id) between 1 and 128),
  constraint srk_razorpay_webhook_event_type_length check (length(event_type) between 1 and 100),
  constraint srk_razorpay_webhook_payload_hash check (payload_sha256 ~ '^[a-f0-9]{64}$')
);

create index if not exists srk_razorpay_webhook_events_retry_idx
  on public.srk_razorpay_webhook_events(state,lease_expires_at)
  where state in ('processing','retryable');

alter table public.srk_razorpay_webhook_events enable row level security;
revoke all on public.srk_razorpay_webhook_events from public,anon,authenticated;

create or replace function public.srk_service_claim_razorpay_webhook_event(
  p_event_id text,p_event_type text,p_payload_sha256 text
)
returns jsonb
language plpgsql
security definer
set search_path=''
as $function$
declare
  v_event public.srk_razorpay_webhook_events%rowtype;
  v_token uuid:=gen_random_uuid();
begin
  if auth.role()<>'service_role' then
    raise exception 'SERVICE_ROLE_REQUIRED' using errcode='42501';
  end if;
  if p_event_id is null or length(p_event_id) not between 1 and 128
     or p_event_type is null or length(p_event_type) not between 1 and 100
     or p_payload_sha256 is null or p_payload_sha256 !~ '^[a-f0-9]{64}$' then
    raise exception 'INVALID_RAZORPAY_WEBHOOK_EVENT' using errcode='22023';
  end if;

  insert into public.srk_razorpay_webhook_events(
    event_id,event_type,payload_sha256,state,attempt_count,claim_token,lease_expires_at
  ) values (
    p_event_id,p_event_type,p_payload_sha256,'processing',1,v_token,clock_timestamp()+interval '2 minutes'
  ) on conflict(event_id) do nothing;

  if found then
    return jsonb_build_object('success',true,'should_process',true,'claim_token',v_token,'attempt_count',1);
  end if;

  select * into v_event from public.srk_razorpay_webhook_events
    where event_id=p_event_id for update;
  if not found then raise exception 'WEBHOOK_EVENT_CLAIM_RETRY'; end if;
  if v_event.event_type<>p_event_type or v_event.payload_sha256<>p_payload_sha256 then
    return jsonb_build_object('success',false,'payload_conflict',true,'should_process',false);
  end if;
  if v_event.state in ('processed','ignored') then
    update public.srk_razorpay_webhook_events set last_received_at=clock_timestamp()
      where event_id=p_event_id;
    return jsonb_build_object('success',true,'duplicate',true,'should_process',false,'state',v_event.state);
  end if;
  if v_event.state='processing' and v_event.lease_expires_at>clock_timestamp() then
    return jsonb_build_object('success',true,'in_progress',true,'should_process',false);
  end if;

  update public.srk_razorpay_webhook_events
    set state='processing',attempt_count=attempt_count+1,claim_token=v_token,
        lease_expires_at=clock_timestamp()+interval '2 minutes',
        last_received_at=clock_timestamp(),last_error=null,completed_at=null
    where event_id=p_event_id;
  return jsonb_build_object('success',true,'should_process',true,
    'claim_token',v_token,'attempt_count',v_event.attempt_count+1);
end;
$function$;

revoke all on function public.srk_service_claim_razorpay_webhook_event(text,text,text) from public,anon,authenticated;
grant execute on function public.srk_service_claim_razorpay_webhook_event(text,text,text) to service_role;

create or replace function public.srk_service_complete_razorpay_webhook_event(
  p_event_id text,p_claim_token uuid,p_outcome text,p_error text default null
)
returns jsonb
language plpgsql
security definer
set search_path=''
as $function$
declare
  v_event public.srk_razorpay_webhook_events%rowtype;
begin
  if auth.role()<>'service_role' then
    raise exception 'SERVICE_ROLE_REQUIRED' using errcode='42501';
  end if;
  if p_event_id is null or p_claim_token is null
     or p_outcome not in ('processed','ignored','retryable')
     or (p_error is not null and length(p_error)>500) then
    raise exception 'INVALID_RAZORPAY_WEBHOOK_COMPLETION' using errcode='22023';
  end if;

  select * into v_event from public.srk_razorpay_webhook_events
    where event_id=p_event_id for update;
  if not found then raise exception 'WEBHOOK_EVENT_NOT_FOUND'; end if;
  if v_event.state<>'processing' or v_event.claim_token is distinct from p_claim_token then
    return jsonb_build_object('success',false,'stale_claim',true,'state',v_event.state);
  end if;

  update public.srk_razorpay_webhook_events
    set state=p_outcome,
        completed_at=case when p_outcome in ('processed','ignored') then clock_timestamp() else null end,
        lease_expires_at=case when p_outcome='retryable' then clock_timestamp() else null end,
        last_error=case when p_outcome='retryable' then left(coalesce(p_error,'Retryable processing error'),500) else null end,
        claim_token=null,last_received_at=clock_timestamp()
    where event_id=p_event_id;
  return jsonb_build_object('success',true,'state',p_outcome);
end;
$function$;

revoke all on function public.srk_service_complete_razorpay_webhook_event(text,uuid,text,text) from public,anon,authenticated;
grant execute on function public.srk_service_complete_razorpay_webhook_event(text,uuid,text,text) to service_role;
