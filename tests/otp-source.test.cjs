const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');

const pages = ['customer-login.html', 'booking.html'];

for (const file of pages) {
  test(file + ': OTP send and SMS verification calls remain present', () => {
    const html = fs.readFileSync(file, 'utf8');
    assert.match(html, /signInWithOtp\s*\(\s*\{\s*phone/);
    assert.match(html, /verifyOtp\s*\(\s*\{\s*phone\s*,\s*token\s*,\s*type\s*:\s*['\"]sms['\"]/);
  });
  test(file + ': client cooldown and duplicate-action guard remain present', () => {
    const html = fs.readFileSync(file, 'utf8');
    assert.match(html, /Date\.now\(\)\s*</);
    assert.match(html, /60000/);
    assert.match(html, /busy|Busy/);
  });
  test(file + ': OTP input remains numeric and bounded', () => {
    const html = fs.readFileSync(file, 'utf8');
    assert.ok(html.includes('4,8'), '4–8 digit validation must remain in source');
    assert.match(html, /maxlength=['\"]8['\"]/);
  });
  test(file + ': all inline JavaScript parses', () => {
    const html = fs.readFileSync(file, 'utf8');
    const scripts = [...html.matchAll(/<script\b([^>]*)>([\s\S]*?)<\/script>/gi)].filter(([, attrs]) => !/\bsrc\s*=/.test(attrs));
    assert.ok(scripts.length > 0, 'expected inline scripts');
    for (const [, , source] of scripts) if (source.trim()) new vm.Script(source, { filename: file });
  });
}

test('customer login logout guards missing client and restores button', () => {
  const html = fs.readFileSync('customer-login.html', 'utf8');
  assert.match(html, /!sb\s*\|\|\s*busy\s*\|\|\s*!logout/);
  assert.match(html, /auth\.signOut\(\)/);
  assert.match(html, /finally/);
});

test('booking logout handles signOut failure', () => {
  const html = fs.readFileSync('booking.html', 'utf8');
  assert.match(html, /auth\.signOut\(\)/);
  assert.match(html, /if\s*\(\s*error\s*\)\s*throw\s+error/);
  assert.match(html, /finally/);
});


test('standalone customer login keeps session and OTP cooldown controls consistent', () => {
  const html = fs.readFileSync('customer-login.html', 'utf8');
  assert.match(html, /let busy=false, resendAt=0, timer=null, hasSession=false/);
  assert.match(html, /hasSession=!!session/);
  assert.match(html, /send\.disabled=hasSession\s*\|\|\s*Date\.now\(\)<resendAt/);
  assert.match(html, /send\.disabled=hasSession\|\|left>0/);
  assert.match(html, /finally\{busy=false;verify\.disabled=hasSession;\}/);
  assert.match(html, /href="\/booking\.html#customer-dashboard"/);
});


test('OTP source workflow uses maintained Node 24 GitHub Actions runtimes', () => {
  const workflow = fs.readFileSync('.github/workflows/otp-source-tests.yml', 'utf8');
  assert.match(workflow, /uses:\s*actions\/checkout@v5/);
  assert.match(workflow, /uses:\s*actions\/setup-node@v5/);
  assert.match(workflow, /node-version:\s*24/);
  assert.doesNotMatch(workflow, /actions\/(?:checkout|setup-node)@v4/);
});


test('standalone customer OTP is bound to the phone that received it', () => {
  const html = fs.readFileSync('customer-login.html', 'utf8');
  assert.match(html, /pendingOtpPhone=phone/);
  assert.match(html, /phone!==pendingOtpPhone/);
  assert.match(html, /phoneInput\.addEventListener\('input'/);
  assert.match(html, /phoneE164\(\)!==phone/);
  assert.match(html, /pendingOtpPhone=null;otpInput\.value='';area\.classList\.add\('hidden'\)/);
});

test('embedded customer OTP is bound to the phone that received it', () => {
  const html = fs.readFileSync('booking.html', 'utf8');
  assert.match(html, /customerPendingOtpPhone = phone/);
  assert.match(html, /phone !== customerPendingOtpPhone/);
  assert.match(html, /customerPhoneE164\(\) !== phone/);
  assert.match(html, /customerPhone'\)\.addEventListener\('input'/);
  assert.match(html, /customerPendingOtpPhone = null/);
});


test('customer OTP send response and cleanup are bound to the same phone operation', () => {
  const html=fs.readFileSync('booking.html','utf8');
  const start=html.indexOf('async function customerSendOtp()');
  const end=html.indexOf('\nasync function customerVerifyOtp',start);
  const source=html.slice(start,end);
  assert.match(source,/const operation=\+\+customerOtpOperationSequence/);
  assert.match(source,/if\(operation!==customerOtpOperationSequence\|\|customerPhoneE164\(\)!==phone\)return/);
  assert.match(source,/finally \{ if\(operation===customerOtpOperationSequence\)/);
});
test('customer OTP verification locks phone identity and restores only its own controls', () => {
  const html=fs.readFileSync('booking.html','utf8');
  const start=html.indexOf('async function customerVerifyOtp()');
  const end=html.indexOf('\nasync function customerLogout',start);
  const source=html.slice(start,end);
  assert.match(source,/const operation=\+\+customerOtpOperationSequence/);
  assert.match(source,/phoneInput\.disabled=true/);
  assert.match(source,/finally \{ if\(operation===customerOtpOperationSequence\)/);
  assert.match(source,/phoneInput\.disabled=phoneWasDisabled/);
});
test('phone edits and logout invalidate pending OTP operations', () => {
  const html=fs.readFileSync('booking.html','utf8');
  assert.match(html,/\+\+customerOtpOperationSequence;customerPendingOtpPhone=null/);
  assert.match(html,/\+\+customerOtpOperationSequence;customerPendingOtpPhone = null/);
  assert.match(html,/\+\+customerOtpOperationSequence;customerOtpBusy=false;customerPendingOtpPhone=null/);
});


test('standalone customer login OTP actions are bound to phone and operation identity', () => {
 const html=fs.readFileSync('customer-login.html','utf8');
 assert.match(html,/operationSequence\+\+;pendingOtpPhone=null/);
 assert.match(html,/const operation=\+\+operationSequence;send\.disabled=true/);
 assert.match(html,/operation!==operationSequence\|\|phoneE164\(\)!==phone/);
 assert.match(html,/finally\{if\(operation===operationSequence\)\{busy=false;send\.disabled=hasSession\|\|Date\.now\(\)<resendAt;\}\}/);
 assert.match(html,/const phoneWasDisabled=phoneInput\.disabled;phoneInput\.disabled=true/);
 assert.match(html,/phoneInput\.disabled=phoneWasDisabled\|\|hasSession/);
});
