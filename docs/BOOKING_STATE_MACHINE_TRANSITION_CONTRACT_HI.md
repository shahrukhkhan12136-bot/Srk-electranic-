# SRK ELECTRONIC — Booking State Machine & Transition Contract

Date: 2026-11-11
Branch: `feature/production-push-notifications`
Status: **Architecture proposal for review; not implemented as a database migration**

## 1. Purpose and authority

This contract defines one authoritative lifecycle for new category/rate-snapshot bookings. The database booking row, accepted offer, timer/bill records and payment evidence are authoritative. UI labels, push notifications, client timestamps and client-supplied amounts are not authority.

Historical quote-based bookings remain readable and use a clearly isolated legacy compatibility path. New timer bookings must never fall back to legacy quote, work-status, Admin-edit, or payment paths.

## 2. Identity and assignment invariant

A booking is assigned only when all of the following agree:
- `service_bookings.assigned_electrician_id` points to the electrician profile;
- the same booking has one `job_offers` row for that profile with status `accepted`;
- the profile is active and Admin-approved;
- the authenticated actor resolves uniquely to that profile through `user_id = auth.uid()` and/or `auth_user_id = auth.uid()`.

If both identity columns match different profiles, reject and flag for Admin review. Never accept a client-supplied profile ID as proof of identity. Lock the booking row before assignment/state checks and enforce one winning offer transactionally.

The two existing acceptance functions (`accept_electrician_job` and `srk_respond_to_offer`) currently differ in identity lookup and eligible booking statuses. Do not modify or revoke either until all callers, grants and regression paths are mapped. A single canonical acceptance contract should be introduced only with a safe compatibility plan.

## 3. Proposed lifecycle for new timer bookings

| Stage | Authoritative state / record | Allowed actor and transition | Required guard/evidence |
|---|---|---|---|
| Request created | booking `new` | verified Customer creates request | server category/rate snapshot, customer ownership, idempotency |
| Offers published | booking remains `new`; offer rows `offered` | server broadcast trigger | serviceability and eligible active/approved electricians |
| Offer accepted | booking `assigned`; exactly one offer `accepted` | matched Electrician accepts | row locks, unique profile identity, no prior assignment |
| Arrival recorded | arrival evidence record; booking remains `assigned` | assigned Electrician records arrival | server timestamp, booking/profile match, evidence metadata |
| Start requested | timer start decision `pending` | assigned Electrician requests | arrival exists; no existing active/completed session |
| Start approved | timer session `running` | owning Customer approves | customer owns booking; server records start timestamp |
| Start rejected | request `rejected`; no running timer | owning Customer rejects | audit reason; electrician may submit a new request only under defined retry rules |
| Stop requested | timer stop decision `pending`; timer still running | assigned Electrician requests | active timer exists; no final bill yet |
| Stop approved | timer `stopped`; immutable final labour bill created | owning Customer approves | server stop timestamp; ceil seconds to whole minutes; precision retained; one final bill |
| Stop rejected | request `rejected`; timer remains running | owning Customer rejects | audit reason; no bill/payment unlock |
| Materials proposed | material revision `pending` | assigned Electrician submits | separate itemized lines; receipt reference for electrician-supplied items; idempotency |
| Materials decided | revision `approved` or `rejected` | owning Customer decides | decision bound to exact revision; customer-supplied items have ₹0 value |
| Payable finalized | immutable payable snapshot | server only | final labour bill + approved electrician-supplied material lines; exclude customer-supplied materials |
| Payment pending | Cash intent or Razorpay order bound to snapshot | Customer chooses after final bill | no booking-time/upfront payment; exact snapshot amount and currency |
| Cash received | cash receipt `confirmed` | assigned Electrician confirms actual receipt | customer booking, assigned profile and exact payable snapshot match |
| Online paid | provider payment `verified` | verified webhook/server handler | signature/provider verification, idempotency, duplicate/replay protection |
| Settlement | commission/payable ledger | server/Admin reconciliation | 15% commission on labour only; materials excluded; no invented transfer evidence |
| Closed | completed/settled status derived from authoritative records | server only | required bill/payment/cash evidence consistent; do not trust client status writes |

A booking can have ancillary complaint, rating, support or dispute records without rewriting the financial/timer history.

## 4. Cancellation sub-state machine

Cancellation is a request and Admin decision, not a direct customer/electrician status update.

