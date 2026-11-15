const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const source = fs.readFileSync(path.join(__dirname, '..', 'supabase/functions/push-job-offer/index.ts'), 'utf8');

test('push sender authenticates webhook calls and bounds payload size', () => {
  assert.match(source, /x-srk-push-secret/);
  assert.match(source, /req\.method !== "POST"/);
  assert.match(source, /32768/);
  assert.match(source, /Unsupported webhook payload/);
});

test('push sender revalidates the current offer and its expiry before sending', () => {
  assert.match(source, /\.from\("job_offers"\)/);
  assert.match(source, /currentOffer\.status !== "offered"/);
  assert.match(source, /Date\.parse\(currentOffer\.expires_at\) <= Date\.now\(\)/);
  assert.match(source, /offer_identity_changed/);
});

test('push sender verifies booking is still offerable and unassigned', () => {
  assert.match(source, /\.from\("service_bookings"\)/);
  assert.match(source, /!\["new", "confirmed"\]\.includes\(booking\.status\)/);
  assert.match(source, /booking\.assigned_electrician_id !== null/);
});

test('push sender requires active approved available electrician', () => {
  assert.match(source, /available_for_work/);
  assert.match(source, /profile\.active/);
  assert.match(source, /profile\.verification_status !== "approved"/);
});

test('push sender removes malformed and permanently expired endpoints', () => {
  assert.match(source, /\.delete\(\)\.eq\("id", target\.subscription_id\)/);
  assert.match(source, /status === 404 \|\| status === 410/);
});

test('public config response never exposes private keys or webhook secret', () => {
  const getBlock = source.slice(source.indexOf('if (req.method === "GET")'), source.indexOf('if (req.method !== "POST"'));
  assert.match(getBlock, /publicKey: vapidPublic/);
  assert.doesNotMatch(getBlock, /vapidPrivate|webhookSecret|serviceKey/);
});
