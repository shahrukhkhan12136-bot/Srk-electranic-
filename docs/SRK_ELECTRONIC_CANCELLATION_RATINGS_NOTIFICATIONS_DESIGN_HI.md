# SRK ELECTRONIC — Customer App: Cancellation, Ratings और Notifications Design

**स्थिति:** Design baseline / implementation से पहले dependency contract  
**शाखा:** `feature/platform-fee-cash-online-cycle`  
**नियम-स्रोत:** `docs/SRK_ELECTRONIC_MASTER_REQUIREMENTS_HI.md` sections 1A, 6, 8.1, 8.2, 9.3, 9.5, 10 और 11  
**सीमा:** Feature-branch design only. कोई Production SQL, live payment, wallet posting, notification delivery या deployment नहीं।

## 1. Cancellation workflow — authoritative rules

- Customer केवल eligible active booking पर `Cancel Booking` request भेजता है; वह booking को cancel नहीं करता।
- Electrician self-cancel नहीं कर सकता। वह Admin/support को issue escalate कर सकता है।
- केवल authorized Admin final decision करेगा; decision, fee, evidence snapshot और reason immutable audit में दर्ज होंगे।
- Fee evidence के आधार पर: not departed = ₹0; en route = ₹49; arrived = ₹99.
- Admin fee tier बदल सकता है, लेकिन evidence और स्पष्ट reason अनिवार्य हैं। Request submit होना cancellation या fee assessment नहीं है।
- Unpaid fee अगली customer booking में अलग-अलग carry-forward line items होगी; service labour/materials से अलग।
- Customer wallet balance fee waive नहीं करता। Cancellation fee को Platform Fee या labour revenue में कभी नहीं मिलाना है।

### 1.1 Proposed state machine

`requested → in_review → approved | rejected`

- `requested`: customer request स्वीकार हुई, booking अभी अपने आप cancel नहीं।
- `in_review`: Admin evidence जाँच रहा है।
- `approved`: Admin ने cancellation final की; booking status transition और fee decision एक ही DB transaction में।
- `rejected`: Admin ने request अस्वीकार की; booking active lifecycle में रहेगी।
- एक booking पर एक समय में केवल एक खुली request। Rejected request के बाद नया request केवल policy-eligible active booking पर नया idempotency key लेकर संभव हो।
- Completed/already-cancelled bookings और unknown/unsupported states reject हों। Timer running, start/completion pending/disputed और payment in-flight states पर explicit conflict guard हो; बिना reconciliation स्वतः cancel न करें।

### 1.2 Evidence contract

अभी के `srk_booking_work_events` में departure/en-route/arrival event types नहीं हैं। इसलिए पुराने work timeline को यात्रा का प्रमाण नहीं मानना है।

Proposed evidence record:
- `evidence_status`: `not_departed | en_route | arrived | unknown`
- `evidence_source`: future verified travel/arrival event reference, permitted location proof reference, या स्पष्ट `manual_admin_verification`
- `evidence_at`: source timestamp; Admin review timestamp से अलग
- `evidence_snapshot`: minimal immutable fields, no unnecessary raw location retention
- `admin_reason`: required, bounded text
- `decided_by`, `decided_at`, before/after booking state

जब reliable travel/arrival telemetry उपलब्ध न हो, Admin केवल manual verification चुन सके और source/reason दर्ज करे। Missing evidence को silently `not_departed` न मानें; `unknown` पर fee decision रोकें या explicit Admin-reviewed exception route दें।

### 1.3 Proposed data model

1. `srk_booking_cancellation_requests`
   - request UUID, booking/customer IDs, customer reason, idempotency key, state, created/updated timestamps.
   - Unique idempotency key; unique partial index enforcing one open request per booking.
   - Customer read only own request; no client table writes.
2. `srk_booking_cancellation_events`
   - append-only actor/role, from/to state, evidence snapshot, fee tier/amount, reason, timestamp, idempotency key.
   - No update/delete grants; trigger rejects mutation.
