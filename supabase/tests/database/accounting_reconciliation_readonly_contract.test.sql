begin;
select plan(67);

select ok(to_regclass('public.srk_electrician_payouts') is not null,
  'electrician payout obligation table exists');
select ok(exists(select 1 from pg_constraint where conrelid='public.srk_electrician_payouts'::regclass
  and contype='u' and pg_get_constraintdef(oid) like '%booking_id%'),
  'one payout obligation is allowed per booking');
select ok(exists(select 1 from pg_constraint where conrelid='public.srk_electrician_payouts'::regclass
  and conname='srk_electrician_payouts_payout_status_check'
  and pg_get_constraintdef(oid) like '%pending%' and pg_get_constraintdef(oid) like '%paid%'
  and pg_get_constraintdef(oid) like '%blocked%' and pg_get_constraintdef(oid) like '%refunded%'),
  'payout states include pending, paid, blocked and refunded');
select ok(exists(select 1 from pg_constraint where conrelid='public.srk_electrician_payouts'::regclass
  and conname='srk_payout_paid_fields_check'),
  'paid payout requires method, reference, timestamp and actor');
select ok((select relrowsecurity from pg_class where oid='public.srk_electrician_payouts'::regclass),
  'electrician payout table has RLS enabled');
select ok(not has_table_privilege('anon','public.srk_electrician_payouts','select'),
  'anonymous users cannot read payout records');
select ok(has_table_privilege('authenticated','public.srk_electrician_payouts','select')
  and exists(select 1 from pg_policies where schemaname='public'
    and tablename='srk_electrician_payouts' and policyname='srk_read_authorized_electrician_payouts'),
  'authenticated payout reads are restricted through the authorized-electrician policy');

select ok(position('public.is_srk_admin()' in pg_get_functiondef(
  'public.srk_admin_mark_electrician_payout_paid(uuid,text,text,text)'::regprocedure))>0,
  'payout settlement RPC independently checks Main Admin authorization');
select ok(position('FOR UPDATE' in upper(pg_get_functiondef(
  'public.srk_admin_mark_electrician_payout_paid(uuid,text,text,text)'::regprocedure)))>0,
  'payout settlement serializes against booking and payout changes');
select ok(position('b.payment_verified_at IS NOT NULL' in pg_get_functiondef(
  'public.srk_admin_mark_electrician_payout_paid(uuid,text,text,text)'::regprocedure))>0,
  'payout settlement requires verified customer payment');
select ok(position('b.status = ''completed''' in pg_get_functiondef(
  'public.srk_admin_mark_electrician_payout_paid(uuid,text,text,text)'::regprocedure))>0,
  'payout settlement requires completed booking');
select ok(position('v_row.gross_service_amount' in pg_get_functiondef(
  'public.srk_admin_mark_electrician_payout_paid(uuid,text,text,text)'::regprocedure))>0
  and position('v_row.materials_amount' in pg_get_functiondef(
  'public.srk_admin_mark_electrician_payout_paid(uuid,text,text,text)'::regprocedure))>0
  and position('v_row.platform_commission' in pg_get_functiondef(
  'public.srk_admin_mark_electrician_payout_paid(uuid,text,text,text)'::regprocedure))>0,
  'payout settlement reconciles labour, materials and labour-only commission separately');
select ok(not has_function_privilege('anon',
  'public.srk_admin_mark_electrician_payout_paid(uuid,text,text,text)','execute'),
  'anonymous users cannot execute payout settlement RPC');

select ok((select relrowsecurity from pg_class where oid='public.srk_wallet_ledger'::regclass),
  'wallet ledger has RLS enabled');
select ok(not has_table_privilege('anon','public.srk_wallet_ledger','select'),
  'anonymous users cannot read wallet ledger');
select ok(exists(select 1 from pg_policies where schemaname='public'
  and tablename='srk_wallet_ledger' and policyname='srk_wallet_ledger_owner_read'),
  'wallet ledger read policy is owner-scoped');
select ok(position('status=''posted''' in pg_get_functiondef(
  'public.srk_get_my_wallet_summary()'::regprocedure))>0,
  'wallet balance uses posted entries only');


select ok(to_regclass('public.srk_customer_cancellation_fee_debts') is not null,
  'customer cancellation-fee debt table exists in the complete Feature Branch migration chain');
select ok(to_regclass('public.srk_booking_cancellation_fee_items') is not null,
  'booking cancellation-fee allocation table exists');
select ok(to_regclass('public.srk_cancellation_fee_ledger') is not null,
  'append-only cancellation-fee accounting ledger exists');
select ok((select relrowsecurity from pg_class where oid='public.srk_cancellation_fee_ledger'::regclass)
  and not has_table_privilege('authenticated','public.srk_cancellation_fee_ledger','select'),
  'authenticated clients cannot directly read private cancellation-fee ledger');
