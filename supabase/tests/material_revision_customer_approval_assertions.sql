-- Material proposal and customer decision assertions.
-- Disposable PostgreSQL harness only; all fixtures are rolled back.
begin;
do $test$
declare
  v_customer uuid := '41000000-0000-4000-8000-000000000001';
  v_electrician uuid := '41000000-0000-4000-8000-000000000002';
  v_outsider uuid := '41000000-0000-4000-8000-000000000005';
  v_profile uuid := '41000000-0000-4000-8000-000000000003';
  v_booking uuid := '41000000-0000-4000-8000-000000000004';
  v_bill uuid := '41000000-0000-4000-8000-000000000006';
  v_result jsonb;
  v_revision uuid;
  v_total numeric;
  v_count bigint;
  v_status text;
  v_snapshot_id uuid;
  v_labour_snapshot numeric(20,10);
  v_materials_snapshot numeric(12,2);
  v_amount numeric(12,2);
  v_paise bigint;
  v_token uuid := '41000000-0000-4000-8000-000000000007';
  v_order_result jsonb;
  v_payment_result jsonb;
  v_ledger_count bigint;
begin
  insert into auth.users(id) values (v_customer),(v_electrician),(v_outsider);
  insert into public.electrician_profiles(id,user_id,active,verification_status)
  values (v_profile,v_electrician,true,'approved');
  insert into public.service_bookings(
    id,customer_user_id,assigned_electrician_id,status,
    service_category_code,service_category_label,hourly_rate_snapshot,timer_state
  ) values (
    v_booking,v_customer,v_profile,'completed','helper','Helper',112.375,'stopped'
  );
  update public.service_bookings set assigned_electrician_id=v_profile,status='completed',timer_state='stopped'
  where id=v_booking;
  insert into public.job_offers(booking_id,electrician_id,status)
  values (v_booking,v_profile,'accepted');
  insert into public.srk_final_bills(
    id,booking_id,bill_version,category_code,category_label,hourly_rate,
    started_at,stopped_at,elapsed_seconds,billable_minutes,labour_amount
  ) values (
    v_bill,v_booking,1,'helper','Helper',112.375,
    now()-interval '60 seconds',now(),60,1,round(112.375::numeric/60,10)
  );
  update public.service_bookings set final_bill_id=v_bill where id=v_booking;

  perform set_config('request.jwt.claim.sub',v_electrician::text,true);
  v_result := public.srk_electrician_submit_material_revision(
    v_booking,
    '[{"description":"Switch","quantity":2,"unit_price":50,"supplied_by":"electrician","receipt_reference":"invoice-001"},{"description":"Customer wire","quantity":1,"unit_price":0,"supplied_by":"customer"}]'::jsonb,
    'material-key-0001'
  );
  v_revision := (v_result->>'revision_id')::uuid;
  if v_result->>'success' <> 'true' or (v_result->>'electrician_material_total')::numeric <> 100 then
    raise exception 'material proposal did not total only electrician supplied items: %',v_result;
  end if;

  v_result := public.srk_electrician_submit_material_revision(
    v_booking,
    '[{"description":"Switch","quantity":2,"unit_price":50,"supplied_by":"electrician","receipt_reference":"invoice-001"},{"description":"Customer wire","quantity":1,"unit_price":0,"supplied_by":"customer"}]'::jsonb,
    'material-key-0001'
  );
  if (v_result->>'revision_id')::uuid <> v_revision or v_result->>'replayed' <> 'true' then
    raise exception 'material proposal retry did not return the original revision';
  end if;

  select count(*) into v_count from public.srk_bill_material_items where revision_id=v_revision;
  if v_count <> 2 then raise exception 'material proposal duplicate items detected'; end if;
  select sum(line_total) into v_total from public.srk_bill_material_items where revision_id=v_revision;
  if v_total <> 100 then raise exception 'customer supplied material was charged: %',v_total; end if;

  perform set_config('request.jwt.claim.sub',v_outsider::text,true);
  begin
    perform public.srk_customer_decide_material_revision(v_revision,'approved');
    raise exception 'unrelated user unexpectedly decided material proposal';
  exception when insufficient_privilege then null;
  end;

  perform set_config('request.jwt.claim.sub',v_customer::text,true);
  v_result := public.srk_customer_decide_material_revision(v_revision,'approved');
  if v_result->>'decision' <> 'approved' then raise exception 'customer material approval failed: %',v_result; end if;
  v_result := public.srk_customer_decide_material_revision(v_revision,'approved');
  if v_result->>'replayed' <> 'true' then raise exception 'material decision replay was not idempotent'; end if;

  perform set_config('request.jwt.claim.sub',v_electrician::text,true);
  begin
    perform public.srk_electrician_submit_material_revision(
      v_booking,
      '[{"description":"No receipt","quantity":1,"unit_price":10,"supplied_by":"electrician"}]'::jsonb,
      'material-key-no-receipt'
    );
    raise exception 'electrician material without receipt reference unexpectedly accepted';
  exception when invalid_parameter_value then null;
  end;

  select count(*) into v_count from public.srk_bill_material_approvals where revision_id=v_revision and decision='approved';
  if v_count <> 1 then raise exception 'customer material approval ledger is not unique'; end if;
  select status into v_status from public.srk_bill_material_revisions where id=v_revision;
  if v_status <> 'approved' then raise exception 'material revision status not approved'; end if;

  perform set_config('request.jwt.claim.sub',v_customer::text,true);
  v_result := public.srk_customer_create_payable_snapshot(v_booking);
  v_snapshot_id := (v_result->>'snapshot_id')::uuid;
  if v_result->>'success' <> 'true' or v_result->>'replayed' <> 'false' then
    raise exception 'customer payable snapshot creation failed: %',v_result;
  end if;
  select labour_amount,materials_amount,total_amount,amount_paise
    into v_labour_snapshot,v_materials_snapshot,v_amount,v_paise
  from public.srk_booking_payable_snapshots where id=v_snapshot_id;
  if v_labour_snapshot <> round(112.375::numeric/60,10) then
    raise exception 'snapshot rounded labour before final payable boundary: %',v_labour_snapshot;
  end if;
  if v_materials_snapshot <> 100 or v_amount <> 101.87 or v_paise <> 10187 then
    raise exception 'snapshot payable total mismatch: labour %, materials %, total %, paise %',
      v_labour_snapshot,v_materials_snapshot,v_amount,v_paise;
  end if;

  v_result := public.srk_customer_create_payable_snapshot(v_booking);
  if (v_result->>'snapshot_id')::uuid <> v_snapshot_id or v_result->>'replayed' <> 'true' then
    raise exception 'snapshot retry did not return immutable existing snapshot';
  end if;

  v_order_result := public.srk_claim_razorpay_snapshot_order(v_snapshot_id,v_token);
  if v_order_result->>'success'<>'true' or v_order_result->>'claimed'<>'true'
     or (v_order_result->>'amount_paise')::bigint<>10187 then
    raise exception 'snapshot Razorpay order claim failed: %',v_order_result;
  end if;

  v_order_result := public.srk_bind_razorpay_snapshot_order(
    v_snapshot_id,v_token,'order_test001',10187,'INR'
  );
  if v_order_result->>'success'<>'true' or v_order_result->>'replayed'<>'false' then
    raise exception 'snapshot Razorpay order binding failed: %',v_order_result;
  end if;

  v_order_result := public.srk_claim_razorpay_snapshot_order(
    v_snapshot_id,'41000000-0000-4000-8000-000000000008'
  );
  if v_order_result->>'claimed'<>'false' or v_order_result->>'provider_order_id'<>'order_test001' then
    raise exception 'existing provider order was not reused: %',v_order_result;
  end if;

  v_payment_result := public.srk_reconcile_razorpay_snapshot_payment(
    'order_test001','pay_test001',10187,'INR','checkout'
  );
  if v_payment_result->>'success'<>'true' or v_payment_result->>'replayed'<>'false' then
    raise exception 'snapshot payment reconciliation failed: %',v_payment_result;
  end if;
  v_payment_result := public.srk_reconcile_razorpay_snapshot_payment(
    'order_test001','pay_test001',10187,'INR','webhook'
  );
  if v_payment_result->>'success'<>'true' or v_payment_result->>'replayed'<>'true' then
    raise exception 'duplicate captured payment was not idempotent: %',v_payment_result;
  end if;

  select count(*) into v_ledger_count from public.srk_razorpay_payments
  where provider_order_id='order_test001' and provider_payment_id='pay_test001'
    and snapshot_id=v_snapshot_id and amount_paise=10187;
  if v_ledger_count<>1 then raise exception 'Razorpay payment ledger is not unique'; end if;

  select count(*) into v_ledger_count from public.service_bookings
  where id=v_booking and payment_status='paid' and amount_paid=101.87
    and razorpay_order_id='order_test001' and razorpay_payment_id='pay_test001';
  if v_ledger_count<>1 then raise exception 'booking payment status was not reconciled'; end if;

  begin
    perform public.srk_reconcile_razorpay_snapshot_payment(
      'order_test001','pay_test002',10187,'INR','webhook'
    );
    raise exception 'second payment ID unexpectedly accepted for one order';
  exception when sqlstate '55000' then null;
  end;

  perform set_config('request.jwt.claim.sub',v_electrician::text,true);
  begin
    perform public.srk_electrician_submit_material_revision(
      v_booking,
      '[{"description":"Late material","quantity":1,"unit_price":10,"supplied_by":"electrician","receipt_reference":"invoice-late"}]'::jsonb,
      'material-key-after-snapshot'
    );
    raise exception 'material revision unexpectedly accepted after payable snapshot';
  exception when sqlstate '55000' then null;
  end;
end
$test$;
rollback;
