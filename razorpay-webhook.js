const crypto = require("crypto");

const SUPABASE_URL = process.env.SUPABASE_URL;
const SUPABASE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;
const WEBHOOK_SECRET = process.env.RAZORPAY_WEBHOOK_SECRET;

const json = (statusCode, body) => ({
  statusCode,
  headers: { "Content-Type": "application/json; charset=utf-8", "Cache-Control": "no-store" },
  body: JSON.stringify(body)
});

async function recordWebhookEvent(eventId, fields) {
  const url = new URL("/rest/v1/srk_razorpay_webhook_events", SUPABASE_URL);
  url.searchParams.set("on_conflict", "event_id");
  const response = await fetch(url, {
    method: "POST",
    headers: { apikey: SUPABASE_KEY, Authorization: "Bearer " + SUPABASE_KEY,
      "Content-Type": "application/json", Prefer: "resolution=merge-duplicates,return=minimal" },
    body: JSON.stringify({ event_id: eventId, ...fields, updated_at: new Date().toISOString() })
  });
  if (!response.ok) throw new Error("Webhook audit write failed");
}

async function updateWebhookEvent(eventId, status, reason) {
  const url = new URL("/rest/v1/srk_razorpay_webhook_events", SUPABASE_URL);
  url.searchParams.set("event_id", "eq." + eventId);
  const response = await fetch(url, {
    method: "PATCH",
    headers: { apikey: SUPABASE_KEY, Authorization: "Bearer " + SUPABASE_KEY,
      "Content-Type": "application/json", Prefer: "return=minimal" },
    body: JSON.stringify({ processing_status: status, reconciliation_reason: reason || null,
      processed_at: new Date().toISOString(), updated_at: new Date().toISOString() })
  });
  if (!response.ok) throw new Error("Webhook audit update failed");
}

async function processRefundWebhook(refund) {
  if (!refund || !/^rfnd_[A-Za-z0-9]+$/.test(refund.id || "") ||
      !/^pay_[A-Za-z0-9]+$/.test(refund.payment_id || "") ||
      !Number.isSafeInteger(refund.amount) || refund.amount <= 0 ||
      refund.currency !== "INR" || !["processed","failed"].includes(refund.status)) {
    return "invalid_refund";
  }
  const lookup = new URL("/rest/v1/srk_razorpay_refunds", SUPABASE_URL);
  lookup.searchParams.set("select","id,booking_id,payment_id,refund_id,amount_paise,status,previous_payout_note");
  lookup.searchParams.set("payment_id","eq."+refund.payment_id);
  lookup.searchParams.set("amount_paise","eq."+refund.amount);
  lookup.searchParams.set("limit","1");
  const found = await fetch(lookup,{headers:{apikey:SUPABASE_KEY,Authorization:"Bearer "+SUPABASE_KEY}});
  if (!found.ok) throw new Error("Refund record lookup failed");
  const rows=await found.json(), row=Array.isArray(rows)?rows[0]:null;
  if (!row) return "refund_not_found";
  if (row.refund_id && row.refund_id!==refund.id) return "refund_id_conflict";
  if ((row.status==="processed" && refund.status!=="processed") || (row.status==="failed" && refund.status==="processed")) return "refund_state_conflict";

  const nextStatus=refund.status==="processed"?"processed":"failed";
  const patch=new URL("/rest/v1/srk_razorpay_refunds",SUPABASE_URL);
  patch.searchParams.set("id","eq."+row.id);
  const updated=await fetch(patch,{method:"PATCH",headers:{apikey:SUPABASE_KEY,Authorization:"Bearer "+SUPABASE_KEY,"Content-Type":"application/json",Prefer:"return=representation"},body:JSON.stringify({refund_id:refund.id,status:nextStatus,provider_status:refund.status,last_error:null,processed_at:nextStatus==="processed"?new Date().toISOString():null,updated_at:new Date().toISOString()})});
  if(!updated.ok)throw new Error("Refund status update failed");
  if(nextStatus==="processed"){
    const bookingUrl=new URL("/rest/v1/service_bookings",SUPABASE_URL);
    bookingUrl.searchParams.set("id","eq."+row.booking_id);
    bookingUrl.searchParams.set("razorpay_payment_id","eq."+row.payment_id);
    bookingUrl.searchParams.set("payment_status","eq.paid");
    const bookingPatch=await fetch(bookingUrl,{method:"PATCH",headers:{apikey:SUPABASE_KEY,Authorization:"Bearer "+SUPABASE_KEY,"Content-Type":"application/json",Prefer:"return=representation"},body:JSON.stringify({payment_status:"refunded"})});
    if(!bookingPatch.ok)throw new Error("Booking refund status update failed");
    const changed=await bookingPatch.json();
    if(!Array.isArray(changed)||!changed.length){
      const checkUrl=new URL("/rest/v1/service_bookings",SUPABASE_URL);
      checkUrl.searchParams.set("select","payment_status,razorpay_payment_id");checkUrl.searchParams.set("id","eq."+row.booking_id);
      const check=await fetch(checkUrl,{headers:{apikey:SUPABASE_KEY,Authorization:"Bearer "+SUPABASE_KEY}});
      const latest=await check.json();
      if(latest?.[0]?.payment_status!=="refunded"||latest?.[0]?.razorpay_payment_id!==row.payment_id)return "booking_update_not_applied";
    }
    const payoutUrl=new URL("/rest/v1/srk_electrician_payouts",SUPABASE_URL);
    payoutUrl.searchParams.set("booking_id","eq."+row.booking_id);payoutUrl.searchParams.set("payout_status","eq.blocked");
    payoutUrl.searchParams.set("payout_note","eq.Razorpay refund pending");
    const payoutPatch=await fetch(payoutUrl,{method:"PATCH",headers:{apikey:SUPABASE_KEY,Authorization:"Bearer "+SUPABASE_KEY,"Content-Type":"application/json",Prefer:"return=minimal"},body:JSON.stringify({payout_status:"refunded",payout_note:"Razorpay refund processed",updated_at:new Date().toISOString()})});
    if(!payoutPatch.ok)throw new Error("Electrician payout refund reconciliation failed");
  } else {
    const payoutUrl=new URL("/rest/v1/srk_electrician_payouts",SUPABASE_URL);
    payoutUrl.searchParams.set("booking_id","eq."+row.booking_id);payoutUrl.searchParams.set("payout_status","eq.blocked");
    payoutUrl.searchParams.set("payout_note","eq.Razorpay refund pending");
    const payoutPatch=await fetch(payoutUrl,{method:"PATCH",headers:{apikey:SUPABASE_KEY,Authorization:"Bearer "+SUPABASE_KEY,"Content-Type":"application/json",Prefer:"return=minimal"},body:JSON.stringify({payout_status:"pending",payout_note:row.previous_payout_note,updated_at:new Date().toISOString()})});
    if(!payoutPatch.ok)throw new Error("Electrician payout hold release failed");
  }
  return nextStatus;
}

