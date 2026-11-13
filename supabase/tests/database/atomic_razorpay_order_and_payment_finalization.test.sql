BEGIN;
SELECT plan(28);

SELECT has_schema('srk_private','private schema exists for payment order locks');
SELECT has_table('srk_private','payment_order_locks','payment order lock table exists');
SELECT ok(
  NOT has_table_privilege('anon','srk_private.payment_order_locks','SELECT')
  AND NOT has_table_privilege('authenticated','srk_private.payment_order_locks','SELECT')
  AND NOT has_table_privilege('service_role','srk_private.payment_order_locks','SELECT'),
  'payment order lock table is inaccessible to API roles'
);

SELECT has_function('public','srk_claim_payment_order_lock',ARRAY['uuid'],'service claim RPC exists');
SELECT has_function('public','srk_link_payment_order',ARRAY['uuid','uuid','text','bigint'],'atomic order link RPC exists');
SELECT has_function('public','srk_release_payment_order_lock',ARRAY['uuid','uuid'],'service release RPC exists');
SELECT has_function('public','srk_service_finalize_captured_payment',ARRAY['uuid','text','text','bigint','text'],'atomic captured payment RPC exists');

SELECT ok(has_function_privilege('service_role','public.srk_claim_payment_order_lock(uuid)','EXECUTE')
  AND NOT has_function_privilege('anon','public.srk_claim_payment_order_lock(uuid)','EXECUTE')
  AND NOT has_function_privilege('authenticated','public.srk_claim_payment_order_lock(uuid)','EXECUTE'),
  'order lock claim is service-role only');
SELECT ok(has_function_privilege('service_role','public.srk_link_payment_order(uuid,uuid,text,bigint)','EXECUTE')
  AND NOT has_function_privilege('anon','public.srk_link_payment_order(uuid,uuid,text,bigint)','EXECUTE')
  AND NOT has_function_privilege('authenticated','public.srk_link_payment_order(uuid,uuid,text,bigint)','EXECUTE'),
  'order linking is service-role only');
SELECT ok(has_function_privilege('service_role','public.srk_release_payment_order_lock(uuid,uuid)','EXECUTE')
  AND NOT has_function_privilege('anon','public.srk_release_payment_order_lock(uuid,uuid)','EXECUTE')
  AND NOT has_function_privilege('authenticated','public.srk_release_payment_order_lock(uuid,uuid)','EXECUTE'),
  'order lock release is service-role only');
SELECT ok(has_function_privilege('service_role','public.srk_service_finalize_captured_payment(uuid,text,text,bigint,text)','EXECUTE')
  AND NOT has_function_privilege('anon','public.srk_service_finalize_captured_payment(uuid,text,text,bigint,text)','EXECUTE')
  AND NOT has_function_privilege('authenticated','public.srk_service_finalize_captured_payment(uuid,text,text,bigint,text)','EXECUTE'),
  'payment finalization is service-role only');

SELECT ok(pg_get_functiondef('public.srk_claim_payment_order_lock(uuid)'::regprocedure) ILIKE '%auth.jwt()%role%'
  AND pg_get_functiondef('public.srk_claim_payment_order_lock(uuid)'::regprocedure) ILIKE '%FOR UPDATE%',
  'claim verifies service role and locks the booking row');
SELECT ok(pg_get_functiondef('public.srk_claim_payment_order_lock(uuid)'::regprocedure) ILIKE '%expires_at%'
  AND pg_get_functiondef('public.srk_claim_payment_order_lock(uuid)'::regprocedure) ILIKE '%interval%',
  'claim uses expiring lock to recover abandoned order attempts');
SELECT ok(pg_get_functiondef('public.srk_claim_payment_order_lock(uuid)'::regprocedure) ILIKE '%payment_method%'
  AND pg_get_functiondef('public.srk_claim_payment_order_lock(uuid)'::regprocedure) ILIKE '%completion_approval_status%',
  'claim checks current payment choice and approved completion');

SELECT ok(pg_get_functiondef('public.srk_link_payment_order(uuid,uuid,text,bigint)'::regprocedure) ILIKE '%lock_token%'
  AND pg_get_functiondef('public.srk_link_payment_order(uuid,uuid,text,bigint)'::regprocedure) ILIKE '%expires_at%',
  'order link requires the active unexpired lock token');
