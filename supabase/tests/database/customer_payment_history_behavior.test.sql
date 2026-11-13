BEGIN;
SELECT plan(8);
INSERT INTO public.service_bookings(id,customer_user_id,payment_method,payment_status,amount_paid,payment_verified_at,created_at) VALUES
 ('10000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001','razorpay','paid',150,'2026-11-13T07:00:00Z','2026-11-13T06:00:00Z'),
 ('10000000-0000-4000-8000-000000000002','20000000-0000-4000-8000-000000000001','cash','paid',200,'2026-11-13T08:00:00Z','2026-11-13T07:00:00Z'),
 ('10000000-0000-4000-8000-000000000003','20000000-0000-4000-8000-000000000002','online','paid',999,'2026-11-13T09:00:00Z','2026-11-13T08:00:00Z');
INSERT INTO public.srk_manual_payment_entries(id,booking_id,amount,payment_method,recorded_at)
VALUES('30000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000002',200,'cash','2026-11-13T08:30:00Z');
INSERT INTO public.srk_booking_refund_requests(id,booking_id,customer_user_id,amount,reason,status,created_at,updated_at)
VALUES('40000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000001',
 '20000000-0000-4000-8000-000000000001',150,'Synthetic customer refund reason','requested',
 '2026-11-13T10:00:00Z','2026-11-13T10:05:00Z');
INSERT INTO public.srk_razorpay_refunds(id,booking_id,amount,status,created_at,updated_at,processed_at)
VALUES('50000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000001',50,'processed',
 '2026-11-13T10:10:00Z','2026-11-13T10:15:00Z','2026-11-13T10:20:00Z');
INSERT INTO public.srk_manual_refund_entries(id,payment_entry_id,amount,recorded_at)
VALUES('60000000-0000-4000-8000-000000000001','30000000-0000-4000-8000-000000000001',20,'2026-11-13T10:30:00Z');

SET LOCAL ROLE authenticated;
SET LOCAL request.jwt.claim.sub = '20000000-0000-4000-8000-000000000001';
SELECT is((SELECT count(*) FROM public.srk_customer_get_payment_history(50,0)),5::bigint,
 'customer one sees their five distinct payment/refund events');
SELECT ok(NOT EXISTS(SELECT 1 FROM public.srk_customer_get_payment_history(50,0)
 WHERE booking_id='10000000-0000-4000-8000-000000000003'),
 'customer one never sees another customer booking');
SELECT is((SELECT count(*) FROM public.srk_customer_get_payment_history(50,0)
 WHERE booking_id='10000000-0000-4000-8000-000000000002' AND event_type='payment'),0::bigint,
 'manual payment audit suppresses duplicate booking payment event');
SELECT is((SELECT count(*) FROM public.srk_customer_get_payment_history(50,0)
 WHERE booking_id='10000000-0000-4000-8000-000000000002' AND event_type='manual_payment'),1::bigint,
 'audited manual payment is represented once as manual_payment');
SELECT results_eq(
 'SELECT event_type FROM public.srk_customer_get_payment_history(50,0) ORDER BY occurred_at DESC,event_id DESC',
 $$VALUES ('manual_refund'::text),('refund'::text),('refund_request'::text),('manual_payment'::text),('payment'::text)$$,
 'all five event types appear in deterministic newest-first order');
SELECT is((SELECT count(*) FROM public.srk_customer_get_payment_history(2,1)),2::bigint,
 'payment history limit and offset return the requested page size');
SET LOCAL request.jwt.claim.sub = '20000000-0000-4000-8000-000000000002';
SELECT is((SELECT count(*) FROM public.srk_customer_get_payment_history(50,0)),1::bigint,
 'customer two sees only their own payment event');
SELECT ok(NOT EXISTS(SELECT 1 FROM public.srk_customer_get_payment_history(50,0)
 WHERE booking_id<>'10000000-0000-4000-8000-000000000003'),
 'customer two cannot see customer one refund or payment events');
RESET ROLE;
SELECT * FROM finish();
ROLLBACK;
