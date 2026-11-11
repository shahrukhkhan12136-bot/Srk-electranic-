# SRK ELECTRONIC — Customer Booking, Timer Billing & Payment Implementation Audit

**Branch:** `feature/production-push-notifications`  
**Audit date:** 2026-11-11  
**Scope:** Customer booking → electrician assignment/arrival → customer-approved timer → final bill → cash/online payment → cancellation.  
**Environment safety:** Read-only inspection of Production Supabase metadata/functions. No Production database changes, no deployment, and no customer records modified.

## 1. User-approved target behaviour

- Customer must sign in with verified mobile OTP before creating/viewing their linked bookings.
- Customer selects the electrician category and sees the approved 8-hour and hourly labour rate. The selected category/rate must be snapshotted on the booking.
- No payment method, Pay Now, checkout, payment order, or advance payment is offered at booking time or while work is underway.
- Electrician acceptance unlocks direct full-number calling for both parties, as already separately approved.
- Electrician arrival is recorded separately from billable work.
- Electrician requests timer start; customer approval is mandatory before server records the start timestamp.
- Electrician requests timer stop; timer continues until customer approval; only then server records stop timestamp and creates the final bill.
- Bill by whole minute. Any remaining seconds round UP to the next whole minute. Amount = saved hourly rate / 60 × billable whole minutes. Keep full precision and round only the final labour total to ₹0.01 using decimal half-up rounding.
- Labour and materials remain separate. Materials require itemized entries and separate customer approval.
- After approved timer stop and final bill only, expose Cash and Online Payment.
- Cash is paid only after the assigned electrician confirms actual receipt. Online is paid only after verified provider/webhook confirmation and idempotent server processing.
- Customer/electrician cancellation is a request, not a direct status update. Admin alone approves/rejects. ₹99 customer cancellation charge applies only when the electrician arrival was recorded and Admin approves the customer's cancellation request. No fee for non-arrival.
- Retire the electrician quotation/quote-approval workflow. Preserve historical records; do not delete old financial evidence.

## 2. Current implementation findings

### Customer page (`index.html`)
- Customer OTP login and linked booking retrieval exist.
- Booking form currently asks the customer to select a payment method before submitting. This contradicts the approved post-completion-only payment rule.
- Booking request currently sends `payment_method` and `quoted_amount: null` to `/api/create-booking`.
- Customer booking history still reads quote columns and renders electrician quote details and approve/reject buttons.
- Final payment UI is currently gated by `status='completed'` and `quote_status='approved'`, and uses `quoted_amount`. It must instead use the server-generated timer bill.
- Customer page calls `srk_customer_respond_booking_quote`; this dependency must be removed from the new customer workflow.
- Customer contact RPC and booking history are already present and must be preserved while updating the booking view.

### Electrician page (`electrician.html`)
- Existing work-state flow still includes quote submission/approval gates. It must be replaced by arrival recording, timer-start request, timer-stop request, customer decision status, materials request/approval and cash-receipt confirmation.
- Existing assigned-booking contact access must remain compatible with the approved direct-call rule.
- Existing push notification subscription flow should be reused for new customer timer approval requests where possible; notification delivery must not itself authorize timer actions.

### Admin page (`admin.html`)
- Existing admin booking/finance screens are built around `quoted_amount` and quote/service-charge data. Admin views and finance reporting must be migrated to timer-generated labour totals plus separately approved materials.
- Admin-only cancellation approval/rejection and audited ₹99 charge handling are not yet implemented as a complete workflow.
- Admin must be able to inspect arrival, timer requests/decisions, authoritative timestamps, minute calculation, bill lines, cash confirmation, online payment evidence and cancellation decisions.

