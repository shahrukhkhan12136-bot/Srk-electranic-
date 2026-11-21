const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve(__dirname, '..');
const app = fs.readFileSync(path.join(root, 'electrician.html'), 'utf8');
const migration = fs.readFileSync(
  path.join(root, 'supabase/migrations/20261114220000_admin_approved_electrician_relocation.sql'),
  'utf8'
);

function functionBody(source, name) {
  const start = source.indexOf('async function ' + name + '(');
  assert.ok(start >= 0, name + ' handler exists');
  const tail = source.slice(start + 1);
  const next = tail.search(/\n(?:async )?function\s+[A-Za-z0-9_$]+\s*\(/);
  return source.slice(start, next < 0 ? source.length : start + 1 + next);
}

test('electrician relocation form validates inputs and submits only the self-service request RPC', () => {
  const submit = functionBody(app, 'submitElectricianAreaChange');
  assert.match(submit, /state\.length<2\|\|district\.length<2/);
  assert.match(submit, /!\/\^\\d\{6\}\$\//);
  assert.match(submit, /reason\.length<10/);
  assert.match(submit, /confirm\(/);
  assert.match(submit, /srk_electrician_request_area_change/);
  assert.match(submit, /मंजूरी मिलने तक आपका मौजूदा क्षेत्र चालू रहेगा/);
  assert.doesNotMatch(submit, /\.update\(\s*\{\s*(state|district|pincode)\s*:/);
});

test('electrician relocation history is read through the owner-scoped list RPC and pending requests lock the form', () => {
  const history = functionBody(app, 'loadMyAreaChangeRequests');
  assert.match(history, /srk_electrician_list_my_area_requests/);
  assert.match(history, /rows\.some\(r=>r\.status==='pending'\)/);
  assert.match(history, /querySelectorAll\('input,textarea,button'\)/);
  assert.match(history, /esc\(r\.admin_note\)/);
});

test('relocation database request is authenticated, linked to the caller profile and permits one pending request', () => {
  assert.match(migration, /CREATE UNIQUE INDEX IF NOT EXISTS srk_electrician_one_pending_area_request[\s\S]*?WHERE status='pending'/);
  assert.match(migration, /WHERE user_id=v_uid AND auth_user_id=v_uid FOR UPDATE/);
  assert.match(migration, /GRANT EXECUTE ON FUNCTION public\.srk_electrician_request_area_change\(text,text,text,text\) TO authenticated/);
  assert.match(migration, /GRANT EXECUTE ON FUNCTION public\.srk_electrician_list_my_area_requests\(\) TO authenticated/);
});

test('only Admin approval changes the active service area and preserves accepted assignments', () => {
  const adminReview = migration.slice(migration.indexOf('CREATE OR REPLACE FUNCTION public.srk_admin_review_electrician_area_request'));
  assert.match(adminReview, /public\.is_srk_admin\(\)/);
  assert.match(adminReview, /p_decision NOT IN \('approved','rejected'\)/);
  assert.match(adminReview, /IF p_decision='approved' THEN[\s\S]*?UPDATE public\.electrician_profiles SET state=/);
  assert.match(adminReview, /status='offered' RETURNING booking_id/);
  assert.match(adminReview, /b\.assigned_electrician_id IS NULL/);
  assert.match(adminReview, /b\.status IN \('new','confirmed'\)/);
  assert.match(adminReview, /UPDATE srk_private\.srk_electrician_area_change_requests SET status=p_decision/);
});

test('uncertain relocation submission is reconciled against one new exact owner-scoped pending request', () => {
  const submit = functionBody(app, 'submitElectricianAreaChange');
  assert.match(submit, /srk_electrician_list_my_area_requests/);
  assert.match(submit, /const baselineIds=new Set\(before\.map\(row=>row\.id\)\)/);
  assert.match(submit, /!baselineIds\.has\(row\.id\)/);
  assert.match(submit, /row\.status==='pending'/);
  assert.match(submit, /normalized\(row\.requested_state\)===normalized\(state\)/);
  assert.match(submit, /normalized\(row\.requested_district\)===normalized\(district\)/);
  assert.match(submit, /row\.requested_pincode===pin/);
  assert.match(submit, /normalized\(row\.reason\)===normalized\(reason\)/);
  assert.match(submit, /confirmed\.length===1/);
  assert.match(submit, /डुप्लिकेट से बचने के लिए अभी दोबारा न भेजें/);
  assert.ok(submit.indexOf('srk_electrician_list_my_area_requests') < submit.indexOf('srk_electrician_request_area_change'),
    'baseline history is captured before creating the relocation request');
});
