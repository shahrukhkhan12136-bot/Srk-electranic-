begin;

select plan(11);

select ok(
  position('auth.uid()' in pg_get_functiondef('public.srk_customer_get_payment_history(integer,integer)'::regprocedure)) > 0,
  'payment history requires an authenticated user'
);

select ok(
  position('b.customer_user_id = v_uid' in pg_get_functiondef('public.srk_customer_get_payment_history(integer,integer)'::regprocedure)) > 0,
  'all booking-derived history is anchored to the authenticated customer bookings'
);

select ok(
  position('r.customer_user_id = v_uid' in pg_get_functiondef('public.srk_customer_get_payment_history(integer,integer)'::regprocedure)) > 0,
  'refund request rows are explicitly scoped to the authenticated customer'
);

select ok(
  position('last_error' in lower(pg_get_functiondef('public.srk_customer_get_payment_history(integer,integer)'::regprocedure))) = 0,
  'provider error details are not selected'
);

select ok(
  position('admin_note' in lower(pg_get_functiondef('public.srk_customer_get_payment_history(integer,integer)'::regprocedure))) = 0,
  'internal admin notes are not selected'
);

select ok(
  position('provider_reference' in lower(pg_get_functiondef('public.srk_customer_get_payment_history(integer,integer)'::regprocedure))) = 0
  and position('idempotency_key' in lower(pg_get_functiondef('public.srk_customer_get_payment_history(integer,integer)'::regprocedure))) = 0,
  'provider references and idempotency keys are not selected'
);

select ok(
  position('least(greatest(coalesce(p_limit, 25), 1), 50)' in lower(pg_get_functiondef('public.srk_customer_get_payment_history(integer,integer)'::regprocedure))) > 0,
  'page size is bounded from 1 to 50'
);

select ok(
  position('v_offset > 10000' in lower(pg_get_functiondef('public.srk_customer_get_payment_history(integer,integer)'::regprocedure))) > 0,
  'offset is bounded'
);

select ok(
  position('order by e.occurred_at desc, e.event_id desc' in lower(pg_get_functiondef('public.srk_customer_get_payment_history(integer,integer)'::regprocedure))) > 0,
  'history has deterministic newest-first ordering'
);

select ok(
  not has_function_privilege('anon', 'public.srk_customer_get_payment_history(integer,integer)', 'EXECUTE')
  and has_function_privilege('authenticated', 'public.srk_customer_get_payment_history(integer,integer)', 'EXECUTE'),
  'payment history RPC is authenticated-only'
);

select ok(
  position('service_bookings' in lower(pg_get_functiondef('public.srk_customer_get_payment_history(integer,integer)'::regprocedure))) > 0
  and position('srk_razorpay_refunds' in lower(pg_get_functiondef('public.srk_customer_get_payment_history(integer,integer)'::regprocedure))) > 0
  and position('srk_manual_refund_entries' in lower(pg_get_functiondef('public.srk_customer_get_payment_history(integer,integer)'::regprocedure))) > 0,
  'history aggregates booking, provider refund and manual refund sources'
);

select * from finish();
rollback;
