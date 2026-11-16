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


## 26. Existing SQL test isolation and schema-workflow safety review — 16 Nov 2026

### Existing pgTAP file boundaries

Static inspection of both current pgTAP files confirms:
- Each starts a transaction with `BEGIN`;
- Each declares its existing pgTAP plan;
- Each ends with `SELECT * FROM finish()` followed by `ROLLBACK`;
- A line-start scan found no top-level INSERT, UPDATE, DELETE, TRUNCATE, CREATE, ALTER, DROP, GRANT, REVOKE, or role-switch statements in either test file.

This supports that the test scripts are written as transactional schema/introspection assertions with rollback boundaries. It is not a guarantee that called functions or database-side hooks are side-effect free, and it is not a substitute for execution in a disposable local database.

### Existing `.github/workflows/supabase-schema-ci.yml` safety finding

The existing workflow is manually dispatched only and has a hard-coded branch guard for `feature/platform-fee-cash-online-cycle`, not the current GPT-2 feature branch. More importantly, its steps require a `SUPABASE_DB_URL` secret, connect to a remote database for a schema-only dump, then restore that dump into a temporary local Supabase stack and apply a fixed list of unrelated feature migrations.

Therefore:
- Do not dispatch this workflow for the current GPT-2 task.
- Do not add or provide a Production connection secret for GPT-2 pgTAP preparation.
- This workflow is not a disposable-local-only test harness and is not the requested timer/status-guard pgTAP job.
- A future safe CI job should use only an isolated local Supabase stack built from an approved, version-controlled baseline and pinned CLI/tool versions, with no remote DB URL or Production secret.

No workflow was dispatched or modified. No remote schema export, database connection, migration execution, pgTAP execution, Production access, or database change occurred.


## 28. Duplicate 20261109 migration body/dependency comparison — 16 Nov 2026

Both same-prefix files were fetched directly from the current feature branch and compared at statement level.

### File A — `20261109_electrician_inspection_quotes_and_service_only_commission.sql`
This larger feature migration adds quote fields to `public.service_bookings`, quote amount/status checks, commission calculation logic, electrician quote submission/customer response/work-status RPCs, and a replacement electrician offer-details RPC with grants/revokes. At its end it drops and recreates the two booking status/assignment CHECK constraints.

### File B — `20261109_allow_quote_approval_booking_states.sql`
This file contains only the same two status/assignment CHECK constraint drop-and-recreate operations. The status values and assignment-required status set match the definitions at the end of File A.

### Source-level conclusion
- File B repeats the constraint-definition step already present at the end of File A; it adds no distinct status value relative to File A.
- File A has materially broader schema/function/grant effects and cannot be treated as interchangeable with File B.
- File B looks redundant if File A has already run successfully, but source redundancy alone does not prove it is safe to delete, omit, rename, or merge in a clean replay chain.
- The two files have the same 8-digit filename prefix but distinct SQL bodies. The exact remote migration identity/order remains unverified; Git chronology and matching live constraint definitions do not resolve it.
- Both files rely on an existing `public.service_bookings` table and other pre-existing schema objects. This comparison does not reconstruct the authoritative starter schema or prove every referenced column/function dependency exists at replay time.

### Decision
No migration file was edited, removed, renamed, merged, reordered, replayed, or repaired. Do not treat either file as approved for omission. The duplicate-version replay gate remains **BLOCKED** pending authoritative migration lineage and an approved baseline/reconciliation decision. No Supabase CLI, PostgreSQL, pgTAP, Production query, or database write was run.


## 29. Historical starter-schema candidates vs current migration dependencies — 16 Nov 2026

Read-only source inspection covered the repository-root files `COMPLETE_DATABASE_SETUP.sql`, `SUPABASE_SCHEMA.sql`, and `PORTAL_SCHEMA.sql`, plus the customer-booking and electrician-identity migrations.

