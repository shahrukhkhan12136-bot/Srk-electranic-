# SRK ELECTRONIC — Master Project Blueprint

यह दस्तावेज़ पूरे प्रोजेक्ट का स्थायी नक्शा है। इसका उद्देश्य सभी मॉड्यूल, डेटा-प्रवाह, जिम्मेदारियाँ, निर्भरताएँ और रिलीज़ गेट एक ही जगह रखना है। यह Blueprint है—इसमें किसी फीचर को बना हुआ तभी माना जाएगा जब कोड, Database, टेस्ट और रनटाइम प्रमाण उपलब्ध हों।

## 1. उत्पाद संरचना

1. Customer Website/PWA और Customer Android App
2. Electrician Website/PWA और Electrician Android App
3. Admin Dashboard — सुरक्षित मोबाइल-फ्रेंडली वेबसाइट/PWA
4. Staff Dashboard — अलग Login और सीमित अधिकारों वाली वेबसाइट/PWA
5. Shared Backend — Supabase Auth, PostgreSQL/RLS/RPC, Netlify Functions, Razorpay
6. Operations — Monitoring, Support/Telephony, Backups, Audit, Release & Recovery

तीसरा Admin Android App नहीं बनाया जाएगा। Android के केवल दो ऐप होंगे: Customer और Electrician।

## 2. End-to-end business lifecycle

Customer registration/login → profile/address/PIN/GPS → service/category selection → booking request → location/serviceability validation → eligible electrician matching → offer/bid → customer selection/acceptance → booking confirmation → booking-scoped contact visibility → electrician arrival evidence → customer-authorized work start → server-timestamped timer → material proposal/itemized approval → work completion → customer timer-stop approval → final bill → Cash/Online payment → server verification/receipt → commission/settlement ledger → rating/review → complaint/cancellation/refund/dispute if needed → reporting and retention.

हर transition का actor, authorization, timestamp, evidence, idempotency और audit event परिभाषित होना चाहिए।

## 3. Roles and access boundaries

- Main Admin: owner-controlled, full business oversight; MFA, secure recovery, audited sensitive actions.
- Staff: individual account; only assigned support/complaint/booking context; no refunds approval, payout control, commission changes, secrets or unrestricted database access.
- Customer: own profile, own bookings, own bills/payments, own complaints.
- Electrician: own profile/application, assigned/offered jobs as authorized, own timer/bill/earnings/payout status.
- System/service role: server-only privileged operations; never expose service-role secrets to browser/mobile apps.

RLS and server-side authorization are mandatory; hiding a UI control is not authorization.

## 4. Business rules (authoritative owner decisions)

- Commission: 15% on labour only; materials excluded.
- Labour and materials are separate; materials require itemized bill/receipt and customer approval; no unauthorized markup.
- Categories/rates:
  - helper: ₹899 / 8 hours; hourly snapshot ₹112.375
  - ordinary: ₹1,199 / 8 hours; hourly snapshot ₹149.875
  - skilled: ₹1,599 / 8 hours; hourly snapshot ₹199.875
  - master: ₹1,999 / 8 hours; hourly snapshot ₹249.875
