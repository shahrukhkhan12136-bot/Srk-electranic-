// Static security and UI regression tests for electrician verification documents.
const assert = require("node:assert/strict");
const fs = require("node:fs");
const vm = require("node:vm");
const migration = fs.readFileSync("supabase/migrations/20261110050000_electrician_verification_documents.sql", "utf8");
const electrician = fs.readFileSync("electrician.html", "utf8");
const admin = fs.readFileSync("admin.html", "utf8");

assert.match(migration, /'srk-electrician-verification',[\s\S]*false[\s\S]*5242880/i);
assert.match(migration, /CREATE POLICY srk_electrician_verification_upload[\s\S]*auth\.uid\(\)/i);
assert.match(migration, /CREATE POLICY srk_electrician_verification_read[\s\S]*public\.is_srk_admin\(\)/i);
assert.match(migration, /CREATE TABLE IF NOT EXISTS public\.srk_electrician_verification_documents/i);
assert.match(migration, /CREATE TABLE IF NOT EXISTS public\.srk_electrician_verification_events/i);
assert.match(migration, /REVOKE ALL ON TABLE public\.srk_electrician_verification_documents FROM PUBLIC,anon,authenticated/i);
assert.match(migration, /REVOKE ALL ON TABLE public\.srk_electrician_verification_events FROM PUBLIC,anon,authenticated/i);
assert.match(migration, /auth_user_id=v_uid AND user_id=v_uid/i);
assert.match(migration, /storage\.objects[\s\S]*bucket_id='srk-electrician-verification'/i);
assert.match(migration, /auth\.uid\(\) IS NULL OR NOT public\.is_srk_admin\(\)/i);
assert.match(migration, /Latest identity and address proof documents must both be approved/i);
assert.match(migration, /REVOKE UPDATE ON TABLE public\.electrician_profiles FROM authenticated/i);
assert.match(migration, /REVOKE UPDATE \(active\) ON TABLE public\.electrician_profiles FROM authenticated/i);
assert.match(migration, /replacement identity\/address document invalidates the previous approval[\s\S]*UPDATE public\.electrician_profiles SET active=false/i);
assert.match(migration, /p_review_status IN \('rejected','needs_resubmission'\)[\s\S]*UPDATE public\.electrician_profiles SET active=false/i);
assert.match(migration, /Serialize activation with document reviews and replacement uploads[\s\S]*FOR SHARE/i);
assert.match(migration,/same profile-then-document lock order[\s\S]*electrician_profiles[\s\S]*FOR UPDATE[\s\S]*srk_electrician_verification_documents[\s\S]*FOR UPDATE/i);
console.log("PASS private document bucket, owner/admin access, metadata privacy, audit events, and race-safe activation guard");

assert.match(electrician, /srk-electrician-verification/);
assert.match(electrician, /srk_electrician_submit_verification_document/);
assert.match(electrician, /srk_electrician_list_my_verification_documents/);
assert.match(electrician, /file\.size>5242880/);
assert.match(admin, /srk_admin_list_electrician_verification_documents/);
assert.match(admin, /srk_admin_review_electrician_document/);
assert.match(admin, /srk_admin_set_electrician_active/);
assert.match(admin, /createSignedUrl\(path,300\)/);
assert.match(admin, /दस्तावेज़ सत्यापन/);
console.log("PASS electrician upload/status UI and Admin review/signed-view/activation UI are connected");

function checkInlineScripts(html, label) {
  const scripts = [...html.matchAll(/<script(?:\s[^>]*)?>([\s\S]*?)<\/script>/gi)]
    .map(match => match[1]).filter(code => code.trim());
  assert.ok(scripts.length, label + " has inline JavaScript");
  scripts.forEach((code, index) => new vm.Script(code, { filename: label + "-inline-" + index + ".js" }));
}
checkInlineScripts(electrician, "electrician");
checkInlineScripts(admin, "admin");
console.log("PASS electrician and Admin inline JavaScript syntax");
console.log(JSON.stringify({passed:3,scope:"static source/UI regression only",realSupabaseCalls:0,postgresExecution:false,storageUploadTested:false},null,2));