### Production database metadata and functions (read-only inspection)
- `public.service_bookings` currently contains quote-oriented fields: `quoted_amount`, `service_charge`, `materials_amount`, `quote_status`, `quote_note`, `quote_submitted_at`, `quote_responded_at`, plus `work_started_at`.
- `service_bookings.status` currently has the legacy state set including `new`, `confirmed`, `assigned`, `inspection`, `awaiting_quote_approval`, `quote_approved`, `quote_rejected`, `in_progress`, `completed`, `cancelled`. A reviewed state migration is required; changing only UI is insufficient.
- `srk_submit_booking_quote` still writes quote fields and moves the booking to `awaiting_quote_approval`.
- `srk_customer_respond_booking_quote` still changes quote state and gates work on customer quote approval.
- `srk_update_booking_work_status` currently permits `in_progress` only after quote approval and allows completion from `in_progress` without the new mutual timer-stop approval.
- `srk_electrician_confirm_cash_payment` currently requires `completed`, approved quote and `quoted_amount`; this must be replaced by a check against the final timer bill and assigned electrician.
- `srk_get_my_assigned_cash_payment` similarly depends on quote status and quoted amount.
- `srk_customer_cancel_booking` currently directly cancels eligible unassigned bookings. This conflicts with the approved Admin-only cancellation decision and must be safely replaced/revoked.
- `srk_customer_get_my_booking_contacts` and `srk_electrician_get_my_assigned_booking_contacts` include legacy quote states; update their state filters without weakening phone-visibility authorization.
- `public.is_srk_admin()` exists and is the established Admin authorization helper.
- Electrician identity is linked through `electrician_profiles.user_id` and/or `auth_user_id`; secure RPCs must validate the assigned profile against `auth.uid()`.
- `service_bookings` currently has no electrician category/rate snapshot, arrival timestamp, mutual timer request/approval records, billable-minute total, timer-generated labour amount, or materials-approval ledger.

## 3. Approved rates

| Category | 8-hour rate | Hourly rate |
|---|---:|---:|
| Helper Electrician | ₹899 | ₹112.375 |
| Ordinary Electrician | ₹1,199 | ₹149.875 |
| Skilled Electrician | ₹1,599 | ₹199.875 |
| Master Electrician | ₹1,999 | ₹249.875 |

Rates are labour-only and must be copied onto the booking as immutable rate snapshots. Do not infer a category from free-text skills or an electrician quote.

## 4. Required implementation work (not yet completed)

1. Add a reviewed additive migration for category/rate snapshots, arrival, timer session/request/decision audit, final bill fields, separate material items/approvals, cancellation requests/admin decisions and payment evidence linkage.
2. Add server-only RPCs for electrician arrival, timer start request, customer start approval/rejection, timer stop request, customer stop approval/rejection, material item submission/customer approval, cancellation request, Admin cancellation decision, and cash confirmation against the final bill.
3. Enforce actor identity, booking ownership, assigned electrician, valid state transitions, row locking, idempotency, server timestamps, immutable accepted timestamps, RLS and execute grants. Do not permit direct client updates to privileged fields.
4. Replace quote-dependent payment-order creation and verification with a post-final-bill gate. Recheck the bill and booking state server-side when creating an order; verify signature/webhook and prevent duplicate settlement.
5. Update customer, electrician and Admin screens and all customer booking/payment/finance/reporting views. Remove quote submission and quote approval from the active workflow, but retain historical quote data for old bookings.
6. Update contact/status RPC filters and notifications. Preserve the existing after-acceptance direct phone visibility rule.
7. Add tests for all categories, partial-minute ceiling, exact minute, ₹0.01 rounding, invalid/repeated/out-of-order timer actions, unauthorized actors, pending stop billing lock, materials separation, cancellation fee conditions, cash confirmation, Razorpay duplicate/webhook handling and historic booking compatibility.
8. Test on a fully representative TEST database. The currently inspected TEST Supabase project is not a complete copy of the Production schema, so it cannot yet validate this migration safely.
9. Only after review and end-to-end tests, request explicit approval before applying any Production migration or deploying.

## 5. Safety and current status

This audit is a factual implementation map, not a claim of completion. No Production schema, data, RPC, payment configuration or deployment was changed during this audit. The next implementation must be performed on the Feature Branch and a representative isolated TEST database. Legacy quote data and payment history must remain intact for audit and reconciliation.

