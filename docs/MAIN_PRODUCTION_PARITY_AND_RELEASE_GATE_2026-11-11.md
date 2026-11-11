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


## Production catalog verification update — 2026-11-11

The following catalog checks were run read-only against Main Production after the CI correction:

- Main Production migration history ends at `20261111142316`.
- The timer release objects are absent: `srk_final_bills`, `srk_bill_material_revisions`, `srk_bill_material_items`, `srk_booking_payable_snapshots`, `srk_razorpay_orders`, `srk_razorpay_payments`, `srk_cash_payment_intents`, `srk_cash_receipts`, and `srk_booking_cancellation_requests`. Timer RPCs and cancellation RPCs are also absent.
- Push subscription state is already present in Production: `srk_push_subscriptions` exists with RLS enabled and four owner-scoped authenticated policies (select/insert/update/delete). `public.srk_save_push_subscription` is SECURITY INVOKER and delegates to `private.srk_save_push_subscription`, which is SECURITY DEFINER with an empty search_path and authenticated-only execution. Therefore do not replay the branch's older push table/upsert migrations as part of the timer release.
- Production `service_bookings` has the exact existing legacy columns through `electrician_quote_kind`; timer-specific category, rate, arrival, timer-state, timestamp and final-bill columns are not yet present. Existing defaults include status `new`, payment status `unpaid`, payment method `Cash`, materials amount `0`, and commission rate `15.00`.
- The existing `service_bookings` trigger graph includes `a_guard_booking` (BEFORE INSERT), `broadcast_new_booking`, `srk_audit_service_bookings`, `srk_calculate_booking_commission`, `srk_cancel_booking_job_offers`, `srk_log_service_booking_status`, and `trg_srk_create_electrician_payable`. The insert guard forces new rows to `new` / `unpaid` / unassigned and resets the commission snapshot to 15%; assignment must happen later through the offer acceptance transition.
- The exact `service_booking_status_history` columns are `id`, `booking_id`, `old_status`, `new_status`, `note`, `changed_by`, and `changed_at`.
- The existing `srk_electrician_payouts` table has no timer settlement/remittance columns yet, has an audit trigger, and currently contains zero rows. The timer integration migration will extend this existing table and replace its payable/commission trigger function; this remains a high-risk compatibility point requiring a Production-shaped fixture before release.
- The legacy payout trigger currently runs after insert/update of payment/status/quote/service-charge/material/assignment/payment-verification/Razorpay-payment/amount-paid fields on `service_bookings`. Preserve and test this legacy path when introducing the timer snapshot branch.

## Latest CI correction

GitHub Actions run `43042109731` passed on commit `699e72c7f494fec865d08196838132b38575bebf`. All 45 PostgreSQL workflow steps completed successfully, including Cash receipt end-to-end, material proposal/customer approval, cancellation/Admin decision, 15% labour-only commission, legacy unpaid booking preservation and rollback-only arithmetic. The prior Cash test failure was fixed by removing an invalid attempt to insert into a nonexistent `electrician_applications(user_id,status,active)` shape in the synthetic material fixture; the actual Production application table uses a different schema. The database RPC authorization checks were not weakened.

This successful run still uses the intentionally synthetic harness. It is not a full Production schema replay, real Supabase Auth/RLS runtime test, browser E2E, or Razorpay provider test.

## Forward-only migration sequencing decision

Do not rename or mark the historical migration files as applied. Prepare a new, separately reviewed release sequence with versions strictly greater than `20261111142316`. The timer foundation and dependent migrations must be replayed in dependency order, followed by cancellation and the commission integration. Exclude/reconcile the already-present push subscription and push upsert migrations rather than duplicating their effects. Before creating this sequence, validate every migration against a disposable fixture that reproduces the actual Production `service_bookings` columns, trigger graph, payout table and status-history table, with representative legacy rows. The existing CI harness is not yet that fixture.
