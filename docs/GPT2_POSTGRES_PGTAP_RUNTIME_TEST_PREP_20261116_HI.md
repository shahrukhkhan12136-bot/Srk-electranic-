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

## 15. Reconciliation of awaiting_work_start_approval against later migration source — 16 Nov 2026

### Question under review

The reported live catalog contains status `awaiting_work_start_approval`, while the two source migrations with the duplicate `20261109` prefix do not list that state in their `service_bookings_status_check` definitions. This is a reconciliation point, not by itself evidence of an incorrect live schema.

### Exact source SQL comparison

1. `20261109_allow_quote_approval_booking_states.sql` defines the allowed status list as `new, confirmed, assigned, inspection, awaiting_quote_approval, quote_approved, quote_rejected, in_progress, completed, cancelled`; it does **not** include `awaiting_work_start_approval`.
2. `20261109_electrician_inspection_quotes_and_service_only_commission.sql` ends with the same status list and likewise does **not** include `awaiting_work_start_approval`.
3. A later source migration, `20261114240000_server_authoritative_customer_approved_work_timer.sql`, explicitly adds:
   - `work_start_approval_status` (default `not_requested`);
   - `work_start_requested_at` and related server timer / approval columns;
   - `awaiting_work_start_approval` to `service_bookings_status_check`;
   - the same state to the assignment-required CHECK constraint.
4. The 20261114 source migration describes the new-customer work-start flow: an electrician requests permission, customer approval starts the server timer, and rejection returns the booking to `assigned`. The exact SQL also contains the status literal in its protected RPC.
5. `20261114250000_admin_work_dispute_review_and_immutable_history.sql` adds append-only work lifecycle event history and Admin review source. `20261114260000_fix_work_start_rpc_and_append_only_event_history.sql` later corrects/hardens the work-start response RPC and customer-safe timeline. These are related follow-on source files, but the status-list addition itself is in `20261114240000`.

### Git source chronology (not Production deployment evidence)

- The later work-timer migration first appears in Git at commit `9f29c1611d0c5ae5ecc052dd73b738da2ef20e40`, dated 2026-11-14 06:28:33 UTC, message “Add server-authoritative work timer and immutable labour-only bill”.
- Fetching the file at that original commit confirms that the original committed body already contained both `awaiting_work_start_approval` and `work_start_approval_status`. Original blob SHA: `ab31e3ae78a706a02749e59ba2a8fd09b81b3f5a`.
- The path history shows later edits to this migration through 2026-11-15, including timer precision, RPC validation, search-path hardening and assigned-electrician profile access. The current branch version is therefore not byte-for-byte identical to the initial Git blob; the current blob SHA at audit time is `e84e2e0124b90b526d07f305bc9bf1e2eb6f0ebe`.
- The 20261114250000 history file was first committed at `ca1f15e126a466903eb9e45ea5c0d0c4c0877c6c` (2026-11-14 06:37:50 UTC).
- The 20261114260000 follow-up file has its own later Git history beginning 2026-11-14 06:48:37 UTC (`fe1e125407f15a629e8846835b92487b311cb445`), with further edits on 2026-11-14 and 2026-11-15.
- Git commit history proves when these source files and revisions entered this repository. It does **not** prove that any of them were applied to Production, the order in which a hosted database applied them, or which exact later-edited file body was executed.

### Required Production history reconciliation

The reported live catalog observation is not independently re-queried in this audit. No Supabase Production connection or history query was performed. To reconcile it, an authorized Database Owner/DBA must use the approved read-only process from §14 and return the relevant history rows for **both** the 20261109 pair and the later work-timer family:

```sql
BEGIN READ ONLY;

SELECT version, name
FROM supabase_migrations.schema_migrations
WHERE version LIKE '20261109%'
   OR version LIKE '20261114%'
ORDER BY version, name;

ROLLBACK;
```

If the actual history table schema differs, inspect its columns first as described in §14 and stop if assumptions do not match. Preserve environment identity and query timestamp; do not share connection strings, passwords, or secrets.

### Decision / no-remediation boundary

