begin;
select plan(9);
select ok(position('auth.uid()' in pg_get_functiondef('public.srk_customer_get_payment_receipt(uuid)'::regprocedure))>0,
 'receipt remains authenticated');
select ok(position('customer_user_id = v_uid' in pg_get_functiondef('public.srk_customer_get_payment_receipt(uuid)'::regprocedure))>0,
 'receipt remains owner-scoped');
select ok(position('srk_booking_labour_bills' in pg_get_functiondef('public.srk_customer_get_payment_receipt(uuid)'::regprocedure))>0,
 'receipt reads immutable labour bill');
select ok(position('labour_amount_paise = round(v_booking.amount_paid * 100)::bigint' in pg_get_functiondef('public.srk_customer_get_payment_receipt(uuid)'::regprocedure))>0,
 'bill labour amount must match verified paid amount');
select ok(position('not v_has_bill' in lower(pg_get_functiondef('public.srk_customer_get_payment_receipt(uuid)'::regprocedure)))>0,
 'legacy service charge fallback is used only when no immutable bill exists');
select ok(position('materials_amount' in lower(pg_get_functiondef('public.srk_customer_get_payment_receipt(uuid)'::regprocedure)))=0,
 'receipt never includes material amounts');
select ok(not has_function_privilege('anon','public.srk_customer_get_payment_receipt(uuid)','EXECUTE')
 and has_function_privilege('authenticated','public.srk_customer_get_payment_receipt(uuid)','EXECUTE'),
 'receipt RPC remains authenticated-only');
select ok((select prosecdef from pg_proc where oid='public.srk_customer_get_payment_receipt(uuid)'::regprocedure),
 'receipt RPC remains SECURITY DEFINER');
select ok(coalesce((select proconfig @> ARRAY['search_path=""'] from pg_proc
 where oid='public.srk_customer_get_payment_receipt(uuid)'::regprocedure),false),
 'receipt RPC pins an empty search_path');
select * from finish();
rollback;
