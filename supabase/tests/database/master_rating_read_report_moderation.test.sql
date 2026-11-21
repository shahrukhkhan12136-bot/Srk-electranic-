BEGIN;
SELECT plan(15);
SELECT has_table('public','srk_master_rating_reports','rating subjects can report a review');
SELECT has_table('public','srk_master_rating_report_events','rating report decisions have an audit ledger');
SELECT has_function('public','srk_customer_list_master_rating_tasks',ARRAY[]::text[],'Customer can list their own completed booking rating tasks');
SELECT has_function('public','srk_technician_list_master_rating_tasks',ARRAY[]::text[],'Technician can list their own completed booking rating tasks');
SELECT has_function('public','srk_master_technician_rating_summary',ARRAY['uuid'],'published Technician rating aggregate exists');
SELECT has_function('public','srk_master_report_booking_rating',ARRAY['uuid','text','text'],'rating subject can report a rating');
SELECT has_function('public','srk_admin_list_master_booking_ratings',ARRAY['integer'],'Admin can list ratings for moderation');
SELECT has_function('public','srk_admin_list_master_rating_reports',ARRAY['integer'],'Admin can list rating reports');
SELECT has_function('public','srk_admin_resolve_master_rating_report',ARRAY['uuid','text','text'],'Admin can resolve rating reports');
SELECT ok(
 has_function_privilege('authenticated','public.srk_customer_list_master_rating_tasks()','EXECUTE')
 AND has_function_privilege('authenticated','public.srk_technician_list_master_rating_tasks()','EXECUTE')
 AND NOT has_function_privilege('anon','public.srk_customer_list_master_rating_tasks()','EXECUTE')
 AND NOT has_function_privilege('anon','public.srk_technician_list_master_rating_tasks()','EXECUTE'),
 'rating task lists require authenticated users'
);
SELECT ok(
 has_function_privilege('authenticated','public.srk_master_report_booking_rating(uuid,text,text)','EXECUTE')
 AND NOT has_function_privilege('anon','public.srk_master_report_booking_rating(uuid,text,text)','EXECUTE'),
 'rating reports require authenticated users'
);
SELECT ok(
 has_function_privilege('authenticated','public.srk_admin_list_master_booking_ratings(integer)','EXECUTE')
 AND has_function_privilege('authenticated','public.srk_admin_list_master_rating_reports(integer)','EXECUTE')
 AND has_function_privilege('authenticated','public.srk_admin_resolve_master_rating_report(uuid,text,text)','EXECUTE'),
 'Admin RPCs are callable by authenticated role and enforce Main Admin internally'
);
SELECT ok(
 (SELECT relrowsecurity FROM pg_class WHERE oid='public.srk_master_rating_reports'::regclass)
 AND (SELECT relrowsecurity FROM pg_class WHERE oid='public.srk_master_rating_report_events'::regclass),
 'rating report tables have RLS enabled'
);
SELECT has_trigger('public','srk_master_rating_report_events','srk_master_rating_report_events_append_only',
 'rating report audit events are append-only');
SELECT ok(
 position('ONLY_RATING_SUBJECT_CAN_REPORT' in pg_get_functiondef('public.srk_master_report_booking_rating(uuid,text,text)'::regprocedure))>0,
 'only the person who is the subject of a rating can report it'
);
SELECT * FROM finish();
ROLLBACK;
