"use strict";
const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const migration = fs.readFileSync(path.join(__dirname, "../supabase/migrations/20261114280000_cancellation_fee_carry_forward_and_accounting.sql"), "utf8");
const payoutMigration = fs.readFileSync(path.join(__dirname, "../supabase/migrations/20261114360000_new_category_electrician_payout_reconciliation.sql"), "utf8");
const hardeningMigration = fs.readFileSync(path.join(__dirname, "../supabase/migrations/20261118120000_harden_online_payment_settlement_state.sql"), "utf8");
const cashHardeningMigration = fs.readFileSync(path.join(__dirname, "../supabase/migrations/20261118130000_harden_catalogue_admin_cash_settlement.sql"), "utf8");
const manualDigitalMigration = fs.readFileSync(path.join(__dirname, "../supabase/migrations/20261118140000_add_catalogue_admin_manual_digital_settlement.sql"), "utf8");
const adminHtml = fs.readFileSync(path.join(__dirname, "../admin.html"), "utf8");
const bookingHtml = fs.readFileSync(path.join(__dirname, "../booking.html"), "utf8");

const extract = (name) => {
  const match = migration.match(new RegExp("create or replace function public\\." + name + "\\([\\s\\S]*?\\n\\$\\$;", "i"));
  return match?.[0] || "";
};

test("new Catalogue payment breakdown RPC is service-role-only and uses immutable labour bill", () => {
  const fn = extract("srk_service_role_get_booking_payment_breakdown");
  assert.ok(fn);
  assert.match(fn, /auth\.jwt\(\)->>'role',''\)\s*<>\s*'service_role'/i);
  assert.match(fn, /from public\.srk_booking_labour_bills[\s\S]*?where booking_id=p_booking_id/i);
  assert.match(fn, /where i\.booking_id=p_booking_id and i\.status='reserved'/i);
  assert.match(fn, /total_amount_paise/i);
  assert.match(migration, /revoke all on function public\.srk_service_role_get_booking_payment_breakdown\(uuid\) from public,anon,authenticated/i);
  assert.match(migration, /grant execute on function public\.srk_service_role_get_booking_payment_breakdown\(uuid\) to service_role/i);
});

test("new Catalogue online settlement RPC locks booking, checks exact order and amount, and is idempotent by payment ID", () => {
  const fn = extract("srk_service_role_record_online_booking_payment");
  assert.ok(fn);
  assert.match(fn, /auth\.jwt\(\)->>'role',''\)\s*<>\s*'service_role'/i);
  assert.match(fn, /from public\.service_bookings where id=p_booking_id for update/i);
  assert.match(fn, /p_amount_paise<>v_expected/i);
  assert.match(fn, /v_booking\.razorpay_order_id<>p_order_id/i);
  assert.match(fn, /v_booking\.payment_status='paid'[\s\S]*?v_booking\.razorpay_payment_id=p_payment_id[\s\S]*?already_processed/i);
  assert.match(fn, /insert into public\.srk_cancellation_fee_ledger[\s\S]*?on conflict\(idempotency_key\) do nothing/i);
  assert.match(migration, /revoke all on function public\.srk_service_role_record_online_booking_payment\(uuid,text,text,bigint\) from public,anon,authenticated/i);
  assert.match(migration, /grant execute on function public\.srk_service_role_record_online_booking_payment\(uuid,text,text,bigint\) to service_role/i);
});

