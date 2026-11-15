import webpush from "npm:web-push@3.6.7";
import { createClient } from "npm:@supabase/supabase-js@2";

type Offer = { id: string; booking_id: string; electrician_id: string; status: string; expires_at: string | null };
type Webhook = { type: "INSERT" | "UPDATE"; schema: "public"; table: "job_offers"; record: Offer; old_record?: Offer | null };
const jsonHeaders = { "Content-Type": "application/json; charset=utf-8" };
const supabaseUrl = Deno.env.get("SUPABASE_URL") || "";
const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "";
const vapidPublic = Deno.env.get("VAPID_PUBLIC_KEY") || "";
const vapidPrivate = Deno.env.get("VAPID_PRIVATE_KEY") || "";
const vapidSubject = (Deno.env.get("VAPID_SUBJECT") || "").replace(/^mailto(?!:)/i, "mailto:");
const webhookSecret = Deno.env.get("PUSH_WEBHOOK_SECRET") || "";
const db = supabaseUrl && serviceKey ? createClient(supabaseUrl, serviceKey, { auth: { persistSession: false } }) : null;
const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

function isObject(v: unknown): v is Record<string, unknown> { return typeof v === "object" && v !== null && !Array.isArray(v); }
function isOffer(v: unknown): v is Offer {
  return isObject(v) && typeof v.id === "string" && uuid.test(v.id) &&
    typeof v.booking_id === "string" && uuid.test(v.booking_id) &&
    typeof v.electrician_id === "string" && uuid.test(v.electrician_id) &&
    typeof v.status === "string" &&
    (v.expires_at === null || typeof v.expires_at === "string");
}
function json(body: unknown, status = 200, headers: Record<string,string> = {}) {
  return new Response(JSON.stringify(body), { status, headers: { ...jsonHeaders, ...headers } });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { status: 204, headers: {
    "Access-Control-Allow-Origin": "*", "Access-Control-Allow-Methods": "GET, OPTIONS",
    "Access-Control-Allow-Headers": "Content-Type", ...jsonHeaders
  }});
  // The public VAPID key is not a credential. Never return any private configuration here.
  if (req.method === "GET") {
    if (!vapidPublic || !vapidPrivate || !vapidSubject) return json({ pushReady: false }, 503, { "Access-Control-Allow-Origin": "*", "Cache-Control": "no-store" });
    try { webpush.setVapidDetails(vapidSubject, vapidPublic, vapidPrivate); }
    catch { return json({ pushReady: false }, 503, { "Access-Control-Allow-Origin": "*", "Cache-Control": "no-store" }); }
    return json({ publicKey: vapidPublic, pushReady: true }, 200, { "Access-Control-Allow-Origin": "*", "Cache-Control": "public, max-age=3600" });
  }
  if (req.method !== "POST" || !db || !webhookSecret || !vapidPublic || !vapidPrivate || !vapidSubject ||
      req.headers.get("x-srk-push-secret") !== webhookSecret) return new Response("Unauthorized", { status: 401 });

  const declared = Number(req.headers.get("content-length") || "0");
  if (Number.isFinite(declared) && declared > 32768) return new Response("Payload too large", { status: 413 });
  let payload: unknown;
  try {
    if (!req.body) return new Response("Missing body", { status: 400 });
    const reader = req.body.getReader(); const chunks: Uint8Array[] = []; let size = 0;
    while (true) {
      const part = await reader.read(); if (part.done) break;
      size += part.value.byteLength; if (size > 32768) { await reader.cancel(); return new Response("Payload too large", { status: 413 }); }
      chunks.push(part.value);
    }
    const bytes = new Uint8Array(size); let offset = 0;
    for (const chunk of chunks) { bytes.set(chunk, offset); offset += chunk.byteLength; }
    payload = JSON.parse(new TextDecoder().decode(bytes));
  } catch { return new Response("Invalid JSON", { status: 400 }); }
  if (!isObject(payload) || (payload.type !== "INSERT" && payload.type !== "UPDATE") ||
      payload.schema !== "public" || payload.table !== "job_offers" || !isOffer(payload.record)) {
    return new Response("Unsupported webhook payload", { status: 400 });
  }
  const event = payload as unknown as Webhook;
  const row = event.record;
  const newOffer = event.type === "INSERT" && row.status === "offered";
  if (!newOffer) return json({ ignored: true });

  // Re-read authoritative rows at delivery time. Webhook payloads can arrive late,
  // after expiry, acceptance, cancellation, reassignment, or electrician deactivation.
  const { data: currentOffer, error: offerError } = await db.from("job_offers")
    .select("id,booking_id,electrician_id,status,expires_at")
    .eq("id", row.id).maybeSingle();
  if (offerError) return json({ error: "offer_lookup_failed" }, 500);
  if (!currentOffer || currentOffer.status !== "offered" ||
      !currentOffer.expires_at || Date.parse(currentOffer.expires_at) <= Date.now()) {
    return json({ ignored: true, reason: "offer_not_current" });
  }
  if (currentOffer.booking_id !== row.booking_id || currentOffer.electrician_id !== row.electrician_id) {
    return json({ ignored: true, reason: "offer_identity_changed" });
  }
  const { data: booking, error: bookingError } = await db.from("service_bookings")
    .select("id,status,assigned_electrician_id")
    .eq("id", currentOffer.booking_id).maybeSingle();
  if (bookingError) return json({ error: "booking_lookup_failed" }, 500);
  if (!booking || !["new", "confirmed"].includes(booking.status) || booking.assigned_electrician_id !== null) {
    return json({ ignored: true, reason: "booking_not_offerable" });
  }
  const { data: profile, error: profileError } = await db.from("electrician_profiles")
    .select("user_id,active,available_for_work,verification_status")
    .eq("id", currentOffer.electrician_id).maybeSingle();
  if (profileError) return json({ error: "profile_lookup_failed" }, 500);
  if (!profile || !profile.user_id || !profile.active || !profile.available_for_work ||
      profile.verification_status !== "approved") return json({ ignored: true, reason: "electrician_not_eligible" });

  const { data: subscriptions, error: subscriptionError } = await db.from("srk_push_subscriptions")
    .select("id,endpoint,p256dh,auth").eq("user_id", profile.user_id);
  if (subscriptionError) return json({ error: "subscription_lookup_failed" }, 500);
  if (!subscriptions?.length) return json({ sent: 0, failed: 0, reason: "no_subscriptions" });

  try { webpush.setVapidDetails(vapidSubject, vapidPublic, vapidPrivate); }
  catch { return json({ error: "push_provider_not_configured" }, 503); }

  const notification = JSON.stringify({
    title: "SRK ELECTRONIC — नया काम",
    body: "आपके लिए नया काम आया है। ऑफर खोलकर समय-सीमा में जवाब दें।",
    offerId: currentOffer.id
  });
  const results = await Promise.all(subscriptions.map(async (sub) => {
    if (typeof sub.endpoint !== "string" || !sub.endpoint.startsWith("https://") ||
        typeof sub.p256dh !== "string" || !sub.p256dh || typeof sub.auth !== "string" || !sub.auth) {
      await db.from("srk_push_subscriptions").delete().eq("id", sub.id);
      return false;
    }
    try {
      await webpush.sendNotification({ endpoint: sub.endpoint, keys: { p256dh: sub.p256dh, auth: sub.auth } },
        notification, { TTL: 60, urgency: "high" });
      return true;
    } catch (err) {
      const status = (err as { statusCode?: number }).statusCode;
      if (status === 404 || status === 410) await db.from("srk_push_subscriptions").delete().eq("id", sub.id);
      return false;
    }
  }));
  return json({ sent: results.filter(Boolean).length, failed: results.filter(x => !x).length });
});
