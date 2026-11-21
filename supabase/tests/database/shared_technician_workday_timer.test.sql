BEGIN;
SELECT plan(19);

SELECT has_table('public','srk_booking_technician_workdays',
  'each assigned Technician has an independent daily work record');
SELECT has_table('public','srk_booking_technician_work_events',
  'work timer transitions are stored as an event history');
SELECT has_column('public','service_bookings','srk_helper_included_snapshot',
  'booking snapshots whether one helper is included with each assigned Technician');
SELECT has_column('public','srk_booking_technician_workdays','helper_hourly_paise_snapshot',
  'daily workday freezes the helper hourly rate');
SELECT has_column('public','srk_booking_technician_labour_ledger','helper_total_paise',
  'daily ledger separates optional helper earnings');
SELECT has_table('public','srk_booking_technician_labour_ledger',
  'daily Technician labour is recorded in an immutable ledger');
SELECT has_table('public','srk_booking_workday_customer_decisions',
  'customer daily decision is stored once per booking and date');
SELECT has_function('public','srk_technician_request_workday_start',ARRAY['uuid']::text[]);
SELECT has_function('public','srk_customer_respond_technician_workday_start',ARRAY['uuid','text']::text[]);
SELECT has_function('public','srk_technician_pause_workday',ARRAY['uuid']::text[]);
SELECT has_function('public','srk_technician_resume_workday',ARRAY['uuid']::text[]);
SELECT has_function('public','srk_technician_stop_workday',ARRAY['uuid']::text[]);
SELECT has_function('public','srk_customer_get_technician_workdays',ARRAY['uuid']::text[]);
SELECT has_function('public','srk_technician_get_workday',ARRAY['uuid']::text[]);
SELECT has_function('public','srk_customer_decide_workday',ARRAY['uuid','date','text','uuid']::text[]);
SELECT has_trigger('public','srk_booking_technician_work_events','srk_booking_technician_work_events_append_only');
SELECT has_trigger('public','srk_booking_technician_labour_ledger','srk_booking_technician_labour_ledger_immutable');
SELECT ok(
  position('v_normal:=least(v_elapsed,28800)' in pg_get_functiondef(
    'public.srk_technician_stop_workday(uuid)'::regprocedure
  ))>0
  AND position('v_overtime:=greatest(v_elapsed-28800,0)' in pg_get_functiondef(
    'public.srk_technician_stop_workday(uuid)'::regprocedure
  ))>0,
  'daily first eight hours are normal and time beyond eight hours is overtime'
);
SELECT ok(
  position('interval ''1 hour''' in pg_get_functiondef(
    'srk_private.srk_normalize_technician_workday_lunch(uuid)'::regprocedure
  ))>0
  AND position('lunch_auto_resumed' in pg_get_functiondef(
    'srk_private.srk_normalize_technician_workday_lunch(uuid)'::regprocedure
  ))>0,
  'one-hour lunch pause is excluded and automatically resumed by server time'
);

SELECT * FROM finish();
ROLLBACK;
