BEGIN;
SELECT plan(12);

SELECT has_table('public','srk_booking_work_events','append-only booking work event history table exists');
SELECT has_column('public','srk_booking_work_events','actor_user_id','work events retain the actor user id');
SELECT has_column('public','srk_booking_work_events','old_state','work events retain prior lifecycle state');
SELECT has_column('public','srk_booking_work_events','new_state','work events retain new lifecycle state');
SELECT has_index('public','srk_booking_work_events','srk_booking_work_events_booking_created_idx','booking event history is indexed by booking and time');
SELECT has_trigger('public','service_bookings','srk_capture_booking_work_event','booking lifecycle changes are captured automatically');
SELECT has_function('public','srk_capture_booking_work_event',ARRAY[]::text[],'event capture function exists');
SELECT has_function('public','srk_admin_get_booking_work_review',ARRAY['uuid'],'Admin can retrieve work history and dispute review');
SELECT ok(
  NOT has_table_privilege('anon','public.srk_booking_work_events','SELECT')
  AND NOT has_table_privilege('authenticated','public.srk_booking_work_events','SELECT'),
  'work event history is not directly readable by browser roles'
);
SELECT ok(
  NOT has_function_privilege('anon','public.srk_admin_get_booking_work_review(uuid)','EXECUTE'),
  'anonymous users cannot invoke Admin review RPC'
);
SELECT ok(
  position('public.is_srk_admin()' in pg_get_functiondef('public.srk_admin_get_booking_work_review(uuid)'::regprocedure))>0,
  'Admin review RPC explicitly checks Admin authorization'
);
SELECT ok(
  position('to_regclass' in pg_get_functiondef('public.srk_admin_get_booking_work_review(uuid)'::regprocedure))>0
  AND position('srk_booking_complaints' in pg_get_functiondef('public.srk_admin_get_booking_work_review(uuid)'::regprocedure))>0,
  'complaint data is loaded only when the complaint table exists'
);

SELECT * FROM finish();
ROLLBACK;
