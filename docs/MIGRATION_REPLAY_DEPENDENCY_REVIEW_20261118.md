# Migration Replay Dependency Review — 18 Nov 2026

Branch: `feat/ai-rate-management-foundation-20261118`
Reviewed HEAD: `2ef5263ec23b94869ce2203254860c9fc6324a62`

## Read-only review findings

### 1. Duplicate version remains a hard replay blocker
These two migration paths share version prefix `20261109`:
- `20261109_electrician_inspection_quotes_and_service_only_commission.sql`
- `20261109_allow_quote_approval_booking_states.sql`

The second file repeats the two booking CHECK-constraint replacements already present at the end of the first file (four SQL statements: drop/add the status constraint and drop/add the assignment constraint). This is confirmed source-level redundancy. The disposable local Supabase probe documented in `docs/DUPLICATE_20261109_MIGRATION_SCRATCH_EVIDENCE_20261118_HI.md` reproduced the migration-ledger primary-key collision. Neither migration file was changed.

### 2. Test-project migration history does not reconcile the application branch
A read-only Supabase MCP migration-history query was performed against the project named `SRK ELECTRONIC TEST`, after confirming its status was `ACTIVE_HEALTHY`.

It returned seven versions:
- `20261110201406`
- `20261110212412`
- `20261111044944`
- `20261111051234`
- `20261111054608`
- `20261111060036`
- `20261111071759`

All seven are push-notification test migrations. None matches the 103 migration version prefixes in the feature branch. Therefore this project's migration history is not evidence of the application's hosted migration history and cannot establish whether either `20261109` file was previously applied in the actual app project.

### 3. amount_paid clean-replay ordering risk
The checked-in consolidated baseline `COMPLETE_DATABASE_SETUP.sql` creates `public.service_bookings` without an `amount_paid` column.

However:
- `supabase/migrations/20261109003000_secure_commission_reporting.sql` defines SQL function bodies that select `service_bookings.amount_paid` and grants column-level UPDATE on `amount_paid`.
- `supabase/migrations/20261116200000_restore_service_bookings_amount_paid.sql` adds `amount_paid`, but has a later version.

On a clean migration replay that uses the checked-in baseline shape and does not already have the column, the commission-reporting migration may fail while creating/parsing its SQL function or applying the column-level grant, before the later restore migration can add the column. This is a source-order dependency finding, not a live database observation.

### 4. Quote workflow dependencies
The quote migration references existing schema objects including:
- `service_bookings.assigned_electrician_id`, `customer_user_id`, `amount_paid`, `commission_rate`, `commission_amount`, and `quoted_amount`
- `electrician_profiles.user_id`, `verification_status`, and `active`
- `job_offers`

The consolidated setup includes some but not all of those columns: it has `assigned_electrician_id`, `commission_rate`, `commission_amount`, `quoted_amount`, and `job_offers`; it does not show `customer_user_id`, `electrician_profiles.user_id` is added later in its portal section, and it does not create `amount_paid`. Other migrations may supply missing columns, but the complete ordered chain has not yet been validated.

## Safe gate
1. Do not edit, rename, delete, merge, or reorder either legacy migration until authoritative read-only migration-history evidence for the actual application Supabase project is obtained with owner authorization.
2. The push-notification test project's seven migration records are not a substitute for the application's migration ledger.
3. Build a complete dependency matrix from all migration files and baseline/setup artifacts.
4. Run a full replay only in disposable local Supabase using the exact supported baseline and ordered migrations, then add targeted pgTAP assertions.
5. Do not query or modify the actual application/production hosted project without separate explicit authorization.

No migration was applied. No hosted schema or data was changed. The only hosted database operation in this review was the read-only migration-list query against the test project. AI remains disabled.
