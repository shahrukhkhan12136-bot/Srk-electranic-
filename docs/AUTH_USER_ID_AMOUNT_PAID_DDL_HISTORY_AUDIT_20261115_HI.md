# `amount_paid` और `auth_user_id` — ऐतिहासिक DDL स्रोत ऑडिट
तारीख: 15 नवम्बर 2026  
Repository: `shahrukhkhan12136-bot/Srk-electranic-`  
Scope: केवल Feature Branch के लिए स्रोत-कोड/ऐतिहासिक Git artifact जाँच; कोई Database कनेक्शन या migration execution नहीं।

## 1. `auth_user_id` — अतिरिक्त ऐतिहासिक प्रमाण
Branch `work/separate-customer-electrician-portals` में migration:

`supabase/migrations/20261109223000_sync_electrician_auth_profile_link.sql`

इस migration का trigger function `public.srk_link_electrician_profile()` पहले से मौजूद `electrician_profiles` पर:
- `user_id = NEW.id`
- `auth_user_id = NEW.id`

सेट करता है। इसी migration की `job_offers` SELECT policy दोनों identity fields की तुलना `auth.uid()` से करती है।

महत्वपूर्ण: यह migration `auth_user_id` कॉलम बनाती नहीं है। यह कॉलम को पहले से मौजूद मानकर UPDATE और SELECT करती है। उसी branch के पुराने `PORTAL_SCHEMA.sql` में `user_id uuid unique references auth.users(id) on delete set null` जोड़ा गया है, लेकिन `auth_user_id` नहीं। मौजूदा Google Maps approval migration भी `auth_user_id` को INSERT/UPSERT में लिखती है, पर उसका ADD COLUMN/FK DDL नहीं देती।

निष्कर्ष: `auth_user_id` के लिए consumer-side historical evidence अब मिला है; authoritative column type, nullability, default, FK target/delete action, uniqueness/index और creation migration अभी भी unresolved हैं।

## 2. `amount_paid` — starter schema और consumer evidence
ऐतिहासिक `SUPABASE_SCHEMA.sql` तथा `COMPLETE_DATABASE_SETUP.sql` में `service_bookings` की starter table definition में `amount_paid` नहीं है। बाद की code/migrations इसे payment webhook, receipt/history, commission reporting और refund reconciliation में उपयोग करती हैं। Quote migration में non-negative validation भी है, पर मूल ADD COLUMN या base-table declaration नहीं मिली।

सभी जाँची गई repository branches में starter schema artifacts मिले; अलग generated schema dump/backup नहीं मिला। GitHub code/commit search में मूल column DDL नहीं मिला। यह search/indexing की सीमा के कारण पूर्ण Git-history absence का प्रमाण नहीं है।

निष्कर्ष: `amount_paid` का type, precision, nullability, default, checks, indexes और ownership contract unresolved हैं।

## 3. सुरक्षा निर्णय और अगला कदम
- अनुमान से कोई `ALTER TABLE` या FK नहीं जोड़ा गया।
- कोई Production query/export, migration execution, credential/role creation या schema change नहीं किया गया।
- अगला सुरक्षित प्रमाण-स्रोत owner-approved read-only schema/catalog export या मूल deployment artifact और migration-history record है।
- इस ऑडिट से checklist item बंद नहीं होता: GPT-2 27/39 = 69%; कुल project 55/86 = 64% अपरिवर्तित।
