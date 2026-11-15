# GPT-2 PostgreSQL / pgTAP Runtime Test Preparation — 2026-11-16

स्थिति: तैयारी और source inventory; कोई database test या migration replay इस pass में execute नहीं हुआ।

## 1. लक्ष्य और सुरक्षा सीमा

पहले disposable local Supabase/PostgreSQL environment में Staff RBAC और SOS Admin/Support migration contracts को verify करना है। Production URL, Production database password, service-role key, live Auth users या payment provider credentials का उपयोग नहीं होगा।

इस समय migrations को replay करना सुरक्षित/विश्वसनीय नहीं है: repository का migration replay manifest अभी authoritative base schema, remote migration history और कुछ मूल column definitions को unresolved बताता है। इस कारण इस दस्तावेज़ में दिए गए commands केवल prerequisites पूरे होने के बाद चलाने के लिए हैं।

## 2. मौजूदा repository स्थिति

- `package.json` का `npm test` केवल `tests/*.test.js` चलाता है।
- `.github/workflows/node-tests.yml` Node 22 suite चलाता है; उसमें Supabase CLI, Docker, PostgreSQL या pgTAP step नहीं है।
- जाँचे गए Feature Branch tree में `supabase/config.toml` मौजूद नहीं मिला।
- Database contracts मौजूद हैं:
  - `supabase/tests/database/admin_staff_rbac_foundation.test.sql` — pgTAP `plan(69)`; assertion call count 69 (finish सहित)।
  - `supabase/tests/database/sos_admin_support_alerts.test.sql` — pgTAP `plan(28)`; assertion call count 28 (finish सहित)।
- RBAC permission helper की row-locking implementation को `VOLATILE` करने वाली migration `20261116100000_fix_staff_permission_helper_volatility.sql` है। Test में helper का `provolatile='v'` होना भी जाँचा जाता है।
- `docs/MIGRATION_REPLAY_MANIFEST_HI.md` में duplicate `20261109` version prefixes, missing authoritative `service_bookings.amount_paid` definition, unresolved electrician identity column baseline और historical schema/migration-history gaps दर्ज हैं। वह manifest खुद को execution-ready नहीं बताता।

## 3. Replay से पहले अनिवार्य gates

सभी gates पूरे और review होने तक `supabase db reset`, migration replay या कोई hosted DB command न चलाएँ।

1. **Baseline:** पूर्ण और authoritative starter schema प्राप्त हो; कम-से-कम `auth.users`, `auth.sessions`, Supabase roles, `public.srk_admin_users`, `public.is_srk_admin()`, `service_bookings`, `electrician_profiles`, customer complaint base tables और आवश्यक support tables के exact definitions/constraints उपलब्ध हों।
2. **Migration history:** duplicate 8-digit `20261109` filenames का remote history के साथ approved reconciliation हो। Filename rename या migration history repair अनुमान से न करें।
3. **Dependency map:** सभी migrations के referenced tables, columns, enums, functions, triggers, extensions, storage objects, grants और RLS prerequisites का पूरा dependency order review हो।
4. **Local harness:** repository में Supabase config और test harness जोड़ा जाए; Supabase CLI version pin/record हो; local Docker stack उपलब्ध हो।
5. **Isolation:** local stack disposable हो; कोई Production URL/secret environment में न हो। Test users/UUIDs केवल local fixtures हों।
6. **Review:** replay log और schema diff में unexpected object replacement/drop/grant बदलाव न हों। किसी failure पर आगे की migrations चलाकर error को छिपाएँ नहीं।

## 4. Prerequisites के बाद प्रस्तावित local-only sequence

ये commands अभी execute नहीं किए गए हैं। इन्हें केवल ऊपर के gates पूरे होने और अलग local environment की पुष्टि के बाद चलाएँ:

```bash
# 1) Local Supabase stack only
supabase start

# 2) Disposable local database पर पूरा migration replay
supabase db reset

# 3) Database pgTAP suite
supabase test db

# 4) Repository JavaScript contract suite
npm ci
npm test
```

अगर repository में अभी भी Supabase config नहीं है, तो पहले isolated worktree/temp checkout में Supabase CLI की चुनी हुई और recorded version से config initialize करें; उससे generated config को review किए बिना Feature Branch में commit न करें। CLI/Docker versions और replay log को test artifact के रूप में रिकॉर्ड करें।

