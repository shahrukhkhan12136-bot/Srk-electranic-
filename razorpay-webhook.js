const crypto = require("crypto");

const SUPABASE_URL = process.env.SUPABASE_URL;
const SUPABASE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;
const WEBHOOK_SECRET = process.env.RAZORPAY_WEBHOOK_SECRET;

const json = (statusCode, body) => ({
  statusCode,
  headers: { "Content-Type": "application/json; charset=utf-8", "Cache-Control": "no-store" },
  body: JSON.stringify(body)
});

async function updateBooking(orderId, payment) {
  const url = new URL("/rest/v1/service_bookings", SUPABASE_URL);
  url.searchParams.set("razorpay_order_id", "eq." + orderId);
  url.searchParams.set("select", "id,quoted_amount,service_charge,materials_amount,quote_status,status,payment_status,razorpay_payment_id,service_category_code");

  const response = await fetch(url, {
    method: "GET",
    headers: { apikey: SUPABASE_KEY, Authorization: "Bearer " + SUPABASE_KEY }
  });
  if (!response.ok) throw new Error("Booking lookup failed");
  const rows = await response.json();
  const booking = Array.isArray(rows) ? rows[0] : null;
  if (!booking) return "not_found";
  if (booking.service_category_code) return "snapshot_payment_required";
  if (booking.payment_status === "paid") return booking.razorpay_payment_id === payment.id ? "already_processed" : "payment_conflict";

  // Reconcile only a completed job with an explicitly approved quote.
  if (booking.status !== "completed" || booking.quote_status !== "approved") {
    return "booking_not_payable";
  }
  const approvedTotal = Number(booking.service_charge) + Number(booking.materials_amount);
  const quotedTotal = Number(booking.quoted_amount);
  const expectedAmount = Math.round(approvedTotal * 100);
  if (!Number.isFinite(approvedTotal) || approvedTotal < 1 ||
      !Number.isFinite(quotedTotal) || Math.round(quotedTotal * 100) !== expectedAmount ||
      !Number.isSafeInteger(expectedAmount) || payment.amount !== expectedAmount || payment.currency !== "INR") {
    return "amount_mismatch";
  }

  const patchUrl = new URL("/rest/v1/service_bookings", SUPABASE_URL);
  patchUrl.searchParams.set("id", "eq." + booking.id);
  patchUrl.searchParams.set("razorpay_order_id", "eq." + orderId);
  patchUrl.searchParams.set("payment_status", "neq.paid");

  const patched = await fetch(patchUrl, {
    method: "PATCH",
    headers: {
      apikey: SUPABASE_KEY,
      Authorization: "Bearer " + SUPABASE_KEY,
      "Content-Type": "application/json",
      Prefer: "return=representation"
    },
    body: JSON.stringify({
      payment_status: "paid",
      amount_paid: Number((payment.amount / 100).toFixed(2)),
      razorpay_payment_id: payment.id,
      payment_verified_at: new Date().toISOString()
    })
  });
  if (!patched.ok) throw new Error("Booking payment update failed");
  const updated = await patched.json();
  if (Array.isArray(updated) && updated.length) return "updated";

  // A concurrent webhook may have updated the row after our initial read.
  // Re-read to distinguish a true duplicate from a different payment conflict.
  const latestResponse = await fetch(url, {
    method: "GET",
    headers: { apikey: SUPABASE_KEY, Authorization: "Bearer " + SUPABASE_KEY }
  });
  if (!latestResponse.ok) throw new Error("Booking payment reconciliation failed");
  const latestRows = await latestResponse.json();
  const latest = Array.isArray(latestRows) ? latestRows[0] : null;
  if (latest?.payment_status === "paid" && latest.razorpay_payment_id === payment.id) {
    return "already_processed";
  }
  if (latest?.payment_status === "paid") return "payment_conflict";
  return "update_not_applied";
}

exports.handler = async (event) => {
  if (event.httpMethod !== "POST") return json(405, { success: false, error: "POST only." });
  if (!SUPABASE_URL || !SUPABASE_KEY || !WEBHOOK_SECRET) {
    console.error("Razorpay webhook server configuration is incomplete.");
    return json(500, { success: false, error: "Webhook server configuration incomplete." });
  }

  const signature = event.headers?.["x-razorpay-signature"] || event.headers?.["X-Razorpay-Signature"] || "";
  const rawBody = event.isBase64Encoded
    ? Buffer.from(event.body || "", "base64")
    : Buffer.from(event.body || "", "utf8");
  if (!/^[a-f0-9]{64}$/i.test(signature)) return json(400, { success: false, error: "Invalid signature." });

  const expected = crypto.createHmac("sha256", WEBHOOK_SECRET).update(rawBody).digest();
  const received = Buffer.from(signature, "hex");
  if (received.length !== expected.length || !crypto.timingSafeEqual(expected, received)) {
    return json(400, { success: false, error: "Signature verification failed." });
  }

  try {
    const payload = JSON.parse(rawBody.toString("utf8"));
    const eventName = payload.event;
    if (eventName !== "payment.captured" && eventName !== "order.paid") {
      return json(200, { success: true, ignored: true });
    }

    const payment = payload.payload?.payment?.entity;
    if (!payment || payment.status !== "captured" || !/^pay_[A-Za-z0-9]+$/.test(payment.id || "") ||
        !/^order_[A-Za-z0-9]+$/.test(payment.order_id || "")) {
      return json(400, { success: false, error: "Captured payment details missing." });
    }

    const result = await updateBooking(payment.order_id, payment);
    if (result === "update_not_applied") {
      console.error("Razorpay webhook update was not applied; retry requested.");
      return json(500, { success: false, reconciled: false, reason: result });
    }
    if (result === "not_found" || result === "amount_mismatch" || result === "payment_conflict" || result === "booking_not_payable" || result === "snapshot_payment_required") {
      console.error("Razorpay webhook could not reconcile booking:", result);
      return json(200, { success: true, reconciled: false, reason: result });
    }
    return json(200, { success: true, reconciled: true, result });
  } catch (error) {
    console.error("Razorpay webhook processing failed:", error?.name || "UnknownError");
    return json(500, { success: false, error: "Webhook processing failed." });
  }
};
