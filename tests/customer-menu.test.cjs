const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');

const html = fs.readFileSync('booking.html', 'utf8');
const bookingApi = fs.readFileSync('create-booking.js', 'utf8');
const labourBilling = require('../lib/labour-billing');
const profileMigration = fs.readFileSync('supabase/migrations/20261113200000_customer_profile_api_and_avatar_security.sql', 'utf8');
const supportAttachmentMigration = fs.readFileSync('supabase/migrations/20261114170000_harden_customer_support_attachment_object_integrity.sql', 'utf8');
const customerReceiptMigration = fs.readFileSync('supabase/migrations/20261114190000_customer_receipt_immutable_labour_amount.sql', 'utf8');
const customerPaymentHistoryMigration = fs.readFileSync('supabase/migrations/20261114200000_customer_payment_refund_history_rpc.sql', 'utf8');
const customerCallContactsMigration = fs.readFileSync('supabase/migrations/20261114220000_customer_contacts_after_completion.sql', 'utf8');

test('accepted customer-electrician direct contact remains available after completion', () => {
  assert.ok(customerCallContactsMigration.includes("'completed'"));
  assert.ok(customerCallContactsMigration.includes("b.customer_user_id = v_uid"));
  assert.ok(customerCallContactsMigration.includes("b.assigned_electrician_id is not null"));
  assert.ok(html.includes("customerEsc(phone) + '</p><a class=\"btn call\" href=\"tel:' + phone"));
  assert.ok(!html.includes('इलेक्ट्रिशियन का मोबाइल नंबर अब प्रदर्शित नहीं होगा'));
});

test('customer online payment preference change is guarded against duplicate submissions and reports refresh separately', () => {
  const start = html.indexOf('const customerPaymentMethodChangeBusy=new Set();');
  const end = html.indexOf('function setCustomerProfileStatus', start);
  assert.ok(start >= 0 && end > start);
  const handler = html.slice(start, end);
  assert.ok(handler.includes('customerPaymentMethodChangeBusy.has(id)'));
  assert.ok(handler.includes('customerPaymentMethodChangeBusy.add(id)'));
  assert.ok(handler.includes('customerPaymentMethodChangeBusy.delete(id)'));
  assert.ok(handler.includes('button.disabled=true'));
  assert.ok(handler.includes("srk_customer_change_payment_method"));
  assert.ok(handler.includes('saved=true'));
  assert.ok(handler.includes('बुकिंग सूची रीफ़्रेश नहीं हो सकी'));
  assert.ok(html.includes('id="customerChangePayment_'+ "'+customerEsc(row.id)+'" +''));
});

test('customer menu keeps the approved five-menu order and accessible tab controls', () => {
  const nav = html.match(/<nav class="customer-menu-nav"[\s\S]*?<\/nav>/)?.[0] || '';
  const names = [...nav.matchAll(/data-customer-menu="([^"]+)"/g)].map(match => match[1]);
  assert.deepEqual(names, ['Home', 'Bookings', 'Payments', 'Support', 'Profile']);
  assert.match(nav, /aria-label="ग्राहक मुख्य मेनू"/);
  assert.match(nav, /role="tablist"/);
  assert.equal((nav.match(/role="tab"/g) || []).length, 5);
});

test('each customer menu has exactly one matching tab panel', () => {
  for (const key of ['Home', 'Bookings', 'Payments', 'Support', 'Profile']) {
    assert.equal((html.match(new RegExp('id="customerMenu' + key + '"', 'g')) || []).length, 1);
    assert.equal((html.match(new RegExp('data-customer-menu="' + key + '"', 'g')) || []).length, 1);
  }
  assert.match(html, /function activate\(name,focus=false\)/);
  assert.match(html, /panel\.hidden=key!==name/);
  assert.match(html, /event\.key==='ArrowRight'/);
  assert.match(html, /event\.key==='ArrowLeft'/);
});

test('support and profile functions are mounted inside their respective menu panels', () => {
  assert.match(html, /Support:document\.getElementById\('customerSupportPanel'\)/);
  assert.match(html, /Profile:document\.getElementById\('customerProfilePanel'\)/);
  assert.match(html, /target\.appendChild\(node\)/);
  assert.match(html, /customerSupportCreate.*createCustomerSupportComplaint/s);
  assert.match(html, /customerSupportSend.*sendCustomerSupportMessage/s);
  assert.match(html, /saveCustomerProfile.*saveCustomerProfile/s);
});

test('customer menu actions lead to the existing booking and saved-address controls', () => {
  assert.match(html, /customerHomeBookNow[\s\S]*?getElementById\('booking'\)[\s\S]*?scrollIntoView/);
  assert.match(html, /customerProfileAddressLink[\s\S]*?getElementById\('savedAddressSelect'\)[\s\S]*?focus/);
  assert.match(html, /customerRefresh[\s\S]*?loadCustomerBookings/);
  assert.match(html, /customerPaymentHistoryRefresh[\s\S]*?loadCustomerPaymentHistory\(true\)/);
  assert.match(html, /customerSupportRefresh[\s\S]*?loadCustomerSupportBookings/);
});

test('customer payment menu only reads verified history and receipt through customer RPCs', () => {
  assert.match(html, /srk_customer_get_payment_history/);
  assert.match(html, /srk_customer_get_payment_receipt/);
  assert.match(html, /data\.document_type!=='payment_receipt'/);
  assert.match(html, /यह टैक्स इनवॉइस नहीं है/);
});


test('support booking selector is populated from only the signed-in customer bookings', () => {
  assert.match(html, /async function loadCustomerSupportBookings\(reset=true\)/);
  assert.match(html, /\.eq\('customer_user_id',session\.user\.id\)/);
  assert.match(html, /customerSupportBooking/);
  assert.match(html, /\.range\(requestedOffset,requestedOffset\+24\)/);
});

test('new customer complaint is validated and created through the ownership-checking RPC', () => {
  assert.match(html, /async function createCustomerSupportComplaint\(\)/);
  assert.match(html, /customerSupportComplaintCreateBusy/);
  assert.match(html, /description\.length<20\|\|description\.length>2000/);
  assert.match(html, /srk_customer_create_booking_complaint/);
  assert.match(html, /p_booking_id:bookingId,p_category:category,p_description:description/);
  assert.match(html, /COMPLAINT_DAILY_LIMIT_REACHED/);
  assert.match(html, /await loadCustomerSupportComplaints\(\)/);
  assert.match(html, /await loadCustomerSupportMessages\(\)/);
});


