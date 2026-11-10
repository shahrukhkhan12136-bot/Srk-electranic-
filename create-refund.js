const SUPABASE_URL = process.env.SUPABASE_URL;
const SUPABASE_ANON_KEY = process.env.SUPABASE_ANON_KEY || process.env.SUPABASE_SERVICE_ROLE_KEY;
const SUPABASE_SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;
const RAZORPAY_KEY_ID = process.env.RAZORPAY_KEY_ID || process.env.APIKEY;
const RAZORPAY_KEY_SECRET = process.env.RAZORPAY_KEY_SECRET || process.env.SECRETAPIKEY;

const json = (statusCode, body) => ({
  statusCode,
  headers: { "Content-Type": "application/json; charset=utf-8", "Cache-Control": "no-store" },
  body: JSON.stringify(body)
});

function adminHeaders(token) {
  return { apikey: SUPABASE_ANON_KEY, Authorization: "Bearer " + token, "Content-Type": "application/json" };
}
function serviceHeaders() {
  return { apikey: SUPABASE_SERVICE_ROLE_KEY, Authorization: "Bearer " + SUPABASE_SERVICE_ROLE_KEY, "Content-Type": "application/json" };
}
async function patchRefund(id, patch) {
  const url = new URL("/rest/v1/srk_razorpay_refunds", SUPABASE_URL);
  url.searchParams.set("id", "eq." + id);
  const response = await fetch(url, { method: "PATCH", headers: { ...serviceHeaders(), Prefer: "return=representation" }, body: JSON.stringify({ ...patch, updated_at: new Date().toISOString() }) });
  if (!response.ok) throw new Error("Refund record update failed");
  return response.json();
}
async function patchBookingRefunded(bookingId, paymentId) {
  const url = new URL("/rest/v1/service_bookings", SUPABASE_URL);
  url.searchParams.set("id", "eq." + bookingId);
  url.searchParams.set("razorpay_payment_id", "eq." + paymentId);
  url.searchParams.set("payment_status", "eq.paid");
  const response = await fetch(url, { method: "PATCH", headers: { ...serviceHeaders(), Prefer: "return=representation" }, body: JSON.stringify({ payment_status: "refunded" }) });
  if (!response.ok) throw new Error("Booking refund reconciliation failed");
}
async function settleRefundedPayout(bookingId) {
  const url = new URL("/rest/v1/srk_electrician_payouts", SUPABASE_URL);
  url.searchParams.set("booking_id", "eq." + bookingId);
  url.searchParams.set("payout_status", "eq.blocked");
  url.searchParams.set("payout_note", "eq.Razorpay refund pending");
  const response = await fetch(url, { method: "PATCH", headers: { ...serviceHeaders(), Prefer: "return=minimal" }, body: JSON.stringify({ payout_status: "refunded", payout_note: "Customer Razorpay refund processed", updated_at: new Date().toISOString() }) });
  if (!response.ok) throw new Error("Payout refund reconciliation failed");
}
async function restorePendingPayout(bookingId, previousNote) {
  const url = new URL("/rest/v1/srk_electrician_payouts", SUPABASE_URL);
  url.searchParams.set("booking_id", "eq." + bookingId);
  url.searchParams.set("payout_status", "eq.blocked");
  url.searchParams.set("payout_note", "eq.Razorpay refund pending");
  const response = await fetch(url, { method: "PATCH", headers: { ...serviceHeaders(), Prefer: "return=minimal" }, body: JSON.stringify({ payout_status: "pending", payout_note: previousNote || null, updated_at: new Date().toISOString() }) });
  if (!response.ok) throw new Error("Payout restoration failed");
}

