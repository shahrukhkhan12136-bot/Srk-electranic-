# SRK ELECTRONIC — मास्टर प्रोजेक्ट प्रगति सूची

**स्थिति snapshot:** 13 नवम्बर 2026  
**Repository:** `shahrukhkhan12136-bot/Srk-electranic-`  
**काम की branch:** `feature/platform-fee-cash-online-cycle`  
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


## 2026-11-13 — Customer booking idempotency hardening (follow-up)

- Resolved the previous GitHub contents API version conflict by refreshing the exact branch file SHA and applying the migration update sequentially.
- Tightened `service_bookings_customer_request_fingerprint_valid`: when an idempotency key is present, the fingerprint must now explicitly be non-NULL and match 64 lowercase hexadecimal characters. This closes PostgreSQL CHECK's NULL/UNKNOWN acceptance edge case.
- Migration commit: `eef97766eaea08fca0bab7fbfe9cf2d64de3bcfc`.
- Earlier Customer Booking form update also removed the `Math.random()` fallback for request-key generation; Web Crypto absence now fails closed. Commit: `8dbd6a19a7650f96c55d22f65298f6c7713bd0e3`.
- Booking page inline JavaScript syntax check passed. Database migration and pgTAP execution, browser/device execution, and live duplicate-submit behavior remain unverified.
- PIN-to-district authoritative validation and booking date/time cut-off policy remain open; no assumptions or historical data corrections made.
- Checklist counts unchanged; no Production schema/data changes, deployment, payment, refund, or payout.


## 2026-11-13 — Customer address validation audit and secure-key correction

- Re-audited the current branch source and found that the earlier tracker note claiming the `Math.random()` fallback had been removed was premature: the fallback was still present in the current `booking.html`. Corrected it now.
- Booking request-key generation now requires `window.crypto.getRandomValues`; unsupported browsers fail closed with a Hindi error instead of using `Math.random()`. Commit: `0109888750d37043613bd88212ca3ffd4373c365`.
- Verified server validation: PIN is exactly six digits; state and district are required; address is required and bounded to 1,000 characters; latitude/longitude must be supplied together and within geographic ranges. Customer form locality and work description are combined into `work_details`.
- Important limitation: PIN-to-district/state matching is NOT implemented; district is free text and PIN is syntax-only. No district was auto-corrected, including the previously noted historical 271861 mismatch. A trustworthy postal directory/data source and defined UX for mismatches are still needed.
- Booking form inline JavaScript syntax check passed after the secure-key correction; source check confirms no `Math.random()` fallback remains. Node booking-handler tests, browser/device tests, database migration/pgTAP and actual duplicate-submit behavior remain unexecuted in this pass.
- No business date/time policy was invented. No Production schema/data change, deployment, live booking, payment, refund or payout occurred. Checklist totals unchanged.


## 2026-11-13 — Customer Booking Form idempotency storage hardening
- Booking form retry-key audit found that `sessionStorage.setItem()` failures were silently ignored. In that case, the first request could reach the server but a retry after a timeout/reload might receive a new UUID and risk creating a duplicate booking.
- Updated `customerBookingRequestKey()` to write the pending key, read it back, and verify both UUID and payload fingerprint before sending the API request. If storage is unavailable, denied, or fails verification, the form now fails closed with a clear Hindi message rather than sending a request without durable retry identity.
- Added a customer booking idempotency source regression test for persistence/read-back verification and fail-closed behavior.
- Commits: `c1f65a03c9ccdac2a3f5dcb3c25c22367d66b73f` (booking form), `d7c98e03b7fba72894985cde203a771a3eed0293` (initial test), `634d08ef1b4cd5bdd06fc8276e6c9de9c937d6b5` (corrected test assertion).
- Initial CI runs failed because the new static test regex represented `||` incorrectly; the assertion was corrected. Latest source regression workflow run `43459149685` completed successfully on commit `634d08ef1b4cd5bdd06fc8276e6c9de9c937d6b5`. This is source-level CI only; browser runtime, real sessionStorage-denial simulation, API/database concurrency, and mobile/Desktop QA remain unverified.
- Resume point: continue Customer App form audit (saved-address load/save/default/edit behavior, map/location handling, and duplicate submission/error recovery). Do not start Electrician Portal until Customer App is complete.


## 2026-11-13 — Customer App saved-address / GPS consistency audit
- Saved-address API source review: customer list/save/delete RPCs derive identity from `auth.uid()`; saved-address table has owner-scoped RLS, authenticated-only RPC execution, 10-address limit, one-default partial unique index, paired/range-checked coordinates, and saved-address changes do not rewrite historical bookings. The existing 14-assertion pgTAP file is present but has NOT been executed.
- Found a customer UX/data-consistency issue: when a saved address with GPS coordinates was edited, the map preview/link was not restored in edit mode; changing address/district/state/PIN after selecting a saved address could leave the old GPS coordinates attached to the new address.
- Updated `booking.html`: editing a saved address now restores its saved map preview/link; manual edits to address, district, state, or PIN clear stale coordinates and hide the old map until the customer chooses GPS again.
- Added source regression assertions to `tests/customer-booking-idempotency.test.cjs` for saved-map restoration and stale-coordinate invalidation.
- Commits: `8413c12c7adc785875346f0d4adff401c5e3be4b` (form logic), `b70ba1621bd420e8384dd389be2c472880103936` (regression tests).
- Source regression workflow run `43459618523` passed on test commit `b70ba1621bd420e8384dd389be2c472880103936`. Refund source workflow run `43459589339` also passed on preceding code commit.
- Not yet verified: browser behavior, live Supabase RPC execution, saved-address RLS under real customer JWTs, concurrent default-address updates, GPS permission/denial flows, and final mobile/Desktop QA. No production data/schema was changed.
- Resume point: continue Customer App audit with booking form payload/duplicate-submit recovery and saved-address default-selection semantics; then proceed through remaining Customer App items only.


## 2026-11-13 — Customer App default address + booking retry recovery hardening
- Saved-address default semantics: after a customer OTP session loads, the form now selects and applies the saved default address only when address/district/PIN fields are still blank. A routine address-list refresh or save does not unexpectedly overwrite an address the customer is currently editing.
- Booking retry audit found two connected issues: successful API creation cleared the idempotency key immediately, so a repeated click or an error while refreshing the booking list could submit the same payload under a new key; and a booking-list refresh error could be reported as if booking creation itself failed.
- Updated success flow: keep the same request key after a successful create so a retry returns the original booking; isolate booking-list refresh errors from booking-create errors; show a separate explicit “इसी विवरण से नई बुकिंग शुरू करें” action to clear that key when the customer intentionally wants a second identical booking. Changing form data naturally produces a new payload fingerprint/key.
- Booking idempotency migration was re-audited and repaired: restored the complete 64-character lowercase SHA-256 fingerprint check, added a guarded constraint creation block and retained the unique partial idempotency-key index. Static regression checks now cover the fingerprint constraint and migration delimiter.
- Added source regression tests for default-address selection, successful retry identity, intentional identical new booking, and migration constraints.
- Commits: `8f6130f8586c53a6d24d4b9e132e250eb2cc4b24` (migration repair), `ba60f1044683a0b5cc77707e7529b9e4d76f9ace` (customer flow), `376fc674464795fac7bf2d8672cb2c89b656cdb5`, `54e20e5fa854f8eaa88fd086a82fbe4cc0537b3a`, `76b63921120c6eead0a042c4209e08f11b9d54dc`, `ee20e4d3892e19034a393a3a063f83a93489e93a`, `285b3ef57ea751864241ca274d8c69de7e825e2a`, `aae979e0e367e664bf8adbb4587a747ac30cf667` (test iterations and final assertion correction), `af1b918ab51c3a4db5b424c8c5e077ff2ad82a0c` (final SQL DO-block terminator).
- Final source regression workflow run `43460516221` passed on commit `aae979e0e367e664bf8adbb4587a747ac30cf667`. Earlier test iterations failed on newly added test assertions and were corrected; no unresolved failure remains in the final run.
- Refund source regression workflow run `43460212696` passed on commit `af1b918ab51c3a4db5b424c8c5e077ff2ad82a0c`.
- These are source-level checks only. The migration has NOT been applied or executed against a database; booking API concurrency, actual Supabase RPC behavior, browser storage/retry behavior, booking list refresh behavior, and final mobile/Desktop QA remain unverified. No Production data/schema, payment, payout, refund, or deployment was changed.
- Resume point: continue Customer App audit on remaining booking form behavior and other Customer App requirements. Do not start Electrician Portal until Customer App is complete.


## 2026-11-13 — Customer App: concurrent booking submission guard and refund flow consistency audit
- Booking submission audit found the submit button was disabled during the request, but the event handler itself did not explicitly reject a second submit event triggered while the first asynchronous request was in flight. Added a handler-level busy guard and guaranteed it is released in `finally`, including all error paths.
- Added a source regression test for the concurrent-submit guard. Customer source regression workflow run `43461039287` passed on commit `2821dbfb96f346ae36a1e64245d8d51118f01838`. Refund source regression workflow run `43461015087` passed on the preceding source commit `3c7b512ec20007d70d6f6b090d15c78474066110`.
- Refund flow source audit confirmed the Customer App calls `srk_customer_create_booking_refund_request` and `srk_customer_list_my_booking_refund_requests`; the source migrations define both expected functions and the list RPC returns only the authenticated customer's refund rows. Rejected requests can be re-submitted by the customer; active/processed duplicate refunds are blocked. Refund UI labels include unknown/Admin reconciliation and processed states.
- Refund requests are restricted by SQL source to completed, paid, verified, customer-approved labour bills and the exact immutable labour amount; materials are excluded. Manual payment refunds require a matching manual payment audit entry. This is source inspection only; SQL/RPC behavior remains unexecuted.
- Booking API source audit reconfirmed server validation for the authenticated OTP phone, UUID v4 idempotency key, normalized payload SHA-256 fingerprint, unique-key replay, changed-payload conflict, coordinate pair/range, PIN syntax, category, duration 1–8h, and calendar/time formats. Booking offer creation remains trigger-owned; API only reads offers to avoid duplicate fan-out.
- Business policy still missing for accepted booking dates/times, same-day cutoff, service hours, and PIN-to-district/state authoritative matching. These were intentionally not invented or changed. The PIN field is currently six-digit syntax validation only; mismatch resolution requires an authoritative India Post dataset and an approved customer UX.
- No database migration was applied, no live refund/payment/payout was executed, no Production changes/deployments, and no mobile/Desktop QA was performed. Mobile/Desktop checks remain reserved for the consolidated final QA.
- Resume point: continue Customer App-only audit; resolve remaining requirements and policy dependencies before proceeding to Electrician Portal.


## 2026-11-13 — Customer App Support & Complaints: missing customer functions restored
- Deeper audit of the Support tab found two event/session paths referenced functions that were not defined in `booking.html`: `loadCustomerSupportBookings()` and `createCustomerSupportComplaint()`. As a result, the complaint booking selector could not populate and the “शिकायत दर्ज करें” action would fail at runtime despite earlier source checks only confirming the listener reference.
- Implemented `loadCustomerSupportBookings()`: requires an OTP session, queries only `service_bookings` rows owned by `session.user.id`, limits the list to 50, and populates the complaint booking selector with service/date/reference labels.
- Implemented `createCustomerSupportComplaint()`: explicit booking/category/20–2000 character validation, session check, handler-level duplicate-click guard, calls the authenticated `srk_customer_create_booking_complaint` RPC, maps daily complaint quota and ownership errors to clear Hindi messages, then refreshes and opens the new complaint thread.
- Added regression coverage for both functions and the customer ownership filter. Inline JavaScript syntax check passed (1 script block). Customer source regression workflow run `43461629230` passed on commit `a5136fde613dca93204e08a51e297f71225f7b2e`; Refund source regression run `43461595108` passed on commit `ec0ee7292ec8b79f4f05ac5d89e737ee0de38baa`.
- This was a source audit correction: no live database migration or RPC was executed, no browser/mobile/Desktop interaction test, no production change, no deploy, and no customer data modification. The actual RPC must be available after the approved database migration set is applied; this branch-only source work does not activate it in Production.
- Resume point: continue Customer App Support/Payments/Profile audit and cross-check remaining runtime references against actual function definitions. Keep Electrician Portal and general Admin Panel deferred until Customer App completion.


## 2026-11-13 — Customer Booking API: सुरक्षित retry और rate-limit सुधार

- Source audit में मिला कि booking API पहले IP rate-limit consume करती थी, उसके बाद JSON parsing, customer Auth verification और idempotency lookup होता था। इससे network timeout / response खो जाने पर उसी booking को सुरक्षित रूप से retry करने पर भी नया submission slot खर्च होता था; पाँचवीं से अधिक retry वैध booking ग्राहक को 429 दे सकती थी।
- create-booking.js में क्रम बदला:
  1. HTTP method/body-size और JSON shape जाँच।
  2. Supabase Auth session + verified phone जाँच।
  3. UUID v4 idempotency key, booking fields और canonical payload fingerprint जाँच।
  4. Authenticated customer + उसी key से पहले की booking lookup।
  5. यदि exact fingerprint match है तो existing booking replay; नया insert नहीं, IP rate-limit slot भी consume नहीं।
  6. यदि key मौजूद है लेकिन fingerprint बदला है तो 409 conflict।
  7. केवल नई booking insert से पहले IP rate limit लागू; rate-limit failure पर fail closed।
  8. Concurrent first submissions में unique-key conflict के बाद दोबारा owner/key/fingerprint पढ़कर exact match को replay; अन्यथा 409।
- इससे safe retries की reliability सुधरी, जबकि genuinely new booking पर existing 5-request IP limit बनी रहती है। ग्राहक Auth verification को rate-limit bypass करने के लिए छोड़ा नहीं गया।
- Regression tests tests/create-booking-handler.test.cjs में malformed JSON, missing IP, unauthenticated request, new-booking rate limit, exact retry, changed-payload conflict और rate-limit bypass cases जोड़े/अपडेट किए।
- GitHub Actions source regression workflow Run #43462252356 — success; tested head commit 63851c41d4146f1fe5f2d6ac0fe68b790fd18b29। इसमें workflow के सभी configured source suites पास हुए।
- पहले दो runs में पुरानी test expectations / missing test idempotency header के कारण failures आए; assertions ठीक करके अंतिम run दोबारा चलाया गया और success मिला। किसी test failure को pass नहीं माना गया।
- यह source/isolated mock verification है; live Supabase rate-limit RPC, database concurrency, वास्तविक Netlify IP headers और browser/device E2E अभी verify नहीं हुए। कोई SQL migration, Production change, deployment या payment/refund execution नहीं हुआ।
- Master checklist counts अपरिवर्तित: Verified Complete 0/96; Partial/In Progress 65; Blocked 7; Remaining 24।
- अगला Customer App काम: customer profile, booking history, Help & Support तथा उनके role-scoped RPC/RLS/error/retry व्यवहार का source audit; उसके बाद बाकी Customer App requirements। Electrician Portal शुरू नहीं हुआ।


## 2026-11-13 — Customer Profile direct-table access hardening

- Customer Profile frontend का source audit किया: नाम/भाषा/अवतार केवल srk_customer_get_my_profile और srk_customer_update_my_profile RPC से पढ़े/सेव किए जा रहे हैं; verified phone Supabase Auth session से read-only दिखता है।
- Profile migration में authenticated role को srk_customer_profiles table पर SELECT/INSERT/UPDATE की direct grants मिली हुई थीं। इससे UI के validated RPC के बाहर client direct table writes कर सकता था; table constraints कुछ सीमाएँ लागू करते थे, लेकिन RPC की min-name और avatar-object existence validation bypass हो सकती थी।
- Migration 20261113200000_customer_profile_api_and_avatar_security.sql से authenticated direct table grant हटाई; anon/authenticated direct privileges revoked ही रहते हैं। Profile access अब owner-scoped SECURITY DEFINER RPCs से होगा। RLS policies defense-in-depth के रूप में बनी रहती हैं।
- pgTAP assertion बदली: authenticated/anon client roles के पास profile table का direct SELECT/INSERT/UPDATE/DELETE access न हो। RPC grants और ownership checks की बाकी assertions बरकरार।
- tests/customer-menu.test.cjs में source regression जोड़ा कि frontend दोनों profile RPCs इस्तेमाल करे और migration client table grants न दे।
- GitHub Actions source regression workflow Run #43462573520 — success; tested head commit 082125515c6e9dab60afe463de551a16d0b423de।
- SQL pgTAP test अभी execute नहीं हुआ; migration Production या किसी live database पर apply नहीं हुई। Storage bucket, avatar MIME/object metadata enforcement और actual signed-URL access की runtime जांच अभी बाकी है। कोई deployment/Production बदलाव नहीं।
- Master checklist counts अपरिवर्तित: Verified Complete 0/96; Partial/In Progress 65; Blocked 7; Remaining 24।
- अगला क्रम Customer App में Help & Support attachment authorization/metadata और booking-history/profile error states का source audit है। Electrician Portal शुरू नहीं हुआ।


## 2026-11-13 — Customer Help & Support thread race hardening

- Customer Support UI source audit में एक async race मिली: ग्राहक शिकायत A खोलकर तुरंत शिकायत B चुनता तो A का धीमा message/attachment response बाद में आकर B की स्क्रीन पर दिखाई दे सकता था।
- `booking.html` में monotonically increasing thread-load sequence जोड़ी। Message और signed-attachment requests पूरी होने के बाद UI तभी render होती है जब sequence अभी नवीनतम हो और dropdown में वही complaint ID चयनित हो। Empty selection पर पुरानी attachments state भी साफ होती है।
- Attachment load failure पहले silently ignore हो रही थी; अब message thread दिखेगा लेकिन status में स्पष्ट बताया जाएगा कि कुछ फ़ाइलें अभी नहीं खुलीं और रीफ़्रेश करना है।
- Send button disable होने के बावजूद simultaneous submit event की race रोकने के लिए explicit `customerSupportMessageBusy` guard जोड़ा; finally block में guard और button दोनों reset होते हैं।
- `tests/customer-menu.test.cjs` में stale-response guard, selected complaint match, duplicate-send guard और attachment error feedback के source regression assertions जोड़े।
- GitHub Actions source regression workflow Run #43463185911 — success; tested head commit 2f9c6b32635e0581a489d71c00ba8ebf5aba5eab।
- ये source-level/isolated tests हैं; live Supabase RLS/Storage policies, signed URL expiry, actual uploads/downloads, cross-customer IDOR और mobile/Desktop interaction अभी runtime में verify नहीं हुए। कोई migration apply, Production change या deployment नहीं।
- Known limitation retained: multi-file upload partial failure पर पहले से सफलतापूर्वक linked attachments बने रहते हैं; UI सफल फ़ाइलों की संख्या बताती है। पूरे message + सभी attachments के लिए atomic transaction अभी उपलब्ध नहीं; retry behavior को future acceptance test में अलग से verify करना है।
- Master checklist counts अपरिवर्तित: Verified Complete 0/96; Partial/In Progress 65; Blocked 7; Remaining 24।
- अगला Customer App audit: complaint/message attachment cleanup and metadata integrity, customer booking-history partial RPC failures, profile/avatar lifecycle. Electrician Portal अभी शुरू नहीं हुआ।


## 2026-11-13 — Customer Support attachment object-integrity hardening

- Existing attachment-link RPC केवल client द्वारा भेजे MIME type और file size को validate कर रही थी; Storage object के वास्तविक metadata से तुलना नहीं थी। अब नई migration `20261114170000_harden_customer_support_attachment_object_integrity.sql` में `storage.objects.metadata.mimetype` और `metadata.size` को requested metadata से exact match कराया गया है; missing/mismatched metadata पर link reject होता है।
- Object path को authenticated customer UID + complaint UUID + UUID filename + allowed extension तक सीमित किया है। Complaint ownership, open status, own customer message और actual object existence checks भी बने हुए हैं।
- पहले customer delete policy अपने complaint के सभी objects हटाने देती थी, जिसमें पहले से message history से linked attachment भी शामिल हो सकता था। नई policy customer cleanup को केवल unlinked/orphan objects तक सीमित करती है; linked attachments history से हटाए नहीं जा सकते।
- pgTAP file `supabase/tests/database/customer_support_attachment_object_integrity.test.sql` में 4 assertions जोड़े: actual Storage MIME/size check, mismatch rejection, cleanup policy existence, linked-file delete denial।
- `.github/workflows/supabase-schema-ci.yml` की isolated migration list में नई migration जोड़ी।
- Source regression `tests/customer-menu.test.cjs` में migration के metadata validation, path constraint और linked-file delete protection assertions जोड़े। GitHub Actions source regression Run #43463628709 — success; tested head commit `3b03a61114d8238029e04d3cd7805820c34a3b71`।
- Database pgTAP अभी execute नहीं हुआ; schema workflow का production schema-export secret मौजूद/usable मानकर नहीं चला और कोई production schema/data access/write नहीं किया। Supabase Storage runtime metadata shape और policy evaluation अभी isolated DB run में verify होने बाकी हैं। File bytes का malware/content signature scan अभी उपलब्ध नहीं है; MIME metadata check actual content signature scanning का विकल्प नहीं है।
- कोई migration Production में apply नहीं हुई; कोई deployment/upload/payment/refund नहीं किया गया।
- Master checklist counts अपरिवर्तित: Verified Complete 0/96; Partial/In Progress 65; Blocked 7; Remaining 24।
- अगला Customer App काम: booking-history RPCs और profile/avatar lifecycle की error/retry/privacy audit; फिर Help & Support upload atomicity/cleanup acceptance cases। Electrician Portal अभी शुरू नहीं हुआ।