- Customer booking के समय चारों electrician categories (Helper, Ordinary, Skilled, Master) और category-wise customer price स्पष्ट देखेगा: Helper ₹899, Ordinary ₹1,199, Skilled ₹1,599, Master ₹1,999 (8 घंटे की approved Labour booking rate)। ग्राहक अपनी जरूरत के अनुसार category चुनकर booking करेगा। ये customer-facing gross Labour prices हैं; electrician-facing Rate Card में इन्हें नहीं दिखाया जाएगा।
- Customer sends category code only; server validates the active category and maps label/rate/version, then stores an immutable booking snapshot. Client-supplied price is never trusted.
- No upfront payment. Final bill follows work completion and customer-approved timer stop.
- Timer uses server timestamps; seconds ceiling and minutes ceiling; retain precision until final paise rounding half-up.
- Cash: customer pays electrician directly; electrician confirms actual receipt; electrician remits commission to SRK; Admin confirms actual receipt; cash ledger electrician_payable=0.
- Online: immutable ledger records verified payment and electrician payable; actual transfer status must reflect provider/bank evidence.
- Cancellation fee ₹99 only if customer requested cancellation, electrician arrival evidence exists, and Admin approves. No arrival/evidence means no fee. Actual ₹99 collection is not yet implemented; never imply collected.
- Phone visibility: before acceptance, parties cannot see each other's phone numbers. After electrician accepts/receives the booking, both may see full unmasked numbers and call directly; no OTP needed to reveal after acceptance. Admin may see both. Enforce server-side booking scope.
- PIN 271861 belongs to Balrampur, Uttar Pradesh. A separate Azamgarh record with same PIN is a data inconsistency; do not auto-correct.

## 5. Module map

### Customer
Authentication; profile; addresses and serviceability; service catalogue; booking; offers/bids; electrician selection; booking status; accepted-booking contact; arrival/work approval; timer; material estimates; final invoice; Cash/Online; receipts; notification preferences; rating; complaint; cancellation/refund request; account/data controls.

### Electrician
Application; identity/skill verification; approval/activation; profile/service areas; availability; offer inbox; bid/quote; accept/reject; accepted-booking contact; arrival evidence; timer lifecycle; materials itemization; completion; Cash receipt confirmation; earnings/wallet; commission remittance; payout status; push notifications; complaints/support; account controls.

### Admin
Secure owner login/MFA/recovery; overview; customer/electrician/application management; service/category/rate settings with validation/versioning; booking and offer oversight; contact visibility audit; timer/bill/material audit; cancellation decisions; complaints; payments/refunds; cash reconciliation; commission/wallet/payout; staff access; reports/export; notification templates; support/telephony settings; app version/update management; audit logs; backup/restore and incident tools.

### Staff
Separate login; least-privilege role; customer/booking lookup with verified identity; relevant booking/electrician/bill/payment/complaint history; create/track complaints; action notes; cancellation support flow; escalate to Admin; call records where lawful and configured. No Admin financial controls or unrestricted customer search.

### Shared platform
Auth and sessions; RLS; server RPC/API; immutable ledgers; idempotency; audit events; notifications; observability; privacy/consent; data retention/deletion; backups; disaster recovery; CI; Preview; release and rollback.

## 6. Core data domains

Use existing authoritative tables and migrations as source of truth; do not create duplicate tables casually.

- Identity: auth users, admin allow-list, role assignments, staff accounts.
- Customer: profiles, contact preferences, addresses/locations.
- Electrician: applications, profiles, verification documents/events, service areas.
- Catalogue: services, categories, rates and effective dates.
- Booking: booking, status history, offer/bid, acceptance, arrival evidence.
- Work: timer sessions/events, material proposals/items/approvals, final bill snapshots.
- Finance: payment orders, provider events, payment verification, refund requests/results, wallet, immutable ledger, commission, payout, cash receipt/remittance.
- Support: complaints, complaint events, staff notes, escalations, call metadata/consent.
- Platform: notifications/subscriptions, app configuration versions, release history, audit events, backups/restore evidence.

Each data domain requires owner, purpose, minimal fields, retention period, access matrix, RLS/API policy, audit requirements and deletion/export rules. Never store passwords, OTPs, recovery codes, service-role keys or payment secrets in app tables, source, chat or logs.

## 7. App Update & Maintenance design

Admin-configurable server-side settings: service descriptions, enabled/disabled categories, approved rates with effective date and confirmation, banners/notices, support hours/contact, notification templates, feature availability flags. Every change requires validation, role check, preview/confirmation for high-impact changes, version history, audit log and rollback.

Code/native changes: feature branch → code review/static checks → automated tests → Preview build → manual mobile/desktop review → regression → backup/rollback plan → explicit owner approval → coordinated production release. Native Android changes require new signed AAB and Google Play release. Never deploy or publish automatically.

