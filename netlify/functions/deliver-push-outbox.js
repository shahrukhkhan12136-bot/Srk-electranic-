// Scheduled at-least-once worker for durable push outbox delivery.
// Required server-only env: SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, PUSH_WEBHOOK_SECRET.
exports.handler = async function () {
  const base = (process.env.SUPABASE_URL || "").replace(/\/$/, "");
  const key = process.env.SUPABASE_SERVICE_ROLE_KEY;
  const pushSecret = process.env.PUSH_WEBHOOK_SECRET;
  if (!base || !key || !pushSecret) {
    console.error("Push outbox worker configuration is incomplete.");
    return { statusCode: 500, body: "Worker configuration missing" };
  }
  const headers = {
    apikey: key, Authorization: "Bearer " + key,
    "Content-Type": "application/json"
  };
  const callRpc = async (name, body) => fetch(base + "/rest/v1/rpc/" + name, {
    method: "POST", headers, body: JSON.stringify(body), signal: AbortSignal.timeout(12000)
  });
  try {
    const claim = await callRpc("srk_claim_push_delivery_outbox", { p_limit: 3 });
    if (!claim.ok) {
      console.error("Push outbox claim failed with HTTP", claim.status);
      return { statusCode: 502, body: "Push outbox claim failed" };
    }
    const rows = await claim.json();
    if (!Array.isArray(rows)) return { statusCode: 502, body: "Invalid outbox claim response" };
    let delivered = 0, retry = 0;
    for (const row of rows) {
      let success = false, errorText = "Push sender unavailable";
      try {
        const response = await fetch(base + "/functions/v1/push-job-offer", {
          method: "POST",
          headers: { apikey: key, Authorization: "Bearer " + key, "Content-Type": "application/json", "x-srk-push-secret": pushSecret },
          body: JSON.stringify({ ...row.payload, outbox_id: row.outbox_id }),
          signal: AbortSignal.timeout(15000)
        });
        const result = await response.json().catch(() => ({}));
        if (response.ok && (result.ignored === true || result.complete === true)) {
          success = true;
        } else {
          errorText = "Push sender returned HTTP " + response.status + " or partial delivery failure";
        }
      } catch (error) {
        errorText = error && error.name ? error.name : "Push sender request failed";
      }
      const finish = await callRpc("srk_finish_push_delivery_outbox", {
        p_outbox_id: row.outbox_id, p_success: success, p_error: errorText
      });
      if (!finish.ok) {
        console.error("Push outbox finish failed for one claimed row; lease will expire.");
        retry++;
      } else if (success) delivered++;
      else retry++;
    }
    console.log("Push outbox batch finished:", { claimed: rows.length, delivered, retry });
    return { statusCode: 200, body: JSON.stringify({ success: true, claimed: rows.length, delivered, retry }) };
  } catch (error) {
    console.error("Push outbox worker failed:", error && error.name ? error.name : "unknown");
    return { statusCode: 502, body: "Push outbox worker failed" };
  }
};

exports.config = { schedule: "* * * * *" };