test("new Catalogue Admin cash RPC is Main Admin-only, locks booking and records cash evidence before payment update", () => {
  const fn = cashHardeningMigration.match(/create or replace function public\.srk_admin_record_new_booking_cash_payment\([\s\S]*?\n\$\$;/i)?.[0] || "";
  assert.ok(fn);
  assert.match(fn, /public\.is_srk_admin\(\)/i);
  assert.match(fn, /from public\.service_bookings where id=p_booking_id for update/i);
  assert.match(fn, /payment_method[\s\S]*?like '%cash%'/i);
  const evidence = fn.indexOf("insert into public.srk_manual_payment_entries");
  const bookingUpdate = fn.indexOf("update public.service_bookings");
  assert.ok(evidence >= 0 && bookingUpdate > evidence);
  assert.match(fn, /cancel-fee:cash:srk-credit:/i);
  assert.match(fn, /cancel-fee:cash:electrician-debit:/i);
  const billAssignmentCheck = fn.indexOf("v_labour.electrician_profile_id is distinct from v_booking.assigned_electrician_id");
  assert.ok(billAssignmentCheck >= 0 && billAssignmentCheck < evidence,
    "cash settlement must verify immutable bill electrician against the assigned booking electrician before payment evidence");
  const debtReservationCheck = fn.indexOf("CANCELLATION_FEE_DEBT_RESERVATION_MISMATCH");
  const walletLedgerInsert = fn.indexOf("insert into public.srk_wallet_ledger");
  assert.ok(debtReservationCheck >= 0 && walletLedgerInsert > debtReservationCheck,
    "cash settlement must lock and verify the exact reserved customer debt before wallet or receivable ledger entries");
  assert.ok(fn.indexOf("reserved_booking_id=p_booking_id") >= 0 && fn.indexOf("customer_user_id=v_booking.customer_user_id") > fn.indexOf("reserved_booking_id=p_booking_id") && fn.indexOf("for update", fn.indexOf("customer_user_id=v_booking.customer_user_id")) > 0, "debt reservation must bind booking and customer before row lock");
});

test("Catalogue payout trigger sources electrician labour only from immutable bill and excludes cancellation fees from payable", () => {
  assert.match(payoutMigration, /if new\.selected_category is not null then[\s\S]*?from public\.srk_booking_labour_bills/i);
  assert.match(payoutMigration, /v_service := round\(v_bill\.labour_amount,2\)/i);
  assert.match(payoutMigration, /v_materials := 0/i);
  assert.match(payoutMigration, /round\(v_service \+ v_materials - v_commission,2\)/i);
});

test("online settlement hardening requires Catalogue booking, exact order before replay, and payable state allow-list", () => {
  assert.match(hardeningMigration, /v_booking\.selected_category is null then raise exception 'NEW_CATALOGUE_BOOKING_REQUIRED'/i);
  assert.ok(hardeningMigration.indexOf("RAZORPAY_ORDER_MISMATCH") < hardeningMigration.indexOf("already_processed"));
  assert.match(hardeningMigration, /payment_status is null or v_booking\.payment_status not in \('unpaid','pending'\)/i);
  assert.match(hardeningMigration, /razorpay_payment_id is not null or v_booking\.payment_verified_at is not null/i);
  assert.match(hardeningMigration, /coalesce\(v_booking\.amount_paid,0\)<>0/i);
  assert.match(hardeningMigration, /revoke all on function public\.srk_service_role_record_online_booking_payment\(uuid,text,text,bigint\) from public,anon,authenticated/i);
  assert.match(hardeningMigration, /grant execute on function public\.srk_service_role_record_online_booking_payment\(uuid,text,text,bigint\) to service_role/i);
});

test("new Catalogue Admin cash settlement is Catalogue-only and rejects unexpected payment states or evidence", () => {
  assert.match(cashHardeningMigration, /v_booking\.selected_category is null then raise exception 'NEW_CATALOGUE_BOOKING_REQUIRED'/i);
  assert.match(cashHardeningMigration, /payment_status is null or v_booking\.payment_status not in \('unpaid','pending'\)/i);
  assert.match(cashHardeningMigration, /payment_verified_at is not null or coalesce\(v_booking\.amount_paid,0\)<>0/i);
  assert.match(cashHardeningMigration, /razorpay_payment_id is not null/i);
  assert.match(cashHardeningMigration, /revoke all on function public\.srk_admin_record_new_booking_cash_payment\(uuid,text,text\) from public,anon/i);
  assert.match(cashHardeningMigration, /grant execute on function public\.srk_admin_record_new_booking_cash_payment\(uuid,text,text\) to authenticated/i);
  assert.match(cashHardeningMigration, /pg_advisory_xact_lock\(hashtextextended\(lower\(v_reference\), 73119\)\)/i);
  assert.match(cashHardeningMigration, /MANUAL_PAYMENT_REFERENCE_ALREADY_USED/i);
});

test("new Catalogue Admin UPI/bank settlement validates method, booking state, unique evidence and direct-SRK fee collection", () => {
  assert.match(manualDigitalMigration, /p_method not in \('upi','bank_transfer'\)/i);
  assert.match(manualDigitalMigration, /v_booking\.selected_category is null then raise exception 'NEW_CATALOGUE_BOOKING_REQUIRED'/i);
  assert.match(manualDigitalMigration, /payment_status is null or v_booking\.payment_status not in \('unpaid','pending'\)/i);
  assert.match(manualDigitalMigration, /payment_verified_at is not null or coalesce\(v_booking\.amount_paid,0\)<>0/i);
  assert.match(manualDigitalMigration, /pg_advisory_xact_lock\(hashtextextended\(lower\(v_reference\), 73119\)\)/i);
  assert.match(manualDigitalMigration, /MANUAL_PAYMENT_REFERENCE_ALREADY_USED/i);
  assert.match(manualDigitalMigration, /payment_method=case when p_method='upi' then 'upi' else 'bank_transfer' end/i);
  assert.match(manualDigitalMigration, /'online_collection','credit'/i);
  assert.doesNotMatch(manualDigitalMigration, /srk_wallet_ledger/i);
  assert.match(manualDigitalMigration, /revoke all on function public\.srk_admin_record_new_booking_manual_digital_payment\(uuid,text,text,text\) from public,anon/i);
  assert.match(manualDigitalMigration, /grant execute on function public\.srk_admin_record_new_booking_manual_digital_payment\(uuid,text,text,text\) to authenticated/i);
});


test("Admin dashboard routes new Catalogue UPI and bank receipts to the dedicated digital settlement RPC", () => {
  assert.match(adminHtml, /srk_admin_record_new_booking_manual_digital_payment/);
  assert.match(adminHtml, /manual_method==='upi'\|\|manual_method==='bank_transfer'/);
  assert.match(adminHtml, /srk_admin_record_new_booking_cash_payment/);
  assert.match(adminHtml, /Razorpay भुगतान केवल verified online flow/);
});


test("new Catalogue digital settlement validates bill assignment and reserved debt ownership before recording payment", () => {
  const billCheck = manualDigitalMigration.indexOf("v_labour.electrician_profile_id is distinct from v_booking.assigned_electrician_id");
  const paymentEvidence = manualDigitalMigration.indexOf("insert into public.srk_manual_payment_entries");
  const bookingPaymentUpdate = manualDigitalMigration.indexOf("update public.service_bookings");
  assert.ok(billCheck >= 0 && paymentEvidence > billCheck && bookingPaymentUpdate > paymentEvidence,
    "immutable bill ownership is checked before payment evidence or booking status changes");
  const debtCheck = manualDigitalMigration.indexOf("CANCELLATION_FEE_DEBT_RESERVATION_MISMATCH");
  const ledgerInsert = manualDigitalMigration.indexOf("insert into public.srk_cancellation_fee_ledger");
  const itemSettlement = manualDigitalMigration.indexOf("update public.srk_booking_cancellation_fee_items set status='settled'");
  const debtSettlement = manualDigitalMigration.indexOf("update public.srk_customer_cancellation_fee_debts set status='settled'");
  assert.ok(debtCheck >= 0 && ledgerInsert > debtCheck && itemSettlement > ledgerInsert && debtSettlement > itemSettlement,
    "reserved debt ownership is verified before ledger credit and settlement updates");
  assert.match(manualDigitalMigration, /status='reserved' and reserved_booking_id=p_booking_id[\s\S]*?customer_user_id=v_booking\.customer_user_id[\s\S]*?for update/i);
});


test("customer payment consent UI distinguishes Razorpay UPI checkout from standalone Admin-recorded UPI/bank transfer", () => {
  const paymentSelect = bookingHtml.match(/<select id="payment" required>([\s\S]*?)<\/select>/i)?.[1] || "";
  assert.match(paymentSelect, /value="Cash"/);
  assert.match(paymentSelect, /value="Razorpay ऑनलाइन भुगतान"/);
  assert.doesNotMatch(paymentSelect, /value="(?:upi|bank_transfer|bank transfer)"/i);
  assert.match(bookingHtml, /क्या आप इस बुकिंग के लिए Cash की जगह Online/);
  assert.match(manualDigitalMigration, /BOOKING_PAYMENT_METHOD_MISMATCH/);
});


test("new Catalogue online order and customer verification paths enforce ownership, amount, capture, and atomic settlement", () => {
  const fs = require("node:fs");
  const path = require("node:path");
  const createOrder = fs.readFileSync(path.join(__dirname, "../create-order.js"), "utf8");
  const verifyPayment = fs.readFileSync(path.join(__dirname, "../verify-payment.js"), "utf8");
  assert.match(createOrder, /user\.id !== booking\.customer_user_id/);
  assert.match(createOrder, /!user\.phone_confirmed_at/);
  assert.match(createOrder, /srk_service_role_get_booking_payment_breakdown/);
  assert.match(createOrder, /srk_claim_payment_order_lock/);
  assert.match(createOrder, /srk_service_role_link_payment_order/);
  assert.match(createOrder, /srk_release_payment_order_lock/);
  assert.match(verifyPayment, /createHmac\("sha256",RAZORPAY_KEY_SECRET\)/);
  assert.match(verifyPayment, /p\.order_id!==orderId\|\|p\.status!=="captured"\|\|p\.currency!=="INR"\|\|p\.amount!==expectedAmount/);
  assert.match(verifyPayment, /srk_service_role_get_booking_payment_breakdown/);
  assert.match(verifyPayment, /srk_service_role_record_online_booking_payment/);
  assert.match(verifyPayment, /p_booking_id:booking\.id,p_order_id:orderId,p_payment_id:payId,p_amount_paise:p\.amount/);
});


test("new Catalogue Razorpay webhook verifies signed raw payload, deduplicates events and delegates payment to atomic settlement RPC", () => {
  const webhook = fs.readFileSync(path.join(__dirname, "../razorpay-webhook.js"), "utf8");
  assert.match(webhook, /createHmac\("sha256", WEBHOOK_SECRET\)\.update\(rawBody\)/);
  assert.match(webhook, /timingSafeEqual\(expected, received\)/);
  assert.match(webhook, /srk_service_claim_razorpay_webhook_event/);
  assert.match(webhook, /srk_service_complete_razorpay_webhook_event/);
  assert.match(webhook, /createHash\("sha256"\)\.update\(rawBody\)/);
  assert.match(webhook, /payment\.status !== "captured"/);
  assert.match(webhook, /payment\.amount !== expectedAmount \|\| payment\.currency !== "INR"/);
  assert.match(webhook, /srk_service_role_get_booking_payment_breakdown/);
  assert.match(webhook, /srk_service_role_record_online_booking_payment/);
  assert.match(webhook, /p_booking_id: booking\.id, p_order_id: payment\.order_id, p_payment_id: payment\.id, p_amount_paise: payment\.amount/);
  assert.match(webhook, /booking\.razorpay_payment_id === payment\.id \? "already_processed" : "payment_conflict"/);
});
