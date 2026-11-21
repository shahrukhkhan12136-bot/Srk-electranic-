const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const bookingUi = fs.readFileSync(path.join(__dirname, '..', 'booking.html'), 'utf8');

process.env.SUPABASE_URL = 'https://supabase.test';
process.env.SUPABASE_SERVICE_ROLE_KEY = 'service-role-test';

const { handler } = require('../create-booking');

const USER_ID = '123e4567-e89b-42d3-a456-426614174001';
const BOOKING_ID = '123e4567-e89b-42d3-a456-426614174002';
const REQUEST_KEY = '123e4567-e89b-42d3-a456-426614174003';
const originalFetch = global.fetch;

function response(body, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' }
  });
}

function bookingBody(overrides = {}) {
  return {
    customer_name: 'Customer A',
    phone: '9876543210',
    state: 'Uttar Pradesh',
    district: 'Varanasi',
    pincode: '221001',
    address: 'Test address',
    service_type: 'Electrical repair',
    selected_category: 'electrical_repair',
    selected_rate_tier: 'skilled_electrician',
    selected_duration_hours: 2,
    work_details: 'Fan repair',
    payment_method: 'नकद (Cash)',
    ...overrides
  };
}

function event(body = bookingBody(), key = REQUEST_KEY) {
  return {
    httpMethod: 'POST',
    headers: {
      'x-nf-client-connection-ip': '203.0.113.10',
      authorization: 'Bearer customer-session-token',
      'Idempotency-Key': key
    },
    body: JSON.stringify(body)
  };
}

function mockSupabase({ existingRows = [], insertResponse, insertStatus = 201, masterRateRows = [] } = {}) {
  const calls = [];
  let lookupCount = 0;
  global.fetch = async (url, options = {}) => {
    const target = String(url);
    calls.push({ target, method: options.method || 'GET', body: options.body });
    if (target.endsWith('/rest/v1/rpc/srk_check_public_rate_limit')) return response(true);
    if (target.endsWith('/rest/v1/rpc/srk_customer_get_service_rate')) return response(masterRateRows);
    if (target.endsWith('/auth/v1/user')) {
      return response({
        id: USER_ID,
        phone: '+919876543210',
        phone_confirmed_at: '2026-01-01T00:00:00.000Z'
      });
    }
    if (target.includes('/rest/v1/service_bookings?select=id,customer_user_id,customer_request_fingerprint')) {
      lookupCount += 1;
      const rows = typeof existingRows === 'function' ? existingRows(lookupCount) : existingRows;
      return response(rows);
    }
    if (target.endsWith('/rest/v1/service_bookings') && options.method === 'POST') {
      return response(insertResponse, insertStatus);
    }
    if (target.includes('/rest/v1/job_offers?select=id,match_level')) return response([]);
    if (target.includes('/rest/v1/srk_technician_dispatch_offers?select=id,match_level')) return response([]);
    throw new Error('Unexpected Supabase request: ' + target);
  };
  return calls;
}

test.afterEach(() => { global.fetch = originalFetch; });

test('same idempotency key and same payload returns the original booking without inserting again', async () => {
  const fingerprint = require('node:crypto').createHash('sha256').update(JSON.stringify({
    customer_user_id: USER_ID,
    customer_name: 'Customer A',
    phone: '9876543210',
    state: 'Uttar Pradesh',
    district: 'Varanasi',
    pincode: '221001',
    address: 'Test address',
    location_lat: null,
    location_lng: null,
    service_type: 'Electrical repair',
    selected_category: 'electrical_repair',
    selected_rate_tier: 'skilled_electrician',
    selected_duration_hours: 2,
    work_details: 'Fan repair',
    payment_method: 'नकद (Cash)'
  })).digest('hex');
  const calls = mockSupabase({
    existingRows: [{ id: BOOKING_ID, customer_user_id: USER_ID, customer_request_fingerprint: fingerprint }]
  });

  const result = await handler(event());
  assert.equal(result.statusCode, 200);
  assert.equal(JSON.parse(result.body).booking_id, BOOKING_ID);
  assert.equal(JSON.parse(result.body).replayed, true);
  assert.equal(calls.filter(call => call.method === 'POST' && call.target.endsWith('/service_bookings')).length, 0);
});

test('reusing an idempotency key with changed payload is rejected', async () => {
  const calls = mockSupabase({
    existingRows: [{ id: BOOKING_ID, customer_user_id: USER_ID, customer_request_fingerprint: 'a'.repeat(64) }]
  });
  const result = await handler(event(bookingBody({ address: 'Changed address' })));
  assert.equal(result.statusCode, 409);
  assert.equal(calls.filter(call => call.method === 'POST' && call.target.endsWith('/service_bookings')).length, 0);
  assert.equal(calls.some(call => call.target.includes('/job_offers?')), false);
});

