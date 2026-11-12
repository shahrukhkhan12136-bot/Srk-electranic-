# SRK ELECTRONIC — शेष कार्य, तीन पैनल और निगरानी कार्यान्वयन योजना

**तारीख:** 12 नवंबर 2026  
**शाखा:** `feature/production-push-notifications`  
**स्थिति:** कार्य-योजना / gap register; यह किसी फीचर के लागू या टेस्ट होने का प्रमाण नहीं है।

## 1. लक्ष्य और कार्य-पद्धति

क्रम अनिवार्य रहेगा: **मौजूदा स्थिति की जाँच → Blueprint/निर्भरता तय → Feature Branch पर implementation → automated tests → Preview/Android E2E → सुरक्षा/वित्तीय acceptance → मालिक की मंजूरी → अलग release approval**।

Production Supabase, Production website, live payment, Play Store या paid provider पर कोई बदलाव इस योजना से अधिकृत नहीं है। मौजूदा architecture, data और legacy records को बिना migration/caller audit के नहीं बदलना है। हर task का प्रमाण (commit, test run, environment, परिणाम) tracker में दर्ज होगा।

## 2. तीन मुख्य पैनल में कौन-सी सुविधा कहाँ होगी

Android ऐप केवल दो होंगे। तीसरा मुख्य पैनल Admin का सुरक्षित responsive web dashboard होगा। Staff, Admin का अलग role/सीमित-access view होगा—अलग Android app नहीं।

| सुविधा | Customer Panel (Website/PWA + Android) | Electrician Panel (Website/PWA + Android) | Admin Panel (Secure Web) |
|---|---|---|---|
| Login/OTP/Profile | अपना OTP, प्रोफाइल, पता, privacy | अपना OTP, प्रोफाइल, आवेदन | Admin MFA, role/session controls |
| Service/Booking | सेवा, श्रेणी, 1–8h, तारीख, अनुमान, booking | eligible offers, quote/accept/reject | सभी booking की निगरानी, सुरक्षित reassignment/oversight |
| पहचान/दस्तावेज | अपना verified account | आवेदन, अनुभव, आवश्यक दस्तावेज, service area | verification, approval/rejection, audit |
| फोन गोपनीयता | acceptance से पहले electrician नंबर छिपा; acceptance के बाद full number | acceptance से पहले customer नंबर छिपा; acceptance के बाद full number | अधिकृत Admin audit में दोनों नंबर |
| काम की प्रगति | arrival देखना, timer start/stop approve/reject | arrival evidence, timer request, work progress | evidence/status audit; ग्राहक की approval bypass नहीं |
| सामग्री/बिल | itemized proposal approve/reject, final bill/receipt | सामग्री प्रस्ताव, अलग receipt, completion | audit/dispute review; बिना अनुमति amount edit नहीं |
| भुगतान/कमाई | final bill के बाद Cash/Online, receipt, refund request | Cash receipt confirm, commission remittance, earnings/payout status | reconciliation, commission ledger, payout/refund approval |
| शिकायत/सहायता | शिकायत, cancellation/refund request, support | support/complaint | triage, assignment, escalation, decision/audit |
| Notification | booking/status/payment/support alerts, preferences | offers/booking/timer/payment alerts, preferences | templates, delivery health, incident view |
| रिपोर्ट/नियंत्रण | अपनी booking/payment history, data request | अपनी jobs/earnings/history | business reports, exports, user/role controls, audit |
| App maintenance | app version/update notice | app version/update notice | release/version policy, maintenance banner, incident controls |

### साझा नियम
- Customer के लिए 8 घंटे के Labour rates: Helper ₹899, Ordinary ₹1,199, Skilled ₹1,599, Master ₹1,999; booking estimate 1–8 घंटे के हिसाब से। Server final authority होगा।
- Electrician Rate Card पर केवल net payout (8h): Helper ₹764.15, Ordinary ₹1,019.15, Skilled ₹1,359.15, Master ₹1,699.15। Gross Labour और 15% commission नहीं दिखाना।
- Labour पर 15% commission; materials पर 0% commission। Labour और materials अलग, itemized और customer-approved।
- कोई upfront payment नहीं। Payment केवल timer stop approval, final bill और materials decision के बाद।
- Cash: ग्राहक electrician को देता है; electrician actual receipt confirm करता है; electrician SRK commission remits करता है; Admin actual receipt confirm करता है।
- Online: provider-verified payment/webhook; immutable payable snapshot/ledger।
- ₹99 cancellation केवल customer-request + arrival evidence + Admin approval पर eligible; actual collection अभी implemented नहीं मानी जाएगी।
- Admin और Staff के अधिकार अलग। Staff complaint/support/lookup/escalation तक; refund approval, payout, commission, secrets या unrestricted DB access नहीं।

