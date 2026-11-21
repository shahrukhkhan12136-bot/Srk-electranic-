const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve(__dirname, '..');
const migration = fs.readFileSync(
  path.join(root, 'supabase/migrations/20261121170000_shared_technician_workday_timer.sql'),
  'utf8'
);

test('shared Technician timer records one independent customer-approved workday per Technician', () => {
  assert.match(migration, /UNIQUE\(booking_id,technician_id,work_date\)/);
  assert.match(migration, /auth_user_id=v_uid AND account_status='active'/);
  assert.match(migration, /TECHNICIAN_ACCEPTED_ASSIGNMENT_REQUIRED/);
  assert.match(migration, /TECHNICIAN_ACTIVE_BOOKING_PRESENCE_REQUIRED/);
  assert.match(migration, /CUSTOMER_LOGIN_REQUIRED/);
  assert.match(migration, /customer_approved_at=clock_timestamp\(\)/);
  assert.match(migration, /status='running'/);
});

test('timer supports pause, resume, stop and daily one-hour automatic lunch pause/resume', () => {
  for (const fn of [
    'srk_technician_pause_workday','srk_technician_resume_workday',
    'srk_technician_stop_workday','srk_private.srk_normalize_technician_workday_lunch'
  ]) assert.ok(migration.includes(fn));
  assert.match(migration, /v_elapsed<14400/);
  assert.match(migration, /v_lunch_end:=v_lunch_start\+interval '1 hour'/);
  assert.match(migration, /lunch_auto_paused/);
  assert.match(migration, /lunch_auto_resumed/);
});

test('daily normal and overtime work are calculated independently with 1.5x overtime', () => {
  assert.match(migration, /v_normal:=least\(v_elapsed,28800\)/);
  assert.match(migration, /v_overtime:=greatest\(v_elapsed-28800,0\)/);
  assert.match(migration, /v_tech_overtime_amount:=floor\(v_w\.technician_hourly_paise_snapshot\*v_w\.overtime_work_seconds\*1\.5\/3600\+0\.5\)/);
  assert.match(migration, /v_helper_overtime_amount:=CASE WHEN v_w\.helper_included_snapshot/);
});

test('customer must stop every active Technician and select one of the three daily decisions', () => {
  for (const decision of ['tomorrow','completed','replace_technician']) {
    assert.match(migration, new RegExp("'" + decision + "'"));
  }
  assert.match(migration, /ALL_ACTIVE_TECHNICIANS_MUST_STOP_THEIR_DAILY_WORK/);
  assert.match(migration, /customer_tomorrow_accepted/);
  assert.match(migration, /customer_technician_replaced/);
  assert.match(migration, /customer_completed/);
});

test('daily labour ledger and work events are append-only; replaced contributors retain completion count', () => {
  assert.match(migration, /TECHNICIAN_LABOUR_LEDGER_IS_IMMUTABLE/);
  assert.match(migration, /TECHNICIAN_WORK_EVENTS_ARE_APPEND_ONLY/);
  assert.match(migration, /assignment_status<>'replaced' OR EXISTS/);
  assert.match(migration, /srk_booking_technician_labour_ledger/);
  assert.match(migration, /TECHNICIAN_EVERY_THIRD_COMPLETED_BOOKING_REQUIRES_ONLINE_PAYMENT/);
});

test('timer APIs are authenticated and data tables are not directly exposed to clients', () => {
  assert.match(migration, /REVOKE ALL ON TABLE public\.srk_booking_technician_workdays/);
  assert.match(migration, /GRANT EXECUTE ON FUNCTION public\.srk_technician_request_workday_start\(uuid\) TO authenticated/);
  assert.match(migration, /GRANT EXECUTE ON FUNCTION public\.srk_customer_decide_workday\(uuid,date,text,uuid\) TO authenticated/);
});
