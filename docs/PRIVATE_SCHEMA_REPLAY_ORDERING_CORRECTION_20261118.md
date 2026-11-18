# Correction — Private Schema Replay Ordering Finding (2026-11-18)

## Status
The earlier report `docs/PRIVATE_SCHEMA_REPLAY_ORDERING_FINDING_20261118.md` incorrectly described a missing `private` schema prerequisite for the customer-selected rate-tier migration. This correction supersedes that specific conclusion.

## Verified source evidence
1. `supabase/migrations/20261109103143_move_customer_call_contact_lookup_to_private.sql` begins with:
   `create schema if not exists private;`
   It then creates `private.srk_get_customer_call_contacts_impl()` and grants schema usage to `authenticated`.
2. `supabase/migrations/20261114160000_customer_selected_rate_tier_and_server_estimate.sql` begins with:
   `CREATE SCHEMA IF NOT EXISTS srk_private;`
   It creates `srk_private.electrician_rate_tier_authorizations` and later creates `private.srk_offer_booking_to_eligible_electricians(uuid)`.
3. `supabase/migrations/20261118040000_atomic_electrician_payment_order_link.sql` also contains `CREATE SCHEMA IF NOT EXISTS private;`. This is idempotent, but it is not the first creation in the migration chain.
4. `supabase/migrations/20261118050000_versioned_rate_catalogue_and_multi_category_electricians.sql` later references `srk_private.electrician_rate_tier_authorizations`, which is created by the 20261114160000 migration.

## Corrected conclusion
- The source-level ordering claim that `private` is first created only in `20261118040000` is false.
- Based on the inspected source files, the `private` schema exists before the 20261114160000 migration runs.
- The `srk_private` schema is created in 20261114160000 before its authorization table is created, and before the later 20261118050000 consumer.
- This resolves the specific schema-creation ordering concern. It does **not** prove the full migration chain replays successfully; other relation, column, function, extension, or duplicate-version dependencies remain to be checked.
- No migration SQL was changed or applied. No hosted database was queried or modified. AI remains disabled.

## Verification boundary
This is a source inspection only. No disposable local Supabase replay was run as part of this correction.
