const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const migration = fs.readFileSync(
  path.join(__dirname, '..', 'supabase/migrations/20261121130000_shared_technician_otp_onboarding.sql'),
  'utf8'
);

test('shared Technician application derives identity from verified Supabase Auth, not request phone', () => {
  assert.match(migration, /auth\.users u WHERE u\.id=v_uid/);
  assert.match(migration, /v_verified_at IS NULL/);
  assert.match(migration, /verified_phone/);
  assert.match(migration, /CREATE UNIQUE INDEX IF NOT EXISTS srk_technicians_verified_phone_uidx/);
  assert.match(migration, /srk_technician_submit_application\([\s\S]*?p_category_codes text\[\],p_skill_codes text\[\]/);
  assert.doesNotMatch(
    migration.match(/CREATE OR REPLACE FUNCTION public\.srk_technician_submit_application\([\s\S]*?\$function\$/)?.[0] || '',
    /p_phone|p_mobile|body\.phone/i
  );
});

test('six service categories are seeded and category/skill catalogue remains Admin configurable', () => {
  for (const category of ['electrician','plumber','painter','ac_fridge_technician','motor_pump','cooler']) {
    assert.match(migration, new RegExp(`'${category}'`));
  }
  assert.match(migration, /srk_admin_upsert_service_category/);
  assert.match(migration, /srk_admin_upsert_service_skill/);
  assert.match(migration, /srk_service_catalogue_events/);
});

test('AC and Fridge skills are independently assessed', () => {
  assert.match(migration, /'ac_technician','AC Technician',true/);
  assert.match(migration, /'fridge_technician','Fridge Technician',true/);
  assert.match(migration, /ALL_SELECTED_TECHNICIAN_SKILLS_REQUIRE_SEPARATE_ADMIN_APPROVAL/);
});

test('Technician KYC uses a private bucket, owner-scoped paths and metadata validation', () => {
  assert.match(migration, /'srk-technician-verification','srk-technician-verification',false/);
  assert.match(migration, /storage\.foldername\(name\)\)\[1\]=auth\.uid\(\)::text/);
  assert.match(migration, /UPLOADED_PRIVATE_KYC_OBJECT_NOT_FOUND/);
  assert.match(migration, /file_size_bytes bigint NOT NULL CHECK \(file_size_bytes BETWEEN 1 AND 5242880\)/);
  assert.match(migration, /mime_type NOT IN \('application\/pdf','image\/jpeg','image\/png'\)/);
});

test('applications cannot be approved before latest identity/address KYC and all skills pass', () => {
  assert.match(migration, /LATEST_IDENTITY_AND_ADDRESS_KYC_MUST_BE_APPROVED/);
  assert.match(migration, /ALL_SELECTED_TECHNICIAN_SKILLS_REQUIRE_SEPARATE_ADMIN_APPROVAL/);
  assert.match(migration, /rejection_reason text CHECK/);
  assert.match(migration, /p_decision='rejected' AND length\(v_reason\) NOT BETWEEN 5 AND 1000/);
});

test('application and KYC histories are append-only and direct client table access is revoked', () => {
  assert.match(migration, /TECHNICIAN_HISTORY_IS_APPEND_ONLY/);
  assert.match(migration, /srk_technician_application_events_append_only/);
  assert.match(migration, /srk_technician_kyc_events_append_only/);
  assert.match(migration, /FROM PUBLIC,anon,authenticated/);
});
