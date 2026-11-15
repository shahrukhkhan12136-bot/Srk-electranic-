begin;
select plan(5);
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
select ok(has_function_privilege('service_role','public.srk_service_reconcile_booking_refund(uuid,text,text,text)','execute')
  and not has_function_privilege('authenticated','public.srk_service_reconcile_booking_refund(uuid,text,text,text)','execute'),
  'only trusted service role can reconcile provider refund state');
select * from finish();
rollback;
