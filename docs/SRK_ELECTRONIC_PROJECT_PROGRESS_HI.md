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
