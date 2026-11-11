-- End-to-end SQL assertions for the customer-approved timer RPC state machine.
-- Disposable PostgreSQL harness only. All fixtures are rolled back.

begin;

do $test$
declare
  v_customer uuid := '40000000-0000-4000-8000-000000000001';
  v_electrician uuid := '40000000-0000-4000-8000-000000000002';
  v_outsider uuid := '40000000-0000-4000-8000-000000000005';
  v_profile uuid := '40000000-0000-4000-8000-000000000003';
  v_booking uuid := '40000000-0000-4000-8000-000000000004';
  v_start_decision uuid;
  v_stop_decision uuid;
  v_bill uuid;
  v_result jsonb;
  v_state text;
  v_elapsed bigint;
  v_minutes bigint;
  v_bill_count bigint;
begin
  insert into auth.users(id) values (v_customer),(v_electrician),(v_outsider);
  insert into public.electrician_profiles(id,user_id,active,verification_status)
  values (v_profile,v_electrician,true,'approved');
  insert into public.service_bookings(
    id,customer_user_id,assigned_electrician_id,status,
    service_category_code,service_category_label,hourly_rate_snapshot
  ) values (
    v_booking,v_customer,v_profile,'assigned','helper','Helper',112.375
  );
  insert into public.job_offers(booking_id,electrician_id,status)
  values (v_booking,v_profile,'accepted');

  perform set_config('request.jwt.claim.sub',v_electrician::text,true);
  v_result := public.srk_electrician_record_arrival(v_booking,'arrival-key-0001');
  if coalesce((v_result->>'success')::boolean,false) is not true then
    raise exception 'arrival RPC did not succeed: %',v_result;
  end if;
  -- Same arrival key is replay-safe; a new key cannot overwrite the timestamp.
  v_result := public.srk_electrician_record_arrival(v_booking,'arrival-key-0001');
  if coalesce((v_result->>'already_recorded')::boolean,false) is not true then
    raise exception 'arrival retry was not recognized';
  end if;

  v_result := public.srk_electrician_request_timer_start(v_booking,'start-key-0001');
  v_start_decision := (v_result->>'decision_id')::uuid;
  v_result := public.srk_electrician_request_timer_start(v_booking,'start-key-0001');
  if coalesce((v_result->>'replayed')::boolean,false) is not true then
    raise exception 'start request retry was not recognized';
  end if;

  perform set_config('request.jwt.claim.sub',v_customer::text,true);
  v_result := public.srk_customer_decide_timer_start(v_start_decision,'approved');
  if v_result->>'decision' <> 'approved' then raise exception 'start approval failed: %',v_result; end if;

  perform set_config('request.jwt.claim.sub',v_electrician::text,true);
  v_result := public.srk_electrician_request_timer_stop(v_booking,'stop-key-0001');
  v_stop_decision := (v_result->>'decision_id')::uuid;
  select timer_state into v_state from public.service_bookings where id=v_booking;
  if v_state <> 'stop_pending' then raise exception 'stop request unexpectedly stopped timer'; end if;

  perform set_config('request.jwt.claim.sub',v_customer::text,true);
  v_result := public.srk_customer_decide_timer_stop(v_stop_decision,'approved');
  if v_result->>'decision' <> 'approved' then raise exception 'stop approval failed: %',v_result; end if;
  v_bill := (v_result->>'bill_id')::uuid;

  select timer_state,timer_elapsed_seconds,timer_billable_minutes
  into v_state,v_elapsed,v_minutes
  from public.service_bookings where id=v_booking;
  if v_state <> 'stopped' then raise exception 'timer did not stop'; end if;
  if v_elapsed is null or v_elapsed < 0 then raise exception 'invalid elapsed seconds'; end if;
  if v_minutes <> (case when v_elapsed=0 then 0 else (v_elapsed+59)/60 end) then
    raise exception 'billable minutes do not follow ceiling rule';
  end if;
  if not exists (
    select 1 from public.srk_final_bills
    where id=v_bill and booking_id=v_booking
      and labour_amount=round((112.375::numeric*v_minutes::numeric)/60,10)
  ) then raise exception 'final labour bill missing or incorrectly calculated'; end if;

  -- A repeated stop approval returns the same bill and never inserts another.
  v_result := public.srk_customer_decide_timer_stop(v_stop_decision,'approved');
  if (v_result->>'bill_id')::uuid <> v_bill or coalesce((v_result->>'replayed')::boolean,false) is not true then
    raise exception 'stop approval replay did not return original bill';
  end if;
  select count(*) into v_bill_count from public.srk_final_bills where booking_id=v_booking;
  if v_bill_count <> 1 then raise exception 'duplicate final bills were generated'; end if;

  -- Customer and accepted assigned electrician can read the scoped details.
  v_result := public.srk_get_booking_timer_bill_details(v_booking);
  if v_result->>'booking_id' <> v_booking::text or v_result->'final_bill'->>'id' <> v_bill::text then
    raise exception 'customer scoped bill read failed';
  end if;
  perform set_config('request.jwt.claim.sub',v_electrician::text,true);
  v_result := public.srk_get_booking_timer_bill_details(v_booking);
  if v_result->>'timer_state' <> 'stopped' then raise exception 'electrician scoped timer read failed'; end if;

  -- A different authenticated user must not see the booking's timer or bill.
  perform set_config('request.jwt.claim.sub',v_outsider::text,true);
  begin
    perform public.srk_get_booking_timer_bill_details(v_booking);
    raise exception 'unrelated user unexpectedly read booking details';
  exception when insufficient_privilege then
    null;
  end;
end
$test$;

rollback;
