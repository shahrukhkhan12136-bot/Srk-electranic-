const test = require("node:test");
const assert = require("node:assert/strict");
const crypto = require("node:crypto");

process.env.SUPABASE_URL = "https://example.supabase.co";
process.env.SUPABASE_SERVICE_ROLE_KEY = "service-role-test-secret";
process.env.RAZORPAY_WEBHOOK_SECRET = "webhook-test-secret";

const { handler } = require("../razorpay-webhook.js");
const originalFetch = global.fetch;
const response = (status, data) => ({
  ok: status >= 200 && status < 300,
  status,
  json: async () => data
});
const event = (payload, eventId = "evt_test_123", signatureOverride) => {
  const body = JSON.stringify(payload);
  const signature = signatureOverride || crypto
    .createHmac("sha256", process.env.RAZORPAY_WEBHOOK_SECRET)
    .update(Buffer.from(body, "utf8")).digest("hex");
  return {
    httpMethod: "POST",
    headers: { "x-razorpay-signature": signature, "x-razorpay-event-id": eventId },
    body,
    isBase64Encoded: false
  };
};
const rpcName = url => String(url).split("/").pop();

test("rejects invalid signature before touching the database", async t => {
  let calls = 0;
  global.fetch = async () => { calls++; throw new Error("must not fetch"); };
  t.after(() => { global.fetch = originalFetch; });
  const result = await handler(event({ event: "refund.created" }, "evt_bad", "0".repeat(64)));
  assert.equal(result.statusCode, 400);
  assert.equal(calls, 0);
});

test("claims a signed event and durably marks unsupported event ignored", async t => {
  const calls = [];
  global.fetch = async (url, options) => {
    const fn = rpcName(url);
    calls.push(fn);
    if (fn === "srk_service_claim_razorpay_webhook_event") {
      const body = JSON.parse(options.body);
      assert.equal(body.p_event_id, "evt_ignored_1");
      assert.equal(body.p_event_type, "payment.authorized");
      assert.match(body.p_payload_sha256, /^[a-f0-9]{64}$/);
      return response(200, { success: true, should_process: true, claim_token: "223e4567-e89b-42d3-a456-426614174000" });
    }
    if (fn === "srk_service_complete_razorpay_webhook_event") {
      const body = JSON.parse(options.body);
      assert.equal(body.p_outcome, "ignored");
      assert.equal(body.p_claim_token, "223e4567-e89b-42d3-a456-426614174000");
      return response(200, { success: true, state: "ignored" });
    }
    throw new Error("unexpected RPC " + fn);
  };
  t.after(() => { global.fetch = originalFetch; });
  const result = await handler(event({ event: "payment.authorized" }, "evt_ignored_1"));
  assert.equal(result.statusCode, 200);
  assert.deepEqual(calls, ["srk_service_claim_razorpay_webhook_event", "srk_service_complete_razorpay_webhook_event"]);
});

test("acknowledges already processed duplicate without replaying business logic", async t => {
  let calls = 0;
  global.fetch = async (url) => {
    calls++;
    assert.equal(rpcName(url), "srk_service_claim_razorpay_webhook_event");
    return response(200, { success: true, duplicate: true, should_process: false, state: "processed" });
  };
  t.after(() => { global.fetch = originalFetch; });
  const result = await handler(event({ event: "refund.processed" }, "evt_duplicate_1"));
  assert.equal(result.statusCode, 200);
  assert.equal(JSON.parse(result.body).duplicate, true);
  assert.equal(calls, 1);
});

test("asks provider to retry while another worker holds an active lease", async t => {
  global.fetch = async () => response(200, { success: true, in_progress: true, should_process: false });
  t.after(() => { global.fetch = originalFetch; });
  const result = await handler(event({ event: "payment.captured" }, "evt_busy_1"));
  assert.equal(result.statusCode, 503);
  assert.equal(JSON.parse(result.body).retry, true);
});

