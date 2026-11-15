const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve(__dirname, '..');
const customer = fs.readFileSync(path.join(root, 'customer-login.html'), 'utf8');
const booking = fs.readFileSync(path.join(root, 'booking.html'), 'utf8');
const electrician = fs.readFileSync(path.join(root, 'electrician.html'), 'utf8');

test('customer OTP login normalizes Indian numbers and verifies SMS OTP before dashboard redirect', () => {
  assert.match(customer, /if\\(d\\.length===10\\)return '\\+91'\\+d/);
  assert.match(customer, /sb\\.auth\\.signInWithOtp\\(\\{phone\\}\\)/);
  assert.match(customer, /sb\\.auth\\.verifyOtp\\(\\{phone,token,type:'sms'\\}\\)/);
  assert.ok(customer.includes("window.location.replace('/booking.html')"));
  assert.match(customer, /resendAt=Date\\.now\\(\\)\\+60000/);
  assert.ok(customer.includes('busy)return'));
});

test('customer booking dashboard remains hidden until a valid session is present', () => {
  assert.match(booking, /id="customer-dashboard"[^>]*style="display:none"/);
  assert.match(booking, /customerSb\\.auth\\.getSession\\(\\)/);
  assert.match(booking, /customerSb\\.auth\\.onAuthStateChange/);
});

test('electrician portal uses OTP login, a resend cooldown, and session-driven portal visibility', () => {
  assert.match(electrician, /sb\\.auth\\.signInWithOtp\\(\\{phone:p\\}\\)/);
  assert.match(electrician, /sb\\.auth\\.verifyOtp\\(\\{phone:p,token,type:'sms'\\}\\)/);
  assert.match(electrician, /otpCooldownUntil=Date\\.now\\(\\)\\+60000/);
  assert.match(electrician, /sb\\.auth\\.onAuthStateChange/);
  assert.match(electrician, /function show\\(\\)\\{document\\.getElementById\\('login'\\)[\\s\\S]*document\\.getElementById\\('app'\\)/);
});
