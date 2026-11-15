# GPT-2 Base Schema, Admin Helper and RLS Dependency Findings — 16 Nov 2026

स्थिति: केवल Git source का read-only audit। कोई SQL execution, local/Production database connection, migration replay, DDL, policy change, deployment या application-source edit नहीं हुआ।

## 1. Base schema का वास्तविक स्रोत

Current branch पर `COMPLETE_DATABASE_SETUP.sql` में निम्न base tables बनती हैं:
- `public.service_bookings`
- `public.electrician_applications`
- `public.electrician_profiles`
- `public.job_offers`
- `public.srk_admin_users`

यह setup `pgcrypto` extension भी मांगता है और Supabase-managed `auth.users` पर foreign keys/functions/triggers निर्भर हैं।

महत्वपूर्ण: ये definitions versioned `supabase/migrations` chain के भीतर किसी clean, canonical baseline migration के रूप में स्थापित नहीं हुईं। इसीलिए file मौजूद होना यह सिद्ध नहीं करता कि disposable replay या Production history में वही exact schema बना था।

## 2. Admin helper नामों में असंगति

Source में दो अलग function names मिले:
- पुराने `PORTAL_SCHEMA.sql` में `public.srk_is_admin()`
- `COMPLETE_DATABASE_SETUP.sql` के बाद वाले Admin compatibility section में `public.is_srk_admin()`

Migration source `20261108234000_combine_booking_read_policy.sql` सीधे `public.is_srk_admin()` को call करती है। इसी नाम को `20261109001000_add_google_maps_location_support.sql`, `20261109003000_secure_commission_reporting.sql`, और `20261109010000_create_secure_wallet_ledger_foundation.sql` भी call करती हैं।

इस audit में `supabase/migrations` के भीतर `is_srk_admin()` को define करने वाली अलग, authoritative introducing migration नहीं मिली। Function की definition starter setup file में है, जो स्वयं replay migration नहीं है। अतः helper का exact approved introduction/placement अभी baseline dependency है।

यह केवल नाम का अंतर नहीं माना जा सकता: दोनों function names अलग database objects हैं। बिना approved source reconciliation के एक को दूसरे का alias मानना उचित नहीं।

## 3. Booking SELECT RLS नीति की dependency

`20261108121115_add_customer_account_booking_access.sql`:
- `customer_user_id` जोड़ती है;
- `srk_customer_read_own_bookings` policy बनाती है।

इसके बाद `20261108234000_combine_booking_read_policy.sql`:
- `srk_admin_read_bookings` और `srk_customer_read_own_bookings` हटाती है;
- combined `srk_admin_or_customer_read_bookings` policy बनाती है;
- policy में `public.is_srk_admin()` और `auth.uid() = customer_user_id` दोनों हैं।

अर्थात यह migration customer ownership column/policy और Admin helper दोनों पर निर्भर है। केवल customer-account migration मौजूद होना पर्याप्त baseline नहीं है।

## 4. Base table columns और downstream expectations

Historical `COMPLETE_DATABASE_SETUP.sql` की शुरुआती `service_bookings` table में:
- `amount_paid` नहीं है;
- `customer_user_id` नहीं है;
- GPS columns नहीं हैं;
- Quote/timer fields नहीं हैं;
- शुरुआती status CHECK में बाद के inspection/approval statuses नहीं हैं।

इनमें से कुछ के introducing source files अब पहचाने गए हैं:
- customer ownership: `20261108121115_add_customer_account_booking_access.sql`;
- GPS: `20261109001000_add_google_maps_location_support.sql`;
- quote fields/statuses: `20261109_electrician_inspection_quotes_and_service_only_commission.sql`;
- amount paid: `20261116200000_restore_service_bookings_amount_paid.sql`.

यह source-level map है, पूर्ण schema reconciliation नहीं। खासकर `amount_paid` को पढ़ने वाले पुराने quote/commission/reporting source के मुकाबले restore migration का later timestamp अभी भी order review मांगता है।

## 5. Wallet foundation के अतिरिक्त base dependencies

`20261109010000_create_secure_wallet_ledger_foundation.sql` नई wallet tables बनाती है, लेकिन साथ ही पहले से मौजूद:
- `auth.users`,
- `public.electrician_profiles.auth_user_id` / `user_id`,
- `public.is_srk_admin()`,
- `gen_random_uuid()` / pgcrypto support

पर निर्भर है।

यह source `electrician_profiles` पर direct query करता है; इसलिए profile table और identity columns का baseline पहले उपलब्ध होना चाहिए। Wallet migration की presence मात्र से base identity schema की उपलब्धता सिद्ध नहीं होती।

## 6. RLS/ACL source review का सीमित निष्कर्ष

- Base setup में RLS enablement और प्रारंभिक public insert / Admin / electrician policies हैं।
- Customer booking policy बाद में अलग migration से आती है और फिर combined policy migration उसे replace करती है।
- Commission migration authenticated direct table UPDATE privileges बदलती है।
- Wallet migration owner-read policies बनाकर table grants सीमित करती है।

इससे साफ है कि replay graph में केवल table creation order नहीं, बल्कि policy replacement, helper function availability और table-level/column-level grants का क्रम भी शामिल करना होगा।

इस छोटे audit में सभी 87 migrations की हर policy/grant/function dependency exhaustively verify नहीं हुई है। इसलिए इसे पूर्ण RLS audit न समझें।

## 7. Safe conclusion / blockers

नए पुष्ट source-level blockers:
1. `is_srk_admin()` का authoritative migration/baseline introduction स्पष्ट नहीं; पुराना `srk_is_admin()` अलग नाम है।
2. Combined booking SELECT policy इस Admin helper और customer ownership column दोनों पर निर्भर है।
3. Canonical base table definitions अभी standalone setup scripts में हैं, verified versioned starter migration में नहीं।
4. Wallet foundation profile identity fields और Admin helper पर निर्भर है।
5. Table, RLS policy, grants और function ordering को एक approved dependency graph में reconcile करना बाकी है।

No migration was renamed/deleted/merged/reordered/repaired/replayed. No database query/write, DDL, deployment, customer/Auth/payment data access, or secrets access occurred. GPT-1 app source untouched.

## 8. अगला सुरक्षित कदम

एक canonical baseline-vs-migration matrix बनाना: हर base table/column/function/policy/grant के लिए (a) starter source, (b) introducing migration, (c) dependent migrations, (d) remote authoritative history proof, और (e) unresolved mismatch। Production provenance केवल DBA/Database Owner के read-only deployment logs/change ticket से verify किया जाए। Gates बंद होने तक local reset/replay और pgTAP runtime execution रुके रहेंगे।
