begin;
select plan(34);

select ok(to_regclass('public.srk_cancellation_fee_ledger') is not null,
  'cancellation fee ledger exists');

select ok(exists(select 1 from information_schema.columns
  where table_schema='public' and table_name='srk_booking_cancellation_fee_items'
    and column_name='source_booking_id')
  and position('source_booking_id' in
    pg_get_functiondef('public.srk_reserve_customer_cancellation_fees_for_booking()'::regprocedure))>0,
  'fee allocations retain the original cancellation booking for receipts and refunds');
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

select ok(position('v_booking.selected_category is not null' in
  pg_get_functiondef('public.srk_admin_prepare_razorpay_refund(uuid,text)'::regprocedure))>0
  and position('srk_booking_labour_bills' in
  pg_get_functiondef('public.srk_admin_prepare_razorpay_refund(uuid,text)'::regprocedure))>0,
  'Razorpay refund preparation supports server-timed labour bills without legacy quote approval');
select ok(position('PAID_AMOUNT_DOES_NOT_MATCH_IMMUTABLE_LABOUR_AND_FEE_LEDGER' in
  pg_get_functiondef('public.srk_admin_prepare_razorpay_refund(uuid,text)'::regprocedure))>0,
  'new booking refund amount reconciles to immutable labour plus settled fee items');
select ok(position('payout_status='||quote_literal('blocked') in
  pg_get_functiondef('public.srk_admin_record_manual_refund(uuid,text,text)'::regprocedure))>0,
  'manual refund blocks an unpaid electrician payout before refund completion');
select ok(position('ELECTRICIAN_PAYOUT_ALREADY_PAID_RECOVERY_REQUIRED' in
  pg_get_functiondef('public.srk_admin_record_manual_refund(uuid,text,text)'::regprocedure))>0,
  'manual refund fails closed when electrician payout is already paid');
select ok(position('p_provider_status is null' in
  pg_get_functiondef('public.srk_service_reconcile_booking_refund(uuid,text,text,text)'::regprocedure))>0
  and position('p_provider_status='||quote_literal('processed') in
  pg_get_functiondef('public.srk_service_reconcile_booking_refund(uuid,text,text,text)'::regprocedure))>0,
  'provider reconciliation rejects missing status and requires provider refund ID on success');

select ok(position('CANCELLATION_FEE_ITEMS_NOT_SETTLED_BEFORE_REFUND' in
  pg_get_functiondef('public.srk_reverse_cancellation_fees_on_full_refund()'::regprocedure))>0,
  'refund fails closed instead of leaving reserved/unsettled cancellation debt stuck');


select ok(
  position('perform 1 from public.service_bookings' in lower(
    pg_get_functiondef('public.srk_service_reconcile_booking_refund(uuid,text,text,text)'::regprocedure)))>0
  and position('perform 1 from public.service_bookings' in lower(
    pg_get_functiondef('public.srk_service_reconcile_booking_refund(uuid,text,text,text)'::regprocedure)))
    < position('select * into v_refund from public.srk_razorpay_refunds' in lower(
    pg_get_functiondef('public.srk_service_reconcile_booking_refund(uuid,text,text,text)'::regprocedure)))
  and position('for update' in substring(lower(
    pg_get_functiondef('public.srk_service_reconcile_booking_refund(uuid,text,text,text)'::regprocedure))
    from position('select * into v_refund from public.srk_razorpay_refunds' in lower(
    pg_get_functiondef('public.srk_service_reconcile_booking_refund(uuid,text,text,text)'::regprocedure))))>0,
  'refund reconciliation locks booking before refund row to match preparation and payout lock order');


select ok(position('v_refund.status in ('||quote_literal('processed')||','||quote_literal('failed')||')' in
  pg_get_functiondef('public.srk_service_reconcile_booking_refund(uuid,text,text,text)'::regprocedure))>0,
  'processed and failed provider refund states are terminal against late out-of-order events');
select ok(position('PROVIDER_REFUND_ID_MISMATCH' in
  pg_get_functiondef('public.srk_service_reconcile_booking_refund(uuid,text,text,text)'::regprocedure))>0
  and position('v_refund.refund_id is distinct from p_provider_refund_id' in
  pg_get_functiondef('public.srk_service_reconcile_booking_refund(uuid,text,text,text)'::regprocedure))>0,
  'a provider event cannot replace a refund ID already bound to the booking refund record');

select ok(
  position('payout_status = '||quote_literal('blocked') in
    pg_get_functiondef('public.srk_create_electrician_payable()'::regprocedure))>0
  and position('Razorpay refund pending' in
    pg_get_functiondef('public.srk_create_electrician_payable()'::regprocedure))>0
  and position('Manual refund processed' in
    pg_get_functiondef('public.srk_create_electrician_payable()'::regprocedure))>0
  and position('payout_status = '||quote_literal('refunded') in
    pg_get_functiondef('public.srk_create_electrician_payable()'::regprocedure))>0,
  'full refunds close only refund-owned payout holds and preserve unrelated Admin blocks');
 
select ok(position('auth.jwt()->>'||quote_literal('role') in
  pg_get_functiondef('public.srk_service_role_get_booking_payment_breakdown(uuid)'::regprocedure))>0,
  'online refund breakdown validates service role from the signed JWT claim');
select ok(position('auth.jwt()->>'||quote_literal('role') in
  pg_get_functiondef('public.srk_service_role_record_online_booking_payment(uuid,text,text,bigint)'::regprocedure))>0,
  'online payment reconciliation validates service role from the signed JWT claim');
select ok(position('auth.jwt()->>'||quote_literal('role') in
  pg_get_functiondef('public.srk_service_reconcile_booking_refund(uuid,text,text,text)'::regprocedure))>0,
  'refund reconciliation validates service role from the signed JWT claim');

select ok(
  position('select r.booking_id into v_booking_id' in lower(
    pg_get_functiondef('public.srk_admin_decide_booking_cancellation(uuid,text,text,text,text)'::regprocedure)))>0
  and position('perform 1 from public.service_bookings' in lower(
    pg_get_functiondef('public.srk_admin_decide_booking_cancellation(uuid,text,text,text,text)'::regprocedure)))
    < position('select * into v_request from public.srk_booking_cancellation_requests r' in lower(
    pg_get_functiondef('public.srk_admin_decide_booking_cancellation(uuid,text,text,text,text)'::regprocedure)))
  and position('for update' in substring(lower(
    pg_get_functiondef('public.srk_admin_decide_booking_cancellation(uuid,text,text,text,text)'::regprocedure))
    from position('select * into v_request from public.srk_booking_cancellation_requests r' in lower(
    pg_get_functiondef('public.srk_admin_decide_booking_cancellation(uuid,text,text,text,text)'::regprocedure))))>0,
  'Admin cancellation decision locks Booking before Request and then locks the Request row');

select ok(position('BOOKING_ALREADY_REFUNDED' in
  pg_get_functiondef('public.srk_service_role_record_online_booking_payment(uuid,text,text,bigint)'::regprocedure))>0,
  'online payment reconciliation refuses to resurrect a refunded booking');

select * from finish();
rollback;