## 8. Quality gates

A feature is COMPLETE only when all applicable gates pass:
1. Requirement and acceptance criteria documented.
2. UI exists and works on supported screen sizes/accessibility.
3. Server/API and database behavior implemented.
4. RLS and role authorization tested positively and negatively.
5. Input validation, error and network retry behavior tested.
6. Audit/idempotency/consistency verified where relevant.
7. Automated tests pass.
8. End-to-end test with appropriate test accounts/provider sandbox passes.
9. Observability and support runbook exist.
10. Production parity/release migration verified.
11. Owner approval recorded for production changes.

Statuses: NOT STARTED / DESIGN / SCAFFOLD / IMPLEMENTED / TESTING / BLOCKED / VERIFIED IN PREVIEW / LIVE VERIFIED. Never equate SCAFFOLD or IMPLEMENTED with COMPLETE.

## 9. Release constraints

- Work only on feature branch until release gates pass.
- Main Production Supabase remains unchanged during scaffolding.
- Do not apply timer migrations or repair migration history blindly; resolve the documented migration-order/parity gate first.
- No synthetic records in Production.
- No real money movement/refund/payout during tests.
- No paid service activation or plan purchase without explicit approval.
- No Netlify Production deployment or Google Play release without explicit approval.
- Prepare one consolidated release; verify deployment capacity and environment secrets first.

## 10. Open decisions / external dependencies

- Owner-controlled Admin login identifier and secure enrollment flow.
- Staff role matrix and staff count/assignment.
- Support number and cloud telephony provider, concurrency, recording consent, retention and cost.
- Android implementation technology and app signing ownership.
- Legal/privacy/terms, electrician agreements, invoice/tax requirements and data retention validated for applicable jurisdiction.
- Serviceable PIN coverage and escalation when no electrician is available.
- Ratings/reviews moderation and fraud controls.
- Provider sandbox credentials and final payment/Route configuration.

Update this blueprint when owner decisions change. Record date, decision, impact and migration/compatibility notes.

## 11. Electrician Android App — Rate Card (Owner-confirmed: 2026-11-11)

Electrician App में स्पष्ट और आसानी से पढ़ी जाने वाली **Rate Card** स्क्रीन/सूची अनिवार्य होगी। अभी स्वीकृत चारों 8-hour Labour rates यथावत रहेंगे; ₹899–₹999 की नई/सीमित range लागू नहीं होगी।

| Category | काम की अवधि | Electrician को मिलने वाली Labour राशि |
|---|---:|---:|
| Helper | 8 घंटे | ₹764.15 |
| Ordinary | 8 घंटे | ₹1,019.15 |
| Skilled | 8 घंटे | ₹1,359.15 |
| Master | 8 घंटे | ₹1,699.15 |

### Rate Card display and assignment rules
- चारों categories की सूची दिखाई जाए; प्रत्येक row/card में केवल category और electrician को मिलने वाली net Labour राशि दिखे। 8-hour Labour charge, commission प्रतिशत/राशि और deduction का कोई विवरण Rate Card में न दिखे।
- स्क्रीन के शीर्ष पर या स्पष्ट badge में electrician की **अपनी Admin-approved assigned category** और उसी category का net amount highlight हो।
- Category assignment profile/application के verified server record से आए; electrician client-side से अपनी category/rate बदल न सके। Category बदलने का अधिकार केवल अधिकृत Admin workflow को हो और बदलाव audit/versioned हो।
- 15% commission केवल Labour पर है। Materials, parts, travel या अन्य separately approved charges इस Rate Card commission calculation में शामिल नहीं होंगे; Labour और materials अलग invoice lines/receipts रहेंगे।
- Rate Card informational है; यह booking के immutable server-side rate snapshot को override नहीं करेगी। Booking के समय लागू approved rate/version snapshot सुरक्षित रखा जाए।
- सभी रकम INR में दो दशमलव तक दिखाई जाएँ। Commission/net calculation में source precision सुरक्षित रहे और अंतिम paise rounding half-up से हो। ऊपर दिए गए 8-hour totals exact 15% calculation हैं।
- कोई hourly net payout, tax, incentive, deduction या additional fee इस Rate Card में स्वतः न जोड़ा जाए; नई रकम/कटौती के लिए अलग owner approval और documented rule आवश्यक है।
- Rate Card और assigned-category badge responsive, accessible और Hindi/English labels के लिए तैयार हों; खाली/अमान्य category पर गलत default न दिखे—स्पष्ट support/admin error state दिखे।

