const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve(__dirname, '..');
const booking = fs.readFileSync(path.join(root, 'booking.html'), 'utf8');
const api = fs.readFileSync(path.join(root, 'create-booking.js'), 'utf8');

test('immediate customer booking does not require nonexistent schedule date/time fields', () => {
  const submitAt = booking.indexOf("document.getElementById('booking').addEventListener('submit'");
  assert.ok(submitAt >= 0, 'customer booking submit handler exists');
  const submit = booking.slice(submitAt);
  assert.doesNotMatch(submit, /value\(['"]date['"]\)|value\(['"]time['"]\)/);
  assert.doesNotMatch(submit, /getElementById\(['"]date['"]\)|getElementById\(['"]time['"]\)/);
});

test('customer booking payload follows the immediate-dispatch API contract', () => {
  const submitAt = booking.indexOf("document.getElementById('booking').addEventListener('submit'");
  const payloadAt = booking.indexOf('const bookingPayload = {', submitAt);
  const requestAt = booking.indexOf("fetch('/api/create-booking'", payloadAt);
  assert.ok(submitAt >= 0 && payloadAt > submitAt && requestAt > payloadAt);
  const payload = booking.slice(payloadAt, requestAt);
  assert.doesNotMatch(payload, /preferred_date|preferred_time|\bdate\s*:|\btime\s*:/);
  assert.match(api, /const preferred_date = null;/);
  assert.match(api, /const preferred_time = null;/);
  assert.match(api, /immediate service requests only/i);
});
