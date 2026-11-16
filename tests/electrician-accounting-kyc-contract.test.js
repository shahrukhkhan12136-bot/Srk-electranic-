const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve(__dirname, '..');
const electrician = fs.readFileSync(path.join(root, 'electrician.html'), 'utf8');

function body(name) {
  const start = electrician.indexOf('async function ' + name + '(');
  assert.ok(start >= 0, name + ' handler exists');
  const tail = electrician.slice(start + 1);
  const next = tail.search(/\n(?:async )?function\s+[A-Za-z0-9_$]+\s*\(/);
  return electrician.slice(start, next < 0 ? electrician.length : start + 1 + next);
}

test('KYC uploads enforce allowlisted document types, MIME types and 5 MB size cap', () => {
  const upload = body('uploadVerificationDocument');
  assert.match(upload, /identity_proof','address_proof','skill_certificate/);
  assert.match(upload, /KYC_MIME_TYPES\.includes\(file\.type\)/);
  assert.match(upload, /file\.size>5242880/);
  assert.match(upload, /upsert:false/);
  assert.match(upload, /srk_electrician_submit_verification_document/);
});

test('KYC document preview uses owner-scoped RPC and a short-lived signed URL', () => {
  const preview = body('openVerificationDocument');
  assert.match(preview, /srk_electrician_get_my_verification_document_path/);
  assert.match(preview, /createSignedUrl\(path,60/);
  assert.match(preview, /preview\.opener=null/);
  assert.match(preview, /preview\.location\.replace\(signed\.signedUrl\)/);
  assert.doesNotMatch(preview, /getPublicUrl/);
});

test('earnings and payout history failures are displayed separately, never as an empty payout balance', () => {
  const earnings = body('loadEarnings');
  assert.match(earnings, /srk_get_my_earnings/);
  assert.match(earnings, /srk_electrician_payouts/);
  assert.match(earnings, /if\(error\)[\s\S]*?कमाई का हिसाब अभी नहीं खुला/);
  assert.match(earnings, /payoutError\?[\s\S]*?पेआउट स्थिति लोड नहीं हुई/);
  assert.match(earnings, /eq\('electrician_profile_id',profile\.id\)/);
  assert.match(earnings, /utr|UTR/i);
});

test('wallet bank and ledger reads are owner scoped and query failures are not rendered as no records', () => {
  const wallet = body('loadPartnerWallet');
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
  const profile = body('saveElectricianDisplayName');
  assert.match(profile, /name\.length<2\|\|name\.length>80/);
  assert.match(profile, /srk_electrician_update_my_display_name/);
  assert.match(profile, /finally\{if\(isCurrent\(\)\)button\.disabled=false;\}/);
});


test('electrician profile name save reports refresh failure as partial success, not save failure', () => {
  const save = body('saveElectricianDisplayName');
  assert.match(save, /srk_electrician_update_my_display_name/);
  assert.match(save, /document\.getElementById\('name'\)\.textContent=data/);
  assert.match(save, /try\{await refresh\(\);?\}catch\(_\)\{if\(isCurrent\(\)\)msg\.textContent='प्रोफ़ाइल नाम अपडेट हो गया है, लेकिन Dashboard रीफ़्रेश नहीं हो सका। कृपया Refresh करें।'/);
  assert.ok(save.indexOf('msg.textContent=\'प्रोफ़ाइल नाम अपडेट हो गया।\'') < save.indexOf('try{await refresh();}catch'));
  assert.match(save, /finally\{if\(isCurrent\(\)\)button\.disabled=false;\}/);
});

test('electrician OTP login validates phone, applies resend cooldown and restores the send button', () => {
  const send = body('sendOtp');
  assert.match(send, /if\(otpBusy\)return/);
  assert.match(send, /normalizedPhone\(\)/);
  assert.match(send, /Date\.now\(\)<otpCooldownUntil/);
  assert.match(send, /sb\.auth\.signInWithOtp\(\{phone:p\}\)/);
  assert.match(send, /startOtpCooldown\(\)/);
  assert.match(send, /finally\{otpBusy=false/);
  assert.match(send, /btn\.disabled=false;btn\.textContent='OTP भेजें'/);
});

test('electrician OTP verification validates token and uses SMS phone verification', () => {
  const verify = body('verifyOtp');
  assert.match(verify, /normalizedPhone\(\)/);
  assert.match(verify, /4,8/);
  assert.match(verify, /token/);
  assert.match(verify, /sb\.auth\.verifyOtp\(\{phone:p,token,type:'sms'\}\)/);
  assert.match(verify, /finally\{otpBusy=false\}/);
  assert.match(verify, /OTP गलत या समाप्त हो गया है/);
});

test('electrician availability changes require approved active profile and explicit confirmation', () => {
  const availability = body('setElectricianAvailability');
  assert.match(availability, /!profile\|\|!profile\.active\|\|profile\.verification_status!=='approved'/);
  assert.match(availability, /if\(!confirm\(/);
  assert.match(availability, /srk_electrician_set_availability/);
  assert.match(availability, /p_available:available/);
  assert.match(availability, /await refresh\(\)/);
  assert.match(availability, /catch\(e\)[\s\S]*?on\.disabled=false;off\.disabled=false/);
});

test('electrician logout confirms server live-location stop before signing out', () => {
  const logout = body('logout');
  assert.match(logout, /locationWatches\.keys\(\)/);
  assert.match(logout, /srk_electrician_stop_live_location/);
  assert.match(logout, /Promise\.allSettled/);
  assert.match(logout, /if\(failedIndex>=0\)throw/);
  assert.ok(logout.indexOf('if(failedIndex>=0)throw') < logout.indexOf('sb.auth.signOut()'));
  assert.match(logout, /if\(error\)throw error/);
  assert.match(logout, /catch\(e\)[\s\S]*?electricianLogoutBusy=false/);
});


test('KYC uploads reject overlapping submissions and restore controls after completion', () => {
  const upload = body('uploadVerificationDocument');
  assert.match(electrician, /let electricianKycUploadBusy=false/);
  assert.match(upload, /if\(electricianKycUploadBusy\)/);
  assert.match(upload, /electricianKycUploadBusy=true/);
  assert.match(upload, /controls\.forEach\(control=>control\.disabled=true\)/);
  assert.match(upload, /previousDisabled\[index\]/);
  assert.match(upload, /finally\{[\s\S]*?electricianKycUploadBusy=false/);
});


test('electrician support ticket create reconciles uncertain writes against a preflight ticket snapshot and exact first message', () => {
  const create = body('createElectricianSupportTicket');
  assert.match(create, /srk_electrician_list_my_support_tickets/);
  assert.match(create, /previousTicketIds=new Set/);
  assert.match(create, /!previousTicketIds\.has\(row\.id\)/);
  assert.match(create, /srk_electrician_list_my_support_messages/);
  assert.match(create, /m\.sender_role==='electrician'&&m\.body===body/);
  assert.match(create, /डुप्लिकेट न बने/);
});

test('electrician support reply reconciles uncertain writes using preflight message IDs', () => {
  const reply = body('sendElectricianSupportReply');
  assert.match(reply, /srk_electrician_list_my_support_messages/);
  assert.match(reply, /previousMessageIds=new Set/);
  assert.match(reply, /!previousMessageIds\.has\(m\.id\)&&m\.sender_role==='electrician'&&m\.body===body/);
  assert.match(reply, /डुप्लिकेट संदेश न बने/);
  assert.match(reply, /electricianSupportReplyBusy=false/);
});


test('missing electrician profile removes the stale realtime offer subscription', () => {
  const refresh = body('refresh');
  const missingProfile = refresh.slice(refresh.indexOf('if(!p){'));
  assert.match(missingProfile, /if\(offersChannel\)\{const oldChannel=offersChannel;offersChannel=null;sb\.removeChannel\(oldChannel\);\}/);
  assert.ok(missingProfile.indexOf('sb.removeChannel(oldChannel)') < missingProfile.indexOf("document.getElementById('name').textContent='प्रोफाइल लिंक नहीं हुई'"));
});
