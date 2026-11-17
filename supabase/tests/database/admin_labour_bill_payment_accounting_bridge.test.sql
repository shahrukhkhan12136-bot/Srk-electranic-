begin;
select plan(23);

select has_function('public','srk_admin_record_new_booking_cash_payment',
  array['uuid','text','text'],
  'new-category Admin Cash settlement RPC exists');

select ok(position('public.is_srk_admin()' in lower(pg_get_functiondef(
  'public.srk_admin_record_new_booking_cash_payment(uuid,text,text)'::regprocedure)))>0,
  'new-category Cash settlement independently requires Main Admin');

select ok(position('for update' in lower(pg_get_functiondef(
  'public.srk_admin_record_new_booking_cash_payment(uuid,text,text)'::regprocedure)))>0,
  'new-category Cash settlement locks the booking before recording payment');

select ok(position('not like ''%cash%''' in lower(pg_get_functiondef(
  'public.srk_admin_record_new_booking_cash_payment(uuid,text,text)'::regprocedure)))>0,
  'new-category manual settlement accepts Cash only');

select ok(position('immutable_labour_bill_required' in lower(pg_get_functiondef(
  'public.srk_admin_record_new_booking_cash_payment(uuid,text,text)'::regprocedure)))>0,
  'new-category Cash settlement requires the immutable final labour bill');

select ok(position('v_total:=v_labour.labour_amount_paise+v_fee' in lower(pg_get_functiondef(
  'public.srk_admin_record_new_booking_cash_payment(uuid,text,text)'::regprocedure)))>0,
  'new-category Cash amount is labour plus separately reserved cancellation fees');

select ok(position('insert into public.srk_manual_payment_entries' in lower(pg_get_functiondef(
  'public.srk_admin_record_new_booking_cash_payment(uuid,text,text)'::regprocedure)))>0
  and position('payment_verified_at=now()' in lower(pg_get_functiondef(
  'public.srk_admin_record_new_booking_cash_payment(uuid,text,text)'::regprocedure)))>0,
  'Cash receipt evidence and server payment-verification timestamp are recorded');

select ok(position('cancel-fee:cash:electrician-debit:' in lower(pg_get_functiondef(
  'public.srk_admin_record_new_booking_cash_payment(uuid,text,text)'::regprocedure)))>0
  and position('cancel-fee:cash:srk-credit:' in lower(pg_get_functiondef(
  'public.srk_admin_record_new_booking_cash_payment(uuid,text,text)'::regprocedure)))>0,
  'cash cancellation-fee wallet debit and SRK ledger credit use stable idempotency keys');

select ok(position('srk_booking_labour_bills' in lower(pg_get_functiondef(
  'public.srk_admin_get_booking_accounting_reconciliation(uuid)'::regprocedure)))>0
  and position('v_materials_paise := 0' in lower(pg_get_functiondef(
  'public.srk_admin_get_booking_accounting_reconciliation(uuid)'::regprocedure)))>0,
  'new-category accounting reads immutable labour bill and excludes materials from electrician labour');

select ok(position('v_collection_paise is distinct from (v_labour_paise+v_fee_captured_paise)' in lower(
  pg_get_functiondef('public.srk_admin_get_booking_accounting_reconciliation(uuid)'::regprocedure)))>0,
  'new-category accounting reconciles verified collection to labour plus settled cancellation fees');

select ok(position('customer_user_id=v_uid' in lower(pg_get_functiondef(
  'public.srk_customer_get_payment_receipt(uuid)'::regprocedure)))>0
  and position('srk_booking_labour_bills' in lower(pg_get_functiondef(
  'public.srk_customer_get_payment_receipt(uuid)'::regprocedure)))>0,
  'customer receipt remains owner-scoped and reads immutable labour bill');

select ok(position('i.status=''settled''' in lower(pg_get_functiondef(
  'public.srk_customer_get_payment_receipt(uuid)'::regprocedure)))>0
  and position('v_total_paise:=v_bill.labour_amount_paise+v_fee_paise' in lower(
  pg_get_functiondef('public.srk_customer_get_payment_receipt(uuid)'::regprocedure)))>0,
  'new-category receipt includes only settled cancellation fees in its reconciled total');

select ok(position('''materials_amount'',0' in lower(pg_get_functiondef(
  'public.srk_customer_get_payment_receipt(uuid)'::regprocedure)))>0,
  'new-category customer receipt explicitly reports zero materials in labour-only flow');

select ok(position('selected_category is not null' in lower(pg_get_functiondef(
  'public.srk_admin_record_manual_payment(uuid,text,text,text)'::regprocedure)))>0
  and position('quote_status is distinct from ''approved''' in lower(pg_get_functiondef(
  'public.srk_admin_record_manual_payment(uuid,text,text,text)'::regprocedure)))>0,
  'legacy manual settlement remains quote-scoped and rejects new-category bookings');

