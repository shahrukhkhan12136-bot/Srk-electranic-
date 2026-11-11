// Static security, accounting and Admin UI regression tests for the business finance dashboard.
const assert = require("node:assert/strict");
const fs = require("node:fs");
const vm = require("node:vm");

const baseline = fs.readFileSync("supabase/migrations/20261110080448_srk_business_finance_dashboard.sql", "utf8");
const reportingDates = fs.readFileSync("supabase/migrations/20261111043852_srk_business_finance_reporting_dates.sql", "utf8");
const migration = fs.readFileSync("supabase/migrations/20261111090000_harden_business_finance_dashboard.sql", "utf8");
const admin = fs.readFileSync("admin.html", "utf8");

assert.match(baseline, /CREATE TABLE IF NOT EXISTS private\.srk_business_expenses/i);
assert.match(baseline, /ENABLE ROW LEVEL SECURITY/i);
assert.match(baseline, /REVOKE ALL ON TABLE private\.srk_business_expenses FROM PUBLIC, anon, authenticated/i);
assert.match(baseline, /auth\.uid\(\) IS NULL OR NOT public\.is_srk_admin\(\)/i);
assert.ok(reportingDates.includes("AT TIME ZONE 'Asia/Kolkata'"));

assert.match(migration, /ADD COLUMN IF NOT EXISTS entry_type text NOT NULL DEFAULT 'actual'/i);
assert.match(migration, /entry_type IN \('actual','estimate'\)/i);
assert.match(migration, /superseded_at IS NULL/i);
assert.match(migration, /srk_admin_finance_add_expense_estimate/i);
assert.match(migration, /srk_admin_finance_replace_estimate/i);
assert.match(migration, /Admin access required/i);
assert.match(migration, /srk_business_expenses_actual_reference_uq/i);
assert.match(migration, /srk_business_expenses_recorded_by_idx/i);
assert.match(migration, /JOIN public\.srk_electrician_payouts p ON p\.booking_id=b\.id/i);
assert.match(migration, /p\.payout_status IN \('pending','paid'\)/i);
assert.match(migration, /b\.payment_verified_at IS NOT NULL/i);
assert.match(migration, /p\.platform_commission/i);
assert.match(migration, /new_status='completed'/i);
assert.match(migration, /entry_type='actual'/i);
assert.match(migration, /entry_type='estimate'/i);
assert.match(migration, /projected_net_profit/i);
assert.match(migration, /net_profit.*actual_expenses/i);
assert.match(migration, /unmatched_paid_completed_bookings/i);
assert.ok(migration.includes("(coalesce(h.completed_at,b.created_at) AT TIME ZONE 'Asia/Kolkata')::date"));
assert.ok(migration.includes("(b.payment_verified_at AT TIME ZONE 'Asia/Kolkata')::date"));
assert.ok(migration.includes("(paid_at AT TIME ZONE 'Asia/Kolkata')::date"));
assert.ok(migration.includes("(created_at AT TIME ZONE 'Asia/Kolkata')::date"));
assert.doesNotMatch(migration, /GRANT\s+SELECT\s+ON\s+TABLE\s+private\.srk_business_expenses\s+TO\s+authenticated/i);

assert.match(admin, /Business Expense &amp; Profit Dashboard/);
assert.match(admin, /srk_admin_finance_dashboard/);
assert.match(admin, /srk_admin_finance_add_expense_estimate/);
assert.match(admin, /srk_admin_finance_replace_estimate/);
assert.match(admin, /loadBusinessFinanceDashboard/);
assert.match(admin, /वास्तविक खर्च/);
assert.match(admin, /अनुमानित खर्च/);
assert.match(admin, /financePeriod/);
assert.match(admin, /financeAnchorDate/);
assert.ok(admin.includes("timeZone:'Asia/Kolkata'"));
assert.match(admin, /formatToParts/);
assert.match(admin, /बदला गया/);
assert.match(admin, /Payout राशि को खर्च में दोबारा नहीं घटाया गया है/);
assert.match(admin, /loadBusinessFinanceDashboard\(\)\]\);/);

function checkInlineScripts(html) {
  const scripts = [...html.matchAll(/<script(?:\s[^>]*)?>([\s\S]*?)<\/script>/gi)]
    .map(match => match[1]).filter(code => code.trim());
  assert.ok(scripts.length, "Admin HTML has inline JavaScript");
  scripts.forEach((code, index) => new vm.Script(code, { filename: "admin-inline-" + index + ".js" }));
}
checkInlineScripts(admin);
console.log("PASS finance schema/RPC security, service-only commission source, estimate replacement, duplicate-reference guard and Admin UI wiring");
console.log(JSON.stringify({passed:4,scope:"static SQL/UI regression only",realProviderBills:false,realPayments:false,realAdminSession:false},null,2));
