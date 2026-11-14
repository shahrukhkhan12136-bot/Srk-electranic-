BEGIN;
SELECT plan(13);

SELECT has_column('public','job_offers','expires_at',
  'job offers carry a server-side expiry deadline');
SELECT has_table('srk_private','srk_booking_offer_dispatch',
  'private dispatch state table exists');
SELECT has_table('srk_private','srk_booking_offer_candidates',
  'private ordered candidate queue exists');
SELECT has_function('private','srk_dispatch_next_booking_offer',ARRAY['uuid'],
  'private next-offer dispatcher exists');
SELECT has_function('private','srk_offer_booking_to_eligible_electricians',ARRAY['uuid'],
  'initial matching and queue builder exists');
SELECT has_function('public','srk_expire_and_advance_booking_offers',ARRAY[]::text[],
  'scheduled expiry worker RPC exists');
SELECT has_trigger('public','service_bookings','broadcast_new_booking',
  'new bookings start the offer dispatcher exactly once');

SELECT ok(
  has_function_privilege('service_role','public.srk_expire_and_advance_booking_offers()','EXECUTE')
  AND NOT has_function_privilege('authenticated','public.srk_expire_and_advance_booking_offers()','EXECUTE')
  AND NOT has_function_privilege('anon','public.srk_expire_and_advance_booking_offers()','EXECUTE'),
  'only the service role can run the expiry worker RPC'
);
SELECT ok(
  NOT has_table_privilege('authenticated','srk_private.srk_booking_offer_dispatch','SELECT')
  AND NOT has_table_privilege('authenticated','srk_private.srk_booking_offer_candidates','SELECT'),
  'authenticated users cannot read the private dispatch queue'
);
SELECT ok(
  position('6371000*asin' in lower(pg_get_functiondef(
    'private.srk_offer_booking_to_eligible_electricians(uuid)'::regprocedure
  )))>0,
  'candidate order uses geographic distance when both sides have coordinates'
);
SELECT ok(
  position('e.approved_rate_tier=v_booking.selected_rate_tier' in lower(pg_get_functiondef(
    'private.srk_offer_booking_to_eligible_electricians(uuid)'::regprocedure
  )))>0,
  'candidate selection requires exact customer-selected commercial tier'
);
SELECT ok(
  position('insert into public.job_offers(booking_id,electrician_id,status,match_level,expires_at)' in lower(pg_get_functiondef(
    'private.srk_dispatch_next_booking_offer(uuid)'::regprocedure
  )))>0
  AND position('return jsonb_build_object' in lower(pg_get_functiondef(
    'private.srk_dispatch_next_booking_offer(uuid)'::regprocedure
  )))>0,
  'dispatcher creates one current offer and returns before issuing another'
);
SELECT ok(
  position('status=''declined''' in lower(pg_get_functiondef(
    'public.srk_respond_to_offer(uuid,text)'::regprocedure
  )))>0
  AND position('srk_dispatch_next_booking_offer' in lower(pg_get_functiondef(
    'public.srk_respond_to_offer(uuid,text)'::regprocedure
  )))>0,
  'declining an offer advances to the next candidate'
);
SELECT ok(
  position('expires_at<=clock_timestamp()' in lower(pg_get_functiondef(
    'public.srk_expire_and_advance_booking_offers()'::regprocedure
  )))>0
  AND position('srk_dispatch_next_booking_offer' in lower(pg_get_functiondef(
    'public.srk_expire_and_advance_booking_offers()'::regprocedure
  )))>0,
  'expired offers advance to the next candidate'
);

SELECT * FROM finish();
ROLLBACK;