select ok((select data_type='bigint' from information_schema.columns
  where table_schema='public' and table_name='srk_cancellation_fee_ledger' and column_name='amount_paise'),
  'cancellation-fee ledger stores integer paise');
select ok(exists(select 1 from pg_trigger where tgrelid='public.srk_cancellation_fee_ledger'::regclass
  and tgname='srk_cancellation_fee_ledger_no_mutation' and not tgisinternal),
  'cancellation-fee ledger has append-only mutation guard');
select ok(position('CANCELLATION_FEE_LEDGER_IS_APPEND_ONLY' in
  pg_get_functiondef('public.srk_guard_cancellation_fee_ledger_immutable()'::regprocedure))>0,
  'cancellation-fee ledger mutation guard rejects update/delete/truncate');
select ok(position('v_service := round(v_bill.labour_amount,2)' in
  pg_get_functiondef('public.srk_create_electrician_payable()'::regprocedure))>0
  and position('v_materials := 0' in
  pg_get_functiondef('public.srk_create_electrician_payable()'::regprocedure))>0,
  'new-category electrician payable uses immutable labour bill and excludes cancellation fees/materials from electrician labour gross');
select ok(position('v_commission := round(v_service * v_rate / 100,2)' in
  pg_get_functiondef('public.srk_create_electrician_payable()'::regprocedure))>0,
  'new-category commission is calculated only on labour');
select ok(position('where public.srk_electrician_payouts.payout_status = ''pending''' in
  pg_get_functiondef('public.srk_create_electrician_payable()'::regprocedure))>0,
  'payout recalculation cannot overwrite a paid, blocked or refunded payout');

select ok(to_regprocedure('public.srk_admin_get_booking_accounting_reconciliation(uuid)') is not null,
  'Main Admin per-booking accounting reconciliation RPC exists');
select ok((select prosecdef from pg_proc where oid='public.srk_admin_get_booking_accounting_reconciliation(uuid)'::regprocedure),
  'accounting reconciliation RPC is SECURITY DEFINER');
select ok((select provolatile='s' from pg_proc where oid='public.srk_admin_get_booking_accounting_reconciliation(uuid)'::regprocedure),
  'accounting reconciliation RPC is declared STABLE');
select ok(coalesce((select proconfig @> ARRAY['search_path=""']::text[] from pg_proc where oid='public.srk_admin_get_booking_accounting_reconciliation(uuid)'::regprocedure),false),
  'SECURITY DEFINER accounting RPC pins an empty search_path');
select ok(not has_function_privilege('anon',
  'public.srk_admin_get_booking_accounting_reconciliation(uuid)','execute'),
  'anonymous users cannot execute accounting reconciliation');
select ok(has_function_privilege('authenticated',
  'public.srk_admin_get_booking_accounting_reconciliation(uuid)','execute'),
  'authenticated role can invoke the RPC but must pass its internal Main Admin gate');
select ok(position('public.is_srk_admin()' in pg_get_functiondef(
  'public.srk_admin_get_booking_accounting_reconciliation(uuid)'::regprocedure))>0,
  'RPC independently enforces Main Admin authorization');
select ok(position('PARTIAL_REFUND_UNSUPPORTED' in pg_get_functiondef(
  'public.srk_admin_get_booking_accounting_reconciliation(uuid)'::regprocedure))>0,
  'partial refunds are explicitly flagged instead of allocated by assumption');
select ok(position('CANCELLATION_FEE_LEDGER_UNBALANCED' in pg_get_functiondef(
  'public.srk_admin_get_booking_accounting_reconciliation(uuid)'::regprocedure))>0,
  'cancellation-fee ledger is compared with settled booking allocations');
