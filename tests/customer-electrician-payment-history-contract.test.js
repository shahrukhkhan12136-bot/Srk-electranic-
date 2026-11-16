const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve(__dirname, '..');
const customer = fs.readFileSync(path.join(root, 'booking.html'), 'utf8');
const electrician = fs.readFileSync(path.join(root, 'electrician.html'), 'utf8');
const receiptSql = fs.readFileSync(path.join(root, 'supabase/migrations/20261114190000_customer_receipt_immutable_labour_amount.sql'), 'utf8');
const earningsSql = fs.readFileSync(path.join(root, 'supabase/migrations/20261109003000_secure_commission_reporting.sql'), 'utf8');
const historySql = fs.readFileSync(path.join(root, 'supabase/migrations/20261114200000_customer_payment_refund_history_rpc.sql'), 'utf8');

test('Customer payment history loads on Payments tab entry, login, manual refresh and paginated continuation', () => {
  assert.match(customer, /if\(name==='Payments'\)\{loadCustomerPaymentHistory\(true\);loadCustomerRefundHistory\(\);\}/);
  assert.match(customer, /await loadCustomerPaymentHistory\(true\);/);
  assert.match(customer, /customerPaymentHistoryRefresh'\)\.addEventListener\('click',\(\)=>loadCustomerPaymentHistory\(true\)\)/);
  assert.match(customer, /customerPaymentHistoryMore'\)\.addEventListener\('click',\(\)=>loadCustomerPaymentHistory\(false\)\)/);
  assert.match(customer, /p_limit:25,p_offset:customerPaymentHistoryOffset/);
  assert.match(customer, /customerPaymentHistoryOffset\+=rows\.length/);
});

test('Customer receipts are offered only for payment events and the RPC requires verified owner-paid booking', () => {
  assert.match(customer, /\['payment','manual_payment'\]\.includes\(row\.event_type\)&&row\.booking_id/);
  assert.match(customer, /srk_customer_get_payment_history/);
  assert.match(receiptSql, /customer_user_id = v_uid/);
  assert.match(receiptSql, /payment_status <> 'paid'/);
  assert.match(receiptSql, /payment_verified_at is null/);
  assert.match(receiptSql, /v_bill\.labour_amount_paise = round\(v_booking\.amount_paid \* 100\)::bigint/);
  assert.match(receiptSql, /'labour_amount', v_labour_amount/);
  assert.match(receiptSql, /'amount_paid', round\(v_booking\.amount_paid,2\)/);
});

test('Electrician earnings and Admin bank payout remain distinct and UI never initiates withdrawal', () => {
  assert.match(earningsSql, /where p\.user_id=auth\.uid\(\) and p\.verification_status='approved'/);
  assert.match(electrician, /sb\.rpc\('srk_get_my_earnings'\)/);
  assert.match(electrician, /srk_electrician_payouts/);
  assert.match(electrician, /ग्राहक का भुगतान और Admin द्वारा आपके बैंक\/UPI में किया गया भुगतान अलग-अलग रिकॉर्ड हैं/);
  assert.match(electrician, /यह ऐप का आंतरिक लेजर बैलेंस है/);
  assert.match(electrician, /बैंक खाता जोड़ना और निकासी अभी बंद है/);
  assert.doesNotMatch(electrician, /srk_wallet_withdraw|srk_create_withdrawal|create_bank_transfer|razorpay_route_transfer/i);
});

test('Refunded completed bookings are not mislabeled as unpaid customer balances', () => {
  assert.match(earningsSql, /payment_status text/);
  assert.match(earningsSql, /b\.payment_status='paid'/);
  assert.match(electrician, /!\['paid','refunded'\]\.includes\(x\.payment_status\)/);
  assert.match(electrician, /customerRefunded=completed\.filter\(x=>x\.payment_status==='refunded'\)\.length/);
  assert.match(electrician, /रिफंड \/ रिवर्सल:/);
});

test('Customer refund and payment history labels distinguish requests, processing, completion and failures', () => {
  assert.match(customer, /refund_request:'रिफंड अनुरोध'/);
  assert.match(customer, /refund:'ऑनलाइन रिफंड'/);
  assert.match(customer, /manual_refund:'दर्ज रिफंड'/);
  assert.match(customer, /requested:'अनुरोध किया गया'/);
  assert.match(customer, /processing:'रिफंड प्रोसेस हो रहा है'/);
  assert.match(customer, /processed:'प्रोसेस्ड'/);
  assert.match(customer, /failed:'असफल'/);
  assert.match(customer, /rejected:'अस्वीकृत'/);
  assert.match(customer, /unknown:'Admin जाँच आवश्यक'/);
  assert.match(customer, /function customerRefundStatusText\(status\)/);
  assert.match(customer, /customerEsc\(customerRefundStatusText\(row\.status\)\)/);
});

test('Payment history RPC includes owner-scoped request, online refund and manual refund events', () => {
  assert.match(historySql, /where b\.customer_user_id=v_uid/);
  assert.match(historySql, /where r\.customer_user_id=v_uid/);
  assert.match(historySql, /from public\.srk_razorpay_refunds rf/);
  assert.match(historySql, /from public\.srk_manual_refund_entries mr/);
  assert.match(historySql, /limit v_limit offset v_offset/);
});

test('customer payment history handles auth session lookup failures through its normal retry state', () => {
  const start = customer.indexOf('async function loadCustomerPaymentHistory(');
  const end = customer.indexOf('\nasync function ', start + 1);
  const fn = customer.slice(start, end < 0 ? customer.length : end);
  const tryAt = fn.indexOf('try{');
  const sessionAt = fn.indexOf('customerSb.auth.getSession()');
  assert.ok(tryAt >= 0 && sessionAt > tryAt, 'session lookup is protected by the payment history try/catch');
  assert.match(fn, /if\(sessionError\)throw sessionError/);
  assert.match(fn, /finally\s*\{\s*customerPaymentHistoryBusy=false;box\.setAttribute\('aria-busy','false'\);/);
});

test('Customer cancellation-fee and refund history guard auth session failures with retry UI', () => {
  for (const [name, rpc, busyText] of [
    ['loadCustomerCancellationFeeDebts', 'srk_customer_list_my_cancellation_fee_debts', 'Cancellation fee बकाया लोड हो रहा है'],
    ['loadCustomerRefundHistory', 'srk_customer_list_booking_refund_requests', 'रिफंड अनुरोध लोड हो रहे हैं']
  ]) {
    const start = customer.indexOf('async function ' + name + '(');
    assert.ok(start >= 0, name + ' exists');
    const end = customer.indexOf('\nasync function ', start + 1);
    const fn = customer.slice(start, end < 0 ? customer.length : end);
    const tryAt = fn.indexOf('try{');
    const sessionAt = fn.indexOf('customerSb.auth.getSession()');
    assert.ok(tryAt >= 0 && sessionAt > tryAt, name + ' protects session lookup');
    assert.match(fn, /if\(sessionError\)throw sessionError/);
    assert.ok(fn.includes(rpc), name + ' calls the expected owner-scoped RPC');
    assert.ok(fn.includes(busyText), name + ' shows its loading state');
    assert.match(fn, /finally\{if\(requestId===customer(?:CancellationFee|RefundHistory)Request\)box\.setAttribute\('aria-busy','false'\);\}/);
  }
});

test('Customer payment-method change handles rejected RPC and unconfirmed responses safely', () => {
  const start = customer.indexOf('async function customerChangePaymentMethod(');
  const end = customer.indexOf('\nfunction customerPayBooking', start);
  const fn = customer.slice(start, end < 0 ? customer.length : end);
  assert.match(fn, /if\(!customerSb\|\|!id\)return/);
  assert.match(fn, /try\{/);
  assert.match(fn, /customerSb\.rpc\('srk_customer_change_payment_method'/);
  assert.match(fn, /if\(!data\?\.success\)throw new Error/);
  assert.match(fn, /catch\(error\)\s*\{\s*if\(!isCurrent\(\)\)return;\s*try\{await loadCustomerBookings\(\)/);
  assert.match(fn, /सर्वर का जवाब स्पष्ट नहीं मिला/);
  assert.match(fn, /पुष्टि किए बिना दोबारा अनुरोध न भेजें/);
  assert.match(fn, /Online भुगतान की पसंद सर्वर पर सुरक्षित हो गई है, लेकिन बुकिंग सूची रीफ़्रेश नहीं हो सकी/);
});

test('Confirmed Razorpay payment remains confirmed when booking or payment-history refresh fails', () => {
  const start = customer.indexOf('async function reconcileCustomerPaymentAfterUncertainVerification(');
  const end = customer.indexOf('\nfunction setPaymentStatus(', start);
  const fn = customer.slice(start, end);
  assert.match(fn, /paymentConfirmed=rows\.some\(row=>row\.booking_id===bookingId&&\['payment','manual_payment'\]\.includes\(String\(row\.event_type\|\|''\)\)\)/);
  assert.match(fn, /bookingsRefreshed=await loadCustomerBookings\(\)===true/);
  assert.match(fn, /historyRefreshed=await loadCustomerPaymentHistory\(true\)===true/);
  assert.match(fn, /return \{lookupSucceeded,paymentConfirmed,bookingsRefreshed,historyRefreshed\}/);
  assert.match(customer, /const \[bookingsRefreshed,historyRefreshed\]=await Promise\.all\(/);
  assert.match(customer, /loadCustomerBookings\(\)\.then\(result=>result===true\)/);
  assert.match(customer, /loadCustomerPaymentHistory\(true\)\.then\(result=>result===true\)/);
  assert.match(customer, /भुगतान सफल और सत्यापित हो गया है।'\+\(bookingsRefreshed\?/);
  assert.match(customer, /historyRefreshed\?/);
  const bookingsStart = customer.indexOf('async function loadCustomerBookings(');
  const bookingsEnd = customer.indexOf('\nasync function customerRespondWorkStart(', bookingsStart);
  const bookingsFn = customer.slice(bookingsStart, bookingsEnd);
  assert.match(bookingsFn, /return true;[\s\S]*catch\(error\)[\s\S]*return false;/);
  const historyStart = customer.indexOf('async function loadCustomerPaymentHistory(');
  const historyEnd = customer.indexOf('\nasync function loadCustomerCancellationFeeDebts(', historyStart);
  const historyFn = customer.slice(historyStart, historyEnd);
  assert.match(historyFn, /return true;[\s\S]*catch\(error\)[\s\S]*return false;/);
});

test('Customer payment-history refresh ignores stale responses after auth changes', () => {
  const start = customer.indexOf('async function loadCustomerPaymentHistory(');
  const end = customer.indexOf('\nasync function loadCustomerCancellationFeeDebts(', start + 1);
  const fn = customer.slice(start, end);
  assert.match(fn, /const requestId=\+\+customerPaymentHistoryRequest/);
  assert.match(fn, /if\(requestId!==customerPaymentHistoryRequest\)return false;/);
  assert.equal((fn.match(/if\(requestId!==customerPaymentHistoryRequest\)return false;/g) || []).length, 3);
  assert.match(fn, /catch\(error\)\{\s*if\(requestId!==customerPaymentHistoryRequest\)return false;/);
  const authStart=customer.indexOf('customerSb.auth.onAuthStateChange');
  const authEnd=customer.indexOf('const handleCustomerOffline',authStart);
  assert.ok(authStart>=0&&authEnd>authStart,'customer auth-change handler exists');
  const authHandler=customer.slice(authStart,authEnd);
  assert.match(authHandler,/if\(event==='SIGNED_IN'\|\|event==='SIGNED_OUT'\|\|event==='USER_DELETED'\)/);
  assert.match(authHandler,/customerPaymentHistoryRequest\+\+/);
  assert.match(authHandler,/customerPaymentHistoryResetPending=false/);
});

test('Customer payment-history reset requested during pagination is queued instead of silently lost', () => {
  const start = customer.indexOf('async function loadCustomerPaymentHistory(');
  const end = customer.indexOf('\nasync function loadCustomerCancellationFeeDebts(', start + 1);
  const fn = customer.slice(start, end);
  assert.match(fn, /if\(customerPaymentHistoryBusy\)\{if\(reset\)\{customerPaymentHistoryRequest\+\+;customerPaymentHistoryResetPending=true;\}return false;\}/);
  assert.match(fn, /if\(customerPaymentHistoryResetPending\)\{customerPaymentHistoryResetPending=false;setTimeout\(\(\)=>loadCustomerPaymentHistory\(true\),0\);\}/);
  assert.match(fn, /finally\{[\s\S]*customerPaymentHistoryBusy=false;[\s\S]*customerPaymentHistoryResetPending/);
});


test('Customer cancellation-fee and refund history ignore stale responses after auth changes or overlapping refreshes', () => {
  for (const [name, counter] of [
    ['loadCustomerCancellationFeeDebts', 'customerCancellationFeeRequest'],
    ['loadCustomerRefundHistory', 'customerRefundHistoryRequest']
  ]) {
    const start = customer.indexOf('async function ' + name + '(');
    const end = customer.indexOf('\nasync function ', start + 1);
    const fn = customer.slice(start, end < 0 ? customer.length : end);
    assert.ok(start >= 0, name + ' exists');
    assert.ok(fn.includes('const requestId=++' + counter), name + ' increments its request generation');
    assert.match(fn, /if\(requestId!==customer(?:CancellationFee|RefundHistory)Request\)return;/);
    assert.match(fn, /if\(requestId===customer(?:CancellationFee|RefundHistory)Request\)box\.setAttribute\('aria-busy','false'\)/);
  }
  assert.match(customer, /customerCancellationFeeRequest\+\+;\s*customerRefundHistoryRequest\+\+;/);
});


test('Customer payment receipt popup is closed when its originating session becomes stale', () => {
  const start = customer.indexOf('async function customerPrintPaymentReceipt(');
  const end = customer.indexOf('\nasync function ', start + 10);
  assert.ok(start >= 0 && end > start);
  const block = customer.slice(start, end);
  assert.ok(block.includes('const generation=customerActionGeneration'));
  assert.ok(block.includes('customerSb.auth.getSession()'));
  assert.ok(block.includes('if(!await sameSession()){printWindow.close();return;}'));
  assert.ok(block.includes('if(isCurrent()&&requestedUserId)alert('));
  assert.ok(block.includes('printWindow.close();'));
});


test('Razorpay create and verify flow does not update a different customer session', () => {
  const start = customer.indexOf('async function startRazorpayPayment()');
  const end = customer.indexOf('\nfunction customerBookingRequestKey', start);
  assert.ok(start >= 0 && end > start);
  const block = customer.slice(start, end);
  assert.ok(block.includes('const generation=customerActionGeneration'));
  assert.ok(block.includes('const sameSession=async()'));
  assert.ok(block.includes('requestedUserId=customerSession.user?.id||null'));
  assert.ok(block.includes('if(!await sameSession())return;'));
  assert.ok(block.includes('if(isCurrent())setPaymentStatus'));
  assert.ok(block.includes('if(isCurrent()){\n      paymentBusy = false;'));
});
