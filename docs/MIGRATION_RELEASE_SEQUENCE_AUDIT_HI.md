# SRK ELECTRONIC — Migration Inventory एवं Release Sequence Audit

**तारीख:** 12 नवंबर 2026  
**Branch:** `feature/production-push-notifications`  
**सत्यापित HEAD:** `32f1d109116e1675d3ee47915661be962e850801`  
**स्थिति:** Feature-branch inventory और disposable CI evidence; Production migration approval नहीं।

## 1. इस audit का उद्देश्य और सीमा

इस audit में branch tree से सभी **57 SQL migration files** गिने और feature families में वर्गीकृत किए गए। इसका उद्देश्य duplicate migration families, dependency boundaries और CI coverage को स्पष्ट करना है।

यह Production की वास्तविक `supabase_migrations.schema_migrations` history का dump नहीं है और न ही Production schema पर replay का प्रमाण। इसलिए नीचे दी गई सूची को Production पर सीधे चलाने का आदेश न माना जाए। किसी migration को हटाया, rename या reorder नहीं किया गया है।

## 2. Migration inventory — 57 files

### A. Existing security, booking, location, quote और finance foundations (15)

- `20261108120608_add_public_api_rate_limiting.sql`
- `20261108120658_enable_rls_public_api_rate_limits.sql`
- `20261108121115_add_customer_account_booking_access.sql`
- `20261108233500_restrict_public_form_inserts.sql`
- `20261108234000_combine_booking_read_policy.sql`
- `20261109001000_add_google_maps_location_support.sql`
- `20261109002000_expose_assigned_booking_map_pin.sql`
- `20261109003000_secure_commission_reporting.sql`
- `20261109010000_create_secure_wallet_ledger_foundation.sql`
- `20261109020000_create_server_only_razorpay_route_transfer_ledger.sql`
- `20261109103038_customer_electrician_direct_call_contacts.sql`
- `20261109103143_move_customer_call_contact_lookup_to_private.sql`
- `20261109_allow_quote_approval_booking_states.sql`
- `20261109_electrician_inspection_quotes_and_service_only_commission.sql`
- `20261110140000_restore_missing_customer_booking_quote_columns.sql`

### B. Original timer/billing family (11)

- `202611110001_timer_billing_materials_foundation.sql`
- `202611110002_timer_billing_integrity_extensions.sql`
- `202611110003_customer_approved_timer_rpcs.sql`
- `202611110004_scoped_timer_bill_read_rpc.sql`
- `202611110005_server_authoritative_booking_creation.sql`
- `202611110006_preserve_labour_calculation_precision.sql`
- `202611110007_material_revision_customer_approval_rpcs.sql`
- `202611110008_customer_payable_snapshot_rpc.sql`
- `202611110009_razorpay_snapshot_order_ledger.sql`
- `202611110010_cash_payment_intent_receipt_confirmation.sql`
- `202611110011_repair_payable_snapshot_rounding_constraint.sql`

### C. Additional booking, push, cancellation and commission changes (6)

- `20261111082515_add_assigned_electrician_cash_payment_status.sql`
- `20261111090000_add_electrician_push_subscriptions.sql`
- `20261111120000_secure_push_subscription_upsert.sql`
- `20261111130000_customer_cancellation_admin_decision.sql`
- `20261111150000_timer_commission_cash_online_integration.sql`
- `20261111153846_srk_booking_refund_requests_workflow.sql`

### D. Forward-copy timer/billing family and its extensions (16)

- `20261111160000_timer_billing_materials_foundation.sql`
- `20261111160001_timer_billing_integrity_extensions.sql`
- `20261111160002_customer_approved_timer_rpcs.sql`
- `20261111160003_scoped_timer_bill_read_rpc.sql`
- `20261111160004_server_authoritative_booking_creation.sql`
- `20261111160005_preserve_labour_calculation_precision.sql`
- `20261111160006_material_revision_customer_approval_rpcs.sql`
- `20261111160007_customer_payable_snapshot_rpc.sql`
- `20261111160008_razorpay_snapshot_order_ledger.sql`
- `20261111160009_cash_payment_intent_receipt_confirmation.sql`
- `20261111160010_repair_payable_snapshot_rounding_constraint.sql`
- `20261111160011_customer_cancellation_admin_decision.sql`
- `20261111160012_timer_commission_cash_online_integration.sql`
- `20261111160013_guard_legacy_quote_status_paths_from_timer_bookings.sql`
- `20261111160014_keep_customer_call_contact_after_completion.sql`
- `20261111160015_timer_snapshot_refund_support.sql`

### E. Electrician identity, booking numbering, date/duration and rate catalogue (8)

- `20261112100000_permanent_electrician_display_ids.sql`
- `20261112110000_customer_booking_order_numbers.sql`
- `20261112120000_electrician_offer_order_number_rpc.sql`
- `20261112130000_customer_booking_date_only.sql`
- `20261112140000_customer_booking_duration_pricing.sql`
- `20261112150000_versioned_rate_catalogue.sql`
- `20261112160000_admin_rate_catalogue_management.sql`
- `20261112170000_public_customer_rate_catalogue_rpc.sql`

