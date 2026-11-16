begin;
select plan(32);

select ok(to_regprocedure('public.srk_create_electrician_payable()') is not null,
  'electrician payable trigger function exists');
select ok(exists(select 1 from pg_trigger t
  where t.tgrelid='public.service_bookings'::regclass
    and not t.tgisinternal
    and t.tgfoid='public.srk_create_electrician_payable()'::regprocedure),
  'electrician payable function is actually attached to service_bookings');
select ok(exists(select 1 from pg_trigger t
  where t.tgrelid='public.service_bookings'::regclass
    and not t.tgisinternal
    and t.tgfoid='public.srk_create_electrician_payable()'::regprocedure
    and (t.tgtype & 4)=4
    and (t.tgtype & 16)=16
    and (t.tgtype & 1)=1
    and (t.tgtype & 2)=0),
  'payout trigger is a row-level AFTER INSERT/UPDATE hook so booking state and verified payment evidence are committed first');

select ok((select prosecdef from pg_proc where oid='public.srk_create_electrician_payable()'::regprocedure),
  'payable trigger uses a privileged server-side execution context');
select ok((select coalesce(proconfig::text,'') like '%search_path=pg_catalog, public, pg_temp%'
  from pg_proc where oid='public.srk_create_electrician_payable()'::regprocedure),
  'payable trigger pins a safe search path');
select ok(not has_function_privilege('anon','public.srk_create_electrician_payable()','EXECUTE')
  and not has_function_privilege('authenticated','public.srk_create_electrician_payable()','EXECUTE'),
  'clients cannot invoke the trigger function directly');

select ok(to_regprocedure('public.srk_admin_mark_electrician_payout_paid(uuid,text,text,text)') is not null,
  'Main Admin payout settlement RPC exists');
select ok((select prosecdef from pg_proc where oid='public.srk_admin_mark_electrician_payout_paid(uuid,text,text,text)'::regprocedure),
  'payout settlement RPC uses a privileged execution context');
select ok(position('auth.uid() is null' in
  pg_get_functiondef('public.srk_admin_mark_electrician_payout_paid(uuid,text,text,text)'::regprocedure))>0
  and position('public.is_srk_admin()' in
  pg_get_functiondef('public.srk_admin_mark_electrician_payout_paid(uuid,text,text,text)'::regprocedure))>0,
  'payout settlement requires an authenticated Main Admin');
select ok(not has_function_privilege('anon','public.srk_admin_mark_electrician_payout_paid(uuid,text,text,text)','EXECUTE')
  and has_function_privilege('authenticated','public.srk_admin_mark_electrician_payout_paid(uuid,text,text,text)','EXECUTE'),
  'only authenticated sessions can reach the Main Admin guarded payout RPC');
select ok(position('p_method not in ('||quote_literal('upi')||','||quote_literal('bank')||')' in
  pg_get_functiondef('public.srk_admin_mark_electrician_payout_paid(uuid,text,text,text)'::regprocedure))>0,
  'payout method is restricted to UPI or bank transfer');
select ok(position('length(btrim(p_reference)) < 4' in
  pg_get_functiondef('public.srk_admin_mark_electrician_payout_paid(uuid,text,text,text)'::regprocedure))>0
  and position('length(btrim(p_reference)) > 120' in
  pg_get_functiondef('public.srk_admin_mark_electrician_payout_paid(uuid,text,text,text)'::regprocedure))>0,
  'payout settlement requires a bounded UTR or UPI reference');

select ok(position('select * into v_booking' in
  pg_get_functiondef('public.srk_admin_mark_electrician_payout_paid(uuid,text,text,text)'::regprocedure))
  < position('select * into v_row' in
  pg_get_functiondef('public.srk_admin_mark_electrician_payout_paid(uuid,text,text,text)'::regprocedure))
  and position('for update' in
  pg_get_functiondef('public.srk_admin_mark_electrician_payout_paid(uuid,text,text,text)'::regprocedure))>0,
  'settlement locks the booking before locking and mutating its payout row');
select ok(position('v_row.payout_status <> '||quote_literal('pending') in
  pg_get_functiondef('public.srk_admin_mark_electrician_payout_paid(uuid,text,text,text)'::regprocedure))>0,
  'only a pending payout can be marked paid');
select ok(position('v_booking.status <> '||quote_literal('completed') in
  pg_get_functiondef('public.srk_admin_mark_electrician_payout_paid(uuid,text,text,text)'::regprocedure))>0
  and position('v_booking.payment_status <> '||quote_literal('paid') in
  pg_get_functiondef('public.srk_admin_mark_electrician_payout_paid(uuid,text,text,text)'::regprocedure))>0
  and position('v_booking.payment_verified_at is null' in
  pg_get_functiondef('public.srk_admin_mark_electrician_payout_paid(uuid,text,text,text)'::regprocedure))>0,
  'payout requires completed booking and verified paid status');
select ok(position('public.srk_booking_labour_bills' in
  pg_get_functiondef('public.srk_admin_mark_electrician_payout_paid(uuid,text,text,text)'::regprocedure))>0
  and position('IMMUTABLE_LABOUR_BILL_REQUIRED' in
  pg_get_functiondef('public.srk_admin_mark_electrician_payout_paid(uuid,text,text,text)'::regprocedure))>0,
  'new-category payout requires the immutable labour bill');
select ok(position('v_bill.electrician_profile_id is distinct from v_row.electrician_profile_id' in
  pg_get_functiondef('public.srk_admin_mark_electrician_payout_paid(uuid,text,text,text)'::regprocedure))>0
  and position('v_booking.assigned_electrician_id is distinct from v_row.electrician_profile_id' in
  pg_get_functiondef('public.srk_admin_mark_electrician_payout_paid(uuid,text,text,text)'::regprocedure))>0,
  'payout electrician must match both booking assignment and immutable bill');
