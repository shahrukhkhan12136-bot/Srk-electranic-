const crypto = require("crypto");

const SUPABASE_URL = process.env.SUPABASE_URL;
const SUPABASE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;
const WEBHOOK_SECRET = process.env.RAZORPAY_WEBHOOK_SECRET;

const getHeader = (headers, name) => {
  const target = String(name).toLowerCase();
  const key = Object.keys(headers || {}).find(candidate => candidate.toLowerCase() === target);
  return key === undefined ? "" : headers[key];
};

const WEBHOOK_HANDLER_BUDGET_MS = 52000;
const WEBHOOK_COMPLETION_RESERVE_MS = 15000;
const requestSignal = (deadlineAt, reserveMs = WEBHOOK_COMPLETION_RESERVE_MS) => {
  const remaining = Number(deadlineAt) - Date.now() - reserveMs;
  if (!Number.isFinite(remaining) || remaining <= 0) {
    const error = new Error("WEBHOOK_HANDLER_DEADLINE_REACHED");
    error.code = "WEBHOOK_HANDLER_DEADLINE_REACHED";
    throw error;
  }
  return AbortSignal.timeout(Math.min(15000, remaining));
};
const webhookFetch = (url, options = {}, deadlineAt, reserveMs = WEBHOOK_COMPLETION_RESERVE_MS) =>
  fetch(url, { ...options, signal: requestSignal(deadlineAt, reserveMs) });

const json = (statusCode, body) => ({
  statusCode,
  headers: { "Content-Type": "application/json; charset=utf-8", "Cache-Control": "no-store" },
  body: JSON.stringify(body)
});

async function webhookInboxRpc(functionName, body, deadlineAt, reserveMs = WEBHOOK_COMPLETION_RESERVE_MS) {
  const response = await webhookFetch(new URL("/rest/v1/rpc/" + functionName, SUPABASE_URL), {
    method: "POST",
    headers: {
      apikey: SUPABASE_KEY,
      Authorization: "Bearer " + SUPABASE_KEY,
      "Content-Type": "application/json"
    },
    body: JSON.stringify(body)
  }, deadlineAt, reserveMs);
  if (!response.ok) throw new Error("Webhook inbox RPC failed: " + functionName);
  return response.json();
}

async function claimWebhookEvent(eventId, eventType, payloadHash, deadlineAt) {
  return webhookInboxRpc("srk_service_claim_razorpay_webhook_event", {
    p_event_id: eventId, p_event_type: eventType, p_payload_sha256: payloadHash
  }, deadlineAt);
}

async function completeWebhookEvent(eventId, claimToken, outcome, error, deadlineAt) {
  const result = await webhookInboxRpc("srk_service_complete_razorpay_webhook_event", {
    p_event_id: eventId, p_claim_token: claimToken,
    p_outcome: outcome, p_error: error ? String(error).slice(0, 500) : null
  }, deadlineAt, 0);
  if (!result?.success) throw new Error("Webhook event completion was not accepted");
  return result;
}

