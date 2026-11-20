import { createClient } from "npm:@supabase/supabase-js@2";
import { extractReportedUsd } from "../_shared/ai-generation-cost.mjs";

const supabaseUrl = Deno.env.get("SUPABASE_URL") || "";
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "";
const gatewayKey = Deno.env.get("AI_GATEWAY_API_KEY") || "";
const workerSecret = Deno.env.get("AI_COST_RECONCILIATION_SECRET") || "";
const enabled = Deno.env.get("AI_COST_RECONCILIATION_ENABLED") === "true";
const db = supabaseUrl && serviceRoleKey
  ? createClient(supabaseUrl, serviceRoleKey, { auth: { persistSession: false } })
  : null;

type CostJob = {
  attempt_id: string;
  generation_id: string;
  model_key: string;
  attempt_count: number;
};

function isObject(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}
function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json; charset=utf-8", "Cache-Control": "no-store" }
  });
}
function isJob(value: unknown): value is CostJob {
  return isObject(value) &&
    typeof value.attempt_id === "string" &&
    /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value.attempt_id) &&
    typeof value.generation_id === "string" &&
    /^gen_[A-Za-z0-9._:-]{1,195}$/.test(value.generation_id) &&
    typeof value.model_key === "string" && value.model_key.length > 0 && value.model_key.length <= 160 &&
    Number.isInteger(value.attempt_count) && (value.attempt_count as number) >= 1 && (value.attempt_count as number) <= 20;
}
Deno.serve(async (req) => {
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);
  if (!enabled) return json({ error: "worker_disabled" }, 503);
  if (!db || !gatewayKey || !workerSecret ||
      req.headers.get("x-srk-ai-cost-reconciliation-secret") !== workerSecret) {
    return json({ error: "unauthorized_or_unconfigured" }, 401);
  }

  const { data: claimed, error: claimError } = await db.rpc(
    "srk_claim_ai_generation_cost_jobs", { p_limit: 5 }
  );
  if (claimError || !Array.isArray(claimed)) return json({ error: "cost_job_claim_failed" }, 502);

  let reported = 0;
  let retried = 0;
  let terminalUnavailable = 0;
  let finishFailed = 0;

  for (const raw of claimed) {
    if (!isJob(raw)) { retried++; continue; }
    const job = raw;
    let costUsd: string | null = null;
    let failure = "Gateway generation cost is not available yet";

    try {
      const lookup = new URL("https://ai-gateway.vercel.sh/v1/generation");
      lookup.searchParams.set("id", job.generation_id);
      const response = await fetch(lookup.toString(), {
        method: "GET",
        headers: { Authorization: "Bearer " + gatewayKey, Accept: "application/json" },
        cache: "no-store",
        redirect: "error",
        signal: AbortSignal.timeout(12000)
      });
      if (response.ok) {
        const payload = await response.json();
        costUsd = extractReportedUsd(payload, job.generation_id);
        if (costUsd === null) failure = "Gateway response did not contain a valid matching USD cost";
      } else {
        // 404 is expected briefly because Gateway usage ingestion is asynchronous.
        failure = response.status === 404
          ? "Gateway generation usage has not arrived yet"
          : "Gateway generation lookup returned HTTP " + response.status;
      }
    } catch {
      failure = "Gateway generation lookup failed";
    }

    const { data: accepted, error: finishError } = await db.rpc(
      "srk_finish_ai_generation_cost_job",
      {
        p_attempt_id: job.attempt_id,
        p_attempt_count: job.attempt_count,
        p_success: costUsd !== null,
        p_cost_usd: costUsd,
        p_cost_source: costUsd !== null ? "vercel_ai_gateway_generation_api" : null,
        p_error: costUsd === null ? failure : null
      }
    );
    if (finishError || accepted !== true) {
      finishFailed++;
      retried++;
      continue;
    }
    if (costUsd !== null) reported++;
    else if (job.attempt_count >= 20) terminalUnavailable++;
    else retried++;
  }

  return json({
    success: retried === 0 && finishFailed === 0,
    claimed: claimed.length,
    reported,
    retried,
    terminalUnavailable,
    finishFailed
  }, retried === 0 && finishFailed === 0 ? 200 : 502);
});
