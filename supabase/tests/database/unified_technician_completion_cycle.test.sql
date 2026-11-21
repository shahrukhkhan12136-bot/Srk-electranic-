BEGIN;
SELECT plan(14);

SELECT has_table('public','srk_technicians','canonical Technician identity table exists');
SELECT has_table('public','srk_technician_profile_links','legacy electrician profiles map to canonical Technician IDs');
SELECT has_table('public','srk_booking_technician_assignments','booking supports one or more Technician IDs');
SELECT has_table('public','srk_technician_booking_counters','per-Technician completed booking counter exists');
SELECT has_table('public','srk_technician_completed_booking_events','idempotent completion event ledger exists');

SELECT has_column('public','srk_technician_completed_booking_events','completion_ordinal',
  'each completed booking receives an immutable per-Technician ordinal');
SELECT has_column('public','srk_booking_technician_assignments','service_category_snapshot',
  'assignment retains the category snapshot');

SELECT has_trigger('public','service_bookings','srk_sync_legacy_electrician_assignment',
  'legacy electrician assignments are bridged to canonical Technician IDs');
SELECT has_trigger('public','service_bookings','srk_record_customer_confirmed_technician_completions',
  'customer-confirmed completion updates the Technician ledger');

SELECT ok(
  (SELECT prosecdef FROM pg_proc
   WHERE oid='public.srk_record_customer_confirmed_technician_completions()'::regprocedure),
  'completion ledger trigger runs in a privileged server-side context'
);
SELECT ok(
  NOT has_function_privilege('anon','public.srk_technician_get_completed_booking_count(uuid)','EXECUTE')
  AND has_function_privilege('authenticated','public.srk_technician_get_completed_booking_count(uuid)','EXECUTE'),
  'only authenticated users can call the guarded own-count RPC'
);
SELECT ok(
  position('new.customer_completed_at is null' in lower(pg_get_functiondef(
    'public.srk_record_customer_confirmed_technician_completions()'::regprocedure)))>0
  AND position('new.completion_approval_status is distinct from '||quote_literal('approved') in lower(pg_get_functiondef(
    'public.srk_record_customer_confirmed_technician_completions()'::regprocedure)))>0,
  'only customer-approved completed work with customer timestamp is counted'
);
SELECT ok(
  position('mod(v_ordinal,3)=0' in lower(pg_get_functiondef(
    'public.srk_record_customer_confirmed_technician_completions()'::regprocedure)))>0
  AND position('not v_online' in lower(pg_get_functiondef(
    'public.srk_record_customer_confirmed_technician_completions()'::regprocedure)))>0,
  'every third, sixth, ninth... completion requires an online payment method'
);
SELECT ok(
  position('for update' in lower(pg_get_functiondef(
    'public.srk_record_customer_confirmed_technician_completions()'::regprocedure)))=0
  AND position('completed_booking_count=completed_booking_count+1' in lower(pg_get_functiondef(
    'public.srk_record_customer_confirmed_technician_completions()'::regprocedure)))>0,
  'counter increments atomically through a row update and duplicate booking events are skipped'
);

SELECT * FROM finish();
ROLLBACK;
