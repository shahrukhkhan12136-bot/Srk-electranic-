'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const source = fs.readFileSync(path.join(__dirname, '..', 'electrician.html'), 'utf8');

function body(name) {
  const start = source.indexOf('async function ' + name + '(');
  assert.ok(start >= 0, name + ' handler exists');
  const tail = source.slice(start + 1);
  const next = tail.search(/\n(?:async )?function\s+[A-Za-z0-9_$]+\s*\(/);
  return source.slice(start, next < 0 ? source.length : start + 1 + next);
}

test('offer response is owner-session RPC driven, guarded against duplicates and reconciles expiry', () => {
  const respond = body('respond');
  assert.match(respond, /!\['accepted','declined'\]\.includes\(response\)/);
  assert.match(respond, /electricianOfferResponseBusy\.has\(id\)/);
  assert.match(respond, /electricianOfferResponseBusy\.add\(id\)/);
  assert.match(respond, /srk_respond_to_offer/);
  assert.match(respond, /p_offer_id:id,p_response:response/);
  assert.match(respond, /data\?\.code==='offer_expired'/);
  assert.match(respond, /data\?\.success!==true/);
  assert.match(respond, /finally\{[\s\S]*?electricianOfferResponseBusy\.delete\(id\)/);
  assert.match(respond, /const requestedUserId=user\.id,requestedProfileId=profile\.id,requestedGeneration=electricianAccountViewGeneration/);
  assert.ok(respond.indexOf('const requestedUserId=user.id') < respond.indexOf("if(!confirm(response==='accepted'"));
  assert.match(respond, /if\(!confirm\(response==='accepted'[\s\S]*?\|\|!isCurrent\(\)\)return/);
  assert.match(respond, /const isCurrent=\(\)=>!electricianLogoutBusy&&requestedGeneration===electricianAccountViewGeneration&&user\?\.id===requestedUserId&&profile\?\.id===requestedProfileId/);
  assert.match(respond, /if\(!isCurrent\(\)\)return/);
  assert.match(respond, /let keepDisabled=false/);
  assert.match(respond, /keepDisabled=true/);
  assert.match(respond, /if\(isCurrent\(\)&&!keepDisabled\)buttons\.forEach\(\(b,i\)=>\{b\.disabled=false/);
  assert.match(respond, /catch\(_\)\{keepDisabled=true;if\(isCurrent\(\)\)alert\('नेटवर्क जवाब नहीं मिला। ऑफर सूची रीफ़्रेश नहीं हो सकी/);
  const clearStart=source.indexOf('function clearElectricianAccountView()');
  const clearEnd=source.indexOf('\nfunction init()',clearStart);
  assert.ok(clearStart>=0&&clearEnd>clearStart,'account view reset handler exists');
  assert.match(source.slice(clearStart,clearEnd), /electricianAccountViewGeneration\+\+/);
});

test('offer refresh uses the scoped offer RPC and refreshes on offer/profile realtime changes', () => {
  const refresh = body('refresh');
  assert.match(refresh, /srk_get_my_offer_details/);
  assert.match(refresh, /table:'job_offers'/);
  assert.match(refresh, /table:'electrician_profiles'/);
  assert.match(refresh, /filter:'user_id=eq\.'\+user\.id/);
  assert.match(refresh, /if\(!isCurrent\(\)\)return/);
  assert.match(source, /scheduleElectricianResumeRefresh/);
  assert.match(source, /document\.visibilityState==='visible'/);
});

test('work start and completion use separate server lifecycle RPCs with duplicate-action guards', () => {
  const start = body('electricianRequestWorkStart');
  const complete = body('electricianRequestWorkCompletion');
  assert.match(start, /electricianLifecycleBusy\.has\(requestKey\)/);
  assert.match(start, /srk_electrician_request_work_start/);
  assert.match(start, /data\?\.success/);
  assert.match(complete, /electricianLifecycleBusy\.has\(requestKey\)/);
  assert.match(complete, /srk_electrician_request_work_completion/);
  assert.match(complete, /data\?\.success/);
  assert.match(source, /data-running=/);
  assert.match(source, /data-started=/);
  assert.match(source, /data-accumulated=/);
  assert.match(source, /srk_electrician_get_labour_bill/);
  assert.match(source, /अंतिम मेहनताना सर्वर के रिकॉर्ड समय से बनेगा/);
});

test('availability can only be changed by an active Admin-approved electrician through the RPC', () => {
  const availability = body('setElectricianAvailability');
  assert.match(availability, /!isCurrent\(\)\|\|!profile\.active\|\|profile\.verification_status!=='approved'/);
  assert.match(availability, /if\(!confirm\(/);
  assert.match(availability, /srk_electrician_set_availability/);
  assert.match(availability, /p_available:available/);
  assert.match(availability, /requestedGeneration=electricianAccountViewGeneration/);
  assert.match(availability, /user\?\.id===requestedUserId&&profile\?\.id===requestedProfileId/);
  assert.match(availability, /if\(!isCurrent\(\)\)return/);
  assert.match(availability, /await refresh\(\)/);
});

test('work lifecycle actions are isolated across electrician account switches', () => {
  for (const [name, rpc] of [
    ['electricianRequestWorkStart', 'srk_electrician_request_work_start'],
    ['electricianRequestWorkCompletion', 'srk_electrician_request_work_completion']
  ]) {
    const action = body(name);
    assert.match(action, /const requestedUserId=user\?\.id,requestedProfileId=profile\?\.id,requestedGeneration=electricianAccountViewGeneration/);
    assert.match(action, /const requestKey=requestedGeneration\+':'\+String\(bookingId\)/);
    assert.match(action, /electricianLifecycleBusy\.has\(requestKey\)/);
    assert.match(action, /electricianLifecycleBusy\.add\(requestKey\)/);
    assert.match(action, new RegExp(rpc));
    assert.match(action, /if\(!isCurrent\(\)\)return/);
    assert.match(action, /finally\{electricianLifecycleBusy\.delete\(requestKey\);?\}/);
    assert.match(action, /if\(isCurrent\(\)\)alert\(/);
  }
});

test('electrician SOS requests do not update another account view after an auth switch', () => {
  const sos = body('submitElectricianSosAlert');
  assert.match(sos, /requestedUserId=user\?\.id,requestedProfileId=profile\?\.id,requestedGeneration=electricianAccountViewGeneration/);
  assert.match(sos, /requestKey=requestedGeneration\+':'\+String\(id\)/);
  assert.match(sos, /electricianSosBusy\.has\(requestKey\)/);
  assert.match(sos, /electricianSosBusy\.add\(requestKey\)/);
  assert.match(sos, /srk_create_sos_alert/);
  assert.match(sos, /if\(!isCurrent\(\)\)return/);
  assert.match(sos, /catch\(_\)\{if\(isCurrent\(\)&&status\)/);
  assert.match(sos, /finally\{electricianSosBusy\.delete\(requestKey\);if\(isCurrent\(\)&&button\)button\.disabled=false/);
});
