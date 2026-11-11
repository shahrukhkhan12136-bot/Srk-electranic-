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
- Customer sends category code; server maps label/rate and stores immutable snapshot.
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

| Category | Electrician को मिलने वाली Labour राशि |
|---|---:|
| Helper | ₹764.15 |
| Ordinary | ₹1,019.15 |
| Skilled | ₹1,359.15 |
| Master | ₹1,699.15 |

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
1. चारों approved categories और gross/commission/net amounts ठीक ऊपर की तालिका से मेल खाते हों।
2. Electrician केवल अपनी assigned category पहचान सके; अन्य electrician की private profile/assignment उजागर न हो।
3. API/RLS tests साबित करें कि electrician category/rate बदल नहीं सकता और unapproved/inactive profile पर Rate Card assignment को active नहीं माना जाता।
4. Materials को 15% commission base में शामिल न किया जाए।
5. Booking rate snapshot और Rate Card version में mismatch होने पर booking का immutable snapshot ही invoice authority रहे।
6. Mobile screen, large text, loading, empty/error और offline states का परीक्षण हो।
7. UI/README/Blueprint में feature को implemented न कहा जाए जब तक वास्तविक app code, server integration और tests प्रमाणित न हों।

स्थिति: **REQUIREMENT APPROVED / IMPLEMENTATION NOT STARTED**. Electrician Android workspace अभी README-only scaffold है।
