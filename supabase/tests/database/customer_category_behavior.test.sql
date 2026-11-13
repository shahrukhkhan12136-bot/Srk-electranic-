BEGIN;
SELECT plan(10);

INSERT INTO public.service_bookings(id,status,service_type,state,district,pincode,customer_name,phone,address)
VALUES
 ('11000000-0000-4000-8000-000000000001','new','पुरानी free-form category','Uttar Pradesh','Balrampur','271861','Fixture Customer','9000000001','Synthetic address'),
 ('11000000-0000-4000-8000-000000000002','new','legacy service','Uttar Pradesh','Balrampur','271862','Fixture Customer','9000000002','Synthetic address'),
 ('11000000-0000-4000-8000-000000000003','new','legacy service','Uttar Pradesh','Balrampur','271863','Fixture Customer','9000000003','Synthetic address');

INSERT INTO public.electrician_profiles(
 id,user_id,auth_user_id,approved_rate_tier,approved_rate_card_version,
 rate_tier_approved_by,rate_tier_approved_at,pincode,state,district
) VALUES
 ('31000000-0000-4000-8000-000000000001','21000000-0000-4000-8000-000000000001','21000000-0000-4000-8000-000000000001','skilled_electrician','SRK-RATE-V1','21000000-0000-4000-8000-000000000099',now(),'271861','Uttar Pradesh','Balrampur'),
 ('31000000-0000-4000-8000-000000000002','21000000-0000-4000-8000-000000000002','21000000-0000-4000-8000-000000000002','expert_electrician','SRK-RATE-V1','21000000-0000-4000-8000-000000000099',now(),'271861','Uttar Pradesh','Balrampur'),
 ('31000000-0000-4000-8000-000000000003','21000000-0000-4000-8000-000000000003','21000000-0000-4000-8000-000000000003',NULL,NULL,NULL,NULL,'271863','Uttar Pradesh','Balrampur');

-- Legacy booking remains unclassified and is not guessed from service_type.
SELECT is((SELECT selected_category::text FROM public.service_bookings WHERE id='11000000-0000-4000-8000-000000000001'),NULL::text,
 'legacy booking category remains NULL');
SELECT is((SELECT selected_duration_hours::text FROM public.service_bookings WHERE id='11000000-0000-4000-8000-000000000001'),NULL::text,
 'legacy booking duration remains NULL');

SELECT lives_ok(
 $$UPDATE public.service_bookings SET selected_category='electrical_repair',selected_duration_hours=3
   WHERE id='11000000-0000-4000-8000-000000000001'$$,
 'valid category and whole-hour duration are accepted'
);
SELECT throws_ok(
 $$UPDATE public.service_bookings SET selected_category='unknown'
   WHERE id='11000000-0000-4000-8000-000000000001'$$,
 '23514',NULL,'unknown customer category is rejected');
SELECT throws_ok(
 $$UPDATE public.service_bookings SET selected_duration_hours=9
   WHERE id='11000000-0000-4000-8000-000000000001'$$,
 '23514',NULL,'duration above eight hours is rejected');
SELECT throws_ok(
 $$UPDATE public.service_bookings SET selected_duration_hours=NULL
   WHERE id='11000000-0000-4000-8000-000000000001'$$,
 '23514',NULL,'category and duration must be present or absent together');

SELECT set_config('request.jwt.claims','{"role":"service_role","sub":"21000000-0000-4000-8000-000000000099"}',true);
SELECT is(
 (public.srk_admin_offer_booking('11000000-0000-4000-8000-000000000001')->>'offers_created')::integer,
 2,'Admin offer path selects only complete approved rate-tier partners at the matching PIN'
);
SELECT is(
 (SELECT count(*)::integer FROM public.job_offers WHERE booking_id='11000000-0000-4000-8000-000000000001' AND match_level='pincode'),
 2,'same-PIN offers are created and classified as PIN matches'
);
SELECT is(
 (public.srk_admin_offer_booking('11000000-0000-4000-8000-000000000003')->>'eligible_count')::integer,
 0,'partner without complete approved rate tier is not eligible'
);
SELECT is(
 (public.srk_admin_offer_booking('11000000-0000-4000-8000-000000000002')->>'match_level')::text,
 'district','when no PIN match exists the matching path falls back to same district'
);

SELECT * FROM finish();
ROLLBACK;