## 2026-11-13 — Customer booking history partial-failure और stale-refresh hardening

- `loadCustomerBookings()` में पहले booking list के बाद तीन अतिरिक्त RPC (call contacts, work timeline, refund history) और completed bookings के labour-bill RPCs चलते थे। Contacts/bill errors चुपचाप छूट सकते थे; अब मूल booking cards render रहते हैं और जो उप-जानकारी विफल हुई उसके लिए स्पष्ट Hindi warning दिखती है।
- Timeline और refund-history failures की warnings अब एक ही partial-status message में दिखती हैं; contact RPC failure और किसी भी completed booking bill fetch failure भी बताया जाता है। Refund request की पिछली स्थिति लोड न होने पर नया refund-request button नहीं दिखाया जाता, ताकि duplicate/अनजाने अनुरोध का जोखिम न बने।
- तेज़ी से दोबारा refresh करने पर पुराने network response से नया booking view overwrite न हो, इसके लिए `customerBookingHistoryLoadSequence` guard जोड़ा। केवल सबसे नया request render कर सकता है और वही `aria-busy` reset करता है।
- Regression tests `tests/customer-menu.test.cjs` में stale response guard, हर partial RPC failure warning, bill failure warning और busy-state ownership की जाँच शामिल। GitHub Actions source regression Run #43463938027 — success, tested head `86def66ec4e621fc7a804394b93b242e6c4244c1`। Booking source change Run #43463914650 — success, head `232c64da294e71227f166862aa3cc8f11f0c5a1d`।
- ये source regression tests हैं; वास्तविक Supabase RPC/RLS, multi-request browser timing, database pgTAP, mobile/Desktop QA अभी नहीं हुए। कोई production बदलाव/deployment नहीं।
- Customer App का Booking History/Profile audit जारी है। Profile/avatar lifecycle में save के बाद preview-load failure और old-avatar cleanup failure को अलग से संभालना अगला उपकार्य है।
- Master checklist counts अपरिवर्तित: Verified Complete 0/96; Partial/In Progress 65; Blocked 7; Remaining 24।


## 2026-11-13 — Customer Profile / Avatar lifecycle hardening

- `loadCustomerAvatar()` अब success/failure लौटाता है और signed URL न बनने पर preview साफ करता है; Profile load अब session retrieval को भी try/catch में रखता है और preview न मिलने पर झूठा success नहीं दिखाता। खाली नई प्रोफ़ाइल/बिना avatar की स्थिति में पुराना preview हटता है।
- Avatar save में सुरक्षित `crypto.randomUUID()` अनिवार्य है; session retrieval error अलग से पकड़ा जाता है। नई image upload के बाद profile RPC fail होने पर uploaded object cleanup result जाँचा जाता है। Profile save सफल हो लेकिन preview या पुराने avatar deletion में समस्या आए तो UI स्पष्ट रूप से बताता है कि profile save हुई है और कौन-सा cleanup/preview काम बाकी है; इसे save failure बताकर गलत retry नहीं कराता।
- नई migration `20261114180000_harden_customer_avatar_object_integrity.sql` में profile update RPC वास्तविक private Storage object metadata से MIME type और byte size जाँचती है; अधिकतम 5 MiB, allowed MIME types और matching UUID filename extension आवश्यक हैं। User-owned object path तथा authenticated-only RPC grant कायम हैं।
- pgTAP `supabase/tests/database/customer_avatar_object_integrity.test.sql` में 5 assertions जोड़े; isolated schema CI migration list में migration शामिल।
- Source Regression workflow Run #43464608065 — success, tested head `a854c7dce5af2259a063ccf1bf1a3bdfc18589b6`। Avatar migration commit पर source regression Run #43464916450 — success; pgTAP-file commit source workflow Run #43465012759 — success, head `ff974e0bc3a1d0a02ac8684e26813a216fc0ffd6`। ये source checks हैं, SQL migration/pgTAP execution नहीं। Isolated schema/pgTAP workflow इस branch commit के लिए अभी execute नहीं हुआ।
- pgTAP अभी execute नहीं हुआ। Storage metadata shape, signed URL expiry/access, वास्तविक upload/delete, cross-user IDOR और browser/mobile/Desktop interactions अभी runtime-verified नहीं। कोई Production migration apply, deployment या customer data change नहीं।
- Master checklist counts अपरिवर्तित: Verified Complete 0/96; Partial/In Progress 65; Blocked 7; Remaining 24।
- अगला Customer App audit: Payments history/receipt and refund-history RPC behavior, then full Profile/Support/Booking acceptance coverage. Electrician Portal अभी शुरू नहीं हुआ।


## 2026-11-13 — Customer Payments History / Receipt / Refund History hardening

- Payments History और Refund History के concurrent refresh पर latest-request sequence guards जोड़े; पुराने async responses नई list को overwrite नहीं कर पाएँगे। Session retrieval अब try/catch के भीतर है और `aria-busy` केवल latest request द्वारा reset होता है। Payment pagination offset केवल latest सफल response के बाद आगे बढ़ता है।
- Receipt action अब केवल `event_type='payment'` और `status='paid'` वाले verified booking-payment row पर दिखता है; unverified/manual-recorded rows पर receipt button नहीं दिखेगा। Receipt RPC की server-side ownership और verified-payment guards कायम हैं।
- नई migration `20261114190000_customer_receipt_immutable_labour_amount.sql` receipt में पहले immutable `srk_booking_labour_bills` से labour amount लेती है, और तभी जब bill मौजूद न हो तो legacy `service_charge` fallback लेती है—वह भी केवल जब वह पूरी verified paid राशि से exact match हो। Materials amount/line items receipt में नहीं आते। Authenticated-only grant और booking owner check कायम।
- pgTAP `supabase/tests/database/customer_receipt_immutable_labour_amount.test.sql` में 7 assertions जोड़े; isolated Supabase schema CI migration list में नई migration शामिल।
- Source workflow Run #43465512466 (payments/refund history UI source update) — success. Source Regression workflow Run #43465670151, rerun attempt 2 — success; branch checkout included migration and pgTAP file at/after commit `ac0d423cefacc1cd71e0cf21fa2c7bd87c420ced` and current tracker commit. Earlier Run #43465662448 failed because the new migration was not yet on the branch; the missing files were restored to the branch and the complete source suite then passed.
- SQL pgTAP अभी execute नहीं हुआ। Payment history RPC का runtime role/JWT isolation, refund history provider state, real receipt generation/printing, payment pagination in browser, and final mobile/Desktop QA अभी बाकी। No Production migration apply, deployment or payment/refund movement.
- Master checklist counts unchanged: Verified Complete 0/96; Partial/In Progress 65; Blocked 7; Remaining 24. Customer App work continues; Electrician Portal/Admin Panel general work not started.


## 2026-11-13 — Customer Payment/Refund History RPC completion

- Audit में महत्वपूर्ण dependency gap मिला: `booking.html` ग्राहक Payments History को `srk_customer_get_payment_history(p_limit,p_offset)` RPC से पढ़ रहा था, लेकिन feature branch migrations में यह RPC मौजूद नहीं था। इसलिए Payment History UI source मौजूद होने के बावजूद वास्तविक Supabase पर history load नहीं हो सकती थी।
- नई migration `20261114200000_customer_payment_refund_history_rpc.sql` में authenticated, `auth.uid()` owner-scoped, stable paginated RPC जोड़ी। इसमें verified booking payment, customer refund request, Razorpay refund और manual refund events आते हैं। Admin notes, provider payload, दूसरे ग्राहक की rows शामिल नहीं। Limit 1–50 bounded है; default 25।
- Refunded booking का मूल भुगतान event अब status `refunded` दिखाता है; अलग refund event भी रहता है। इससे refunded payment पर गलत “रसीद उपलब्ध” बटन नहीं दिखेगा। UI status label भी `रिफंड किया गया` किया।
- Refresh पर payment pagination offset reset और stale “अगले रिकॉर्ड” बटन छिपता है। Sequence guard और latest request ownership पहले से कायम।
- pgTAP `supabase/tests/database/customer_payment_refund_history_rpc.test.sql` में 10 assertions; `tests/customer-menu.test.cjs` में RPC existence, owner scope, event sources, refunded-state and pagination regressions जोड़े। Supabase isolated schema CI migration list में migration शामिल।
- Source Regression workflow Run #43466694208 — success on commit `6a1fe74f83037cdf4c8ef8a0ed10c2a93041a3be`; follow-up Run #43466799589 — success on `bbce79072ed4140a3b244e28311cd6dcbd82c6df`; latest full source regression Run #43466817318 — success on `fc03e08a987427c634e545c4c21ff6642f100712`।
- Earlier two source runs failed because new migration/test files had been created in detached commits and were not present on branch checkout; files were restored onto the approved feature branch before the passing full run. Those failures were not code-test failures.
- SQL pgTAP/schema workflow and real Supabase RPC/JWT tests have NOT run. Receipt print/browser testing, refund provider status lifecycle runtime verification, payment list pagination in a browser and final mobile/Desktop QA remain outstanding. No Production schema apply, deployment, payout or refund movement.
- Master checklist counts unchanged: Verified Complete 0/96; Partial/In Progress 65; Blocked 7; Remaining 24. Customer App remains active; Electrician Portal/Admin Panel general work not started.


## 2026-11-13 — Customer Refund Request Eligibility / Duplicate Submit hardening

- Customer Booking UI पहले verified paid booking पर refund request दिखा सकता था, जबकि server RPC केवल `completed` + customer-approved completion + selected category + immutable labour bill + paid amount exact match वाली booking स्वीकार करता है। इससे legacy/ineligible booking पर ग्राहक को ऐसा form दिखता था जो server पर reject होता।
- अब UI refund request केवल तभी दिखाता है जब booking completed हो, customer ने completion approve की हो, selected category मौजूद हो, immutable bill loaded हो, payment verified हो और bill labour amount paise में paid amount से exact match हो। Server-side RPC validation authoritative बनी हुई है।
- Refund submit पर प्रति booking Set-based busy guard जोड़ा ताकि duplicate event submissions न हों। सफल अनुरोध के बाद Booking History, Refund History और Payment History तीनों refresh होते हैं।
- Source regression tests ने eligibility, amount match, duplicate guard और तीनों histories refresh assertions जोड़े। Source Regression Run #43467024941 — success; Refund source regression Run #43467024908 — success; दोनों commit `31eb2f33748dd084024a9130ab9898d30b4ea7ca` पर।
- UI gate browser source checks तक verified; live RPC/database eligibility, concurrent request locking और refund state provider lifecycle अभी runtime tested नहीं। SQL pgTAP बाकी; no Production changes/deployment/refund movement.

- अतिरिक्त classification सुधार: `manual_payment` event label अब तभी दिया जाता है जब उसी booking के लिए वास्तविक audited `srk_manual_payment_entries` row मौजूद हो; केवल `razorpay_payment_id` NULL होने से किसी legacy/अन्य payment को manual नहीं कहा जाएगा। Source regression Run #43467154570 — success, commit `850c7c3d02eaeaeed9569d15ce77d7f4e4653353`।


## 2026-11-13 — Payment History RPC compatibility review/correction

- Deep compatibility audit में पता चला कि पहले draft `20261114200000_customer_payment_refund_history_rpc.sql` ने existing RPC के 8 output columns (event_id, event_type, booking_id, amount, status, payment_method, occurred_at, description) को बदलकर 7 columns कर दिया था। PostgreSQL `CREATE OR REPLACE FUNCTION` से OUT/RETURNS TABLE signature नहीं बदल सकता; इससे migration apply fail होती। यह migration अभी कहीं apply नहीं हुई थी।
- Draft को corrected किया: existing 8-column return signature और parameter defaults preserved; payment, refund request, Razorpay refund, audited manual payment और manual refund सभी event sources शामिल; `auth.uid()` customer booking scope; limit 1–50; offset >10,000 reject; stable sort occurred_at + event_id; no provider/admin private fields; refunded booking payment state अलग दिखती है।
- pgTAP test plan 11: original result signature preserved, auth, owner scope, verified payment, four refund/payment event sources, pagination, no private fields, authenticated-only grants. Tests अभी execute नहीं हुए।
- Source regression workflow Run #43467914135 — success, commit `fd5774edb8a3b2e4fc9415c35565ba5afd15a773`। Earlier source workflow failures were test assertion case/format mismatches while checking SQL source; corrected source assertions now pass. No migration applied; no Production changes/deployment.


## 2026-11-13 — Customer Help & Support partial attachment recovery

- Support message RPC पहले attachments upload/link करने से पहले message row बनाता है। यदि किसी बाद की फ़ाइल upload/link या thread refresh में error आता था, catch UI “message/file नहीं भेजा” कहता और customer retry करने पर duplicate message बन सकता था।
- अब server से message ID मिलने के तुरंत बाद message text input clear होता है और `messageCreated` state track होती है। बाद में attachment fail होने पर UI बताता है कि message पहले ही भेजा जा चुका है; कितनी फ़ाइलें जुड़ीं; शेष फ़ाइलें अलग से चुनें; message दोबारा न भेजें। Thread refresh failure पर भी duplicate resend न करने की स्पष्ट सूचना।
- Pending unlinked object cleanup का result अब check होता है; cleanup fail होने पर ग्राहक को orphan attachment cleanup pending होने की जानकारी दी जाती है, पहले की तरह error silently ignore नहीं होता।
- `tests/customer-menu.test.cjs` में partial attachment failure, no duplicate resend, linked-count recovery prompt, and cleanup failure warning source assertions जोड़े।
- Source Regression Run #43468150124 — success on commit `0c0e858bbc25f650764439a1675c8942c7e70984`; latest Source Regression Run #43468291002 — success on commit `82c165155de72c4bc3869a5378944dc42d56336f`; Refund source regression Run #43468267240 — success on `a127bce5ff250da7656593f04c71513c6c3d40d7`.
- Multi-file upload अभी भी एक atomic transaction नहीं है; पहले से linked attachments सुरक्षित रहते हैं और शेष को अलग से resend करना पड़ता है। Storage/RPC runtime, real signed URL, network-failure cleanup, RLS/IDOR, and final mobile/Desktop QA अभी नहीं हुए। No Production change/deployment.


## 2026-11-13 — Customer Profile avatar cleanup error visibility

- Profile save flow में नई avatar upload सफल होने के बाद profile RPC fail हो और नई file cleanup भी fail हो, तो पहले cleanup warning set होती थी लेकिन outer catch उसे generic save error से overwrite कर देता था। इस कारण संभावित orphan avatar की सफाई समस्या ग्राहक को दिखाई नहीं देती थी।
- अब `uploadCleanupFailed` flag cleanup result को outer catch तक सुरक्षित रखता है और final error में स्पष्ट बताता है कि नई अपलोड फोटो की सफाई पूरी नहीं हुई; सहायता लें। Existing successful profile save + preview failure और old-avatar cleanup warning behavior कायम।
- `tests/customer-menu.test.cjs` में cleanup warning persistence regression जोड़ा। Source Regression Run #43468563874 — success on commit `3b56ff6f7872ab86c0e0de76a4c4716c40615e47`; Refund source regression Run #43468542234 — success on commit `5d53538a5fb8f3bc87b1b7c6aa10af3d7e1a73e3`.
- यह source-only verification है; actual Storage cleanup failure, signed URL, avatar upload, Supabase RPC/JWT and SQL pgTAP अभी runtime tested नहीं। No Production changes/deployment.


## 2026-11-13 — Customer Booking payment status Hindi labels

- My Bookings card में `paid` को Hindi में दिखाया जाता था, लेकिन `refunded` जैसे नए payment states सीधे अंग्रेज़ी database value के रूप में दिख सकते थे। अब central `customerBookingPaymentStatusText()` helper से paid/refunded/pending/failed/processing/created सभी known payment states के Hindi labels मिलते हैं; unknown value generic Hindi fallback देता है।
- Source Regression Run #43468833561 — success on UI commit `0a168d9558cf421c778229426e352df06d510e3d`; latest regression Run #43468859611 — success on test commit `8d388effeb5c5ec20d7428fa9bc1baa85243461a`; Refund source regression Run #43468833649 — success.
- Browser visual/mobile QA अभी final consolidated pass में होगा।


## 2026-11-13 — Customer Payment History duplicate and manual-refund status correction

- Payment History में verified booking-level payment row और उसी booking की audited `srk_manual_payment_entries` row दोनों आ सकती थीं, जिससे एक ही cash/UPI/manual payment दो बार दिखाई देता। अब booking summary event तभी दिखेगा जब matching audited manual-payment row मौजूद न हो; audited manual payment अपने वास्तविक `recorded_at` के साथ एक बार दिखेगा। Legacy booking summary fallback बना रहता है जहाँ manual audit row नहीं है।
- Manual refund audit entry केवल manual transfer evidence दर्ज होने और Admin finalization transaction में booking `payment_status='refunded'` तथा ledger/payout reversal के साथ बनती है। Customer history में उसे generic `recorded` के बजाय `processed` दिखाया जाएगा।
- Source regression: dedupe test run #43469156977 — success (commit `1ac90dd0fb74e3e5764f0bf099b4b9d4606531dc`); finalized manual refund status migration source run #43469199920 — success (commit `a2118c88a185fb0dfb8b4439f608b9cb3ce7781f`); latest expanded source tests run #43469222453 — success (commit `5dd3c5f86d863dd54fc834629dd91a43d083c948`). Refund source checks run #43469119618 — success.
- Database pgTAP `customer_payment_refund_history_rpc.test.sql` plan 13 updated, NOT EXECUTED. No live payment/refund records queried or changed; no Production migration apply/deploy or money movement. Manual customer UI display not browser-tested; final consolidated mobile/Desktop QA deferred.


## 2026-11-13 — Customer Refund History completion timestamp + live-tracking dependency audit

- Refund History में अंतिम अपडेट के लिए `updated_at` पहले चुना जाता था; processed request पर यह वास्तविक `processed_at` से अलग हो सकता था। अब UI तारीख के लिए `processed_at || updated_at || created_at` प्राथमिकता देता है, ताकि सफल Refund completion की असली timestamp दिखे। Source Regression Run #43469350321 — success; Refund source checks #43469350207 — success; regression test commit `1b09be68fb960c80f5d71ef98d5c89d9d7f83c58` Run #43469363689 — success.
- Customer App live electrician tracking requirement का dependency audit: वर्तमान `booking.html` में customer live tracking/ETA component नहीं है। मौजूदा location migration केवल customer booking pin और electrician profile/base coordinates store करती है; electrician की यात्रा के दौरान timestamped live-location update stream, customer-scoped read RPC/policy, arrival/stop lifecycle और ETA contract नहीं मिला। इसलिए मौजूदा static booking pin को live tracking कहना गलत होगा।
- Strict phase order के कारण अभी Electrician Portal या general Admin Panel काम शुरू नहीं किया गया। Live tracking को Customer App completion के cross-phase dependency के रूप में दर्ज किया: customer view तभी पूरा/verified होगा जब बाद के Electrician Portal चरण में authorized trip updates और सुरक्षित server-side feed बने, फिर customer UI integration और consolidated end-to-end QA हो। कोई नकली/पुरानी coordinates live नहीं दिखानी हैं।
- No live location tracking, user/device GPS, Production data/schema, deployment or money movement changed. SQL pgTAP for payment history remains NOT EXECUTED; final consolidated mobile/Desktop QA remains deferred.


## 2026-11-13 — Booking card refund timestamp consistency + manual refund dependency

- My Bookings card में Refund summary timestamp अब Refund History tab के समान `processed_at || updated_at || created_at` प्राथमिकता से दिखता है; इससे completed refund की तारीख वास्तविक processing timestamp रहती है, न कि बाद के unrelated update की।
- Regression assertion added: `tests/customer-menu.test.cjs`; Refund source regression Run #43469711139 — completed success on UI commit `9406f047d4111ac02186eae164ac369f088d96ef` (test commit subsequently `98c6a2a8fdbc29c687335497918a8784bba6dc6c`).
- Refund flow audit confirms customer history RPC is owner-scoped and returns `processed_at`; UI statuses cover requested/in_review/approved/rejected/processing/unknown/processed. Customer duplicate submit guard and backend one-request-per-booking checks exist.
- Important remaining cross-phase/backend dependency: manual-payment refund request can be created, but a complete Admin-authorized manual refund finalization workflow (manual transfer evidence validation, exact labour-only amount, payout/fee ledger reconciliation, idempotent audit, and customer state transition) is not yet implemented/verified. Do not show manual refund as complete until this exists. Razorpay provider execution remains source-only and not runtime-tested.
- SQL pgTAP/RPC execution, Supabase RLS/JWT, provider/manual refund integration and final consolidated mobile/Desktop QA remain unverified. No Production changes/deployment/money movement.


## 2026-11-13 — Manual Refund finalization retry safety

