# SRK ELECTRONIC — Timer, Final Bill and Materials Implementation Plan

Status: design/implementation blueprint only. This file does not mean the feature is implemented.

Target branch: `feature/production-push-notifications`
Production Supabase ref: `gnqhoaqatmoiwwhgzkgm` (read-only inspection only)
TEST Supabase ref: `dvzmarekhstaubyuoeeh` (currently incomplete; not a booking test clone)

## 1. Non-negotiable workflow

1. Customer OTP login and category selection.
2. Customer creates booking without payment method, advance, checkout, or quoted amount.
3. Electrician accepts. Full phone visibility is permitted only after acceptance.
4. Electrician records arrival. Arrival is not billable work time.
5. Electrician requests timer start; customer approves. Server records the authoritative start timestamp only on approval.
6. Electrician requests timer stop; timer keeps running until customer approves. Server records authoritative stop timestamp only on approval.
7. Server calculates elapsed seconds, rounds remaining seconds up to the next whole minute, and creates one immutable labour bill.
8. Materials are separate itemized lines, each requiring customer approval. No unauthorized markup.
9. Only after stop approval and bill generation can Cash or Online Payment appear.
10. Cash becomes paid only after assigned electrician confirms actual receipt. Online becomes paid only after verified provider webhook/signature and idempotency checks.
11. Receipt/history and Admin audit must show timer approvals, bill calculation, material approvals and payment evidence.

## 2. Category/rate snapshot (server-authoritative)

| category_code | Display label | 8-hour amount | hourly amount |
|---|---|---:|---:|
| helper | हेल्पर इलेक्ट्रिशियन | ₹899 | ₹112.375 |
| ordinary | साधारण इलेक्ट्रिशियन | ₹1,199 | ₹149.875 |
| skilled | कुशल इलेक्ट्रिशियन | ₹1,599 | ₹199.875 |
| master | मास्टर इलेक्ट्रिशियन | ₹1,999 | ₹249.875 |

- Store category code, display label and exact hourly rate on each new booking.
- The server maps category_code to the fixed rate table; ignore/reject client-supplied rate, quote, total, minutes or payment method.
- Never infer the selected category from electrician free-text `skills`.
- Existing historical bookings keep NULL category/rate snapshots; do not backfill guesses.

## 3. Proposed additive database model

Do not drop or rewrite historical quote columns, quote statuses or quote evidence in the first migration.

### service_bookings additions
- `service_category_code`, `service_category_label`, `hourly_rate_snapshot`
- `electrician_arrived_at`, `electrician_arrived_by`
- `timer_state` (not_requested, start_pending, running, stop_pending, stopped)
- `timer_started_at`, `timer_start_approved_at`, `timer_stop_requested_at`, `timer_stopped_at`, `timer_stop_approved_at`
- `timer_elapsed_seconds`, `timer_billable_minutes`
- `final_bill_id`
- Keep old quote/payment columns temporarily for historical compatibility; new flow must not read quote fields as its bill source.

### Immutable timer decision ledger
One row per timer action request/decision, linked to booking:
- action: start_request or stop_request
- requester user/profile identity and request timestamp
- decision: pending, approved, rejected
- decision actor and decision timestamp
- authoritative effective timestamp for approved action
- unique/idempotency key
- append-only access: no client INSERT/UPDATE/DELETE; dedicated RPCs only.

### Final bill
- One final bill per timer session/booking (unique booking ID for first release).
- Snapshot category, rate, start/stop timestamps, actual elapsed seconds, billable whole minutes, labour subtotal, rounding rule/version and final labour amount.
- Immutable once generated; corrections must be explicit audited adjustment/credit records, not edits.
- Labour total excludes all materials.

### Materials
- Item lines with description, quantity, unit price, line total, supplier/source and optional receipt reference.
- Separate customer approval ledger per bill/material revision.
- Material lines and approval cannot change labour amount.
- Customer may purchase materials independently; electrician-supplied materials must be itemized. No unauthorized markup.

### Cancellation
- Customer/electrician cancellation requests recorded separately from Admin decision.
- Record requester, reason, request time, arrival evidence, Admin actor, decision, decision time and assessed fee.
- ₹99 only when customer requested cancellation, actual arrival was recorded, and Admin approved. No fee if no arrival. Do not collect on request.
- Paid bookings require verified refund workflow before cancellation; preserve existing refund guard.

### Payment evidence
- Tie each payment attempt/confirmation to final_bill_id and immutable bill version.
- Cash: assigned electrician receipt confirmation with actor and timestamp; idempotent.
- Online: provider order/payment IDs, verified webhook evidence and idempotency key; never trust browser success.
- Admin manual adjustments remain a separate audited path, not a substitute for customer Cash/Online payment.

## 4. RPC design and authorization

All state changes use SECURITY DEFINER functions with fixed search_path, explicit `auth.uid()`, row locks (`FOR UPDATE`), strict state transitions and narrowly scoped EXECUTE grants. No broad client UPDATE policy.

