begin;
select plan(5);

select ok(
  has_function_privilege('authenticated','public.srk_get_customer_call_contacts()','EXECUTE')
  and not has_function_privilege('anon','public.srk_get_customer_call_contacts()','EXECUTE'),
  'customer contact RPC is authenticated only'
);

select ok(
  position('auth.uid()' in lower(pg_get_functiondef('private.srk_get_customer_call_contacts_impl()'::regprocedure))) > 0,
  'private contact lookup requires the authenticated customer identity'
);

select ok(
  position('b.customer_user_id = v_uid' in pg_get_functiondef('private.srk_get_customer_call_contacts_impl()'::regprocedure)) > 0,
  'contact lookup is restricted to bookings owned by the customer'
);

select ok(
  position('b.assigned_electrician_id is not null' in lower(pg_get_functiondef('private.srk_get_customer_call_contacts_impl()'::regprocedure))) > 0,
  'contact lookup requires an assigned electrician'
);

select ok(
  position('completed' in lower(pg_get_functiondef('private.srk_get_customer_call_contacts_impl()'::regprocedure))) > 0,
  'accepted customer-electrician contact remains available after completion'
);

select * from finish();
rollback;
