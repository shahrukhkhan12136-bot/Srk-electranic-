const crypto = require('crypto');
const Razorpay = require('razorpay');
const json = (statusCode, data) => ({ statusCode, headers: { 'Content-Type': 'application/json', 'Cache-Control': 'no-store' }, body: JSON.stringify(data) });

exports.handler = async (event) => {
  if (event.httpMethod !== 'POST') return json(405, { success: false, error: 'Method not allowed' });
  try {
    const { razorpay_order_id, razorpay_payment_id, razorpay_signature } = JSON.parse(event.body || '{}');
    if (!razorpay_order_id || !razorpay_payment_id || !razorpay_signature) return json(400, { success: false, error: 'Payment verification के लिए जरूरी जानकारी नहीं मिली।' });
    const keyId = process.env.RAZORPAY_KEY_ID, secret = process.env.RAZORPAY_KEY_SECRET;
    const baseUrl = process.env.SUPABASE_URL, serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
    if (!keyId || !secret || !baseUrl || !serviceKey) return json(503, { success: false, error: 'Payment/database server configuration अधूरी है।' });

    const expected = crypto.createHmac('sha256', secret).update(`${razorpay_order_id}|${razorpay_payment_id}`).digest('hex');
    const received = Buffer.from(String(razorpay_signature), 'utf8'), expectedBuf = Buffer.from(expected, 'utf8');
    if (received.length !== expectedBuf.length || !crypto.timingSafeEqual(received, expectedBuf)) return json(400, { success: false, error: 'Payment signature match नहीं हुआ।' });

    const razorpay = new Razorpay({ key_id: keyId, key_secret: secret });
    const payment = await razorpay.payments.fetch(razorpay_payment_id);
    if (payment.order_id !== razorpay_order_id || payment.currency !== 'INR' || payment.status !== 'captured') return json(409, { success: false, error: 'Razorpay पर पेमेंट Captured नहीं है।', payment_status: payment.status || 'unknown' });

    const base = baseUrl.replace(/\/$/, '') + '/rest/v1';
    const headers = { apikey: serviceKey, Authorization: `Bearer ${serviceKey}`, 'Content-Type': 'application/json' };
    const lookup = await fetch(`${base}/service_bookings?razorpay_order_id=eq.${encodeURIComponent(razorpay_order_id)}&select=id,quoted_amount,payment_status`, { headers });
    const rows = await lookup.json();
    if (!lookup.ok || !rows.length) return json(404, { success: false, error: 'इस Razorpay ऑर्डर से जुड़ी बुकिंग नहीं मिली।' });
    const booking = rows[0];
    if (Math.round(Number(booking.quoted_amount) * 100) !== Number(payment.amount)) return json(409, { success: false, error: 'भुगतान राशि बुकिंग राशि से मेल नहीं खाती।' });
    if (booking.payment_status === 'paid') return json(200, { success: true, payment_status: 'captured', payment_id: payment.id, order_id: payment.order_id, message: 'भुगतान पहले ही सत्यापित है।' });

    const update = await fetch(`${base}/service_bookings?id=eq.${encodeURIComponent(booking.id)}`, {
      method: 'PATCH', headers: { ...headers, Prefer: 'return=minimal' },
      body: JSON.stringify({ payment_status: 'paid', razorpay_payment_id: payment.id, payment_verified_at: new Date().toISOString() })
    });
    if (!update.ok) return json(500, { success: false, error: 'भुगतान Razorpay पर सफल है, लेकिन वेबसाइट रिकॉर्ड अपडेट नहीं हुआ। Admin से तुरंत जाँच कराएँ।' });
    return json(200, { success: true, payment_status: 'captured', payment_id: payment.id, order_id: payment.order_id, amount: payment.amount, currency: payment.currency, message: 'Payment captured and booking record updated.' });
  } catch (error) {
    console.error('Razorpay verify-payment error:', error);
    return json(400, { success: false, error: 'पेमेंट की स्थिति जाँची नहीं जा सकी। Razorpay Dashboard में जाँच करें।' });
  }
};