## 5. Targeted test order और expected gates

1. `admin_staff_rbac_foundation.test.sql` — 69 assertions:
   - Main Admin / Support identity separation;
   - browser roles के direct table grants निषिद्ध;
   - Support permission catalog में केवल approved scope;
   - exact Auth session + tracked non-revoked session requirement;
   - `srk_has_admin_permission` volatility और row locks;
   - invite registration service-role-only;
   - staff status lifecycle, verified email, assignment scoping;
   - private contact projection और append-only audit.
2. `sos_admin_support_alerts.test.sql` — 28 assertions:
   - SOS tables RLS/private grants;
   - append-only event history;
   - active-work booking ownership;
   - dedicated Support read/acknowledge permissions;
   - acknowledgement locking and audit event;
   - no false claim of SMS delivery when provider is not configured.
3. **Negative runtime cases to add/verify in an isolated fixture**:
   - anon and ordinary authenticated user denied;
   - invited/suspended/disabled Staff denied;
   - active Staff with missing/wrong/revoked Auth session denied;
   - Support Staff denied finance/refund/payout/KYC/staff-management RPCs;
   - Staff cannot read unassigned support cases or private contact fields;
   - Staff cannot reassign, self-promote, reopen closed cases, or mutate/truncate audit;
   - Main Admin lifecycle actions revoke Staff sessions;
   - concurrent disable/revoke vs support RPC serializes without stale authorization.
4. Run all existing database pgTAP files after targeted tests pass, not only these two, before any staging consideration.

## 6. CI integration proposal (not implemented)

After local replay is deterministic:
- Add a separate GitHub Actions job with pinned Supabase CLI and a disposable local Supabase stack.
- Do not add Production secrets or deploy steps.
- Run migration replay, pgTAP and Node tests.
- Upload logs/artifacts with secrets scrubbed.
- Keep CI status separate from actual staging/Production approval.

## 7. Current result

- Source inventory and test plan counts checked.
- Runtime PostgreSQL/pgTAP: NOT RUN.
- Migration replay: NOT RUN.
- Production access or schema change: NONE.
- CI pgTAP job: NOT ADDED.
- GPT-1 Customer/Electrician source: untouched.

अगला सुरक्षित कदम: authoritative baseline और duplicate migration history gaps resolve करना; उसके बाद ही disposable local replay शुरू किया जा सकता है।


## 8. Existing Supabase schema CI workflow audit — 16 Nov 2026

Feature Branch पर `.github/workflows/supabase-schema-ci.yml` मिला। इसलिए पिछली पंक्ति “CI pgTAP job नहीं जोड़ा गया” का अर्थ यह है कि GPT-2 RBAC/SOS के लिए कोई उपयुक्त pgTAP job नहीं जोड़ा गया; repository में एक पुराना, अलग-purpose schema workflow पहले से मौजूद है।

### वर्तमान workflow की सीमाएँ

- Trigger केवल `workflow_dispatch` है।
- Job guard केवल `refs/heads/feature/platform-fee-cash-online-cycle` स्वीकार करता है; वर्तमान GPT-2 branch `feat/customer-login-first-dashboard-20261114` पर यह job चलने के लिए configured नहीं है।
- Workflow GitHub Secret `SUPABASE_DB_URL` से remote Production schema-only dump लेता है। यह table data dump करने का workflow नहीं है, लेकिन यह फिर भी hosted Production DB से जुड़ता है; इसलिए इसे इस दस्तावेज़ के प्रस्तावित strictly-local/no-Production-credential test harness के बराबर नहीं मानना चाहिए।
- यह एक generated temporary Supabase project बनाता है, Production schema dump को local stack में restore करता है, फिर केवल पाँच hard-coded पुरानी payment/fee migrations चलाता है।
- इसमें current Feature Branch की पूरी migration inventory, duplicate `20261109` version gate, RBAC/SOS migrations के targeted pgTAP tests या `supabase test db` step शामिल नहीं हैं।
- इसलिए इस workflow का मौजूद होना या किसी अन्य branch पर चलना GPT-2 PostgreSQL/pgTAP test pass का प्रमाण नहीं है।

### सुरक्षित निर्णय

