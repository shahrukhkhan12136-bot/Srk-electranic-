const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve(__dirname, '..');
const admin = fs.readFileSync(path.join(root, 'admin.html'), 'utf8');
const webhook = fs.readFileSync(path.join(root, 'razorpay-webhook.js'), 'utf8');
const bookingApi = fs.readFileSync(path.join(root, 'create-booking.js'), 'utf8');
const timerSql = fs.readFileSync(path.join(root, 'supabase/migrations/20261114240000_server_authoritative_customer_approved_work_timer.sql'), 'utf8');
const archiveSql = fs.readFileSync(path.join(root, 'supabase/migrations/20261115210000_legacy_manual_payment_and_itemized_receipt.sql'), 'utf8');
const retirementSql = fs.readFileSync(path.join(root, 'supabase/migrations/20261115220000_retire_live_legacy_quotation_rpcs.sql'), 'utf8');
const removalSql = fs.readFileSync(path.join(root, 'supabase/migrations/20261118000000_remove_quotation_system_completely.sql'), 'utf8');

test('Admin has no quotation columns, status, or editing controls in booking rows', () => {
  assert.doesNotMatch(admin, /quoted_amount|quote_status|quote_note|service_charge/);
  assert.doesNotMatch(admin, /पुराना Quote|कोटेशन|quotation/i);
  assert.match(admin, /selected_category,selected_rate_tier,selected_duration_hours,estimated_labour_paise/);
  assert.match(admin, /srk_admin_record_new_booking_cash_payment/);
  assert.doesNotMatch(admin, /srk_admin_record_manual_payment/);
});

test('Razorpay webhook only settles new category bookings against server payment breakdown', () => {
  assert.doesNotMatch(webhook, /quoted_amount|quote_status|service_charge|materials_amount|approved quote/i);
  assert.match(webhook, /if \(!booking\.selected_category\) return "legacy_booking_retired"/);
  assert.match(webhook, /srk_service_role_get_booking_payment_breakdown/);
  assert.match(webhook, /srk_service_role_record_online_booking_payment/);
});

test('Booking API ignores and does not persist client-supplied price/quotation fields', () => {
  assert.doesNotMatch(bookingApi, /body\.quoted_amount|quoted_amount:/);
  assert.match(bookingApi, /estimated_labour_paise:EstimatedLabourPaise|estimated_labour_paise:estimatedLabourPaise/);
  assert.match(bookingApi, /selected_category, selected_rate_tier, selected_duration_hours/);
});

test('Work timer migration creates no quotation RPCs, projections, or quotation booking states', () => {
  assert.doesNotMatch(timerSql, /srk_submit_booking_quote|srk_customer_respond_booking_quote|srk_update_booking_work_status/);
  assert.doesNotMatch(timerSql, /quote_status|quoted_amount|awaiting_quote_approval|quote_approved|quote_rejected|inspection/);
  assert.match(timerSql, /srk_electrician_request_work_start/);
  assert.match(timerSql, /srk_customer_respond_work_completion/);
  assert.match(timerSql, /srk_booking_labour_bills/);
});

test('Historical financial data is archived privately and old manual payment RPC is retired', () => {
  assert.match(archiveSql, /srk_private\.legacy_booking_financial_evidence/);
  assert.match(archiveSql, /ENABLE ROW LEVEL SECURITY/);
  assert.match(archiveSql, /REVOKE ALL ON srk_private\.legacy_booking_financial_evidence FROM PUBLIC,anon,authenticated/);
  assert.match(archiveSql, /DROP FUNCTION IF EXISTS public\.srk_admin_record_manual_payment/);
  assert.match(archiveSql, /from srk_private\.legacy_booking_financial_evidence/);
});

test('Final retirement drops legacy APIs and active booking quotation/price columns', () => {
  for (const fn of [
    'srk_submit_booking_quote','srk_customer_respond_booking_quote','srk_update_booking_work_status',
    'srk_get_my_assigned_booking_quote_details','srk_get_my_offer_price_details',
    'srk_electrician_confirm_cash_payment','srk_get_my_assigned_cash_payment',
    'srk_admin_record_manual_payment'
  ]) assert.match(removalSql, new RegExp('DROP FUNCTION IF EXISTS public\\\\.' + fn));
  for (const col of [
    'quoted_amount','quote_status','quote_note','quote_submitted_at','quote_responded_at',
    'customer_suggested_amount','electrician_quote_kind','service_charge','materials_amount'
  ]) assert.match(removalSql, new RegExp('DROP COLUMN IF EXISTS ' + col));
  assert.match(removalSql, /srk_booking_labour_bills/);
  assert.match(removalSql, /legacy_booking_financial_evidence/);
});

test('New payouts and refunds use immutable bills or read-only historical evidence, never live quote state', () => {
  assert.doesNotMatch(removalSql, /v_booking\.quote_status|v_booking\.quoted_amount|new\.quote_status/);
  assert.match(removalSql, /v_bill\.labour_amount_paise/);
  assert.match(removalSql, /v_legacy\.service_charge/);
  assert.match(removalSql, /srk_admin_prepare_booking_refund/);
  assert.match(removalSql, /srk_admin_prepare_razorpay_refund/);
  assert.match(removalSql, /srk_admin_mark_electrician_payout_paid/);
});
