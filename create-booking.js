// SRK ELECTRONIC booking API.
// Netlify environment variables required: SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY.
// Keep the service-role key in Netlify environment variables only; never commit it.
const SUPABASE_URL = process.env.SUPABASE_URL;
const SUPABASE_SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;

const json = (statusCode, body) => ({
  statusCode,
  headers: { "Content-Type": "application/json; charset=utf-8", "Cache-Control": "no-store" },
  body: JSON.stringify(body)
});

const clean = (value, max = 500) =>
  typeof value === "string" ? value.trim().slice(0, max) : "";

async function supabase(path, options = {}) {
  const response = await fetch(`${SUPABASE_URL}/rest/v1/${path}`, {
    ...options,
    headers: {
      apikey: SUPABASE_SERVICE_ROLE_KEY,
      Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
      "Content-Type": "application/json",
      Prefer: "return=representation",
      ...(options.headers || {})
    }
  });
  const raw = await response.text();
  let data;
  try { data = raw ? JSON.parse(raw) : null; } catch { data = raw; }
  if (!response.ok) {
    console.error("Supabase error:", response.status, data);
    throw new Error("Database request failed");
  }
  return data;
}

exports.handler = async (event) => {
  if (event.httpMethod !== "POST") {
    return json(405, { success: false, error: "केवल POST अनुरोध स्वीकार है।" });
  }
  if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
    console.error("Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY.");
    return json(500, { success: false, error: "सर्वर कॉन्फ़िगरेशन अधूरा है। Admin से संपर्क करें।" });
  }

  try {
    const body = JSON.parse(event.body || "{}");
    // Safe connectivity check: verifies server credentials and table access without inserting data.
    if (body && body.dry_run === true) {
      await supabase("service_bookings?select=id&limit=1", { method: "GET" });
      return json(200, { success: true, dry_run: true, message: "Supabase connection and service_bookings access are working. No booking was created." });
    }
    const customer_name = clean(body.customer_name, 100);
    const phone = clean(body.phone, 10);
    const state = clean(body.state, 100);
    const district = clean(body.district, 100);
    const pincode = clean(body.pincode, 6);
    const address = clean(body.address, 1000);
    const service_type = clean(body.service_type, 120);
    const preferred_date = clean(body.preferred_date, 10);
    const preferred_time = clean(body.preferred_time, 8);
    const work_details = clean(body.work_details, 2000);
    const payment_method = clean(body.payment_method, 80) || "नकद (Cash)";
    const quoted_amount = body.quoted_amount == null || body.quoted_amount === ""
      ? null : Number(body.quoted_amount);

    if (!customer_name || !/^[0-9]{10}$/.test(phone) || !state || !district ||
        !/^[0-9]{6}$/.test(pincode) || !address || !service_type ||
        !/^\\d{4}-\\d{2}-\\d{2}$/.test(preferred_date) ||
        !/^\\d{2}:\\d{2}$/.test(preferred_time)) {
      return json(400, { success: false, error: "कृपया नाम, सही 10 अंकों का मोबाइल, राज्य, जिला, 6 अंकों का PIN Code, पता, सर्विस, तारीख और समय भरें।" });
    }
    if (quoted_amount !== null &&
        (!Number.isFinite(quoted_amount) || quoted_amount <= 0 || quoted_amount > 10000000)) {
      return json(400, { success: false, error: "भुगतान राशि सही नहीं है।" });
    }

    const inserted = await supabase("service_bookings", {
      method: "POST",
      body: JSON.stringify([{
        customer_name, phone, state, district, pincode, address, service_type,
        preferred_date, preferred_time, work_details, payment_method, quoted_amount,
        status: "new", payment_status: "unpaid"
      }])
    });
    const booking = Array.isArray(inserted) ? inserted[0] : null;
    if (!booking || !booking.id) throw new Error("Booking insert returned no booking ID.");

    // Match approved and active electricians in the exact PIN code first.
    const base = "electrician_profiles?select=id&active=eq.true&verification_status=eq.approved";
    const exact = await supabase(
      base + "&pincode=eq." + encodeURIComponent(pincode) +
      "&state=ilike." + encodeURIComponent(state)
    );
    let matches = Array.isArray(exact) ? exact : [];
    let matchLevel = "pincode";

    // If no PIN-code partner exists, fall back to the same district and state.
    if (matches.length === 0) {
      const districtResult = await supabase(
        base + "&district=ilike." + encodeURIComponent(district) +
        "&state=ilike." + encodeURIComponent(state)
      );
      matches = Array.isArray(districtResult) ? districtResult : [];
      matchLevel = "district";
    }

    let offersCreated = 0;
    if (matches.length) {
      const offerRows = matches.map(({ id }) => ({
        booking_id: booking.id,
        electrician_id: id,
        status: "offered",
        match_level: matchLevel
      }));
      const offers = await supabase("job_offers", {
        method: "POST",
        body: JSON.stringify(offerRows)
      });
      offersCreated = Array.isArray(offers) ? offers.length : offerRows.length;
    }

    return json(200, {
      success: true,
      booking_id: booking.id,
      offers_created: offersCreated,
      match_level: offersCreated ? matchLevel : null,
      message: offersCreated
        ? `बुकिंग सेव हो गई। ${offersCreated} approved और active इलेक्ट्रिशियन को ${matchLevel === "pincode" ? "इसी PIN Code" : "इसी जिले"} का ऑफर बनाया गया है।`
        : "बुकिंग सेव हो गई। इस PIN Code या जिले में अभी कोई approved और active इलेक्ट्रिशियन उपलब्ध नहीं मिला।"
    });
  } catch (error) {
    console.error("create-booking error:", error);
    return json(500, { success: false, error: "बुकिंग सेव नहीं हो सकी। कृपया कुछ देर बाद दोबारा कोशिश करें।" });
  }
};
