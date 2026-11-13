// SRK ELECTRONIC booking API.
const crypto = require("crypto");
// Netlify environment variables required: SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY.
// Keep the service-role key in Netlify environment variables only; never commit it.
const SUPABASE_URL = process.env.SUPABASE_URL;
const SUPABASE_SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;

const json = (statusCode, body) => ({
  statusCode,
  headers: { "Content-Type": "application/json; charset=utf-8", "Cache-Control": "no-store" },
  body: JSON.stringify(body)
});

const clean = (value, max = 500) =>
  typeof value === "string" ? value.trim().slice(0, max) : "";

const validDate = (value) => {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(value)) return false;
  const [year, month, day] = value.split("-").map(Number);
  const date = new Date(Date.UTC(year, month - 1, day));
  return date.getUTCFullYear() === year && date.getUTCMonth() === month - 1 && date.getUTCDate() === day;
};

const validTime = (value) => {
  if (!/^\d{2}:\d{2}$/.test(value)) return false;
  const [hour, minute] = value.split(":").map(Number);
  return hour >= 0 && hour <= 23 && minute >= 0 && minute <= 59;
};

// Booking dates are interpreted in the business timezone, not the server's
// deployment timezone. Same-day cutoff/business hours remain an explicit
// policy decision and are deliberately not inferred here.
const indiaToday = (now = new Date()) => {
  const parts = new Intl.DateTimeFormat("en-US", {
    timeZone: "Asia/Kolkata",
    year: "numeric",
    month: "2-digit",
    day: "2-digit"
  }).formatToParts(now);
  const part = (type) => parts.find((item) => item.type === type)?.value || "";
  return part("year") + "-" + part("month") + "-" + part("day");
};

async function supabase(path, options = {}) {
  const response = await fetch(`${SUPABASE_URL}/rest/v1/${path}`, {
    ...options,
    headers: {
      apikey: SUPABASE_SERVICE_ROLE_KEY,
      Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
      "Content-Type": "application/json",
      Prefer: "return=representation",
      ...(options.headers || {})
    }
  });
  const raw = await response.text();
  let data;
  try { data = raw ? JSON.parse(raw) : null; } catch { data = raw; }
  if (!response.ok) {
    console.error("Supabase request failed:", response.status, data && typeof data === "object" && typeof data.code === "string" ? data.code : "database_error");
    const error = new Error("Database request failed");
    error.httpStatus = response.status;
    error.dbCode = data && typeof data === "object" && typeof data.code === "string" ? data.code : null;
    throw error;
  }
  return data;
}

async function checkPublicRateLimit(endpoint, ipHash, limit) {
  const result = await supabase("rpc/srk_check_public_rate_limit", {
    method: "POST",
    body: JSON.stringify({ p_endpoint: endpoint, p_ip_hash: ipHash, p_limit: limit })
  });
  return result === true;
}

async function verifyCustomerSession(authorization, bookingPhone) {
  if (!authorization) { const error = new Error("Customer login required"); error.httpStatus = 401; throw error; }
  const match = /^Bearer ([A-Za-z0-9._~-]+)$/.exec(authorization);
  if (!match || match[1].length > 8192) {
    const error = new Error("Invalid customer session");
    error.httpStatus = 401;
    throw error;
  }
  const response = await fetch(`${SUPABASE_URL}/auth/v1/user`, {
    headers: {
      apikey: SUPABASE_SERVICE_ROLE_KEY,
      Authorization: `Bearer ${match[1]}`
    }
  });
  if (!response.ok) {
    const error = new Error("Customer session could not be verified");
    error.httpStatus = 401;
    throw error;
  }
  const user = await response.json();
  const verifiedPhone = typeof user.phone === "string" ? user.phone.replace(/\D/g, "") : "";
  const submittedPhone = bookingPhone.replace(/\D/g, "");
  const normalizedVerified = verifiedPhone.length === 10 ? "91" + verifiedPhone : verifiedPhone;
  const normalizedSubmitted = submittedPhone.length === 10 ? "91" + submittedPhone : submittedPhone;
  if (!user.id || !user.phone_confirmed_at || normalizedVerified !== normalizedSubmitted) {
    const error = new Error("Verified account phone must match booking phone");
    error.httpStatus = 403;
    throw error;
  }
  return user.id;
}