- Manual/Cash refund का Admin workflow branch पर पहले से मौजूद था: Admin-only prepare → वास्तविक transfer reference अलग से durable record → booking/payment और platform-fee/payout ledger finalization। पिछली स्थिति-रिपोर्ट में इसे “अभी implement होना बाकी” कहना stale था; source audit से migration `20261114140000_manual_labour_only_refund_workflow.sql`, Admin UI actions और pgTAP/source tests मौजूद मिले।
- Deep retry audit में एक वास्तविक idempotency defect मिला: सफल manual refund के बाद refund trigger payout row को अंतिम refunded state में बदल सकता है। यदि Admin उसी finalization RPC को retry करता, तो पुराना code उसी payout row को फिर temporary `blocked` marker मानने की कोशिश कर सकता था और processed refund को reconciliation में डाल सकता था।
- Migration में अब `status='processed'` के लिए early read-only idempotent success path है। यह booking के refunded state और exact manual refund audit entry (booking, payment entry, amount in paise, transfer reference) verify करता है; mismatch पर error देता है; सही होने पर payout/ledger mutation दोबारा चलाए बिना `already_finalized=true` लौटाता है।
- Source regression test और pgTAP assertion जोड़े गए; pgTAP plan 15 से 16 किया।
- Migration commit `3a1197726ea66fc011bdfbb1fa5dfe36a7bdacea`; source test commit `d89cdd3e56498dccfcb74589196817cc2b9be066`; pgTAP test commit `7817578ebfc82d7ab93a7764c832b7742f749121`.
- Source Regression Run #43470164003 — success; Refund Source Regression Run #43470164015 — success (latest head `7817578ebfc82d7ab93a7764c832b7742f749121`). Earlier intermediate commits also passed: #43470149137 and #43470149291.
- SQL pgTAP execution, Supabase runtime/RLS/JWT/concurrency checks, actual transfer/refund execution and payout-ledger reconciliation remain NOT tested. Migration is branch-only; no Production schema/data changes, deployment or money movement. Mobile/Desktop QA remains deferred to the final consolidated pass.


## 2026-11-13 — Customer payment history RPC audit

- Feature-branch migration `20261114200000_customer_payment_refund_history_rpc.sql` का source audit किया। `srk_customer_get_payment_history(integer,integer)` मूल 8-column return contract रखता है: event_id, event_type, booking_id, amount, status, payment_method, occurred_at, description; customer scope `auth.uid()` के booking ownership join से लागू है।
- Pagination limit 1–50 और offset 0–10000 तक bounded है; ordering `occurred_at DESC NULLS LAST,event_id DESC` deterministic tie-breaker देता है।
- Payment events केवल verified paid/refunded bookings के लिए हैं; audited manual-payment row मौजूद हो तो duplicate booking-payment event suppress होता है। Manual refund event तभी history में आता है जब manual refund audit entry मौजूद है; Razorpay refund events provider refund table से आते हैं।
- Customer UI के receipt button को केवल `event_type='payment'` और `status='paid'` पर दिखाने का source guard देखा; receipt RPC immutable labour bill को प्राथमिकता देता है और materials को receipt amount में शामिल नहीं करता।
- यह migration/source audit है, database execution या live JWT/RLS runtime proof नहीं। Manual payment row की वास्तविक verification semantics और provider event lifecycle को isolated DB/runtime tests में सत्यापित करना शेष है। कोई Production बदलाव या deployment नहीं।


## 2026-11-13 — Customer booking history stable ordering

- Customer App के My Bookings query में पहले केवल `created_at DESC` था। समान timestamp वाली दो bookings के बीच database order स्थिर होने की गारंटी नहीं थी।
- अब secondary `id DESC` tie-breaker जोड़ा है, जिससे first-page 50 bookings का ordering deterministic रहता है।
- Source regression test जोड़ा। पहली test run में test fixture variable का नाम गलत (`bookingHtml`) था; run #43470587772 fail हुआ। Test fixture को वास्तविक `html` variable से ठीक किया और rerun किया।
- Source Regression Run #43470667452 — success, head `a19f6935d80a338fef1d03aaa95ebd4852d46daa`.
- यह केवल deterministic ordering है; current UI अभी पहली 50 bookings तक सीमित है, infinite/history pagination नहीं जोड़ी गई। Browser/mobile QA deferred; SQL/runtime/Production changes नहीं।


## 2026-11-13 — Customer refund history stable ordering and privacy regression

- Refund history RPC `srk_customer_list_my_booking_refund_requests()` पहले केवल `created_at DESC` पर sort करता था; समान timestamp पर क्रम स्थिर नहीं था।
- अब secondary `id DESC` tie-breaker जोड़ा गया। Customer-only filter `customer_user_id = auth.uid()`, bounded result `LIMIT 100`, और output में admin note / Razorpay provider metadata / internal refund record ID शामिल न होने की source assertions जोड़ीं।
- Source Regression Run #43470921740 — success, head `f319f81e653ea3b55cc9a513f65aaf63058347c1`.
- यह source-level verification है; SQL/pgTAP, Supabase JWT/RLS runtime और actual refund workflow अभी execute नहीं हुए। No Production migration, deployment, or money movement.


## 2026-11-13 — Customer Payment/Refund status label regression coverage

- Customer Payment History RPC के पाँच event types (`payment`, `refund_request`, `refund`, `manual_payment`, `manual_refund`) के लिए UI label mapping source-checked।
- Status mapping में paid/captured/refunded, recorded/processed, requested/in_review/approved/processing, unknown/requires_reconciliation, failed/rejected labels की regression coverage जोड़ी।
- Refund History UI के requested, in_review, approved, processing, unknown, processed, rejected, failed status labels की अलग regression coverage जोड़ी।
- Source Regression Run #43471201722 — success, head `c9956d98ec7ac4e2765924136b7cd2c0cc617662`.
- यह static/source regression है; actual RPC response fixtures, SQL pgTAP, live Supabase runtime और browser/mobile display tests अभी बाकी हैं।


## 2026-11-13 — Customer Booking History session/error handling

- `loadCustomerBookings()` में Supabase Auth `getSession()` पहले try/catch के बाहर था; session retrieval/network error पर unhandled rejection हो सकता था और loading state ठीक से संभल नहीं सकती थी।
- Session retrieval अब guarded try/catch के अंदर है; stale async session response sequence token से ignore होता है; error पर उपयोगकर्ता को पुनः प्रयास संदेश और latest request के लिए `aria-busy=false` मिलता है।
- Regression assertion जोड़ा गया।
- Source Regression Run #43471437666 — success, head `89648207d551fa52272cbe2f75449920ebced17b`.
- वास्तविक Auth/network outage simulation, browser interaction और mobile/Desktop QA अभी बाकी हैं।


## 2026-11-13 — Customer Saved Address Auth resilience

- `loadCustomerSavedAddresses()` और `saveCurrentBookingAddress()` में Auth `getSession()` पहले try/catch के बाहर था; नेटवर्क/Auth failure पर unhandled rejection हो सकता था और disabled state अटक सकती थी।
- दोनों functions में session lookup अब try/catch के अंदर है; session error स्पष्ट रूप से handle होता है; list/save controls finally में पुनः enable होते हैं।
- Regression test जोड़ा।
- Source Regression Run #43471742069 — success, head `fd305818f2d83d9b831f02015ada0a6166c8917d`.
- वास्तविक Auth outage, saved-address RPC/RLS और browser/mobile interaction अभी runtime-tested नहीं हैं।


## 2026-11-13 — Customer Auth session synchronization and Support send resilience

- `syncCustomerSession()` में `getSession()` का error पहले unchecked था; अब try/catch, explicit error handling और monotonically increasing sequence guard है, ताकि पुराना Auth response नए login/logout state को overwrite न करे।
- Session sync के दौरान हर async customer-data load के बाद sequence check जोड़ा, जिससे बीच में login state बदलने पर पुराना sync आगे काम न करे।
- Customer Support message/file भेजते समय `getSession()` error अब स्पष्ट रूप से पकड़ा जाता है; null/invalid session से user ID पढ़ने का जोखिम हटाया।
- Regression tests जोड़े।
- Source Regression Run #43472067910 — success, head `2c33e8b9a38db89cb967e7edaec203f234817c09`.
- वास्तविक Supabase Auth event race, network failure, message upload/RLS और browser/mobile UI runtime tests अभी बाकी हैं।


## 2026-11-13 — Customer refund submission success/refresh separation

- Customer refund request RPC success को अब booking/payment/refund history refresh से अलग रखा गया है।
- Server से request creation की पुष्टि मिलते ही UI साफ़ बताता है कि अनुरोध दर्ज हो गया; बाद में history refresh विफल होने पर अब गलत तरीके से “रिफंड अनुरोध दर्ज नहीं हो सका” नहीं दिखेगा।
- Booking list, refund history और payment history refresh को अलग-अलग `Promise.allSettled` से चलाया; refresh समस्या पर स्पष्ट संदेश कि अनुरोध सुरक्षित है और सूची रीफ़्रेश करनी है।
- Regression test update के बाद Source Regression Run #43472895185 — success, head `c90f278ab0f6a5f5ccd9796368aae4888bc3ea50`.
- वास्तविक RPC/network failure, browser UI और database/RLS runtime परीक्षण अभी बाकी हैं; Production में कोई बदलाव नहीं।


## 2026-11-13 — Customer saved-address and profile stale-load race protection

- Saved-address loader में sequence guard जोड़ा: पुराने Auth/RPC response अब नए address list, selected default या control enabled/disabled state को overwrite नहीं करेंगे।
- Customer profile loader में sequence guard जोड़ा: पुराने profile/avatar fetch अब नए profile state को overwrite नहीं करेंगे; avatar preview के बाद भी latest-request check है।
- Regression assertions update किए।
- Source Regression Run #43473708324 — success, head `6833a1175e6a68a0fb0628aaef4b7e02a766fee0`.
- Real concurrent Supabase Auth/RPC, storage avatar, browser interaction और final mobile/Desktop QA अभी बाकी हैं। SQL/Production/deployment में कोई बदलाव नहीं।


## 2026-11-13 — Customer Support complaint creation/refresh separation

- `createCustomerSupportComplaint()` में शिकायत create RPC सफल होने के बाद complaint-list या message-thread refresh विफल होने पर पहले गलत “शिकायत दर्ज नहीं हो सकी” संदेश दिख सकता था।
- अब server से complaint ID मिलने के बाद creation को सफल माना जाता है; list/thread refresh को अलग से संभाला जाता है। Refresh विफल होने पर शिकायत दोबारा दर्ज न करने की स्पष्ट चेतावनी और thread refresh निर्देश दिखते हैं।
- नए complaint ID को select list में अस्थायी रूप से जोड़ा जाता है, ताकि list refresh failure के बावजूद ग्राहक उसी शिकायत thread को चुन सके।
- Source regression test जोड़ा गया। GitHub Actions workflow result अभी प्राप्त नहीं हुआ है; test को passed नहीं माना गया है।
- केवल feature branch source change; SQL/RPC schema, Production, deployment और वास्तविक Supabase runtime में कोई बदलाव/परीक्षण नहीं।


- पहली regression run #43474003202 में test assertion regex syntax error से suite fail हुई; application source test तक execute नहीं हुआ था। Assertion को string-based check से सुधारा और rerun commit 824522d6da4fb0d8596ac2fe9c2c4a0988d2bd68 पर trigger किया है। नया workflow परिणाम आने तक test status pending है।


- Corrected source regression assertions after two test-only failures (regex escaping/match assumptions). Final GitHub Actions Source Regression Run #43474230056 completed successfully on commit `274c7c465045235c6113ecc3fd6fa72189082af0`. This verifies source-level regression suite only; it does not prove live Supabase RPC, Storage, browser or device behavior.


## Customer Support attachment thread consistency — 2026-11-13

- Message/attachment send के दौरान complaint selector पहले enabled रहता था। ग्राहक upload के बीच दूसरी शिकायत चुन सकता था; बाद का thread refresh गलत चयनित शिकायत पर जा सकता था।
- अब send प्रक्रिया के दौरान complaint selector disable होता है और `finally` में उसकी पिछली disabled स्थिति restore होती है। इससे upload/message operation के बीच thread बदलने से रोका गया है।
- Source regression assertion जोड़ा गया। नया workflow result अभी pending है। यह source-level safeguard है; browser और वास्तविक Storage upload QA अभी नहीं हुआ। Production/SQL में कोई बदलाव नहीं।


- Support attachment cleanup failure handling: orphan-object removal is now wrapped against both returned Storage errors and thrown network exceptions, so cleanup failure cannot bypass the customer-facing partial-send recovery path. Added source regression coverage. Commit `aaafcd6fbd652ba9799350e9277dd384fc5fe503`; test commit `54340a73e80cbd1e4d6cac442543c651834a01f6`. Workflow result pending at tracker update. No live Storage test or Production change.


- Cleanup regression assertion was updated to match the new guarded `try/catch` cleanup implementation. GitHub Actions Source Regression Run #43474653510 completed successfully on commit `d85019882c845da9691ffd15e6939d65ebb17145`. This confirms source assertions only; actual Storage/network fault injection remains untested.


## Customer avatar cleanup network-failure handling — 2026-11-13

- Avatar cleanup previously handled returned Storage errors but a thrown network exception could make a successful profile update appear to have failed when deleting the old avatar.
- Both new-upload cleanup after profile RPC failure and old-avatar cleanup after successful profile update now catch thrown exceptions. The old-avatar cleanup failure is shown as a cleanup warning while the saved profile remains correctly reported as saved.
- Source regression coverage added. Commits: `6e8accb868392e6dba0b59dbdc2791485e62d0bf`, `138293fbee54b232c1ea620b87b2f10ccd705cca`. Workflow pending. Live Storage/network fault injection not run; no Production changes.


## Saved address write/refresh outcome integrity — 2026-11-13

- Saved address loader now returns an explicit success/failure result. Save, delete and set-default flows distinguish the successful database RPC from a failed subsequent list refresh.
- Customer is no longer told that the address operation fully completed/was confirmed when the refresh failed. The UI reports the write outcome and asks to reload/check state; default success is shown only when refreshed data confirms `is_default=true`.
- Source regression coverage added. Commits `6d3f31396236a190f49d075f7ba42340f4aa4050`, `8420941203e6b0122b86065654c47bb96eccef84`. Workflow pending. No live database/RPC or browser test; no Production change.


- Saved-address mutation race guard: delete/default operations now disable the address selector while the RPC and list refresh are in progress, prevent duplicate operation invocation, and restore the selector's prior disabled state in `finally`. Source regression assertions added. Commits `fd74dc8ddd75df2b4a5d1ba96ac5a24152c9a6f2`, `98bd3b163d87e36aa387e575b8673608e6a28189`. Workflow pending; no browser/concurrent interaction test or Production change.


- Customer Profile async race guard: beginning a profile save invalidates any older in-flight profile load; profile reload is skipped while save is active, preventing stale RPC/avatar responses from overwriting fields during/after a save. Source regression coverage added. Commits `9d158247b59bd9d46c006071f00f179c9dd11079`, `9d1a76e0310a1f7220aa029f338e46038da20175`. Workflow pending. No browser/network race injection or Production change.

- Regression CI attempts exposed two test-selector assertion issues (expected count too strict; newline match too literal), not application runtime failures. Assertions corrected in commit `599339ff4e63e8fe3e582bf2d5554f8e9324a15c`; rerun pending. Earlier source suite had 38/39 and then 38/40 passing; affected tests were the new assertions. Do not mark them passed until rerun succeeds.

- Corrected source regression suite completed successfully: GitHub Actions run `43475351432` — SUCCESS on tested commit `599339ff4e63e8fe3e582bf2d5554f8e9324a15c`. This verifies static source assertions only; no live browser/Auth/Storage/RPC/database race test has run.


- Saved-address save race guard: while a saved address create/update RPC and subsequent refresh are running, the saved-address selector and edit action are disabled. Their prior disabled states are restored in `finally`, preventing selection/edit changes from racing with the save completion handler. Source regression test added. Commits `d2a7f9cb07a61f780904acc41d2a6f1237aab4f3`, `7faf5f4515adde58e1209f273f40d0ef34049ff9`. Workflow pending. No browser interaction or live RPC test.


- Saved-address save-lock regression workflow `43475524612` failed only because an older Auth-recovery assertion expected the pre-lock `finally` text. The application implementation was not implicated: the actual `finally` correctly restores the prior disabled states of the selector and Edit button. Updated the stale assertion to match that behavior in test commit `499122a02039c8632305917079cbfef99f64cf66`. A fresh CI result has not yet been confirmed; do not mark the save-lock suite passed until the new run succeeds. No production, database, or live customer-data changes.


## Customer payment-history pagination concurrency guard — 2026-11-13

- Source review found `customerPaymentHistoryBusy` was declared but not used. Rapid repeated taps on “और रिकॉर्ड देखें” could start overlapping requests for the same offset and append duplicate payment-history rows.
- `loadCustomerPaymentHistory(false)` now exits when another payment-history request is active. During a request, More and Refresh controls are disabled; only the latest request sequence restores them and clears the busy state. A deliberate Refresh can supersede an older pagination request, while stale responses remain prevented from rendering. Offset advances only after the latest successful response.
- Source regression coverage added for duplicate-load prevention, control locking/restoration, offset advancement and stale-response guard. Commits: app `8e61d0c93d5dd188352997860ed0091d1e1a4795`; test `203de11687a7388fe5448c965f933cda12aa2246`. CI result pending; do not mark source suite passed until a successful run is confirmed. No SQL/Production changes, browser test, or mobile/Desktop QA.


## Customer refund-history pagination — 2026-11-13

- Refund history पहले एक बार में अधिकतम 100 रिकॉर्ड लौटाती थी और UI में आगे के रिकॉर्ड लाने का विकल्प नहीं था। बड़े/लंबे समय से सक्रिय ग्राहक खाते में पुराने refund requests छूट सकते थे।
- नया authenticated, SECURITY DEFINER overload `srk_customer_list_my_booking_refund_requests(integer,integer)` जोड़ा गया है। यह केवल `auth.uid()` के customer-owned refund rows लौटाता है, stable `created_at DESC,id DESC` ordering रखता है, page size 1–50 तक clamp करता है और offset 10,000 से अधिक होने पर reject करता है। पुराना zero-argument RPC compatibility के लिए रखा गया है।
- Customer Payments UI में “और रिफंड रिकॉर्ड देखें” pagination जोड़ी गई है; 25 records प्रति page, duplicate concurrent load guard, disabled controls, sequence-based stale response guard और successful page के बाद offset advance शामिल हैं।
- Migration `20261114210000_customer_refund_history_pagination.sql`, pgTAP plan 8 `supabase/tests/database/customer_refund_history_pagination.test.sql`, Supabase schema CI migration/smoke registration और source regression assertions जोड़े गए। Commits: UI `e3d222b5741e32d135381ef3a8e63a4b52e8d8f1`; migration `3386b86758bd69db2c66a8695e96906827c701f0`; pgTAP `2d86c2a316cb0def2189983e28845653687150f2`; CI `af90a295bbfe56cb94563a024ec6e988f61e031e`; source tests `cc80ea982b55de8c08215da9719b10f3d63d84b2`.
- SQL migration/pgTAP अभी execute नहीं हुए; CI success, live Supabase RPC, customer data, browser interaction और final mobile/Desktop QA प्रमाणित नहीं हैं। Production में कोई बदलाव नहीं।

- अतिरिक्त failure-path hardening: refund history के अगले page का network/RPC request fail होने पर अब पहले से लोड हुए refund cards नहीं हटेंगे। पुराने रिकॉर्ड सुरक्षित रहते हैं, Hindi warning उसी list में जुड़ती है और pagination offset आगे नहीं बढ़ता, ताकि ग्राहक उसी page को दोबारा प्रयास कर सके। Source regression assertion जोड़ी। Commits: app `0ce51a5e766490b2159f167a612b995ca8184c48`; test `496ca45ddd9f6458f5e37ea6c7a05bc6de62bbe9`. CI अभी प्रमाणित नहीं; database और browser tests अभी निष्पादित नहीं।

- Booking History pagination: पहले केवल नवीनतम 50 बुकिंग दिखती थीं। अब customer-owned query stable `created_at DESC, id DESC` ordering के साथ 25-25 रिकॉर्ड `.range()` से लाती है; “और पुरानी बुकिंग देखें” incremental cards जोड़ता है। Refresh पुरानी सूची reset करता है; sequence token stale responses रोकता है; एक समय में duplicate next-page request नहीं चलती; failed next page पर पहले से दिख रहे cards सुरक्षित रहते हैं और offset आगे नहीं बढ़ता। Secondary timeline/contact/refund data और labour bill अभी भी प्रत्येक दिखाए जा रहे page के लिए लोड होते हैं। App commit `e5567e16596c1755c76f7c102be3a1fb66a268ee`; source regression tests commit `e870f43fb304c1ed306b480326848e6e5aae5d28`. CI result अभी उपलब्ध/सत्यापित नहीं; SQL/browser/mobile QA नहीं किया गया।

- Payment History pagination failure-path भी मजबूत: अगले page की RPC विफल होने पर अब alert के बजाय उसी सूची में accessible Hindi status warning जुड़ती है; पहले से लोड भुगतान रिकॉर्ड सुरक्षित रहते हैं और offset आगे नहीं बढ़ता। Source regression assertion जोड़ी। App commit `3079d0cf5f4dd2f414e4f2e18d32bacf8cba2e2e`; test commit `670f537b8ed802f5438b48246e0ad3d409893f68`. CI/Browser/DB tests अभी प्रमाणित नहीं।