1. Existing workflow को अभी dispatch या modify नहीं किया गया।
2. इसे current GPT-2 branch पर सीधे enable नहीं करना चाहिए: branch guard, Production schema export dependency, limited migration list और missing pgTAP coverage पहले owner-reviewed design में बदलने होंगे।
3. अगला प्रस्ताव strictly local disposable Supabase stack + reviewed authoritative fixture schema + complete approved migration order + `supabase test db` होना चाहिए। जब तक baseline और duplicate-version questions resolve नहीं होते, replay blocked रहेगा।
4. No Production URL/secret was read or used; no remote query, schema dump, migration, workflow dispatch, deployment, or source change outside this documentation update.

### Verification

- Existing workflow file read from `feat/customer-login-first-dashboard-20261114`.
- Workflow branch guard and five migration paths inspected directly.
- Workflow execution status: NOT RUN in this audit.
- PostgreSQL/pgTAP: NOT RUN.


## 9. Duplicate migration version / Supabase CLI risk — 16 Nov 2026

- Feature Branch में ये दो अलग files एक ही 8-digit version prefix 20261109 से शुरू होती हैं:
  - 20261109_electrician_inspection_quotes_and_service_only_commission.sql
  - 20261109_allow_quote_approval_booking_states.sql
- Supabase CLI migration convention <timestamp>_<name>.sql है; migration history table version/timestamp को track करती है। इसलिए दोनों filenames को दो स्वतंत्र, सुरक्षित रूप से ordered migration versions मानना उचित नहीं है।
- Supabase CLI v3 के migration list / db push documentation में local filenames और remote schema_migrations versions के timestamp-based comparison का वर्णन है। GitHub issue में 8-digit और उसी prefix से शुरू होने वाले 14-digit versions के ordering mismatch का उदाहरण भी दर्ज है। यह हमारे exact two-file case का CLI reproduction नहीं है; इसलिए exact error/behavior अभी UNVERIFIED है।
- इस वजह से duplicate prefix को संभावित version collision / ordering blocker मानें, लेकिन बिना pinned CLI scratch reproduction के निश्चित CLI error घोषित न करें।
- अगला सुरक्षित परीक्षण: Production credentials और network access से अलग disposable scratch checkout में Supabase CLI version pin करें; पहले केवल दो minimal dummy migrations के साथ समान version prefix का parser/list/reset behavior देखें। फिर exact project files की copy पर test करें, कोई project migration rename/delete/repair किए बिना। Scratch run के logs और CLI version दर्ज करें।
- Remote history जानने के लिए supabase migration list --remote जैसी command documented है, लेकिन इस audit में कोई remote history command नहीं चलाई गई। Production history अज्ञात ही है।
- supabase migration repair remote history table को बदल सकता है; owner-reviewed evidence और explicit approval के बिना इसे न चलाएँ।

### Updated status

- Duplicate version prefixes: SOURCE CONFIRMED.
- Exact pinned-CLI behavior on these two files: NOT TESTED.
- Remote supabase_migrations.schema_migrations entries: NOT INSPECTED.
- Migration rename/delete/resequence/repair: NOT PERFORMED.
- Local PostgreSQL replay / pgTAP: NOT RUN.

## 10. Supabase official migration rules and precise duplicate-version finding — 16 Nov 2026

- Official Supabase CLI documentation says migration filenames follow `<timestamp>_<name>.sql`, local migrations live in `supabase/migrations`, remote applied versions live in `supabase_migrations.schema_migrations`, and migration list compares timestamps only. See Supabase CLI migration reference: https://supabase.com/docs/reference/cli/supabase-migration-list
- Exact source inventory for this branch: both 20261109 files have the same extracted 8-digit version `20261109`; they are not the separate 8-digit + 14-digit prefix pattern described in Supabase CLI issue #6036. That issue is related background, not proof of this exact case: https://github.com/supabase/cli/issues/6036
- Because the two files resolve to the same migration version, their SQL bodies cannot be represented as two distinct version entries in a timestamp-keyed migration history without additional history/design context. This is a strong source-level collision finding; exact pinned CLI parser/reset output remains unverified because CLI and Docker are unavailable in the current execution environment.
- Do not infer which file, if either, is recorded remotely. Do not rename, delete, combine, or repair the migrations until owner provides authoritative remote migration history and approves a reconciliation plan.
- Safe scratch experiment is still pending: pinned CLI + disposable isolated environment, first with dummy files sharing the exact same 8-digit version, then with copies of these two SQL files. Keep Production credentials/network entirely absent.

