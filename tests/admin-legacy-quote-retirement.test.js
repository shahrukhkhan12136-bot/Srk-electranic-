const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const root=path.resolve(__dirname,'..');
const admin=fs.readFileSync(path.join(root,'admin.html'),'utf8');
const bookingApi=fs.readFileSync(path.join(root,'create-booking.js'),'utf8');
const orderApi=fs.readFileSync(path.join(root,'create-order.js'),'utf8');
const verifyApi=fs.readFileSync(path.join(root,'verify-payment.js'),'utf8');
const webhook=fs.readFileSync(path.join(root,'razorpay-webhook.js'),'utf8');
const archiveMigration=fs.readFileSync(path.join(root,'supabase/migrations/20261115210000_legacy_manual_payment_and_itemized_receipt.sql'),'utf8');
const adminMigration=fs.readFileSync(path.join(root,'supabase/migrations/20261115230000_admin_booking_direct_write_closure.sql'),'utf8');
const quoteRetirement=fs.readFileSync(path.join(root,'supabase/migrations/20261115220000_retire_live_legacy_quotation_rpcs.sql'),'utf8');
const finalRetirement=fs.readFileSync(path.join(root,'supabase/migrations/20261121250000_retire_quote_system_and_drop_live_quote_columns.sql'),'utf8');

test('Customer booking API accepts no quote amount and does not write quote fields',()=>{
 assert.doesNotMatch(bookingApi,/quoted_amount|quote_status|service_charge|materials_amount/);
});

test('Payment order, verification and webhook use immutable bills and reject quote-era bookings',()=>{
 for(const source of [orderApi,verifyApi,webhook])assert.doesNotMatch(source,/quote_status|quoted_amount|\bservice_charge\b|\bmaterials_amount\b|approved quote|कोटेशन/);
 assert.match(orderApi,/verified immutable labour bill/i);
 assert.match(verifyApi,/पुरानी बुकिंग नए भुगतान सत्यापन के लिए पात्र नहीं है/);
 assert.match(webhook,/Historical bookings without an immutable bill/);
});

test('Admin no longer displays or records legacy quotes or manual customer payments',()=>{
 assert.doesNotMatch(admin,/quoted_amount|quote_status|service_charge|पुराना Quote|srk_admin_record_manual_payment|srk_admin_record_new_booking_cash_payment/);
 assert.match(admin,/सत्यापित भुगतान/);
});

test('Historical amounts are archived privately and quote/manual-payment write RPCs are retired',()=>{
 assert.match(archiveMigration,/CREATE TABLE IF NOT EXISTS srk_private\.legacy_booking_financial_evidence/);
 assert.match(archiveMigration,/ON CONFLICT \(booking_id\) DO NOTHING/);
 assert.match(archiveMigration,/DROP FUNCTION IF EXISTS public\.srk_admin_record_manual_payment/);
 assert.match(archiveMigration,/legacy_booking_financial_evidence/);
 assert.match(adminMigration,/DROP FUNCTION IF EXISTS public\.srk_admin_update_legacy_booking_quote/);
 for(const rpc of ['srk_submit_booking_quote','srk_customer_respond_booking_quote','srk_update_booking_work_status']){
  assert.match(quoteRetirement,new RegExp('DROP FUNCTION IF EXISTS public\.'+rpc));
 }
});


test('Final migration removes quote-era columns from live bookings but preserves historical records in the private archive',()=>{
 assert.match(finalRetirement,/DROP COLUMN IF EXISTS quoted_amount/);
 assert.match(finalRetirement,/DROP COLUMN IF EXISTS quote_status/);
 assert.match(finalRetirement,/DROP COLUMN IF EXISTS service_charge/);
 assert.match(finalRetirement,/DROP COLUMN IF EXISTS materials_amount/);
 assert.match(finalRetirement,/SET status='legacy_archived'/);
 assert.match(finalRetirement,/service_bookings_status_check/);
 assert.match(finalRetirement,/awaiting_quote_approval/);
 assert.match(finalRetirement,/'legacy_archived'/);
 assert.match(admin,/legacy_archived/);
 assert.match(finalRetirement,/legacy_booking_financial_evidence/);
 assert.match(finalRetirement,/DROP FUNCTION IF EXISTS public\.srk_admin_record_manual_payment/);
 assert.doesNotMatch(finalRetirement,/DROP TABLE public\.service_bookings/i);
 assert.match(finalRetirement,/NOTIFY pgrst/);
});