## 6. Deeper code and schema verification (2026-11-11 follow-up)

### Confirmed repository locations
- Root-level Netlify function sources are `create-booking.js`, `create-order.js`, `verify-payment.js`, and `razorpay-webhook.js`; the `netlify/functions/*.js` files are thin wrappers. Changes must be made to the root sources and then checked against wrapper routing.
- The actual migration directory is `supabase/migrations/`. It contains the quote workflow migration `20261109_electrician_inspection_quotes_and_service_only_commission.sql`, the follow-up cash payment migration `20261111082515_add_assigned_electrician_cash_payment_status.sql`, and prior security/commission/wallet/Route/contact migrations. This resolves the earlier uncertainty about migration paths.
- Main UI files are root `index.html`, `electrician.html`, and `admin.html`.

### Confirmed database constraints and triggers
- The current booking status CHECK constraint explicitly includes the three quote states and `inspection`; the assignment constraint also requires an assigned electrician for those states. A replacement state constraint must be coordinated with every dependent RPC, trigger, view, and UI query before legacy states are retired.
- Current payment status constraint is `unpaid/pending/paid/refunded/failed`; existing quote amount and service/material non-negative constraints are present.
- Existing booking triggers include booking initialization, job-offer broadcast, audit capture, commission calculation, job-offer cancellation, status history, and electrician payable creation. Commission and payable triggers must be reviewed against timer labour and material separation before changing bill fields.
- Do not drop old quote columns or constraints in the first migration. Historical bookings and payment reconciliation depend on them.

### Confirmed critical legacy authorization/workflow gaps
- `srk_update_booking_work_status` currently looks up the electrician by `user_id = auth.uid()` only, while other assigned-electrician functions accept either `user_id` or `auth_user_id`. New timer RPCs must use the established dual-link validation and verify the exact assigned profile.
- Existing customer and electrician contact RPCs expose full numbers only when a booking is in a hard-coded list of assigned/quote/work statuses. Their filters need to be updated to the new active states, while continuing to require customer ownership or assigned electrician identity and an approved active electrician profile.
- Existing cash confirmation marks the booking paid directly from `quoted_amount`; it does not require a separate immutable customer-approved timer bill. The new confirmation must bind to the final bill ID/version and reject any changed or unpaid material line.
- Existing Admin manual-payment RPC requires a quote-approved completed booking and a manually entered reference. This is not a substitute for the approved customer cash → assigned electrician receipt-confirmation flow and must remain separate or be redesigned with explicit Admin audit semantics.
- Existing Admin booking update RPC accepts direct status changes including cancellation and legacy quote states. This is another path that must be restricted so Admin cancellation decisions are recorded through the new cancellation decision ledger, not a generic status edit.
- Existing quote submission and customer quote-response RPCs are still callable by authenticated users under their current grants. Hiding the old controls alone would leave the legacy workflow active; grants and function behaviour must be explicitly retired only after new RPCs and UI are ready.

### Payment API dependencies confirmed
- `create-order.js`, `verify-payment.js`, and `razorpay-webhook.js` all validate completion/quote approval and reconcile the amount using `quoted_amount`, `service_charge`, and `materials_amount`. All three must be migrated together to the final bill ledger; updating only order creation would leave inconsistent verification/webhook behaviour.
- `create-booking.js` currently defaults the payment method to Cash when the client omits it and accepts a client-supplied `quoted_amount`. The new endpoint must ignore/reject client-supplied financial values and persist only a server-validated category/rate snapshot, with no payment method at booking creation.
- Admin and commission reporting currently uses `service_charge` as the labour basis. The new commission calculation must be explicitly reviewed against the business-approved commission policy; do not assume materials are commissionable or alter the percentage without approval.

### Verification status
- These are source-code and read-only Production metadata/function inspections. No migration was applied, no function or policy was changed, no payment was created, no booking/customer record was modified, and no deployment was run.
- The next safe implementation unit is an additive schema/RPC migration plus automated database tests, reviewed together with the four payment/booking API sources. It must be validated on a complete isolated schema before any Production rollout.