### Correction to the prior section

- The earlier mention of an 8-digit/14-digit shared-prefix CLI issue is only an analogous known issue. The project's exact source condition is two files with the identical 8-digit version, which is a different and more direct collision.
- CLI/Docker executable availability checked in the current environment: neither found. No install, remote connection, or database command was attempted.

## 11. Complete migration filename inventory — 16 Nov 2026

वर्तमान Feature Branch के recursive Git tree से सभी `supabase/migrations/*.sql` filenames की पूरी inventory की गई:

- कुल SQL migration files: **87**.
- 14-digit timestamp prefix वाली files: **85**.
- 8-digit timestamp prefix वाली files: **2** — दोनों केवल `20261109` वाली pair हैं.
- Duplicate version groups: **1** — `20261109` (ठीक वही दो files जो §9–10 में सूचीबद्ध हैं).
- Invalid/missing timestamp-prefix pattern: **0** (इस inventory में हर filename 8 या 14 digits + underscore + name + `.sql` format से match हुई).
- किसी दूसरे duplicate timestamp group का source evidence नहीं मिला.

### Existing automated guard

`tests/database-migration-version-uniqueness.test.js` पहले से सभी migration filenames पढ़ता है, version prefix को 8 या 14 digits तक सीमित करता है, और duplicate groups की तुलना एक explicit allow-list से करता है। उसमें केवल `20261109` की यही दो files approved legacy collision के रूप में दर्ज हैं; कोई नया duplicate आने पर test fail होगा। यह source-level filename guard है, Supabase CLI behavior या remote migration-history reconciliation का विकल्प नहीं है।

### निष्कर्ष

इस inventory में पहले से ज्ञात duplicate pair के अलावा कोई अतिरिक्त filename collision या malformed timestamp prefix नहीं मिला। इसलिए अगला blocker अभी भी वही एक `20261109` pair + authoritative remote history/baseline है। किसी migration SQL या GPT-1 source file में बदलाव नहीं किया गया; केवल इस audit report को विस्तृत किया गया।

- Inventory source: Feature Branch tree `7d254603176db02d1fa8e6c5fa5e204034772af9`.
- Filename inventory: **87/87 reviewed**.
- CLI/Docker runtime, replay, pgTAP: **NOT RUN**.
- Production/remote migration history: **NOT ACCESSED**.


## 12. Exact SQL overlap in the 20261109 collision pair — 16 Nov 2026

दोनों duplicate files का source दोबारा साथ में compare किया गया:

- `20261109_allow_quote_approval_booking_states.sql` में केवल booking status allow-list और assigned-electrician requirement के दो CHECK constraints drop/recreate किए जाते हैं।
- `20261109_electrician_inspection_quotes_and_service_only_commission.sql` में quote workflow columns, commission trigger/function, quote submission/customer response/work-status RPCs, offer-details RPC और grants/revokes के बाद **ठीक वही दो CHECK constraints** फिर से drop/recreate किए जाते हैं।
- दोनों files के उन अंतिम constraint statements का SQL text समान है: `service_bookings_status_check` और `service_bookings_assignment_status_requires_electrician`.

### Source-level प्रभाव

1. छोटी status-only migration, बड़ी quote/commission migration के अंत में पहले से मौजूद constraint change को दोहराती है।
2. यदि दोनों को किसी custom runner से क्रमशः execute किया जाए, तो दूसरी execution उन्हीं constraints को फिर drop/add करेगी; यह duplicate business logic है और constraint revalidation/locking का अतिरिक्त काम कर सकती है। यह केवल source analysis है—runtime lock duration या data impact मापा नहीं गया।
3. Timestamp-keyed migration history में एक ही version prefix होने के कारण यह तय नहीं किया जा सकता कि remote history में कौन-सी SQL body दर्ज हुई, या कोई अलग custom process दोनों चला चुका है। इसे अनुमान से तय न करें।
4. इसलिए इस जोड़ी को स्वतः merge/delete/rename करना सुरक्षित नहीं है। पहले authoritative remote history और owner-approved reconciliation आवश्यक है।

### निर्णय