test('missing or malformed idempotency key is rejected before booking lookup', async () => {
  const calls = mockSupabase();
  const missing = await handler(event(bookingBody(), ''));
  const malformed = await handler(event(bookingBody(), 'not-a-uuid'));
  assert.equal(missing.statusCode, 400);
  assert.equal(malformed.statusCode, 400);
  assert.equal(calls.some(call => call.target.includes('/service_bookings?select=')), false);
});

test('unsupported payment methods are rejected before booking lookup or insertion', async () => {
  const calls = mockSupabase();
  const result = await handler(event(bookingBody({ payment_method: 'wire_transfer' })));
  assert.equal(result.statusCode, 400);
  assert.match(JSON.parse(result.body).error, /Cash या Razorpay/);
  assert.equal(calls.some(call => call.target.includes('/rest/v1/service_bookings')), false);
});

test('booking phone is derived from OTP-verified Auth and ignores forged or missing client phone', async () => {
  const calls = mockSupabase({ insertResponse: [{ id: BOOKING_ID }] });
  const forged = await handler(event(bookingBody({ phone: '0000000000' })));
  assert.equal(forged.statusCode, 200);
  const inserted = calls.find(call => call.method === 'POST' && call.target.endsWith('/service_bookings'));
  assert.ok(inserted);
  assert.equal(JSON.parse(inserted.body)[0].phone, '9876543210');

  const callsWithoutPhone = mockSupabase({ insertResponse: [{ id: BOOKING_ID }] });
  const { phone, ...withoutPhone } = bookingBody();
  const omitted = await handler(event(withoutPhone, '123e4567-e89b-42d3-a456-426614174004'));
  assert.equal(omitted.statusCode, 200);
  const insertedWithoutPhone = callsWithoutPhone.find(call => call.method === 'POST' && call.target.endsWith('/service_bookings'));
  assert.ok(insertedWithoutPhone);
  assert.equal(JSON.parse(insertedWithoutPhone.body)[0].phone, '9876543210');
});

test('Master booking calculates hourly labour from Admin rate and stores canonical category/skill snapshots', async () => {
  const calls = mockSupabase({
    masterRateRows: [{
      category_code: 'plumber', skill_code: 'residential_plumbing',
      service_code: 'residential_plumbing', service_name: 'Residential Plumbing',
      billing_model: 'hourly', unit_label: 'घंटा', level_code: 'basic', level_label: 'Basic',
      technician_hourly_paise: 10000, helper_hourly_paise: 5000,
      fixed_labour_paise: null, rate_version: 'SRK-PLUMBER-2026-11-21-V1'
    }],
    insertResponse: [{ id: BOOKING_ID }]
  });
  const result = await handler(event(bookingBody({
    service_type: '',
    selected_category: undefined,
    selected_rate_tier: undefined,
    selected_duration_hours: undefined,
    srk_service_code: 'residential_plumbing',
    srk_rate_level_code: 'basic',
    srk_duration_minutes: 120,
    srk_service_quantity: 1,
    srk_required_technician_count: 1
  })));
  assert.equal(result.statusCode, 200);
  const body = JSON.parse(result.body);
  assert.equal(body.estimate.amount_paise, 30000);
  assert.equal(body.estimate.technician_8h_paise, 80000);
  assert.equal(body.estimate.helper_8h_paise, 40000);
  assert.equal(body.estimate.combined_8h_paise, 120000);
  const inserted = calls.find(call => call.method === 'POST' && call.target.endsWith('/service_bookings'));
  assert.ok(inserted);
  const row = JSON.parse(inserted.body)[0];
  assert.equal(row.srk_service_category_code, 'plumber');
  assert.equal(row.srk_service_skill_code, 'residential_plumbing');
  assert.equal(row.srk_service_code, 'residential_plumbing');
  assert.equal(row.srk_rate_level_code, 'basic');
  assert.equal(row.srk_estimated_labour_paise, 30000);
  assert.equal(row.srk_duration_minutes, 120);
  assert.equal(row.srk_service_quantity, 1);
  assert.equal(row.selected_category, null);
  assert.equal(row.selected_rate_tier, null);
  assert.equal(row.estimated_labour_paise, null);
  assert.ok(calls.some(call => call.target.endsWith('/rest/v1/rpc/srk_customer_get_service_rate')));
  assert.ok(calls.some(call => call.target.includes('/rest/v1/srk_technician_dispatch_offers?select=id,match_level')));
});