- Help & Support complaint-list refresh concurrency hardening: simultaneous refresh/list requests अब serialized हैं; pending refresh के दौरान duplicate list RPC नहीं चलेगी, और button/select loading states नियंत्रित हैं। Latest response guard stale list render रोकता है; `finally` में controls restore होते हैं। Source regression test जोड़ी। App commits `31c8eece6dc09d6e91b461c0f1b8eeb623a49c4d`, `b01d65c7f9cb9436512dd751dc611fd400e69053`; test commit `75ad5c37d3799330aa0b9eac6ef4c7faf0ea3781`. CI result, actual RPC/browser behavior अभी प्रमाणित नहीं।

- Customer History retry/date hardening: Payment History में malformed `occurred_at` आने पर अब `Invalid Date` नहीं दिखेगा; सुरक्षित “तारीख उपलब्ध नहीं” संदेश दिखेगा। Payment, Refund और Booking History के अगले पेज का अस्थायी load-warning सफल retry के बाद हटेगा, ताकि पुरानी error नई सफल स्थिति के साथ न रहे। Source regression test जोड़ा। App commit `dab16c7aefc27bc821e73bee1e7c236d34a7a4d9`; test commit `b3c4570ac209f61835f2d2ca5c66f5454bb2b353`. CI तथा live RPC/browser परीक्षण अभी प्रमाणित नहीं।

- Source regression assertions की अतिरिक्त समीक्षा में section-boundary string में escaped newline की गलती मिली; Customer History तथा Support complaint-list tests अब वास्तविक अगले function marker से source section काटते हैं। Test correction commit `e0513a17ab1f4f9b3419fb95e79beae5f67425ae`. यह test code correction है, test run/pass का दावा नहीं; CI execution अभी उपलब्ध नहीं।

- Customer work-start / work-completion response duplicate-submit hardening: एक ही booking के लिए start approval या completion approve/reject/dispute response के concurrent duplicate RPC अब in-memory per-booking guard से रोके जाते हैं। Confirmation cancel या validation failure पर completion guard lock नहीं होता; RPC success/failure के बाद `finally` guard release करता है। Start response भी `finally` में guard release करता है। Source regression assertions जोड़ीं। App commits `f35bc0e6ffbe9a61f1d33111300fb3fd77ac86e5`, `028d65b7e1742dcf8021779e9f5280ca308dd3ea`; test commit `684cd44c8500439836414845c9b3ddb20dce4511`. CI/browser/RPC runtime verification अभी नहीं हुई।

- Customer Profile Avatar async-race hardening: पुराने profile refresh का धीमा signed-URL response अब नई चुनी गई profile/avatar preview को overwrite नहीं कर सकता। `loadCustomerAvatar()` apply-guard स्वीकार करता है; Profile loader केवल उसी sequence और उसी current avatar path के लिए preview लागू करता है। Failure path भी stale request से preview clear नहीं करता। Source regression test जोड़ी। App commit `9a928dc1d2ecce67f0ab32d9fd6d075293684fbd`; test commit `e5da69ca704a5a9a1f7f191f2ce25e4b9561dcb3`. CI तथा वास्तविक Storage/browser concurrency test अभी नहीं हुआ।


- Avatar stale-response guard के बाद test audit में एक पुराना lifecycle assertion मिला जो `loadCustomerAvatar(path)` और बिना guard वाले call की अपेक्षा कर रहा था। उसे नए `shouldApply` guard और sequence/path-checked call के अनुरूप अपडेट किया। Test commit `3e96ea12f8a66c26008c5722990f17760f024aad`. यह assertion correction है; CI pass अभी प्रमाणित नहीं, और वास्तविक Storage/browser race test अभी बाकी है। Production/SQL में कोई बदलाव नहीं।


- Avatar regression workflow `43478827391` FAILED. Job log में Avatar-specific assertion सफल था; विफलताएँ दो पुराने Customer History source assertions में थीं: Payment History `finally` block के नए multi-line form को पुराना one-line regex पहचान नहीं रहा था, और Booking History test पुराने no-argument loader signature को खोज रहा था जबकि loader pagination के लिए `reset=true` लेता है। Test assertions अपडेट किए: `0125b97c80afaae773fe371f80041b6da6f65d05`, फिर payment/refund aria-busy checks को latest-sequence `finally` block के अनुसार ठीक किया: `6e3cf083b8e2b87c2ceb2d21fd2f68ae00f976f2`। नई CI run अभी सत्यापित नहीं हुई; इसलिए tests को PASS नहीं माना गया। Application source में इस failure से कोई runtime defect प्रमाणित नहीं हुआ।

- Source regression run `43479038892` failed only at the Customer Booking History `finally` assertion: implementation restores busy flag and `aria-busy` inside a multi-line latest-sequence block, while test expected immediate one-line form. Updated assertion to inspect the guarded block: test commit `54740226e568ab8d16782922f1fc2d63ec924d85`. No app source change. New CI result pending/unverified; do not mark suite passed.


- Source Regression workflow `43479148520` succeeded on tracker commit `f7caf6e` (latest full source suite at that point). Customer Support thread audit then found that message RPC errors could bubble out of `loadCustomerSupportMessages()` and become an unhandled rejection when called from complaint-selection flows; list refresh also risked misclassifying the error. Added an internal, sequence/selected-complaint-guarded catch with clear Hindi retry status and safe thread clearing. App commit `af749e6da622a66a6c9c50e959f880f693cf90e4`; added focused source regression test `df05be0c7f3ca3a3de2b0f928400dba315033a32`. New CI for these latest commits is pending/unverified. No DB/Storage/production changes; browser/mobile tests remain deferred to consolidated final QA.

- Customer Support thread hardening source workflow `43479236477` passed on app commit `af749e6`. The combined source workflow then failed only because the newly added test regexes were over-escaped (test expected literal backslashes); corrected the `try`, `catch`, and selected-thread guard regexes in test commit `b842467cf24d8839285dc3d726a9aaf546c57937`. This is a test-only correction; fresh CI not yet verified. Refund source workflow `43479236468` also failed on the same branch head; inspect its job log before considering refund checks passed.

- Follow-up CI audit: Customer Support thread error-handling test failed because its newly added regex was over-escaped; corrected in `b842467`. The refund-source workflow `43479236468` had passed handler/Admin syntax checks but failed a legacy test expecting `loadCustomerRefundHistory()` without the new pagination parameter and expecting the old no-argument RPC call. Updated that test to the current `reset=true` signature and paginated RPC arguments, then corrected its regex escaping. Test commits `e1b33201` and `228a140d`. No refund handler/runtime failure was reported by this log, but the full refund source suite remains unverified until rerun.

- Combined source regression run `43479486576` passed on tracker commit `8f3bcbc`; this includes Customer Support thread error-handling assertions after the regex correction. Refund source workflow `43479468005` still failed only because the loader-signature test regex treated literal parentheses as regex grouping; paginated RPC assertion and handler/Admin syntax checks passed. Corrected the signature assertion by escaping parentheses in test commit `be399c1467eae3c54aa23b2e6a7d0274de7dbd7b`. Refund suite rerun pending; no application or payment/refund runtime failure evidenced by this log.

- Refund source workflow `43479658215` again failed only at the loader-signature assertion: the regex was still double-escaped and matched backslashes literally. Replaced it with a direct `html.includes('async function loadCustomerRefundHistory(reset=true)')` assertion in test commit `3ddb83817edf058919dabcb4fc62359775c0b2f2`. Customer App source suite run `43479674489` passed on previous tracker head. Refund source suite must be rerun after this test-only correction; no runtime/SQL proof is implied.

- Refund Source Regression workflow `43479934002` succeeded on test commit `3ddb83817edf058919dabcb4fc62359775c0b2f2`; combined Customer App source workflow `43479951202` also succeeded on tracker commit `1d284033807f81d7e602353dab1dd8317584f36f`. This confirms source-level suites only, not SQL/DB/browser/provider runtime behavior.
- Customer Booking disclosure audit found stale language promising an electrician home visit/quotation, contrary to the approved no-separate-inspection-quotation model and customer-only materials policy. Updated `booking.html` disclosure: no separate home quotation; labour bill is server-recorded actual time × Admin-approved rate; materials are customer-provided/purchased and excluded from labour; payment after completion via selected Cash/Online method. Added regression assertion against legacy quote wording. App commit `97df24b288c42365fe9e26a48b675a75c30e557b`; test commit `86e9794d7ab93df772af7d80615ed5454583d84b`. CI rerun pending; no runtime/browser/DB verification and no production change. Rate-tier selection and pre-booking estimate display remain unresolved and must not be guessed.

- Customer pre-booking estimate audit: Master §1 requires visible applicable rate and estimated amount before booking, while §19.14/§19.17 explicitly keep customer work category (`selected_category`) separate from electrician Admin-approved commercial rate tier. Therefore the selected work type must not be used to guess a rate. Added a transparent estimate panel under the 1–8 hour duration selector showing each of the four published labour tiers and the corresponding duration-based estimate using integer-paise BigInt half-up arithmetic. It clearly states that the actual applicable tier depends on the assigned electrician's Admin-approved tier, the work category does not determine the rate tier, actual billing uses server-recorded billable minutes, and materials are excluded. `booking.html` commit `7d2e301b3a78649a0b2a50d2ad5f227bb5a5a060`; regression assertions commit `d24250960cbada0bb4fe88b470969a17ab135a9c`. Both non-empty inline scripts compile with `new Function` (2/2 PASS). Customer App source CI result pending; no browser interaction, SQL/DB test, live rate lookup, or production change. This panel shows all possible tier estimates, not a claim that one tier has already been selected for the booking.

- Booking submit-handler source audit found unused legacy variables/comments that still said the quote/final amount would be set after electrician inspection and constructed a zero/“अभी तय नहीं” amount message. They were not sent or used by the current API request, but contradicted the approved no-inspection-quotation flow and new estimate panel. Removed the dead legacy block; actual booking payload/API fields were left unchanged. `booking.html` commit `b205589ff76cd733afebb3b0a14e310426dbf94e`; regression test commit `3d84260f3317c3473e0e79673aa43cbab0930974`. Both non-empty inline scripts compile (2/2 PASS), and static check confirms old quote copy absent. CI pending; no API/DB/browser execution, no booking created, no production change.


## 13 नवम्बर 2026 — Customer Booking PIN / Date validation audit

- `create-booking.js` में तारीख का server-side validation India business timezone (`Asia/Kolkata`) के अनुसार जोड़ा: आज से पहले की तारीख reject होगी। इससे deployment server के timezone पर निर्भरता नहीं रहती।
- Same-day cutoff, booking business hours और future scheduling horizon तय नहीं किए गए हैं; कोई मनगढ़ंत समय-सीमा लागू नहीं की गई।
- `booking.html` में PIN के पास स्पष्ट सूचना जोड़ी कि फिलहाल केवल छह अंकों का format validate होता है; PIN से जिला/राज्य का authoritative postal match अभी सत्यापित नहीं है। ग्राहक को सही जिला/राज्य स्वयं जाँचने को कहा गया है।
- Regression assertions जोड़े गए: India timezone date guard और PIN validation disclosure।
- Commits: API `f92b88d3a8365007132e90344f2f9944be74df0e`; UI `a62858632820b45271d3ec5ce51fe9dcef73ff83`; tests `427057c154ac2392f5b2b8bb450c46fa3a596b32`.
- अभी ये source changes हैं; GitHub Actions result, runtime API test और database verification की पुष्टि बाकी है। PIN/district matching तब तक blocked रहेगा जब तक authoritative India Post PIN directory और mismatch handling तय/जोड़ी न जाए।
- अगला कदम: regression CI परिणाम देखना, फिर booking date/time validation के लिए boundary tests जोड़ना; same-day cutoff/business hours के लिए कोई नियम स्वयं न गढ़ना।


### 13 नवम्बर 2026 — Booking date/time boundary hardening

- India business date formatter को locale-dependent en-CA output से बदलकर formatToParts() आधारित YYYY-MM-DD बनाया; इससे runtime locale formatting पर निर्भरता नहीं रहती।
- Server validation पिछली तारीख रोकता है; तारीख की तुलना Asia/Kolkata business date से होती है।
- Handler regression tests जोड़े: पुरानी तारीख 400 पर reject और rate-limit/booking insert तक न पहुँचे; 23:59 वैध तथा 24:00 reject।
- Commits: timezone formatter 26472f950ceb6c1a2ba180970ccf5ce2c706b98f; handler tests b69b7363b341f0ef9f7a6f8136752e9908ed01cf.
- अभी source code/tests review मात्र है; test suite/CI का निष्पादन प्रमाण उपलब्ध नहीं। Same-day cutoff और booking hours अभी business decision की प्रतीक्षा में हैं। PIN-to-district authoritative validation भी अभी लागू नहीं।


### 13 नवम्बर 2026 — Customer booking markup review

- Booking form के PIN validation disclosure की HTML जाँच में paragraph closing tag की कमी मिली; उसे ठीक किया ताकि अगला Address label उसी paragraph के भीतर न रहे।
- Regression assertion जोड़ा कि PIN सूचना का paragraph सही तरह बंद हो और Address label उसके बाद आए।
- Commits: markup abc098af7e755b37142e275b086ef92a82180edb; assertion 6113a88f598cea62be36653fb7625e4232e25c78.
- Tests/CI अभी execute या verify नहीं हुए हैं।


### 13 नवम्बर 2026 — Customer Booking structured-input validation hardening

- Server handler में PIN Code, preferred date और preferred time को अब वैध लंबाई तक truncate नहीं किया जाता; malformed suffix मौजूद होने पर पूरा input validation तक पहुँचता है और format check उसे reject करता है। इससे `2718617`, `2026-12-01extra` और `10:30extra` जैसे input वैध prefix में truncate होकर स्वीकार नहीं होंगे।
- तीनों malformed-input मामलों के लिए handler regression test जोड़ा; हर मामले में अपेक्षित HTTP 400, कोई booking insert नहीं और public rate-limit RPC call नहीं होने की assertion है।
- Commits: handler `f50143243456fc19ed4956ebd21251f5e605ceb1`, source formatting correction `d8038fd39dc3e142b753a58954c56d97ed1feb2d`, tests `faed53ab37e40255aad3021f7bd2f224b4420737`.
- अभी Node tests/CI execute या verify नहीं हुए हैं। Production और database में कोई बदलाव नहीं किया।


### 13 नवम्बर 2026 — Customer App booking validation regression CI परिणाम

- Booking PIN/date/time trailing-character rejection test ने 3 cases के साथ पास किया: `2718617`, `2026-12-01extra`, `10:30extra` — सभी HTTP 400, कोई booking insert नहीं, और public rate-limit RPC call नहीं। Booking handler suite में 39/39 tests पास हुए।
- उसी push-triggered all-source regression workflow में Customer Menu test file के दो source-assertion syntax/closure दोष मिले; assertions को regex से हटाकर सुरक्षित `includes`/index checks में बदला और test block बंद किया। ये test-file defects थे, application handler failure नहीं।
- अंतिम workflow run **43482573166** (commit `42e884c98bb656eb87435728b8b19d5d7d83573d`) — सभी isolated source regression suites **SUCCESS**।
- इसका अर्थ source-level automated tests पास हैं; SQL/pgTAP, वास्तविक Supabase RPC/Storage, browser interaction और अंतिम mobile/Desktop QA अभी अलग से बाकी हैं। Production deployment/डेटाबेस बदलाव नहीं हुए।


### 13 नवम्बर 2026 — Customer Labour Estimate और canonical rate-card parity

- Customer booking estimate के चारों tier rates को canonical `lib/labour-billing.js` rate card से जोड़कर regression test में parity assertion जोड़ी।
- प्रत्येक tier के 1–8 घंटे के estimate को integer-paise half-up formula से canonical helper के विरुद्ध जाँचा; UI में प्रकाशित rate values भी उसी canonical rate card से मिलाई जाती हैं।
- Source regression workflow **43482879728** (commit `8e57eb253d2c323274c75874cf3326f61263a6b1`) — **SUCCESS**।
- यह source-level test है; वास्तविक browser rendering, user interaction और DB/runtime verification अभी नहीं हुए।


### 13 नवम्बर 2026 — स्वीकृत बुकिंग के बाद Customer–Electrician direct calling

- Audit में मिला कि customer contact RPC केवल active statuses लौटाता था और Customer Booking History completed बुकिंग पर electrician का मोबाइल नंबर छिपा देती थी। यह स्वीकृत नियम से मेल नहीं खाता था: electrician द्वारा booking स्वीकार करने के बाद दोनों पक्ष full number से सीधे कॉल कर सकें।
- नई migration `20261114220000_customer_contacts_after_completion.sql` private owner-scoped contact lookup में `completed` status भी शामिल करती है; केवल उसी ग्राहक की booking और assigned electrician का संपर्क लौटता है। `confirmed`/unassigned bookings पर नंबर नहीं खुलता।
- Customer Booking History UI में completed status पर नंबर छिपाने वाला अलग branch हटाया; उपलब्ध owner-scoped contact पर full number और `tel:` call action दिखेगा।
- pgTAP `customer_contacts_after_completion.test.sql` में authenticated-only execution, `auth.uid()`, booking ownership, assigned electrician और completed status के 5 assertions जोड़े। Supabase schema CI migration list और smoke check भी अपडेट किए।
- Source regression workflow **43483271638** (commit `92c9574a163663e28a414e5675d147787e348a7a`) — **SUCCESS**।
- pgTAP अभी execute नहीं हुआ; migration isolated DB या Production पर apply नहीं हुई; वास्तविक Supabase RPC/JWT और browser/mobile परीक्षण बाकी हैं।


### 13 नवम्बर 2026 — Customer Online Payment Preference action safety

- Booking History में Cash से Online (Razorpay) preference बदलने वाले action का audit किया। पहले repeated tap से समान RPC एक साथ चल सकता था और RPC सफल होने के बाद list refresh fail होने पर UI स्थिति अस्पष्ट हो सकती थी।
- Per-booking in-flight guard, button disable/restore और duplicate submission रोकथाम जोड़ी। RPC success के बाद list refresh failure को payment preference failure से अलग Hindi संदेश दिया; raw backend error ग्राहक को नहीं दिखाया।
- Source Regression workflow **43483640001** (commit `70471fe4b91cec8869b4cc306cb964d3c5e43914`) — **SUCCESS**। Refund Source Regression workflow **43483633710** (app commit `754fc2f365e9d70ee0f515ca5e0c582bf171e7b3`) — **SUCCESS**।
- ये source-level checks हैं; live Supabase RPC, concurrent browser clicks, network failure injection और mobile/Desktop QA अभी बाकी हैं। कोई भुगतान शुरू नहीं किया गया और Production में बदलाव नहीं हुआ।


### 14 नवम्बर 2026 — Customer 14.1.10 timer test parity: post-completion calling rule

- क्रमबद्ध 14.1.10 review के दौरान timer/billing pgTAP file में एक पुराना assertion मिला: वह वर्तमान customer contact implementation से completion के बाद फोन छिपाने की अपेक्षा कर रहा था। यह 14 नवम्बर की स्वीकृत post-acceptance direct-calling requirement और migration `20261114220000_customer_contacts_after_completion.sql` से टकराता था।
- केवल current customer contact implementation वाले assertion को अपडेट किया: अब यह सत्यापित करता है कि assigned booking owner के लिए `completed` status पर भी संपर्क उपलब्ध रहे। Legacy `srk_customer_get_my_booking_contacts()` का अलग active-only assertion नहीं बदला; वर्तमान Customer UI उस legacy RPC को call नहीं करता और उसका पुराना restrictive व्यवहार अतिरिक्त exposure नहीं बनाता।
- Test file commit: `b7b2722ec6056c1504cf8e90f250dbe0e1233d97`।
- यह test-source correction है, pgTAP निष्पादन नहीं। Supabase schema CI के लिए read-only DB URL secret/isolated test execution की उपलब्धता अभी सत्यापित करनी है; कोई migration apply, Production write, deploy या mobile/Desktop QA नहीं हुआ। 14.1.10 Partial/In Progress ही रहेगा।
- अगला resume point: 14.1.10 के completion/dispute/Admin resolution RPC, event trigger, bill creation authorization और payment/refund/payout consumer dependencies का targeted security review।


### 14 नवम्बर 2026 — Customer completion / dispute / immutable bill targeted source audit

- Feature branch पर `20261114040000_server_authoritative_labour_timer_and_bill_snapshot.sql` और `20261114060000_work_completion_admin_review_and_immutable_event_history.sql` की source-level समीक्षा की।
- Confirmed in source: electrician completion request केवल assigned approved/active electrician के लिए है, booking row lock लेता है और server clock से timer रोककर original completion-request timestamp रखता है; customer decision owner-scoped है; rejected completion timer फिर server clock से resume करता है; dispute के लिए कम-से-कम 20 अक्षर का कारण, complaint entry और paused timer है; Admin approval Admin-gated है, booking lock करता है, 20–1000 अक्षर कारण मांगता है और केवल stopped pending/disputed categorized booking पर bill बनाता है; immutable bill guard scoped transaction authorization, booking ownership/assigned electrician, original request timestamp और rate snapshot reconcile करता है; Admin work-event details private authorization से एक trigger-generated event में दर्ज होते हैं।
- दोनों मुख्य pgTAP files के declared plan और top-level assertion count मिलाए: timer/bill suite 101/101; Admin completion/event suite 22/22। यह केवल test-source count है, pgTAP execution नहीं।
- कोई नया code defect इस सीमित source pass में प्रमाणित नहीं हुआ। Concurrency/rollback, RLS under real customer/electrician/Admin JWTs, trigger execution, complaint write, bill immutability, Admin audit details, payment/refund/payout integration runtime में अप्रमाणित हैं।
- Production migration apply, Production data writes, deploy, payment/refund/payout execution या manual device QA नहीं किया। Customer App अभी Partial/In Progress; 14.1.10 को complete नहीं माना जाएगा।
- अगला resume point: customer UI में completion pending/reject/dispute states और retry behavior की handler-to-RPC contract parity; उसके बाद SQL test execution की सुरक्षित isolated व्यवस्था की समीक्षा।


