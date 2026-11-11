# Timer Cutover: Payment API and Legacy Booking API Audit

Date: 2026-11-11  
Branch: `feature/production-push-notifications`

## Scope and safety

Read-only inspection of the Feature Branch source and Production PostgreSQL function grants. No source runtime behavior was changed. No database writes, migrations, payment requests, or deployments were performed.

Inspected:
- `create-booking.js`
- `create-order.js`
- `verify-payment.js`
- `razorpay-webhook.js`
- Their Netlify adapters under `netlify/functions/`
- Production EXECUTE privileges for legacy booking/offer functions.

The Netlify files are thin adapters which import the root handlers; the root files are the effective implementation.

## Findings

### 1. Booking creation is incompatible with the approved no-advance-payment flow

Current `create-booking.js`:
- Requires the request to choose Cash or Razorpay Online.
- Defaults a missing payment method to Cash.
- Accepts client-supplied `quoted_amount`.
- Inserts legacy `payment_method` and `quoted_amount` into `service_bookings`.
- Does not snapshot a canonical electrician category and server-owned hourly rate into the new timer/billing fields.

Required cutover:
- Booking creation must not offer or require a payment method.
- It must not accept or persist a client-supplied final/quoted amount.
- Category must be a validated enum mapped server-side to the approved rate table, then snapshotted on the booking.
- No checkout, payment order, advance, or payment authorization is created at booking time.
- Preserve historical legacy columns and records; do not mass-null or rewrite old bookings.

### 2. Razorpay order creation still trusts legacy quote/payment state

Current `create-order.js`:
- Allows payment only when booking is `completed` and `quote_status='approved'`.
- Computes amount from `service_charge + materials_amount`, then compares it to `quoted_amount`.
- Reusable-order matching also compares the Razorpay amount to `quoted_amount`.
- Writes `razorpay_order_id` and `payment_status='pending'` directly through the service-role REST API.
- Uses a per-booking lock, but the payable contract is still the legacy quote contract.

Required cutover:
- Require customer-approved final bill ID and immutable bill revision, with the server loading the authoritative total from the final bill.
- Reusable-order matching must bind to that bill ID/revision and exact paise amount, not a mutable booking quote field.
- Persist an order-to-bill binding/idempotency record atomically before returning the order.
- Payment availability must not appear before timer stop approval, final bill creation, and materials approval.
- Keep lock/idempotency semantics and re-check all authoritative state after acquiring the lock.

### 3. Payment verification still validates and mutates legacy booking fields

Current `verify-payment.js`:
- Repeats the completed + approved-quote gate and legacy amount comparison.
- Verifies Razorpay signature and fetches the payment to check captured status, order, currency, and amount.
- Directly patches booking payment fields via service-role REST.
- Has a useful same-payment duplicate check, but payment verification is not bound to a final bill revision.

Required cutover:
- Verify signature and provider payment facts, then call a narrow database reconciliation RPC.
- RPC must lock the payment/bill/booking state, verify the immutable bill binding and exact amount, and write payment evidence idempotently.
- A duplicate same payment must return success; a different payment against an already-paid bill must conflict.
- Do not let the browser or API caller provide an authoritative payable amount.

### 4. Razorpay webhook lacks a durable event ledger and uses direct booking PATCH

Current `razorpay-webhook.js`:
- Verifies the webhook HMAC against the raw request body.
- Handles `payment.captured` and `order.paid`.
- Reads a booking by Razorpay order ID, checks legacy quote state/amount, then directly patches `service_bookings`.
- Detects duplicate payment IDs by re-reading the booking after a concurrent update.
- Does not persist the Razorpay webhook event ID, payload hash, processing state, or terminal outcome in a durable idempotency ledger.
- Does not bind the payment to a final bill ID/revision.

Required cutover:
- Add a durable webhook-event ledger with a unique provider event ID and safe duplicate/retry behavior.
- Route reconciliation through the same narrow payment RPC used by verification, with server-side bill binding.
- Persist rejected/mismatched events for Admin reconciliation without marking the booking paid.
- A repeated event must not duplicate payout, commission, receipt, or booking transitions.

### 5. Production legacy function grants confirmed

Read-only `has_function_privilege` results for Production:
| Function | anon | authenticated | service_role |
|---|---:|---:|---:|
| `accept_electrician_job(uuid)` | false | false | true |
| `srk_respond_to_offer(uuid,text)` | false | true | true |
| `srk_update_booking_work_status(uuid,text)` | false | true | true |

Implications:
- The current electrician UI's `srk_respond_to_offer` path is available to authenticated users.
- The legacy work-status function is executable by authenticated users and can advance legacy work states without customer timer approval.
- `accept_electrician_job` is not executable by authenticated users in Production, despite its presence; do not assume this is the live frontend acceptance path.
- The new timer cutover must explicitly remove authenticated execution from the legacy work-status path only after all frontend/API callers are migrated and verified. Do not revoke it now because the current electrician UI still calls it.
- Re-check grants after the coordinated migration; do not infer default privileges from these three functions.

## Coordinated migration order

1. Finish caller inventory across customer, electrician, Admin, Netlify functions, database triggers, and payment flows.
2. Freeze and document the new booking/timer/final-bill/payment contracts.
3. Implement hardened database RPCs and append-only timer, approval, bill, material, cancellation, payment, and webhook audit records.
4. Add automated SQL tests for ownership, assigned electrician + accepted offer, ambiguous profiles, customer approvals, replay/idempotency, concurrency, timer rounding, bill immutability, materials approval, and payment-to-bill binding.
5. Update booking creation and all three payment handlers as one coordinated cutover.
6. Update customer/electrician/Admin UI callers and remove the legacy quote path only when no active caller remains.
7. Run isolated TEST project migration and end-to-end tests; then obtain explicit approval before any Production migration or deployment.

## Explicitly not done

- No migration was applied to TEST or Production.
- No RPC was deployed.
- No payment order/payment was created.
- No webhook was replayed.
- No UI or API source file was modified.
- No Production data was changed.
- No Netlify/Vercel deployment was made.

This audit is a source/metadata finding, not a claim that the new timer or billing system is implemented.
