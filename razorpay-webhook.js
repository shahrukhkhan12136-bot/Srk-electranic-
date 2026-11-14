const crypto = require("crypto");

const SUPABASE_URL = process.env.SUPABASE_URL;
const SUPABASE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;
const WEBHOOK_SECRET = process.env.RAZORPAY_WEBHOOK_SECRET;

const json = (statusCode, body) => ({
  statusCode,
  headers: { "Content-Type": "application/json; charset=utf-8", "Cache-Control": "no-store" },
  body: JSON.stringify(body)
});

async function webhookInboxRpc(functionName, body) {
  const response = await fetch(new URL("/rest/v1/rpc/" + functionName, SUPABASE_URL), {
    method: "POST",
    headers: {
      apikey: SUPABASE_KEY,
      Authorization: "Bearer " + SUPABASE_KEY,
      "Content-Type": "application/json"
    },
    body: JSON.stringify(body)
  });
  if (!response.ok) throw new Error("Webhook inbox RPC failed: " + functionName);
  return response.json();
}

async function claimWebhookEvent(eventId, eventType, payloadHash) {
  return webhookInboxRpc("srk_service_claim_razorpay_webhook_event", {
    p_event_id: eventId, p_event_type: eventType, p_payload_sha256: payloadHash
  });
}

async function completeWebhookEvent(eventId, claimToken, outcome, error) {
  const result = await webhookInboxRpc("srk_service_complete_razorpay_webhook_event", {
    p_event_id: eventId, p_claim_token: claimToken,
    p_outcome: outcome, p_error: error ? String(error).slice(0, 500) : null
  });
  if (!result?.success) throw new Error("Webhook event completion was not accepted");
  return result;
}