### What the starter files establish
- `SUPABASE_SCHEMA.sql` and the first section of `COMPLETE_DATABASE_SETUP.sql` define a historical starter form of `public.service_bookings`, `electrician_applications`, `electrician_profiles`, and `job_offers`.
- They enable RLS and define early public-insert and electrician/admin access policies.
- `PORTAL_SCHEMA.sql` adds the historical admin table, electrician `user_id) link, identity-linking trigger/function, and related portal policies/RPCs.
- These files are useful historical design evidence, but they are not a complete current replay baseline by themselves.

### Concrete differences against current migration dependencies
- The starter `service_bookings` definition has the original status set `new/confirmed/assigned/in_progress/completed/cancelled`; later migrations add quote and work-approval states.
- The starter table definition does not include the later `customer_user_id` column introduced by `20261108121115_add_customer_account_booking_access.sql`.
- It does not include later quote workflow columns such as quote status/note/timestamps, nor the newer customer-approved work-start timer fields.
- The starter `electrician_profiles` definition and portal script use `user_id`; the later hardening migration `20261109000500_harden_electrician_profile_identity_linking.sql` adds `auth_user_id`, reconciliation/synchronization logic, identity guard triggers, and a partial unique index.
- The starter file contains `commission_rate` and `commission_amount`, but the later reporting migration `20261109003000_secure_commission_reporting.sql` references `service_bookings.amount_paid`; that column is supplied by the later restore migration, not by the historical starter table.
- The starter SQL includes auth-linked objects and triggers on `auth.users`; a disposable local baseline must therefore use the matching Supabase Auth schema and required roles/extensions rather than plain PostgreSQL alone.

### Replay-readiness conclusion
The repository-root SQL files are historical setup scripts, not an approved immutable snapshot of the current Production schema or a complete clean-replay baseline. They must not be treated as a direct `supabase db reset` input without a separately reviewed baseline and dependency manifest. This finding does not imply that the historical scripts are wrong for their original purpose.

No files were edited except this report. No SQL was executed, no Supabase CLI/Docker/PostgreSQL/pgTAP was run, and no Production connection, query, migration, or data change occurred.


## 30. Support/complaint schema, Storage policy और Admin helper provenance — 16 Nov 2026

इस चरण में current feature branch के source और संबंधित pgTAP test का read-only निरीक्षण किया गया। खास तौर पर complaint base tables, private Storage bucket/policies और `public.is_srk_admin()` की introducing source खोजी गई।

### 30.1 Complaint base tables — introducing source अभी नहीं मिला

`20261113230000_support_attachment_paths_and_admin_message_list.sql` में ये पहले से मौजूद objects उपयोग किए गए हैं:

- `public.srk_booking_complaints` — customer ownership और complaint existence जाँचने के लिए;
- `public.srk_booking_complaint_messages` — Admin message thread पढ़ने के लिए;
- `public.srk_booking_complaint_message_attachments` — attachment metadata पढ़ने के लिए।

यह migration इन तीनों base tables को CREATE नहीं करती। संबंधित support pgTAP test अतिरिक्त रूप से `srk_booking_complaint_messages_id_thread_uidx` unique index और `srk_complaint_attachment_message_thread_fk` foreign key की अपेक्षा करता है।

इस read-only branch search में इन base tables/index/FK को बनाने वाली कोई अलग migration या historical starter SQL definition नहीं मिली। इसलिए इनके exact columns, constraints, indexes, RLS policies और introducing migration अभी **unverified** हैं। Search results की सीमा के कारण इसे पूरे repository में अनुपस्थिति का अंतिम प्रमाण न माना जाए; अगली inventory pass में migration tree की प्रत्यक्ष सूची और हर candidate file की जाँच आवश्यक होगी।

### 30.2 Private support Storage bucket/policies — source gap

Customer frontend `srk-customer-support` नाम के Storage bucket में file upload और 300-second signed URL बनाता है। Support pgTAP test इन objects/functions की मौजूदगी और सुरक्षा की अपेक्षा करता है:

- `public.srk_customer_support_object_access(text,boolean)`;
- Storage object policy `srk_customer_support_read_own_or_admin` on `storage.objects`;
- `public.srk_customer_link_complaint_message_attachment(uuid,uuid,text,text,text,bigint)`;
- bucket `srk-customer-support`, object owner और complaint linkage की जाँच।

मौजूदा attachment-listing migration इन Storage objects/functions को define नहीं करती। Exact-name branch search में इनके introducing SQL का परिणाम नहीं मिला। इस कारण bucket creation/configuration, private/public setting, upload/read/delete policies, object ownership checks और attachment-link RPC का source provenance **unresolved** है। केवल frontend reference या test assertion से Storage bucket/policy का अस्तित्व सिद्ध नहीं होता।

### 30.3 `public.is_srk_admin()` — historical setup में definition मिली, migration में नहीं

अब historical root SQL में exact definition की पुष्टि हुई:

- `ADMIN_EMAIL_LOGIN_SETUP.sql` में `CREATE OR REPLACE FUNCTION public.is_srk_admin()` मौजूद है; यह `SECURITY DEFINER`, `STABLE`, `SET search_path = public, auth` है और `public.srk_admin_users` में `auth.uid()` की मौजूदगी जाँचता है। यह PUBLIC से EXECUTE revoke कर `authenticated` को grant करता है।
- `COMPLETE_DATABASE_SETUP.sql` में इसी function की Admin email-login compatibility definition भी मौजूद है।
- उसी historical setup में पहले `public.srk_is_admin()` नाम का अलग helper भी है। दोनों नाम अलग database objects हैं; इन्हें interchangeable नहीं माना जा सकता।
- इस branch search में `public.is_srk_admin()` की introducing versioned migration नहीं मिली। कई बाद की migrations (booking read policy, commission reporting, wallet और support message listing) इसे dependency के रूप में call करती हैं।

अतः helper का historical setup source ज्ञात है, लेकिन current migration chain में इसे स्थापित करने वाला authoritative versioned migration और clean-replay placement अभी नहीं मिला। Baseline में helper मौजूद होने की पुष्टि के बिना dependent migrations का replay सुरक्षित घोषित नहीं किया जा सकता।

### 30.4 प्रभाव और अगला read-only कदम

यह support area केवल attachment-listing function तक सीमित नहीं है। इसकी runtime dependency chain में complaint tables, message/attachment relational integrity, private Storage bucket/policies, attachment-link RPC और Admin helper सभी शामिल हैं। इनके बिना support pgTAP file की function/policy introspection assertions भी fail या unresolved हो सकती हैं।

अगला सुरक्षित कदम migration directory की प्रत्यक्ष पूरी inventory से support/complaint/Storage candidate files पहचानना और उनके complete SQL bodies की जाँच करना है। यदि कोई introducing source वास्तव में branch में नहीं है, तो उसे स्पष्ट missing-baseline item के रूप में दर्ज किया जाए; अनुमान से नया schema या migration न बनाया जाए।

**सीमा:** यह source-only निरीक्षण है। कोई SQL execute नहीं हुआ; pgTAP, Supabase CLI, Docker या PostgreSQL नहीं चलाया गया; Production से संपर्क/पढ़ाई/बदलाव नहीं हुआ; कोई migration, application source या Storage object नहीं बदला गया।


## 31. Support migration directory की प्रत्यक्ष inventory से Section 30 का संशोधन — 16 Nov 2026

Section 30 के बाद migration directory की GitHub Contents API inventory को प्रत्यक्ष रूप से पढ़ा गया। कुल 87 migration filenames की सूची मिली। इस पूरी सूची में support के वे दो महत्वपूर्ण migration files मिले जो पहले exact-name code search में सामने नहीं आए थे। इसलिए Section 30 में complaint base tables और Storage setup को “introducing source नहीं मिला” कहना अधूरा था। नीचे corrected source-of-truth दर्ज है।

### 31.1 Complaint base schema का source मिल गया

`20261110040000_customer_admin_complaints.sql` ये objects बनाती है:

- `public.srk_booking_complaints` — customer booking complaint, category, description, status, Admin note और resolution metadata;
- `public.srk_booking_complaint_events` — complaint status/activity history;
- complaint created/booking/status indexes;
- customer complaint create/list RPCs और Admin complaint list/update RPCs;
- दोनों base tables पर RLS enable और direct table privileges revoke।

यह migration `service_bookings.customer_user_id` और `public.is_srk_admin()` पर निर्भर है। Customer account field पहले वाली `20261108121115_add_customer_account_booking_access.sql` migration में जोड़ी जाती है। `is_srk_admin()` की migration-chain introducing definition फिर भी नहीं मिली; इसका ऐतिहासिक root setup source Section 30.3 में दर्ज है।

### 31.2 Conversation/attachment schema और private Storage source मिल गया

`20261113220000_customer_support_conversation_schema.sql`:

- `srk_booking_complaint_messages` और `srk_booking_complaint_message_attachments` tables बनाती है;
- attachment thread integrity के लिए composite unique index और composite foreign key बनाती है;
- customer message send/list और attachment-link RPCs बनाती है;
- `srk-customer-support` bucket को private (`public=false`) बनाकर 10 MiB size limit और JPEG/PNG/WebP/PDF MIME allowlist सेट करती है;
- `srk_customer_support_object_access(text,boolean)` helper बनाती है;
- authenticated customer के complaint-folder upload/delete और customer-owner-or-Admin read के लिए Storage object policies बनाती है;
- base support message/attachment tables पर RLS enable और direct privileges revoke करती है।

Attachment linker Storage object के bucket ID, path prefix, customer ownership, complaint ownership, customer-authored message और file metadata की जाँच के बाद metadata row insert करता है।

### 31.3 Support dependency order — source के अनुसार

1. `20261108121115_add_customer_account_booking_access.sql` — `service_bookings.customer_user_id` prerequisite।
2. Authoritative baseline में `public.is_srk_admin()` और `srk_admin_users` उपलब्ध होना चाहिए; current migrations में helper की introducing definition अब भी नहीं मिली।
3. `20261110040000_customer_admin_complaints.sql` — complaint/event base tables और customer/Admin complaint RPCs।
4. `20261113220000_customer_support_conversation_schema.sql` — complaint FK पर conversation/attachment tables, bucket, object access helper और Storage policies।
5. `20261113230000_support_attachment_paths_and_admin_message_list.sql` — customer attachment listing और Admin message/attachment listing RPCs।
6. `20261114300000_admin_customer_support_thread_replies.sql` — Admin reply RPC; prior complaint/message tables और Admin helper पर निर्भर।

`20261114350000_electrician_support_tickets_and_admin_inbox.sql` अलग electrician-support subsystem है। यह electrician profile identity fields (`user_id`, `auth_user_id`), booking, Auth users और Admin helper पर निर्भर होकर ticket/message tables तथा electrician/Admin RPCs बनाती है। इसे customer complaint Storage chain के साथ एक ही table family न समझें।

### 31.4 Corrected conclusion

- Complaint base table source **मिल गया**: migration `20261110040000`।
- Customer/Admin conversation, attachment schema और private Storage bucket/policies source **मिल गया**: migration `20261113220000`।
- Attachment/Admin listing और Admin reply migrations बाद के क्रम में मौजूद हैं।
- शेष प्रमुख unresolved dependency: `public.is_srk_admin()` का authoritative versioned migration/baseline source और उसका grants/privileges provenance।
- Source order एक उपयोगी dependency sequence देता है, लेकिन इससे Production application या migration replay safety सिद्ध नहीं होती। Duplicate 20261109 prefix, approved baseline, remote migration lineage और Production provenance gates पहले जैसे खुले हैं।

यह Section 30 की “support base/Storage source नहीं मिला” वाली provisional बात को supersede करता है। Section 30 का `is_srk_admin()` provenance finding अभी भी लागू है। कोई SQL execute, migration replay, pgTAP run, Production access/change, DDL या application source modification नहीं हुआ।


## 32. Admin Staff RBAC migration और Main Admin helper dependency — 16 Nov 2026

Read-only inspection of `20261114390000_admin_staff_rbac_foundation.sql`, `20261116100000_fix_staff_permission_helper_volatility.sql`, and `20261115230000_admin_booking_direct_write_closure.sql` confirms:

- `20261114390000_admin_staff_rbac_foundation.sql` introduces `public.srk_has_admin_permission(text)` and the staff/session/audit/support-assignment RPC family. Its Main Admin bypass and multiple management paths call `public.is_srk_admin()`; it does not define that Main Admin helper.
- The staff migration explicitly keeps Main Admin identity in `public.srk_admin_users` and states that staff identities must not be inserted there. This is an important role-separation rule: delegated staff permissions are not equivalent to Main Admin identity.
- The 16 Nov volatility-fix migration replaces `srk_has_admin_permission(text)`; it still calls `public.is_srk_admin()` and does not create the Main Admin helper.
- The 15 Nov direct-write closure RPCs also call `public.is_srk_admin()` without defining it.

Therefore the Admin helper gap is not isolated to the older complaint/commission migrations: later Staff RBAC and booking-write-closure migrations also depend on it. A future approved baseline must supply the exact Main Admin helper and its allow-list table before these dependents. Do not substitute `srk_is_admin()` or `srk_has_admin_permission()` for `is_srk_admin()`; they have different names and roles.

No migration or policy was changed. No database execution, Production access, migration replay, or deployment occurred.


## 33. Main Admin allow-list table और helper — exact historical source cross-check — 16 Nov 2026

Exact-definition search और historical root SQL cross-check से निम्न बातें स्थापित हुईं:

- `PORTAL_SCHEMA.sql` में `public.srk_admin_users` का source DDL है: `user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE`, साथ में `created_at timestamptz NOT NULL DEFAULT now()`।
- `ADMIN_EMAIL_LOGIN_SETUP.sql` इस table पर RLS enable करता है, `srk_admin_users_self_read` policy authenticated user को केवल `user_id = auth.uid()` row पढ़ने देती है, और `public.is_srk_admin()` को `SECURITY DEFINER`, `STABLE`, `SET search_path = public, auth` के साथ define करता है। Function `srk_admin_users` में current `auth.uid()` की मौजूदगी देखता है; PUBLIC EXECUTE revoke और authenticated EXECUTE grant भी स्पष्ट हैं।
- `COMPLETE_DATABASE_SETUP.sql` में यही table/helper setup सम्मिलित है। ये historical setup SQL artifacts हैं; वर्तमान versioned migration chain का हिस्सा होने का प्रमाण नहीं।
- Current 87-file migration inventory और exact-definition search में `CREATE OR REPLACE FUNCTION public.is_srk_admin()` या `CREATE TABLE public.srk_admin_users` वाली कोई versioned migration नहीं मिली। Migration files इसे call करती हैं, पर helper/table को introduce नहीं करतीं।
- अतः exact historical definition और grants ज्ञात हैं; लेकिन clean migration replay में इन्हें कौन-सा approved versioned baseline स्थापित करता है, यह अब भी unresolved है। Historical SQL को स्वतः replay करने की अनुमति या सुरक्षितता इससे नहीं मिलती।

यह finding Sections 30–32 को और स्पष्ट करती है: Main Admin allow-list identity (`srk_admin_users`) और delegated staff permission helper (`srk_has_admin_permission`) अलग authorization layers हैं। Main Admin helper/table के बिना dependent migrations को replay-ready नहीं कहा जा सकता।

कोई historical SQL execute नहीं किया गया; कोई Admin identity/allow-list row नहीं पढ़ी या बदली गई; Production access, migration replay, DDL या deployment नहीं हुआ।


## 34. Finance, refunds, cancellation-fee और booking idempotency dependency audit — 16 Nov 2026

इस चरण में financial/refund/cancellation migrations और उनकी table/function dependencies का source-level मिलान किया गया।

### 34.1 Financial audit core — मुख्य finance base tables

`20261114125844_restore_financial_audit_core_schema.sql` निम्न relations बनाती है:

- `srk_booking_labour_bills`;
- `srk_manual_payment_entries`;
- `srk_electrician_payouts`;
- `srk_admin_audit_events`;
- `srk_razorpay_refunds`;
- `srk_booking_refund_requests`;
- `srk_manual_refund_entries`.

इनमें से अधिकांश पर RLS enable, browser roles के direct table privileges revoke और service_role grants लगाए गए हैं। Payouts के लिए authenticated SELECT को Admin predicate या संबंधित electrician profile ownership से सीमित policy दी गई है। Audit/refund capture triggers भी इसी migration में बनते हैं।

**Critical baseline dependency:** इसी migration में `ALTER FUNCTION public.is_srk_admin() SET search_path=''` है, फिर PUBLIC/anon execute revoke और authenticated/service_role execute grant हैं। यदि clean replay से पहले historical helper स्थापित नहीं है, तो यह migration उस बिंदु पर fail होगी। Current versioned migration inventory में helper/table का introducing migration नहीं मिला; इसलिए finance chain भी उसी unresolved Admin baseline पर निर्भर है।

### 34.2 Finance/refund chain का source-level क्रम

- `20261109010000_create_secure_wallet_ledger_foundation.sql` — wallet ledger foundation और Admin wallet RPCs; यह शुरुआती wallet base है।
- `20261114125844_restore_financial_audit_core_schema.sql` — bill/payment/payout/refund/audit core relations; receipt/history consumers से पहले रखने का migration comment है।
- `20261114190000` और `20261114200000` — customer receipt और payment-history RPCs; finance core relations पढ़ते हैं।
- `20261114270000` — cancellation request/event tables, direct booking cancellation guard और customer/Admin cancellation RPCs।
- `20261114280000` — wallet ledger में cancellation-fee type, cancellation-fee debt/item/ledger tables, reserve/release triggers, receipt/payment RPC replacements।
- `20261114290000` — full-refund पर cancellation-fee ledger और wallet reversal; prior cancellation-fee schema, wallet ledger और refund records पर निर्भर।
- `20261114410000` — Razorpay webhook event inbox और service-role claim/complete RPCs।
- `20261115100000`–`20261115130000` — customer refund request, Admin review, durable provider recovery evidence और manual refund completion RPCs।
- `20261115150000`, `15170000`, `15180000` — Admin accounting reconciliation RPCs की successive replacements/extensions; बाद के definitions पहले वाले function को replace करते हैं।
- `20261115200000` — payout/manual-refund SECURITY DEFINER RPC search_path hardening; पहले उन functions का मौजूद होना आवश्यक।
- `20261115240000` और `15250000` — refund recovery/finalization और refund reconciliation functions की successive hardening replacements।
- `20261115210000` — legacy manual payment और itemized receipt RPCs; पहले के finance tables और booking columns पर निर्भर।

यह sequence source chronology और explicit references पर आधारित dependency map है; complete executable topological order नहीं। Historical baseline, duplicate 20261109 version ambiguity और Production history reconciliation अभी बाकी हैं।

### 34.3 Booking submission idempotency

`20261114150000_customer_booking_submission_idempotency.sql` केवल `service_bookings` पर दो nullable columns जोड़ती है: `customer_request_key` और `customer_request_fingerprint`। साथ में fingerprint format CHECK और non-null request key पर unique partial index बनाती है। यह booking table की पहले से मौजूदगी पर निर्भर है। इस migration में client retry behavior या server RPC implementation नहीं है; वह application/RPC path में separately verify होना चाहिए। इसलिए schema idempotency columns की मौजूदगी अकेले end-to-end duplicate booking रोकने का runtime proof नहीं है।

### 34.4 Cancellation-fee/refund correctness review — सीमित static observations

- Cancellation-fee carry-forward migration `srk_wallet_ledger` के entry_type CHECK को replace करती है; wallet ledger की introducing migration और उसके exact prior constraint definition को replay baseline में शामिल करना होगा।
- Full-refund reversal trigger `service_bookings.payment_status` को refunded होते समय matching processed Razorpay refund या matching manual refund record की पुष्टि करता है; partial refund के लिए fail-closed path है।
- Cash cancellation-fee path में reversal electrician wallet ledger entry को credit करता है; इसलिए wallet ledger columns, enum/check values, unique/idempotency constraints और wallet row identity उसी exact source lineage से validate करनी होगी।
- ये static source conditions हैं; concurrency, transaction rollback, trigger firing, financial invariants और provider webhook behavior का runtime proof नहीं।

### 34.5 Current gate

Finance/refund source family काफी हद तक map हो चुकी है, लेकिन इसे replay-ready नहीं कहा जा सकता। अभी भी authoritative core baseline, `is_srk_admin()` helper provenance, exact wallet schema lineage, all booking columns, remote migration history और duplicate 20261109 reconciliation आवश्यक हैं। कोई finance RPC, payment/refund operation, webhook, migration, pgTAP test या Production action execute नहीं हुआ; कोई data या schema बदला नहीं गया।


## 35. Push delivery, KYC activation और SOS dependency audit — 16 Nov 2026

### 35.1 Push subscription और durable delivery chain

- `20261111020000_add_electrician_push_subscriptions.sql` पहली बार `public.srk_push_subscriptions` table बनाती है; यह `auth.users` पर निर्भर है और owner-scoped RLS policy लगाती है।
- `20261115170001_durable_push_delivery_outbox.sql` स्पष्ट preflight में `srk_private` schema, subscription table/columns, `job_offers.expires_at`, `electrician_profiles.available_for_work`, और electrician identity/approval columns मांगती है। यह prerequisites के बिना fail-fast करती है।
- `20261115180001_push_subscription_delivery_ledger.sql` outbox तथा subscription IDs पर per-device delivery ledger बनाती है।
- `20261115190001_push_delivery_health_monitoring.sql` outbox और device ledger के बाद health summary और dead-letter recovery RPC जोड़ती है।
- `20261115200001_push_delivery_lease_fencing.sql` पुराने finish RPC signatures हटाकर attempt-count/fencing-token signatures बनाती है; worker contract को उसी signature पर update करना जरूरी होगा।
- Push worker RPCs service_role-only हैं; delivery tables private schema में हैं और browser roles को direct access नहीं मिलता।

**नया baseline blocker:** मौजूदा 87 versioned migration files की inventory तथा `CREATE SCHEMA` source search में `srk_private` schema बनाने वाला कोई migration नहीं मिला। Push outbox migration इसे preflight में अनिवार्य मानती है। इसलिए इसका creator वर्तमान versioned migration chain में नहीं मिला। यह संभव है कि schema किसी पहले से मौजूद external/bootstrap setup से आता हो, लेकिन ऐसा authoritative evidence इस source audit में नहीं मिला। जब तक Database Owner उस schema की approved origin/ownership पुष्टि न करे या अलग approved baseline उपलब्ध न हो, clean replay gate बंद रहेगा। इसे स्वयं जोड़ना या Production में बनाना इस read-only scope में नहीं है।

### 35.2 KYC और electrician activation chain

- `20261115140000_electrician_kyc_review_and_activation_gate.sql` private Storage bucket `srk-electrician-verification` बनाता/अपडेट करता है; KYC document और append-only review event tables बनाता है; owner upload, owner/Admin read और unregistered-object delete Storage policies लगाता है।
- यह migration electrician profile, Auth users, Storage schema/bucket/object infrastructure, availability events, job offers, rate-tier activation guard और Main Admin helper पर निर्भर है।
- `20261114330000` document path lookup RPC और `20261114380000` phone-change approval workflow इसी identity/KYC domain के अलग components हैं।
- KYC event table के direct client privileges revoke हैं; document access RPCs और Storage object policies के माध्यम से नियंत्रित है।
- Bucket upsert existing bucket configuration बदल भी सकता है; इसलिए replay में existing bucket state/approved settings का parity check जरूरी है। कोई bucket या document बदला नहीं गया।

### 35.3 SOS और delegated staff permissions

- `20261115260000_sos_admin_support_alerts.sql` पहले `srk_admin_permissions` और `srk_admin_role_permissions` में SOS read/acknowledge permissions insert करता है; फिर SOS alert और append-only event tables तथा Main Admin/authorized Support Staff RPCs बनाता है।
- इन permission tables का introducing source `20261114390000_admin_staff_rbac_foundation.sql` है। इसलिए RBAC foundation से पहले SOS migration चलाना dependency failure होगा।
- SOS migration के comments स्पष्ट करते हैं कि इस backend source में SMS/Push provider configured नहीं है और automatic police/112 notification नहीं है। Database record/acknowledgement RPC को वास्तविक alert-delivery समझना गलत होगा।
- SOS RPC authorization `srk_has_admin_permission(text)` और Main Admin helper `is_srk_admin()` की existing provenance/behavior पर निर्भर है; helper baseline gap पहले के sections में unresolved है।

### 35.4 Test और replay निष्कर्ष

Push/KYC/SOS source definitions और dependency checks अब map किए गए हैं, पर वर्तमान branch के इस GPT-2 run में कोई migration apply, PostgreSQL/pgTAP runtime test, push worker invocation, Storage write, KYC upload/review, SOS creation, provider delivery या Production query नहीं किया गया। Historical checklist/search snippets को वर्तमान branch runtime proof नहीं माना गया। Replay readiness अभी भी BLOCKED है: `srk_private` schema origin, core baseline, Main Admin helper, worker contract/version parity और authoritative remote migration lineage की पुष्टि बाकी है।


## 36. Search-path hardening chronology और amount_paid column-order risk — 16 Nov 2026

### 36.1 SECURITY DEFINER search_path pin migrations

मौजूदा 16 Nov pin migrations की source-level समीक्षा:

- `20261116110000`: commission report, wallet summary और Admin wallet overview functions पर empty search_path।
- `20261116120000`: private customer-call implementation और public wrapper पर empty search_path।
- `20261116130000`: wallet summary/Admin overview को फिर से pin करता है; साथ में electrician earnings और customer receipt RPC pin करता है।
- `20261116140000`: electrician offer-details RPC pin।
- `20261116150000`: Admin application-review RPC pin।
- `20261116160000`: तीन legacy quote/work-status RPC signatures को `ALTER FUNCTION IF EXISTS` से pin; यह पहले retire किए गए installations पर missing-function error को टालता है।
- `20261116170000`: public rate-limit RPC pin।

**Duplicate pin observation:** `srk_get_my_wallet_summary()` और `srk_admin_wallet_overview()` पर 16110000 और 16130000 दोनों में वही empty search_path सेट होता है। यह duplicate hardening statement है; source text में अलग function body/ACL बदलाव नहीं। इसे अपने आप में runtime failure नहीं माना गया। Replay review में इसे harmless redundancy के रूप में note किया जाए, स्वतः edit/remove नहीं।

इन ALTER statements का सफल होना उनके exact function signatures के पहले से मौजूद होने पर निर्भर है। संबंधित creator/replace migrations और IF EXISTS exceptions को replay manifest में रखना होगा। Source inspection ने इन ALTER statements को execute नहीं किया।

### 36.2 `amount_paid` का chronology / clean-replay risk

Current branch inventory में `service_bookings.amount_paid` जोड़ने वाला स्पष्ट DDL केवल:
`20261116200000_restore_service_bookings_amount_paid.sql`
में मिला; यह nullable `numeric(12,2)` column और nonnegative CHECK (`NOT VALID`) जोड़ता है।

इससे पहले की source migrations में:
- `20261109003000_secure_commission_reporting.sql` — authenticated role को column-level UPDATE grant में `amount_paid` शामिल करता है और commission reporting function इसे पढ़ता है।
- `20261115160000_legacy_booking_status_write_guard.sql` — column-level UPDATE grant में `amount_paid` शामिल करता है।
- `20261115230000_admin_booking_direct_write_closure.sql` — `amount_paid` का उपयोग करता है और column-level UPDATE revoke में इसे शामिल करता है।
- `20261115210000_legacy_manual_payment_and_itemized_receipt.sql` — payment/receipt RPC logic में `amount_paid` पढ़ता और update करता है।
- `20261114190000` और `20261114200000` — receipt/payment-history functions में `amount_paid` पढ़ते हैं।

Function body में कुछ column references PL/pgSQL runtime पर resolve हो सकते हैं, पर column-level GRANT/REVOKE statements को target column का मौजूद होना आवश्यक है। इसलिए खास तौर पर 09003000 और 15160000 के column-level grants, और 15230000 के column-level revoke, यदि उस समय column अनुपस्थित हो तो migration application रोक सकते हैं।

**स्थिति को सावधानी से समझें:** यह source chronology से निकला conditional clean-replay risk है। किसी ऐतिहासिक starter SQL या live schema में column पहले से मौजूद हो सकता है; लेकिन उपलब्ध source inventory ने ऐसा authoritative starter definition स्थापित नहीं किया। बाद की 16200000 “restore” migration स्वयं इस सवाल का जवाब नहीं देती कि पहले की migrations किस baseline पर सफल हुई थीं। इसलिए:
1. exact approved starter schema में `amount_paid` की मौजूदगी/अनुपस्थिति स्थापित करनी होगी;
2. Production/remote migration history और execution evidence अलग से reconcile करनी होगी;
3. उसके बाद ही migration order/forward-fix पर authorized owner निर्णय ले सकता है।

इस खोज के आधार पर migration reorder, rename, edit, repair या replay नहीं किया गया।

### 36.3 निष्कर्ष

Search-path hardening family source-level mapped है; दो repeated ALTER statements दर्ज हैं। `amount_paid` chronology एक अधिक गंभीर conditional replay gate है और authoritative baseline के बिना clean replay को सुरक्षित घोषित नहीं किया जा सकता। कोई DB query, PostgreSQL/pgTAP execution, Production access, payment action, DDL, data change या deployment नहीं हुआ।



## 37. Historical starter SQL में amount_paid की अनुपस्थिति की पुष्टि — 16 Nov 2026

Section 36 के conditional column-order risk को जाँचने के लिए current branch पर उपलब्ध दोनों historical starter files के पूरे शुरुआती `service_bookings` table definitions पढ़े गए:

- `SUPABASE_SCHEMA.sql` में `service_bookings` की पूरी CREATE TABLE definition में `amount_paid` column नहीं है।
- `COMPLETE_DATABASE_SETUP.sql` के consolidated starter section में भी वही base table definition है और उसमें `amount_paid` नहीं है।
- `20261116200000_restore_service_bookings_amount_paid.sql` इस column को बाद में `ADD COLUMN IF NOT EXISTS` से जोड़ती है।
- इसके विपरीत `20261109003000_secure_commission_reporting.sql`, `20261115160000_legacy_booking_status_write_guard.sql` और `20261115230000_admin_booking_direct_write_closure.sql` पहले ही column-level GRANT/REVOKE में `amount_paid` का नाम लेते हैं।

**इससे क्या सिद्ध होता है:** उपलब्ध दोनों ऐतिहासिक starter SQL definitions इस column को स्थापित नहीं करतीं; इसलिए यदि इन्हीं definitions को शुरुआती schema baseline मानकर migration chronology replay की जाए, तो पहले के column-level privilege statements का target column अनुपस्थित होगा। यह source-level clean-replay blocker को पहले से अधिक मजबूत बनाता है।

**क्या अभी भी सिद्ध नहीं है:** ये दो ऐतिहासिक SQL files authoritative/approved Production bootstrap baseline हैं, ऐसा प्रमाण उपलब्ध नहीं। किसी अलग manual bootstrap, dashboard SQL, external migration, या पुराने schema snapshot में column पहले जोड़ा गया हो सकता है। Production history और execution logs की स्वतंत्र पुष्टि अभी भी Database Owner से चाहिए।

इसलिए निर्णय अभी भी **REPLAY BLOCKED / OWNER EVIDENCE REQUIRED** है। कोई migration reorder/edit/repair/replay, DDL, Production query या data change नहीं किया गया।



## 38. Customer/Admin booking SELECT policy replacement और direct-write ACL chronology — 16 Nov 2026

### 38.1 Booking read policies additive नहीं, explicit replacement हैं

Current branch source में:
- `20261108121115_add_customer_account_booking_access.sql` customer ownership column/index और अलग `srk_customer_read_own_bookings` SELECT policy बनाती है।
- `20261108234000_combine_booking_read_policy.sql` पहले पुराने `srk_admin_read_bookings` और `srk_customer_read_own_bookings` दोनों को DROP करती है, फिर एक `srk_admin_or_customer_read_bookings` policy बनाती है।
- Combined policy में केवल Main Admin predicate `public.is_srk_admin()` या `auth.uid() = customer_user_id` से row visibility मिलती है।

इसलिए इन दोनों migration files का क्रम महत्वपूर्ण है: combined-policy migration पुराने policy names को हटाकर एक स्पष्ट OR-policy स्थापित करती है। इस pair में पुरानी customer policy के साथ duplicate permissive policy बचने का source-level संकेत नहीं मिला। लेकिन यह निष्कर्ष केवल इन दो files तक सीमित है; सभी tables की सभी policy combinations का exhaustive runtime audit नहीं है।

### 38.2 Booking direct UPDATE privilege chronology

- `20261109003000_secure_commission_reporting.sql` authenticated role का table-wide UPDATE revoke करके सीमित columns पर UPDATE grant करती है; इस सूची में `amount_paid` शामिल है।
- `20261115160000_legacy_booking_status_write_guard.sql` table-wide UPDATE फिर revoke करके केवल quote/payment columns पर सीमित grant देती है; इसमें भी `amount_paid` शामिल है।
- `20261115230000_admin_booking_direct_write_closure.sql` अंत में table-wide UPDATE और status/quote/payment/location column UPDATE privileges revoke करती है; intended write path validated SECURITY DEFINER RPCs/server payment workflows है।

यह source chronology दिखाती है कि direct-write privilege posture क्रमशः tighten होती है। पहले के grants को बाद की closure migration से अलग पढ़ना पर्याप्त नहीं; clean replay में अंतिम effective ACL और RLS policies दोनों का संयुक्त परीक्षण चाहिए। केवल GRANT/REVOKE statements से row-level authorization सिद्ध नहीं होता।

### 38.3 अभी बाकी सत्यापन

- सभी `service_bookings` policies की complete inventory और permissive/restrictive mode का एक consolidated matrix।
- सभी relevant tables पर RLS enabled status तथा table/column privileges का final effective-state snapshot।
- RPC execute grants के साथ SECURITY DEFINER owner, search_path और called helper authorization का मिलान।

ये तीनों checks source/runtime parity के लिए शेष हैं। कोई SQL execution, ACL परिवर्तन, policy परिवर्तन, migration replay या Production access नहीं हुआ।



## 39. RLS/ACL/RPC संयुक्त जाँच — private schema, server-only ledger और Storage dependencies — 16 Nov 2026

### 39.1 `private` और `srk_private` अलग schemas हैं

अब current migration source में `private` schema के explicit creators मिल गए:
- `20261108120608_add_public_api_rate_limiting.sql` में `create schema if not exists private` और server-only rate-limit table/function।
- `20261109103143_move_customer_call_contact_lookup_to_private.sql` में भी `create schema if not exists private` और private contact-lookup implementation।

इससे `private` schema के source-level creator का gap बंद होता है। लेकिन यह `srk_private` schema से अलग नाम है। Section 35 में `srk_private` के migration creator का न मिलना अभी भी unresolved है; दोनों schemas को एक न माना जाए।

### 39.2 Server-only table ACL का उदाहरण

`20261109020000_create_server_only_razorpay_route_transfer_ledger.sql`:
- `public.srk_route_transfers` पर RLS enable करती है।
- `anon` और `authenticated` से सभी table privileges revoke करती है।
- `service_role` को SELECT/INSERT/UPDATE देती है।
- Source comment स्पष्ट करता है कि DB ledger write अपने-आप Razorpay money movement नहीं करता।

`20261108120608` की rate-limit table भी `anon`/ `authenticated` से बंद है और `service_role` के लिए है; rate-limit RPC execute भी केवल `service_role` को मिलता है।

### 39.3 SECURITY DEFINER / Storage boundary

`20261114180000_harden_customer_avatar_object_integrity.sql` में profile RPC SECURITY DEFINER और empty search_path के साथ है। Function Storage object metadata, bucket ID, owner, MIME type, size और user-folder path जाँचता है; execute privilege `authenticated` को दिया गया है, जबकि public/anon revoke हैं। यह Storage schema/table/bucket की पहले से मौजूद Supabase infrastructure पर निर्भर है। Source पढ़ने से bucket/object policies की live स्थिति सिद्ध नहीं होती।

### 39.4 संयुक्त जाँच-सूची की वर्तमान स्थिति

| जाँच क्षेत्र | Source से मिला निष्कर्ष | शेष प्रमाण |
|---|---|---|
| Booking read policies | Customer/Admin policy replacement स्पष्ट | सभी tables की पूर्ण policy inventory और effective mode |
| Booking direct UPDATE | privilege grants बाद में closure से revoke | effective table/column ACL + RLS संयुक्त snapshot |
| Server-only ledger | RLS + anon/authenticated revoke + service_role grants | Production effective ACL snapshot |
| Rate limiting | private schema/table और service_role-only RPC source में | private schema/table runtime parity |
| RPC execute grants | कई RPCs में public/anon revoke और authenticated/service_role grant स्पष्ट | सभी overloads/signatures और अंतिम grants की exhaustive सूची |
| SECURITY DEFINER | अलग-अलग search_path patterns, कुछ empty path | प्रत्येक function में object qualification, owner और helper chain review |
| Storage | avatar RPC storage.objects metadata पढ़ती है | bucket existence/config, RLS policies और ownership metadata parity |
| Internal schema | `private` का creator मिला | `srk_private` creator अभी नहीं मिला |

**स्थिति:** यह source-only ACL/RLS/RPC reconciliation है, complete effective-state certification नहीं। विशेष रूप से `private` की मौजूदगी `srk_private` की मौजूदगी सिद्ध नहीं करती। कोई SQL/Production query, migration execution, permission edit, data write या deployment नहीं किया गया।


## 40. SECURITY DEFINER RPC सूची और authorization review — 16 Nov 2026

### 40.1 Source में पहचाने गए प्रमुख RPC समूह

निम्न migrations में SECURITY DEFINER functions और उनके explicit EXECUTE grants मिले:

| Migration / RPC समूह | Search path | Authorization/source observation |
|---|---|---|
| `20261109003000` — Admin commission report | `public, pg_temp` | `auth.uid()` और `public.is_srk_admin()` दोनों जाँचता है; PUBLIC/anon revoke, authenticated grant |
| `20261109003000` — electrician earnings | `pg_catalog, public, auth, pg_temp` | `auth.uid()` से approved electrician profile सीमित; PUBLIC/anon revoke |
| `20261109010000` — wallet summary | `public, pg_temp` | login अनिवार्य; wallet summary current UID से सीमित; authenticated grant |
| `20261109010000` — Admin wallet overview | `public, pg_temp` | `is_srk_admin()` gate; authenticated grant |
| `20261109001000` — Admin application review | `pg_catalog, public, auth, pg_temp` | `auth.uid()` + `is_srk_admin()` gate |
| `20261109...` quote workflow | `pg_catalog, public, auth, pg_temp` | quote submit/work status approved active assigned electrician से; quote response customer_user_id से |
| `20261109...` offer details | `pg_catalog, public, auth, pg_temp` | authenticated electrician profile के user_id से offer list सीमित |
| `20261114190000` — payment receipt | `pg_catalog, public, auth, pg_temp` | login और customer booking ownership checks; PUBLIC/anon revoke |
| `20261114200000` — payment/refund history | empty search_path | fully qualified object references और UID-owned bookings; PUBLIC/anon revoke |
| `20261113230000` — support attachment/message RPCs | empty search_path | Admin listing functions `is_srk_admin()` gate करती हैं; customer listing अलग ownership checks करती है |

यह source-discovered सूची है, database की exhaustive function catalog नहीं। GitHub code search की सीमाओं के कारण इसे सभी functions की पूर्ण inventory न माना जाए।

### 40.2 Authorization और grants के बारे में निष्कर्ष

- Admin commission, wallet overview, application review और support Admin listing RPCs authenticated role को execute देती हैं, लेकिन function body में Main Admin helper check भी है। इसलिए केवल EXECUTE grant से Admin authorization सिद्ध नहीं होता; helper की वास्तविक definition और runtime behavior निर्णायक हैं।
- Customer receipt/history RPCs UID-आधारित booking ownership लागू करती हैं।
- Quote workflow में customer response को `customer_user_id=auth.uid()` से बाँधा गया है; electrician operations को approved/active profile और assigned booking से।
- Offer details RPC customer contact fields तभी लौटाती है जब booking उसी electrician profile को assigned हो; source में यह conditional masking दिखती है।
- Rate-limit RPC केवल `service_role` execute के लिए है; सामान्य authenticated/anon execute revoke है।
- Customer contact lookup का private implementation SECURITY DEFINER है, पर outer public wrapper SECURITY INVOKER है। Private implementation में customer UID के अपने bookings पर filter है।

### 40.3 Search path और unresolved proof

- कई पुराने RPCs `search_path = public, pg_temp` उपयोग करते हैं; नए customer-facing RPCs में `pg_catalog` पहले या empty search_path का उपयोग मिलता है।
- Empty search_path वाले functions में schema-qualified object references का source review किया गया; runtime owner, object ownership और function body की वास्तविक deployed definition फिर भी Production catalog से ही सिद्ध होगी।
- Source code से SECURITY DEFINER function का effective owner, live EXECUTE privileges, PUBLIC default privileges, overload collisions, और helper function का deployed body प्रमाणित नहीं हो सकता।
- Main Admin helper `public.is_srk_admin()` की versioned migration provenance अब भी नहीं मिली। कई Admin RPCs इसी helper पर निर्भर हैं; इसलिए यह एक साझा unresolved dependency है।
- `srk_has_admin_permission(text)` Staff RBAC helper को `is_srk_admin()` से अलग identity/authorization layer समझना होगा; इसे Main Admin helper का विकल्प नहीं माना जाए।

### 40.4 अगला आवश्यक authoritative read-only evidence

DBA/GPT-1 से केवल read-only catalog evidence चाहिए:
1. प्रत्येक listed function का exact identity/signature, `prosecdef`, owner, `proconfig/search_path`, और deployed definition hash/definition।
2. प्रत्येक signature के लिए `PUBLIC`, `anon`, `authenticated`, `service_role` EXECUTE ACL और overload inventory।
3. `is_srk_admin()` तथा `srk_has_admin_permission(text)` के deployed owner, body, EXECUTE ACL और dependency chain।
4. संबंधित roles की schema USAGE/CREATE permissions, विशेषकर `public`, `private` और `srk_private`।

**स्थिति:** source-level review में कई RPCs के explicit grants और UID/Admin gates मिले; इसे effective Production security certification नहीं कहा जा सकता। कोई Production query, SQL execution, grant/revoke, function replacement या deployment नहीं किया गया।


## 41. GPT-1/DBA के लिए न्यूनतम Production catalog evidence request — केवल read-only — 16 Nov 2026

Source audit से अब यह स्पष्ट है कि शेष प्रश्न GitHub source से हल नहीं हो सकते: Production में function का वास्तविक owner, deployed body/config और प्रभावी ACL catalog से ही प्रमाणित होंगे। इसलिए अगला कदम किसी remediation का नहीं, केवल metadata-only catalog evidence का है।

### 41.1 सभी SECURITY DEFINER functions का catalog snapshot

GPT-1/DBA नीचे का SELECT Production SQL Editor में read-only रूप से चला सकते हैं। यह application/customer/payment rows नहीं पढ़ता; केवल function metadata और ACL दिखाता है।

```sql
select
  n.nspname as schema_name,
  p.proname as function_name,
  pg_get_function_identity_arguments(p.oid) as identity_arguments,
  pg_get_userbyid(p.proowner) as function_owner,
  p.prosecdef as security_definer,
  p.provolatile as volatility,
  p.proconfig as function_settings,
  pg_get_function_result(p.oid) as result_type,
  p.proacl as function_acl,
  pg_get_functiondef(p.oid) as deployed_definition
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname in ('public','private','srk_private')
  and p.prosecdef = true