### 14 नवम्बर 2026 — Customer completion response UI/RPC contract regression coverage

- Customer booking card में pending completion के लिए तीनों action labels/handlers source-reviewed: customer approve, reject/resume timer, dispute with required 20–1000 character reason. Handler वही RPC `srk_customer_respond_work_completion` और expected `p_booking_id/p_response/p_note` args भेजता है; duplicate-submit Set guard और finally cleanup मौजूद हैं।
- `tests/customer-menu.test.cjs` में नया source regression test जोड़ा: UI तीनों actions render करे, pending state gating, dispute length validation, RPC contract, confirmed success check और busy guard cleanup। Test source commit: `d63b4eeb2deab806917830c5601691ec206c6769`।
- अभी इस नए test commit का CI result उपलब्ध नहीं; इसे PASS नहीं माना गया है। Test static source contract है, browser click/real RPC behavior नहीं।
- SQL/pgTAP, real customer JWT, complaint creation, payment and final bill runtime, mobile/Desktop QA अभी बाकी। Production या deploy में कोई बदलाव नहीं।
- अगला resume point: नए regression test का CI परिणाम जाँचना; यदि pass हो तो Customer App के booking history completion controls और refresh/error recovery का अगला audit।

- Regression CI follow-up: run `43485649409` failed 56/57 only because the newly added test expected an incorrectly escaped inline HTML template string; application source was not implicated. Corrected the test to assert the three rendered handler occurrences and each response action separately in commit `c92313d7031ac0ba365cca3c1e4be3907c1c7e0a`. Fresh CI result is pending; do not mark the new test pass yet.

- Second CI attempt `43485736582` failed before executing the customer-menu suite because the corrected assertion still contained an over-escaped regular expression (syntax error). Replaced regex counting with plain string split counting in commit `ccd98e8a2b4b3d4d2a31374f4b067cea25a27f56`. Application source remains unchanged; test suite remains unverified until a fresh green CI run.


### 14 नवम्बर 2026 — Completion response refresh failure को सुरक्षित अलग किया

- Source Regression runs `43485803175` (completion test fix commit) और `43485824596` (tracker update) SUCCESS हुए। नए completion controls/RPC source contract test सहित suite green है; यह static source regression है, वास्तविक browser/DB test नहीं।
- UI/RPC contract cross-check में एक UX reliability defect मिला: customer completion response RPC सफल होने के बाद `loadCustomerBookings()` refresh fail होने पर पुराने catch block “जवाब दर्ज नहीं हुआ” दिखा सकता था, जबकि server ने response पहले ही commit कर दिया होता। इससे ग्राहक duplicate response retry कर सकता था।
- `booking.html` में server-confirmed response और subsequent history refresh को अलग किया: confirmation के बाद refresh failure पर स्पष्ट बताया जाता है कि जवाब दर्ज है, केवल सूची refresh करें और response दोबारा न भेजें। Busy guard finally में release होता है।
- App change commit: `404f0dfa863c16166a698feaafb2548d11089e48`; regression assertion commit: `5d4e502bcd36e494c25ecdc0418a746b6dca68f4`। Fresh CI result अभी pending; test pass का दावा नहीं।
- कोई DB migration apply, Production write, payment/refund, deploy या manual mobile/Desktop QA नहीं किया।
- अगला resume point: fresh source CI verify करना; फिर इसी response/refresh failure pattern को customer work-start response और other booking actions में जाँचना।


### 14 नवम्बर 2026 — Customer work-start response refresh recovery

- Completion response hardening पर CI सत्यापित: source regression run `43486182243` SUCCESS और combined Customer App source suite `43486203914` SUCCESS।
- उसी failure mode को work-start approval में पाया: `srk_customer_respond_work_start` सफल होने के बाद booking list refresh fail होने पर पुराना catch “जवाब दर्ज नहीं हुआ” दिखाता था। इसे अलग किया। अब server confirmation के बाद refresh fail हो तो ग्राहक को बताया जाता है कि मंजूरी दर्ज है और केवल सूची refresh करें, जवाब दोबारा न भेजें।
- App commit `38641c1d5a8dc4642160f947e96af6c2ec863786`; regression test commit `9c101243cb428e7eadca515949316bee1c7018da`। CI अभी pending; इसे pass न मानें।
- No DB/Production write, deploy, payment action or manual device QA. अगला कदम नए source CI की जाँच और Customer App के booking-action recovery audit को जारी रखना है।


### 14 नवम्बर 2026 — Customer booking actions / cancellation / refund / support recovery audit

- Customer booking actions की source review की: work-start approval और completion response server-confirmed-success बनाम list-refresh failure को अलग करते हैं; payment method change भी confirmed RPC के बाद refresh failure को success के रूप में सुरक्षित बताता है; refund request server success के बाद तीन history lists को independent refresh करता है और partial refresh failure बताता है; support complaint/message paths server-created complaint/message को refresh failure पर दोबारा भेजने से रोकते हैं।
- Cancellation policy parity: Customer booking card स्पष्ट रूप से कहता है कि cancellation के लिए Help & Support में request भेजें और अंतिम निर्णय Admin करेगा। Customer UI में direct self-cancel RPC action नहीं मिला। Help & Support complaint creation RPC इस request path का आधार है।
- Regression test added: `tests/customer-menu.test.cjs` verifies Admin-mediated cancellation wording, absence of direct customer-cancel RPC calls, and Help & Support complaint path. Commit `255eeb590f3a64f9426a0f686ebe88b21dbcad11`. Fresh CI pending; not marked passed.
- No new app code change required in this pass. Remaining proof gaps: DB pgTAP execution, actual authenticated customer JWT/RPC, attachment Storage failure injection, browser interactions, payment/refund runtime, final mobile/Desktop QA. No Production changes/deploy.
- Next: verify source CI; then continue Customer App profile/address and support thread error/retry contract review before considering Customer App complete.


### 14 नवम्बर 2026 — Customer Support booking selector async-race hardening

- Help & Support के संबंधित बुकिंग selector में stale async response race मिली: तेज़ refresh/session change के दौरान पुरानी request नई request के बाद लौटकर विकल्पों को overwrite कर सकती थी और selector को गलत समय पर enable कर सकती थी।
- `loadCustomerSupportBookings()` में monotonically increasing request sequence जोड़ा; Auth session response और booking query response दोनों के बाद latest-sequence guard; केवल latest request error UI बदलती है और केवल वही request selector की पिछली disabled state restore करती है। Query में `created_at DESC, id DESC` deterministic ordering भी जोड़ी। Customer ownership filter `customer_user_id=session.user.id` कायम है।
- App commit: `54441fee51d15489766bebdafb6c29818b06fbce`. Regression test commit: `cd00c2863f5590819d0cfe3a6d2de4e79c78ddfb`. CI result अभी pending verification.
- यह source-level race guard है; browser/network fault injection, actual Supabase JWT/RLS, database pgTAP और final mobile/Desktop QA अभी नहीं हुए। No Production changes/deploy.
- अगला कदम: source CI verify करना और Customer App में remaining Profile/Support user-flow edge cases का audit जारी रखना।

- CI follow-up: Customer App source regression run `43487261469` failed on an older saved-address test assertion that still expected unconditional `select.disabled=false`; the implementation already restores control state only for the latest sequence. Updated that assertion to match the guarded behavior in test commit `aeec34a53829085ad45440a6475c9aa95f70e2e0`. The failure was in stale test expectation, not an identified runtime defect. Fresh CI result pending; do not mark the new selector test passed until rerun succeeds.


### 14 नवम्बर 2026 — Customer Support booking selector pagination

- Help & Support शिकायत फॉर्म में संबंधित बुकिंग selector पहले केवल नवीनतम 50 बुकिंग दिखाता था; पुराने ग्राहक की बुकिंग शिकायत से जोड़ने में छूट सकती थी। इसे 25-record pages में बदला: `customerSupportBookingsMore` “और पुरानी बुकिंग देखें”, deterministic `created_at DESC, id DESC`, owner filter कायम, stable offset, duplicate next-page guard और stale-request sequence guard।
- Next-page failure पर पहले से दिख रहे booking options सुरक्षित रहते हैं और offset आगे नहीं बढ़ता; retry उसी page को फिर से लोड कर सकता है। Refresh नई sequence से पुराने response को निष्क्रिय करता है और original disabled state को भी सुरक्षित रखता है।
- App commits: `538422cae74e2087d228f7847b3eb8558a0c7e15`, `222f17c3ccfd8db2dfd46b60ba27bc088813fbc4`. Regression test commit: `80bef1698f6b7601cd49e591e487767875fc6893`. CI pending; not marked passed.
- यह source-level change है; browser pagination, real Supabase RLS/JWT, DB pgTAP, Storage runtime और final mobile/Desktop QA अभी बाकी। No Production changes/deploy.

- CI follow-up: Source run `43487545567` exposed two stale assertions in the newly added test itself: it searched the old no-argument loader signature and expected the pre-pagination busy guard. Updated both assertions for `loadCustomerSupportBookings(reset=true)` and the new combined guard in test commit `c825aeec7cf314c66fec3cfa754a56e986d1f9ea`. No application failure was reported by those assertions. Fresh source CI pending; do not mark selector pagination test passed until a green run.

- CI run `43487632427` then caught one remaining old assertion in the first stale-response test: it expected the former single-control `finally` form, while paginated loader now restores both selector and “load older” button and resets its busy state in a guarded block. Updated that assertion in test commit `eb8e8e552a724dfa17e85afd36bf780a8ffc963d`. App code was not implicated by this assertion. Fresh CI pending.

- अतिरिक्त wiring review में नया “और पुरानी बुकिंग देखें” control का click listener छूटा हुआ मिला। Listener `loadCustomerSupportBookings(false)` से जोड़ा और regression test में इसकी wiring assertion भी जोड़ी। App commit `341a582a667df0a578f8c0b9402a4ea0acb9b181`; test commit `1374cd70dd05c8fa58167e3edb30d7dc841ee68f`. पहले चल रहा CI run पुराने commit का है; नए head पर fresh run जरूरी है।

- Source CI run `43487798612` completed with 59/60 Customer Menu tests passing. The only failure was another legacy assertion at the earlier support-booking test expecting the old no-argument loader signature; the new pagination and stale-response tests both passed. Updated the remaining assertion to `loadCustomerSupportBookings(reset=true)` in test commit `2dd67aeaee718f12d108679e83bb37d38182bf84`. Fresh run pending.

- Source CI run `43487870305` had 59/60 tests passing; the remaining failure was the old selector test still asserting `.limit(50)` after pagination moved to `.range(requestedOffset, requestedOffset+24)`. Updated this test assertion in commit `71808be961ea2045c39476ffb04fc5c358bff3f1`. The new pagination and stale-response regression tests were both green in that run. Fresh CI pending.

- Verification: Source Regression run `43487953782` on code/test commit `71808be961ea2045c39476ffb04fc5c358bff3f1` completed **SUCCESS** after the legacy selector assertions were aligned. This covers the Customer Menu suite including both new support-selector race/pagination tests. Tracker-only follow-up commit `52cd09b2fca286434d4b9a5d1204258a6ecbae0d` has a separate queued workflow at the time of this note; no new app code after the successful test commit. Browser, real DB/RLS, pgTAP and final mobile/Desktop QA remain unverified.


### 14 नवम्बर 2026 — Customer Support attachment signed-link failure visibility

- Support thread source audit में एक UX/diagnostic gap मिला: attachment metadata RPC सफल होने पर भी individual Storage signed URL failure को `null` में बदल दिया जाता था, लेकिन ग्राहक को यह नहीं बताया जाता था कि फ़ाइल लिंक अस्थायी रूप से उपलब्ध नहीं है।
- अब attachment object में `signedUrlError` flag रखा जाता है और disabled link के label में स्पष्ट हिन्दी संदेश दिखता है: “फ़ाइल लिंक अभी उपलब्ध नहीं; थ्रेड रीफ़्रेश करें”. इससे broken link पर click करने की कोशिश और silent failure से बचाव होता है; signed URL न होने पर link navigation disabled ही रहती है।
- App commit: `753b8d430f1078d8e869e9ff9764cba7cd48bbc9`. Regression test commit: `c404237978bfbe1de337ad993c69ba2e10873a08`. Fresh CI pending; not marked passed.
- No Storage policy/runtime change, no DB/Production changes. Real signed URL expiry/failure injection, database pgTAP and final mobile/Desktop QA remain pending.


### 14 नवम्बर 2026 — Customer Profile session privacy cleanup

- Profile audit में एक privacy edge case मिला: OTP session अनुपस्थित होने पर profile loader केवल login संदेश दिखाता था, पर पुराने in-memory phone/name/avatar preview को साफ़ नहीं करता था। Shared device या session expiry पर stale profile information दिखाई रह सकती थी।
- No-session branch अब profile phone/name fields खाली करता है, current avatar path reset करता है और avatar preview clear करता है; OTP login message कायम है। Booking form का अलग contact name field जानबूझकर नहीं मिटाया गया।
- App commit: `73c266dce2aceb81aa6d890bec3f9ee721743aee`. Regression test commit: `48a5fcf14a39de7bf21ea49db4a9302e52340028`. Fresh CI pending.
- Previous support attachment change: source regression `43488271607` SUCCESS on test commit `c404237978bf`; app source regression `43488248308` SUCCESS on app commit `753b8d430f10`. New no-session privacy test is not yet passed.
- No Production changes/deploy. Browser session-expiry test, real Auth/storage checks, DB pgTAP and final mobile/Desktop QA remain pending.


### 14 नवम्बर 2026 — Customer logout account-isolation hardening

- Auth/session lifecycle audit में logout के समय stale in-flight async responses और पुराना saved-address/form data memory/DOM में रहने का जोखिम मिला। Dashboard hide होने के बावजूद पुराने account के hidden controls और pending responses दूसरे login के समय cross-account state overwrite कर सकते थे।
- Logout/no-session branch अब Profile, Saved Address, Support Complaint/Thread और Support Booking selector के request sequence tokens invalidate करता है; busy flags/control state reset करता है ताकि stale response render न हो और अगले login पर loader stuck न रहे।
- पुरानी saved-address list/selection, complaint/thread attachments, support booking options, profile name/phone/avatar और booking address/GPS fields clear होते हैं; map preview hide होता है।
- App commits: `4d7138dcdc3bfbcd82699d5f6a06af2f5f2c0d08`, typo correction `e4c1ede56f7c3904b7e4969a9c43d1e50f83f215`. Regression test commit: `e29b067e89b1d674b394de7aea318c7779c07ab6`. Fresh CI pending; not marked passed.
- Prior source CI: support attachment signed-link change run `43488271607` SUCCESS; profile no-session clearing run `43488577045` SUCCESS; associated refund source run `43488552371` SUCCESS. New logout invalidation test not yet passed.
- No Production changes/deploy. Real Auth signout/session-switch race injection, Supabase Storage/RLS and pgTAP tests, browser, final mobile/Desktop QA remain pending.

- Verification update: Customer App source regression run `43488811755` completed **SUCCESS** (job `132104230681`) on test commit `e29b067e89b1`; this includes the logout account-isolation regression test. Earlier app source run `43488754507` was also **SUCCESS** on app commit `4d7138dcdc3b`, and Refund Source Regression run `43488754454` was **SUCCESS**. These are source-level tests only, not browser/Auth runtime or database proof.


### 14 नवम्बर 2026 — Customer booking/payment/refund history logout race fix

- अगले auth-isolation audit में पाया कि booking, payment और refund history के अपने async request sequence थे। Logout पर इन्हें invalidate नहीं किया जा रहा था; pending पुराना response logout के बाद hidden dashboard/history में लिख सकता था और busy/aria-busy/pagination controls अटके रह सकते थे।
- No-session branch अब तीनों history sequence counters बढ़ाता है, busy flags और offsets reset करता है, “और रिकॉर्ड” controls hide/enable करता है, refresh controls restore करता है और aria-busy हटाता है। इससे stale in-flight responses render नहीं होने चाहिए और अगला login clean history load से शुरू होता है।
- App commit: `6a8202b306c7bebbd3c2610baa313ff1fd37d3df`. Regression test commit: `fca8c835cc4db1eef295e87d86a3b8a474240792`. CI pending.
- No Production changes/deploy. Auth/session race injection, browser testing, database pgTAP and final consolidated mobile/Desktop QA remain pending.

- Verification update: Customer App source regression run `43489083654` completed **SUCCESS** on test commit `fca8c835cc4d`; logout history invalidation assertions passed. App source regression run `43489059944` **SUCCESS** on app commit `6a8202b306c7`; Refund source regression `43489059892` **SUCCESS** on the same app commit. These remain source-level checks only.


### 14 नवम्बर 2026 — Customer App async mutation session-generation guard

- Logout/account-isolation audit में केवल read loaders नहीं, बल्कि चल रहे customer mutations भी जोखिम में थे: Support message + attachment upload/link, नई complaint creation और Profile/avatar save. Session बदलने के बाद इनका पुराना response स्क्रीन/controls को अपडेट कर सकता था या अगला attachment upload शुरू कर सकता था।
- अलग customerSessionGeneration guard जोड़ा गया। SIGNED_OUT, SIGNED_IN और USER_UPDATED auth events पर generation बदलती है; routine TOKEN_REFRESHED पर नहीं, ताकि सामान्य token refresh के कारण वैध काम अनावश्यक रूप से abort न हो।
- Support message flow में Auth lookup, message RPC, प्रत्येक upload, प्रत्येक attachment-link और thread refresh के बाद generation जाँची जाती है। Session बदलने के बाद अगली upload/link या stale success/error UI update नहीं चलती।
- Complaint creation और Profile save में भी awaited RPC/upload/preview/refresh के बाद generation guard जोड़ा गया। पुराने operation का finally नई session के controls/busy flags को unlock या overwrite नहीं करता; no-session cleanup Support action buttons और busy flags reset करता है।
- App commits: 8a96969a5e25cf8689ff879e23b57924fe5f8780, follow-up token-refresh behavior d535ea8cc6a70aa7a0b5fdc1681defd42f81eba9. Regression test commits: 7037d60b0d165910cb842eb1c59c6f976241c47f, assertion alignment 47b50fa1f278c0e99e4a841e6fa826d313968a68, final assertion correction 664f5595e777f30ab202e6eed487c8364de8eeac.
- Verification: Customer App source regression run 43490490566 completed SUCCESS (job 132110071623) on test commit 664f5595e777. Refund Source Regression on app commit d535ea8cc6a7 also completed SUCCESS (43490258584).
- Scope limitation: ये source-level regression assertions हैं; वास्तविक browser logout बीच RPC/upload के दौरान, Supabase Auth/Storage runtime, orphaned upload cleanup, real session-switch race और final consolidated mobile/Desktop QA अभी बाकी हैं। Upload/RPC पहले से server पर स्वीकार हो चुका हो तो client-side generation guard उस server-side action को retroactively cancel नहीं कर सकता।
- No Production changes, SQL execution, deployment, payout या payment movement.


### 14 नवम्बर 2026 — Customer Booking submit का logout/session-switch race guard

- Customer Booking submit handler audit में पाया कि booking create request के दौरान logout या दूसरे account के login पर पुराना response success/error alert और history refresh चला सकता था। साथ ही Auth getSession error को पहले स्पष्ट रूप से handle नहीं किया जा रहा था।
- Booking submit अब `customerSessionGeneration` और अलग `customerBookingSubmissionToken` दोनों capture करता है। SIGNED_OUT/SIGNED_IN/USER_UPDATED पर pending booking operation invalidate होती है, busy lock release होता है और submit control restore होता है। पुराने operation का finally नई operation के controls को reset नहीं कर सकता।
- Auth session lookup error अब explicit throw होता है। getSession, create-booking fetch और response JSON parse के बाद stale-operation guard है; session बदलने के बाद stale success/error UI और पुरानी booking history refresh रोक दी जाती है।
- Payment Checkout handler को booking-only operation guard से अलग रखा गया; उसका Auth lookup error handling स्पष्ट किया और regression assertion जोड़ा कि payment function में booking operation guard reference न आए।
- App commits: booking guard `86dfd2ba2405b1fb5d26f1709fa1c4add4413b8b`; targeted correction to keep booking-only guard out of Razorpay handler `3f3a2dbf06f3bee8146cb81ad11dd8950bc6e29c`. Regression test commits: `5c9593c852ed35c8bb6546aa4fc3d0a8086be331`, existing idempotency assertion alignment `c65cdad7b9d72d1b549b751c1bd53b17159b593a`, auth hook/payment isolation assertions `c95839db8676e574afbd45062f157f3fbf1599f9`, final test commit `9ddd82b3e61bf6d9ac3db5af5eab851311ae92ad`.
- Verification: Customer App source regression run `43491096981` completed **SUCCESS** on test commit `9ddd82b3e61b` (job `132112183613`). Customer App source regression run `43491075004` completed **SUCCESS** on app commit `3f3a2dbf06f3`. Refund source regression run `43491075008` also **SUCCESS**.
- Scope limitation: source-level checks only. Real browser logout during a pending API request, cross-tab session switch, actual Supabase Auth and booking API behavior, DB/RLS tests and final consolidated mobile/Desktop QA remain pending. A booking request already accepted by the server cannot be cancelled retroactively by this client guard; its idempotency key is retained for safe retry/reconciliation.
- No Production changes, database execution, deployment or payment movement.


