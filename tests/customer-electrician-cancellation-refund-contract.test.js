const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve(__dirname, '..');
const customer = fs.readFileSync(path.join(root, 'booking.html'), 'utf8');
const electrician = fs.readFileSync(path.join(root, 'electrician.html'), 'utf8');
const cancellationSql = fs.readFileSync(path.join(root, 'supabase/migrations/20261114270000_admin_only_cancellation_requests_and_decisions.sql'), 'utf8');
const refundSql = fs.readFileSync(path.join(root, 'supabase/migrations/20261115100000_customer_refund_request_contract.sql'), 'utf8');
const offerSql = fs.readFileSync(path.join(root, 'supabase/migrations/20261115220000_retire_live_legacy_quotation_rpcs.sql'), 'utf8');

function sqlFunction(source, name) {
  const start = source.toLowerCase().indexOf('function public.' + name.toLowerCase() + '(');
  assert.ok(start >= 0, name + ' function exists');
  const end = source.indexOf('$$;', start);
  assert.ok(end > start, name + ' function body ends');
  return source.slice(start, end + 3);
}

test('customer cancellation request is submitted through the owner-authenticated request RPC, not a direct status write', () => {
  assert.match(customer, /customerSb\.rpc\('srk_customer_request_booking_cancellation',\{p_booking_id:bookingId,p_customer_note:note\}\)/);
  assert.match(customer, /अभी बुकिंग रद्द नहीं होगी/);
  assert.match(customer, /₹99 केवल ग्राहक के घर पहुँचने का प्रमाण/);
  assert.match(cancellationSql, /create or replace function public\.srk_customer_request_booking_cancellation\(/i);
  assert.match(cancellationSql, /v_uid uuid := auth\.uid\(\)/i);
  assert.match(cancellationSql, /where id=p_booking_id and customer_user_id=v_uid[\s\S]*?for update/i);
  assert.match(cancellationSql, /grant execute on function public\.srk_customer_request_booking_cancellation\(uuid,text\) to authenticated/i);
});

test('cancellation decision is Admin-gated, evidence-based, and applies only the approved fee rule', () => {
  const decide = sqlFunction(cancellationSql, 'srk_admin_decide_booking_cancellation');
  assert.match(decide, /is_srk_admin\(\)/i);
  assert.match(decide, /p_verified_stage not in \('not_departed','en_route','arrived'\)/i);
  assert.match(decide, /case p_verified_stage when 'not_departed' then 0 when 'en_route' then 0 when 'arrived' then 99 end/i);
  assert.match(decide, /set_config\('srk\.cancel_request_id'/i);
  assert.match(cancellationSql, /CANCELLATION_REQUIRES_ADMIN_DECISION/);
  assert.match(cancellationSql, /CANCELLATION_EVENT_HISTORY_IS_APPEND_ONLY/);
  assert.match(customer, /srk_customer_list_booking_cancellation_requests/);
  assert.match(customer, /cancellationRequest\.fee_amount/);
});

test('customer refund request UI and RPC expose only owner-safe request status and validate paid booking amount', () => {
  assert.match(customer, /customerSb\.rpc\('srk_customer_create_booking_refund_request',\{p_booking_id:bookingId,p_reason:reason\}\)/);
  assert.match(customer, /customerSb\.rpc\('srk_customer_list_booking_refund_requests'\)/);
  assert.match(customer, /customerEsc\(row\.reason\|\|'—'\)/);
  assert.match(refundSql, /v_uid uuid:=auth\.uid\(\)/i);
  assert.match(refundSql, /payment_status is distinct from 'paid'/i);
  assert.match(refundSql, /payment_verified_at is null/i);
  assert.match(refundSql, /IMMUTABLE_LABOUR_BILL_REQUIRED/);
  assert.match(refundSql, /CANCELLATION_FEE_ITEMS_NOT_FULLY_SETTLED/);
  assert.match(refundSql, /where r\.customer_user_id=v_uid/i);
  assert.match(refundSql, /Customer projection deliberately omits the private Admin note/i);
  assert.match(refundSql, /grant execute on function public\.srk_customer_create_booking_refund_request\(uuid,text\) to authenticated/i);
});

test('electrician portal displays an Admin-cancelled booking and cannot offer an accept action for it', () => {
  assert.match(offerSql, /booking_status text/i);
  assert.match(offerSql, /b\.status[\s\S]*?\('assigned','awaiting_work_start_approval','in_progress','completed','cancelled'\)/i);
  assert.match(electrician, /o\.booking_status==="cancelled"[\s\S]*?बुकिंग Admin द्वारा रद्द/);
  assert.match(electrician, /o\.offer_status==='offered'&&o\.booking_status!=='cancelled'&&p\.active/);
});


test('Customer refund submission reconciles a rejected write using the owner-scoped refund request list and never auto-resubmits', () => {
  const start=customer.indexOf('async function customerSubmitBookingRefund(');
  const end=customer.indexOf('\nasync function customerCancelBooking(',start);
  const fn=customer.slice(start,end);
  assert.match(fn,/srk_customer_create_booking_refund_request/);
  assert.match(fn,/srk_customer_list_booking_refund_requests/);
  assert.match(fn,/requests\.find\(row=>row\.booking_id===bookingId\)/);
  assert.match(fn,/customerRefundStatusText\(confirmedRequest\.status\)/);
  assert.match(fn,/दोबारा अनुरोध नहीं भेजा गया/);
  assert.doesNotMatch(fn,/catch[\s\S]*?customerSb\.rpc\('srk_customer_create_booking_refund_request'/);
});

test('Customer cancellation submission reconciles a rejected write through the owner-scoped pending request list', () => {
  const start=customer.indexOf('async function customerCancelBooking(');
  const end=customer.indexOf('\nlet customerLiveLocationBookingIds',start);
  const fn=customer.slice(start,end);
  assert.match(fn,/srk_customer_request_booking_cancellation/);
  assert.match(fn,/srk_customer_list_booking_cancellation_requests/);
  assert.match(fn,/requests\.find\(row=>row\.booking_id===bookingId&&row\.request_status==='pending'\)/);
  assert.match(fn,/रद्द करने का अनुरोध Admin के पास लंबित है/);
  assert.match(fn,/दोबारा अनुरोध नहीं भेजा गया/);
  assert.match(fn,/lookupSucceeded/);
});
