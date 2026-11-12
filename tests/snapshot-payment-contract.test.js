const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const read = file => fs.readFileSync(path.join(__dirname, "..", file), "utf8");
const create = read("create-snapshot-order.js");
const verify = read("verify-snapshot-payment.js");
const webhook = read("razorpay-webhook.js");
const legacyCreate = read("create-order.js");
const legacyVerify = read("verify-payment.js");
const webhookLedgerMigration = read("supabase/migrations/20261112180000_razorpay_webhook_event_ledger.sql");

function includesAll(source, tokens, label) {
  for (const token of tokens) {
    assert.ok(source.includes(token), label + " must enforce: " + token);
  }
}

// Snapshot order creation must be bound to an authenticated owner and immutable final bill.
includesAll(create, [
  "verifyCustomer", "phone_confirmed_at", "customer_user_id",
  "timer_state!==\"stopped\"", "final_bill_id!==snapshot.bill_id",
  "srk_claim_razorpay_snapshot_order", "srk_bind_razorpay_snapshot_order",
  "amount_paise", "currency!==\"INR\"", "srk_cash_payment_intents",
  "payment_status===\"paid\""
], "snapshot order creation");

// Verification must prove the signature, persisted order binding, captured payment,
// exact amount/currency, final bill identity and server-side ledger reconciliation.
includesAll(verify, [
  "createHmac(\"sha256\"", "timingSafeEqual",
  "srk_razorpay_orders", "snapshot_id", "provider_order_id",
  "final_bill_id!==snapshot.bill_id", "captured.status!==\"captured\"",
  "captured.amount!==Number(order.amount_paise)",
  "srk_reconcile_razorpay_snapshot_payment"
], "snapshot payment verification");

// Legacy quote-based endpoints must reject all category/timer bookings.
includesAll(legacyCreate, [
  "if(booking.service_category_code)", "केवल अंतिम सुरक्षित Payable Snapshot"
], "legacy order endpoint");
includesAll(legacyVerify, [
  "if(booking.service_category_code)", "केवल अंतिम सुरक्षित Payable Snapshot"
], "legacy verification endpoint");

// Webhook must route snapshot-category bookings away from legacy direct booking updates
// and maintain a durable idempotency ledger for snapshot events.
includesAll(webhook, [
  "snapshot_payment_required", "srk_payment_webhook_events",
  "provider_event_id", "payload_sha256",
  'processing_status", "eq." + row.processing_status',
  '["received", "retryable_error"]', "inProgress",
  "Webhook event claim reconciliation failed",
  "processing_started_at", "staleProcessing", "5 * 60 * 1000",
  "Webhook event claim was not acquired",
  "srk_reconcile_razorpay_snapshot_payment"
], "Razorpay webhook");

// Webhook event ledger is durable, server-only, unique per provider event and recoverable.\nincludesAll(webhookLedgerMigration, [\n  "srk_payment_webhook_events", "unique(provider,provider_event_id)",\n  "processing_started_at", "retryable_error", "enable row level security",\n  "revoke all on public.srk_payment_webhook_events from public,anon,authenticated",\n  "to service_role"\n], "webhook event ledger migration");\n\n// Service-role credentials must remain server-side; browser surfaces call Netlify APIs,
// not Supabase service-role REST endpoints.
const customer = read("index.html");
assert.ok(customer.includes("/api/create-snapshot-order"));
assert.ok(customer.includes("/api/verify-snapshot-payment"));
assert.ok(!customer.includes("SUPABASE_SERVICE_ROLE_KEY"));
assert.ok(!customer.includes("RAZORPAY_KEY_SECRET"));

console.log("Snapshot payment contract tests passed (owner, final bill, idempotency, capture, legacy isolation and webhook ledger).");
