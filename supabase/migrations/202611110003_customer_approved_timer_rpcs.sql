-- SRK ELECTRONIC: customer-approved timer RPCs.
-- Depends on timer foundation (001) and integrity extensions (002).
-- Feature Branch only; do not apply to shared TEST or Production without approval.

begin;

-- One unresolved decision per booking and action, regardless of caller retry key.
create unique index if not exists srk_timer_one_pending_action_per_booking
  on public.srk_booking_timer_decisions(booking_id, action)
  where decision = 'pending';

create index if not exists srk_booking_timer_decisions_requester_idx
  on public.srk_booking_timer_decisions(requester_user_id, booking_id, requested_at desc);

create or replace function public.srk_timer_validate_idempotency_key(p_key text)
returns text
language plpgsql
immutable
set search_path = ''
as $function$
begin
  if p_key is null or length(btrim(p_key)) < 8 or length(btrim(p_key)) > 128
     or btrim(p_key) !~ '^[A-Za-z0-9._:-]+$' then
    raise exception 'INVALID_IDEMPOTENCY_KEY' using errcode = '22023';
  end if;
  return btrim(p_key);
end
$function$;

create or replace function public.srk_electrician_record_arrival(
  p_booking_id uuid,
  p_idempotency_key text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_uid uuid := auth.uid();
  v_key text := public.srk_timer_validate_idempotency_key(p_idempotency_key);
  v_booking public.service_bookings%rowtype;
  v_profile_id uuid;
  v_now timestamptz;
begin
  if v_uid is null then raise exception 'AUTHENTICATION_REQUIRED' using errcode='28000'; end if;
  if p_booking_id is null then raise exception 'BOOKING_ID_REQUIRED' using errcode='22023'; end if;

  select b.* into v_booking
  from public.service_bookings b
  where b.id=p_booking_id
  for update;
  if not found then raise exception 'BOOKING_NOT_FOUND' using errcode='P0002'; end if;

  select ep.id into v_profile_id
  from public.electrician_profiles ep
  where ep.id=v_booking.assigned_electrician_id
    and (ep.user_id=v_uid or ep.auth_user_id=v_uid)
    and ep.active=true and ep.verification_status='approved';
  if v_profile_id is null then raise exception 'ASSIGNED_APPROVED_ELECTRICIAN_REQUIRED' using errcode='42501'; end if;

  if not exists (
    select 1 from public.job_offers jo
    where jo.booking_id=p_booking_id
      and jo.electrician_id=v_profile_id
      and jo.status='accepted'
  ) then
    raise exception 'ACCEPTED_OFFER_REQUIRED' using errcode='42501';
  end if;

  if v_booking.electrician_arrived_at is not null then
    if exists (
      select 1 from public.srk_booking_audit_events ae
      where ae.booking_id=p_booking_id and ae.actor_user_id=v_uid
        and ae.action='electrician.arrival_recorded' and ae.idempotency_key=v_key
    ) then
      return jsonb_build_object('success',true,'already_recorded',true,'arrived_at',v_booking.electrician_arrived_at);
    end if;
    raise exception 'ARRIVAL_ALREADY_RECORDED' using errcode='55000';
  end if;

  if v_booking.timer_state <> 'not_requested' then
    raise exception 'ARRIVAL_WINDOW_CLOSED' using errcode='55000';
  end if;

  v_now := clock_timestamp();
  update public.service_bookings
  set electrician_arrived_at=v_now, electrician_arrived_by=v_uid
  where id=p_booking_id;

  insert into public.srk_booking_audit_events(
    booking_id,actor_user_id,actor_kind,action,entity_type,entity_id,idempotency_key,metadata
  ) values (
    p_booking_id,v_uid,'electrician','electrician.arrival_recorded',
    'booking',p_booking_id,v_key,jsonb_build_object('arrived_at',v_now)
  );

  return jsonb_build_object('success',true,'already_recorded',false,'arrived_at',v_now);
end
$function$;

create or replace function public.srk_electrician_request_timer_start(
  p_booking_id uuid,
  p_idempotency_key text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_uid uuid := auth.uid();
  v_key text := public.srk_timer_validate_idempotency_key(p_idempotency_key);
  v_booking public.service_bookings%rowtype;
  v_profile_id uuid;
  v_existing public.srk_booking_timer_decisions%rowtype;
  v_decision public.srk_booking_timer_decisions%rowtype;
begin
  if v_uid is null then raise exception 'AUTHENTICATION_REQUIRED' using errcode='28000'; end if;
  if p_booking_id is null then raise exception 'BOOKING_ID_REQUIRED' using errcode='22023'; end if;

  select b.* into v_booking from public.service_bookings b
  where b.id=p_booking_id for update;
  if not found then raise exception 'BOOKING_NOT_FOUND' using errcode='P0002'; end if;

  select ep.id into v_profile_id from public.electrician_profiles ep
  where ep.id=v_booking.assigned_electrician_id
    and (ep.user_id=v_uid or ep.auth_user_id=v_uid)
    and ep.active=true and ep.verification_status='approved';
  if v_profile_id is null then raise exception 'ASSIGNED_APPROVED_ELECTRICIAN_REQUIRED' using errcode='42501'; end if;
  if not exists (select 1 from public.job_offers jo where jo.booking_id=p_booking_id and jo.electrician_id=v_profile_id and jo.status='accepted') then
    raise exception 'ACCEPTED_OFFER_REQUIRED' using errcode='42501';
  end if;

  select d.* into v_existing from public.srk_booking_timer_decisions d
  where d.booking_id=p_booking_id and d.action='start_request' and d.idempotency_key=v_key;
  if found then
    if v_existing.requester_user_id<>v_uid then raise exception 'IDEMPOTENCY_KEY_ACTOR_MISMATCH' using errcode='42501'; end if;
    return jsonb_build_object('success',true,'decision_id',v_existing.id,'decision',v_existing.decision,'replayed',true);
  end if;

  if v_booking.electrician_arrived_at is null then raise exception 'ARRIVAL_REQUIRED' using errcode='55000'; end if;
  if v_booking.timer_state<>'not_requested' then raise exception 'TIMER_NOT_READY_FOR_START' using errcode='55000'; end if;

  insert into public.srk_booking_timer_decisions(
    booking_id,action,requester_user_id,idempotency_key
  ) values (p_booking_id,'start_request',v_uid,v_key)
  returning * into v_decision;

  update public.service_bookings set timer_state='start_pending' where id=p_booking_id;
  insert into public.srk_booking_audit_events(
    booking_id,actor_user_id,actor_kind,action,entity_type,entity_id,idempotency_key,metadata
  ) values (
    p_booking_id,v_uid,'electrician','timer.start_requested',
    'timer_decision',v_decision.id,v_key,'{}'::jsonb
  );

  return jsonb_build_object('success',true,'decision_id',v_decision.id,'decision','pending','replayed',false);
end
$function$;

create or replace function public.srk_customer_decide_timer_start(
  p_decision_id uuid,
  p_decision text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_uid uuid := auth.uid();
  v_decision public.srk_booking_timer_decisions%rowtype;
  v_booking public.service_bookings%rowtype;
  v_now timestamptz;
begin
  if v_uid is null then raise exception 'AUTHENTICATION_REQUIRED' using errcode='28000'; end if;
  if p_decision_id is null or p_decision not in ('approved','rejected') then raise exception 'INVALID_DECISION' using errcode='22023'; end if;

  select b.* into v_booking
  from public.service_bookings b
  join public.srk_booking_timer_decisions d on d.booking_id=b.id
  where d.id=p_decision_id and b.customer_user_id=v_uid
  for update of b;
  if not found then raise exception 'CUSTOMER_BOOKING_NOT_FOUND' using errcode='42501'; end if;

  select d.* into v_decision from public.srk_booking_timer_decisions d
  where d.id=p_decision_id and d.booking_id=v_booking.id for update;
  if not found or v_decision.action<>'start_request' then raise exception 'START_REQUEST_NOT_FOUND' using errcode='P0002'; end if;

  if v_decision.decision<>'pending' then
    if v_decision.decided_by=v_uid and v_decision.decision=p_decision then
      return jsonb_build_object('success',true,'decision_id',v_decision.id,'decision',v_decision.decision,'replayed',true);
    end if;
    raise exception 'START_REQUEST_ALREADY_DECIDED' using errcode='55000';
  end if;
  if v_booking.timer_state<>'start_pending' then raise exception 'TIMER_STATE_CONFLICT' using errcode='55000'; end if;

  v_now := clock_timestamp();
  update public.srk_booking_timer_decisions
  set decision=p_decision,decided_by=v_uid,decided_at=v_now,
      effective_at=case when p_decision='approved' then v_now else null end
  where id=v_decision.id;

  if p_decision='approved' then
    update public.service_bookings
    set timer_state='running',timer_started_at=v_now,timer_start_approved_at=v_now
    where id=v_booking.id;
  else
    update public.service_bookings set timer_state='not_requested' where id=v_booking.id;
  end if;

  insert into public.srk_booking_audit_events(
    booking_id,actor_user_id,actor_kind,action,entity_type,entity_id,metadata
  ) values (
    v_booking.id,v_uid,'customer','timer.start_'||p_decision,
    'timer_decision',v_decision.id,jsonb_build_object('effective_at',case when p_decision='approved' then v_now else null end)
  );

  return jsonb_build_object('success',true,'decision_id',v_decision.id,'decision',p_decision,'effective_at',case when p_decision='approved' then v_now else null end,'replayed',false);
end
$function$;

create or replace function public.srk_electrician_request_timer_stop(
  p_booking_id uuid,
  p_idempotency_key text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_uid uuid := auth.uid();
  v_key text := public.srk_timer_validate_idempotency_key(p_idempotency_key);
  v_booking public.service_bookings%rowtype;
  v_profile_id uuid;
  v_existing public.srk_booking_timer_decisions%rowtype;
  v_decision public.srk_booking_timer_decisions%rowtype;
begin
  if v_uid is null then raise exception 'AUTHENTICATION_REQUIRED' using errcode='28000'; end if;
  select b.* into v_booking from public.service_bookings b
  where b.id=p_booking_id for update;
  if not found then raise exception 'BOOKING_NOT_FOUND' using errcode='P0002'; end if;

  select ep.id into v_profile_id from public.electrician_profiles ep
  where ep.id=v_booking.assigned_electrician_id
    and (ep.user_id=v_uid or ep.auth_user_id=v_uid)
    and ep.active=true and ep.verification_status='approved';
  if v_profile_id is null then raise exception 'ASSIGNED_APPROVED_ELECTRICIAN_REQUIRED' using errcode='42501'; end if;
  if not exists (select 1 from public.job_offers jo where jo.booking_id=p_booking_id and jo.electrician_id=v_profile_id and jo.status='accepted') then
    raise exception 'ACCEPTED_OFFER_REQUIRED' using errcode='42501';
  end if;

  select d.* into v_existing from public.srk_booking_timer_decisions d
  where d.booking_id=p_booking_id and d.action='stop_request' and d.idempotency_key=v_key;
  if found then
    if v_existing.requester_user_id<>v_uid then raise exception 'IDEMPOTENCY_KEY_ACTOR_MISMATCH' using errcode='42501'; end if;
    return jsonb_build_object('success',true,'decision_id',v_existing.id,'decision',v_existing.decision,'replayed',true);
  end if;
  if v_booking.timer_state<>'running' or v_booking.timer_started_at is null then raise exception 'TIMER_NOT_RUNNING' using errcode='55000'; end if;

  insert into public.srk_booking_timer_decisions(
    booking_id,action,requester_user_id,idempotency_key
  ) values (p_booking_id,'stop_request',v_uid,v_key)
  returning * into v_decision;

  update public.service_bookings
  set timer_state='stop_pending',timer_stop_requested_at=clock_timestamp()
  where id=p_booking_id;
  insert into public.srk_booking_audit_events(
    booking_id,actor_user_id,actor_kind,action,entity_type,entity_id,idempotency_key,metadata
  ) values (
    p_booking_id,v_uid,'electrician','timer.stop_requested',
    'timer_decision',v_decision.id,v_key,'{}'::jsonb
  );
  return jsonb_build_object('success',true,'decision_id',v_decision.id,'decision','pending','replayed',false);
end
$function$;

create or replace function public.srk_customer_decide_timer_stop(
  p_decision_id uuid,
  p_decision text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_uid uuid := auth.uid();
  v_decision public.srk_booking_timer_decisions%rowtype;
  v_booking public.service_bookings%rowtype;
  v_now timestamptz;
  v_elapsed bigint;
  v_minutes bigint;
  v_labour numeric(12,2);
  v_bill_id uuid;
begin
  if v_uid is null then raise exception 'AUTHENTICATION_REQUIRED' using errcode='28000'; end if;
  if p_decision_id is null or p_decision not in ('approved','rejected') then raise exception 'INVALID_DECISION' using errcode='22023'; end if;

  select b.* into v_booking
  from public.service_bookings b
  join public.srk_booking_timer_decisions d on d.booking_id=b.id
  where d.id=p_decision_id and b.customer_user_id=v_uid
  for update of b;
  if not found then raise exception 'CUSTOMER_BOOKING_NOT_FOUND' using errcode='42501'; end if;

  select d.* into v_decision from public.srk_booking_timer_decisions d
  where d.id=p_decision_id and d.booking_id=v_booking.id for update;
  if not found or v_decision.action<>'stop_request' then raise exception 'STOP_REQUEST_NOT_FOUND' using errcode='P0002'; end if;

  if v_decision.decision<>'pending' then
    if v_decision.decided_by=v_uid and v_decision.decision=p_decision then
      return jsonb_build_object('success',true,'decision_id',v_decision.id,'decision',v_decision.decision,'bill_id',v_booking.final_bill_id,'replayed',true);
    end if;
    raise exception 'STOP_REQUEST_ALREADY_DECIDED' using errcode='55000';
  end if;
  if v_booking.timer_state<>'stop_pending' or v_booking.timer_started_at is null then raise exception 'TIMER_STATE_CONFLICT' using errcode='55000'; end if;
  if v_booking.service_category_code is null or v_booking.service_category_label is null or v_booking.hourly_rate_snapshot is null then
    raise exception 'BOOKING_RATE_SNAPSHOT_MISSING' using errcode='55000';
  end if;
  if v_booking.final_bill_id is not null then raise exception 'FINAL_BILL_ALREADY_EXISTS' using errcode='55000'; end if;

  v_now := clock_timestamp();
  if p_decision='rejected' then
    update public.srk_booking_timer_decisions
    set decision='rejected',decided_by=v_uid,decided_at=v_now,effective_at=null
    where id=v_decision.id;
    update public.service_bookings
    set timer_state='running',timer_stop_requested_at=null
    where id=v_booking.id;
    insert into public.srk_booking_audit_events(
      booking_id,actor_user_id,actor_kind,action,entity_type,entity_id,metadata
    ) values (v_booking.id,v_uid,'customer','timer.stop_rejected','timer_decision',v_decision.id,'{}'::jsonb);
    return jsonb_build_object('success',true,'decision_id',v_decision.id,'decision','rejected','replayed',false);
  end if;

  v_elapsed := greatest(0,ceil(extract(epoch from (v_now-v_booking.timer_started_at)))::bigint);
  v_minutes := case when v_elapsed=0 then 0 else (v_elapsed+59)/60 end;
  v_labour := round((v_booking.hourly_rate_snapshot::numeric*v_minutes::numeric)/60,2);
  insert into public.srk_final_bills(
    booking_id,bill_version,category_code,category_label,hourly_rate,
    started_at,stopped_at,elapsed_seconds,billable_minutes,labour_amount,
    calculation_version,generated_at,generated_by
  ) values (
    v_booking.id,1,v_booking.service_category_code,v_booking.service_category_label,
    v_booking.hourly_rate_snapshot,v_booking.timer_started_at,v_now,
    v_elapsed,v_minutes,v_labour,'timer-v1',v_now,v_uid
  ) returning id into v_bill_id;

  update public.service_bookings
  set timer_state='stopped',timer_stopped_at=v_now,timer_stop_approved_at=v_now,
      timer_elapsed_seconds=v_elapsed,timer_billable_minutes=v_minutes,final_bill_id=v_bill_id
  where id=v_booking.id;

  update public.srk_booking_timer_decisions
  set decision='approved',decided_by=v_uid,decided_at=v_now,effective_at=v_now
  where id=v_decision.id;

  insert into public.srk_booking_audit_events(
    booking_id,actor_user_id,actor_kind,action,entity_type,entity_id,metadata
  ) values (
    v_booking.id,v_uid,'customer','timer.stop_approved_and_bill_generated',
    'final_bill',v_bill_id,
    jsonb_build_object('decision_id',v_decision.id,'stopped_at',v_now,
      'elapsed_seconds',v_elapsed,'billable_minutes',v_minutes,
      'hourly_rate_snapshot',v_booking.hourly_rate_snapshot,'labour_amount',v_labour,
      'calculation_version','timer-v1')
  );

  return jsonb_build_object(
    'success',true,'decision_id',v_decision.id,'decision','approved',
    'bill_id',v_bill_id,'elapsed_seconds',v_elapsed,
    'billable_minutes',v_minutes,'labour_amount',v_labour,'replayed',false
  );
end
$function$;

revoke all on function public.srk_timer_validate_idempotency_key(text) from public, anon, authenticated;
revoke all on function public.srk_electrician_record_arrival(uuid,text) from public, anon;
revoke all on function public.srk_electrician_request_timer_start(uuid,text) from public, anon;
revoke all on function public.srk_customer_decide_timer_start(uuid,text) from public, anon;
revoke all on function public.srk_electrician_request_timer_stop(uuid,text) from public, anon;
revoke all on function public.srk_customer_decide_timer_stop(uuid,text) from public, anon;

grant execute on function public.srk_electrician_record_arrival(uuid,text) to authenticated;
grant execute on function public.srk_electrician_request_timer_start(uuid,text) to authenticated;
grant execute on function public.srk_customer_decide_timer_start(uuid,text) to authenticated;
grant execute on function public.srk_electrician_request_timer_stop(uuid,text) to authenticated;
grant execute on function public.srk_customer_decide_timer_stop(uuid,text) to authenticated;

commit;
