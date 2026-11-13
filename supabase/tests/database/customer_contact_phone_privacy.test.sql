begin;

-- Regression tests for customer electrician-phone visibility.
-- Run after applying the two source migrations in a disposable/local DB:
--   supabase test db

select plan(12);

-- The private implementation behind the legacy customer call RPC must not
-- include completed/cancelled bookings in its phone-number result.
select ok(
  position('completed' in pg_get_functiondef('private.srk_get_customer_call_contacts_impl()'::regprocedure)) = 0,
  'private call-contact implementation does not expose completed bookings'
);

select ok(
  position('cancelled' in pg_get_functiondef('private.srk_get_customer_call_contacts_impl()'::regprocedure)) = 0,
  'private call-contact implementation does not expose cancelled bookings'
);

select ok(
  position('b.customer_user_id = v_uid' in pg_get_functiondef('private.srk_get_customer_call_contacts_impl()'::regprocedure)) > 0,
  'private call-contact implementation scopes rows to the authenticated customer'
);

select ok(
  position('ep.verification_status = ''approved''' in pg_get_functiondef('private.srk_get_customer_call_contacts_impl()'::regprocedure)) > 0
  and position('ep.active = true' in pg_get_functiondef('private.srk_get_customer_call_contacts_impl()'::regprocedure)) > 0,
  'private call-contact implementation requires an approved and active electrician'
);

-- The second RPC must have the same completion/cancellation protection.
select ok(
  position('completed' in pg_get_functiondef('public.srk_customer_get_my_booking_contacts()'::regprocedure)) = 0,
  'booking-contact RPC does not expose completed bookings'
);

select ok(
  position('cancelled' in pg_get_functiondef('public.srk_customer_get_my_booking_contacts()'::regprocedure)) = 0,
  'booking-contact RPC does not expose cancelled bookings'
);

select ok(
  position('b.customer_user_id = auth.uid()' in pg_get_functiondef('public.srk_customer_get_my_booking_contacts()'::regprocedure)) > 0,
  'booking-contact RPC scopes rows to auth.uid()'
);

select ok(
  position('ep.verification_status = ''approved''' in pg_get_functiondef('public.srk_customer_get_my_booking_contacts()'::regprocedure)) > 0
  and position('ep.active = true' in pg_get_functiondef('public.srk_customer_get_my_booking_contacts()'::regprocedure)) > 0,
  'booking-contact RPC requires an approved and active electrician'
);

-- The private implementation is not callable by anon or PUBLIC.
select ok(
  not has_function_privilege('anon', 'private.srk_get_customer_call_contacts_impl()', 'EXECUTE'),
  'anon cannot execute the private call-contact implementation'
);

select ok(
  has_function_privilege('authenticated', 'private.srk_get_customer_call_contacts_impl()', 'EXECUTE'),
  'authenticated can execute the private call-contact implementation through its wrapper'
);

-- Both public RPC entry points are authenticated-only.
select ok(
  not has_function_privilege('anon', 'public.srk_get_customer_call_contacts()', 'EXECUTE')
  and has_function_privilege('authenticated', 'public.srk_get_customer_call_contacts()', 'EXECUTE'),
  'legacy customer call-contact wrapper is authenticated-only'
);

select ok(
  not has_function_privilege('anon', 'public.srk_customer_get_my_booking_contacts()', 'EXECUTE')
  and has_function_privilege('authenticated', 'public.srk_customer_get_my_booking_contacts()', 'EXECUTE'),
  'booking-contact RPC is authenticated-only'
);

select * from finish();
rollback;