### Acceptance criteria
1. चारों approved categories, 8-hour duration और electrician के net amounts ठीक ऊपर की तालिका से मेल खाते हों; electrician UI में gross/commission details न हों।
2. Electrician केवल अपनी assigned category पहचान सके; अन्य electrician की private profile/assignment उजागर न हो।
3. API/RLS tests साबित करें कि electrician category/rate बदल नहीं सकता और unapproved/inactive profile पर Rate Card assignment को active नहीं माना जाता।
4. Materials को 15% commission base में शामिल न किया जाए।
5. Booking rate snapshot और Rate Card version में mismatch होने पर booking का immutable snapshot ही invoice authority रहे।
6. Mobile screen, large text, loading, empty/error और offline states का परीक्षण हो।
7. UI/README/Blueprint में feature को implemented न कहा जाए जब तक वास्तविक app code, server integration और tests प्रमाणित न हों।

स्थिति: **REQUIREMENT APPROVED / IMPLEMENTATION NOT STARTED**. Electrician Android workspace अभी README-only scaffold है।


## 12. Customer Booking — Category & Price Display (Owner-confirmed: 2026-11-11)

Booking शुरू करते समय ग्राहक को electrician की चारों categories और हर category का customer price साफ़ दिखेगा। ग्राहक category चुनने के बाद उसी category के आधार पर booking request भेजेगा।

| Electrician category | Customer को दिखने वाला 8-hour price |
|---|---:|
| Helper | ₹899.00 |
| Ordinary | ₹1,199.00 |
| Skilled | ₹1,599.00 |
| Master | ₹1,999.00 |

- Customer-facing booking screen पर category name और संबंधित customer price स्पष्ट हों; price ₹899 से ₹1,999 तक category के अनुसार होगा।
- यह customer price है; इसे electrician के Rate Card से अलग रखें। Electrician Rate Card पर केवल 8 घंटे की अवधि और electrician को मिलने वाला net amount दिखेगा।
- Category/rate की अंतिम पुष्टि server-side active, Admin-approved catalogue से हो। Client से आया price authoritative नहीं होगा।
- Booking create होते समय category code, display label, approved rate/version और applicable duration का immutable snapshot सुरक्षित हो। बाद में rate बदलने से पुरानी booking न बदले।
- ग्राहक को category/price चुनने से पहले कोई upfront payment न लिया जाए। Final bill approved booking snapshot, actual timer और separately approved materials के नियमों के अनुसार बने।
- UI में सभी prices INR में दो दशमलव तक, responsive और accessible रूप में दिखें; loading/error/empty/offline states में गलत या अनुमानित price न दिखे।

स्थिति: **REQUIREMENT APPROVED / CUSTOMER UI IMPLEMENTATION & E2E TEST PENDING**.


## 13. Customer Booking — selectable duration 1–8 hours (Owner-confirmed: 2026-11-11)

Customer booking screen में ग्राहक को **1 से 8 घंटे तक** duration चुनने का विकल्प मिलेगा। ग्राहक 1, 2, 3 … 8 घंटे में से जितने घंटे चुनता है, मोबाइल स्क्रीन पर उसी category और चुनी हुई अवधि का कुल Labour price तुरंत दिखेगा।

