begin;
select plan(24);

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

select ok(position('route_ledger_retired_no_route_transfers' in lower(pg_get_functiondef(
  'public.srk_admin_get_booking_accounting_reconciliation(uuid)'::regprocedure)))>0
  and position('srk_route_transfers' in lower(pg_get_functiondef(
  'public.srk_admin_get_booking_accounting_reconciliation(uuid)'::regprocedure)))=0
  and position('route_provider_settlement_verified' in lower(pg_get_functiondef(
  'public.srk_admin_get_booking_accounting_reconciliation(uuid)'::regprocedure)))>0,
  'Route ledger remains retired; Admin reconciliation reports explicit retired status without querying Route transfers');

select ok(
  (select proconfig @> ARRAY['search_path=""']::text[] from pg_proc where oid='public.srk_set_booking_commission_before_payout()'::regprocedure)
  and (select proconfig @> ARRAY['search_path=""']::text[] from pg_proc where oid='public.srk_validate_booking_commission_payout_parity()'::regprocedure)
  and (select proconfig @> ARRAY['search_path=""']::text[] from pg_proc where oid='public.srk_admin_commission_report()'::regprocedure)
  and (select proconfig @> ARRAY['search_path=""']::text[] from pg_proc where oid='public.srk_get_my_earnings()'::regprocedure),
  'all SECURITY DEFINER accounting bridge functions pin an empty search_path');


select ok(position('new.commission_amount := null' in lower(pg_get_functiondef(
  'public.srk_set_booking_commission_before_payout()'::regprocedure)))>0,
  'commission amount is cleared when booking leaves verified completed-paid state');

select ok(exists(
  select 1
    from pg_trigger bridge_before
   where bridge_before.tgrelid='public.service_bookings'::regclass
     and bridge_before.tgname='zz_srk_set_booking_commission_before_payout'
     and bridge_before.tgfoid='public.srk_set_booking_commission_before_payout()'::regprocedure
     and pg_get_triggerdef(bridge_before.oid,true) ilike 'CREATE TRIGGER% BEFORE %'
  ),
  'commission BEFORE trigger is explicitly attached by the timestamped accounting bridge migration');

select ok(exists(
  select 1
    from pg_trigger payout_after
    join pg_trigger parity_after
      on parity_after.tgrelid=payout_after.tgrelid
   where payout_after.tgrelid='public.service_bookings'::regclass
     and payout_after.tgname='trg_srk_create_electrician_payable'
     and payout_after.tgfoid='public.srk_create_electrician_payable()'::regprocedure
     and parity_after.tgname='zz_srk_validate_booking_commission_payout_parity'
     and pg_get_triggerdef(payout_after.oid,true) ilike 'CREATE TRIGGER% AFTER %'
     and pg_get_triggerdef(parity_after.oid,true) ilike 'CREATE TRIGGER% AFTER %'
     and payout_after.tgname < parity_after.tgname
  ),
  'payout ledger AFTER trigger runs before the commission-to-payout parity validation trigger');

select * from finish();
rollback;
