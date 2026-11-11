import webpush from "npm:web-push@3.6.7";
import { createClient } from "npm:@supabase/supabase-js@2";

type OfferRow = { id: string; electrician_id: string; booking_id: string; status: string };
type WebhookPayload = { type: "INSERT" | "UPDATE"; table: string; schema: string; record: OfferRow };

const supabaseUrl = Deno.env.get("SUPABASE_URL") || "";
const secretKeys = JSON.parse(Deno.env.get("SUPABASE_SECRET_KEYS") || "{}");
const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || secretKeys.default || "";
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

  let payload: WebhookPayload;
  try { payload = await req.json(); }
  catch { return new Response("Invalid JSON", { status: 400 }); }

  if (payload.schema !== "public" || payload.table !== "job_offers" ||
      !payload.record?.id || !payload.record?.electrician_id) {
    return new Response("Unsupported webhook payload", { status: 400 });
  }

  const row = payload.record;
  const isNewOffer = payload.type === "INSERT" && row.status === "offered";
  const shouldClose = payload.type === "UPDATE" && row.status !== "offered";
  if (!isNewOffer && !shouldClose) return new Response("Ignored", { status: 200 });

  webpush.setVapidDetails(vapidSubject, vapidPublic, vapidPrivate);

  const { data: profile, error: profileError } = await db
    .from("electrician_profiles")
    .select("user_id,auth_user_id,active,verification_status")
    .eq("id", row.electrician_id)
    .maybeSingle();

  if (profileError || !profile) return new Response("Electrician profile not found", { status: 404 });
  if (!profile.active || profile.verification_status !== "approved") {
    return new Response("Electrician is not eligible", { status: 200 });
  }

  const userId = profile.user_id || profile.auth_user_id;
  if (!userId) return new Response("Electrician account not linked", { status: 409 });

  const { data: subscriptions, error } = await db
    .from("srk_push_subscriptions")
    .select("id,endpoint,p256dh,auth")
    .eq("user_id", userId);

  if (error) return new Response("Could not load subscriptions", { status: 500 });

  const results = await Promise.all((subscriptions || []).map(async (sub) => {
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
        await db.from("srk_push_subscriptions").delete().eq("id", sub.id);
      }
      return { id: sub.id, ok: false, statusCode };
    }
  }));

  return Response.json({
    sent: results.filter(x => x.ok).length,
    failed: results.filter(x => !x.ok).length
  });
});