async function updateBooking(orderId, payment) {
  const url = new URL("/rest/v1/service_bookings", SUPABASE_URL);
  url.searchParams.set("razorpay_order_id", "eq." + orderId);
  url.searchParams.set("select", "id,quoted_amount,service_charge,materials_amount,quote_status,status,payment_status,razorpay_payment_id,selected_category");

  const response = await fetch(url, {
    method: "GET",
    headers: { apikey: SUPABASE_KEY, Authorization: "Bearer " + SUPABASE_KEY }
  });
  if (!response.ok) throw new Error("Booking lookup failed");
  const rows = await response.json();
  const booking = Array.isArray(rows) ? rows[0] : null;
  if (!booking) return "not_found";
  if (booking.selected_category) {
    if (booking.payment_status === "paid") return booking.razorpay_payment_id === payment.id ? "already_processed" : "payment_conflict";
    if (booking.status !== "completed") return "booking_not_payable";
    const breakdownResponse = await fetch(new URL("/rest/v1/rpc/srk_service_role_get_booking_payment_breakdown", SUPABASE_URL), {
      method: "POST",
      headers: { apikey: SUPABASE_KEY, Authorization: "Bearer " + SUPABASE_KEY, "Content-Type": "application/json" },
      body: JSON.stringify({ p_booking_id: booking.id })
    });
    if (!breakdownResponse.ok) throw new Error("Cancellation fee breakdown lookup failed");
    const breakdown = await breakdownResponse.json();
    const expectedAmount = Number(breakdown?.total_amount_paise);
    if (!Number.isSafeInteger(expectedAmount) || expectedAmount < 100 || payment.amount !== expectedAmount || payment.currency !== "INR") return "amount_mismatch";
    const settlementResponse = await fetch(new URL("/rest/v1/rpc/srk_service_role_record_online_booking_payment", SUPABASE_URL), {
      method: "POST",
      headers: { apikey: SUPABASE_KEY, Authorization: "Bearer " + SUPABASE_KEY, "Content-Type": "application/json" },
      body: JSON.stringify({ p_booking_id: booking.id, p_order_id: payment.order_id, p_payment_id: payment.id, p_amount_paise: payment.amount })
    });
    if (!settlementResponse.ok) throw new Error("Cancellation fee ledger settlement failed");
    const settlement = await settlementResponse.json();
    return settlement?.success ? (settlement.already_processed ? "already_processed" : "updated") : "update_not_applied";
  }
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

async function reconcileRefund(refund, eventName) {
  const expectedStatus = {
    "refund.created": "pending",
    "refund.processed": "processed",
    "refund.failed": "failed"
  }[eventName];
  if (!expectedStatus || !refund ||
      !/^rfnd_[A-Za-z0-9]+$/.test(refund.id || "") ||
      !/^pay_[A-Za-z0-9]+$/.test(refund.payment_id || "") ||
      refund.status !== expectedStatus ||
      refund.currency !== "INR" ||
      !Number.isSafeInteger(refund.amount) || refund.amount < 100) {
    return "refund_payload_invalid";
  }

  const lookupUrl = new URL("/rest/v1/srk_razorpay_refunds", SUPABASE_URL);
  lookupUrl.searchParams.set("payment_id", "eq." + refund.payment_id);
  lookupUrl.searchParams.set("select", "id,payment_id,refund_id,amount_paise,status");
  lookupUrl.searchParams.set("limit", "2");
  const lookupResponse = await fetch(lookupUrl, {
    method: "GET",
    headers: { apikey: SUPABASE_KEY, Authorization: "Bearer " + SUPABASE_KEY }
  });
  if (!lookupResponse.ok) throw new Error("Refund record lookup failed");
  const rows = await lookupResponse.json();
  if (!Array.isArray(rows) || rows.length !== 1) throw new Error("Refund record missing or ambiguous");
  const record = rows[0];
  if (record.payment_id !== refund.payment_id ||
      Number(record.amount_paise) !== refund.amount ||
      (record.refund_id && record.refund_id !== refund.id)) {
    return "refund_record_mismatch";
  }

  const reconcileResponse = await fetch(new URL("/rest/v1/rpc/srk_service_reconcile_booking_refund", SUPABASE_URL), {
    method: "POST",
    headers: { apikey: SUPABASE_KEY, Authorization: "Bearer " + SUPABASE_KEY, "Content-Type": "application/json" },
    body: JSON.stringify({
      p_refund_record_id: record.id,
      p_provider_refund_id: refund.id,
      p_provider_status: expectedStatus,
      p_error: expectedStatus === "failed" ? "Razorpay reported refund failed" : null
    })
  });
  if (!reconcileResponse.ok) throw new Error("Refund reconciliation RPC failed");
  const result = await reconcileResponse.json();
  return result?.success ? (result.replayed ? "already_processed" : result.status) : "refund_not_reconciled";
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

  let eventId = null;
  let claimToken = null;
  try {
    const payload = JSON.parse(rawBody.toString("utf8"));
    const eventName = typeof payload.event === "string" && payload.event.length <= 100
      ? payload.event : "unknown";
    const payloadHash = crypto.createHash("sha256").update(rawBody).digest("hex");
    const suppliedEventId = String(event.headers?.["x-razorpay-event-id"] ||
      event.headers?.["X-Razorpay-Event-Id"] || "").trim();
    // The provider event ID is preferred, while the database also uniquely
    // indexes the signed body hash to stop replay under a changed header.
    eventId = suppliedEventId && suppliedEventId.length <= 128
      ? suppliedEventId : ("sha256:" + payloadHash);
    const claim = await claimWebhookEvent(eventId, eventName, payloadHash);

    if (claim?.payload_conflict) {
      console.error("Razorpay reused an event ID with a different signed payload.");
      return json(200, { success: true, reconciled: false, reason: "event_id_payload_conflict" });
    }
    if (claim?.duplicate) {
      return json(200, { success: true, duplicate: true, state: claim.state });
    }
    if (claim?.in_progress) {
      return json(503, { success: false, retry: true, reason: "event_processing_in_progress" });
    }
    if (!claim?.should_process || !claim.claim_token) {
      throw new Error("Webhook event claim was not granted");
    }
    claimToken = claim.claim_token;

    if (eventName === "refund.created" || eventName === "refund.processed" || eventName === "refund.failed") {
      const refund = payload.payload?.refund?.entity;
      const result = await reconcileRefund(refund, eventName);
      if (result === "refund_payload_invalid" || result === "refund_record_mismatch") {
        console.error("Razorpay refund webhook requires manual reconciliation:", result);
        await completeWebhookEvent(eventId, claimToken, "ignored", result);
        claimToken = null;
        return json(200, { success: true, reconciled: false, reason: result });
      }
      if (result === "refund_not_reconciled") throw new Error("Refund record was not reconciled");
      await completeWebhookEvent(eventId, claimToken, "processed", null);
      claimToken = null;
      return json(200, { success: true, reconciled: true, result });
    }

    if (eventName !== "payment.captured" && eventName !== "order.paid") {
      await completeWebhookEvent(eventId, claimToken, "ignored", "Unsupported event type");
      claimToken = null;
      return json(200, { success: true, ignored: true });
    }

    const payment = payload.payload?.payment?.entity;
    if (!payment || payment.status !== "captured" || !/^pay_[A-Za-z0-9]+$/.test(payment.id || "") ||
        !/^order_[A-Za-z0-9]+$/.test(payment.order_id || "")) {
      await completeWebhookEvent(eventId, claimToken, "ignored", "Captured payment details missing or invalid");
      claimToken = null;
      return json(200, { success: true, reconciled: false, reason: "captured_payment_details_invalid" });
    }

    const result = await updateBooking(payment.order_id, payment);
    if (result === "update_not_applied") throw new Error("Payment reconciliation update was not applied");
    if (result === "not_found" || result === "amount_mismatch" || result === "payment_conflict" || result === "booking_not_payable") {
      console.error("Razorpay webhook could not reconcile booking:", result);
      await completeWebhookEvent(eventId, claimToken, "ignored", result);
      claimToken = null;
      return json(200, { success: true, reconciled: false, reason: result });
    }

    await completeWebhookEvent(eventId, claimToken, "processed", null);
    claimToken = null;
    return json(200, { success: true, reconciled: true, result });
  } catch (error) {
    if (claimToken && eventId) {
      try {
        await completeWebhookEvent(eventId, claimToken, "retryable", error?.message || "Webhook processing failed");
      } catch (completionError) {
        console.error("Razorpay webhook retry state could not be saved:", completionError?.name || "UnknownError");
      }
    }
    console.error("Razorpay webhook processing failed:", error?.name || "UnknownError");
    return json(500, { success: false, error: "Webhook processing failed; provider retry requested." });
  }
};
