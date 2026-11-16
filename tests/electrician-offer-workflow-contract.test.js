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
  assert.match(respond, /buttons\.forEach\(\(b,i\)=>\{b\.disabled=false/);
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
  assert.match(start, /electricianLifecycleBusy\.has\(bookingId\)/);
  assert.match(start, /srk_electrician_request_work_start/);
  assert.match(start, /data\?\.success/);
  assert.match(complete, /electricianLifecycleBusy\.has\(bookingId\)/);
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
  assert.match(availability, /!profile\|\|!profile\.active\|\|profile\.verification_status!=='approved'/);
  assert.match(availability, /if\(!confirm\(/);
  assert.match(availability, /srk_electrician_set_availability/);
  assert.match(availability, /p_available:available/);
  assert.match(availability, /await refresh\(\)/);
});
