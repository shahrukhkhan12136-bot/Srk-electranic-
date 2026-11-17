begin;
select plan(55);

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

select ok(to_regprocedure('public.srk_enforce_new_booking_commission_rate()') is not null
  and exists(select 1 from pg_trigger t
    where t.tgrelid='public.service_bookings'::regclass
      and not t.tgisinternal
      and t.tgname='aa_srk_enforce_new_booking_commission_rate'
      and (t.tgtype & 2)=2 and (t.tgtype & 1)=1
      and (t.tgtype & 4)=4 and (t.tgtype & 16)=16
      and position('commission_rate' in lower(pg_get_triggerdef(t.oid)))>0),
  'fixed commission guard runs before INSERT and on commission_rate UPDATE attempts');
select ok(position('new.commission_rate := 15.00' in
  lower(pg_get_functiondef('public.srk_enforce_new_booking_commission_rate()'::regprocedure)))>0
  and position('tg_op = '||quote_literal('INSERT') in
  lower(pg_get_functiondef('public.srk_enforce_new_booking_commission_rate()'::regprocedure)))>0,
  'every newly inserted booking is assigned exactly 15 percent regardless of supplied value');
select ok(position('new.commission_rate is distinct from old.commission_rate' in
  lower(pg_get_functiondef('public.srk_enforce_new_booking_commission_rate()'::regprocedure)))>0
  and position('booking_commission_rate_is_immutable' in
  lower(pg_get_functiondef('public.srk_enforce_new_booking_commission_rate()'::regprocedure)))>0,
  'existing booking commission snapshots cannot be rewritten');

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
  and position('round(new.commission_amount,2) is distinct from v_platform_commission' in
  lower(pg_get_functiondef('public.srk_validate_booking_commission_payout_parity()'::regprocedure)))>0
  and position('new.commission_amount :=' in
  lower(pg_get_functiondef('public.srk_create_electrician_payable()'::regprocedure)))=0,
  'AFTER triggers retain payout writes and independently reject booking-to-ledger commission mismatches');

select ok((select position('materials_amount' in lower(pg_get_triggerdef(t.oid)))>0
  and position('commission_amount' in lower(pg_get_triggerdef(t.oid)))>0
  from pg_trigger t
  where t.tgrelid='public.service_bookings'::regclass
    and not t.tgisinternal
    and t.tgfoid='public.srk_validate_booking_commission_payout_parity()'::regprocedure),
  'AFTER parity validator covers every payout-writer update column plus direct commission edits');

select ok((select min(t.tgname)='srk_reconcile_electrician_payable'
  from pg_trigger t
  where t.tgrelid='public.service_bookings'::regclass
    and not t.tgisinternal
    and t.tgfoid in (
      'public.srk_create_electrician_payable()'::regprocedure,
      'public.srk_validate_booking_commission_payout_parity()'::regprocedure))
  and (select max(t.tgname)='zz_srk_validate_booking_commission_payout_parity'
  from pg_trigger t
  where t.tgrelid='public.service_bookings'::regclass
    and not t.tgisinternal
    and t.tgfoid in (
      'public.srk_create_electrician_payable()'::regprocedure,
      'public.srk_validate_booking_commission_payout_parity()'::regprocedure)),
  'alphabetical AFTER trigger order writes payout ledger before parity validation');


select ok(not exists(select 1 from pg_trigger t
  where t.tgrelid='public.service_bookings'::regclass
    and not t.tgisinternal
    and t.tgname='srk_booking_commission_trigger'),
  'legacy completion-time commission trigger is retired from service_bookings');

select ok(to_regprocedure('public.srk_calculate_commission_on_completion()') is not null,
  'legacy commission function remains available for compatibility but is not attached');

select ok(exists(select 1 from pg_trigger t
    where t.tgrelid='public.service_bookings'::regclass
      and not t.tgisinternal
      and t.tgname='zz_srk_set_booking_commission_before_payout'),
  'verified-payment commission trigger remains installed after legacy trigger retirement');