## 3. काम का मौजूदा प्रमाण-आधारित वर्गीकरण

| क्षेत्र | अभी ज्ञात स्थिति | अगला acceptance gate |
|---|---|---|
| Customer OTP और booking foundation | Feature Branch पर मौजूद; OTP और booking का पूर्ण real E2E अभी प्रमाणित नहीं | real Preview/mobile OTP, ownership, retry, duplicate और failure tests |
| Category/rate/duration/date | rate catalogue RPC, Admin publish RPC, 1–8h और date-only code/SQL assertions मौजूद | India date boundary, stale rates, invalid dates, UI/DB E2E |
| Booking order number | migration/RPC/tests मौजूद | full legacy compatibility और concurrent live-like E2E |
| Electrician application/experience | experience input clarification commit मौजूद; latest commit पर dedicated CI परिणाम अलग से verify करना | form submit, server persistence, Admin display, 0/60/invalid validation |
| Offer/assignment | पुराने acceptance paths और अलग identity rules का audit आवश्यक | single-winner concurrency, profile identity, legacy callers, phone privacy |
| Arrival/timer/final bill | कई migrations/RPC foundations मौजूद; duplicate migration families और cutover gates खुले | clean schema fixture, replay twice, role/RLS, timer concurrency, customer approvals, immutable bill |
| Materials | foundation/contract मौजूद; full UI + revision/approval E2E बाकी | separate itemized revisions, receipt, customer approval, no markup, 0 commission |
| Cash/Online/Razorpay | handlers/migrations मौजूद; Test Mode/Route और reconciliation अधूरे | no-money sandbox, signature/webhook replay, exact snapshot, cash receipt and remittance |
| Cancellation/refund | request/admin-decision/refund foundations मौजूद; ₹99 collection नहीं | all eligibility permutations, no false collection, refund approval/execution separation |
| Admin | existing portal and rate catalogue management present | full role matrix, MFA/recovery, operational/finance audit and E2E |
| Staff | `staff/README.md` scaffold only | separate login, least-privilege dashboard, support workflow |
| Android | Customer POC only; Electrician Android README scaffold | approved app architecture, secure auth bridge, full screens, push/deep links, device testing, signed builds |
| Welcome screen | approved layout code; original uploaded photo asset replacement not complete | exact original photo asset integrated, visual QA on Android; no AI face edits |
| Monitoring/operations | three scheduled checks exist (10:00 security, 12:30 CI, 19:00 CI/test); overlap possible | one authoritative report, evidence, alerting, recovery and backup tests |

## 4. शेष कार्य का क्रम और निर्भरताएँ

### Phase 0 — Inventory और architecture freeze
- Repo tree, branch head, all migrations, RPCs, triggers, policies, Netlify functions, UI callers और workflows का inventory।
- Duplicate/overlapping migrations और legacy quote/timer callers का dependency graph।
- हर feature को `Not started / Scaffold / Implemented / Testing / Verified` में evidence सहित classify करना।
- इस योजना और Master Feature Tracker को एक-दूसरे से sync रखना।

**Exit:** कोई unknown migration/caller या panel ownership नहीं बचा; risky unknowns स्पष्ट BLOCKED हों।

### Phase 1 — Booking और identity foundation
- Customer verified identity, address/serviceability, date-only booking, category/rate snapshot, duration, idempotency।
- Electrician profile/auth identity reconciliation, application verification, approval and permanent display ID।
- Canonical offer acceptance contract; old RPCs के सभी callers/grants/legacy states mapped होने के बाद ही consolidation।
- Exactly-one accepted offer, server assignment और acceptance-based phone visibility।

**Exit:** duplicate booking/acceptance रोकने वाले positive/negative/concurrency tests और दोनों panels का E2E।

### Phase 2 — Work, timer, materials, final bill
- Arrival evidence → electrician start request → customer approval → server timer।
- Stop request → customer approval → immutable final labour bill।
- Material revision/itemized lines → customer approval → separate receipt।
- Customer-supplied materials ₹0; no unauthorized markup; materials excluded from commission।

**Exit:** authorization, replay, concurrency, rounding, stop rejection, material revision और audit tests pass।

### Phase 3 — Payments, ledger और cancellation
- Exact bill/material snapshot से payment eligibility/order।
- Razorpay Test Mode signature, capture, webhook, duplicate/replay and reconciliation।
- Cash actual receipt confirmation, electrician commission remittance, Admin receipt confirmation।
- 15% labour-only commission, online payable ledger, refund evidence।
- ₹99 cancellation eligibility; actual collection को अलग feature/gate रखें।

**Exit:** sandbox-only payment tests; no real money; ledger reconciliation exact।