select ok(position('v_expected_service := round(v_bill.labour_amount,2)' in
  pg_get_functiondef('public.srk_admin_mark_electrician_payout_paid(uuid,text,text,text)'::regprocedure))>0
  and position('v_expected_materials := 0' in
  pg_get_functiondef('public.srk_admin_mark_electrician_payout_paid(uuid,text,text,text)'::regprocedure))>0,
  'new-category payout is based on labour only and excludes materials');
select ok(position('v_expected_commission := round(v_expected_service * v_booking.commission_rate / 100,2)' in
  pg_get_functiondef('public.srk_admin_mark_electrician_payout_paid(uuid,text,text,text)'::regprocedure))>0,
  'platform commission is reconciled against the immutable labour amount');
select ok(position('v_expected_service + v_expected_materials - v_expected_commission' in
  pg_get_functiondef('public.srk_admin_mark_electrician_payout_paid(uuid,text,text,text)'::regprocedure))>0,
  'electrician payable is labour plus materials less commission');
select ok(position('i.status = '||quote_literal('settled') in
  pg_get_functiondef('public.srk_admin_mark_electrician_payout_paid(uuid,text,text,text)'::regprocedure))>0
  and position('i.status = '||quote_literal('reserved') in
  pg_get_functiondef('public.srk_admin_mark_electrician_payout_paid(uuid,text,text,text)'::regprocedure))>0,
  'payment reconciliation includes carry-forward fees but payout calculation excludes fee debt');

select ok(position('elsif new.payment_status = '||quote_literal('refunded') in
  pg_get_functiondef('public.srk_create_electrician_payable()'::regprocedure))>0,
  'refund transition is handled by the payout trigger');
select ok(position('payout_status = '||quote_literal('pending') in
  pg_get_functiondef('public.srk_create_electrician_payable()'::regprocedure))>0
  and position('payout_status = '||quote_literal('refunded') in
  pg_get_functiondef('public.srk_create_electrician_payable()'::regprocedure))>0,
  'full refund closes an unpaid pending payout');
select ok(position('payout_status = '||quote_literal('blocked') in
  pg_get_functiondef('public.srk_create_electrician_payable()'::regprocedure))>0
  and position('Razorpay refund pending' in
  pg_get_functiondef('public.srk_create_electrician_payable()'::regprocedure))>0
  and position('Manual refund processed' in
  pg_get_functiondef('public.srk_create_electrician_payable()'::regprocedure))>0,
  'full refund closes only refund-owned blocked holds and preserves unrelated Admin blocks');
select ok(position('and payout_note in (' in
  pg_get_functiondef('public.srk_create_electrician_payable()'::regprocedure))>0,
  'unrelated Admin payout blocks remain untouched');
select ok(position('payout_note = null' in
  pg_get_functiondef('public.srk_create_electrician_payable()'::regprocedure))>0,
  'refund-owned payout hold metadata is cleared after final refund');
select ok(position('payout_status = '||quote_literal('paid') in
  pg_get_functiondef('public.srk_create_electrician_payable()'::regprocedure))=0,
  'refund trigger never overwrites an already paid payout');

select ok(position('v_booking.commission_rate is null' in
  pg_get_functiondef('public.srk_admin_mark_electrician_payout_paid(uuid,text,text,text)'::regprocedure))>0
  and position('v_booking.commission_rate > 100' in
  pg_get_functiondef('public.srk_admin_mark_electrician_payout_paid(uuid,text,text,text)'::regprocedure))>0,
  'Admin settlement independently rejects missing or out-of-range commission rates');

select ok(exists(select 1 from pg_trigger t
  where t.tgrelid='public.service_bookings'::regclass
    and not t.tgisinternal
    and t.tgfoid='public.srk_set_booking_commission_before_payout()'::regprocedure
    and (t.tgtype & 2)=2
    and (t.tgtype & 1)=1
    and (t.tgtype & 4)=4
    and (t.tgtype & 16)=16),
  'booking commission is assigned by a row-level BEFORE INSERT/UPDATE trigger');

select ok(position('manual_payment_method_mismatch' in
  lower(pg_get_functiondef('public.srk_set_booking_commission_before_payout()'::regprocedure)))>0,
  'payout finalization fails closed when manual evidence method differs from the booking');

select ok(position('new.commission_amount := v_commission' in
  lower(pg_get_functiondef('public.srk_set_booking_commission_before_payout()'::regprocedure)))>0
  and position('round(v_service * v_rate / 100,2)' in
  lower(pg_get_functiondef('public.srk_set_booking_commission_before_payout()'::regprocedure)))>0,
  'BEFORE trigger writes the same labour-only commission formula used by payout reconciliation');

select ok(exists(select 1 from pg_trigger t
  where t.tgrelid='public.service_bookings'::regclass
    and not t.tgisinternal
    and t.tgfoid='public.srk_validate_booking_commission_payout_parity()'::regprocedure
    and (t.tgtype & 2)=0
    and (t.tgtype & 1)=1
    and (t.tgtype & 4)=4
    and (t.tgtype & 16)=16)
  and position('new.commission_amount is distinct from v_platform_commission' in
  lower(pg_get_functiondef('public.srk_validate_booking_commission_payout_parity()'::regprocedure)))>0
  and position('new.commission_amount :=' in
  lower(pg_get_functiondef('public.srk_create_electrician_payable()'::regprocedure)))=0,
  'AFTER triggers retain payout writes and independently reject booking-to-ledger commission mismatches');

select * from finish();
rollback;
