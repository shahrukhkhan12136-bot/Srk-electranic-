BEGIN;
SELECT plan(14);

SELECT has_column('public','service_bookings','selected_category','canonical customer-selected category column exists');
SELECT has_column('public','service_bookings','selected_duration_hours','customer-selected duration column exists');

SELECT ok(
  (SELECT is_nullable='YES' FROM information_schema.columns
   WHERE table_schema='public' AND table_name='service_bookings' AND column_name='selected_category'),
  'legacy bookings remain nullable and are not backfilled by inference'
);
SELECT ok(
  (SELECT is_nullable='YES' FROM information_schema.columns
   WHERE table_schema='public' AND table_name='service_bookings' AND column_name='selected_duration_hours'),
  'legacy duration remains nullable'
);
SELECT ok(
  EXISTS (SELECT 1 FROM pg_constraint
          WHERE conrelid='public.service_bookings'::regclass
            AND conname='service_bookings_selected_category_valid'),
  'category allowlist constraint exists'
);
SELECT ok(
  EXISTS (SELECT 1 FROM pg_constraint
          WHERE conrelid='public.service_bookings'::regclass
            AND conname='service_bookings_selected_duration_hours_valid')
  AND EXISTS (SELECT 1 FROM pg_constraint
          WHERE conrelid='public.service_bookings'::regclass
            AND conname='service_bookings_category_duration_pair'),
  'duration range and paired-null legacy constraints exist'
);


SELECT has_function('public','srk_admin_offer_booking',ARRAY['uuid'],'Admin booking offer RPC remains available');
SELECT has_function('public','srk_get_my_offer_details',ARRAY[]::text[],'Electrician offer details RPC remains available');
SELECT ok(
  pg_get_functiondef('private.srk_offer_booking_to_eligible_electricians(uuid)'::regprocedure) ILIKE '%approved_rate_tier IS NOT NULL%'
  AND pg_get_functiondef('private.srk_offer_booking_to_eligible_electricians(uuid)'::regprocedure) ILIKE '%approved_rate_card_version IS NOT NULL%'
  AND pg_get_functiondef('private.srk_offer_booking_to_eligible_electricians(uuid)'::regprocedure) ILIKE '%rate_tier_approved_by IS NOT NULL%'
  AND pg_get_functiondef('private.srk_offer_booking_to_eligible_electricians(uuid)'::regprocedure) ILIKE '%rate_tier_approved_at IS NOT NULL%',
  'offers require the complete Admin-approved commercial rate-tier tuple'
);
SELECT ok(
  pg_get_functiondef('private.srk_offer_booking_to_eligible_electricians(uuid)'::regprocedure) ILIKE '%e.pincode=v_booking.pincode%'
  AND pg_get_functiondef('private.srk_offer_booking_to_eligible_electricians(uuid)'::regprocedure) ILIKE '%e.district%'
  AND pg_get_functiondef('private.srk_offer_booking_to_eligible_electricians(uuid)'::regprocedure) ILIKE '%e.active=true%'
  AND pg_get_functiondef('private.srk_offer_booking_to_eligible_electricians(uuid)'::regprocedure) ILIKE '%e.verification_status=''approved''%',
  'PIN/district matching retains active and KYC-approved eligibility'
);
SELECT ok(
  pg_get_functiondef('public.srk_get_my_offer_details()'::regprocedure) ILIKE '%b.selected_category%'
  AND pg_get_functiondef('public.srk_get_my_offer_details()'::regprocedure) ILIKE '%b.selected_duration_hours%',
  'electrician offer details return customer work category and booked duration'
);
SELECT ok(
  pg_get_functiondef('public.srk_get_my_offer_details()'::regprocedure) ILIKE '%p.approved_rate_tier%'
  AND pg_get_functiondef('public.srk_get_my_offer_details()'::regprocedure) ILIKE '%p.rate_tier_approved_at IS NOT NULL%',
  'electrician offer details return only the approved commercial rate tier'
);
SELECT ok(
  pg_get_functiondef('public.srk_get_my_offer_details()'::regprocedure) ILIKE '%b.assigned_electrician_id=p.id%'
  AND pg_get_functiondef('public.srk_get_my_offer_details()'::regprocedure) ILIKE '%THEN b.phone ELSE NULL%',
  'customer phone remains hidden before offer assignment'
);
SELECT ok(
  pg_get_functiondef('public.srk_admin_offer_booking(uuid)'::regprocedure) NOT ILIKE '%requested_category = v_booking.selected_category%',
  'applicant requested commercial tier is not equated with customer work category'
);

SELECT * FROM finish();
ROLLBACK;
