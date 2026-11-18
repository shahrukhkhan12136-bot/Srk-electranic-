# Migration Replay Dependency Review — 18 Nov 2026

Branch: `feat/ai-rate-management-foundation-20261118`

## Read-only review findings

### 1. Duplicate version remains a hard replay blocker
These two migration paths share version prefix `20261109`:
- `20261109_electrician_inspection_quotes_and_service_only_commission.sql`
- `20261109_allow_quote_approval_booking_states.sql`

The latter repeats the two booking CHECK-constraint changes already included at the end of the former. The disposable local Supabase probe documented in `docs/DUPLICATE_20261109_MIGRATION_SCRATCH_EVIDENCE_20261118_HI.md` reproduced the migration-ledger primary-key collision. Neither migration file was changed in this review.

### 2. amount_paid clean-replay ordering risk
The checked-in consolidated baseline `COMPLETE_DATABASE_SETUP.sql` creates `public.service_bookings` without an `amount_paid` column.

However:
- `supabase/migrations/20261109003000_secure_commission_reporting.sql` defines SQL function bodies that select `service_bookings.amount_paid` and grants column-level UPDATE on `amount_paid`.
- `supabase/migrations/20261116200000_restore_service_bookings_amount_paid.sql` adds `amount_paid`, but has a later version.

On a clean migration replay that uses the checked-in baseline shape and does not already have the column, the commission-reporting migration may fail while creating/parsing its SQL function or applying the column-level grant, before the later restore migration can add the column. This is a source-order dependency finding, not a live database observation.

### 3. Quote workflow dependencies
The quote migration references existing schema objects including:
- `service_bookings.assigned_electrician_id`, `customer_user_id`, `amount_paid`, `commission_rate`, `commission_amount`, and `quoted_amount`
- `electrician_profiles.user_id`, `verification_status`, and `active`
- `job_offers`

The consolidated setup includes some but not all of those columns: it has `assigned_electrician_id`, `commission_rate`, `commission_amount`, `quoted_amount`, and `job_offers`; it does not show `customer_user_id`, `electrician_profiles.user_id` is added later in its portal section, and it does not create `amount_paid`. Other migrations may supply missing columns, but the complete ordered chain has not yet been validated.

## Safe gate
1. Do not edit, rename, delete, merge, or reorder migrations until authoritative hosted migration-history evidence is obtained with owner authorization.
2. Build a complete dependency matrix from all migration files and baseline/setup artifacts.
3. Run a full replay only in disposable local Supabase using the exact supported baseline and ordered migrations, then add targeted pgTAP assertions.
4. Do not query or modify hosted projects as part of this review.

No database was connected to or changed. No migration was applied. AI remains disabled.