### Pricing calculation
- चुनी हुई category का approved 8-hour customer price आधार होगा: Helper ₹899, Ordinary ₹1,199, Skilled ₹1,599, Master ₹1,999.
- चुनी हुई अवधि का कुल price = approved 8-hour price × selected hours ÷ 8. गणना में पूरी precision रखें और अंतिम payable paise पर half-up rounding करें; केवल display के लिए बीच में rounding करके कुल न निकालें।
- उदाहरण: Helper के लिए 1 घंटा ₹112.38, 2 घंटे ₹224.75 और 8 घंटे ₹899.00; Ordinary के लिए 1 घंटा ₹149.88, 2 घंटे ₹299.75 और 8 घंटे ₹1,199.00. अन्य categories भी इसी exact formula से calculate होंगी।
- Screen पर selected category, selected hours और उसी अवधि का total price स्पष्ट दिखे; duration बदलते ही price update हो। ग्राहक 1–8 घंटे में से केवल एक अवधि चुन सके।
- Server active Admin-approved rate/version और duration bounds (integer 1–8) validate करे; client-calculated price पर भरोसा न करे। Booking में category, rate/version, selected duration और calculated Labour total का immutable snapshot store हो।
- 1–8 घंटे का चयन केवल booking करने का विकल्प/ग्राहक की चुनी हुई प्रारंभिक अवधि है; यह काम की अधिकतम सीमा, timer cutoff या final bill cap नहीं है। काम शुरू होने पर server-authoritative timer चलेगा और वास्तविक elapsed work time के अनुसार final Labour bill बनेगा—चाहे वास्तविक समय चुने हुए घंटों से कम हो या अधिक। Timer start/stop, rounding और final bill के पहले से स्वीकृत नियम लागू होंगे; timer को selected duration पर अपने-आप रोकना नहीं है। ग्राहक को booking के समय चुने हुए घंटों का अनुमानित/चयनित अवधि price दिखेगा; final amount actual timer से निर्धारित होगा। Materials/parts अलग itemized और customer-approved रहेंगे। कोई upfront payment नहीं।
- Offline/loading/error/invalid-duration state में stale या अनुमानित price न दिखे; server-validated price unavailable हो तो booking submit रोकें और स्पष्ट संदेश दें।

स्थिति: **REQUIREMENT APPROVED / CUSTOMER UI, SERVER CONTRACT & E2E TEST PENDING**.


## 14. Customer Booking — date-only selection (Owner-confirmed: 2026-11-11)

Customer booking form में **केवल तारीख (Date) चुनने का विकल्प** रहेगा। ग्राहक से booking के समय कोई clock-time / समय चुनने को नहीं कहा जाएगा। मौजूदा time-picker/time-slot selection UI हटाया जाएगा।

- Date picker स्पष्ट, mobile-friendly और उपलब्ध/अनुमत booking dates के validation के साथ हो।
- Booking request में customer-selected service date सुरक्षित हो; customer-selected time field/slot अनिवार्य न हो और UI में time selection न दिखे।
- Date की validation server-side हो; invalid, past या business rules के अनुसार unavailable date पर booking submit न हो।
- Date-only booking को किसी मनगढ़ंत/default समय (जैसे 09:00 या 00:00) में silently convert न करें। Backend/API और matching workflow को date-only intent support करना होगा; जहाँ operational scheduling time बाद में तय हो, वह अलग authorized workflow से हो और customer से time चुनवाने की शर्त न बने।
- Existing timer lifecycle इससे अलग है: काम शुरू होने पर server-authoritative timer चलेगा और final Labour bill actual elapsed work time से बनेगा। 1–8 घंटे का booking selection timer cutoff नहीं है।
- Date-only booking के लिए timezone/date-boundary, availability, duplicate booking, reschedule/cancellation और legacy time-slot compatibility tests आवश्यक हैं।
- पुरानी bookings में मौजूद time data को मिटाएँ/बदलें नहीं; केवल नए booking flow में customer time selection हटाएँ।