SELECT ok(pg_get_functiondef('public.srk_link_payment_order(uuid,uuid,text,bigint)'::regprocedure) ILIKE '%FOR UPDATE%'
  AND pg_get_functiondef('public.srk_link_payment_order(uuid,uuid,text,bigint)'::regprocedure) ILIKE '%status%',
  'order link rechecks and locks the latest booking state');
SELECT ok(pg_get_functiondef('public.srk_link_payment_order(uuid,uuid,text,bigint)'::regprocedure) ILIKE '%labour_amount_paise%'
  AND pg_get_functiondef('public.srk_link_payment_order(uuid,uuid,text,bigint)'::regprocedure) ILIKE '%p_amount_paise%',
  'order link matches amount to immutable labour bill or legacy approved quote');
SELECT ok(pg_get_functiondef('public.srk_link_payment_order(uuid,uuid,text,bigint)'::regprocedure) ILIKE '%payment_verified_at%'
  AND pg_get_functiondef('public.srk_link_payment_order(uuid,uuid,text,bigint)'::regprocedure) ILIKE '%razorpay_payment_id%',
  'order link rejects already verified or identified payments');

SELECT ok(pg_get_functiondef('public.srk_release_payment_order_lock(uuid,uuid)'::regprocedure) ILIKE '%lock_token%',
  'lock release is scoped to the exact booking and token');

SELECT ok(pg_get_functiondef('public.srk_service_finalize_captured_payment(uuid,text,text,bigint,text)'::regprocedure) ILIKE '%FOR UPDATE%',
  'captured payment finalizer serializes on the booking row');
SELECT ok(pg_get_functiondef('public.srk_service_finalize_captured_payment(uuid,text,text,bigint,text)'::regprocedure) ILIKE '%IS DISTINCT FROM p_razorpay_order_id%',
  'finalizer requires the exact order linked to the booking');
SELECT ok(pg_get_functiondef('public.srk_service_finalize_captured_payment(uuid,text,text,bigint,text)'::regprocedure) ILIKE '%p_amount_paise%'
  AND pg_get_functiondef('public.srk_service_finalize_captured_payment(uuid,text,text,bigint,text)'::regprocedure) ILIKE '%labour_amount_paise%',
  'finalizer reconciles captured paise against immutable labour bill');
SELECT ok(pg_get_functiondef('public.srk_service_finalize_captured_payment(uuid,text,text,bigint,text)'::regprocedure) ILIKE '%p_currency IS DISTINCT FROM%',
  'finalizer rejects null or non-INR currency');
SELECT ok(pg_get_functiondef('public.srk_service_finalize_captured_payment(uuid,text,text,bigint,text)'::regprocedure) ILIKE '%payment_method%'
  AND pg_get_functiondef('public.srk_service_finalize_captured_payment(uuid,text,text,bigint,text)'::regprocedure) ILIKE '%completion_approval_status%',
  'finalizer rechecks online choice and customer-approved completion');
SELECT ok(pg_get_functiondef('public.srk_service_finalize_captured_payment(uuid,text,text,bigint,text)'::regprocedure) ILIKE '%already_processed%'
  AND pg_get_functiondef('public.srk_service_finalize_captured_payment(uuid,text,text,bigint,text)'::regprocedure) ILIKE '%razorpay_payment_id%',
  'same payment retry is idempotent and different payment ID conflicts');
SELECT ok(pg_get_functiondef('public.srk_service_finalize_captured_payment(uuid,text,text,bigint,text)'::regprocedure) ILIKE '%payment_status=''paid''%'
  AND pg_get_functiondef('public.srk_service_finalize_captured_payment(uuid,text,text,bigint,text)'::regprocedure) ILIKE '%payment_verified_at%',
  'finalizer records paid state and server verification timestamp atomically');


SELECT ok(
  pg_get_functiondef('public.srk_link_payment_order(uuid,uuid,text,bigint)'::regprocedure)
    ILIKE '%v_booking.quoted_amount IS NULL%',
  'legacy order linking rejects a missing approved quote total instead of allowing SQL NULL to bypass reconciliation'
);
SELECT ok(
  pg_get_functiondef('public.srk_service_finalize_captured_payment(uuid,text,text,bigint,text)'::regprocedure)
    ILIKE '%v_booking.quoted_amount IS NULL%',
  'captured payment finalization independently rejects a missing approved quote total'
);

SELECT * FROM finish();
ROLLBACK;