- Source explanation for the status difference: **CONFIRMED** — the state is absent from both 20261109 source files and is explicitly introduced by later source migration `20261114240000`.
- Original Git commit for that later migration and presence of the status in its original committed body: **CONFIRMED**.
- Presence of `20261114240000`, `20261114250000`, or `20261114260000` in Production migration history: **NOT VERIFIED**.
- Whether Production's live constraint came from that migration, a later migration, manual DDL, or another deployment path: **UNKNOWN** until owner-provided history and catalog evidence are reconciled.
- Whether the Production-applied body matches the original or a later edited Git revision: **UNKNOWN**; a version/name history row alone may not prove the exact executed SQL body.
- No migration was run, repaired, renamed, deleted, merged, reordered or edited. No Production connection or database write occurred. No GPT-1 Customer/Electrician/Welcome source was changed.

### Source links

- Original work-timer migration commit: https://github.com/shahrukhkhan12136-bot/Srk-electranic-/commit/9f29c1611d0c5ae5ecc052dd73b738da2ef20e40
- Work-timer migration source: https://github.com/shahrukhkhan12136-bot/Srk-electranic-/blob/feat/customer-login-first-dashboard-20261114/supabase/migrations/20261114240000_server_authoritative_customer_approved_work_timer.sql
- Work lifecycle history migration: https://github.com/shahrukhkhan12136-bot/Srk-electranic-/blob/feat/customer-login-first-dashboard-20261114/supabase/migrations/20261114250000_admin_work_dispute_review_and_immutable_history.sql
- Work-start RPC correction migration: https://github.com/shahrukhkhan12136-bot/Srk-electranic-/blob/feat/customer-login-first-dashboard-20261114/supabase/migrations/20261114260000_fix_work_start_rpc_and_append_only_event_history.sql


## 16. Owner-provided read-only Production evidence — 16 Nov 2026

### Evidence supplied to GPT-2

The following results were supplied by the user as the output of an additional read-only check. GPT-2 did not independently connect to Production or rerun these queries; treat them as owner-provided evidence pending preservation of the original query output.

- Environment: Supabase Production.
- Reported query: `version = '20261114240000'`.
- Reported result: no matching row (`[]`).
- Reported Production migration inventory's latest visible entries include:
  - `20261115091906 — retire_unused_legacy_accept_electrician_job`
  - `20261115092149 — retire_unused_razorpay_route_transfer_ledger`
- Reported Live Catalog: both relevant constraints are present, and `awaiting_work_start_approval` is present.
- Git branch source: `20261114240000_server_authoritative_customer_approved_work_timer.sql` exists.
- Reported Git file SHA: `e84e2e0124b90b526d07f305bc9bf1e2eb6f0ebe` (matches the current branch file blob SHA observed during the source review).
- Reported migration SQL defines both constraints and includes `awaiting_work_start_approval`.
- Reported environment metadata: PostgreSQL 17.11; SQL client version unavailable from connector.
- Reported check timestamp: 16 Nov 2026, 03:44:48 IST.
- Reported safety: no Production changes, no migration apply/repair, no deployment, and no customer or business records read.

### Reconciliation

| Evidence item | Production (owner-provided) | Git source (reviewed) | Status |
|---|---|---|---|
| Both booking constraints | Present in Live Catalog | Defined by source migrations | Definitions align at a high level; exact live definition text should remain attached to §14 evidence |
| `awaiting_work_start_approval` | Present in Live Catalog | Explicitly added by `20261114240000` | State exists in both reported catalog and source |
| Migration history version `20261114240000` | No matching row returned | File exists | **Provenance unresolved** |
| Current Git file SHA | Not applicable | `e84e2e0124b90b526d07f305bc9bf1e2eb6f0ebe` | Source identity recorded |

### Updated conclusion

The owner-provided evidence strengthens the observation that the Production catalog currently contains the two constraints and the `awaiting_work_start_approval` state, while the Git source migration `20261114240000` also defines them. However, the reported absence of a `20261114240000` row in Production migration history means the migration's application/provenance is **not established** by the evidence currently available.

Do not infer that the migration is simply missing and do not treat the history result as authorization to repair it. Plausible explanations are not ranked or asserted here; resolving provenance requires the exact migration inventory/history output and any independently retained deployment record, reviewed by the Database Owner. A history row's absence alone does not identify how the live catalog reached its current state.

### Required next evidence-only step

Preserve the original read-only outputs (redacting project identifiers if desired, and never including connection strings or secrets) for:
1. the exact history query and its empty result;
2. the relevant inventory rows and the inventory's scope/ordering;
3. the exact `pg_get_constraintdef` output, `convalidated`, and the relevant column metadata from §14;
4. the Production environment label and timestamp.