exports.handler = async (event) => {
  if (event.httpMethod !== "POST") return json(405, { success: false, error: "POST only." });
  if (!SUPABASE_URL || !SUPABASE_ANON_KEY || !SUPABASE_SERVICE_ROLE_KEY || !RAZORPAY_KEY_ID || !RAZORPAY_KEY_SECRET) {
    console.error("Refund endpoint server configuration is incomplete.");
    return json(500, { success: false, error: "Refund server configuration incomplete." });
  }
  const auth = event.headers?.authorization || event.headers?.Authorization || "";
  const token = auth.startsWith("Bearer ") ? auth.slice(7).trim() : "";
  if (!token) return json(401, { success: false, error: "Admin login required." });

  try {
    const userResponse = await fetch(new URL("/auth/v1/user", SUPABASE_URL), { headers: { apikey: SUPABASE_ANON_KEY, Authorization: "Bearer " + token } });
    if (!userResponse.ok) return json(401, { success: false, error: "Admin session is invalid or expired." });
    const adminResponse = await fetch(new URL("/rest/v1/rpc/is_srk_admin", SUPABASE_URL), { method: "POST", headers: adminHeaders(token), body: "{}" });
    if (!adminResponse.ok || await adminResponse.json() !== true) return json(403, { success: false, error: "Admin access required." });

    let input;
    try { input = JSON.parse(event.body || "{}"); } catch { return json(400, { success: false, error: "Invalid JSON." }); }
    const bookingId = String(input.booking_id || "");
    const reason = String(input.reason || "").trim();
    if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(bookingId) || reason.length < 20 || reason.length > 250) {
      return json(400, { success: false, error: "A valid booking and a 20–250 character refund reason are required." });
    }

    const prepareResponse = await fetch(new URL("/rest/v1/rpc/srk_admin_prepare_razorpay_refund", SUPABASE_URL), {
      method: "POST", headers: adminHeaders(token), body: JSON.stringify({ p_booking_id: bookingId, p_reason: reason })
    });
    const prepareText = await prepareResponse.text();
    if (!prepareResponse.ok) return json(409, { success: false, error: "Refund preparation was rejected.", detail: prepareText.slice(0, 500) });
    const prepared = JSON.parse(prepareText);
    const row = Array.isArray(prepared) ? prepared[0] : prepared;
    if (!row?.refund_record_id || !row.payment_id || !Number.isSafeInteger(Number(row.amount_paise)) || !row.idempotency_key) {
      return json(500, { success: false, error: "Refund preparation returned incomplete data." });
    }
    if (row.status === "processed") return json(200, { success: true, status: "processed", already_processed: true, refund_record_id: row.refund_record_id });

    await patchRefund(row.refund_record_id, { status: "processing", last_error: null });
    const requestBody = { amount: Number(row.amount_paise), receipt: "srk_" + row.refund_record_id.replace(/-/g, "").slice(0, 32), notes: { booking_id: bookingId, refund_record_id: row.refund_record_id } };
    let providerResponse, provider;
    try {
      providerResponse = await fetch("https://api.razorpay.com/v1/payments/" + encodeURIComponent(row.payment_id) + "/refund", {
        method: "POST",
        headers: {
          Authorization: "Basic " + Buffer.from(RAZORPAY_KEY_ID + ":" + RAZORPAY_KEY_SECRET).toString("base64"),
          "Content-Type": "application/json",
          "X-Refund-Idempotency": row.idempotency_key
        },
        body: JSON.stringify(requestBody),
        signal: AbortSignal.timeout(20000)
      });
      provider = await providerResponse.json();
    } catch (error) {
      await patchRefund(row.refund_record_id, { status: "unknown", provider_status: null, last_error: "Provider response not confirmed; retry only with the same idempotency key." });
      return json(202, { success: false, status: "unknown", message: "Razorpay response was not confirmed. The same idempotent request can be retried safely." });
    }

    if (!providerResponse.ok || !provider?.id || provider.payment_id !== row.payment_id || Number(provider.amount) !== Number(row.amount_paise) || provider.currency !== "INR") {
      const detail = provider?.error?.description || "Razorpay did not confirm the requested refund.";
      await patchRefund(row.refund_record_id, { status: "unknown", provider_status: provider?.status || null, last_error: String(detail).slice(0, 500) });
      return json(202, { success: false, status: "unknown", message: "Razorpay response needs reconciliation before it can be marked successful." });
    }

    const status = provider.status === "processed" ? "processed" : provider.status === "failed" ? "failed" : "processing";
    await patchRefund(row.refund_record_id, {
      refund_id: provider.id,
      provider_status: provider.status,
      status,
      processed_at: status === "processed" ? new Date().toISOString() : null,
      last_error: status === "failed" ? "Razorpay reported refund failed." : null
    });
    if (status === "processed") {
      await patchBookingRefunded(bookingId, row.payment_id);
      await settleRefundedPayout(bookingId);
    } else if (status === "failed") {
      await restorePendingPayout(bookingId, row.previous_payout_note);
    }
    return json(status === "processed" ? 200 : status === "failed" ? 409 : 202, {
      success: status === "processed",
      status,
      refund_id: provider.id,
      message: status === "processed" ? "Razorpay refund processed and reconciled." : status === "failed" ? "Razorpay refund failed; payout hold was released." : "Razorpay refund is processing; webhook will confirm the final state."
    });
  } catch (error) {
    console.error("Refund endpoint failed:", error?.name || "UnknownError");
    return json(500, { success: false, error: "Refund request could not be reconciled. Check the Admin refund record before retrying." });
  }
};
