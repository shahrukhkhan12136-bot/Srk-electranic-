BEGIN;
SELECT plan(34);

SELECT has_column('public','service_bookings','work_timer_seconds','timer seconds use bigint storage');
SELECT has_column('public','service_bookings','work_timer_elapsed_seconds','exact accumulated server elapsed seconds stored');
SELECT has_column('public','service_bookings','work_start_origin_status','rejected start request restores prior state');
SELECT has_column('public','service_bookings','labour_rate_tier_snapshot','commercial rate tier snapshotted per booking');
SELECT has_column('public','service_bookings','labour_rate8h_paise_snapshot','eight-hour rate snapshotted in integer paise');
SELECT has_column('public','service_bookings','labour_rate_card_version_snapshot','rate card version snapshotted per booking');
SELECT has_table('public','srk_booking_labour_bills','final labour bill snapshot table exists');
SELECT ok((SELECT relrowsecurity FROM pg_class WHERE oid='public.srk_booking_labour_bills'::regclass),'final bill table RLS enabled');
SELECT ok(NOT has_table_privilege('anon','public.srk_booking_labour_bills','SELECT')
  AND NOT has_table_privilege('authenticated','public.srk_booking_labour_bills','SELECT'),
  'final bill table has no direct client SELECT');
SELECT has_table('srk_private','work_timer_authorizations','timer updates use private transaction authorization');
SELECT ok(NOT has_table_privilege('anon','srk_private.work_timer_authorizations','SELECT')
  AND NOT has_table_privilege('authenticated','srk_private.work_timer_authorizations','INSERT')
  AND NOT has_table_privilege('authenticated','srk_private.work_timer_authorizations','UPDATE')
  AND NOT has_table_privilege('authenticated','srk_private.work_timer_authorizations','DELETE'),
  'timer authorization table is inaccessible to client roles');

SELECT ok(EXISTS(SELECT 1 FROM pg_trigger WHERE tgname='srk_guard_server_work_timer'
  AND tgrelid='public.service_bookings'::regclass AND NOT tgisinternal),
  'server timer authorization trigger installed');
SELECT ok((SELECT prosecdef FROM pg_proc WHERE oid='public.srk_guard_server_work_timer()'::regprocedure),
  'timer guard executes with protected definer context');
SELECT ok(NOT EXISTS(SELECT 1 FROM pg_constraint WHERE conrelid='public.service_bookings'::regclass
  AND pg_get_constraintdef(oid) ILIKE '%604800%'),
  'seven-day timer cap constraint removed');

SELECT has_function('public','srk_electrician_request_work_start',ARRAY['uuid'],'electrician start request RPC exists');
SELECT has_function('public','srk_customer_respond_work_start',ARRAY['uuid','text'],'customer start approval RPC exists');
SELECT has_function('public','srk_electrician_request_work_completion',ARRAY['uuid'],'electrician completion request RPC exists');
SELECT has_function('public','srk_customer_respond_work_completion',ARRAY['uuid','text','text'],'customer completion decision RPC exists');
SELECT has_function('public','srk_customer_get_labour_bill',ARRAY['uuid'],'customer final bill RPC exists');
SELECT has_function('public','srk_electrician_get_labour_bill',ARRAY['uuid'],'electrician final bill RPC exists');

SELECT ok(pg_get_functiondef('public.srk_electrician_request_work_start(uuid)'::regprocedure)
  ILIKE '%selected_category IS NOT NULL%' AND
  pg_get_functiondef('public.srk_electrician_request_work_start(uuid)'::regprocedure)
  ILIKE '%work_start_origin_status%',
  'new categorized bookings can request start without a quote and retain origin state');
SELECT ok(pg_get_functiondef('public.srk_customer_respond_work_start(uuid,text)'::regprocedure)
  ILIKE '%approved_rate_tier%' AND
  pg_get_functiondef('public.srk_customer_respond_work_start(uuid,text)'::regprocedure)
  ILIKE '%labour_rate8h_paise_snapshot%',
  'customer approval snapshots the assigned electrician approved commercial rate');
