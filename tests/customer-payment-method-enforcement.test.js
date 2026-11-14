const test = require('node:test');
const assert = require('node:assert/strict');
const crypto = require('node:crypto');

process.env.SUPABASE_URL = 'https://supabase.test';
process.env.SUPABASE_SERVICE_ROLE_KEY = 'service-role-test';
process.env.RAZORPAY_KEY_ID = 'rzp_test_key';
process.env.RAZORPAY_KEY_SECRET = 'razorpay-test-secret';

const createOrder = require('../create-order');
const verifyPayment = require('../verify-payment');

const BOOKING_ID = '123e4567-e89b-42d3-a456-426614174000';
const USER_ID = '123e4567-e89b-42d3-a456-426614174001';
const ORDER_ID = 'order_test123';
const PAYMENT_ID = 'pay_test123';
const originalFetch = global.fetch;

function response(body, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' }
  });
}

function mockSupabase({ paymentMethod = 'Cash', paymentStatus = 'unpaid' } = {}) {
  const calls = [];
  global.fetch = async (url) => {
    const target = String(url);
    calls.push(target);
    if (target.startsWith('https://supabase.test/auth/v1/user')) {
      return response({
        id: USER_ID,
        phone: '+919876543210',
        phone_confirmed_at: '2026-01-01T00:00:00.000Z'
      });
    }
    if (target.startsWith('https://supabase.test/rest/v1/service_bookings?')) {
      return response([{
        id: BOOKING_ID,
        phone: '9876543210',
        customer_user_id: USER_ID,
        payment_method: paymentMethod,
        payment_status: paymentStatus,
        quoted_amount: 500,
        service_charge: 500,
        materials_amount: 0,
        amount_paid: 0,
        status: 'completed',
        quote_status: 'approved',
        selected_category: 'home_wiring',
        razorpay_order_id: ORDER_ID,
        razorpay_payment_id: null
      }]);
    }
    throw new Error('Unexpected network request: ' + target);
  };
  return calls;
}

test.afterEach(() => { global.fetch = originalFetch; });

test('create-order rejects a Cash booking even after work completion', async () => {
  const calls = mockSupabase({ paymentMethod: 'Cash' });
  const result = await createOrder.handler({
    httpMethod: 'POST',
    headers: { authorization: 'Bearer customer-session-token' },
    body: JSON.stringify({ booking_id: BOOKING_ID })
  });
  assert.equal(result.statusCode, 409);
  assert.match(JSON.parse(result.body).error, /Razorpay ऑनलाइन भुगतान/);
  assert.equal(calls.filter(url => url.startsWith('https://api.razorpay.com/')).length, 0);
});

test('create-order rejects a refunded booking with online preference', async () => {
  const calls = mockSupabase({ paymentMethod: 'Razorpay ऑनलाइन भुगतान', paymentStatus: 'refunded' });
  const result = await createOrder.handler({
    httpMethod: 'POST',
    headers: { authorization: 'Bearer customer-session-token' },
    body: JSON.stringify({ booking_id: BOOKING_ID })
  });
  assert.equal(result.statusCode, 409);
  assert.match(JSON.parse(result.body).error, /रिफंड/);
  assert.equal(calls.filter(url => url.startsWith('https://api.razorpay.com/')).length, 0);
});

test('verify-payment rejects a Cash booking before contacting Razorpay', async () => {
  const calls = mockSupabase({ paymentMethod: 'Cash' });
  const signature = crypto.createHmac('sha256', process.env.RAZORPAY_KEY_SECRET)
    .update(ORDER_ID + '|' + PAYMENT_ID).digest('hex');
  const result = await verifyPayment.handler({
    httpMethod: 'POST',
    headers: { authorization: 'Bearer customer-session-token' },
    body: JSON.stringify({
      razorpay_payment_id: PAYMENT_ID,
      razorpay_order_id: ORDER_ID,
      razorpay_signature: signature
    })
  });
  assert.equal(result.statusCode, 409);
  assert.match(JSON.parse(result.body).error, /Razorpay ऑनलाइन भुगतान/);
  assert.equal(calls.filter(url => url.startsWith('https://api.razorpay.com/')).length, 0);
});

test('verify-payment rejects a refunded booking with online preference', async () => {
  const calls = mockSupabase({ paymentMethod: 'Razorpay ऑनलाइन भुगतान', paymentStatus: 'refunded' });
  const signature = crypto.createHmac('sha256', process.env.RAZORPAY_KEY_SECRET)
    .update(ORDER_ID + '|' + PAYMENT_ID).digest('hex');
  const result = await verifyPayment.handler({
    httpMethod: 'POST',
    headers: { authorization: 'Bearer customer-session-token' },
    body: JSON.stringify({
      razorpay_payment_id: PAYMENT_ID,
      razorpay_order_id: ORDER_ID,
      razorpay_signature: signature
    })
  });
  assert.equal(result.statusCode, 409);
  assert.match(JSON.parse(result.body).error, /रिफंड/);
  assert.equal(calls.filter(url => url.startsWith('https://api.razorpay.com/')).length, 0);
});
