# PR #8 — Disposable Baseline Design (Review Draft)

**Source commit:** `41b4b1ecc84f5ba3b753c6940ccbfe3c3ffd68d7`  
**Status:** design-only; not executable SQL and not approved for any hosted database.

## Goal

Define a reproducible clean-install starting point for the numbered migration chain without pretending that the existing consolidated setup script is already a canonical baseline.

## Baseline object inventory from checked-in source

| Object | Existing source | Required before migrations | Status |
|---|---|---:|---|
| `public.service_bookings` | `COMPLETE_DATABASE_SETUP.sql` | Yes | Base definition exists; must reconcile with all later consumers |
| `public.electrician_applications` | `COMPLETE_DATABASE_SETUP.sql` | Yes | Base definition exists |
| `public.electrician_profiles` | `COMPLETE_DATABASE_SETUP.sql` | Yes | Base definition exists; identity extension is migration-managed |
| `public.job_offers` | `COMPLETE_DATABASE_SETUP.sql` | Yes | Base definition exists |
| `public.srk_admin_users` | `COMPLETE_DATABASE_SETUP.sql` | Yes | Base definition exists |
| `auth.users` | Supabase-managed Auth schema | Yes | Must be supplied by disposable Supabase environment |
| `public.srk_is_admin()` | Setup SQL / legacy portal schema | For dependent migrations | Exact function exists in source; versioned placement unresolved |
| `public.is_srk_admin()` | Setup SQL / consolidated setup SQL | For dependent migrations | Separate function exists in source; versioned placement unresolved |
| `pgcrypto` / `gen_random_uuid()` | Setup SQL | Yes | Extension/bootstrap requirement; local config absent |

This inventory is intentionally limited to the objects directly established by the reviewed baseline artifacts and the named migration consumers. It is not a complete catalog of all dependencies across all 87 migrations.

## Required dependency order (source-backed, provisional)

1. Start an isolated disposable Supabase/PostgreSQL environment that supplies the managed `auth` schema and roles.
2. Apply an owner-approved canonical base schema for the five public base tables above, including the initial RLS state and indexes.
3. Introduce both Admin helper functions with their exact source definitions and reviewed grants. Do not alias one function name to the other.
4. Apply customer ownership migration before the combined customer/Admin booking read policy.
5. Apply electrician identity-linking migration before GPS support that writes `auth_user_id`.
6. Apply GPS support before the later replacement of the Admin approval RPC.
7. Apply the initial assigned-offer map RPC before the quote workflow migration that replaces its return shape.
8. Resolve `amount_paid` availability before any earlier commission/quote consumer or column-level grant references it.
9. Reconcile malformed migration filenames and actual migration ledger before selecting a numbered execution order.
10. Only after all preceding gates are approved, run a full disposable replay and the complete pgTAP suite.

## Blocking decisions — do not guess

### A. Canonical base provenance

The consolidated setup SQL is a useful source artifact, but the repository does not establish that it is the exact schema used to create the current remote database or the intended clean-install baseline. Obtain owner-approved baseline provenance or a schema-only export before promoting it into a versioned baseline.

### B. Admin helper introduction

Both helper definitions exist in setup SQL, but several numbered migrations call them before any clear versioned introduction in the chain. Decide and document their canonical baseline placement and grants.

### C. `amount_paid` ordering

The base setup table does not declare `amount_paid`. The later restore migration adds it at version `20261116200000`, while earlier commission and quote sources consume it. The clean-install design must make the column available before those consumers, but its authoritative deployment lineage and intended migration history must be reconciled before changing versioned files.

### D. Migration history and filenames

The two legacy filenames beginning `20261109_` are not valid 14-digit migration versions. Their correct versions cannot be inferred from the filename text. Compare with the authoritative migration ledger before renaming, merging, deleting, or resequencing.

### E. Supabase local configuration

The audited PR tree has no `supabase/config.toml`. A supported local Supabase harness cannot be claimed ready until this configuration and required local services are reviewed.

## Validation plan after approval

- Create a disposable local Supabase project only; no hosted credentials.
- Capture tool versions and exact source commit.
- Run static migration preflight.
- Reset/replay the full chain on the disposable database.
- Run all 32 pgTAP SQL tests and collect complete logs.
- Inspect resulting schema, functions, policies, and grants against the approved contract.
- Repeat from a fresh disposable database to demonstrate reproducibility.

## Explicit non-claims

- This document does not prove PostgreSQL syntax validity.
- It does not prove a full migration replay succeeds.
- It does not prove any pgTAP test passes.
- It does not establish Production parity or authorize remote history repair.
- No SQL has been executed and no database has been changed by creating this document.


## Source-backed dependency graph — early schema and access layer (16 Nov 2026)

यह graph केवल पढ़ी गई source files से निकला है। Arrow का अर्थ है “पहले उपलब्ध होना आवश्यक”; यह Production history या successful replay का दावा नहीं है।

