const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const admin=fs.readFileSync(path.join(__dirname,'..','admin.html'),'utf8');

test('Admin booking list shows verified payment as read-only and has no quote or manual customer payment controls',()=>{
 assert.match(admin,/सत्यापित भुगतान/);
 assert.doesNotMatch(admin,/quoted_amount|quote_status|service_charge|materials_amount|पुराना Quote/);
 assert.doesNotMatch(admin,/id="pay-\$\{x\.id\}"|id="manual-method-\$\{x\.id\}"|id="ref-\$\{x\.id\}"/);
 assert.doesNotMatch(admin,/srk_admin_record_manual_payment|srk_admin_record_new_booking_cash_payment/);
});

test('Admin booking save handler only confirms eligible legacy new bookings and never edits payment or price',()=>{
 const start=admin.indexOf('async function saveBookingInternal(id){');
 const end=admin.indexOf('\n}',start);
 assert.ok(start>=0&&end>start);
 const fn=admin.slice(start,end);
 assert.match(fn,/srk_admin_confirm_legacy_booking/);
 assert.doesNotMatch(fn,/payment_status|amount_paid|quote|manual_payment|service_charge/);
});
