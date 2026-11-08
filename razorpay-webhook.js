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
  url.searchParams.set("select", "id,quoted_amount,payment_status");

  const response = await fetch(url, {
    method: "GET",
    headers: { apikey: SUPABASE_KEY, Authorization: "Bearer " + SUPABASE_KEY }
  });
  if (!response.ok) throw new Error("Booking lookup failed");
  const rows = await response.json();
  const booking = Array.isArray(rows) ? rows[0] : null;
  if (!booking) return "not_found";
  if (booking.payment_status === "paid") return "already_processed";

  const expectedAmount = Math.round(Number(booking.quoted_amount) * 100);
  if (!Number.isSafeInteger(expectedAmount) || payment.amount !== expectedAmount || payment.currency !== "INR") {
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
      razorpay_payment_id: payment.id,
      payment_verified_at: new Date().toISOString()
    })
  });
  if (!patched.ok) throw new Error("Booking payment update failed");
  const updated = await patched.json();
  return Array.isArray(updated) && updated.length ? "updated" : "already_processed";
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
    if (result === "not_found" || result === "amount_mismatch") {
      console.error("Razorpay webhook could not reconcile booking:", result);
      return json(200, { success: true, reconciled: false, reason: result });
    }
    return json(200, { success: true, reconciled: true, result });
  } catch (error) {
    console.error("Razorpay webhook processing failed:", error?.name || "UnknownError");
    return json(500, { success: false, error: "Webhook processing failed." });
  }
};
