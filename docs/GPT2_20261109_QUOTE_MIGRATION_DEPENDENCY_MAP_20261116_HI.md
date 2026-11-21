# GPT-2 20261109 Quote/Commission Migration Dependency Map — 16 Nov 2026

स्थिति: केवल Git source का read-only dependency audit। कोई SQL execution, migration replay, database connection, Production query/write, DDL, deployment या application-source edit नहीं हुआ।

## 1. दायरा

Current branch: `feat/customer-login-first-dashboard-20261114`

मुख्य target:
`supabase/migrations/20261109_electrician_inspection_quotes_and_service_only_commission.sql`

साथ में संबंधित starter SQL और migrations पढ़े गए:
- `COMPLETE_DATABASE_SETUP.sql`
- `SUPABASE_SCHEMA.sql`
- `PORTAL_SCHEMA.sql`
- `20261108121115_add_customer_account_booking_access.sql`
- `20261109000500_harden_electrician_profile_identity_linking.sql`
- `20261109001000_add_google_maps_location_support.sql`
- `20261109002000_expose_assigned_booking_map_pin.sql`
- `20261109003000_secure_commission_reporting.sql`
- `20261116200000_restore_service_bookings_amount_paid.sql`

## 2. Target migration के प्रत्यक्ष object dependencies

### A. `public.service_bookings` — पहले से मौजूद table और columns

Target migration table को create नहीं करती; वह `ALTER TABLE public.service_bookings` करती है और उसके बाद trigger/RPCs बनाती है।

यह इन पहले से मौजूद columns को पढ़ती/लिखती है:
- Base booking fields: `id`, `status`, `assigned_electrician_id`, `customer_name`, `phone`, `address`, `state`, `district`, `pincode`, `preferred_date`, `preferred_time`, `work_details`, `quoted_amount`, `payment_status`.
- Commission fields: `commission_rate`, `commission_amount`.
- Customer ownership: `customer_user_id`.
- Map fields: `location_lat`, `location_lng`.
- Target migration खुद जोड़ती है: `service_charge`, `materials_amount`, `quote_status`, `quote_note`, `quote_submitted_at`, `quote_responded_at`, `work_started_at`.

### B. Profile और offer tables

Target RPCs इन objects पर निर्भर हैं:
- `public.electrician_profiles`: `id`, `user_id`, `verification_status`, `active`, `display_name`, `phone`.
- `public.job_offers`: `id`, `booking_id`, `electrician_id`, `status`, `match_level`, `created_at`.

Target migration इन दोनों tables को create नहीं करती। Historical starter setup में ये tables/fields मौजूद हैं; लेकिन वह Production का authoritative current snapshot नहीं है।

### C. Supabase Auth

RPCs `auth.uid()` का उपयोग करती हैं और customer ownership `customer_user_id` Auth user से जुड़ता है। इसलिए local replay के लिए केवल plain PostgreSQL नहीं, Supabase Auth schema/functions/roles वाला compatible local stack चाहिए।

## 3. Source में मिले migration-to-dependency links

| Dependency | Source evidence | स्थिति |
|---|---|---|
| `customer_user_id` | `20261108121115_add_customer_account_booking_access.sql` इसे `service_bookings` पर जोड़ती है | Source में introducing migration मिली |
| `user_id` / profile identity | `PORTAL_SCHEMA.sql` historical setup में जोड़ती है; `20261109000500...` इसे `auth_user_id` के साथ synchronize/guard करती है | Exact clean-replay baseline और ordering अभी स्वीकृत नहीं |
| `location_lat`, `location_lng` | `20261109001000_add_google_maps_location_support.sql` तीनों booking/application/profile tables पर जोड़ती है | Target quote RPC इन्हें पढ़ती है; dependency order verify करना बाकी |
| `job_offers` और profile base columns | Historical starter setup में definitions मिलीं | Current authoritative baseline नहीं |
| `amount_paid` | Branch में explicit add-column migration `20261116200000_restore_service_bookings_amount_paid.sql` मिली | **महत्वपूर्ण prerequisite gap** |

## 4. नया महत्वपूर्ण finding: `amount_paid` dependency

Target quote/commission migration के trigger function `srk_calculate_booking_commission()` में `NEW.amount_paid` पढ़ा जाता है।

उसी branch में `amount_paid` जोड़ने वाली explicit migration:
`20261116200000_restore_service_bookings_amount_paid.sql`
है। Historical starter `service_bookings` definition में यह column नहीं है।

अलग migration `20261109003000_secure_commission_reporting.sql` भी `amount_paid` को report/RPC में पढ़ती है और authenticated update grant में शामिल करती है।

इसलिए यदि approved replay baseline में `amount_paid` पहले से मौजूद नहीं है, तो:
- quote/commission trigger migration को उस column के उपलब्ध होने से पहले replay करना dependency-order risk है;
- commission reporting migration भी उस column के उपलब्ध होने पर निर्भर है।