| क्रम | Object / migration | पहले की आवश्यकताएँ | आगे निर्भर consumers | स्थिति |
|---|---|---|---|---|
| P0 | Supabase platform: `auth.users`, roles `anon/authenticated/service_role`, `auth.uid()` | Disposable Supabase environment | Auth FKs, policies, RPC identity checks | Platform-supplied; local harness/config अभी gate है |
| P0 | `pgcrypto` / `gen_random_uuid()` | Disposable PostgreSQL extension bootstrap | UUID defaults in legacy base tables and later DDL | Setup source में extension request है; local extension state verify नहीं |
| B1 | `public.service_bookings` | P0 | Customer ownership, GPS, quote/commission, offers, wallet/reporting joins | DDL केवल standalone setup artifacts में source-backed; canonical versioned baseline unresolved |
| B1 | `public.electrician_applications` | P0 | GPS application columns and Admin approval RPC | Same baseline gate |
| B1 | `public.electrician_profiles` | P0; FK to applications/Auth | Identity link, GPS, offer details, commission and wallet ownership | Same baseline gate |
| B1 | `public.job_offers` | B1 bookings + profiles | Assigned-offer map RPC and dispatch workflows | Same baseline gate |
| B1 | `public.srk_admin_users` | P0; FK to `auth.users` | Admin helper source definitions and Admin access design | Same baseline gate; do not create helpers before approved table baseline |
| A1 | `20261108121115_add_customer_account_booking_access.sql` | `service_bookings`, `auth.users` | Adds `customer_user_id`, index and customer-own SELECT policy | Source edge confirmed |
| A2 | `20261108234000_combine_booking_read_policy.sql` | A1 + `public.is_srk_admin()` | Combined Admin-or-customer booking SELECT policy | Helper introduction is unresolved; migration cannot be considered clean-replay-ready |
| I1 | `20261109000500_harden_electrician_profile_identity_linking.sql` | `electrician_profiles`, `auth.users` | Adds `auth_user_id`, sync/guard/link triggers and partial unique index | Source DDL confirmed; deployed provenance not confirmed |
| G1 | `20261109001000_add_google_maps_location_support.sql` | Base bookings/applications/profiles + I1 + `is_srk_admin()` | Adds coordinate columns/checks and Admin approval RPC | Identity ordering confirmed; Admin helper still unresolved |
| O1 | `20261109002000_expose_assigned_booking_map_pin.sql` | `job_offers`, bookings, profiles, GPS columns and profile `user_id`/approval fields | Later replacement of `srk_get_my_offer_details()` by quote/workflow migrations | Direct table/column dependencies confirmed; exact predecessor reconciliation remains |
| C1 | `20261109003000_secure_commission_reporting.sql` | Bookings, profiles, commission/payment fields, `is_srk_admin()` | Admin commission report, electrician earnings, column-level UPDATE grants | Audit branch adds nullable `amount_paid numeric(12,2)` before consumers; Admin helper remains unresolved |
| W1 | `20261109010000_create_secure_wallet_ledger_foundation.sql` | Auth, profiles with `auth_user_id`/`user_id`, `is_srk_admin()`, UUID generation | Wallet tables, owner policies, wallet summary and Admin overview RPCs | Table/identity dependencies confirmed; helper/baseline gate remains |

### Dependency edges to preserve

```text
Supabase Auth + roles + UUID extension
                  |
          approved base schema
      /       |       |       \
 bookings applications profiles job_offers
    |             |       |
 customer link    |   identity link (09000500)
    |             |       |
 combined RLS     +--- GPS support (09001000)
 (requires Admin helper)       |
                         map offer RPC (09002000)
                                |
                     quote workflow replacement

bookings + profiles + Admin helper
              |
 commission reporting (09003000)
              |
 wallet foundation (0910000)
      requires profiles identity + Admin helper
```

### Baseline decisions still open — no guessed DDL

1. **Admin helpers:** exact definitions are present in historical setup artifacts, but neither helper has a verified authoritative introducing migration in the numbered chain. `is_srk_admin()` and `srk_is_admin()` are distinct names. Do not add either into a dependent migration until `srk_admin_users` baseline and exact grants/search_path/security contract are owner-approved.
2. **Base-table provenance:** `COMPLETE_DATABASE_SETUP.sql`, `SUPABASE_SCHEMA.sql` and `PORTAL_SCHEMA.sql` are evidence sources, not yet an approved canonical baseline. They overlap and do not cover every later dependency.
3. **Column ordering:** on this audit branch, `amount_paid numeric(12,2)` is added at the top of `20261109003000_secure_commission_reporting.sql` before its SQL-language earnings function and grants. The later restoration migration remains idempotent. This is a source-order correction only; replay and type/constraint parity still need runtime/schema approval.
4. **Identity:** `auth_user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL` is explicitly added by `20261109000500`; do not duplicate it in the baseline if that migration remains the selected owner.
5. **RLS and ACL:** the graph must include policy replacement, function EXECUTE grants and column/table privileges—not just table creation. This pass covers only the listed early paths, not all migrations.

### Next acceptance gate

Before creating an executable baseline file, obtain an owner-approved schema-only baseline/provenance and reconcile it object-by-object against these source contracts. Then prepare a review-only diff, validate version ordering and duplicate filename handling, and only after explicit approval run replay and pgTAP on a disposable local target. No hosted database action is authorized by this document.


## Standalone schema provenance inventory — read-only comparison (16 Nov 2026)

चार SQL artifacts पढ़े गए; इन्हें अभी canonical baseline घोषित नहीं किया गया है।

| Artifact | Source में मिला | उपयोगिता | Baseline के रूप में सीमा |
|---|---|---|---|
| `SUPABASE_SCHEMA.sql` | `pgcrypto`; `service_bookings`, `electrician_applications`, `electrician_profiles`, `job_offers`; शुरुआती indexes और RLS insert policies | शुरुआती marketplace table shape का स्रोत | `srk_admin_users`, portal auth columns और बाद के financial/quote columns नहीं; केवल 93 lines का starter schema |
| `PORTAL_SCHEMA.sql` | `srk_admin_users`; electrician `user_id`; Auth trigger; `srk_is_admin()`; Admin/electrician policies और offer RPCs | Portal-layer additions और legacy Admin helper का स्रोत | Header कहता है SUPABASE_SCHEMA के बाद चलाएँ; पुराने function/search_path/permissions contract को वर्तमान numbered migrations का स्वतः विकल्प नहीं मान सकते |
| `COMPLETE_DATABASE_SETUP.sql` | पहले दो artifacts का consolidated रूप; चार base tables, `srk_admin_users`, `user_id`, `srk_is_admin()`, `is_srk_admin()`, legacy policies/RPCs | सबसे व्यापक standalone setup candidate | इसमें पुराने starter/portal objects और policies हैं; numbered migrations की पूरी वर्तमान schema, financial/quote/KYC/audit objects नहीं; कुछ DDL दोहराया गया है |
| `ADMIN_EMAIL_LOGIN_SETUP.sql` | `srk_admin_users` पर RLS/self-read policy; `is_srk_admin()`; Admin table policies | Admin email-login patch का प्रमाण | Base schema नहीं; पहले से बनी tables पर निर्भर; इसे पहले चलाना संभव नहीं |

### Source-backed table/column provenance

