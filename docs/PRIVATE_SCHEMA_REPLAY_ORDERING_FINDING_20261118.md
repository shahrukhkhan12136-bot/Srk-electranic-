# Migration Replay Follow-up — Private Schema Ordering — 18 Nov 2026

Branch: `feat/ai-rate-management-foundation-20261118`
Reviewed HEAD: `4fde1185f713fded84962f8c2d10eaf8cfb9ffb0`

## Finding: `private` schema is referenced before its explicit creation

### Source evidence
1. `supabase/migrations/20261114160000_customer_selected_rate_tier_and_server_estimate.sql` creates `srk_private` at line 3, but later defines `private.srk_offer_booking_to_eligible_electricians(uuid)` (around line 66). It does not create the separate `private` schema.
2. `supabase/migrations/20261118040000_atomic_electrician_payment_order_link.sql` explicitly runs `CREATE SCHEMA IF NOT EXISTS private` at the beginning.
3. The consolidated setup files `COMPLETE_DATABASE_SETUP.sql` and `SUPABASE_SCHEMA.sql` contain no explicit `CREATE SCHEMA ... private` statement.

### Assessment
On a clean PostgreSQL database where `private` has not been provisioned by the platform or another earlier script, migration `20261114160000` can fail when it attempts to create a function in the missing schema. The later `20261118040000` creation is too late to satisfy that earlier dependency.

This is a source-level ordering risk. No clean replay was run to confirm the exact failure, and no hosted schema was inspected. Do not assume the schema is absent in an existing hosted project.

### Required validation
- Check the exact disposable local Supabase baseline and confirm whether it pre-creates `private`.
- If it does not, validate a source-only correction that creates `private` before the first function declaration (or moves the schema creation into the earliest prerequisite migration).
- Re-run the full ordered migration replay only in disposable local Supabase.
- Preserve the separate `20261109` duplicate-version blocker and `amount_paid` ordering concern; resolving one does not resolve the others.

## Safety
No migration source was modified. No hosted database was queried or changed. No migration was applied. AI remains disabled.
