const SUPABASE_URL = (process.env.SUPABASE_URL || "").replace(/\/$/, "");
const SUPABASE_SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY || "";
const RAZORPAY_KEY_ID = process.env.RAZORPAY_KEY_ID || process.env.APIKEY || "";
const RAZORPAY_KEY_SECRET = process.env.RAZORPAY_KEY_SECRET || process.env.SECRETAPIKEY || "";

const json = (statusCode, body) => ({
  statusCode,
  headers: { "Content-Type": "application/json; charset=utf-8", "Cache-Control": "no-store" },
  body: JSON.stringify(body)
});
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

async function supabaseRequest(path, { method = "GET", body, accessToken = SUPABASE_SERVICE_ROLE_KEY } = {}) {
  const response = await fetch(SUPABASE_URL + path, {
    method,
    headers: {
      apikey: SUPABASE_SERVICE_ROLE_KEY,
      Authorization: "Bearer " + accessToken,
      "Content-Type": "application/json",
      Prefer: "return=representation"
    },
    ...(body === undefined ? {} : { body: JSON.stringify(body) }),
    signal: AbortSignal.timeout(12000)
  });
  const raw = await response.text();
  let data = null;
  try { data = raw ? JSON.parse(raw) : null; } catch (_) { data = null; }
  if (!response.ok) {
    const error = new Error("Supabase request failed");
    error.status = response.status;
    error.data = data;
    throw error;
  }
  return data;
}

async function razorpayCreateRefund(record) {
  const auth = Buffer.from(RAZORPAY_KEY_ID + ":" + RAZORPAY_KEY_SECRET).toString("base64");
  const body = {
    amount: Number(record.amount_paise),
    receipt: record.idempotency_key,
    notes: {
      srk_booking_id: record.booking_id,
      srk_refund_record_id: record.refund_record_id
    }
  };
  if (!Number.isSafeInteger(body.amount) || body.amount < 100 ||
      !/^[A-Za-z0-9_-]{10,64}$/.test(record.idempotency_key || "") ||
      !/^pay_[A-Za-z0-9]+$/.test(record.payment_id || "")) {
    throw new Error("Prepared refund record failed validation");
  }

  const response = await fetch(
    "https://api.razorpay.com/v1/payments/" + encodeURIComponent(record.payment_id) + "/refund",
    {
      method: "POST",
      headers: {
        Authorization: "Basic " + auth,
        "Content-Type": "application/json",
        "X-Refund-Idempotency": record.idempotency_key
      },
      body: JSON.stringify(body),
      signal: AbortSignal.timeout(20000)
    }
  );
  const raw = await response.text();
  let data = null;
  try { data = raw ? JSON.parse(raw) : null; } catch (_) { data = null; }
  return { response, data };
}

