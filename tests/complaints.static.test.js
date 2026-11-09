// Static security and UI regression tests for customer complaints.
const assert = require("node:assert/strict");
const fs = require("node:fs");
const vm = require("node:vm");
const migration = fs.readFileSync("supabase/migrations/20261110040000_customer_admin_complaints.sql", "utf8");
const customer = fs.readFileSync("index.html", "utf8");
const admin = fs.readFileSync("admin.html", "utf8");

assert.match(migration, /CREATE TABLE IF NOT EXISTS public\.srk_booking_complaints/i);
assert.match(migration, /ENABLE ROW LEVEL SECURITY/i);
assert.match(migration, /REVOKE ALL ON TABLE public\.srk_booking_complaints FROM PUBLIC, anon, authenticated/i);
assert.match(migration, /b\.customer_user_id=v_customer_id[\s\S]*FOR SHARE/i);
assert.match(migration, /length\(btrim\(p_description\)\) NOT BETWEEN 20 AND 2000/i);
assert.match(migration, /auth\.uid\(\) IS NULL OR NOT public\.is_srk_admin\(\)/i);
assert.match(migration, /FOR UPDATE/i);
assert.match(migration, /GRANT EXECUTE ON FUNCTION public\.srk_admin_update_booking_complaint\(uuid,text,text\) TO authenticated/i);
console.log("PASS complaint table is private, customer ownership is checked, and Admin mutations are gated");

assert.match(customer, /srk_customer_create_booking_complaint/);
assert.match(customer, /srk_customer_list_booking_complaints/);
assert.match(customer, /customerSubmitComplaint/);
assert.match(customer, /customer_user_id/);
assert.match(admin, /srk_admin_list_booking_complaints/);
assert.match(admin, /srk_admin_update_booking_complaint/);
assert.match(admin, /ग्राहक शिकायतें और सहायता/);
console.log("PASS customer submission/history and Admin complaint inbox/update UI are connected to RPCs");

function checkInlineScripts(html, label) {
  const scripts = [...html.matchAll(/<script(?:\s[^>]*)?>([\s\S]*?)<\/script>/gi)]
    .map(match => match[1]).filter(code => code.trim());
  assert.ok(scripts.length, label + " has inline JavaScript");
  scripts.forEach((code, index) => new vm.Script(code, { filename: label + "-inline-" + index + ".js" }));
}
checkInlineScripts(customer, "customer");
checkInlineScripts(admin, "admin");
console.log("PASS customer and Admin inline JavaScript syntax");
console.log(JSON.stringify({passed:3,scope:"static source/UI regression only",realSupabaseCalls:0,postgresExecution:false},null,2));