Then compare the evidence with the Git source and any Database Owner-held deployment record. No schema change, migration repair, migration replay, `db push`, deployment, rename, delete, reorder, or other remediation is authorized by this finding. Any future remediation requires separate explicit Database Owner approval.

### Evidence boundary

This section records user-supplied Production query results; it is not an independent Production verification by GPT-2. No database connection was opened by GPT-2, no SQL was executed by GPT-2, no Production data was changed or read by GPT-2, and no GPT-1 Customer/Electrician/Welcome source was modified.

## 17. Git-source expected catalog fingerprints — evidence-only — 16 Nov 2026

### Purpose and boundary

This section records the exact source-side definitions that can be compared with the owner/DBA's read-only Production catalog output. It does not claim that these definitions were independently observed in Production. No Production connection or SQL execution was performed.

### Expected definitions from current branch source

Source file:
`supabase/migrations/20261114240000_server_authoritative_customer_approved_work_timer.sql`

Current branch blob SHA:
`e84e2e0124b90b526d07f305bc9bf1e2eb6f0ebe`

The migration drops/recreates `public.service_bookings_status_check` with the following status set:

```sql
CHECK (status = ANY (ARRAY[
  'new','confirmed','assigned','inspection','awaiting_quote_approval',
  'quote_approved','quote_rejected','awaiting_work_start_approval',
  'in_progress','completed','cancelled'
]::text[]))
```

It drops/recreates `public.service_bookings_assignment_status_requires_electrician` with this predicate:

```sql
CHECK (
  status <> ALL (ARRAY[
    'assigned','inspection','awaiting_quote_approval','quote_approved',
    'quote_rejected','awaiting_work_start_approval','in_progress','completed'
  ]::text[]) OR assigned_electrician_id IS NOT NULL
)
```

The same migration adds the following timer/approval columns to `public.service_bookings` (among others):

- `work_timer_running boolean NOT NULL DEFAULT false`
- `work_started_at timestamptz`
- `work_start_requested_at timestamptz`
- `work_start_origin_status text`
- `work_start_approval_status text NOT NULL DEFAULT 'not_requested'`
- `completion_approval_status text NOT NULL DEFAULT 'not_requested'`
- `completion_requested_at timestamptz`
- `customer_completed_at timestamptz`
- `work_timer_seconds bigint NOT NULL DEFAULT 0`

Related identity source, not a Production assertion:
`supabase/migrations/20261109000500_harden_electrician_profile_identity_linking.sql` adds `public.electrician_profiles.auth_user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL`, backfills the identity link, and creates a partial unique index. This is relevant only if a separate catalog comparison needs that identity column; it does not establish the status constraint's deployment provenance.

### Comparison checklist for DBA-supplied output

Compare exact normalized `pg_get_constraintdef` output against the two predicates above, and separately record:

- whether each constraint exists exactly once;
- `convalidated`, `condeferrable`, and `condeferred`;
- `service_bookings.status` and `service_bookings.assigned_electrician_id` data types and nullability;
- presence, type, nullability, and defaults of the listed timer/approval columns.

A textual match supports current-definition alignment only. It does not prove which migration, deployment mechanism, or operator produced the live catalog. A mismatch is a finding to document and escalate to the Database Owner, not permission to alter the schema.

### Status

- Current branch source definitions: READ AND RECORDED.
- Live Production catalog comparison: PENDING OWNER/DBA OUTPUT.
- Migration provenance: UNRESOLVED.
- Production changes, migration repair/replay, deployment, and GPT-1 source changes: NONE.

## 18. Exact source-side delta: 9 Nov constraints → 14 Nov timer migration — 16 Nov 2026

A fresh read of all three current-branch source files confirms this narrow source-side sequence:

1. `20261109_allow_quote_approval_booking_states.sql` defines `service_bookings_status_check` without `awaiting_work_start_approval`. Its assignment-required CHECK also omits that state.
2. `20261109_electrician_inspection_quotes_and_service_only_commission.sql` repeats those same two status/assignment CHECK definitions, likewise without `awaiting_work_start_approval`. It also contains separate quote/commission SQL; this does not make its two CHECK definitions different from the status-only migration.
3. `20261114240000_server_authoritative_customer_approved_work_timer.sql` drops and recreates both constraints and adds `awaiting_work_start_approval` to each relevant state list. The same migration adds work-start approval/timer columns and server-authoritative RPC logic.

