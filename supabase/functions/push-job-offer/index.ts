import webpush from "npm:web-push@3.6.7";
import { createClient } from "npm:@supabase/supabase-js@2";

type OfferRow = { id: string; electrician_id: string; booking_id: string; status: string };
type WebhookPayload = { type: "INSERT" | "UPDATE"; table: string; schema: string; record: OfferRow; old_record?: OfferRow | null };

function isObject(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function isOfferRow(value: unknown): value is OfferRow {
  if (!isObject(value)) return false;
  return typeof value.id === "string" && value.id.length > 0 &&
    typeof value.electrician_id === "string" && value.electrician_id.length > 0 &&
    typeof value.booking_id === "string" && value.booking_id.length > 0 &&
    typeof value.status === "string" && value.status.length > 0;
}

const supabaseUrl = Deno.env.get("SUPABASE_URL") || "";
// Secret API-key bundles are optional; malformed JSON must not crash the function at startup.
let defaultSecretKey = "";
try {
  const parsedKeys: unknown = JSON.parse(Deno.env.get("SUPABASE_SECRET_KEYS") || "{}");
  if (parsedKeys && typeof parsedKeys === "object" &&
      "default" in parsedKeys && typeof parsedKeys.default === "string") {
    defaultSecretKey = parsedKeys.default;
  }
} catch {
  // Fall back to the explicitly configured service-role key below.
}
const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || defaultSecretKey;
const vapidPublic = Deno.env.get("VAPID_PUBLIC_KEY") || "";
const vapidPrivate = Deno.env.get("VAPID_PRIVATE_KEY") || "";
const vapidSubject = Deno.env.get("VAPID_SUBJECT") || "";
const hookSecret = Deno.env.get("PUSH_WEBHOOK_SECRET") || "";
const db = supabaseUrl && serviceKey
  ? createClient(supabaseUrl, serviceKey, { auth: { persistSession: false } })
  : null;

Deno.serve(async (req) => {
  if (req.method !== "POST" || !hookSecret || !serviceKey || !vapidPublic ||
      !vapidPrivate || !vapidSubject || !db ||
      req.headers.get("x-srk-push-secret") !== hookSecret) {
    return new Response("Unauthorized", { status: 401 });
  }

  // Reject oversized webhook bodies before parsing to limit memory/CPU abuse.
  const declaredLength = Number(req.headers.get("content-length") || "0");
  if (Number.isFinite(declaredLength) && declaredLength > 32_768) {
    return new Response("Payload too large", { status: 413 });
  }

  let rawPayload: unknown;
  try {
    if (!req.body) return new Response("Missing request body", { status: 400 });
    const reader = req.body.getReader();
    const chunks: Uint8Array[] = [];
    let totalBytes = 0;
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      totalBytes += value.byteLength;
      if (totalBytes > 32_768) {
        await reader.cancel();
        return new Response("Payload too large", { status: 413 });
      }
      chunks.push(value);
    }
    const bodyBytes = new Uint8Array(totalBytes);
    let offset = 0;
    for (const chunk of chunks) {
      bodyBytes.set(chunk, offset);
      offset += chunk.byteLength;
    }
    rawPayload = JSON.parse(new TextDecoder().decode(bodyBytes));
  } catch {
    return new Response("Invalid JSON", { status: 400 });
  }

  if (!isObject(rawPayload) ||
      (rawPayload.type !== "INSERT" && rawPayload.type !== "UPDATE") ||
      rawPayload.schema !== "public" || rawPayload.table !== "job_offers" ||
      !isOfferRow(rawPayload.record)) {
    return new Response("Unsupported webhook payload", { status: 400 });
  }
  if (rawPayload.old_record !== undefined && rawPayload.old_record !== null &&
      !isOfferRow(rawPayload.old_record)) {
    return new Response("Invalid previous row", { status: 400 });
  }

  const payload = rawPayload as unknown as WebhookPayload;
  const row = payload.record;
  const isNewOffer = payload.type === "INSERT" && row.status === "offered";
  const wasOffered = payload.old_record?.status === "offered";
  const shouldClose = payload.type === "UPDATE" && wasOffered && row.status !== "offered" && row.status !== "accepted";
  if (!isNewOffer && !shouldClose) return new Response("Ignored", { status: 200 });

  try {
    webpush.setVapidDetails(vapidSubject, vapidPublic, vapidPrivate);
  } catch {
    return new Response("Push provider configuration is invalid", { status: 500 });
  }

  const { data: profile, error: profileError } = await db
    .from("electrician_profiles")
    .select("user_id,active,verification_status")
    .eq("id", row.electrician_id)
    .maybeSingle();

  if (profileError || !profile) return new Response("Electrician profile not found", { status: 404 });
  if (!profile.active || profile.verification_status !== "approved") {
    return new Response("Electrician is not eligible", { status: 200 });
  }

  const userId = profile.user_id; // Must match the dashboard RPC identity (p.user_id = auth.uid()).
  if (!userId) return new Response("Electrician account not linked", { status: 409 });

  const { data: subscriptions, error } = await db
    .from("srk_push_subscriptions")
    .select("id,endpoint,p256dh,auth")
    .eq("user_id", userId);

  if (error) return new Response("Could not load subscriptions", { status: 500 });

  const results = await Promise.all((subscriptions || []).map(async (sub) => {
    if (typeof sub.endpoint !== "string" || !sub.endpoint.startsWith("https://") ||
        typeof sub.p256dh !== "string" || !sub.p256dh ||
        typeof sub.auth !== "string" || !sub.auth) {
      try { await db.from("srk_push_subscriptions").delete().eq("id", sub.id); } catch { /* best-effort cleanup */ }
      return { id: sub.id, ok: false, reason: "invalid_subscription" };
    }
    const subscription = { endpoint: sub.endpoint, keys: { p256dh: sub.p256dh, auth: sub.auth } };
    const body = isNewOffer
      ? {
          title: "SRK ELECTRONIC — नई बुकिंग",
          body: "आपके लिए नया काम आया है। ऑफर खोलकर जवाब दें।",
          offerId: row.id,
          url: "/electrician.html?offerId=" + encodeURIComponent(row.id),
          action: "open"
        }
      : {
          title: "SRK ELECTRONIC",
          body: "यह बुकिंग ऑफर अब उपलब्ध नहीं है।",
          offerId: row.id,
          action: "close"
        };

    try {
      await webpush.sendNotification(subscription, JSON.stringify(body), {
        TTL: 60,
        urgency: isNewOffer ? "high" : "normal"
      });
      return { id: sub.id, ok: true };
    } catch (err) {
      const statusCode = (err as { statusCode?: number }).statusCode;
      if (statusCode === 404 || statusCode === 410) {
        try { await db.from("srk_push_subscriptions").delete().eq("id", sub.id); } catch { /* best-effort cleanup */ }
      }
      return { id: sub.id, ok: false, statusCode };
    }
  }));

  return Response.json({
    sent: results.filter(x => x.ok).length,
    failed: results.filter(x => !x.ok).length
  });
});
