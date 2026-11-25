BEGIN;
SELECT plan(7);
SELECT ok(position('auth.uid()' in pg_get_functiondef('public.srk_customer_get_payment_receipt(uuid)'::regprocedure))>0,
 'receipt requires an authenticated user');
SELECT ok(position('customer_user_id=v_uid' in pg_get_functiondef('public.srk_customer_get_payment_receipt(uuid)'::regprocedure))>0,
 'receipt is scoped to the booking owner');
SELECT ok(position('service_amount' in pg_get_functiondef('public.srk_customer_get_payment_receipt(uuid)'::regprocedure))>0,
 'new Master receipt returns the service amount');
SELECT ok(position('f.subtotal_paise<>f.labour_amount_paise' in pg_get_functiondef('public.srk_customer_get_payment_receipt(uuid)'::regprocedure))>0,
 'new Master bill must reconcile to service amount only');
SELECT ok(position('v_service+v_fee=v_total' in pg_get_functiondef('public.srk_customer_get_payment_receipt(uuid)'::regprocedure))>0,
 'legacy receipt fallback reconciles only service and recorded cancellation fee');
SELECT ok(position('materials_amount' in lower(pg_get_functiondef('public.srk_customer_get_payment_receipt(uuid)'::regprocedure)))=0,
 'receipt RPC exposes no legacy add-on amount field');
SELECT ok(not has_function_privilege('anon','public.srk_customer_get_payment_receipt(uuid)','EXECUTE')
 and has_function_privilege('authenticated','public.srk_customer_get_payment_receipt(uuid)','EXECUTE'),
 'receipt RPC remains authenticated-only');
SELECT * FROM finish();
ROLLBACK;