- Exact duplicated constraint block: **SOURCE CONFIRMED**.
- Which SQL body is represented in remote history: **UNKNOWN / NOT ACCESSED**.
- Whether both files have ever run against any hosted database: **UNKNOWN**.
- CLI replay, PostgreSQL lock/performance behavior, and pgTAP: **NOT TESTED**.
- कोई SQL migration edit नहीं की गई।


## 13. Git commit chronology and dependency review for 20261109 pair — 16 Nov 2026

### Verified Git history

दोनों paths की GitHub commit history और तीनों relevant commit diffs पढ़े गए:

| UTC समय | Commit | Source change |
|---|---|---|
| 08:00:19 | `073d59e64672ee436783338dc3842c35e920a078` | बड़ी quote/commission migration path पहले एक-line “Applied migration…” note के रूप में record हुई। |
| 08:01:17 | `04d0c02f03cd7fb27d9b699b109dedc0fa0e0bad` | उसी बड़ी file को पूर्ण 99-line quote/commission SQL से बदला गया। |
| 08:04:11 | `b5e5b3bf2555bde77d17fde1e8e1d62a67b58f2b` | बड़ी file के अंत में दोनों booking CHECK constraints जोड़े गए। |
| 08:04:25 | `cd2c46e6e938ba7813eeb6461769f2a796ad3d93` | छोटी status-only file नई बनाई गई; इसका parent commit ठीक `b5e5b3b...` है। |

छोटी file के creation diff में केवल वही सात SQL lines हैं जो बड़ी file में 14 सेकंड पहले जोड़ी गई थीं। यह Git source history से पुष्टि करता है कि छोटी file का बदलाव बड़ी file के constraint update के बाद अलग से दोहराया गया। यह remote Supabase migration history का प्रमाण नहीं है।

### Dependency / ordering review

- दोनों constraint statements `public.service_bookings` पर निर्भर हैं और `status` तथा `assigned_electrician_id` columns को पढ़ते हैं। दोनों files स्वयं इन columns या base table को create नहीं करतीं।
- बड़ी migration अतिरिक्त रूप से `service_bookings` के quote/payment/status fields, `electrician_profiles`, `job_offers`, `auth.uid()`, commission function और संबंधित RPC dependencies पर निर्भर है। इसलिए इसका पूरा replay base schema और पूर्व migrations के बिना सुरक्षित रूप से validate नहीं किया जा सकता।
- बाद की migration `20261114370000_electrician_offer_details_immediate_booking_fields.sql` offer-details RPC को फिर से परिभाषित करती है और quote/category/workflow fields पर निर्भर है। इससे current source tree में आगे का dependency chain दिखता है, लेकिन यह historical remote execution order या successful deployment सिद्ध नहीं करता।
- Git parent chain और file chronology केवल repository history बताते हैं। Supabase की `supabase_migrations.schema_migrations` table में कौन-सा version/name दर्ज है, वह अभी भी अज्ञात है।

### Safe conclusion / action

1. Source-level duplicate को accidental/redundant second recording कहना उचित है; exact author intent अज्ञात है।
2. दोनों files को अभी जस का तस रखें। Rename, delete, merge, timestamp change या remote migration repair न करें।
3. अगला निर्णायक प्रमाण authoritative remote migration-history export और matching live schema/catalog snapshot होगा—इसे केवल owner-approved, read-only process से प्राप्त किया जाए। उसके बाद pinned Supabase CLI के disposable scratch reproduction से replay behavior अलग से जाँचा जाए।
4. Production database से कोई query, migration, repair या deployment इस pass में नहीं किया गया।

### Status

- Git commit chronology: **SOURCE HISTORY CONFIRMED**.
- Duplicate file parent relation: **CONFIRMED** (`cd2c46e...` parent is `b5e5b3b...`).
- Required base columns in the duplicate statements: **SOURCE CONFIRMED**.
- Remote migration-history row / live schema parity: **UNKNOWN / NOT ACCESSED**.
- Supabase CLI replay, PostgreSQL execution and pgTAP: **NOT RUN**.
- Migration SQL or GPT-1 Customer/Electrician/Welcome source: **UNCHANGED**.

## 14. Owner-run read-only Supabase history and schema evidence plan — 16 Nov 2026

यह section केवल evidence collection की तैयारी है। इस execution environment में Supabase DB connector/CLI/psql access उपलब्ध नहीं है; कोई hosted DB connection नहीं किया गया। GitHub repository access को Supabase database access न समझें।

