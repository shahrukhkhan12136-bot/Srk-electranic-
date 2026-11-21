const test = require('node:test');
const assert = require('node:assert/strict');

const worker = require('../netlify/functions/expire-booking-offers.js');

function withWorkerEnvironment(values, run) {
  const names = ['SUPABASE_URL', 'SUPABASE_SERVICE_ROLE_KEY'];
  const previous = Object.fromEntries(names.map(name => [name, process.env[name]]));
  const previousFetch = global.fetch;
  for (const name of names) {
    if (Object.prototype.hasOwnProperty.call(values, name)) process.env[name] = values[name];
    else delete process.env[name];
  }
  return Promise.resolve()
    .then(run)
    .finally(() => {
      for (const name of names) {
        if (previous[name] === undefined) delete process.env[name];
        else process.env[name] = previous[name];
      }
      global.fetch = previousFetch;
    });
}

test('offer expiry worker is scheduled once per minute', () => {
  assert.deepEqual(worker.config, { schedule: '* * * * *' });
});

test('offer expiry worker refuses to call Supabase without server configuration', async () => {
  await withWorkerEnvironment({}, async () => {
    let called = false;
    global.fetch = async () => { called = true; throw new Error('must not call'); };
    const result = await worker.handler();
    assert.equal(result.statusCode, 500);
    assert.equal(called, false);
  });
});

test('offer expiry worker calls the service-role-only RPC and returns the advanced count', async () => {
  await withWorkerEnvironment({
    SUPABASE_URL: 'https://example.supabase.co/',
    SUPABASE_SERVICE_ROLE_KEY: 'test-service-role-key'
  }, async () => {
    let request;
    global.fetch = async (url, options) => {
      request = { url, options };
      return { ok: true, status: 200, text: async () => '3' };
    };
    const result = await worker.handler();
    assert.equal(request.url, 'https://example.supabase.co/rest/v1/rpc/srk_expire_and_advance_booking_offers');
    assert.equal(request.options.method, 'POST');
    assert.equal(request.options.headers.apikey, 'test-service-role-key');
    assert.equal(request.options.headers.Authorization, 'Bearer test-service-role-key');
    assert.equal(request.options.body, '{}');
    assert.deepEqual(JSON.parse(result.body), { success: true, advanced: 3 });
    assert.equal(result.statusCode, 200);
  });
});

test('offer expiry worker reports RPC and malformed-response failures without claiming success', async () => {
  await withWorkerEnvironment({
    SUPABASE_URL: 'https://example.supabase.co',
    SUPABASE_SERVICE_ROLE_KEY: 'test-service-role-key'
  }, async () => {
    global.fetch = async () => ({ ok: false, status: 503, text: async () => 'private error detail' });
    const failed = await worker.handler();
    assert.equal(failed.statusCode, 502);
    assert.equal(failed.body, 'Offer expiry RPC failed');

    global.fetch = async () => ({ ok: true, status: 200, text: async () => 'not-an-integer' });
    const malformed = await worker.handler();
    assert.equal(malformed.statusCode, 502);
    assert.equal(malformed.body, 'Unexpected offer expiry response');
  });
});

test('offer expiry worker handles network failures without leaking request details', async () => {
  await withWorkerEnvironment({
    SUPABASE_URL: 'https://example.supabase.co',
    SUPABASE_SERVICE_ROLE_KEY: 'test-service-role-key'
  }, async () => {
    global.fetch = async () => { throw new Error('sensitive transport detail'); };
    const result = await worker.handler();
    assert.equal(result.statusCode, 502);
    assert.equal(result.body, 'Offer expiry worker request failed');
    assert.equal(result.body.includes('sensitive'), false);
  });
});
