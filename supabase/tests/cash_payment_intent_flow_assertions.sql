-- End-to-end rollback-only test for customer-selected cash and electrician confirmation.
begin;
do $test$
declare
  v_customer uuid := '42000000-0000-4000-8000-000000000001';
  v_electrician uuid := '42000000-0000-4000-8000-000000000002';
  v_outsider uuid := '42000000-0000-4000-8000-000000000005';
  v_profile uuid := '42000000-0000-4000-8000-000000000003';
  v_booking uuid := '42000000-0000-4000-8000-000000000004';
  v_bill uuid := '42000000-0000-4000-8000-000000000006';
  v_snapshot uuid;
  v_intent uuid;
  v_receipt uuid;
  v_result jsonb;
  v_amount bigint;
  v_count bigint;
  v_payment_status text;
  v_method text;
  v_status text;
  v_details jsonb;
  v_token uuid := '42000000-0000-4000-8000-000000000007';
begin
  insert into auth.users(id) values (v_customer),(v_electrician),(v_outsider);
  insert into public.electrician_profiles(id,user_id,active,verification_status)
  values (v_profile,v_electrician,true,'approved');
  insert into public.service_bookings(
    id,customer_user_id,assigned_electrician_id,status,
    service_category_code,service_category_label,hourly_rate_snapshot,timer_state
  ) values (
    v_booking,v_customer,v_profile,'completed','helper','Helper',120,'stopped'
  );
  insert into public.job_offers(booking_id,electrician_id,status)
  values (v_booking,v_profile,'accepted');
  insert into public.srk_final_bills(
    id,booking_id,bill_version,category_code,category_label,hourly_rate,
    started_at,stopped_at,elapsed_seconds,billable_minutes,labour_amount
  ) values (
    v_bill,v_booking,1,'helper','Helper',120,
    now()-interval '60 seconds',now(),60,1,2.0000000000
  );
  update public.service_bookings set final_bill_id=v_bill where id=v_booking;

  perform set_config('request.jwt.claim.sub',v_customer::text,true);
  v_result:=public.srk_customer_create_payable_snapshot(v_booking);
  v_snapshot:=(v_result->>'snapshot_id')::uuid;
  if v_result->>'success'<>'true' then raise exception 'cash test payable snapshot creation failed: %',v_result; end if;
  select amount_paise into v_amount from public.srk_booking_payable_snapshots where id=v_snapshot;
  if v_amount<>200 then raise exception 'cash test snapshot amount should be 200 paise, got %',v_amount; end if;

  perform set_config('request.jwt.claim.sub',v_outsider::text,true);
  begin
    perform public.srk_customer_select_cash_payment(v_snapshot);
    raise exception 'unrelated user unexpectedly selected cash payment';
  exception when insufficient_privilege then null;
  end;

  perform set_config('request.jwt.claim.sub',v_customer::text,true);
  v_result:=public.srk_customer_select_cash_payment(v_snapshot);
  v_intent:=(v_result->>'intent_id')::uuid;
  if v_result->>'success'<>'true' or v_result->>'status'<>'pending' then
    raise exception 'customer cash selection failed: %',v_result;
  end if;
  v_result:=public.srk_customer_select_cash_payment(v_snapshot);
  if v_result->>'replayed'<>'true' or (v_result->>'intent_id')::uuid<>v_intent then
    raise exception 'customer cash selection retry was not idempotent: %',v_result;
  end if;

  begin
    perform public.srk_claim_razorpay_snapshot_order(v_snapshot,v_token);
    raise exception 'Razorpay order unexpectedly created after customer selected cash';
  exception when sqlstate '55000' then null;
  end;
  select count(*) into v_count from public.srk_razorpay_orders where booking_id=v_booking;
  if v_count<>0 then raise exception 'Razorpay order exists despite cash selection'; end if;

  perform set_config('request.jwt.claim.sub',v_outsider::text,true);
  begin
    perform public.srk_electrician_confirm_snapshot_cash_payment(v_snapshot,'unauthorized');
    raise exception 'unassigned user unexpectedly confirmed cash receipt';
  exception when insufficient_privilege then null;
  end;

  perform set_config('request.jwt.claim.sub',v_electrician::text,true);
  v_result:=public.srk_electrician_confirm_snapshot_cash_payment(v_snapshot,'cash receipt test 001');
  v_receipt:=(v_result->>'receipt_id')::uuid;
  if v_result->>'success'<>'true' or v_result->>'status'<>'confirmed' or v_result->>'replayed'<>'false' then
    raise exception 'assigned electrician cash confirmation failed: %',v_result;
  end if;

  v_result:=public.srk_electrician_confirm_snapshot_cash_payment(v_snapshot,'cash receipt test 001');
  if v_result->>'replayed'<>'true' or (v_result->>'receipt_id')::uuid<>v_receipt then
    raise exception 'electrician cash confirmation retry was not idempotent: %',v_result;
  end if;

  select count(*) into v_count from public.srk_cash_receipts
  where id=v_receipt and payable_snapshot_id=v_snapshot and booking_id=v_booking
    and amount_paise=200 and currency='INR' and confirmed_by=v_electrician;
  if v_count<>1 then raise exception 'cash receipt does not match immutable payable snapshot'; end if;

  select payment_status,payment_method,status into v_payment_status,v_method,v_status
  from public.service_bookings where id=v_booking;
  if v_payment_status<>'paid' or v_method<>'Cash' or v_status<>'completed' then
    raise exception 'booking not marked Paid/Completed after electrician receipt: %, %, %',v_payment_status,v_method,v_status;
  end if;

  perform set_config('request.jwt.claim.sub',v_customer::text,true);
  v_result:=public.srk_customer_select_cash_payment(v_snapshot);
  if v_result->>'status'<>'confirmed' or v_result->>'replayed'<>'true' then
    raise exception 'customer cash selection replay after receipt confirmation failed: %',v_result;
  end if;

  v_details:=public.srk_get_booking_timer_bill_details(v_booking);
  if v_details->'cash_payment_intent'->>'status'<>'confirmed'
     or v_details->'cash_payment_intent'->>'receipt_id'<>v_receipt::text then
    raise exception 'scoped booking details do not expose confirmed cash receipt: %',v_details->'cash_payment_intent';
  end if;

  select count(*) into v_count from public.srk_cash_payment_intents
  where id=v_intent and status='confirmed' and receipt_id=v_receipt;
  if v_count<>1 then raise exception 'cash intent confirmation ledger is inconsistent'; end if;
end
$test$;
rollback;