### 14 नवम्बर 2026 — Customer Booking review confirmation और session guard verification

- Booking submit के पहले अब customer को नाम, सेवा, अनुमानित अवधि, पूरा पता/PIN, तारीख-समय और चुना payment method दिखाकर स्पष्ट browser confirmation माँगा जाता है। Confirmation में दोहराया जाता है कि duration estimate है, final Labour Bill server-recorded actual time/Admin-approved rate से बनेगा, सामग्री अलग है और payment काम पूरा होने के बाद होगा। Cancel करने पर कोई create-booking request या idempotency key जारी नहीं होती; handler का finally busy control restore करता है।
- Regression coverage में booking review confirmation के fields/terms, submit session generation guard, stale response handling और Razorpay payment handler isolation शामिल है।
- App commits: session-scoped booking submit `3f3a2dbf06f3bee8146cb81ad11dd8950bc6e29c`; explicit pre-submit confirmation `1d972f4fa12fd91fec32db0a759e197d778ac8f2`. Regression test commits: booking race/confirmation `7006b5ab3ed96b16608dbc4f5b3a9ed5f91b352d`; final combined source tests also include idempotency assertion correction `c65cdad7b9d72d1b549b751c1bd53b17159b593a` and payment-isolation test `9ddd82b3e61bf6d9ac3db5af5eab851311ae92ad`.
- Verification: Customer App source regression run `43491213105` completed **SUCCESS** on test/app commit `1d972f4fa12f`; Refund source regression run `43491213354` completed **SUCCESS**. Earlier booking session-guard source run `43491096981` and app-only run `43491075004` also **SUCCESS**.
- Remaining: manual browser confirmation cancel/accept, real API request count, cross-tab/session-switch injection, Supabase Auth/RLS and database pgTAP, and final consolidated mobile/Desktop QA are not yet tested. No Production change/deploy.

### 14 नवम्बर 2026 — PIN directory source decision / blocker

- PIN validation source search में Department of Posts द्वारा प्रकाशित All India Pincode Directory (OGD Platform) की monthly-updated catalog/resource मिला; catalog metadata में 10 Aug 2026 तक update दर्ज है। यह official source में PIN, post-office, district और state fields बताता है। India Post का “Know Your PIN Code” portal भी official user-facing reference है।
- इसे किसी अनधिकृत third-party PIN API या पुराने static GitHub dump से बदलना उचित नहीं होगा। OGD catalog का API/CSV resource ingestion और freshness/version policy तय किए बिना hard validation या district auto-correction नहीं जोड़ा गया। Existing address overwrite नहीं होगा; 271861 Balrampur UP और पुराने Azamgarh mismatch को अलग रखा जाएगा।
- Blocker: official data.gov.in API access के लिए registered API key / approved bulk CSV acquisition, snapshot provenance and refresh owner चाहिए। यह key/credential अभी उपलब्ध/verified नहीं है; इसलिए 14.1.3 PIN/district validation अभी **Blocked/Partial**, syntax-only validation ही है।
- Reference: OGD All India Pincode Directory catalog (Department of Posts): https://data.gov.in/catalog/all-india-pincode-directory-through-webservice ; India Post “Know Your PIN Code”: https://dac.indiapost.gov.in/mypincode/home . No external API dependency or production setting was added.


### 14 नवम्बर 2026 — Customer booking timeline status-change labels

- Customer booking history timeline audit में पाया कि status-change events (`booking_work_state_changed`) के लिए UI हमेशा generic “बुकिंग की स्थिति अपडेट हुई” दिखा रहा था, जबकि safe timeline RPC पहले से `new_status` देता है। इससे pending/assigned/accepted/en-route/arrived/start-approval/in-progress/completion-review/completed जैसे वास्तविक चरण ग्राहक को स्पष्ट नहीं दिखते थे।
- Timeline formatter अब `event_type` के साथ `new_status` भी देखता है और ज्ञात booking statuses के लिए स्पष्ट हिन्दी labels दिखाता है। Unknown status पर सुरक्षित generic fallback रहता है; event timestamps/actor roles और customer-owned RPC contract नहीं बदले।
- App commit: `f081cfbf0bdd58679c2ad3379869a9e739169b44`. Regression test commits: `7bfab6dcea2a2323d988d38a8224e63a7f7606fb`, existing timeline assertion alignment `3206bf3be879e70281e2ff9cb8a8ebe3eb893b8f`.
- Verification: Customer App source regression run `43491545377` completed **SUCCESS** on test commit `3206bf3be879`; Refund Source Regression run `43491421430` **SUCCESS**. Previous Customer App suite `43491302281` also **SUCCESS** for booking confirmation work.
- Limitation: timeline RPC event capture currently records booking creation and work/status transitions, not every offer-queue internal event or payment/refund event. This change improves only statuses already recorded; payment history remains a separate view. Offer/assignment/live-tracking and payment timeline integration need their own backend dependency audit and tests. No DB/Production changes.


### 14 नवम्बर 2026 — Customer OTP CI annotations audit और Node runtime guard

- पिछले OTP source workflow Run #5 (`959b083db244`) और Run #6 (`02bc05b`) की annotations/logs जाँचीं। दोनों में 2 non-blocking deprecation annotations थीं: पुराने `actions/checkout@v4` / `actions/setup-node@v4` का Node.js 20 runtime deprecation, और Node dependency stack से `[DEP0040] punycode` deprecation warning। OTP tests स्वयं 10/10 PASS थे; ये OTP logic failures नहीं थे।
- Current feature-branch OTP/source workflow पहले से `actions/checkout@v5`, `actions/setup-node@v5`, Node 24 पर है। इसे regression-proof करने के लिए `tests/otp-source.test.cjs` में workflow-version assertion जोड़ा; v4 actions लौटने पर CI fail होगा।
- Test commit: `c798ff82fc37b7cb14835edd5ee36e3cfe108383`. Full Customer App source regression workflow `43491986534` completed **SUCCESS** (Node 24 setup + all isolated source suites successful).
- Remaining OTP security items unchanged: actual OTP expiry, Supabase server-side resend/wrong-attempt rate limits, CAPTCHA/bot protection, session expiry/revocation and real SMS/browser E2E. Client-side 60-second cooldown is UX only, not server-side abuse protection. These depend on Auth provider configuration/runtime verification; no Auth settings were changed and no OTP was sent.
- The `punycode` deprecation notice is still an upstream Node dependency warning; no package upgrade was made without dependency provenance/compatibility evidence. No Production change/deployment.


### 14 नवम्बर 2026 — Customer OTP recipient binding hardening

- दोनों customer OTP entry points (`customer-login.html` और embedded `booking.html`) में OTP challenge अब उसी E.164 phone number से bind है जिस पर `signInWithOtp` request भेजी गई थी। Verification से पहले current phone और captured recipient match अनिवार्य है; user number बदलता है तो पुराना OTP input/challenge clear/hide होता है और cooldown के बाद नए नंबर के लिए नया OTP चाहिए।
- Send request के दौरान phone field बदलने की race भी संभाली: request लौटने पर current phone captured phone से अलग हो तो पुराना challenge UI में सक्रिय नहीं किया जाता।
- Regression tests `tests/otp-source.test.cjs` में standalone और embedded दोनों flows के recipient-binding, number-change reset और send-race guards जोड़े।
- Commits: standalone page `562291045ba9d29b8f68bb4eb081496a6eae64e3`, verification guard `0bff7c7899dffc373fb6bdf3c6af82923edeaa29`, send-race guard `889baae8737b796786ce56c55ab2a5ad7e812787`, embedded booking flow `5f451bbd3de9a2f1d80a045fd9a48eeca1088fec`, regression tests `d0935cd5439dee298588d25116f29b8a20553f4e`.
- Customer App source workflow Run `43492430070` completed **SUCCESS** on `d0935cd5439d`; booking source/refund checks also succeeded on `5f451bbd3de9`.
- Read-only Supabase project lookup: `gnqhoaqatmoiwwhgzkgm` is `ACTIVE_HEALTHY`, PostgreSQL 17. Browser config contains only Supabase publishable key (no service-role secret). Existing `srk_public_api_rate_limits` migration protects only `booking` and `application` API endpoints; it is not evidence of Auth OTP throttling. Available project metadata endpoint does not expose Auth provider OTP expiry/resend/wrong-attempt/CAPTCHA configuration. These remain unverified; no Auth settings changed and no live OTP was sent.
- Real SMS/browser E2E, server-side Auth abuse controls, session expiry/revocation and final consolidated mobile/Desktop QA remain pending. No Production SQL, Auth settings, or deployment changes.


### 14 नवम्बर 2026 — Customer App payment/refund RPC और Production schema parity audit

- Feature branch की Customer payment-history migration `20261114200000_customer_payment_refund_history_rpc.sql` पढ़ी। यह authenticated `auth.uid()` से केवल अपने bookings के payment/refund events लौटाती है, original 8-column RPC contract रखती है, manual payment entry मौजूद होने पर duplicate booking-payment row suppress करती है, और deterministic timestamp/event-id pagination करती है। Refund-request pagination migration `20261114210000_customer_refund_history_pagination.sql` अलग overload बनाती है; पुराने zero-argument RPC को compatibility के लिए रखती है।
- Production Supabase `gnqhoaqatmoiwwhgzkgm` पर केवल read-only catalog introspection किया। वहाँ `srk_customer_get_payment_history(integer,integer)` नहीं मिला; `srk_customer_get_my_booking_work_timeline()` भी catalog में नहीं मिला। Production में refund-list function का नाम `srk_customer_list_booking_refund_requests()` है (9 output columns, जिसमें `admin_note` भी है), जबकि feature-branch Customer UI `srk_customer_list_my_booking_refund_requests()` नाम call करती है और customer-safe 8-column shape अपेक्षित करती है। इसलिए branch UI और current Production RPC names/contracts में वास्तविक parity gap है; Production में migrations/deploy हुए बिना ये नई Customer history calls उपलब्ध मानना गलत होगा।
- Production catalog में `service_bookings` के legacy fields `amount_paid`, `payment_verified_at`, `payment_method`, `payment_status`, `razorpay_payment_id` मौजूद हैं। Refund tables में customer ownership, request status/amount, Razorpay refund status/payment/refund IDs तथा manual payment/refund audit fields मौजूद हैं। लेकिन Production `service_bookings.work_timer_seconds` अभी integer है और नई labour bill snapshot/category-duration migration family पहले की read-only audit के अनुसार अनुपस्थित है। अतः Production legacy schema presence को नई labour-only bill/refund readiness न माना जाए।
- Customer refund create RPC `srk_customer_create_booking_refund_request(uuid,text)` Production में मौजूद है; इसका legacy `amount_paid`-based behavior नए immutable labour-bill model के बराबर नहीं माना जा सकता। Feature branch की labour-only refund foundation और payment-history RPC migrations अभी source-only हैं; कोई SQL लागू नहीं किया।
- निष्कर्ष/अगला काम: Customer App को complete घोषित करने से पहले branch migration chain में सभी called RPCs की reproducible definitions, exact signatures/output contracts, grants और RLS/owner scoping verify करें; timeline RPC तथा refund list/payment history के Production-vs-branch drift को स्पष्ट deployment dependency के रूप में track करें। किसी legacy Production RPC को बिना migration/reconciliation plan के rename/drop/replace न करें। pgTAP/runtime/browser/mobile tests अभी execute नहीं हुए। कोई Production SQL, data, Auth setting, payment/refund, या deployment परिवर्तन नहीं किया गया।


### 14 नवम्बर 2026 — Booking Timeline lifecycle coverage का Production read-only audit

- Feature-branch migration `20261114060000_work_completion_admin_review_and_immutable_event_history.sql` का trigger source review किया। यह `service_bookings` INSERT/UPDATE पर append-only `srk_booking_work_events` में booking creation, work-start request/approval/rejection, completion request/rejection/dispute/customer approval/Admin approval, timer start और अन्य booking state changes दर्ज करता है। Trigger में offer-queue table का event capture नहीं है; payment/refund tables के events भी इस work-event trigger से नहीं आते।
- Production read-only introspection में `service_booking_status_history` मिला। उसका trigger केवल booking INSERT और `status` बदलने पर old/new status, note और actor लिखता है; work timer/start/completion approval lifecycle इसमें नहीं आता। Production `srk_admin_audit_events` trigger booking के सीमित fields (status, payment_status/method, amount_paid, quote_status, service_charge, materials_amount, assigned_electrician_id, commission_amount) बदलने पर Admin audit बनाता है; यह customer-facing immutable timeline contract नहीं है।
- Production `job_offers` table में `booking_id`, `electrician_id`, `status`, `match_level`, `created_at`, `responded_at` मौजूद हैं, लेकिन offer transitions के लिए कोई customer timeline RPC/event stream इस audit में प्रमाणित नहीं हुआ। इसलिए customer को offer sent/accepted/declined/expired जैसे lifecycle updates दिखाने का दावा अभी नहीं किया जा सकता।
- Production में `service_bookings` पर legacy status-history, Admin audit, commission, cancellation-offer और work-approval triggers मौजूद हैं; Feature Branch की append-only work-event trigger Production में उपलब्ध होने की पुष्टि नहीं हुई। Timeline UI/RPC के लिए Production parity अभी unresolved है।
- निष्कर्ष: Timeline को केवल वास्तविक source events से render करें; अनुमानित offer/payment/refund events न बनाएं। Customer timeline में booking/work lifecycle, offer/assignment lifecycle और payment/refund lifecycle की अलग-अलग authoritative sources/ownership, ordering और privacy contracts तय व test होने चाहिए। Offer events जोड़ने से पहले `job_offers` state transitions और customer-safe fields का source audit करें; payment/refund timeline पहले से अलग Payment History में है, इसलिए duplicate rows न बनाएं। कोई Production SQL/trigger/RPC/data परिवर्तन नहीं किया गया।


### 14 नवम्बर 2026 — Customer App offer/assignment source-state audit (feature branch)

- Feature branch के tracked SQL source artifacts (`SUPABASE_SCHEMA.sql`, `PORTAL_SCHEMA.sql`) और `create-booking.js` में offer flow का source-level audit किया। Schema artifact में `job_offers.status` के मान `offered`, `accepted`, `declined`, `expired`, `cancelled` हैं; प्रति booking/electrician unique constraint है; offer row में `match_level`, `created_at`, `responded_at` हैं। Table RLS-enabled है और baseline schema में client direct read/write policy नहीं है।
- Booking handler स्वयं offer rows insert नहीं करता: वह `broadcast_new_booking` trigger द्वारा offer queue बनने की अपेक्षा करता है और फिर केवल offer count/match level पढ़ता है। यह response booking submission के समय queue snapshot है; बाद के electrician responses या customer-facing lifecycle feed नहीं। Queue read failure अलग Hindi warning देता है।
- Tracked `PORTAL_SCHEMA.sql` में `srk_respond_to_offer(uuid,text)` केवल logged-in, approved और active electrician की अपनी `offered` row स्वीकार करता है। Accept पर booking को तभी assign करता है जब अभी unassigned हो और status `new/confirmed` हो; accepted offer पर उसी booking के अन्य `offered` rows को `expired` करता है। Decline पर केवल उस offer को `declined` करता है। सभी बदलाव `job_offers` में `responded_at` लिखते हैं।
- इस audit में inspected artifacts में offer timeout/automatic expiry scheduler, offer-status-to-customer RPC, customer-safe offer event stream, या offer lifecycle को `srk_booking_work_events` में capture करने वाला trigger प्रमाणित नहीं हुआ। इसलिए customer timeline में offer sent/declined/expired events दिखाना अभी सुरक्षित नहीं; केवल booking status change से offer response का अनुमान नहीं लगाया जाएगा।
- सावधानी: ये tracked SQL artifacts source evidence हैं, current Production deployment या active migration-chain parity का प्रमाण नहीं। Existing Production read-only audit में `job_offers` table था, लेकिन customer-facing offer event feed प्रमाणित नहीं हुआ। No SQL/Production changes, no electrician portal work. अगला dependency task: active migration-chain में `broadcast_new_booking` trigger, `srk_respond_to_offer` का canonical current definition, offer expiry mechanism और customer-owned read contract को verify करना; फिर idempotency/concurrency/RLS tests जोड़ने का निर्णय करना।


### 14 नवम्बर 2026 — Offer trigger और active migration-chain parity audit

- Feature Branch के tracked `supabase/migrations/` में Customer Booking Category/Duration, server-authoritative timer, immutable work events, completion review और refund migrations जाँचीं। इस inspected active migration set में `broadcast_new_booking` trigger की CREATE/REPLACE definition या `srk_respond_to_offer(uuid,text)` की canonical current definition नहीं मिली।
- `broadcast_new_booking` का व्यवहार `IMPLEMENTATION_PLAN_HI.md` में वर्णित है: PIN match पर approved/active electricians को offers, फिर राज्य/जिला fallback। `create-booking.js` भी इसी trigger पर निर्भर होकर queue को केवल पढ़ता है। लेकिन यह documentation/consumer expectation है, वर्तमान migration-chain में trigger की reproducible definition का प्रमाण नहीं।
- `srk_respond_to_offer(uuid,text)` की definition tracked legacy `PORTAL_SCHEMA.sql`/`COMPLETE_DATABASE_SETUP.sql` में है: approved-active electrician की अपनी offered row; accepted booking का atomic assignment; बाकी offered rows expired; declined response अलग। ये root-level SQL snapshots हैं, active migration-chain में canonical migration नहीं।
- Inspected sources में offer timeout/cron expiry mechanism नहीं मिला। केवल successful accept पर sibling offers expire करने का code मिला। इसलिए time-based expiry मौजूद है, ऐसा दावा नहीं किया जा सकता।
- निष्कर्ष: Offer generation और response का runtime path legacy SQL artifacts/documentation पर निर्भर दिखाई देता है, जबकि feature branch की active migration chain में उसका reproducible source स्थापित नहीं हुआ। इससे clean database rebuild, schema drift और production parity का जोखिम है। इसे अभी Customer App का unresolved backend dependency माना जाएगा; Electrician Portal phase शुरू नहीं होगी।
- अगला सुरक्षित कदम: migration history/Production read-only catalog से exact deployed trigger/function definitions और dependencies का मिलान; फिर existing behavior को नई additive, idempotent migration में formalize करने का design और pgTAP coverage। कोई migration apply, Production write, deployment या booking creation नहीं की गई।


### 14 नवम्बर 2026 — Production Offer Trigger/Response read-only verification और पूर्व निष्कर्ष सुधार

- पिछली Feature Branch artifact खोज में `broadcast_new_booking` और `srk_respond_to_offer` की active migration-chain definitions नहीं मिली थीं। उस आधार पर Production में भी definition अप्रमाणित बताना अधूरा था। इस चरण में वास्तविक Supabase Production project `gnqhoaqatmoiwwhgzkgm` पर read-only introspection किया और निष्कर्ष सुधारा।
- Production migration history में ये migrations दर्ज हैं: `20261108102323_harden_booking_broadcast_search_path`, `20261109094209_add_secure_admin_booking_offer_flow`, `20261109170626_expire_job_offers_when_booking_cancelled`, `20261111075205_wire_job_offer_push_webhook`, तथा `20261113081436_customer_booking_timeline`। इसलिए Offer flow Production migration history में मौजूद है; Feature Branch tracked migration files की उपलब्धता/parity अलग समस्या है।
- Production `service_bookings` पर `broadcast_new_booking` AFTER INSERT trigger, `public.broadcast_booking_job()` function मौजूद है। Function पहले exact PIN + state + district के approved/active electricians को `pincode` offers देता है; यदि PIN match count शून्य हो तभी same state+district fallback `district` offers बनाता है; `(booking_id,electrician_id)` conflict पर duplicate insert नहीं करता।
- Production `public.srk_respond_to_offer(uuid,text)` की वास्तविक definition पढ़ी: authenticated user आवश्यक; केवल अपने approved/active electrician profile की `offered` row; response केवल accepted/declined; accepted पर booking unassigned और `new/confirmed` होनी चाहिए; फिर assignment और status update; sibling offered rows expired; `responded_at` दर्ज।
- Production `job_offers` पर `trg_srk_push_job_offer` AFTER INSERT OR UPDATE भी है, जो Vault में `PUSH_WEBHOOK_SECRET` उपलब्ध होने पर `push-job-offer` Edge Function को HTTP POST भेजता है। यह push notification trigger है, Customer Timeline event feed नहीं।
- Migration history में `expire_job_offers_when_booking_cancelled` मौजूद है। इस audit में अलग wall-clock timeout/cron expiry mechanism की पुष्टि नहीं हुई; इसलिए automatic time-based expiry अभी भी unverified है।
- सुधारित निष्कर्ष: Production में offer generation/response definitions मौजूद और सत्यापित हैं। Feature Branch की tracked active migration files में उन्हीं definitions की reproducible parity अभी नहीं मिली। पिछली रिपोर्ट का Production definition “अप्रमाणित” वाला भाग इस read-only evidence से superseded है। कोई SQL write, migration apply, deployment या live booking नहीं की गई।