3. `srk_customer_cancellation_fee_items`
   - one immutable receivable per approved cancellation; customer ID, source booking ID, amount in integer paise, fee tier, evidence/event reference, status and idempotency key.
   - Distinct rows remain distinct; no pooled customer due balance as the only source of truth.
4. `srk_customer_cancellation_fee_allocations`
   - allocation links each fee item to a later booking and exact payment settlement; partial allocation only if policy explicitly supports it (initial version should require full line-item settlement or leave it outstanding).
   - unique idempotency keys and foreign keys; immutable allocation/reversal entries.
5. Separate cancellation-fee accounting entries / ledger:
   - own accounting head, not `srk_platform_fee_ledger`, `commission`, labour, materials or generic complaint.
   - reversal by compensating entry, never row rewrite.

### 1.4 RPC boundary

- `srk_customer_request_booking_cancellation(booking_id, reason, idempotency_key)`
  - authenticated customer ownership; lock booking; validate eligible status and no duplicate open request; insert request + event atomically; does not update booking status or create fee.
- `srk_admin_list_booking_cancellation_requests(...)`
  - Admin-only, paginated; returns minimum customer/booking details and evidence state.
- `srk_admin_review_booking_cancellation(request_id, decision, evidence_status, evidence_source, evidence_reference, reason, idempotency_key)`
  - Admin-only; locks request + booking; validates evidence, tier and current booking state; approved decision updates booking to cancelled, creates fee item (₹0/₹49/₹99), request state and immutable event in one transaction. Rejected decision does not alter booking status.
- `srk_customer_list_my_cancellation_requests(...)`
  - customer owner-scoped status/history; only safe fields.
- All functions revoke PUBLIC/anon execute; explicit authenticated grants; every SECURITY DEFINER function must check auth and role/ownership internally and pin search_path.

## 2. Carry-forward settlement — separate from current booking price

### 2.1 Booking bill representation
Customer bill must show distinct rows:
- New booking labour
- Materials (if any; separate)
- Each prior cancellation fee with its source booking/reference
- Total payable

A single opaque amount_paid or labour-only bill snapshot cannot be treated as proof that every fee item was collected. Immutable booking payment snapshot must retain labour paise, materials paise and each cancellation-fee item/allocation separately.

### 2.2 Online
- Razorpay order amount = labour + materials + selected prior cancellation fee items, all integer paise and INR.
- On verified capture, payment finalization allocates each cancellation-fee item to SRK cancellation-fee ledger/account, while labour and materials follow their existing separate paths.
- Repeated webhook/order finalization is idempotent per payment and per fee item.
- Partial/failed/unknown capture does not mark fee items settled; provider-unknown states retain reconciliation gate.
- Refund must reverse only the actual component allocations, respecting already paid-out/settled constraints. Existing labour-only refund workflow cannot be blindly reused for a mixed-component bill.

### 2.3 Cash
- Customer pays full total cash to electrician.
- In the same DB transaction that verifies/records the cash receipt, each carried fee item is allocated and an electrician wallet debit/negative-liability entry is posted for the same cancellation-fee amount.
- Use the existing wallet's `adjustment` debit only if the wallet schema and ledger semantics are proven compatible; otherwise add a dedicated electrician cancellation-liability ledger and reconcile its balance. Do not mutate wallet balance directly.
- The cash receipt, per-item allocations, debit entries and booking payment status must be atomic and idempotent. No debit merely because a booking was created or a fee was approved.
- If electrician wallet/account is unavailable or the debit cannot be posted, cash settlement must fail closed or enter a visible Admin reconciliation state; never silently mark the fee settled.

### 2.4 Critical dependency gates
- Existing `srk_platform_fee_ledger` is electrician Platform Fee due accounting and pooled settlement; it is not a cancellation-fee ledger.
- Existing `srk_wallet_ledger` is generic and wallet top-ups/payouts are disabled. Its `adjustment` debit semantics and payout/reconciliation consumers require further audit before use.
- Existing Razorpay order/finalize RPC currently validates the booking's approved bill amount; mixed cancellation-fee component support is not proven.
- Existing refund provider workflow is labour-only. Mixed fee refunds need explicit component-level reversal and must not refund SRK cancellation fee as electrician labour.
- Therefore no cancellation-fee ledger/RPC migration should be authored/applied until all payment/refund/payout consumers and test fixtures are updated together.

