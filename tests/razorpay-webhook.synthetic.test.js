// Synthetic-only webhook regression harness. All Supabase REST calls are mocked.
const assert = require("node:assert/strict");
const crypto = require("node:crypto");

process.env.SUPABASE_URL = "https://mock.supabase.test";
process.env.SUPABASE_SERVICE_ROLE_KEY = "mock-service-role";
process.env.RAZORPAY_WEBHOOK_SECRET = "synthetic-test-secret";

const auditRows = new Map();
let booking = null;
let failAudit = false;
let bookingLookups = 0;
let bookingPatches = 0;

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
      const id = url.searchParams.get("event_id").slice(3);
      if (auditRows.has(id)) auditRows.set(id, { ...auditRows.get(id), ...JSON.parse(init.body) });
      return new Response(null, { status: 204 });
    }
  }
  if (url.pathname === "/rest/v1/service_bookings" && method === "GET") {
    bookingLookups++;
    return Response.json(booking ? [structuredClone(booking)] : []);
  }
  if (url.pathname === "/rest/v1/service_bookings" && method === "PATCH") {
    bookingPatches++;
    if (!booking || booking.payment_status === "paid") return Response.json([]);
    Object.assign(booking, JSON.parse(init.body));
    return Response.json([structuredClone(booking)]);
  }
  return new Response("unexpected mock request", { status: 500 });
};

const { handler } = require("../razorpay-webhook.js");
const basePayment = {
  id: "pay_QATEST000001", order_id: "order_QATEST000001",
  status: "captured", amount: 12000, currency: "INR"
};
const setBooking = (overrides = {}) => {
  booking = {
    id: "qa-booking-0001", quoted_amount: 120, service_charge: 100,
    materials_amount: 20, quote_status: "approved", status: "completed",
    payment_status: "pending", razorpay_payment_id: null, ...overrides
  };
};
const makeEvent = (payment = basePayment, eventId = "qa_event_001", sigOverride = null) => {
  const raw = JSON.stringify({ event: "payment.captured", payload: { payment: { entity: payment } } });
  const sig = crypto.createHmac("sha256", process.env.RAZORPAY_WEBHOOK_SECRET).update(Buffer.from(raw)).digest("hex");
  return {
    httpMethod: "POST",
    headers: { "x-razorpay-signature": sigOverride || sig, "x-razorpay-event-id": eventId },
    body: raw, isBase64Encoded: false
  };
};
const run = async (event) => {
  const response = await handler(event);
  return { status: response.statusCode, body: JSON.parse(response.body) };
};
const reset = () => {
  auditRows.clear(); failAudit = false; bookingLookups = 0; bookingPatches = 0;
};
const results = [];
const pass = name => results.push({ name, result: "PASS" });

(async () => {
  reset();
  let r = await run({ httpMethod: "GET", headers: {}, body: "" });
  assert.equal(r.status, 405); pass("POST-only method guard");

  r = await run(makeEvent(basePayment, "qa_invalid_sig", "0".repeat(64)));
  assert.equal(r.status, 400); assert.equal(auditRows.size, 0);
  pass("Invalid HMAC rejected before audit/database access");

  reset(); setBooking();
  r = await run(makeEvent());
  assert.equal(r.status, 200); assert.equal(r.body.reconciled, true);
  assert.equal(booking.payment_status, "paid");
  assert.equal(booking.razorpay_payment_id, basePayment.id);
  assert.equal(bookingPatches, 1);
  pass("Valid captured payment reconciles exact approved INR amount");

  r = await run(makeEvent());
  assert.equal(r.status, 200); assert.equal(r.body.result, "already_processed");
  assert.equal(bookingPatches, 1);
  assert.equal(auditRows.size, 1);
  pass("Duplicate event ID is idempotent; no second booking patch");

  r = await run(makeEvent(basePayment, "qa_same_payment_new_event"));
  assert.equal(r.status, 200); assert.equal(r.body.result, "already_processed");
  assert.equal(bookingPatches, 1);
  pass("Same captured payment under a different event ID is idempotent");

  reset(); setBooking();
  r = await run(makeEvent({ ...basePayment, amount: 11999 }, "qa_wrong_amount"));
  assert.equal(r.status, 200); assert.equal(r.body.reason, "amount_mismatch");
  assert.equal(booking.payment_status, "pending"); assert.equal(bookingPatches, 0);
  assert.equal(auditRows.get("qa_wrong_amount").processing_status, "exception");
  pass("Wrong amount is recorded as exception and booking remains unpaid");

  reset(); setBooking({ payment_status: "paid", razorpay_payment_id: "pay_EXISTING0001" });
  r = await run(makeEvent(basePayment, "qa_payment_conflict"));
  assert.equal(r.status, 200); assert.equal(r.body.reason, "payment_conflict");
  assert.equal(auditRows.get("qa_payment_conflict").processing_status, "exception");
  pass("Different payment ID against an already-paid booking is flagged");

  reset(); setBooking();
  failAudit = true;
  r = await run(makeEvent(basePayment, "qa_audit_outage"));
  assert.equal(r.status, 500); assert.equal(bookingPatches, 0);
  pass("Audit storage outage returns retryable 500 before booking mutation");

  console.log(JSON.stringify({
    tests: results,
    passed: results.length,
    realSupabaseCalls: 0,
    realRazorpayCalls: 0,
    note: "Run with Node.js 20 in the repository to execute this isolated harness."
  }, null, 2));
})().catch(error => { console.error(error); process.exitCode = 1; });
