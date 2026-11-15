const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve(__dirname, '..');
const electrician = fs.readFileSync(path.join(root, 'electrician.html'), 'utf8');
const customer = fs.readFileSync(path.join(root, 'booking.html'), 'utf8');

function handler(source, name) {
  const start = source.indexOf('async function ' + name + '(');
  assert.ok(start >= 0, name + ' handler exists');
  const tail = source.slice(start + 1);
  const next = tail.search(/\n(?:async )?function\s+[A-Za-z0-9_$]+\s*\(/);
  return source.slice(start, next < 0 ? source.length : start + 1 + next);
}

test('electrician start and completion requests are serialized per booking', () => {
  assert.match(electrician, /const electricianLifecycleBusy=new Set\(\)/);
  for (const [name, rpc] of [
    ['electricianRequestWorkStart', 'srk_electrician_request_work_start'],
    ['electricianRequestWorkCompletion', 'srk_electrician_request_work_completion']
  ]) {
    const fn = handler(electrician, name);
    assert.match(fn, /electricianLifecycleBusy\.has\(bookingId\)/);
    assert.match(fn, /electricianLifecycleBusy\.add\(bookingId\)/);
    assert.match(fn, new RegExp(rpc));
    assert.match(fn, /finally\{electricianLifecycleBusy\.delete\(bookingId\);\}/);
  }
});

test('customer start approval is validated and serialized per booking', () => {
  assert.match(customer, /const customerLifecycleBusy=new Set\(\)/);
  const fn = handler(customer, 'customerRespondWorkStart');
  assert.match(fn, /!\['approved','rejected'\]\.includes\(response\)/);
  assert.match(fn, /customerLifecycleBusy\.has\(bookingId\)/);
  assert.match(fn, /customerLifecycleBusy\.add\(bookingId\)/);
  assert.match(fn, /srk_customer_respond_work_start/);
  assert.match(fn, /finally\{customerLifecycleBusy\.delete\(bookingId\);\}/);
});

test('customer completion response allows only approve, reject or dispute and requires dispute reason', () => {
  const fn = handler(customer, 'customerRespondWorkCompletion');
  assert.match(fn, /!\['approved','rejected','disputed'\]\.includes\(response\)/);
  assert.match(fn, /note\.length<20\|\|note\.length>1000/);
  assert.match(fn, /srk_customer_respond_work_completion/);
  assert.match(fn, /customerLifecycleBusy\.has\(bookingId\)/);
  assert.match(fn, /finally[\s\S]*?customerLifecycleBusy\.delete\(bookingId\)/);
});

test('customer and electrician timers are display-only projections of server timestamps and elapsed seconds', () => {
  assert.match(customer, /work_timer_elapsed_seconds,work_started_at,work_timer_running/);
  assert.match(customer, /Date\.parse\(el\.dataset\.started\)/);
  assert.match(electrician, /data-running=.*work_timer_running/);
  assert.match(electrician, /Date\.parse\(el\.dataset\.started\)/);
  assert.match(electrician, /srk_electrician_get_labour_bill/);
  assert.doesNotMatch(customer + electrician, /\.update\(\{[^}]*work_timer_(?:running|elapsed_seconds)/);
});

test('electrician offer response is restricted to accepted/declined and rejects duplicate in-flight response', () => {
  const fn = handler(electrician, 'respond');
  assert.match(fn, /!\['accepted','declined'\]\.includes\(response\)/);
  assert.match(fn, /electricianOfferResponseBusy\.has\(id\)/);
  assert.match(fn, /electricianOfferResponseBusy\.add\(id\)/);
  assert.match(fn, /srk_respond_to_offer/);
  assert.match(fn, /data\?\.success!==true/);
  assert.match(fn, /finally[\s\S]*?electricianOfferResponseBusy\.delete\(id\)/);
});

test('booking lifecycle UI distinguishes pending start, running work, completion review and dispute', () => {
  assert.match(electrician, /booking_status==='awaiting_work_start_approval'/);
  assert.match(electrician, /booking_status==='in_progress'/);
  assert.match(electrician, /completion_approval_status==='pending'/);
  assert.match(electrician, /completion_approval_status==='disputed'/);
  assert.match(customer, /work_start_approval_status/);
  assert.match(customer, /completion_approval_status/);
  assert.match(customer, /completion_approval_status==='pending'/);
});
