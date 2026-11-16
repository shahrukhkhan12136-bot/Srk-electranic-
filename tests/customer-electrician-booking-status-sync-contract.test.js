const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve(__dirname, '..');
const customer = fs.readFileSync(path.join(root, 'booking.html'), 'utf8');
const electrician = fs.readFileSync(path.join(root, 'electrician.html'), 'utf8');
const serviceWorker = fs.readFileSync(path.join(root, 'sw.js'), 'utf8');
const offerDispatchSql = fs.readFileSync(path.join(root, 'supabase/migrations/20261114210000_sequential_nearest_offer_dispatch.sql'), 'utf8');
const offerExpiryWorker = fs.readFileSync(path.join(root, 'netlify/functions/expire-booking-offers.js'), 'utf8');
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
  assert.match(load, /finally \{\s*if \(isCurrent\(\)\) box\.setAttribute\('aria-busy','false'\);\s*\}/);
  assert.match(load, /बुकिंग लोड नहीं हो सकीं/);
});

test('customer booking timeline isolates a rejected per-booking RPC transport', () => {
  const load = functionBody(customer, 'loadCustomerBookings');
  assert.match(load, /catch\s*\(error\)/);
  assert.match(load, /return\s*\{\s*bookingId:\s*row\.id,\s*result:\s*\{\s*error\s*\}\s*\};/);
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
  assert.match(load, /for\(const loader of \[loadElectricianPhoneChangeHistory,loadMyAreaChangeRequests,loadVerificationDocuments,loadEarnings,loadPartnerWallet,refreshElectricianPushState,loadElectricianSupportTickets\]\)\{Promise\.resolve\(\)\.then\(\(\)=>loader\(\)\)\.catch\(e=>\{\/\* Optional profile panels must not block the offer list\. \*\/\}\);\}/);
  assert.ok(load.indexOf('Promise.resolve().then(()=>loader())') < load.indexOf("sb.rpc('srk_get_my_offer_details')"), 'optional panels are scheduled without awaiting them before offer loading');
});