- `SUPABASE_SCHEMA.sql` और `COMPLETE_DATABASE_SETUP.sql` दोनों में शुरुआती `service_bookings` DDL है; इस DDL में `amount_paid` नहीं है।
- शुरुआती `electrician_profiles` DDL में `application_id`, display/contact/location, skills, active और created_at हैं; `user_id` अलग Portal setup में जोड़ा गया; `auth_user_id` numbered migration `20261109000500` में जोड़ा गया।
- शुरुआती `job_offers` DDL `service_bookings` और `electrician_profiles` पर foreign keys रखता है; इसलिए उन दोनों tables का पहले होना आवश्यक है।
- `srk_admin_users` का DDL `PORTAL_SCHEMA.sql` और `COMPLETE_DATABASE_SETUP.sql` में है; numbered migration chain में इसका authoritative introducing migration इस audit में नहीं मिला।
- `COMPLETE_DATABASE_SETUP.sql` में `srk_is_admin()` और `is_srk_admin()` दोनों के definitions हैं, लेकिन यह standalone setup artifact है, numbered migration नहीं।
- `ADMIN_EMAIL_LOGIN_SETUP.sql` `srk_admin_users` पहले से मौजूद मानता है; यह table-creation source नहीं है।

### निष्कर्ष / निर्णय

**अभी कोई standalone SQL file copy करके baseline migration नहीं बनाई जाएगी।** `COMPLETE_DATABASE_SETUP.sql` सबसे अधिक शुरुआती DDL समेटता है, लेकिन वह historical starter/portal contract है; उसे वर्तमान PR #8 schema का पूरा या सुरक्षित canonical snapshot कहना गलत होगा। पहले object-by-object schema reconciliation, policy/ACL review, and owner sign-off चाहिए।

इस inventory में केवल GitHub source files पढ़े गए। किसी database पर SQL execute नहीं किया गया; कोई production/test project बदला नहीं गया।


## Object-by-object delta — legacy setup बनाम शुरुआती numbered migrations (16 Nov 2026)

यह तुलना वर्तमान audit branch की exact source files पर आधारित है। “Legacy setup में है” का अर्थ केवल standalone SQL में DDL मौजूद होना है; इसका अर्थ यह नहीं कि उसे numbered migrations से पहले बिना review चलाना चाहिए।

| Object / contract | Legacy setup में स्थिति | Numbered migration delta / dependency | Replay निष्कर्ष |
|---|---|---|---|
| `service_bookings` | Base table मौजूद; customer/payment/booking/location fields, लेकिन `amount_paid` और `customer_user_id` नहीं | `20261108121115` adds `customer_user_id`; `20261109001000` adds GPS pair/range; `20261109003000` adds nullable `amount_paid numeric(12,2)`; quote workflow adds quote/service/work fields and constraints | Legacy table foundation उपयोगी, पर migration chain का replacement नहीं |
| `electrician_applications` | Base table मौजूद; profile/application identity fields and approval state | `20261109001000` adds GPS pair/range; Admin review RPC uses `auth.users` phone confirmation and inserts/updates profile linkage | Auth schema + profiles prerequisites चाहिए |
| `electrician_profiles` | Base table मौजूद; `application_id`, profile/contact/location, skills, active; consolidated setup additionally adds `verification_status` and `user_id` | `20261109000500` adds `auth_user_id` FK, backfill, unique partial index, sync/guard/link triggers; `20261109001000` adds GPS; later migrations evolve profile security and status | Legacy `user_id` may be present in consolidated setup; `auth_user_id` still needs owning migration |
| `job_offers` | Base table, booking/profile FKs, status/match level, indexes, RLS; no public read/write policy | Early map RPC reads it; later dispatch migrations evolve offers, status and triggers | Depends on both bookings and profiles before creation |
| `srk_admin_users` | Table in `PORTAL_SCHEMA.sql` and `COMPLETE_DATABASE_SETUP.sql`; FK to `auth.users`; RLS/self-read policy later in setup | No verified authoritative numbered CREATE TABLE migration in inspected chain | Baseline provenance gate; do not infer it is created by a migration |
| `public.srk_is_admin()` | Defined in `PORTAL_SCHEMA.sql` and `COMPLETE_DATABASE_SETUP.sql` | `20261109001500` and wallet Admin overview call it | Helper is legacy setup prerequisite, not created by those consumers |
| `public.is_srk_admin()` | Defined in `ADMIN_EMAIL_LOGIN_SETUP.sql` and `COMPLETE_DATABASE_SETUP.sql` | `20261108234000`, `20261109001000`, commission reporting and wallet Admin overview call it | Helper is legacy setup prerequisite, not created by those consumers |
| `amount_paid` | Not in the original `service_bookings` DDL in `SUPABASE_SCHEMA.sql` / `COMPLETE_DATABASE_SETUP.sql` | Audit branch adds it at start of `20261109003000`, before SQL-language earnings function; quote trigger later reads `NEW.amount_paid` | Source-order patch present; still requires actual PostgreSQL replay |
| `auth_user_id` | Not in original or consolidated legacy profile DDL | `20261109000500` adds it before GPS Admin review and wallet functions consume it | Ordering is source-backed; runtime not tested |

### Exact early dependency blockers

1. `20261108234000_combine_booking_read_policy.sql` creates an Admin-or-customer policy and calls `public.is_srk_admin()`. That migration does not define the helper or create `srk_admin_users`.
2. `20261109001000_add_google_maps_location_support.sql` defines `srk_admin_review_application()` and calls `public.is_srk_admin()`; it also reads/writes `auth.users`, `electrician_applications` and `electrician_profiles`, and writes both `user_id` and `auth_user_id`.
3. `20261109001500_unique_electrician_admin_identity_linking.sql` replaces the same Admin review RPC and calls the differently named `public.srk_is_admin()`. It therefore needs both the base Admin allowlist and the exact helper contract before execution.
4. `20261109010000_create_secure_wallet_ledger_foundation.sql` consumes `electrician_profiles.auth_user_id/user_id`, `auth.users`, and `public.is_srk_admin()`; it creates wallet objects but does not establish the Admin base table/helper prerequisites.
5. `COMPLETE_DATABASE_SETUP.sql` does contain both Admin helper names and the allowlist table, but also contains legacy policy/RPC definitions. It is not proven equivalent to the current migration-era function grants, search_path hardening, RLS and ACL state.

### Current bounded status

- **Confirmed by source:** all four operational base tables, Admin allowlist table, both legacy helper definitions, and the listed early migration consumers.
- **Source-order fix on audit branch:** `amount_paid` is added before the SQL-language commission earnings function in `20261109003000`; the later restoration migration remains idempotent.
- **Not resolved:** canonical base-schema ownership and whether the standalone setup's Admin helpers/table exactly satisfy the current numbered migration contracts.
- **Not tested:** PostgreSQL clean replay, trigger runtime, grants under actual Supabase roles, RLS behavior, pgTAP.
- **No action:** no production/test database SQL was executed; no migration was applied; no PR head/merge/deploy was changed.

