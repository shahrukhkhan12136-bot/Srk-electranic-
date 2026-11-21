BEGIN;
SELECT plan(12);
SELECT has_column('public','srk_technician_application_skills','approved_level_code','verified skill can store its Admin-assigned level');
SELECT has_table('public','srk_master_booking_ratings','two-way booking ratings are stored');
SELECT has_table('public','srk_master_rating_moderation_events','rating moderation has an audit ledger');
SELECT has_function('public','srk_admin_set_technician_skill_level',ARRAY['uuid','text']);
SELECT has_function('public','srk_technician_list_my_85_percent_rates',ARRAY[]::text[]);
SELECT has_function('public','srk_technician_list_all_85_percent_rates',ARRAY[]::text[]);
SELECT has_function('public','srk_customer_rate_master_technician',ARRAY['uuid','uuid','smallint','text']);
SELECT has_function('public','srk_technician_rate_master_customer',ARRAY['uuid','smallint','text']);
SELECT has_function('public','srk_admin_moderate_master_rating',ARRAY['uuid','text','text']);
SELECT has_index('public','srk_master_booking_ratings','srk_master_customer_rating_per_technician_booking_uidx');
SELECT has_index('public','srk_master_booking_ratings','srk_master_technician_rating_per_booking_uidx');
SELECT ok(
  (SELECT relrowsecurity FROM pg_class WHERE oid='public.srk_master_booking_ratings'::regclass)
  AND NOT has_table_privilege('anon','public.srk_master_booking_ratings','SELECT')
  AND NOT has_table_privilege('authenticated','public.srk_master_booking_ratings','SELECT'),
  'rating rows are RLS protected and cannot be read directly by clients'
);
SELECT * FROM finish();
ROLLBACK;
