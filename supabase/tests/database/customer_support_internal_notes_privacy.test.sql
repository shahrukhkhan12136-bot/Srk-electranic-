begin;

-- Customer-facing support/refund RPCs must never serialize internal staff notes.
select plan(10);

select ok(
  position('null::text as admin_note' in lower(pg_get_functiondef('public.srk_customer_list_booking_complaints()'::regprocedure))) > 0,
  'complaint RPC preserves legacy field but returns NULL for admin_note'
);

select ok(
  position('c.admin_note' in lower(pg_get_functiondef('public.srk_customer_list_booking_complaints()'::regprocedure))) = 0,
  'complaint RPC does not select the internal admin_note column'
);

select ok(
  position('e.note' in lower(pg_get_functiondef('public.srk_customer_list_booking_complaints()'::regprocedure))) = 0,
  'complaint activity does not serialize unrestricted event notes'
);

select ok(
  position('c.customer_user_id = auth.uid()' in lower(pg_get_functiondef('public.srk_customer_list_booking_complaints()'::regprocedure))) > 0,
  'complaint RPC remains scoped to the authenticated customer'
);

select ok(
  position('null::text as admin_note' in lower(pg_get_functiondef('public.srk_customer_list_booking_refund_requests()'::regprocedure))) > 0,
  'refund RPC preserves legacy field but returns NULL for admin_note'
);

select ok(
  position('r.admin_note' in lower(pg_get_functiondef('public.srk_customer_list_booking_refund_requests()'::regprocedure))) = 0,
  'refund RPC does not select the internal admin_note column'
);

select ok(
  position('r.customer_user_id = auth.uid()' in lower(pg_get_functiondef('public.srk_customer_list_booking_refund_requests()'::regprocedure))) > 0,
  'refund RPC remains scoped to the authenticated customer'
);

select ok(
  not has_function_privilege('anon', 'public.srk_customer_list_booking_complaints()', 'EXECUTE')
  and has_function_privilege('authenticated', 'public.srk_customer_list_booking_complaints()', 'EXECUTE'),
  'complaint RPC remains authenticated-only'
);

select ok(
  not has_function_privilege('anon', 'public.srk_customer_list_booking_refund_requests()', 'EXECUTE')
  and has_function_privilege('authenticated', 'public.srk_customer_list_booking_refund_requests()', 'EXECUTE'),
  'refund RPC remains authenticated-only'
);

select ok(
  position('limit 100' in lower(pg_get_functiondef('public.srk_customer_list_booking_complaints()'::regprocedure))) > 0,
  'complaint list retains bounded result size'
);

select * from finish();
rollback;
