"use strict";

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}(?![\s\S])/i;
const MODULE_ROLES = Object.freeze({
  customer_support: ["customer"],
  booking_assistant: ["customer"],
  electrician_assistant: ["electrician"],
});

function json(statusCode, body) {
  return {
    statusCode,
    headers: { "Content-Type": "application/json; charset=utf-8", "Cache-Control": "no-store" },
    body: JSON.stringify(body)
  };
}

function getHeader(headers, name) {
  const target = name.toLowerCase();
  const keys = Object.keys(headers || {}).filter(candidate => candidate.toLowerCase() === target);
  // Ambiguous duplicate spellings fail closed instead of choosing one value.
  if (keys.length !== 1) return undefined;
  return headers[keys[0]];
}

function createAiServerGuard({ fetchImpl = globalThis.fetch, env = process.env } = {}) {
  return async function handler(event, mode = "assistant") {
    if (event.httpMethod !== "POST") {
      return json(405, { success: false, error: "method_not_allowed" });
    }
    if (mode !== "assistant" && mode !== "handoff") {
      return json(404, { success: false, error: "not_found" });
    }

    const headers = event.headers || {};
    if (typeof event.body !== "string" || Buffer.byteLength(event.body, "utf8") > 8192) {
      return json(413, { success: false, error: "request_too_large" });
    }
    let input;
    try { input = JSON.parse(event.body); } catch (_) {
      return json(400, { success: false, error: "invalid_request" });
    }
    if (!input || typeof input !== "object" || Array.isArray(input)) {
      return json(400, { success: false, error: "invalid_request" });
    }
    if (typeof input.module_key !== "string" ||
        !Object.prototype.hasOwnProperty.call(MODULE_ROLES, input.module_key)) {
      return json(403, { success: false, error: "ai_access_denied" });
    }
    const allowedRequestKeys = mode === "assistant"
      ? ["module_key", "message", "conversation_id", "context"]
      : ["module_key", "conversation_id", "booking_id", "reason_code", "urgency", "summary"];
    if (Object.keys(input).some(key => !allowedRequestKeys.includes(key))) {
      return json(400, { success: false, error: "invalid_request" });
    }
    const authHeader = getHeader(headers, "authorization");
    const match = typeof authHeader === "string" && authHeader.match(/^Bearer[ \t]([A-Za-z0-9._~+\/-]+=*)$/i);
    const bearerToken = match && match[0] === authHeader ? match[1] : null;
    if (!bearerToken || bearerToken.length > 8192) {
      return json(401, { success: false, error: "authentication_required" });
    }

    const idempotencyKey = getHeader(headers, "idempotency-key");
    if (typeof idempotencyKey !== "string" || !UUID.test(idempotencyKey)) {
      return json(400, { success: false, error: "invalid_idempotency_key" });
    }

    const supabaseUrl = env.SUPABASE_URL;
    const anonKey = env.SUPABASE_ANON_KEY;
    if (typeof supabaseUrl !== "string" || typeof anonKey !== "string" ||
        typeof fetchImpl !== "function") {
      return json(503, { success: false, error: "ai_service_unavailable" });
    }

    let authUrl;
    try {
      authUrl = new URL("/auth/v1/user", supabaseUrl);
      if (authUrl.protocol !== "https:" && authUrl.hostname !== "localhost") throw new Error("invalid_url");
    } catch (_) {
      return json(503, { success: false, error: "ai_service_unavailable" });
    }

    let userResponse;
    try {
      userResponse = await fetchImpl(authUrl.toString(), {
        method: "GET",
        headers: { apikey: anonKey, Authorization: "Bearer " + bearerToken },
        cache: "no-store",
        redirect: "error"
      });
    } catch (_) {
      return json(503, { success: false, error: "ai_service_unavailable" });
    }
    if (!userResponse || userResponse.status === 401 || userResponse.status === 403) {
      return json(401, { success: false, error: "authentication_required" });
    }
    if (typeof userResponse.ok !== "boolean" || !userResponse.ok ||
        !Number.isInteger(userResponse.status) || userResponse.status < 200 || userResponse.status >= 300) {
      return json(503, { success: false, error: "ai_service_unavailable" });
    }

    let user;
    try { user = await userResponse.json(); } catch (_) {
      return json(401, { success: false, error: "authentication_required" });
    }
    if (!user || typeof user.id !== "string" || !UUID.test(user.id)) {
      return json(403, { success: false, error: "ai_access_denied" });
    }

    // Role is derived from the application's own profile records, never app_metadata
    // or browser input. Service-role credentials are used only inside this function.
    const serviceRoleKey = env.SUPABASE_SERVICE_ROLE_KEY;
    if (typeof serviceRoleKey !== "string" || !serviceRoleKey) {
      return json(503, { success: false, error: "ai_service_unavailable" });
    }
    let customerProfileUrl;
    let electricianProfileUrl;
    try {
      customerProfileUrl = new URL("/rest/v1/srk_customer_profiles", supabaseUrl);
      customerProfileUrl.searchParams.set("user_id", "eq." + user.id);
      customerProfileUrl.searchParams.set("select", "user_id");
      customerProfileUrl.searchParams.set("limit", "2");
      electricianProfileUrl = new URL("/rest/v1/electrician_profiles", supabaseUrl);
      electricianProfileUrl.searchParams.set("user_id", "eq." + user.id);
      electricianProfileUrl.searchParams.set("auth_user_id", "eq." + user.id);
      electricianProfileUrl.searchParams.set("verification_status", "eq.approved");
      electricianProfileUrl.searchParams.set("active", "eq.true");
      electricianProfileUrl.searchParams.set("select", "id,user_id,auth_user_id,verification_status,active");
      electricianProfileUrl.searchParams.set("limit", "2");
    } catch (_) {
      return json(503, { success: false, error: "ai_service_unavailable" });
    }

    const profileHeaders = {
      apikey: serviceRoleKey,
      Authorization: "Bearer " + serviceRoleKey,
      Accept: "application/json"
    };
    let customerProfileResponse;
    let electricianProfileResponse;
    try {
      [customerProfileResponse, electricianProfileResponse] = await Promise.all([
        fetchImpl(customerProfileUrl.toString(), { method: "GET", headers: profileHeaders, cache: "no-store", redirect: "error" }),
        fetchImpl(electricianProfileUrl.toString(), { method: "GET", headers: profileHeaders, cache: "no-store", redirect: "error" })
      ]);
    } catch (_) {
      return json(503, { success: false, error: "ai_service_unavailable" });
    }
    if (!customerProfileResponse || customerProfileResponse.ok !== true ||
        !Number.isInteger(customerProfileResponse.status) || customerProfileResponse.status < 200 || customerProfileResponse.status >= 300 ||
        !electricianProfileResponse || electricianProfileResponse.ok !== true ||
        !Number.isInteger(electricianProfileResponse.status) || electricianProfileResponse.status < 200 || electricianProfileResponse.status >= 300) {
      return json(503, { success: false, error: "ai_service_unavailable" });
    }
    let customerProfiles;
    let electricianProfiles;
    try {
      [customerProfiles, electricianProfiles] = await Promise.all([
        customerProfileResponse.json(), electricianProfileResponse.json()
      ]);
    } catch (_) {
      return json(503, { success: false, error: "ai_service_unavailable" });
    }
    if (!Array.isArray(customerProfiles) || !Array.isArray(electricianProfiles)) {
      return json(503, { success: false, error: "ai_service_unavailable" });
    }
    // Verify the returned rows as well as the PostgREST filters. This keeps
    // authorization fail-closed if a proxy/mock/query regression returns a
    // different user's profile or an inactive/unapproved electrician record.
    const hasCustomerProfile = customerProfiles.length === 1 &&
      customerProfiles[0] && customerProfiles[0].user_id === user.id;
    const hasElectricianProfile = electricianProfiles.length === 1 &&
      electricianProfiles[0] && UUID.test(electricianProfiles[0].id || "") &&
      electricianProfiles[0].user_id === user.id &&
      electricianProfiles[0].auth_user_id === user.id &&
      electricianProfiles[0].verification_status === "approved" &&
      electricianProfiles[0].active === true;

    if (!(MODULE_ROLES[input.module_key].includes("customer") && hasCustomerProfile) &&
        !(MODULE_ROLES[input.module_key].includes("electrician") && hasElectricianProfile)) {
      return json(403, { success: false, error: "ai_access_denied" });
    }

    if (mode === "assistant") {
      if (typeof input.message !== "string" || !input.message.trim() || input.message.length > 4000) {
        return json(400, { success: false, error: "invalid_message" });
      }
      if (input.conversation_id != null && !UUID.test(input.conversation_id)) {
        return json(400, { success: false, error: "invalid_conversation_id" });
      }
      if (input.context != null && (typeof input.context !== "object" || Array.isArray(input.context) ||
          Object.keys(input.context).some(key => key !== "booking_id") ||
          (input.context.booking_id != null && !UUID.test(input.context.booking_id)))) {
        return json(400, { success: false, error: "invalid_context" });
      }
    } else if (mode === "handoff") {
      if (typeof input.conversation_id !== "string" || !UUID.test(input.conversation_id) ||
          (input.booking_id != null && !UUID.test(input.booking_id)) ||
          typeof input.reason_code !== "string" || !["needs_human_support", "safety_concern", "account_issue", "billing_question", "other"].includes(input.reason_code) ||
          !["low", "normal", "high"].includes(input.urgency || "normal") ||
          (typeof input.summary !== "string" || !input.summary.trim() || input.summary.length > 1000)) {
        return json(400, { success: false, error: "invalid_handoff_request" });
      }
    } else {
      return json(404, { success: false, error: "not_found" });
    }

    // Booking context is never trusted from the browser. Resolve the exact booking
    // with service-role access and compare its authoritative owner/assignee to the
    // authenticated identity before any future AI feature can consume that context.
    const requestedBookingId = mode === "assistant"
      ? input.context && input.context.booking_id
      : input.booking_id;
    if (requestedBookingId != null) {
      let bookingUrl;
      try {
        bookingUrl = new URL("/rest/v1/service_bookings", supabaseUrl);
        bookingUrl.searchParams.set("id", "eq." + requestedBookingId);
        bookingUrl.searchParams.set("select", "id,customer_user_id,assigned_electrician_id");
        bookingUrl.searchParams.set("limit", "2");
      } catch (_) {
        return json(503, { success: false, error: "ai_service_unavailable" });
      }
      let bookingResponse;
      try {
        bookingResponse = await fetchImpl(bookingUrl.toString(), {
          method: "GET", headers: profileHeaders, cache: "no-store", redirect: "error"
        });
      } catch (_) {
        return json(503, { success: false, error: "ai_service_unavailable" });
      }
      if (!bookingResponse || bookingResponse.ok !== true ||
          !Number.isInteger(bookingResponse.status) || bookingResponse.status < 200 ||
          bookingResponse.status >= 300) {
        return json(503, { success: false, error: "ai_service_unavailable" });
      }
      let bookingRows;
      try { bookingRows = await bookingResponse.json(); } catch (_) {
        return json(503, { success: false, error: "ai_service_unavailable" });
      }
      if (!Array.isArray(bookingRows)) {
        return json(503, { success: false, error: "ai_service_unavailable" });
      }
      if (bookingRows.length !== 1 || !bookingRows[0] ||
          bookingRows[0].id !== requestedBookingId) {
        return json(403, { success: false, error: "ai_booking_access_denied" });
      }
      const booking = bookingRows[0];
      const ownsBooking = input.module_key === "electrician_assistant"
        ? hasElectricianProfile && booking.assigned_electrician_id === electricianProfiles[0].id
        : hasCustomerProfile && booking.customer_user_id === user.id;
      if (!ownsBooking) {
        return json(403, { success: false, error: "ai_booking_access_denied" });
      }
    }

    // AI remains deliberately disabled before launch even after ownership checks pass.
    return json(503, { success: false, error: "ai_not_enabled" });
  };
}

module.exports = { MODULE_ROLES, createAiServerGuard };
