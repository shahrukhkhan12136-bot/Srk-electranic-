const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const root = path.resolve(__dirname, "..");
const handler = fs.readFileSync(path.join(root, "razorpay-refund.js"), "utf8");
const prep = fs.readFileSync(path.join(root, "supabase/migrations/20261114120000_guarded_labour_only_razorpay_refund_preparation.sql"), "utf8");
const provider = fs.readFileSync(path.join(root, "supabase/migrations/20261114130000_durable_razorpay_refund_provider_reconciliation.sql"), "utf8");

test("refund executor authenticates Admin session and claims via Admin RPC", () => {
  assert.match(handler, /auth\/v1\/user/);
  assert.match(handler, /srk_admin_claim_razorpay_refund/);
});

test("refund request uses Razorpay documented idempotency header and stable stored key", () => {
  assert.match(handler, /X-Refund-Idempotency/);
  assert.match(handler, /idempotency_key/);
  assert.match(prep, /idempotency_key/);
});

test("refund executor requires exact INR captured labour amount and no prior refund", () => {
  assert.match(handler, /payment\.status!=="captured"/);
  assert.match(handler, /payment\.currency!=="INR"/);
  assert.match(handler, /payment\.amount!==amount_paise/);
  assert.match(handler, /amount_refunded/);
});

test("provider result is durably recorded before internal booking reconciliation", () => {
  assert.match(handler, /srk_service_record_razorpay_refund_result/);
  assert.match(handler, /srk_service_finalize_razorpay_refund/);
  assert.ok(handler.indexOf("srk_service_record_razorpay_refund_result") < handler.indexOf("srk_service_finalize_razorpay_refund"));
});

test("webhook verifies HMAC and captures unique provider event before reconciliation", () => {
  assert.match(handler, /timingSafeEqual/);
  assert.match(handler, /x-razorpay-event-id/);
  assert.match(handler, /srk_service_capture_razorpay_refund_event/);
  assert.ok(handler.indexOf("srk_service_capture_razorpay_refund_event") < handler.indexOf("srk_service_record_razorpay_refund_result"));
});

test("service reconciliation functions are service-role only and webhook inbox is private", () => {
  assert.match(provider, /auth\.role\(\) <> 'service_role'/);
  assert.match(provider, /REVOKE ALL ON FUNCTION public\.srk_service_finalize_razorpay_refund/);
  assert.match(provider, /REVOKE ALL ON public\.srk_razorpay_refund_events FROM PUBLIC,anon,authenticated/);
});

test("provider failure or unknown response does not falsely mark booking refunded", () => {
  assert.match(handler, /internal_status==="processed"/);
  assert.match(provider, /provider_status<>'processed'/);
  assert.match(provider, /status='processed'/);
});
