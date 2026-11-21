# SRK ELECTRONIC — Unified Technician Completion Cycle (Feature Branch)

Date: 21 November 2026  
Branch: `feature/master-technician-payment-cycle-20261121`  
Status: **Partially implemented — source only; not deployed**

## What this change establishes

1. A canonical `srk_technicians` identity keyed to a single Auth user where an Auth identity exists.
2. A bridge from existing `electrician_profiles` to canonical Technician IDs. Existing profile rows and IDs are retained.
3. A booking-to-Technician assignment relation that can hold multiple Technician IDs per booking and stores the service-category snapshot.
4. A per-Technician completed-booking counter and append-only completion event ledger with unique (Technician, Booking) and (Technician, ordinal) constraints.
5. Legacy single-electrician assignment writes are mirrored into the canonical assignment relation.
6. Completion events are recorded only after booking status is `completed`, completion approval is `approved`, and `customer_completed_at` is present.
7. The next completed-booking ordinal 3, 6, 9, ... requires an online/Razorpay payment method. If a cash booking reaches one of those ordinals, the completion transition and counter update roll back together.
8. A guarded authenticated RPC returns the Technician's completed count and whether the next completion requires online payment.

## Counting semantics

- Only customer-confirmed completed work increments the counter.
- Cancelled, rejected, pending, accepted, assigned, and incomplete work do not create completion events.
- Payment status is not used as a counting filter.
- Duplicate completion updates are ignored once customer-confirmed completion evidence already exists.
- Each assigned Technician on a multi-Technician booking receives one event for that booking.
- The counter row update serializes concurrent completions for the same Technician; stable Technician ordering reduces deadlock risk for multi-Technician bookings.

## Compatibility and data preservation

- Existing electrician profile rows are not dropped or rewritten.
- Existing assigned-electrician bookings are backfilled into the new assignment relation.
- Historical completion events are backfilled only where customer completion evidence exists.
- Old quote fields and financial history are not deleted by this migration.
- This migration does not alter Production or apply any database DDL.

## Remaining integration work — do not mark complete

1. The category-neutral dispatch/offer engine must create rows in `srk_booking_technician_assignments` for Plumber, Painter, AC/Fridge, Motor/Pump and Cooler bookings.
2. The shared Technician App onboarding must create/attach a canonical Technician identity for non-electrician categories and enforce one account per verified mobile.
3. Booking creation/payment-method UI must call the count RPC and guide the customer before assignment/payment; the database completion guard remains authoritative against stale UI or concurrent jobs.
4. Existing quote-dependent commission, refund and payment functions still need the separate final-labour-bill/material-approval refactor. This change does not claim quotation retirement is complete.
5. Add transactional pgTAP scenarios with fixtures for first/second/third/fourth/sixth completions, cancellation/rejection, duplicate events, multi-Technician bookings and concurrent completion attempts.
6. Run full migration replay against a disposable local/test Supabase baseline before any Production rollout.

## Test evidence

- GitHub Actions Node test suite: workflow run `44882626325` completed its Node test step successfully.
- pgTAP file added: `supabase/tests/database/unified_technician_completion_cycle.test.sql`.
- The pgTAP test has **not** been executed against a disposable PostgreSQL/Supabase database yet.
- No Production SQL, Main Branch, live payment, payout, or deployment action was performed.


## 21 November 2026 — Category-neutral integration source audit

The next integration audit inspected the feature-branch source for booking creation, application intake, the current technician portal, and sequential offer dispatch.

### Confirmed current-state findings

1. The existing customer booking API `create-booking.js` still validates only the legacy Electrician service categories (`home_wiring`, `electrical_repair`, `light_fan_fitting`, `home_repair`, `other`). It uses an Electrician-only hard-coded rate card and limits duration to 1–8 hours. It is not yet the Master System's six-category/dynamic-rate booking API.
2. The same booking API still accepts legacy quotation-related request input (`quoted_amount`) even though it writes `quoted_amount: null`. This is a compatibility residue to remove from the new request contract after payment/refund dependencies are mapped; no historical DB fields or records should be dropped blindly.
3. Booking creation relies on the existing database trigger/dispatch queue. The sequential dispatch migration uses `electrician_profiles`, `job_offers.electrician_id`, electrician-specific approved rate tiers, and the `assigned_electrician_id` field. It cannot yet dispatch to Plumber, Painter, AC/Fridge, Motor/Pump or Cooler Technician identities.
4. The current portal source is `electrician.html`, titled “Electrician Partner”, and its KYC, availability, location, offers and wallet panels call Electrician-specific RPCs. The repository root listing contains `electrician.html` but no separate Plumber/Painter/AC/Fridge/Motor/Cooler or shared Technician portal source.
5. The current public `apply-electrician.js` endpoint inserts into `electrician_applications` after IP rate limiting. It does not itself validate an authenticated Supabase OTP session or bind the application to the verified Auth user's phone. The Master System requires OTP login before the shared Technician application form. This must be corrected in the shared onboarding contract; do not expose service-role credentials or trust a client-supplied phone as proof of verification.
6. The existing electrician identity bridge is a useful legacy adapter, not the universal application/identity system. New category onboarding must link to the same canonical Technician ID using the verified Auth identity and must reject duplicate/ambiguous verified phone identities.
7. The existing dispatch flow is sequential and nearest-first, but its eligibility and candidate tables are Electrician-specific. The future generic dispatcher must preserve the existing timeout/decline/next-candidate behavior while evaluating approved status, skill/category, online availability, fresh location, work-area match, capacity and duplicate assignment for every category.

