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
  assert.match(electrician, /catch\(error\)[\\s\\S]*?await stopElectricianLiveLocationAfterGpsFailure/);
});

test('GPS permission or signal error also requests server-side stop', () => {
  assert.match(electrician, /stopElectricianLiveLocationAfterGpsFailure\(id,watch,status,'GPS सिग्नल उपलब्ध नहीं है।'\)/);
});

test('failed stop retains the booking in the logout retry set', () => {
  const helper = electrician.match(/async function stopElectricianLiveLocationAfterGpsFailure\([\s\S]*?\nasync function startElectricianLiveLocation/);
  assert.ok(helper, 'live location stop helper exists');
  assert.match(helper[0], /locationWatches\.delete\(id\)/);
  assert.match(helper[0], /catch\(e\)[\s\S]*?सर्वर पर sharing बंद होने की पुष्टि नहीं हुई/);
  assert.ok(!/catch\(e\)[\s\S]*?locationWatches\.delete\(id\)/.test(helper[0]));
});


test('push notification click opens the exact offer using a validated same-origin route', () => {
  const worker = fs.readFileSync(path.join(root, 'sw.js'), 'utf8');
  assert.match(worker, /const CACHE='srk-electronic-v8'/);
  assert.match(worker, /const target=new URL\('\.\/electrician\.html',self\.registration\.scope\)/);
  assert.match(worker, /target\.searchParams\.set\('offerId',offerId\)/);
  assert.match(worker, /const offerId=event\.notification\.data\?\.offerId/);
  assert.doesNotMatch(worker, /new URL\(raw,self\.location\.origin\)/);
});
