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
