// Runs every minute and advances expired sequential electrician offers.
// Requires SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY in Netlify environment.
exports.handler = async function () {
  const supabaseUrl = process.env.SUPABASE_URL;
  const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
  if (!supabaseUrl || !serviceRoleKey) {
    console.error("Offer expiry worker is missing its server-side Supabase configuration.");
    return { statusCode: 500, body: "Worker configuration missing" };
  }

  try {
    const response = await fetch(
      (supabaseUrl.endsWith("/") ? supabaseUrl.slice(0, -1) : supabaseUrl) + "/rest/v1/rpc/srk_expire_and_advance_booking_offers",
      {
        method: "POST",
        headers: {
          apikey: serviceRoleKey,
          Authorization: "Bearer " + serviceRoleKey,
          "Content-Type": "application/json"
        },
        body: "{}",
        signal: AbortSignal.timeout(10000)
      }
    );
    const responseText = await response.text();
    if (!response.ok) {
      console.error("Offer expiry RPC failed with HTTP", response.status);
      return { statusCode: 502, body: "Offer expiry RPC failed" };
    }
    const expiredCount = Number(responseText);
    if (!Number.isInteger(expiredCount) || expiredCount < 0) {
      console.error("Offer expiry RPC returned an unexpected response.");
      return { statusCode: 502, body: "Unexpected offer expiry response" };
    }
    // Backward-compatible rollout: before the category-neutral dispatch migration is applied,
    // PostgREST returns 404 for the new RPC. Keep the legacy Electrician worker healthy.
    let technicianDispatch = { available: false, processed: 0, offers_sent: 0, waiting_for_eligible_technician: 0 };
    const dispatchResponse = await fetch(
      (supabaseUrl.endsWith("/") ? supabaseUrl.slice(0, -1) : supabaseUrl) + "/rest/v1/rpc/srk_dispatch_process_pending_queue",
      {
        method: "POST",
        headers: {
          apikey: serviceRoleKey,
          Authorization: "Bearer " + serviceRoleKey,
          "Content-Type": "application/json"
        },
        body: "{}",
        signal: AbortSignal.timeout(10000)
      }
    );
    if (dispatchResponse.ok) {
      const dispatchBody = await dispatchResponse.json();
      technicianDispatch = { available: true, ...dispatchBody };
    } else if (dispatchResponse.status !== 404) {
      console.error("Technician dispatch queue RPC failed with HTTP", dispatchResponse.status);
      return { statusCode: 502, body: "Technician dispatch queue RPC failed" };
    }

    console.log("Expired electrician offers advanced:", expiredCount,
      "Technician dispatch requests processed:", technicianDispatch.processed || 0);
    return { statusCode: 200, body: JSON.stringify({
      success: true, electrician_offers_advanced: expiredCount, technician_dispatch: technicianDispatch
    }) };
  } catch (error) {
    console.error("Offer expiry worker request failed:", error && error.name ? error.name : "unknown");
    return { statusCode: 502, body: "Offer expiry worker request failed" };
  }
};

exports.config = { schedule: "* * * * *" };