### 14 नवम्बर 2026 — Offer RLS, Schema और Customer Timeline की Production जाँच

- Production `public.job_offers` schema में columns: `id`, `booking_id`, `electrician_id`, `status`, `match_level`, `created_at`, `responded_at`; अलग offer-expiry timestamp/lease column नहीं मिला।
- `job_offers` पर RLS policy `electrician_and_admin_read_offers` authenticated SELECT तक सीमित है: Admin या संबंधित active + approved electrician profile owner अपने offers पढ़ सकता है। Table grants में authenticated को केवल SELECT मिला; INSERT/UPDATE/DELETE नहीं।
- Production `srk_get_customer_booking_timeline()` सिर्फ `service_booking_status_history` को customer-owned `service_bookings` से join करके पढ़ता है; यह `job_offers` events नहीं लौटाता। इसलिए customer को offer-created/declined/expired/accepted history इस RPC से नहीं मिलती।
- Production query में `cron.job` relation उपलब्ध नहीं था; इस जांच से pg_cron offer-expiry job की पुष्टि नहीं हुई। इसे “scheduler नहीं है” का निर्णायक प्रमाण नहीं मानना; extension/schema/alternative scheduler की जाँच बाकी है।
- कोई production write नहीं किया। अगला implementation design: offer event audit table + atomic offer lifecycle event capture (creation/respond/expiry/cancel), customer-owned safe read RPC, deterministic ordering/pagination, RLS/grant review और pgTAP coverage। Existing job_offers RLS/privileges यथावत रखें; ग्राहक को electrician IDs/phone/private fields expose न हों। साथ में Feature Branch में production offer trigger/response migration definitions की reproducible parity restore/verify करनी है।


### 14 नवम्बर 2026 — Customer App Offer Timeline implementation (Feature Branch only)

- Added `supabase/migrations/20261114230000_customer_safe_offer_timeline.sql`: private offer-event table, RLS enabled, direct client table privileges revoked, trigger capture for offer creation and status transitions (accepted/declined/expired/cancelled), and authenticated customer-owned timeline RPC. Event payload contains no electrician ID/phone/contact data.
- Added one-time backfill for currently existing offers: creation event and current final status event where available. Legacy intermediate history cannot be reconstructed; final-state event uses legacy `responded_at` timestamp where present.
- Updated `booking.html` Customer Booking History to load offer timeline alongside booking status timeline, merge and sort events, show Hindi labels, and surface a partial-load warning if offer timeline RPC fails.
- Added `tests/customer-offer-timeline.test.cjs` and npm script `test:customer-offer-timeline`; added pgTAP `supabase/tests/database/customer_safe_offer_timeline.test.sql` (10 assertions; NOT EXECUTED).
- Added source-only GitHub Actions workflow `.github/workflows/customer-offer-timeline-ci.yml`. No Production deployment or migration execution configured. GitHub push workflow result has not yet been retrieved; source tests are not marked passed. No browser/runtime JWT/RLS/trigger concurrency/mobile QA.
- Supabase changelog check: current November CLI v3 breaking change means database commands target local by default and hosted modifications require explicit `--remote`/confirmation. This work did not invoke CLI or modify hosted DB. (Reference: Supabase CLI v3 migration guide.)
- Commits: migration `dc458ba2d053f52c395d66e1d622e5261543c1ca`; customer UI `9d8e97a8ba9bbae3e325a27adbb928aa193796b2`; source test `8eb2329b4cf9bd07c4b8f7110a6f1c2cf073097f`; pgTAP `b5fe1c3a2f55327f7c0750b1f056d4bfd5f4deed`; package script `8383b65740a083f77d7c7a3e918c5683997ec280`; workflow `bc97da22ebdfb477852e08a20f0782a2cb05371a`.
- Next: retrieve CI result and fix any source-test failures; then static review of SQL against Production catalog and feature migration dependencies. Keep migration unapplied until isolated database/JWT/RLS tests and separate approval. Customer App remains active; do not move to Electrician Portal.


### 14 नवम्बर 2026 — Offer Expiry Scheduler और Push Trigger की अतिरिक्त Production जाँच

- Production extensions में `pg_net` 0.20.4 मौजूद; `pg_cron` extension मौजूद नहीं और `cron`/`pgagent` schema नहीं मिला। इसलिए इस project DB में pg_cron-आधारित offer timeout scheduler का प्रमाण नहीं है। बाहरी scheduler/Edge Function schedule अभी अलग से सत्यापित करना होगा; पूर्ण निष्कर्ष “कोई scheduler नहीं” नहीं है।
- `job_offers` पर वास्तविक trigger `trg_srk_push_job_offer` AFTER INSERT OR UPDATE मौजूद है; यह `private.srk_notify_job_offer_push()` चलाता है। Function Vault के `PUSH_WEBHOOK_SECRET` को पढ़कर `net.http_post` से `push-job-offer` Edge Function को webhook payload भेजता है। Secret अनुपलब्ध/कमज़ोर होने पर warning देता है और notification request queue नहीं करता। यह push notification है, expiry scheduler या customer timeline event नहीं।
- `service_bookings` पर `broadcast_new_booking` AFTER INSERT और `guard_new_booking` BEFORE INSERT मौजूद हैं। Broadcast function PIN match के बाद ही district fallback करता है।
- Production customer timeline `srk_get_customer_booking_timeline()` status history से ही आता है; branch का richer `srk_customer_get_my_booking_work_timeline()` नाम Production catalog query में नहीं मिला। Branch/Production RPC contract parity अभी अनसुलझी है।
- अगले implementation gate: Feature Branch का वास्तविक HEAD/tree और migrations directory resolve करना; फिर additive offer-event migration + tests उसी branch पर बनाना। इस session में कोई schema migration या app source change नहीं किया गया; केवल audit/tracker update।


### 14 नवम्बर 2026 — Customer Offer Timeline implementation का branch audit

- नवीनतम Feature Branch tree की जाँच में `supabase/migrations/20261114230000_customer_safe_offer_timeline.sql`, `supabase/tests/database/customer_safe_offer_timeline.test.sql`, `tests/customer-offer-timeline.test.cjs`, `.github/workflows/customer-offer-timeline-ci.yml` और `booking.html` integration पहले से मौजूद मिले। इसलिए इस चरण में नया implementation लिखने के बजाय मौजूदा काम का source audit किया; पहले की प्रगति रिपोर्ट में इसे pending बताना अब सही नहीं है।
- Migration private `private.srk_booking_offer_events` table बनाती है; RLS on, authenticated/anon direct table access revoked; event trigger `job_offers` INSERT/status UPDATE पर offer_created/accepted/declined/expired/cancelled events capture करता है; unique `(offer_id,event_type)` duplicate capture रोकता है; legacy current-state backfill करता है; customer RPC केवल `service_bookings.customer_user_id=auth.uid()` वाली bookings के event rows लौटाती है।
- Feature Branch booking history एक ही timeline में work events और offer events merge करती है; partial RPC failure warning दिखाती है; Hindi labels पांचों offer event types के लिए मौजूद हैं।
- Production schema से status CHECK में `offered, accepted, declined, expired, cancelled` सभी values सत्यापित हुईं। Production cancellation trigger `srk_cancel_booking_job_offers` booking cancelled होने पर `offered` और `accepted` offers को `cancelled` करता है; branch offer-event trigger इस status change को capture कर सकता है।
- Source-level risk/review: pgTAP file में 10 structural/security assertions हैं, लेकिन live behavior (insert/update/backfill/idempotency/owner-vs-other-customer result) assertions नहीं हैं। Node source test UI wiring/event labels/privacy strings check करता है। `customer-offer-timeline-ci.yml` runs `npm run test:customer-offer-timeline` और checks migration auto-deploy workflow से wired न हो।
- इस चरण में source files या Production DB नहीं बदले; pgTAP/live Supabase execution, Node workflow result, browser UI and final mobile/Desktop QA अभी verified नहीं हैं। अगला काम: test coverage को event behavior/transition idempotency/backfill/RPC ownership तक मजबूत करना और GitHub Actions result retrieve करना; migration apply/deploy नहीं करना।


### 14 नवम्बर 2026 — Offer Timeline migration privilege hardening

- Existing migration review में broad `REVOKE ALL ON SCHEMA private FROM public, anon, authenticated` मिला। यह केवल नए Offer Events तक सीमित नहीं था और पहले से मौजूद अन्य private-schema objects के client grants को अनावश्यक रूप से प्रभावित कर सकता था। इसे हटाया; private event table पर explicit direct-access revoke यथावत रखा।
- Trigger function `private.srk_capture_booking_offer_event()` पर PostgreSQL default PUBLIC EXECUTE privilege का जोखिम पाया। अब migration स्पष्ट रूप से PUBLIC/anon/authenticated से उस function का EXECUTE revoke करती है; trigger owner के रूप में event capture करता है।
- pgTAP plan 10→11 किया और assert जोड़ा कि authenticated role private capture trigger function execute नहीं कर सकता। Node source regression में भी function-level revoke और broad schema revoke न होने की जाँच जोड़ी।
- Commits: migration scope fix `91da38a29b4544791a0025c5c88c7642364d47de`; pgTAP assertion `ba828a4417f99d0792bceaf74ef807fd0d58cd86`; explicit trigger function revoke `d0639333595648d97c7d5b2c020af6622a715da9`; Node regression guard `58fe830794d3fd8d4d76a481acdf085850196471`.
- GitHub combined status for latest commit shows only Vercel failure due account build-rate-limit URL; this is not evidence that Customer Offer Timeline source workflow passed or failed. Dedicated GitHub Actions run details were not returned in this audit. Node tests and pgTAP remain unexecuted; no Production SQL or migration apply.


### 14 नवम्बर 2026 — Offer Timeline regression workflow और test readiness जाँच

- Dedicated workflow `customer-offer-timeline-ci.yml` inspected: push trigger feature branch पर relevant files/migration changes के लिए configured है; Node 24 पर `npm run test:customer-offer-timeline` और migration auto-deploy guard चलाता है। `package.json` में test script मौजूद है।
- Source test दो groups में UI merge/event labels और private storage/owner-scope/privilege guards जाँचता है। SQL pgTAP अब plan 11 है।
- `fetch_commit_workflow_runs` for commit `58fe830794d3fd8d4d76a481acdf085850196471` returned zero PR-triggered workflow runs; यह push-run status बताने वाला endpoint नहीं है। इसलिए CI result अभी VERIFIED नहीं कहा जा सकता। GitHub Actions job logs/result इस interface से प्राप्त नहीं हुए।
- pgTAP execute करने के लिए Supabase project में migration apply या database object changes जरूरी होंगे; user approval के बिना Production पर यह नहीं किया। Node source test को भी अभी executed नहीं बताया जा रहा।
- Security hardening commits `91da38a...`, `ba828a4...`, `d063933...`, `58fe830...`; tracker commit `67fac0e...`.
- Remaining: GitHub Actions push run का वास्तविक result पढ़ना; isolated non-production test database पर migration+pgTAP behavior (trigger transitions, duplicate idempotency, backfill, owner isolation) चलाना; फिर Customer App browser test. Production untouched.

- Follow-up security test: pgTAP plan 11→12; added explicit assertion that `anon` cannot execute `private.srk_capture_booking_offer_event()` (authenticated-role assertion already present). Commit `6cef3afdf03cb6e8bde2878efc7f6e1fda5f2884`. This is a test-source change only; pgTAP not executed.


## Customer Offer Timeline Source CI correction (2026-11-14)
- GitHub Actions audit found the Customer Offer Timeline Node source test step itself had passed on run #43496809867, but the workflow's Production-deployment guard failed because grep matched its own literal pattern in the workflow file.
- Fixed .github/workflows/customer-offer-timeline-ci.yml to search deployment commands with a whitespace-tolerant regex while excluding its own workflow file. This preserves detection in other workflows without self-matching.
- Corrected workflow commit: `4a39fa7e405c098c3c621f766d0a4afd2177ea70`.
- Re-run #43497295539 completed SUCCESS: Node source regression step PASS; Production deployment guard PASS.
- General source regression run #43497295502: all isolated source regression suites step PASS; overall job was still in progress at the time checked.
- This is Feature Branch CI only. No migration applied, no pgTAP execution, no browser/mobile QA, and no Production changes. Remaining: isolated database behavioral/owner-isolation pgTAP, then Customer App runtime/browser checks; final consolidated mobile/Desktop QA remains deferred until all other tasks complete.


## Customer Offer Timeline test hardening (2026-11-14)
- Expanded `supabase/tests/database/customer_safe_offer_timeline.test.sql` from 12 to 16 structural/security assertions: unique `(offer_id,event_type)` index, duplicate suppression, trigger scope (INSERT/status update), and actual status-change mapping for expired/cancelled transitions.
- Expanded `tests/customer-offer-timeline.test.cjs` to assert lifecycle dedupe, legacy final-state backfill, stable chronology, owner filter, and absence of electrician identifiers.
- Node Source Regression workflow #43497630683 completed SUCCESS on `a690023e09cf46b3edae924b3a1bd71646f684a4`; `npm run test:customer-offer-timeline` and Production deployment guard both PASS.
- These SQL assertions remain unexecuted pgTAP structural checks; they do not prove actual trigger execution, backfill behavior, duplicate inserts, or cross-customer isolation under JWT. No Supabase migration applied and Production unchanged. Next: run pgTAP only in an approved isolated non-production database (no new paid QA branch), or establish an existing safe local test database; then add behavioral fixture tests for owner A vs owner B.


## Offer Timeline isolated DB environment assessment (2026-11-14)
- Checked existing Supabase project `SRK ELECTRONIC TEST` (`dvzmarekhstaubyuoeeh`) read-only. It is ACTIVE_HEALTHY but is a narrow push-test schema: migrations cover push subscriptions/webhook setup, and current tables include `srk_push_subscriptions`, `electrician_profiles`, and `job_offers`; required `service_bookings` customer ownership schema is absent from the exposed table inventory.
- Existing TEST project contains push-test records and is not a clean disposable full-app database. Did not apply Offer Timeline migration or mutate it.
- Production project `gnqhoaqatmoiwwhgzkgm` has no development branches. No new branch created (user previously declined hourly branch cost). Production remains read-only.
- Therefore 16 pgTAP assertions remain unexecuted. Need a genuinely isolated local PostgreSQL/Supabase test DB or owner-approved disposable environment with full prerequisite migrations; do not force the migration into the push-test project or Production.


## Customer Offer Timeline isolated pgTAP execution (2026-11-14)
- First attempt through the prior schema-export workflow stopped safely: the dedicated connection passed the no-row-read/no-DDL role check, but `pg_dump --schema-only` still requested ACCESS SHARE locks on production tables and failed on `public.services` due missing SELECT. No production rows were exported or changed; the local stack was not started in that attempt. Do not grant broad SELECT merely to satisfy pg_dump.
- Replaced that path with a fully isolated synthetic local Supabase fixture. Added `supabase/tests/fixtures/customer_offer_timeline_bootstrap.sql` containing only synthetic booking/electrician/offer IDs and two pre-migration legacy offer states; no production connection or data required.
- Added `supabase/tests/database/customer_safe_offer_timeline_behavior.test.sql` with 9 behavioral assertions: existing-offer backfill, acceptance actor role, cancelled transition, no-op duplicate prevention, new offer capture, and Customer A/Customer B owner isolation through the authenticated RPC.
- Reworked `.github/workflows/supabase-schema-ci.yml` into a local-only Supabase CLI 3.1.0 workflow. It starts a temporary stack, applies the targeted migration to the synthetic baseline, copies and runs structural + behavioral pgTAP tests, and tears down the stack. It no longer reads Production schema or requires `SUPABASE_DB_URL`.
- Workflow #43498347854 was started on commit `36a50e3171ce6ca3626d5c30ae62a3167e4c5592`; at tracker update time the Supabase stack startup step was still in progress. Node source regression workflow #43498320458 completed SUCCESS on test commit `766481bb6ab3b18aa5e49c0897e9a9a7868a9860`.
- No production migration, deployment, or schema change. pgTAP outcome is pending until workflow #43498347854 completes.


## Offer Timeline pgTAP follow-up corrections (2026-11-14)
- Review of new behavioral test found the declared pgTAP plan was 9 while there are 8 assertions. Corrected `customer_safe_offer_timeline_behavior.test.sql` to `plan(8)` (commit `208d347a357f8f61daead3cf7181c9ab1e52afba`).
- Supabase CLI `test db` takes a single optional path; changed workflow to copy the two target SQL tests into its temporary project and invoke `supabase test db` so both are discovered (commit `7f5c872300e5cdfbbf206506feded23d50a5f42e`).
- Latest isolated run #43498561119 is queued/pending; earlier run #43498347854 remains stalled at local Supabase stack startup, no migration or pgTAP execution observed yet. Treat database result as NOT RUN / pending, not pass. Source regression after assertion-count fix #43498561182 in progress at this update.
- Production remains untouched. Continue investigating runner local-container startup; do not switch to Production or existing push-test project.


## Customer Offer Timeline isolated pgTAP result (2026-11-14)
- Local-only GitHub Actions workflow #43498578390 completed **SUCCESS** on commit `7f5c872300e5cdfbbf206506feded23d50a5f42e`.
- Supabase CLI local stack started successfully; synthetic legacy schema/fixtures applied; migration `20261114230000_customer_safe_offer_timeline.sql` applied successfully; stack stopped cleanly.
- `supabase test db` result: **2 files, 24 assertions, PASS**. Structural suite `customer_safe_offer_timeline.test.sql` and behavioral/owner-isolation suite `customer_safe_offer_timeline_behavior.test.sql` both `ok`.
- Behavioral plan corrected to 8 assertions; structural plan 16. This verifies the migration against a synthetic local baseline only, including customer A/B timeline isolation, backfill, lifecycle capture, duplicate suppression, role labels and access controls. It does NOT prove compatibility with full Production schema, production migration application, or live JWT/runtime behavior.
- Separate source regression #43498634380 SUCCESS on commit `9444e80bc3b1b4f7571f36995212f7e420c64167`.
- Production database/configuration unchanged; no deployment or live booking changes.


## Customer refund submission session-race hardening (2026-11-14)
- Audit found `customerSubmitBookingRefund()` could finish after SIGNED_OUT / SIGNED_IN / USER_UPDATED and display a stale success/error alert or refresh the newly authenticated customer's lists. The per-booking busy Set also had no safe ownership token for an old operation's `finally` after a new session began.
- Replaced the busy Set with an operation-token Map; captured `customerSessionGeneration` before RPC; stale response/error and post-refresh UI are ignored; cleanup only releases the lock if the current operation still owns that booking key.
- Added `invalidateCustomerRefundSubmissions()` to auth lifecycle invalidation; it clears old operations and restores stale disabled submit controls. It does not cancel a server-side RPC already in flight; server-side owner authorization remains authoritative.
- Added source regression assertions in `tests/customer-refund-history.test.cjs`; updated existing Customer Menu assertions for Map-based lock and auth listener invalidation.
- Refund Source Regression #43499286974 completed SUCCESS (runs `npm run test:refund`, including customer refund history tests). Full Customer App source regression #43499524801 completed SUCCESS on commit `9cd3d28bac0f49f5dd8ef989b0159bdaa9099f6b`.
- Intermediate full-suite failures were stale test expectations (auth listener guard and Set→Map lock), corrected; latest full source regression is SUCCESS.
- No production database, payment, refund, or deployment action occurred. Browser/runtime session-switch verification and final consolidated mobile/Desktop QA remain pending.


## Customer private payment-receipt session-race hardening (2026-11-14)
- Audit found a payment receipt popup could receive and render the prior session's private receipt after a shared-device account switch while the receipt RPC was in flight.
- `customerPrintPaymentReceipt()` now captures `customerSessionGeneration`, checks it immediately after the receipt RPC and closes the pending popup without rendering or showing stale error UI when the session changed. The RPC remains server-side owner-scoped; this is an additional client stale-response guard.
- Added regression coverage in `tests/customer-menu.test.cjs`.
- Refund Source Regression #43499677244 SUCCESS; Customer Offer Timeline Source Regression #43499676223 SUCCESS; full Customer App Source Regression #43499676424 SUCCESS on commit `58f43e447187e6484873a99ede025f51a01fda28`.
- No browser session-switch test has been performed; final mobile/Desktop QA remains deferred. No Production/payment/refund action was taken.


## Customer Booking History account-switch privacy hardening (2026-11-14)
- Audit found `loadCustomerBookings()` only used its refresh sequence. During SIGNED_IN / SIGNED_OUT / USER_UPDATED, a prior account's in-flight booking query could still pass its sequence check before the new `syncCustomerSession()` refresh began, and render old private booking cards into the changed session.
- Added `customerSessionGeneration` capture and a combined `isCurrent()` guard across Auth lookup, booking query, contact/work/offer/refund RPC fan-out, final bill fan-out, render, catch and finally. Stale account work cannot render cards, warnings, or unlock controls owned by a newer request.
- Added `invalidateCustomerBookingHistory()` to auth lifecycle changes. It increments the history sequence, resets pagination/busy state, clears old booking cards immediately, and restores refresh/load-more controls before the new session loads its own history.
- Added source regression coverage for immediate clearing, auth listener invalidation, and stale response guards. First CI attempts exposed stale test expectations; assertions were updated to the combined generation guard. Latest full Customer App Source Regression #43500436558 completed **SUCCESS** on commit `8449e7cb476d753fa6958266a20892d8110947d4`.
- Refund Source Regression #43500272005 and Offer Timeline Source Regression #43500172169 had passed on preceding app source state; the latest full regression covers all source suites after the booking-history fix.
- This is source-level verification only; real two-account browser switching, live Supabase JWT/RLS runtime checks, and consolidated final mobile/Desktop QA remain pending. Production remains unchanged.