**Decision:** Do not create an executable baseline from these legacy files yet. Use them as source evidence, reconcile every base object and security contract, then produce a review-only candidate for owner approval.


## RLS, policy और ACL cross-check — legacy setup बनाम early migrations (16 Nov 2026)

| Security area | Standalone setup का source contract | Numbered migration का बदलाव | परिणाम |
|---|---|---|---|
| Public booking/application INSERT | `SUPABASE_SCHEMA.sql` और `COMPLETE_DATABASE_SETUP.sql` में anon तथा authenticated के लिए permissive INSERT policies | `20261108233500_restrict_public_form_inserts.sql` दोनों policies DROP करता है; anon/authenticated INSERT REVOKE; service_role को INSERT GRANT | पुराने public INSERT model को final access model न मानें |
| Customer booking read | Legacy portal setup में electrician offer-based booking read; customer ownership column base table में नहीं | `20261108121115` `customer_user_id` FK/index और own-booking SELECT policy जोड़ता है; `20261108234000` Admin + customer को एक SELECT policy में जोड़ता है | Ownership migration और Admin helper दोनों पहले चाहिए |
| Admin booking read | `PORTAL_SCHEMA.sql` में `srk_admin_read_bookings` | `20261108234000` उसे हटाकर `srk_admin_or_customer_read_bookings` बनाता है, जो `public.is_srk_admin()` call करता है | Helper dependency explicit |
| Admin booking UPDATE / application access | Portal script अलग Admin SELECT/UPDATE policies बनाती है | बाद की hardening migrations policy/ACL को आगे बदलती हैं; केवल legacy policies वर्तमान grants का प्रमाण नहीं | Final ACL/RLS को पूरी chain से पुनर्निर्मित करना होगा |
| Electrician profile/offer read | Portal script own-profile / own-offer policies बनाती है; offer-based booking SELECT policy भी जोड़ती है | Identity-linking, offer RPC और बाद की privacy migrations इन्हें बदलती/सीमित करती हैं | Legacy policies अकेले वर्तमान privacy contract नहीं |
| Admin helper execution | Portal script `srk_is_admin()` को PUBLIC से revoke और authenticated को execute grant देती है; Admin email setup `is_srk_admin()` पर अलग revoke/grant देती है | Migrations दोनों नामों का उपयोग करती हैं; helper definitions/grants के exact baseline provenance का प्रमाण अभी अलग से आवश्यक | दोनों helper contracts को एक-दूसरे का substitute न मानें |
| SECURITY DEFINER functions | Portal setup में Auth link trigger helper, offer response और Admin review functions SECURITY DEFINER हैं; explicit search_path अलग-अलग है | `20261109000500` identity functions/triggers बनाता है और PUBLIC/anon/authenticated execution revoke करता है; `20261109001500` Admin review function को `search_path=pg_catalog,public,auth` के साथ replace करता है | पुराने function body/grants को current hardened contract न मानें |

### प्रत्यक्ष policy/ACL evidence

- `20261108233500_restrict_public_form_inserts.sql` स्पष्ट रूप से public browser INSERT बंद करता है और केवल `service_role` INSERT grant करता है। यह public Netlify/server-function submission design का हिस्सा है।
- `20261108121115_add_customer_account_booking_access.sql` `customer_user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL` और partial index जोड़ता है। Customer SELECT predicate `auth.uid() = customer_user_id` है।
- `20261108234000_combine_booking_read_policy.sql` दो पुरानी SELECT policies हटाकर एक policy बनाता है: Admin helper OR customer ownership। इस migration में `public.is_srk_admin()` का definition नहीं है।
- `20261109001500_unique_electrician_admin_identity_linking.sql` अलग helper `public.srk_is_admin()` call करता है; वह Admin review RPC को drop/recreate करता है, PUBLIC execution revoke करता है और authenticated को grant देता है।
- Legacy consolidated setup में `srk_admin_users_self_read` policy कई जगह दोहराई गई है और `is_srk_admin()` / `srk_is_admin()` दोनों मौजूद हैं। Duplicate DDL और migration-era security state को बिना normalization के एक ही executable baseline में जोड़ना उचित नहीं।

### RLS/ACL निष्कर्ष

1. चार core tables पर RLS enable होना, पूर्ण access model होने के बराबर नहीं है। Policies, table privileges, function EXECUTE grants और SECURITY DEFINER search_path सभी अलग-अलग सत्यापित होने चाहिए।
2. Legacy public INSERT policies को migration `20261108233500` हटाती है। यदि disposable baseline में legacy setup को wholesale चलाकर बाद की migration छोड़ी जाए, तो अपेक्षित server-only insert boundary स्थापित नहीं होगी।
3. Admin booking read policy को helper `is_srk_admin()` चाहिए; Admin approval migration `srk_is_admin()` पर निर्भर है। दोनों नाम अलग API contracts हैं।
4. `PORTAL_SECURITY_UPDATE.sql` और `ADMIN_EMAIL_LOGIN_SETUP.sql` patch/setup artifacts हैं; इन्हें numbered migration chain का विकल्प नहीं माना गया।
5. अभी भी कोई PostgreSQL replay, role-based ACL test, RLS test या pgTAP run नहीं हुआ। ये निष्कर्ष source comparison हैं, runtime security certification नहीं।

**अगला सुरक्षित gate:** canonical base DDL में प्रत्येक table के साथ RLS enablement, exact policy set, table GRANT/REVOKE, function owner/SECURITY DEFINER/search_path और EXECUTE grants को object-wise मंजूर कराना; उसके बाद ही disposable PostgreSQL replay candidate बनाना।

## Triggers, Functions और EXECUTE permissions की migration-wise तुलना (16 Nov 2026)

यह section standalone setup SQL और चुनी हुई numbered migrations के source-level comparison पर आधारित है। यह PostgreSQL replay या live trigger execution का प्रमाण नहीं है।

### मुख्य object comparison