### Phase 4 — Admin और Staff operations
- Admin role/MFA/recovery, user verification, booking oversight, rate publish/audit।
- Complaint triage, cancellation decision, refund approval vs execution, cash/online reconciliation।
- Staff individual login, least privilege, support lookup, complaint notes, SLA, escalation।
- Reports/export permissions, audit logs, app maintenance and incident controls।

**Exit:** role matrix positive/negative tests; Staff privilege escalation tests fail closed।

### Phase 5 — Android, PWA और welcome asset
- Customer Android full implementation; Electrician Android full implementation।
- Secure Auth session bridge; device token/push/deep links; permission denial/offline/crash/accessibility।
- Founder की पहली भेजी हुई original photo binary asset के रूप में app में लगाना; current old asset तभी replace करें जब new file verified हो। Original face/appearance unchanged; crop owner-approved।
- Customer/Electrician PWA responsive checks; Admin/Staff web-only।

**Exit:** real devices पर supported screen sizes, auth, booking, notifications, image, offline and crash tests।

### Phase 6 — Monitoring, release और recovery
- Daily CI/security jobs के overlap को एक master evidence report में consolidate करना।
- Booking stuck/failure, payment mismatch, notification delivery, crash, backup, restore, reconciliation, complaints और SLA alerts।
- Production schema compatibility, migration rehearsal twice, rollback/forward recovery, RLS regression।
- Release checklist, signed artifacts, privacy/data safety, staged rollout और rollback plan।

**Exit:** सभी critical checks PASS; कोई unresolved critical/high issue नहीं; owner approval और अलग release approval।

## 5. Monitoring tree — क्या लगातार देखना है

1. **Customer:** OTP failure, booking create failure, duplicate request, stuck status, complaint.
2. **Electrician:** application backlog, verification, offer delivery/response, assignment mismatch, arrival/timer errors.
3. **Booking lifecycle:** invalid transition, no accepted offer, multiple winner, stale booking, unauthorized phone visibility.
4. **Timer/Bill:** pending approval age, server timestamp anomalies, duplicate bill, rounding discrepancy.
5. **Materials:** pending revision, missing receipt, customer-supplied charge, unauthorized amount.
6. **Payments:** order/bill mismatch, webhook failure/replay, cash receipt pending, refund mismatch.
7. **Finance:** labour commission 15%, material commission zero, cash remittance, payout mismatch, ledger imbalance.
8. **Admin/Staff:** login/MFA anomaly, privilege denial, sensitive read/action audit, SLA breach.
9. **Notifications:** push token health, send/delivery failure, deep-link failure, opt-out respected.
10. **Website/Android:** uptime, JS/runtime error, app crash, outdated version, offline/retry failure.
11. **Database/Security:** RLS, grants, SECURITY DEFINER search_path, secrets, auth policy, migration drift.
12. **Operations:** backup freshness, restore drill, incident response, CI status, deployment/rollback evidence.

हर alert में severity, affected booking/user reference (PII-minimized), timestamp, owner, runbook, status और resolution evidence होगा। Phone/OTP/secrets alert या logs में नहीं होंगे।

## 6. Release blocker / नियम

- कोई feature केवल UI या migration file मौजूद होने से COMPLETE नहीं होगा।
- Unit/SQL tests, security negative tests और runtime E2E के अलग-अलग परिणाम दर्ज होंगे।
- Production migration, live Razorpay/Route activation, paid telephony/provider, Netlify production deploy, Play Store publish — प्रत्येक के लिए अलग explicit approval चाहिए।
- कोई real-money test नहीं।
- Production database को disposable/incomplete test project पर blindly migrate नहीं करना।
- Existing customer/electrician records और historical bookings preserve करना; unknown data silently rewrite नहीं करना।
- Welcome photo का पुराना asset तब तक delete/overwrite नहीं होगा जब तक नया binary asset commit और app render verify न हो।

## 7. तत्काल अगली execution सूची

1. इस plan को Master Blueprint/Tracker से link करना।
2. Current branch के latest CI runs और सभी workflows verify करना।
3. Migration/RPC/trigger/caller dependency inventory बनाना; duplicates और blockers दर्ज करना।
4. Customer booking + offer/assignment + phone privacy का पूरा E2E test matrix बनाना।
5. Timer/material/final bill/payment का safe disposable fixture rehearsal करना।
6. Admin/Staff role matrix और missing screens implement करना।
7. दोनों Android apps को README/POC से full screen-by-screen implementation तक ले जाना।
8. Original founder photo binary integration और device visual QA।
9. Monitoring alerts/backup/restore/reconciliation tests।
10. Master Tracker में हर item का status केवल evidence मिलने पर बदलना।

**वर्तमान निर्णय:** यह दस्तावेज़ काम का authoritative organization plan है। इसमें listed work को complete नहीं माना गया है। सभी implementation Feature Branch पर होगी; Production और release अभी बंद रहेंगे।
