const json = (statusCode, data) => ({ statusCode, headers: { 'Content-Type': 'application/json', 'Cache-Control': 'no-store' }, body: JSON.stringify(data) });
exports.handler = async (event) => {
  if (event.httpMethod !== 'POST') return json(405, { error: 'Method not allowed' });
  if (!process.env.SUPABASE_URL || !process.env.SUPABASE_SERVICE_ROLE_KEY) return json(503, { error: 'रजिस्ट्रेशन डेटाबेस अभी सेट नहीं है। WhatsApp से आवेदन भेजें।' });
  try {
    const b = JSON.parse(event.body || '{}');
    if (!b.full_name || !/^\d{10}$/.test(b.phone || '') || !b.state || !b.district || !/^\d{6}$/.test(b.pincode || '') || !b.skills) return json(400, { error: 'कृपया सभी जरूरी जानकारी सही भरें।' });
    const url = process.env.SUPABASE_URL.replace(/\/$/, '') + '/rest/v1/electrician_applications';
    const r = await fetch(url, { method: 'POST', headers: { apikey: process.env.SUPABASE_SERVICE_ROLE_KEY, Authorization: `Bearer ${process.env.SUPABASE_SERVICE_ROLE_KEY}`, 'Content-Type': 'application/json', Prefer: 'return=minimal' }, body: JSON.stringify({ full_name: String(b.full_name).slice(0,100), phone: b.phone, state: String(b.state).slice(0,100), district: String(b.district).slice(0,100), pincode: b.pincode, skills: String(b.skills).slice(0,200), experience_years: Math.max(0, Math.min(60, Number(b.experience_years) || 0)), about: String(b.about || '').slice(0,1000) }) });
    if (!r.ok) { const err = await r.json(); throw new Error(err.message || 'आवेदन सेव नहीं हुआ।'); }
    return json(200, { success: true, message: 'आवेदन मिल गया। दस्तावेज़ जाँच और Admin approval के बाद ही काम मिलेगा।' });
  } catch (e) { return json(500, { error: e.message || 'सर्वर में समस्या हुई।' }); }
};
