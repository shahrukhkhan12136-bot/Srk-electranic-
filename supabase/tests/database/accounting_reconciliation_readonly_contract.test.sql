begin;
select plan(20);

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

select ok((select relrowsecurity from pg_class where oid='public.srk_route_transfers'::regclass),
  'Route transfer ledger has RLS enabled');
select ok(not has_table_privilege('authenticated','public.srk_route_transfers','select'),
  'authenticated clients cannot read provider Route transfer ledger');
select ok((select data_type='bigint' from information_schema.columns
  where table_schema='public' and table_name='srk_route_transfers' and column_name='amount_paise'),
  'Route transfer values are stored as integer paise');

select * from finish();
rollback;
