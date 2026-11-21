# SRK ELECTRONIC — Master Booking / Rate Catalogue API Contract
तारीख: 21-11-2026  
स्थिति: Feature Branch source contract; Production या TEST Database पर लागू नहीं।

## उद्देश्य
मौजूदा `/api/create-booking` endpoint और मौजूदा Booking System को ही Master System में बदलना है। अलग/parallel Booking System या नया booking endpoint न बनाएं। पुराने booking records और पुराने rate snapshots को न बदलें।

## Customer Rate Catalogue
Customer UI सक्रिय दरों के लिए Supabase RPC `srk_customer_list_active_service_rates()` पढ़े। RPC केवल active category, active skill, active service और वर्तमान effective rate लौटाता है।

प्रत्येक row में:
- `category_code`, `skill_code`
- `service_code`, `service_name`
- `billing_model`: `hourly` या `fixed_per_unit`
- `unit_label`
- `level_code`, `level_label`
- `technician_hourly_paise`, `helper_hourly_paise`
- `fixed_labour_paise`
- `rate_version`

रुपये दिखाते समय paise को 100 से भाग दें। API से मिले दर को UI में hardcode न करें। अभी केवल Plumber के Basic, Expert और Master/Industrial rate rows सक्रिय seeded हैं। जिन categories के rate conflicts बाकी हैं, वे सूची में तब तक नहीं आएँगी जब तक Main Admin उन्हें activate नहीं करता।

## मौजूदा Booking API payload
POST `/api/create-booking`; Authorization: Bearer OTP-authenticated customer session; Header `Idempotency-Key`: UUID v4.

साझा आवश्यक fields:
- `customer_name`
- `state`, `district`, `pincode`, `address`
- `location_lat`, `location_lng` (दोनों null या दोनों valid coordinates)
- `work_details`
- `payment_method` (Cash या Razorpay)
- `srk_service_code`
- `srk_rate_level_code`
- `srk_required_technician_count` (1–10)

Hourly सेवा के लिए:
- `srk_duration_minutes`: 1 से 72,000 मिनट (50 दिन) तक
- `srk_service_quantity`: सामान्यतः 1

Fixed-per-unit सेवा के लिए:
- `srk_duration_minutes` न भेजें या null रखें
- `srk_service_quantity`: 1–100

ग्राहक का मोबाइल नंबर payload से authoritative नहीं है। Backend Supabase Auth के OTP-verified user से नंबर लेता है। UI में नंबर readonly दिखाएँ; अलग editable booking phone न जोड़ें।

Master booking के लिए पुराने `selected_category`, `selected_rate_tier`, `selected_duration_hours` fields न भेजें। पुरानी bookings के लिए इनका ऐतिहासिक अर्थ बना रहेगा।

## Server calculation और response
Backend active rate को `srk_customer_get_service_rate(p_service_code,p_level_code)` से पढ़ता है; client-supplied price कभी स्वीकार न करें।

Hourly:
`round((technician_hourly_paise + helper_hourly_paise) × duration_minutes / 60)`

Response `estimate` में:
- `amount_paise`, `amount_rupees`
- `billing_model`, `rate_card_version`
- `technician_hourly_paise`, `helper_hourly_paise`
- `technician_8h_paise`, `helper_8h_paise`, `combined_8h_paise`

8-hour salary केवल rate-card transparency है; hourly billing actual work timer से होगी। इसे fixed package न दिखाएँ।

Fixed-per-unit:
`fixed_labour_paise × srk_service_quantity`

Response में `fixed_labour_paise` और `unit_label` आएँगे। Fixed service पर hourly timer या 8-hour salary न दिखाएँ।

## Rate list UI requirements (GPT-1)
1. मौजूदा Booking screen और मौजूदा rate-list area को ही अपडेट करें; parallel booking screen न बनाएं।
2. Category → Skill/Service → Level चयन active catalogue से dynamic करें।
3. Hourly rate list में Technician प्रति घंटा, Helper प्रति घंटा, Combined प्रति घंटा और Technician/Helper/Combined 8-hour comparison दिखाएँ।
4. Estimate चुनी अवधि के आधार पर दिखाएँ; वास्तविक billing server-side timer records से होगी।
5. Fixed service में प्रति unit fixed labour और quantity दिखाएँ; 8-hour comparison नहीं।
6. Materials/parts labour से अलग रहें; customer approval flow बना रहे।
7. Rate unavailable / Admin Configuration Pending हो तो बुकिंग रोकें; दूसरी category या rate अपने-आप select न करें।
8. Founder photo, OTP login, saved address, GPS/manual address, payment, idempotency, existing booking history और बाकी उपयोगी UI features सुरक्षित रखें।
9. UI में customer phone field केवल verified Auth phone का readonly display रहे; API payload में phone भेजना आवश्यक नहीं।

## Booking snapshots
नई Master booking में backend:
- canonical category/skill/service
- required Technician count
- rate level/version/label
- billing model
- hourly Technician/Helper rate या fixed price
- duration/quantity
- estimated labour
को booking row पर snapshot करता है। बाद के Admin rate changes पुराने booking snapshots नहीं बदलते।

Canonical category वाली booking existing legacy Electrician broadcast को skip करके उसी transaction में shared category-neutral dispatch शुरू करती है। पुरानी legacy bookings existing Electrician flow में रहती हैं।

## Rollout gate और शेष backend integration
- `create-booking.js` में Master API path बनाया गया है, लेकिन `SRK_MASTER_BOOKING_ENABLED=true` feature flag के बिना वह जानबूझकर 503 लौटाता है।
- पुरानी hard-coded Electrician booking दरें भी नई बुकिंग के लिए retire हैं; केवल explicit temporary compatibility flag `SRK_LEGACY_ELECTRICIAN_BOOKING_ENABLED=true` उन्हें चालू कर सकता है। इस flag को production में न लगाएँ।
- इस flag को चालू न करें: मौजूदा authoritative work-timer, multi-Technician completion bill और `create-order.js` / `verify-payment.js` अभी canonical Master hourly/fixed rate snapshots से पूरी तरह जुड़े नहीं हैं।
- अगले backend चरण में Technician identity-based timer start/stop, daily 8-hour threshold + 1.5x overtime, helper/team billing, immutable multi-Technician labour ledger, और quote-free Razorpay/Cash settlement bridge पूरा करना जरूरी है।
- जब तक यह पूरा न हो, Master Booking को live/preview में चालू न करें। Existing legacy Electrician booking path और historical quote/payment records को बिना migration plan न हटाएँ।

## सुरक्षित सीमाएँ
- Migration केवल Feature Branch में source है; अभी किसी Database पर apply नहीं की गई।
- Main Branch, Production DB, live payments, payouts और deployment न बदलें।
- Database pgTAP / disposable PostgreSQL replay अभी बाकी है।
