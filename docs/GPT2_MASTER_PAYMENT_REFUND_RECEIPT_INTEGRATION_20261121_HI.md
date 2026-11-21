# GPT-2 Master Payment, Refund and Receipt Integration (2026-11-21)

Feature branch: `feature/master-technician-payment-cycle-20261121`

## New migration sources

- `20261121190000_master_payment_collection_and_technician_payables.sql`
- `20261121200000_master_refund_final_bill_integration.sql`
- `20261121210000_master_customer_payment_receipt.sql`

These are source-only changes. They have not been applied to any database. No live Razorpay order/payment/refund/payout was created.

## Automatic final-bill issuance

- Customer-confirmed Master completion, final Technician daily ledger insertion, and customer material approval/rejection each retry final-bill creation.
- Expected not-ready states (missing last ledger row, an unstopped workday, or pending material decision) defer issuance without blocking the booking/customer action. The final bill is issued automatically once all prerequisites are satisfied.

## Online payment

- `create-order.js` identifies canonical Master bookings using `srk_service_category_code`.
- Master order amount is read only from `srk_booking_final_bills.subtotal_paise`; no quote, client-supplied amount, or legacy `service_charge` fallback is used.
- The Master order path remains explicitly gated by `SRK_MASTER_BOOKING_ENABLED=true`; with the flag off, it returns HTTP 503.
- `verify-payment.js` verifies the Razorpay signature, fetches provider payment details, requires captured INR payment and exact final-bill amount, then calls the service-role settlement RPC.
- `razorpay-webhook.js` uses the existing signed-body verification and durable event inbox, then reconciles captured Master payments through the same idempotent settlement RPC.

## Payment ledger and per-Technician payable allocation

- `srk_master_booking_payments` stores one verified collection per booking and links it to the immutable final bill.
- `srk_master_payment_events` stores append-only collection/refund events.
- `srk_master_technician_payables` creates one payable row for each Technician who has immutable labour ledger entries.
- Labour commission is allocated proportionally across Technicians, with the final row receiving the remaining paise so allocation totals exactly equal the booking's snapshotted company commission.
- Approved material reimbursement is allocated to the Technician who submitted the approved material request; materials are not commission-bearing.
- Online payment settlement is service-role-only and idempotent for the same booking/order/payment/amount.
- Admin manual payment RPC supports cash, UPI, and bank transfer with reference/evidence, and requires Admin authorization. It also creates the same per-Technician payable allocations.

## Refund and receipt

- Existing Admin Razorpay refund preparation now has a Master branch that validates the paid amount against the immutable Master Final Bill rather than a legacy quote.
- Pending/requested Technician payables are blocked during refund processing. A definitively failed Razorpay refund releases them to pending; a processed refund marks unpaid payables refunded.
- Existing customer payment receipt RPC now has a Master branch reading the final bill, verified payment record and approved itemized materials. Historical single-Electrician and quote-era receipt branches are preserved.
- Existing Razorpay refund event inbox/reconciliation is reused; no parallel webhook system was introduced.

## Still outstanding before enabling Master bookings

1. Wire the new per-Technician payable records into the existing Technician wallet, payout request, Admin payout review and UTR verification screens/RPCs. A pending payable is not a paid payout.
2. Verify settlement-to-company before allowing Admin payout completion; no automatic two-day settlement assumption.
3. Complete GST/tax snapshots, invoice/credit-note and gateway-fee GST reconciliation.
4. Add Admin/customer/Technician read RPCs and end-to-end UI/API contracts for the new payment records.
5. Run all new pgTAP suites against a disposable PostgreSQL/Supabase test database and perform a full booking → workday → final bill → payment → refund replay.
6. Reconcile legacy commission/payout triggers with Master accounting, without altering historical records.

The feature flag remains disabled. No production DB, Main Branch, live payment, payout or deployment was changed.
