# GPT-2 Source Audit — Payment Paths for New Catalogue Bookings

**Audit date:** 18 November 2026  
**Branch:** `feat/ai-rate-management-foundation-20261118`  
**Scope:** Source inspection only. No database connection, SQL execution, migration application, deployment, or production data change.

## Findings

### 1. Razorpay online payment path includes new Catalogue bookings

The following source paths explicitly branch on `service_bookings.selected_category`:

- `create-order.js`
  - Verifies the customer's Supabase bearer session against booking owner and verified phone.
  - Requires completed booking and an online/Razorpay payment method.
  - For a new Catalogue booking, obtains the final paise amount from `rpc/srk_service_role_get_booking_payment_breakdown`.
  - Validates integer paise fields and checks total = labour + cancellation fee.
  - Uses the per-booking order-lock RPC, re-reads the booking, and links the Razorpay order through `srk_service_role_link_payment_order`.
- `verify-payment.js`
  - Verifies Razorpay HMAC signature, booking ownership/session, payment method, completed status, captured payment, INR currency, and exact amount.
  - For a new Catalogue booking, calls `srk_service_role_record_online_booking_payment` rather than directly patching the booking payment fields.
- `razorpay-webhook.js`
  - Verifies the webhook signature and claims the event through the webhook inbox.
  - For a new Catalogue booking, validates the immutable payment breakdown and calls the same `srk_service_role_record_online_booking_payment` RPC.
  - Duplicate/conflict handling and retryable webhook outcomes are present in the handler source.

The payment-order locking/linking migration `20261118040000_atomic_electrician_payment_order_link.sql` confirms that its service-role RPC accepts both new Catalogue bookings (via the payment-breakdown RPC) and legacy approved-quote bookings.

### 2. Manual payment remains a separate gap for new Catalogue bookings

The legacy `srk_admin_record_manual_payment(uuid,text,text,text)` RPC in `20261115210000_legacy_manual_payment_and_itemized_receipt.sql` explicitly rejects bookings with `selected_category IS NOT NULL`. Do not remove that guard or route Catalogue bookings through the legacy quote-settlement path.

A dedicated Main-Admin-authorized, evidence-bound manual settlement RPC for new Catalogue bookings is not confirmed by this audit. Until such a path is implemented and tested, new Catalogue manual payments must remain unavailable/blocked rather than being recorded through a legacy path.

### 3. Verification boundary

This is a static source finding, not runtime proof. The definitions and grants of `srk_service_role_get_booking_payment_breakdown` and `srk_service_role_record_online_booking_payment` still require a full migration dependency/ACL review, and the new-category online settlement needs database/runtime tests for idempotency, amount mismatch, duplicate payment, payout reconciliation, and failure rollback.

## Next safe work

1. Trace the exact SQL definitions, execution grants, row locks, and transaction behavior of the two service-role settlement RPCs.
2. Add static regression tests for the new-category online payment handler branches and manual-payment exclusion.
3. Design a dedicated manual settlement contract without changing the legacy RPC.
4. Keep all SQL source changes unapplied until explicitly authorized; no production or paid database activity is permitted by this audit.
