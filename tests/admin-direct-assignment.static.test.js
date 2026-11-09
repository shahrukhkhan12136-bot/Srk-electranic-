// Static regression tests for the Admin direct-assignment UI and SQL safeguards.
// These tests do not execute PostgreSQL or call Supabase; they validate source-level invariants.
const assert = require("node:assert/strict");
const fs = require("node:fs");
const vm = require("node:vm");

const migration = fs.readFileSync("supabase/migrations/20261110030000_admin_direct_electrician_assignment.sql", "utf8");
const admin = fs.readFileSync("admin.html", "utf8");
const start = admin.indexOf("function renderDirectAssignControl");
const end = admin.indexOf("async function directAssignBooking", start);
assert.ok(start >= 0 && end > start, "direct-assignment renderer exists");
const rendererSource = admin.slice(start, end);
const context = {
  esc: value => String(value ?? "").replace(/[&<>"']/g, c => ({ "&":"&amp;", "<":"&lt;", ">":"&gt;", '"':"&quot;", "'":"&#39;" }[c]))
};
vm.runInNewContext(rendererSource + "\nthis.renderDirectAssignControl = renderDirectAssignControl;", context);
const render = context.renderDirectAssignControl;
const booking = { id: "booking-1", status: "new", state: "Uttar Pradesh", district: "Balrampur", pincode: "271861" };
const electrician = (id, overrides = {}) => ({
  id, display_name: id, active: true, verification_status: "approved",
  auth_user_id: "auth-" + id, user_id: "auth-" + id,
  state: "Uttar Pradesh", district: "Balrampur", pincode: "271861", ...overrides
});
const pinMatch = electrician("pin-match");
const districtMatch = electrician("district-match", { pincode: "271862" });
let html = render(booking, [districtMatch, pinMatch]);
assert.match(html, /PIN/);
assert.match(html, /pin-match/);
assert.doesNotMatch(html, /district-match/);
console.log("PASS same-PIN eligible electrician takes priority over district candidate");

html = render(booking, [districtMatch]);
assert.match(html, /जिला fallback/);
assert.match(html, /district-match/);
console.log("PASS district fallback appears only when no eligible same-PIN candidate exists");

const invalid = [
  electrician("inactive", { active: false }),
  electrician("pending", { verification_status: "pending" }),
  electrician("unlinked", { user_id: "different-user" }),
  electrician("wrong-state", { state: "Bihar" }),
  electrician("wrong-district", { district: "Azamgarh", pincode: "271862" })
];
html = render(booking, invalid);
assert.doesNotMatch(html, /value="inactive"/);
assert.doesNotMatch(html, /value="pending"/);
assert.doesNotMatch(html, /value="unlinked"/);
assert.doesNotMatch(html, /value="wrong-state"/);
assert.doesNotMatch(html, /value="wrong-district"/);
console.log("PASS inactive, unapproved, unlinked, wrong-state and wrong-district profiles are excluded");

assert.equal(render({ ...booking, status: "completed" }, [pinMatch]), "");
assert.equal(render({ ...booking, assigned_electrician_id: "already-assigned" }, [pinMatch]), "");
console.log("PASS renderer hides assignment controls for completed or already-assigned bookings");

assert.match(migration, /auth\.uid\(\)\s+IS NULL\s+OR\s+NOT public\.is_srk_admin\(\)/i);
assert.match(migration, /WHERE id=p_booking_id\s+FOR UPDATE/i);
assert.match(migration, /WHERE id=p_electrician_id\s+FOR SHARE/i);
assert.match(migration, /v_booking\.status NOT IN \('new','confirmed'\)/i);
assert.match(migration, /e\.active=true[\s\S]*e\.verification_status='approved'[\s\S]*e\.auth_user_id IS NOT NULL[\s\S]*e\.user_id=e\.auth_user_id/i);
assert.match(migration, /SET assigned_electrician_id=p_electrician_id, status='assigned'/i);
assert.match(migration, /AND assigned_electrician_id IS NULL\s+AND status IN \('new','confirmed'\)/i);
assert.match(migration, /status IN \('offered','accepted'\)/i);
assert.match(migration, /REVOKE ALL ON FUNCTION public\.srk_admin_assign_electrician\(uuid,uuid\) FROM PUBLIC/i);
assert.match(migration, /REVOKE ALL ON FUNCTION public\.srk_admin_assign_electrician\(uuid,uuid\) FROM anon/i);
assert.match(migration, /GRANT EXECUTE ON FUNCTION public\.srk_admin_assign_electrician\(uuid,uuid\) TO authenticated/i);
console.log("PASS SQL source includes Admin gate, booking lock, electrician lock, status/location/auth checks, offer expiry and restricted grants");

console.log(JSON.stringify({ passed: 5, scope: "static source/UI regression only", realSupabaseCalls: 0, postgresExecution: false }, null, 2));
