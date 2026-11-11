-- SRK ELECTRONIC: customer cancellation requests and Admin-only decisions.
-- ₹99 is assessed only when a customer requests cancellation after recorded arrival
-- and an Admin approves that request. Feature branch / disposable CI first.
begin;

create unique index if not exists srk_cancellation_one_pending_per_booking
  on public.srk_booking_cancellation_requests(booking_id)
  where decision='pending';

create or replace function public.srk_customer_request_booking_cancellation(
  p_booking_id uuid,
  p_reason text
)
returns jsonb
language plpgsql
security definer
set search_path=''
as $function$
declare
  v_uid uuid := auth.uid();
  v_booking public.service_bookings%rowtype;
  v_request public.srk_booking_cancellation_requests%rowtype;
  v_reason text := btrim(coalesce(p_reason,''));
begin
  if v_uid is null then raise exception 'AUTHENTICATION_REQUIRED' using errcode='28000'; end if;
  if p_booking_id is null or length(v_reason) not between 1 and 1000 then
    raise exception 'INVALID_CANCELLATION_REQUEST' using errcode='22023';
  end if;

  select b.* into v_booking from public.service_bookings b
  where b.id=p_booking_id and b.customer_user_id=v_uid
  for update;
  if not found then raise exception 'CUSTOMER_BOOKING_NOT_FOUND' using errcode='42501'; end if;
  if v_booking.status in ('cancelled','completed')
     or v_booking.timer_state in ('running','start_pending','stop_pending','stopped')
     or v_booking.final_bill_id is not null then
    raise exception 'BOOKING_NOT_CANCELLABLE' using errcode='55000';
  end if;

  select r.* into v_request from public.srk_booking_cancellation_requests r
  where r.booking_id=p_booking_id and r.decision='pending'
  for update;
  if found then
    if v_request.requester_user_id=v_uid then
      return jsonb_build_object('success',true,'request_id',v_request.id,'decision','pending','replayed',true);
    end if;
    raise exception 'CANCELLATION_ALREADY_PENDING' using errcode='55000';
  end if;

  insert into public.srk_booking_cancellation_requests(
    booking_id,requester_user_id,requester_role,reason,arrival_evidence_at_request
  ) values (
    p_booking_id,v_uid,'customer',v_reason,v_booking.electrician_arrived_at
  ) returning * into v_request;

  insert into public.srk_booking_audit_events(
    booking_id,actor_user_id,actor_kind,action,entity_type,entity_id,metadata
  ) values (
    p_booking_id,v_uid,'customer','booking.cancellation_requested',
    'cancellation_request',v_request.id,
    jsonb_build_object('arrival_evidence_at_request',v_request.arrival_evidence_at_request)
  );

  return jsonb_build_object('success',true,'request_id',v_request.id,'decision','pending','replayed',false);
end
$function$;

create or replace function public.srk_admin_decide_booking_cancellation(
  p_request_id uuid,
  p_decision text,
  p_admin_note text default null
)
returns jsonb
language plpgsql
security definer
set search_path=''
as $function$
declare
  v_uid uuid := auth.uid();
  v_request public.srk_booking_cancellation_requests%rowtype;
  v_booking public.service_bookings%rowtype;
  v_now timestamptz := clock_timestamp();
  v_fee numeric(12,2);