### A. Owner/DBA से क्या evidence लेना है

केवल project के अधिकृत Database Owner/DBA से, approved secure workstation और approved access path पर:

1. Supabase project reference और environment की पुष्टि (Production/Staging/local) — connection string या password साझा किए बिना।
2. Migration history table में 20261109 के आसपास के सभी rows; खास तौर पर version, name और यदि उपलब्ध हो तो statement metadata.
3. public.service_bookings table का existence और status, assigned_electrician_id columns की presence/type.
4. उन्हीं दो named CHECK constraints की live definitions, validation flags (convalidated) और deferrability.
5. service_bookings से जुड़े अन्य constraints/indexes/triggers की सूची, यदि किसी reconciliation review में ज़रूरत हो।

### B. Read-only SQL template

इसे केवल DBA अपने approved SQL client में चलाए। पहले BEGIN READ ONLY से transaction read-only घोषित करें; output को approved secure channel से दें। Connection URL/password को chat, GitHub, issue, commit या report में paste न करें।

```sql
BEGIN READ ONLY;

-- 1) Verify the migration history relation and its actual columns first.
SELECT table_schema, table_name, column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'supabase_migrations'
  AND table_name = 'schema_migrations'
ORDER BY ordinal_position;

-- 2) After confirming the columns above, retrieve the relevant history rows.
-- Standard Supabase installations expose version and name; if this project
-- differs, adapt only after inspecting the column list.
SELECT version, name
FROM supabase_migrations.schema_migrations
WHERE version LIKE '20261109%'
ORDER BY version, name;

-- 3) Confirm the target table and the two referenced columns.
SELECT table_schema, table_name, column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'service_bookings'
  AND column_name IN ('status', 'assigned_electrician_id')
ORDER BY column_name;

-- 4) Read the live definitions and validation state of the two constraints.
SELECT
  c.conname,
  pg_get_constraintdef(c.oid, true) AS definition,
  c.contype,
  c.convalidated,
  c.condeferrable,
  c.condeferred
FROM pg_constraint c
JOIN pg_class t ON t.oid = c.conrelid
JOIN pg_namespace n ON n.oid = t.relnamespace
WHERE n.nspname = 'public'
  AND t.relname = 'service_bookings'
  AND c.conname IN (
    'service_bookings_status_check',
    'service_bookings_assignment_status_requires_electrician'
  )
ORDER BY c.conname;

ROLLBACK;
```

यदि history query में version/name columns नहीं हों या table न मिले, तो वहीं रुकें; schema assumptions से query बदलकर कोई write action न करें। Query errors और column listing DBA को सुरक्षित तरीके से preserve करनी चाहिए।

### C. Evidence handling / interpretation

- History में केवल 20261109 version row हो तो उससे यह पता चल सकता है कि version दर्ज है; उससे अपने-आप यह सिद्ध नहीं होगा कि कौन-सी local filename/body चली थी। name/stored statement metadata उपलब्ध हो तो उसे भी जाँचें।
- Live catalog में दोनों constraints मौजूद हों तो केवल current definitions सिद्ध होंगी; यह नहीं कि किस migration file ने उन्हें बनाया।
- convalidated=false का अर्थ constraint अभी validated नहीं है; इसे स्वतः validate/alter न करें।
- Missing history row या missing constraint को देखकर migration run, repair, drop/add, या schema fix न करें।
- History rows और catalog output का समय, project environment, CLI/SQL client version और evidence source record करें। Secrets, customer rows, Auth user data या business records collect न करें।
- DBA output मिलने के बाद Git history + exact source SQL + live catalog + migration history का side-by-side reconciliation बनाएं। फिर अलग owner approval के बिना कोई remediation न करें।

### D. Explicitly out of scope

- supabase migration repair, supabase db push, supabase db reset, ALTER TABLE, DROP/ADD CONSTRAINT, migration rename/delete/resequence.
- Production schema dump, data export, Auth/user inspection, payment or booking data access.
- किसी credential/secret को chat में माँगना या store करना.

### Status

- Read-only evidence plan: DOCUMENTED.
- Supabase Production connection / remote history query: NOT RUN.
- Live catalog snapshot: NOT ACCESSED.
- Migration repair or database write: NONE.