order by n.nspname, p.proname,
         pg_get_function_identity_arguments(p.oid);
```

### 41.2 Main Admin और Staff helper के exact signatures

```sql
select
  n.nspname as schema_name,
  p.proname as function_name,
  pg_get_function_identity_arguments(p.oid) as identity_arguments,
  pg_get_userbyid(p.proowner) as function_owner,
  p.prosecdef as security_definer,
  p.provolatile as volatility,
  p.proconfig as function_settings,
  p.proacl as function_acl,
  pg_get_functiondef(p.oid) as deployed_definition
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.proname in ('is_srk_admin','srk_has_admin_permission')
order by p.proname, pg_get_function_identity_arguments(p.oid);
```

### 41.3 Schema usage/create ACL और default function ACL

```sql
select
  n.nspname as schema_name,
  r.rolname as role_name,
  has_schema_privilege(r.oid, n.oid, 'USAGE') as has_usage,
  has_schema_privilege(r.oid, n.oid, 'CREATE') as has_create
from pg_namespace n
cross join pg_roles r
where n.nspname in ('public','private','srk_private')
  and r.rolname in ('anon','authenticated','service_role','postgres')
order by n.nspname, r.rolname;

select
  coalesce(n.nspname, '<all schemas>') as schema_name,
  pg_get_userbyid(d.defaclrole) as grantor_role,
  d.defaclobjtype as object_type,
  d.defaclacl as default_acl
