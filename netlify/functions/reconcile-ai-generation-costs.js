// Scheduled Gateway cost reconciliation dispatcher.
// Disabled unless AI_COST_RECONCILIATION_ENABLED is explicitly "true".
// Required server-only env: SUPABASE_URL, AI_COST_RECONCILIATION_SECRET.
exports.handler = async function () {
  if (process.env.AI_COST_RECONCILIATION_ENABLED !== "true") {
    return { statusCode: 200, body: JSON.stringify({ success: true, disabled: true }) };
  }
  const base = (process.env.SUPABASE_URL || "").replace(/\/$/, "");
  const secret = process.env.AI_COST_RECONCILIATION_SECRET;
  if (!base || !secret) {
    console.error("AI cost reconciliation worker configuration is incomplete.");
    return { statusCode: 500, body: "Worker configuration missing" };
  }
  try {
    const response = await fetch(base + "/functions/v1/ai-generation-cost-reconcile", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "x-srk-ai-cost-reconciliation-secret": secret
      },
      body: "{}",
      signal: AbortSignal.timeout(55000)
    });
    const result = await response.json().catch(() => ({}));
    if (!response.ok || result.success !== true) {
      console.error(JSON.stringify({
        event: "ai_generation_cost_reconciliation_degraded",
        http_status: response.status,
        claimed: Number(result.claimed || 0),
        reported: Number(result.reported || 0),
        retried: Number(result.retried || 0),
        finishFailed: Number(result.finishFailed || 0)
      }));
      return { statusCode: 502, body: JSON.stringify({ success: false, status: response.status }) };
    }
    return { statusCode: 200, body: JSON.stringify({
      success: true, claimed: result.claimed, reported: result.reported
    }) };
  } catch (error) {
    console.error("AI generation cost reconciliation failed:", error && error.name ? error.name : "unknown");
    return { statusCode: 502, body: "AI generation cost reconciliation failed" };
  }
};

exports.config = { schedule: "*/2 * * * *" };
