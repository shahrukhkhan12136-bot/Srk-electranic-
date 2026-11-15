const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve(__dirname, '..');
const customer = fs.readFileSync(path.join(root, 'booking.html'), 'utf8');
const electrician = fs.readFileSync(path.join(root, 'electrician.html'), 'utf8');

const reasons = [
  'customer_at_risk',
  'electrician_at_risk',
  'violence_or_other_emergency'
];

test('SOS controls are rendered only during an active work booking in both apps', () => {
  assert.match(customer, /row\.selected_category&&row\.status==='in_progress'[\s\S]*?customerSosPanel_/);
  assert.match(electrician, /o\.selected_category&&o\.booking_status==='in_progress'[\s\S]*?electricianSosPanel_/);
});

test('Customer and Electrician SOS UI expose only the three approved reason codes', () => {
  for (const [app, source] of [['Customer', customer], ['Electrician', electrician]]) {
    for (const reason of reasons) {
      assert.ok(source.includes('value="' + reason + '"'), app + ' UI is missing ' + reason);
    }
    assert.doesNotMatch(source, /value="(?:other|medical_emergency|police_help|accident)"/);
  }
});

test('SOS requires a distinct final send action and explicit confirmation in both apps', () => {
  assert.match(customer, /id="customerSosSend_[\s\S]*?SOS भेजें/);
  assert.match(electrician, /id="electricianSosSend_[\s\S]*?SOS भेजें/);
  assert.match(customer, /async function submitCustomerSosAlert\([\s\S]*?if\(!confirm\(/);
  assert.match(electrician, /async function submitElectricianSosAlert\([\s\S]*?if\(!confirm\(/);
  assert.match(customer, /कारण चुनें। अलर्ट केवल “SOS भेजें” दबाने पर बनेगा।/);
  assert.match(electrician, /कारण चुनें। अलर्ट केवल “SOS भेजें” दबाने पर बनेगा।/);
});

test('Cancelling SOS selection discards the reason and never calls the backend', () => {
  const customerCancel = customer.match(/function cancelCustomerSosSelection\([\s\S]*?\n\}/);
  const electricianCancel = electrician.match(/function cancelElectricianSosSelection\([\s\S]*?\n\}/);
  assert.ok(customerCancel && electricianCancel);
  for (const [app, handler] of [['Customer', customerCancel[0]], ['Electrician', electricianCancel[0]]]) {
    assert.match(handler, /Reason_.*\.value=''/);
    assert.match(handler, /चयन रद्द किया गया; कोई अलर्ट नहीं भेजा गया।/);
    assert.doesNotMatch(handler, /\.rpc\(/, app + ' cancel handler must not call the SOS RPC');
  }
});

test('SOS client sends only the reason and never claims delivery without a confirmed case id', () => {
  for (const [app, source, handlerName, client] of [
    ['Customer', customer, 'submitCustomerSosAlert', 'customerSb'],
    ['Electrician', electrician, 'submitElectricianSosAlert', 'sb']
  ]) {
    const start = source.indexOf('async function ' + handlerName + '(');
    const end = source.indexOf('\n}', start);
    assert.ok(start >= 0 && end > start, app + ' SOS submit handler exists');
    const handler = source.slice(start, end);
    assert.match(handler, new RegExp(client + '\\.rpc\\(\\'srk_create_sos_alert\\',\\{p_reason:reason\\}\\)'));
    assert.match(handler, /!data\?\.success\|\|!data\?\.case_id/);
    assert.match(handler, /SOS अभी दर्ज नहीं हो सका। अलर्ट भेजा हुआ न मानें।/);
    assert.doesNotMatch(handler, /p_booking_id|p_user_id|p_actor_id/);
  }
});
