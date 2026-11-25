'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');

const app = fs.readFileSync('apps/electrician_app/lib/main.dart', 'utf8');
const workerModules = fs.readFileSync('apps/electrician_app/lib/worker_application_and_work_session.dart', 'utf8');
const pubspec = fs.readFileSync('apps/electrician_app/pubspec.yaml', 'utf8');
const migration = fs.readFileSync('supabase/migrations/20261125113624_worker_registration_policy_consent_gate.sql', 'utf8');
const financialMigration = fs.readFileSync('supabase/migrations/20261125115348_worker_financial_details_include_final_bill_id_for_dynamic_qr.sql', 'utf8');

test('Technician app exposes the existing authenticated registration form when no approved profile exists', () => {
  assert.match(app, /import 'worker_application_and_work_session\.dart';/);
  assert.match(app, /WorkerApplicationPage\(onSubmitted: load\)/);
  assert.match(app, /srk_worker_applications/);
  assert.match(workerModules, /srk_submit_worker_application/);
  assert.match(workerModules, /srk_submit_worker_document/);
  assert.match(workerModules, /srk_record_registration_policy_consent/);
});

test('Technician app connects the GPS work-session controls to active assignments', () => {
  assert.match(app, /WorkerWorkSessionPanel\(/);
  assert.match(app, /assignmentId: booking\['assignment_id'\]\.toString\(\)/);
  assert.match(workerModules, /srk_worker_open_work_session/);
  assert.match(workerModules, /srk_worker_record_session_location/);
  assert.match(workerModules, /srk_worker_session_action/);
  assert.match(workerModules, /srk_worker_complete_assignment/);
});

test('Worker app declares the file and GPS packages used by registration and work sessions', () => {
  assert.match(pubspec, /file_picker:/);
  assert.match(pubspec, /geolocator:/);
});

test('Worker application submission is blocked unless current Hindi Terms and Privacy consent exists', () => {
  assert.match(migration, /srk_require_worker_registration_policy_consent/);
  assert.match(migration, /v_required_count<>2/);
  assert.match(migration, /c\.accepted=true/);
});

test('Technician bill detail can generate a final-bill-specific Razorpay QR for onsite UPI payment', () => {
  assert.match(app, /create-razorpay-dynamic-qr/);
  assert.match(app, /final_bill_id/);
  assert.match(app, /On-site QR बनाएँ/);
  assert.match(financialMigration, /'final_bill_id',fb\.id/);
});
