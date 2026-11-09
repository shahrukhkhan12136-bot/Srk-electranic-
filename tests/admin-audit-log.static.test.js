// Static checks for the Admin audit log migration and panel.
const assert=require("node:assert/strict");
const fs=require("node:fs");
const vm=require("node:vm");
const migration=fs.readFileSync("supabase/migrations/20261110060000_admin_audit_log.sql","utf8");
const admin=fs.readFileSync("admin.html","utf8");
assert.match(migration,/CREATE TABLE IF NOT EXISTS public\.srk_admin_audit_events/i);
assert.match(migration,/ENABLE ROW LEVEL SECURITY/i);
assert.match(migration,/REVOKE ALL ON TABLE public\.srk_admin_audit_events FROM PUBLIC,anon,authenticated/i);
assert.match(migration,/SECURITY DEFINER[\s\S]*SET search_path=pg_catalog,public,auth,pg_temp/i);
assert.match(migration,/auth\.uid\(\) IS NULL OR NOT public\.is_srk_admin\(\)/i);
assert.match(migration,/GRANT EXECUTE ON FUNCTION public\.srk_admin_list_audit_events\(integer\) TO authenticated/i);
assert.match(migration,/CREATE TRIGGER srk_audit_service_bookings/i);
assert.match(migration,/CREATE TRIGGER srk_audit_electrician_profiles/i);
assert.match(migration,/CREATE TRIGGER srk_audit_electrician_applications/i);
assert.match(migration,/CREATE TRIGGER srk_audit_manual_payment_entries/i);
assert.match(migration,/CREATE TRIGGER srk_audit_manual_refund_entries/i);
assert.match(migration,/CREATE TRIGGER srk_audit_electrician_payouts/i);
assert.match(migration,/v_allow := CASE v_entity_type/i);
assert.match(migration,/before_data,after_data/i);
console.log("PASS private Admin-only audit table, allowlisted fields, six sensitive-table triggers and safe data minimization");
assert.match(admin,/srk_admin_list_audit_events/);
assert.match(admin,/Admin Audit Log/);
assert.match(admin,/loadAdminAuditLog\(\)/);
assert.match(admin,/esc\(before\)/);
function scripts(html){return [...html.matchAll(/<script(?:\s[^>]*)?>([\s\S]*?)<\/script>/gi)].map(x=>x[1]).filter(x=>x.trim())}
const all=scripts(admin);assert.ok(all.length);all.forEach((x,i)=>new vm.Script(x,{filename:"admin-"+i+".js"}));
console.log("PASS Admin audit viewer wiring and inline JavaScript syntax");
console.log(JSON.stringify({passed:2,scope:"static only",realSupabaseCalls:0,migrationApplied:false},null,2));
