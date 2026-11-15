# SRK ELECTRONIC — Core Baseline DDL Contract (Source-backed, partial)

**Branch:** `feat/customer-login-first-dashboard-20261114`  
**स्थिति:** आंशिक source-backed extraction; executable fixture नहीं।  
**सुरक्षा सीमा:** यह दस्तावेज़ केवल source review है। किसी database, Supabase project, secret, customer record या payment provider को access/modify नहीं किया गया।

## 1. प्रमाणित legacy base DDL

नीचे के चार base objects `SUPABASE_SCHEMA.sql` और `PORTAL_SCHEMA.sql` में स्पष्ट `CREATE TABLE` definitions से प्रमाणित हैं। `COMPLETE_DATABASE_SETUP.sql` में भी ये definitions consolidated रूप में मौजूद हैं। इन्हें नवीनतम branch schema का पूर्ण प्रतिनिधि नहीं माना जा सकता; incremental migrations के additions अलग से replay होने चाहिए।

### 1.1 `public.service_bookings`

**Source:** `SUPABASE_SCHEMA.sql` (base definition), `COMPLETE_DATABASE_SETUP.sql` (same consolidated definition).

| Column | Type | Null/default | Base constraint |
|---|---|---|---|
| id | uuid | NOT NULL / gen_random_uuid() | PRIMARY KEY |
| created_at | timestamptz | NOT NULL / now() | — |
| customer_name | text | NOT NULL | — |
| phone | text | NOT NULL | CHECK: 10 digits |
| state | text | NOT NULL | — |
| district | text | NOT NULL | — |
| pincode | text | NOT NULL | CHECK: 6 digits |
| address | text | NOT NULL | — |
| service_type | text | NOT NULL | — |
| preferred_date | date | NULL | — |
| preferred_time | time | NULL | — |
| work_details | text | NULL | — |
| payment_method | text | NOT NULL / 'Cash' | — |
| quoted_amount | numeric(12,2) | NULL | CHECK: NULL or >= 0 |
| status | text | NOT NULL / 'new' | CHECK: new, confirmed, assigned, in_progress, completed, cancelled (later widened by migrations) |
| assigned_electrician_id | uuid | NULL | No FK in this base DDL |
| commission_rate | numeric(5,2) | NOT NULL / 15.00 | CHECK: 0..100 |
| commission_amount | numeric(12,2) | NULL | — |
| payment_status | text | NOT NULL / 'unpaid' | CHECK: unpaid, pending, paid, refunded, failed |
| razorpay_order_id | text | NULL | UNIQUE |
| razorpay_payment_id | text | NULL | UNIQUE |
| payment_verified_at | timestamptz | NULL | — |

**Base indexes:** `bookings_location_status_idx(state,district,pincode,status)`.  
**Base RLS:** enabled. Policy `public can submit bookings` permits INSERT to anon/authenticated; no public SELECT policy is created by the base schema.  
**Important later changes:** many migrations add customer ownership, location, payment, quote, work, cancellation, immutable bill, timer, refund and accounting columns/constraints. Base table above is not sufficient on its own to replay those migrations.

### 1.2 `public.electrician_applications`

**Source:** `SUPABASE_SCHEMA.sql`, repeated in `COMPLETE_DATABASE_SETUP.sql`.

| Column | Type | Null/default | Base constraint |
|---|---|---|---|
| id | uuid | NOT NULL / gen_random_uuid() | PRIMARY KEY |
| created_at | timestamptz | NOT NULL / now() | — |
| full_name | text | NOT NULL | — |
| phone | text | NOT NULL | CHECK: 10 digits |
| state | text | NOT NULL | — |
| district | text | NOT NULL | — |
| pincode | text | NOT NULL | CHECK: 6 digits |
| skills | text | NOT NULL | — |
| experience_years | integer | NOT NULL / 0 | CHECK: 0..60 |
| about | text | NULL | — |
| verification_status | text | NOT NULL / 'pending' | CHECK: pending, approved, rejected, suspended |
| active | boolean | NOT NULL / false | — |

**Base RLS:** enabled. Policy `public can apply as electrician` permits INSERT to anon/authenticated. Base file also defines location-related index only for profiles, not applications.

### 1.3 `public.electrician_profiles`

