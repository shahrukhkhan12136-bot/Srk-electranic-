const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const webhook = fs.readFileSync(path.join(__dirname, "..", "razorpay-webhook.js"), "utf8");
const migration = fs.readFileSync(path.join(__dirname, "..", "supabase/migrations/20261112190000_harden_refund_provider_reconciliation.sql"), "utf8");

assert.match(webhook, /lookup\.searchParams\.set\("limit", "2"\)/,
  "refund webhook must fetch enough rows to detect ambiguous payment IDs");
assert.match(webhook, /rows\.length > 1[\s\S]{0,300}ambiguous_refund_ledger_match/,
  "refund webhook must reject ambiguous payment-to-refund ledger matches");
assert.match(migration, /v_refund\.status=\x27processed\x27[\s\S]{0,500}v_refund\.refund_id is null[\s\S]{0,300}set refund_id=p_provider_refund_id/,
  "processed legacy refund rows must bind their first verified provider refund ID");
assert.match(migration, /PROVIDER_REFUND_ID_CONFLICT/,
  "provider refund ID replacement must be rejected");

console.log("Razorpay refund webhook contract tests passed.");
