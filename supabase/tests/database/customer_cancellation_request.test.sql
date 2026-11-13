-- Customer cancellation request intake and Admin review queue contract.
BEGIN;
SELECT plan(23);

SELECT has_table('public','srk_booking_cancellation_requests','request table exists');
SELECT has_table('public','srk_booking_cancellation_request_events','append-only event table exists');
SELECT ok((SELECT relrowsecurity FROM pg_class WHERE oid='public.srk_booking_cancellation_requests'::regclass),'request table has RLS enabled');
SELECT ok(NOT has_table_privilege('authenticated','public.srk_booking_cancellation_requests','SELECT'),'clients cannot directly read request rows');
SELECT ok(NOT has_table_privilege('authenticated','public.srk_booking_cancellation_request_events','INSERT'),'clients cannot forge audit events');

SELECT has_function('public','srk_customer_request_booking_cancellation',ARRAY['uuid','text','uuid'],'customer request RPC exists');
SELECT has_function('public','srk_customer_list_my_booking_cancellation_requests',ARRAY['integer','integer'],'customer own-history RPC exists');
SELECT has_function('public','srk_admin_list_booking_cancellation_requests',ARRAY[]::text[],'Admin queue RPC exists');
SELECT has_function('public','srk_admin_start_booking_cancellation_review',ARRAY['uuid','text'],'Admin review-start RPC exists');
SELECT ok(has_function_privilege('authenticated','public.srk_customer_request_booking_cancellation(uuid,text,uuid)','EXECUTE'),'authenticated can invoke customer request RPC');
SELECT ok(NOT has_function_privilege('anon','public.srk_customer_request_booking_cancellation(uuid,text,uuid)','EXECUTE'),'anon cannot invoke customer request RPC');
SELECT ok(position('customer_user_id=v_uid' in pg_get_functiondef('public.srk_customer_request_booking_cancellation(uuid,text,uuid)'::regprocedure))>0,'customer request enforces booking ownership');
SELECT ok(position('payment_status' in pg_get_functiondef('public.srk_customer_request_booking_cancellation(uuid,text,uuid)'::regprocedure))>0,'customer request blocks payment states pending reconciliation');
SELECT ok(position('srk_booking_labour_bills' in pg_get_functiondef('public.srk_customer_request_booking_cancellation(uuid,text,uuid)'::regprocedure))>0,'customer request blocks bookings with final labour bill');
SELECT ok(position('public.is_srk_admin()' in pg_get_functiondef('public.srk_admin_start_booking_cancellation_review(uuid,text)'::regprocedure))>0,'review-start RPC is Admin gated');
SELECT ok((SELECT (tgtype & 2)=2 AND (tgtype & 8)=8 AND (tgtype & 16)=16 FROM pg_trigger WHERE tgname='srk_guard_immutable_booking_cancellation_request_event'),'audit event mutation is blocked by a BEFORE UPDATE OR DELETE trigger');

SET LOCAL ROLE supabase_auth_admin;
INSERT INTO auth.users(id,aud,role) VALUES
 ('00000000-0000-4000-8000-000000000001','authenticated','authenticated'),
 ('00000000-0000-4000-8000-000000000002','authenticated','authenticated');
RESET ROLE;
INSERT INTO public.service_bookings(id,customer_user_id,status,payment_status)
VALUES
 ('10000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-000000000001','new','unpaid'),
 ('10000000-0000-4000-8000-000000000002','00000000-0000-4000-8000-000000000001','new','paid'),
 ('10000000-0000-4000-8000-000000000003','00000000-0000-4000-8000-000000000001','in_progress','unpaid'),
 ('10000000-0000-4000-8000-000000000004','00000000-0000-4000-8000-000000000002','new','unpaid');
SELECT set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000001',true);
SELECT set_config('test.srk_admin','false',true);

SELECT is(
 (public.srk_customer_request_booking_cancellation(
  '10000000-0000-4000-8000-000000000001',
  'ग्राहक ने सेवा की आवश्यकता समाप्त होने के कारण अनुरोध भेजा है।',
  '20000000-0000-4000-8000-000000000001'
 )->>'status'),'requested','eligible owner can create a request');
SELECT throws_ok(
 $$SELECT public.srk_customer_request_booking_cancellation(
  '10000000-0000-4000-8000-000000000004',
  'यह किसी दूसरे ग्राहक की बुकिंग के लिए गलत अनुरोध है।',
  '20000000-0000-4000-8000-000000000002')$$,
 '42501','BOOKING_NOT_FOUND_OR_NOT_OWNED','another customer booking is rejected');
SELECT throws_ok(
 $$SELECT public.srk_customer_request_booking_cancellation(
  '10000000-0000-4000-8000-000000000002',
  'ग्राहक ने सेवा की आवश्यकता समाप्त होने के कारण अनुरोध भेजा है।',
  '20000000-0000-4000-8000-000000000003')$$,
 '55000','BOOKING_STATE_REQUIRES_ADMIN_RECONCILIATION','paid booking is rejected');
SELECT throws_ok(
 $$SELECT public.srk_customer_request_booking_cancellation(
  '10000000-0000-4000-8000-000000000003',
  'ग्राहक ने सेवा की आवश्यकता समाप्त होने के कारण अनुरोध भेजा है।',
  '20000000-0000-4000-8000-000000000004')$$,
 '55000','BOOKING_STATE_REQUIRES_ADMIN_RECONCILIATION','in-progress booking is rejected');

SELECT set_config('test.srk_admin','true',true);
SELECT is(
 (public.srk_admin_start_booking_cancellation_review(
  (SELECT id FROM public.srk_booking_cancellation_requests LIMIT 1),
  'Admin ने उपलब्ध रिकॉर्ड की प्रारंभिक जाँच शुरू की है।'
 )->>'status'),'in_review','Admin can start review without cancelling booking');
SELECT is((SELECT status FROM public.service_bookings WHERE id='10000000-0000-4000-8000-000000000001'),
 'new','review start does not cancel the booking');
SELECT is((SELECT count(*)::integer FROM public.srk_booking_cancellation_request_events),2,
 'customer request and Admin review each append one audit event');

SELECT * FROM finish();
ROLLBACK;