Source blob SHAs on branch `feat/customer-login-first-dashboard-20261114`:
- `20261109_allow_quote_approval_booking_states.sql`: `ef4bf8b9b8a9a35bf3ddd94ea4614c7498fb1c6d`
- `20261109_electrician_inspection_quotes_and_service_only_commission.sql`: `014699d3190e45aacde4022ac7e7fa9ca4fec006`
- `20261114240000_server_authoritative_customer_approved_work_timer.sql`: `e84e2e0124b90b526d07f305bc9bf1e2eb6f0ebe`

### Interpretation boundary

This establishes the expected source evolution, not the actual order or success of hosted Production migrations. The previously user-reported absence of history version `20261114240000` therefore remains unresolved against the user-reported live presence of the later status. No source migration was changed and no repair is authorized.

### Status

- Three source files re-read and exact constraint delta recorded.
- Production history/catalog: still requires original owner/DBA read-only evidence.
- No Production connection, DDL, migration replay/repair, deployment, or GPT-1 source edits.

## 19. GitHub per-file commit chronology cross-check — 16 Nov 2026

A read-only GitHub per-file commit-history check adds the following precise chronology (timestamps UTC):

- The larger inspection/quote/commission migration's constraint update is recorded in commit `b5e5b3bf2555bde77d17fde1e8e1d62a67b58f2b` at `2026-11-09T08:04:11Z`, message: “Include quote workflow states in booking constraints”.
- The separate status-only migration file is recorded in commit `cd2c46e6e938ba7813eeb6461769f2a796ad3d93` at `2026-11-09T08:04:25Z`, message: “Allow inspection and quote approval booking states”.
- Thus the larger file's matching status/assignment constraint definitions were committed 14 seconds before the smaller duplicate file was added.
- The server-authoritative timer migration first appears in Git at `9f29c1611d0c5ae5ecc052dd73b738da2ef20e40` at `2026-11-14T06:28:33Z`, message: “Add server-authoritative work timer and immutable labour-only bill”. Later commits on 14–15 Nov modify that same file; its present branch blob is recorded in §17–18.

### Interpretation

This strengthens the source-repository chronology and confirms that the two 9 Nov files are a duplicate-definition group at the relevant CHECK constraints. Git commit timestamps describe repository history only. They do not establish Supabase migration application order, whether a hosted migration ran, or the provenance of current Production constraints. The reported missing Production history row for `20261114240000` therefore remains an unresolved provenance gap.

No migrations were edited, renamed, deleted, replayed, or repaired. No Production access or changes occurred.

## 20. Production read-only audit reconciliation — owner-provided evidence — 16 Nov 2026

The following Production audit was supplied by the project owner in this conversation. GPT-2 did not independently connect to Supabase or execute these queries. All Production observations below are therefore explicitly attributed to the supplied audit.

### Environment and scope reported

- Project: `Srk electranic`; reference: `gnqhoaqatmoiwwhgzkgm`; environment: Production; region: `ap-south-1`.
- Project status: `ACTIVE_HEALTHY`; PostgreSQL `17.11.0.018` / server `17.11`.
- Audit timestamp supplied: `16-11-2026 03:44:48 IST`.
- The audit states that it read migration metadata and catalog metadata only; no customer, Auth, payment, or booking records, and no credentials/secrets.
- No writes, migration execution/repair, DDL, data modification, or deployment were reported.

### Migration-history reconciliation

The supplied audit reports that `supabase_migrations.schema_migrations` exists with columns `version text`, `statements ARRAY`, `name text`, `created_by text`, `idempotency_key text`, and `rollback ARRAY`.

For `version LIKE '20261109%'`, the audit reports 38 rows and these two relevant entries:

| Production version | Production name |
|---|---|
| `20261109075837` | `electrician_inspection_quotes_and_service_only_commission` |
| `20261109080400` | `allow_quote_approval_booking_states` |

This confirms, within the supplied audit, that both 9 Nov migrations have Production history entries. Their names correspond to the two source files discussed in §§11–13 and §19. The reported Production versions also provide a distinct migration-history timestamp sequence; Git commit timestamps in §19 remain repository chronology and must not be conflated with database migration versions.