async function updateBooking(orderId, payment, deadlineAt) {
  const url = new URL("/rest/v1/service_bookings", SUPABASE_URL);
  url.searchParams.set("razorpay_order_id", "eq." + orderId);
  url.searchParams.set("select", "id,quoted_amount,service_charge,materials_amount,quote_status,status,payment_status,payment_method,razorpay_payment_id,selected_category");

  const response = await webhookFetch(url, {
    method: "GET",
    headers: { apikey: SUPABASE_KEY, Authorization: "Bearer " + SUPABASE_KEY }
  }, deadlineAt);
  if (!response.ok) throw new Error("Booking lookup failed");
  const rows = await response.json();
  const booking = Array.isArray(rows) ? rows[0] : null;
  if (!booking) return "not_found";
  const paymentMethod = String(booking.payment_method || "").trim().toLowerCase();
  if (!paymentMethod.includes("razorpay") && !paymentMethod.includes("online")) return "payment_method_not_online";
  if (booking.payment_status === "refunded") return "payment_refunded";
  if (booking.selected_category) {
    if (booking.payment_status === "paid") return booking.razorpay_payment_id === payment.id ? "already_processed" : "payment_conflict";
    if (booking.status !== "completed") return "booking_not_payable";
    const breakdownResponse = await webhookFetch(new URL("/rest/v1/rpc/srk_service_role_get_booking_payment_breakdown", SUPABASE_URL), {
      method: "POST",
      headers: { apikey: SUPABASE_KEY, Authorization: "Bearer " + SUPABASE_KEY, "Content-Type": "application/json" },
      body: JSON.stringify({ p_booking_id: booking.id })
    }, deadlineAt);
    if (!breakdownResponse.ok) throw new Error("Cancellation fee breakdown lookup failed");
    const breakdown = await breakdownResponse.json();
    const expectedAmount = Number(breakdown?.total_amount_paise);
    if (!Number.isSafeInteger(expectedAmount) || expectedAmount < 100 || payment.amount !== expectedAmount || payment.currency !== "INR") return "amount_mismatch";
    const settlementResponse = await webhookFetch(new URL("/rest/v1/rpc/srk_service_role_record_online_booking_payment", SUPABASE_URL), {
      method: "POST",
      headers: { apikey: SUPABASE_KEY, Authorization: "Bearer " + SUPABASE_KEY, "Content-Type": "application/json" },
      body: JSON.stringify({ p_booking_id: booking.id, p_order_id: payment.order_id, p_payment_id: payment.id, p_amount_paise: payment.amount })
    }, deadlineAt);
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
  patchUrl.searchParams.set("payment_status", "not.in.(paid,refunded)");

  const patched = await webhookFetch(patchUrl, {
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
  }, deadlineAt);
  if (!patched.ok) throw new Error("Booking payment update failed");
  const updated = await patched.json();
  if (Array.isArray(updated) && updated.length) return "updated";

  // A concurrent webhook may have updated the row after our initial read.
  // Re-read to distinguish a true duplicate from a different payment conflict.
  const latestResponse = await webhookFetch(url, {
    method: "GET",
    headers: { apikey: SUPABASE_KEY, Authorization: "Bearer " + SUPABASE_KEY }
  }, deadlineAt);
  if (!latestResponse.ok) throw new Error("Booking payment reconciliation failed");
  const latestRows = await latestResponse.json();
  const latest = Array.isArray(latestRows) ? latestRows[0] : null;
  if (latest?.payment_status === "paid" && latest.razorpay_payment_id === payment.id) {
    return "already_processed";
  }
  if (latest?.payment_status === "paid") return "payment_conflict";
  return "update_not_applied";
}

async function reconcileRefund(refund, eventName, deadlineAt) {
  // Razorpay's own refund.created sample payloads can already carry
  // status=processed (for example, an immediately processed normal refund).
  // Do not discard that signed terminal evidence just because the event name
  // is refund.created. The dedicated terminal events remain strict.
  const allowedStatuses = {
    "refund.created": ["pending", "processed"],
    "refund.processed": ["processed"],
    "refund.failed": ["failed"]
  }[eventName];
  if (!allowedStatuses || !refund ||
      !/^rfnd_[A-Za-z0-9]+$/.test(refund.id || "") ||
      !/^pay_[A-Za-z0-9]+$/.test(refund.payment_id || "") ||
      !allowedStatuses.includes(refund.status) ||
      refund.currency !== "INR" ||
      !Number.isSafeInteger(refund.amount) || refund.amount < 100) {
    return "refund_payload_invalid";
  }

  const lookupUrl = new URL("/rest/v1/srk_razorpay_refunds", SUPABASE_URL);
  lookupUrl.searchParams.set("payment_id", "eq." + refund.payment_id);
  lookupUrl.searchParams.set("select", "id,payment_id,refund_id,idempotency_key,amount_paise,status");
  lookupUrl.searchParams.set("limit", "2");
  const lookupResponse = await webhookFetch(lookupUrl, {
    method: "GET",
    headers: { apikey: SUPABASE_KEY, Authorization: "Bearer " + SUPABASE_KEY }
  }, deadlineAt);
  if (!lookupResponse.ok) throw new Error("Refund record lookup failed");
  const rows = await lookupResponse.json();
  if (!Array.isArray(rows) || rows.length !== 1) throw new Error("Refund record missing or ambiguous");
  const record = rows[0];
  if (record.payment_id !== refund.payment_id ||
      Number(record.amount_paise) !== refund.amount ||
      (record.refund_id && record.refund_id !== refund.id)) {
    return "refund_record_mismatch";
  }
  // Before the provider refund ID is persisted, bind the webhook to the
  // exact internal refund using the receipt or record ID sent at creation.
  // Payment ID + amount alone is not a sufficient identity for same-payment refunds.
  if (!record.refund_id) {
    const notesRecordId = refund.notes?.srk_refund_record_id;
    const receipt = refund.receipt;
    const recordIdMatches = typeof notesRecordId === "string" && notesRecordId === record.id;
    const receiptMatches = typeof record.idempotency_key === "string" &&
      record.idempotency_key.length > 0 && receipt === record.idempotency_key;
    if (!recordIdMatches && !receiptMatches) return "refund_record_mismatch";
  }

  const reconcileResponse = await webhookFetch(new URL("/rest/v1/rpc/srk_service_reconcile_booking_refund", SUPABASE_URL), {
    method: "POST",
    headers: { apikey: SUPABASE_KEY, Authorization: "Bearer " + SUPABASE_KEY, "Content-Type": "application/json" },
    body: JSON.stringify({
      p_refund_record_id: record.id,
      p_provider_refund_id: refund.id,
      p_provider_status: refund.status,
      p_error: refund.status === "failed" ? "Razorpay reported refund failed" : null
    })
  }, deadlineAt);
  if (!reconcileResponse.ok) throw new Error("Refund reconciliation RPC failed");
  const result = await reconcileResponse.json();
  return result?.success ? (result.replayed ? "already_processed" : result.status) : "refund_not_reconciled";
}

async function processWebhookPayload(payload,eventName,deadlineAt) {
  if (eventName === "refund.created" || eventName === "refund.processed" || eventName === "refund.failed") {
    const refund = payload.payload?.refund?.entity;
    const result = await reconcileRefund(refund,eventName,deadlineAt);
    if (result === "refund_payload_invalid" || result === "refund_record_mismatch")
      return { outcome: "ignored", reason: result };
    if (result === "refund_not_reconciled") throw new Error("Refund record was not reconciled");
    return { outcome: "processed", result };
  }
  if (eventName !== "payment.captured" && eventName !== "order.paid")
    return { outcome: "ignored", reason: "unsupported_event_type" };
  const payment = payload.payload?.payment?.entity;
  if (!payment || payment.status !== "captured" || !/^pay_[A-Za-z0-9]+$/.test(payment.id || "") ||
      !/^order_[A-Za-z0-9]+$/.test(payment.order_id || ""))
    return { outcome: "ignored", reason: "captured_payment_details_invalid" };
  const result = await updateBooking(payment.order_id,payment,deadlineAt);
  if (result === "update_not_applied") throw new Error("Payment reconciliation update was not applied");
  if (["not_found","amount_mismatch","payment_conflict","booking_not_payable","payment_method_not_online","payment_refunded"].includes(result))
    return { outcome: "ignored", reason: result };
  return { outcome: "processed", result };
}

function minimalEventPayload(payload,eventName) {
  if (eventName === "payment.captured" || eventName === "order.paid") {
    const entity = payload.payload?.payment?.entity;
    if (!entity || typeof entity !== "object") return {};
    return { payload: { payment: { entity: { id: entity.id, order_id: entity.order_id, status: entity.status, amount: entity.amount, currency: entity.currency } } } };
  }
  if (["refund.created","refund.processed","refund.failed"].includes(eventName)) {
    const entity = payload.payload?.refund?.entity;
    if (!entity || typeof entity !== "object") return {};
    return { payload: { refund: { entity: { id: entity.id, payment_id: entity.payment_id, status: entity.status, currency: entity.currency, amount: entity.amount, receipt: entity.receipt, notes: { srk_refund_record_id: entity.notes?.srk_refund_record_id } } } } };
  }
  return {};
}

async function enqueueWebhookEvent(eventId,eventType,payloadHash,eventPayload) {
  const response = await fetch(new URL("/rest/v1/rpc/srk_service_enqueue_razorpay_webhook_event",SUPABASE_URL), {
    method: "POST",
    headers: { apikey: SUPABASE_KEY, Authorization: "Bearer "+SUPABASE_KEY, "Content-Type": "application/json" },
    body: JSON.stringify({ p_event_id:eventId,p_event_type:eventType,p_payload_sha256:payloadHash,p_event_payload:eventPayload }),
    signal: AbortSignal.timeout(3200)
  });
  if (!response.ok) throw new Error("Webhook durable enqueue failed");
  return response.json();
}

async function triggerWebhookConsumer(eventId) {
  const siteBase = process.env.DEPLOY_PRIME_URL || process.env.URL;
  if (!siteBase) throw new Error("Webhook consumer site URL is not configured");
  const target = new URL("/.netlify/functions/razorpay-webhook-consumer",siteBase);
  if (target.protocol !== "https:") throw new Error("Webhook consumer URL must use HTTPS");
  const workerAuth = crypto.createHmac("sha256",SUPABASE_KEY).update(eventId).digest("hex");
  const response = await fetch(target,{
    method:"POST",headers:{"Content-Type":"application/json","x-srk-webhook-worker-auth":workerAuth},
    body:JSON.stringify({event_id:eventId}),signal:AbortSignal.timeout(900)
  });
  if (response.status !== 202) throw new Error("Webhook background consumer was not accepted");
}

exports.processWebhookPayload = processWebhookPayload;

exports.handler = async (event) => {
  if (event.httpMethod !== "POST") return json(405,{success:false,error:"POST only."});
  if (!SUPABASE_URL || !SUPABASE_KEY || !WEBHOOK_SECRET) {
    console.error("Razorpay webhook server configuration is incomplete.");
    return json(500,{success:false,error:"Webhook server configuration incomplete."});
  }
  const signature = getHeader(event.headers,"x-razorpay-signature");
  const rawBody = event.isBase64Encoded ? Buffer.from(event.body || "","base64") : Buffer.from(event.body || "","utf8");
  if (rawBody.length === 0 || rawBody.length > 262144) return json(413,{success:false,error:"Webhook payload size is invalid."});
  if (!/^[a-f0-9]{64}$/i.test(signature)) return json(400,{success:false,error:"Invalid signature."});
  const expected = crypto.createHmac("sha256",WEBHOOK_SECRET).update(rawBody).digest();
  const received = Buffer.from(signature,"hex");
  if (received.length !== expected.length || !crypto.timingSafeEqual(expected,received))
    return json(400,{success:false,error:"Signature verification failed."});
  try {
    const payload = JSON.parse(rawBody.toString("utf8"));
    const eventName = typeof payload.event === "string" && payload.event.length <= 100 ? payload.event : "unknown";
    const payloadHash = crypto.createHash("sha256").update(rawBody).digest("hex");
    const suppliedEventId = String(getHeader(event.headers,"x-razorpay-event-id")).trim();
    const eventId = suppliedEventId && suppliedEventId.length <= 128 ? suppliedEventId : "sha256:"+payloadHash;
    const accepted = await enqueueWebhookEvent(eventId,eventName,payloadHash,minimalEventPayload(payload,eventName));
    if (accepted?.payload_conflict) {
      console.error("Razorpay reused an event ID with a different signed payload.");
      return json(200,{success:true,reconciled:false,reason:"event_id_payload_conflict"});
    }
    if (!accepted?.success || accepted.accepted !== true || !accepted.event_id)
      throw new Error("Webhook event was not durably accepted");
    if (accepted.state !== "processed" && accepted.state !== "ignored")
      await triggerWebhookConsumer(accepted.event_id);
    return json(200,{success:true,accepted:true,queued:accepted.queued===true,duplicate:accepted.duplicate===true});
  } catch (error) {
    console.error("Razorpay webhook durable acceptance failed:",error?.name || "UnknownError");
    return json(503,{success:false,retry:true,error:"Webhook was not confirmed as durably accepted; provider retry requested."});
  }
};