**Source:** `SUPABASE_SCHEMA.sql`, repeated in `COMPLETE_DATABASE_SETUP.sql`; `PORTAL_SCHEMA.sql` adds Auth linkage and indexes.

| Column | Type | Null/default | Base constraint |
|---|---|---|---|
| id | uuid | NOT NULL / gen_random_uuid() | PRIMARY KEY |
| application_id | uuid | NULL | UNIQUE; FK to electrician_applications(id) |
| display_name | text | NOT NULL | — |
| phone | text | NOT NULL | CHECK: 10 digits |
| state | text | NOT NULL | — |
| district | text | NOT NULL | — |
| pincode | text | NOT NULL | CHECK: 6 digits |
| skills | text[] | NOT NULL / '{}' | — |
| active | boolean | NOT NULL / false | — |
| created_at | timestamptz | NOT NULL / now() | — |

**Base indexes:** `electrician_location_active_idx(state,district,pincode,active)`.  
**RLS:** enabled in base schema.  
**Portal additions:** `verification_status text NOT NULL DEFAULT 'pending'` with pending/approved/rejected/suspended CHECK; `user_id uuid UNIQUE REFERENCES auth.users(id) ON DELETE SET NULL`; index `electrician_profiles_user_id_idx(user_id)`.  
**Important:** portal script adds `verification_status` after the base definition, so a clean-room baseline should not duplicate it if the portal/legacy layer is replayed.

### 1.4 `public.job_offers`

**Source:** `SUPABASE_SCHEMA.sql`, repeated in `COMPLETE_DATABASE_SETUP.sql`.

| Column | Type | Null/default | Base constraint |
|---|---|---|---|
| id | uuid | NOT NULL / gen_random_uuid() | PRIMARY KEY |
| booking_id | uuid | NOT NULL | FK service_bookings(id) ON DELETE CASCADE |
| electrician_id | uuid | NOT NULL | FK electrician_profiles(id) ON DELETE CASCADE |
| status | text | NOT NULL / 'offered' | CHECK: offered, accepted, declined, expired, cancelled |
| match_level | text | NOT NULL / 'pincode' | CHECK: pincode, district |
| created_at | timestamptz | NOT NULL / now() | — |
| responded_at | timestamptz | NULL | — |

**Constraints/indexes:** UNIQUE(booking_id,electrician_id); `job_offers_provider_status_idx(electrician_id,status,created_at DESC)`; `job_offers_booking_idx(booking_id,created_at DESC)`.  
**RLS:** enabled; base script intentionally defines no public read/write policies.

### 1.5 `public.srk_admin_users`

**Source:** `PORTAL_SCHEMA.sql`, repeated in `COMPLETE_DATABASE_SETUP.sql`.

| Column | Type | Null/default | Constraint |
|---|---|---|---|
| user_id | uuid | NOT NULL | PRIMARY KEY; FK auth.users(id) ON DELETE CASCADE |
| created_at | timestamptz | NOT NULL / now() | — |

**RLS:** enabled; `srk_admin_users_self_read` SELECT policy for authenticated where user_id = auth.uid(). Admin helper functions/policies are defined in the portal script and later branch migrations; their exact test-double contract must be inventoried separately.

## 2. Objects अभी exact DDL के रूप में प्रमाणित नहीं

पिछली dependency scan में ये pre-existing candidates मिले थे, लेकिन ऊपर उपलब्ध base schema files में इनकी CREATE TABLE definition नहीं है और अभी इस branch के लिए पूर्ण authoritative DDL नहीं मिला:

- `public.srk_booking_complaints`
- `public.srk_booking_complaint_events`
- `public.srk_push_subscriptions`

इनके columns, keys, constraints, RLS और triggers **अनुमान से नहीं बनाए जाएँगे**। इनके owning source/migration या production-independent canonical schema evidence मिलने तक baseline fixture को इन पर निर्भर migrations/tests के लिए incomplete माना जाएगा।

## 3. Versioned migration additions: उदाहरण, पूर्ण सूची नहीं

