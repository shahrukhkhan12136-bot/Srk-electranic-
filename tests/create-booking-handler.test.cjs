const test = require('node:test');
const assert = require('node:assert/strict');
const crypto = require('node:crypto');

process.env.SUPABASE_URL = 'https://unit-test.supabase.co';
process.env.SUPABASE_SERVICE_ROLE_KEY = 'unit-test-only-not-a-real-secret';
const { handler } = require('../create-booking.js');
const originalFetch = global.fetch;

const validBody = {
  customer_name: 'Test Customer',
  phone: '9876543210',
  state: 'Uttar Pradesh',
  district: 'Balrampur',
  pincode: '271861',
  address: 'Test address, Balrampur',
  service_type: 'Electrical repair',
  selected_category: 'electrical_repair',
  selected_duration_hours: 2,
  preferred_date: '2026-12-01',
  preferred_time: '10:30',
  work_details: 'Switch board repair',
  payment_method: 'नकद (Cash)'
};

function response(status, value) {
  const raw = typeof value === 'string' ? value : JSON.stringify(value);
  return {
    ok: status >= 200 && status < 300,
    status,
    text: async () => raw,
    json: async () => JSON.parse(raw)
  };
}

let calls;
let config;
let insertedRows;

function mockFetch() {
  calls = [];
  insertedRows = null;
  config = { rateAllowed: true, authStatus: 200, insertStatus: 201, offers: [], duplicateInsert: false, existingFingerprint: null };
  global.fetch = async (url, options = {}) => {
    calls.push({ url: String(url), options });
    if (String(url).includes('/rpc/srk_check_public_rate_limit')) {
      return response(200, config.rateAllowed);
    }
    if (String(url).includes('/auth/v1/user')) {
      return response(config.authStatus, {
        id: 'auth-user-verified-123',
        phone: '+919876543210',
        phone_confirmed_at: '2026-11-01T00:00:00Z'
      });
    }
    if (String(url).includes('/rest/v1/service_bookings?')) {
      return response(200, config.existingFingerprint ? [{ id: 'booking-existing', customer_request_fingerprint: config.existingFingerprint }] : []);
    }
    if (String(url).includes('/rest/v1/service_bookings')) {
      insertedRows = JSON.parse(options.body);
      if (config.insertStatus >= 400) return response(config.insertStatus, { code: 'insert_failed' });
      return response(201, config.duplicateInsert ? [] : [{ id: 'booking-123' }]);
    }
    if (String(url).includes('/rest/v1/job_offers?')) {
      return response(200, config.offers);
    }
    throw new Error('Unexpected mocked fetch: ' + url);
  };
}

function event(overrides = {}) {
  return {
    httpMethod: 'POST',
    headers: {
      'x-nf-client-connection-ip': '203.0.113.10',
      authorization: 'Bearer verified-test-token',
      'Idempotency-Key': '123e4567-e89b-42d3-a456-426614174000'
    },
    body: JSON.stringify(validBody),
    ...overrides
  };
}

function status(result) { return result.statusCode; }

function validFingerprint(overrides = {}) {
  const payload = {
    customer_name: 'Test Customer', phone: '9876543210', state: 'Uttar Pradesh',
    district: 'Balrampur', pincode: '271861', address: 'Test address, Balrampur',
    service_type: 'इलेक्ट्रिकल रिपेयर', selected_category: 'electrical_repair',
    selected_duration_hours: 2, preferred_date: '2026-12-01', preferred_time: '10:30',
    work_details: 'Switch board repair', payment_method: 'Cash',
    quoted_amount: null, location_lat: null, location_lng: null
  };
  return crypto.createHash('sha256').update(JSON.stringify({ ...payload, ...overrides })).digest('hex');
}


test.beforeEach(mockFetch);
test.afterEach(() => { global.fetch = originalFetch; });

test('rejects non-POST without calling Supabase', async () => {
  const result = await handler(event({ httpMethod: 'GET' }));
  assert.equal(status(result), 405);
  assert.equal(calls.length, 0);
});

