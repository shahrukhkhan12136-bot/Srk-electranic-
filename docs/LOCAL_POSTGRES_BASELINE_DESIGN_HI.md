# SRK ELECTRONIC — Isolated PostgreSQL Baseline Design (Hindi)

**स्थिति:** डिज़ाइन प्रस्ताव / source-audit आधारित; अभी executable fixture नहीं।  
**उद्देश्य:** Feature Branch की SQL migrations और pgTAP contracts को केवल disposable local/CI PostgreSQL में चलाने की तैयारी। Production Supabase, production secrets या वास्तविक customer/payment data का उपयोग नहीं।

## 1. सुरक्षा सीमाएँ

1. Test harness केवल नया disposable database/container बनाएगा; production URL, Supabase project URL या repository secret स्वीकार नहीं करेगा।
2. कोई migration Production/Live पर apply नहीं होगी। Existing `.github/workflows/supabase-schema-ci.yml` इस उद्देश्य के लिए उपयोग नहीं होगा, क्योंकि वह Production schema export और पुराने branch gate पर निर्भर है।
3. Harness में केवल synthetic test users/rows होंगे। `auth.uid()`, `auth.users`, Storage और roles के test doubles local fixture में ही रहेंगे।
4. Provider integrations mock/stub रहेंगी। कोई Razorpay refund/order, Route transfer, payout, SMS/OTP या push send नहीं होगा।
5. Migration source को baseline में copy/duplicate करके दोहरी परिभाषा नहीं बनाई जाएगी। Baseline केवल उन पूर्व-मौजूद objects को परिभाषित करेगा जिन पर शुरुआती migrations निर्भर हैं।
6. `20261109` के दो legacy migration version names को rename या silently reorder नहीं करना है। पहले migration-history reconciliation और CLI behavior का अलग निर्णय आवश्यक है।

## 2. प्रस्तावित fixture layers

| Layer | उद्देश्य | न्यूनतम scope |
|---|---|---|
| A — PostgreSQL bootstrap | Disposable DB को Supabase-जैसा test context देना | आवश्यक extensions; `anon`, `authenticated`, `service_role` roles; `auth`, `storage`, `srk_private` schemas; केवल source से प्रमाणित helper functions |
| B — Auth test double | JWT/owner checks के लिए deterministic पहचान | `auth.users` के केवल migration-referenced columns; `auth.uid()` को test session claim से पढ़ना; synthetic users |
| C — Storage test double | Avatar/support attachment policy contracts | `storage.objects` और bucket metadata के केवल migration-referenced columns; कोई वास्तविक object storage नहीं |
| D — Legacy application baseline | Incremental migrations से पहले मौजूद core tables | `service_bookings`, `electrician_applications`, `electrician_profiles`, `job_offers`, `srk_admin_users` और source audit में प्रमाणित अन्य pre-existing tables |
| E — Migration replay | Branch की incremental SQL chain | Explicit ordered manifest; version collision पर stop/fail-closed; कोई automatic rename नहीं |
| F — pgTAP execution | वास्तविक SQL assertions चलाना | उपलब्ध pgTAP extension/version; प्रत्येक test का plan और SQL execution result |

## 3. Core baseline के लिए अभी तक प्रमाणित बातें

- Branch में 71 SQL migration files हैं।
- शुरुआती migrations core application tables पर `ALTER TABLE`, policies, triggers और functions लगाती हैं; इसलिए migration directory अकेले clean-room baseline नहीं है।
- `COMPLETE_DATABASE_SETUP.sql` में पाँच core tables दिखती हैं, पर यह नवीनतम migration chain के सभी पुराने columns, constraints, triggers या platform objects की पूर्ण परिभाषा नहीं है। इसे बिना reconciliation के fixture या canonical schema नहीं मानना है।
- Customer profile/avatar/support migrations `auth.users`, `auth.uid()` और Storage objects का संदर्भ देती हैं।
- Refund, payout, booking, timer, dispatch और audit migrations कई पहले से मौजूद booking/profile columns तथा helper schemas पर निर्भर हैं।
- 33 pgTAP SQL test files मौजूद हैं। वर्तमान Node plan-count test केवल `plan()` और assertion-call संख्या मिलाता है; SQL execute नहीं करता।

