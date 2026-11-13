// SRK ELECTRONIC electrician application API.
const crypto = require("crypto");
// Server-side only: keep SUPABASE_SERVICE_ROLE_KEY in Netlify environment variables.
const SUPABASE_URL = process.env.SUPABASE_URL;
const SUPABASE_SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;

const json = (statusCode, body) => ({
  statusCode,
  headers: {
    "Content-Type": "application/json; charset=utf-8",
    "Cache-Control": "no-store"
  },
  body: JSON.stringify(body)
});

const clean = (value, max = 500) =>
  typeof value === "string" ? value.trim().slice(0, max) : "";

async function checkPublicRateLimit(endpoint, ipHash, limit) {
  const response = await fetch(`${SUPABASE_URL}/rest/v1/rpc/srk_check_public_rate_limit`, {
    method: "POST",
    headers: {
      apikey: SUPABASE_SERVICE_ROLE_KEY,
      Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
      "Content-Type": "application/json"
    },
    body: JSON.stringify({ p_endpoint: endpoint, p_ip_hash: ipHash, p_limit: limit })
  });
  if (!response.ok) throw new Error("Rate-limit database request failed");
  return (await response.json()) === true;
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
    console.error("Missing Supabase server configuration for electrician applications.");
    return json(500, { success: false, error: "सर्वर कॉन्फ़िगरेशन अधूरा है। Admin से संपर्क करें।" });
  }

  const clientIp = event.headers?.["x-nf-client-connection-ip"] || event.headers?.["X-Nf-Client-Connection-Ip"];
  if (typeof clientIp !== "string" || !clientIp.trim()) {
    return json(503, { success: false, error: "सुरक्षा जाँच अभी उपलब्ध नहीं है। कृपया थोड़ी देर बाद कोशिश करें।" });
  }
  try {
    const ipHash = crypto.createHash("sha256").update(clientIp.trim()).digest("hex");
    const allowed = await checkPublicRateLimit("application", ipHash, 3);
    if (!allowed) return {
      ...json(429, { success: false, error: "इस मोबाइल नेटवर्क से बहुत अधिक आवेदन आए हैं। कृपया कुछ देर बाद कोशिश करें।" }),
      headers: { "Content-Type": "application/json; charset=utf-8", "Cache-Control": "no-store", "Retry-After": "3600" }
    };
  } catch (rateError) {
    console.error("Application rate-limit check failed:", rateError.name || "UnknownError");
    return json(503, { success: false, error: "आवेदन सुरक्षा जाँच अस्थायी रूप से उपलब्ध नहीं है। कृपया बाद में कोशिश करें।" });
  }

  try {
    const body = JSON.parse(event.body || "{}");
    const full_name = clean(body.full_name, 100);
    const phone = clean(body.phone, 10);
    const state = clean(body.state, 100);
    const district = clean(body.district, 100);
    const pincode = clean(body.pincode, 6);
    const allowedSkills = ['घर की वायरिंग','इलेक्ट्रिकल रिपेयर','लाइट / फैन फिटिंग','MCB / DB / इन्वर्टर','मोटर / पंप','होम रिपेयरिंग','अन्य इलेक्ट्रिकल काम','सभी इलेक्ट्रिकल काम'];
    const submittedSkills = Array.isArray(body.skills) ? body.skills : [body.skills];
    const skillsList = [...new Set(submittedSkills.map(value => clean(value, 80)).filter(Boolean))];
    const skills = skillsList.join(', ');
    const about = clean(body.about, 2000);
    const location_lat = body.location_lat == null || body.location_lat === '' ? null : Number(body.location_lat);
    const location_lng = body.location_lng == null || body.location_lng === '' ? null : Number(body.location_lng);
    const experience_years = Number(body.experience_years);

    if ((location_lat === null) !== (location_lng === null) || (location_lat !== null && (!Number.isFinite(location_lat) || !Number.isFinite(location_lng) || location_lat < -90 || location_lat > 90 || location_lng < -180 || location_lng > 180))) {
      return json(400, { success: false, error: 'मैप लोकेशन सही नहीं है। दोबारा लोकेशन चुनें।' });
    }
    if (!full_name || !/^[0-9]{10}$/.test(phone) || !state || !district ||
        !/^[0-9]{6}$/.test(pincode) || !skillsList.length ||
        skillsList.some(skill => !allowedSkills.includes(skill)) ||
        (skillsList.includes('सभी इलेक्ट्रिकल काम') && skillsList.length > 1) ||
        !Number.isInteger(experience_years) || experience_years < 0 || experience_years > 60) {
      return json(400, {
        success: false,
        error: "कृपया नाम, सही 10 अंकों का मोबाइल, राज्य, जिला, 6 अंकों का PIN Code, कौशल और 0 से 60 वर्ष का अनुभव भरें।"
      });
    }

    const response = await fetch(
      `${SUPABASE_URL}/rest/v1/electrician_applications?select=id,verification_status`,
      {
        method: "POST",
        headers: {
          apikey: SUPABASE_SERVICE_ROLE_KEY,
          Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
          "Content-Type": "application/json",
          Prefer: "return=representation"
        },
        body: JSON.stringify([{
          full_name, phone, state, district, pincode, location_lat, location_lng, skills,
          experience_years, about: about || null,
          verification_status: "pending",
          active: false
        }])
      }
    );

    const raw = await response.text();
    let data;
    try { data = raw ? JSON.parse(raw) : null; } catch { data = null; }

    if (!response.ok) {
      const error = new Error("Supabase application insert failed");
      error.status = response.status;
      error.code = data && typeof data.code === "string" ? data.code : null;
      console.error("Electrician application database error:", error.status, error.code);
      return json(502, {
        success: false,
        stage: "application_insert",
        http_status: error.status,
        database_code: error.code,
        error: "आवेदन डेटाबेस में सेव नहीं हुआ। कृपया कुछ देर बाद दोबारा कोशिश करें।"
      });
    }

    const application = Array.isArray(data) ? data[0] : null;
    if (!application || !application.id) {
      return json(502, {
        success: false,
        error: "आवेदन सेव होने की पुष्टि नहीं मिली। कृपया Admin से संपर्क करें।"
      });
    }

    return json(200, {
      success: true,
      application_id: application.id,
      verification_status: application.verification_status || "pending",
      message: "आपका इलेक्ट्रिशियन आवेदन सफलतापूर्वक सेव हो गया है। Admin की जाँच और मंजूरी के बाद आगे की प्रक्रिया होगी।"
    });
  } catch (error) {
    console.error("apply-electrician error:", error && error.name ? error.name : "UnknownError");
    return json(500, {
      success: false,
      error: "आवेदन सेव नहीं हो सका। कृपया दोबारा कोशिश करें।"
    });
  }
};
