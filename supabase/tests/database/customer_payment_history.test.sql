BEGIN;
SELECT plan(14);
SELECT has_function('public','srk_customer_get_payment_history',ARRAY['integer','integer'],
 'unified customer payment history RPC exists');
SELECT ok(pg_get_function_result('public.srk_customer_get_payment_history(integer,integer)'::regprocedure)
  ILIKE '%event_id uuid%' AND
  pg_get_function_result('public.srk_customer_get_payment_history(integer,integer)'::regprocedure)
  ILIKE '%event_type text%' AND
  pg_get_function_result('public.srk_customer_get_payment_history(integer,integer)'::regprocedure)
  ILIKE '%occurred_at timestamp with time zone%',
  'original eight-column payment history return contract is preserved');
SELECT ok((SELECT prosecdef AND provolatile='s' FROM pg_proc
  WHERE oid='public.srk_customer_get_payment_history(integer,integer)'::regprocedure),
  'payment history runs stable with a security definer boundary');
SELECT ok(position('Customer login required' in pg_get_functiondef(
  'public.srk_customer_get_payment_history(integer,integer)'::regprocedure))>0
  AND position('auth.uid()' in pg_get_functiondef(
  'public.srk_customer_get_payment_history(integer,integer)'::regprocedure))>0,
  'payment history rejects anonymous calls');
SELECT ok(position('b.customer_user_id=v_uid' in pg_get_functiondef(
  'public.srk_customer_get_payment_history(integer,integer)'::regprocedure))>0,
  'all payment and refund events are scoped to the signed-in customer');
SELECT ok(position('least(greatest(coalesce(p_limit,25),1),50)' in lower(pg_get_functiondef(
  'public.srk_customer_get_payment_history(integer,integer)'::regprocedure)))>0,
  'page size is clamped to 1 through 50');
SELECT ok(position('v_offset > 10000' in pg_get_functiondef(
  'public.srk_customer_get_payment_history(integer,integer)'::regprocedure))>0,
  'excessive page offsets are rejected');
SELECT ok(position('order by e.occurred_at desc nulls last,e.event_id desc' in lower(pg_get_functiondef(
  'public.srk_customer_get_payment_history(integer,integer)'::regprocedure))>0,
  'payment history has stable timestamp and event-id ordering');
SELECT ok(position('b.payment_status in (''paid'',''refunded'')' in lower(pg_get_functiondef(
  'public.srk_customer_get_payment_history(integer,integer)'::regprocedure))>0,
  'ordinary payment events are limited to verified paid or refunded bookings');
SELECT ok(position('not exists' in lower(pg_get_functiondef(
  'public.srk_customer_get_payment_history(integer,integer)'::regprocedure))>0
  AND position('srk_manual_payment_entries' in pg_get_functiondef(
  'public.srk_customer_get_payment_history(integer,integer)'::regprocedure))>0,
  'audited manual payment suppresses duplicate booking payment event');
SELECT ok(position('srk_booking_refund_requests' in pg_get_functiondef(
  'public.srk_customer_get_payment_history(integer,integer)'::regprocedure))>0,
  'customer refund request events are included');
SELECT ok(position('srk_razorpay_refunds' in pg_get_functiondef(
  'public.srk_customer_get_payment_history(integer,integer)'::regprocedure))>0,
  'Razorpay refund events are included');
SELECT ok(position('srk_manual_refund_entries' in pg_get_functiondef(
  'public.srk_customer_get_payment_history(integer,integer)'::regprocedure))>0
  AND position('srk_manual_payment_entries' in pg_get_functiondef(
  'public.srk_customer_get_payment_history(integer,integer)'::regprocedure))>0,
  'manual refund events are linked through the original manual payment audit');
SELECT ok(has_function_privilege('authenticated','public.srk_customer_get_payment_history(integer,integer)','EXECUTE')
  AND NOT has_function_privilege('anon','public.srk_customer_get_payment_history(integer,integer)','EXECUTE'),
  'payment history is executable only by authenticated customers');
SELECT * FROM finish();
ROLLBACK;