स्थिति: **REQUIREMENT APPROVED / BOOKING UI, API-DATA CONTRACT & E2E TEST PENDING**.


## 15. Electrician ID/Profile — assigned category visibility (Owner-confirmed: 2026-11-11)

हर electrician को अपने Electrician App के **Profile / Electrician ID** पर अपनी Admin-approved category साफ़ दिखाई देनी चाहिए—जैसे **Helper, Ordinary, Skilled या Master**। Electrician को अपने ID/profile को देखकर तुरंत पता चल सके कि वह किस category में registered/approved है।

- Electrician ID/Profile पर category का स्पष्ट नाम और badge दिखे; केवल अस्पष्ट code न दिखे।
- Category server-authoritative, verified electrician profile/application assignment से आए; app client से भेजे गए label/category पर भरोसा न हो।
- Electrician अपनी category खुद edit, upgrade या downgrade नहीं कर सके। बदलाव केवल authorized Admin workflow से, audit trail और version history के साथ हो।
- Pending, rejected, suspended, inactive या missing assignment पर Helper/Master जैसी कोई default category न दिखे; वास्तविक status के अनुसार स्पष्ट message दिखे।
- अपने ID/Profile पर केवल signed-in electrician की category दिखाई जाए; दूसरे electricians की private assignment उजागर न हो।
- यही assigned category Rate Card में भी highlight हो और दोनों जगह एक ही authoritative profile value उपयोग हो।
- Category badge mobile-friendly, accessible और Hindi/English labels के साथ हो; loading, offline, stale data और server error states स्पष्ट हों।

Acceptance: profile API/RLS ownership tests, client-tampering negative tests, Admin category-change audit/version tests, status-state tests और mobile UI E2E पास हों।

स्थिति: **REQUIREMENT APPROVED / IMPLEMENTATION & TESTING PENDING**.


## 16. Electrician ID Number — permanent unique identifier (Owner-approved: 2026-11-12)

हर electrician को एक अलग, स्थायी और unique **SRK ELECTRONIC Electrician ID Number** दिया जाएगा। प्रस्तावित readable format: **SRK-EL-000001**, अगला **SRK-EL-000002**, फिर **SRK-EL-000003** आदि।

- ID number server/database द्वारा सुरक्षित तरीके से generate होगा; electrician या client उसे स्वयं नहीं चुन/बदल सकेगा।
- ID केवल Admin approval और electrician account activation के सफल होने पर issue होगा। Pending/rejected application को active Electrician ID number न दिया जाए।
- Number unique, permanent और कभी recycle न हो—account deactivate/delete/suspend होने पर भी वही number किसी दूसरे electrician को न दिया जाए।
- ID में mobile number, Aadhaar, जन्मतिथि या कोई निजी जानकारी encode न हो।
- Electrician Profile/ID Card पर ID Number, approved category badge (Helper/Ordinary/Skilled/Master), electrician display name और approval/status दिखें। Category बदलने पर ID number वही रहे; केवल Admin-approved category और उसका audit/version बदले।
- Database में internal immutable UUID primary key अलग रहे; readable SRK-EL number public/display identifier होगा। Unique constraint, server-side sequence/transaction और concurrent issuance tests अनिवार्य हैं।
- Admin dashboard में ID lookup/search हो; customer-facing screens पर electrician ID केवल जरूरत/अनुमति के अनुसार दिखे। किसी ID number को अकेले authentication या account access का प्रमाण न मानें।
- QR verification भविष्य में जोड़ी जा सकती है, लेकिन QR में निजी data न हो और verification server-side हो।

स्थिति: **ID FORMAT OWNER-APPROVED / SERVER-SIDE SEQUENCE & TRIGGER MIGRATION COMMITTED TO FEATURE BRANCH; NOT APPLIED / PROFILE UI, ADMIN LOOKUP, RUNTIME AUTHORIZATION & TESTING PENDING**.
