BEGIN;
SELECT plan(9);

SELECT is(
  (SELECT count(*) FROM private.srk_booking_offer_events WHERE offer_id='40000000-0000-4000-8000-000000000001'),
  2::bigint,
  'migration backfills both creation and accepted lifecycle events for an existing offer'
);
SELECT is(
  (SELECT actor_role FROM private.srk_booking_offer_events WHERE offer_id='40000000-0000-4000-8000-000000000001' AND event_type='offer_accepted'),
  'electrician',
  'backfilled acceptance is attributed to the electrician role'
);

UPDATE public.job_offers
SET status='cancelled', responded_at='2026-11-03T10:00:00Z'
WHERE id='40000000-0000-4000-8000-000000000001';

SELECT is(
  (SELECT count(*) FROM private.srk_booking_offer_events WHERE offer_id='40000000-0000-4000-8000-000000000001' AND event_type='offer_cancelled'),
  1::bigint,
  'status transition to cancelled creates one lifecycle event'
);
SELECT is(
  (SELECT actor_role FROM private.srk_booking_offer_events WHERE offer_id='40000000-0000-4000-8000-000000000001' AND event_type='offer_cancelled'),
  'system',
  'unauthenticated database transition is attributed to system'
);

-- A same-status UPDATE must not create another lifecycle event.
UPDATE public.job_offers SET status='cancelled'
WHERE id='40000000-0000-4000-8000-000000000001';
SELECT is(
  (SELECT count(*) FROM private.srk_booking_offer_events WHERE offer_id='40000000-0000-4000-8000-000000000001' AND event_type='offer_cancelled'),
  1::bigint,
  'no-op status update does not duplicate the cancellation event'
);

INSERT INTO public.job_offers (id,booking_id,electrician_id,status,created_at)
VALUES (
  '40000000-0000-4000-8000-000000000003',
  '10000000-0000-4000-8000-000000000001',
  '30000000-0000-4000-8000-000000000001',
  'offered',
  '2026-11-04T10:00:00Z'
);
SELECT is(
  (SELECT count(*) FROM private.srk_booking_offer_events WHERE offer_id='40000000-0000-4000-8000-000000000003' AND event_type='offer_created'),
  1::bigint,
  'new offer inserted after migration creates its event'
);

SET LOCAL ROLE authenticated;
SET LOCAL request.jwt.claim.sub = '20000000-0000-4000-8000-000000000001';
SELECT results_eq(
  'SELECT DISTINCT booking_id FROM public.srk_customer_get_my_booking_offer_timeline() ORDER BY booking_id',
  $$VALUES ('10000000-0000-4000-8000-000000000001'::uuid)$$,
  'customer one sees only their own booking timeline'
);

RESET ROLE;
SET LOCAL ROLE authenticated;
SET LOCAL request.jwt.claim.sub = '20000000-0000-4000-8000-000000000002';
SELECT results_eq(
  'SELECT DISTINCT booking_id FROM public.srk_customer_get_my_booking_offer_timeline() ORDER BY booking_id',
  $$VALUES ('10000000-0000-4000-8000-000000000002'::uuid)$$,
  'customer two sees only their own booking timeline'
);

SELECT * FROM finish();
ROLLBACK;