exports.handler = async event => {
  if (event.httpMethod !== "POST") return json(405, { success: false, error: "केवल POST अनुरोध स्वीकार है।" });
  if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY || !RAZORPAY_KEY_ID || !RAZORPAY_KEY_SECRET) {
    return json(500, { success: false, error: "Refund server configuration is incomplete." });
  }

  const authorization = event.headers?.authorization || event.headers?.Authorization || "";
  const tokenMatch = /^Bearer ([A-Za-z0-9._~-]{20,8192})$/.exec(authorization);
  if (!tokenMatch) return json(401, { success: false, error: "Main Admin login required." });

  let input;
  try { input = JSON.parse(event.body || "{}"); }
  catch (_) { return json(400, { success: false, error: "Invalid JSON request." }); }
  const bookingId = input?.booking_id;
  const reason = typeof input?.reason === "string" ? input.reason.trim() : "";
  if (!UUID.test(bookingId || "") || reason.length < 20 || reason.length > 250) {
    return json(400, { success: false, error: "Valid booking ID and a 20–250 character reason are required." });
  }

  try {
    // Verify the bearer token with Supabase Auth; never trust a client-supplied role.
    const authResponse = await fetch(SUPABASE_URL + "/auth/v1/user", {
      headers: { apikey: SUPABASE_SERVICE_ROLE_KEY, Authorization: "Bearer " + tokenMatch[1] },
      signal: AbortSignal.timeout(10000)
    });
    if (!authResponse.ok) return json(401, { success: false, error: "Admin session is invalid or expired." });
    const authUser = await authResponse.json();
    if (!authUser?.id) return json(401, { success: false, error: "Admin session is invalid." });

    // The database remains authoritative for Main Admin membership.
    const isAdmin = await supabaseRequest("/rest/v1/rpc/is_srk_admin", { method: "POST", body: {}, accessToken: tokenMatch[1] });
    if (isAdmin !== true) return json(403, { success: false, error: "Only Main Admin can initiate a Razorpay refund." });

    const prepared = await supabaseRequest("/rest/v1/rpc/srk_admin_prepare_razorpay_refund", {
      method: "POST",
      body: { p_booking_id: bookingId, p_reason: reason },
      accessToken: tokenMatch[1]
    });
    const record = Array.isArray(prepared) ? prepared[0] : prepared;
    if (!record?.refund_record_id || record.booking_id !== bookingId) {
      return json(409, { success: false, error: "Refund preparation did not return a valid record." });
    }
    if (record.status === "processed") {
      return json(200, { success: true, status: "processed", replayed: true, message: "यह Refund पहले ही पूरा हो चुका है।" });
    }
    if (record.status === "failed") {
      return json(409, { success: false, status: "failed", error: "पिछला Refund failed है। Admin reconciliation आवश्यक है।" });
    }
    if (!["requested", "processing"].includes(record.status)) {
      return json(409, { success: false, status: record.status, error: "Refund इस स्थिति में आगे नहीं बढ़ सकता।" });
    }

    let provider;
    try {
      provider = await razorpayCreateRefund(record);
    } catch (error) {
      // Network/timeout is ambiguous: keep the payout hold and retry only with
      // the exact same provider idempotency key and request body.
      console.error("Razorpay refund request outcome is unknown:", error?.name || "NetworkError");
      return json(503, {
        success: false, status: "unknown", retryable: true,
        error: "Razorpay का जवाब नहीं मिला। कोई नया Refund न बनाएँ; इसी रिकॉर्ड पर सुरक्षित retry करें।"
      });
    }

    if (!provider.response.ok) {
      // A 409 can mean the same idempotent operation is still running. Other
      // provider errors are held for manual reconciliation; never release payout here.
      if (provider.response.status === 409) {
        return json(202, {
          success: true, status: "processing", retryable: true,
          error: "Razorpay पर Refund अनुरोध अभी प्रक्रिया में है। कुछ देर बाद इसी अनुरोध को दोहराएँ।"
        });
      }
      console.error("Razorpay rejected refund request:", provider.response.status, provider.data?.error?.code || "provider_error");
      return json(502, {
        success: false, status: "needs_reconciliation", retryable: false,
        error: "Razorpay ने Refund अनुरोध स्वीकार नहीं किया। Payout hold सुरक्षित है; Admin reconciliation आवश्यक है।"
      });
    }

    const refund = provider.data;
    if (!refund || !/^rfnd_[A-Za-z0-9]+$/.test(refund.id || "") ||
        refund.payment_id !== record.payment_id ||
        Number(refund.amount) !== Number(record.amount_paise) ||
        refund.currency !== "INR" ||
        !["pending", "processed", "failed"].includes(refund.status)) {
      console.error("Razorpay refund response failed record matching.");
      return json(202, {
        success: false, status: "needs_reconciliation",
        error: "Razorpay response सुरक्षित रूप से match नहीं हुआ। Webhook या Admin reconciliation आवश्यक है।"
      });
    }

    try {
      const reconciled = await supabaseRequest("/rest/v1/rpc/srk_service_reconcile_booking_refund", {
        method: "POST",
        body: {
          p_refund_record_id: record.refund_record_id,
          p_provider_refund_id: refund.id,
          p_provider_status: refund.status,
          p_error: refund.status === "failed" ? "Razorpay reported refund failed" : null
        }
      });
      if (reconciled?.success) {
        const finalStatus = reconciled.status || refund.status;
        return json(200, {
          success: true,
          status: finalStatus,
          refund_id: refund.id,
          message: finalStatus === "processed"
            ? "Razorpay Refund processed और ledger reconciliation सफल हुई।"
            : finalStatus === "failed"
              ? "Razorpay ने Refund failed बताया। Payout hold नियम के अनुसार अपडेट हुआ।"
              : "Razorpay ने Refund स्वीकार किया है; final status Webhook से अपडेट होगा।"
        });
      }
    } catch (error) {
      console.error("Refund response received; DB reconciliation deferred:", error?.status || error?.name || "Unknown");
    }
    // Provider accepted the refund; signed webhook is the independent recovery path.
    return json(202, {
      success: true, status: "provider_accepted_reconciliation_pending",
      refund_id: refund.id,
      message: "Razorpay ने Refund स्वीकार किया। Database reconciliation Webhook से पूरी होगी।"
    });
  } catch (error) {
    console.error("Admin Razorpay refund handler failed:", error?.status || error?.name || "Unknown");
    if (error?.status === 401) return json(401, { success: false, error: "Admin session expired; फिर लॉगिन करें।" });
    if (error?.status === 403) return json(403, { success: false, error: "इस खाते को Main Admin अनुमति नहीं है।" });
    if (error?.status === 409) return json(409, { success: false, error: "Refund रिकॉर्ड पहले से final या reconciliation की प्रतीक्षा में है।" });
    return json(502, { success: false, error: "Refund सुरक्षित रूप से शुरू नहीं हो सका। कृपया रिकॉर्ड जाँचें।" });
  }
};
