// Privacy-safe electrician application status API.
// Only an OTP-verified Supabase phone session matching the submitted application phone can read its status.
const crypto = require("crypto");
const SUPABASE_URL = process.env.SUPABASE_URL;
const SUPABASE_SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;

const json = (statusCode, body, extraHeaders = {}) => ({
  statusCode,
  headers: { "Content-Type": "application/json; charset=utf-8", "Cache-Control": "no-store", ...extraHeaders },
  body: JSON.stringify(body)
});

async function checkPublicRateLimit(endpoint, ipHash, limit) {
  const response = await fetch(`${SUPABASE_URL}/rest/v1/rpc/srk_check_public_rate_limit`, {
    method: "POST",
    headers: { apikey: SUPABASE_SERVICE_ROLE_KEY, Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`, "Content-Type": "application/json" },
    body: JSON.stringify({ p_endpoint: endpoint, p_ip_hash: ipHash, p_limit: limit })
  });
  if (!response.ok) throw new Error("Rate-limit database request failed");
  return (await response.json()) === true;
}

exports.handler = async (event) => {
  if (event.httpMethod !== "GET") return json(405, { success: false, error: "केवल GET अनुरोध स्वीकार है।" }, { Allow: "GET" });
  if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) return json(500, { success: false, error: "स्थिति सेवा अभी कॉन्फ़िगर नहीं है।" });

  const authorization = event.headers?.authorization || event.headers?.Authorization || "";
  const tokenMatch = /^Bearer\s+([^\s]+)$/i.exec(authorization);
  if (!tokenMatch) return json(401, { success: false, error: "आवेदन की स्थिति देखने के लिए पहले मोबाइल OTP सत्यापित करें।" });

  const clientIp = event.headers?.["x-nf-client-connection-ip"] || event.headers?.["X-Nf-Client-Connection-Ip"];
  if (typeof clientIp !== "string" || !clientIp.trim()) return json(503, { success: false, error: "सुरक्षा जाँच अभी उपलब्ध नहीं है।" });

  try {
    const ipHash = crypto.createHash("sha256").update(clientIp.trim()).digest("hex");
    if (!(await checkPublicRateLimit("application_status", ipHash, 10))) {
      return json(429, { success: false, error: "बहुत अधिक प्रयास हुए हैं। कृपया कुछ देर बाद कोशिश करें।" }, { "Retry-After": "3600" });
    }

    // Validate the bearer token with Supabase Auth; never trust decoded JWT claims alone.
    const authResponse = await fetch(`${SUPABASE_URL}/auth/v1/user`, {
      headers: { apikey: SUPABASE_SERVICE_ROLE_KEY, Authorization: `Bearer ${tokenMatch[1]}` }
    });
    if (!authResponse.ok) return json(401, { success: false, error: "मोबाइल OTP सेशन मान्य नहीं है। दोबारा OTP सत्यापित करें।" });
    const user = await authResponse.json();
    if (!user || !user.id || !user.phone || !user.phone_confirmed_at) {
      return json(403, { success: false, error: "आवेदन की स्थिति के लिए सत्यापित मोबाइल नंबर आवश्यक है।" });
    }
    const digits = String(user.phone).replace(/\D/g, "");
    const phone = digits.length >= 10 ? digits.slice(-10) : "";
    if (!/^[0-9]{10}$/.test(phone)) return json(403, { success: false, error: "सत्यापित मोबाइल नंबर मान्य नहीं है।" });

    const query = new URLSearchParams({
      select: "id,verification_status,created_at,requested_category,district,state,pincode",
      phone: `eq.${phone}`,
      order: "created_at.desc",
      limit: "10"
    });
    const rowsResponse = await fetch(`${SUPABASE_URL}/rest/v1/electrician_applications?${query.toString()}`, {
      headers: { apikey: SUPABASE_SERVICE_ROLE_KEY, Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}` }
    });
    if (!rowsResponse.ok) throw new Error("Application status query failed");
    const rows = await rowsResponse.json();
    return json(200, {
      success: true,
      applications: (Array.isArray(rows) ? rows : []).map(row => ({
        application_id: row.id,
        status: row.verification_status,
        submitted_at: row.created_at,
        requested_category: row.requested_category,
        district: row.district,
        state: row.state,
        pincode: row.pincode
      })),
      message: Array.isArray(rows) && rows.length ? null : "इस सत्यापित मोबाइल नंबर से कोई आवेदन नहीं मिला।"
    });
  } catch (error) {
    console.error("application-status error:", error && error.name ? error.name : "UnknownError");
    return json(503, { success: false, error: "अभी आवेदन की स्थिति नहीं मिल सकी। कृपया बाद में कोशिश करें।" });
  }
};
