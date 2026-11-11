-- Cancellation authorization, arrival-fee eligibility, and Admin decision tests.
-- Disposable PostgreSQL harness only; all fixtures and helper override roll back.
begin;

create or replace function public.is_srk_admin()
returns boolean language sql stable as $function$ select true $function$;

do $test$
declare
  v_customer uuid := '50000000-0000-4000-8000-000000000001';
  v_admin uuid := '50000000-0000-4000-8000-000000000002';
  v_outsider uuid := '50000000-0000-4000-8000-000000000003';
  v_arrived_booking uuid := '50000000-0000-4000-8000-000000000011';
  v_no_arrival_booking uuid := '50000000-0000-4000-8000-000000000012';
  v_rejected_booking uuid := '50000000-0000-4000-8000-000000000013';
  v_request uuid;
  v_result jsonb;
  v_fee numeric(12,2);
  v_status text;
begin
  insert into auth.users(id) values(v_customer),(v_admin),(v_outsider);
  insert into public.service_bookings(id,customer_user_id,status,electrician_arrived_at)
  values
    (v_arrived_booking,v_customer,'assigned',clock_timestamp()),
    (v_no_arrival_booking,v_customer,'assigned',null),
    (v_rejected_booking,v_customer,'assigned',clock_timestamp());

  perform set_config('request.jwt.claim.sub',v_outsider::text,true);
  begin
    perform public.srk_customer_request_booking_cancellation(v_arrived_booking,'Not my booking');
    raise exception 'unrelated customer cancellation unexpectedly accepted';
  exception when insufficient_privilege then null;
  end;

  perform set_config('request.jwt.claim.sub',v_customer::text,true);
  v_result:=public.srk_customer_request_booking_cancellation(v_arrived_booking,'Customer changed plans');
  v_request:=(v_result->>'request_id')::uuid;
  if v_result->>'decision'<>'pending' then raise exception 'request did not enter pending state'; end if;
  v_result:=public.srk_customer_request_booking_cancellation(v_arrived_booking,'Retry');
  if coalesce((v_result->>'replayed')::boolean,false) is not true then
    raise exception 'duplicate pending request was not replay-safe';
  end if;

  perform set_config('request.jwt.claim.sub',v_outsider::text,true);
  begin
    perform public.srk_admin_decide_booking_cancellation(v_request,'approved',null);
    raise exception 'non-admin cancellation decision unexpectedly accepted';
  exception when insufficient_privilege then null;
  end;

  perform set_config('request.jwt.claim.sub',v_admin::text,true);
  v_result:=public.srk_admin_decide_booking_cancellation(v_request,'approved','Verified customer request');
  if (v_result->>'cancellation_fee')::numeric<>99 then
    raise exception 'arrival + customer request + Admin approval must assess exactly INR 99';
  end if;
  select status into v_status from public.service_bookings where id=v_arrived_booking;
  if v_status<>'cancelled' then raise exception 'approved cancellation did not cancel booking'; end if;

  perform set_config('request.jwt.claim.sub',v_customer::text,true);
  v_result:=public.srk_customer_request_booking_cancellation(v_no_arrival_booking,'Before electrician arrived');
  v_request:=(v_result->>'request_id')::uuid;
  perform set_config('request.jwt.claim.sub',v_admin::text,true);
  v_result:=public.srk_admin_decide_booking_cancellation(v_request,'approved',null);
  if (v_result->>'cancellation_fee')::numeric<>0 then
    raise exception 'no-arrival cancellation must not assess a fee';
  end if;

  perform set_config('request.jwt.claim.sub',v_customer::text,true);
  v_result:=public.srk_customer_request_booking_cancellation(v_rejected_booking,'Please cancel');
  v_request:=(v_result->>'request_id')::uuid;
  perform set_config('request.jwt.claim.sub',v_admin::text,true);
  v_result:=public.srk_admin_decide_booking_cancellation(v_request,'rejected','Not approved');
  if (v_result->>'cancellation_fee')::numeric<>0 then
    raise exception 'rejected cancellation must not assess a fee';
  end if;
  select status into v_status from public.service_bookings where id=v_rejected_booking;
  if v_status='cancelled' then raise exception 'rejected cancellation changed booking status'; end if;

  if not exists(select 1 from public.srk_booking_audit_events where booking_id=v_arrived_booking and action='booking.cancellation_approved') then
    raise exception 'Admin cancellation decision audit event missing';
  end if;
end
$test$;

rollback;