begin
  if v_uid is null then raise exception 'AUTHENTICATION_REQUIRED' using errcode='28000'; end if;
  if not coalesce(public.is_srk_admin(),false) then
    raise exception 'ADMIN_ONLY' using errcode='42501';
  end if;
  if p_request_id is null or p_decision is null or p_decision not in ('approved','rejected') then
    raise exception 'INVALID_CANCELLATION_DECISION' using errcode='22023';
  end if;
  if length(coalesce(p_admin_note,''))>1000 then
    raise exception 'ADMIN_NOTE_TOO_LONG' using errcode='22023';
  end if;

  -- Lock order matches the customer request RPC: booking first, then request.
  -- This avoids a request-vs-Admin deadlock when both arrive concurrently.
  select b.* into v_booking
  from public.service_bookings b
  join public.srk_booking_cancellation_requests r on r.booking_id=b.id
  where r.id=p_request_id
  for update of b;
  if not found then raise exception 'CANCELLATION_REQUEST_NOT_FOUND' using errcode='P0002'; end if;

  select r.* into v_request from public.srk_booking_cancellation_requests r
  where r.id=p_request_id and r.booking_id=v_booking.id for update;
  if not found then raise exception 'CANCELLATION_REQUEST_NOT_FOUND' using errcode='P0002'; end if;

  if v_request.decision<>'pending' then
    if v_request.decided_by=v_uid and v_request.decision=p_decision then
      return jsonb_build_object('success',true,'request_id',v_request.id,
        'decision',v_request.decision,'cancellation_fee',v_request.cancellation_fee,'replayed',true);
    end if;
    raise exception 'CANCELLATION_ALREADY_DECIDED' using errcode='55000';
  end if;

  if p_decision='approved' and (
       v_booking.status in ('cancelled','completed')
       or v_booking.timer_state in ('running','start_pending','stop_pending','stopped')
       or v_booking.final_bill_id is not null
     ) then
    raise exception 'BOOKING_NOT_CANCELLABLE' using errcode='55000';
  end if;

  v_fee := case
    when p_decision='approved'
      and v_request.requester_role='customer'
      and v_request.arrival_evidence_at_request is not null
    then 99.00 else 0.00 end;

  update public.srk_booking_cancellation_requests
  set decision=p_decision,decided_by=v_uid,decided_at=v_now,
      admin_note=nullif(btrim(coalesce(p_admin_note,'')),''),
      cancellation_fee=v_fee
  where id=v_request.id;

  if p_decision='approved' then
    update public.service_bookings set status='cancelled' where id=v_booking.id;
  end if;

  insert into public.srk_booking_audit_events(
    booking_id,actor_user_id,actor_kind,action,entity_type,entity_id,metadata
  ) values (
    v_booking.id,v_uid,'admin','booking.cancellation_'||p_decision,
    'cancellation_request',v_request.id,
    jsonb_build_object('requester_role',v_request.requester_role,
      'arrival_evidence_at_request',v_request.arrival_evidence_at_request,
      'cancellation_fee',v_fee,'admin_note',nullif(btrim(coalesce(p_admin_note,'')),''))
  );

  return jsonb_build_object('success',true,'request_id',v_request.id,
    'decision',p_decision,'cancellation_fee',v_fee,'replayed',false);
end
$function$;

create or replace function public.srk_get_customer_booking_cancellation(
  p_booking_id uuid
)
returns jsonb
language plpgsql
stable
security definer
set search_path=''
as $function$
declare
  v_uid uuid := auth.uid();
  v_result jsonb;
begin
  if v_uid is null then raise exception 'AUTHENTICATION_REQUIRED' using errcode='28000'; end if;
  if not exists(select 1 from public.service_bookings b where b.id=p_booking_id and b.customer_user_id=v_uid) then
    raise exception 'CUSTOMER_BOOKING_NOT_FOUND' using errcode='42501';
  end if;
  select jsonb_build_object(
    'request_id',r.id,'decision',r.decision,'reason',r.reason,
    'requested_at',r.requested_at,'decided_at',r.decided_at,
    'cancellation_fee',r.cancellation_fee,'admin_note',r.admin_note
  ) into v_result
  from public.srk_booking_cancellation_requests r
  where r.booking_id=p_booking_id
  order by r.requested_at desc limit 1;
  return coalesce(v_result,'null'::jsonb);
end
$function$;

create or replace function public.srk_admin_list_booking_cancellation_requests()
returns jsonb
language plpgsql
stable
security definer
set search_path=''
as $function$
declare
  v_result jsonb;
begin
  if auth.uid() is null then raise exception 'AUTHENTICATION_REQUIRED' using errcode='28000'; end if;
  if not coalesce(public.is_srk_admin(),false) then raise exception 'ADMIN_ONLY' using errcode='42501'; end if;
  select coalesce(jsonb_agg(jsonb_build_object(
    'request_id',r.id,'booking_id',r.booking_id,'customer_name',b.customer_name,
    'customer_phone',b.phone,'reason',r.reason,'requester_role',r.requester_role,
    'requested_at',r.requested_at,'arrival_evidence_at_request',r.arrival_evidence_at_request,
    'decision',r.decision,'cancellation_fee',r.cancellation_fee,
    'decided_at',r.decided_at,'admin_note',r.admin_note
  ) order by r.requested_at desc),'[]'::jsonb)
  into v_result
  from public.srk_booking_cancellation_requests r
  join public.service_bookings b on b.id=r.booking_id
  where r.decision='pending';
  return v_result;
end
$function$;

revoke all on function public.srk_customer_request_booking_cancellation(uuid,text) from public,anon;
revoke all on function public.srk_admin_decide_booking_cancellation(uuid,text,text) from public,anon;
revoke all on function public.srk_get_customer_booking_cancellation(uuid) from public,anon;
revoke all on function public.srk_admin_list_booking_cancellation_requests() from public,anon;
grant execute on function public.srk_customer_request_booking_cancellation(uuid,text) to authenticated;
grant execute on function public.srk_admin_decide_booking_cancellation(uuid,text,text) to authenticated;
grant execute on function public.srk_get_customer_booking_cancellation(uuid) to authenticated;
grant execute on function public.srk_admin_list_booking_cancellation_requests() to authenticated;

commit;