| Object / contract | Standalone setup का रूप | Numbered migration chain का रूप | Replay / सुरक्षा निष्कर्ष |
|---|---|---|---|
| Auth phone-link trigger | `PORTAL_SCHEMA.sql` और `COMPLETE_DATABASE_SETUP.sql` में `public.srk_link_electrician_profile()` SECURITY DEFINER, `search_path=public,auth`; `auth.users` पर AFTER INSERT या phone/phone_confirmed_at UPDATE trigger | `20261109000500` identity columns, sync/guard triggers और उसी link function का hardened replacement देता है; function का path `pg_catalog,public,auth`; direct EXECUTE PUBLIC/anon/authenticated से revoke | Trigger का base attachment standalone setup में है; numbered hardening function को बदलता है। Clean replay के लिए Auth trigger की creation/retention और `auth.users`/profile prerequisites को साथ verify करना होगा |
| Profile identity synchronization | पुराना setup केवल `user_id` आधारित phone linking दिखाता है | `20261109000500` और दोबारा `20261114130000` में `auth_user_id` FK/index, दोनों identity columns का sync trigger, SECURITY DEFINER guard trigger और hardened Auth link function | दो numbered files में identity hardening दोहराई गई है; इसे अलग-अलग स्वतंत्र baseline समझना ठीक नहीं। दोनों columns की consistency और Auth user matching आवश्यक है |
| Offer response RPC | `srk_respond_to_offer(uuid,text)` SECURITY DEFINER; approved/active profile के `user_id=auth.uid()` पर ownership check; PUBLIC revoke और authenticated grant | `20261114210000` में sequential-dispatch architecture के अनुरूप replacement; `user_id` और `auth_user_id` दोनों auth.uid से match; path `pg_catalog,public,auth,pg_temp`; PUBLIC/anon revoke, authenticated grant | समान function signature है, लेकिन business behavior और identity contract समान नहीं। Legacy body को वर्तमान implementation मानना गलत होगा |
| Offer-details RPC | `COMPLETE_DATABASE_SETUP.sql` / `PORTAL_SECURITY_UPDATE.sql` में शुरुआती projection; SECURITY DEFINER, path `public,auth`, authenticated grant | `20261109002000`, quote migration और `20261114370000` में क्रमिक DROP/CREATE replacement; output columns बढ़ते हैं; final inspected version में SECURITY DEFINER, hardened path और authenticated-only grant। `20261116140000` path को खाली string पर pin करता है | Return shape समय के साथ बदलता है; clients और SQL callers के लिए अंतिम signature/columns महत्वपूर्ण हैं |
| Admin application review | शुरुआती setup में jsonb-returning SECURITY DEFINER RPC; helper `srk_is_admin()`; authenticated grant | `20261109001500` स्पष्ट रूप से पुराने void-returning version को DROP करके jsonb contract बनाता है; बाद में `20261114130000` identity-safe matching के साथ replace करता है; `20261116150000` search_path को खाली pin करता है | Migration comment स्वयं पुराने void बनाम jsonb contract का अंतर बताता है। सही helper और `srk_admin_users` baseline dependency अब भी अनसुलझी है |
| Commission trigger | Portal setup में `srk_calculate_commission_on_completion()` BEFORE UPDATE OF status trigger से जुड़ा; completion transition पर `quoted_amount * commission_rate` | Quote workflow migration `srk_calculate_booking_commission()` नाम का अलग trigger function बनाती है, जो `amount_paid`, `payment_status`, `service_charge` और commission rate देखता है | ये दो अलग commission contracts हैं। Inspected quote migration में इस नए function को जोड़ने वाला CREATE TRIGGER statement नहीं मिला; trigger attachment का वास्तविक owner अलग से प्रमाणित करना बाकी है |
| Commission reporting RPCs | शुरुआती portal setup में इस जोड़ी का समकक्ष नहीं | `20261109003000` में Admin report और electrician earnings SECURITY DEFINER RPCs; explicit search_path, PUBLIC/anon revoke, authenticated grant | ये `amount_paid` सहित बाद में जोड़े गए columns पर निर्भर हैं; इसी कारण पहले दर्ज amount_paid prerequisite fix महत्वपूर्ण है |

### विशेष trigger और permission observations

1. **Trigger function EXECUTE और client RPC EXECUTE अलग बातें हैं।** Identity sync/guard, Auth-link और booking trigger functions पर PUBLIC/anon/authenticated का direct EXECUTE revoke होना अपने-आप trigger invocation को रोकने का प्रमाण नहीं है; trigger firing table operation के संदर्भ में होती है। इसके विपरीत callable RPCs के लिए स्पष्ट authenticated/service_role grants आवश्यक हैं।
2. `20261114210000_sequential_nearest_offer_dispatch.sql` में `broadcast_booking_job()` trigger function direct browser execution से revoke है; AFTER INSERT trigger sequential dispatcher को चलाता है। Internal private dispatch functions के EXECUTE grants भी सीमित किए गए हैं; offer response RPC authenticated को मिलता है और expiry/advance RPC service_role को।
3. `20261109001500` Admin review RPC को DROP/CREATE करता है, जबकि `20261114130000` उसे CREATE OR REPLACE करता है। DROP/CREATE के बाद grants दोबारा देना जरूरी है; इस migration में PUBLIC revoke और authenticated grant मौजूद हैं।
4. `20261116140000`, `20261116150000` और `20261116160000` बाद की search_path hardening migrations हैं। इन्हें पुराने function definitions से अलग पढ़ना होगा; final function body, owner, SECURITY DEFINER flag और EXECUTE grants को एक साथ inspect करना अभी बाकी है।
5. Auth-link chain `auth.users`, `electrician_profiles.user_id`, `electrician_profiles.auth_user_id`, verified phone और approved profile status पर निर्भर है। Standalone setup में Auth trigger मौजूद है, लेकिन numbered migration chain में उसका पूरा creation/retention path और canonical base schema एक ही replayable chain के रूप में अभी प्रमाणित नहीं है।
6. Legacy commission trigger `quoted_amount` और status transition पर चलता है; quote-era function `amount_paid`/paid-state/service-charge आधारित है। इनके trigger attachment, execution order और duplicate commission-write risk को disposable PostgreSQL replay तथा trigger catalog inspection से ही निर्णायक रूप से जाँचा जा सकता है।

### सीमाएँ और अगला gate

- यह तुलना चुनी हुई setup files और ऊपर नामित migrations तक सीमित है; पूरे repository के हर SQL object का exhaustive scan नहीं है।
- Function ownership, effective privileges inherited via PUBLIC/role membership, actual trigger catalog order, Auth trigger survival, and runtime behavior सत्यापित नहीं किए गए।
- कोई PostgreSQL replay, pgTAP, trigger execution test या production write नहीं किया गया।
- Canonical base schema और `srk_admin_users`/Admin helper introduction अभी भी unresolved replay gates हैं। इस आधार पर अभी consolidated executable baseline बनाना सुरक्षित नहीं है।