from pg_default_acl d
left join pg_namespace n on n.oid = d.defaclnamespace
where d.defaclobjtype = 'f'
order by 1,2;
```

### 41.4 Evidence लौटाने का न्यूनतम प्रारूप

GPT-1/DBA से केवल ऊपर के result sets और query timestamp/environment label चाहिए। कोई password, API key, service-role secret, customer row, phone, payment record या personal data नहीं चाहिए। अगर output में deployed function definition लौटाना policy के अनुसार संभव न हो, तो कम-से-कम owner, signature, `prosecdef`, `provolatile`, `proconfig` और ACL लौटाएँ।

### 41.5 Source provenance पर निष्कर्ष

- `public.is_srk_admin()` का exact SECURITY DEFINER implementation केवल historical `ADMIN_EMAIL_LOGIN_SETUP.sql` और `COMPLETE_DATABASE_SETUP.sql` में मिला; इसे introduce करने वाली versioned migration source search में नहीं मिली।
- `public.srk_has_admin_permission(text)` का current helper implementation `20261116100000_fix_staff_permission_helper_volatility.sql` में है; यह Main Admin helper को call करता है।
- `srk_private` schema creator और function/schema effective ACL अभी भी source evidence से सिद्ध नहीं।
- Production catalog output मिलने तक function ownership, deployed helper body, default ACL, और schema-level access को **UNVERIFIED / OWNER EVIDENCE REQUIRED** माना जाएगा।

**सुरक्षा सीमा:** ऊपर के statements SELECT-only catalog inspection हैं। GPT-2 ने इन्हें Production में execute नहीं किया। कोई migration, DDL, grant/revoke, function edit, data change या deployment नहीं किया गया।


## 42. Local Supabase harness और वास्तविक test inventory की पुनः जाँच — 16 Nov 2026

### 42.1 Local harness अभी repository में अधूरा है

Current Feature Branch पर सीधे जाँच में:
- `supabase/` directory में `functions/`, `migrations/`, `tests/` मौजूद हैं।
- `supabase/config.toml` नहीं मिला (GitHub Contents API पर exact path 404)।
- Root `package.json` में `npm test` केवल `node --test tests/*.test.js` चलाता है; PostgreSQL या pgTAP script नहीं है।
- इसलिए वर्तमान checkout अपने-आप `supabase start` / `supabase test db` के लिए complete, initialized local Supabase project नहीं है। पहले isolated scratch/worktree में pinned Supabase CLI से config/harness बनाना और review करना होगा; अभी branch में generated config commit नहीं की गई।

### 42.2 Database pgTAP inventory की स्थिति

- `supabase/tests/database/` में **32** SQL test files मौजूद हैं।
- Staff RBAC और SOS Admin/Support के targeted contracts क्रमशः `plan(69)` और `plan(28)` के रूप में दर्ज हैं; §2 और §25 में static count verification पहले दर्ज है।
- इन 32 SQL files का होना runtime pass नहीं है। कोई pgTAP test अभी execute नहीं हुआ।

### 42.3 Migration version gate की exact स्थिति

- Current migration directory में **87** SQL files हैं।
- `20261109_allow_quote_approval_booking_states.sql` और `20261109_electrician_inspection_quotes_and_service_only_commission.sql` दोनों का extracted version ठीक `20261109` है।
- `tests/database-migration-version-uniqueness.test.js` इस duplicate को सामान्य valid unique pair नहीं मानता; यह इसे एक explicit `approvedLegacyCollision` allow-list exception में दर्ज करता है। इसका अर्थ केवल इतना है कि repository test इस ज्ञात collision को फिलहाल स्वीकार करता है—यह Supabase CLI replay compatibility या remote history correctness का प्रमाण नहीं।
- Staff RBAC foundation file का वास्तविक नाम `20261114390000_admin_staff_rbac_foundation.sql` मिला। इस migration में Staff tables, RLS, browser-role revokes, permission helper और session/audit structures हैं; इसलिए local test में Auth schema/session prerequisites निर्णायक हैं। यह अलग से कोई नया Production finding नहीं है।

### 42.4 इस pass का निष्कर्ष और अगला सुरक्षित कदम

**Local DB creation: NOT STARTED. Runtime tests: NOT RUN.**

अभी local replay शुरू न करने के दो प्रत्यक्ष repository blockers हैं:
1. `supabase/config.toml` / reviewed local harness अनुपस्थित है।
2. duplicate `20261109` version collision का CLI-compatible resolution और authoritative migration-history reconciliation बाकी है।

इसके अतिरिक्त §37 में दर्ज base-schema/column provenance और §41 में माँगा गया owner catalog evidence भी unresolved है। अगला सुरक्षित technical step isolated scratch checkout में pinned Supabase CLI + Docker availability की पुष्टि करके केवल disposable dummy migrations पर समान 8-digit version behavior जाँचना है; उसके बाद ही project migration replay design पर लौटना चाहिए। Production credentials/network का उपयोग नहीं करना है।

**इस pass में:** GitHub branch files और directory inventory ही पढ़े गए। कोई config generate/commit, migration edit/rename/reorder, SQL execution, Docker stack start, pgTAP run, Production query या deployment नहीं किया गया।


## 43. Scratch runtime की वास्तविक executable availability — 16 Nov 2026

इस execution environment में shell से सीधे executable lookup किया गया:

| Tool | परिणाम |
|---|---|
| Node.js | उपलब्ध — v22.16.0 |
| npm | उपलब्ध — 10.9.2 |
| Supabase CLI (`supabase`) | उपलब्ध नहीं |
| Docker CLI (`docker`) | उपलब्ध नहीं |
| Podman (`podman`) | उपलब्ध नहीं |
| PostgreSQL client (`psql`) | उपलब्ध नहीं |
| pgTAP runner (`pg_prove`) | उपलब्ध नहीं |

इसलिए अभी इसी environment में disposable Supabase stack शुरू करना, PostgreSQL server उपलब्ध कराना, या pgTAP runtime चलाना संभव नहीं है। Dummy migration collision का वास्तविक Supabase CLI experiment भी CLI के बिना नहीं किया गया; केवल filename/source collision पहले से प्रमाणित है। कोई package install, Docker daemon access, remote connection या database command चलाने का प्रयास नहीं किया गया।

### निर्णय

- **Node test tooling:** runtime मौजूद है, लेकिन repository checkout इस shell में उपलब्ध न होने के कारण repository का `npm test` इस pass में नहीं चलाया।
- **Supabase/PostgreSQL runtime:** BLOCKED — आवश्यक binaries अनुपस्थित।
- **Migration replay / pgTAP:** NOT RUN।
- **अगला आवश्यक सक्षम वातावरण:** isolated machine/runner जिसमें Docker daemon और pinned Supabase CLI हों, repository checkout scratch worktree में हो, और Production credentials/network secrets अनुपस्थित हों। वहाँ पहले dummy duplicate-version fixture पर CLI behavior जाँचा जाए; project migrations को अभी replay न किया जाए।

यह Section 43 केवल environment capability evidence है; इससे Production की स्थिति या Supabase CLI के duplicate-version behavior के बारे में कोई नया निष्कर्ष नहीं निकाला गया।


## 44. Staff RBAC और SOS pgTAP contracts: structural बनाम behavioral coverage — 16 Nov 2026

दो targeted pgTAP files को पूरा पढ़कर उनके assertion bodies और test harness calls की जाँच की गई:

- `admin_staff_rbac_foundation.test.sql`: 375 lines, `plan(69)`, `finish()`, `ROLLBACK`.
- `sos_admin_support_alerts.test.sql`: 111 lines, `plan(28)`, `finish()`, `ROLLBACK`.

### 44.1 ये tests अभी क्या प्रमाणित करते हैं

इनका मुख्य तरीका catalog और stored function source inspection है:
- `has_table`, `has_column`, `has_function`, `has_trigger`;
- `has_table_privilege` और `has_function_privilege`;
- `pg_get_functiondef`, `pg_get_function_result`, `pg_proc.provolatile`;
- stored function body में expected permission names, ownership checks, row-lock clauses और audit insert text की उपस्थिति।

इससे schema objects, grants और function source contracts का अच्छा structural guard मिलता है।

### 44.2 वास्तविक runtime authorization cases अभी इस pair में execute नहीं होते

दोनों files में निम्न behavioral harness calls नहीं मिले:
- `set_config` / `request.jwt.claims` से अलग-अलग JWT/Auth identities स्थापित करना;
- `SET ROLE anon` / `SET ROLE authenticated` करके वास्तविक caller privilege context में RPC call;
- pgTAP `throws_ok`, `lives_ok`, `results_eq` या `is_empty` से allow/deny परिणाम assert करना;
- Staff invite/activation, exact Auth session registration, revocation, suspension, assignment, reply और status transitions के लिए fixture rows बनाकर RPC invoke करना;
- concurrent revoke/suspend और in-flight permission-check के बीच वास्तविक lock serialization test करना।

विशेष रूप से Staff contract में `FOR SHARE` clauses के source text और `VOLATILE` catalog property की जाँच है; इससे concurrency race का runtime pass सिद्ध नहीं होता। SOS test में भी function bodies में expected INSERT/permission text की जाँच है, actual caller identity से RPC behavior नहीं।

### 44.3 Test coverage classification

| क्षेत्र | मौजूदा targeted pgTAP evidence | शेष runtime evidence |
|---|---|---|
| Tables / functions / triggers | Structural presence checks | Clean replay में object creation |
| Table/function grants | Catalog privilege checks | अलग role context से direct access attempts |
| Staff permission helper | Definition text + volatility + lock clauses | Auth UID/JWT/session fixture के साथ true/false results |
| Staff lifecycle | RPC existence और source text | Invite, verify, activate, suspend, disable, revoke behavior |
| Support assignment | RPC/body source assertions | Assigned vs unassigned staff callers |
| Support reply/status | permission/assignment/source assertions | Actual allowed and denied RPC calls |
| SOS acknowledgement | Function/body source assertions | Pending/acknowledged state transitions, duplicate/concurrent calls |
| Concurrency | Lock-order/source assertions | Two-session transaction test |

### 44.4 सुरक्षित अगला test-design कदम

Replay gates पूरे होने और disposable local Supabase harness उपलब्ध होने के बाद targeted test suite में अलग behavioral pgTAP file जोड़ने का प्रस्ताव है। उसमें केवल synthetic local Auth users, synthetic Staff/Support records और synthetic cases हों; हर test transaction rollback हो। पहले negative authorization cases (anon, ordinary user, inactive Staff, wrong/revoked session, unassigned case) और फिर positive authorized flows चलें। Concurrency को अलग two-connection harness में जाँचा जाए, क्योंकि एक सामान्य single-transaction pgTAP test वास्तविक race reproduce नहीं करता।

**निष्कर्ष:** मौजूदा 69 + 28 assertions structural contract coverage हैं; इन्हें 97 runtime authorization scenarios कहना गलत होगा। Behavioral coverage अभी **NOT PRESENT IN THESE TWO TARGETED FILES** है। यह source-only finding है—कोई test execute, SQL write, migration replay या Production access नहीं किया गया।


## 45. High-risk workflow pgTAP files का source-level behavior audit — 16 Nov 2026

इस pass में पाँच महत्वपूर्ण test files की पूरी सामग्री पढ़ी गई: work timer, legacy booking status guard, sequential offer dispatch, push delivery lease fencing और Razorpay webhook inbox.

### 45.1 पाँचों files का साझा test pattern

इन पाँचों में `BEGIN`, घोषित `plan(...)`, `finish()` और `ROLLBACK` मौजूद हैं। लेकिन इनके assertions मुख्यतः catalog metadata और `pg_get_functiondef(...)` में अपेक्षित SQL text की उपस्थिति पर निर्भर हैं। Test files में अलग-अलग JWT identity स्थापित करना, `SET ROLE`, या pgTAP `throws_ok/lives_ok/results_eq/is_empty` के जरिए caller behavior execute/assert करना नहीं मिला।

### 45.2 विशिष्ट coverage और gaps

| Test | मौजूदा assertions | जो अभी runtime में सिद्ध नहीं |
|---|---|---|
| `server_authoritative_work_timer.test.sql` — plan 20 | columns, tables, RPCs, triggers, rounding formula, protected status/timer source, anonymous execute denial | customer/electrician identities से request-start → customer approval → elapsed time → completion → bill; forged client writes; dispute/reject outcomes |
| `legacy_booking_status_write_guard.test.sql` — plan 9 | Admin RPC definition, row-lock text, status transition guard, grants, search_path | non-admin/Admin caller invoke; actual legacy row state transition और denied state |
| `sequential_nearest_offer_dispatch.test.sql` — plan 16 | queue objects, RPC grants, geographic/tier source, decline/expiry dispatch source | synthetic booking/electrician fixtures, actual candidate ordering, one-at-a-time offer, expiry worker and concurrent accept/decline |
| `push_delivery_lease_fencing.test.sql` — plan 20 | service-role grants, attempt-count fencing, row-lock text, processing/terminal states, retry bounds/backoff, search_path | stale/current worker calls against fixture rows; lease renewal/finish races and actual persisted status |
| `razorpay_webhook_event_inbox.test.sql` — plan 15 | RLS/grants, unique constraints, claim/complete source, token/hash/lease text | duplicate event claims, expired lease reclaim, wrong token rejection, idempotent completion against local synthetic events |

### 45.3 Local behavioral suite के लिए प्राथमिकता

1. **Timer lifecycle (P0):** अलग customer और electrician Auth users; customer approval से पहले timer न चले; customer approval के बाद server timestamps; completion पर final bill; customer/electrician cross-booking denial; direct timer/snapshot writes denied.
2. **Webhook lease fencing (P0):** synthetic event ID/hash; duplicate claim; active lease conflict; expired lease reclaim; old token completion denied; current token completion accepted; terminal event idempotency.
3. **Offer dispatch (P1):** synthetic eligible candidates; exact rate tier/area; decline/expiry next candidate; simultaneous accept attempts में एक winner.
4. **Push delivery fencing (P1):** stale attempt rejected; current processing attempt accepted; terminal state immutable; retry/dead-letter boundaries.
5. **Legacy status guard (P1):** anonymous/ordinary authenticated denied; Main Admin valid transition; already transitioned or payment-protected booking denied.

ये proposed synthetic-local tests हैं, अभी जोड़े या चलाए नहीं गए हैं। Concurrency scenarios के लिए दो अलग DB connections/transactions चाहिए; एक साधारण pgTAP transaction पर्याप्त नहीं।

**निष्कर्ष:** पाँचों high-risk workflow tests अभी implementation text/metadata की regression checks हैं, end-to-end behavioral runtime proof नहीं। इससे उनके SQL logic में defect सिद्ध नहीं होता; केवल test coverage की सीमा स्पष्ट होती है। कोई SQL execute, test run, migration replay, fixture write या Production access नहीं किया गया।


## 46. पाँच workflow tests के synthetic fixture prerequisites — 16 Nov 2026

§45 में पहचाने गए behavioral gaps के आधार पर पाँचों मौजूदा test files दोबारा पढ़ीं और test-design से पहले आवश्यक fixture boundaries दर्ज कीं। यह केवल तैयारी है; कोई test file बदली या जोड़ी नहीं गई।

| Workflow | न्यूनतम isolated local fixture | निर्णायक behavioral assertions |
|---|---|---|
| Work Timer | दो local Auth users (एक customer, एक assigned electrician), एक नई category booking, approved rate snapshot | customer approval से पहले elapsed time शून्य; केवल संबंधित customer approval timer शुरू करे; दूसरे customer/electrician को deny; final bill server elapsed minutes से बने; dispute/reject path bill को गलत तरीके से finalize न करे |
| Razorpay Inbox | service-role-only local invocation context, दो synthetic event IDs, अलग payload hashes | समान event दोबारा claim करने पर duplicate; active lease रहते दूसरा worker claim न करे; expiry के बाद नया fencing token; पुराना token completion reject; terminal event repeat idempotent |
| Offer Dispatch | एक synthetic booking, समान क्षेत्र के कम-से-कम दो eligible electricians और एक ineligible control electrician; अलग rate-tier control | exact area/tier eligibility; एक समय में केवल एक current offer; decline/expiry पर अगला candidate; stale area/tier acceptance reject; concurrent accept में अधिकतम एक winner |
| Push Delivery | एक outbox row और एक per-device row, processing state तथा attempt counters | stale attempt number reject; current attempt accept; delivered/dead terminal rows immutable; retry boundary और capped backoff persisted values से verify |
| Legacy Status Guard | एक eligible legacy new booking, एक new-category booking, एक paid/refunded booking; local Main Admin और ordinary authenticated user | ordinary user deny; Main Admin केवल eligible legacy new को confirm करे; new-category और paid/refunded bookings unchanged रहें; direct authenticated status UPDATE deny |

### 46.1 Test harness boundaries

- हर Auth user और business row केवल disposable local Supabase database में synthetic हो; Production IDs या records fixture में न आएँ।
- auth.uid() / JWT claim को test helper से सेट करने के बाद वास्तविक authenticated role context में RPC चलाया जाए। service_role workflow को अलग privileged local invocation में जाँचा जाए।
- हर non-concurrency test transaction rollback करे; database-wide shared fixtures या स्थायी seed records न छोड़े।
- Lease expiry के लिए वास्तविक sleep की जगह controllable timestamps/fixture clock तभी उपयोग हों जब function contract उसे सुरक्षित रूप से support करता हो; अन्यथा isolated local transaction में समय-सीमा को स्पष्ट रूप से test किया जाए।
- Concurrent winner/lease race के लिए दो स्वतंत्र DB connections और coordinated transactions चाहिए; single pgTAP transaction को concurrency proof न माना जाए।
- Local Auth schema, helper functions और authoritative base schema provenance उपलब्ध होने तक इन fixtures को runnable test code में बदलना अभी blocked है।

### 46.2 Source-level inventory की पुष्टि

इस pass में पाँच files के exact वर्तमान आकार/plan दोबारा जाँचे:
- Work Timer: 54 lines, plan 20, INSERT fixture नहीं।
- Razorpay Inbox: 69 lines, plan 15, INSERT fixture नहीं।
- Sequential Offer Dispatch: 91 lines, plan 16, एक INSERT statement मौजूद; यह अकेले end-to-end workflow proof नहीं।
- Push Delivery: 82 lines, plan 20, INSERT fixture नहीं।
- Legacy Status Guard: 51 lines, plan 9, INSERT fixture नहीं।

पाँचों में JWT/session setup, role switching या throws_ok / lives_ok / results_eq / is_empty behavioral assertion calls नहीं मिले। यह पाँचों targeted files की सीमा तक का निष्कर्ष है, पूरे 32-file suite का दावा नहीं।

**निर्णय:** अगला coding step अभी production या current branch पर test edits नहीं है। पहले approved isolated runner, local Supabase config/harness, base-schema provenance और migration-version collision gate उपलब्ध होने चाहिए। उसके बाद पहले Work Timer और Webhook के local-only behavioral tests बनाए जाएँ; शेष तीन उसके बाद। इस pass में केवल GitHub source files पढ़ीं—कोई file write, SQL execution, test run, migration replay या Production access नहीं हुआ।