async function updateBooking(orderId, payment) {
  const url = new URL("/rest/v1/service_bookings", SUPABASE_URL);
  url.searchParams.set("razorpay_order_id", "eq." + orderId);
  url.searchParams.set("select", "id,quoted_amount,service_charge,materials_amount,quote_status,status,payment_status,razorpay_payment_id");

  const response = await fetch(url, {
    method: "GET",
    headers: { apikey: SUPABASE_KEY, Authorization: "Bearer " + SUPABASE_KEY }
  });
  if (!response.ok) throw new Error("Booking lookup failed");
  const rows = await response.json();
  const booking = Array.isArray(rows) ? rows[0] : null;
  if (!booking) return "not_found";
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
    const eventIdHeader = event.headers?.["x-razorpay-event-id"] || event.headers?.["X-Razorpay-Event-Id"] || "";
    const eventId = /^[A-Za-z0-9_-]{1,128}$/.test(eventIdHeader)
      ? eventIdHeader
      : "body_" + crypto.createHash("sha256").update(rawBody).digest("hex");

    if (eventName === "refund.processed" || eventName === "refund.failed") {
      const refund = payload.payload?.refund?.entity;
      if (!refund || (eventName==="refund.processed" && refund.status!=="processed") ||
          (eventName==="refund.failed" && refund.status!=="failed")) {
        return json(400,{success:false,error:"Refund details missing or invalid."});
      }
      await recordWebhookEvent(eventId,{
        event_type:eventName,razorpay_payment_id:refund.payment_id,
        razorpay_refund_id:refund.id,
        payment_amount_paise:Number.isSafeInteger(refund.amount)?refund.amount:null,
        payment_currency:typeof refund.currency==="string"?refund.currency:null,
        processing_status:"received",reconciliation_reason:null
      });
      const result=await processRefundWebhook(refund);
      if(result==="invalid_refund"||result==="refund_not_found"||result==="refund_id_conflict"||result==="refund_state_conflict"||result==="booking_update_not_applied"){
        await updateWebhookEvent(eventId,"exception",result);
        return json(200,{success:true,reconciled:false,reason:result,audit_recorded:true});
      }
      await updateWebhookEvent(eventId,"reconciled",result);
      return json(200,{success:true,reconciled:true,result,audit_recorded:true});
    }

    if (eventName !== "payment.captured" && eventName !== "order.paid") {
      return json(200, { success: true, ignored: true });
    }

    const payment = payload.payload?.payment?.entity;
    if (!payment || payment.status !== "captured" || !/^pay_[A-Za-z0-9]+$/.test(payment.id || "") ||
        !/^order_[A-Za-z0-9]+$/.test(payment.order_id || "")) {
      return json(400, { success: false, error: "Captured payment details missing." });
    }

    await recordWebhookEvent(eventId, {
      event_type: eventName,
      razorpay_order_id: payment.order_id,
      razorpay_payment_id: payment.id,
      payment_amount_paise: Number.isSafeInteger(payment.amount) ? payment.amount : null,
      payment_currency: typeof payment.currency === "string" ? payment.currency : null,
      processing_status: "received",
      reconciliation_reason: null
    });

    const result = await updateBooking(payment.order_id, payment);
    if (result === "update_not_applied") {
      await updateWebhookEvent(eventId, "processing_error", result);
      console.error("Razorpay webhook update was not applied; retry requested.");
      return json(500, { success: false, reconciled: false, reason: result });
    }
    if (result === "not_found" || result === "amount_mismatch" || result === "payment_conflict" || result === "booking_not_payable") {
      await updateWebhookEvent(eventId, "exception", result);
      console.error("Razorpay webhook requires Admin reconciliation:", result);
      return json(200, { success: true, reconciled: false, reason: result, audit_recorded: true });
    }
    await updateWebhookEvent(eventId, "reconciled", result);
    return json(200, { success: true, reconciled: true, result, audit_recorded: true });
  } catch (error) {
    console.error("Razorpay webhook processing failed:", error?.name || "UnknownError");
    return json(500, { success: false, error: "Webhook processing failed." });
  }
};
