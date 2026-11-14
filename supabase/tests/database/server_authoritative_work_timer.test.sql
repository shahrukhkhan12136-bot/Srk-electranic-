BEGIN;
SELECT plan(18);

SELECT has_column('public','service_bookings','work_timer_elapsed_seconds','server accumulated timer seconds are stored');
SELECT has_column('public','service_bookings','work_started_at','server timer start timestamp is stored');
SELECT has_column('public','service_bookings','labour_rate_tier_snapshot','approved commercial tier is snapshotted at start');
SELECT has_column('public','service_bookings','labour_rate8h_paise_snapshot','approved eight-hour rate is snapshotted in paise');
SELECT has_table('public','srk_booking_labour_bills','immutable final labour bill table exists');
SELECT has_table('srk_private','work_timer_authorizations','private timer authorization table exists');
SELECT has_table('srk_private','work_transition_authorizations','private status transition authorization table exists');

SELECT has_function('public','srk_electrician_request_work_start',ARRAY['uuid'],'electrician can request customer permission to start');
SELECT has_function('public','srk_customer_respond_work_start',ARRAY['uuid','text'],'customer controls timer start');
SELECT has_function('public','srk_electrician_request_work_completion',ARRAY['uuid'],'electrician submits completion using server time');
SELECT has_function('public','srk_customer_respond_work_completion',ARRAY['uuid','text','text'],'customer approves, rejects or disputes completion');
SELECT has_function('public','srk_customer_get_labour_bill',ARRAY['uuid'],'customer can read only own final labour bill');
SELECT has_function('public','srk_electrician_get_labour_bill',ARRAY['uuid'],'assigned electrician can read final labour bill');

SELECT has_trigger('public','service_bookings','srk_guard_server_work_timer','client writes cannot set timer or rate snapshots');
SELECT has_trigger('public','srk_booking_labour_bills','srk_guard_immutable_booking_labour_bill','final labour bills are immutable');

SELECT ok(
  position('floor(b.labour_rate8h_paise_snapshot::numeric*v_minutes/480+0.5)' in lower(pg_get_functiondef('public.srk_customer_respond_work_completion(uuid,text,text)'::regprocedure)))>0,
  'final labour uses actual billable minutes and integer-paise half-up rounding'
);
SELECT ok(
  position('v_booking.selected_category is not null' in lower(pg_get_functiondef('public.srk_submit_booking_quote(uuid,numeric,numeric,text)'::regprocedure)))>0
  AND position('नई बुकिंग' in pg_get_functiondef('public.srk_submit_booking_quote(uuid,numeric,numeric,text)'::regprocedure))>0
  AND position('v_booking.selected_category is not null' in lower(pg_get_functiondef('public.srk_update_booking_work_status(uuid,text)'::regprocedure)))>0,
  'new category bookings cannot use legacy quote or direct status RPCs'
);
SELECT ok(
  NOT has_function_privilege('anon','public.srk_customer_respond_work_start(uuid,text)','EXECUTE')
  AND NOT has_function_privilege('anon','public.srk_electrician_request_work_start(uuid)','EXECUTE')
  AND NOT has_function_privilege('anon','public.srk_customer_respond_work_completion(uuid,text,text)','EXECUTE'),
  'anonymous users cannot invoke protected work lifecycle RPCs'
);

SELECT * FROM finish();
ROLLBACK;
