begin;
select plan(9);

select ok(
  has_function_privilege('authenticated','public.srk_customer_create_booking_complaint(uuid,text,text)','EXECUTE')
  and not has_function_privilege('anon','public.srk_customer_create_booking_complaint(uuid,text,text)','EXECUTE'),
  'complaint creation RPC is authenticated only'
);
select ok(
  position('set search_path = ''''' in lower(pg_get_functiondef('public.srk_customer_create_booking_complaint(uuid,text,text)'::regprocedure))) > 0,
  'security definer RPC uses an empty search_path'
);
select ok(
  position('auth.uid()' in lower(pg_get_functiondef('public.srk_customer_create_booking_complaint(uuid,text,text)'::regprocedure))) > 0,
  'customer identity is derived from auth.uid'
);
select ok(
  position('customer_user_id = v_customer_id' in lower(pg_get_functiondef('public.srk_customer_create_booking_complaint(uuid,text,text)'::regprocedure))) > 0,
  'booking ownership is enforced server-side'
);
select ok(
  position('for share' in lower(pg_get_functiondef('public.srk_customer_create_booking_complaint(uuid,text,text)'::regprocedure))) > 0,
  'booking ownership check locks the booking row during complaint creation'
);
select ok(
  position('pg_advisory_xact_lock' in lower(pg_get_functiondef('public.srk_customer_create_booking_complaint(uuid,text,text)'::regprocedure))) > 0,
  'per-customer quota checks are serialized'
);
select ok(
  position('not between 20 and 2000' in lower(pg_get_functiondef('public.srk_customer_create_booking_complaint(uuid,text,text)'::regprocedure))) > 0,
  'complaint description length is bounded'
);
select ok(
  position('p_category not in' in lower(pg_get_functiondef('public.srk_customer_create_booking_complaint(uuid,text,text)'::regprocedure))) > 0,
  'complaint category is allowlisted'
);
select ok(
  position('count(*)' in lower(pg_get_functiondef('public.srk_customer_create_booking_complaint(uuid,text,text)'::regprocedure))) > 0
  and position('interval ''24 hours''' in lower(pg_get_functiondef('public.srk_customer_create_booking_complaint(uuid,text,text)'::regprocedure))) > 0,
  'complaint creation has a rolling 24-hour quota'
);

select * from finish();
rollback;
