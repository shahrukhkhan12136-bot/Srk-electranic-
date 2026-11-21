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
