const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve(__dirname, '..');
const customer = fs.readFileSync(path.join(root, 'customer-login.html'), 'utf8');
const booking = fs.readFileSync(path.join(root, 'booking.html'), 'utf8');
const electrician = fs.readFileSync(path.join(root, 'electrician.html'), 'utf8');

test('customer OTP login normalizes Indian numbers and verifies SMS OTP before dashboard redirect', () => {
  assert.ok(customer.includes("if(d.length===10)return '+91'+d"));
  assert.ok(customer.includes("if(raw.startsWith('+91')&&d.length===12&&d.startsWith('91'))return '+91'+d"));
  assert.ok(!customer.includes("d.length>=10&&d.length<=15"), 'non-Indian international numbers are not accepted by this India-only booking flow');
  assert.ok(customer.includes('sb.auth.signInWithOtp({phone})'));
  assert.ok(customer.includes("sb.auth.verifyOtp({phone,token,type:'sms'})"));
  assert.ok(customer.includes("window.location.replace('/booking.html')"));
  assert.ok(customer.includes('resendAt=Date.now()+60000'));
  assert.ok(customer.includes('if(busy)return'));
});

test('customer booking dashboard remains hidden until a valid session is present', () => {
  assert.ok(booking.includes('id="customer-dashboard"'));
  assert.ok(booking.includes('style="display:none"'));
  assert.ok(booking.includes('customerSb.auth.getSession()'));
  assert.ok(booking.includes('customerSb.auth.onAuthStateChange'));
});

test('electrician portal uses OTP login, a resend cooldown, and session-driven portal visibility', () => {
  assert.ok(electrician.includes('sb.auth.signInWithOtp({phone:p})'));
  assert.ok(electrician.includes("sb.auth.verifyOtp({phone:p,token,type:'sms'})"));
  assert.ok(electrician.includes('otpCooldownUntil=Date.now()+60000'));
  assert.ok(electrician.includes('sb.auth.onAuthStateChange'));
  assert.ok(electrician.includes("function show(){document.getElementById('login')"));
  assert.ok(electrician.includes("document.getElementById('app').classList.toggle('hidden',!user)"));
});
