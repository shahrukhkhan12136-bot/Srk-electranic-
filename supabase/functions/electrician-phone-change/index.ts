import { createClient } from "npm:@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
function reply(status: number, body: Record<string, unknown>) {
  return new Response(JSON.stringify(body), { status, headers: { ...cors, "Content-Type": "application/json" } });
}
function normalizeIndianPhone(value: unknown): string | null {
  const raw = String(value ?? "").trim();
  const digits = raw.replace(/\D/g, "");
  const local = digits.length === 12 && digits.startsWith("91") ? digits.slice(2) : digits;
  return /^[6-9]\d{9}$/.test(local) ? "+91" + local : null;
}
function phoneDigits(value: unknown): string {
  return String(value ?? "").replace(/\D/g, "");
}
function generateOtp(): string {
  // Rejection sampling avoids modulo bias when mapping 32-bit CSPRNG output to 000000–999999.
  const range = 0x1_0000_0000;
  const limit = Math.floor(range / 1_000_000) * 1_000_000;
  const value = new Uint32Array(1);
  let sample: number;
  do {
    crypto.getRandomValues(value);
    sample = value[0];
  } while (sample >= limit);
  return String(sample % 1_000_000).padStart(6, "0");
}
async function otpDigest(requestId: string, otp: string, secret: string): Promise<string> {
  const key = await crypto.subtle.importKey("raw", new TextEncoder().encode(secret), { name: "HMAC", hash: "SHA-256" }, false, ["sign"]);
  const bytes = await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(requestId + ":" + otp));
  return Array.from(new Uint8Array(bytes)).map((b) => b.toString(16).padStart(2, "0")).join("");
}
async function sendSms(phone: string, otp: string, apiKey: string): Promise<boolean> {
  const local = phone.slice(3);
  const endpoint = `https://2factor.in/API/V1/${encodeURIComponent(apiKey)}/SMS/${local}/${encodeURIComponent(otp)}/SRK_ELECTRONIC_OTP`;
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 5000);
  try {
    const response = await fetch(endpoint, { method: "GET", signal: controller.signal, headers: { Accept: "application/json, text/plain" } });
    const body = (await response.text()).trim();
    let parsed: Record<string, unknown> = {};
    try { parsed = JSON.parse(body); } catch { /* provider may return plain text */ }
    const status = String(parsed.Status ?? parsed.status ?? parsed.APIStatus ?? parsed.apiStatus ?? "");
    return response.ok && (/^(success|sent|queued)$/i.test(status) || /^(success|sent|queued)(\b|\|)/i.test(body));
  } catch {
    return false;
  } finally {
    clearTimeout(timeout);
  }
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return reply(405, { error: "Method not allowed" });

  const url = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !anonKey || !serviceKey) return reply(500, { error: "Server configuration is incomplete." });

  const authHeader = req.headers.get("Authorization") ?? "";
  if (!authHeader.startsWith("Bearer ")) return reply(401, { error: "लॉगिन सत्र नहीं मिला।" });
  const token = authHeader.slice(7);
  const userClient = createClient(url, anonKey, { global: { headers: { Authorization: `Bearer ${token}` } }, auth: { persistSession: false, autoRefreshToken: false } });
  const { data: authData, error: authError } = await userClient.auth.getUser(token);
  if (authError || !authData.user) return reply(401, { error: "लॉगिन सत्र अमान्य या समाप्त हो गया है।" });
  const actor = authData.user;
  const service = createClient(url, serviceKey, { auth: { persistSession: false, autoRefreshToken: false } });

  let body: Record<string, unknown>;
  try { body = await req.json(); } catch { return reply(400, { error: "अनुरोध सही प्रारूप में नहीं है।" }); }
  const action = String(body.action ?? "");

  if (action === "send_otp") {
    const phone = normalizeIndianPhone(body.new_phone);
    const reason = String(body.reason ?? "").trim();
    if (!phone || reason.length < 10 || reason.length > 500) return reply(400, { error: "सही नया भारतीय मोबाइल नंबर और 10–500 अक्षरों का कारण भरें।" });
    const apiKey = Deno.env.get("2FACTOR_API_KEY");
    if (!apiKey) return reply(503, { error: "SMS सेवा अभी कॉन्फ़िगर नहीं है।" });
    const requestId = crypto.randomUUID();
    const otp = generateOtp();
    const digest = await otpDigest(requestId, otp, serviceKey);
    const { error: prepareError } = await service.rpc("srk_phone_change_prepare", {
      p_request_id: requestId, p_user_id: actor.id, p_new_phone: phone, p_reason: reason,
      p_otp_hash: digest, p_otp_expires_at: new Date(Date.now() + 5 * 60_000).toISOString(),
    });
    if (prepareError) return reply(409, { error: prepareError.message || "मोबाइल नंबर अनुरोध तैयार नहीं हो सका।" });
    if (!await sendSms(phone, otp, apiKey)) {
      const { data: cleanup, error: cleanupError } = await service.rpc("srk_phone_change_cancel_send", {
        p_request_id: requestId, p_user_id: actor.id,
      });
      if (cleanupError || cleanup?.success !== true) {
        // Do not pretend the request was cleared: history must be refreshed before retrying.
        return reply(503, {
          error: "OTP नहीं भेजा जा सका और अनुरोध की स्थिति साफ़ होने की पुष्टि नहीं मिली। नया OTP भेजने से पहले ऐप में मोबाइल अपडेट इतिहास refresh करें।",
          cleanup_pending: true,
        });
      }
      return reply(502, { error: "नए नंबर पर OTP नहीं भेजा जा सका। अनुरोध बंद कर दिया गया है; थोड़ी देर बाद फिर कोशिश करें।" });
    }
    return reply(200, { success: true, request_id: requestId, message: "नए मोबाइल नंबर पर OTP भेज दिया गया है।" });
  }

  if (action === "verify_otp") {
    const requestId = String(body.request_id ?? "");
    const otp = String(body.otp ?? "").trim();
    if (!/^[0-9a-f-]{36}$/i.test(requestId) || !/^\d{6}$/.test(otp)) return reply(400, { error: "6 अंकों का सही OTP डालें।" });
    const digest = await otpDigest(requestId, otp, serviceKey);
    const { data, error } = await service.rpc("srk_phone_change_verify", {
      p_request_id: requestId, p_user_id: actor.id, p_otp_hash: digest,
    });
    if (error) return reply(400, { error: "OTP सत्यापन पूरा नहीं हो सका।" });
    if (!data?.success) return reply(400, { error: data?.message || "OTP सत्यापन असफल हुआ।" });
    return reply(200, { success: true, status: "pending_admin", message: "नया नंबर OTP से सत्यापित हो गया है। अनुरोध Admin की जाँच के लिए भेज दिया गया है।" });
  }

  if (action === "my_requests") {
    const { data, error } = await service.rpc("srk_phone_change_my_requests", { p_user_id: actor.id });
    if (error) return reply(500, { error: "मोबाइल अपडेट का इतिहास लोड नहीं हो सका।" });
    return reply(200, { success: true, requests: data ?? [] });
  }

  const { data: adminAllowed, error: adminCheckError } = await userClient.rpc("is_srk_admin");
  if (adminCheckError || adminAllowed !== true) return reply(403, { error: "इस कार्रवाई के लिए Admin अनुमति आवश्यक है।" });

  if (action === "admin_list") {
    const { data, error } = await service.rpc("srk_admin_list_electrician_phone_change_requests");
    if (error) return reply(500, { error: "Admin मोबाइल अपडेट रिक्वेस्ट लोड नहीं हो सकीं।" });
    return reply(200, { success: true, requests: data ?? [] });
  }

  if (action === "admin_review") {
    const requestId = String(body.request_id ?? "");
    const decision = String(body.decision ?? "");
    const note = String(body.note ?? "").trim();
    if (!/^[0-9a-f-]{36}$/i.test(requestId)) return reply(400, { error: "रिक्वेस्ट ID सही नहीं है।" });
    if (decision === "rejected") {
      const { data, error } = await service.rpc("srk_admin_reject_electrician_phone_change", {
        p_request_id: requestId, p_admin_id: actor.id, p_note: note,
      });
      if (error || !data?.success) return reply(409, { error: error?.message || "रिक्वेस्ट अस्वीकार नहीं हो सकी।" });
      return reply(200, { success: true, message: "रिक्वेस्ट अस्वीकार कर दी गई।" });
    }
    if (decision !== "approved") return reply(400, { error: "Admin निर्णय मान्य नहीं है।" });

    const { data: claim, error: claimError } = await service.rpc("srk_admin_claim_electrician_phone_change", {
      p_request_id: requestId, p_admin_id: actor.id,
    });
    if (claimError || !claim?.success) return reply(409, { error: claimError?.message || "रिक्वेस्ट पर कार्रवाई नहीं हो सकी।" });

    const { data: authBefore, error: authReadError } = await service.auth.admin.getUserById(claim.user_id);
    const authPhoneDigits = phoneDigits(authBefore?.user?.phone);
    const oldPhoneDigits = phoneDigits(claim.old_phone);
    const newPhoneDigits = phoneDigits(claim.new_phone);
    if (authReadError || !authPhoneDigits ||
        (authPhoneDigits !== oldPhoneDigits && authPhoneDigits !== newPhoneDigits)) {
      await service.rpc("srk_admin_release_electrician_phone_change", {
        p_request_id: requestId, p_admin_id: actor.id, p_sync_error: true,
      });
      return reply(409, { error: "लॉगिन मोबाइल नंबर की स्थिति बदल चुकी है या पढ़ी नहीं जा सकी। रिक्वेस्ट तकनीकी जाँच के लिए सुरक्षित रखी गई है।" });
    }

    // A previous interrupted attempt may already have changed Auth to the new number.
    // Do not repeat the update in that case; continue with the profile finalization.
    if (authPhoneDigits !== newPhoneDigits) {
      const { error: authUpdateError } = await service.auth.admin.updateUserById(claim.user_id, {
        phone: claim.new_phone, phone_confirm: true,
      });
      if (authUpdateError) {
        await service.rpc("srk_admin_release_electrician_phone_change", {
          p_request_id: requestId, p_admin_id: actor.id, p_sync_error: false,
        });
        return reply(502, { error: "Supabase लॉगिन नंबर अपडेट नहीं हुआ। रिक्वेस्ट फिर से Admin queue में रखी गई है।" });
      }
    }

    const { data: finalized, error: finalizeError } = await service.rpc("srk_admin_finalize_electrician_phone_change", {
      p_request_id: requestId, p_admin_id: actor.id,
    });
    if (finalizeError || !finalized?.success) {
      // The RPC may have committed even if its response was lost. Never roll Auth
      // back based only on an ambiguous network result; keep a recoverable sync state.
      await service.rpc("srk_admin_release_electrician_phone_change", {
        p_request_id: requestId, p_admin_id: actor.id, p_sync_error: true,
      });
      return reply(503, { error: "मोबाइल अपडेट की अंतिम स्थिति की पुष्टि नहीं हो सकी। लॉगिन नंबर को अपने-आप वापस नहीं बदला गया है। Admin queue refresh करके रिक्वेस्ट की स्थिति जाँचें।" });
    }
    return reply(200, { success: true, message: "नया मोबाइल नंबर सत्यापित और Admin द्वारा मंजूर करके अपडेट कर दिया गया।" });
  }

  return reply(400, { error: "अनुरोध का प्रकार मान्य नहीं है।" });
});
