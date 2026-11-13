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
    assert.match(html, /\\d\{4,8\}/);
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