select ok(position('insert into' in lower(pg_get_functiondef(
  'public.srk_admin_get_booking_accounting_reconciliation(uuid)'::regprocedure)))=0
  and position('update ' in lower(pg_get_functiondef(
  'public.srk_admin_get_booking_accounting_reconciliation(uuid)'::regprocedure))=0
  and position('delete from' in lower(pg_get_functiondef(
  'public.srk_admin_get_booking_accounting_reconciliation(uuid)'::regprocedure))=0,
  'accounting reconciliation function contains no financial write statements');

select ok(position('COMMISSION_RATE_MISSING_OR_INVALID' in pg_get_functiondef(
  'public.srk_admin_get_booking_accounting_reconciliation(uuid)'::regprocedure))>0
  and position('VERIFIED_COLLECTION_DOES_NOT_MATCH_LABOUR_AND_SETTLED_FEES' in pg_get_functiondef(
  'public.srk_admin_get_booking_accounting_reconciliation(uuid)'::regprocedure))>0,
  'invalid commission rates and collection mismatches fail closed as report exceptions');


select ok(position('VERIFIED_PAYMENT_EVIDENCE_MISSING_OR_MISMATCHED' in pg_get_functiondef(
  'public.srk_admin_get_booking_accounting_reconciliation(uuid)'::regprocedure))>0,
  'paid/refunded bookings require a matching Razorpay or manual payment evidence');
select ok(position('REFUND_PROVIDER_PAYMENT_ID_MISMATCH' in pg_get_functiondef(
  'public.srk_admin_get_booking_accounting_reconciliation(uuid)'::regprocedure))>0
  and position('MANUAL_REFUND_PAYMENT_EVIDENCE_MISMATCH' in pg_get_functiondef(
  'public.srk_admin_get_booking_accounting_reconciliation(uuid)'::regprocedure))>0,
  'refund records must match their original payment evidence');
select ok(position('select i.debt_id::text from public.srk_booking_cancellation_fee_items' in
  pg_get_functiondef('public.srk_admin_get_booking_accounting_reconciliation(uuid)'::regprocedure))>0,
  'wallet reconciliation includes the debt-linked electrician wallet refund reversal');

select ok(position('PAYOUT_ELECTRICIAN_ASSIGNMENT_MISMATCH' in pg_get_functiondef(
  'public.srk_admin_get_booking_accounting_reconciliation(uuid)'::regprocedure))>0
  and position('PAYOUT_EXISTS_BEFORE_BOOKING_COMPLETION' in pg_get_functiondef(
  'public.srk_admin_get_booking_accounting_reconciliation(uuid)'::regprocedure))>0,
  'payout must belong to the currently assigned electrician and a completed booking');

select ok(position('v_fee_captured_paise' in pg_get_functiondef(
  'public.srk_admin_get_booking_accounting_reconciliation(uuid)'::regprocedure))>0
  and position('''reversed''' in pg_get_functiondef(
  'public.srk_admin_get_booking_accounting_reconciliation(uuid)'::regprocedure))>0,
  'historically captured cancellation fees remain reconciled after full-refund reversal');

select ok(position('if v_refund.status=''processed'' then' in pg_get_functiondef(
  'public.srk_admin_get_booking_accounting_reconciliation(uuid)'::regprocedure))>0
  and position('REFUND_FAILED_REQUIRES_REVIEW' in pg_get_functiondef(
  'public.srk_admin_get_booking_accounting_reconciliation(uuid)'::regprocedure))>0,
  'only provider-confirmed processed refunds reduce net customer collection; failed refunds are flagged');
select ok(position('REFUND_REQUEST_PENDING_REVIEW' in pg_get_functiondef(
  'public.srk_admin_get_booking_accounting_reconciliation(uuid)'::regprocedure))>0
  and position('REFUND_REQUEST_PROCESSED_WITHOUT_FINAL_REFUND_EVIDENCE' in pg_get_functiondef(
  'public.srk_admin_get_booking_accounting_reconciliation(uuid)'::regprocedure))>0,
  'refund request workflow states are reconciled against final refund evidence');

select ok(position('CASH_FEE_WALLET_REFUND_MISMATCH' in pg_get_functiondef(
  'public.srk_admin_get_booking_accounting_reconciliation(uuid)'::regprocedure))>0
  and position('provider_reference=v_manual_refund.id::text' in pg_get_functiondef(
  'public.srk_admin_get_booking_accounting_reconciliation(uuid)'::regprocedure))>0,
  'manual full-refund reconciliation compares the exact cash-fee wallet credit to its original debit');


select ok(to_regclass('public.srk_route_transfers') is not null,
  'server-only Razorpay Route transfer ledger exists');
select ok(position('route_transfers' in pg_get_functiondef(
  'public.srk_admin_get_booking_accounting_reconciliation(uuid)'::regprocedure))>0
  and position('route_transfer_count' in pg_get_functiondef(
  'public.srk_admin_get_booking_accounting_reconciliation(uuid)'::regprocedure))>0,
  'read-only accounting report exposes Route transfer rows and count');
select ok(position('ROUTE_TRANSFER_RECIPIENT_ROWS_MISMATCH' in pg_get_functiondef(
  'public.srk_admin_get_booking_accounting_reconciliation(uuid)'::regprocedure))>0,
  'Route reconciliation requires one electrician transfer and a commission transfer only when commission is positive');
select ok(position('ROUTE_TRANSFER_PAYMENT_ID_MISMATCH' in pg_get_functiondef(
  'public.srk_admin_get_booking_accounting_reconciliation(uuid)'::regprocedure))>0,
  'Route transfers must reference the booking Razorpay payment');
select ok(position('ROUTE_TRANSFER_AMOUNT_MISMATCH' in pg_get_functiondef(
  'public.srk_admin_get_booking_accounting_reconciliation(uuid)'::regprocedure))>0,
  'Route electrician and commission transfer amounts are matched to expected payable and commission');
select ok(position('ROUTE_TRANSFER_NOT_SETTLED' in pg_get_functiondef(
  'public.srk_admin_get_booking_accounting_reconciliation(uuid)'::regprocedure))>0
  and position('ROUTE_TRANSFER_FAILED_REVERSED_OR_REVIEW' in pg_get_functiondef(
  'public.srk_admin_get_booking_accounting_reconciliation(uuid)'::regprocedure))>0,
  'pending, failed, reversed and review-required Route states are surfaced as exceptions');
select ok(position('ROUTE_TRANSFER_PROVIDER_ID_MISSING' in pg_get_functiondef(
  'public.srk_admin_get_booking_accounting_reconciliation(uuid)'::regprocedure))>0,
  'created/processed Route transfers require a provider transfer ID');
select ok(position('MANUAL_AND_ROUTE_ELECTRICIAN_PAYOUT_OVERLAP' in pg_get_functiondef(
  'public.srk_admin_get_booking_accounting_reconciliation(uuid)'::regprocedure))>0,
  'manual paid payout and Route electrician transfer overlap is flagged for review');


select ok(position('coalesce(v_commission_paise,0)>0' in pg_get_functiondef(
  'public.srk_admin_get_booking_accounting_reconciliation(uuid)'::regprocedure))>0,
  'zero-commission bookings do not require a zero-value Route commission transfer row');


select ok(position('ROUTE_ELECTRICIAN_RECIPIENT_USER_MISMATCH' in pg_get_functiondef(
  'public.srk_admin_get_booking_accounting_reconciliation(uuid)'::regprocedure))>0,
  'Route electrician recipient Auth user must match the assigned electrician profile');
select ok(position('ROUTE_VERIFIED_PRIMARY_LINKED_ACCOUNT_MISSING_OR_AMBIGUOUS' in pg_get_functiondef(
  'public.srk_admin_get_booking_accounting_reconciliation(uuid)'::regprocedure))>0,
  'Route transfer requires exactly one verified primary electrician linked account');
select ok(position('ROUTE_LINKED_ACCOUNT_ID_MISMATCH' in pg_get_functiondef(
  'public.srk_admin_get_booking_accounting_reconciliation(uuid)'::regprocedure))>0,
  'Route electrician transfer linked account must match the verified primary bank link');
select ok(position('ROUTE_SETTLED_WITHOUT_PROCESSED_TRANSFER' in pg_get_functiondef(
  'public.srk_admin_get_booking_accounting_reconciliation(uuid)'::regprocedure))>0,
  'settled Route records require processed transfer status');

select ok(to_regclass('public.srk_wallet_bank_links_one_primary_route_electrician_uidx') is not null,
  'database enforces at most one primary Razorpay Route electrician bank link per Auth user');

select ok(exists(select 1 from pg_constraint
  where conrelid='public.srk_route_transfers'::regclass and contype='u'
    and pg_get_constraintdef(oid) like '%idempotency_key%'),
  'Route transfer ledger enforces unique idempotency keys');
select ok(exists(select 1 from pg_constraint
  where conrelid='public.srk_route_transfers'::regclass and contype='u'
    and pg_get_constraintdef(oid) like '%razorpay_payment_id%' and pg_get_constraintdef(oid) like '%recipient_type%'),
  'Route transfer ledger prevents duplicate recipient rows for the same Razorpay payment');

select ok((select relrowsecurity from pg_class where oid='public.srk_route_transfers'::regclass),
  'Route transfer ledger has row-level security enabled');
select ok(not has_table_privilege('anon','public.srk_route_transfers','select')
  and not has_table_privilege('authenticated','public.srk_route_transfers','select'),
  'anonymous and authenticated clients cannot read Route transfer ledger');
select ok(has_table_privilege('service_role','public.srk_route_transfers','select')
  and has_table_privilege('service_role','public.srk_route_transfers','insert')
  and has_table_privilege('service_role','public.srk_route_transfers','update'),
  'only server service role has the Route transfer ledger operational grants');

select ok(position('auth.uid() is null or not public.is_srk_admin()' in lower(pg_get_functiondef(
  'public.srk_admin_mark_electrician_payout_paid(uuid,text,text,text)'::regprocedure)))>0,
  'payout settlement independently requires Main Admin authorization');
select ok(position('auth.uid() is null or not public.is_srk_admin()' in lower(pg_get_functiondef(
  'public.srk_admin_record_manual_refund(uuid,text,text)'::regprocedure)))>0,
  'manual refund recording independently requires Main Admin authorization');

select * from finish();
rollback;