यह source-level dependency finding है, runtime failure का दावा नहीं। किसी दूसरे approved baseline या historical SQL path में column पहले से हो सकता है; अभी ऐसा authoritative evidence नहीं मिला। Migration filename collision और remote lineage unresolved होने के कारण migration reorder/rename/repair का कोई प्रस्ताव नहीं किया गया।

## 5. अन्य महत्वपूर्ण dependency observations

1. Target RPC `srk_submit_booking_quote` approved और active electrician profile खोजती है; इसलिए profile verification/activation columns और identity mapping का सही baseline आवश्यक है।
2. Customer quote-response RPC `customer_user_id = auth.uid()` से booking ownership जाँचती है; customer-account migration का सही क्रम आवश्यक है।
3. Offer-details RPC `job_offers`, `electrician_profiles`, `service_bookings` join करती है और map coordinates लौटाती है; तीनों table definitions और location columns आवश्यक हैं।
4. Target migration status/assignment CHECK constraints drop/recreate करती है। Existing constraint names/definitions का baseline और duplicate `20261109` history reconciliation जरूरी है।
5. Target migration `srk_get_my_offer_details()` को drop/recreate करती है; उसी signature की पहले से मौजूद function definition/return type का history-aware reconciliation चाहिए।

## 6. Safe conclusion

- Target migration की dependency chain historical setup scripts से अकेले प्रमाणित नहीं होती।
- `customer_user_id`, profile identity hardening और map coordinates के source introducing files पहचाने गए।
- `amount_paid` एक स्पष्ट order-sensitive prerequisite है: current branch में इसका explicit restore migration 16 Nov timestamp वाली है, जबकि target quote/commission migration और commission-reporting migration इसे पढ़ती हैं।
- यह finding पहले से खुले authoritative baseline और duplicate-version blockers को और स्पष्ट करती है; इन्हें बंद नहीं करती।
- कोई migration rename, delete, merge, reorder, repair, replay या deployment नहीं किया गया।
- कोई Production data, customer/Auth/payment record या secret नहीं पढ़ा गया।

## 7. अगला सुरक्षित कदम

Migration owner/DBA से केवल read-only authoritative migration lineage और approved starter-schema snapshot प्राप्त करना; फिर प्रत्येक prerequisite के लिए source version, remote history version और actual catalog object को अलग-अलग reconcile करना। जब तक यह पूरा न हो, local reset/replay और pgTAP runtime gate BLOCKED रहेगा।

## 8. Verification boundary

- Git source files fetched from the named Feature Branch.
- Static dependency mapping only.
- Supabase CLI / Docker / PostgreSQL / pgTAP: NOT RUN.
- Production connection/query/write: NONE.
- Migration replay/repair/DDL/deployment: NONE.
- GPT-1 Customer/Electrician application source: untouched.

## 9. 16 Nov — Admin/Accounting legacy quotation boundary re-check

Current branch source files re-read:
- `admin.html`: Admin booking table still selects `service_charge`, `materials_amount`, `quote_status` and `quoted_amount`, but renders the historical quote as read-only. The quote cell has no input/select/button or edit handler. Admin's legacy manual-payment branch calls `srk_admin_record_manual_payment`.
- `supabase/migrations/20261115210000_legacy_manual_payment_and_itemized_receipt.sql`: that RPC deliberately requires `selected_category IS NULL`, completed + assigned booking, `quote_status='approved'`, exact labour + materials = approved `quoted_amount`, and rejects Razorpay-linked/new-category bookings. The legacy receipt also reconciles those historic amounts.
- `admin.html` does not call the old quote submit/respond/work-status RPCs. The current `electrician.html` has no references to those old quote RPC names or quote-status fields.
- `20261115220000_retire_live_legacy_quotation_rpcs.sql` drops only the three live legacy quote/work RPCs and replaces the electrician offer-details projection; it does not drop historical quote columns, booking rows, manual-payment RPC, or receipt data.

### Safe retirement rule
Do not delete `quote_status`, `service_charge`, `materials_amount`, `quoted_amount`, or historical quote/payment rows as part of this retirement. They remain necessary for old completed bookings and historical receipts/accounting. New-category bookings must continue using immutable server labour bills and their dedicated Cash settlement path, never the legacy quote/manual-payment RPC. The UI must keep historical quote data read-only and must not reintroduce quote submission/approval for new bookings.

### Regression coverage added
- `tests/admin-legacy-quote-retirement.test.js` now checks that the retirement migration removes the three active quote RPCs without dropping historical booking columns/table or the legacy manual-payment RPC, and that the legacy payment RPC remains approved-quote-scoped and excludes new-category bookings.
- Existing pgTAP source files include 18 checks for legacy manual payment/itemized receipt and 15 checks for the new-category labour-bill/accounting bridge. These files have **not** been executed against isolated PostgreSQL/Supabase in this step; source assertions are not runtime proof.

Verification boundary: current Feature Branch source only. No SQL replay, DB connection, Production query/write, DDL, deployment, merge, or payment/refund action.