## Customer Payment / Refund History account-switch privacy hardening (2026-11-14)
- Audit found payment and refund history loaders used per-loader request sequences but did not bind in-flight requests to `customerSessionGeneration`. A response from the previous account could therefore still be rendered if it completed before the next session's Payments refresh began.
- Both loaders now capture the current session generation and use a combined sequence + session-current guard after Auth lookup, after the owner-scoped history RPC, before render, in error handling, and in `finally`. An old request cannot render another account's payment/refund records or release controls owned by a newer request.
- Added `invalidateCustomerPaymentHistory()` and `invalidateCustomerRefundHistory()`: they increment request sequences, reset pagination/busy state, immediately clear private history UI, and restore pagination/refresh controls on account changes. Auth SIGNED_IN / SIGNED_OUT / USER_UPDATED invokes both invalidators; logout cleanup reuses them.
- Added regression assertions in `tests/customer-menu.test.cjs` for generation guards, Auth/RPC await boundaries, stale-response prevention and immediate invalidation.
- Source commits: app `376860c1e742d493c30284190bb48657a50f2f89`; regression test `8fa195782810fe5436be8e2213659d70747e24fe`. Full source regression workflow status has not yet been confirmed; do not mark tests passed until the GitHub Actions result is inspected.
- No live browser/two-account test, Supabase JWT/RLS runtime test, Production DB/configuration change, payment/refund action, merge or deployment. Final consolidated mobile/Desktop QA remains deferred until all Customer App work is complete.

### Payment / Refund History regression outcome
- Full isolated source regression workflow #43501768722 completed **SUCCESS** on test commit `1bf9e282ce456d19eb3363cac691776962259a8d`; all nine source regression suites completed, including the updated Customer Menu tests.
- Earlier runs #43501383276, #43501563657 and #43501645417 failed only on stale assertions that expected sequence-only guards/direct inline logout resets and the previous Auth listener shape. Those assertions were updated to require the stronger session-generation guard and shared invalidation helpers; latest full run is green.
- Vercel status on the app/test commits is a separate account build-rate-limit failure; it is not the source regression result and no deployment was attempted.


## Customer Profile और Saved Address session-race hardening (2026-11-14)
- Audit में Profile और Saved Address loaders में request-sequence guard था, लेकिन Auth session generation binding नहीं थी। Shared device पर account switch के समय पुरानी profile/avatar या saved-address response नई session में render हो सकती थी।
- `loadCustomerProfile()` अब request sequence + `customerSessionGeneration` दोनों validate करता है; Auth lookup, profile RPC, avatar signed-URL await, catch और stale response paths पुराने session के UI को बदल नहीं सकते।
- `loadCustomerSavedAddresses()` भी Auth lookup, owner RPC, error और finally/control restoration पर combined generation guard लगाता है। पुरानी session का finally नए session के address selector को unlock नहीं करेगा।
- `invalidateCustomerProfileAndSavedAddresses()` Auth SIGNED_IN / SIGNED_OUT / USER_UPDATED पर पुरानी profile/avatar और saved-address list तुरंत clear करके load sequence invalidate करता है; नई session sync फिर अपना data लोड करती है।
- App commit: `43ea5700c6328b4f922690bcf3806a4829338b40`; regression test commit: `c35ad87989be11aec2f1829316cd483f21feec5a`; CI workflow updated to run `npm run test:customer-menu` alongside refund source checks: `deb89481fc5ca8a1951c788e00f52da45eb6a909`.
- GitHub Actions result अभी pending/अज्ञात है; tests को pass नहीं माना गया है। Browser two-account test, live Supabase JWT/RLS, और final consolidated mobile/Desktop QA बाकी हैं। Production DB/configuration, payments/refunds, merge और deployment untouched हैं।

- CI follow-up: first run `#43502229767` exposed an overly strict source-test regex (implementation correctly increments the two load sequences with prefix `++`); corrected assertion in test commit `6f171455ef0eabec42ec213be7c5a5ed8e1fd73c`. A fresh workflow run is expected from this test-only commit; earlier run is a test assertion failure, not a runtime/source syntax failure.

- दूसरा CI audit: source suite ने पुराने Auth-listener assertion को पकड़ा, क्योंकि अब उसी listener में `invalidateCustomerProfileAndSavedAddresses()` भी जोड़ा गया है। Regression assertion को नए सुरक्षित listener contract के अनुसार अपडेट किया: `eee6bfecfccfad19abd346a957630a2b78d4ec64`. पिछले failures assertion drift के थे; अंतिम pass अभी प्रतीक्षित है।

- CI follow-up #2: expanded Customer Menu suite ने दो पुराने sequence-only assertions पकड़े; अब वे combined `isCurrent()` session+sequence guard और उसके finally cleanup को verify करते हैं। Test correction commit: `3f39500f1bff35fd0b5e7d92077dce0c0f90ff41`. पहले CI attempts में केवल test expectations fail हुईं; corrected suite का अंतिम परिणाम प्रतीक्षित है।

- CI follow-up #3: avatar preview callback और saved-address loader के दो अन्य पुराने source assertions भी sequence-only implementation से जुड़े थे। इन्हें अब session-aware `isCurrent()` callback/finally behavior पर अपडेट किया: `398833e34daa5a7e805e82f27ec23347075004fb`. अगला workflow result ही अंतिम pass/fail माना जाएगा।

- CI follow-up #4: avatar signed-URL callback में implementation का एक closure अभी sequence-only था; इसे `isCurrent()` session+sequence guard से बाँधा। साथ ही Auth retrieval failure test में पुराना finally assertion बदला। Commits: app `7ef812c31e7c77f78ae4d7fedc0ad22f2344e208`, test `c435403e0a145d47c40c7b3c033512266f20f9bb`. पहले runs ने stale assertions और avatar callback gap पकड़ा; नया regression outcome अभी प्रतीक्षित है।


## Customer Support session-switch privacy hardening (2026-11-14)
- Support booking selector, complaint list, message thread और attachment signed-URL loading को `customerSessionGeneration` + per-loader sequence guards से बाँधा। पुराने account की pending RPC/Storage response नए account के Support UI में render नहीं हो सकती।
- Auth SIGNED_IN / SIGNED_OUT / USER_UPDATED पर Support booking choices, complaint choices, thread messages और attachments तुरंत clear होते हैं; pending loader sequences invalidate होते हैं और controls restore होते हैं।
- Attachment RPC तथा प्रत्येक signed-URL await के बाद generation जाँची जाती है; stale generation पर आगे की private file links नहीं बनतीं/रेंडर नहीं होतीं।
- App commits: `9a388461750e5a879464ad2a3c9d4b55572dce35`, corrective guard `73b4399bc778cd2d436224d96427eb2b71be9561`; source regression tests: `a98500b3771f470e6f489c2a005152e299ef2014`. Saved-address prior test assertion corrected in `1489923d2758d6ab475f78de0cc29a73ce78fb74`.
- Earlier CI run `#43502626728` had 70/71 Customer Menu tests pass; remaining failure was a stale saved-address finally assertion. Corrected assertion commit `1489923...`. Support-specific tests are now added; final CI result pending. No browser/two-account test, live Supabase JWT/RLS, or final mobile/Desktop QA performed. Production unchanged.

- CI assertion alignment: Support regression suite के पुराने sequence-only assertions अब session-aware `isCurrent()` guards और Auth listener के Support invalidation को verify करते हैं। Test commit `367f7e9d31a1b01429fb7924ce7b11084c5b89b6`; prior run #43503612615 में 65/72 Customer Menu assertions passed, 7 पुराने source expectations अपडेट किए गए। Corrected CI result अभी pending है।

- Corrected CI outcomes: full Customer App source regression workflow `#43503823632` completed **SUCCESS**; refund/account-privacy workflow `#43503823509` completed all test and syntax steps **SUCCESS**. Customer Support loaders and attachment guards are covered by the updated source tests. These are source-level regressions only; no browser/two-account, live Supabase JWT/RLS, or mobile/Desktop QA claim. Production remains unchanged.


## Customer 14.1.10 — Completion और Online Payment Preference account-switch race hardening (2026-11-14)
- Customer completion approve/reject/dispute handler का audit मिला: RPC पुराने session में शुरू होकर login switch के बाद resolve होने पर stale success/error alert दिखा सकता था और नई session की booking list refresh कर सकता था।
- Handler अब session generation capture करता है; confirmation dialog के बाद, RPC के बाद, alert/refresh से पहले और catch path पर generation check करता है। Per-booking lock अब operation-token Map है; पुरानी operation का finally नई session के lock को delete नहीं कर सकता। Auth change पर pending locks invalidate होते हैं।
- Customer Cash→Online payment preference handler में भी वही race मिला। RPC response, confirmation/error UI और booking refresh अब active session से bound हैं; token ownership के बिना finally नई session के button/lock को नहीं बदलता। Auth change पर locks invalidate होते हैं।
- App commits: `e28aaf860e184a56870fd2263c36630bc07c856b`, follow-up confirmation/error guards `11ff350e19ae5676339cb01034a7a7eb6fee6c0e`; regression commits `e3818fe15f19d7e566e618477a3f7f936f98fe65`, `bf5e855ab971a3676b41ae94a39c6da41e1c2bad`, `52fa9d23aef093028e3feee75f6dec2c1a775967`, latest assertion correction `1db53f201f59894033799424a07a80a2de500823`.
- Earlier CI runs found stale test expectations (Set→Map, token-based finally, and semicolon in invalidator assertions); these are test assertion mismatches, not yet a passing verification. Latest full source workflow `#43504622728` is queued at time of tracker update; do not mark PASS until checked. Customer Offer Timeline workflow #43504281672 PASS on earlier app commit, but it does not verify these later edits.
- Next: confirm full Customer App source regression and refund/account-privacy workflow results; then continue 14.1.10 isolated DB/JWT/pgTAP review. No Supabase migration applied, no Production DB/Auth/payment/refund/transfer/deployment action, no merge. Browser two-account and final consolidated mobile/Desktop QA remain deferred.

- Final verification update: full Customer App source regression workflow `#43504622728` completed **SUCCESS**; refund/account-privacy source workflow `#43504622667` completed **SUCCESS** including handler/Admin syntax checks and refund + customer-menu tests. Both ran on test commit `1db53f201f59894033799424a07a80a2de500823`. This verifies source-level guards only; not DB/JWT runtime, actual account-switch browser behavior, or device QA. 14.1.10 remains Partial/In Progress.


## Customer App — अगला account-switch audit और labour snapshot SQL hardening (2026-11-14)

### ग्राहक work-start / completion / payment preference
- Customer work-start approval handler में भी पुराने account का RPC response login switch के बाद stale alert/refresh कर सकता था; completion handler पहले ही session-bound किया गया था। अब work-start approval में session-generation checks, per-booking operation-token Map, token-owned finally cleanup और Auth-change invalidation है।
- Cash→Online preference handler के catch path में stale error alert का एक छूटा हुआ रास्ता भी बंद किया गया; पुराने session की error नई session में नहीं दिखाई जाएगी।
- App commit: `9989579d7f66410cc02be5214b4b27ef3e57d98f`; source/test assertion corrections के बाद latest source test commit `3b6ad864f56e51ecb0f087901fed4e2fe552e884`.

### Help & Support account-switch cleanup
- Audit में पाया कि शिकायत बनाना/संदेश भेजना generation guard तो रखते थे, लेकिन account switch पर mutation busy flags और disabled buttons reset नहीं होते थे; पुराने account की typed description/message और queued file selection भी form में रह सकती थी।
- `invalidateCustomerSupportPrivateState()` अब complaint-create/message-send busy flags reset करता है, दोनों action buttons restore करता है, complaint selector unlock करता है, message/description drafts और selected attachment FileList clear करता है, और prior thread/attachments/complaints clear करता है। पुराने operation का finally generation guard के कारण नए session के controls नहीं बदलेगा।
- App commit: `8f321f1efe76d3f5c06adb0d256350773df05abe`; source test commit `f21f459e9be6b7f4c9126b00e6973057f9c1bb88`; final passing test commit `3b6ad864f56e51ecb0f087901fed4e2fe552e884`.

### Server timer / immutable labour bill schema audit
- Production read-only introspection: Production project `gnqhoaqatmoiwwhgzkgm` migration history अभी `20261113081436_customer_booking_timeline` तक है; 14-Nov feature migrations Production में लागू नहीं हैं। Production `service_bookings.work_timer_seconds` अभी integer है और existing CHECK 0–604800 (7-day cap) है; approved rate-tier columns, new elapsed-seconds snapshot, `srk_booking_labour_bills`, work-event history और private timer authorization table अभी absent हैं। `work_transition_authorizations` मौजूद है।
- उसी read-only aggregate query में Production में अभी `work_timer_running=true` या `status='in_progress'` वाले कोई booking rows नहीं मिले। कोई booking/data mutate नहीं किया।
- Branch timer migration `20261114040000` में PostgreSQL three-valued CHECK logic का एक वास्तविक NULL loophole मिला: rate-tier snapshot constraint में paise field NULL होने पर CHECK expression NULL हो सकता था और PostgreSQL CHECK इसे pass कर देता। अब snapshot tuple के तीनों fields पर explicit `IS NOT NULL` लगाया है; all-NULL legacy state ही दूसरा valid case है।
- Updated pgTAP plan 101→102; नया assertion constraint definition में तीनों explicit non-NULL guards verify करता है। pgTAP अभी execute नहीं हुआ; यह source-level/CI assertion है।
- Commits: timer migration fix `d56960ca0fc031b244d0e00c4e0cbe0ed7235e62`; pgTAP `cdb33a72343987ae62459f01f3070c53baa04eb2`; Node source regression `3b6ad864f56e51ecb0f087901fed4e2fe552e884`.

### CI स्थिति
- Full Customer App source regression `#43505627440` **SUCCESS**.
- Refund + Account Privacy source workflow `#43505627319` **SUCCESS**.
- अतिरिक्त OTP/source regression `#43505620835` **SUCCESS**.
- Offer Timeline source workflow `#43505386762` **SUCCESS**.
- ये source/static regression results हैं; browser account-switch E2E, live JWT/RLS/RPC, timer concurrency/race tests, timer pgTAP execution और final consolidated mobile/Desktop QA अभी बाकी हैं।
- कोई Production migration, Auth setting, payment/refund/transfer, merge या deployment नहीं किया गया।

**अगला resume point:** Customer App private-state account-switch audit को शेष payment/refund/support/profile/booking mutations पर पूरा करें; फिर 14.1.10 timer/completion/payment integration के DB/RPC acceptance gaps और isolated pgTAP execution strategy पर आगे बढ़ें। Electrician Portal शुरू न करें जब तक Customer App acceptance gate पूरा न हो।


## Customer App — Saved Address और Razorpay session isolation hardening (2026-11-14)

### Saved Address mutations
- Save, delete और default-address RPC flows पहले Auth session generation से बंधे नहीं थे; account switch के बाद पुराना response नई session के selector/status/buttons को बदल सकता था। तीनों handlers अब generation capture/check करते हैं, RPC और list refresh के बाद stale UI रोकते हैं, catch alerts केवल उसी session में दिखाते हैं और finally केवल उसी session के controls restore करता है।
- Auth invalidation अब Save/Edit/Delete/Default controls restore करता है; पुराने operation का finally नई session के controls नहीं छूता।
- Commits: app c2b03b24b7ac2dc28c23b41557609c9d0fd4057c; regression/test corrections 102d42c00aa4fc39cb6b8a6ceb0d7440825f53ed, b1ad728ff5e2df908aa4260c47185997fee9c2a9; latest phone/avatar cleanup app 01332b7136e3cd4f99a121d7d0dd9f01e739ed44, test ea4f4e713f5915f4e94b17364e4e203c547ad968.
- Account change पर prior verified phone और queued avatar file भी clear होते हैं; new session sync नया verified phone पुनः भरता है।

### Razorpay checkout flow
- startRazorpayPayment() में session-generation और operation-sequence guard जोड़ा। Order-create response के बाद checkout केवल तभी खुलता है जब initiating customer session अभी active हो।
- Checkout खुला रहने तक payment single-flight lock बना रहता है; duplicate Checkout launches रोकता है। Payment success/failure/dismiss पर lock/button उसी operation token और session के लिए release होता है।
- Account switch पर checkout close, payment panel hide, pending booking/amount clear, button restore और stale status/UI updates रोक दिए जाते हैं।
- महत्वपूर्ण financial behavior: यदि checkout से payment success callback account switch के बाद भी आता है, verification request initiating customer के captured access token से server पर जारी रहती है ताकि वास्तविक भुगतान reconcile हो सके; लेकिन पुराने customer का success/error UI या booking refresh नए account में नहीं दिखता।
- App commit f620bc60d3fb75a3bd6b0b4b063b593c10b265fa; payment/auth test correction ecd0133129f48ee5d546dc23480c537d9301c538, latest test commit ffa1f1cce70b8db37810e6fffb94f99d6f51eb15.

### Verification
- Customer App full source regression #43506681936 SUCCESS.
- Refund + Account Privacy source workflow #43506681692 SUCCESS.
- दोनों workflows में Node source regression तथा Refund/Admin syntax checks पास हुए। यह source-level verification है; Razorpay test-mode/live callback, browser session-switch और payment reconciliation E2E अभी execute नहीं हुए।
- Previous customer session hardening source results: #43506274811 OTP/source PASS, #43506274976 refund/account privacy PASS, #43506263929 Offer Timeline PASS.
- कोई Production payment, refund, Auth setting, migration, merge या deployment नहीं हुआ।

**अगला resume point:** customer private-state inventory में बाकी UI/actions और account-change behavior की audit जारी रखें; फिर 14.1.10 timer/payment integration के DB/RPC runtime acceptance, migration parity और isolated test execution gaps पर काम करें।

- Follow-up: no-session fallback in syncCustomerSession() also now invalidates pending refund submissions, work-start/work-completion actions, payment-method changes and Razorpay checkout when getSession() returns no session without relying only on an Auth event. Regression commit 010b6cc5d6b281a04eb5d979ff871e90f7fe2a94; test commit b9a70c01e308721816ccdfe20f4dfadf44b0685a.
- Final verification for this pass: Customer App full source regression #43506928099 SUCCESS; Refund + Account Privacy #43506928361 SUCCESS; Customer Offer Timeline source #43506928088 test and deployment guard SUCCESS. These are source checks only; actual browser/account-switch and Razorpay test-mode E2E remain unrun.


## Customer OTP — phone-operation race hardening (2026-11-14)

- Embedded Customer App OTP send अब phone + operation sequence से bound है। यदि request pending रहते मोबाइल नंबर बदलता है तो पुराना response OTP challenge नहीं खोलेगा; पुराना catch/finally नई request के status/button/busy state को नहीं बदलेगा।
- Embedded OTP verification के दौरान phone input lock रहता है; उसी request का finally phone और verify button restore करता है। Phone edit और logout pending OTP operation invalidates करते हैं।
- Standalone `customer-login.html` में भी वही protection लागू: phone change pending send invalidates, stale send response/cleanup ignored, OTP verify के दौरान phone locked, session state के अनुसार button restore। Logout के दौरान pending OTP sequence invalidated।
- Commits: embedded page `a23d6ca73c6f780e7ae0f9bb73109745d80b3ccb`; standalone page `568690cdd9235e085ba0befb1fcd9fc9e1011ef1`; OTP regression updates `bffc89152ad47ba8e2bd3c42ade6e7703a5d6337`.
- OTP/source regression initially exposed stale test assumptions and a missing test-local HTML fixture; these test-only issues were corrected. Final full Customer App source regression `#43508020264` **SUCCESS** (all isolated source regression suites passed).
- OTP Auth provider expiry, server-side resend/wrong-attempt throttling, CAPTCHA, SMS delivery, and live Auth JWT/session runtime remain unverified. No live OTP SMS or Auth setting change.
- Browser two-phone/OTP flow, actual network race, and consolidated final mobile/Desktop QA remain pending. Production unchanged.

**अगला resume point:** Customer App में शेष payment/refund/profile/support private state एवं customer-facing flows की acceptance audit जारी रखें; फिर server-authoritative timer/completion/bill/payment migrations के local isolated DB tests और API/JWT integration gaps पर काम करें।

- अतिरिक्त Profile audit: profile avatar upload/RPC के दौरान account switch होने पर session-generation guard stale UI रोकता था, लेकिन Save Profile button disabled रह सकता था क्योंकि पुराने operation का finally जानबूझकर नए session को unlock नहीं करता। Auth invalidator अब Profile Save button restore करता है; regression test जोड़ा। App commit ab0bb7fdeed0144de9e2940531e952bf2e65f95f; test commit acd5c9714ebeab8a4ae4658ea6cd788f9ad1c18c.
- इस सुधार के बाद Customer App full source regression #43508138339 SUCCESS, Refund + Account Privacy #43508138399 SUCCESS, Offer Timeline + deployment guard #43508138474 SUCCESS। Source-only checks; browser/device runtime अभी pending।