- `20261109_electrician_inspection_quotes_and_service_only_commission.sql` adds to `service_bookings`: `service_charge numeric(12,2)`, `materials_amount numeric(12,2) NOT NULL DEFAULT 0`, `quote_status text NOT NULL DEFAULT 'not_submitted'`, `quote_note text`, `quote_submitted_at timestamptz`, `quote_responded_at timestamptz`, `work_started_at timestamptz`; it adds nonnegative/valid-status constraints and workflow functions.
- `20261109_allow_quote_approval_booking_states.sql` widens the booking status check to include inspection and quote-approval states, and adds the assigned-electrician requirement for post-assignment states.
- `20261109001000_add_google_maps_location_support.sql` adds booking/application/profile location coordinates and pair/range constraints (exact full additions must be read from that migration during the manifest pass).
- Other migrations add further columns and dependencies. The examples above do not establish the complete final table shape.

**Version collision:** two migration filenames begin with `20261109`. No rename/reorder is authorized by this audit; migration history compatibility must be resolved first.

## 4. Baseline design rules

1. Keep legacy base DDL, Supabase platform test doubles and incremental migrations as separate layers.
2. Do not run `COMPLETE_DATABASE_SETUP.sql` wholesale and then replay migrations: it is a consolidated setup script with overlapping portal/security logic, not a reconciled clean-room baseline manifest.
3. Do not create tables/columns based on regex-only references or guessed names.
4. Record exact source path and DDL evidence for every baseline object.
5. Keep Auth/Storage test doubles synthetic and local-only; never use production secrets or real customer/payment data.
6. Do not claim clean-room replay or pgTAP success until PostgreSQL actually executes the full migration chain and all SQL tests.

## 5. Current conclusion

चार core tables और legacy Admin allowlist की base DDL अब source-backed रूप में दर्ज है। तीन additional pre-existing table candidates अभी unresolved हैं। यह काम dependency documentation को मजबूत करता है, लेकिन कोई GPT-2 checklist item बंद नहीं करता।

**GPT-2 progress:** 27/39 = **69% complete**, 12/39 = **31% remaining**.  
**PostgreSQL/pgTAP runtime:** अभी execute नहीं हुआ।  
**Production / merge / deployment:** कोई बदलाव नहीं।


## 6. Complaint और Push dependencies — अतिरिक्त source audit (2026-11-15)

### 6.1 `public.srk_booking_complaints` और `public.srk_booking_complaint_events`

Branch की recursive migration-tree सूची और complaint-संबंधित migration files जाँची गईं। इन migration files में इन दोनों base tables की कोई `CREATE TABLE` definition नहीं मिली। इसलिए इन्हें अभी भी pre-existing platform/application baseline dependencies माना जाएगा; columns/PK/FK/checks/RLS का पूरा DDL प्रमाणित नहीं है।

माइग्रेशन से केवल निम्न आवश्यक column contract प्रत्यक्ष रूप से दिखता है:

- `srk_booking_complaints`: `id`, `booking_id`, `customer_user_id`, `category`, `description`, `status`, `admin_note`, `created_at`, `updated_at`, `resolved_at`। Complaint create RPC `(booking_id,customer_user_id,category,description)` में INSERT करता है और `id` लौटाता है।
- `srk_booking_complaint_events`: `complaint_id`, `actor_user_id`, `actor_role`, `from_status`, `to_status`, `note`। Complaint create RPC event INSERT करता है; यह पूर्ण table definition नहीं है।
- Customer-facing RPC customer ownership को `service_bookings.customer_user_id` से जाँचता है और complaint पर 24 घंटे में अधिकतम 10 submissions की सीमा लगाता है। यह RPC contract है, base table DDL का विकल्प नहीं।
- `20261113220000_customer_support_conversation_schema.sql` में `srk_booking_complaint_messages` तथा `srk_booking_complaint_message_attachments` नई tables के रूप में बनती हैं; दोनों `srk_booking_complaints(id)` को FK करती हैं और RLS enable करती हैं। इन्हें complaint base tables के साथ भ्रमित नहीं करना चाहिए।

### 6.2 `public.srk_push_subscriptions`

Branch migration tree में `srk_push_subscriptions` की base `CREATE TABLE` definition नहीं मिली। `20261115170001_durable_push_delivery_outbox.sql` का preflight स्पष्ट रूप से `id`, `user_id`, `endpoint`, `p256dh`, `auth` पाँच columns माँगता है; बाद की delivery-ledger migration `id` और `user_id` पर निर्भर करती है। इससे पूरा type/default/unique/FK contract प्रमाणित नहीं होता।

