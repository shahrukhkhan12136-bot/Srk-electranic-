begin;
select plan(9);

select has_function('public','srk_admin_confirm_legacy_booking',array['uuid'],
  'legacy Admin confirmation RPC exists');

select ok(position('public.is_srk_admin()' in
  pg_get_functiondef('public.srk_admin_confirm_legacy_booking(uuid)'::regprocedure))>0,
  'legacy confirmation is Main Admin only');

select ok(position('for update' in lower(
  pg_get_functiondef('public.srk_admin_confirm_legacy_booking(uuid)'::regprocedure)))>0,
  'legacy confirmation locks the booking row');

select ok(position('selected_category is not null' in lower(
  pg_get_functiondef('public.srk_admin_confirm_legacy_booking(uuid)'::regprocedure)))>0
  and position('status is distinct from ''new''' in lower(
  pg_get_functiondef('public.srk_admin_confirm_legacy_booking(uuid)'::regprocedure)))>0,
  'confirmation accepts only new legacy bookings');

select ok(position('razorpay_order_id' in lower(
  pg_get_functiondef('public.srk_admin_confirm_legacy_booking(uuid)'::regprocedure)))>0
  and position('payment_status in (' in lower(
  pg_get_functiondef('public.srk_admin_confirm_legacy_booking(uuid)'::regprocedure)))>0,
  'confirmation cannot bypass online or paid/refunded payment workflows');

select ok(position('set status=''confirmed''' in lower(
  pg_get_functiondef('public.srk_admin_confirm_legacy_booking(uuid)'::regprocedure)))>0
  and position('set status=' in lower(
  pg_get_functiondef('public.srk_admin_confirm_legacy_booking(uuid)'::regprocedure)))=
  position('set status=''confirmed''' in lower(
  pg_get_functiondef('public.srk_admin_confirm_legacy_booking(uuid)'::regprocedure)),
  'RPC performs only the new-to-confirmed status transition');

select ok(has_function_privilege('authenticated',
  'public.srk_admin_confirm_legacy_booking(uuid)','EXECUTE')
  and not has_function_privilege('anon',
  'public.srk_admin_confirm_legacy_booking(uuid)','EXECUTE'),
  'RPC execution is authenticated-only; Main Admin is enforced inside');

select ok(not has_column_privilege('authenticated','public.service_bookings','status','UPDATE')
  and has_column_privilege('authenticated','public.service_bookings','quoted_amount','UPDATE'),
  'authenticated clients cannot directly update status while quote edits remain available');

select ok(coalesce((select proconfig @> ARRAY['search_path=""'] from pg_proc
  where oid='public.srk_admin_confirm_legacy_booking(uuid)'::regprocedure),false),
  'SECURITY DEFINER RPC pins an empty search_path');

select * from finish();
rollback;
