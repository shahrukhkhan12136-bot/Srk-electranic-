begin;
select plan(10);
select ok(to_regprocedure('public.srk_service_reconcile_booking_refund(uuid,text,text,text)') is not null,
  'provider refund reconciliation RPC exists');
select ok(position('PROVIDER_REFUND_AMOUNT_DOES_NOT_MATCH_FULL_BOOKING_COLLECTION' in
  pg_get_functiondef('public.srk_service_reconcile_booking_refund(uuid,text,text,text)'::regprocedure))>0,
  'processed provider refund must match the full captured booking collection');
select ok(position('v_refund.amount_paise is distinct from round(v_booking.amount_paid*100)::bigint' in
  pg_get_functiondef('public.srk_service_reconcile_booking_refund(uuid,text,text,text)'::regprocedure))>0,
  'full amount comparison uses integer paise from the locked booking row');
select ok(position('for update of b' in lower(pg_get_functiondef('public.srk_service_reconcile_booking_refund(uuid,text,text,text)'::regprocedure)))>0,
  'booking row is locked before refund record reconciliation');
select ok(position('set payout_status=''refunded''' in lower(pg_get_functiondef(
  'public.srk_service_reconcile_booking_refund(uuid,text,text,text)'::regprocedure))>0,
  'verified processed refund closes its own blocked payout as refunded');
select ok(position('payout_note is null' in lower(pg_get_functiondef(
  'public.srk_service_reconcile_booking_refund(uuid,text,text,text)'::regprocedure)))>0
  and position('razorpay full refund verified; payout permanently withheld.' in lower(pg_get_functiondef(
  'public.srk_service_reconcile_booking_refund(uuid,text,text,text)'::regprocedure)))>0,
  'refund reconciliation tolerates the booking payout trigger closing the refund-owned hold and restores the final audit note');
select ok(position('historical processed-but-blocked state' in pg_get_functiondef(
  'public.srk_service_reconcile_booking_refund(uuid,text,text,text)'::regprocedure))>0,
  'replayed processed refunds repair their previously blocked payout');
select ok(position('ELECTRICIAN_PAYOUT_STATE_REQUIRES_MANUAL_RECONCILIATION' in pg_get_functiondef(
  'public.srk_service_reconcile_booking_refund(uuid,text,text,text)'::regprocedure))>0
  and position('ELECTRICIAN_PAYOUT_BLOCK_REASON_MISMATCH' in pg_get_functiondef(
  'public.srk_service_reconcile_booking_refund(uuid,text,text,text)'::regprocedure))>0,
  'unexpected or paid payout states fail closed for manual reconciliation');
select ok(position('from public.srk_electrician_payouts' in lower(pg_get_functiondef(
  'public.srk_service_reconcile_booking_refund(uuid,text,text,text)'::regprocedure))>0
  and position('for update' in lower(pg_get_functiondef(
  'public.srk_service_reconcile_booking_refund(uuid,text,text,text)'::regprocedure))>0,
  'payout row is locked before final refund accounting');
select ok(has_function_privilege('service_role','public.srk_service_reconcile_booking_refund(uuid,text,text,text)','execute')
  and not has_function_privilege('authenticated','public.srk_service_reconcile_booking_refund(uuid,text,text,text)','execute'),
  'only trusted service role can reconcile provider refund state');
select * from finish();
rollback;