**अगला सुरक्षित gate:** canonical base schema तय होने के बाद disposable database में migration replay करके `pg_proc`, `pg_trigger`, `pg_class.relowner` और effective function privileges की तुलना करना; उसके बाद ही trigger ownership/order और RPC grants को मंजूर करना।

## Canonical base schema और disposable replay gate (16 Nov 2026)

### अभी उपलब्ध base artifacts

| Artifact | इसमें क्या बनता है | सीमा |
|---|---|---|
| `SUPABASE_SCHEMA.sql` | `service_bookings`, `electrician_applications`, `electrician_profiles`, `job_offers`; pgcrypto और शुरुआती RLS/policies | `srk_admin_users`, Auth profile-link trigger, Admin helpers और बाद के financial/quote columns का पूरा आधार नहीं |
| `PORTAL_SCHEMA.sql` | `srk_admin_users`, profile `user_id`, Auth phone-link trigger, `srk_is_admin()`, portal RPCs और legacy commission trigger | स्पष्ट रूप से पहले `SUPABASE_SCHEMA.sql` चलाने को कहता है; बाद के migration contracts का पूरा विकल्प नहीं |
| `COMPLETE_DATABASE_SETUP.sql` | ऊपर के चार core tables और portal objects को एक consolidated file में रखता है; दोनों Admin helper नाम भी हैं | दोहराए गए DDL/policies/functions हैं; `service_bookings.amount_paid` और बाद के सभी migration-era objects इसमें नहीं हैं |
| `ADMIN_EMAIL_LOGIN_SETUP.sql` | पहले से मौजूद Admin table के ऊपर `is_srk_admin()` helper और policies का patch | standalone base नहीं; `srk_admin_users` पहले से होना जरूरी |
| `PORTAL_SECURITY_UPDATE.sql` | Offer Details RPC का security patch | standalone base नहीं; table/function prerequisites पहले से चाहिए |

### Numbered chain से दिखने वाला base dependency gap

- जाँची गई numbered migration chain में core tables `service_bookings`, `electrician_applications`, `electrician_profiles`, `job_offers` बनाने वाली कोई verified initial CREATE TABLE migration नहीं मिली। शुरुआती relevant migrations इन्हें पहले से मौजूद मानकर ALTER/POLICY/trigger/RPC करती हैं।
- इसी तरह `public.srk_admin_users` बनाने वाली numbered migration अभी नहीं मिली। लेकिन `srk_is_admin()` और `is_srk_admin()` दोनों helper contracts बाद की policies/RPCs में उपयोग होते हैं।
- `20261109001000_add_google_maps_location_support.sql` तीन core tables पर ALTER/constraint validation करता है और Admin helper `is_srk_admin()` को consume करता है।
- `20261109001500_unique_electrician_admin_identity_linking.sql` अलग helper `srk_is_admin()` consume करता है और `srk_admin_users`/Auth identity context पर निर्भर है।
- `20261109000500_harden_electrician_profile_identity_linking.sql` `electrician_profiles.auth_user_id` जोड़ता है; इसलिए base profile table और पहले का `user_id` identity contract आवश्यक हैं।
- `20261109003000_secure_commission_reporting.sql` में `amount_paid` को functions से पहले जोड़ने वाला prerequisite अब source में मौजूद है; यह केवल एक missing-column gate का समाधान है, पूरे base schema का नहीं।
- Wallet migration `20261109010000` अपने wallet tables बनाती है, पर वह core booking/profile/Admin base का स्थान नहीं लेती।

### Disposable replay के लिए प्रस्तावित prerequisite order

यह **सत्यापित execution plan नहीं**, source-derived dependency checklist है:

1. Supabase-provided schemas/roles/extensions और Auth schema की उपलब्धता तय करें।
2. चार core tables, उनके exact columns, primary/foreign keys, unique constraints और आवश्यक indexes का एक canonical base DDL तय करें।
3. `srk_admin_users` table और Admin allowlist provisioning contract तय करें।
4. `is_srk_admin()` और `srk_is_admin()` दोनों functions का intended अलग-अलग contract, owner, SECURITY DEFINER, search_path और grants मंजूर करें; इन्हें एक नाम में merge न करें।
5. Portal Auth phone-link trigger और प्रारंभिक profile `user_id` linkage स्थापित करें।
6. Customer ownership तथा electrician `auth_user_id` identity columns/indexes और synchronization/guard triggers जोड़ें।
7. Location, quote, payment/commission prerequisites को उनके consuming RPCs से पहले लागू करें।
8. शेष numbered migrations को सही version order में apply करके policies, triggers, functions और grants का catalog snapshot लें।
9. फिर सभी उपलब्ध pgTAP tests चलाएँ और failures को अलग से दर्ज करें।

### निर्णय

अभी canonical base schema चुनने के लिए प्रमाण पर्याप्त नहीं है। `COMPLETE_DATABASE_SETUP.sql` सबसे समेकित manual setup artifact है, लेकिन इसे बिना normalization और migration reconciliation के numbered migration chain का canonical replay baseline घोषित नहीं किया जा सकता। इसलिए कोई नई executable baseline SQL file नहीं बनाई गई।

**इस चरण में किया गया काम:** source inventory और dependency gate दस्तावेज़ित। कोई disposable database create/reset नहीं किया, कोई SQL apply नहीं किया, कोई PostgreSQL replay या pgTAP run नहीं हुआ, Production untouched है।


## 2026-11-16 — Base table/column replay gates और quote trigger attachment re-check

यह superseding source-only recheck वर्तमान audit branch `chore/pr8-replay-audit-20261116-v2` पर किया गया। यह live database या remote migration ledger का प्रमाण नहीं है।

### 1. `amount_paid` का source-order correction

