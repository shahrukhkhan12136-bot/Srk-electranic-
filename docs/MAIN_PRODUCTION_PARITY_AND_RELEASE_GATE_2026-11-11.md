# Main Production ↔ Feature Branch parity and release gate

Date: 2026-11-11
Scope: SRK ELECTRONIC customer booking, four labour categories, arrival, customer-approved timer, final bill, materials, Cash/Online settlement, commission and complaints.

## Current database comparison

### Main Production — `gnqhoaqatmoiwwhgzkgm`

- Active, healthy Supabase project in ap-south-1.
- Existing application data remains in `service_bookings`, `electrician_profiles`, `electrician_applications`, `job_offers`, wallet, payout, payment, refund, complaint, audit and push-subscription tables.
- The obsolete, empty legacy tables `public.electricians`, `public.bookings`, and `public.booking_status_history` were removed in a guarded transaction. The migration is recorded as `20261111142316_retire_empty_legacy_electrician_booking_tables`.
- Post-change catalog verification confirmed those three relations are absent and the active `service_bookings` and `electrician_profiles` relations remain.
- Existing customer/electrician/booking/wallet/payment history was not deleted as part of this table cleanup.
- Production currently has no timer/final-bill/material-revision/payable-snapshot/Razorpay-snapshot-order/cash-receipt tables from the Feature Branch timer release. Therefore the new timer system is not yet active in Production.
- A completed-but-unpaid legacy booking and its associated profile/offer/wallet records were deliberately preserved. No payment was fabricated and no payout was generated.

### Shared TEST — `dvzmarekhstaubyuoeeh`

- Active, healthy Supabase project in ap-south-1.
- It currently contains only three public tables: `electrician_profiles`, `job_offers`, and `srk_push_subscriptions`.
- Its seven migrations and limited schema support push-notification tests only; it is not a clone or full integration environment for Main Production.
- Do not apply the full timer/payment migration set to this shared TEST project: doing so would create an incomplete hybrid and would not prove compatibility with Production triggers, policies, constraints or legacy records.

## Four-category rate contract

The customer form and server-authoritative booking RPC both use these exact category codes and rates:

| Code | Category | 8-hour reference | Hourly snapshot |
|---|---|---:|---:|
| helper | Helper | ₹899 | ₹112.375 |
| ordinary | Ordinary | ₹1,199 | ₹149.875 |
| skilled | Skilled | ₹1,599 | ₹199.875 |
| master | Master | ₹1,999 | ₹249.875 |

The browser submits only the category code. The database RPC maps it to the label and hourly rate and stores an immutable booking snapshot. Labour and materials remain separate.

## Feature Branch implementation already present

- Customer OTP login and customer-owned booking list.
- Four category choices in the booking form.
- Server-side booking creation with category/rate snapshot and idempotency.
- Customer and electrician timer UI, scoped timer read RPC, arrival/start/stop requests, customer approval/rejection and server-generated final labour bill.
- Separate material proposal and customer approval UI/RPC.
- Immutable payable snapshot creation.
- Razorpay order/payment ledger and snapshot-bound serverless handlers.
- Customer Cash selection and assigned-electrician receipt confirmation.
- Cancellation request and Admin decision with ₹99 eligibility rule.
- Admin timer/material/payment audit display.
- Labour-only 15% commission integration and separate Cash commission-remittance state.

These are Feature Branch implementation claims, not evidence that the same objects are live in Production or that provider-side payment was tested.

## CI evidence

GitHub Actions run `43039281805` completed successfully on commit `1168e6bd9b5aa559fb71a0d3574f5b8019ba0747`.

- Customer, electrician and Admin inline JavaScript syntax checks passed.
- Payment handler and Netlify adapter syntax checks passed.
- PostgreSQL 16 disposable synthetic harness applied and replayed the timer, category, material, payable, Cash, cancellation and commission migrations.
- Timer lifecycle, category-rate, payment/receipt, cancellation, commission and legacy unpaid-booking preservation assertions passed.

This CI harness is intentionally synthetic/minimal. It does not contain the full Production schema, full Production trigger graph, actual Supabase Auth/RLS runtime, browser E2E, or a real Razorpay Test Mode transaction. It is not a Production compatibility sign-off.

## Release blockers that must be resolved before Main Production migration

1. **Migration history ordering:** Main Production's latest recorded migration is `20261111142316`. Several timer migrations in the branch use earlier versions `202611110001` through `202611110011`, and the cancellation migration is `20261111130000`. A normal forward-only Supabase migration push cannot safely apply these pending files after the newer Production history. Do not blindly run `db push`, repair migration history, or mark migrations applied without a verified consolidated forward migration plan.
2. **Duplicate/past migration identities:** Production has duplicate-name migration entries for `add_assigned_electrician_cash_payment_status` at versions `20261111082515` and `20261111083811`. Branch also has push-subscription migration files whose effects already exist in Production under different recorded versions. Reconcile source migration files with actual catalog state before generating a release sequence.
3. **Production schema compatibility:** Build a disposable PostgreSQL fixture from an authoritative Production schema snapshot, including relevant tables, constraints, indexes, RLS, grants, triggers, functions and representative legacy rows. Run the complete forward migration sequence twice and test failure/rollback behavior there.
4. **Legacy caller cutover:** Audit all callers and database paths for legacy quote/work-status/payment flows. Keep legacy history readable, but ensure new timer-category bookings cannot fall through old work-status, quote, generic Admin update, or legacy payment routes.
5. **Runtime and E2E:** Test customer OTP, booking, offer broadcast/acceptance, phone visibility after acceptance, arrival, customer-approved timer start/stop, labour calculation, materials revision approval, Cash receipt, Razorpay Test Mode checkout/signature/webhook replay, refunds/disputes and complaint history.
6. **Provider readiness:** Razorpay Test Mode order/capture/webhook and Route behavior are not yet verified end-to-end. Do not claim automatic split transfers or actual ₹99 cancellation fee collection.
7. **Release/deployment:** Prepare one coordinated database + Netlify release package, verify environment variables and deployment capacity, and perform a single production rollout only after the release gates pass and the user explicitly confirms the final release.

## Latest source correction

The customer booking page previously retained the same idempotency key after a successful booking. A second booking from the same page could therefore replay the first booking instead of creating a new one. This was fixed in commit `1168e6bd9b5aa559fb71a0d3574f5b8019ba0747`: the key is cleared only after the server confirms a successful booking, while failed submissions retain the key for safe retry. The above CI run passed after this correction.

## Safety decisions

- Keep the three empty legacy tables retired.
- Keep `service_bookings`, `electrician_profiles`, application, accepted-offer, wallet, payout, complaint, payment/refund and audit records unless a row-level review proves a test record is safe to remove.
- Never infer that an unpaid record is a successful payment.
- Never delete an Auth user or customer record as part of broad schema cleanup.
- No timer/payment migrations have been applied to Production in this release cycle.
- No Production website deployment has been made.