test('rejects oversized body before rate-limit or auth requests', async () => {
  const result = await handler(event({ body: 'x'.repeat(16385) }));
  assert.equal(status(result), 413);
  assert.equal(calls.length, 0);
});

test('rejects malformed JSON as HTTP 400 before any rate-limit or auth requests', async () => {
  const result = await handler(event({ body: '{broken-json' }));
  assert.equal(status(result), 400);
  assert.equal(calls.length, 0);
  assert.match(JSON.parse(result.body).error, /JSON/);
});

test('rejects missing client IP after verifying session and checking for an existing safe retry', async () => {
  const result = await handler(event({ headers: { authorization: 'Bearer verified-test-token', 'Idempotency-Key': '123e4567-e89b-42d3-a456-426614174000' } }));
  assert.equal(status(result), 503);
  assert.equal(calls.some(x => x.url.includes('/auth/v1/user')), true);
  assert.equal(calls.some(x => x.url.includes('/rest/v1/service_bookings?')), true);
  assert.equal(calls.some(x => x.url.includes('/rpc/srk_check_public_rate_limit')), false);
});

test('rejects rate-limited new bookings after customer authentication and idempotency lookup', async () => {
  config.rateAllowed = false;
  const result = await handler(event());
  assert.equal(status(result), 429);
  assert.equal(calls.some(x => x.url.includes('/auth/v1/user')), true);
  assert.equal(calls.some(x => x.url.includes('/rest/v1/service_bookings?')), true);
  assert.equal(calls.some(x => x.url.includes('/rpc/srk_check_public_rate_limit')), true);
});

test('requires a Bearer customer session', async () => {
  const result = await handler(event({ headers: { 'x-nf-client-connection-ip': '203.0.113.10' } }));
  assert.equal(status(result), 401);
  assert.equal(calls.length, 0);
});

test('rejects invalid Supabase customer session', async () => {
  config.authStatus = 401;
  const result = await handler(event());
  assert.equal(status(result), 401);
});

test('rejects booking phone that differs from verified Auth phone', async () => {
  const result = await handler(event({ body: JSON.stringify({ ...validBody, phone: '9123456780' }) }));
  assert.equal(status(result), 403);
  assert.equal(insertedRows, null);
});

test('rejects invalid booking fields after session verification', async () => {
  const result = await handler(event({ body: JSON.stringify({ ...validBody, pincode: '123' }) }));
  assert.equal(status(result), 400);
  assert.equal(insertedRows, null);
});

test('rejects non-object JSON payload', async () => {
  const result = await handler(event({ body: '[]' }));
  assert.equal(status(result), 400);
  assert.equal(insertedRows, null);
});

test('valid booking derives customer UUID from verified Auth and does not create duplicate offers', async () => {
  config.offers = [{ id: 'offer-1', match_level: 'pincode' }];
  const result = await handler(event({ body: JSON.stringify({ ...validBody, customer_user_id: 'attacker-controlled-id' }) }));
  assert.equal(status(result), 200);
  assert.equal(insertedRows.length, 1);
  assert.equal(insertedRows[0].customer_user_id, 'auth-user-verified-123');
  assert.equal(insertedRows[0].status, 'new');
  assert.equal(insertedRows[0].payment_status, 'unpaid');
  assert.equal(insertedRows[0].payment_method, 'Cash');
  assert.equal(insertedRows[0].customer_user_id === 'attacker-controlled-id', false);
  assert.equal(calls.filter(x => x.url.includes('/rest/v1/job_offers?')).length, 1);
  assert.equal(calls.some(x => x.url.includes('/rest/v1/job_offers') && x.options.method === 'POST'), false);
});


test('rejects payment methods outside the customer form allowlist', async () => {
  const result = await handler(event({ body: JSON.stringify({ ...validBody, payment_method: 'pay_later_by_unknown_provider' }) }));
  assert.equal(status(result), 400);
  assert.equal(insertedRows, null);
});