exports.handler = async (event) => {
  if (event.httpMethod !== "POST") {
    return json(405, { success: false, error: "केवल POST अनुरोध स्वीकार है।" });
  }
  // Reject oversized requests before parsing or contacting Supabase.
  if (typeof event.body === "string" && Buffer.byteLength(event.body, "utf8") > 16384) {
    return json(413, { success: false, error: "अनुरोध बहुत बड़ा है। कृपया जानकारी कम करके दोबारा भेजें।" });
  }
  if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
    console.error("Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY.");
    return json(500, { success: false, error: "सर्वर कॉन्फ़िगरेशन अधूरा है। Admin से संपर्क करें।" });
  }

  let body;
  try {
    body = JSON.parse(event.body || "{}");
  } catch {
    return json(400, { success: false, error: "अनुरोध का डेटा सही JSON प्रारूप में नहीं है। कृपया दोबारा कोशिश करें।" });
  }
  if (!body || typeof body !== "object" || Array.isArray(body)) {
    return json(400, { success: false, error: "बुकिंग की जानकारी सही प्रारूप में नहीं है।" });
  }

  try {
    const customer_name = clean(body.customer_name, 100);
    // Do not truncate malformed phone input into a different, apparently valid number.
    const phone = clean(body.phone, 20);
    const state = clean(body.state, 100);
    const district = clean(body.district, 100);
    // Preserve malformed suffixes so validation rejects them instead of truncating into a valid PIN.
    const pincode = clean(body.pincode, 32);
    const address = clean(body.address, 1000);
    const location_lat = body.location_lat == null || body.location_lat === '' ? null : Number(body.location_lat);
    const location_lng = body.location_lng == null || body.location_lng === '' ? null : Number(body.location_lng);
    const categoryLabels = {
      home_wiring: "घर की वायरिंग",
      electrical_repair: "इलेक्ट्रिकल रिपेयर",
      light_fan_fitting: "लाइट / फैन फिटिंग",
      home_repair: "होम रिपेयरिंग",
      other: "अन्य"
    };
    const selected_category = clean(body.selected_category, 40);
    const selected_duration_hours = body.selected_duration_hours;
    const service_type = categoryLabels[selected_category] || "";
    // Date/time inputs are structured values: never truncate malformed suffixes into valid values.
    const preferred_date = clean(body.preferred_date, 32);
    const preferred_time = clean(body.preferred_time, 32);
    const work_details = clean(body.work_details, 2000);
    const submittedPaymentMethod = clean(body.payment_method, 80) || "Cash";
    // Keep booking choices aligned with the customer form. Accept the older
    // Hindi cash label as a compatibility alias, but persist one canonical value.
    const paymentMethods = {
      Cash: "Cash",
      "नकद (Cash)": "Cash",
      "Razorpay ऑनलाइन भुगतान": "Razorpay ऑनलाइन भुगतान"
    };
    const payment_method = paymentMethods[submittedPaymentMethod] || "";
    const quoted_amount = body.quoted_amount == null || body.quoted_amount === ""
      ? null : Number(body.quoted_amount);
    const customer_user_id = await verifyCustomerSession(
      event.headers?.authorization || event.headers?.Authorization || "",
      phone
    );
    const requestKey = event.headers?.["idempotency-key"] || event.headers?.["Idempotency-Key"] || "";
    if (!/^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(requestKey)) {
      return json(400, { success: false, error: "बुकिंग अनुरोध की सुरक्षा पहचान उपलब्ध नहीं है। कृपया पेज रीफ़्रेश करके दोबारा कोशिश करें।" });
    }

    if (!customer_name || !/^[0-9]{10}$/.test(phone) || !state || !district ||
        !/^[0-9]{6}$/.test(pincode) || !address || !service_type ||
        !Number.isInteger(selected_duration_hours) || selected_duration_hours < 1 || selected_duration_hours > 8 ||
        !payment_method || !validDate(preferred_date) || preferred_date < indiaToday() || !validTime(preferred_time)) {
      return json(400, { success: false, error: "कृपया नाम, सही 10 अंकों का मोबाइल, राज्य, जिला, 6 अंकों का PIN Code, पता, मान्य सर्विस श्रेणी, 1–8 घंटे की अवधि और सही तारीख/समय भरें। पिछली तारीख की बुकिंग स्वीकार नहीं है।" });
    }
    if ((location_lat === null) !== (location_lng === null) || (location_lat !== null && (!Number.isFinite(location_lat) || !Number.isFinite(location_lng) || location_lat < -90 || location_lat > 90 || location_lng < -180 || location_lng > 180))) {
      return json(400, { success: false, error: 'मैप लोकेशन सही नहीं है। दोबारा लोकेशन चुनें।' });
    }
    if (quoted_amount !== null &&
        (!Number.isFinite(quoted_amount) || quoted_amount <= 0 || quoted_amount > 10000000)) {
      return json(400, { success: false, error: "भुगतान राशि सही नहीं है।" });
    }

    const fingerprintPayload = {
      customer_name, phone, state, district, pincode, address, service_type,
      selected_category, selected_duration_hours, preferred_date, preferred_time,
      work_details, payment_method, quoted_amount, location_lat, location_lng
    };
    const requestFingerprint = crypto.createHash("sha256")
      .update(JSON.stringify(fingerprintPayload)).digest("hex");
    // Resolve a previously-created request before rate limiting. Only an exact
    // owner + key + payload match may replay; it creates no new booking.
    const existing = await supabase(
      "service_bookings?select=id,customer_request_fingerprint&customer_request_key=eq." +
      encodeURIComponent(requestKey) + "&customer_user_id=eq." + encodeURIComponent(customer_user_id) + "&limit=1",
      { method: "GET" }
    );
    const prior = Array.isArray(existing) ? existing[0] : null;
    if (prior?.id && prior.customer_request_fingerprint !== requestFingerprint) {
      return json(409, { success: false, error: "इस बुकिंग अनुरोध की जानकारी बदल गई है। कृपया नई बुकिंग शुरू करके दोबारा भेजें।" });
    }

    let booking = prior?.id ? { id: prior.id } : null;
    let idempotentReplay = Boolean(prior?.id);
    if (!booking) {
      // Rate-limit only genuinely new bookings. Safe retries of an existing,
      // identical idempotency key do not consume another submission slot.
      const clientIp = event.headers?.["x-nf-client-connection-ip"] || event.headers?.["X-Nf-Client-Connection-Ip"];
      if (typeof clientIp !== "string" || !clientIp.trim()) {
        return json(503, { success: false, error: "सुरक्षा जाँच अभी उपलब्ध नहीं है। कृपया थोड़ी देर बाद कोशिश करें।" });
      }
      try {
        const ipHash = crypto.createHash("sha256").update(clientIp.trim()).digest("hex");
        const allowed = await checkPublicRateLimit("booking", ipHash, 5);
        if (!allowed) return {
          ...json(429, { success: false, error: "इस मोबाइल नेटवर्क से बहुत अधिक नई बुकिंग आई हैं। कृपया कुछ देर बाद कोशिश करें।" }),
          headers: { "Content-Type": "application/json; charset=utf-8", "Cache-Control": "no-store", "Retry-After": "3600" }
        };
      } catch (rateError) {
        console.error("Booking rate-limit check failed:", rateError.httpStatus || rateError.name || "UnknownError");
        return json(503, { success: false, error: "बुकिंग सुरक्षा जाँच अस्थायी रूप से उपलब्ध नहीं है। कृपया बाद में कोशिश करें।" });
      }

      const inserted = await supabase("service_bookings", {
        method: "POST",
        headers: { Prefer: "resolution=ignore-duplicates,return=representation" },
        body: JSON.stringify([{
          customer_name, phone, state, district, pincode, address, service_type,
          selected_category, selected_duration_hours, preferred_date, preferred_time, work_details, payment_method, quoted_amount, location_lat, location_lng,
          customer_request_key: requestKey, customer_request_fingerprint: requestFingerprint,
          status: "new", payment_status: "unpaid", customer_user_id
        }])
      });
      booking = Array.isArray(inserted) ? inserted[0] : null;
      if (!booking?.id) {
        // Another concurrent request may have inserted the same key after the
        // preflight lookup. Confirm it is the same owner and exact same payload.
        const raced = await supabase(
          "service_bookings?select=id,customer_request_fingerprint&customer_request_key=eq." +
          encodeURIComponent(requestKey) + "&customer_user_id=eq." + encodeURIComponent(customer_user_id) + "&limit=1",
          { method: "GET" }
        );
        const racedPrior = Array.isArray(raced) ? raced[0] : null;
        if (!racedPrior?.id || racedPrior.customer_request_fingerprint !== requestFingerprint) {
          return json(409, { success: false, error: "यह बुकिंग अनुरोध पहले इस्तेमाल हो चुका है। कृपया नई बुकिंग शुरू करके दोबारा कोशिश करें।" });
        }
        booking = { id: racedPrior.id };
        idempotentReplay = true;
      }
    }

    // Supabase's broadcast_new_booking trigger creates offers exactly once.
    // Read the resulting queue here; do not create duplicate job_offers from this function.
    let offerRows = [];
    let offerStatusChecked = true;
    try {
      const offers = await supabase(
        "job_offers?select=id,match_level&booking_id=eq." + encodeURIComponent(booking.id)
      );
      offerRows = Array.isArray(offers) ? offers : [];
    } catch (offerError) {
      offerStatusChecked = false;
      console.error("Booking saved; offer queue read failed:", offerError.httpStatus || offerError.name || "UnknownError");
    }
    const offersCreated = offerRows.length;
    const matchLevel = offerRows[0]?.match_level || null;

    return json(200, {
      success: true,
      booking_id: booking.id,
      idempotent_replay: idempotentReplay,
      offers_created: offersCreated,
      match_level: offersCreated ? matchLevel : null,
      message: !offerStatusChecked
        ? "बुकिंग सेव हो गई है, लेकिन ऑफर की स्थिति अभी जाँची नहीं जा सकी। हमारी टीम से पुष्टि करें।"
        : offersCreated
          ? `बुकिंग सेव हो गई। ${offersCreated} approved और active इलेक्ट्रिशियन को ${matchLevel === "pincode" ? "इसी PIN Code" : "इसी जिले"} का ऑफर बनाया गया है।`
          : "बुकिंग सेव हो गई। इस PIN Code या जिले में अभी कोई approved और active इलेक्ट्रिशियन उपलब्ध नहीं मिला।"
    });
  } catch (error) {
    if (error.httpStatus === 401 || error.httpStatus === 403) {
      return json(error.httpStatus, {
        success: false,
        error: error.httpStatus === 401
          ? "आपका लॉगिन सत्र समाप्त हो गया है। कृपया दोबारा OTP लॉगिन करें।"
          : "लॉगिन मोबाइल नंबर और बुकिंग मोबाइल नंबर एक जैसे होने चाहिए।"
      });
    }
    console.error("create-booking error:", error.httpStatus || error.name || "UnknownError");
    return json(500, { success: false, error: "बुकिंग सेव नहीं हो सकी। कृपया कुछ देर बाद दोबारा कोशिश करें।" });
  }
};