test('customer and electrician lifecycle actions expose retry states and always release their busy guards', () => {
  const customerStart = functionBody(customer, 'customerRespondWorkStart');
  const customerCompletion = functionBody(customer, 'customerRespondWorkCompletion');
  const customerRefund = functionBody(customer, 'customerSubmitBookingRefund');
  const customerCancel = functionBody(customer, 'customerCancelBooking');
  const electricianStart = functionBody(electrician, 'electricianRequestWorkStart');
  const electricianCompletion = functionBody(electrician, 'electricianRequestWorkCompletion');
  const offerResponse = functionBody(electrician, 'respond');

  for (const fn of [customerStart, customerCompletion]) {
    assert.match(fn, /catch\s*\(/);
    assert.match(fn, /finally\s*\{\s*customerLifecycleBusy\.delete\(bookingId\)/);
    assert.match(fn, /नेटवर्क जवाब नहीं मिला/);
  }
  for (const fn of [electricianStart, electricianCompletion]) {
    assert.match(fn, /catch\s*\(/);
    assert.match(fn, /finally\s*\{\s*electricianLifecycleBusy\.delete\(bookingId\)/);
    assert.match(fn, /वर्तमान स्थिति रीफ़्रेश करके जाँचें/);
  }
  assert.match(customerRefund, /catch\s*\(error\)/);
  assert.match(customerRefund, /finally\s*\{\s*if\(button\)button\.disabled=false/);
  assert.match(customerRefund, /दोबारा अनुरोध नहीं भेजा गया/);
  assert.match(customerCancel, /catch\(error\)/);
  assert.match(customerCancel, /finally \{if\(button\)button\.disabled=false;\}/);
  assert.match(customerCancel, /रद्द करने के अनुरोध का परिणाम स्पष्ट नहीं है/);
  assert.match(offerResponse, /catch\(e\)/);
  assert.match(offerResponse, /finally\{/);
  assert.match(offerResponse, /electricianOfferResponseBusy\.delete\(id\)/);
  assert.match(offerResponse, /buttons\.forEach\(\(b,i\)=>\{b\.disabled=false/);
  assert.match(offerResponse, /catch\(e\)\{\s*try\{await refresh\(\)/);
});

test('customer live-location transport failure does not discard rendered booking history', () => {
  const live = customer.slice(customer.indexOf('async function refreshCustomerLiveLocations'), customer.indexOf('if(!customerLiveLocationPoller)'));
  assert.match(live, /try\{const \{data,error\}=await customerSb\.rpc\('srk_customer_get_live_electrician_location'/);
  assert.match(live, /catch\(error\)\{if\(!isCurrent\(id\)\)return;box\.innerHTML=.*लोकेशन अभी लोड नहीं हो सकी/);
  assert.match(live, /await Promise\.all\(bookingIds\.map\(async id=>/);
  const load = functionBody(customer, 'loadCustomerBookings');
  assert.ok(load.indexOf('box.innerHTML = data.map') < load.indexOf('await refreshCustomerLiveLocations()'), 'booking cards render before location refresh');
  assert.match(load, /finally \{\s*if \(isCurrent\(\)\) box\.setAttribute\('aria-busy','false'\);/);
});

test('customer booking list survives rejected supplementary contact, refund, and cancellation RPCs', () => {
  const load = functionBody(customer, 'loadCustomerBookings');
  assert.match(load, /const safeCustomerRpc = async \(name\) => \{\s*try \{ return await customerSb\.rpc\(name\); \}\s*catch \(error\) \{ return \{ data: null, error \}; \}\s*\};/);
  for (const name of ['srk_get_customer_call_contacts','srk_customer_list_booking_refund_requests','srk_customer_list_booking_cancellation_requests','srk_customer_list_booking_cancellation_fee_items']) {
    assert.ok(load.includes("safeCustomerRpc('" + name + "')"), 'supplementary RPC is isolated: ' + name);
  }
  assert.ok(load.indexOf('safeCustomerRpc') < load.indexOf('const timelineMap'), 'booking rendering continues after supplementary RPC results');
  assert.match(load, /try \{\s*const \{data:bill,error\}=await customerSb\.rpc\('srk_customer_get_labour_bill'/);
  assert.match(load, /catch \(error\) \{\s*\/\/ A bill transport failure must not hide the customer's booking history\./);
});


test('Electrician earnings and wallet panels isolate rejected network requests', () => {
  const earningsStart = electrician.indexOf('async function loadEarnings(){');
  const walletStart = electrician.indexOf('async function loadPartnerWallet(){');
  const respondStart = electrician.indexOf('const electricianOfferResponseBusy', walletStart);
  assert.ok(earningsStart >= 0 && walletStart > earningsStart && respondStart > walletStart);
  const earnings = electrician.slice(earningsStart, walletStart);
  const wallet = electrician.slice(walletStart, respondStart);
  assert.match(earnings, /Promise\.resolve\(\)\.then\(\(\)=>sb\.rpc\('srk_get_my_earnings'\)\)\.catch\(error=>\(\{data:null,error\}\)\)/);
  assert.match(earnings, /\.catch\(error=>\(\{data:null,error\}\)\)/);
  assert.match(earnings, /पेआउट स्थिति लोड नहीं हुई/);
  assert.match(wallet, /Promise\.resolve\(\)\.then\(\(\)=>sb\.rpc\('srk_get_my_wallet_summary'\)\)\.catch\(error=>\(\{data:null,error\}\)\)/);
  assert.match(wallet, /Promise\.resolve\(\)\.then\(\(\)=>sb\.from\('srk_wallet_bank_links'\)/);
  assert.match(wallet, /Promise\.resolve\(\)\.then\(\(\)=>sb\.from\('srk_wallet_ledger'\)/);
  assert.match(wallet, /बैंक लिंक की स्थिति लोड नहीं हो सकी/);
  assert.match(wallet, /वॉलेट लेन-देन सूची अभी उपलब्ध नहीं है/);
});


test('Electrician area, KYC, support and phone-history loaders handle rejected transports', () => {
  const areaStart=electrician.indexOf('async function loadMyAreaChangeRequests(){');
  const kycStart=electrician.indexOf('async function loadVerificationDocuments(){');
  const supportStart=electrician.indexOf('async function loadElectricianSupportTickets(){');
  const phoneStart=electrician.indexOf('async function loadElectricianPhoneChangeHistory(){');
  assert.ok(areaStart>=0&&kycStart>areaStart&&supportStart>=0&&phoneStart>=0);
  const area=electrician.slice(areaStart,electrician.indexOf('\nasync function submitElectricianAreaChange',areaStart));
  const kyc=electrician.slice(kycStart,electrician.indexOf('\nasync function openVerificationDocument',kycStart));
  const support=electrician.slice(supportStart,electrician.indexOf('\nlet electricianSupportCreateBusy',supportStart));
  const phone=electrician.slice(phoneStart,electrician.indexOf('\nasync function ',phoneStart+10));
  assert.match(area,/Promise\.resolve\(\)\.then\(\(\)=>sb\.rpc\('srk_electrician_list_my_area_requests'\)\)\.catch\(error=>\(\{data:null,error\}\)\)/);
  assert.match(kyc,/Promise\.resolve\(\)\.then\(\(\)=>sb\.rpc\('srk_electrician_list_my_verification_documents'\)\)\.catch\(error=>\(\{data:null,error\}\)\)/);
  assert.match(support,/Promise\.resolve\(\)\.then\(\(\)=>sb\.rpc\('srk_electrician_list_my_support_tickets'\)\)\.catch\(error=>\(\{data:null,error\}\)\)/);
  assert.match(support,/सहायता अनुरोध अभी उपलब्ध नहीं हैं/);
  assert.match(phone,/Promise\.resolve\(\)\.then\(\(\)=>sb\.functions\.invoke\('electrician-phone-change'/);
  assert.match(phone,/\.catch\(error=>\(\{data:null,error\}\)\)/);
});


test('Electrician support ticket list uses its caught result and support thread catches transport rejection', () => {
  const listStart=electrician.indexOf('async function loadElectricianSupportTickets(){');
  const listEnd=electrician.indexOf('let electricianSupportCreateBusy',listStart);
  const threadStart=electrician.indexOf('async function openElectricianSupportThread(id){');
  const threadEnd=electrician.indexOf('async function sendElectricianSupportReply()',threadStart);
  assert.ok(listStart>=0&&listEnd>listStart&&threadStart>listEnd&&threadEnd>threadStart);
  const list=electrician.slice(listStart,listEnd);
  const thread=electrician.slice(threadStart,threadEnd);
  assert.match(list,/const \{data\}=result;/);
  assert.doesNotMatch(list,/if\(error\).*error\.message/);
  assert.match(list,/result\.error/);
  assert.match(thread,/Promise\.resolve\(\)\.then\(\(\)=>sb\.rpc\('srk_electrician_list_my_support_messages'/);
  assert.match(thread,/\.catch\(error=>\(\{data:null,error\}\)\)/);
  assert.match(thread,/if\(error\)\{box\.textContent='बातचीत नहीं खुली/);
});


test('Electrician initial auth session lookup handles rejected promises safely', () => {
  const initStart=electrician.indexOf('function init(){');
  const initEnd=electrician.indexOf('\nfunction show()',initStart);
  assert.ok(initStart>=0&&initEnd>initStart);
  const init=electrician.slice(initStart,initEnd);
  assert.match(init,/sb\.auth\.getSession\(\)\.then\(/);
  assert.match(init,/\.catch\(\(\)=>\{[\s\S]*?clearElectricianAccountView\(\);user=null;show\(\)/);
  assert.match(init,/लॉगिन स्थिति अभी जाँची नहीं जा सकी/);
});


test('Electrician push disable removes server endpoint before browser unsubscribe', () => {
  const start=electrician.indexOf('async function disableElectricianPushNotifications()');
  const end=electrician.indexOf('\nlet electricianSupportSelectedId',start);
  assert.ok(start>=0&&end>start);
  const disable=electrician.slice(start,end);
  const deleteIndex=disable.indexOf("sb.from('srk_push_subscriptions').delete()");
  const unsubscribeIndex=disable.indexOf('sub.unsubscribe()');
  assert.ok(deleteIndex>=0&&unsubscribeIndex>deleteIndex,'server endpoint must be removed before local subscription is stopped');
  assert.match(disable,/if\(error\)throw error;const stopped=await sub\.unsubscribe\(\)/);
  assert.match(disable,/finally\{await refreshElectricianPushState\(\);\}/);
});


test('Electrician push enable rolls back only a newly created browser subscription on setup failure', () => {
  const start=electrician.indexOf('async function enableElectricianPushNotifications(){');
  const end=electrician.indexOf('async function disableElectricianPushNotifications()',start);
  assert.ok(start>=0&&end>start);
  const enable=electrician.slice(start,end);
  assert.match(enable,/let newlyCreatedSubscription=null/);
  assert.match(enable,/if\(!sub\)\{sub=await reg\.pushManager\.subscribe\([\s\S]*?newlyCreatedSubscription=sub;\}/);
  assert.match(enable,/newlyCreatedSubscription=null;await refreshElectricianPushState\(\)/);
  assert.match(enable,/catch\(err\)\{if\(newlyCreatedSubscription\)\{try\{await newlyCreatedSubscription\.unsubscribe\(\)/);
  assert.match(enable,/button\.disabled=false/);
});


test('Electrician push state allows re-syncing an existing browser subscription', () => {
  const start=electrician.indexOf('async function refreshElectricianPushState()');
  const end=electrician.indexOf('\nasync function enableElectricianPushNotifications',start);
  assert.ok(start>=0&&end>start);
  const state=electrician.slice(start,end);
  assert.match(state,/state\.textContent=sub\?'इस ब्राउज़र पर Push Subscription मौजूद है। सर्वर पंजीकरण दोबारा सिंक करने के लिए Enable दबा सकते हैं।'/);
  assert.match(state,/on\.disabled=permission==='denied';off\.disabled=!sub/);
  const enable=electrician.slice(electrician.indexOf('async function enableElectricianPushNotifications()'),electrician.indexOf('async function disableElectricianPushNotifications()'));
  assert.match(enable,/let sub=await reg\.pushManager\.getSubscription\(\);if\(!sub\)\{sub=await reg\.pushManager\.subscribe/);
  assert.match(enable,/sb\.from\('srk_push_subscriptions'\)\.upsert/);
});

test('Electrician dashboard refresh ignores stale profile, offer and supplementary RPC responses', () => {
  const refresh = functionBody(electrician, 'refresh');
  assert.match(electrician, /electricianRefreshRequest=0/);
  assert.match(refresh, /const refreshRequest=\+\+electricianRefreshRequest,refreshUserId=user\.id,isCurrent=\(\)=>refreshRequest===electricianRefreshRequest&&user\?\.id===refreshUserId/);
  assert.match(refresh, /await sb\.from\('electrician_profiles'[\s\S]*?if\(!isCurrent\(\)\)return/);
  assert.match(refresh, /await sb\.rpc\('srk_get_my_offer_details'\)[\s\S]*?if\(!isCurrent\(\)\)return/);
  assert.match(refresh, /await Promise\.all\(rows\.filter\(o=>o\.booking_status==='completed'[\s\S]*?if\(!isCurrent\(\)\)return;document\.getElementById\('jobs'\)\.innerHTML/);
  const logout = functionBody(electrician, 'logout');
  assert.match(logout, /electricianRefreshRequest\+\+/);
});

test('Customer booking refresh ignores stale requests after session, booking, timeline and bill reads', () => {
  const load = functionBody(customer, 'loadCustomerBookings');
  assert.match(customer, /let customerBookingRefreshRequest = 0/);
  assert.match(load, /const request = \+\+customerBookingRefreshRequest/);
  assert.match(load, /const isCurrent = \(\) => request === customerBookingRefreshRequest/);
  assert.match(load, /if \(!isCurrent\(\)\) return;[\s\S]*?const \{ data, error \} = await customerSb\.from\('service_bookings'\)/);
  assert.match(load, /if \(!isCurrent\(\)\) return;\s*if \(error\) throw error/);
  assert.match(load, /await Promise\.all\(data\.map\(async row =>/);
  assert.match(load, /if \(!isCurrent\(\)\) return;\s*timelineResults\.forEach/);
  assert.match(load, /if \(!isCurrent\(\)\) return;\s*box\.innerHTML = data\.map/);
  assert.match(load, /if \(isCurrent\(\)\) box\.setAttribute\('aria-busy','false'\)/);
  assert.match(customer, /customerBookingRefreshRequest\+\+;[\s\S]*?customerLiveLocationRefreshRequest\+\+;\s*customerLiveLocationBookingIds=\[\]/);
});

test('Customer live location polling ignores stale responses and preserves network-error state', () => {
  const start = customer.indexOf('async function refreshCustomerLiveLocations()');
  const end = customer.indexOf('\nif(!customerLiveLocationPoller)', start);
  const refresh = customer.slice(start, end);
  assert.ok(start >= 0 && end > start);
  assert.match(refresh, /const request=\+\+customerLiveLocationRefreshRequest/);
  assert.match(refresh, /request===customerLiveLocationRefreshRequest&&customerLiveLocationBookingIds\.includes\(id\)/);
  assert.match(refresh, /if\(!isCurrent\(id\)\)return/);
  assert.match(refresh, /if\(error\)\{/);
  assert.match(refresh, /if\(!data\?\.is_active\)\{/);
  assert.match(refresh, /navigator\.onLine===false\|\|document\.visibilityState==='hidden'/);
  assert.match(customer, /customerLiveLocationRefreshRequest\+\+;\s*customerLiveLocationBookingIds=data\.filter/);
  assert.match(customer, /customerLiveLocationRefreshRequest\+\+;\s*customerLiveLocationBookingIds=\[\]/);
});

test('Customer offline event hides stale live location and invalidates in-flight polls', () => {
  assert.match(customer, /const handleCustomerOffline = \(\) => \{/);
  const start = customer.indexOf('const handleCustomerOffline = () => {');
  const end = customer.indexOf("window.addEventListener('offline', handleCustomerOffline);", start);
  assert.ok(start >= 0 && end > start, 'offline handler and listener exist');
  const handler = customer.slice(start, end);
  assert.match(handler, /customerLiveLocationRefreshRequest\+\+/);
  assert.match(handler, /customerLiveLocationBookingIds\.forEach/);
  assert.match(handler, /पुरानी लोकेशन छिपा दी गई है/);
  assert.match(handler, /role=\\?"status\\?"/);
  assert.match(customer, /window\.addEventListener\('online', scheduleCustomerResumeRefresh\)/);
});

test('Customer booking list refreshes on foreground and reconnect without duplicate rapid refreshes', () => {
  assert.match(customer, /let customerResumeRefreshTimer = null/);
  assert.match(customer, /const scheduleCustomerResumeRefresh = \(\) => \{/);
  assert.match(customer, /window\.addEventListener\('focus', scheduleCustomerResumeRefresh\)/);
  assert.match(customer, /window\.addEventListener\('online', scheduleCustomerResumeRefresh\)/);
  assert.match(customer, /document\.addEventListener\('visibilitychange',[\s\S]*?scheduleCustomerResumeRefresh\(\)/);
  assert.match(customer, /document\.visibilityState === 'visible'[\s\S]*?loadCustomerBookings\(\)/);
});

test('Electrician offers refresh on foreground and reconnect using the guarded dashboard refresh', () => {
  assert.match(electrician, /let electricianResumeRefreshTimer=null/);
  assert.match(electrician, /function scheduleElectricianResumeRefresh\(\)/);
  assert.match(electrician, /window\.addEventListener\('focus',scheduleElectricianResumeRefresh\)/);
  assert.match(electrician, /window\.addEventListener\('online',scheduleElectricianResumeRefresh\)/);
  assert.match(electrician, /document\.addEventListener\('visibilitychange',[\s\S]*?scheduleElectricianResumeRefresh\(\)/);
  assert.match(electrician, /document\.visibilityState==='visible'&&user\)refresh\(\)/);
});

test('Electrician notification deep links explain unavailable or non-actionable offers', () => {
  const focusStart=electrician.indexOf('function focusElectricianOfferFromNotification()');
  const focusEnd=electrician.indexOf('\nfunction base64UrlToBytes',focusStart);
  assert.ok(focusStart>=0&&focusEnd>focusStart,'notification focus handler exists');
  const focus=electrician.slice(focusStart,focusEnd);
  assert.match(focus, /const card=document\.getElementById\('electricianOffer_\'\+offerId\)/);
  assert.match(focus, /if\(!card\.querySelector\('button\[onclick\*="respond\("\]'\)\)notice=/);
  assert.match(focus, /सूचना वाला ऑफर अब आपकी सूची में उपलब्ध नहीं है/);
  assert.match(focus, /संभव है कि समय समाप्त हो गया हो/);
  assert.match(focus, /status\.setAttribute\('role','status'\)/);
  assert.match(focus, /params\.delete\('offerId'\)/);
});

test('Electrician offer expiry remains server-authoritative and advances the next eligible offer', () => {
  assert.match(offerDispatchSql, /v_expires_at<=clock_timestamp\(\)/);
  assert.match(offerDispatchSql, /SET status='expired',responded_at=clock_timestamp\(\)/);
  assert.match(offerDispatchSql, /v_next:=private\.srk_dispatch_next_booking_offer\(v_booking_id\)/);
  assert.match(offerDispatchSql, /'code','offer_expired'/);
  assert.match(offerDispatchSql, /WHERE o\.status='offered' AND o\.expires_at<=clock_timestamp\(\)/);
  assert.match(offerExpiryWorker, /srk_expire_and_advance_booking_offers/);
  assert.match(offerExpiryWorker, /schedule: "\* \* \* \* \*"/);
  const respondStart = electrician.indexOf('function respond(');
  const respondEnd = electrician.indexOf('\nfunction bookingMapDirections', respondStart);
  const respond = electrician.slice(respondStart, respondEnd);
  assert.ok(respondStart >= 0 && respondEnd > respondStart);
  assert.match(respond, /data\?\.code==='offer_expired'/);
  assert.match(respond, /await refresh\(\)/);
});

test('Electrician offer response keeps a confirmed server decision distinct from a later refresh failure', () => {
  const start = electrician.indexOf('async function respond(button,id,response){');
  const end = electrician.indexOf('\nfunction bookingMapDirections', start);
  assert.ok(start >= 0 && end > start);
  const respond = electrician.slice(start, end);
  const confirmed = respond.indexOf("if(data?.success!==true)");
  const successRefresh = respond.indexOf("try{await refresh();if(!isCurrent())return;}catch(_){if(isCurrent())alert('आपका जवाब सर्वर पर दर्ज हो गया है");
  const expiryRefresh = respond.indexOf("try{await refresh();if(!isCurrent())return;}catch(_){if(isCurrent())alert('ऑफर समाप्त होने की पुष्टि मिल गई है");
  const uncertainCatch = respond.indexOf("नेटवर्क जवाब नहीं मिला। ऑफर की वर्तमान स्थिति रीफ़्रेश करके जाँचें");
  assert.ok(confirmed >= 0 && successRefresh > confirmed, 'confirmed response has its own refresh-failure handling');
  assert.ok(expiryRefresh >= 0, 'expired offer has its own refresh-failure handling');
  assert.ok(uncertainCatch > successRefresh, 'uncertain RPC responses still reconcile by refreshing authoritative offers');
  assert.match(respond, /electricianOfferResponseBusy\.delete\(id\)/);
});

test('Service worker notification click routes to a validated electrician offer deep link', () => {
  assert.match(serviceWorker, /self\.addEventListener\('push'/);
  assert.match(serviceWorker, /payload\.offerId/);
  assert.match(serviceWorker, /target\.searchParams\.set\('offerId',offerId\)/);
  assert.match(serviceWorker, /self\.addEventListener\('notificationclick'/);
  assert.match(serviceWorker, /self\.clients\.matchAll\(\{type:'window',includeUncontrolled:true\}\)/);
  assert.match(serviceWorker, /client\.navigate\(target\.href\)/);
  assert.match(serviceWorker, /self\.clients\.openWindow\(target\.href\)/);
});


test('Customer and electrician lifecycle actions distinguish confirmed RPC success from later refresh failure', () => {
  const customerStart = functionBody(customer, 'customerRespondWorkStart');
  const customerCompletion = functionBody(customer, 'customerRespondWorkCompletion');
  const electricianStart = functionBody(electrician, 'electricianRequestWorkStart');
  const electricianCompletion = functionBody(electrician, 'electricianRequestWorkCompletion');
  for (const fn of [customerStart, customerCompletion]) {
    assert.ok(fn.includes("try{await loadCustomerBookings();}catch(_){alert('आपका जवाब सर्वर पर दर्ज हो गया है"), 'confirmed customer action has separate refresh-failure feedback');
    assert.ok(fn.includes('await loadCustomerBookings();') && fn.includes('नेटवर्क जवाब नहीं मिला।'), 'uncertain customer RPC still refreshes authoritative bookings');
    assert.ok(fn.includes('स्थिति रीफ़्रेश करके जाँचें'), 'uncertain customer outcome asks user to check current status');
  }
  for (const fn of [electricianStart, electricianCompletion]) {
    assert.ok(fn.includes('try{await refresh();}catch(_){alert('), 'confirmed electrician action has separate refresh-failure handling');
    assert.ok(fn.includes('सर्वर पर दर्ज हो गया है') || fn.includes('सर्वर पर दर्ज हो गई है'), 'refresh failure does not misreport the confirmed action');
    assert.ok(fn.includes('await refresh();') && fn.includes('नेटवर्क जवाब नहीं मिला।'), 'uncertain electrician RPC still refreshes authoritative dashboard');
    assert.ok(fn.includes('वर्तमान स्थिति रीफ़्रेश करके जाँचें'), 'uncertain electrician outcome asks user to check current status');
  }
});
test('Customer Razorpay verification reconciles uncertain responses against authoritative payment history', () => {
  const reconcile = functionBody(customer, 'reconcileCustomerPaymentAfterUncertainVerification');
  assert.match(reconcile, /srk_customer_get_payment_history/);
  assert.match(reconcile, /p_limit:25,p_offset:0/);
  assert.match(reconcile, /row\.booking_id===bookingId&&\['payment','manual_payment'\]\.includes/);
  assert.match(reconcile, /await loadCustomerBookings\(\)/);
  assert.match(reconcile, /await loadCustomerPaymentHistory\(true\)/);
  const payment = functionBody(customer, 'startRazorpayPayment');
  assert.match(payment, /const paymentBookingId = pendingBookingId/);
  assert.match(payment, /booking_id: paymentBookingId/);
  assert.match(payment, /reconcileCustomerPaymentAfterUncertainVerification\(paymentBookingId\)/);
  assert.match(payment, /अभी दोबारा भुगतान न करें/);
  assert.doesNotMatch(payment, /catch \(err\) \{ setPaymentStatus\(err\.message, true\); \}/);
});

test('Customer booking refresh displays its network error before returning failure', () => {
  const load = functionBody(customer, 'loadCustomerBookings');
  const catchStart = load.indexOf('} catch(error) {');
  const finallyStart = load.indexOf('} finally {', catchStart);
  assert.ok(catchStart >= 0 && finallyStart > catchStart);
  const catchBlock = load.slice(catchStart, finallyStart);
  assert.match(catchBlock, /if \(!isCurrent\(\)\) return;\s*box\.textContent=navigator\.onLine===false[\s\S]*?return false;/);
  assert.doesNotMatch(catchBlock, /return false;\s*box\.textContent/);
});

test('customer auth changes invalidate in-flight booking refreshes before another session can render them', () => {
  const authStart = customer.indexOf("customerSb.auth.onAuthStateChange((event) => {");
  assert.ok(authStart >= 0, 'customer auth state listener exists');
  const authEnd = customer.indexOf("setTimeout(syncCustomerSession, 0);", authStart);
  assert.ok(authEnd > authStart, 'auth listener schedules session synchronization');
  const authBlock = customer.slice(authStart, authEnd);
  assert.match(authBlock, /customerBookingRefreshRequest\+\+/);
  assert.match(authBlock, /customerBookings/);
  assert.match(authBlock, /लॉगिन सत्र बदल रहा है/);
});