test('Master fixed-price booking multiplies the Admin unit price by quantity without hourly duration', async () => {
  const calls = mockSupabase({
    masterRateRows: [{
      category_code: 'cooler', skill_code: 'cooler_repair',
      service_code: 'cooler_repair', service_name: 'Cooler Repair',
      billing_model: 'fixed_per_unit', unit_label: 'कूलर', level_code: 'standard', level_label: 'Standard',
      technician_hourly_paise: null, helper_hourly_paise: 0,
      fixed_labour_paise: 50000, rate_version: 'SRK-COOLER-2026-11-21-V1'
    }],
    insertResponse: [{ id: BOOKING_ID }]
  });
  const result = await handler(event(bookingBody({
    service_type: '',
    selected_category: undefined,
    selected_rate_tier: undefined,
    selected_duration_hours: undefined,
    srk_service_code: 'cooler_repair',
    srk_rate_level_code: 'standard',
    srk_duration_minutes: null,
    srk_service_quantity: 2
  })));
  assert.equal(result.statusCode, 200);
  const body = JSON.parse(result.body);
  assert.equal(body.estimate.amount_paise, 100000);
  assert.equal(body.estimate.billing_model, 'fixed_per_unit');
  const inserted = calls.find(call => call.method === 'POST' && call.target.endsWith('/service_bookings'));
  const row = JSON.parse(inserted.body)[0];
  assert.equal(row.srk_fixed_labour_paise_snapshot, 50000);
  assert.equal(row.srk_estimated_labour_paise, 100000);
  assert.equal(row.srk_service_quantity, 2);
  assert.equal(row.srk_duration_minutes, null);
});

test('Master booking idempotency replay uses the saved rate snapshot even after catalogue deactivation', async () => {
  const fingerprint = require('node:crypto').createHash('sha256').update(JSON.stringify({
    customer_user_id: USER_ID,
    customer_name: 'Customer A',
    phone: '9876543210',
    state: 'Uttar Pradesh',
    district: 'Varanasi',
    pincode: '221001',
    address: 'Test address',
    location_lat: null,
    location_lng: null,
    service_type: 'residential_plumbing',
    selected_category: null,
    selected_rate_tier: null,
    selected_duration_hours: null,
    work_details: 'Fan repair',
    payment_method: 'नकद (Cash)',
    srk_service_code: 'residential_plumbing',
    srk_rate_level_code: 'basic',
    srk_duration_minutes: 120,
    srk_service_quantity: 1,
    srk_required_technician_count: 1
  })).digest('hex');
  const calls = mockSupabase({
    existingRows: [{
      id: BOOKING_ID, customer_user_id: USER_ID, customer_request_fingerprint: fingerprint,
      srk_estimated_labour_paise: 30000, srk_rate_version_snapshot: 'SRK-PLUMBER-OLD-V1',
      srk_billing_model_snapshot: 'hourly', srk_technician_hourly_paise_snapshot: 10000,
      srk_helper_hourly_paise_snapshot: 5000, srk_fixed_labour_paise_snapshot: null
    }]
  });
  const result = await handler(event(bookingBody({
    service_type: '',
    selected_category: undefined,
    selected_rate_tier: undefined,
    selected_duration_hours: undefined,
    srk_service_code: 'residential_plumbing',
    srk_rate_level_code: 'basic',
    srk_duration_minutes: 120,
    srk_service_quantity: 1,
    srk_required_technician_count: 1
  })));
  assert.equal(result.statusCode, 200);
  assert.equal(JSON.parse(result.body).replayed, true);
  assert.equal(JSON.parse(result.body).estimate.amount_paise, 30000);
  assert.equal(JSON.parse(result.body).estimate.rate_card_version, 'SRK-PLUMBER-OLD-V1');
  assert.equal(calls.some(call => call.target.endsWith('/rpc/srk_customer_get_service_rate')), false);
});

test('Master booking refuses a service without an active Admin rate and never inserts it', async () => {
  const calls = mockSupabase({ masterRateRows: [] });
  const result = await handler(event(bookingBody({
    srk_service_code: 'ac_installation',
    srk_rate_level_code: 'expert',
    srk_duration_minutes: 60
  })));
  assert.equal(result.statusCode, 409);
  assert.equal(JSON.parse(result.body).code, 'SERVICE_RATE_NOT_AVAILABLE');
  assert.equal(calls.some(call => call.method === 'POST' && call.target.endsWith('/service_bookings')), false);
});

