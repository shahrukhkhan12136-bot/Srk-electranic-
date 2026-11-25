# Main Supabase migration source reconciliation — 2026-11-25

## Authoritative ledger and recovered archive

- Main project: `gnqhoaqatmoiwwhgzkgm`.
- Live Main migration ledger: 539 versions.
- Recovered source archive: 22 JSON chunks, 539 rows, 539 non-empty SQL statement items, 2,073,329 SQL characters.
- Reconstructed files: 539/539, each named `<version>_<name>.sql` under `supabase/migrations_recovered/`.
- `manifest.csv` maps each recovered version/name/path to its Git blob SHA.
- No migration was applied to Main and no migration history row was changed.

## Comparison against the 11 previously inspected Git refs

| Git ref | SQL files | Distinct filename versions | Main version overlaps | Byte-identical body hashes |
|---|---:|---:|---:|---:|
| `main` | 22 | 21 | 5 | 0 |
| `work/mobile-customer-technician-integration-20261125` | 120 | 119 | 22 | 6 |
| `work/admin-worker-payout-web-integration-20261125` | 105 | 104 | 10 | 0 |
| `feat/ai-rate-management-foundation-20261118` | 127 | 126 | 7 | 0 |
| `feature/master-customer-workday-ui-20261121` | 110 | 109 | 7 | 0 |
| `feature/master-technician-payment-cycle-20261121` | 102 | 101 | 7 | 0 |
| `chore/pr8-replay-audit-20261116-v2` | 100 | 99 | 7 | 0 |
| `feature/electrician-categories-hourly-booking` | 17 | 16 | 5 | 0 |
| `work/separate-customer-electrician-portals` | 37 | 36 | 11 | 0 |
| `feature/platform-fee-cash-online-cycle` | 66 | 66 | 12 | 0 |
| `feature/production-push-notifications` | 61 | 60 | 7 | 0 |

The union of those refs contains 289 distinct filename versions. Exactly 40 versions overlap the 539-version Main ledger; 499 Main versions were absent from those Git refs. Among the overlapping versions, six exact Git blob matches were found, all on the mobile integration branch. The other overlapping copies have different blob hashes and must not be assumed equivalent.

### Exact body matches found

- `20261125102825_add_clean_admin_service_pricing_update_rpc.sql`
- `20261125112825_secure_worker_booking_reads_and_contact_visibility.sql`
- `20261125112828_labour_only_customer_billing.sql`
- `20261125113624_worker_registration_policy_consent_gate.sql`
- `20261125113720_admin_policy_document_list_rpc.sql`
- `20261125114307_one_worker_session_per_booking_day.sql`

## Replay blockers and next steps

1. Recovered source is now complete as an archive reconstruction, but the canonical `supabase/migrations/` directory is not replaced.
2. The original pre-migration baseline is still required. The live schema includes objects that may have been created before or outside the 539 recorded migrations.
3. Compare every recovered source file with any trusted deployment artifact and record provenance.
4. Reconcile existing short-version filenames, duplicate version prefixes, branch-only migrations and dependency ordering.
5. Build a disposable local PostgreSQL baseline with required Supabase Auth/Storage roles, extensions and schemas; replay all 539 files in original Main ledger order.
6. Run schema, function, RLS, trigger, constraint and application-contract tests against the clean-room database.
7. Only after replay and reconciliation succeed should a separate PR propose a canonical migration-directory replacement.

**Status:** SQL archive recovery complete. Canonical migration reconciliation, baseline reconstruction and clean-room replay remain blocked/in progress. Do not call the database fully reproducible yet.