select ok(position('materials_amount' in lower(pg_get_functiondef(
  'public.srk_customer_get_payment_receipt(uuid)'::regprocedure)))>0
  and position('quoted_amount' in lower(pg_get_functiondef(
  'public.srk_customer_get_payment_receipt(uuid)'::regprocedure)))>0,
  'legacy receipt retains separate materials and approved-quote reconciliation for historical records');

select ok(position('lower(btrim(mp.payment_method)) = lower(btrim(v_booking.payment_method))' in lower(
  pg_get_functiondef('public.srk_admin_get_booking_accounting_reconciliation(uuid)'::regprocedure)))>0
  and position('manual_payment_method_mismatch' in lower(
  pg_get_functiondef('public.srk_admin_get_booking_accounting_reconciliation(uuid)'::regprocedure)))>0,
  'manual payment evidence requires a normalized non-null payment-method match and reports mismatches');

select ok(position('p.electrician_payable' in lower(pg_get_functiondef(
  'public.srk_admin_commission_report()'::regprocedure)))>0
  and position('p.platform_commission' in lower(pg_get_functiondef(
  'public.srk_admin_commission_report()'::regprocedure)))>0
  and position('p.gross_service_amount' in lower(pg_get_functiondef(
  'public.srk_admin_commission_report()'::regprocedure)))>0,
  'Admin commission report uses payout ledger values rather than treating cancellation-fee collection as electrician earnings');

select ok(position('p.electrician_payable' in lower(pg_get_functiondef(
  'public.srk_get_my_earnings()'::regprocedure)))>0
  and position('p.platform_commission' in lower(pg_get_functiondef(
  'public.srk_get_my_earnings()'::regprocedure)))>0
  and position('coalesce(b.amount_paid,0)' in lower(pg_get_functiondef(
  'public.srk_get_my_earnings()'::regprocedure)))>0,
  'Electrician earnings separates customer collection from authoritative payout payable');

select ok(position('booking_commission_payout_ledger_mismatch' in lower(pg_get_functiondef(
  'public.srk_admin_get_booking_accounting_reconciliation(uuid)'::regprocedure)))>0
  and position('v_payout.platform_commission' in lower(pg_get_functiondef(
  'public.srk_admin_get_booking_accounting_reconciliation(uuid)'::regprocedure)))>0,
  'Admin financial reconciliation flags booking-to-payout commission ledger divergence');


select ok(position('v_booking.razorpay_order_id<>p_order_id' in lower(pg_get_functiondef(
  'public.srk_service_role_record_online_booking_payment(uuid,text,text,bigint)'::regprocedure)))>0
  and position('v_booking.razorpay_order_id<>p_order_id' in lower(pg_get_functiondef(
  'public.srk_service_role_record_online_booking_payment(uuid,text,text,bigint)'::regprocedure)))<
  position('if v_booking.payment_status=''paid''' in lower(pg_get_functiondef(
  'public.srk_service_role_record_online_booking_payment(uuid,text,text,bigint)'::regprocedure))),
  'online settlement validates the original Razorpay order before idempotent retry handling');

select ok(position('round(v_booking.amount_paid*100)::bigint<>p_amount_paise' in lower(pg_get_functiondef(
  'public.srk_service_role_record_online_booking_payment(uuid,text,text,bigint)'::regprocedure)))>0,
  'same-payment retry must match the durable original captured amount');

select ok(position('if v_booking.payment_status=''paid''' in lower(pg_get_functiondef(
  'public.srk_service_role_record_online_booking_payment(uuid,text,text,bigint)'::regprocedure)))<
  position('where booking_id=p_booking_id and status=''reserved''' in lower(pg_get_functiondef(
  'public.srk_service_role_record_online_booking_payment(uuid,text,text,bigint)'::regprocedure))),
  'idempotent paid retry is handled before summing fee rows already transitioned from reserved');

select ok(position('RETRY_CAPTURED_AMOUNT_DOES_NOT_MATCH_ORIGINAL_COLLECTION' in pg_get_functiondef(
  'public.srk_service_role_record_online_booking_payment(uuid,text,text,bigint)'::regprocedure))>0,
  'same payment ID with a changed captured amount is rejected');

select * from finish();
rollback;