test('concurrent duplicate insert resolves to the winning booking after unique-key conflict', async () => {
  const fingerprint = require('node:crypto').createHash('sha256').update(JSON.stringify({
    customer_user_id: USER_ID,
    customer_name: 'Customer A',
    phone: '9876543210',
    state: 'Uttar Pradesh',
    district: 'Varanasi',
    pincode: '221001',
    address: 'Test address',
    location_lat: null,
    location_lng: null,
    service_type: 'Electrical repair',
    selected_category: 'electrical_repair',
    selected_rate_tier: 'skilled_electrician',
    selected_duration_hours: 2,
    work_details: 'Fan repair',
    payment_method: 'नकद (Cash)'
  })).digest('hex');
  const calls = mockSupabase({
    existingRows: count => count === 1 ? [] : [{
      id: BOOKING_ID,
      customer_user_id: USER_ID,
      customer_request_fingerprint: fingerprint
    }],
    insertResponse: { code: '23505', message: 'duplicate key value violates unique constraint' },
    insertStatus: 409
  });

  const result = await handler(event());
  assert.equal(result.statusCode, 200);
  assert.equal(JSON.parse(result.body).booking_id, BOOKING_ID);
  assert.equal(JSON.parse(result.body).replayed, true);
  assert.equal(calls.filter(call => call.method === 'POST' && call.target.endsWith('/service_bookings')).length, 1);
  assert.equal(calls.filter(call => call.target.includes('/rest/v1/job_offers?')).length, 1);
});


test('pending browser idempotency keys are isolated per authenticated customer account', () => {
  assert.match(bookingUi, /function customerBookingRequestKey\(payload,customerUserId\)/);
  assert.match(bookingUi, /const storageKey='srk\.customer\.booking\.pending\.v1:'\+customerUserId/);
  assert.match(bookingUi, /customerBookingRequestKey\(bookingPayload, latestSession\.user\.id\)/);
  assert.match(bookingUi, /clearCustomerBookingRequestKey\(requestKey, latestSession\.user\.id\)/);
  assert.match(bookingUi, /function clearCustomerBookingRequestKey\(key,customerUserId\)/);
});

test('booking submission fails closed when session storage cannot persist its idempotency key', () => {
  const helper = bookingUi.slice(bookingUi.indexOf('function customerBookingRequestKey('), bookingUi.indexOf('function clearCustomerBookingRequestKey('));
  assert.match(helper, /catch\(_\)\{throw new Error\('बुकिंग की सुरक्षित पहचान इस ब्राउज़र में सेव नहीं हो सकी/);
  assert.match(helper, /catch\(_\)\{throw new Error\('बुकिंग की सुरक्षित पहचान सेव नहीं हो सकी। बुकिंग नहीं भेजी गई/);
  assert.doesNotMatch(helper, /catch\(_\)\{\}/);
});

test('uncertain booking submission is not falsely reported as definitely unsaved', () => {
  assert.match(bookingUi, /बुकिंग की पुष्टि नहीं हो सकी; संभव है अनुरोध सर्वर तक पहुँच गया हो/);
  assert.match(bookingUi, /पहले बुकिंग सूची रीफ़्रेश करके देखें/);
  assert.match(bookingUi, /इसी विवरण के साथ दोबारा कोशिश करें/);
});

test('pending booking key is retained when the customer edits payload before resolving an uncertain request', () => {
  const helper = bookingUi.slice(bookingUi.indexOf('function customerBookingRequestKey('), bookingUi.indexOf('function clearCustomerBookingRequestKey('));
  assert.match(helper, /if\(saved&&\/[\s\S]*?test\(saved\.key\)\)return saved\.key/);
  assert.doesNotMatch(helper, /saved\.fingerprint===fingerprint/);
  const bookingApi = fs.readFileSync(path.join(__dirname, '..', 'create-booking.js'), 'utf8');
  assert.match(bookingApi, /यह बुकिंग अनुरोध पहचान पहले अलग जानकारी के साथ इस्तेमाल हो चुकी है/);
  assert.ok(bookingApi.includes('existing.customer_request_fingerprint !== requestFingerprint'));
});

test('successful booking keeps its idempotency key until the new booking is visible after refresh', () => {
  const submit = bookingUi.slice(bookingUi.indexOf("document.getElementById('booking').addEventListener('submit'"));
  const loadIndex = submit.indexOf('const bookingListLoaded = await loadCustomerBookings();');
  const visibleIndex = submit.indexOf("document.getElementById('customerBookings')?.innerHTML.includes(String(result.booking_id))");
  const clearIndex = submit.indexOf('clearCustomerBookingRequestKey(requestKey, latestSession.user.id);');
  assert.ok(loadIndex >= 0, 'booking list refresh result is captured');
  assert.ok(visibleIndex > loadIndex, 'created booking visibility is checked after refresh');
  assert.ok(clearIndex > visibleIndex, 'idempotency key is cleared only after booking is visible');
  assert.match(submit, /सुरक्षित डुप्लीकेट-रोक पहचान सुरक्षित रखी गई है/);
  assert.match(submit, /नई या बदली हुई बुकिंग अभी न भेजें/);
});