### Read-only Production schema snapshot

A read-only metadata query was also run against the Production project to inspect table columns and RPC names; no rows containing customer or technician personal data were queried.

- `electrician_applications` stores the Electrician-specific application fields (name, phone, state, district, PIN, skills, experience, status, active flag and optional coordinates). No shared Technician application table appeared in the inspected public schema.
- `electrician_profiles` stores the Electrician-specific identity, KYC/approval, skills, availability and coordinates. No general `srk_technicians` table exists in Production yet; the canonical Technician tables remain feature-branch migration source only.
- `job_offers` is keyed by `electrician_id`; `service_bookings` still has `assigned_electrician_id` and legacy quotation columns.
- The public `services` table is only a simple service-name/description/active catalogue in the inspected schema; category hierarchy, skill mapping and versioned rate configuration are not represented there.
- The inspected RPC inventory remains Electrician-named for offer response, work controls, KYC documents, availability-related workflows and payout operations. A category-neutral Technician API/RPC layer is not present in the inspected Production schema.
- Quote-related RPC names are still present in the inspected Production function inventory. Therefore the earlier migration name that retires legacy quotation RPCs must not be interpreted as proof that all quote functions and dependencies are absent.

### Integration decision

Do not add a thin category-name switch to the old Electrician API and call it complete. First establish the shared Technician application/profile and category-skill schema, then introduce a category-neutral booking contract and dispatch relation that writes to `srk_booking_technician_assignments`. Keep the Electrician tables/RPCs as compatibility adapters during migration; retain their rows and histories.

### Required next implementation sequence

1. Inspect the complete live schema definitions and all relevant RPC dependencies for `electrician_applications`, `electrician_profiles`, `service_bookings`, `job_offers`, rate approvals, availability and GPS.
2. Define a shared Technician application/profile and category-skill model, including one verified Auth identity per Technician and Admin review states (pending/under review/approved/rejected with reason).
3. Define server-authoritative category/service/rate snapshots for all six categories. Resolve the documented rate conflicts through Admin-configurable rate records; do not hard-code disputed rates into a migration.
4. Add category-neutral assignment/offer candidate and offer-response contracts, preserving existing Electrician history and adapting the legacy flow without duplicate offers.
5. Update customer booking API only after the database contract exists; enforce OTP identity, dynamic rate calculation, work-address dispatch and the every-third-completion payment rule.
6. Add integration tests for all six categories, onboarding approval gates, duplicate verified mobile, GPS eligibility, timeout/decline progression, multiple Technicians, and legacy Electrician compatibility.

### Scope and safety

This is a source-code audit plus read-only Production schema metadata inspection. No database rows were changed, no DDL or migration was applied, and no Main Branch, live payment, payout or deployment action was performed.


### Follow-up source verification — 21 November 2026

The feature-branch files were fetched directly to verify the earlier source-audit statements:

- `electrician.html` (blob `0588cfe716e1e5c47690e826bbe2bb09a0c57bed`) is explicitly titled “Electrician Partner” and its portal controls call Electrician-specific workflows.
- Root-level `apply-electrician.js` (blob `ab9cfff5f135d456df63a87623746b74a3917f3f`) accepts `full_name`, a client-submitted 10-digit `phone`, location, skills and experience, then inserts into `electrician_applications`. The handler performs IP rate limiting and input validation, but does not verify a Bearer Supabase Auth access token, call the Auth user endpoint, or bind the submitted phone to `user.phone` / `phone_confirmed_at`. This endpoint therefore must not be reused as the shared OTP-first Technician application endpoint.
- Root-level `create-booking.js` (blob `8fdc202c2451a63696ec7a42efc8559bbbbe2526`) is the canonical Netlify booking function according to the repository README. The earlier path label “create-booking.js” refers to this root-level file, not `api/create-booking.js`.
- The README confirms the current portal and application route are Electrician-specific and that `/api/create-booking` is a Netlify adapter to the root-level function.

### Safe implementation gate

No generic Technician application migration or endpoint was added in this follow-up. The shared application schema must be designed against the complete authoritative migration chain and current category/service/rate model first; otherwise it could create duplicate identity records or conflict with existing Admin review, KYC storage, and category configuration. The next implementation must use the verified Auth user as the identity source, never trust a submitted phone as OTP proof, and keep application status pending until Admin approval.

This follow-up is source inspection only. It does not change any Database, Production, Main Branch, payment, payout, or deployment state.
