const crypto = require("crypto");
const { processWebhookPayload } = require("../../razorpay-webhook.js");

const SUPABASE_URL = (process.env.SUPABASE_URL || "").replace(/\/$/, "");
const SUPABASE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;
const WORKER_BUDGET_MS = 52000;
const COMPLETION_RESERVE_MS = 12000;

function rpc(name,body,deadlineAt,reserveMs=COMPLETION_RESERVE_MS) {
  const remaining = deadlineAt - Date.now() - reserveMs;
  if (remaining <= 0) throw new Error("WEBHOOK_WORKER_DEADLINE_REACHED");
  return fetch(SUPABASE_URL+"/rest/v1/rpc/"+name,{
    method:"POST",
    headers:{apikey:SUPABASE_KEY,Authorization:"Bearer "+SUPABASE_KEY,"Content-Type":"application/json"},
    body:JSON.stringify(body),
    signal:AbortSignal.timeout(Math.min(15000,remaining))
  });
}

function json(statusCode,body) { return {statusCode,headers:{"Content-Type":"application/json; charset=utf-8","Cache-Control":"no-store"},body:JSON.stringify(body)}; }

exports.handler = async event => {
  const deadlineAt = Date.now()+WORKER_BUDGET_MS;
  if (!SUPABASE_URL || !SUPABASE_KEY) throw new Error("Webhook consumer configuration is incomplete");
  let input;
  try { input=JSON.parse(event.body || "{}"); } catch { throw new Error("Invalid consumer request body"); }
  const eventId = typeof input.event_id === "string" ? input.event_id : "";
  if (!eventId || eventId.length>128) throw new Error("Invalid webhook event ID");
  const supplied = String(event.headers?.["x-srk-webhook-worker-auth"] || event.headers?.["X-Srk-Webhook-Worker-Auth"] || "");
  const expected = crypto.createHmac("sha256",SUPABASE_KEY).update(eventId).digest();
  const received = /^[a-f0-9]{64}$/i.test(supplied) ? Buffer.from(supplied,"hex") : Buffer.alloc(0);
  if (received.length!==expected.length || !crypto.timingSafeEqual(expected,received))
    return json(401,{success:false,error:"Unauthorized worker invocation"});

  let claimed = null;
  try {
    const claimResponse = await rpc("srk_service_claim_razorpay_webhook_event_for_worker",{p_event_id:eventId},deadlineAt);
    if (!claimResponse.ok) throw new Error("Webhook event claim failed");
    const rows = await claimResponse.json();
    claimed = Array.isArray(rows) ? rows[0] : null;
    if (!claimed) return json(200,{success:true,claimed:false});
    const result = await processWebhookPayload(claimed.event_payload,claimed.event_type,deadlineAt);
    const finishResponse = await rpc("srk_service_complete_razorpay_webhook_event",{
      p_event_id:claimed.event_id,p_claim_token:claimed.claim_token,p_outcome:result.outcome,
      p_error:result.outcome==="ignored" ? String(result.reason || "Ignored event").slice(0,500) : null
    },deadlineAt,0);
    if (!finishResponse.ok) throw new Error("Webhook event completion failed");
    const finish = await finishResponse.json();
    if (!finish?.success) throw new Error("Webhook event completion was rejected");
    return json(200,{success:true,state:result.outcome,result:result.result || result.reason || null});
  } catch (error) {
    if (claimed?.claim_token) {
      try {
        const finishResponse = await rpc("srk_service_complete_razorpay_webhook_event",{
          p_event_id:claimed.event_id,p_claim_token:claimed.claim_token,p_outcome:"retryable",
          p_error:String(error?.message || "Webhook consumer failed").slice(0,500)
        },deadlineAt,0);
        if (!finishResponse.ok) throw new Error("Retryable state write failed");
        const finish = await finishResponse.json();
        if (!finish?.success) throw new Error("Retryable state write rejected");
      } catch (finishError) {
        console.error("Webhook consumer could not persist retryable state:",finishError?.name || "UnknownError");
      }
    }
    console.error("Razorpay background consumer failed:",error?.name || "UnknownError");
    throw error;
  }
};

exports.config = { background: true };