- `20261109003000_secure_commission_reporting.sql` की वर्तमान audit-branch body अब सबसे पहले `public.service_bookings.amount_paid numeric(12,2)` को `ADD COLUMN IF NOT EXISTS` से जोड़ती है; इसके बाद commission report और SQL-language earnings function बनते हैं।
- `20261116200000_restore_service_bookings_amount_paid.sql` में वही column idempotently जोड़ा गया है और nonnegative CHECK `NOT VALID` रूप में जोड़ा जाता है।
- इसलिए पुराने audit notes में यह कहना कि वर्तमान audit branch में 09:00:00 migration सीधे missing-column consumer है, अब superseded है: इस branch में 09:00:00 file के भीतर column prerequisite पहले रखा गया है। Late restoration migration अब duplicate-safe fallback/constraint addition है।
- यह source-order fix तभी उपयोगी है जब `public.service_bookings` पहले से approved baseline में मौजूद हो। यह table की introducing DDL या canonical baseline provenance स्वयं सिद्ध नहीं करता।

### 2. Electrician identity column

- `20261109000500_harden_electrician_profile_identity_linking.sql` सीधे `electrician_profiles.auth_user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL` जोड़ती है, existing `user_id` से दोनों ओर backfill करती है, partial unique index बनाती है और identity-sync/guard triggers बनाती है।
- उसी migration में `srk_link_electrician_profile()` function की replacement definition है, पर यह file स्वयं `auth.users` पर उसका trigger attach नहीं करती। Auth trigger की वास्तविक attachment/पूर्व-परिभाषा canonical baseline और earlier setup source से reconcile करनी होगी।
- `electrician_profiles`, `auth.users`, `user_id` और Auth trigger bootstrap की उपलब्धता इस migration से पहले आवश्यक है।

### 3. Quote commission trigger attachment — unresolved source gap

- `20261109_electrician_inspection_quotes_and_service_only_commission.sql` `srk_calculate_booking_commission()` नाम का trigger function बनाती है और उसके body में `NEW.amount_paid`, `NEW.commission_rate`, `NEW.service_charge`, `NEW.status` और `NEW.payment_status` पढ़ती है।
- उसी migration body में इस function के लिए कोई `CREATE TRIGGER ... EXECUTE FUNCTION public.srk_calculate_booking_commission()` statement नहीं है।
- Audit branch की सभी नाम-संबंधित quote/commission/amount_paid migration files के bounded scan में भी इस function को attach करने वाला कोई अलग `CREATE TRIGGER` नहीं मिला।
- इसलिए function definition मौजूद होना commission trigger के वास्तव में सक्रिय होने का प्रमाण नहीं है। इसे source-level **trigger attachment gap / unresolved** के रूप में रखा जाए; बिना स्वीकृत व्यवहार/मूल lineage के नया trigger अनुमान से न जोड़ें।

### 4. समान migration prefix और replay निर्णय

- `20261109_electrician_inspection_quotes_and_service_only_commission.sql` और `20261109_allow_quote_approval_booking_states.sql` दोनों का version prefix केवल `20261109` है, जबकि Supabase numbered migration सामान्यतः unique 14-digit version मांगती है।
- दोनों files status/assignment constraints पर overlapping DROP/ADD DDL रखती हैं। वास्तविक execution order repository filename से विश्वसनीय रूप से तय नहीं किया जा सकता।
- `20261109003000_secure_commission_reporting.sql` में अब `amount_paid` prerequisite का source-order सुधार है, लेकिन इससे duplicate-prefix lineage, Admin helper/bootstrap, base-table provenance, Auth trigger attachment या quote trigger attachment के gates बंद नहीं होते।

### 5. अगली कार्रवाई और सीमा

1. Owner/DBA से sanitized authoritative migration ledger तथा approved schema-only baseline/provenance लेना।
2. Confirm करना कि `srk_link_electrician_profile()` का Auth trigger किस approved bootstrap/migration में attach होता है।
3. Quote commission function के लिए अपेक्षित trigger event/columns और intended active status को product/database owner से confirm करना; उसके बाद ही migration change प्रस्तावित करना।
4. Duplicate `20261109` version lineage को authoritative ledger से reconcile करना।
5. इन gates के बाद ही disposable local Supabase/PostgreSQL replay और pgTAP चलाना।

**Verification:** यह Git source fetch और static text scan है। PostgreSQL replay, pgTAP, Production query/write, migration apply, merge और deployment नहीं किए गए। Scan केवल quote/commission/amount_paid नाम-संबंधित migration files पर सीमित था; इसे सभी SQL files या dynamic SQL की exhaustive जाँच न माना जाए।


### 6. Root setup में पुराने Auth और commission trigger attachments — अतिरिक्त cross-check

चार root SQL artifacts (PORTAL_SCHEMA.sql, COMPLETE_DATABASE_SETUP.sql, SUPABASE_SCHEMA.sql, ADMIN_EMAIL_LOGIN_SETUP.sql) में bounded search के बाद:

- PORTAL_SCHEMA.sql और COMPLETE_DATABASE_SETUP.sql दोनों auth.users पर srk_link_electrician_profile_trigger को AFTER INSERT OR UPDATE OF phone, phone_confirmed_at से attach करते हैं। दोनों में पुरानी srk_link_electrician_profile() implementation भी है।
- Current numbered migration 20261109000500_harden_electrician_profile_identity_linking.sql उसी function को अधिक सख्त identity/phone checks वाली implementation से replace करती है, लेकिन Auth trigger को drop/recreate नहीं करती। यदि approved bootstrap में root setup का Auth trigger पहले से बना हो, तो trigger उसी नाम के function को नई implementation के साथ invoke करेगा; clean replay में root setup शामिल न हो तो attachment का numbered migration source अभी नहीं मिला।
- Root setup files में पुराना commission trigger srk_booking_commission_trigger, srk_calculate_commission_on_completion() को BEFORE UPDATE OF status पर attach करता है। यह नई quote migration के srk_calculate_booking_commission() से अलग function और अलग calculation contract है।
- Quote migration की नई commission trigger function के लिए कोई matching trigger attachment नहीं मिला। पुराने root commission trigger की मौजूदगी नए function को attach नहीं करती और दोनों functions को interchangeable नहीं मानना चाहिए।

इसलिए Auth trigger attachment का source root manual setup में पहचाना गया, लेकिन canonical numbered replay baseline में उसका स्थान अब भी unresolved है। इसी तरह पुराने commission trigger का manual setup evidence, नए quote commission trigger की सक्रियता सिद्ध नहीं करता।


### 7. Admin helper और RBAC migration bootstrap — अतिरिक्त dependency check (16 Nov 2026)