The supplied audit reports no history row for `20261114240000` and no matching item in the Production migration inventory. This is an evidence gap, not proof that the SQL never ran: the current catalog may have been produced by another approved path, but no such path is established by the evidence currently available.

### Live catalog reconciliation

The supplied audit reports these `public.service_bookings` columns:

- `assigned_electrician_id uuid NULL`
- `status text NOT NULL`

It reports both expected CHECK constraints as present, `convalidated = true`, `condeferrable = false`, and `condeferred = false`.

The supplied audit summarizes the live status CHECK as including:
`new`, `confirmed`, `assigned`, `inspection`, `awaiting_quote_approval`, `quote_approved`, `quote_rejected`, `awaiting_work_start_approval`, `in_progress`, `completed`, and `cancelled`.

It summarizes the assignment-required CHECK as requiring a non-NULL `assigned_electrician_id` for:
`assigned`, `inspection`, `awaiting_quote_approval`, `quote_approved`, `awaiting_work_start_approval`, `quote_rejected`, `in_progress`, and `completed`.

These state sets are consistent with the later Git source migration `20261114240000_server_authoritative_customer_approved_work_timer.sql` described in §§17–18, and inconsistent with the earlier 9 Nov source definitions in the precise way already documented there. This is a semantic/state-set comparison based on the audit's summary. The audit text supplied here does not include the raw `pg_get_constraintdef(...)` output, so byte-for-byte or full normalized SQL-definition equality is not independently established in this section.

### Reconciled conclusion

1. **9 Nov migration provenance:** the supplied Production history includes both related 9 Nov entries. This closes the earlier uncertainty about whether those two named 9 Nov migrations appear in the checked Production history.
2. **Current live state:** the supplied catalog summary reports both CHECK constraints present and validated, with `awaiting_work_start_approval` in both relevant state sets.
3. **14 Nov migration provenance:** still unresolved. The supplied audit reports no `20261114240000` history or inventory record, despite the live state matching the later source migration's state additions.
4. **No repair inference:** do not infer manual DDL, an alternate deployment path, or a failed migration from the current evidence. Do not repair, insert history rows, replay migrations, alter constraints, or deploy.
5. **Evidence needed to close the gap:** exact raw `pg_get_constraintdef(c.oid, true)` text for both constraints; relevant `convalidated` and deferrability fields (the summary is already supplied); and an authoritative DBA/deployment record explaining how the later state reached Production without the reported migration-history entry. Preserve read-only scope. Do not share secrets or connection strings.

### Status

- Owner-provided Production audit reconciled against the existing Git-source analysis.
- The 9 Nov history entries are reported present.
- Current live constraint state is reported consistent with the later source migration's state sets.
- The missing 14 Nov history/inventory record and its provenance remain unresolved.
- No independent GPT-2 Production access; no Production write, migration repair/replay, DDL, deployment, or GPT-1 source change.

## 21. Full Production CHECK definitions and second migration-history check — owner-provided read-only evidence — 16 Nov 2026

The project owner supplied a second read-only Production audit in this conversation. GPT-2 did not independently connect to Supabase or execute the queries. The details below are attributed to that supplied audit.

### Exact live CHECK definitions supplied

Table: `public.service_bookings`.

**A. `service_bookings_status_check`**

```sql
CHECK (
  status = ANY (
    ARRAY[
      'new'::text,
      'confirmed'::text,
      'assigned'::text,
      'inspection'::text,
      'awaiting_quote_approval'::text,
      'quote_approved'::text,
      'awaiting_work_start_approval'::text,
      'quote_rejected'::text,
      'in_progress'::text,
      'completed'::text,
      'cancelled'::text
    ]
  )
)
```

**B. `service_bookings_assignment_status_requires_electrician`**

```sql
CHECK (
  (
    status <> ALL (
      ARRAY[
        'assigned'::text,
        'inspection'::text,
        'awaiting_quote_approval'::text,
        'quote_approved'::text,
        'awaiting_work_start_approval'::text,
        'quote_rejected'::text,
        'in_progress'::text,
        'completed'::text
      ]
    )
  )
  OR assigned_electrician_id IS NOT NULL
)
```

The supplied audit reports for both constraints: `convalidated = true`, `condeferrable = false`, and `condeferred = false`.

