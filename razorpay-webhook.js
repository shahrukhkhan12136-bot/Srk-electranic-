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

async function startSnapshotWebhookEvent(eventMeta, orderId, paymentId) {
  const endpoint = new URL("/rest/v1/srk_payment_webhook_events", SUPABASE_URL);
  endpoint.searchParams.set("on_conflict", "provider,provider_event_id");
  const insert = await fetch(endpoint, {
    method: "POST",
    headers: {
      apikey: SUPABASE_KEY,
      Authorization: "Bearer " + SUPABASE_KEY,
      "Content-Type": "application/json",
      Prefer: "resolution=ignore-duplicates,return=representation"
    },
    body: JSON.stringify([{
      provider: "razorpay",
      provider_event_id: eventMeta.eventId,
      payload_sha256: eventMeta.payloadHash,
      event_type: eventMeta.eventType,
      provider_order_id: orderId,
      provider_payment_id: paymentId,
      processing_status: "received"
    }])
  });
  if (!insert.ok) throw new Error("Webhook event ledger insert failed");
  const inserted = await insert.json();
  let row = Array.isArray(inserted) ? inserted[0] : null;
  const lookup = new URL("/rest/v1/srk_payment_webhook_events", SUPABASE_URL);
  lookup.searchParams.set("provider", "eq.razorpay");
  lookup.searchParams.set("provider_event_id", "eq." + eventMeta.eventId);
  lookup.searchParams.set("select", "id,processing_status,attempt_count,payload_sha256,processing_started_at");
  lookup.searchParams.set("limit", "2");
  if (!row) {
    const existingResponse = await fetch(lookup, {
      headers: { apikey: SUPABASE_KEY, Authorization: "Bearer " + SUPABASE_KEY }
    });
    if (!existingResponse.ok) throw new Error("Webhook event ledger lookup failed");
    const rows = await existingResponse.json();
    row = Array.isArray(rows) ? rows[0] : null;
  }
  if (!row) throw new Error("Webhook event ledger row unavailable");
  if (row.payload_sha256 !== eventMeta.payloadHash) throw new Error("Webhook event ID payload hash conflict");
  if (row.processing_status === "processed") return { id: row.id, processed: true };
  if (row.processing_status === "rejected") return { id: row.id, rejected: true };
  const staleProcessing = row.processing_status === "processing" &&
    row.processing_started_at &&
    Date.now() - new Date(row.processing_started_at).getTime() > 5 * 60 * 1000;
  if (row.processing_status === "processing" && !staleProcessing) {
    return { id: row.id, inProgress: true };
  }

  // Conditional PATCH is the atomic lease claim. A processing lease older than
  // five minutes is recoverable after a crashed/terminated serverless attempt.
  if (!["received", "retryable_error"].includes(row.processing_status) && !staleProcessing) {
    throw new Error("Webhook event ledger has an unsupported processing state");
  }
  const claimStatus = row.processing_status;
  const leaseStartedAt = new Date().toISOString();
  const patchUrl = new URL("/rest/v1/srk_payment_webhook_events", SUPABASE_URL);
  patchUrl.searchParams.set("id", "eq." + row.id);
  patchUrl.searchParams.set("processing_status", "eq." + claimStatus);
  if (staleProcessing) {
    patchUrl.searchParams.set("processing_started_at", "lt." + new Date(Date.now() - 5 * 60 * 1000).toISOString());
  }
  const patch = await fetch(patchUrl, {
    method: "PATCH",
    headers: {
      apikey: SUPABASE_KEY,
      Authorization: "Bearer " + SUPABASE_KEY,
      "Content-Type": "application/json",
      Prefer: "return=representation"
    },
    body: JSON.stringify({
      processing_status: "processing",
      processing_started_at: leaseStartedAt,
      updated_at: leaseStartedAt,
      attempt_count: Number(row.attempt_count || 0) + 1
    })
  });
  if (!patch.ok) throw new Error("Webhook event ledger claim failed");
  const claimed = await patch.json();
  if (Array.isArray(claimed) && claimed.length) return { id: row.id, leaseStartedAt, processed: false };

  // Another delivery won the conditional update. Re-read its state rather
  // than processing the same provider event concurrently.
  const latestResponse = await fetch(lookup, {
    headers: { apikey: SUPABASE_KEY, Authorization: "Bearer " + SUPABASE_KEY }
  });
  if (!latestResponse.ok) throw new Error("Webhook event ledger claim reconciliation failed");
  const latestRows = await latestResponse.json();
  const latest = Array.isArray(latestRows) ? latestRows[0] : null;
  if (latest?.payload_sha256 !== eventMeta.payloadHash) throw new Error("Webhook event ID payload hash conflict");
  if (latest?.processing_status === "processed") return { id: row.id, processed: true };
  if (latest?.processing_status === "rejected") return { id: row.id, rejected: true };
  if (latest?.processing_status === "processing") return { id: row.id, inProgress: true };
  throw new Error("Webhook event claim was not acquired");
}