select ok(position('payout_row_missing_during_commission_parity_check' in
  lower(pg_get_functiondef('public.srk_validate_booking_commission_payout_parity()'::regprocedure)))>0
  and position('booking_commission_and_payout_platform_commission_mismatch' in
  lower(pg_get_functiondef('public.srk_validate_booking_commission_payout_parity()'::regprocedure)))>0,
  'parity validator explicitly rejects missing payout rows and commission mismatches');

select ok(position('where public.srk_electrician_payouts.payout_status = '||quote_literal('pending') in
  lower(pg_get_functiondef('public.srk_create_electrician_payable()'::regprocedure)))>0,
  'payout upsert cannot silently overwrite a blocked payout row');


select ok((select position('commission_amount' in lower(pg_get_triggerdef(t.oid)))=0
  from pg_trigger t
  where t.tgrelid='public.service_bookings'::regclass
    and not t.tgisinternal
    and t.tgfoid='public.srk_create_electrician_payable()'::regprocedure),
  'payout writer does not run on commission_amount-only edits');

select ok((select position('commission_amount' in lower(pg_get_triggerdef(t.oid)))>0
  from pg_trigger t
  where t.tgrelid='public.service_bookings'::regclass
    and not t.tgisinternal
    and t.tgfoid='public.srk_validate_booking_commission_payout_parity()'::regprocedure),
  'parity validator runs on commission_amount-only edits while payout writer does not');


-- Behavioral rollback fixtures: legacy approved-quote path avoids Auth-user and
-- immutable new-category labour-bill prerequisites. These execute only when pgTAP runs.
create temporary table payout_rollback_fixtures (
  scenario text primary key,
  electrician_id uuid not null,
  booking_id uuid not null
) on commit drop;

with profiles as (
  insert into public.electrician_profiles
    (display_name,phone,state,district,pincode,active)
  values
    ('pgTAP payout rollback missing','9811100001','Uttar Pradesh','Varanasi','221001',false),
    ('pgTAP payout rollback mismatch','9811100002','Uttar Pradesh','Varanasi','221001',false),
    ('pgTAP payout rollback positive','9811100003','Uttar Pradesh','Varanasi','221001',false)
  returning id, phone
),
bookings as (
  insert into public.service_bookings
    (customer_name,phone,state,district,pincode,address,service_type,
     payment_method,quoted_amount,status,assigned_electrician_id,
     commission_rate,payment_status,razorpay_payment_id,payment_verified_at,
     amount_paid,service_charge,materials_amount,quote_status)
  select
    'pgTAP payout rollback', '9822200000', 'Uttar Pradesh','Varanasi','221001',
    'Test address','Electrical repair','Razorpay',100.00,'completed',
    p.id,99.00,'paid',
    case p.phone
      when '9811100001' then 'pgTapRollbackMissingPayment'
      when '9811100002' then 'pgTapRollbackMismatchPayment'
      else 'pgTapRollbackPositivePayment'
    end,
    now(),100.00,100.00,0.00,'approved'
  from profiles p
  returning id, assigned_electrician_id, razorpay_payment_id
)
insert into payout_rollback_fixtures(scenario,electrician_id,booking_id)
select case b.razorpay_payment_id
         when 'pgTapRollbackMissingPayment' then 'missing'
         when 'pgTapRollbackMismatchPayment' then 'mismatch'
         else 'positive'
       end,
       b.assigned_electrician_id,b.id
from bookings b;

select ok((select count(*)=3 and bool_and(b.commission_rate=15.00)
  from public.service_bookings b
  join payout_rollback_fixtures f on f.booking_id=b.id),
  'booking INSERT forces exactly 15 percent even when the caller supplies 99 percent');

lives_ok(
  format('update public.service_bookings set commission_amount=commission_amount where id=%L',
    (select booking_id from payout_rollback_fixtures where scenario='positive')),
  'commission-only update succeeds when booking and payout commission already match'
);

select throws_ok(
  format('update public.service_bookings set commission_rate=20.00 where id=%L',
    (select booking_id from payout_rollback_fixtures where scenario='missing')),
  'P0001',
  'BOOKING_COMMISSION_RATE_IS_IMMUTABLE',
  'existing booking commission snapshot cannot be changed'
);

