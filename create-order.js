const Razorpay = require('razorpay');
const json = (statusCode, data) => ({ statusCode, headers: { 'Content-Type': 'application/json', 'Cache-Control': 'no-store' }, body: JSON.stringify(data) });

exports.handler = async (event) => {
  if (event.httpMethod !== 'POST') return json(405, { error: 'Method not allowed' });
  const baseUrl = process.env.SUPABASE_URL;
  const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
  const keyId = process.env.RAZORPAY_KEY_ID;
  const keySecret = process.env.RAZORPAY_KEY_SECRET;
  if (!baseUrl || !serviceKey || !keyId || !keySecret) return json(503, { error: 'Payment/database server configuration अधूरी है।' });
  try {
    const { booking_id } = JSON.parse(event.body || '{}');
    if (!booking_id || !/^[0-9a-f-]{36}$/i.test(String(booking_id))) return json(400, { error: 'सही booking ID नहीं मिली।' });
    const headers = { apikey: serviceKey, Authorization: `Bearer ${serviceKey}`, 'Content-Type': 'application/json' };
    const base = baseUrl.replace(/\/$/, '') + '/rest/v1';
    const lookup = await fetch(`${base}/service_bookings?id=eq.${encodeURIComponent(booking_id)}&select=id,quoted_amount,payment_status`, { headers });
    const rows = await lookup.json();
    if (!lookup.ok || !rows.length) return json(404, { error: 'बुकिंग नहीं मिली। पहले बुकिंग सेव करें।' });
    const booking = rows[0];
    const paise = Math.round(Number(booking.quoted_amount) * 100);
    if (!Number.isSafeInteger(paise) || paise < 100) return json(400, { error: 'बुकिंग में कम से कम ₹1 की सही राशि नहीं है।' });
    if (!['unpaid', 'pending'].includes(booking.payment_status)) return json(409, { error: 'इस बुकिंग का भुगतान पहले ही प्रोसेस हो चुका है।' });

    const razorpay = new Razorpay({ key_id: keyId, key_secret: keySecret });
    const order = await razorpay.orders.create({ amount: paise, currency: 'INR', receipt: `srk_${String(booking.id).replace(/-/g,'').slice(0,18)}_${Date.now().toString().slice(-8)}`, notes: { booking_id: booking.id } });
    const update = await fetch(`${base}/service_bookings?id=eq.${encodeURIComponent(booking.id)}`, {
      method: 'PATCH', headers: { ...headers, Prefer: 'return=minimal' },
      body: JSON.stringify({ payment_status: 'pending', razorpay_order_id: order.id })
    });
    if (!update.ok) throw new Error('ऑर्डर बना, लेकिन बुकिंग रिकॉर्ड अपडेट नहीं हुआ। Admin से जाँच कराएँ।');
    return json(200, { order_id: order.id, amount: order.amount, currency: order.currency, key_id: keyId });
  } catch (error) {
    console.error('Razorpay create-order error:', error);
    return json(500, { error: error.message || 'ऑर्डर नहीं बन पाया। कृपया दोबारा कोशिश करें।' });
  }
};
