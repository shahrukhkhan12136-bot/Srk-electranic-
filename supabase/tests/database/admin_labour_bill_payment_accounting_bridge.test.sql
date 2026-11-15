begin;
select plan(15);

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

select * from finish();
rollback;
