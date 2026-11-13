BEGIN;
SELECT plan(15);

INSERT INTO public.service_bookings(
  id,status,payment_method,payment_status,selected_category,completion_approval_status
) VALUES (
  '10000000-0000-4000-8000-000000000001','completed',
  'Razorpay ऑनलाइन भुगतान','unpaid','electrical_repair','approved'
);
INSERT INTO public.srk_booking_labour_bills(booking_id,labour_amount_paise)
VALUES ('10000000-0000-4000-8000-000000000001',12345);

SELECT set_config('request.jwt.claims','{"role":"service_role"}',true);
CREATE TEMP TABLE payment_order_test_state(lock_token uuid) ON COMMIT DROP;
INSERT INTO payment_order_test_state
SELECT public.srk_claim_payment_order_lock('10000000-0000-4000-8000-000000000001');

SELECT ok((SELECT lock_token IS NOT NULL FROM payment_order_test_state),
  'service role can claim a payment-order lock for an approved labour bill');
SELECT is(
  public.srk_claim_payment_order_lock('10000000-0000-4000-8000-000000000001'),
  NULL::uuid,
  'a second active order attempt cannot claim the same booking lock'
);

SELECT throws_ok(
  $$SELECT public.srk_link_payment_order(
    '10000000-0000-4000-8000-000000000001',
    (SELECT lock_token FROM payment_order_test_state),
    'order_srkfixture001',12344
  )$$,
  'P0001','Order amount does not match approved bill',
  'order linking rejects even a one-paise amount mismatch'
);

SELECT lives_ok(
  $$SELECT public.srk_link_payment_order(
    '10000000-0000-4000-8000-000000000001',
    (SELECT lock_token FROM payment_order_test_state),
    'order_srkfixture001',12345
  )$$,
  'valid order is linked to the exact immutable labour amount'
);
SELECT is((SELECT payment_status FROM public.service_bookings
  WHERE id='10000000-0000-4000-8000-000000000001'),'pending'::text,
  'successful order linking marks payment pending');
SELECT is((SELECT razorpay_order_id FROM public.service_bookings
  WHERE id='10000000-0000-4000-8000-000000000001'),'order_srkfixture001'::text,
  'successful order linking stores the Razorpay order ID');

SELECT throws_ok(
  $$SELECT public.srk_service_finalize_captured_payment(
    '10000000-0000-4000-8000-000000000001','order_srkfixture001',
    'pay_srkfixture001',12344,'INR'
  )$$,
  'P0001','Captured amount does not match approved booking amount',
  'captured payment rejects a one-paise mismatch'
);

SELECT lives_ok(
  $$SELECT public.srk_service_finalize_captured_payment(
    '10000000-0000-4000-8000-000000000001','order_srkfixture001',
    'pay_srkfixture001',12345,'INR'
  )$$,
  'valid captured payment finalizes atomically');
SELECT is((SELECT payment_status FROM public.service_bookings
  WHERE id='10000000-0000-4000-8000-000000000001'),'paid'::text,
  'finalization records paid state');
SELECT is((SELECT razorpay_payment_id FROM public.service_bookings
  WHERE id='10000000-0000-4000-8000-000000000001'),'pay_srkfixture001'::text,
  'finalization records the verified payment ID');

SELECT is(
  public.srk_service_finalize_captured_payment(
    '10000000-0000-4000-8000-000000000001','order_srkfixture001',
    'pay_srkfixture001',12345,'INR')->>'already_processed',
  'true'::text,
  'retrying the same captured payment is idempotent'
);
SELECT throws_ok(
  $$SELECT public.srk_service_finalize_captured_payment(
    '10000000-0000-4000-8000-000000000001','order_srkfixture001',
    'pay_srkfixture002',12345,'INR'
  )$$,
  '23505','A different payment is already recorded',
  'a different payment ID cannot replace the recorded payment'
);

INSERT INTO public.service_bookings(
  id,status,payment_method,payment_status,quote_status,service_charge,materials_amount,quoted_amount
) VALUES (
  '10000000-0000-4000-8000-000000000002','completed',
  'Razorpay ऑनलाइन भुगतान','unpaid','approved',100,20,NULL
);
TRUNCATE payment_order_test_state;
INSERT INTO payment_order_test_state
SELECT public.srk_claim_payment_order_lock('10000000-0000-4000-8000-000000000002');
SELECT ok((SELECT lock_token IS NOT NULL FROM payment_order_test_state),
  'legacy approved booking can claim a lock before amount reconciliation');
SELECT throws_ok(
  $$SELECT public.srk_link_payment_order(
    '10000000-0000-4000-8000-000000000002',
    (SELECT lock_token FROM payment_order_test_state),
    'order_srkfixture002',12000
  )$$,
  'P0001','Legacy approved quote does not reconcile',
  'legacy order linking rejects a NULL quoted_amount instead of bypassing reconciliation'
);

SELECT set_config('request.jwt.claims','{"role":"authenticated"}',true);
SELECT throws_ok(
  $$SELECT public.srk_claim_payment_order_lock('10000000-0000-4000-8000-000000000002')$$,
  '42501','Service role only',
  'authenticated JWT cannot invoke the service-only order lock RPC'
);

SELECT * FROM finish();
ROLLBACK;