### Source comparison

The exact supplied definitions contain the `awaiting_work_start_approval` state in both relevant state sets. This matches the state-set changes recorded in the Git source migration `20261114240000_server_authoritative_customer_approved_work_timer.sql` (§§17–18).

This is now an exact textual SQL definition supplied by the owner, and it matches the expected logical predicates in the current Git source. It still does not establish that this specific migration executed in Production. The absence of its migration-history/inventory record remains a separate provenance question.

### Second migration-history / DBA explanation check

The supplied second audit reports:

- Production contains migration `20261114193300`, named `admin_approved_electrician_relocation_20261114220000`.
- Other entries dated 13 and 15 Nov are also reported present.
- The specifically investigated `20261114240000_server_authoritative_customer_approved_work_timer` remains absent from both `supabase_migrations.schema_migrations` and the Supabase migration inventory.
- No DBA explanation, repair record, execution log, manual SQL record, or written reason for this absence has been verified in the evidence supplied.

The presence of a different 14 Nov migration does not explain the missing timer migration. No causal relationship is inferred.

### Updated conclusion and safe next step

1. Both full live CHECK definitions are now available and match the later Git migration's relevant state sets.
2. Both constraints are reported validated and non-deferrable.
3. The target 14 Nov timer migration remains absent from the checked Production history and inventory.
4. The reason and actual provenance of the live constraint definitions remain unknown. Do not label the migration as intentionally skipped, failed, manually applied, or applied by another route without authoritative evidence.
5. The only appropriate next evidence is a DBA/owner-held deployment or execution record, approved change record, or written explanation that accounts for the live definitions and missing history entry. If none exists, record provenance as unknown and escalate to the authorized Database Owner for a separately approved decision. Continue read-only; do not insert history rows, run/replay/repair migrations, execute DDL, alter constraints, or deploy.

### Status

- Full CHECK definitions: supplied and recorded.
- Both constraints: reported validated, not deferrable.
- 9 Nov Production history entries: reported present (§20).
- Target 14 Nov timer migration history/inventory entry: reported absent on the second check as well.
- DBA explanation / execution provenance: not verified.
- No independent GPT-2 Production access; no Production write, repair, replay, DDL, deployment, or GPT-1 source changes.


## 22. Owner-confirmed Question Database replacement authorization — 16 Nov 2026

The project owner explicitly clarified in this conversation:

- The owner had instructed that the old Question Database be removed.
- The owner had instructed that the new Question Database be added.
- The owner states GPT-1 performed that replacement under the owner's direction.

### Reconciliation

- Record this as an **owner-authorized product/data change**, not as an unauthorized or accidental change.
- Do not attribute the replacement to an unapproved GPT-1 action.
- This authorization applies to the Question Database replacement described by the owner. It does not by itself establish authorization or execution of any Supabase Production migration, including `20261114240000_server_authoritative_customer_approved_work_timer`.
- Keep historical quotation bookings (legacy quotation approval) distinct from new-category bookings (customer-approved server timer). The source migration retains legacy quote RPC behavior only for rows without a customer-selected category; this is source-code evidence, not proof of Production rollout.

### Status / boundary

- Owner authorization for old-to-new Question Database replacement: **CONFIRMED BY OWNER STATEMENT**.
- Independent audit of the exact Question Database records changed: **NOT PERFORMED**.
- Production migration provenance for the 14 Nov timer migration: **UNRESOLVED** (§21).
- No Production write, migration repair/replay, DDL, deployment, or GPT-1 application-source change performed by GPT-2.


## 23. New-category status guard source reconciliation — 16 Nov 2026

A fresh read of the current branch's complete source file
`supabase/migrations/20261114240000_server_authoritative_customer_approved_work_timer.sql`
confirms that it already defines and installs:

- `public.srk_guard_new_category_booking_status_transition()`;
- trigger `srk_guard_new_category_booking_status_transition` on `public.service_bookings`;
- protected transition checks for new-category bookings, including work-start approval, authorized in-progress/completed transitions, and approved cancellation;
- the legacy quotation RPCs are separately restricted to rows where `selected_category IS NULL`.

The previously inspected standalone draft path
`supabase/migrations/20261115140000_guard_new_category_booking_status_transitions.sql`
is not present on the current branch (GitHub file lookup returned 404). Its earlier add/remove commit sequence therefore does **not** establish a currently active standalone migration.