- `20261114390000_admin_staff_rbac_foundation.sql` में `public.srk_admin_staff`, permissions, role-permissions, sessions और append-only audit tables बनती हैं। इसी migration का `srk_has_admin_permission(text)` Main Admin check के लिए `public.is_srk_admin()` call करता है।
- उसी numbered migration में `is_srk_admin()` या `srk_admin_users` की table definition नहीं है। इसलिए RBAC foundation का clean replay इन objects की पहले से approved उपलब्धता पर निर्भर है।
- GitHub code-search के इस audit pass में `is_srk_admin()` के numbered-migration matches केवल consumer/reference files में मिले: `20261108234000_combine_booking_read_policy.sql`, `20261109001000_add_google_maps_location_support.sql`, `20261109003000_secure_commission_reporting.sql`, `20261109010000_create_secure_wallet_ledger_foundation.sql`, `20261113230000_support_attachment_paths_and_admin_message_list.sql`; matching numbered migration definition नहीं मिली।
- `is_srk_admin()` की definition root setup artifacts `PORTAL_SCHEMA.sql` / `COMPLETE_DATABASE_SETUP.sql` और `ADMIN_EMAIL_LOGIN_SETUP.sql` में है। ये manual/root setup files हैं; अभी तक इन्हें canonical numbered migration baseline घोषित करने का प्रमाण नहीं मिला।
- `20261109001500_unique_electrician_admin_identity_linking.sql` दूसरी helper `public.srk_is_admin()` call करती है। इसे `is_srk_admin()` का alias न मानें; दोनों नाम अलग API contracts हैं और उनकी provenance/permissions अलग से verify होनी चाहिए।
- RBAC migration का अपना comment भी Main Admin को `srk_admin_users` में अलग identity class बताता है, लेकिन इस pass में numbered migration chain में `srk_admin_users` की introducing DDL नहीं मिली। इसलिए Staff RBAC tables का होना Main Admin registry bootstrap को सिद्ध नहीं करता।

**Replay gate:** canonical baseline owner से लिखित पुष्टि लें कि `srk_admin_users`, `is_srk_admin()`, `srk_is_admin()` और उनके exact grants/security/search_path contract किस approved bootstrap/migration से आते हैं। तब तक helper definitions को अनुमान से जोड़ना या RBAC/consumer migrations को clean replay-ready बताना उचित नहीं है। यह GitHub source/code-search आधारित bounded audit है; database replay/pgTAP नहीं।


### 8. Support Staff RPC separation — authorization boundary cross-check (16 Nov 2026)

- `20261114390000_admin_staff_rbac_foundation.sql` केवल Staff registry नहीं बनाती; उसी migration में assignment-aware Staff RPCs भी परिभाषित हैं: customer complaint/ticket list, message read/reply, status update और assignment listing.
- Staff-facing complaint/ticket RPCs `public.srk_has_admin_permission(...)` से permission जाँचती हैं और current `srk_admin_support_assignments` ownership भी जाँचती हैं। यह Main Admin के broad RPC path से अलग सीमित access contract है।
- Main Admin management RPCs (staff invite/status/session revoke/assignment) `public.is_srk_admin()` से guarded हैं। पुराने Main Admin complaint/ticket inbox RPCs भी इसी Main Admin helper से guarded रहते हैं।
- इसलिए Staff RBAC जोड़ने का अर्थ यह नहीं कि हर पुराने `srk_admin_*` RPC को Support Staff के लिए खोल दिया जाए। Staff को केवल नए scoped RPCs और assigned cases के माध्यम से access मिलना चाहिए; इस separation को regression review में सुरक्षित रखना है।
- यह static source review है: किसी JWT session, assignment race, permission denial, RPC execution या RLS behavior का runtime test नहीं हुआ।


### 9. Support conversation / ticket / Staff RBAC replay dependency chain (16 Nov 2026)

Bounded source review of `20261110040000_customer_admin_complaints.sql`, `20261113220000_customer_support_conversation_schema.sql`, `20261113230000_support_attachment_paths_and_admin_message_list.sql`, `20261114130000_harden_electrician_profile_identity_linking.sql`, `20261114350000_electrician_support_tickets_and_admin_inbox.sql` and `20261114390000_admin_staff_rbac_foundation.sql`:

- Customer complaint foundation `20261110040000` creates `srk_booking_complaints` and `srk_booking_complaint_events`; it depends on `service_bookings) and its `customer_user_id` column. The customer ownership column is added by `20261108121115_add_customer_account_booking_access.sql`.
- Customer thread migration `20261113220000` creates `srk_booking_complaint_messages` and attachments; it depends on the complaint table from `20261110040000`. It also writes to `storage.buckets`, queries `storage.objects`, and creates Storage policies, so the Supabase Storage schema/bucket-policy prerequisites must exist.
- `20261113230000` consumes the message/attachment tables from `20261113220000` and the complaint table; it must run after those foundations.
- Electrician ticket migration `20261114350000` depends on `electrician_profiles), `service_bookings`, and Auth users. Its create-ticket RPC reads both `electrician_profiles.user_id` and `electrician_profiles.auth_user_id`, and checks `service_bookings.assigned_electrician_id`. The identity hardening migration `20261114130000` adds/synchronizes `auth_user_id`; that migration and the base booking/profile columns must precede ticket creation.
- Staff RBAC migration `20261114390000` consumes `srk_booking_complaints`, `srk_booking_complaint_messages`, `srk_booking_complaint_events`, `srk_electrician_support_tickets`, `srk_electrician_support_messages`, and the Auth session relation. Thus complaint foundation, customer thread schema, and electrician ticket schema must precede Staff RBAC. Its `ALTER TABLE ... ADD COLUMN IF NOT EXISTS sender_user_id` is compatible with the earlier message schema, which already declares that column.
- The visible filename ordering places these consumer migrations after their immediate feature foundations, but that alone does not solve the separate unresolved base-schema and Main Admin helper dependencies: `service_bookings`, `electrician_profiles`, `public.is_srk_admin()`, and `public.srk_admin_users` still need an approved canonical bootstrap. The ticket and Staff RBAC files call `is_srk_admin()`; identity review calls `srk_is_admin()`.

**Replay gate:** validate the full ordered chain against an owner-approved disposable baseline, including Storage availability and all referenced base columns. Do not treat this static dependency graph as a successful replay. No database writes, replay, or pgTAP tests were performed in this review.