`20261115170001` migration table पर RLS enable करती है, PUBLIC/anon/authenticated से सभी privileges revoke करके authenticated को SELECT/INSERT/UPDATE/DELETE देती है, और चार own-row policies बनाती है जिनका predicate `user_id = (SELECT auth.uid())` है। इसी migration में नई `srk_private.srk_push_delivery_outbox` table बनती है; `20261115180001` नई `srk_private.srk_push_subscription_deliveries` table बनाती है, जिसका `subscription_id` FK `public.srk_push_subscriptions(id)` पर है। ये नई private ledger tables हैं, base subscription table नहीं।

### 6.3 निष्कर्ष और सीमा

- Complaint base और Push subscription base के पूर्ण DDL को अभी अनुमान से fixture में नहीं जोड़ा जाएगा।
- Complaint message/attachment और push outbox/subscription-delivery ledger की migration-created DDL उपलब्ध है; पर ये base dependencies को replace नहीं करतीं।
- इस चरण में कोई migration, test, application code या database बदला नहीं गया; केवल source-backed documentation update है।
- PostgreSQL/pgTAP runtime अभी execute नहीं हुआ। GPT-2 checklist count अपरिवर्तित: **27/39 = 69% complete**, **12/39 = 31% remaining**।


## 7. Legacy consolidated setup files की cross-check

`COMPLETE_DATABASE_SETUP.sql` (402 lines), `SUPABASE_SCHEMA.sql` और `PORTAL_SCHEMA.sql` को भी complaint तथा push base-table definitions के लिए cross-check किया। इन तीनों में `srk_booking_complaints`, `srk_booking_complaint_events` या `srk_push_subscriptions` की `CREATE TABLE` definition नहीं मिली। `COMPLETE_DATABASE_SETUP.sql` में मुख्य रूप से booking/application/profile/job-offer/admin base objects हैं; इसलिए यह complaint/push dependencies का complete baseline नहीं है।

GitHub code search में भी इन तीनों exact base-table `CREATE TABLE` definitions का कोई विश्वसनीय source result नहीं मिला। अतः निष्कर्ष अभी भी यही है: इनके वास्तविक source DDL/remote schema export की आवश्यकता है; केवल migration references से column types, defaults, keys, constraints और मूल RLS policies का अनुमान लगाना सुरक्षित नहीं। इस अनुपलब्धता को स्पष्ट रूप से दर्ज किया गया है; कोई Production schema या secret fetch नहीं किया गया।


## 8. Complaint table का विस्तृत column-use contract

Complaint conversation migrations को line-level पर cross-check करने से base complaint table के लिए अतिरिक्त आवश्यक references प्रमाणित हुए:

- `srk_booking_complaints.id`: message/attachment tables के FK और Admin/Customer conversation RPCs में complaint lookup के लिए आवश्यक।
- `srk_booking_complaints.customer_user_id`: customer message भेजने/पढ़ने, attachment access और customer-owned storage object authorization में ownership predicate के लिए आवश्यक।
- `srk_booking_complaints.booking_id`, `category`, `description`, `status`, `admin_note`, `created_at`, `updated_at`, `resolved_at`: customer complaint create/list RPC के explicit INSERT/SELECT response contract में संदर्भित।
- `srk_booking_complaint_events` के लिए उपलब्ध source evidence में explicit INSERT columns `complaint_id`, `actor_user_id`, `actor_role`, `from_status`, `to_status`, `note` हैं।

यह सूची migration consumers द्वारा आवश्यक column usage है, authoritative DDL नहीं। इससे data types, nullability, defaults, PK/FK, unique/check constraints, indexes, triggers या base RLS policy set प्रमाणित नहीं होते। विशेष रूप से conversation messages/attachments की नई tables के RLS policies base complaint table की policies का विकल्प नहीं हैं।

Push subscription base के लिए उपलब्ध exact consumer contract अभी `id`, `user_id`, `endpoint`, `p256dh`, `auth` ही है; `id`/`user_id` पर delivery ledger और बाकी तीन columns delivery sender payload में प्रयुक्त हैं। उनके SQL types और uniqueness/FK semantics अभी unresolved हैं।


## 9. Historical branch source recovery — Complaint और Push base DDL (2026-11-15)