### Reconciled source conclusion

- The status-guard implementation is present in the 14 Nov timer migration source itself.
- There is no source-level reason to restore the deleted standalone draft solely to obtain that guard; doing so could duplicate the implementation.
- The current branch source does not prove that the 14 Nov migration or its trigger was applied in Production.
- No migration was restored, replayed, repaired, renamed, or deployed. No Production schema was accessed or changed.

### Remaining verification gate

Before runtime claims, the existing blockers in §§1–7 and §§21–22 remain: authoritative base schema, duplicate 9 Nov migration-version reconciliation, isolated local Supabase configuration/harness, and the missing Production provenance explanation. The 14 Nov source guard should be included in the future disposable-local replay and pgTAP coverage once those prerequisites are resolved.


## 24. Timer/status-guard pgTAP coverage gap — 16 Nov 2026

A read-only source comparison was made between the 14 Nov timer migration and the two existing database pgTAP files:

- `supabase/tests/database/admin_staff_rbac_foundation.test.sql` (declared `plan(69)`);
- `supabase/tests/database/sos_admin_support_alerts.test.sql` (declared `plan(28)`).

Neither of these two test files contains a direct assertion for
`srk_guard_new_category_booking_status_transition`, its trigger, or the timer workflow's `awaiting_work_start_approval` transition. The SOS test has one general assertion mentioning an active new-category work booking, but that is not direct coverage of the status guard or work-start authorization.

The migration source defines the guard as a SECURITY DEFINER trigger function with an empty search_path, installed as a BEFORE UPDATE OF status,selected_category trigger on `public.service_bookings`. Its explicit allow paths include:
- Main Admin confirmation from `new` to `confirmed`;
- assignment from `new`/`confirmed` only when the selected electrician has an accepted job offer;
- electrician request from `assigned` to `awaiting_work_start_approval` with transaction-scoped work-timer authorization;
- customer rejection returning the booking to `assigned` with the corresponding authorization;
- `in_progress` and `completed` only with matching work-transition authorization;
- cancellation only with a matching approved cancellation request.

All other new-category status transitions are rejected with
`NEW_CATEGORY_STATUS_REQUIRES_PROTECTED_WORKFLOW`; changing `selected_category` is rejected as immutable. Legacy rows with `selected_category IS NULL` are outside this new-category guard.

### Recommended future disposable-local pgTAP coverage

After the replay prerequisites in §§1–7 are resolved, add a dedicated test file rather than inflating unrelated RBAC/SOS tests. Its assertions should cover:
1. Guard function and trigger existence, trigger timing/events, SECURITY DEFINER, empty search_path, and no browser-role EXECUTE grant.
2. Rejection of direct new-category status edits that lack the protected authorization path.
3. Rejection of selected-category mutation.
4. Acceptance of each intended protected transition using isolated fixture identities and transaction-scoped authorization rows.
5. Acceptance of the legacy-row exemption without weakening the new-category guard.
6. Rejection of cancellation without a matching approved request and acceptance only with a booking-matched approved request.
7. Cleanup/rollback of all fixtures and deterministic assertion counts.

This is a test-coverage finding and a future test specification only. No pgTAP test was added or executed in this step; no migration replay, Production query/write, DDL, deployment, or application-source change occurred. The local replay blockers and unknown Production provenance remain unchanged.


## 25. Existing pgTAP plan-count static reconciliation — 16 Nov 2026

A statement-level count was performed on the two existing SQL test files (splitting complete top-level SQL statements at semicolons; nested SELECT expressions inside an assertion are not counted as separate test assertions):

| Test file | Declared plan | Top-level SELECT statements | Plan + assertions + finish | Result |
|---|---:|---:|---:|---|
| `admin_staff_rbac_foundation.test.sql` | 69 | 71 | 1 plan + 69 assertions + 1 finish | Count matches |
| `sos_admin_support_alerts.test.sql` | 28 | 30 | 1 plan + 28 assertions + 1 finish | Count matches |

Both files therefore have internally consistent declared pgTAP plan counts by static statement counting. This does not establish that either SQL file parses or passes against PostgreSQL, nor does it validate the referenced schema objects, privileges, function definitions, or runtime behavior.

No database engine, pgTAP, Supabase CLI, Docker, or CI job was run. No Production access or change occurred.
