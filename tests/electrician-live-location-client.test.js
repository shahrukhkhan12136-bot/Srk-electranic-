const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve(__dirname, '..');
const electrician = fs.readFileSync(path.join(root, 'electrician.html'), 'utf8');

test('GPS update failure stops server-side live location sharing', () => {
  assert.match(electrician, /async function stopElectricianLiveLocationAfterGpsFailure\(/);
  assert.match(electrician, /srk_electrician_stop_live_location/);
  assert.match(electrician, /if\(r\.error\)await stopElectricianLiveLocationAfterGpsFailure/);
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