पहले की current-branch-only खोज में Complaint/Push base DDL नहीं मिला था। सभी उपलब्ध historical branches के migration trees जाँचने पर दो authoritative repository source files मिले। इसलिए नीचे का निष्कर्ष संशोधित है: ये definitions अब source-backed हैं; फिर भी historical migration को current release में सीधे replay करने की अनुमति/सिफारिश नहीं है।

### 9.1 Complaint base tables — recovered

**Source:** branch `work/separate-customer-electrician-portals`, file `supabase/migrations/20261110040000_customer_admin_complaints.sql`.

इस migration में दोनों base tables की पूरी `CREATE TABLE IF NOT EXISTS` definitions हैं:

- `public.srk_booking_complaints`
  - PK `id uuid DEFAULT gen_random_uuid()`
  - FK `booking_id → service_bookings(id) ON DELETE RESTRICT`
  - FK `customer_user_id → auth.users(id) ON DELETE RESTRICT`
  - category allowlist और description 20–2000 character checks
  - status default `new`, allowed: `new/in_review/resolved/closed`
  - optional `admin_note` max 2000 characters
  - `created_at`, `updated_at` default `now()`; nullable `resolved_at`
  - nullable `updated_by` और `resolved_by` FKs to `auth.users(id)`
- `public.srk_booking_complaint_events`
  - PK `id uuid DEFAULT gen_random_uuid()`
  - FK `complaint_id → srk_booking_complaints(id) ON DELETE CASCADE`
  - FK `actor_user_id → auth.users(id) ON DELETE RESTRICT`
  - actor role allowlist `customer/admin`
  - optional from_status, required to_status, allowed complaint states
  - optional note max 2000 characters; `created_at DEFAULT now()`

**Indexes:** complaint events on `(complaint_id, created_at ASC)`; complaints on `created_at DESC`, `(booking_id, created_at DESC)`, and `(status, created_at DESC)`.

**RLS/ACL:** दोनों tables पर RLS enabled; PUBLIC, anon और authenticated से सभी table privileges revoke। इस migration में base complaint/event tables के लिए कोई direct client RLS policy नहीं बनाई गई। Access intended through the granted SECURITY DEFINER RPCs; service-side access remains separate. इसे own-row direct-table policy समझना गलत होगा।

### 9.2 Push subscription base table — recovered

**Source:** branch `feature/production-push-notifications`, file `supabase/migrations/20261111090000_add_electrician_push_subscriptions.sql`.

`public.srk_push_subscriptions` का पूर्ण base DDL मिला:

- `id uuid PRIMARY KEY DEFAULT gen_random_uuid()`
- `user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE`
- `endpoint text NOT NULL UNIQUE`
- `p256dh text NOT NULL`, `auth text NOT NULL`
- `created_at timestamptz NOT NULL DEFAULT now()`, `updated_at timestamptz NOT NULL DEFAULT now()`
- endpoint length 1–2048; p256dh और auth length 1–256 checks
- index `srk_push_subscriptions_user_id_idx(user_id)`

**RLS/ACL:** RLS enabled; authenticated user के लिए own-row SELECT/INSERT/UPDATE/DELETE policies, predicate `user_id = (select auth.uid())`; anon और PUBLIC revoke; authenticated को SELECT/INSERT/UPDATE/DELETE grants।

### 9.3 Release और baseline सुरक्षा निष्कर्ष

- दोनों DDL definitions historical feature branches से recovered हैं; ये वर्तमान branch के migrations की स्वतः replay approval नहीं हैं।
- Complaint source migration का timestamp `20261110040000` और Push source migration का `20261111090000` है। Current branch में इनके बाद के migrations मौजूद हैं, इसलिए baseline manifest में historical base DDL को एक बार शामिल कर dependency order और duplicate-object behavior जाँचना होगा।
- Current branch की बाद की complaint/push migrations ने इन base objects को `CREATE TABLE` से दोबारा नहीं बनाया; वे इन्हें existing dependencies की तरह consume करती हैं।
- Historical Production schema inventory में इन tables के RLS enabled होने और complaint/event tables पर direct policies न होने का catalog observation भी दर्ज है; यह inventory snapshot है, वर्तमान Production access या schema re-query नहीं।
- कोई database/Production project/secret बदला या access नहीं किया; कोई migration apply नहीं हुई। PostgreSQL/pgTAP runtime अभी भी बाकी है।