test('accepts the online payment choice without treating it as a completed payment', async () => {
  const result = await handler(event({ body: JSON.stringify({ ...validBody, payment_method: 'Razorpay ऑनलाइन भुगतान' }) }));
  assert.equal(status(result), 200);
  assert.equal(insertedRows[0].payment_method, 'Razorpay ऑनलाइन भुगतान');
  assert.equal(insertedRows[0].payment_status, 'unpaid');
});

test('rejects unknown canonical customer category', async () => {
  const result = await handler(event({ body: JSON.stringify({ ...validBody, selected_category: 'premium_electrical_specialist' }) }));
  assert.equal(status(result), 400);
  assert.equal(insertedRows, null);
});

test('rejects duration outside the 1–8 hour booking range', async () => {
  const result = await handler(event({ body: JSON.stringify({ ...validBody, selected_duration_hours: 9 }) }));
  assert.equal(status(result), 400);
  assert.equal(insertedRows, null);
});


test('rejects string duration instead of accepting a coerced value', async () => {
  const result = await handler(event({ body: JSON.stringify({ ...validBody, selected_duration_hours: '2' }) }));
  assert.equal(status(result), 400);
  assert.equal(insertedRows, null);
});

test('persists canonical category and duration and derives the display label server-side', async () => {
  const result = await handler(event({ body: JSON.stringify({ ...validBody, service_type: 'forged label' }) }));
  assert.equal(status(result), 200);
  assert.equal(insertedRows[0].selected_category, 'electrical_repair');
  assert.equal(insertedRows[0].selected_duration_hours, 2);
  assert.equal(insertedRows[0].service_type, 'इलेक्ट्रिकल रिपेयर');
});

test('maps database insert failure to a safe generic HTTP 500 response', async () => {
  config.insertStatus = 500;
  const result = await handler(event());
  assert.equal(status(result), 500);
  assert.match(JSON.parse(result.body).error, /बुकिंग सेव नहीं हो सकी/);
});

test('requires a UUID idempotency key before creating a booking', async () => {
  const result = await handler(event({ headers: { 'x-nf-client-connection-ip': '203.0.113.10', authorization: 'Bearer verified-test-token' } }));
  assert.equal(status(result), 400);
  assert.equal(insertedRows, null);
});

test('retries an identical submission by returning the existing booking without a second insert', async () => {
  config.duplicateInsert = true;
  config.existingFingerprint = validFingerprint();
  const result = await handler(event());
  assert.equal(status(result), 200);
  const data = JSON.parse(result.body);
  assert.equal(data.booking_id, 'booking-existing');
  assert.equal(data.idempotent_replay, true);
  assert.equal(calls.filter(x => x.url.includes('/rest/v1/service_bookings') && x.options.method === 'POST').length, 0);
  assert.equal(calls.filter(x => x.url.includes('/rest/v1/service_bookings?') && x.options.method === 'GET').length, 1);
  assert.equal(calls.some(x => x.url.includes('/rpc/srk_check_public_rate_limit')), false);
});

test('an exact idempotent retry bypasses the new-booking rate limit', async () => {
  config.rateAllowed = false;
  config.existingFingerprint = validFingerprint();
  const result = await handler(event());
  assert.equal(status(result), 200);
  assert.equal(JSON.parse(result.body).idempotent_replay, true);
  assert.equal(calls.some(x => x.url.includes('/rpc/srk_check_public_rate_limit')), false);
  assert.equal(calls.filter(x => x.url.includes('/rest/v1/service_bookings') && x.options.method === 'POST').length, 0);
});

test('rejects reuse of the same idempotency key with changed booking details', async () => {
  config.duplicateInsert = true;
  config.existingFingerprint = 'a'.repeat(64);
  const result = await handler(event());
  assert.equal(status(result), 409);
  assert.match(JSON.parse(result.body).error, /जानकारी बदल गई है/);
});

test('rejects an idempotency key already owned by another customer', async () => {
  config.duplicateInsert = true;
  config.existingFingerprint = null;
  const result = await handler(event());
  assert.equal(status(result), 409);
  assert.match(JSON.parse(result.body).error, /पहले इस्तेमाल हो चुका है/);
});