delete from public.srk_electrician_payouts p
using payout_rollback_fixtures f
where f.scenario='missing' and p.booking_id=f.booking_id;

select throws_ok(
  format('update public.service_bookings set commission_amount=commission_amount where id=%L',
    (select booking_id from payout_rollback_fixtures where scenario='missing')),
  'P0001',
  'PAYOUT_ROW_MISSING_DURING_COMMISSION_PARITY_CHECK',
  'commission-only update rejects a missing payout row'
);
select ok(not exists(
  select 1 from public.srk_electrician_payouts p
  join payout_rollback_fixtures f on f.booking_id=p.booking_id
  where f.scenario='missing'
), 'failed missing-payout update leaves the payout row absent');

update public.srk_electrician_payouts p
set payout_status='blocked',
    platform_commission=platform_commission+1.00
from payout_rollback_fixtures f
where f.scenario='mismatch' and p.booking_id=f.booking_id;

select throws_ok(
  format('update public.service_bookings set commission_amount=commission_amount where id=%L',
    (select booking_id from payout_rollback_fixtures where scenario='mismatch')),
  'P0001',
  'BOOKING_COMMISSION_AND_PAYOUT_PLATFORM_COMMISSION_MISMATCH',
  'commission-only update rejects a payout commission mismatch'
);
select ok(exists(
  select 1 from public.srk_electrician_payouts p
  join payout_rollback_fixtures f on f.booking_id=p.booking_id
  where f.scenario='mismatch' and p.payout_status='blocked'
    and p.platform_commission=16.00
), 'failed mismatch update preserves the blocked payout and its mismatched ledger amount');
select ok((select count(*)=1 from public.srk_electrician_payouts p
  join payout_rollback_fixtures f on f.booking_id=p.booking_id
  where f.scenario='mismatch'),
  'mismatch rollback preserves exactly one payout row');


select ok(position('p.gross_service_amount' in lower(pg_get_functiondef(
  'public.srk_admin_commission_report()'::regprocedure)))>0
  and position('p.materials_amount' in lower(pg_get_functiondef(
  'public.srk_admin_commission_report()'::regprocedure)))>0
  and position('p.platform_commission' in lower(pg_get_functiondef(
  'public.srk_admin_commission_report()'::regprocedure)))>0
  and position('p.electrician_payable' in lower(pg_get_functiondef(
  'public.srk_admin_commission_report()'::regprocedure)))>0,
  'Admin commission report reads electrician gross, commission and payable from the canonical payout ledger');

select ok(position('b.amount_paid' in lower(pg_get_functiondef(
  'public.srk_admin_commission_report()'::regprocedure)))>0
  and position('p.electrician_payable' in lower(pg_get_functiondef(
  'public.srk_admin_commission_report()'::regprocedure)))>0
  and position('set search_path = ""' in lower(pg_get_functiondef(
  'public.srk_admin_commission_report()'::regprocedure)))>0,
  'Admin commission report separates customer collection from payout payable and pins an empty search_path');


select ok(position('collection_totals' in lower(pg_get_functiondef(
  'public.srk_admin_commission_report()'::regprocedure)))>0
  and position('sum(coalesce(b.amount_paid,0))' in lower(pg_get_functiondef(
  'public.srk_admin_commission_report()'::regprocedure)))>0,
  'Admin report totals verified collections independently of payout rows so missing payout records cannot hide customer collections');


select ok(position('left join public.srk_electrician_payouts p' in lower(pg_get_functiondef(
  'public.srk_admin_commission_report()'::regprocedure)))>0
  and position('and p.payout_status in (''pending'',''paid'',''blocked'')' in lower(pg_get_functiondef(
  'public.srk_admin_commission_report()'::regprocedure)))>0
  and position('count(pc.booking_id)' in lower(pg_get_functiondef(
  'public.srk_admin_commission_report()'::regprocedure)))>0
  and position('payout_status in (''pending'',''paid'',''blocked'',''refunded'')' in lower(pg_get_functiondef(
  'public.srk_admin_commission_report()'::regprocedure)))=0,
  'Admin commission report counts all eligible paid completed bookings and excludes refunded payout amounts from commission totals');

select * from finish();
rollback;
