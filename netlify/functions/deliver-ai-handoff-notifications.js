// Scheduled AI handoff notification dispatcher.
// Delivery remains disabled unless AI_HANDOFF_PUSH_ENABLED is explicitly "true".
// Required server-only env: SUPABASE_URL, AI_HANDOFF_PUSH_SECRET.
exports.handler = async function () {
  if (process.env.AI_HANDOFF_PUSH_ENABLED !== "true") {
    return { statusCode: 200, body: JSON.stringify({ success: true, disabled: true }) };
  }
  const base = (process.env.SUPABASE_URL || "").replace(/\/$/, "");
  const secret = process.env.AI_HANDOFF_PUSH_SECRET;
  if (!base || !secret) {
    console.error("AI handoff push worker configuration is incomplete.");
    return { statusCode: 500, body: "Worker configuration missing" };
  }
  try {
    const response = await fetch(base + "/functions/v1/ai-handoff-push", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "x-srk-ai-handoff-push-secret": secret
      },
      body: "{}",
      signal: AbortSignal.timeout(55000)
    });
    const result = await response.json().catch(() => ({}));
    if (!response.ok || result.success !== true) {
      console.error(JSON.stringify({
        event: "ai_handoff_push_delivery_degraded",
        http_status: response.status,
        claimed: Number(result.claimed || 0),
        delivered: Number(result.delivered || 0),
        retried: Number(result.retried || 0),
        deviceFailed: Number(result.deviceFailed || 0)
      }));
      return { statusCode: 502, body: JSON.stringify({ success: false, status: response.status }) };
    }
    return { statusCode: 200, body: JSON.stringify({ success: true, claimed: result.claimed, delivered: result.delivered }) };
  } catch (error) {
    console.error("AI handoff push worker failed:", error && error.name ? error.name : "unknown");
    return { statusCode: 502, body: "AI handoff push worker failed" };
  }
};

exports.config = { schedule: "* * * * *" };
