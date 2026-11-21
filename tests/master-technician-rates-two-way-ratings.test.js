const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve(__dirname, '..');
const migration = fs.readFileSync(path.join(root, 'supabase/migrations/20261121250000_master_technician_rates_and_two_way_ratings.sql'), 'utf8');

test('Technician verified skill can be assigned an Admin-approved rate level', () => {
  assert.match(migration, /ADD COLUMN IF NOT EXISTS approved_level_code/);
  assert.match(migration, /srk_admin_set_technician_skill_level/);
  assert.match(migration, /public\.is_srk_admin\(\)/);
  assert.match(migration, /ACTIVE_RATE_FOR_VERIFIED_SKILL_LEVEL_REQUIRED/);
});

test('Technician personal 85 percent rate list is limited to own approved category, skill and level', () => {
  assert.match(migration, /srk_technician_list_my_85_percent_rates/);
  assert.match(migration, /aps\.review_status='approved' AND aps\.approved_level_code IS NOT NULL/);
  assert.match(migration, /a\.technician_id=v_tid AND a\.status='approved'/);
  assert.match(migration, /floor\(\(r\.technician_hourly_paise\+r\.helper_hourly_paise\)::numeric\*8\*0\.85\)/);
});

test('All-category Technician reference rate list shows 85 percent without granting skill eligibility', () => {
  assert.match(migration, /srk_technician_list_all_85_percent_rates/);
  assert.match(migration, /floor\(\(r\.technician_hourly_paise\+r\.helper_hourly_paise\)::numeric\*8\*0\.85\)/);
  assert.match(migration, /does not grant booking eligibility/i);
});

test('fixed-per-unit services display 85 percent of unit labour price rather than an hourly amount', () => {
  assert.match(migration, /fixed_share_85_paise/);
  assert.match(migration, /floor\(r\.fixed_labour_paise::numeric\*0\.85\)/);
});

test('two-way ratings are tied to completed booking participants and unique per side', () => {
  assert.match(migration, /srk_master_booking_ratings/);
  assert.match(migration, /b\.customer_user_id=v_uid AND b\.status='completed'/);
  assert.match(migration, /a\.technician_id=p_technician_id AND a\.assignment_status='completed'/);
  assert.match(migration, /a\.technician_id=v_tid AND a\.assignment_status='completed'/);
  assert.match(migration, /srk_master_customer_rating_per_technician_booking_uidx/);
  assert.match(migration, /srk_master_technician_rating_per_booking_uidx/);
});

test('ratings require 1 to 5 stars and cannot be submitted by unrelated users', () => {
  assert.match(migration, /p_stars NOT BETWEEN 1 AND 5/);
  assert.match(migration, /COMPLETED_BOOKING_PARTICIPATION_REQUIRED/);
  assert.match(migration, /customer_user_id=v_uid/);
  assert.match(migration, /auth_user_id=v_uid AND account_status='active'/);
});

test('Admin rating moderation requires a reason and keeps an immutable moderation event', () => {
  assert.match(migration, /srk_admin_moderate_master_rating/);
  assert.match(migration, /srk_master_rating_moderation_events/);
  assert.match(migration, /srk_master_rating_moderation_events_append_only/);
  assert.match(migration, /RATING_ALREADY_IN_TARGET_STATE/);
  assert.match(migration, /moderation_reason=CASE WHEN v_after='hidden'/);
});

test('private rating tables have RLS and no direct client table grants', () => {
  assert.match(migration, /ALTER TABLE public\.srk_master_booking_ratings ENABLE ROW LEVEL SECURITY/);
  assert.match(migration, /REVOKE ALL ON public\.srk_master_booking_ratings FROM PUBLIC,anon,authenticated/);
  assert.match(migration, /REVOKE ALL ON public\.srk_master_rating_moderation_events FROM PUBLIC,anon,authenticated/);
});
