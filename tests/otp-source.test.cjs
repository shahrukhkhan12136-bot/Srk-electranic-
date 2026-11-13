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
