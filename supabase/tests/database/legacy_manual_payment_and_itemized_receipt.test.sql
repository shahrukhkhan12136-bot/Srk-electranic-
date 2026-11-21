begin;
select plan(18);

select has_function('public','srk_admin_record_manual_payment',
  array['uuid','text','text','text'],
  'legacy Admin manual-payment RPC exists');

select ok(position('public.is_srk_admin()' in
  pg_get_functiondef('public.srk_admin_record_manual_payment(uuid,text,text,text)'::regprocedure))>0,
  'manual-payment RPC is Main Admin only');

select ok(position('for update' in lower(
  pg_get_functiondef('public.srk_admin_record_manual_payment(uuid,text,text,text)'::regprocedure)))>0,
  'manual-payment RPC locks the booking before settlement');

select ok(position('selected_category is not null' in lower(
  pg_get_functiondef('public.srk_admin_record_manual_payment(uuid,text,text,text)'::regprocedure)))>0,
  'new-category bookings are excluded from legacy manual settlement');

select ok(position('quote_status is distinct from ''approved''' in lower(
  pg_get_functiondef('public.srk_admin_record_manual_payment(uuid,text,text,text)'::regprocedure)))>0,
  'only customer-approved legacy quotes can be settled');

select ok(position('status<>''completed''' in lower(
  pg_get_functiondef('public.srk_admin_record_manual_payment(uuid,text,text,text)'::regprocedure)))>0
  and position('assigned_electrician_id is null' in lower(
  pg_get_functiondef('public.srk_admin_record_manual_payment(uuid,text,text,text)'::regprocedure)))>0,
  'completed booking and electrician assignment are mandatory');

select ok(position('coalesce(v_booking.payment_status,''unpaid'') not in (''unpaid'',''pending'')' in lower(
  pg_get_functiondef('public.srk_admin_record_manual_payment(uuid,text,text,text)'::regprocedure))>0,
  'unexpected payment states fail closed');

select ok(position('razorpay_order_id' in lower(
  pg_get_functiondef('public.srk_admin_record_manual_payment(uuid,text,text,text)'::regprocedure)))>0
  and position('razorpay_payment_id' in lower(
  pg_get_functiondef('public.srk_admin_record_manual_payment(uuid,text,text,text)'::regprocedure)))>0,
  'Razorpay-linked bookings cannot use manual settlement');

select ok(position('service_charge' in lower(
  pg_get_functiondef('public.srk_admin_record_manual_payment(uuid,text,text,text)'::regprocedure)))>0
  and position('materials_amount' in lower(
  pg_get_functiondef('public.srk_admin_record_manual_payment(uuid,text,text,text)'::regprocedure)))>0,
  'labour and materials are separately sourced');

select ok(position('quoted_amount' in lower(
  pg_get_functiondef('public.srk_admin_record_manual_payment(uuid,text,text,text)'::regprocedure)))>0
  and position('approved_quote_total_does_not_match_labour_and_materials' in lower(
  pg_get_functiondef('public.srk_admin_record_manual_payment(uuid,text,text,text)'::regprocedure)))>0,
  'approved quote total must equal labour plus materials');

select ok(position('commission_paise:=round(v_service_paise::numeric*v_booking.commission_rate/100)' in lower(
  pg_get_functiondef('public.srk_admin_record_manual_payment(uuid,text,text,text)'::regprocedure)))>0,
  'platform commission is calculated on labour only');

select ok(position('insert into public.srk_manual_payment_entries' in lower(
  pg_get_functiondef('public.srk_admin_record_manual_payment(uuid,text,text,text)'::regprocedure)))>0,
  'payment receipt reference and method are written to the immutable unique payment ledger');

select ok(position('payment_verified_at=clock_timestamp()' in lower(
  pg_get_functiondef('public.srk_admin_record_manual_payment(uuid,text,text,text)'::regprocedure)))>0,
  'verified payment timestamp is recorded server-side');

select ok(position('insert into public.srk_electrician_payouts' in lower(
  pg_get_functiondef('public.srk_admin_record_manual_payment(uuid,text,text,text)'::regprocedure)))>0,
  'separate labour/material/commission payout row is created');

select ok(position('materials_amount' in lower(
  pg_get_functiondef('public.srk_customer_get_payment_receipt(uuid)'::regprocedure)))>0
  and position('payment receipt does not reconcile to approved labour and materials' in lower(
  pg_get_functiondef('public.srk_customer_get_payment_receipt(uuid)'::regprocedure)))>0,
  'customer receipt returns and reconciles separate materials amount');

select ok(has_function_privilege('authenticated',
  'public.srk_admin_record_manual_payment(uuid,text,text,text)','EXECUTE')
  and not has_function_privilege('anon',
  'public.srk_admin_record_manual_payment(uuid,text,text,text)','EXECUTE'),
  'manual-payment RPC is authenticated-executable and denies anon');

select ok(coalesce((select proconfig @> ARRAY['search_path=""'] from pg_proc
  where oid='public.srk_admin_record_manual_payment(uuid,text,text,text)'::regprocedure),false),
  'manual-payment SECURITY DEFINER pins an empty search_path');

select ok(position('char_length(v_reference)<4' in lower(
  pg_get_functiondef('public.srk_admin_record_manual_payment(uuid,text,text,text)'::regprocedure)))>0
  and position('char_length(v_reference)>120' in lower(
  pg_get_functiondef('public.srk_admin_record_manual_payment(uuid,text,text,text)'::regprocedure)))>0,
  'payment receipt reference is length-bounded');

select * from finish();
rollback;
