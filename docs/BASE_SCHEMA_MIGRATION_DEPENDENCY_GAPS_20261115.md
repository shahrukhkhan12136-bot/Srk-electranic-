# Base Schema → Migration Dependency Gap — 2026-11-15

## Confirmed starter-schema baseline
Reviewed the historical starter artifacts on branch
`feature/platform-fee-cash-online-cycle`:

- `SUPABASE_SCHEMA.sql` defines `public.service_bookings` with
  `quoted_amount numeric(12,2)`, payment status, Razorpay identifiers and
  `payment_verified_at`; it does **not** define `amount_paid`.
- The same file defines `public.electrician_profiles` with profile identity,
  application link, display/contact/location/status fields; it does **not**
  define `auth_user_id`.
- `PORTAL_SCHEMA.sql` adds
  `electrician_profiles.user_id uuid unique references auth.users(id)
  on delete set null` and an index on `user_id`. It does **not** add
  `auth_user_id`.
- The starter files were added together in commit
  `c4b6a46f22553e57638cdae844ec33d09bf8da2c`.

## Downstream dependency evidence
- Razorpay verification commit
  `d7c7fc9800141195023453c7781d34b7e03bdc41` writes the captured amount
  into `service_bookings.amount_paid`.
- Razorpay webhook commit
  `1983b7334dfcd138ecc3dcf0f920b81ddfe671ee` also writes
  `amount_paid`.
- Migration `20261109003000_secure_commission_reporting.sql` reads
  `amount_paid` for commission reporting and grants Admin column-level
  UPDATE permission for it.
- Migration `20261109001000_add_google_maps_location_support.sql`
  inserts both `user_id` and `auth_user_id` into
  `electrician_profiles`; it adds location columns but does not declare
  `auth_user_id`.
- Migration `20261109010000_create_secure_wallet_ledger_foundation.sql`
  reads `coalesce(ep.auth_user_id, ep.user_id)`.
- Historical alternate-branch identity-sync code also writes both IDs,
  without defining `auth_user_id`.

## Dependency graph and blocking gates

| Object | Baseline | Downstream dependency | Required evidence before repair |
|---|---|---|---|
| `service_bookings.amount_paid` | Missing from starter table | Razorpay verification/webhook, commission, refunds, receipts, accounting | Authoritative type/precision, nullability/default, constraints/indexes/grants, introducing deployment artifact |
| `electrician_profiles.auth_user_id` | Missing from starter table and PORTAL_SCHEMA | Admin approval, wallet identity, SOS ownership, historical RLS | Authoritative type, FK/on-delete, nullability/default, uniqueness/indexes/grants, introducing deployment artifact |

## Safe engineering decision
1. Do not infer `amount_paid` as `numeric(12,2)` merely because
   `quoted_amount` uses that type; the two columns may have different
   contracts.
2. Do not infer `auth_user_id` is identical to `user_id`; historical
   usage does not establish whether it is an alias, a separate FK, or a
   migration-era compatibility field.
3. Keep the dependent migrations blocked from a clean-baseline replay until
   the original deployment SQL or an approved schema-only catalog export is
   available.
4. Do not modify Production, migration history, or shared GPT-1 files.
5. PostgreSQL/pgTAP runtime remains unexecuted; this is static source
   dependency analysis, not database parity verification.

## Result
This records a concrete baseline-to-consumer dependency gap and narrows the
next evidence request. It does not close a delivery checklist item or change
the project completion percentages.


## Additional source check — 15 Nov 2026, 18:23 UTC
- Current Feature Branch की तीनों consolidated/base SQL files (`SUPABASE_SCHEMA.sql`, `PORTAL_SCHEMA.sql`, `COMPLETE_DATABASE_SETUP.sql`) को पूरे content में दोबारा जाँचा। तीनों में `amount_paid` और `auth_user_id` का कोई occurrence/DDL नहीं मिला।
- Repository commit search में `amount_paid` के केवल दो introducing application-consumer commits मिले: `d7c7fc9800141195023453c7781d34b7e03bdc41` और `1983b7334dfcd138ecc3dcf0f920b81ddfe671ee`; ये payment amount लिखने वाले commits हैं, schema DDL नहीं। `auth_user_id` के नाम से कोई introducing commit नहीं मिला।
- यह check तीन checked-in schema files और searchable commit history तक सीमित है; GitHub connector की repository code search default branch तक सीमित है। इसे सभी deleted refs, unreachable Git objects या remote database history की exhaustive proof नहीं माना जा रहा।
- Safe outcome अपरिवर्तित: missing column types/constraints अनुमान से नहीं बनाए जाएँगे। अगला निर्णायक प्रमाण owner-approved schema-only export/original deployment SQL या authorized migration-history evidence है।


## Correction — `auth_user_id` source DDL found (15 Nov 2026, 18:25 UTC)

A direct read of the current Feature Branch migration file `supabase/migrations/20261109000500_harden_electrician_profile_identity_linking.sql` found the authoritative column addition that the earlier search had missed:

```sql
ALTER TABLE public.electrician_profiles
  ADD COLUMN IF NOT EXISTS auth_user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL;
```

- The column is `uuid`, nullable by default, has no explicit default, and references `auth.users(id)` with `ON DELETE SET NULL`.
- The same migration checks conflicts/duplicate links, synchronizes `user_id` and `auth_user_id`, and creates a partial unique index on non-NULL `auth_user_id`.
- It is versioned `20261109000500`, before the `20261109001000` Google Maps migration that writes both columns. The later `20261114130000_harden_electrician_profile_identity_linking.sql` repeats the `ADD COLUMN IF NOT EXISTS` defensively.
- Therefore `auth_user_id` is **not an unresolved source-DDL blocker** on the current Feature Branch. Previous statements in this document that said its introducing DDL was missing are superseded by this correction. The historical starter schema still lacks the column, but the migration chain supplies it.

### Remaining confirmed source-DDL gap
`service_bookings.amount_paid` remains absent from the three checked-in base schema files and no authoritative introducing `ADD COLUMN`/`CREATE TABLE` source has been identified. This is now the one confirmed missing-column source blocker. Do not guess its type, precision, nullability, default, constraints, indexes, or grants.
