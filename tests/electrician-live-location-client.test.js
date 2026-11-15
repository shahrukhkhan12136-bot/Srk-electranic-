const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve(__dirname, '..');
const electrician = fs.readFileSync(path.join(root, 'electrician.html'), 'utf8');

test('GPS update failure stops server-side live location sharing', () => {
  assert.match(electrician, /async function stopElectricianLiveLocationAfterGpsFailure\(/);
  assert.match(electrician, /srk_electrician_stop_live_location/);
  assert.match(electrician, /if\(r\.error\)throw r\.error/);
  assert.match(electrician, /catch\(error\)[\s\S]*?await stopElectricianLiveLocationAfterGpsFailure/);
});

test('GPS permission or signal error also requests server-side stop', () => {
  assert.match(electrician, /stopElectricianLiveLocationAfterGpsFailure\(id,watch,status,'GPS सिग्नल उपलब्ध नहीं है।'\)/);
});

test('GPS failure and manual stop share one in-flight guard', () => {
  assert.match(electrician, /const electricianLocationStopBusy=new Set\(\)/);
  const helper = electrician.match(/async function stopElectricianLiveLocationAfterGpsFailure\([\s\S]*?\n\}/);
  const manual = electrician.match(/async function stopElectricianLiveLocation\([\s\S]*?\n\}/);
  assert.ok(helper && manual, 'both GPS failure and manual stop handlers exist');
  assert.match(helper[0], /electricianLocationStopBusy\.has\(id\)/);
  assert.match(helper[0], /electricianLocationStopBusy\.add\(id\)/);
  assert.match(helper[0], /finally[\s\S]*?electricianLocationStopBusy\.delete\(id\)/);
  assert.match(manual[0], /electricianLocationStopBusy\.has\(id\)/);
});

test('failed stop retains the booking in the logout retry set', () => {
  const helper = electrician.match(/async function stopElectricianLiveLocationAfterGpsFailure\([\s\S]*?\nasync function startElectricianLiveLocation/);
  assert.ok(helper, 'live location stop helper exists');
  assert.match(helper[0], /locationWatches\.delete\(id\)/);
  assert.match(helper[0], /catch\(e\)[\s\S]*?सर्वर पर sharing बंद होने की पुष्टि नहीं हुई/);
  assert.ok(!/catch\(e\)[\s\S]*?locationWatches\.delete\(id\)/.test(helper[0]));
});


test('push permission is requested directly from the enable-button gesture before async account validation', () => {
  const start = electrician.indexOf('async function enableElectricianPushNotifications()');
  const end = electrician.indexOf('async function disableElectricianPushNotifications()', start);
  assert.ok(start >= 0 && end > start, 'push enable handler exists');
  const handler = electrician.slice(start, end);
  const permission = handler.indexOf('Notification.requestPermission()');
  const accountCheck = handler.indexOf('await getElectricianPushContext()');
  assert.ok(permission >= 0 && accountCheck > permission, 'browser permission request precedes async Supabase/account validation');
  assert.ok(handler.indexOf('button.disabled=true') < permission, 'prevent duplicate enable clicks before requesting permission');
});

test('push notification click opens the exact offer using a validated same-origin route', () => {
  const worker = fs.readFileSync(path.join(root, 'sw.js'), 'utf8');
  assert.match(worker, /const CACHE='srk-electronic-v11'/);
  assert.match(worker, /const target=new URL\('\.\/electrician\.html',self\.registration\.scope\)/);
  assert.match(worker, /target\.searchParams\.set\('offerId',offerId\)/);
  assert.match(worker, /const offerId=event\.notification\.data\?\.offerId/);
  assert.doesNotMatch(worker, /new URL\(raw,self\.location\.origin\)/);
});


test('live location start is guarded against duplicate in-flight requests', () => {
  assert.match(electrician, /const electricianLocationStartBusy=new Set\\(\\)/);
  const start = electrician.match(/async function startElectricianLiveLocation\\(id\\)\\{[\\s\\S]*?\\n\\}/);
  assert.ok(start, 'live location start handler exists');
  assert.match(start[0], /electricianLocationStartBusy\\.has\\(id\\)/);
  assert.match(start[0], /electricianLocationStartBusy\\.add\\(id\\)/);
  assert.match(start[0], /finally[\\s\\S]*?electricianLocationStartBusy\\.delete\\(id\\)/);
  assert.match(start[0], /if\\(locationWatches\\.has\\(id\\)\\)/);
});

test('live location start failure after server activation attempts server-side cleanup', () => {
  const start = electrician.match(/async function startElectricianLiveLocation\\(id\\)\\{[\\s\\S]*?\\n\\}/);
  assert.ok(start, 'live location start handler exists');
  assert.match(start[0], /serverStarted=true/);
  assert.match(start[0], /if\\(serverStarted\\)[\\s\\S]*?srk_electrician_stop_live_location/);
  assert.match(start[0], /सर्वर पर sharing बंद होने की पुष्टि नहीं हुई/);
});