## 3. Two-way ratings and reviews

### 3.1 Eligibility and uniqueness
- Only a real booking with `status='completed'`, valid assigned electrician and authoritative completion approval may be rated.
- Customer → assigned electrician: one rating per booking.
- Electrician → customer: one rating per booking.
- Each rating 1–5 integer stars; optional written review and optional dimensions (quality, punctuality, conduct/cooperation, payment/communication).
- A unique constraint on (booking_id, rater_role) enforces one rating per side. Rater identity is derived server-side, never trusted from client payload.
- Ratings are not allowed for cancelled, disputed, incomplete or unassigned bookings.

### 3.2 Proposed tables / APIs
- `srk_booking_ratings`: booking, rater user, rater role, ratee profile/user, stars, optional review and dimensions, status, timestamps, unique booking+role.
- `srk_booking_rating_moderation_events`: append-only Admin action, reason, prior/new visibility state, actor and timestamp.
- Separate customer and electrician submit/list RPCs with owner and assignment validation.
- Aggregate profile average should be derived from visible/approved ratings only; do not accept client-supplied aggregate values.
- Admin hide/remove requires a reason and audit entry. Preserve the original review for audit; no silent deletion. Valid negative criticism remains visible unless policy violation is documented.
- Anti-abuse: text length bounds, no HTML trust, rate limit, no edits that bypass one-rating rule. Any edit window policy must be decided before implementation; default v1 is immutable submission with Admin moderation only.

## 4. Customer notification preferences

### 4.1 Preferences are consent, not delivery
- Separate notification preferences from push subscription tokens and delivery records.
- Preferences should be channel- and event-specific, with essential transactional/security notices distinguished from optional promotional messages.
- No promotional channel enabled by default. Opt-in timestamp, source and policy version must be auditable.
- Customer can change preferences; update must be owner-scoped and session-safe.

### 4.2 Delivery architecture (not yet approved/configured)
- Proposed event outbox: booking accepted/status changed, electrician arrival, work start/completion, payment receipt/refund, cancellation decision, support reply.
- Outbox rows created transactionally with source event; unique event+recipient+channel key prevents duplicate notifications.
- Worker claims with leases, bounded retry/backoff, provider response IDs and terminal failure state.
- Push tokens stored separately, scoped to user/device, revocable, and never exposed to other users.
- Respect user preferences and channel consent at send time; never send secrets, full phone numbers, private address or payment credentials in notification payload.
- Provider choice, SMS/push costs, consent wording, data retention, quiet-hours/timezone and essential-notice exceptions are open implementation decisions. Do not enable a provider or send live notifications without approval.

## 5. Implementation and verification order

1. Finish cancellation request + Admin decision/evidence workflow and customer My Bookings status UI, without activating financial settlement prematurely.
2. Audit and design component-level mixed payment/refund/payout integration; then implement separate cancellation-fee receivable and carry-forward settlement with synthetic fixtures.
3. Implement two-way ratings, moderation and aggregate profile read paths.
4. Implement customer notification preferences and event outbox; only then select/configure a provider.
5. Add isolated pgTAP contracts and source regression tests for ownership, Admin authorization, idempotency, duplicate requests/ratings, immutable events, exact paise, component allocations, reversals and session changes.
6. Only after Customer App is complete proceed to Electrician Portal; Admin dependency changes are limited to the required cancellation/rating review queues.
7. Final consolidated mobile/Desktop QA after all implementation; Production changes/deployment require separate approval.

## 6. Explicitly not done
- No migration applied to Production or any connected live database.
- No booking cancelled, fee charged, wallet debited, payment/refund/payout made.
- No travel/arrival tracking, location collection, push provider, SMS provider or notification token activated.
- No rating/review submitted or moderated.
- No browser/device QA or end-to-end payment provider verification performed.