async function finishSnapshotWebhookEvent(eventId, leaseStartedAt, status, outcomeCode, detail) {
  const endpoint = new URL("/rest/v1/srk_payment_webhook_events", SUPABASE_URL);
  endpoint.searchParams.set("id", "eq." + eventId);
  endpoint.searchParams.set("processing_status", "eq.processing");
  endpoint.searchParams.set("processing_started_at", "eq." + leaseStartedAt);
  const response = await fetch(endpoint, {
    method: "PATCH",
    headers: {
      apikey: SUPABASE_KEY,
      Authorization: "Bearer " + SUPABASE_KEY,
      "Content-Type": "application/json",
      Prefer: "return=representation"
    },
    body: JSON.stringify({
      processing_status: status,
      processing_started_at: null,
      updated_at: new Date().toISOString(),
      outcome_code: outcomeCode,
      outcome_detail: String(detail || "").slice(0, 300),
      processed_at: status === "processed" || status === "rejected" ? new Date().toISOString() : null
    })
  });
  if (!response.ok) throw new Error("Webhook event ledger status update failed");
  const updated = await response.json();
  if (!Array.isArray(updated) || updated.length !== 1) throw new Error("Webhook processing lease was lost before completion");
}

async function updateSnapshotOrder(orderId, payment, eventMeta) {
  const lookup = new URL("/rest/v1/srk_razorpay_orders", SUPABASE_URL);
  lookup.searchParams.set("provider_order_id", "eq." + orderId);
  lookup.searchParams.set("select", "provider_order_id,provider_payment_id,amount_paise,currency,status");
  lookup.searchParams.set("limit", "1");
  const response = await fetch(lookup, {
    headers: { apikey: SUPABASE_KEY, Authorization: "Bearer " + SUPABASE_KEY }
  });
  if (!response.ok) throw new Error("Snapshot Razorpay order lookup failed");
  const rows = await response.json();
  const order = Array.isArray(rows) ? rows[0] : null;
  if (!order) return null;

  const eventRow = await startSnapshotWebhookEvent(eventMeta, orderId, payment.id);
  if (eventRow.processed) return "snapshot_event_already_processed";
  if (eventRow.rejected) return "snapshot_event_rejected";
  if (eventRow.inProgress) return "snapshot_event_in_progress";
  if (Number(order.amount_paise) !== payment.amount || order.currency !== payment.currency) {
    await finishSnapshotWebhookEvent(eventRow.id, eventRow.leaseStartedAt, "rejected", "snapshot_amount_mismatch", "Captured payment amount/currency does not match the bound snapshot order.");
    return "snapshot_amount_mismatch";
  }
  if (order.status === "paid" && order.provider_payment_id === payment.id) {
    await finishSnapshotWebhookEvent(eventRow.id, eventRow.leaseStartedAt, "processed", "snapshot_already_processed", "Payment was already reconciled.");
    return "snapshot_already_processed";
  }
  if (order.status !== "created") {
    await finishSnapshotWebhookEvent(eventRow.id, eventRow.leaseStartedAt, "rejected", "snapshot_order_not_ready", "Order is not in created state.");
    return "snapshot_order_not_ready";
  }

  try {
  const rpcResponse = await fetch(new URL("/rest/v1/rpc/srk_reconcile_razorpay_snapshot_payment", SUPABASE_URL), {
    method: "POST",
    headers: {
      apikey: SUPABASE_KEY,
      Authorization: "Bearer " + SUPABASE_KEY,
      "Content-Type": "application/json"
    },
    body: JSON.stringify({
      p_provider_order_id: orderId,
      p_provider_payment_id: payment.id,
      p_amount_paise: payment.amount,
      p_currency: payment.currency,
      p_source: "webhook"
    })
  });
  if (!rpcResponse.ok) {
    const detail = await rpcResponse.text();
    const error = new Error("Snapshot payment reconciliation failed");
    error.status = rpcResponse.status;
    error.detail = detail.slice(0, 300);
    throw error;
  }
  const result = await rpcResponse.json();
  if (result?.success) {
    await finishSnapshotWebhookEvent(eventRow.id, eventRow.leaseStartedAt, "processed", result.replayed ? "snapshot_replayed" : "snapshot_reconciled", "Snapshot payment reconciliation completed.");
    return result.replayed ? "snapshot_already_processed" : "snapshot_reconciled";
  }
  await finishSnapshotWebhookEvent(eventRow.id, eventRow.leaseStartedAt, "retryable_error", "snapshot_not_reconciled", "Reconciliation RPC returned no success.");
  return "snapshot_not_reconciled";
  } catch (error) {
    try { await finishSnapshotWebhookEvent(eventRow.id, eventRow.leaseStartedAt, "retryable_error", "snapshot_reconcile_error", error.message); } catch (_) {}
    throw error;
  }
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
    if (eventName === "refund.processed" || eventName === "refund.failed" || eventName === "refund.created") {
      const refund = payload.payload?.refund?.entity;
      if (!refund || !/^rfnd_[A-Za-z0-9]+$/.test(refund.id || "") ||
          !/^pay_[A-Za-z0-9]+$/.test(refund.payment_id || "")) {
        return json(400, { success: false, error: "Refund details missing." });
      }
      const lookup = new URL("/rest/v1/srk_razorpay_refunds", SUPABASE_URL);
      lookup.searchParams.set("payment_id", "eq." + refund.payment_id);
      lookup.searchParams.set("select", "id,refund_id,status");
      lookup.searchParams.set("limit", "2");
      const found = await fetch(lookup, { headers: { apikey: SUPABASE_KEY, Authorization: "Bearer " + SUPABASE_KEY } });
      if (!found.ok) throw new Error("Refund ledger lookup failed");
      const rows = await found.json();
      if (!Array.isArray(rows)) throw new Error("Refund ledger lookup returned an invalid response");
      if (rows.length > 1) {
        // Never reconcile an arbitrary ledger row when the payment ID is ambiguous.
        return json(500, { success: false, retry: true, error: "ambiguous_refund_ledger_match" });
      }
      const record = rows[0] || null;
      if (!record) return json(200, { success: true, ignored: true, reason: "refund_not_managed_by_srk" });
      const providerStatus = refund.status === "processed" ? "processed" :
        refund.status === "failed" ? "failed" : "pending";
      const rawEventHeader = event.headers?.["x-razorpay-event-id"] || event.headers?.["X-Razorpay-Event-Id"] || "";
      const refundEventMeta = {
        eventId: /^[A-Za-z0-9_:-]{1,160}$/.test(rawEventHeader) ? rawEventHeader : "sha256-" + crypto.createHash("sha256").update(rawBody).digest("hex"),
        payloadHash: crypto.createHash("sha256").update(rawBody).digest("hex"),
        eventType: String(eventName || "unknown").slice(0, 120)
      };
      const refundEvent = await startSnapshotWebhookEvent(refundEventMeta, null, refund.payment_id);
      if (refundEvent.processed) return json(200, { success: true, refund_reconciled: true, duplicate: true });
      if (refundEvent.rejected) return json(200, { success: true, refund_reconciled: false, duplicate: true });
      if (refundEvent.inProgress) return json(500, { success: false, refund_reconciled: false, retry: true });
      // A provider refund ID already bound to this payment ledger must never be replaced.
      if (record.refund_id && record.refund_id !== refund.id) {
        await finishSnapshotWebhookEvent(refundEvent.id, refundEvent.leaseStartedAt, "rejected", "refund_id_conflict", "Provider refund ID does not match the refund ledger.");
        return json(200, { success: true, refund_reconciled: false, rejected: true, reason: "refund_id_conflict" });
      }
      // Out-of-order refund.created must not move a failed refund back to processing.
      if (record.status === "failed" && providerStatus === "pending") {
        await finishSnapshotWebhookEvent(refundEvent.id, refundEvent.leaseStartedAt, "processed", "refund_stale_pending_ignored", "Ignored stale pending event after a failed refund.");
        return json(200, { success: true, refund_reconciled: false, status: "failed", stale_event_ignored: true });
      }
      try {
        const reconcile = await fetch(new URL("/rest/v1/rpc/srk_service_reconcile_booking_refund", SUPABASE_URL), {
          method: "POST",
          headers: { apikey: SUPABASE_KEY, Authorization: "Bearer " + SUPABASE_KEY, "Content-Type": "application/json" },
          body: JSON.stringify({
            p_refund_record_id: record.id,
            p_provider_refund_id: refund.id,
            p_provider_status: providerStatus,
            p_error: providerStatus === "failed" ? "Razorpay refund.failed webhook" : null
          })
        });
        if (!reconcile.ok) throw new Error("Refund webhook reconciliation failed");
        const reconcileResult = await reconcile.json();
        if (!reconcileResult?.success) throw new Error("Refund webhook reconciliation returned no success");
        await finishSnapshotWebhookEvent(refundEvent.id, refundEvent.leaseStartedAt, "processed", "refund_" + providerStatus, "Razorpay refund event reconciled.");
        return json(200, { success: true, refund_reconciled: true, status: providerStatus });
      } catch (refundError) {
        try { await finishSnapshotWebhookEvent(refundEvent.id, refundEvent.leaseStartedAt, "retryable_error", "refund_reconcile_error", refundError.message); } catch (_) {}
        throw refundError;
      }
    }
    if (eventName !== "payment.captured" && eventName !== "order.paid") {
      return json(200, { success: true, ignored: true });
    }

    const payment = payload.payload?.payment?.entity;
    if (!payment || payment.status !== "captured" || !/^pay_[A-Za-z0-9]+$/.test(payment.id || "") ||
        !/^order_[A-Za-z0-9]+$/.test(payment.order_id || "")) {
      return json(400, { success: false, error: "Captured payment details missing." });
    }

    const eventHeader = event.headers?.["x-razorpay-event-id"] || event.headers?.["X-Razorpay-Event-Id"] || "";
    const eventMeta = {
      eventId: /^[A-Za-z0-9_:-]{1,160}$/.test(eventHeader) ? eventHeader : "sha256-" + crypto.createHash("sha256").update(rawBody).digest("hex"),
      payloadHash: crypto.createHash("sha256").update(rawBody).digest("hex"),
      eventType: String(eventName || "unknown").slice(0, 120)
    };
    const snapshotResult = await updateSnapshotOrder(payment.order_id, payment, eventMeta);
    if (snapshotResult !== null) {
      if (snapshotResult === "snapshot_reconciled" || snapshotResult === "snapshot_already_processed" || snapshotResult === "snapshot_event_already_processed") {
        return json(200, { success: true, reconciled: true, result: snapshotResult });
      }
      if (snapshotResult === "snapshot_event_in_progress") {
        return json(500, { success: false, reconciled: false, reason: snapshotResult });
      }
      if (snapshotResult === "snapshot_event_rejected" || snapshotResult === "snapshot_amount_mismatch" || snapshotResult === "snapshot_order_not_ready") {
        console.error("Razorpay snapshot webhook requires review:", snapshotResult);
        return json(200, { success: true, reconciled: false, reason: snapshotResult });
      }
      return json(500, { success: false, reconciled: false, reason: snapshotResult });
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
