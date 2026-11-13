BEGIN;
SELECT plan(21);

SELECT has_table('public','srk_booking_work_events','append-only work event history table exists');
SELECT ok((SELECT relrowsecurity FROM pg_class WHERE oid='public.srk_booking_work_events'::regclass),
  'work event history has RLS enabled');
SELECT ok(NOT has_table_privilege('anon','public.srk_booking_work_events','SELECT')
  AND NOT has_table_privilege('authenticated','public.srk_booking_work_events','SELECT')
  AND NOT has_table_privilege('authenticated','public.srk_booking_work_events','INSERT'),
  'client roles cannot directly read or write work event history');
SELECT ok((SELECT pg_get_triggerdef(oid) ILIKE '%BEFORE UPDATE OR DELETE%'
  FROM pg_trigger WHERE tgrelid='public.srk_booking_work_events'::regclass
    AND tgname='srk_guard_immutable_booking_work_event'),
  'work event history rejects updates and deletes');
SELECT ok((SELECT pg_get_triggerdef(oid) ILIKE '%AFTER INSERT OR UPDATE%'
  FROM pg_trigger WHERE tgrelid='public.service_bookings'::regclass
    AND tgname='srk_capture_booking_work_event'),
  'booking timer and approval transitions automatically create audit events');
SELECT has_function('public','srk_admin_approve_work_completion',ARRAY['uuid','text'],
  'Admin completion approval RPC exists');
SELECT ok(NOT has_function_privilege('anon','public.srk_admin_approve_work_completion(uuid,text)','EXECUTE')
  AND has_function_privilege('authenticated','public.srk_admin_approve_work_completion(uuid,text)','EXECUTE'),
  'Admin completion approval RPC is authenticated-only');
SELECT ok(pg_get_functiondef('public.srk_admin_approve_work_completion(uuid,text)'::regprocedure)
  ILIKE '%is_srk_admin()%' AND pg_get_functiondef('public.srk_admin_approve_work_completion(uuid,text)'::regprocedure)
  ILIKE '%FOR UPDATE%',
  'Admin approval requires Admin authorization and locks the booking row');
SELECT ok(pg_get_functiondef('public.srk_admin_approve_work_completion(uuid,text)'::regprocedure)
  ILIKE '%completion_requested_at%' AND pg_get_functiondef('public.srk_admin_approve_work_completion(uuid,text)'::regprocedure)
  ILIKE '%work_timer_elapsed_seconds%',
  'Admin bill uses the stored completion-request time and stopped server elapsed duration');
SELECT ok(pg_get_functiondef('public.srk_admin_approve_work_completion(uuid,text)'::regprocedure)
  ILIKE '%20 AND 1000%' AND pg_get_functiondef('public.srk_admin_approve_work_completion(uuid,text)'::regprocedure)
  ILIKE '%details%',
  'Admin decision requires a reason and records its audit details');
SELECT ok(pg_get_functiondef('public.srk_admin_approve_work_completion(uuid,text)'::regprocedure)
  ILIKE '%srk_booking_labour_bills%' AND pg_get_functiondef('public.srk_admin_approve_work_completion(uuid,text)'::regprocedure)
  ILIKE '%work_timer_authorizations%',
  'Admin resolution creates a protected immutable bill through scoped authorization');
SELECT ok(pg_get_functiondef('public.srk_guard_immutable_booking_labour_bill()'::regprocedure)
  ILIKE '%completion_approval_status NOT IN (''pending'',''disputed'')%'
  AND pg_get_functiondef('public.srk_guard_immutable_booking_labour_bill()'::regprocedure)
  ILIKE '%NEW.completion_requested_at%',
  'bill guard supports customer-pending and Admin-reviewed disputed requests without replacing request time');
SELECT has_column('public','srk_booking_labour_bills','completion_requested_at',
  'final bill stores the original completion request timestamp');
SELECT has_function('public','srk_admin_get_booking_work_events',ARRAY['uuid'],
  'Admin work-event history read RPC exists');
SELECT ok(NOT has_function_privilege('anon','public.srk_admin_get_booking_work_events(uuid)','EXECUTE')
  AND has_function_privilege('authenticated','public.srk_admin_get_booking_work_events(uuid)','EXECUTE'),
  'work-event history read RPC is authenticated-only');
SELECT ok(pg_get_functiondef('public.srk_admin_get_booking_work_events(uuid)'::regprocedure)
  ILIKE '%is_srk_admin()%' AND pg_get_functiondef('public.srk_admin_get_booking_work_events(uuid)'::regprocedure)
  ILIKE '%ORDER BY e.occurred_at%',
  'only Admin can read chronologically ordered booking work events');
SELECT ok(pg_get_functiondef('public.srk_capture_booking_work_event()'::regprocedure)
  ILIKE '%auth.uid()%' AND pg_get_functiondef('public.srk_capture_booking_work_event()'::regprocedure)
  ILIKE '%completion_requested_at%',
  'event history records authenticated actor and server completion request timestamp');
SELECT ok(pg_get_functiondef('public.srk_admin_approve_work_completion(uuid,text)'::regprocedure)
  ILIKE '%platform_fee_paise%' AND pg_get_functiondef('public.srk_admin_approve_work_completion(uuid,text)'::regprocedure)
  ILIKE '%electrician_payable%',
  'Admin approval retains separate Platform Fee and electrician net calculations');
SELECT ok(pg_get_functiondef('public.srk_customer_respond_work_completion(uuid,text,text)'::regprocedure)
  ILIKE '%completion_requested_at%' AND
  pg_get_functiondef('public.srk_customer_respond_work_completion(uuid,text,text)'::regprocedure)
  ILIKE '%work_timer_elapsed_seconds%',
  'customer-approved final bill preserves the original completion-request timestamp');
SELECT ok(position('completion_requested_at' in pg_get_functiondef(
  'public.srk_customer_respond_work_completion(uuid,text,text)'::regprocedure))>0,
  'customer completion RPC is replaced after adding the immutable bill timestamp column');

SELECT ok(
  pg_get_functiondef('public.srk_customer_get_labour_bill(uuid)'::regprocedure) ILIKE '%completion_requested_at%'
  AND pg_get_functiondef('public.srk_electrician_get_labour_bill(uuid)'::regprocedure) ILIKE '%completion_requested_at%'
  AND pg_get_functiondef('public.srk_admin_get_labour_bill(uuid)'::regprocedure) ILIKE '%completion_requested_at%',
  'customer, assigned electrician, and Admin bill reads expose the original completion-request timestamp');

SELECT * FROM finish();
ROLLBACK;