## 4. Fixture लिखने से पहले अनिवार्य dependency inventory

हर migration और test file से machine-readable सूची बनानी होगी:

- `CREATE/ALTER TABLE`, `ADD/DROP COLUMN`, constraints, indexes और triggers;
- `REFERENCES` वाले FK targets और referenced columns;
- function bodies में प्रयुक्त table/column names (सिर्फ DDL scan पर्याप्त नहीं);
- `auth.*`, `storage.*`, `extensions.*`, `srk_private.*` references;
- required extensions, enum/types, operators और PostGIS/geo functions यदि कोई हों;
- role grants, RLS policies, `SECURITY DEFINER`, `search_path` और function execute grants;
- migration से पहले मौजूद trigger/function/table dependencies;
- प्रत्येक pgTAP test के `BEGIN/ROLLBACK`, fixtures, role switching और JWT claim assumptions।

किसी column/table का नाम अनुमान से fixture में नहीं जोड़ना है। हर baseline object के साथ source path और reference evidence दर्ज होगा।

## 5. Migration replay और legacy version collision

- दोनों `20261109_*.sql` filenames के version prefix समान हैं। मौजूदा Node guard इसे legacy collision के रूप में पहचानता है।
- पहले Supabase CLI/migration runner के version parsing और duplicate-version व्यवहार को अलग isolated scratch repository/database में सत्यापित करना होगा।
- Production migration history से तुलना किए बिना इन filenames को rename करना मना है।
- Replay manifest में प्रत्येक migration का exact filename, parsed version, predecessor dependencies और collision status दर्ज हो।
- किसी unresolved duplicate, missing prerequisite या failed migration पर replay तुरंत रुके; अगले migration पर skip न करे।

## 6. CI में स्वीकार्यता के gates

1. **Static dependency gate:** हर migration dependency या तो bootstrap/baseline में परिभाषित हो या पहले की migration में निर्मित हो।
2. **Clean-room gate:** खाली disposable PostgreSQL से bootstrap + baseline + पूरी migration chain बिना manual SQL edits के replay हो।
3. **Version gate:** migration versions unique हों या स्पष्ट, tested legacy handling मौजूद हो।
4. **pgTAP gate:** सभी 33 SQL test files वास्तव में execute हों; केवल plan count पर्याप्त नहीं।
5. **Role/RLS gate:** anon, authenticated (कम-से-कम customer/electrician/support/admin synthetic identities) और service_role contexts में authorization tests चलें।
6. **Repeatability gate:** नया database बनाकर पूरा run दोहराने पर वही परिणाम मिले।
7. **Isolation gate:** CI में production secrets/URLs अनुपस्थित हों; test job disposable service container के अतिरिक्त किसी DB host से connect न कर सके।
8. **Evidence gate:** CI summary में PostgreSQL version, migration count, executed pgTAP count, pass/fail और exact commit SHA दर्ज हों।

## 7. वर्तमान blocker और अगला सुरक्षित कदम

इस कार्य-सत्र के environment check में `psql`, `postgres`, `docker`, `podman` और `pg_virtualenv` executables उपलब्ध नहीं मिले। इसलिए अभी local PostgreSQL container शुरू करके runtime दावा करना संभव नहीं है।

अगला कदम source-only dependency manifest बनाना है—विशेषकर core table columns, Auth/Storage object contracts, extensions और शुरुआती migration prerequisites। उसके बाद CI में disposable PostgreSQL service जोड़ने की feasibility जाँची जाएगी। जब तक clean-room replay और pgTAP वास्तविक रूप से न चलें, SQL runtime को **असत्यापित** ही माना जाएगा।

**वर्तमान GPT-2 checklist:** 27/39 = 69% पूरा; 12/39 बाकी। यह डिज़ाइन/अतिरिक्त hardening checklist item closure नहीं है, इसलिए प्रतिशत नहीं बढ़ाया गया।
