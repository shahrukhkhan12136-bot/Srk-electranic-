const crypto = require("crypto");

const SUPABASE_URL = process.env.SUPABASE_URL;
const SUPABASE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;
const WEBHOOK_SECRET = process.env.RAZORPAY_WEBHOOK_SECRET;

const json = (statusCode, body) => ({
  statusCode,
  headers: { "Content-Type": "application/json; charset=utf-8", "Cache-Control": "no-store" },
  body: JSON.stringify(body)
});
const serviceHeaders = () => ({ apikey: SUPABASE_KEY, Authorization: "Bearer " + SUPABASE_KEY, "Content-Type": "application/json" });

async function updateBooking(orderId, payment) {
  const url = new URL("/rest/v1/service_bookings", SUPABASE_URL);
  url.searchParams.set("razorpay_order_id", "eq." + orderId);
  url.searchParams.set("select", "id,quoted_amount,service_charge,materials_amount,quote_status,status,payment_status,razorpay_payment_id");
  const response = await fetch(url, { headers: serviceHeaders() });
  if (!response.ok) throw new Error("Booking lookup failed");
  const rows = await response.json();
  const booking = Array.isArray(rows) ? rows[0] : null;
  if (!booking) return "not_found";
  if (booking.payment_status === "paid") return booking.razorpay_payment_id === payment.id ? "already_processed" : "payment_conflict";
  if (booking.status !== "completed" || booking.quote_status !== "approved") return "booking_not_payable";
  const approvedTotal = Number(booking.service_charge) + Number(booking.materials_amount);
  const quotedTotal = Number(booking.quoted_amount);
  const expectedAmount = Math.round(approvedTotal * 100);
  if (!Number.isFinite(approvedTotal) || approvedTotal < 1 || !Number.isFinite(quotedTotal) ||
      Math.round(quotedTotal * 100) !== expectedAmount || !Number.isSafeInteger(expectedAmount) ||
      payment.amount !== expectedAmount || payment.currency !== "INR") return "amount_mismatch";

  const patchUrl = new URL("/rest/v1/service_bookings", SUPABASE_URL);
  patchUrl.searchParams.set("id", "eq." + booking.id);
  patchUrl.searchParams.set("razorpay_order_id", "eq." + orderId);
  patchUrl.searchParams.set("payment_status", "neq.paid");
  const patched = await fetch(patchUrl, {
    method: "PATCH",
    headers: { ...serviceHeaders(), Prefer: "return=representation" },
    body: JSON.stringify({ payment_status: "paid", amount_paid: Number((payment.amount / 100).toFixed(2)), razorpay_payment_id: payment.id, payment_verified_at: new Date().toISOString() })
  });
  if (!patched.ok) throw new Error("Booking payment update failed");
  const updated = await patched.json();
  if (Array.isArray(updated) && updated.length) return "updated";
  const latestResponse = await fetch(url, { headers: serviceHeaders() });
  if (!latestResponse.ok) throw new Error("Booking payment reconciliation failed");
  const latestRows = await latestResponse.json();
  const latest = Array.isArray(latestRows) ? latestRows[0] : null;
  if (latest?.payment_status === "paid" && latest.razorpay_payment_id === payment.id) return "already_processed";
  if (latest?.payment_status === "paid") return "payment_conflict";
  return "update_not_applied";
}

