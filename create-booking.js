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

async function verifyCustomerSession(authorization) {
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
  const digits = typeof user.phone === "string" ? user.phone.replace(/\D/g, "") : "";
  const verifiedPhone = digits.length === 10 ? digits : digits.length === 12 && digits.startsWith("91") ? digits.slice(2) : "";
  if (!user.id || !user.phone_confirmed_at || !/^[0-9]{10}$/.test(verifiedPhone)) {
    const error = new Error("OTP-verified account phone is required");
    error.httpStatus = 403;
    throw error;
  }
  // The Auth-verified number is authoritative. Never trust a client-supplied phone.
  return { userId: user.id, phone: verifiedPhone };
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

  const clientIp = event.headers?.["x-nf-client-connection-ip"] || event.headers?.["X-Nf-Client-Connection-Ip"];
  if (typeof clientIp !== "string" || !clientIp.trim()) {
    return json(503, { success: false, error: "सुरक्षा जाँच अभी उपलब्ध नहीं है। कृपया थोड़ी देर बाद कोशिश करें।" });
  }
  try {
    const ipHash = crypto.createHash("sha256").update(clientIp.trim()).digest("hex");
    const allowed = await checkPublicRateLimit("booking", ipHash, 5);
    if (!allowed) return {
      ...json(429, { success: false, error: "इस मोबाइल नेटवर्क से बहुत अधिक बुकिंग अनुरोध आए हैं। कृपया कुछ देर बाद कोशिश करें।" }),
      headers: { "Content-Type": "application/json; charset=utf-8", "Cache-Control": "no-store", "Retry-After": "3600" }
    };
  } catch (rateError) {
    console.error("Booking rate-limit check failed:", rateError.httpStatus || rateError.name || "UnknownError");
    return json(503, { success: false, error: "बुकिंग सुरक्षा जाँच अस्थायी रूप से उपलब्ध नहीं है। कृपया बाद में कोशिश करें।" });
  }

  try {
    const body = JSON.parse(event.body || "{}");
    const customer_name = clean(body.customer_name, 100);
    // Phone is derived exclusively from the verified Supabase Auth session.
    const state = clean(body.state, 100);
    const district = clean(body.district, 100);
    const pincode = clean(body.pincode, 6);
    const address = clean(body.address, 1000);
    const location_lat = body.location_lat == null || body.location_lat === '' ? null : Number(body.location_lat);
    const location_lng = body.location_lng == null || body.location_lng === '' ? null : Number(body.location_lng);
    let service_type = clean(body.service_type, 120);
    const masterServiceCode = clean(body.srk_service_code, 80);
    const masterRateLevelCode = clean(body.srk_rate_level_code, 80);
    const masterDurationMinutes = body.srk_duration_minutes == null || body.srk_duration_minutes === ""
      ? null : Number(body.srk_duration_minutes);
    const masterServiceQuantity = body.srk_service_quantity == null || body.srk_service_quantity === ""
      ? 1 : Number(body.srk_service_quantity);
    const masterRequiredTechnicians = body.srk_required_technician_count == null || body.srk_required_technician_count === ""
      ? 1 : Number(body.srk_required_technician_count);
    const masterHelperIncluded = body.srk_helper_included === true;
    const isMasterBooking = Boolean(masterServiceCode || masterRateLevelCode);
    const selected_category = isMasterBooking ? null : clean(body.selected_category, 40);
    const selected_rate_tier = isMasterBooking ? null : clean(body.selected_rate_tier, 40);
    const selected_duration_hours = isMasterBooking ? null : Number(body.selected_duration_hours);
    const legacyRateCard = { electrical_assistant: 89900, skilled_electrician: 119900, expert_electrician: 159900, premium_electrical_specialist: 199900 };
    let rateCardVersion = "SRK-CUSTOMER-LABOUR-2026-11-13-V1";
    let masterRate = null;
    let estimatedLabourPaise = null;
    let rate8hPaise = null;
    // SRK ELECTRONIC accepts immediate service requests only; ignore legacy schedule fields.
    const preferred_date = null;
    const preferred_time = null;
const work_details = clean(body.work_details, 2000);
    const payment_method = clean(body.payment_method, 80) || "नकद (Cash)";
    if (!["Cash", "नकद (Cash)", "Razorpay ऑनलाइन भुगतान"].includes(payment_method)) {
      return json(400, { success: false, error: "कृपया Cash या Razorpay ऑनलाइन भुगतान में से एक तरीका चुनें।" });
    }
    const verifiedCustomer = await verifyCustomerSession(
      event.headers?.authorization || event.headers?.Authorization || ""
    );
    const customer_user_id = verifiedCustomer.userId;
    const phone = verifiedCustomer.phone;
    const idempotencyKey = event.headers?.["idempotency-key"] || event.headers?.["Idempotency-Key"] || "";
    if (!/^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(idempotencyKey)) {
      return json(400, { success: false, error: "बुकिंग अनुरोध की सुरक्षित पहचान नहीं मिली। कृपया दोबारा कोशिश करें।" });
    }

    if (isMasterBooking && process.env.SRK_MASTER_BOOKING_ENABLED !== "true") {
      return json(503, { success: false, code: "MASTER_BOOKING_BACKEND_NOT_READY",
        error: "नई Master Booking अभी सुरक्षित rollout के लिए तैयार नहीं है। कृपया थोड़ी देर बाद कोशिश करें।" });
    }
    if (!isMasterBooking && process.env.SRK_LEGACY_ELECTRICIAN_BOOKING_ENABLED !== "true") {
      return json(503, { success: false, code: "LEGACY_BOOKING_RATE_CARD_RETIRED",
        error: "पुरानी Booking Rate List बंद की जा चुकी है। नई Master Rate List तैयार होने पर बुकिंग शुरू होगी।" });
    }
    if (!customer_name || !state || !district ||
        !/^[0-9]{6}$/.test(pincode) || !address ||
        (isMasterBooking
          ? (!masterServiceCode || !masterRateLevelCode ||
             !Number.isInteger(masterRequiredTechnicians) || masterRequiredTechnicians < 1 || masterRequiredTechnicians > 10 ||
             !Number.isInteger(masterServiceQuantity) || masterServiceQuantity < 1 || masterServiceQuantity > 100 ||
             (body.srk_helper_included != null && typeof body.srk_helper_included !== "boolean"))
          : (!service_type ||
             !["home_wiring", "electrical_repair", "light_fan_fitting", "home_repair", "other"].includes(selected_category) ||
             !Object.prototype.hasOwnProperty.call(legacyRateCard, selected_rate_tier) ||
             !Number.isInteger(selected_duration_hours) || selected_duration_hours < 1 || selected_duration_hours > 8))) {
      return json(400, { success: false, error: "कृपया नाम, राज्य, जिला, 6 अंकों का PIN Code, पता और सही सेवा/रेट विकल्प भरें।" });
    }
    if ((location_lat === null) !== (location_lng === null) || (location_lat !== null && (!Number.isFinite(location_lat) || !Number.isFinite(location_lng) || location_lat < -90 || location_lat > 90 || location_lng < -180 || location_lng > 180))) {
      return json(400, { success: false, error: 'मैप लोकेशन सही नहीं है। दोबारा लोकेशन चुनें।' });
    }

    if (!isMasterBooking) {
      rate8hPaise = legacyRateCard[selected_rate_tier];
      estimatedLabourPaise = Math.floor((rate8hPaise * selected_duration_hours) / 8 + 0.5);
    }
    const requestFingerprint = crypto.createHash("sha256").update(JSON.stringify({
      customer_user_id, customer_name, phone, state, district, pincode, address,
      location_lat, location_lng, service_type: isMasterBooking ? masterServiceCode : service_type, selected_category, selected_rate_tier,
      selected_duration_hours, work_details, payment_method,
      ...(isMasterBooking ? {
        srk_service_code: masterServiceCode, srk_rate_level_code: masterRateLevelCode,
        srk_duration_minutes: masterDurationMinutes, srk_service_quantity: masterServiceQuantity,
        srk_required_technician_count: masterRequiredTechnicians,
        srk_helper_included: masterHelperIncluded
      } : {})
    })).digest("hex");
    const findByRequestKey = () => supabase(
      "service_bookings?select=id,customer_user_id,customer_request_fingerprint,srk_estimated_labour_paise,srk_rate_version_snapshot,srk_billing_model_snapshot,srk_technician_hourly_paise_snapshot,srk_helper_hourly_paise_snapshot,srk_helper_included_snapshot,srk_required_technician_count,srk_fixed_labour_paise_snapshot&customer_request_key=eq." + encodeURIComponent(idempotencyKey),
      { method: "GET" }
    );
    const existingRows = await findByRequestKey();
    const existing = Array.isArray(existingRows) ? existingRows[0] : null;
    if (existing) {
      if (existing.customer_user_id !== customer_user_id || existing.customer_request_fingerprint !== requestFingerprint) {
        return json(409, { success: false, error: "यह बुकिंग अनुरोध पहचान पहले अलग जानकारी के साथ इस्तेमाल हो चुकी है। नई बुकिंग शुरू करें।" });
      }
      const priorOffers = await supabase(
        isMasterBooking
          ? "srk_technician_dispatch_offers?select=id,match_level&booking_id=eq." + encodeURIComponent(existing.id)
          : "job_offers?select=id,match_level&booking_id=eq." + encodeURIComponent(existing.id)
      );
      const priorOfferRows = Array.isArray(priorOffers) ? priorOffers : [];
      const priorAmount = existing.srk_estimated_labour_paise ?? estimatedLabourPaise;
      return json(200, { success: true, booking_id: existing.id, replayed: true,
        estimate: { amount_paise: priorAmount, amount_rupees: (priorAmount / 100).toFixed(2),
          rate8h_paise: rate8hPaise, rate_card_version: existing.srk_rate_version_snapshot || rateCardVersion,
          ...(isMasterBooking ? { billing_model: existing.srk_billing_model_snapshot,
            technician_hourly_paise: existing.srk_technician_hourly_paise_snapshot,
            helper_hourly_paise: existing.srk_helper_hourly_paise_snapshot,
            technician_8h_paise: existing.srk_technician_hourly_paise_snapshot == null ? null : Number(existing.srk_technician_hourly_paise_snapshot) * 8,
            helper_8h_paise: existing.srk_helper_hourly_paise_snapshot == null ? null : Number(existing.srk_helper_hourly_paise_snapshot) * 8,
            combined_8h_paise: existing.srk_technician_hourly_paise_snapshot == null ? null : (Number(existing.srk_technician_hourly_paise_snapshot) + (existing.srk_helper_included_snapshot ? Number(existing.srk_helper_hourly_paise_snapshot) : 0)) * 8,
            helper_included: existing.srk_helper_included_snapshot === true,
            required_technician_count: existing.srk_required_technician_count,
            fixed_labour_paise: existing.srk_fixed_labour_paise_snapshot } : {}) },
        offers_created: priorOfferRows.length, match_level: priorOfferRows[0]?.match_level || null,
        message: "पहले से सेव की गई यही बुकिंग मिली है; नई डुप्लीकेट बुकिंग नहीं बनाई गई।" });
    }
    if (isMasterBooking) {
      const rateRows = await supabase("rpc/srk_customer_get_service_rate", {
        method: "POST",
        body: JSON.stringify({ p_service_code: masterServiceCode, p_level_code: masterRateLevelCode })
      });
      masterRate = Array.isArray(rateRows) ? rateRows[0] : null;
      if (!masterRate) {
        return json(409, { success: false, code: "SERVICE_RATE_NOT_AVAILABLE",
          error: "इस सेवा की दर अभी Admin द्वारा सक्रिय नहीं की गई है। कृपया दूसरी सक्रिय सेवा चुनें।" });
      }
      service_type = masterRate.service_name;
      rateCardVersion = masterRate.rate_version;
      if (masterRate.billing_model === "hourly") {
        if (masterServiceQuantity !== 1) {
          return json(400, { success: false, error: "Hourly सेवा में quantity 1 रखें; अतिरिक्त Technician संख्या अलग चुनें।" });
        }
        if (!Number.isInteger(masterDurationMinutes) || masterDurationMinutes < 1 || masterDurationMinutes > 72000) {
          return json(400, { success: false, error: "घंटे के हिसाब से सेवा के लिए 1 मिनट से 50 दिन तक की सही अवधि चुनें।" });
        }
        const technicianHourly = Number(masterRate.technician_hourly_paise);
        const helperHourly = Number(masterRate.helper_hourly_paise);
        if (!Number.isSafeInteger(technicianHourly) || !Number.isSafeInteger(helperHourly) ||
            technicianHourly <= 0 || helperHourly < 0 || (masterHelperIncluded && helperHourly <= 0)) {
          throw new Error("Invalid active hourly rate configuration");
        }
        const selectedHourly = technicianHourly + (masterHelperIncluded ? helperHourly : 0);
        estimatedLabourPaise = Math.floor((selectedHourly * masterRequiredTechnicians * masterDurationMinutes) / 60 + 0.5);
      } else if (masterRate.billing_model === "fixed_per_unit") {
        if (masterHelperIncluded || masterDurationMinutes !== null || !Number.isSafeInteger(Number(masterRate.fixed_labour_paise)) ||
            Number(masterRate.fixed_labour_paise) <= 0) {
          return json(400, { success: false, error: "Fixed-price सेवा के लिए अवधि नहीं, सही quantity चुनें।" });
        }
        estimatedLabourPaise = Number(masterRate.fixed_labour_paise) * masterServiceQuantity;
      } else {
        throw new Error("Unsupported active billing model");
      }
      if (!Number.isSafeInteger(estimatedLabourPaise) || estimatedLabourPaise <= 0 || estimatedLabourPaise > 100000000000) {
        return json(400, { success: false, error: "सेवा का अनुमानित मेहनताना सीमा से बाहर है।" });
      }
    } else {
      rate8hPaise = legacyRateCard[selected_rate_tier];
      estimatedLabourPaise = Math.floor((rate8hPaise * selected_duration_hours) / 8 + 0.5);
    }
    let inserted;
    try {
      inserted = await supabase("service_bookings", {
        method: "POST",
        body: JSON.stringify([{
          customer_name, phone, state, district, pincode, address, service_type,
          selected_category, selected_rate_tier, selected_duration_hours,
          estimated_labour_paise: isMasterBooking ? null : estimatedLabourPaise,
          estimate_rate_card_version: isMasterBooking ? null : rateCardVersion,
          customer_request_key: idempotencyKey,
          customer_request_fingerprint: requestFingerprint,
          preferred_date, preferred_time, work_details, payment_method, location_lat, location_lng,
          ...(isMasterBooking ? {
            srk_service_category_code: masterRate.category_code,
            srk_service_skill_code: masterRate.skill_code,
            srk_required_technician_count: masterRequiredTechnicians,
            srk_service_code: masterRate.service_code,
            srk_rate_level_code: masterRate.level_code,
            srk_rate_level_label_snapshot: masterRate.level_label,
            srk_rate_version_snapshot: masterRate.rate_version,
            srk_billing_model_snapshot: masterRate.billing_model,
            srk_technician_hourly_paise_snapshot: masterRate.billing_model === "hourly" ? Number(masterRate.technician_hourly_paise) : null,
            srk_helper_hourly_paise_snapshot: masterRate.billing_model === "hourly" ? Number(masterRate.helper_hourly_paise) : null,
            srk_helper_included_snapshot: masterRate.billing_model === "hourly" ? masterHelperIncluded : false,
            srk_fixed_labour_paise_snapshot: masterRate.billing_model === "fixed_per_unit" ? Number(masterRate.fixed_labour_paise) : null,
            srk_estimated_labour_paise: estimatedLabourPaise,
            srk_duration_minutes: masterRate.billing_model === "hourly" ? masterDurationMinutes : null,
            srk_service_quantity: masterServiceQuantity
          } : {}),
          status: "new", payment_status: "unpaid",
          ...(customer_user_id ? { customer_user_id } : {})
        }])
      });
    } catch (insertError) {
      if (insertError.dbCode !== "23505") throw insertError;
      const racedRows = await findByRequestKey();
      const raced = Array.isArray(racedRows) ? racedRows[0] : null;
      if (!raced || raced.customer_user_id !== customer_user_id || raced.customer_request_fingerprint !== requestFingerprint) throw insertError;
      const racedOffers = await supabase(
        isMasterBooking
          ? "srk_technician_dispatch_offers?select=id,match_level&booking_id=eq." + encodeURIComponent(raced.id)
          : "job_offers?select=id,match_level&booking_id=eq." + encodeURIComponent(raced.id)
      );
      const racedOfferRows = Array.isArray(racedOffers) ? racedOffers : [];
      const racedAmount = raced.srk_estimated_labour_paise ?? estimatedLabourPaise;
      return json(200, { success: true, booking_id: raced.id, replayed: true,
        estimate: { amount_paise: racedAmount, amount_rupees: (racedAmount / 100).toFixed(2),
          rate8h_paise: rate8hPaise, rate_card_version: raced.srk_rate_version_snapshot || rateCardVersion,
          ...(isMasterBooking ? { billing_model: raced.srk_billing_model_snapshot,
            technician_hourly_paise: raced.srk_technician_hourly_paise_snapshot,
            helper_hourly_paise: raced.srk_helper_hourly_paise_snapshot,
            technician_8h_paise: raced.srk_technician_hourly_paise_snapshot == null ? null : Number(raced.srk_technician_hourly_paise_snapshot) * 8,
            helper_8h_paise: raced.srk_helper_hourly_paise_snapshot == null ? null : Number(raced.srk_helper_hourly_paise_snapshot) * 8,
            combined_8h_paise: raced.srk_technician_hourly_paise_snapshot == null ? null : (Number(raced.srk_technician_hourly_paise_snapshot) + (raced.srk_helper_included_snapshot ? Number(raced.srk_helper_hourly_paise_snapshot) : 0)) * 8,
            helper_included: raced.srk_helper_included_snapshot === true,
            required_technician_count: raced.srk_required_technician_count,
            fixed_labour_paise: raced.srk_fixed_labour_paise_snapshot } : {}) },
        offers_created: racedOfferRows.length, match_level: racedOfferRows[0]?.match_level || null,
        message: "पहले से सेव की गई यही बुकिंग मिली है; नई डुप्लीकेट बुकिंग नहीं बनाई गई।" });
    }
    const booking = Array.isArray(inserted) ? inserted[0] : null;
    if (!booking || !booking.id) throw new Error("Booking insert returned no booking ID.");

    // Supabase's broadcast_new_booking trigger creates offers exactly once.
    // Read the resulting queue here; do not create duplicate job_offers from this function.
    let offerRows = [];
    let offerStatusChecked = true;
    try {
      const offers = await supabase(
        isMasterBooking
          ? "srk_technician_dispatch_offers?select=id,match_level&booking_id=eq." + encodeURIComponent(booking.id)
          : "job_offers?select=id,match_level&booking_id=eq." + encodeURIComponent(booking.id)
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
      estimate: { amount_paise: estimatedLabourPaise, amount_rupees: (estimatedLabourPaise / 100).toFixed(2), rate8h_paise: rate8hPaise, rate_card_version: rateCardVersion,
        ...(isMasterBooking ? { billing_model: masterRate.billing_model,
          technician_hourly_paise: masterRate.technician_hourly_paise,
          helper_hourly_paise: masterRate.helper_hourly_paise,
          technician_8h_paise: masterRate.billing_model === "hourly" ? Number(masterRate.technician_hourly_paise) * 8 : null,
          helper_8h_paise: masterRate.billing_model === "hourly" ? Number(masterRate.helper_hourly_paise) * 8 : null,
          combined_8h_paise: masterRate.billing_model === "hourly" ? (Number(masterRate.technician_hourly_paise) + (masterHelperIncluded ? Number(masterRate.helper_hourly_paise) : 0)) * 8 : null,
          helper_included: masterRate.billing_model === "hourly" ? masterHelperIncluded : false,
          required_technician_count: masterRequiredTechnicians,
          team_8h_paise: masterRate.billing_model === "hourly" ? (Number(masterRate.technician_hourly_paise) + (masterHelperIncluded ? Number(masterRate.helper_hourly_paise) : 0)) * 8 * masterRequiredTechnicians : null,
          fixed_labour_paise: masterRate.fixed_labour_paise, unit_label: masterRate.unit_label } : {}) },
      offers_created: offersCreated,
      match_level: offersCreated ? matchLevel : null,
      message: !offerStatusChecked
        ? "बुकिंग सेव हो गई है, लेकिन ऑफर की स्थिति अभी जाँची नहीं जा सकी। हमारी टीम से पुष्टि करें।"
        : offersCreated
          ? (isMasterBooking
          ? `बुकिंग सेव हो गई। आपकी चुनी हुई सेवा के approved Technician को ${matchLevel === "nearby_30km" ? "30 km के दायरे में" : "उपलब्धता के अनुसार"} पहला ऑफर भेजा गया है।`
          : `बुकिंग सेव हो गई। आपकी चुनी हुई श्रेणी के एक approved और active इलेक्ट्रिशियन को ${matchLevel === "pincode" ? "इसी PIN Code" : "इसी जिले"} का पहला ऑफर भेजा गया है। जवाब न मिलने या अस्वीकार होने पर अगला eligible इलेक्ट्रिशियन चुना जाएगा।`)
          : (isMasterBooking
            ? "बुकिंग सेव हो गई। अभी इस सेवा के लिए कोई eligible Technician उपलब्ध नहीं मिला या GPS लोकेशन की प्रतीक्षा है।"
            : "बुकिंग सेव हो गई। इस PIN Code या जिले में अभी कोई approved और active इलेक्ट्रिशियन उपलब्ध नहीं मिला।")
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
