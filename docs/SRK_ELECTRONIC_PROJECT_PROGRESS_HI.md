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
