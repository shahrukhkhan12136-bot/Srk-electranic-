const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve(__dirname, '..');
const customer = fs.readFileSync(path.join(root, 'booking.html'), 'utf8');
const electrician = fs.readFileSync(path.join(root, 'electrician.html'), 'utf8');
const offerProjection = fs.readFileSync(path.join(root, 'supabase/migrations/20261115220000_retire_live_legacy_quotation_rpcs.sql'), 'utf8');
const timelineSql = fs.readFileSync(path.join(root, 'supabase/migrations/20261114260000_fix_work_start_rpc_and_append_only_event_history.sql'), 'utf8');

function functionBody(source, name) {
  const start = source.indexOf('async function ' + name + '(');
  assert.ok(start >= 0, name + ' handler exists');
  const tail = source.slice(start + 1);
  const next = tail.search(/\n(?:async )?function\s+[A-Za-z0-9_$]+\s*\(/);
  return source.slice(start, next < 0 ? source.length : start + 1 + next);
}

function sqlFunction(source, name) {
  const start = source.indexOf('CREATE FUNCTION public.' + name + '(');
  assert.ok(start >= 0, name + ' final SQL projection exists');
  const end = source.indexOf('$function$;', start);
  assert.ok(end > start, name + ' SQL function body ends');
  return source.slice(start, end + '$function$;'.length);
}

test('customer booking refresh reads authoritative owner-scoped lifecycle and timer fields', () => {
  const load = functionBody(customer, 'loadCustomerBookings');
  const projection = load.match(/\.select\('([^']+)'\)/)?.[1] || '';
  for (const field of ['status','work_start_approval_status','completion_approval_status','completion_requested_at','work_timer_elapsed_seconds','work_started_at','work_timer_running']) assert.ok(projection.split(',').includes(field), 'customer booking projection includes ' + field);
  assert.match(load, /\.eq\('customer_user_id', session\.user\.id\)/);
  assert.match(load, /\.order\('created_at', \{ ascending: false \}\)/);
  assert.match(load, /srk_customer_get_my_booking_work_timeline/);
  assert.match(load, /p_booking_id:row\.id/);
  assert.match(load, /row\.status==='awaiting_work_start_approval'&&row\.work_start_approval_status==='pending'/);
  assert.match(load, /row\.status==='in_progress'&&row\.completion_approval_status==='pending'/);
  assert.match(load, /row\.completion_approval_status==='disputed'/);
});

test('electrician refresh uses the current offer projection and renders the same booking lifecycle states', () => {
  const refresh = functionBody(electrician, 'refresh');
  assert.match(refresh, /srk_get_my_offer_details/);
  assert.match(refresh, /if\(oe\)[\s\S]*?काम के ऑफर लोड नहीं हो सके/);
  assert.match(refresh, /booking_status==='awaiting_work_start_approval'/);
  assert.match(refresh, /booking_status==='in_progress'/);
  assert.match(refresh, /completion_approval_status==='pending'/);
  assert.match(refresh, /completion_approval_status==='disputed'/);
  assert.match(refresh, /booking_status==='completed'/);
});

test('final electrician offer RPC exposes every lifecycle/timer field consumed by the portal', () => {
  const fn = sqlFunction(offerProjection, 'srk_get_my_offer_details');
  const signature = fn.slice(0, fn.indexOf('LANGUAGE sql'));
  for (const field of [
    'booking_status text',
    'work_start_approval_status text',
    'completion_approval_status text',
    'completion_requested_at timestamptz',
    'work_timer_elapsed_seconds numeric',
    'work_started_at timestamptz',
    'work_timer_running boolean'
  ]) assert.ok(signature.includes(field), 'RPC return table includes ' + field);
  for (const field of [
    'b.status',
    'b.work_start_approval_status',
    'b.completion_approval_status',
    'b.completion_requested_at',
    'b.work_timer_elapsed_seconds',
    'b.work_started_at',
    'b.work_timer_running'
  ]) assert.ok(fn.includes(field), 'RPC SELECT projects ' + field);
  assert.match(fn, /p\.user_id=auth\.uid\(\) OR p\.auth_user_id=auth\.uid\(\)/);
});

test('customer work timeline is owner-scoped and exposes only safe event labels, actor role and timestamp', () => {
  const fnStart = timelineSql.indexOf('create or replace function public.srk_customer_get_my_booking_work_timeline(');
  assert.ok(fnStart >= 0);
  const fnEnd = timelineSql.indexOf('$function$;', fnStart);
  const fn = timelineSql.slice(fnStart, fnEnd + '$function$;'.length);
  assert.match(fn, /returns table\(event_type text,actor_role text,occurred_at timestamptz\)/i);
  assert.match(fn, /b\.id=p_booking_id and b\.customer_user_id=v_uid/);
  assert.match(fn, /order by e\.created_at asc,e\.id asc/);
  assert.doesNotMatch(fn, /old_state|new_state|event_payload/);
});

test('booking state changes trigger an explicit refresh after user decisions and offer responses', () => {
  const customerStart = functionBody(customer, 'customerRespondWorkStart');
  const customerCompletion = functionBody(customer, 'customerRespondWorkCompletion');
  const electricianStart = functionBody(electrician, 'electricianRequestWorkStart');
  const electricianCompletion = functionBody(electrician, 'electricianRequestWorkCompletion');
  const offerResponse = functionBody(electrician, 'respond');
  for (const fn of [customerStart, customerCompletion]) assert.match(fn, /await loadCustomerBookings\(\)/);
  for (const fn of [electricianStart, electricianCompletion, offerResponse]) assert.match(fn, /await refresh\(\)/);
});

test('customer booking timeline reports partial per-booking RPC errors without throwing an undefined variable', () => {
  const load = functionBody(customer, 'loadCustomerBookings');
  assert.match(load, /const timelineResults = await Promise\.all\(data\.map/);
  assert.match(load, /timelineResults\.forEach\(\(\{bookingId,result\}\)=>/);
  assert.match(load, /if\(timelineResults\.some\(\(\{result\}\)=>result\.error\)\)\s*\{/);
  assert.doesNotMatch(load, /if\(timelineResult\.error\)/);
});

test('customer booking status has a clear label while electrician work-start approval is pending', () => {
  assert.match(customer, /awaiting_work_start_approval:'काम शुरू करने के लिए आपकी मंजूरी प्रतीक्षित'/);
  assert.match(customer, /row\.status==='awaiting_work_start_approval'&&row\.work_start_approval_status==='pending'/);
});

test('Customer booking list guards rejected auth session lookup and always clears loading state', () => {
  const load = functionBody(customer, 'loadCustomerBookings');
  const tryAt = load.indexOf('try {');
  const sessionAt = load.indexOf('customerSb.auth.getSession()');
  assert.ok(tryAt >= 0 && sessionAt > tryAt, 'session lookup is inside booking loader try/catch');
  assert.match(load, /if \(sessionError \|\| !session\)/);
  assert.match(load, /finally \{\s*box\.setAttribute\('aria-busy','false'\);\s*\}/);
  assert.match(load, /बुकिंग लोड नहीं हो सकीं/);
});

test('customer booking timeline isolates a rejected per-booking RPC transport', () => {
  const load = functionBody(customer, 'loadCustomerBookings');
  assert.match(load, /catch\\(error\\)/);
  assert.match(load, /return \\{ bookingId: row\\.id, result: \\{ error \\} \\};/);
});


test('electrician profile panel transport failures do not prevent booking offers from loading', () => {
  const load = functionBody(electrician, 'refresh');
  const loaders = [
    'loadElectricianPhoneChangeHistory',
    'loadMyAreaChangeRequests',
    'loadVerificationDocuments',
    'loadEarnings',
    'loadPartnerWallet',
    'refreshElectricianPushState',
    'loadElectricianSupportTickets'
  ];
  for (const name of loaders) assert.ok(load.includes(name), 'refresh attempts ' + name);
  assert.match(load, /for\(const loader of \[loadElectricianPhoneChangeHistory,loadMyAreaChangeRequests,loadVerificationDocuments,loadEarnings,loadPartnerWallet,refreshElectricianPushState,loadElectricianSupportTickets\]\)\{try\{await loader\(\);\}catch\(e\)\{\/\* Optional profile panels must not block the offer list\. \*\/\}\}/);
  assert.ok(load.indexOf('catch(e){/* Optional profile panels must not block the offer list. */}') < load.indexOf("sb.rpc('srk_get_my_offer_details')"), 'offer loading continues after an optional panel failure');
});


test('customer booking list survives rejected supplementary contact, refund, and cancellation RPCs', () => {
  const load = functionBody(customer, 'loadCustomerBookings');
  assert.match(load, /const safeCustomerRpc = async \(name\) => \{\s*try \{ return await customerSb\.rpc\(name\); \}\s*catch \(error\) \{ return \{ data: null, error \}; \}\s*\};/);
  for (const name of ['srk_get_customer_call_contacts','srk_customer_list_booking_refund_requests','srk_customer_list_booking_cancellation_requests','srk_customer_list_booking_cancellation_fee_items']) {
    assert.ok(load.includes("safeCustomerRpc('" + name + "')"), 'supplementary RPC is isolated: ' + name);
  }
  assert.ok(load.indexOf('safeCustomerRpc') < load.indexOf('const timelineMap'), 'booking rendering continues after supplementary RPC results');
});
