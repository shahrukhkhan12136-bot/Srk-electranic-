const crypto = require("crypto");
const SUPABASE_URL = (process.env.SUPABASE_URL || "").replace(/\/$/, "");
const SUPABASE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;
const SITE_URL = process.env.DEPLOY_PRIME_URL || process.env.URL;

exports.handler = async () => {
  if (!SUPABASE_URL || !SUPABASE_KEY || !SITE_URL) {
    console.error("Razorpay webhook sweeper configuration is incomplete.");
    return { statusCode: 500, body: "Worker configuration missing" };
  }
  try {
    const dueResponse = await fetch(SUPABASE_URL+"/rest/v1/rpc/srk_service_list_due_razorpay_webhook_events",{
      method:"POST",
      headers:{apikey:SUPABASE_KEY,Authorization:"Bearer "+SUPABASE_KEY,"Content-Type":"application/json"},
      body:JSON.stringify({p_limit:15}),signal:AbortSignal.timeout(7000)
    });
    if (!dueResponse.ok) throw new Error("Webhook due-event lookup failed");
    const rows = await dueResponse.json();
    if (!Array.isArray(rows)) throw new Error("Webhook due-event lookup returned invalid data");
    const target = new URL("/.netlify/functions/razorpay-webhook-consumer",SITE_URL);
    if (target.protocol!=="https:") throw new Error("Webhook consumer URL must use HTTPS");
    let triggered=0,failed=0;
    for (const row of rows) {
      if (typeof row.event_id!=="string" || row.event_id.length>128) { failed++; continue; }
      try {
        const auth = crypto.createHmac("sha256",SUPABASE_KEY).update(row.event_id).digest("hex");
        const response = await fetch(target,{
          method:"POST",headers:{"Content-Type":"application/json","x-srk-webhook-worker-auth":auth},
          body:JSON.stringify({event_id:row.event_id}),signal:AbortSignal.timeout(900)
        });
        if (response.status===202) triggered++; else failed++;
      } catch { failed++; }
    }
    const summary={due:rows.length,triggered,failed};
    if (failed) console.error(JSON.stringify({event:"razorpay_webhook_sweep_partial",...summary}));
    else console.log(JSON.stringify({event:"razorpay_webhook_sweep_complete",...summary}));
    return {statusCode:200,body:JSON.stringify({success:failed===0,...summary})};
  } catch (error) {
    console.error("Razorpay webhook sweeper failed:",error?.name || "UnknownError");
    return {statusCode:502,body:"Webhook sweeper failed"};
  }
};

exports.config = { schedule: "* * * * *" };
