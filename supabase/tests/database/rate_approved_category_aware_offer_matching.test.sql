BEGIN;
SELECT plan(8);

SELECT has_function('public','srk_admin_offer_booking',ARRAY['uuid'],'Admin booking offer RPC remains available');
SELECT has_function('public','srk_get_my_offer_details',ARRAY[]::text[],'Electrician offer details RPC remains available');

SELECT ok(
  pg_get_functiondef('public.srk_admin_offer_booking(uuid)'::regprocedure) ILIKE '%approved_rate_tier IS NOT NULL%'
  AND pg_get_functiondef('public.srk_admin_offer_booking(uuid)'::regprocedure) ILIKE '%approved_rate_card_version IS NOT NULL%'
  AND pg_get_functiondef('public.srk_admin_offer_booking(uuid)'::regprocedure) ILIKE '%rate_tier_approved_by IS NOT NULL%'
  AND pg_get_functiondef('public.srk_admin_offer_booking(uuid)'::regprocedure) ILIKE '%rate_tier_approved_at IS NOT NULL%',
  'offers require the full Admin-approved commercial rate-tier tuple'
);

SELECT ok(
  pg_get_functiondef('public.srk_admin_offer_booking(uuid)'::regprocedure) ILIKE '%e.pincode = v_booking.pincode%'
  AND pg_get_functiondef('public.srk_admin_offer_booking(uuid)'::regprocedure) ILIKE '%e.district%'
  AND pg_get_functiondef('public.srk_admin_offer_booking(uuid)'::regprocedure) ILIKE '%e.active = true%'
  AND pg_get_functiondef('public.srk_admin_offer_booking(uuid)'::regprocedure) ILIKE '%e.verification_status = ''approved''%',
  'geographic matching retains active, KYC-approved PIN/district rules'
);

SELECT ok(
  pg_get_functiondef('public.srk_get_my_offer_details()'::regprocedure) ILIKE '%b.selected_category%'
  AND pg_get_functiondef('public.srk_get_my_offer_details()'::regprocedure) ILIKE '%b.selected_duration_hours%',
  'electrician offer RPC returns customer-selected work category and booked duration'
);

SELECT ok(
  pg_get_functiondef('public.srk_get_my_offer_details()'::regprocedure) ILIKE '%p.approved_rate_tier%'
  AND pg_get_functiondef('public.srk_get_my_offer_details()'::regprocedure) ILIKE '%p.rate_tier_approved_at IS NOT NULL%',
  'electrician offer RPC returns only own approved tier for eligible profile'
);

SELECT ok(
  pg_get_functiondef('public.srk_get_my_offer_details()'::regprocedure) ILIKE '%b.assigned_electrician_id = p.id%'
  AND pg_get_functiondef('public.srk_get_my_offer_details()'::regprocedure) ILIKE '%THEN b.phone ELSE NULL%',
  'customer phone remains hidden until booking assignment'
);

SELECT ok(
  pg_get_functiondef('public.srk_admin_offer_booking(uuid)'::regprocedure) NOT ILIKE '%requested_category = v_booking.selected_category%',
  'applicant commercial request is not incorrectly equated with customer work category'
);

SELECT * FROM finish();
ROLLBACK;
