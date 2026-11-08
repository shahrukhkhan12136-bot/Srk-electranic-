const SUPABASE_URL = process.env.SUPABASE_URL;
const SERVICE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;
const json = (statusCode, data) => ({ statusCode, headers: { 'Content-Type': 'application/json', 'Cache-Control': 'no-store' }, body: JSON.stringify(data) });

exports.handler = async (event) => {
  if (event.httpMethod !== 'POST') return json(405, { error: 'Method not allowed' });
  if (!SUPABASE_URL || !SERVICE_KEY) return json(503, { error: 'बुकिंग डेटाबेस अभी सेट नहीं है। कृपया WhatsApp से संपर्क करें।' });
  try {
    const b = JSON.parse(event.body || '{}');
    const required = ['customer_name','phone','state','district','pincode','address','service_type'];
    for (const k of required) if (!String(b[k] || '').trim()) return json(400, { error: `${k} आवश्यक है।` });
    if (!/^\d{10}$/.test(b.phone) || !/^\d{6}$/.test(b.pincode)) return json(400, { error: 'मोबाइल या PIN Code सही नहीं है।' });
    const base = SUPABASE_URL.replace(/\/$/, '') + '/rest/v1';
    const headers = { apikey: SERVICE_KEY, Authorization: `Bearer ${SERVICE_KEY}`, 'Content-Type': 'application/json', Prefer: 'return=representation' };
    const bookingPayload = {
      customer_name: String(b.customer_name).slice(0,100), phone: b.phone, state: String(b.state).slice(0,100),
      district: String(b.district).slice(0,100), pincode: b.pincode, address: String(b.address).slice(0,500),
      service_type: String(b.service_type).slice(0,100), preferred_date: b.preferred_date || null,
      preferred_time: b.preferred_time || null, work_details: String(b.work_details || '').slice(0,2000),
      payment_method: String(b.payment_method || 'Cash').slice(0,80), quoted_amount: b.quoted_amount ? Number(b.quoted_amount) : null
    };
    const saved = await fetch(`${base}/service_bookings`, { method: 'POST', headers, body: JSON.stringify(bookingPayload) });
    const savedRows = await saved.json();
    if (!saved.ok) throw new Error(savedRows.message || 'बुकिंग सेव नहीं हो सकी।');
    const booking = savedRows[0];
    // Notify all approved, active electricians in the same PIN code; if none, fall back to same district/state.
    const enc = encodeURIComponent;
    let providersRes = await fetch(`${base}/electrician_profiles?select=id,phone,display_name&active=eq.true&verification_status=eq.approved&pincode=eq.${enc(b.pincode)}`, { headers: { apikey: SERVICE_KEY, Authorization: `Bearer ${SERVICE_KEY}` } });
    let providers = providersRes.ok ? await providersRes.json() : [];
    let matchLevel = 'pincode';
    if (!providers.length) {
      providersRes = await fetch(`${base}/electrician_profiles?select=id,phone,display_name&active=eq.true&verification_status=eq.approved&state=eq.${enc(b.state)}&district=eq.${enc(b.district)}`, { headers: { apikey: SERVICE_KEY, Authorization: `Bearer ${SERVICE_KEY}` } });
      providers = providersRes.ok ? await providersRes.json() : [];
      matchLevel = 'district';
    }
    let offersCreated = 0;
    if (providers.length) {
      const offerRows = providers.map(p => ({ booking_id: booking.id, electrician_id: p.id, status: 'offered', match_level: matchLevel }));
      const offerRes = await fetch(`${base}/job_offers`, { method: 'POST', headers: { ...headers, Prefer: 'return=minimal' }, body: JSON.stringify(offerRows) });
      if (offerRes.ok) offersCreated = providers.length;
    }
    return json(200, { success: true, booking_id: booking.id, offers_created: offersCreated, match_level: offersCreated ? matchLevel : null, message: offersCreated ? `${offersCreated} verified electrician(s) को काम का offer queue किया गया।` : 'बुकिंग सेव हो गई। इस PIN Code/जिले में अभी कोई approved electrician उपलब्ध नहीं मिला; टीम संपर्क करेगी।' });
  } catch (e) { return json(500, { error: e.message || 'सर्वर में समस्या हुई।' }); }
};
