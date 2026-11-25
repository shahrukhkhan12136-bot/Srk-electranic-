'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');

const customer = fs.readFileSync('apps/customer_app/lib/main.dart', 'utf8');
const migration = fs.readFileSync('supabase/migrations/20261125115830_require_customer_terms_privacy_consent_before_profile.sql', 'utf8');
const admin = fs.readFileSync('admin.html', 'utf8');

test('Customer booking registration loads, displays and records current Hindi Terms and Privacy consent', () => {
  assert.match(customer, /srk_get_registration_policy_documents/);
  assert.match(customer, /p_worker_type': 'customer'/);
  assert.match(customer, /Terms & Privacy Policy/);
  assert.match(customer, /_hasPolicyConsent/);
  assert.match(customer, /srk_record_registration_policy_consent/);
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

test('Customer booking form fails closed while policy loading or consent is missing', () => {
  assert.match(customer, /_policyLoading \|\| !_hasPolicyConsent/);
  assert.match(customer, /वर्तमान Hindi Terms और Privacy Policy/);
});
