# SRK ELECTRONIC — मास्टर प्रोजेक्ट प्रगति सूची

**स्थिति snapshot:** 14 नवम्बर 2026  
**Repository:** `shahrukhkhan12136-bot/Srk-electranic-`  
**काम की branch:** `feat/customer-login-first-dashboard-20261114`  
**Master Epic:** [Issue #3](https://github.com/shahrukhkhan12136-bot/Srk-electranic-/issues/3)  
**Requirements का source of truth:** [SRK ELECTRONIC Master Requirements](https://github.com/shahrukhkhan12136-bot/Srk-electranic-/blob/feature/platform-fee-cash-online-cycle/docs/SRK_ELECTRONIC_MASTER_REQUIREMENTS_HI.md)

> यह स्थायी hand-off / resume दस्तावेज़ है। बातचीत रुक जाए तो इसी फाइल को खोलकर स्थिति, बाकी काम और अगला क्रम समझा जा सकता है। हर अगली प्रगति पर इसे update करना है।

## 1. कुल प्रगति — प्रमाण आधारित

इस tracker में Master Requirements के Section 14.1–14.8 के 89 checkbox points और Section 16 के 7 public-website points शामिल हैं: **कुल 96 मूल checklist points**।

| स्थिति | संख्या | अर्थ |
|---|---:|---|
| ✅ पूरी तरह Verified Complete | 0 | Code + backend/RLS/RPC + relevant tests + required verification evidence सभी पूरे |
| 🟡 आंशिक / काम जारी | 65 | Audit, source changes, partial implementation या test preparation मौजूद; acceptance अभी अधूरा |
| 🟠 Blocked / dependency या decision बाकी | 7 | authoritative data, approved policy, backend dependency या सुरक्षित release prerequisite बाकी |
| ⚪ बाकी / पर्याप्त प्रमाण नहीं | 24 | अभी implementation/verification का भरोसेमंद evidence उपलब्ध नहीं |
| **कुल** | **96** |  |

**महत्वपूर्ण:** 65/96 का मतलब 67.7% फीचर पूरे होना नहीं है। इसका मतलब इन बिंदुओं पर कुछ audit/source/implementation कार्य दर्ज है। **सख्त verified completion अभी 0/96 (0%) है।** किसी item को केवल UI या migration file मौजूद होने से Complete नहीं माना जाएगा।

अलग से Master Epic में बताया गया **96-item real-world test batch** final acceptance test set है; वह इस 96-point requirements checklist से अलग test gate है।

## 2. श्रेणीवार स्थिति

| Master category | मूल points | आंशिक / जारी | Blocked | बाकी | Verified Complete |
|---|---:|---:|---:|---:|---:|
| ग्राहक ऐप और वेबसाइट (Section 14.1) | 14 | 8 | 4 | 2 | 0 |
| इलेक्ट्रिशियन ऐप / पोर्टल (Section 14.2) | 14 | 11 | 0 | 3 | 0 |
| एडमिन पैनल और कंपनी संचालन (Section 14.3) | 15 | 13 | 0 | 2 | 0 |
| पेमेंट, Razorpay, Wallet और Accounting (Section 14.4) | 13 | 11 | 1 | 1 | 0 |
| Notifications और Communication (Section 14.5) | 6 | 4 | 0 | 2 | 0 |
| Security, Privacy और Data Governance (Section 14.6) | 10 | 5 | 0 | 5 | 0 |
| Backup, Reliability और Recovery (Section 14.7) | 6 | 0 | 0 | 6 | 0 |
| QA, Accessibility और Release Sign-off (Section 14.8) | 11 | 7 | 2 | 2 | 0 |
| Public Website / Landing Page (Section 16) | 7 | 6 | 0 | 1 | 0 |
| **कुल** | **96** | **65** | **7** | **24** | **0** |

## 3. मूल checklist — बिंदुवार स्थिति

### Section 14.1 — ग्राहक ऐप और वेबसाइट

- **🟡 आंशिक / काम जारी** — OTP login — Source/CI जाँच Verified: OTP send/verify source, दोनों customer pages के cooldown/duplicate-action markers, OTP input/source checks, inline JavaScript syntax, logout guards/error handling और GitHub Actions Run #9 success दर्ज। वास्तविक OTP/Auth परीक्षण बाकी; Production OTP expiry, server-side resend/wrong-attempt limits, CAPTCHA, abuse controls, session lifecycle/revocation और browser/device E2E अभी अंतिम batch test/config verification में लंबित हैं।
  - स्थिति/अगला काम: OTP source/CI checks और login/session सुधार हैं; server-side Auth policy, expiry/abuse controls और वास्तविक OTP E2E बाकी।
- **🟡 आंशिक / काम जारी** — पाँच मुख्य मेनू: Home, My Bookings, Payments, Help & Support, My Profile।
  - स्थिति/अगला काम: पाँच-menu shell मौजूद है; Payments/Support/Profile contracts और payment dependency अभी पूरे नहीं।
- **🟡 आंशिक / काम जारी** — Booking form: verified mobile (editable नहीं), नाम, address, map pin, PIN/district/state, work description, category और 1–8 घंटे।
  - स्थिति/अगला काम: Verified mobile read-only का सीमित source fix है; बाकी form fields, category/duration, address/map और full tests अधूरे।
- **🟠 Blocked / निर्भरता बाकी** — PIN/district validation: authoritative PIN directory, mismatch warning/review queue; existing address स्वतः overwrite नहीं।
  - स्थिति/अगला काम: Authoritative PIN directory और mismatch review workflow उपलब्ध/स्वीकृत नहीं।
- **🟠 Blocked / निर्भरता बाकी** — Category, rate, duration और estimate का स्पष्ट विवरण; estimate और final actual-minute bill अलग।
  - स्थिति/अगला काम: Category/rate/duration/estimate semantics और approved category mapping पूरी तरह तय/verify नहीं।
- **🟠 Blocked / निर्भरता बाकी** — Submit confirmation, terms/fee disclosure और duplicate-submit protection।
  - स्थिति/अगला काम: Terms/fee disclosure और server-side idempotent duplicate-submit proof बाकी।
- **🟡 आंशिक / काम जारी** — Booking timeline: pending/offers/accepted/en route/arrived/start approval/in progress/completion review/payment/closed।
  - स्थिति/अगला काम: Timeline UI/RPC source मौजूद; legacy event mapping, electrician view और DB/JWT runtime tests बाकी।
- **🟡 आंशिक / काम जारी** — Accepted booking में assigned electrician का direct-call number; completion के बाद customer-facing UI/API/receipt/history में phone अनुपलब्ध।
  - स्थिति/अगला काम: Contact visibility के source gates में सुधार; दोनों पक्ष, सभी states और Production parity runtime verification बाकी।
- **🟠 Blocked / निर्भरता बाकी** — यात्रा के दौरान live location/ETA; permission-denied और stale-location states; arrival/cancel/close पर tracking बंद।
  - स्थिति/अगला काम: Live tracking/ETA का सुरक्षित end-to-end implementation प्रमाणित नहीं; privacy/retention policy और tests बाकी।
- **🟡 आंशिक / काम जारी** — Timer, completion approval और dispute/Admin review।
  - स्थिति/अगला काम: Server timer/completion migrations और source मौजूद; isolated DB/pgTAP/JWT/runtime verification बाकी।
- **🟡 आंशिक / काम जारी** — Bill, receipt, payment history, cancellation request/fee और पुराने dues अलग line items।
  - स्थिति/अगला काम: Labour-only bill snapshot/source work है; payment/refund/receipt/legacy reconciliation अभी अधूरा।
- **⚪ बाकी / पर्याप्त प्रमाण नहीं** — Help ticket, attachments, reference number, reply thread, status और history।
  - स्थिति/अगला काम: Electrician-specific/customer support backend, tickets, RLS और attachments अभी उपलब्ध/verified नहीं।
- **⚪ बाकी / पर्याप्त प्रमाण नहीं** — Ratings/reviews, notification preferences, saved addresses, profile/photo और account security।
  - स्थिति/अगला काम: Ratings, reviews, saved addresses/profile/photo/preferences का end-to-end implementation बाकी।
- **🟡 आंशिक / काम जारी** — Loading/empty/offline/error/retry states, accessibility, स्पष्ट हिंदी, responsive UI और low-bandwidth व्यवहार।
  - स्थिति/अगला काम: कुछ source/UI और regression work हुआ; complete error/offline/accessibility/responsive acceptance बाकी।

### Section 14.2 — इलेक्ट्रिशियन ऐप / पोर्टल

- **🟡 आंशिक / काम जारी** — OTP login, verified mobile, secure session/logout और account status।
  - स्थिति/अगला काम: Electrician OTP portal source है; role/session/expiry और वास्तविक device tests बाकी।
- **🟡 आंशिक / काम जारी** — Application, documents, experience, skills, service area, requested/approved category और unique digital ID।
  - स्थिति/अगला काम: Application/docs/skills/approval के कुछ flows हैं; unique ID, service area और lifecycle पूरी तरह verify नहीं।
- **🟡 आंशिक / काम जारी** — स्पष्ट navigation/dashboard: Home, New Booking Offers, My Bookings/Work, Earnings & Wallet, Profile/ID, Help & Support (अंतिम labels UI review में confirm)।
  - स्थिति/अगला काम: छह navigation sections मौजूद; हर menu के backend और functional acceptance पूरे नहीं।
- **🟡 आंशिक / काम जारी** — Offer details: काम, category, approximate location/distance, duration/estimate और expiry; acceptance से पहले privacy-safe सीमित जानकारी।
  - स्थिति/अगला काम: Offer details UI मौजूद; expiry, location minimization और full state coverage बाकी।
- **🟡 आंशिक / काम जारी** — Accept/decline/expiry, next eligible offer, single-winner assignment और simultaneous acceptance tests।
  - स्थिति/अगला काम: Accept/decline path मौजूद; expiry, single-winner concurrency और race tests बाकी।
- **🟡 आंशिक / काम जारी** — Accepted booking के दौरान ही customer phone का अनुमत access; public/unassigned context में नहीं।
  - स्थिति/अगला काम: Accepted booking contact gating में source fixes; all states/surfaces runtime privacy tests बाकी।
- **⚪ बाकी / पर्याप्त प्रमाण नहीं** — यात्रा/arrival status, location permission, ETA और tracking stop।
  - स्थिति/अगला काम: Travel/arrival/live location/ETA का complete implementation प्रमाणित नहीं।
- **🟡 आंशिक / काम जारी** — Work-start request, customer approval, server timer, completion request और dispute/Admin review।
  - स्थिति/अगला काम: Start approval, server timer और completion request source मौजूद; dispute/Admin round-trip runtime verification बाकी।
- **🟡 आंशिक / काम जारी** — Rate List में approved category की केवल net payable 8-hour reference amount; Platform Fee विवरण नहीं।
  - स्थिति/अगला काम: Rate-list/net payable presentation और category mapping का पूर्ण acceptance प्रमाणित नहीं।
- **🟡 आंशिक / काम जारी** — Actual minutes, gross labour, Platform Fee, wallet dues/adjustments और net payable अलग statement; materials labour में नहीं।
  - स्थिति/अगला काम: Earnings/wallet/fee summaries source मौजूद; ledger reconciliation और downloadable statements बाकी।
- **🟡 आंशिक / काम जारी** — Cash/Online eligibility, cash-cycle status, Platform Fee due और verified top-up history।
  - स्थिति/अगला काम: Cash/Online eligibility/fee due/top-up status के source elements हैं; full provider verified cycle बाकी।
- **⚪ बाकी / पर्याप्त प्रमाण नहीं** — Payout status, provider reference जहाँ उचित हो, failed/reversed payout और support path।
  - स्थिति/अगला काम: Payout status/reversal/support path और provider-confirmed lifecycle अधूरा।
- **⚪ बाकी / पर्याप्त प्रमाण नहीं** — Help tickets, customer ratings/reviews, electrician द्वारा customer rating और booking history।
  - स्थिति/अगला काम: Electrician support tickets और two-way ratings/reviews backend/UI अभी बाकी।
- **🟡 आंशिक / काम जारी** — Suspension/restriction, document re-verification और notification preferences।
  - स्थिति/अगला काम: Profile/ID/verification के कुछ controls हैं; suspension, re-verification और notification preferences अधूरे।

### Section 14.3 — एडमिन पैनल और कंपनी संचालन

- **🟡 आंशिक / काम जारी** — Main Admin secure login, MFA/strong authentication विकल्प, session list/revoke और recovery controls।
  - स्थिति/अगला काम: Admin login/allow-list मौजूद; MFA/session revoke/recovery और security acceptance बाकी।
- **🟡 आंशिक / काम जारी** — Customer/electrician/booking/address/PIN mismatch और verification management।
  - स्थिति/अगला काम: Admin booking/customer/electrician screens मौजूद; mismatch/PIN/verification full workflow अधूरा।
- **🟡 आंशिक / काम जारी** — Category/skill/document approval या rejection reason सहित।
  - स्थिति/अगला काम: Application/skill/category review के कुछ flows हैं; rejection reason/document audit पूरा नहीं।
- **🟡 आंशिक / काम जारी** — Offer queue, assignment, timeline, exceptions और duplicate/race protection visibility।
  - स्थिति/अगला काम: Offer queue/assignment/timeline के source elements हैं; race/exception visibility और runtime proof बाकी।
- **🟡 आंशिक / काम जारी** — Cancellation inbox, evidence, policy-based fee decision, reason, customer communication और dispute trail।
  - स्थिति/अगला काम: Cancellation Admin-mediated policy है; inbox/evidence/fee decision/dispute workflow पूर्ण नहीं।
- **🟡 आंशिक / काम जारी** — Timer/completion dispute review; Admin override reason, evidence और immutable audit।
  - स्थिति/अगला काम: Timer/completion Admin review source work है; mandatory reason/evidence/immutable audit runtime tests बाकी।
- **🟡 आंशिक / काम जारी** — Payment/provider events, refunds, wallet ledger, top-ups, cash dues, payout और reconciliation views।
  - स्थिति/अगला काम: Finance/wallet/payment screens/RPCs मौजूद; provider reconciliation/refund/dues complete नहीं।
- **🟡 आंशिक / काम जारी** — Support inbox, ticket assignment, replies, SLA/escalation और attachment access controls।
  - स्थिति/अगला काम: Admin support UI placeholder/limited; ticket inbox, assignment, replies, attachments और RLS बाकी।
- **⚪ बाकी / पर्याप्त प्रमाण नहीं** — Rating moderation with reason, audit and appeal path।
  - स्थिति/अगला काम: Rating moderation/reason/appeal workflow अभी पर्याप्त source evidence से नहीं मिला।
- **🟡 आंशिक / काम जारी** — Expense entry, receipt, permitted approval, accounting heads, exports और period reports।
  - स्थिति/अगला काम: Finance expense RPC/UI मौजूद; receipts, approval, accounting heads/exports पूर्ण नहीं।
- **⚪ बाकी / पर्याप्त प्रमाण नहीं** — Staff roles, granular permissions, least privilege और backend/RLS enforcement।
  - स्थिति/अगला काम: Granular staff roles/permissions backend और login controls उपलब्ध नहीं।
- **🟡 आंशिक / काम जारी** — Staff tasks, internal communication, login/activity history, suspicious-login handling और session revocation।
  - स्थिति/अगला काम: Staff tasks/internal communication/activity/session revocation अभी अधूरे।
- **🟡 आंशिक / काम जारी** — Dashboard metrics की स्पष्ट definitions, filters, drill-down और role-based exports।
  - स्थिति/अगला काम: Dashboard/finance metrics के कुछ views हैं; definitions, filters, drilldown और exports का पूरा प्रमाण नहीं।
- **🟡 आंशिक / काम जारी** — Emergency controls: confirmation, reason, audit, recovery safeguards और post-action reconciliation।
  - स्थिति/अगला काम: Emergency controls के लिए safeguards/audit/recovery flow पूरी तरह verify नहीं।
- **🟡 आंशिक / काम जारी** — सभी महत्वपूर्ण Admin/staff actions का actor, timestamp, before/after और reason audit।
  - स्थिति/अगला काम: Admin/staff action audit मौजूद आंशिक; हर critical action का before/after/reason coverage verify करना बाकी।

### Section 14.4 — पेमेंट, Razorpay, Wallet और Accounting

- **🟡 आंशिक / काम जारी** — Razorpay Test Mode integration और webhook signature verification; duplicate/out-of-order webhook idempotency।
  - स्थिति/अगला काम: Razorpay integration/webhook source मौजूद; complete Test Mode and signature/idempotency matrix बाकी।
- **🟡 आंशिक / काम जारी** — Order, payment, booking और provider transaction IDs का सुरक्षित linkage।
  - स्थिति/अगला काम: Order/payment/booking/provider linkage के fields/source हैं; all states and reconciliation tests बाकी।
- **🟡 आंशिक / काम जारी** — Created/pending/authorized/captured/failed/refunded/disputed जैसे payment states का स्पष्ट mapping।
  - स्थिति/अगला काम: Payment state fields exist; canonical state mapping and out-of-order transition proof incomplete।
- **🟡 आंशिक / काम जारी** — Online payment success केवल server-verified capture/signature के बाद।
  - स्थिति/अगला काम: Server-side verify/finalizer exists; race, webhook ordering and Test Mode verification pending।
- **🟡 आंशिक / काम जारी** — Cash confirmation, electrician cash collection acknowledgement और cash ledger reconciliation।
  - स्थिति/अगला काम: Cash acknowledgement/source exists; full cash ledger reconciliation and exception cases pending।
- **🟡 आंशिक / काम जारी** — Platform Fee 15% केवल labour पर; material/parts को fee base या electrician labour payout में शामिल नहीं करना।
  - स्थिति/अगला काम: 15% labour-only fee and separate material rules/source work exists; full accounting reconciliation pending।
- **🟡 आंशिक / काम जारी** — Wallet top-up केवल provider-verified; screenshot/manual claim से balance credit नहीं।
  - स्थिति/अगला काम: Wallet top-up/provider verification dependencies exist; full verified top-up cycle not proven۔
- **🟡 आंशिक / काम जारी** — Cash-cycle eligibility/reservation concurrency-safe; failed/expired/cancelled bookings का counter प्रभाव लिखित रूप से तय।
  - स्थिति/अगला काम: Cash-cycle/wallet/dues source and policy work exists; reservation concurrency and all outcomes not fully tested۔
- **⚪ बाकी / पर्याप्त प्रमाण नहीं** — Payout initiation, success/failure, retries, reversal और provider reference; Paid status केवल verified transfer पर।
  - स्थिति/अगला काम: Payout retries/reversal and provider-confirmed Paid state remain unverified/incomplete।
- **🟡 आंशिक / काम जारी** — Refund/partial refund/duplicate payment/chargeback/dispute और cancellation-fee reversal के स्पष्ट workflows।
  - स्थिति/अगला काम: Refund/cancellation/refund reversal RPCs and legacy quote dependencies remain; full lifecycle incomplete۔
- **🟡 आंशिक / काम जारी** — Gross labour, Platform Fee, cancellation fees, electrician payable, wallet liabilities, refunds, expenses और net profit अलग ledgers।
  - स्थिति/अगला काम: Separate ledgers for gross labour, fee, dues, refunds, expenses and profit are partially implemented; audit/reconciliation incomplete۔
- **🟡 आंशिक / काम जारी** — Daily settlement/reconciliation report और unmatched transaction exception queue।
  - स्थिति/अगला काम: Finance summary/expense reports exist; daily settlement and unmatched exception queue not proven complete।
- **🟠 Blocked / निर्भरता बाकी** — Live payments/transfers केवल अलग approval, provider readiness और production checklist के बाद।
  - स्थिति/अगला काम: Live payments/transfers are intentionally gated; explicit release approval and provider readiness remain.

### Section 14.5 — Notifications और Communication

- **🟡 आंशिक / काम जारी** — Push notification permission, token registration/rotation/revocation और logout/device lifecycle।
  - स्थिति/अगला काम: Push permission/subscription UI, service worker and deployed Edge Function source recovered; migration lineage and end-to-end device delivery remain.
- **🟡 आंशिक / काम जारी** — Booking created, offer/acceptance, electrician en route/arrival, start approval, timer/completion, payment/refund और cancellation updates।
  - स्थिति/अगला काम: Job-offer push trigger/function path exists in Production; branch migration source and delivery verification remain.
- **⚪ बाकी / पर्याप्त प्रमाण नहीं** — Help ticket received, Admin reply, status change और escalation notifications।
  - स्थिति/अगला काम: Help-ticket/Admin reply/status/escalation notifications not yet implemented/verified.
- **🟡 आंशिक / काम जारी** — Notification delivery failure, retry, deduplication और in-app notification inbox।
  - स्थिति/अगला काम: Push send/withdraw behavior and some webhook path exist; retry, deduplication and in-app inbox remain incomplete.
- **🟡 आंशिक / काम जारी** — SMS/OTP/push provider failure पर स्पष्ट fallback और user-facing status; secrets client में नहीं।
  - स्थिति/अगला काम: OTP/SMS/Push provider handling partly exists; failure fallback and user-facing coverage not complete.
- **⚪ बाकी / पर्याप्त प्रमाण नहीं** — Notification content में अनावश्यक personal data, पूरा पता या payment secrets नहीं।
  - स्थिति/अगला काम: Push payload source is minimal; privacy checks across every notification type remain.

### Section 14.6 — Security, Privacy और Data Governance

- **🟡 आंशिक / काम जारी** — सभी private tables/storage objects पर RLS और server-side authorization; role/ownership negative tests।
  - स्थिति/अगला काम: RLS/RPC audits and owner policies reviewed in several areas; every private table/storage object and negative test coverage remains.
- **🟡 आंशिक / काम जारी** — OTP abuse protection, rate limits, session expiry/revocation और brute-force safeguards।
  - स्थिति/अगला काम: OTP/Auth source and client cooldown exist; server rate limits, expiry/revocation and brute-force tests remain.
- **🟡 आंशिक / काम जारी** — Secrets केवल सुरक्षित server environment में; repository, client bundle और logs में secrets/PII नहीं।
  - स्थिति/अगला काम: Secret handling has been audited/fixed in selected code; full repo/client/log scan and rotation proof remain.
- **🟡 आंशिक / काम जारी** — Customer/electrician phone और location API/RPC स्तर पर least-privilege।
  - स्थिति/अगला काम: Phone privacy RPCs and status gates have source fixes; all role/state/location paths require tests.
- **⚪ बाकी / पर्याप्त प्रमाण नहीं** — Upload validation: file type/size, malware scanning जहाँ उपलब्ध, private storage और signed access।
  - स्थिति/अगला काम: Upload constraints/storage privacy partly reviewed; malware scanning/signed access full proof pending.
- **🟡 आंशिक / काम जारी** — Audit logs tamper-resistant; financial ledgers append-only/reversal-based।
  - स्थिति/अगला काम: Audit and ledger foundations exist; tamper resistance and append-only/reversal semantics not fully proven.
- **⚪ बाकी / पर्याप्त प्रमाण नहीं** — Data retention/deletion/export, consent, privacy notice और grievance contact policy लागू करने से पहले legal/privacy review।
  - स्थिति/अगला काम: Retention/deletion/export/consent/legal review not completed.
- **⚪ बाकी / पर्याप्त प्रमाण नहीं** — Location collection केवल approved booking purpose और अवधि तक; access audit और retention limit।
  - स्थिति/अगला काम: Location fields and limited access controls exist; retention/access audit/retention limit not complete.
- **⚪ बाकी / पर्याप्त प्रमाण नहीं** — Staff IP/device metadata का न्यूनतम संग्रह, सीमित access और निर्धारित retention।
  - स्थिति/अगला काम: Staff IP/device metadata policy and retention not implemented/verified.
- **⚪ बाकी / पर्याप्त प्रमाण नहीं** — Dependency/security scanning, vulnerable package review और incident response procedure।
  - स्थिति/अगला काम: Dependency scanning and incident response process not fully evidenced.

### Section 14.7 — Backup, Reliability और Recovery

- **⚪ बाकी / पर्याप्त प्रमाण नहीं** — Database backup schedule, retention और encryption की पुष्टि।
  - स्थिति/अगला काम: Backup schedule/retention/encryption not yet evidenced.
- **⚪ बाकी / पर्याप्त प्रमाण नहीं** — Restore drill: backup से अलग सुरक्षित environment में वास्तविक restore test और evidence।
  - स्थिति/अगला काम: Restore drill not performed.
- **⚪ बाकी / पर्याप्त प्रमाण नहीं** — Recovery Point Objective (RPO) और Recovery Time Objective (RTO) तय और दर्ज।
  - स्थिति/अगला काम: RPO/RTO not formally set and tested.
- **⚪ बाकी / पर्याप्त प्रमाण नहीं** — Provider outage, webhook delay, network failure और partial transaction recovery runbooks।
  - स्थिति/अगला काम: Provider/network/partial transaction recovery runbooks incomplete.
- **⚪ बाकी / पर्याप्त प्रमाण नहीं** — Monitoring/alerts: API errors, failed jobs, payment mismatch, queue backlog, suspicious access और service health।
  - स्थिति/अगला काम: Monitoring/alerts coverage not fully verified.
- **⚪ बाकी / पर्याप्त प्रमाण नहीं** — Emergency pause के बाद safe resume checklist और pending booking/payment reconciliation।
  - स्थिति/अगला काम: Emergency pause/resume and reconciliation runbook incomplete.

### Section 14.8 — QA, Accessibility और Release Sign-off

- **🟡 आंशिक / काम जारी** — Unit tests: pricing/minute calculation, fee split, cash-cycle, cancellation, wallet और permissions।
  - स्थिति/अगला काम: Unit/source tests added across billing, booking, OTP and portal; full execution/pass evidence incomplete.
- **🟡 आंशिक / काम जारी** — Integration tests: frontend/API/RPC/database/webhooks/storage/notifications।
  - स्थिति/अगला काम: Some API/RPC/schema integration tests exist; full integration run not verified.
- **🟡 आंशिक / काम जारी** — End-to-end tests: customer booking से electrician assignment, work timer, completion, payment, receipt और rating तक।
  - स्थिति/अगला काम: Full customer-to-rating end-to-end acceptance not executed.
- **🟡 आंशिक / काम जारी** — Negative/security tests: unauthorized access, phone/location leakage, RLS bypass, duplicate requests और race conditions।
  - स्थिति/अगला काम: Privacy/RLS/duplicate/race negative tests partly present; complete suite not executed.
- **🟡 आंशिक / काम जारी** — Payment Test Mode cases: success, failure, pending, duplicate webhook, refund, payout failure और reconciliation।
  - स्थिति/अगला काम: Payment Test Mode matrix not fully executed.
- **🟠 Blocked / निर्भरता बाकी** — Device/browser tests: Android के प्रमुख screen sizes, mobile browsers और desktop responsive layout।
  - स्थिति/अगला काम: Final consolidated Android/mobile/desktop manual QA is deliberately deferred until all other checklist tasks finish.
- **🟡 आंशिक / काम जारी** — Accessibility, readable Hindi, contrast, touch targets, keyboard navigation और clear error messages।
  - स्थिति/अगला काम: Accessibility/Hindi source work exists; full contrast/touch/keyboard checks pending.
- **⚪ बाकी / पर्याप्त प्रमाण नहीं** — Performance/load tests और slow/intermittent network tests।
  - स्थिति/अगला काम: Load/performance tests not evidenced.
- **⚪ बाकी / पर्याप्त प्रमाण नहीं** — Staging/UAT sign-off, known-issues list, rollback plan और production readiness checklist।
  - स्थिति/अगला काम: Staging/UAT sign-off and rollback plan not complete.
- **🟡 आंशिक / काम जारी** — सभी migrations reversible/forward-safe योजना के साथ; schema drift और existing data compatibility audit।
  - स्थिति/अगला काम: Migration/schema drift audit ongoing; historical source lineage and isolated execution remain.
- **🟠 Blocked / निर्भरता बाकी** — एक consolidated production deployment; अलग स्पष्ट अनुमति के बिना main merge, production DB migration, live payment या deploy नहीं।
  - स्थिति/अगला काम: Production release is intentionally blocked pending complete tests and separate approval.

### Section 16 — Public Website / Landing Page

- **🟡 आंशिक / काम जारी** — Public landing page पर केवल SRK ELECTRONIC का आधिकारिक लोगो, एक उच्च-गुणवत्ता वाली उपयुक्त मुख्य फोटो और उपलब्ध/वास्तविक panels के प्रवेश विकल्प दिखें।
  - स्थिति/अगला काम: Landing page source audit and updates touched; final logo/hero/panel acceptance not complete.
- **🟡 आंशिक / काम जारी** — Landing page पर केवल तीन login विकल्प हों: Customer Login, Electrician Login, और Admin Login।
  - स्थिति/अगला काम: Three login options are a known requirement; current landing/route wiring still needs full verification.
- **🟡 आंशिक / काम जारी** — कुल login प्रकार/भूमिकाएँ 3 (तीन) हैं; लोगो और फोटो login नहीं हैं। कोई चौथा login विकल्प न दिखाया जाए।
  - स्थिति/अगला काम: Three-role boundary is documented; fourth-route/role negative checks pending.
- **🟡 आंशिक / काम जारी** — हर login अपने अलग role-based सुरक्षित authentication और सही dashboard/panel पर जाए; URL बदलकर दूसरे role का access न मिले।
  - स्थिति/अगला काम: Role-specific route/auth source exists; direct URL/wrong-role negative tests remain.
- **🟡 आंशिक / काम जारी** — Public landing page पर अनावश्यक अतिरिक्त menus, dashboards, internal details या staff-only panels न दिखें।
  - स्थिति/अगला काम: Public/internal navigation cleanup not fully accepted.
- **🟡 आंशिक / काम जारी** — Admin के अंदर staff/sub-admin permissions हो सकती हैं, लेकिन public landing page पर अलग चौथा login विकल्प नहीं बनेगा; authorized staff access का तरीका Admin policy के अनुसार रहेगा।
  - स्थिति/अगला काम: Staff access stays within Admin; staff role/permission workflow incomplete.
- **⚪ बाकी / पर्याप्त प्रमाण नहीं** — Mobile और desktop पर साफ़, professional, fast-loading और accessible layout; logo/photo optimized हों।
  - स्थिति/अगला काम: Final responsive, performance and accessibility checks deferred to consolidated QA.

## 4. अभी तक के महत्वपूर्ण implementation / audit प्रमाण

- **Customer OTP/Login:** source-level OTP send/verify, cooldown/duplicate-action checks, session/logout guards और GitHub Actions का user-shared successful run evidence दर्ज है। वास्तविक OTP expiry, server-side abuse controls, Auth policy/session lifecycle और वास्तविक browser/device E2E अभी अधूरे हैं। Master checklist 14.1.1 को पूर्ण project acceptance नहीं माना गया।
- **Customer menu / booking:** पाँच menu sections मौजूद हैं, पर Payments/Support/Profile के secure data contracts और labour-only payment dependency के कारण full activation अधूरा है। Booking form में verified phone को read-only करने का सीमित source fix हुआ; PIN authority, category/duration और बाकी booking acceptance pending है।
- **Booking timeline / timer / billing:** Customer timeline RPC/UI, server-authoritative timer और immutable bill snapshot/completion-review migration source files जोड़े गए हैं। pgTAP/isolated DB/JWT runtime execution प्रमाणित नहीं है; Production पर migrations लागू नहीं की गईं।
- **Contact privacy:** electrician/customer contact fields पर allowed booking status gates के source fixes और regression assertions जोड़े गए। Production RPC parity, completed/cancelled/unassigned/other-owner negative tests अभी बाकी हैं।
- **Electrician portal:** छह menu sections और application/document/offer/wallet/profile flows के source मौजूद हैं; support backend, ratings, expiry/race tests, payout statement और final device QA बाकी हैं।
- **Notifications:** Electrician Home में device Push controls, root service worker push/click/withdraw handlers, Production Push Edge Function version 4 का source recovery और public-key readiness integration branch में है। चार Production-applied push migration SQL files branch में recover नहीं हुईं; browser/device push delivery runtime test नहीं हुआ। UI/worker को fully working push service न मानें।
- **Admin/Finance:** Admin dashboard, application/booking/finance/expense RPC/UI और wallet/fee views के कुछ source/backend हिस्से मौजूद हैं। Staff RBAC, support inbox, receipt/expense proof, mandatory reason/before-after audit, complete reconciliation, MFA/session controls और final verification बाकी हैं।
- **Migration lineage:** Production में applied migrations और feature-branch SQL files में महत्वपूर्ण drift है। Missing historical migrations को guess करके recreate/apply नहीं करना है; source history recover और isolated verification आवश्यक है।
- **Backup/Recovery:** backup schedule, restore drill, RPO/RTO और recovery runbooks का verified evidence अभी नहीं है।

## 5. इस समय खुले मुख्य blockers

1. **Auth/OTP:** server-side OTP expiry, resend/wrong-attempt throttles, session revocation और approved runtime test evidence।
2. **Customer booking:** authoritative PIN/district source; category/rate/duration semantics; submit idempotency/fee disclosure।
3. **Payment dependency:** पुराने quote-based order/verify/refund flows को labour-only billing, materials separation और immutable bill snapshot के साथ backward-safe reconcile करना।
4. **Contact privacy:** Production function behavior और Feature Branch allow-lists का सुरक्षित parity verification।
5. **Electrician Push:** चार applied migration SQL files और webhook trigger source lineage; VAPID readiness + actual push delivery tests।
6. **Admin/Staff:** granular staff RBAC, secure support inbox, audit reason/before-after, MFA/session recovery।
7. **Support/Ratings:** customer/electrician tickets, attachments, RLS, replies/escalation और two-way ratings/reviews।
8. **Migration drift:** Production migration history vs branch migration source; कोई blind replay/reset/squash नहीं।
9. **QA/Recovery:** pgTAP/integration/JWT/E2E, backup/restore/RPO/RTO, performance/accessibility और final consolidated mobile/Desktop QA।

## 6. अगला काम — Master checklist क्रम बनाए रखना

1. Customer checklist के पहले से inspect किए गए points 14.1.1–14.1.9 की status/evidence reconcile करके अगला क्रमबद्ध point **14.1.10 — Timer, completion approval और dispute/Admin review** पर internal verification जारी रखें। Source migrations मौजूद हैं, लेकिन isolated DB/pgTAP/JWT runtime evidence अभी नहीं है।
2. फिर 14.1.11 bill/receipt/payment history/cancellation/dues; उसके बाद 14.1.12 Support; 14.1.13 profile/ratings/notifications; 14.1.14 cross-cutting responsive/error/accessibility।
3. इसके बाद Electrician (14.2), Admin (14.3), Payment (14.4), Notifications (14.5), Security (14.6), Backup/Recovery (14.7), QA/Release (14.8), और Public Website (16) को मूल क्रम में पूरा करें।
4. हर मूल बिंदु पर: existing audit → code/backend/RLS/RPC review → implementation/fix → unit/integration/security tests → commit → re-fetch verification → tracker update।
5. सभी मूल tasks internal-verified होने के बाद ही **एक consolidated manual mobile/Desktop QA pass** करें। बीच में अलग-अलग device QA नहीं।
6. Production deploy, Main merge, Production DB/Auth/Vault/Edge Function settings, live payment/transfer या live data changes के लिए अलग स्पष्ट approval अनिवार्य है।

## 7. काम जारी रखने के स्थायी नियम

- केवल `feature/platform-fee-cash-online-cycle` branch पर काम।
- Master Requirements मूल numbering और order सुरक्षित।
- UI दिखने भर से Complete नहीं; backend authorization/RLS/RPC और tests भी verify।
- Production SQL केवल read-only introspection; Production migration/apply नहीं।
- नया hosted Supabase QA branch नहीं बनाना; अतिरिक्त खर्च से बचना।
- Payment, payout, refund, live customer data या production settings बिना अलग approval न बदलें।
- Manual mobile/Desktop QA केवल सभी internal tasks के बाद एक consolidated pass में।
- User ने स्पष्ट कहा है: **कोई schedule/reminder/automation नहीं; काम तत्काल करना है।**
- किसी feature/test के चलाए बिना “pass” नहीं लिखना; test लिखा होना और test pass होना अलग-अलग दर्ज करना।

## 8. Latest saved work / resume reference

- Feature branch: `feature/platform-fee-cash-online-cycle`
- Latest known progress-related commit before this tracker: `2755f72c8e6b8fed2250eaae31902b5f3c41dc49` (Master Requirements Section 17.133 update)। उसके बाद का tracker commit इस file के GitHub commit में दर्ज होगा।
- Recent notification source commits: `415d1c41087b3825dbd9d7f89f76acf1583a1cee`, `b1ee69d8cda3bc31090ddc0907679d97e68ea530`, `2a9e55292ba53cdeccb016b4f7b56e7135bc4d88`, `02c519cc770153e06b43426c8ef8c4deeaca095c`।
- Master Requirements Sections 17.129–17.133 में Electrician audit, location picker, application status, Push UI audit और deployed Push Edge Function source recovery का विस्तृत history है।
- **Next resume point:** Customer 14.1.10 — server timer / completion / dispute/Admin review का internal DB/JWT/pgTAP verification; उसके बाद 14.1.11।
- **Tracker maintenance:** हर आगे के verified change के बाद इस file में counts, item statuses, evidence/commit और next resume point अपडेट करें।

## 20. Customer App — 14.1.10 Timer / Completion / Dispute — कार्य लॉग (13 नवम्बर 2026)

**क्रमवार Customer App कार्य शुरू; वर्तमान उप-कार्य: 14.1.10। अभी Audit/Source Review चरण है — इसे Complete नहीं माना गया है।**

### इस pass में किए गए वास्तविक read-only checks
- Feature branch में संबंधित source migrations मिलीं:
  - `20261114010000_customer_booking_category_and_duration.sql`
  - `20261114040000_server_authoritative_labour_timer_and_bill_snapshot.sql`
  - `20261114060000_work_completion_admin_review_and_immutable_event_history.sql`
- Feature branch में pgTAP database tests मौजूद:
  - `server_authoritative_labour_timer_and_bill_snapshot.test.sql` — घोषित plan 101 assertions।
  - `work_completion_admin_review_and_immutable_event_history.test.sql` — घोषित plan 22 assertions।
  - `customer_booking_category_duration.test.sql` — घोषित plan 14 assertions।
- Static source review में नए categorized bookings के लिए customer-approved server timer start, electrician completion request पर server timestamp से timer freeze, partial minute को अगले minute तक ceil, integer-paise half-up calculation, customer approve/reject/dispute branches, immutable final bill snapshot और Admin reason/evidence event trail के source paths मिले।
- Timer storage migration `work_timer_seconds` को bigint करती है और exact elapsed seconds अलग numeric field में रखती है; reviewed source में पुराना 7-day cap हटाने का प्रयास है।
- Legacy NULL-category bookings के लिए पुराना quote-first workflow अलग रखने का compatibility path source में मौजूद है।
- Feature branch source में final bill को सीधे client table access से रोकने, private transaction authorization और trigger-based amount recomputation के controls लिखे गए हैं। इनका database execution/role-JWT व्यवहार अभी प्रमाणित नहीं।

### Production की read-only स्थिति जाँच
- Production migration history में ऊपर की तीन नई migration versions नहीं मिलीं।
- Production `service_bookings.work_timer_seconds` अभी `integer` है; नई `selected_category`, `selected_duration_hours`, `work_timer_elapsed_seconds` और rate snapshot columns इस introspection result में मौजूद नहीं मिले।
- Production में पुरानी `srk_electrician_request_work_completion(uuid)` और `srk_customer_respond_work_completion(uuid,text,text)` RPCs मौजूद हैं; नई bill snapshot / Admin review RPCs इस query result में नहीं मिलीं।
- कोई Production migration, schema change, live booking या payment action नहीं किया गया।

### अभी बाकी — 14.1.10 को पूरा मानने से पहले
1. तीनों migrations का पूरा dependency/order review और live Production schema से column/constraint/function/trigger/RLS parity mapping।
2. Customer start approval, electrician start/completion permissions, customer approval/rejection/dispute और Admin review के सभी transition paths की line-by-line review।
3. Completion rejection के बाद timer resume; dispute के बाद timer paused; repeated/parallel RPC calls; idempotency और booking row-lock race tests।
4. Final bill trigger/authorization, immutable snapshot, customer-only/electrician-only/Admin-only bill reads और cross-booking IDOR negative tests।
5. Payment/cash/Razorpay/refund/payout consumers का final bill snapshot से सुरक्षित rebind और duplicate financial posting रोकने की पुष्टि।
6. pgTAP तथा isolated DB/JWT integration tests चलाना। इस pass में कोई pgTAP या runtime test execute नहीं हुआ; सभी tests **Not Run** हैं।
7. संबंधित UI handlers तथा server RPC response shape का Customer App के साथ end-to-end मिलान; अंतिम device QA बाद के consolidated pass में ही होगा।

**अगला resume point:** 14.1.10 का विस्तृत transition/security review — विशेषकर completion approve/reject/dispute और Admin resolution RPCs, bill trigger तथा payment-consumer dependencies। इसके बाद isolated test execution की उपलब्धता जाँची जाएगी। Production में apply/deploy नहीं करना है।

**स्थिति snapshot नियम:** इस audit से checklist counts नहीं बदले। Section 14.1.10 अभी 🟡 आंशिक / काम जारी है; verified complete नहीं।

### 14.1.10 — दूसरा review pass: transition, audit trail और payment consumers (13 नवम्बर 2026)

**इस pass में केवल Feature Branch source का read-only static review किया; Production में कोई बदलाव नहीं।**

#### Transition / Security review में source से पुष्ट बिंदु
- Completion rejection: पुराने elapsed seconds सुरक्षित रहते हैं; `completion_requested_at` साफ करके `work_started_at=clock_timestamp()` और `work_timer_running=true` किया जाता है, अर्थात Timer server clock से resume होता है।
- Customer dispute: complaint record बनता है; completion status `disputed` होता है; timer बंद रहता है और stopped elapsed time सुरक्षित रहता है।
- Admin resolution: केवल `is_srk_admin()`-authorized RPC; booking row `FOR UPDATE`; कारण 20–1000 characters; पहले immutable bill snapshot insert, फिर booking completed; एक trigger-generated event में reason/financial details transaction-scoped private authorization से दर्ज।
- Bill table में `booking_id` PRIMARY KEY है (एक booking पर अधिकतम एक final bill); RLS enabled, client table privileges revoked; trigger UPDATE/DELETE रोकता है और INSERT पर booking ownership, stopped timer, completion timestamp, approved rate snapshot तथा paise calculations पुनः जाँचता है।
- Customer/Electrician/Admin bill reads अलग role-scoped RPCs के माध्यम से हैं; Admin work-event history RPC में Admin authorization जाँची जाती है।
- Payment consumers की static source review में नए categorized flow के लिए cash confirmation, Admin manual payment, payout ledger, Razorpay refund और payout reconciliation final bill amount/approved completion से जोड़ने वाले guards मिले। Cash receipt labour-only है; material amount नए category flow में payout calculation में शून्य रखा गया है।
- Cash/online ledger postings के लिए booking-आधारित idempotency keys मौजूद हैं; duplicate payment entry मिलने पर manual reconciliation error path है।

#### Release से पहले अभी भी आवश्यक सत्यापन
1. ऊपर के सभी निष्कर्ष source-text review हैं, database execution नहीं। pgTAP और role/JWT runtime assertions अभी Not Run हैं।
2. Parallel/repeated completion calls, दो simultaneous customer decisions, duplicate payment webhook, retry और payout/refund race को isolated DB में चलाकर साबित करना बाकी है। PK/idempotency key source में मौजूद होना runtime race proof नहीं है।
3. Bill read RPCs में customer/electrician/Admin identity mismatch तथा दूसरे booking ID से access के negative tests चलाने बाकी हैं।
4. New migrations के filenames `20261114...` हैं जबकि इस audit की तारीख 2026-11-13 है। Apply/deploy से पहले migration ordering/timestamp policy और पूरी pending migration chain की पुष्टि करनी होगी; अभी timestamps नहीं बदले।
5. पूरा dependency audit अभी शेष है: payment webhook handler/Razorpay verification call chain, refund request/execute chain, cash fee settlement और payout settlement के सभी callers को इस final bill snapshot के साथ end-to-end reconcile करना है।

**इस pass में code/migration apply या कोई test execute नहीं किया।** Checklist counts नहीं बदले; 14.1.10 अभी 🟡 आंशिक / काम जारी है। अगला resume point: payment/refund/payout call-chain और RPC privilege/IDOR test coverage का पूरा dependency review, फिर isolated execution की उपलब्धता जाँचना।


## 14.1.10 — Payment / Refund / Payout dependency audit (13 नवम्बर 2026)

**Audit scope:** Feature branch source review only; कोई Production write, payment, refund, payout या deployment नहीं किया गया। इस audit में Razorpay order creation, customer payment verification, webhook, labour bill amount lookup, cash Platform Fee due, online fee settlement, refund reversal और Admin payout confirmation के source paths देखे।

### Source से मिले सकारात्मक नियंत्रण (static review; runtime प्रमाण नहीं)
- `create-order.js`: Bearer session को Supabase Auth से validate करता है; booking customer ID और verified phone match करता है; केवल Razorpay Online method, completed booking और approved final bill/legacy approved quote पर order बनाता है। New categorized flow में amount labour bill snapshot के integer paise से आता है; materials शामिल नहीं।
- `verify-payment.js`: Razorpay order/payment ID format और HMAC signature validate करता है; Razorpay API से payment status=captured, order ID, INR currency और exact expected amount मिलाता है; booking payment update order ID और unpaid status से conditional है; same payment retry को idempotent success देता है।
- `razorpay-webhook.js`: raw request body पर Razorpay webhook HMAC signature verify करता है; केवल payment.captured/order.paid process करता है; captured status, INR और expected amount जाँचता है; same payment replay पर already-processed path है।
- New-flow bill lookup RPC service_role-only है; customer/electrician bill RPC owner-scoped हैं। Labour bill snapshot payment path में customer-approved completion आवश्यक है।
- Cash fee ledger में per-electrician advisory transaction lock और unique idempotency keys हैं। Cash booking पर fee due बनती है; बाद की online booking में current fee पहले reserve होती है और पुराने dues केवल labour/service share से settle होते हैं (materials share से नहीं)।
- Refund trigger path paid electrician payout पर refund रोकता है; pooled cash due बाद में settle हो चुका हो तो cash refund को Admin reconciliation तक रोकता है; fee reversals/restores idempotent ledger entries हैं।
- Admin payout confirmation Admin authorization, row locks, pending-only status और booking/payment/payout reconciliation checks मांगता है।
- Customer refund-history RPC authenticated customer के अपने records तक सीमित है और Admin notes/staff identity expose नहीं करता; payment receipt RPC verified paid booking के customer owner तक सीमित है।

### मिले हुए खुले जोखिम / blockers
1. **Order creation race:** `create-order.js` Razorpay order link करते समय booking PATCH केवल booking ID पर करता है और `payment_status='pending'` लिखता है; update filter में current payment status, payment method, completion state और lock token नहीं हैं। Concurrent webhook/payment confirmation के बीच stale order-link write की race को isolated concurrency test से prove/fix करना होगा।
2. **Webhook final-state race:** webhook पहले booking state/amount पढ़ता है, फिर PATCH में केवल booking ID + order ID + payment_status != paid लगाता है। PATCH predicate में payment method, completed status और final-bill approval/amount snapshot state दोबारा enforce नहीं हैं। बीच में booking state बदलने की race के लिए atomic DB RPC/conditional update और test आवश्यक है।
3. **Webhook unmatched-event handling:** not_found, amount_mismatch, payment_conflict, booking_not_payable और cash_booking पर webhook 200 लौटाता है। यह retry रोकता है; mismatch को durable reconciliation/alert queue में दर्ज करने का proof अभी नहीं है।
4. **Refund execution gap:** inspected customer refund migration केवल customer-owned refund request history RPC देती है। Razorpay refund API execution, provider refund ID/status reconciliation, partial refund handling और refund webhook/event idempotency का पूर्ण end-to-end caller path इस pass में स्थापित नहीं हुआ। इसे verified नहीं मानें।
5. **Payout scope:** inspected Admin RPC manual UPI/bank reference के आधार पर pending payout को paid mark करती है। Razorpay Route transfer ledger server-only है और schema comment के अनुसार DB writes स्वयं money movement नहीं करते; live transfer execution, provider status polling/webhook, reversal/partial reversal और reconciliation अभी सिद्ध नहीं।
6. **Legacy vs new flow:** legacy quote path approved service + materials total charge कर सकता है; new categorized labour-only flow अलग bill snapshot से चलता है। दोनों के बीच no-cross-contamination और legacy data migration tests जरूरी हैं।
7. **Security/runtime tests:** SQL test files में कई static function-definition/privilege assertions हैं, पर इस audit में pgTAP execute नहीं हुआ। वास्तविक JWT identity swap/IDOR, wrong customer booking ID, fake/mismatched Razorpay order/payment, amount tampering, webhook signature failure/replay, duplicate/concurrent callbacks, cash-vs-online race, refund-after-settlement और payout double-submit tests अभी Not Run हैं।

### Verification status
- Source review: **पूरा इस सीमित audit scope में**।
- Database pgTAP / isolated concurrency / provider sandbox tests: **Not Run**।
- Production migration application: **नहीं की गई**; कोई Production schema/data/payment state नहीं बदली।
- 14.1.10: **🟡 Partial / In Progress ही रहेगा**। Payment/refund/payout chain को verified complete नहीं माना जा सकता।

**अगला Customer App कार्य:** ऊपर के order/webhook race paths और refund/payout execution dependencies को migration/RPC तथा test suite में trace करना; पहले isolated test environment उपलब्धता/branch policy स्पष्ट किए बिना Production पर प्रयोग नहीं करना।


## 14.1.10 — Razorpay order/payment race hardening (13 नवम्बर 2026, follow-up)

पिछले audit में मिली order-link और payment-finalization race पर Feature Branch में source changes किए गए:

### जो बदलाव किए गए
- नया migration `20261114090000_atomic_razorpay_order_and_payment_finalization.sql`:
  - Private expiring payment-order lock table और service-role-only claim/release RPC।
  - Order link करने से पहले booking row lock, lock-token validation, current payment choice/status/completion approval और exact approved amount recheck।
  - Captured payment finalizer में booking row `FOR UPDATE`, exact linked order ID, provider payment ID format, INR currency, current online payment choice, completed/approved state और final bill/legacy quote amount recheck।
  - एक ही payment ID की retry idempotent; अलग payment ID पर conflict।
  - RPC execution केवल `service_role`; client roles को execute permission नहीं।
- `create-order.js`: हर order request पहले lock claim करती है; latest booking फिर से पढ़ती है; stale/changed state पर order link नहीं करती। Existing Razorpay order paid/attempted हो या राशि mismatch हो तो नया order बनाने के बजाय Admin reconciliation पर रोकती है।
- `verify-payment.js` और `razorpay-webhook.js`: direct service-bookings PATCH हटाकर एक ही atomic finalizer RPC call करते हैं। Webhook mismatch/unmatched payment पर अब 200 acknowledgement नहीं देता; retry/error path देता है।
- Payment handler regression tests में lock contention, order-link amount, atomic finalizer args, stale-state rejection और webhook finalizer assertions जोड़े।
- Supabase schema CI workflow में गलत cash-fee migration filename ठीक किया, नया atomic-payment migration apply list में जोड़ा और तीन RPC smoke checks जोड़े।

### उपलब्ध test प्रमाण
- GitHub Actions source regression workflow commit `ae9760e594afc40aac50748ba98fa899697eb64d` पर **Success** हुआ; workflow के सभी source regression suites सफल रहे, जिसमें `test:payments` भी शामिल है।
- पुराने intermediate commits पर payment test mock अपडेट होने से पहले failures आए थे; updated test suite के successful run को ऊपर दर्ज किया गया है।
- New SQL migration और 26 assertions वाले pgTAP test file को अभी isolated Supabase database पर execute नहीं किया गया। Supabase schema CI workflow भी अभी run नहीं हुआ।
- वास्तविक Razorpay sandbox, webhook replay/concurrency, दो parallel order requests, JWT/IDOR और provider retry behavior अभी **Not Run** हैं।

### Refund और payout audit — शेष स्थिति
- Netlify functions directory में payment order, verification और webhook handlers मिले; Razorpay refund API execution handler नहीं मिला।
- Customer refund migration में केवल authenticated customer की अपनी refund-request history पढ़ने वाला RPC है; refund request create/approve/execute, provider refund ID/status, partial refund और refund webhook reconciliation का पूर्ण रास्ता अभी प्रमाणित नहीं।
- वर्तमान Admin payout UI UPI/Bank transfer को Admin द्वारा वास्तव में बाहर transfer करने के बाद UTR/reference दर्ज करती है। Automatic Razorpay Route transfer को current flow नहीं माना गया; DB ledger अपने-आप पैसा transfer नहीं करता।
- Payout double-submit और refund-after-payout/settled-cash-due के लिए isolated tests अभी बाकी हैं।

### Verification status
- Order/payment source race guards: **Feature Branch में implemented; source regression CI passed**।
- Atomic SQL migration/pgTAP/runtime concurrency: **Not Run — अभी verified complete नहीं**।
- Refund execution/reconciliation: **Blocked / not implemented or not evidenced**।
- Manual Admin payout ledger: source मौजूद; वास्तविक bank transfer external/manual है; sandbox/live reconciliation **Not Run**।
- Production schema/data, payment, refund, payout या deployment: **कोई बदलाव नहीं**।
- Customer App checklist 14.1.10: **🟡 Partial / In Progress**; 96-point tracker counts नहीं बदले।

**अगला Customer App कार्य:** सुरक्षित isolated schema CI में नया migration और pgTAP चलाना; उसके बाद refund request → Admin decision → provider refund/manual reconciliation path का पूर्ण audit/implementation। Production पर कोई apply या live money movement नहीं।


## 14.1.10 — Refund workflow: Customer UI और Production RPC parity audit (13 नवम्बर 2026)

**Scope:** Feature Branch source और Production Supabase पर केवल read-only SQL introspection। किसी table/data/function को बदला नहीं; कोई refund, payment या payout execute नहीं किया।

### Feature Branch source में मिला
- `booking.html` में Customer refund form मौजूद है। यह `srk_customer_create_booking_refund_request(uuid,text)` RPC call करता है; कारण 20–1000 अक्षर और button-disable guard UI में हैं।
- Customer page `srk_customer_list_my_booking_refund_requests()` को call करता है और उसी RPC का migration `20261113235900_harden_customer_cancellation_and_safe_refund_history.sql` में मौजूद है।
- उस migration में केवल authenticated customer की अपनी refund-history SELECT RPC परिभाषित है। **Create-request RPC की branch migration definition इस inspected migration में नहीं मिली**, जबकि UI उसे call करती है। अतः branch migration chain से इस RPC की reproducible definition अभी प्रमाणित नहीं।
- Admin panel `admin.html` में Finance/Payouts और Support sections हैं, लेकिन refund request queue / decision / refund execution UI इस source review में नहीं मिला।
- Customer history migration के लिए pgTAP file 5 static assertions रखती है; tests execute नहीं हुए।

### Production Supabase — read-only introspection से मिला
- Production में refund-related tables मौजूद हैं: `srk_booking_refund_requests`, `srk_manual_refund_entries`, `srk_razorpay_refunds`; इनके columns में request status/admin decision, provider refund ID/status, amount in paise, idempotency key, error और timestamps के fields हैं।
- Production में Admin decision/list/prepare/manual-finalize, Customer create/list, service reconciliation तथा audit-trigger functions मौजूद हैं। इसलिए पिछली tracker wording “refund implementation नहीं मिला” को refine करना जरूरी है: **Production DB में काफी refund workflow मौजूद है, लेकिन Feature Branch migration/UI और new billing model के साथ parity अभी सिद्ध नहीं।**
- `srk_admin_prepare_booking_refund(uuid)` का inspected Production function Razorpay-paid booking को तभी आगे बढ़ाता है जब `quote_status='approved'`, `quoted_amount` = `amount_paid` और `service_charge + materials_amount` = `amount_paid` हों। यह नया categorized labour-only final-bill flow नहीं है; उस flow में final approved labour bill snapshot को reconcile करने वाला path अभी प्रमाणित नहीं। Function timer/non-quote refund को स्पष्ट रूप से अलग reconciliation पर रोकता है।
- उसी prepare function में payout row lock होती है; पहले से paid electrician payout पर refund रोककर Admin reconciliation मांगता है; pending/blocked payout को refund processing के दौरान block करता है।
- `srk_service_reconcile_booking_refund(...)` provider status को pending/processed/failed में map करता है; processed होने पर request processed और booking payment_status refunded करता है। इसकी provider caller/webhook delivery, signature validation, retry और duplicate/out-of-order event chain इस audit में अभी प्रमाणित नहीं।
- Manual refund RPC Razorpay-linked payment को मना करती है, manual payment audit entry और exact amount match मांगती है, duplicate manual refund और already-paid electrician payout रोकती है।

### अगला implementation gate — अभी कोई code change नहीं
1. Production refund RPCs की पूरी function definition, EXECUTE grants, triggers, constraints और idempotency uniqueness का read-only audit पूरा करना।
2. Feature Branch में Production की सुरक्षित existing refund contract को migration history में reproduce/align करना; branch में मौजूद `srk_customer_create_booking_refund_request` UI call और migration gap को ठीक करना।
3. New categorized booking refund को immutable final labour bill / exact captured payment amount से जोड़ना; materials को refund amount में स्वतः शामिल न करना।
4. Admin refund queue/decision UI तथा Razorpay provider execution handler, webhook/poll reconciliation और retry-safe idempotency का call-chain audit/implementation।
5. Partial refund, duplicate submit, concurrent Admin decisions, refund-after-payout, cash-fee-settled, provider pending/failed/unknown, replay/out-of-order callbacks और cross-customer IDOR के isolated tests जोड़ना/चलाना।

**Verification:** Production queries केवल SELECT/catalog introspection थीं। Existing TEST project की जाँच में केवल push-test schema मिला; उसे refund tests के लिए इस्तेमाल नहीं किया और कोई QA branch/project नहीं बनाया। कोई SQL migration/pgTAP/runtime/provider test execute नहीं हुआ। कोई Production write, payment, refund, payout या deployment नहीं हुआ। Checklist counts नहीं बदले; Customer App 14.1.10 अभी 🟡 Partial / In Progress है।

**Resume point:** Production refund RPC privileges/triggers/constraints और provider refund caller का पूरा audit; उसके बाद branch migration + new labour-bill-compatible refund path।


### Refund audit — अतिरिक्त Production privilege / uniqueness checks (13 नवम्बर 2026)
- Production catalog ACL introspection में customer create/list refund RPCs और Admin decision/list/prepare/finalize RPCs पर `authenticated` EXECUTE grant दिखा; Admin functions के body में `auth.uid()` + `is_srk_admin()` gate मौजूद है। Service reconciliation और audit-trigger functions service_role-only हैं। यह ACL/catalog evidence है, JWT negative runtime test नहीं।
- Unique indexes मिले: refund request पर booking_id और refund_record_id; Razorpay refund पर booking_id, idempotency_key और provider refund_id; manual refund पर booking_id और payment_entry_id। ये duplicate रोकने के database safeguards हैं, लेकिन concurrent execution का runtime proof नहीं।
- Production में Customer list RPC का नाम `srk_customer_list_booking_refund_requests()` मिला; Feature Branch UI/migration `srk_customer_list_my_booking_refund_requests()` नाम call/define करती है। दोनों environments की RPC naming parity अभी confirm नहीं; Production में branch वाला exact RPC catalog query में नहीं मिला।
- Production refund queue/list और decision/prepare RPCs होने के बावजूद inspected `admin.html` में refund queue UI नहीं मिला। Provider refund execution caller भी अभी locate/verify नहीं हुआ।

**Next exact focus:** Production customer refund RPC grants/row ownership, Admin prepare + provider execution caller, service reconcile caller and refund audit trigger की end-to-end mapping; फिर branch में exact function-name parity और labour-only refund support।


### Refund audit — Production RLS, grants और provider surface (13 नवम्बर 2026)
- तीनों Production refund tables पर RLS enabled मिला; catalog query में इन tables के लिए कोई direct RLS policy row नहीं मिली। information_schema.role_table_grants में direct table grants केवल postgres और service_role को दिखे; anon/authenticated को direct table grants नहीं मिले। यह अच्छा least-privilege संकेत है; role/JWT runtime bypass test अभी बाकी।
- Production में refund tables के audit triggers मौजूद हैं: manual refund entry पर सामान्य Admin audit trigger और Razorpay refund table पर dedicated before/after audit event trigger। Request table के लिए अलग trigger इस catalog result में नहीं दिखा।
- Production Supabase Edge Functions list में केवल send-sms-2factor और push-job-offer मिले; refund provider executor Edge Function नहीं मिला। Feature Branch compare में भी कोई refund Netlify Function file नहीं दिखी। इसलिए srk_service_reconcile_booking_refund का actual trusted provider caller अभी missing/unlocated है।
- Production schema में refund request, provider refund, manual refund की uniqueness/index guards हैं; लेकिन provider API call, provider callback signature validation, polling/retry, and event replay chain के बिना इन्हें end-to-end refund execution का प्रमाण नहीं माना जाएगा।

**Status update:** RLS/table grant/unique index/audit-trigger catalog review पूरा; provider execution caller और labour-only refund compatibility अभी unresolved। कोई database write/test/provider call नहीं हुआ।


### Refund implementation gate — migration reproducibility check (13 नवम्बर 2026)
- Feature Branch की पूरी `supabase/migrations/` filename सूची जाँची। उसमें refund request / Razorpay refund / manual refund tables बनाने वाली कोई migration नहीं मिली। Existing refund-history migration इन tables को पहले से मौजूद मानकर RPC बनाती है। इसलिए fresh isolated Supabase पर migration chain अकेले इन refund RPCs को reproducibly तैयार नहीं कर सकती; Production में manually/पूर्व setup से बने tables को migration evidence नहीं मान सकते।
- Feature Branch customer UI refund submit पर `srk_customer_create_booking_refund_request(uuid,text)` call करता है, लेकिन Branch migration chain में इस function की definition नहीं मिली। History UI `srk_customer_list_my_booking_refund_requests()` call करती है; Production में समान उद्देश्य वाला अलग नाम `srk_customer_list_booking_refund_requests()` मिला।
- Production customer-create RPC inspected definition पुराने `amount_paid` पर request amount तय करती है। इसे सीधे copy करना सही नहीं: नए categorized booking में immutable `srk_booking_labour_bills.labour_amount_paise` और captured online amount का exact reconciliation चाहिए; materials अलग हैं और refund amount में स्वतः नहीं जुड़ने चाहिए।
- Production Admin prepare RPC भी `quote_status='approved'`, `quoted_amount`, `service_charge + materials_amount` matching पर निर्भर है; इसलिए नए labour-only final bill flow को process करने के लिए इसे अलग सुरक्षित migration में बदलना होगा।
- इस gate पर जानबूझकर कोई partial RPC या table migration नहीं जोड़ी: table DDL, foreign keys/check constraints, refund lifecycle state machine, payout lock semantics, and new-bill amount contract एक साथ reproducibly define किए बिना आधा implementation unsafe होता।

**Current verified state:** Source/UI audit + Production read-only function/ACL/RLS/index/trigger audit documented. Fresh-DB refund schema reproducibility, branch create RPC, Admin queue UI, provider executor/callback, labour-bill-compatible prepare/finalize, and runtime pgTAP/concurrency/IDOR tests remain incomplete. No production writes or provider actions.


### Refund contract — Production schema constraint audit (13 नवम्बर 2026)
- Production refund schema के column/constraint catalog को read-only तरीके से और जाँचा। Request table में प्रति booking unique request (पुराने model में), customer/auth FK, refund-record FK, amount > 0, reason 20–1000 अक्षर और status enum (`requested/in_review/approved/rejected/processing/unknown/processed`) हैं।
- Razorpay refund table में प्रति booking unique row, globally unique idempotency key/provider refund ID, `pay_`/`rfnd_` format checks, INR-only currency, positive paise amount, reason length और status enum (`requested/processing/unknown/processed/failed`) हैं।
- Manual refund table में प्रति booking और प्रति manual payment entry unique row, payment-entry FK, positive amount, reference length 4–120 और note max 250 हैं। ये पुराने Production constraints हैं; नए branch schema में blindly copy नहीं किए जाएँगे।
- Immutable labour bill का branch contract स्पष्ट है: `labour_amount_paise` integer-paise numeric snapshot, `labour_amount`, `platform_fee_paise`, `platform_fee_amount`, `electrician_payable`; materials इस bill का हिस्सा नहीं हैं। New refund amount को इसी labour amount और exact verified captured payment के बीच reconcile करना होगा, पुराने `amount_paid`-only shortcut से नहीं।
- एक महत्वपूर्ण compatibility issue: Production refund request पर booking_id unique होने से rejected request के बाद customer UI का “दोबारा अनुरोध” उसी booking पर दूसरा row insert नहीं कर पाएगा, जब तक Admin/Customer RPC पुराने row को safely reuse/update न करे या schema में active-request partial uniqueness वाला versioned lifecycle न बनाया जाए। इस व्यवहार को source/runtime test से resolve करना बाकी है।
- इसलिए अभी भी कोई migration लिखना/चलाना उचित नहीं: पुराने Production constraints में booking_id UNIQUE और refund lifecycle semantics नए repeat-request + immutable labour bill के साथ conflict कर सकते हैं। पहले state machine और migration compatibility तय होगी; फिर एक atomic, reproducible migration set बनेगा।

**Verification boundary:** केवल Production catalog SELECT और Feature Branch source reads। कोई schema/data write, migration apply, pgTAP/runtime test, provider API call, refund, payout या deployment नहीं हुआ। Customer App 14.1.10 🟡 Partial / In Progress ही है।


### Refund lifecycle — Production RPC और fee-ledger interaction audit (13 नवम्बर 2026)
- Customer create RPC की पूरी definition पढ़ी: ownership (`customer_user_id=auth.uid()`), booking row `FOR UPDATE`, paid + verified payment, reason length, existing refund checks और rejected-request row reuse मौजूद हैं। पर यह RPC पुराने `amount_paid` को amount मानती है; `completed` status, immutable labour bill existence/amount और exact captured Razorpay paise reconciliation enforce नहीं करती। Cash/manual और Razorpay अलग रास्ते भी request creation में स्पष्ट रूप से नहीं चुने गए।
- Admin decision RPC row lock करती है और `is_srk_admin()` check करती है। `approved`/`rejected` निर्णय संभव हैं; processing/unknown/processed पर नया निर्णय रोकती है। Admin list RPC customer phone/name समेत sensitive data देती है और Admin gate है; लेकिन branch `admin.html` में queue UI अभी नहीं मिला।
- Admin prepare RPC legacy quote model पर निर्भर है (`quote_status`, `quoted_amount`, `service_charge + materials_amount`) और request amount को `amount_paid` से match करती है। यह new immutable labour bill के `labour_amount_paise` contract के अनुकूल नहीं है। Existing Razorpay refund record reuse होता है; payout `paid` हो तो रोकता है, pending/blocked payout को blocked करता है।
- Service reconciliation RPC `service_role` मांगती है, provider status pending/processed/failed स्वीकारती है, और processed पर booking को `payment_status='refunded'` करती है। लेकिन Production payout/fee-ledger trigger भी इस update पर चलता है। Trigger paid electrician payout रोकता है; cash booking का fee due बाद की online booking से settle हो चुका हो तो cash refund को भी रोकता है; online refund पर settled cash due restore और online fee reversal ledger entries बनाता है। इस trigger का business व्यवहार refund lifecycle के साथ atomic रूप से test होना बाकी है।
- Manual refund RPC केवल Razorpay-unlinked verified payment + manual payment audit entry + exact amount match स्वीकारती है; duplicate manual refund रोकती है; paid electrician payout पर अलग reconciliation मांगती है। New labour-bill amount को manual receipt amount से reconcile करने का branch implementation अभी नहीं है।
- Critical end-to-end risk: provider पर refund सफल होने के बाद service reconciliation में fee-ledger trigger यदि exception उठाए, तो database transaction rollback हो सकता है जबकि provider ने पैसा लौटा दिया हो। ऐसी स्थिति के लिए provider event durable capture, retry-safe `unknown`/reconciliation state और Admin recovery path आवश्यक है; केवल webhook response/retry पर्याप्त नहीं।

**Next exact implementation sequence:** (1) migration-complete refund tables + explicit lifecycle state model, (2) customer request RPC: completed + immutable bill + exact paid amount, (3) Admin review/prepare RPC labour-only and payout/fee-ledger locks, (4) trusted provider executor + signed callback/poll reconciliation durable-before-finalize, (5) Admin refund queue UI, (6) pgTAP concurrency/IDOR/ledger failure/replay tests. No Production write/provider call/runtime test was made. Customer App 14.1.10 remains 🟡 Partial / In Progress.


### Refund foundation implementation — Feature Branch (13 नवम्बर 2026)
- Feature Branch में नई migration `20261114100000_reproducible_labour_only_refund_foundation.sql` जोड़ी: Razorpay refund, manual refund audit और customer refund request tables की idempotent `CREATE TABLE IF NOT EXISTS` definitions; FK/check/unique/index guards; RLS enable और client direct table grants revoke। यह migration अभी केवल branch source है, कहीं apply नहीं हुई।
- इसी migration में `srk_customer_create_booking_refund_request(uuid,text)` जोड़ी। यह authenticated customer की अपनी booking lock करती है; completed + paid + verified + customer-approved completion + selected category अनिवार्य करती है; immutable labour bill के integer paise और captured payment amount को exact reconcile करती है; Razorpay ID या manual payment audit entry verify करती है; materials को refund amount से बाहर रखती है; duplicate active/processed refund रोकती है; rejected request को उसी row पर सुरक्षित reopen करती है। Legacy quote-only bookings को इस नए RPC से रोककर Admin reconciliation gate में रखती है।
- New pgTAP file `supabase/tests/database/labour_only_refund_foundation.test.sql` में 12 static/schema assertions जोड़े: तीन tables, completed/approved state, immutable labour amount, paise match, manual proof, rejected-only reopen, ownership, RPC grants और direct table read denial। Test file अभी execute नहीं हुई।
- `.github/workflows/supabase-schema-ci.yml` में migration apply list और smoke checks जोड़े ताकि isolated schema workflow refund tables/RPC existence verify करे। Workflow dispatch नहीं किया गया; dedicated least-privilege `SUPABASE_DB_URL` secret/runtime CI availability अभी gate है।
- Important remaining compatibility checks: pre-existing schema export में `CREATE TABLE IF NOT EXISTS` existing objects को alter नहीं करेगा; actual deployed refund table shape/constraints must match. Existing Production RPCs and audit triggers are not replaced. Admin review/queue UI, manual-refund finalization labour-bill parity, trusted Razorpay executor/callback/polling and provider-side durable reconciliation still incomplete.

**Verification boundary:** GitHub Feature Branch commits only. No SQL migration applied, no pgTAP or runtime tests executed, no Production schema/data writes, no provider API/refund/payout, no deploy. Therefore these are implementation artifacts, not verified operational functionality. Customer App 14.1.10 remains 🟡 Partial / In Progress; original 96 checklist counts unchanged.

**Commits:** migration + test `74558c0b4612bd008e7b88bb9cfe842797420fdc`, `e2102a4085f063579483d94c526ea4516750bbcc`; CI update `9b24f94bec75df3e0e16adbcdcf244c2e13432fd`.


### Admin refund review queue — Feature Branch (13 नवम्बर 2026)
- नई migration `20261114110000_admin_refund_review_queue_and_decisions.sql` जोड़ी। `srk_admin_list_booking_refund_requests()` Admin-only सूची RPC है; ग्राहक, booking, payment reference, refund request, labour bill और राशि का Admin review view लौटाता है। `srk_admin_decide_booking_refund_request(uuid,text,text)` Admin authorization, row lock, 10–2000 अक्षर audit note और सीमित state machine (`requested → in_review → approved/rejected`) लागू करता है। इस migration में कोई provider refund initiation या payment status mutation नहीं है।
- `admin.html` में Refund Requests navigation और अलग review queue panel जोड़ा। Admin सूची refresh कर सकता है, review शुरू कर सकता है, approved/rejected निर्णय के साथ अनिवार्य audit note दे सकता है। UI स्पष्ट करता है कि approval से पैसा नहीं भेजा जाता; actual refund अलग सुरक्षित workflow में होगा।
- pgTAP `supabase/tests/database/admin_refund_review_queue.test.sql` में 8 schema/authorization/state-transition assertions जोड़े। अभी execute नहीं हुए।
- Supabase isolated schema CI migration list और smoke checks में Admin refund queue/decision RPCs जोड़े। Workflow dispatch नहीं हुआ।

**Remaining high-risk refund work:** Admin approval के बाद Razorpay refund prepare/executor/callback/poll reconciliation अभी implement नहीं; manual refund completion अभी labour-bill paise model से aligned नहीं; payout-paid / cash-fee-settlement conflict handling must be preflighted and durably recoverable before provider call. Current UI deliberately stops at review decision and does not move money. Admin queue SQL/UI source is not runtime verified. No Production changes/provider calls.

**Commits:** Admin RPC migration/test `ebf898450169fa0a94abc6bb2f3ffa88b348cd66`, `eb5c818f97c9c1dbc8f9f09a6a105d400e429c5f`; Admin UI `62db39fe8772d714966752069247173a034045e2`; CI `f5053dfe29c2d10654d252140b4581f712ccd1ce`.


### Razorpay refund preparation + financial preflight — Feature Branch (13 नवम्बर 2026)
- Migration `20261114120000_guarded_labour_only_razorpay_refund_preparation.sql` में Admin-only `srk_admin_prepare_booking_refund(uuid)` जोड़ा। यह request + booking rows lock करता है; completed/customer-approved/verified/category booking, immutable labour bill, integer paise, request amount और paid amount exact match करता है; Razorpay captured payment/order reference मांगता है; materials exclude करता है।
- Preparation से पहले per-electrician advisory transaction lock लिया जाता है। Electrician payout `paid` हो तो automatic refund block; payout unexpected state में हो तो reconciliation; cash booking की fee due बाद के online settlement में consume हो चुकी हो तो automatic refund block।
- Existing refund intent के लिए idempotent response; processing/unknown/processed अथवा mismatched record पर provider retry नहीं, Admin reconciliation result/exception। New intent `srk_razorpay_refunds` में `requested` state और unique idempotency key के साथ durable record बनाता है। यह RPC Razorpay API call नहीं करता और request को falsely processed नहीं बताता।
- Admin UI में approved request के लिए “Razorpay रिफंड की सुरक्षित तैयारी” action जोड़ा। Confirmation स्पष्ट करती है कि अभी Razorpay को पैसा भेजने का अनुरोध नहीं जाएगा। Success में intent/amount दिखाता है।
- pgTAP `guarded_razorpay_refund_preparation.test.sql` में 10 static assertions जोड़े; test execute नहीं हुआ। CI migration list + smoke check updated; workflow dispatch नहीं हुआ। Admin inline JS syntax check PASS (source-only check).

**Still not operational:** Trusted server-side Razorpay refund executor using Razorpay refund API + idempotency key, signed webhook/polling, durable provider-event inbox, recovery when provider succeeds but fee-ledger trigger transaction fails, and labour-bill-compatible manual refund finalizer are still missing. Do not call provider or mark request processed until durable two-phase reconciliation exists. No SQL migrations applied, no runtime/pgTAP tests, no Production changes, no money movement or deployment. Customer App 14.1.10 remains Partial/In Progress; checklist totals unchanged.

**Commits:** guarded preparation migration/test `edeafa84a41063cc2c7af519cbff096942e18d15`, `95ace1b9ab7f1b6a3ff6008208bfa3a5c54d55cb`; Admin UI `9c8c332ab288a97a4e56eadef8cd0d74bcced504`; CI `c26dbe8c8b3b2c01ad0f695aec15b781e5214234`.


### Razorpay refund provider executor + durable recovery — Feature Branch (13 नवम्बर 2026)
- Official Razorpay Refund API contract checked: normal refund `POST /v1/payments/:id/refund` supports `X-Refund-Idempotency`; retries must reuse same key and identical body. Branch implementation uses this header and stored key. Official docs: https://github.com/razorpay/markdown-docs/blob/master/api/refunds/normal-refunds-idempotent.md
- New migration `20261114130000_durable_razorpay_refund_provider_reconciliation.sql`: private provider-event inbox keyed by Razorpay event ID; Admin-only claim RPC; service-role-only provider-result persistence, webhook event capture and internal finalization RPCs. Provider result is stored in a separate transaction before `service_bookings.payment_status='refunded'` triggers payout/fee-ledger reversals. If ledger reconciliation fails after Razorpay success, provider refund ID/status remains durable and booking is not falsely marked refunded; same record can be retried/reconciled.
- New `razorpay-refund.js` Netlify handler: validates Admin session and claim RPC; rechecks captured INR payment and exact amount against labour-only bill; checks existing provider refunds when prior refund activity exists; uses the stable `X-Refund-Idempotency` key; persists provider response before attempting internal reconciliation. Unknown network outcomes retain the same key. Separate webhook handler verifies raw-body HMAC, requires Razorpay event ID, durably captures the event before reconciliation, and deduplicates event IDs.
- Admin UI connects approved request to provider executor and exposes same-key retry for processing/unknown requests. `netlify.toml` routes executor and webhook endpoints. CI includes migration and a source regression workflow.
- Added Node source regression tests (7 cases) and pgTAP test (13 assertions). Neither has been executed in this environment; workflow has not been observed running. Static `new Function` syntax checks PASS for handler and Admin inline JS. Do not call runtime, SQL or end-to-end tests passed.
- Razorpay official webhook URL still needs configuration in Razorpay Dashboard; deployment/secrets are not changed. Required environment variables follow existing project conventions (`SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`, Razorpay API credentials, `RAZORPAY_WEBHOOK_SECRET`); verify actual environment configuration before deployment.
- Production schema was read-only inspected: existing refund tables contain `amount_paise`, `idempotency_key`, `provider_status`, `refund_id`, and current status/foreign-key/unique constraints; `service_bookings` includes payment references and customer identity. Production currently lacks the new branch labour-bill table/migrations, so none of these branch migrations can be applied to Production yet. No SQL writes, deployment, provider API calls, refunds, payouts, or money movement performed.
- Safety limitation: if a refund succeeds at Razorpay but local fee/payout trigger blocks finalization due to a concurrent payout or pooled fee-ledger change, durable provider response remains, request stays processing and requires Admin reconciliation; automatic reversal/ledger repair is not attempted. This is intentional fail-safe behavior, not a fully automatic end-to-end guarantee.

**Commits:** provider reconciliation migration/test `b31d3a89b4f6d01ba6c3c0267b713925fe160528`, `484f08599debbd766ba98997706b435830f62974`; link prepared intent `f84196b7c19bcfaa58b14f6194136dec042aca76`; executor + Netlify wrappers `56782255212626a8fca4448700c2deedb27015f0`, `1724cd9a1a42056ff4327172a8453f764b6f0b51`, `44cbbe2fd8a9ef9261a313d8a12c829570526be3`; Admin integration/retry `001da27997e5ca760510b215b02b6367c4657463`, `42d7be6c994ef8e4ae9b73cd6f62d7ce89a5183a`; routes/CI `c161a25c0a66ef1bf47771642f4c4fe709f43312`, `6e3d95729af512848b1600239859822437c6d278`, `2d9acd08a571898f8a62bfff5944fb79756c5077`, `415f9d527659b653fd273052b2810d363dd6022d`; source tests `b28bf04931d8e5628e136d6bb4a03cb89162b0d1`, `599785fed168a42cf6d893928231da6b98291695`, `3122815f123ec57efea4d00622613734a83c1509`; final key/payment guards `c23572666a9703022d6382e2568c321c1a62933c`, `e2232e306dc4ea8555a2ed968a4ee66989998b3f`, `0ec1593cb6c19c391b29885eb5d5d6d67c20ad23`.


### Manual/offline labour-only refund workflow — Feature Branch (13 नवम्बर 2026)
- Migration `20261114140000_manual_labour_only_refund_workflow.sql` में private `srk_manual_refund_intents` lifecycle बनाया: `prepared → paid → processed`, या `requires_reconciliation`। इसमें amount paise, matching manual payment entry, transfer reference, Admin identity, timestamps और recovery note सुरक्षित होते हैं।
- `srk_admin_prepare_manual_booking_refund(uuid)` केवल Admin के लिए: completed + customer-approved + verified manual payment, immutable labour bill, exact paise amount और non-Razorpay payment channel जाँचता है; Razorpay-linked payment को Razorpay flow पर भेजता है। पहले से pending electrician payout को marker सहित block करता है; paid/अनपेक्षित payout state तथा cash-fee pooled settlement conflict पर रोकता है। Existing intent retry को idempotent बनाया और payout block ownership marker जोड़ा।
- `srk_admin_record_manual_refund_transfer(uuid,text,text)` वास्तविक transfer reference अलग transaction में durable करता है। यह ऐप से पैसा नहीं भेजता; Admin को ग्राहक को बाहर Cash/UPI/Bank से वास्तविक राशि लौटाने के बाद ही reference दर्ज करना है।
- `srk_admin_finalize_manual_booking_refund(uuid)` transfer evidence के बाद booking को refunded करता है, existing trigger से fee/payout reversals चलाता है और `srk_manual_refund_entries` audit record बनाता है। यदि trigger/ledger transaction fail हो तो पहले से दर्ज transfer evidence अलग transaction में सुरक्षित रहता है; उसी intent को retry किया जा सकता है। Payout marker बदलने/गायब होने या payout paid होने पर automatic finalization रोककर `requires_reconciliation` दर्ज करता है।
- Admin list v2 RPC manual refund status/reference/amount दिखाता है। Admin UI में तीन अलग कदम हैं: intent तैयार करना, वास्तविक transfer reference दर्ज करना, और ledger finalization।
- pgTAP `manual_labour_only_refund_workflow.test.sql` में 14 assertions; Node source regression suite `manual-refund-workflow.test.cjs` में 7 cases; `npm run test:refund` अब Razorpay + manual refund source suites चलाता है। `supabase-schema-ci` migration + RPC smoke checks और refund source CI path filters updated।
- Static checks: Admin inline JavaScript syntax PASS; manual Node test source syntax PASS; pgTAP declared plan 14 and 14 assertions verified by source inspection. Node tests and pgTAP have NOT been executed; CI run has not been observed. No SQL applied to Production, no manual money transfer, no deployment.
- Production schema read-only inspection confirms current manual payment/refund entry columns and payout/fee ledger tables, but Production lacks the new branch labour-bill model/migrations; this workflow remains Feature Branch only pending schema compatibility review and explicit deployment approval.

**Commits:** manual workflow migration/test `b5c28fb77428b74aba848152d92a4c8515fe231f`, `2994a03bf9f4aa8f762190ed35f677fe6d3eb818`; retry/payout ownership fixes `ae67d95fcf9dfd87d405968b14b08c50aa4d5593`, `1be87949b7e9c89822a8e8fb4ef97e95d5decd39`, `e1c08ecdce63d19195a0caf360f3d4613b8fc483`; Admin UI `c8c74de02e1ea404cf2c29de55beeb5070357f25`; Node tests/package `515edafca22f85ff3e374d998f2a05a13fdfdabf`, `0e2dc2746234e247b3e08e8b8688d93be9fecde2`; CI `dd891d12f6802aa9e75125e1314ab51b887f0281`, `b16c2592ee0ca466b22125e1314ab51b887f0281`, `d00c7aeeb79dd10c0ad0fbd6fc9486fb10af997c`, `f7034819fbe4c5d142a765cbccbab8c2453b0c60`.


### Customer Payments refund-history completion + manual refund hardening — Feature Branch (13 नवम्बर 2026)
- Customer App Payments tab में अलग “मेरे रिफंड अनुरोध” private history panel जोड़ा। यह authenticated `srk_customer_list_my_booking_refund_requests()` RPC से केवल उसी ग्राहक के request rows लाता है; request amount, reason, booking reference, last update और readable status दिखाता है। Login पर और Payments tab खोलने पर payment + refund history auto-refresh होती है; logout पर refund history clear होती है।
- Customer refund status copy में `in_review` और `unknown` (Admin जाँच आवश्यक) जोड़ा; request-submit confirmation अब सही बताता है कि स्थिति My Bookings और Payments दोनों में दिखेगी।
- Manual refund migration को retry/payout marker ownership और exact immutable manual-refund audit row verification के लिए harden किया। Manual transfer evidence अलग transaction में stored रहता है; final ledger transaction failure पर intent `paid` रहता है और Admin उसी intent को retry कर सकता है।
- Refund source test suite अब Razorpay 7 + Manual 7 + Customer history 4 = 18 source test cases चलाने के लिए configured है (`npm run test:refund`). Manual refund pgTAP plan अब 15 है, 15 assertions source में हैं। CI path filters में Customer booking HTML और नया test जोड़ा।
- Static checks PASS: Customer `booking.html` inline JS, Admin `admin.html` inline JS, और तीनों Node test source files की syntax. Manual refund pgTAP plan/assertion count 15/15 verified by source inspection. **Node tests, pgTAP और CI अभी execute/observe नहीं हुए।**
- No SQL applied to Production; no external manual transfer, Razorpay provider call, deployment, payout, or live money movement. Customer App remains Partial/In Progress until runtime SQL tests, schema compatibility, payment/refund recovery tests, and consolidated final mobile/Desktop QA are complete.

**Additional commits:** manual refund audit hardening `3dd4cbf6f1d7a2a36c3eef5fbb4134083d900e7a`, `3a12e16f50652422b8d2bc1178206838504b9f20`; Customer Payments history `3f2aa3666ba425d01cadc87810fd53a0fda70bfc`, `c972f4decce6cc1dc68d3c51be9176632016dbd8`, `82fc861270438f941a55c064f6db418d28b00d55`; Customer refund tests/CI `d4812229a21e872d1f81e8ce65858eefac4753c2`, `7a8359cfdfbebdb128a7572ef46c8bf30ee536bd`, `808f2cef318b9b6a26d866360dba6b6016f16777`.


## 2026-11-13 — Customer App refund recovery follow-up

- Refund lifecycle audit found a concrete state-visibility defect: when Razorpay returned `failed`, the provider refund row became `failed` but the customer refund request remained `processing`. The retry claimant correctly rejected the failed provider row, leaving the request apparently stuck.
- Added feature-branch migration `20261114160000_surface_failed_provider_refunds_for_admin_reconciliation.sql`: provider failure now moves the linked customer request to `unknown`, records a concise Admin-visible reconciliation note, and returns an explicit `admin_reconciliation_required` flag. It deliberately does **not** auto-retry or create a new refund intent after provider failure.
- Added pgTAP contract file `supabase/tests/database/failed_provider_refund_admin_reconciliation.test.sql` (5 assertions) and registered the migration in isolated schema CI.
- Commits: migration `0e8d3e831dea4611fd9b25fc494f5b1a4e6b11f0`; test `d996d38c67f8df3154fb47a87d2bcaf5a526397e`; CI `37a04114f9559b32282cb865a18b0319dee307bf`.
- Verification status: source/migration/test files committed; pgTAP and isolated schema workflow have **not** been executed. No Production schema/data, payment, refund, payout, secret, or deployment changes.
- Checklist totals remain unchanged (96 points; 0 fully verified). Section 14.1.10 remains Partial/In Progress.
- Next Customer App task: continue Booking Form and submission contract audit (category/duration, address/PIN validation, date/time, duplicate submission, and confirmation disclosure); then complete customer payment/refund/receipt dependency verification before moving to Electrician Portal.


## 2026-11-13 — Customer Booking API input validation follow-up

- Reviewed the customer booking form and server handler together. The form sends a 10-digit phone, while the API previously trimmed the input to the first 10 characters before validation. This could silently transform malformed longer input rather than reject it.
- Changed the API to retain up to 20 input characters before its existing strict `^[0-9]{10}$` validation, so overlong values and prefixed values are rejected rather than truncated into another number.
- Commit: `677b04ff0e968eead759abe840ebaf9f2042bfd9`.
- Verification: JavaScript syntax check passed. No functional booking API test or database test was run; no real booking or Production change.
- Date/time business policy remains unmodified pending an approved rule; this pass only confirmed strict calendar/time format and numeric bounds. PIN-to-district postal-directory validation and same-day booking cut-off remain open.
- Checklist totals unchanged; Customer App 14.1.10 remains Partial/In Progress.

## 14 नवंबर 2026 — Customer Page checklist पुनः-जाँच (Feature Branch)

यह अपडेट Section 14.1 के ग्राहक-पेज बिंदुओं को वर्तमान source के विरुद्ध जाँचकर जोड़ा गया है। यह मूल 96-point checklist का विकल्प नहीं है और किसी item को केवल UI मौजूद होने से Verified Complete नहीं मानता।

### इस सत्र में किए गए source सुधार
- Booking form में स्पष्ट शर्तें/घोषणा जोड़ी: estimate advance या maximum cap नहीं; final labour server-recorded actual minutes पर; materials/parts अलग itemized और अलग customer approval; exact selected electrician tier; payment method बिना customer consent नहीं बदलेगा।
- Booking submit से पहले अनिवार्य checkbox और एक final review confirmation जोड़ा, जिसमें selected tier, duration, estimate और payment method दिखते हैं।
- Client-side booking date/time validation जोड़ी ताकि अतीत का समय submit न हो।
- Booking success message को sequential dispatch के अनुरूप किया: एक समय में एक eligible electrician को पहला offer जाता है; decline/timeout पर अगला candidate। पुराने “कई electricians को एक साथ offer” वाले संदेश को हटाया।
- Static verification: booking.html inline JavaScript parse PASS; create-booking.js syntax parse PASS; terms checkbox, final confirmation, past-time guard और sequential-offer messaging source checks PASS।

### Section 14.1 की वर्तमान स्थिति — अभी शेष
- OTP: source मौजूद; वास्तविक SMS/Auth delivery, expiry, resend/wrong-attempt throttling और browser/device E2E बाकी।
- पाँच मेनू: Home, My Bookings, Payments, Help & Support, My Profile के sections मौजूद और shell द्वारा सही panel में content mount होता है; हर backend flow का runtime acceptance बाकी।
- Booking: customer verified phone read-only, address/GPS/map, 5 electrical work categories, चार approved rate tiers और 1–8 घंटे estimate source मौजूद; authoritative PIN/district directory तथा mismatch review queue अभी blocked।
- Booking terms/confirmation और past date/time guard source में जोड़े गए; server-side runtime proof और real-world duplicate/retry tests बाकी।
- Sequential offer source मौजूद; वास्तविक database concurrency/expiry/JWT tests बाकी।
- Booking timeline, accepted-only contact और actual-time timer/completion source मौजूद; DB/JWT/RLS runtime और full lifecycle tests बाकी।
- Live travel location/ETA तथा permission-denied/stale/arrival-stop behavior अभी पूर्ण रूप से प्रमाणित नहीं; blocked।
- Payment history/refund history/receipt और Razorpay source मौजूद; provider-confirmed payment/refund lifecycle और reconciliation tests बाकी।
- Cancellation अभी customer booking card से Help & Support request करने को कहता है; dedicated cancellation request/status/fee workflow और policy verification बाकी।
- Help & Support ticket/message/attachment source मौजूद; backend schema/RLS/storage end-to-end tests बाकी।
- Profile/photo/saved-address source मौजूद; account-security controls, notification preferences और full tests बाकी।
- Customer ratings/reviews UI + moderation lifecycle अभी पर्याप्त रूप से उपलब्ध/verified नहीं।
- Accessibility, low-bandwidth/offline, responsive and final consolidated mobile QA बाकी।

### सुरक्षा/रिलीज़ स्थिति
- सभी बदलाव केवल `feat/customer-login-first-dashboard-20261114` branch / Draft PR #8 में हैं।
- Supabase migrations और pgTAP अभी वास्तविक database पर execute नहीं हुए।
- कोई merge, production migration, production setting change या deployment नहीं किया गया।
- Manual mobile QA सभी कार्य पूरे होने के बाद एक consolidated pass में ही होगा।

### Customer Page follow-up — Support और Cancellation source fixes
- Customer script में createCustomerSupportComplaint और loadCustomerSupportBookings event/session flow से refer हो रहे थे, लेकिन function definitions मौजूद नहीं थीं। इससे initial script में ReferenceError आकर OTP event wiring और booking submit handler तक execution रुक सकता था।
- दोनों functions जोड़े: signed-in customer की अपनी booking list भरना और srk_customer_create_booking_complaint(p_booking_id,p_category,p_description) RPC से 20–2000 अक्षर की complaint create करना; success पर complaint thread refresh।
- srk_customer_cancel_my_booking(p_booking_id) के साथ direct cancellation action जोड़ा, केवल new/confirmed और unassigned bookings के लिए। Assigned/active booking को सीधे cancel नहीं करता; Help & Support request का रास्ता दिखाता है। कोई cancellation fee invent नहीं की गई।
- Read-only Supabase inspection में primary project पर customer complaint create/list और pre-assignment cancellation RPCs मौजूद मिले। उसी read-only schema inspection में deployed service_bookings में नई selected-tier/timer columns नहीं मिले; इसलिए feature-branch migrations की database rollout dependency अभी बाकी है।
- Latest static checks: booking.html inline JS PASS; create-booking.js syntax PASS; support/cancel functions defined and wired; OTP/login functions remain reachable; booking terms/past-time checks PASS।
- वास्तविक customer OTP login, complaint insert, cancellation RPC, booking/timer/payment flows को live customer session/JWT से E2E चलाना बाकी है। कोई database write या production change नहीं किया गया।


## 14 नवम्बर 2026 — Customer cancellation policy alignment

Master Requirements Section 6 की दोबारा जाँच में एक महत्वपूर्ण mismatch मिला: ग्राहक पेज पर पहले unassigned booking को सीधे cancel करने के लिए `srk_customer_cancel_my_booking` RPC बुलाया जा रहा था, जबकि स्वीकृत नीति के अनुसार ग्राहक या electrician स्वयं booking cancel/finalize नहीं कर सकते; अंतिम निर्णय केवल Admin करेगा।

### Feature Branch में किया गया corrective source change
- Customer booking card का बटन अब **“Admin से रद्द करने का अनुरोध”** है।
- यह सीधे booking status बदलने या cancellation RPC चलाने के बजाय Help & Support में संबंधित booking चुनकर cancellation request का विवरण prefill करता है।
- ग्राहक को स्पष्ट बताया जाता है कि शिकायत/अनुरोध भेजने के लिए उसे “शिकायत दर्ज करें” दबाना होगा; Admin निर्णय से पहले booking cancelled नहीं मानी जाएगी।
- Customer UI अब ₹0/₹49/₹99 में से कोई cancellation fee स्वयं नहीं लगाता; Admin सत्यापित electrician status और reason के आधार पर निर्णय करेगा।
- Direct customer cancellation RPC call को इस UI path से हटा दिया गया है।

### शेष blocker — cancellation workflow अभी पूर्ण नहीं
- Existing Help & Support complaint के माध्यम से अनुरोध भेजना अभी temporary routing है; dedicated Admin cancellation inbox, evidence review, approved fee selection (केवल ₹0/₹49/₹99), mandatory decision reason, append-only audit, customer-visible decision/status और unpaid fee carry-forward/accounting अभी अलग से implement और verify करने हैं।
- Existing legacy Admin booking status dropdown में manual “cancelled” update path भी audit/guard करना बाकी है, ताकि Admin cancellation request/decision workflow bypass न हो।
- कोई production DB/RPC, live booking, payment, migration application या deployment नहीं किया गया।
- इस correction को complete cancellation feature न माना जाए; यह केवल customer-side direct-cancel policy mismatch को हटाता है।


### 14 नवम्बर 2026 — Admin status-dropdown cancellation bypass बंद

- Admin booking table में सामान्य status dropdown से `cancelled` चुनकर सीधे booking रद्द करने का रास्ता हटाया गया।
- पहले से cancelled historical booking के लिए status label read-only/disabled रूप में दिखता रहेगा।
- `saveBooking()` में server से booking का वर्तमान status दोबारा पढ़ने के बाद guard लगाया: नई cancellation को सामान्य status update से अस्वीकार किया जाएगा और सूची refresh होगी।
- यह UI guard है; authoritative database/RPC-level enforcement अभी बाकी है। कोई live booking या production data बदला नहीं गया।

### Cancellation implementation का वर्तमान सत्यापित scope
- Customer button केवल Help & Support में cancellation request prefill करता है; ग्राहक को complaint submit करना होता है।
- Admin सामान्य status dropdown से cancellation नहीं कर सकता।
- Dedicated cancellation inbox + direct customer request RPC + stage evidence + ₹0/₹49/₹99 Admin decision + immutable decision audit + customer debt carry-forward + SRK cancellation-fee ledger + cash/online reconciliation अभी implement और verify होने बाकी हैं।
- Production schema read-only निरीक्षण में wallet ledger के मौजूदा entry_type values में dedicated cancellation-fee entry type नहीं मिला; इसलिए इसे existing Platform Fee/commission/adjustment में गलत तरीके से नहीं मिलाया जाएगा।


## 14 नवम्बर 2026 — Dedicated Admin-only Cancellation Inbox (Feature Branch)

### Master Section 6 के अनुरूप जो source बनाया गया
- Customer Help & Support complaint के सहारे cancellation request भेजने वाला अस्थायी तरीका हटाकर dedicated RPC request flow जोड़ा गया।
- नया migration source: `20261114270000_admin_only_cancellation_requests_and_decisions.sql`.
- नई request table में customer note, pending/approved/rejected state, verified stage, fixed fee, evidence text, Admin reason, actor और timestamps दर्ज होंगे।
- एक booking पर एक समय में केवल एक pending request की unique constraint है; customer ownership check और booking row lock request RPC में हैं।
- Admin-only RPC pending requests list करता है; Admin निर्णय RPC stage के अनुसार केवल ₹0/₹49/₹99 स्वीकार करता है और कम-से-कम 10 अक्षर का evidence तथा decision reason अनिवार्य करता है।
- निर्णय से पहले booking को lock करके दोबारा जाँचा जाता है; completed/cancelled booking पर फैसला नहीं होगा।
- Approved decision के बाद ही booking status cancelled होता है। DB trigger सामान्य client/direct status update और पुराने direct-cancel RPC को रोकता है; केवल approved request context से transition स्वीकार करता है।
- Cancellation event log append-only है; browser roles को दोनों नई tables पर direct table access नहीं दिया गया।
- Customer page अब dedicated request RPC call करता है और अपने booking card में pending/approved/rejected decision, verified stage, fee और Admin reason दिखाता है।
- Admin Dashboard में dedicated Cancellation Requests Inbox, stage selection, evidence/reason fields, approve/reject actions और refresh control जोड़ा गया। सामान्य booking status dropdown से cancellation पहले की तरह रोकी गई है।

### Static verification
- `booking.html`: 4 inline scripts — सभी parse PASS.
- `admin.html`: 3 inline scripts — सभी parse PASS.
- Customer request/list RPC wiring, Admin list/decision RPC wiring, ₹0/₹49/₹99 stage options, direct-cancel DB guard और append-only audit source checks PASS.

### अभी अधूरे/अप्रमाणित — इन्हें complete न मानें
- Migration केवल Feature Branch में है; Supabase में apply नहीं किया गया। इसलिए live customer/Admin RPC flow अभी चलने का दावा नहीं है।
- Admin द्वारा stage evidence text दर्ज होता है; live GPS/travel/arrival event से automatic evidence linking अभी उपलब्ध नहीं। Admin को उपलब्ध वास्तविक evidence manually verify करना होगा।
- Approved cancellation fee अभी request record में सुरक्षित होती है, पर customer debt/carry-forward, अगली booking के bill में अलग line item, Online cancellation-fee ledger, Cash settlement में electrician wallet debit और SRK cancellation ledger अभी implement नहीं हुए।
- Refund/reversal, duplicate/failed payment reconciliation, customer-visible multi-request debt history और full staging JWT/RLS/concurrency/E2E tests बाकी हैं।
- Existing पुराने cancellation RPC को DB trigger रोकने का उद्देश्य है; migration लागू होने के बाद उसका legacy caller impact staging में जाँचना आवश्यक है।
- Production database, live bookings, payments, wallet entries, settings या deployment में कोई बदलाव नहीं किया गया।


## 14 नवम्बर 2026 — Cancellation Fee Carry-Forward, अगली Booking Bill और अलग Ledger (Feature Branch)

### जो source implementation जोड़ी गई
- Migration: `20261114280000_cancellation_fee_carry_forward_and_accounting.sql`.
- Admin द्वारा ₹49/₹99 cancellation decision approve होने पर customer की अलग fee-debt row बनती है; ₹0 पर कोई debt नहीं बनता। पहले से approved ₹49/₹99 requests के लिए idempotent backfill भी शामिल है।
- अगली customer booking insert पर उसी customer के सभी खुले debts, पुराने created_at क्रम में, अलग-अलग booking line items के रूप में reserve होते हैं। Customer wallet balance से fee waive नहीं होती।
- यदि वह अगली booking Admin द्वारा cancelled हो जाती है और payment नहीं हुआ, तो reserved fee items फिर open debt बनकर अगली booking के लिए release होते हैं।
- Customer Payments में सभी fee debts (open/reserved/settled/reversed) और कुल outstanding amount दिखता है।
- नई booking भेजने से पहले customer app खुले unpaid cancellation fees की जाँच करता है, हर source booking की fee और संयुक्त अनुमान confirmation में दिखाता है; fee lookup असफल हो तो booking submit रोकता है।
- Customer booking card तथा payment receipt में प्रत्येक पुरानी cancellation fee source booking के साथ अलग line item है। Final payment total = immutable server labour bill + उस booking पर reserved cancellation fee items।
- Razorpay create-order path नई server-timed booking के लिए server RPC से labour + fee total लेता है। Verify-payment और webhook captured amount, order ID, selected Online method तथा immutable labour/fee breakdown मिलाकर एक atomic RPC से booking payment और fee ledger settle करते हैं।
- Online cancellation-fee हिस्से की अलग SRK cancellation-fee ledger entry बनती है; service labour अलग रहता है।
- Cash payment के लिए Admin-only RPC वास्तविक receipt/reference पर booking को Paid करता है, electrician wallet में प्रत्येक fee के लिए idempotent debit और SRK cancellation ledger में matching credit एक ही DB transaction में लिखता है। Wallet balance negative हो सकता है; debt waive नहीं होता।
- Wallet ledger में `cancellation_fee` entry type जोड़ा; SRK cancellation fee ledger append-only है।
- Admin Dashboard में open/reserved/settled debt, online fee collection और cash electrician wallet debit के अलग totals दिखाई देते हैं।
- Receipt RPC अब new category booking में immutable labour amount + settled fee items को अलग दिखाता है; print/PDF receipt में भी अलग fee rows हैं।

### Static verification
- `booking.html`: 4 inline scripts parse PASS.
- `admin.html`: 3 inline scripts parse PASS.
- `create-order.js`, `verify-payment.js`, `razorpay-webhook.js`: JavaScript parse PASS.
- Migration source checks: fee debt table, booking allocation trigger, cash wallet debit, online settlement, separate ledger, receipt fee items और append-only ledger checks PASS.
- कोई live customer payment, cash receipt, wallet entry या refund execute नहीं किया गया।

### अभी भी बाकी / जरूरी staging gates
- SQL migration को staging में apply करके PostgreSQL compile, trigger order, RLS/role claims, booking insert allocation, multiple fee rows, cancellation release, duplicate retries और concurrent cash/online settlement की वास्तविक tests करनी हैं। Production में apply नहीं किया गया।
- Cash RPC केवल Admin द्वारा वास्तविक Cash receipt/reference के बाद चलती है; Admin को ग्राहक से कुल रकम मिलने का वास्तविक प्रमाण देखना होगा।
- Online ledger entry SRK fee का accounting allocation है; Razorpay settlement/bank reconciliation और Route transfer में labour तथा cancellation fee का वास्तविक अलग settlement end-to-end verify करना बाकी है।
- Refund/reversal: partial/full refund, settled cancellation fee का reversal, cash wallet debit reversal, पहले से paid electrician payout recovery और chargeback/dispute reconciliation अभी implement/test नहीं हुए।
- Cash payment Admin path नई server-timed booking के लिए है; पुरानी quote-based bookings पुराने RPC पर चलती हैं। UPI/Bank manual reconciliation नई category के लिए अभी जानबूझकर बंद है; Razorpay Online या Cash ही सुरक्षित verified paths हैं।
- Cancellation fee evidence अभी Admin द्वारा दर्ज manual verified evidence text है; live travel/arrival telemetry से automatic evidence attachment अभी उपलब्ध नहीं।
- Migration और UI wiring source-only हैं; actual Supabase migration apply, live Razorpay test-mode transaction, customer/Admin JWT E2E, wallet balance verification और consolidated final mobile QA बाकी हैं।
- Production deployment, merge, live DB write या payment setting में कोई बदलाव नहीं हुआ।


## 14 नवम्बर 2026 — Full Refund पर Cancellation Fee / Electrician Wallet Reversal (Feature Branch)

### नई migration और नियम
- Migration: `20261114290000_full_refund_cancellation_fee_and_wallet_reversal.sql`.
- Booking का `payment_status` केवल verified full refund evidence के बाद `refunded` बन सकता है: Online में processed Razorpay refund record और exact full paise amount; Cash/manual में matching manual refund entry और exact full amount।
- Refund transition पर उसी Database Transaction में उस booking के settled cancellation-fee items reverse होते हैं। Original ledger row कभी edit/delete नहीं होती; append-only ledger में linked reversal debit entry बनती है।
- Online refund: SRK cancellation ledger की online collection का बराबर reversal debit।
- Cash refund: original electrician wallet debit की exact amount का wallet credit reversal, और SRK cancellation ledger में corresponding debit reversal। Original electrician wallet debit missing हो तो refund status transition fail-closed होकर rollback होगा।
- Reversed fee debt को माफ नहीं किया जाता: debt फिर `open` होता है, ताकि ग्राहक की आगे की booking में वही fee दोबारा अलग मद के रूप में reserve/collect हो सके। Refunded booking का पुराना fee item `reversed` audit state में रहता है।
- प्रत्येक ledger reversal अपने immutable original ledger row से `reversal_of_entry_id` के जरिए जुड़ा है; unique index duplicate reversal रोकता है।
- पहले एक debt के लिए केवल एक fee item की global uniqueness थी; उसे हटाकर प्रति booking + debt uniqueness रखी गई, ताकि refunded debt आगे की booking में फिर collect हो सके। Cash/Online collection idempotency भी per booking fee item की गई।
- Admin summary में net online collection, net cash electrician wallet debit, refunded fee amount और reversal entry count अलग दिखाई देते हैं।
- Razorpay refund fail होने पर previously blocked, unpaid electrician payout को वापस pending किया जाता है और पुराना payout note restore होता है।
- नया pgTAP test: `supabase/tests/database/cancellation_fee_refund_reversal.test.sql` (24 assertions)।

### महत्वपूर्ण सीमाएँ / fail-closed सुरक्षा
- मौजूदा refund APIs पूर्ण booking amount refund करती हैं; partial refund इस cancellation-fee allocation के लिए समर्थित नहीं है और matching full amount न होने पर DB transition reject होगा।
- पहले से paid electrician payout पर refund preparation/manual refund पहले से block है; paid payout recovery को automatic नहीं माना गया। ऐसे मामले में Admin को payout/provider reconciliation अलग से करनी होगी।
- Razorpay refund preparation को server-timed category bookings के लिए भी जोड़ा: legacy quote approval पर निर्भर हुए बिना immutable labour bill + settled cancellation fee items का exact full total verify होता है। Manual refund में pending electrician payout पहले blocked होता है; already-paid payout पर refund रोक दिया जाता है।
- Cash reversal तभी होगा जब original cash cancellation-fee ledger और electrician wallet debit दोनों मौजूद हों; missing records पर refund booking status update rollback होगा।
- Original Razorpay refund processing और bank settlement provider-side workflow पर निर्भर है; केवल DB status update को bank credit का प्रमाण नहीं माना जाएगा।
- नई migrations/tests source-only हैं। Production database पर कोई DDL, payment, refund, wallet credit/debit या payout action नहीं किया गया। Staging में migration apply और end-to-end verification बाकी है।


## 14 नवम्बर 2026 — Admin Customer Support Inbox और Reply Workflow (Feature Branch)

- Admin Panel में dedicated **ग्राहक सहायता Inbox** जोड़ा: शिकायत सूची, ग्राहक/बुकिंग संदर्भ, category, description और created time।
- Admin शिकायत की स्थिति `new / in_review / resolved / closed` बदल सकता है और अधिकतम 2000 अक्षरों का Admin note सुरक्षित कर सकता है; मौजूदा Admin-only `srk_admin_update_booking_complaint` RPC का उपयोग।
- प्रत्येक शिकायत की customer–Admin message thread खोलने और संदेश पढ़ने के लिए `srk_admin_list_booking_complaint_messages` wiring जोड़ी।
- Admin reply के लिए नई migration source `20261114300000_admin_customer_support_thread_replies.sql`: authenticated Admin check, complaint row lock, 1–4000 अक्षर validation, sender_role='admin' के साथ message insert, anon/public execute revoke और authenticated grant।
- Admin login के बाद और Refresh पर inbox auto-load होता है। Message/notes को HTML में escape किया जाता है; reply भेजने से पहले selected complaint और length validate होते हैं।
- Static verification: Admin inline JavaScript parse PASS; inbox/list/status/thread/reply RPC wiring checks PASS; SQL dollar-quote balance, Admin guard और grant source checks PASS।
- सीमाएँ: नई reply migration अभी source-only है; वास्तविक DB पर apply/compile नहीं हुई। Customer/Admin JWT से message insertion, RLS/role behavior और attachment viewing का consolidated E2E test अंतिम Testing चरण में बाकी है। कोई live customer message, DB write, Production change या deployment नहीं किया गया।


### Support backend dependency audit — 14 नवम्बर 2026
- Read-only Production schema inspection में `srk_booking_complaint_messages` और `srk_booking_complaint_message_attachments` tables तथा customer message RPCs अनुपस्थित मिले; जबकि Customer UI पहले से इन्हें call कर रही थी। इसलिए केवल Admin Inbox UI जोड़ना पर्याप्त नहीं था।
- Feature Branch में earlier-order migration `20261113220000_customer_support_conversation_schema.sql` जोड़ी: private message/attachment tables, thread indexes, RLS + direct table privilege revoke, customer-owned message/list/attachment-link RPCs और private Storage bucket policies।
- इसके बाद `20261113230000_support_attachment_paths_and_admin_message_list.sql` Admin/customer attachment paths और Admin thread reads देता है; `20261114300000_admin_customer_support_thread_replies.sql` Admin-only reply RPC जोड़ता है।
- Storage object access के लिए SECURITY DEFINER helper में authenticated UID, complaint ownership और Admin check लागू; bucket private तथा MIME/size limits सीमित।
- Production database पर कोई table, function, bucket या policy नहीं बनाया/बदला गया। ये migrations source-only हैं; PostgreSQL compile, migration-order execution, Storage policy behavior और customer/Admin JWT E2E अभी अंतिम consolidated testing चरण में होंगे।


## Electrician App — स्थायी ID/Order ID प्रदर्शन (14 नवम्बर 2026)
- Electrician dashboard profile में वास्तविक `electrician_profiles.id` UUID को `EL-<UUID>` के रूप में दिखाया गया है। यह मौजूदा server-generated primary key पर आधारित स्थायी पहचान है; कोई अनुमानित sequential number नहीं बनाया गया।
- हर job card में वास्तविक `service_bookings.id` UUID को `ORD-<UUID>` के रूप में दिखाया गया है।
- Payout history में भी वही Order ID दिखेगा, ताकि काम और भुगतान रिकॉर्ड का मिलान हो सके।
- Production schema की read-only जाँच में इन दोनों tables में अभी अलग sequential human-readable ID columns नहीं मिले; इसलिए UI मौजूदा वास्तविक UUIDs को prefix के साथ दिखाता है। Sequential numbering के लिए अलग approved schema migration और data backfill की आवश्यकता होगी; अभी कोई DB/production बदलाव नहीं किया गया।
- बदलाव source-only हैं; login, offer, timer, payout या mobile runtime परीक्षण अभी नहीं किया गया। अंतिम consolidated QA में जाँचा जाएगा।


## Electrician App — सुरक्षित KYC दस्तावेज़ जमा करना (14 नवम्बर 2026)
- Dashboard में पहचान प्रमाण, पता प्रमाण और कौशल प्रमाणपत्र के लिए अलग upload controls जोड़े। केवल PDF/JPEG/PNG और अधिकतम 5 MB client-side पर validate होता है; server RPC भी MIME, size, document type और user-owned storage path validate करता है।
- Upload private Storage bucket `srk-electrician-verification` में UID/document-type folder के अंदर random UUID filename के साथ होता है; public URL नहीं बनाया जाता और upsert बंद है।
- Upload के बाद `srk_electrician_submit_verification_document` RPC document metadata तथा audit event दर्ज करता है; `srk_electrician_list_my_verification_documents` से review status, Admin note और timestamps दिखते हैं। Failed metadata submission पर unreferenced uploaded object cleanup की कोशिश होती है।
- Read-only Production inspection से bucket private, 5 MB limit, PDF/JPEG/PNG allowlist, upload/read/delete storage policies और संबंधित RPC signatures सत्यापित हुए। KYC tables पर direct client SELECT policy उपलब्ध नहीं मिली; इसलिए frontend private object path सीधे पढ़ने या public URL बनाने की कोशिश नहीं करता। दस्तावेज़ preview/download के लिए अलग ownership-checked signed-URL backend endpoint अभी बाकी है।
- Static source checks: KYC UI, private bucket, upload RPC, status RPC, 5 MB check और no-public-URL checks PASS। Runtime upload/JWT/storage policy test अंतिम consolidated QA में बाकी; कोई live document upload या production schema change नहीं किया गया।
- ऐतिहासिक नोट: इस KYC UI के पहले संस्करण में electrician self-availability और live GPS controls उपलब्ध नहीं थे। बाद के 14 नवम्बर 2026 वाले Availability तथा Live Location sections में ये दोनों source-code सुविधाएँ जोड़ी गईं; migrations अभी भी Production पर लागू नहीं हैं.


## Electrician App — अपनी काम की उपलब्धता नियंत्रित करना (14 नवम्बर 2026)
- Dashboard में अलग Availability panel और दो स्पष्ट controls जोड़े: “काम के लिए उपलब्ध हूँ” तथा “अभी उपलब्ध नहीं हूँ”। यह Admin-controlled `active` और `verification_status` से अलग है; गैर-approved/Inactive पार्टनर availability toggle नहीं कर सकता।
- नई migration source `20261114310000_electrician_self_availability.sql`: `electrician_profiles.available_for_work` (default true), private-to-client audit table (RLS enabled, direct grants revoked) और authenticated, ownership-checked `srk_electrician_set_availability(boolean)` RPC।
- Offline करने पर उस इलेक्ट्रिशियन के unaccepted offers `declined` होते हैं और हर प्रभावित sequential queue अगले पात्र पार्टनर को तुरंत dispatch करने की कोशिश करती है। पहले से accepted assignments को नहीं छेड़ा जाता।
- Sequential dispatch migration `20261114210000_sequential_nearest_offer_dispatch.sql` के candidate eligibility, candidate re-check और offer response filters में `available_for_work=true` जोड़ा; इस प्रकार offline पार्टनर को नया offer नहीं मिलना चाहिए।
- Static verification: electrician inline JavaScript parse PASS; Availability UI/RPC/state wiring checks PASS; dispatch source में चारों eligibility checks updated।
- महत्वपूर्ण: दोनों migrations अभी source-only हैं और Production DB पर apply नहीं हुईं। Migration-order/PLpgSQL compile, concurrent offer acceptance बनाम offline race, RLS/RPC JWT behavior तथा वास्तविक dispatch tests अंतिम consolidated QA में बाकी हैं। कोई live offer या profile setting बदली नहीं गई।
- Live location sharing अभी implement नहीं है। मौजूदा `location_lat/lng` केवल electrician base/application और customer booking destination coordinates हैं; इन्हें live GPS मानकर दिखाना सुरक्षित नहीं होगा। Assigned/travelling अवस्था के लिए अलग time-stamped location table, ownership-checked RPC, customer read path और arrival/stop controls अगला विकास कार्य है।


## 2026-11-14 — Electrician live location sharing (source-only)
- Added migration `supabase/migrations/20261114320000_booking_scoped_live_electrician_location.sql`.
- Added a private booking-scoped live location table; direct Data API access is revoked and RLS is enabled.
- Added ownership-checked RPCs for electrician start/update/stop/status and customer read. Customer read is limited to the customer's own currently assigned booking and returns only fresh coordinates (maximum age 90 seconds).
- Electrician UI now requests GPS only after an explicit button tap and confirmation, requires browser location permission and GPS accuracy <=150m, throttles updates to about 12 seconds, supports stopping on arrival, and can resume GPS updates after reconnect/page reload.
- Customer booking UI polls every 15 seconds and renders a refreshed embedded Google Map plus directions link only while the booking is still in the assigned/travel stage.
- Database trigger clears active coordinates automatically when the booking leaves the assigned travel stage, is cancelled/completed, or the assigned electrician changes. A different newly assigned electrician can start a fresh location session; the previous electrician's stopped session cannot be resumed. Moving into work-start approval therefore stops tracking.
- Existing electrician base coordinates and customer destination coordinates are not reused as live GPS. No home/base coordinates are exposed.
- Static source checks still required. Migration and UI are source-only; not applied to Supabase and not deployed. No live GPS permission, real tracking session, customer visibility, trigger, or RLS/RPC runtime test has been performed. Final consolidated QA only.


## 14 नवम्बर 2026 — Electrician KYC निजी दस्तावेज़ Preview (source-only)
- Migration: `20261114330000_electrician_private_kyc_document_preview.sql`.
- नया authenticated RPC `srk_electrician_get_my_verification_document_path(uuid)` केवल उसी लॉगिन इलेक्ट्रिशियन के अपने KYC document का private storage path लौटाता है; दूसरे profile/document ID पर fail-closed।
- RPC path के बाद frontend private bucket की existing owner/Admin SELECT policy से 60-second signed URL बनाता है। कोई public URL या direct public bucket access नहीं।
- KYC सूची में पहले से मौजूद “दस्तावेज़ देखें” बटन अब preview flow से जुड़ा है; popup को user click के synchronous context में खोलकर signed URL आने पर navigate करता है।
- Read-only schema audit में private bucket, 5 MB PDF/JPEG/PNG limit, existing owner/Admin Storage SELECT policy और KYC metadata columns सत्यापित हुए।
- Static source checks और JS parse आगे verify होंगे। Migration source-only; Production पर apply नहीं हुई। वास्तविक signed URL generation, PDF/image preview, expiry, दूसरे user द्वारा ID guessing और Admin preview का end-to-end test अंतिम consolidated QA में बाकी।


## 14 नवम्बर 2026 — Admin KYC दस्तावेज़ Review Panel (source-only)
- Admin Dashboard में सभी जमा किए गए KYC दस्तावेज़ों की सूची, पार्टनर/इलाका, फ़ाइल metadata, upload/review समय और activity history दिखाई जाती है।
- Admin private Storage SELECT policy से 60-second signed preview खोल सकता है; कोई public file URL नहीं बनाया गया।
- Admin RPC `srk_admin_review_electrician_document` से approve, reject या needs_resubmission निर्णय; reject/resubmission के लिए कारण अनिवार्य। सफल निर्णय पर UI सूची refresh करता है।
- Admin list/review RPCs और private bucket/policy पहले से मौजूद होने की read-only schema inspection में पुष्टि की गई थी।
- Static JavaScript parse और source checks: नीचे दर्ज परिणाम। Production migration/deployment या live document review नहीं किया गया। वास्तविक Admin JWT, signed preview, status transition और electrician deactivation behavior का E2E test अंतिम संयुक्त QA में बाकी।


## 14 नवम्बर 2026 — Electrician स्वयं प्रोफ़ाइल नाम अपडेट (source-only)
- Electrician Dashboard के Profile card में display name edit field और save action जोड़ा।
- नई migration: `20261114340000_electrician_self_profile_name_edit.sql`.
- Authenticated RPC केवल `auth.uid()` से जुड़े अपने profile row (दोनों `user_id` और `auth_user_id` match) को lock करके `display_name` बदलता है। Name 2–80 characters और सीमित अक्षर/अंक/space/dot/apostrophe/hyphen नियम से validate होता है।
- हर वास्तविक बदलाव append-only profile-name event table में old/new name, actor और timestamp सहित दर्ज होता है; table पर RLS enabled और browser direct grants revoked।
- Phone, district, state, PIN, approved skills, rate tier, Active और verification status self-edit में शामिल नहीं हैं; ये सत्यापित/Admin-controlled रहेंगे।
- Migration/UI source-only हैं; Production में apply नहीं। JS syntax, SQL static review और actual JWT/row lock/audit event tests final consolidated QA में बाकी।


## 14 नवम्बर 2026 — Electrician Web Push Notifications (opt-in, source-only UI/SW)
- Electrician Dashboard में स्पष्ट opt-in controls जोड़े: इस फोन पर सूचनाएँ चालू करें और सूचनाएँ बंद करें। Notification permission केवल user के button tap पर माँगी जाती है; silent/automatic permission prompt नहीं।
- Existing active Supabase Edge Function `push-job-offer` (version 4) के public GET endpoint से केवल VAPID public key ली जाती है; VAPID private key, webhook secret और service-role key browser को नहीं दिए जाते।
- HTTPS/Web Push/Service Worker support, Admin-approved Active profile और logged-in user identity validate करने के बाद browser subscription बनती है और existing `srk_push_subscriptions` table में own `user_id` के साथ upsert होती है। Existing DB policy audit में SELECT/INSERT/UPDATE/DELETE सभी केवल `auth.uid()` की own row तक सीमित मिले; endpoint unique index भी मौजूद है।
- Unsubscribe पर browser subscription बंद करके उसी authenticated user + endpoint की DB row delete की जाती है। Unsupported browser, denied permission और provider/configuration failure के लिए स्पष्ट status text है।
- Root `sw.js` में push event से system notification display और notification click पर same-origin Electrician page खोलने का handler जोड़ा। Notification URL का origin validate होता है; बाहरी URL स्वीकार नहीं।
- Push notification में offer ID होने पर Electrician App उसी offer card तक scroll/highlight करता है; query parameter बाद में URL से हटता है।
- Read-only Production audit में existing `job_offers` trigger `private.srk_notify_job_offer_push()` से `push-job-offer` Edge Function को webhook भेजता है; function currently ACTIVE version 4 है। Function source inspection में केवल नए offered INSERT और offered से non-accepted terminal update पर push send/close behavior दिखा। कोई function deploy/update नहीं किया।
- Static verification: Electrician inline JS parse PASS; Service Worker JS parse PASS; opt-in permission, public-key fetch, own subscription upsert/delete, push event, same-origin click, offer-focus wiring checks PASS.
- सीमाएँ: source branch में कोई push permission/subscription/notification manually execute नहीं की। Browser notification permission, Android Chrome service worker lifecycle, real push delivery/click, endpoint expiry cleanup और provider VAPID configuration का runtime test अंतिम consolidated QA में बाकी। Production Edge Function/DB/Push subscriptions में कोई बदलाव नहीं।


## 14 नवम्बर 2026 — Electrician निजी सहायता / Admin Support Inbox (source-only)
- Electrician Dashboard में निजी सहायता केंद्र जोड़ा: Booking/काम, कमाई/भुगतान/निकासी, KYC/अकाउंट, ऐप तकनीकी समस्या, ग्राहक सुरक्षा/व्यवहार और अन्य श्रेणियाँ।
- इलेक्ट्रिशियन विषय (4–120 अक्षर), विवरण (20–4000 अक्षर) और वैकल्पिक Booking UUID के साथ सहायता अनुरोध बना सकता है; अपने अनुरोधों की स्थिति और Admin बातचीत देख सकता है तथा खुले अनुरोध पर जवाब दे सकता है।
- नई migration `20261114350000_electrician_support_tickets_and_admin_inbox.sql`: private ticket/message tables, RLS enabled, direct browser table grants revoked; सभी कार्रवाइयाँ authenticated SECURITY DEFINER RPCs से।
- Ticket creation में profile identity दोनों `user_id` और `auth_user_id` से verify होती है। वैकल्पिक Booking ID तभी स्वीकार होती है जब `service_bookings.assigned_electrician_id` उसी electrician profile ID से मेल खाए। Live schema audit के आधार पर वास्तविक column name ठीक किया।
- प्रति इलेक्ट्रिशियन 24 घंटे में अधिकतम 10 नए tickets की server-side सीमा जोड़ी।
- Admin-only RPCs `is_srk_admin()` से protected: inbox list, message history, reply और status/admin-note update। Customer support tables/threads से अलग electrician-only private inbox है।
- Admin Dashboard में अलग Electrician Support Inbox, status update और reply thread जोड़ा; Admin `loadAll()` refresh में inbox शामिल।
- Static verification: Electrician और Admin JavaScript syntax parse PASS; दोनों pages पर duplicate element IDs नहीं; RPC wiring, Admin gate, owner filter, private table grants और वास्तविक booking ownership column checks PASS।
- Source-only: migration Production में apply नहीं हुई; वास्तविक ticket creation, unauthorized Booking ID rejection, Admin JWT access, status update/reply और दो अकाउंट के बीच private data isolation का runtime test अंतिम संयुक्त QA में बाकी।


## 14 नवम्बर 2026 — Electrician कमाई और पेआउट स्क्रीन सुधार (source-only)
- Electrician Earnings में ग्राहक से प्राप्त राशि, कंपनी कमीशन, कुल देय कमाई और Admin द्वारा वास्तविक बैंक/UPI पेआउट को अलग-अलग दिखाया।
- पेआउट इतिहास में Order ID, राशि, Admin दर्ज भुगतान स्थिति, भुगतान माध्यम, UTR/reference और तारीख दिखाई जाती है।
- पहले छूटी हुई `blocked` स्थिति अब स्पष्ट “पेआउट रोका गया — Admin से संपर्क करें” संदेश और blocked राशि के साथ दिखाई जाती है; pending, paid और refunded स्थितियों के हिंदी लेबल भी स्पष्ट किए।
- बैंक/UPI भुगतान चालू नहीं किया; Route onboarding/approval के बिना कोई self-withdrawal या live transfer विकल्प नहीं जोड़ा।
- Read-only DB audit: payout status constraint में `pending/paid/blocked/refunded`; electrician SELECT policy केवल उसी profile के `user_id=auth.uid()` पर, Admin अलग से देख सकता है; Route transfer table पर anon/authenticated client API deny policy मौजूद। इसलिए Route transfer table सीधे app से पढ़ने की कोशिश नहीं की।
- Static JavaScript syntax parse PASS; HTML IDs duplicate नहीं।
- Source-only; वास्तविक payout sample/status rendering और mobile layout अंतिम संयुक्त QA में बाकी।

## 2026-11-14 — Electrician Wallet और बैंक लिंक स्थिति की स्पष्टता
- `electrician.html` के `loadPartnerWallet()` को बेहतर किया।
- वॉलेट सारांश, बैंक/UPI लिंक और लेजर हिस्ट्री के लिए अलग-अलग error handling जोड़ी; डेटा लोड न होने पर अब गलत “कोई रिकॉर्ड नहीं” नहीं दिखेगा।
- बैंक लिंक में केवल masked account last-4 और masked IFSC दिखाने की व्यवस्था; प्राथमिक बैंक लिंक और verification status को स्पष्ट किया।
- हाल के लेजर रिकॉर्ड में जमा/निकासी दिशा, स्थिति, विवरण, reference और तारीख दिखाई जाएगी।
- वॉलेट balance को साफ तौर पर internal ledger balance बताया; इसे बैंक भुगतान का प्रमाण नहीं बताया।
- बैंक जोड़ना और वास्तविक निकासी अभी भी बंद है; Route onboarding/verification/Admin अनुमति से पहले कोई transfer action नहीं जोड़ा।
- Static source checks: wallet function, bank/ledger error handling, masked IFSC, primary account, transaction references और disabled withdrawal copy — PASS. Inline JavaScript syntax parse — PASS.
- यह source-only बदलाव है। वास्तविक bank-link/ledger rendering, अलग-अलग RLS permissions और mobile layout की जाँच अंतिम consolidated QA में होगी; कोई migration, production setting या live payout नहीं बदला।

## 2026-11-14 — SRK प्लेटफॉर्म में Schedule / Appointment विकल्प हटाया
- ग्राहक की नई बुकिंग स्क्रीन से बुकिंग तारीख और पसंदीदा समय के दोनों input पूरी तरह हटाए।
- ग्राहक की My Bookings सूची से पुराने scheduled date/time की UI display हटाई; पुराने records के अन्य विवरण सुरक्षित हैं।
- Electrician App के offer cards से तारीख/समय display हटाया; dashboard की बाकी rendering को restore करके syntax जाँचा।
- Booking API अब `preferred_date` और `preferred_time` अनिवार्य नहीं मानती; नए अनुरोधों के लिए legacy columns में NULL रखती है और fingerprint में schedule fields शामिल नहीं करती।
- Admin booking data query से भी schedule columns हटाए; किसी Admin schedule workflow का निर्माण नहीं किया।
- Static verification: Customer booking UI में date/time inputs नहीं, Customer history में schedule display नहीं, Electrician offer cards में schedule display नहीं; booking/electrician/admin inline JavaScript parse PASS.
- Source-only बदलाव। कोई production deploy, database migration या live booking नहीं की। वास्तविक deployed behavior अंतिम consolidated QA में जाँचा जाएगा।

## 2026-11-14 — Electrician Logout पर Live GPS सुरक्षा
- Electrician App के Logout flow को सुरक्षित किया।
- Logout से पहले browser के सभी सक्रिय geolocation watches रोके जाते हैं।
- हर सक्रिय booking के लिए `srk_electrician_stop_live_location` RPC सर्वर पर चलाया जाता है।
- सर्वर से Location Stop की पुष्टि मिलने के बाद ही watch state हटती है और Supabase sign-out आगे बढ़ता है।
- यदि किसी booking का stop request विफल हो, logout रोक दिया जाता है और उपयोगकर्ता को दोबारा प्रयास करने का संदेश मिलता है; pending booking IDs retry के लिए रखी जाती हैं।
- Static verification: GPS watch clear, server stop RPC, stop confirmation before sign-out, retry state retention — PASS. Electrician inline JavaScript syntax — PASS.
- Source-only बदलाव; कोई live GPS session, production data या deployment नहीं छुआ। वास्तविक GPS/logout behavior अंतिम consolidated QA में जाँचा जाएगा।

## 2026-11-14 — Electrician Support Messaging Reliability
- सहायता अनुरोध बनाने और जवाब भेजने पर duplicate-submit guards जोड़े।
- अनुरोध/जवाब भेजते समय संबंधित बटन disable और स्पष्ट busy label दिखाता है; प्रक्रिया पूरी होने पर फिर enable होता है।
- तेज़ी से अलग-अलग सहायता बातचीत खोलने पर पुराने धीमे network response को नए thread पर overwrite करने से रोका।
- Error संदेशों में raw backend exception text दिखाने के बजाय सुरक्षित, उपयोगकर्ता-समझने योग्य संदेश रखे।
- Static checks: duplicate guards, disabled states, stale-thread protection, safe errors, no schedule UI — PASS. Electrician inline JavaScript syntax — PASS.
- Source-only; कोई support ticket/message या production DB परिवर्तन नहीं किया। वास्तविक multi-account isolation और RPC runtime परीक्षण अंतिम consolidated QA में होंगे।

## 2026-11-14 — Admin Electrician Support Inbox Reliability
- Admin सहायता Inbox में एक साथ दो list-load requests चलने से रोका।
- Ticket status/Admin note save पर प्रति-ticket duplicate-submit guard और busy button state जोड़ी।
- Admin reply पर duplicate-submit guard और busy state जोड़ी।
- तेजी से अलग-अलग ticket threads खोलने पर पुराने response से वर्तमान thread overwrite नहीं होगा।
- Inbox और reply के error संदेशों से raw backend details हटाकर सुरक्षित, स्पष्ट Hindi संदेश रखे।
- Static checks: load/save/reply guards, stale-thread protection, safe errors — PASS. Admin inline JavaScript syntax — PASS.
- Source-only; कोई वास्तविक ticket, status या message update नहीं किया। Admin role authorization और two-account isolation का runtime test अंतिम consolidated QA में होगा।

## 2026-11-14 — Customer Support Thread and Attachment Reliability
- Customer support reply भेजने पर duplicate-submit guard और busy state जोड़ी।
- शिकायत सूची के concurrent duplicate loads रोके।
- अलग-अलग शिकायतें तेजी से खोलने पर पुराना response वर्तमान बातचीत को overwrite नहीं करेगा।
- Attachment signed URLs अब हर request के local result में रखे जाते हैं; stale thread की फ़ाइलें दूसरे thread में नहीं मिलेंगी।
- Customer support conversation loading errors को स्पष्ट और सुरक्षित Hindi संदेशों में बदला।
- पहले से मौजूद नई शिकायत create-button guard कायम है।
- Static checks: message duplicate guard, list-load guard, stale-thread protection, local attachment result handling, create guard — PASS. booking.html inline JavaScript syntax — PASS.
- Source-only; कोई वास्तविक ग्राहक शिकायत, संदेश या attachment upload नहीं किया। Customer/Admin account isolation, Storage signed URLs और partial-upload recovery का runtime परीक्षण अंतिम consolidated QA में होगा।

## 2026-11-14 — Admin Electrician Payout Action Reliability
- Admin payout list में concurrent duplicate load guard और स्पष्ट loading/error state जोड़ी।
- प्रत्येक payout पर अलग duplicate-action guard और busy button state जोड़ी।
- भुगतान दर्ज करने से पहले UPI/Bank method validation, वास्तविक UTR/reference की न्यूनतम लंबाई और अधिकतम field length जाँची जाती है।
- UI दोबारा स्पष्ट करता है कि Paid केवल वास्तविक बैंक/UPI transfer के बाद ही दर्ज करें।
- Raw backend errors UI में दिखाने के बजाय सुरक्षित Hindi संदेश दिए।
- Static checks: load guard, per-payout duplicate guard, method/reference validation, busy state, safe error and actual-transfer confirmation — PASS. Admin inline JavaScript syntax — PASS.
- Source-only; कोई payout status, बैंक ट्रांसफर या wallet ledger नहीं बदला। वास्तविक Admin RPC permission, duplicate race और payout accounting का runtime test अंतिम consolidated QA में होगा।

## 2026-11-14 — Razorpay Create-Order Re-read Consistency Fix
- पेमेंट ऑर्डर lock लेने के बाद booking को दोबारा पढ़ने वाले SELECT में `selected_category` छूट गया था। इससे नए category-based bookings का payment breakdown legacy quote path में जा सकता था।
- Re-read SELECT में `selected_category` वापस शामिल किया, ताकि initial read और lock के बाद की read दोनों समान payment-path decision data रखें।
- Static verification: JavaScript syntax PASS; दोनों booking SELECT statements में `selected_category` मौजूद — PASS.
- Source-only; Razorpay order/payment या database record नहीं बनाया/बदला। वास्तविक order-lock race, amount validation और captured-payment reconciliation अंतिम consolidated QA में जाँचे जाएँगे।

## 2026-11-14 — New Category Booking Electrician Payout Reconciliation
- Read-only Supabase audit में मौजूदा payout trigger और Admin payout RPC की जाँच की। वे केवल legacy `quote_status='approved'` तथा `service_charge + materials_amount` मॉडल पर निर्भर थे; नए customer-approved server-timed category bookings immutable labour bill और अलग cancellation-fee accounting इस्तेमाल करते हैं।
- नई source migration `20261114360000_new_category_electrician_payout_reconciliation.sql` जोड़ी।
- New-category payout immutable labour bill और assigned electrician से सत्यापित होगा; cancellation fee SRK की रहेगी और electrician earnings/commission base में नहीं जुड़ेगी। अभी materials amount शून्य रखा गया है क्योंकि materials का अलग itemized collection/payout integration इस flow में शामिल नहीं है।
- Trigger reserved/settled cancellation-fee items दोनों को payment-trigger timing में गिनता है, क्योंकि online/cash payment RPC पहले booking को Paid करता है और उसके बाद fee items settle करता है।
- Admin Paid RPC booking-first lock, Admin authorization, verified payment evidence, immutable bill, electrician assignment और payout arithmetic को दोबारा जाँचता है। Legacy quote payout path सुरक्षित रखा है।
- Static source checks: category branch, immutable bill, cancellation-fee separation, pre-settlement fee timing, Admin gate, lock order, payment evidence, legacy path and function grants — PASS.
- Read-only production schema/function inspection हुआ; कोई production SQL, payout status, wallet, bank transfer या payment data नहीं बदला। Migration अभी apply नहीं हुई। SQL runtime compilation, trigger ordering, cash/online payout creation, refund race और Admin payout execution अंतिम consolidated QA में जाँचे जाएँगे।

## 2026-11-14 — Payment Flow Cross-File Static Verification
- `create-order.js`, `verify-payment.js`, `razorpay-webhook.js` और Admin booking/payment script को एक साथ दोबारा पढ़कर cross-check किया।
- नई category booking के लिए Razorpay order amount server-side labour + reserved cancellation fees breakdown से बनता है; browser-provided amount पर भरोसा नहीं किया जाता।
- Verify endpoint HMAC signature, provider captured status, INR currency, exact paise amount और customer OTP session जाँचता है; settlement service-role RPC से होता है।
- Webhook path भी exact amount और completed booking जाँचकर उसी idempotent settlement RPC को call करता है।
- Admin manual settlement में नई category booking के लिए केवल वास्तविक Cash receipt RPC उपलब्ध है; online payment Razorpay verification से ही।
- Static JavaScript syntax: create-order, verify-payment, Razorpay webhook और Admin scripts — PASS. सभी relevant payment reads में `selected_category` मौजूद — PASS.
- यह source inspection/static verification है; कोई live Razorpay payment, webhook event, cash receipt या database update नहीं किया गया। End-to-end payment, duplicate webhook, captured-payment reconciliation और refund race final consolidated QA में होंगे।

## 2026-11-14 — Electrician Payout Reconciliation Hardening
- Immutable labour bill की वास्तविक schema definition जाँची: `labour_amount_paise` और `labour_amount` दोनों मौजूद हैं; payout गणना के लिए रुपये वाला `labour_amount` field सही है।
- Production schema का read-only निरीक्षण: payout table के सभी referenced columns, payout status/method constraints और मौजूदा Admin RPC signature migration से मेल खाते हैं। Existing payout trigger booking update पर चलता है; कोई production function या trigger बदला नहीं।
- Migration में Admin payout settlement अब Razorpay payment ID को booking payment ID से exact match करता है; manual cash entry तभी स्वीकार होती है जब booking payment ID NULL हो और matching receipt मौजूद हो।
- Admin payout mark-paid path अब किसी भी अभी-reserved cancellation fee item को अस्वीकार करता है; payout amount में केवल settled fee शामिल होती है। इससे अधूरी fee settlement के बीच electrician payout mark-paid नहीं हो सकता।
- Static source checks PASS: exact payment ID match, reserved-fee rejection, settled-fee-only accounting, booking-first lock order, Admin authorization, legacy quote path, function signature, immutable labour amount field।
- Source-only change; migration अभी apply नहीं की गई। SQL runtime compile, concurrency, cash/online settlement और refund/payout integration final consolidated QA में होंगे।

## 2026-11-14 — Admin / Electrician UI Safety Sweep
- Electrician profile status UI में database से आने वाला `verification_status` अब HTML render से पहले escape होता है; पहले यह field template में सीधे insert हो रहा था।
- Admin Wallet Overview की backend error को अब `innerHTML` में raw डालने के बजाय सुरक्षित generic Hindi `textContent` message से दिखाया जाता है।
- Customer Booking, Electrician, Admin और payment/serverless JavaScript files की syntax जाँच PASS।
- Admin, Electrician और Customer booking UI में Schedule / Appointment / preferred date-time विकल्प या शब्द नहीं मिले। Legacy API में पुरानी date/time columns को NULL रखने की backward-compatibility logic बनी हुई है; Netlify worker का cron केवल offer expiry/dispatch backend प्रक्रिया है, customer scheduling feature नहीं।
- यह source-only UI hardening है; live account, booking या payment data नहीं बदला।

## 2026-11-14 — Electrician Offer Accept / Decline Duplicate-Action Protection
- Electrician offer के Accept और Decline buttons अब एक ही offer पर concurrent/double submission रोकते हैं।
- Click के बाद उस offer के दोनों action buttons disable होते हैं और clicked button पर busy label दिखता है।
- केवल `accepted` और `declined` response values स्वीकार की जाती हैं; सफल RPC के बाद dashboard refresh होता है।
- Failure पर raw backend error नहीं दिखता; सुरक्षित Hindi संदेश दिया जाता है और buttons retry के लिए restore होते हैं।
- Electrician inline JavaScript syntax PASS; duplicate guard, busy state, response validation, safe failure और button wiring PASS।
- Source-only; कोई वास्तविक offer स्वीकार/अस्वीकार नहीं किया गया। Multi-electrician offer race और actual assignment runtime test अंतिम संयुक्त QA में होंगे।


## 2026-11-14 — Admin Booking Action Duplicate-Submission Guard
- Admin booking status/quote save action में per-booking in-flight guard जोड़ा; एक ही booking पर तेज़ double-click या concurrent submission दूसरा save शुरू नहीं करेगा।
- Admin offer-dispatch action में per-booking guard जोड़ा; एक ही booking पर duplicate offer-dispatch request रोकता है।
- Existing business validations, cancellation restriction, payment checks और RPC/table workflows जस के तस रखे गए।
- Source verification में दोनों guards और wrapper wiring मौजूद — PASS; Admin inline JavaScript syntax — PASS.
- Source-only; कोई booking status, offer, assignment या payment record बदला नहीं गया।

## 2026-11-14 — Admin Electrician Activation / Rate-Tier Controls Hardening
- Admin द्वारा electrician की rate tier approve करने के action में per-electrician duplicate-request guard जोड़ा।
- Rate tier को चार प्रकाशित commercial tier keys की allowlist से validate किया; arbitrary value RPC तक नहीं भेजी जाएगी।
- Active/Inactive toggle में per-electrician duplicate guard, boolean validation और action से पहले स्पष्ट confirmation जोड़ा।
- Backend raw error को सीधे alert में दिखाने के बजाय सुरक्षित Hindi error message दिया।
- Admin inline JavaScript syntax PASS; rate-tier allowlist, दोनों action guards और safe error handling source verification PASS।
- Source-only; किसी electrician का वास्तविक KYC, rate tier या Active status बदला नहीं गया।

## 2026-11-14 — Admin Cancellation Decision Safety
- Cancellation request पर Admin decision के लिए प्रति-request duplicate-submit guard जोड़ा।
- Decision केवल `approved` या `rejected`; approved स्थिति केवल `not_departed`, `en_route`, `arrived` allowlist से स्वीकार होगी।
- Existing fee evidence और Admin reason length validation कायम रखी; backend error अब raw alert में नहीं दिखता।
- Admin inline JavaScript syntax PASS; decision/stage allowlists, duplicate guard और safe error handling source verification PASS।
- Source-only; कोई cancellation request approve/reject नहीं हुई और कोई booking/fee/ledger record नहीं बदला।

## 2026-11-14 — Admin Booking Save / Electrician Activation Hardening
- Admin booking status केवल अनुमत states (`new`, `confirmed`, `assigned`, `in_progress`, `completed`) में स्वीकार; cancellation dedicated Admin workflow में ही रहेगा।
- Booking update और electrician Active/Inactive update के बाद affected row लौटने की पुष्टि; silent zero-row update को success नहीं माना जाएगा।
- Electrician को Active करने से पहले KYC Approved और मान्य approved rate tier जाँचा जाता है।
- Raw backend errors हटाकर सुरक्षित Hindi messages; मौजूदा duplicate-action guard कायम।
- Admin inline JavaScript syntax PASS; allowlist, KYC/tier gate और returned-row checks source verification PASS।
- Read-only production schema audit: Admin-only RLS UPDATE policies मौजूद; booking status/work approval और audit triggers मौजूद। कोई schema/production परिवर्तन नहीं।
- Source-only; कोई booking status, payment, electrician Active status या KYC record नहीं बदला।

## 2026-11-14 — Admin Offer Dispatch Compatibility Guard
- Admin booking list में customer-selected category/tier fields पढ़े जाते हैं।
- नई category booking को legacy `srk_admin_offer_booking` RPC से manually dispatch करने पर रोक लगाई; legacy RPC category-tier, `available_for_work` और nearest-first sequential eligibility लागू नहीं करता।
- Legacy-format booking के लिए ही पुराने Admin offer RPC की अनुमति; booking state/assignment पुनः पढ़कर जाँची जाती है, duplicate guard कायम और raw backend errors सुरक्षित संदेश में बदले।
- Read-only production function audit ने पुष्टि की कि वर्तमान deployed `srk_admin_offer_booking` legacy broad matching करता है; sequential nearest-first dispatcher केवल feature-branch migration `20261114210000...` में है और production DB में अभी लागू नहीं है।
- Admin inline JavaScript syntax PASS; category guard और selection read source verification PASS।
- Source-only; कोई offer, booking या electrician assignment नहीं बदला। Production RPC/migration नहीं बदली।

## 2026-11-14 — Electrician Offer Details / Expiry UI Integration
- `srk_get_my_offer_details()` के लिए source-only migration `20261114370000...` जोड़ी: immediate booking fields, customer-selected category/tier/duration/estimate, start/completion approval states और offer expiry लौटाएगा। Schedule date/time fields RPC से हटाए गए।
- ग्राहक का नाम, मोबाइल, पता और location केवल उसी समय लौटेंगे जब booking उस electrician profile को assign हो चुकी हो और booking assigned/work stage में हो; unaccepted offer में private customer details NULL रहेंगी।
- Electrician App में offer status का हिंदी label और server expiry deadline दिखाई जाती है।
- Electrician inline JavaScript syntax PASS; expiry/status UI और schedule-field absence source checks PASS।
- Read-only production schema audit ने पुष्टि की कि वर्तमान deployed offer-details RPC में नई booking fields/expiry नहीं हैं; migration केवल feature branch में है और लागू नहीं की गई।
- Source-only; कोई offer accept/decline, booking assignment, customer contact exposure या production DB परिवर्तन नहीं हुआ। Runtime RPC output, expiry worker cadence और sequential dispatch integration final consolidated QA में जाँचे जाएँगे।
- Follow-up static shape check: RPC के 28 declared return fields और SELECT expressions का क्रम मिलाया; assigned-only `location_lat` तथा `location_lng` दोनों शामिल किए। SQL compile अभी migration rollout/final QA के लिए लंबित है।

## 2026-11-14 — Electrician Offer Matching Display Refinement
- Electrician offer card में PIN-code और district match को हिंदी में दिखाया; raw backend key को UI में नहीं दिखाया जाता।
- Customer-selected category booking में estimated labour amount अब immutable selection snapshot के `estimated_labour_paise` से ₹ में दिखेगा; legacy booking के लिए पुराना quote display fallback रखा। Materials को labour estimate में नहीं जोड़ा।
- Offer expiry/status UI और immediate-only booking display के साथ inline JavaScript syntax PASS।
- Source-only; वास्तविक offer, booking, assignment, payment या production database नहीं बदला।

## 2026-11-14 — Sequential Dispatch PIN-to-District Fallback Hardening
- Sequential dispatcher migration की static review में एक edge case मिला: यदि booking बनते समय PIN-code candidates मौजूद हों, लेकिन वे बाद में offline/inactive हो जाएँ या सभी offer decline/expire हों, तो पहले version में district candidates की सूची उपलब्ध नहीं थी।
- Migration को बदला: जब exact-tier PIN candidates हों, candidate queue में पहले सभी PIN matches (nearest-first), फिर उसी state/district के non-PIN matches (nearest-first) snapshot किए जाते हैं। हर candidate का वास्तविक match level अलग रखा जाता है। इसलिए PIN queue के skip/decline/expiry के बाद district fallback संभव है; exact selected tier, KYC/approval और availability checks हर offer dispatch पर फिर से होते हैं।
- यदि PIN candidate मौजूद नहीं है तो district-only queue बनती है। यदि PIN candidates हैं, तो district queue उनसे पहले नहीं भेजी जाएगी।
- Netlify expiry worker और `netlify.toml` का static inspection: worker हर मिनट scheduled है, server-side service-role key से केवल `srk_expire_and_advance_booking_offers` RPC call करता है, 10-second timeout और safe error responses हैं। कोई secret source में नहीं रखा गया।
- Read-only production schema audit: वर्तमान deployed schema में नए category/tier columns और `job_offers.expires_at` अभी नहीं हैं; यह पुष्टि करता है कि sequential dispatch migration feature branch source-only है और production पर apply नहीं हुई।
- कोई migration apply, deploy, booking/offer/assignment या live data परिवर्तन नहीं किया। SQL runtime compile, Netlify scheduled execution, concurrent accept/expiry और full dispatch lifecycle अंतिम consolidated QA में होंगे।

## 2026-11-14 — Electrician Offer Expiry Response UX
- Offer response RPC का expired branch `success:false` के साथ `code='offer_expired'` और अगले dispatch का परिणाम लौटाता है। पहले UI इसे सामान्य failure मानकर dashboard refresh नहीं करता था।
- Electrician response handler अब इस विशिष्ट expiry result को अलग पहचानता है, अगले offer भेजे जाने/न मिलने का स्पष्ट Hindi संदेश दिखाता है और dashboard refresh करता है। अन्य unexpected response अब भी success नहीं माना जाता।
- Static source inspection: RPC call, expiry code branch, next-offer result handling, refresh और success allowlist मौजूद — PASS।
- Source-only; कोई offer accept/decline, assignment या database record नहीं बदला। वास्तविक expiry/response race अंतिम consolidated QA में जाँची जाएगी।

## 2026-11-14 — Admin-Approved Electrician Relocation / Operating Area
- Electrician App में “मेरा काम करने का क्षेत्र बदलें” UI जोड़ा: नया राज्य, जिला/शहर, छह अंकों का PIN और कारण देकर relocation request भेजी जा सकती है। Electrician अपनी request history और Admin का निर्णय देख सकता है; एक pending request रहते हुए duplicate request रोकने के लिए UI और backend guard हैं।
- Admin Panel में relocation approval inbox जोड़ा: पुराना और नया operating area, PIN, request reason देखकर Admin approve या reject कर सकता है। Rejection पर कम से कम पाँच अक्षरों का कारण अनिवार्य है।
- नई source-only migration `20261114220000_admin_approved_electrician_relocation.sql`: private request table, per-electrician single-pending constraint, authenticated electrician request/history RPCs और Admin-only list/review RPCs।
- Approval पर `electrician_profiles.state/district/pincode` नया operating area बनता है; पुराने operating area को उसी profile पर बंद कर दिया जाता है। मूल electrician application/KYC address अलग और अपरिवर्तित रहता है। Accepted bookings/assignments नहीं छेड़े जाते; पुराने क्षेत्र के unaccepted offers बंद करके dispatch queue आगे बढ़ाई जाती है।
- अतिरिक्त migration `20261114230000_recheck_electrician_current_area_before_offer.sql` dispatch के समय candidate का वर्तमान state/district फिर जाँचती है, ताकि relocation से पहले बने पुराने candidate snapshots नए जिले की बुकिंग न पा सकें।
- Electrician और Admin inline JavaScript syntax checks PASS। Migration/function definitions और source wiring static review में मौजूद हैं।
- **सीमाएँ:** ये source-only changes हैं। कोई Supabase migration apply नहीं की गई, कोई electrician relocation request/approval वास्तविक रूप से नहीं किया गया, और कोई production profile/booking/offer बदला नहीं गया। SQL runtime compile, Admin RPC authorization/RLS negative tests, relocation के बाद dispatch/old-queue race और full end-to-end QA final consolidated testing में बाकी हैं।

## 2026-11-14 — Electrician OTP-Verified Mobile Update + Admin Final Approval
- Electrician App में “रजिस्टर्ड मोबाइल नंबर अपडेट करें” सेक्शन जोड़ा: नया भारतीय मोबाइल नंबर और बदलाव का कारण भरकर OTP भेजने का अनुरोध; 6-अंकों का OTP सत्यापित होने के बाद ही रिक्वेस्ट Admin queue में जाती है। OTP की समय-सीमा 5 मिनट, अधिकतम 5 गलत प्रयास, 60-सेकंड resend guard और एक समय में एक खुली रिक्वेस्ट रखी गई है।
- Admin Panel में OTP-सत्यापित रिक्वेस्ट inbox जोड़ा: इलेक्ट्रिशियन का नाम/प्रोफ़ाइल ID, पुराना नंबर, नया सत्यापित नंबर, कारण और सत्यापन समय दिखता है। Admin जाँचकर Approve या कारण सहित Reject कर सकता है।
- नई migration `20261114380000_electrician_phone_change_admin_approval.sql`: अनुरोध/स्थिति/audit metadata, OTP hash (plain OTP नहीं), request ownership, duplicate-open-request और unique pending new-number guard, rate limits, expiry, Admin review और profile sync RPCs जोड़े।
- नई Edge Function `supabase/functions/electrician-phone-change/index.ts`: authenticated caller की पहचान server-side verify करती है; OTP server-side generate/hash करके 2Factor SMS provider से नए नंबर पर भेजती है; केवल सही OTP के बाद Admin inbox में request आती है। Admin approval के समय Supabase Auth phone और electrician profile phone को sync करने की कोशिश की जाती है; profile sync fail होने पर Auth phone rollback का प्रयास और सुरक्षित error state रखी जाती है।
- Read-only Supabase schema inspection से `electrician_profiles.user_id/auth_user_id/display_name/phone` और `srk_admin_users.user_id` columns की मौजूदगी की पुष्टि हुई। Electrician और Admin inline JavaScript syntax checks PASS।
- **महत्वपूर्ण सीमाएँ:** यह feature अभी GitHub feature branch पर source-only है। Migration apply नहीं की गई, Edge Function deploy नहीं की गई, SMS provider secret `2FACTOR_API_KEY` configure/verify नहीं किया गया और कोई वास्तविक OTP/SMS या Admin approval नहीं किया गया। SMS provider template/route, Edge Function deployment, SQL runtime compilation, Admin authorization negative tests, duplicate/expiry/OTP retry tests, Auth/profile rollback और end-to-end testing अंतिम consolidated QA में बाकी हैं। Production Auth नंबर, electrician profile या किसी live account में बदलाव नहीं किया गया।


## 2026-11-14 — Phone Change Migration SQL Syntax Correction
- OTP-verified phone update migration की deeper PL/pgSQL review में Admin claim RPC के declaration block में दूसरा DECLARE keyword मिला, जो function compile को रोक सकता था।
- इसे एक वैध DECLARE block में समेटा; दोबारा GitHub से migration fetch करके पुष्टि की कि malformed repeated declaration pattern अब नहीं है।
- यह केवल source correction है। वास्तविक PostgreSQL compile/execute अभी नहीं हुआ; वह final consolidated QA में रहेगा। कोई migration apply, Edge Function deploy, SMS या live account change नहीं हुआ।


## 2026-11-14 — Phone Change OTP Expiry Input Validation Hardening
- OTP prepare RPC की validation में NULL expiry timestamp का edge case मिला: SQL में NULL comparison अपने-आप invalid condition नहीं बनता।
- अब `p_otp_expires_at IS NULL` को स्पष्ट रूप से reject किया जाता है; 5-minute application expiry और database की maximum 6-minute bound कायम है।
- GitHub से migration दोबारा fetch करके source correction सत्यापित की। यह static source review है; PostgreSQL runtime compilation/tests अभी अंतिम consolidated QA में होंगे। कोई migration apply, SMS या live account change नहीं किया।


## 2026-11-14 — Expired OTP Request Retry Handling
- Phone-change flow की source review में मिला कि यदि OTP 5 मिनट बाद समाप्त हो जाए और इलेक्ट्रिशियन ऐप दोबारा न खोले, तो पुरानी `otp_pending` रिक्वेस्ट नई रिक्वेस्ट को रोक सकती थी।
- अब नई रिक्वेस्ट तैयार करते समय उसी इलेक्ट्रिशियन की समाप्त/NULL-expiry OTP रिक्वेस्ट पहले `expired` की जाती है और OTP hash साफ किया जाता है; फिर pending-request guard चलता है।
- Migration को दोबारा fetch करके source change सत्यापित किया। PostgreSQL runtime compile/test, SMS provider verification और E2E अभी final consolidated QA में हैं। कोई migration apply या SMS नहीं भेजा गया।


## 2026-11-14 — Relocation-Aware Dispatch Metadata Correction
- Sequential dispatch और relocation recheck migration की cross-review में मिला कि पुरानी candidate snapshot का `match_level` और दूरी relocation के बाद stale रह सकते थे। Relocation coordinates साफ करता है, इसलिए पुराने coordinates से दूरी दिखाना गलत होता।
- `20261114230000_recheck_electrician_current_area_before_offer.sql` में dispatch समय electrician का वर्तमान profile दोबारा पढ़कर exact PIN बनाम district match label फिर calculate किया जाता है। दूरी केवल वर्तमान booking/electrician coordinates उपलब्ध होने पर पुनर्गणित होती है; relocation के बाद cleared coordinates से पुरानी दूरी नहीं लौटेगी।
- GitHub से migration दोबारा fetch करके source change सत्यापित किया। PostgreSQL compile, concurrent dispatch/relocation tests और runtime QA final consolidated phase में बाकी हैं। कोई migration apply या live booking/offer/profile update नहीं हुआ।


### 2026-11-14 — Electrician phone-change approval stale-state guard
- Phone-change Admin approval claim में अतिरिक्त consistency check जोड़ा: OTP request बनने के बाद यदि Auth login phone या electrician profile phone किसी अन्य प्रक्रिया से बदल गया हो, तो Admin approval claim अब रुक जाएगा; पुरानी request के आधार पर नया नंबर overwrite नहीं होगा। दोनों मौजूदा नंबरों का normalized digits के आधार पर request के captured old phone से मिलान आवश्यक है।
- Electrician phone-change history RPC में NULL OTP expiry को भी expired माना जाएगा, ताकि malformed/legacy OTP-pending row अनिश्चितकाल तक लंबित न रहे।
- यह केवल source change है। Migration लागू नहीं हुई, Edge Function deploy नहीं हुई, SMS/OTP या वास्तविक Admin approval नहीं किया गया। SQL compilation/runtime, concurrency, Auth/profile synchronization और rollback tests अंतिम consolidated QA में बाकी हैं।
- Commit: `c59588bc3d1c7e7bc2d505aafb1f6965ea0385f7`.


### 2026-11-14 — Phone-change partial-sync recovery
- Phone-change Admin claim को recovery-safe बनाया: यदि Auth login phone या electrician profile phone में से कोई एक Auth update/finalize के बीच आंशिक रूप से नए नंबर पर पहुँच चुका हो, तो Admin उसी verified request को दोबारा claim कर सकता है और sync पूरा कर सकता है।
- दोनों मौजूदा नंबर केवल request के captured पुराने नंबर या OTP-सत्यापित नए नंबर में से होने चाहिए; कोई तीसरा/अलग नंबर मिलने पर कार्रवाई block रहती है। इससे rollback failure के बाद `sync_error` request स्थायी रूप से फँसने से बचती है, बिना unrelated number overwrite किए।
- Source-only; migration लागू/deploy नहीं हुई। Partial-sync permutations, duplicate-number races, Auth update idempotency और profile finalization tests अंतिम consolidated QA में बाकी हैं।
- Commit: `178369715abfa705aba08ff7f9b6bc6474c9478d`.


### 2026-11-14 — Phone-change OTP randomness hardening
- Edge Function में OTP generation को modulo-based mapping से rejection sampling पर बदला। अब 32-bit cryptographically secure random sample को केवल unbiased सीमा में स्वीकार करके 6-digit OTP बनाया जाता है; इससे modulo bias हटता है।
- Admin reject path, `processing` state exclusion, `sync_error` recovery queue, service-role-only RPC grants और OTP request throttling का static cross-review किया; कोई live action नहीं हुआ।
- Source-only; SMS provider/template, Deno runtime, SQL compilation और वास्तविक OTP/Admin flow अंतिम consolidated QA में बाकी हैं।
- Commit: `eb522983a9ba0c4483a7d1c41ee4279463e1711e`.


### 2026-11-14 — Phone-change Auth/profile synchronization retry safety
- Admin finalization RPC अब प्रोफ़ाइल नंबर बदलने से पहले `auth.users.phone` को OTP-सत्यापित नए नंबर से मिलाती है; mismatch पर profile finalize नहीं होती।
- Edge Function अब claim के बाद Auth phone दोबारा पढ़ती है: यदि Auth पहले से नए नंबर पर है तो update दोहराए बिना finalization retry करती है; यदि पुराना नंबर है तभी update करती है; कोई तीसरा नंबर या read failure मिलने पर request को `sync_error` में सुरक्षित रखती है।
- Finalization fail होने पर rollback केवल तब होता है जब Auth अभी भी इसी request के नए नंबर पर हो। किसी independently बदले तीसरे नंबर को overwrite नहीं किया जाता। इससे interrupted partial-sync recovery सुरक्षित हुई।
- Source-only; migration लागू नहीं, Edge Function deploy नहीं, SQL/Deno runtime या वास्तविक Auth/OTP flow नहीं चलाया। अंतिम consolidated QA में concurrency, Auth read/update failures, profile finalize failure और rollback permutations जाँचने हैं।
- Commits: `bed76c5a4cf3ee5dc78d1b7bfda17db55b17aa3f`, `33c35e50c0c7e25315e0554c68c9162edea24bf3`.


### 2026-11-14 — Phone-change expired OTP UI cleanup
- Electrician phone-change history refresh अब OTP input panel केवल तभी दिखाता है जब सबसे नई रिक्वेस्ट `otp_pending` हो और उसकी expiry अभी बाकी हो।
- OTP verify हो जाने, expire होने या पाँच गलत प्रयासों के बाद history refresh पर पुराना OTP request ID और input साफ़ होकर OTP panel छिप जाता है; expired OTP UI में सक्रिय नहीं दिखेगा।
- Source-only UI correction; वास्तविक OTP/मोबाइल परीक्षण अंतिम consolidated QA में ही होगा।
- Commit: `7077613a24eb2e3d6ee6476aa06bbaeaf21fb104`.


### 2026-11-14 — OTP failure state refresh
- Electrician OTP verification में गलत OTP / server error आने पर अब request history तुरंत दोबारा पढ़ी जाती है। पाँचवाँ गलत प्रयास OTP को expire करे तो UI उसी response cycle में stale OTP box और request ID साफ़ कर देती है; valid OTP-pending request पर retry UI बनी रहती है।
- Source-only UI hardening; वास्तविक SMS/OTP और mobile QA अंतिम consolidated चरण में होगा।
- Commit: `7660b687943d8231920931aa05ddf0c9e0fa56dd`.


### 2026-11-14 — Phone-change empty-history stale UI cleanup
- Electrician phone-change history RPC यदि सफलतापूर्वक खाली सूची लौटाए, तो अब stale OTP request ID, OTP input/panel और पुराने disabled form controls साफ़ किए जाते हैं। इससे पुराने session/UI state के कारण OTP panel छिपा रहने या नया अनुरोध अनावश्यक रूप से disabled रहने की समस्या रोकी गई।
- यह केवल source-level सुधार है। वास्तविक browser/mobile flow और history/RPC runtime परीक्षण अंतिम consolidated QA में बाकी हैं।
- Commit: `5ac5808babd13dc69b43ad3edfd56d91b904e4f3`.


### 2026-11-14 — Admin phone-change duplicate-action guard
- Admin मोबाइल नंबर बदलाव समीक्षा में प्रति request in-flight guard जोड़ा। Approve/Reject पर संबंधित कार्ड के buttons तुरंत disable होते हैं; repeated clicks एक साथ दूसरी Edge Function request नहीं भेजेंगे। Request समाप्त होने पर controls restore होते हैं; परिणाम अनिश्चित हो तो Admin को refresh करके authoritative status जाँचने का संदेश मिलता है।
- Source-only UI hardening; Admin browser, concurrent request और SQL/RPC runtime परीक्षण अंतिम consolidated QA में बाकी हैं।
- Commit: `c795e959f2d7d584b309f73e487b71375371834c`.


### 2026-11-14 — Phone-change SMS failure cleanup confirmation
- SMS provider से OTP भेजने में failure होने पर Edge Function पहले cancellation RPC चलाती थी, लेकिन RPC error/cleanup result को अनदेखा करके सामान्य retry संदेश दे देती थी। इससे failed SMS के बाद otp_pending row बचने और अगला अनुरोध रोकने की संभावना थी।
- srk_phone_change_cancel_send अब JSON result देता है, request owner और request ID पर ही OTP-pending row को expired करके OTP hash हटाता है, और पहले से expired row पर idempotent success देता है।
- Edge Function अब cleanup success की पुष्टि के बाद ही सामान्य retry संदेश देती है। Cleanup की पुष्टि न हो तो स्पष्ट रूप से history refresh करने को कहती है और false success नहीं दिखाती।
- Source-only बदलाव; migration लागू नहीं, Edge Function deploy नहीं, SMS/provider call या वास्तविक request नहीं चलाई गई। SQL/Deno runtime, SMS failure + cleanup failure, concurrent expiry/history और retry tests final consolidated QA में बाकी हैं।
