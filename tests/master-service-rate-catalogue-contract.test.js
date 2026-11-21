const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve(__dirname, '..');
const migration = fs.readFileSync(path.join(root, 'supabase/migrations/20261121150000_master_service_rate_catalogue.sql'), 'utf8');

test('Master Rate Catalogue supports all service categories, skills, and service-specific offerings', () => {
  assert.match(migration, /CREATE TABLE IF NOT EXISTS public\.srk_service_offerings/);
  assert.match(migration, /category_code text NOT NULL REFERENCES public\.srk_service_categories/);
  assert.match(migration, /skill_code text NOT NULL REFERENCES public\.srk_service_skills/);
  assert.match(migration, /billing_model text NOT NULL CHECK \(billing_model IN \('hourly','fixed_per_unit'\)\)/);
  assert.match(migration, /ON CONFLICT\(service_code\) DO NOTHING/);
  assert.match(migration, /'ac_installation','AC Installation'/);
  assert.match(migration, /'ac_repair','AC Repair'/);
});

test('rate catalogue supports technician/helper hourly pay and fixed-per-unit labour prices', () => {
  assert.match(migration, /technician_hourly_paise bigint/);
  assert.match(migration, /helper_hourly_paise bigint NOT NULL DEFAULT 0/);
  assert.match(migration, /fixed_labour_paise bigint/);
  assert.match(migration, /RATE_FIELDS_DO_NOT_MATCH_BILLING_MODEL/);
});

test('only explicitly confirmed plumber rates are activated; unresolved category prices are not guessed', () => {
  assert.match(migration, /\('residential_plumbing','basic','Basic',10000,5000/);
  assert.match(migration, /\('residential_plumbing','expert','Expert',15000,7500/);
  assert.match(migration, /\('industrial_plumbing','master_industrial','Master \/ Industrial',22500,10000/);
  assert.doesNotMatch(migration, /\('residential_wiring',[\s\S]{0,120}'active'/);
  assert.match(migration, /Conflicting category prices are deliberately not activated/);
});

test('rate versions preserve history and only one active rate exists per service level', () => {
  assert.match(migration, /UNIQUE\(service_code,level_code,rate_version\)/);
  assert.match(migration, /srk_service_rates_one_active_level_uidx/);
  assert.match(migration, /ACTIVE_RATE_VALUES_ARE_IMMUTABLE_CREATE_A_NEW_VERSION/);
  assert.match(migration, /SERVICE_RATE_HISTORY_CANNOT_BE_DELETED/);
  assert.match(migration, /SERVICE_RATE_EVENTS_ARE_APPEND_ONLY/);
  assert.match(migration, /CREATE TABLE IF NOT EXISTS public\.srk_service_rate_events/);
});

test('customer rate lookup returns only active effective rates and Admin writes are Main Admin only', () => {
  assert.match(migration, /srk_customer_get_service_rate/);
  assert.match(migration, /srk_customer_list_active_service_rates/);
  assert.match(migration, /r\.status='active'/);
  assert.match(migration, /r\.effective_from<=clock_timestamp\(\)/);
  assert.match(migration, /public\.is_srk_admin\(\)/);
  assert.match(migration, /srk_admin_upsert_service_rate/);
  assert.match(migration, /SERVICE_IDENTITY_AND_BILLING_MODEL_ARE_IMMUTABLE_AFTER_RATE_HISTORY/);
  assert.match(migration, /srk_admin_list_service_rates/);
});

test('new booking schema stores canonical category, service, duration and immutable rate snapshots', () => {
  for (const field of [
    'srk_service_code','srk_rate_level_code','srk_rate_level_label_snapshot',
    'srk_rate_version_snapshot','srk_billing_model_snapshot',
    'srk_technician_hourly_paise_snapshot','srk_helper_hourly_paise_snapshot',
    'srk_fixed_labour_paise_snapshot','srk_estimated_labour_paise','srk_duration_minutes','srk_service_quantity'
  ]) assert.ok(migration.includes(field), 'missing booking snapshot field: ' + field);
  assert.match(migration, /service_bookings_srk_rate_snapshot_complete/);
  assert.match(migration, /DROP CONSTRAINT IF EXISTS service_bookings_estimate_matches_rate_card/);
  assert.match(migration, /Historical bookings retain their legacy rate columns and immutable snapshots/i);
});

test('Admin service offering and rate changes are audited and no direct client table access is granted', () => {
  assert.match(migration, /srk_admin_upsert_service_offering/);
  assert.match(migration, /srk_service_catalogue_events/);
  assert.match(migration, /srk_service_rate_events/);
  assert.match(migration, /REVOKE ALL ON TABLE public\.srk_service_offerings,public\.srk_service_rates/);
  assert.match(migration, /GRANT EXECUTE ON FUNCTION public\.srk_customer_list_active_service_rates\(\) TO anon,authenticated,service_role/);
});

test('rate catalogue migration has valid service/level identifiers and no duplicated SQL fragments', () => {
  assert.equal(migration.split('CREATE OR REPLACE FUNCTION public.srk_admin_upsert_service_offering').length - 1, 1);
  assert.equal(migration.split('CREATE OR REPLACE FUNCTION public.srk_admin_upsert_service_rate').length - 1, 1);
  assert.match(migration, /p_service_code !~/);
  assert.match(migration, /p_level_code !~/);
  assert.doesNotMatch(migration, /79} IS NULL|79}    OR/);
});