## 10. पाँच core base tables के historical starter DDL स्रोत (2026-11-15)

Repository के पुराने commit `08e5ff8abc1cf2a5e2ae656a951f8f4d8863247b` पर मौजूद setup files से पाँच core tables के प्रारंभिक DDL स्रोत मिले। यह historical starter schema है, current Production या वर्तमान Feature Branch का पूर्ण parity export नहीं।

### 10.1 Source mapping

| Table | Historical source |
|---|---|
| `public.service_bookings` | `SUPABASE_SCHEMA.sql` |
| `public.electrician_applications` | `SUPABASE_SCHEMA.sql` |
| `public.electrician_profiles` | `SUPABASE_SCHEMA.sql` + `PORTAL_SCHEMA.sql` alterations |
| `public.job_offers` | `SUPABASE_SCHEMA.sql` |
| `public.srk_admin_users` | `PORTAL_SCHEMA.sql` |

`COMPLETE_DATABASE_SETUP.sql` में यही starter setup consolidated रूप में है। इसे नई/current migrations का replacement नहीं माना जा सकता।

### 10.2 Base contract का संक्षिप्त सार

- `service_bookings`: UUID PK; customer contact/location/service fields; optional preferred date/time और work details; payment method/quote; booking status; assigned electrician UUID; commission rate/amount; payment status; unique Razorpay order/payment IDs; payment verification timestamp। Phone/pincode format, status, payment-status और commission-rate checks मौजूद हैं।
- `electrician_applications`: UUID PK; applicant name/phone/location/skills; experience 0–60; optional about; verification status allowlist; active flag; phone/pincode checks।
- `electrician_profiles`: UUID PK; unique optional application FK; display name/phone/location; skills text array; active; created timestamp। Portal setup बाद में `verification_status` और unique nullable `user_id` Auth FK जोड़ता है।
- `job_offers`: UUID PK; booking और electrician profile FKs; offer status/match-level allowlists; timestamps; unique `(booking_id,electrician_id)`; provider/status और booking indexes।
- `srk_admin_users`: `user_id` Auth FK/PK और `created_at` timestamp; बाद के setup में RLS enabled और self-read policy।

### 10.3 महत्वपूर्ण parity सीमाएँ

- ये files कई बार `CREATE TABLE IF NOT EXISTS` और बाद के `ALTER TABLE ADD COLUMN IF NOT EXISTS` का उपयोग करती हैं। किसी पहले से मौजूद table पर इन्हें चलाने से existing table की पूरी definition verify नहीं होती।
- `service_bookings.assigned_electrician_id` का शुरुआती DDL केवल UUID column है; इस source में FK constraint नहीं है।
- ये पुरानी schema files current branch में बाद में जुड़े customer/auth identity, timer, immutable bill, refund, payout, wallet, audit, support, push-delivery और अनेक payment contracts का complete baseline नहीं हैं।
- Historical Production inventory में 25 public tables और 182 constraints दर्ज थे; यह starter setup केवल पाँच core operational tables तथा शुरुआती portal setup दिखाता है। Counts अलग समय/स्रोत के हैं; इन्हें current parity assertion न समझें।
- Current branch के सभी incremental migrations का dependency-ordered replay manifest और object-by-object reconciliation अभी बाकी है। Duplicate migration timestamps तथा production-vs-feature schema differences को resolve किए बिना fixture को parity-ready घोषित नहीं किया जाएगा।

**सुरक्षा:** यह source recovery और दस्तावेज़ी तुलना है। कोई SQL apply, Production access, schema mutation या live operation नहीं किया गया।


## 11. Migration dependency audit — unresolved base-column prerequisites

71 migration SQL files वर्तमान Feature Branch tree में मिले। Filename/version grouping में duplicate 8-digit prefix `20261109` मिला:

- `20261109_allow_quote_approval_booking_states.sql`
- `20261109_electrician_inspection_quotes_and_service_only_commission.sql`

दोनों का version prefix समान है। इन्हें Supabase migration history में सुरक्षित रूप से कैसे represent/replay करना है, यह CLI/history reconciliation के बिना तय नहीं किया गया। किसी file का rename या migration history repair नहीं किया गया।