test('customer profile reads and writes only through validated owner-scoped RPCs', () => {
  assert.match(html, /customerSb\.rpc\('srk_customer_get_my_profile'/);
  assert.match(html, /customerSb\.rpc\('srk_customer_update_my_profile'/);
  assert.match(profileMigration, /revoke all on public\.srk_customer_profiles from anon, authenticated/);
  assert.doesNotMatch(profileMigration, /grant\s+(?:select|insert|update|all)[^;]*srk_customer_profiles\s+to\s+authenticated/i);
  assert.match(profileMigration, /where p\.user_id=v_user_id/);
  assert.match(profileMigration, /length\(v_name\) < 2 or length\(v_name\) > 120/);
  assert.match(profileMigration, /u\.phone_confirmed_at is not null/);
});


test('support thread selection ignores stale async responses and blocks duplicate sends', () => {
  assert.match(html, /let customerSupportThreadLoadSequence=0/);
  assert.match(html, /const sequence=\+\+customerSupportThreadLoadSequence/);
  assert.match(html, /sequence!==customerSupportThreadLoadSequence\|\|document\.getElementById\('customerSupportComplaint'\)\.value!==id/);
  assert.match(html, /let customerSupportMessageBusy=false/);
  assert.match(html, /if\(customerSupportMessageBusy\)return/);
  assert.match(html, /customerSupportMessageBusy=true;button\.disabled=true/);
  assert.match(html, /finally\{customerSupportMessageBusy=false;button\.disabled=false/);
  assert.match(html, /कुछ संलग्न फ़ाइलें अभी लोड नहीं हो सकीं/);
});


test('support attachment metadata must match stored object and linked files cannot be customer-deleted', () => {
  assert.match(supportAttachmentMigration, /metadata->>'mimetype'/);
  assert.match(supportAttachmentMigration, /metadata->>'size'/);
  assert.match(supportAttachmentMigration, /ATTACHMENT_OBJECT_METADATA_MISMATCH/);
  assert.match(supportAttachmentMigration, /\[0-9a-fA-F-\]\{36\}\\\./);
  assert.match(supportAttachmentMigration, /customer deletes only unlinked support attachments/);
  assert.match(supportAttachmentMigration, /not exists\s*\([\s\S]*?srk_booking_complaint_message_attachments/);
});


test('customer booking history reports partial RPC and labour-bill failures without hiding booking data', () => {
  assert.match(html, /let customerBookingHistoryLoadSequence=0/);
  assert.match(html, /const sequence=\+\+customerBookingHistoryLoadSequence/);
  assert.match(html, /if\(sequence!==customerBookingHistoryLoadSequence\)return/);
  assert.match(html, /if\(contactsResult\.error\)partialWarnings\.push/);
  assert.match(html, /if\(timelineResult\.error\)partialWarnings\.push/);
  assert.match(html, /if\(refundResult\.error\)partialWarnings\.push/);
  assert.match(html, /if\(error\)billLoadFailures\+\+/);
  assert.match(html, /कुछ पूरी हुई बुकिंग के अंतिम Labour Bill अभी लोड नहीं हो सके/);
  assert.match(html, /let customerBookingHistoryOffset=0/);
  assert.match(html, /let customerBookingHistoryBusy=false/);
  assert.match(html, /async function loadCustomerBookings\(reset=true\)/);
  assert.ok(html.includes('id="customerBookingHistoryMore"'));
  assert.match(html, /\.range\(requestedOffset,requestedOffset\+24\)/);
  assert.match(html, /customerBookingHistoryOffset=requestedOffset\+data\.length/);
  assert.match(html, /if\(reset\)box\.innerHTML=cardsHtml;else box\.insertAdjacentHTML\('beforeend',cardsHtml\)/);
  assert.match(html, /if\(sequence===customerBookingHistoryLoadSequence\)\{customerBookingHistoryBusy=false;box\.setAttribute\('aria-busy','false'\)/);
  assert.match(html, /पहले से दिख रही बुकिंग सुरक्षित हैं/);
});


test('customer avatar lifecycle keeps profile save separate from preview and cleanup outcomes', () => {
  assert.match(html, /async function loadCustomerAvatar\(path,shouldApply=\(\)=>true\)[\s\S]*?return true;[\s\S]*?return false;/);
  assert.match(html, /if\(!window\.crypto\?\.randomUUID\)throw new Error/);
  assert.match(html, /let uploadedAvatarPath=null/);
  assert.match(html, /let uploadCleanupFailed=false/);
  assert.match(html, /if\(cleanup\.error\)uploadCleanupFailed=true/);
  assert.match(html, /uploadCleanupFailed\?' नई अपलोड फोटो की सफाई पूरी नहीं हुई/);
  assert.match(html, /if\(cleanup\.error\)cleanupWarning=/);
  assert.match(html, /प्रोफ़ाइल सफलतापूर्वक सेव हो गई।'.*previewLoaded/s);
  assert.match(html, /प्रोफ़ाइल सफलतापूर्वक सेव हो गई।'.*cleanupWarning/s);
  assert.ok(html.includes('const avatarPath=customerCurrentAvatarPath;') && html.includes('const avatarLoaded=avatarPath?await loadCustomerAvatar(avatarPath,()=>sequence===customerProfileLoadSequence&&customerCurrentAvatarPath===avatarPath):true;') && html.includes('if(sequence!==customerProfileLoadSequence)return;'));
  assert.match(html, /if\(!customerCurrentAvatarPath\)setCustomerAvatarPreview\(''\)/);
  assert.match(html, /const \{data:sessionData,error:sessionError\}=await customerSb\.auth\.getSession\(\)/);
  assert.match(html, /फोटो का पूर्वावलोकन अभी उपलब्ध नहीं है/);
});


test('customer payment and refund history refreshes safely and only verified payment rows offer receipts', () => {
  assert.match(html, /let customerPaymentHistoryLoadSequence=0/);
  assert.match(html, /const sequence=\+\+customerPaymentHistoryLoadSequence/);
  assert.match(html, /if\(sequence!==customerPaymentHistoryLoadSequence\)return/);
  assert.match(html, /if\(sequence===customerPaymentHistoryLoadSequence\)\{[\s\S]*?box\.setAttribute\('aria-busy','false'\)/);
  assert.match(html, /let customerRefundHistoryLoadSequence=0/);
  assert.match(html, /const sequence=\+\+customerRefundHistoryLoadSequence/);
  assert.match(html, /if\(sequence!==customerRefundHistoryLoadSequence\)return/);
  assert.match(html, /if\(sequence===customerRefundHistoryLoadSequence\)\{[\s\S]*?box\.setAttribute\('aria-busy','false'\)/);
  assert.match(html, /row\.event_type==='payment'&&row\.status==='paid'&&row\.booking_id/);
  assert.match(html, /if\(reset\)\{customerPaymentHistoryOffset=0;more\.style\.display='none';box\.textContent=/);
  assert.match(html, /const \{data:sessionData,error:sessionError\}=await customerSb\.auth\.getSession\(\)/);
});


test('customer payment history pagination prevents duplicate loads and restores controls only for latest request', () => {
  const start=html.indexOf('async function loadCustomerPaymentHistory(reset=true)');
  const end=html.indexOf('let customerRefundHistoryLoadSequence',start);
  const source=html.slice(start,end);
  assert.match(source,/if\(!customerSb\|\|\(!reset&&customerPaymentHistoryBusy\)\)return/);
  assert.ok(source.includes('customerPaymentHistoryBusy=true;')&&source.includes('more.disabled=true;')&&source.includes('refresh.disabled=true;'));
  assert.ok(source.includes('customerPaymentHistoryBusy=false;')&&source.includes('more.disabled=false;')&&source.includes('refresh.disabled=false;'));
  assert.match(source,/customerPaymentHistoryOffset=requestedOffset\+rows\.length/);
  assert.match(source,/if\(sequence!==customerPaymentHistoryLoadSequence\)return/);
  assert.ok(source.includes('data-payment-history-load-warning'));
  assert.ok(source.includes('पहले से दिख रहे रिकॉर्ड सुरक्षित हैं'));
});


test('customer avatar signed-url responses cannot overwrite a newer profile selection', () => {
  assert.match(html,/async function loadCustomerAvatar\(path,shouldApply=\(\)=>true\)/);
  const start=html.indexOf('async function loadCustomerAvatar(path,shouldApply=()=>true)');
  const end=html.indexOf('let customerProfileLoadSequence',start);
  const source=html.slice(start,end);
  assert.match(source,/if\(!shouldApply\(\)\)return false/);
  assert.match(source,/if\(shouldApply\(\)\)setCustomerAvatarPreview\(''\)/);
  assert.match(html,/loadCustomerAvatar\(avatarPath,\(\)=>sequence===customerProfileLoadSequence&&customerCurrentAvatarPath===avatarPath\)/);
});


test('customer work start and completion responses reject duplicate submissions and always release guards', () => {
  assert.match(html,/let customerWorkCompletionResponseBusy=new Set\(\)/);
  const completionStart=html.indexOf('async function customerRespondWorkCompletion(bookingId,response)');
  const completionEnd=html.indexOf('let customerRefundSubmissionBusy',completionStart);
  const completion=html.slice(completionStart,completionEnd);
  assert.match(completion,/customerWorkCompletionResponseBusy\.has\(bookingId\)/);
  assert.ok(completion.indexOf("if(!confirm(messages[response]")<completion.indexOf('customerWorkCompletionResponseBusy.add(bookingId)'));
  assert.match(completion,/finally\{customerWorkCompletionResponseBusy\.delete\(bookingId\);\}/);
  assert.match(html,/let customerWorkStartResponseBusy=new Set\(\)/);
  const start=html.indexOf('async function customerRespondWorkStart(bookingId,response)');
  const end=html.indexOf('function formatCustomerTimer',start);
  const source=html.slice(start,end);
  assert.match(source,/customerWorkStartResponseBusy\.has\(bookingId\)/);
  assert.match(source,/customerWorkStartResponseBusy\.add\(bookingId\)/);
  assert.match(source,/finally\{customerWorkStartResponseBusy\.delete\(bookingId\);\}/);
  assert.ok(source.includes('let responseConfirmed=false;'));
  assert.ok(source.includes('responseConfirmed=true;'));
  assert.ok(source.includes('जवाब सर्वर पर दर्ज हो गया है'));
  assert.ok(source.includes('जवाब दोबारा न भेजें'));
});


test('customer history retries clear stale warnings and invalid payment timestamps render safely', () => {
  const paymentStart=html.indexOf('async function loadCustomerPaymentHistory(reset=true)');
  const paymentEnd=html.indexOf('let customerRefundHistoryLoadSequence',paymentStart);
  const payment=html.slice(paymentStart,paymentEnd);
  assert.match(payment,/const dateValue=row\.occurred_at\?new Date\(row\.occurred_at\):null/);
  assert.match(payment,/!Number\.isNaN\(dateValue\.getTime\(\)\)/);
  assert.match(payment,/box\.querySelector\('\[data-payment-history-load-warning\]'\)\?\.remove\(\)/);
  const refundStart=html.indexOf('async function loadCustomerRefundHistory(reset=true)');
  const refundEnd=html.indexOf('const customerBookingStatusLabels',refundStart);
  assert.match(html.slice(refundStart,refundEnd),/box\.querySelector\('\[data-refund-history-load-warning\]'\)\?\.remove\(\)/);
  const bookingStart=html.indexOf('async function loadCustomerBookings(reset=true)');
  const bookingEnd=html.indexOf('async function customerRespondWorkStart',bookingStart);
  assert.match(html.slice(bookingStart,bookingEnd),/box\.querySelector\('\[data-booking-history-load-warning\]'\)\?\.remove\(\)/);
});


test('customer refund history pagination prevents duplicate loads and uses bounded paginated RPC', () => {
  assert.ok(html.includes('id="customerRefundHistoryMore"'));
  const start=html.indexOf('async function loadCustomerRefundHistory(reset=true)');
  const end=html.indexOf('const customerBookingStatusLabels',start);
  const source=html.slice(start,end);
  assert.ok(source.includes('if(!customerSb||(!reset&&customerRefundHistoryBusy))return;'));
  assert.ok(source.includes('customerRefundHistoryBusy=true;')&&source.includes('more.disabled=true;'));
  assert.ok(source.includes('customerRefundHistoryBusy=false;')&&source.includes('more.disabled=false;'));
  assert.ok(source.includes('p_limit:25,p_offset:requestedOffset'));
  assert.ok(source.includes('customerRefundHistoryOffset=requestedOffset+rows.length;'));
  assert.ok(source.includes('if(sequence!==customerRefundHistoryLoadSequence)return;'));
  assert.ok(source.includes('else{let note=box.querySelector(\'[data-refund-history-load-warning]\')'));
  assert.ok(source.includes('पहले से दिख रहे रिकॉर्ड सुरक्षित हैं'));
});

test('customer payment receipt uses immutable labour amount and never infers materials', () => {
  assert.match(customerReceiptMigration, /srk_booking_labour_bills/);
  assert.match(customerReceiptMigration, /labour_amount_paise = round\(v_booking\.amount_paid \* 100\)::bigint/);
  assert.match(customerReceiptMigration, /elsif not v_has_bill/);
  assert.match(customerReceiptMigration, /v_booking\.service_charge/);
  assert.doesNotMatch(customerReceiptMigration, /materials_amount/i);
  assert.match(customerReceiptMigration, /customer_user_id = v_uid/);
  assert.match(customerReceiptMigration, /grant execute on function public\.srk_customer_get_payment_receipt\(uuid\) to authenticated/i);
});


test('customer payment history RPC exists, is owner-scoped and covers all payment/refund event sources', () => {
  assert.match(customerPaymentHistoryMigration, /create or replace function public\.srk_customer_get_payment_history\(\s*p_limit integer default 25,\s*p_offset integer default 0/is);
  assert.match(customerPaymentHistoryMigration, /b\.customer_user_id=v_uid/);
  assert.match(customerPaymentHistoryMigration, /b\.payment_status in \('paid','refunded'\)/i);
  assert.match(customerPaymentHistoryMigration, /b\.payment_verified_at is not null/i);
  assert.match(customerPaymentHistoryMigration, /case when b\.payment_status='refunded' then 'refunded'[\s\S]*?else coalesce\(nullif\(b\.payment_status,''\),'recorded'\)/i);
  assert.match(html, /refunded:'रिफंड किया गया'/);
  assert.match(customerPaymentHistoryMigration, /srk_booking_refund_requests/);
  assert.match(customerPaymentHistoryMigration, /srk_razorpay_refunds/);
  assert.match(customerPaymentHistoryMigration, /srk_manual_refund_entries/);
  assert.match(customerPaymentHistoryMigration, /'manual_payment'::text/);
  assert.match(customerPaymentHistoryMigration, /from public\.srk_manual_payment_entries mp/i);
  assert.match(customerPaymentHistoryMigration, /event_id uuid,[\s\S]*?description text/i);
  assert.match(customerPaymentHistoryMigration, /limit v_limit offset v_offset/i);
  assert.match(customerPaymentHistoryMigration, /grant execute on function public\.srk_customer_get_payment_history\(integer,integer\) to authenticated/i);
  assert.match(customerPaymentHistoryMigration, /revoke all on function public\.srk_customer_get_payment_history\(integer,integer\) from public,anon/i);
});


test('customer refund form only appears for completed approved immutable labour bill and refreshes all histories', () => {
  assert.match(html, /let customerRefundSubmissionBusy=new Set\(\)/);
  assert.match(html, /customerRefundSubmissionBusy\.has\(bookingId\)/);
  assert.match(html, /customerRefundSubmissionBusy\.add\(bookingId\)/);
  assert.match(html, /customerRefundSubmissionBusy\.delete\(bookingId\)/);
  assert.match(html, /row\.status==='completed'[\s\S]*?row\.completion_approval_status==='approved'[\s\S]*?Boolean\(row\.selected_category\)[\s\S]*?Boolean\(bill\)/);
  assert.match(html, /Math\.round\(Number\(bill\.labour_amount\)\*100\)===Math\.round\(Number\(row\.amount_paid\)\*100\)/);
  const refundSubmitStart=html.indexOf('async function customerSubmitBookingRefund(');
  const refundSubmitEnd=html.indexOf('\\nlet customerBookingHistoryLoadSequence',refundSubmitStart);
  const refundSubmitSource=html.slice(refundSubmitStart,refundSubmitEnd);
  assert.ok(refundSubmitSource.includes('Promise.allSettled(['));
  assert.ok(refundSubmitSource.includes('loadCustomerBookings(),'));
  assert.ok(refundSubmitSource.includes('loadCustomerRefundHistory(),'));
  assert.ok(refundSubmitSource.includes('loadCustomerPaymentHistory(true)'));
  assert.match(refundSubmitSource, /रिफंड अनुरोध सुरक्षित रूप से दर्ज हो गया है, लेकिन कुछ सूची अपडेट नहीं हो सकीं/);
});


test('customer support attachment partial failure never invites duplicate message resend', () => {
  assert.match(html, /let pendingUploadPath=null,linkedCount=0,messageCreated=false/);
  assert.match(html, /messageCreated=true;\s*input\.value=''/);
  assert.match(html, /if\(messageCreated\)\{\s*fileInput\.value=''/);
  assert.match(html, /दोबारा भेजते समय केवल बची हुई फ़ाइलें चुनें/);
  assert.match(html, /संदेश दोबारा न भेजें/);
  assert.match(html, /if\(pendingUploadPath\)\{try\{const \{error:cleanupError\}=await customerSb\.storage\.from\('srk-customer-support'\)\.remove\(\[pendingUploadPath\]\);orphanCleanupFailed=Boolean\(cleanupError\);\}catch\(_\)\{orphanCleanupFailed=true;\}\}/);
  assert.match(html, /orphanCleanupFailed\?' अपलोड की गई असंबद्ध फ़ाइल की सफाई पूरी नहीं हुई/);
});


test('customer booking history localizes payment states including refunded', () => {
  assert.match(html, /function customerBookingPaymentStatusText\(status\)/);
  assert.match(html, /refunded:'रिफंड किया गया'/);
  assert.match(html, /pending:'भुगतान लंबित'/);
  assert.match(html, /const paymentLabel=customerBookingPaymentStatusText\(row\.payment_status\)/);
});


test('customer payment history does not duplicate audited manual payment summary rows', () => {
  assert.match(customerPaymentHistoryMigration, /not exists\s*\(\s*select 1 from public\.srk_manual_payment_entries mp\s*where mp\.booking_id=b\.id\s*\)/i);
  assert.match(customerPaymentHistoryMigration, /from public\.srk_manual_payment_entries mp\s*join customer_bookings b on b\.id\s*=\s*mp\.booking_id/i);
});


test('finalized manual refund history is labeled processed, not merely recorded', () => {
  assert.match(customerPaymentHistoryMigration, /select mr\.id,'manual_refund'::text,mp\.booking_id,mr\.amount,\s*'processed'::text/i);
});


test('customer refund history prioritizes actual processed timestamp', () => {
  assert.match(html, /const date=row\.processed_at\|\|row\.updated_at\|\|row\.created_at/);
});


test('booking card refund summary prioritizes processed timestamp', () => {
  assert.match(html, /customerBookingTimeText\(refund\.processed_at\|\|refund\.updated_at\|\|refund\.created_at\)/);
});


test('customer booking history uses a stable ID tie-breaker for equal creation timestamps', () => {
  const start = html.indexOf("from('service_bookings')", html.indexOf('async function loadCustomerBookings'));
  const end = html.indexOf('.limit(50)', start);
  const query = html.slice(start, end);
  assert.match(query, /\.order\('created_at',\s*\{\s*ascending:\s*false\s*\}\)/);
  assert.match(query, /\.order\('id',\s*\{\s*ascending:\s*false\s*\}\)/);
});


test('customer refund history RPC has stable ordering and exposes no private admin/provider fields', () => {
  const source = fs.readFileSync('supabase/migrations/20261113235900_harden_customer_cancellation_and_safe_refund_history.sql', 'utf8');
  const fn = source.slice(source.indexOf('create or replace function public.srk_customer_list_my_booking_refund_requests'));
  assert.match(fn, /where r\.customer_user_id = auth\.uid\(\)/i);
  assert.match(fn, /order by r\.created_at desc, r\.id desc/i);
  assert.match(fn, /limit 100/i);
  assert.doesNotMatch(fn, /admin_note|razorpay_payment_id|refund_record_id|provider_response/i);
});


test('customer payment history labels every RPC event type and refund reconciliation state', () => {
  const start = html.indexOf('function customerPaymentLabel(row)');
  const end = html.indexOf('async function customerPrintPaymentReceipt', start);
  const source = html.slice(start, end);
  for (const eventType of ['payment','refund_request','refund','manual_payment','manual_refund']) {
    assert.match(source, new RegExp(eventType + ':'));
  }
  for (const status of ['paid','captured','refunded','recorded','processed','requested','in_review','approved','processing','unknown','requires_reconciliation','failed','rejected']) {
    assert.match(source, new RegExp(status + ':'));
  }
  assert.match(source, /unknown:'Admin जाँच आवश्यक'/);
  assert.match(source, /requires_reconciliation:'Admin जाँच आवश्यक'/);
});

test('customer refund status labels distinguish completion, review, provider failure and reconciliation', () => {
  const start = html.indexOf('const customerRefundStatusLabels=');
  const end = html.indexOf('function customerRefundStatusText', start);
  const source = html.slice(start, end);
  for (const [status,label] of [
    ['requested','अनुरोध प्राप्त'],['in_review','Admin समीक्षा में'],
    ['approved','रिफंड स्वीकृत'],['processing','रिफंड प्रोसेस हो रहा है'],
    ['unknown','Admin जाँच आवश्यक'],['processed','रिफंड पूरा हुआ'],
    ['rejected','रिफंड अनुरोध अस्वीकृत'],['failed','रिफंड में समस्या']
  ]) {
    assert.ok(source.includes(status + ":'" + label + "'"), 'missing refund status label: ' + status);
  }
});


test('customer booking history catches session retrieval failures and ignores stale session responses', () => {
  const start = html.indexOf('async function loadCustomerBookings(reset=true)');
  const end = html.indexOf('\n}\n', start);
  const source = html.slice(start, end);
  assert.ok(source.indexOf('try {') < source.indexOf('customerSb.auth.getSession()'));
  assert.match(source, /if\(sequence!==customerBookingHistoryLoadSequence\)return;\s*if\(sessionError\)throw sessionError/);
  assert.match(source, /finally\s*\{\s*if\(sequence===customerBookingHistoryLoadSequence\)\{[\s\S]*?box\.setAttribute\('aria-busy','false'\)/);
});


test('saved address list and save catch Auth session retrieval failures', () => {
  const loadStart = html.indexOf('async function loadCustomerSavedAddresses');
  const loadEnd = html.indexOf('\nfunction applySelectedSavedAddress', loadStart);
  const loadSource = html.slice(loadStart, loadEnd);
  assert.ok(loadSource.indexOf('try {') < loadSource.indexOf('customerSb.auth.getSession()'));
  assert.match(loadSource, /if\(sessionError\)throw sessionError/);
  assert.match(loadSource, /finally \{if\(sequence===customerSavedAddressLoadSequence\)select.disabled=false;\}/);
  const saveStart = html.indexOf('async function saveCurrentBookingAddress');
  const saveEnd = html.indexOf('\nfunction editSelectedSavedAddress', saveStart);
  const saveSource = html.slice(saveStart, saveEnd);
  assert.ok(saveSource.indexOf('try {') < saveSource.indexOf('customerSb.auth.getSession()'));
  assert.match(saveSource, /if\(sessionError\)throw sessionError/);
  assert.match(saveSource, /finally \{button.disabled=false;select.disabled=selectWasDisabled;editButton.disabled=editWasDisabled;button.textContent='यह पता सेव करें';\}/);
});


test('customer session synchronization handles Auth errors and ignores stale sync results', () => {
  const start = html.indexOf('let customerSessionSyncSequence=0;');
  const end = html.indexOf('\nasync function customerSendOtp()', start);
  const source = html.slice(start, end);
  assert.ok(source.indexOf('try {') < source.indexOf('customerSb.auth.getSession()'));
  assert.match(source, /if\(sequence!==customerSessionSyncSequence\)return;\s*if\(error\)throw error/);
  assert.match(source, /if\(sequence===customerSessionSyncSequence\)\s*\{[\s\S]*?customerMessage\(/);
  assert.match(source, /await loadCustomerBookings\(\); if\(sequence!==customerSessionSyncSequence\)return/);
  assert.match(source, /await loadCustomerProfile\(\)/);
});

test('customer support message send checks Auth session errors before using user identity', () => {
  const start = html.indexOf('async function sendCustomerSupportMessage()');
  const end = html.indexOf('\nasync function ', start + 20);
  const source = html.slice(start, end);
  assert.match(source, /const \{data:sessionData,error:sessionError\}=await customerSb\.auth\.getSession\(\);\s*if\(sessionError\)throw sessionError;\s*const userId=sessionData\?\.session\?\.user\?\.id/);
});


test('customer refund success is confirmed before independent history refreshes', () => {
  const start = html.indexOf('async function customerSubmitBookingRefund(');
  const end = html.indexOf('\nlet customerBookingHistoryLoadSequence', start);
  const source = html.slice(start, end);
  assert.match(source, /requestCreated=true;\s*refundAmount=data\.amount/);
  assert.ok(source.indexOf("alert('रिफंड अनुरोध दर्ज हो गया है।") < source.indexOf('Promise.allSettled(['));
  assert.match(source, /Promise\.allSettled\(\[\s*loadCustomerBookings\(\),\s*loadCustomerRefundHistory\(\),\s*loadCustomerPaymentHistory\(true\)/);
  assert.match(source, /रिफंड अनुरोध सुरक्षित रूप से दर्ज हो गया है, लेकिन कुछ सूची अपडेट नहीं हो सकीं/);
  assert.match(source, /if\(!requestCreated\)\s*\{[\s\S]*?customerRefundSubmissionBusy\.delete\(bookingId\)/);
});


test('saved address loader ignores stale responses and only latest request restores controls', () => {
  const start=html.indexOf('let customerSavedAddressLoadSequence=0;');
  const end=html.indexOf('\\nasync function saveCurrentBookingAddress()',start);
  const source=html.slice(start,end);
  assert.ok(source.includes('const sequence=++customerSavedAddressLoadSequence;'));
  assert.ok(source.includes('if(sequence!==customerSavedAddressLoadSequence)return;'));
  assert.ok(source.includes('finally {if(sequence===customerSavedAddressLoadSequence)select.disabled=false;}'));
});

test('customer profile loader ignores stale profile and avatar responses', () => {
  const start=html.indexOf('let customerProfileLoadSequence=0;');
  const end=html.indexOf('\\nasync function saveCustomerProfile()',start);
  const source=html.slice(start,end);
  assert.ok(source.includes('const sequence=++customerProfileLoadSequence;'));
  assert.ok(source.includes('if(sequence!==customerProfileLoadSequence)return;'));
  assert.ok(source.includes('if(sequence===customerProfileLoadSequence)setCustomerProfileStatus'));
});


test('customer support complaint list refresh is serialized and stale results cannot replace the latest list', () => {
  assert.match(html,/let customerSupportComplaintsLoadSequence=0/);
  assert.match(html,/let customerSupportComplaintsBusy=false/);
  const start=html.indexOf('async function loadCustomerSupportComplaints()');
  const end=html.indexOf('let customerSupportThreadLoadSequence',start);
  const source=html.slice(start,end);
  assert.match(source,/if\(customerSupportComplaintsBusy\)return/);
  assert.match(source,/customerSupportComplaintsBusy=true/);
  assert.match(source,/if\(sequence!==customerSupportComplaintsLoadSequence\)return/);
  assert.match(source,/customerSupportComplaintsBusy=false;select\.disabled=wasDisabled/);
});


test('customer support thread RPC failures are handled without unhandled rejection or stale overwrite', () => {
  const start=html.indexOf('async function loadCustomerSupportMessages()');
  const end=html.indexOf('\\n}',start);
  const source=html.slice(start,end);
  assert.match(source,/try \{/);
  assert.match(source,/catch\(error\)/);
  assert.match(source,/if\(sequence===customerSupportThreadLoadSequence&&document\.getElementById\('customerSupportComplaint'\)\.value===id\)/);
  assert.match(source,/इस शिकायत के संदेश अभी लोड नहीं हो सके/);
  assert.match(source,/कृपया रीफ़्रेश करके दोबारा कोशिश करें/);
});

test('customer complaint creation success is not reported as failure when thread refresh fails', () => {
  const start=html.indexOf('async function createCustomerSupportComplaint()');
  const end=html.indexOf('\\nasync function loadCustomerSupportComplaints()',start);
  const source=html.slice(start,end);
  assert.match(source,/let complaintCreated=false/);
  assert.ok(source.includes("complaintCreated=true;") && source.includes("customerSupportDescription').value='';"));
  assert.ok(source.indexOf('complaintCreated=true;') < source.indexOf('await loadCustomerSupportComplaints()'));
  assert.match(source,/let refreshFailed=false/);
  assert.ok(source.includes('try{await loadCustomerSupportComplaints();}catch(_){refreshFailed=true;}'));
  assert.ok(source.includes('try{await loadCustomerSupportMessages();}catch(_){refreshFailed=true;}'));
  assert.match(source,/शिकायत सफलतापूर्वक दर्ज हो गई है, लेकिन शिकायत सूची या संदेश अभी रीफ़्रेश नहीं हो सके/);
  assert.match(source,/शिकायत दोबारा दर्ज न करें/);
  assert.ok(source.includes("complaintCreated\n   ?'आपकी शिकायत दर्ज हो चुकी है"));
  assert.ok(source.includes('finally {\n  customerSupportComplaintCreateBusy=false;button.disabled=false;'));
});


test('customer support message upload locks complaint selection until completion', () => {
  const start=html.indexOf('async function sendCustomerSupportMessage()');
  const end=html.indexOf('\\nlet customerSessionSyncSequence',start);
  const source=html.slice(start,end);
  assert.ok(source.includes("const complaintSelect=document.getElementById('customerSupportComplaint');"));
  assert.ok(source.includes("complaintSelect.disabled=true;"));
  assert.ok(source.includes("complaintSelect.disabled=complaintSelectWasDisabled;"));
  assert.ok(source.indexOf('complaintSelect.disabled=true;') < source.indexOf('for(const file of files)'));
  assert.ok(source.indexOf('complaintSelect.disabled=complaintSelectWasDisabled;') > source.indexOf('finally{'));
});


test('customer support attachment cleanup network exceptions do not bypass failure recovery', () => {
  const start=html.indexOf('async function sendCustomerSupportMessage()');
  const end=html.indexOf('\\nlet customerSessionSyncSequence',start);
  const source=html.slice(start,end);
  assert.ok(source.includes("if(pendingUploadPath){try{const {error:cleanupError}=await customerSb.storage.from('srk-customer-support').remove([pendingUploadPath]);orphanCleanupFailed=Boolean(cleanupError);}catch(_){orphanCleanupFailed=true;}}"));
  assert.ok(source.indexOf('catch(_){orphanCleanupFailed=true;}') < source.indexOf('if(messageCreated)'));
  assert.ok(source.includes("orphanCleanupFailed?' अपलोड की गई असंबद्ध फ़ाइल की सफाई पूरी नहीं हुई; सहायता टीम से संपर्क करें।':''"));
});


test('customer avatar cleanup network exceptions do not misreport saved profile as failed', () => {
  const start=html.indexOf('async function saveCustomerProfile()');
  const end=html.indexOf('\\nlet customerSavedAddresses =',start);
  const source=html.slice(start,end);
  assert.ok(source.includes('} catch(_) {uploadCleanupFailed=true;}'));
  assert.ok(source.includes("} catch(_) {cleanupWarning=' पुरानी फोटो की सफाई पूरी नहीं हुई; प्रोफ़ाइल में नई फोटो सुरक्षित है।';}"));
  assert.ok(source.includes('setCustomerProfileStatus(\'प्रोफ़ाइल सफलतापूर्वक सेव हो गई।\'+(previewLoaded?'));
  assert.ok(source.indexOf('customerCurrentAvatarPath=avatarPath;') < source.indexOf('if(oldAvatar&&oldAvatar!==avatarPath)'));
});


test('saved address writes distinguish database success from failed list refresh', () => {
  const loaderStart=html.indexOf('let customerSavedAddressLoadSequence=0;');
  const loaderEnd=html.indexOf('\\nasync function saveCurrentBookingAddress()',loaderStart);
  const loader=html.slice(loaderStart,loaderEnd);
  assert.ok(loader.includes('  return true;'));
  assert.ok(loader.includes('return false;'));
  const saveStart=html.indexOf('async function saveCurrentBookingAddress()');
  const saveEnd=html.indexOf('\\nfunction editSelectedSavedAddress()',saveStart);
  const save=html.slice(saveStart,saveEnd);
  assert.ok(save.includes('const refreshed=await loadCustomerSavedAddresses();'));
  assert.ok(save.includes('पता सेव हो गया है, लेकिन सेव किए गए पतों की सूची अभी रीफ़्रेश नहीं हो सकी'));
  const deleteStart=html.indexOf('async function deleteSelectedSavedAddress()');
  const deleteEnd=html.indexOf('\\nasync function makeSelectedAddressDefault()',deleteStart);
  const del=html.slice(deleteStart,deleteEnd);
  assert.ok(del.includes('पता हटाने का अनुरोध सफल हुआ, लेकिन सूची अभी रीफ़्रेश नहीं हो सकी'));
  const defaultStart=html.indexOf('async function makeSelectedAddressDefault()');
  const defaultEnd=html.indexOf('\\nlet customerSupportComplaints',defaultStart);
  const makeDefault=html.slice(defaultStart,defaultEnd);
  assert.ok(makeDefault.includes('const defaultConfirmed=refreshed&&customerSavedAddresses.some(item=>item.id===a.id&&item.is_default===true);'));
  assert.ok(makeDefault.includes('डिफ़ॉल्ट पता अपडेट हो गया है, लेकिन सूची रीफ़्रेश नहीं हो सकी'));
});


test('saved address selection stays locked during delete and default mutations', () => {
  const start=html.indexOf('async function deleteSelectedSavedAddress()');
  const end=html.indexOf('\\nlet customerSupportComplaints',start);
  const source=html.slice(start,end);
  assert.ok((source.match(/select.disabled=true;/g)||[]).length>=2);
  assert.equal((source.match(/select.disabled=selectWasDisabled;/g)||[]).length,2);
  assert.equal((source.match(/if\(button.disabled\)return;/g)||[]).length,2);
  assert.ok(source.includes('button.disabled=true;select.disabled=true;'));
});


test('customer profile save invalidates pending profile loads and blocks overlapping reloads', () => {
  const loadStart=html.indexOf('async function loadCustomerProfile()');
  const loadEnd=html.indexOf('\\nasync function saveCustomerProfile()',loadStart);
  const load=html.slice(loadStart,loadEnd);
  assert.ok(load.includes("if(!customerSb||document.getElementById('saveCustomerProfile')?.disabled)return;"));
  const saveStart=html.indexOf('async function saveCustomerProfile()');
  const saveEnd=html.indexOf('\\nlet customerSavedAddresses',saveStart);
  const save=html.slice(saveStart,saveEnd);
  assert.ok(save.includes('button.disabled=true;'));
  assert.ok(save.includes('++customerProfileLoadSequence;'));
  assert.ok(save.includes('finally{button.disabled=false;}'));
});


test('saved address selector and edit action stay locked during address save', () => {
  const start=html.indexOf('async function saveCurrentBookingAddress()');
  const end=html.indexOf('\\nfunction editSelectedSavedAddress()',start);
  const source=html.slice(start,end);
  assert.ok(source.includes("const select=document.getElementById('savedAddressSelect');"));
  assert.ok(source.includes("const editButton=document.getElementById('editSavedAddress');"));
  assert.ok(source.includes('button.disabled=true;select.disabled=true;editButton.disabled=true;'));
  assert.ok(source.includes('select.disabled=selectWasDisabled;editButton.disabled=editWasDisabled;'));
});


test('customer booking disclosure no longer promises a legacy home inspection quotation', () => {
  assert.match(html, /अलग घर-पर-कोटेशन प्रक्रिया नहीं है/);
  assert.match(html, /अंतिम Labour Bill सर्वर द्वारा दर्ज वास्तविक काम के समय और Admin-approved rate से बनेगा/);
  assert.match(html, /सामग्री ग्राहक स्वयं उपलब्ध कराएगा या खरीदेगा/);
  assert.match(html, /सामग्री का खर्च Labour में शामिल नहीं है और अलग रहेगा/);
  assert.doesNotMatch(html, /पहले इलेक्ट्रिशियन घर आकर काम देखेगा/);
  assert.doesNotMatch(html, /सर्विस चार्ज तथा सामान का अलग-अलग कोटेशन देगा/);
});


test('customer booking estimate rate card stays aligned with the canonical labour billing module', () => {
  const expected = [
    ['Electrical Assistant', 'electrical_assistant'],
    ['Skilled Electrician', 'skilled_electrician'],
    ['Expert Electrician', 'expert_electrician'],
    ['Premium Electrical Specialist', 'premium_electrical_specialist']
  ];
  for (const [label, key] of expected) {
    const rate = labourBilling.RATE_CARD[key].rate8hPaise;
    assert.ok(html.includes("['" + label + "'," + rate + ']'));
    for (let hours = 1; hours <= 8; hours += 1) {
      const numerator = BigInt(rate) * BigInt(hours * 60);
      const expectedPaise = (numerator + 240n) / 480n;
      assert.equal(labourBilling.calculateEstimatePaise(key, hours), Number(expectedPaise));
    }
  }
});

test('customer booking shows transparent duration estimates for all published labour tiers', () => {
  assert.ok(html.includes('id="customerLabourEstimate"'));
  assert.ok(html.includes('id="customerLabourEstimatePrompt"'));
  assert.ok(html.includes('id="customerLabourEstimateRows"'));
  for (const rate of ['89900', '119900', '159900', '199900']) assert.ok(html.includes(rate));
  assert.match(html, /const estimate=\(rate,hours\)=>[\s\S]*?BigInt\(rate\)\*BigInt\(hours\*60\)/);
  assert.match(html, /if\(\(numerator%denominator\)\*2n>=denominator\)amount\+=1n/);
  assert.match(html, /duration\.addEventListener\('change',render\)/);
  assert.match(html, /काम का प्रकार अपने-आप rate tier तय नहीं करता/);
  assert.match(html, /सामग्री\/parts इसमें शामिल नहीं हैं/);
  assert.match(html, /server-recorded वास्तविक billable minutes/);
});


test('customer booking submit handler contains no unused legacy inspection quote or zero-amount message', () => {
  assert.doesNotMatch(html, /Quote and final amount are set after electrician inspection/);
  assert.doesNotMatch(html, /राशि: \$\{amount \? '₹'\+amount : 'अभी तय नहीं'\}/);
});


test('booking API rejects past dates using India business timezone without inventing same-day cutoff', () => {
  assert.ok(bookingApi.includes('timeZone: "Asia/Kolkata"'));
  assert.ok(bookingApi.includes("preferred_date < indiaToday()"));
  assert.ok(bookingApi.includes("Same-day cutoff/business hours remain an explicit"));
});

test('booking form clearly discloses PIN syntax-only validation until authoritative postal matching exists', () => {
  assert.match(html, /id="pinValidationNote"/);
  assert.match(html, /डाक-विभागीय मिलान अभी सत्यापित नहीं है/);
  const pinNote = html.indexOf('id="pinValidationNote"');
  const pinNoteEnd = html.indexOf("</p>", pinNote);
  const addressLabel = html.indexOf('<label for="address">', pinNote);
  assert.ok(pinNote >= 0 && pinNoteEnd > pinNote && addressLabel > pinNoteEnd);
});


test('customer completion controls match the server accept reject and dispute contract', () => {
  const start=html.indexOf('async function customerRespondWorkCompletion(bookingId,response)');
  const end=html.indexOf('let customerRefundSubmissionBusy',start);
  const source=html.slice(start,end);
  assert.ok(source.includes("response==='disputed'"));
  assert.ok(source.includes("note.length<20||note.length>1000"));
  assert.ok(source.includes("p_booking_id:bookingId,p_response:response,p_note:note"));
  assert.ok(source.includes("if(!data?.success)"));
  assert.ok(source.includes("customerWorkCompletionResponseBusy.add(bookingId)"));
  assert.ok(source.includes("finally{customerWorkCompletionResponseBusy.delete(bookingId);}"));
  assert.ok(source.includes('let responseConfirmed=false;'));
  assert.ok(source.includes('responseConfirmed=true;'));
  assert.ok(source.includes('await loadCustomerBookings();'));
  assert.ok(source.includes('जवाब सर्वर पर दर्ज हो गया है'));
  assert.ok(source.includes('जवाब दोबारा न भेजें'));
  const historyStart=html.indexOf('async function loadCustomerBookings(reset=true)');
  const historyEnd=html.indexOf('async function customerRespondWorkStart',historyStart);
  const history=html.slice(historyStart,historyEnd);
  assert.ok(history.includes("row.completion_approval_status==='pending'"));
  assert.equal(history.split('customerRespondWorkCompletion(').length-1,3);
  assert.ok(history.includes("customerEsc(row.id)"));
  assert.ok(history.includes("'approved'"));
  assert.ok(history.includes("'rejected'"));
  assert.ok(history.includes("'disputed'"));
  assert.ok(history.includes('काम पूरा स्वीकार करें'));
  assert.ok(history.includes('काम अभी अधूरा है'));
  assert.ok(history.includes('विवाद दर्ज करें'));
});


test('customer cancellation remains an Admin-mediated Help and Support request', () => {
  assert.ok(html.includes('बुकिंग रद्द कराने के लिए Help & Support में अनुरोध भेजें। रद्द करने का अंतिम निर्णय Admin करेगा।'));
  assert.ok(!html.includes("rpc('srk_customer_cancel_booking'"));
  assert.ok(!html.includes("rpc('srk_customer_request_booking_cancellation'"));
  assert.ok(html.includes("async function createCustomerSupportComplaint()"));
  assert.ok(html.includes("srk_customer_create_booking_complaint"));
});


test('customer support booking selector ignores stale asynchronous responses', () => {
  assert.match(html, /let customerSupportBookingsLoadSequence=0/);
  const start = html.indexOf('async function loadCustomerSupportBookings(reset=true)');
  const end = html.indexOf('\nlet customerSupportComplaintCreateBusy', start);
  assert.ok(start >= 0 && end > start);
  const source = html.slice(start, end);
  assert.ok(source.includes('const sequence=++customerSupportBookingsLoadSequence;'));
  assert.ok(source.includes('if(sequence!==customerSupportBookingsLoadSequence)return;'));
  assert.ok(source.includes('if(sequence===customerSupportBookingsLoadSequence){'));
  assert.ok(source.includes('if(sequence===customerSupportBookingsLoadSequence){\n   customerSupportBookingsBusy=false;select.disabled=wasDisabled;more.disabled=false;'));
  assert.ok(source.includes(".eq('customer_user_id',session.user.id)"));
});


test('customer support booking selector paginates older bookings and preserves loaded choices on retryable failure', () => {
  assert.ok(html.includes('id="customerSupportBookingsMore"'));
  assert.ok(html.includes("customerSupportBookingsMore').addEventListener('click',()=>loadCustomerSupportBookings(false)"));
  const start = html.indexOf('let customerSupportBookingsLoadSequence=0;');
  const end = html.indexOf('\nlet customerSupportComplaintCreateBusy', start);
  assert.ok(start >= 0 && end > start);
  const source = html.slice(start, end);
  assert.ok(source.includes('async function loadCustomerSupportBookings(reset=true)'));
  assert.ok(source.includes('customerSupportBookingsOffset'));
  assert.ok(source.includes('(!reset&&customerSupportBookingsBusy)'));
  assert.ok(source.includes('.range(requestedOffset,requestedOffset+24)'));
  assert.ok(source.includes('customerSupportBookingsOffset=requestedOffset+rows.length;'));
  assert.ok(source.includes("more.style.display=rows.length===25?'block':'none';"));
  assert.ok(source.includes("if(reset)select.replaceChildren(new Option('बुकिंग लोड नहीं हो सकी — रीफ़्रेश करें',''));"));
  assert.ok(source.includes('customerSupportBookingsBusy?customerSupportBookingsWasDisabled:select.disabled'));
  assert.ok(source.includes('if(sequence===customerSupportBookingsLoadSequence){'));
});


test('customer support attachment signed-link failures are visible instead of silent disabled links', () => {
  const start = html.indexOf('async function loadCustomerSupportAttachments(complaintId)');
  const end = html.indexOf('\nlet customerSupportBookingsLoadSequence=0;', start);
  assert.ok(start >= 0 && end > start);
  const loader = html.slice(start, end);
  assert.ok(loader.includes('signedUrlError:Boolean(signedError)'));
  assert.ok(html.includes('फ़ाइल लिंक अभी उपलब्ध नहीं; थ्रेड रीफ़्रेश करें'));
  assert.ok(html.includes("if(!a.signedUrl){link.removeAttribute('target');"));
});