### F. Razorpay webhook event ledger (1)

- `20261112180000_razorpay_webhook_event_ledger.sql`

**Count check:** 15 + 11 + 6 + 16 + 8 + 1 = **57**.

## 3. Duplicate-family finding — do not blindly apply both families

The original timer series `202611110001`–`202611110011` and forward-copy series `20261111160000`–`20261111160010` cover overlapping objects and RPCs. Prior source comparison checked 13 pairs:

- 10 pairs were SQL-equivalent or differed only in comments/formatting.
- `20261111150000_timer_commission_cash_online_integration.sql` and `20261111160012_timer_commission_cash_online_integration.sql` are materially different; the later copy adds extra immutable payable-snapshot protection.
- Forward additions `160013`, `160014`, and `160015` add distinct legacy-path guards, completed-booking contact behavior, and timer snapshot refund support.
- The webhook event ledger migration `20261112180000` is a separate additive migration; it is not present in the earlier snapshot-order ledger migrations.

**Decision:** no duplicate migration has been deleted, renamed, or silently canonicalized. A canonical migration plan must be based on the exact target database migration history and schema, not filenames alone.

## 4. Known feature dependency order (clean disposable fixture only)

The newer booking/rate sequence has these explicit dependencies:

1. Existing `service_bookings`, `electrician_profiles`, `job_offers`, `auth.uid()`, `auth.jwt()`, and `is_srk_admin()` foundation must exist.
2. `20261112110000_customer_booking_order_numbers.sql` adds stable booking identifiers.
3. `20261112130000_customer_booking_date_only.sql` versions the server booking RPC and preserves legacy explicit-time callers.
4. `20261112140000_customer_booking_duration_pricing.sql` adds duration and server-computed estimate.
5. `20261112150000_versioned_rate_catalogue.sql` adds the append-only effective-dated catalogue and replaces the booking RPC to snapshot catalogue ID/version.
6. `20261112160000_admin_rate_catalogue_management.sql` adds Admin-only version publication and audit.
7. `20261112170000_public_customer_rate_catalogue_rpc.sql` exposes only the safe customer-facing rate view.
8. `20261112120000_electrician_offer_order_number_rpc.sql` adds the versioned offer-detail RPC that returns the non-sensitive order number.
9. `20261112100000_permanent_electrician_display_ids.sql` is a separate electrician-profile migration and requires its own profile/Auth-link fixture.
10. `20261112180000_razorpay_webhook_event_ledger.sql` is additive to webhook processing and is tested with the refund fixture.

This is not a complete 57-file global replay order. The earlier security, quote, push, commission and timer families still require a single dependency graph tied to the real target schema.

## 5. CI evidence currently available

- Timer/billing SQL workflow run **43169284161** — SUCCESS on commit `1ac783fb`. It applies the timer migration path and replay checks against disposable PostgreSQL 16 fixtures, including a Production-shaped legacy baseline. It is not a full replay of all 57 migrations.
- Refund/webhook workflow run **43169304973** — SUCCESS on commit `32f1d109`. It applies the refund/webhook ledger migration twice and passes refund SQL assertions, webhook lease/duplicate/access assertions, Node syntax checks and payment/webhook contract tests.
- Refund/webhook workflow run **43169283980** — SUCCESS on commit `1ac783fb`, including webhook ledger lease, duplicate event and access-control SQL assertions.
- Electrician display-ID workflow run **43082442370** — previously recorded SUCCESS in the feature tracker; separate PostgreSQL 16 profile/Auth fixture, migration catalog/security assertions, behavior tests and 24 concurrent issuance transactions.
- Booking order/date/rate workflow has earlier successful runs recorded in `MASTER_FEATURE_TRACKER_HI.md`; it tests the order-number, date-only, duration and rate-catalogue sequence on a disposable fixture. Re-run it against the current HEAD before treating that sequence as current-HEAD verified.

## 6. Required release-parity work before any Production change

1. Export exact Production migration history and compare it with the complete 57-file branch inventory.
2. Read-only inspect Production schema, constraints, indexes, triggers, policies, grants, function definitions and data shape for every touched object.
3. Produce a per-migration decision: already applied / safe forward migration / superseded duplicate / blocked by missing prerequisite. Never mark a migration applied merely because equivalent SQL appears elsewhere.
4. Build a disposable database from a sanitized Production-shaped baseline; replay the proposed canonical sequence from clean state and replay it a second time where idempotency is expected.
5. Preserve representative legacy bookings, quote records, commission/payout rows, electrician profile/Auth link variants and payment/refund ledger rows; assert no unintended mutation.
6. Test role matrix, RLS, function grants, SECURITY DEFINER search paths, PII visibility, date/timezone boundaries, immutable financial snapshots and concurrency.
7. Obtain separate explicit owner approval before any Production migration, live payment/provider action or website deployment.

## 7. Release decision

**NO-GO for Production.** This document records repository inventory and existing disposable-CI evidence only. No Production Supabase migration, live Razorpay operation, real-money test, Netlify Production deployment or Play Store release was performed or authorized.
