const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve(__dirname, '..');
const electrician = fs.readFileSync(path.join(root, 'electrician.html'), 'utf8');

function body(name, nextName) {
  const start = electrician.indexOf('async function ' + name + '(');
  const end = electrician.indexOf('\\nasync function ' + nextName + '(', start);
  assert.ok(start >= 0 && end > start, name + ' handler exists');
  return electrician.slice(start, end);
}

test('KYC uploads enforce allowlisted document types, MIME types and 5 MB size cap', () => {
  const upload = body('uploadVerificationDocument', 'loadEarnings');
  assert.match(upload, /identity_proof','address_proof','skill_certificate/);
  assert.match(upload, /KYC_MIME_TYPES\.includes\(file\.type\)/);
  assert.match(upload, /file\.size>5242880/);
  assert.match(upload, /upsert:false/);
  assert.match(upload, /srk_electrician_submit_verification_document/);
});

test('KYC document preview uses owner-scoped RPC and a short-lived signed URL', () => {
  const preview = body('openVerificationDocument', 'uploadVerificationDocument');
  assert.match(preview, /srk_electrician_get_my_verification_document_path/);
  assert.match(preview, /createSignedUrl\(path,60/);
  assert.match(preview, /preview\.opener=null/);
  assert.match(preview, /preview\.location\.replace\(signed\.signedUrl\)/);
  assert.doesNotMatch(preview, /getPublicUrl/);
});

test('earnings and payout history failures are displayed separately, never as an empty payout balance', () => {
  const earnings = body('loadEarnings', 'loadPartnerWallet');
  assert.match(earnings, /srk_get_my_earnings/);
  assert.match(earnings, /srk_electrician_payouts/);
  assert.match(earnings, /if\(error\)[\s\S]*?कमाई का हिसाब अभी नहीं खुला/);
  assert.match(earnings, /payoutError\?[\s\S]*?पेआउट स्थिति लोड नहीं हुई/);
  assert.match(earnings, /eq\('electrician_profile_id',profile\.id\)/);
  assert.match(earnings, /utr|UTR/i);
});

test('wallet bank and ledger reads are owner scoped and query failures are not rendered as no records', () => {
  const wallet = body('loadPartnerWallet', 'respond');
  assert.match(wallet, /srk_get_my_wallet_summary/);
  assert.match(wallet, /srk_wallet_bank_links/);
  assert.match(wallet, /srk_wallet_ledger/);
  assert.match(wallet, /eq\('user_id',user\.id\)/);
  assert.match(wallet, /bankResult\.error\?[\s\S]*?बैंक लिंक की स्थिति लोड नहीं हो सकी/);
  assert.match(wallet, /ledgerResult\.error\?[\s\S]*?वॉलेट लेन-देन सूची अभी उपलब्ध नहीं है/);
  assert.match(wallet, /यह ऐप का आंतरिक लेजर बैलेंस है/);
});

test('electrician app does not initiate wallet withdrawal or bank transfer actions', () => {
  assert.doesNotMatch(electrician, /srk_wallet_withdraw|srk_create_withdrawal|create_bank_transfer|razorpay_route_transfer/i);
  assert.match(electrician, /बैंक खाता जोड़ना और निकासी अभी बंद है/);
});

test('profile display-name updates validate input and use the self-service RPC', () => {
  const profile = body('saveElectricianDisplayName', 'loadElectricianPhoneChangeHistory');
  assert.match(profile, /name\.length<2\|\|name\.length>80/);
  assert.match(profile, /srk_electrician_update_my_display_name/);
  assert.match(profile, /finally\{button\.disabled=false\}/);
});
