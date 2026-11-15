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


## Follow-up historical branch and CI check — 15 Nov 2026, 18:30 UTC
- Historical refs पर उपलब्ध starter schema की जाँच दोहराई: `main`, `feature/platform-fee-cash-online-cycle`, `safe-payment-refund-implementation`, और `work/separate-customer-electrician-portals` में `SUPABASE_SCHEMA.sql` का blob SHA समान `8ae88a7035bc963b244f22c6c1450c22618ec88f` है; चारों में `amount_paid` नहीं मिला। `feature/business-finance-dashboard` के `COMPLETE_DATABASE_SETUP.sql` में भी इसका उल्लेख नहीं मिला।
- Repository commit search में `amount_paid` के लिए दो application-consumer commits ही मिले; कोई matching schema-introduction commit नहीं मिला। GitHub code search default branch तक सीमित है, इसलिए यह सभी historical/deleted/unreachable objects की exhaustive जाँच नहीं है।
- नवीनतम PR head `2b08300e374f3a7c06e9e3d656b0165e6bd5f216` पर run `43746918575` completed success; job `132912152246` logs: 189 tests, 189 pass, 0 fail, 0 skipped। उसी SHA का दूसरा run `43746922357` उस समय pending था।
- निष्कर्ष अपरिवर्तित: `auth_user_id` migration-chain DDL से covered है; `service_bookings.amount_paid` एकमात्र confirmed missing source-DDL gap है। No guessed DDL, no Production access or migration, no merge/deployment.


## Superseding status — latest verified CI, 15 Nov 2026, 18:32 UTC
- Latest PR head `659cd151fdf83779261bed034517b92b90d4a240` run `43747168727` completed successfully. Node job `132912932723`: 189 tests, 189 pass, 0 fail, 0 skipped.
- Earlier row in this document listing `electrician_profiles.auth_user_id` as a missing source-DDL blocker is historical and superseded by the correction above: current migration chain defines it. The sole confirmed missing source-DDL item remains `service_bookings.amount_paid`.
- This remains Node-only CI evidence, not PostgreSQL/pgTAP execution, complete migration replay, Production parity, or deployment.


## Additional historical-ref and root SQL artifact sweep — 15 Nov 2026, 18:35 UTC
- Checked six additional branches: `feature/direct-upi-commission-15`, `fix/admin-payout-reference-correction`, `predeploy/verified-electrician-booking-match`, `fix/admin-activation-rpc-and-readme-20261113`, `feature/electrician-categories-hourly-booking`, and `feature/customer-homepage-menu`.
- Every one has the same `SUPABASE_SCHEMA.sql` blob `8ae88a7035bc963b244f22c6c1450c22618ec88f` and `COMPLETE_DATABASE_SETUP.sql` blob `2b806e727f449ba18e71ad23edef805ceb2da2b5`; neither contains an authoritative `service_bookings.amount_paid` column definition.
- Inspected historical `work/separate-customer-electrician-portals` payment/refund/finance migrations and root SQL artifacts (`PORTAL_SCHEMA.sql`, `PORTAL_SECURITY_UPDATE.sql`, `ADMIN_EMAIL_LOGIN_SETUP.sql`, `COMPLETE_DATABASE_SETUP.sql`). They consume `amount_paid` or configure RLS, but no `ADD COLUMN amount_paid` / column declaration was found in these checked artifacts.
- This expands checked-in branch/artifact evidence but is not proof about unreferenced Git objects, deleted refs, deployment SQL, or the live database. No Production schema or migration history was queried.
- Required next evidence remains owner-provided original deployment SQL or an explicitly approved schema-only export. Do not infer type/default/nullability/precision or write a guessed migration.


### 2026-11-15 18:42 UTC — amount_paid commit-diff verification
- Repository-scoped GitHub commit search को exact terms `amount_paid`, `service_bookings amount_paid`, `ADD COLUMN amount_paid`, `service_bookings payment amount`, और `captured payment service_bookings` के साथ दोहराया। केवल दो matching commits मिले: `d7c7fc9800141195023453c7781d34b7e03bdc41` और `1983b7334dfcd138ecc3dcf0f920b81ddfe671ee`।
- दोनों commit diffs सीधे fetch करके जाँचे: पहला Razorpay verify-payment PATCH में captured provider amount को `amount_paid` में लिखता है; दूसरा captured webhook handler में यही field लिखता है। दोनों application consumers/writers हैं, CREATE/ALTER TABLE DDL नहीं।
- इस खोज से source-DDL blocker हल नहीं हुआ। GitHub commit search matching commits का प्रमाण है, सम्पूर्ण unreachable/deleted Git object या external deployment history का नहीं।
- कोई अनुमानित DDL नहीं जोड़ा; Production schema/catalog/history query नहीं की; कोई payment/refund/transfer, migration apply, merge या deployment नहीं हुआ।