SELECT ok(pg_get_functiondef('public.srk_customer_respond_work_start(uuid,text)'::regprocedure)
  ILIKE '%work_started_at=clock_timestamp()%' AND
  pg_get_functiondef('public.srk_customer_respond_work_start(uuid,text)'::regprocedure)
  ILIKE '%work_timer_running=true%',
  'timer starts only on customer approval using database clock');
SELECT ok(pg_get_functiondef('public.srk_electrician_request_work_completion(uuid)'::regprocedure)
  ILIKE '%work_timer_elapsed_seconds%' AND
  pg_get_functiondef('public.srk_electrician_request_work_completion(uuid)'::regprocedure)
  NOT ILIKE '%604800%',
  'completion accumulates exact elapsed time without a seven-day cap');
SELECT ok(pg_get_functiondef('public.srk_electrician_request_work_completion(uuid)'::regprocedure)
  ILIKE '%clock_timestamp()%' AND
  pg_get_functiondef('public.srk_electrician_request_work_completion(uuid)'::regprocedure)
  ILIKE '%FOR UPDATE%',
  'completion uses server clock and booking row lock');
SELECT ok(pg_get_functiondef('public.srk_customer_respond_work_completion(uuid,text,text)'::regprocedure)
  ILIKE '%ceil(v_booking.work_timer_elapsed_seconds/60)%',
  'any positive partial minute rounds up to the next billable minute');
SELECT ok(pg_get_functiondef('public.srk_customer_respond_work_completion(uuid,text,text)'::regprocedure)
  ILIKE '%floor(%+0.5%',
  'final monetary paise use half-up rounding');
SELECT ok(pg_get_functiondef('public.srk_customer_respond_work_completion(uuid,text,text)'::regprocedure)
  ILIKE '%INSERT INTO public.srk_booking_labour_bills%' AND
  pg_get_functiondef('public.srk_customer_respond_work_completion(uuid,text,text)'::regprocedure)
  ILIKE '%p_response=''approved''%',
  'final bill snapshot is created only on customer-approved completion');
SELECT ok(pg_get_functiondef('public.srk_customer_respond_work_completion(uuid,text,text)'::regprocedure)
  ILIKE '%p_response=''disputed''%' AND
  pg_get_functiondef('public.srk_customer_respond_work_completion(uuid,text,text)'::regprocedure)
  ILIKE '%completion_approval_status=''disputed''%',
  'disputed completion stops timer and does not enter approved-bill branch');
SELECT ok(pg_get_functiondef('public.srk_customer_get_labour_bill(uuid)'::regprocedure)
  ILIKE '%customer_user_id=auth.uid()%' AND
  pg_get_functiondef('public.srk_electrician_get_labour_bill(uuid)'::regprocedure)
  ILIKE '%electrician_profile_id=v_profile_id%',
  'customer and electrician bill reads are owner-scoped');
SELECT ok(pg_get_functiondef('public.srk_customer_get_labour_bill(uuid)'::regprocedure)
  NOT ILIKE '%phone%' AND
  pg_get_functiondef('public.srk_electrician_get_labour_bill(uuid)'::regprocedure)
  NOT ILIKE '%materials%',
  'final labour bill RPCs expose neither phone nor materials fields');
SELECT ok(NOT has_function_privilege('anon','public.srk_customer_get_labour_bill(uuid)','EXECUTE')
  AND has_function_privilege('authenticated','public.srk_customer_get_labour_bill(uuid)','EXECUTE'),
  'final bill RPC is authenticated-only');
SELECT ok(pg_get_functiondef('public.srk_guard_server_work_timer()'::regprocedure)
  ILIKE '%work_timer_authorizations%' AND
  pg_get_functiondef('public.srk_guard_server_work_timer()'::regprocedure)
  ILIKE '%auth.uid()%',
  'direct timer/rate snapshot edits require transaction-scoped actor authorization');
SELECT ok(pg_get_functiondef('public.srk_customer_respond_work_completion(uuid,text,text)'::regprocedure)
  ILIKE '%work_timer_authorizations%' AND
  pg_get_functiondef('public.srk_customer_respond_work_completion(uuid,text,text)'::regprocedure)
  ILIKE '%work_transition_authorizations%',
  'customer completion keeps both timer and status-transition authorization guards');

SELECT * FROM finish();
ROLLBACK;