### Static source cross-check से मिले dependency gaps

1. Historical starter `SUPABASE_SCHEMA.sql` में `service_bookings` के लिए `amount_paid` column नहीं है। लेकिन `20261109_electrician_inspection_quotes_and_service_only_commission.sql` में trigger/RPC `amount_paid` को पढ़ता है। Current branch migration tree और exact-text repository search में इसका authoritative `ADD COLUMN`/base DDL source नहीं मिला।
2. `20261109001000_add_google_maps_location_support.sql` के Admin approval function में `electrician_profiles.auth_user_id` को INSERT/UPDATE किया जाता है। Historical starter `PORTAL_SCHEMA.sql` केवल `user_id` जोड़ता है; current migration tree/repository exact-text search में `auth_user_id` का authoritative base/add-column DDL नहीं मिला।
3. उसी Google Maps migration में `location_lat/location_lng` columns जोड़े जाते हैं; यह dependency स्पष्ट रूप से उस migration में मौजूद है।
4. `20261108121115_add_customer_account_booking_access.sql` `service_bookings.customer_user_id` जोड़ता है; यह ग्राहक ownership migration का source-backed prerequisite है।
5. `20261110140000_restore_missing_customer_booking_quote_columns.sql` केवल `customer_suggested_amount` और `electrician_quote_kind` जोड़ता है; यह `amount_paid` gap को resolve नहीं करता।

### निष्कर्ष / सुरक्षित अगला कदम

- Historical setup files + current migration files को जोड़कर अभी भी complete, self-contained, reproducible baseline नहीं बनता।
- विशेष रूप से `amount_paid` और `auth_user_id` के लिए source-of-truth DDL या approved schema snapshot चाहिए। Production inventory में column observation होना source SQL या migration provenance के बराबर नहीं है।
- Disposable DB fixture तब तक parity-ready नहीं होगा जब तक इन prerequisites के types, nullability, defaults, constraints, indexes और ownership semantics प्रमाणित न हों।
- Migration CLI version parsing, duplicate-version handling और existing migration-history reconciliation को अलग से validate करना होगा; production history को edit नहीं करना है।

यह static source audit है। कोई migration execute नहीं हुई और कोई Production/database connection नहीं किया गया।


### 11.1 — Cross-branch exact DDL search update (15 नवम्बर 2026)

पिछले static audit के बाद अतिरिक्त cross-check:

- पाँच उपलब्ध historical feature/work branches में COMPLETE_DATABASE_SETUP.sql और 20261109001000_add_google_maps_location_support.sql के समान paths पढ़े। इन setup copies में service_bookings.amount_paid का base/add-column DDL नहीं मिला; Google Maps migration copies में auth_user_id को function INSERT/UPSERT में उपयोग किया गया है, पर उसे जोड़ने वाला ADD COLUMN नहीं मिला।
- Current code search में auth_user_id का एक और consumer 20261109010000_create_secure_wallet_ledger_foundation.sql के line 104 पर मिला: coalesce(ep.auth_user_id, ep.user_id)। अतः यह column केवल Google Maps approval function की जरूरत नहीं; wallet ownership resolution भी इसे पढ़ता है।
- 20261109003000_secure_commission_reporting.sql amount_paid पढ़ता है, negative-value guard लगाता है और authenticated column UPDATE grant में इसे शामिल करता है। 20261109_electrician_inspection_quotes_and_service_only_commission.sql भी trigger में इसे पढ़ता है; फिर भी starter schema और उपलब्ध migration tree में authoritative column definition नहीं मिली।
- Exact-text code search में कोई अलग ADD COLUMN amount_paid या ADD COLUMN auth_user_id definition नहीं मिली। पाँच historical branches की समान file copies एक ही ऐतिहासिक स्रोत की पुनरावृत्ति हो सकती हैं; उन्हें स्वतंत्र schema provenance नहीं माना गया।

**निर्णय:** दोनों columns के type/nullability/default/constraint/index/ownership contract अभी भी unresolved हैं। उन्हें अनुमान से जोड़ना, migration बनाना या fixture को parity-ready घोषित करना सुरक्षित नहीं। अगला वैध स्रोत पुराने commit/tree history में अलग migration/schema snapshot या अनुमोदित schema export होगा।
