// Safe local-only Razorpay webhook harness. Uses mocked Supabase REST; never contacts Razorpay or Supabase.
const assert = require("node:assert/strict");
const crypto = require("node:crypto");

process.env.SUPABASE_URL = "https://mock.supabase.test";
process.env.SUPABASE_SERVICE_ROLE_KEY = "mock-service-role";
process.env.RAZORPAY_WEBHOOK_SECRET = "synthetic-test-secret";

const auditRows = new Map();
let failAudit = false;
let bookingLookups = 0;

global.fetch = async (input, init = {}) => {
  const url = new URL(input);
  const method = init.method || "GET";

  if (url.pathname === "/rest/v1/srk_razorpay_webhook_events") {
    if (failAudit) return new Response("mock audit outage", { status: 503 });
    if (method === "POST") {
      const row = JSON.parse(init.body);
      auditRows.set(row.event_id, { ...(auditRows.get(row.event_id) || {}), ...row });
      return new Response(null, { status: 201 });
    }
    if (method === "PATCH") {
      const eventId = url.searchParams.get("event_id").slice(3);
      if (auditRows.has(eventId)) {
        auditRows.set(eventId, { ...auditRows.get(eventId), ...JSON.parse(init.body) });
      }
      return new Response(null, { status: 204 });
    }
  }

  if (url.pathname === "/rest/v1/service_bookings" && method === "GET") {
    bookingLookups++;
    return Response.json([]); // synthetic order deliberately has no booking
  }

  return new Response("unexpected mock request", { status: 500 });
};

const { handler } = require("../razorpay-webhook.js");
const payload = JSON.stringify({
  event: "payment.captured",
  payload: { payment: { entity: {
    id: "pay_QATEST000001",
    order_id: "order_QATEST000001",
    status: "captured",
    amount: 12000,
    currency: "INR"
  } } }
});
const signature = crypto.createHmac("sha256", process.env.RAZORPAY_WEBHOOK_SECRET)
  .update(Buffer.from(payload)).digest("hex");
const makeEvent = (sig = signature) => ({
  httpMethod: "POST",
  headers: {
    "x-razorpay-signature": sig,
    "x-razorpay-event-id": "qa_synthetic_event_001"
  },
  body: payload,
  isBase64Encoded: false
});

(async () => {
  let response = await handler({ httpMethod: "GET", headers: {}, body: "" });
  assert.equal(response.statusCode, 405, "non-POST requests must be rejected");

  response = await handler(makeEvent("0".repeat(64)));
  assert.equal(response.statusCode, 400, "invalid HMAC must be rejected");
  assert.equal(auditRows.size, 0, "invalid signature must not write audit row");

  response = await handler(makeEvent());
  assert.equal(response.statusCode, 200);
  const body = JSON.parse(response.body);
  assert.equal(body.reason, "not_found");
  assert.equal(body.audit_recorded, true);
  assert.equal(auditRows.get("qa_synthetic_event_001").processing_status, "exception");
  assert.equal(auditRows.get("qa_synthetic_event_001").reconciliation_reason, "not_found");

  response = await handler(makeEvent());
  assert.equal(response.statusCode, 200, "duplicate event should be idempotently accepted");
  assert.equal(auditRows.size, 1, "duplicate event ID must not create a second audit row");
  assert.equal(auditRows.get("qa_synthetic_event_001").processing_status, "exception");

  failAudit = true;
  response = await handler(makeEvent());
  assert.equal(response.statusCode, 500, "audit storage failure must request provider retry");

  console.log(JSON.stringify({
    tests: [
      { name: "POST-only method guard", result: "PASS" },
      { name: "Invalid HMAC rejected before database access", result: "PASS" },
      { name: "Valid synthetic HMAC records not_found exception", result: "PASS" },
      { name: "Duplicate event ID remains one audit row", result: "PASS" },
      { name: "Audit storage outage returns 500 for retry", result: "PASS" }
    ],
    auditRows: auditRows.size,
    bookingLookupRequests: bookingLookups,
    realSupabaseCalls: 0,
    realRazorpayCalls: 0
  }, null, 2));
})().catch(error => {
  console.error(error);
  process.exitCode = 1;
});
