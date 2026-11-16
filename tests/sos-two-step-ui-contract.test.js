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
  for (const [app, source, prefix] of [['Customer', customer, 'customer'], ['Electrician', electrician, 'electrician']]) {
    const start = source.indexOf('<select id="' + prefix + 'SosReason_');
    const end = source.indexOf('</select>', start);
    assert.ok(start >= 0 && end > start, app + ' SOS reason selector exists');
    const select = source.slice(start, end);
    const values = [...select.matchAll(/<option value="([^"]*)"/g)].map(match => match[1]).filter(Boolean);
    assert.deepEqual(values, reasons, app + ' selector must expose exactly the three approved reasons');
  }
});

test('SOS requires a distinct final send action without an extra confirmation modal in both apps', () => {
  assert.match(customer, /id="customerSosSend_[\s\S]*?SOS भेजें/);
  assert.match(electrician, /id="electricianSosSend_[\s\S]*?SOS भेजें/);
  const customerStart = customer.indexOf('async function submitCustomerSosAlert(');
  const customerEnd = customer.indexOf('\n\n', customerStart);
  const electricianStart = electrician.indexOf('async function submitElectricianSosAlert(');
  const electricianEnd = electrician.indexOf('\n\n', electricianStart);
  assert.ok(customerStart >= 0 && customerEnd > customerStart);
  assert.ok(electricianStart >= 0 && electricianEnd > electricianStart);
  assert.doesNotMatch(customer.slice(customerStart, customerEnd), /if\(!confirm\(/);
  assert.doesNotMatch(electrician.slice(electricianStart, electricianEnd), /if\(!confirm\(/);
  assert.match(customer, /कारण चुनें। अलर्ट केवल “SOS भेजें” दबाने पर बनेगा।/);
  assert.match(electrician, /कारण चुनें। अलर्ट केवल “SOS भेजें” दबाने पर बनेगा।/);
});

test('Cancelling SOS selection discards the reason and never calls the backend', () => {
  for (const [app, source, handlerName] of [
    ['Customer', customer, 'cancelCustomerSosSelection'],
    ['Electrician', electrician, 'cancelElectricianSosSelection']
  ]) {
    const start = source.indexOf('function ' + handlerName + '(');
    const nextHandler = source.indexOf('document.addEventListener', start);
    assert.ok(start >= 0 && nextHandler > start, app + ' cancel handler exists');
    const handler = source.slice(start, nextHandler);
    assert.match(handler, /Reason_.*\.value=''/);
    assert.match(handler, /चयन रद्द किया गया; कोई अलर्ट नहीं भेजा गया।/);
    assert.doesNotMatch(handler, /\.rpc\(/, app + ' cancel handler must not call the SOS RPC');
  }
});

test('SOS client sends only the reason and never claims delivery without a confirmed case id', () => {
  for (const [app, source, handlerName, client, nextHandler] of [
    ['Customer', customer, 'submitCustomerSosAlert', 'customerSb', 'async function customerRespondWorkCompletion'],
    ['Electrician', electrician, 'submitElectricianSosAlert', 'sb', 'async function electricianRequestWorkStart']
  ]) {
    const start = source.indexOf('async function ' + handlerName + '(');
    const end = source.indexOf(nextHandler, start);
    assert.ok(start >= 0 && end > start, app + ' SOS submit handler exists');
    const handler = source.slice(start, end);
    assert.ok(handler.includes(client + ".rpc('srk_create_sos_alert',{p_reason:reason})"), app + ' RPC payload must contain only the selected reason');
    assert.match(handler, /!data\?\.success\|\|!data\?\.case_id/);
    assert.match(handler, /SOS अभी दर्ज नहीं हो सका। अलर्ट भेजा हुआ न मानें।/);
    assert.doesNotMatch(handler, /p_booking_id|p_user_id|p_actor_id/);
    if(app==='Customer'){
      assert.ok(handler.includes('requestedGeneration=customerActionGeneration'));
      assert.ok(handler.includes('customerSb.auth.getSession()'));
      assert.ok(handler.includes('if(!isCurrent())return'));
      assert.ok(handler.includes('finally{if(isCurrent())'));
      assert.ok(customer.includes('customerSosBusy.clear()'));
    }
  }
});