Required RPCs:
- `srk_electrician_record_arrival(booking_id)`: assigned approved active electrician only; idempotent arrival timestamp.
- `srk_electrician_request_timer_start(booking_id, idempotency_key)`: assigned electrician only; requires accepted assignment and recorded arrival; creates pending start request.
- `srk_customer_decide_timer_start(request_id, approve)`: owning customer only; approval writes server timestamp and changes timer state to running.
- `srk_electrician_request_timer_stop(booking_id, idempotency_key)`: assigned electrician only; running timer required; state becomes stop_pending; timer continues.
- `srk_customer_decide_timer_stop(request_id, approve)`: owning customer only; reject returns timer to running; approve writes authoritative stop timestamp and generates final labour bill in same transaction.
- `srk_customer_approve_materials(bill_id, revision, approve)`: owning customer only; separate approval from labour bill.
- `srk_electrician_confirm_cash_payment(booking_id, bill_id)`: assigned electrician only; requires final bill, customer-approved materials if any, selected Cash method, unpaid state; records actual receipt.
- `srk_customer_request_cancellation(booking_id, reason)` and `srk_admin_decide_cancellation(request_id, decision, note)`.
- Scoped read RPCs for customer, assigned electrician and Admin audit.

Identity checks for electrician must support the established linked-profile model: `electrician_profiles.user_id = auth.uid()` OR `auth_user_id = auth.uid()`, plus approved+active and exact `assigned_electrician_id`. Customer actions must verify `customer_user_id = auth.uid()`. Admin actions must verify `is_srk_admin()`.

## 5. Billing arithmetic

- Billable minutes = ceiling(elapsed_seconds / 60).
- No minimum labour charge is approved.
- Labour = hourly_rate_snapshot / 60 × billable_minutes.
- Use PostgreSQL NUMERIC (not floating point); round only final total to ₹0.01 using numeric `round()` (half away from zero, equivalent to half-up for non-negative charges).
- 1m00s = 1 minute; 1m01s = 2 minutes; 1m59s = 2 minutes.
- Record actual elapsed seconds and billable minutes separately.
- Never accept browser-calculated amount/duration as authority.

## 6. Existing-system dependencies that must be migrated together

- Current `payment_method` is NOT NULL with default Cash. New booking flow requires no selected/implied method. Change nullable/default only in a reviewed migration, preserving old values.
- Existing quote RPCs remain executable by authenticated users; hiding the quote UI is insufficient. Revoke/retire only after replacement RPCs and all callers are ready.
- Existing commission and electrician-payable triggers depend on completed + approved quote + quote totals. Rework them to use final bill records. Commission basis is labour only unless a separate business decision approves otherwise; do not silently change commission percentage.
- Existing Admin update RPC can set cancelled directly. Generic update must reject cancellation after dedicated Admin cancellation decisions are available.
- Existing cash confirmation marks paid using `quoted_amount`; replace it with final-bill-linked receipt confirmation.
- Existing payment APIs (create order, verify payment, webhook) must all validate the immutable final bill amount and payment eligibility. Update together.
- Contact/offer RPC status filters must recognize new timer lifecycle without revealing phone numbers before acceptance.
- Preserve legacy records and historical reporting; do not drop quote columns or status values until all references have been audited.

## 7. Security and testing gates

- New tables: RLS enabled; no anon access; no direct authenticated INSERT/UPDATE/DELETE. Use ownership-scoped read RPCs or minimal SELECT policies.
- Review every trigger, view, function, grant, policy and API caller before migration.
- Concurrency: simultaneous approvals, duplicate requests, repeated webhooks, competing Admin decisions and repeated cash confirmations must be idempotent/serialized.
- Negative tests: wrong customer, wrong electrician, unassigned electrician, inactive/unapproved electrician, anonymous user, altered booking ID, stale request ID, out-of-order transitions, rejected stop, pending stop, duplicate request, browser amount tampering.
- Billing fixtures: all four categories at 1, 2, 60, 61 and 480 minutes; verify ₹0.01 final rounding and no floating-point drift.
- Materials tests: no inclusion in labour; no unapproved items charged; revision change requires fresh approval.
- Cancellation tests: no arrival = ₹0; arrival + customer request + Admin approval = ₹99; missing any required condition = ₹0.
- Payment tests: Cash not paid until electrician confirms receipt; online only after verified webhook; duplicates do not duplicate payment or payout.
- Historical compatibility: existing quote-approved, paid, refunded and cancelled bookings remain readable and finance totals unchanged.

## 8. Environment and release gates

- Current TEST project `dvzmarekhstaubyuoeeh` contains only `electrician_profiles`, `job_offers`, and `srk_push_subscriptions`; it is not a full booking schema clone.
- Do not apply booking migration to that project as if it were representative.
- First provision a separate disposable TEST Supabase/Postgres schema from reviewed migrations, including required auth helpers, extensions, triggers, RLS and grants. Use synthetic data only.
- Run migration up/down or forward-recovery validation, SQL tests, API tests and browser tests there.
- Feature branch only until complete. No Production SQL writes, no production migration, and no Netlify/Vercel production deployment without explicit user approval after test evidence review.

## 9. Current status

This plan is documentation only. No timer RPC, booking schema, UI, API, payment, trigger, policy or database behavior is claimed implemented by this document.