1. Customer or assigned Electrician submits a cancellation request with actor, reason and idempotency key.
2. Booking remains in its current operational state while the request is pending, subject to a documented safe-work policy.
3. Admin reviews booking state, arrival evidence, requester and audit history.
4. Admin approves or rejects with an immutable decision record.
5. ₹99 customer cancellation fee is eligible only if (a) Customer requested cancellation, (b) electrician arrival evidence exists, and (c) Admin explicitly approves the fee. If any condition is false, fee is ₹0.
6. Staff may explain policy, collect facts and escalate, but cannot approve, impose or collect the fee.
7. Actual ₹99 collection is not implemented. Approval must not be represented as successful collection.

The existing Production `srk_customer_cancel_booking` direct-cancel path conflicts with this target and must be addressed only in a reviewed migration after caller/grant audit. Preserve historical cancellation records.

## 5. Payment and ledger invariants

- No payment method selector, checkout or order creation at booking time or while work is running.
- A payment attempt must reference one immutable payable snapshot; amount cannot be re-derived from mutable UI fields.
- Cash: customer pays assigned Electrician directly; Electrician confirms actual receipt; commission remittance is tracked separately; Admin confirms actual SRK receipt. Cash ledger electrician_payable = 0.
- Online: payment is recognized only after verified provider evidence; ledger records the payable and commission separately.
- Commission is 15% of labour only; no commission on materials.
- A webhook, browser return URL, screenshot or client success message alone is not payment proof.
- Refund approval and provider refund execution/reconciliation are separate audited steps.

## 6. Contact visibility and notifications

- Before offer acceptance/assignment, Customer and Electrician cannot see each other's phone numbers.
- After the authoritative assignment/accepted-offer invariant is satisfied, the two parties may see full unmasked numbers for that booking; no OTP is required for this post-acceptance reveal.
- Admin may inspect both numbers. Staff sees only the minimum support context required by assigned role and verified lookup.
- Contact RPCs must validate booking ownership/assignment server-side; do not rely on UI hiding.
- Push notifications announce pending actions but never authorize or execute them.

## 7. Legacy compatibility boundary

Legacy quote fields and functions remain available only to historical bookings that do not have the new server-saved category/rate snapshot. For new timer bookings:
- block quote submission/approval and legacy work-status completion;
- block generic Admin edits that could mutate timer/payment authority;
- block legacy cash confirmation and quote-based order/verification;
- preserve historical quote/payment evidence and read-only reporting;
- audit every remaining caller and EXECUTE grant before retiring old RPCs.

The Production status CHECK constraint and insert/status triggers are legacy-oriented. Do not simply replace status strings in the UI. The final migration must be designed against a representative Production schema fixture, including triggers, RLS, grants, constraints and legacy rows.

## 8. Error, retry and concurrency rules

- Every mutating request has an idempotency key and returns the original result on safe replay.
- Lock the booking row before checking or changing assignment, arrival, timer, cancellation or payable state.
- Lock the specific offer/revision/session/snapshot rows in a consistent order to avoid deadlocks.
- Enforce one accepted offer, one active timer session, one final labour bill and one payable snapshot per applicable lifecycle.
- A rejected or expired action cannot be replayed as accepted.
- Server timestamps are authoritative; client time is display-only.
- Reject out-of-order transitions with stable machine-readable error codes.
- SECURITY DEFINER functions use empty search_path, schema-qualified objects, explicit actor checks and minimum EXECUTE grants.

## 9. Implementation sequence and gates

1. Inventory all UI/API/RPC callers, triggers, grants and state constraints (read-only).
2. Convert this proposal into a transition matrix with exact existing/new DB columns and RPC names.
3. Build a disposable PostgreSQL fixture from an authoritative Production schema snapshot, including representative historical rows.
4. Design one forward-only migration sequence that resolves Production migration-history ordering without blind repair or fake applied records.
5. Implement additive server RPCs and compatibility guards on Feature Branch.
6. Test positive/negative role matrix, concurrent acceptance, retries, timer decisions, materials revisions, cancellation, Cash, Razorpay webhook replay, historic booking preservation and rollback.
7. Run browser Preview E2E and Razorpay Test Mode; no real-money tests.
8. Obtain explicit owner approval before any Production migration, deployment or provider activation.

## 10. Explicitly not done

This document does not change the database, UI, APIs, RPCs, grants, payment settings or Production website. It does not mean the state machine is implemented or tested. All transitions above are proposed acceptance criteria until verified by code and runtime tests.
