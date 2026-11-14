begin;
select plan(18);

select ok(to_regclass('public.srk_cancellation_fee_ledger') is not null,
  'cancellation fee ledger exists');
select ok(exists(select 1 from information_schema.columns
  where table_schema='public' and table_name='srk_cancellation_fee_ledger'
    and column_name='reversal_of_entry_id'),
  'refund reversal links to its immutable original ledger entry');
select ok(not exists(select 1 from pg_constraint
  where conrelid='public.srk_booking_cancellation_fee_items'::regclass
    and conname='srk_booking_cancellation_fee_items_debt_id_key'),
  'a previously refunded fee debt can be reserved again on a later booking');
select ok(exists(select 1 from pg_indexes
  where schemaname='public' and indexname='srk_cancellation_fee_ledger_one_reversal_per_entry'),
  'each original fee ledger entry can be reversed at most once');
select ok(exists(select 1 from pg_trigger
  where tgrelid='public.service_bookings'::regclass
    and tgname='srk_reverse_cancellation_fees_on_full_refund' and not tgisinternal),
  'booking refund transition automatically reverses fee accounting');
select ok(position('old.payment_status<>'||quote_literal('paid') in
  pg_get_functiondef('public.srk_reverse_cancellation_fees_on_full_refund()'::regprocedure))>0,
  'only a previously paid booking can enter the refund reversal');
select ok(position('VERIFIED_FULL_RAZORPAY_REFUND_RECORD_REQUIRED' in
  pg_get_functiondef('public.srk_reverse_cancellation_fees_on_full_refund()'::regprocedure))>0,
  'online reversal requires a processed full Razorpay refund');
select ok(position('VERIFIED_FULL_MANUAL_REFUND_RECORD_REQUIRED' in
  pg_get_functiondef('public.srk_reverse_cancellation_fees_on_full_refund()'::regprocedure))>0,
  'cash/manual reversal requires a matching full manual refund record');
select ok(position('ORIGINAL_ONLINE_CANCELLATION_FEE_LEDGER_ENTRY_MISSING' in
  pg_get_functiondef('public.srk_reverse_cancellation_fees_on_full_refund()'::regprocedure))>0,
  'online fee reversal fails closed if the original collection is missing');
select ok(position('ORIGINAL_ELECTRICIAN_WALLET_DEBIT_MISSING' in
  pg_get_functiondef('public.srk_reverse_cancellation_fees_on_full_refund()'::regprocedure))>0,
  'cash fee reversal fails closed if the original wallet debit is missing');
select ok(position('cancel-fee:cash:refund-wallet-credit:' in
  pg_get_functiondef('public.srk_reverse_cancellation_fees_on_full_refund()'::regprocedure))>0,
  'cash refund credits back the exact earlier electrician wallet debit');
select ok(position('set status='||quote_literal('open') in
  pg_get_functiondef('public.srk_reverse_cancellation_fees_on_full_refund()'::regprocedure))>0,
  'refunded cancellation fee debt is reopened rather than forgiven');
select ok(position('set status='||quote_literal('reversed') in
  pg_get_functiondef('public.srk_reverse_cancellation_fees_on_full_refund()'::regprocedure))>0,
  'the refunded booking fee item is marked reversed');
select ok(position('reversal_of_entry_id' in
  pg_get_functiondef('public.srk_admin_get_cancellation_fee_ledger_summary()'::regprocedure))>0,
  'Admin totals net off fee collection reversals');
select ok(position('payout_status='||quote_literal('pending') in
  pg_get_functiondef('public.srk_service_reconcile_booking_refund(uuid,text,text,text)'::regprocedure))>0,
  'failed online refund releases the previously placed payout hold');
select ok(position('on conflict(booking_id,debt_id) do nothing' in
  pg_get_functiondef('public.srk_reserve_customer_cancellation_fees_for_booking()'::regprocedure))>0,
  'fee allocation is idempotent per booking and debt, not forever per debt');
select ok(position('v_item.id::text' in
  pg_get_functiondef('public.srk_service_role_record_online_booking_payment(uuid,text,text,bigint)'::regprocedure))>0,
  'online collection idempotency is unique per booking fee item');
select ok(position('v_item.id::text' in
  pg_get_functiondef('public.srk_admin_record_new_booking_cash_payment(uuid,text,text)'::regprocedure))>0,
  'cash collection idempotency is unique per booking fee item');

select * from finish();
rollback;