### 2026-11-15 18:43 UTC — documentation commit CI verification
- Commit `cd578ba701a32df713833d9172ca11b3f57515b6` पर GitHub Actions run `43748278987` completed `success`; job `132916319445` completed `success`।
- Decoded job log में Node test summary: 189 tests, 189 pass, 0 fail, 0 cancelled, 0 skipped।
- Scope केवल Node regression suite है। इससे PostgreSQL/pgTAP execution, complete migration replay, Production schema parity, payment-provider settlement, या deployment प्रमाणित नहीं होते।
- कोई migration apply, Production परिवर्तन, payment/refund/transfer, merge या deployment नहीं हुआ।


### 2026-11-15 18:44 UTC — root schema path history and latest branch CI
- GitHub path history for root `SUPABASE_SCHEMA.sql` and `COMPLETE_DATABASE_SETUP.sql` each returns only the original upload commit `c4b6a46f22553e57638cdae844ec33d09bf8da2c`; no later checked-in revision of either root artifact exists in the path history.
- Repository commit search for `amount_paid` again returned only the two already-reviewed application writer commits; search for `service_bookings` returned no additional commit matches. This narrows visible commit history but does not inspect unreachable Git objects, deleted refs, external backups, or deployment artifacts.
- New PR branch head `456027f0f6f5e94d205077589d140e071e8c9e9c` (GPT-1 runtime acceptance matrix documentation) has GitHub Actions run `43748410761`, job `132916731999`, completed success. Decoded log: 189 tests, 189 pass, 0 fail, 0 skipped. Node regression only; no PostgreSQL/pgTAP/full migration replay/Production parity evidence.
- No DDL guessed or added; no Production schema/history query, migration apply, payment/refund/transfer, merge, or deployment. The sole confirmed missing source-column DDL remains `service_bookings.amount_paid`.


### 2026-11-15 18:46 UTC — exact source-column and branch-head recheck
- Root `SUPABASE_SCHEMA.sql` (4,931 bytes) और `COMPLETE_DATABASE_SETUP.sql` (21,482 bytes) के पूरे contents में `service_bookings` table declaration और आसपास के schema को फिर पढ़ा। दोनों में `amount_paid` column declaration नहीं है।
- Quote migration `20261109_electrician_inspection_quotes_and_service_only_commission.sql` की पूरी 9,568-byte body जाँची: ALTER में service_charge/materials_amount/quote/work columns हैं; `amount_paid` केवल trigger function में पहले से मौजूद NEW field की तरह consume होता है। यह introducing DDL नहीं।
- Exact code-search queries `ADD COLUMN amount_paid`, `ADD COLUMN IF NOT EXISTS amount_paid`, `service_bookings.amount_paid`, `amount_paid numeric`, `amount_paid decimal` में कोई authoritative column-definition result नहीं मिला। Search index current default branch snapshot पर आधारित है; इसे पूर्ण Git object database का प्रमाण नहीं माना जा सकता।
- PR #8 वर्तमान में Open + Draft + Unmerged है; head `8a3f95aca92c9d3f06cd0e2785cc3bb34c31b091`, base `main`। कोई merge/deploy नहीं।
- इसी head का Node CI run `43748576900`, job `132917235441`, completed success: 189 tests, 189 pass, 0 fail, 0 cancelled, 0 skipped। यह Node regression मात्र है; PostgreSQL/pgTAP, full migration replay, Production parity या deploy प्रमाण नहीं।
- शेष confirmed source gap अब भी केवल `service_bookings.amount_paid` का introducing DDL है। अगला सुरक्षित evidence path: owner-provided original deployment SQL या अलग से explicitly approved schema-only export; अनुमानित migration नहीं बनाई जाएगी। No Production query/change, migration apply, payment/refund/transfer, merge or deployment.


## Superseding source-status correction — 16 Nov 2026

Current Feature Branch में `supabase/migrations/20261116200000_restore_service_bookings_amount_paid.sql` मौजूद है। यह `public.service_bookings.amount_paid numeric(12,2)` nullable column जोड़ती है और nonnegative CHECK को `NOT VALID` बनाती है। इसलिए पुराने इस दस्तावेज़ के वे कथन कि current branch में amount_paid का introducing DDL नहीं मिला, historical हैं और अब superseded हैं।

अब ज्ञात missing-column source-DDL gap के रूप में `amount_paid` को सूचीबद्ध न करें। इससे live database पर column मौजूद होना, पुराने rows का CHECK validate होना, या Production parity सिद्ध नहीं होती।

अलग और unresolved blocker अभी भी दोनों अलग files का समान 8-digit migration prefix `20261109` होना है। Remote Supabase migration history/schema-only evidence उपलब्ध नहीं है; किसी migration को rename/delete/merge/resequence करना या remote history repair करना बिना authoritative lineage के नहीं किया जाएगा। Current Feature Branch में `supabase/config.toml` भी नहीं मिला। कोई PostgreSQL replay/pgTAP या Production query/write नहीं चला।
