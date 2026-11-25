'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');

const customer = fs.readFileSync('apps/customer_app/lib/main.dart', 'utf8');
const migration = fs.readFileSync('supabase/migrations/20261125115830_require_customer_terms_privacy_consent_before_profile.sql', 'utf8');
const admin = fs.readFileSync('admin.html', 'utf8');

test('Customer accepts current Hindi Terms and Privacy once while saving the first profile', () => {
  assert.match(customer, /CustomerProfileSetupPage/);
  assert.match(customer, /srk_get_registration_policy_documents/);
  assert.match(customer, /p_worker_type': 'customer'/);
  assert.match(customer, /srk_record_registration_policy_consent/);
  assert.match(customer, /नाम और सहमति सेव करें/);
  const bookingForm = customer.slice(customer.indexOf('class CustomerBookingFormPage'));
  assert.doesNotMatch(bookingForm, /Terms & Privacy Policy|srk_record_registration_policy_consent/);
});

test('Customer profile creation is blocked server-side until both current Hindi policies are accepted', () => {
  assert.match(migration, /audience_role='customer'/);
  assert.match(migration, /v_required_count<>2/);
  assert.match(migration, /c\.policy_document_id=v_policy\.id and c\.accepted=true/);
  assert.match(migration, /srk_customer_upsert_profile/);
});

test('Main Admin can publish separate Customer, Technician and Helper policy documents', () => {
  assert.match(admin, /adminPolicyManagementCard/);
  assert.match(admin, /value="customer"/);
  assert.match(admin, /value="technician"/);
  assert.match(admin, /value="helper"/);
  assert.match(admin, /srk_admin_publish_policy_document/);
});

test('Customer booking does not ask for repeated Terms or Privacy consent', () => {
  const bookingForm = customer.slice(customer.indexOf('class CustomerBookingFormPage'));
  assert.doesNotMatch(bookingForm, /_policyLoading|_hasPolicyConsent|Terms & Privacy Policy|srk_record_registration_policy_consent/);
  assert.match(customer, /srk_customer_has_current_policy_consent/);
});

test('Customer language preference is saved to the signed-in profile; booking UI stays Hindi', () => {
  assert.match(customer, /customer_language/);
  assert.match(customer, /DropdownMenuItem\(value: 'hi'/);
  assert.match(customer, /DropdownMenuItem\(value: 'en'/);
  assert.match(customer, /बुकिंग फॉर्म और सर्विस विवरण हिंदी में ही रहेंगे/);
});

test('Customer booking cards show the server-authoritative running work timer', () => {
  assert.match(customer, /work_timer_elapsed_seconds/);
  assert.match(customer, /work_started_at/);
  assert.match(customer, /work_timer_running/);
  assert.match(customer, /_customerTimerText\(booking\)/);
  assert.match(customer, /Timer\.periodic\(const Duration\(seconds: 1\)/);
});