async function reconcileRefund(refund, eventName) {
  if (!refund || !/^rfnd_[A-Za-z0-9]+$/.test(refund.id || "") ||
      !/^pay_[A-Za-z0-9]+$/.test(refund.payment_id || "") ||
      !Number.isSafeInteger(Number(refund.amount)) || refund.amount <= 0 || refund.currency !== "INR") {
    return "invalid_refund_payload";
  }
  const lookup = new URL("/rest/v1/srk_razorpay_refunds", SUPABASE_URL);
  lookup.searchParams.set("payment_id", "eq." + refund.payment_id);
  lookup.searchParams.set("select", "id,booking_id,payment_id,refund_id,amount_paise,status,previous_payout_note");
  const foundResponse = await fetch(lookup, { headers: serviceHeaders() });
  if (!foundResponse.ok) throw new Error("Refund lookup failed");
  const rows = await foundResponse.json();
  const record = Array.isArray(rows) ? rows[0] : null;
  // Ignore provider auto-refunds and refunds not initiated through this Admin workflow.
  if (!record) return "unmatched_refund";
  if (Number(record.amount_paise) !== Number(refund.amount)) return "refund_amount_mismatch";
  if (record.refund_id && record.refund_id !== refund.id) return "refund_id_conflict";
  if (record.status === "processed") return "already_processed";
  if (record.status === "failed") return eventName === "refund.failed" ? "already_failed" : "terminal_state_conflict";

  const mapped = eventName === "refund.processed" ? "processed" :
    eventName === "refund.failed" ? "failed" : "processing";
  const patch = new URL("/rest/v1/srk_razorpay_refunds", SUPABASE_URL);
  patch.searchParams.set("id", "eq." + record.id);
  patch.searchParams.set("status", "not.in.(processed,failed)");
  const patchResponse = await fetch(patch, {
    method: "PATCH",
    headers: { ...serviceHeaders(), Prefer: "return=representation" },
    body: JSON.stringify({
      refund_id: refund.id,
      provider_status: refund.status || mapped,
      status: mapped,
      processed_at: mapped === "processed" ? new Date().toISOString() : null,
      last_error: mapped === "failed" ? "Razorpay reported refund.failed." : null,
      updated_at: new Date().toISOString()
    })
  });
  if (!patchResponse.ok) throw new Error("Refund status update failed");
  const changed = await patchResponse.json();
  if (!Array.isArray(changed) || !changed.length) return "terminal_state_conflict";

  if (mapped === "processed") {
    const booking = new URL("/rest/v1/service_bookings", SUPABASE_URL);
    booking.searchParams.set("id", "eq." + record.booking_id);
    booking.searchParams.set("razorpay_payment_id", "eq." + record.payment_id);
    booking.searchParams.set("payment_status", "eq.paid");
    const bookingResponse = await fetch(booking, {
      method: "PATCH", headers: { ...serviceHeaders(), Prefer: "return=minimal" },
      body: JSON.stringify({ payment_status: "refunded" })
    });
    if (!bookingResponse.ok) throw new Error("Booking refund update failed");

    const payout = new URL("/rest/v1/srk_electrician_payouts", SUPABASE_URL);
    payout.searchParams.set("booking_id", "eq." + record.booking_id);
    payout.searchParams.set("payout_status", "eq.blocked");
    payout.searchParams.set("payout_note", "eq.Razorpay refund pending");
    const payoutResponse = await fetch(payout, {
      method: "PATCH", headers: { ...serviceHeaders(), Prefer: "return=minimal" },
      body: JSON.stringify({ payout_status: "refunded", payout_note: "Customer Razorpay refund processed", updated_at: new Date().toISOString() })
    });
    if (!payoutResponse.ok) throw new Error("Payout refund update failed");
  } else if (mapped === "failed") {
    const payout = new URL("/rest/v1/srk_electrician_payouts", SUPABASE_URL);
    payout.searchParams.set("booking_id", "eq." + record.booking_id);
    payout.searchParams.set("payout_status", "eq.blocked");
    payout.searchParams.set("payout_note", "eq.Razorpay refund pending");
    const payoutResponse = await fetch(payout, {
      method: "PATCH", headers: { ...serviceHeaders(), Prefer: "return=minimal" },
      body: JSON.stringify({ payout_status: "pending", payout_note: record.previous_payout_note || null, updated_at: new Date().toISOString() })
    });
    if (!payoutResponse.ok) throw new Error("Payout restoration failed");
  }
  return mapped;
}

exports.handler = async (event) => {
  if (event.httpMethod !== "POST") return json(405, { success: false, error: "POST only." });
  if (!SUPABASE_URL || !SUPABASE_KEY || !WEBHOOK_SECRET) {
    console.error("Razorpay webhook server configuration is incomplete.");
    return json(500, { success: false, error: "Webhook server configuration incomplete." });
  }
  const signature = event.headers?.["x-razorpay-signature"] || event.headers?.["X-Razorpay-Signature"] || "";
  const rawBody = event.isBase64Encoded ? Buffer.from(event.body || "", "base64") : Buffer.from(event.body || "", "utf8");
  if (!/^[a-f0-9]{64}$/i.test(signature)) return json(400, { success: false, error: "Invalid signature." });
  const expected = crypto.createHmac("sha256", WEBHOOK_SECRET).update(rawBody).digest();
  const received = Buffer.from(signature, "hex");
  if (received.length !== expected.length || !crypto.timingSafeEqual(expected, received)) return json(400, { success: false, error: "Signature verification failed." });

  try {
    const payload = JSON.parse(rawBody.toString("utf8"));
    const eventName = payload.event;
    if (["refund.created", "refund.processed", "refund.failed", "refund.speed_changed"].includes(eventName)) {
      const refund = payload.payload?.refund?.entity;
      const result = await reconcileRefund(refund, eventName);
      if (result === "invalid_refund_payload" || result === "refund_amount_mismatch" || result === "refund_id_conflict") {
        console.error("Razorpay refund webhook could not reconcile:", result);
        return json(200, { success: true, reconciled: false, reason: result });
      }
      return json(200, { success: true, reconciled: result !== "unmatched_refund", result });
    }
    if (eventName !== "payment.captured" && eventName !== "order.paid") return json(200, { success: true, ignored: true });

    const payment = payload.payload?.payment?.entity;
    if (!payment || payment.status !== "captured" || !/^pay_[A-Za-z0-9]+$/.test(payment.id || "") ||
        !/^order_[A-Za-z0-9]+$/.test(payment.order_id || "")) return json(400, { success: false, error: "Captured payment details missing." });
    const result = await updateBooking(payment.order_id, payment);
    if (result === "update_not_applied") return json(500, { success: false, reconciled: false, reason: result });
    if (["not_found", "amount_mismatch", "payment_conflict", "booking_not_payable"].includes(result)) {
      console.error("Razorpay payment webhook could not reconcile booking:", result);
      return json(200, { success: true, reconciled: false, reason: result });
    }
    return json(200, { success: true, reconciled: true, result });
  } catch (error) {
    console.error("Razorpay webhook processing failed:", error?.name || "UnknownError");
    return json(500, { success: false, error: "Webhook processing failed." });
  }
};
