import webpush from "npm:web-push@3.6.7";
import { createClient } from "npm:@supabase/supabase-js@2";

const url = Deno.env.get("SUPABASE_URL") || "";
const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "";
const enabled = Deno.env.get("AI_HANDOFF_PUSH_ENABLED") === "true";
const workerSecret = Deno.env.get("AI_HANDOFF_PUSH_SECRET") || "";
const vapidPublic = Deno.env.get("VAPID_PUBLIC_KEY") || "";
const vapidPrivate = Deno.env.get("VAPID_PRIVATE_KEY") || "";
const vapidSubject = (Deno.env.get("VAPID_SUBJECT") || "").replace(/^mailto(?!:)/i, "mailto:");
const db = url && serviceKey ? createClient(url, serviceKey, { auth: { persistSession: false } }) : null;
const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
type Outbox = { outbox_id: string; handoff_id: string; urgency: string; created_at: string; recipient_user_ids: string[]; attempt_count: number };
type Target = { delivery_id: string; subscription_id: string; endpoint: string; p256dh: string; auth: string; attempt_count: number };
function isObject(v: unknown): v is Record<string, unknown> { return typeof v === "object" && v !== null && !Array.isArray(v); }
function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json; charset=utf-8", "Cache-Control": "no-store" } });
}
function isOutbox(v: unknown): v is Outbox {
  return isObject(v) && typeof v.outbox_id === "string" && uuid.test(v.outbox_id) &&
    typeof v.handoff_id === "string" && uuid.test(v.handoff_id) &&
    Array.isArray(v.recipient_user_ids) && v.recipient_user_ids.every(x => typeof x === "string" && uuid.test(x)) &&
    Number.isInteger(v.attempt_count) && typeof v.urgency === "string";
}
function isTarget(v: unknown): v is Target {
  return isObject(v) && typeof v.delivery_id === "string" && uuid.test(v.delivery_id) &&
    typeof v.subscription_id === "string" && uuid.test(v.subscription_id) &&
    typeof v.endpoint === "string" && v.endpoint.startsWith("https://") &&
    typeof v.p256dh === "string" && v.p256dh.length > 0 &&
    typeof v.auth === "string" && v.auth.length > 0 && Number.isInteger(v.attempt_count);
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);
  if (!enabled) return json({ error: "worker_disabled" }, 503);
  if (!db || !workerSecret || req.headers.get("x-srk-ai-handoff-push-secret") !== workerSecret ||
      !vapidPublic || !vapidPrivate || !vapidSubject) return json({ error: "unauthorized_or_unconfigured" }, 401);

  try { webpush.setVapidDetails(vapidSubject, vapidPublic, vapidPrivate); }
  catch { return json({ error: "push_provider_not_configured" }, 503); }

  const { data: claimed, error: claimError } = await db.rpc("srk_claim_ai_handoff_notification_outbox", { p_limit: 5 });
  if (claimError || !Array.isArray(claimed)) return json({ error: "outbox_claim_failed" }, 502);
  let delivered = 0, retried = 0, deviceSent = 0, deviceFailed = 0, finishFailed = 0;

  for (const raw of claimed) {
    if (!isOutbox(raw)) { retried++; continue; }
    const event = raw;
    let eventError = "One or more staff devices did not complete delivery";
    let eventComplete = event.recipient_user_ids.length > 0;
    if (!eventComplete) eventError = "No active Staff member has handoff read permission";

    for (const userId of [...new Set(event.recipient_user_ids)]) {
      const { data: deviceClaim, error: deviceClaimError } = await db.rpc(
        "srk_claim_ai_handoff_subscription_deliveries",
        { p_outbox_id: event.outbox_id, p_user_id: userId, p_limit: 100 }
      );
      if (deviceClaimError || !isObject(deviceClaim) || !Array.isArray(deviceClaim.targets)) {
        eventComplete = false; eventError = "Device delivery claim failed"; continue;
      }

      await Promise.all(deviceClaim.targets.map(async (rawTarget: unknown) => {
        if (!isTarget(rawTarget)) { deviceFailed++; eventComplete = false; return; }
        const target = rawTarget;
        try {
          // Do not include conversation text, customer identity, phone, or other private content.
          const payload = JSON.stringify({
            title: "SRK ELECTRONIC — कर्मचारी सहायता",
            body: "एक नया सहायता अनुरोध आया है। Admin Panel में खोलें।",
            type: "ai_handoff",
            handoffId: event.handoff_id,
            urgency: event.urgency
          });
          await webpush.sendNotification(
            { endpoint: target.endpoint, keys: { p256dh: target.p256dh, auth: target.auth } },
            payload,
            { TTL: 300, urgency: event.urgency === "high" ? "high" : "normal" }
          );
          const { data, error } = await db.rpc("srk_finish_ai_handoff_subscription_delivery", {
            p_delivery_id: target.delivery_id, p_attempt_count: target.attempt_count,
            p_success: true, p_error: null
          });
          if (error || data !== true) { deviceFailed++; eventComplete = false; }
          else deviceSent++;
        } catch (err) {
          const status = (err as { statusCode?: number }).statusCode;
          if (status === 404 || status === 410) {
            const { error } = await db.from("srk_push_subscriptions").delete().eq("id", target.subscription_id);
            if (error) {
              await db.rpc("srk_finish_ai_handoff_subscription_delivery", {
                p_delivery_id: target.delivery_id, p_attempt_count: target.attempt_count,
                p_success: false, p_error: "Expired subscription cleanup failed"
              });
              deviceFailed++; eventComplete = false;
            }
            return;
          }
          const { data, error } = await db.rpc("srk_finish_ai_handoff_subscription_delivery", {
            p_delivery_id: target.delivery_id, p_attempt_count: target.attempt_count,
            p_success: false, p_error: status ? "Push provider HTTP " + status : "Push provider request failed"
          });
          if (error || data !== true) eventError = "Device retry state could not be saved";
          deviceFailed++; eventComplete = false;
        }
      }));
    }

    const { data: complete, error: completeError } = await db.rpc(
      "srk_is_ai_handoff_subscription_delivery_complete", { p_outbox_id: event.outbox_id }
    );
    if (completeError || complete !== true) eventComplete = false;

    const { data: finishAccepted, error: finishError } = await db.rpc(
      "srk_finish_ai_handoff_notification_outbox",
      { p_outbox_id: event.outbox_id, p_attempt_count: event.attempt_count,
        p_success: eventComplete, p_error: eventError }
    );
    if (finishError || finishAccepted !== true) { finishFailed++; retried++; }
    else if (eventComplete) delivered++;
    else retried++;
  }

  return json({ success: retried === 0 && finishFailed === 0, claimed: claimed.length,
    delivered, retried, deviceSent, deviceFailed, finishFailed });
});