test("same signed body cannot be replayed under a changed event header", async t => {
  let firstClaim = true;
  let completionCount = 0;
  let firstHash = null;
  global.fetch = async (url, options) => {
    const fn = rpcName(url);
    if (fn === "srk_service_claim_razorpay_webhook_event") {
      const body = JSON.parse(options.body);
      if (firstClaim) {
        firstClaim = false;
        firstHash = body.p_payload_sha256;
        return response(200, { success: true, should_process: true, claim_token: "323e4567-e89b-42d3-a456-426614174000" });
      }
      assert.notEqual(body.p_event_id, "evt_replay_original");
      assert.equal(body.p_payload_sha256, firstHash);
      return response(200, { success: true, duplicate: true, should_process: false, state: "ignored" });
    }
    if (fn === "srk_service_complete_razorpay_webhook_event") {
      completionCount++;
      return response(200, { success: true, state: "ignored" });
    }
    throw new Error("unexpected RPC " + fn);
  };
  t.after(() => { global.fetch = originalFetch; });
  const payload = { event: "payment.authorized" };
  const first = await handler(event(payload, "evt_replay_original"));
  const replay = await handler(event(payload, "evt_replay_changed_header"));
  assert.equal(first.statusCode, 200);
  assert.equal(replay.statusCode, 200);
  assert.equal(JSON.parse(replay.body).duplicate, true);
  assert.equal(completionCount, 1);
});

test("does not settle a Cash booking from a captured webhook", async t => {
  const calls = [];
  global.fetch = async (url, options = {}) => {
    const target = String(url);
    const fn = rpcName(target);
    calls.push(target);
    if (fn === "srk_service_claim_razorpay_webhook_event") {
      return response(200, { success: true, should_process: true, claim_token: "423e4567-e89b-42d3-a456-426614174000" });
    }
    if (target.includes("/rest/v1/service_bookings?")) {
      return response(200, [{
        id: "123e4567-e89b-42d3-a456-426614174000",
        payment_method: "Cash",
        payment_status: "unpaid",
        razorpay_payment_id: null,
        selected_category: "home_wiring",
        status: "completed"
      }]);
    }
    if (fn === "srk_service_complete_razorpay_webhook_event") {
      const body = JSON.parse(options.body);
      assert.equal(body.p_outcome, "ignored");
      assert.equal(body.p_error, "payment_method_not_online");
      return response(200, { success: true, state: "ignored" });
    }
    throw new Error("unexpected request " + target);
  };
  t.after(() => { global.fetch = originalFetch; });
  const result = await handler(event({
    event: "payment.captured",
    payload: { payment: { entity: {
      id: "paycashblocked", order_id: "ordercashblocked",
      status: "captured", amount: 50000, currency: "INR"
    } } }
  }, "evt_cash_payment_blocked"));
  assert.equal(result.statusCode, 200);
  assert.equal(JSON.parse(result.body).reason, "payment_method_not_online");
  assert.equal(calls.some(url => url.includes("srk_service_role_get_booking_payment_breakdown")), false);
  assert.equal(calls.some(url => url.includes("srk_service_role_record_online_booking_payment")), false);
});

test("does not re-open a refunded booking from a captured webhook", async t => {
  const calls = [];
  global.fetch = async (url, options = {}) => {
    const target = String(url);
    const fn = rpcName(target);
    calls.push(target);
    if (fn === "srk_service_claim_razorpay_webhook_event") {
      return response(200, { success: true, should_process: true, claim_token: "523e4567-e89b-42d3-a456-426614174000" });
    }
    if (target.includes("/rest/v1/service_bookings?")) {
      return response(200, [{
        id: "123e4567-e89b-42d3-a456-426614174000",
        payment_method: "Razorpay ऑनलाइन भुगतान",
        payment_status: "refunded",
        razorpay_payment_id: null,
        selected_category: "home_wiring",
        status: "completed"
      }]);
    }
    if (fn === "srk_service_complete_razorpay_webhook_event") {
      const body = JSON.parse(options.body);
      assert.equal(body.p_outcome, "ignored");
      assert.equal(body.p_error, "payment_refunded");
      return response(200, { success: true, state: "ignored" });
    }
    throw new Error("unexpected request " + target);
  };
  t.after(() => { global.fetch = originalFetch; });
  const result = await handler(event({
    event: "payment.captured",
    payload: { payment: { entity: {
      id: "payrefundblocked", order_id: "orderrefundblocked",
      status: "captured", amount: 50000, currency: "INR"
    } } }
  }, "evt_refund_payment_blocked"));
  assert.equal(result.statusCode, 200);
  assert.equal(JSON.parse(result.body).reason, "payment_refunded");
  assert.equal(calls.some(url => url.includes("srk_service_role_get_booking_payment_breakdown")), false);
  assert.equal(calls.some(url => url.includes("srk_service_role_record_online_booking_payment")), false);
});
