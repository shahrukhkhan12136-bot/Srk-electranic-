import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const form = readFileSync('apps/electrician_app/lib/worker_application_and_work_session.dart', 'utf8');
const pubspec = readFileSync('apps/electrician_app/pubspec.yaml', 'utf8');

test('Technician registration loads the selected category skills and category-specific qualification levels', () => {
  assert.match(form, /from\('srk_service_skills'\)/);
  assert.match(form, /from\('srk_skill_levels'\)/);
  assert.match(form, /Skill Level — Basic \/ Expert \/ Master/);
  assert.match(form, /srk_worker_submit_application_skill/);
  assert.match(form, /p_application_id/);
  assert.match(form, /p_skill_level_id/);
});

test('Technician registration attempts automatic state detection using the phone location', () => {
  assert.match(pubspec, /geolocator:/);
  assert.match(pubspec, /geocoding:/);
  assert.match(form, /placemarkFromCoordinates/);
  assert.match(form, /administrativeArea/);
  assert.match(form, /राज्य स्वतः भर दिया गया है/);
});

test('Worker registration keeps Terms and Privacy consent fail-closed', () => {
  assert.match(form, /srk_get_registration_policy_documents/);
  assert.match(form, /srk_record_registration_policy_consent/);
  assert.match(form, /if \(!hasPolicies\)/);
});
