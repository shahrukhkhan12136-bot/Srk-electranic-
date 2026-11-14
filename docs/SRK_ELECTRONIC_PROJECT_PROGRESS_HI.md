### 2026-11-15 — Customer work timeline RPC contract correction
- Detailed branch-vs-function-signature review found `booking.html` called `srk_customer_get_my_booking_work_timeline()` without an argument, while the SECURITY DEFINER RPC requires `p_booking_id uuid`. The previous customer-wide response handling also expected a `booking_id` column that the function intentionally does not return.
- Fixed the Customer booking loader to request the timeline separately for each booking already filtered by `customer_user_id = auth.uid()`, passing `{p_booking_id: row.id}`, then map returned safe event labels/actor roles/timestamps to that booking. This retains booking-level authorization and avoids introducing a customer-wide event stream.
- Change committed to the approved Feature Branch in commit `cc78a603f5f266e5fbab29e774fbf305b433c405`. Source re-fetch confirms the exact updated call is present. Runtime browser/E2E and Node syntax/test verification are still pending; the previous Vercel sandbox session has stopped and no replacement test environment was created.
- No Production database, Storage bucket, payment, deployment, or setting was changed.

# SRK ELECTRONIC — मास्टर प्रोजेक्ट प्रगति सूची

### 2026-11-15 — Razorpay server-side payment-method enforcement
- Server audit found `create-order.js` and `verify-payment.js` checked booking ownership and completion status but did not independently require the booking's saved payment method to be Razorpay. A direct API request could therefore attempt online payment against a Cash booking even though the UI hid that action.
- Updated both server endpoints to fetch and require an explicit Online/Razorpay payment preference (while preserving legacy online labels), and to reject already-refunded bookings before provider order/payment lookup or settlement. The preference RPC writes the exact `Razorpay ऑनलाइन भुगतान` value. This preserves the approved flow: customer explicitly changes an unassigned new/confirmed Cash booking to Online; money is not collected until work completion.
- Added `tests/customer-payment-method-enforcement.test.js` and `test:customer-payment` package script. Four mocked API tests cover Cash rejection and refunded-booking rejection in both order creation and payment verification. The webhook now also ignores captured events for Cash/offline or refunded bookings, with two additional mocked tests; the online-settlement RPC fails closed on refunded bookings and its pgTAP plan now includes the guard. The refund/cancellation pgTAP file statically parses with 34/34 assertions; two pre-existing unbalanced-parenthesis issues in that test file were corrected. The aggregate `npm test` command passed **15/15**; no Razorpay provider request or settlement RPC was made in the six negative tests.
- This is Feature Branch source and test evidence only. No live payment, refund, database row or Production setting was changed.

### 2026-11-15 — Customer booking preference and work timeline RPC foundations
- Customer UI called `srk_customer_change_payment_method` and `srk_customer_get_my_booking_work_timeline`, but neither RPC existed in the Live function catalog or the source migration set. Added the missing payment-preference RPC in CLI-generated migration `20261114202656_customer_change_payment_method_rpc.sql`: it only permits the booking owner to switch an unassigned `new/confirmed` cash booking to the exact Razorpay preference, while unpaid, with zero amount paid and no Razorpay order/payment IDs. It changes only the preference; it does not create an order or collect money.
- Added `srk_customer_get_my_booking_work_timeline(uuid)` to the post-event-table work migration `20261114260000_fix_work_start_rpc_and_append_only_event_history.sql`. It verifies customer ownership and returns only event labels, actor roles and timestamps; it does not expose private old/new event snapshots. It maps customer/Admin completion approvals to the labels already used by the UI. Final work-start and work-completion SECURITY DEFINER functions are also assigned an empty `search_path` after their timer-migration replacements.
- Added 14 pgTAP assertions for payment preference restrictions and 16 for timeline ownership, output minimization, actor mapping, execute grants and final search paths. PostgreSQL outer-SQL parser accepted the new/updated SQL; plan counts match 14/14 and 16/16. Runtime pgTAP remains blocked by missing Docker/Podman.
- Customer source static checks: `create-booking.js` passed `node --check`; the one non-empty inline JavaScript block in `booking.html` passed `node --check`; the full Node test set (customer payment-method enforcement + Razorpay refund/webhook) passed **13/13**. These are static/unit checks, not Customer OTP/booking/payment E2E.
- All 26 customer RPC call names now have source definitions in the Feature Branch (some were already present; others are in the staged migrations). Live still has only 7/26 exact names, with 19 absent; no live RPC or schema was changed. Customer booking query remains blocked by missing Live columns until the reviewed migration set is applied in a separately approved test environment.

### 2026-11-15 — Customer complaint history privacy hardening
- Production RPC review found that `srk_customer_list_booking_complaints()` returned the internal `admin_note` column and raw complaint-event `note` values to the customer session, even though the current Customer UI does not render those fields. This was an unnecessary disclosure surface.
- Added Feature Branch migration `20261114202250_customer_complaint_customer_safe_projection.sql`: preserve the existing RPC response shape for UI compatibility, but always return `NULL` for `admin_note` and an empty activity array; retain strict `auth.uid()` customer ownership filtering and authenticated-only execute grants. Also set an empty `search_path` on the customer complaint-create and complaint-list SECURITY DEFINER RPCs; final work-start/completion definitions are hardened after the timer migrations in `20261114260000_fix_work_start_rpc_and_append_only_event_history.sql`.
- Added 10 pgTAP assertions for customer ownership, omitted internal notes, empty search path and execute grants. SQL parser and 10/10 assertion-plan count checks passed statically; pgTAP was **not executed** because this sandbox has no Docker/Podman. No live RPC was altered.
- Source and test are on Feature Branch / PR #8 only. No Production migration, deployment, merge or mobile test.


### 2026-11-15 — Customer Portal backend contract audit + missing foundation source added
- Exact scan of `booking.html`: **26 distinct RPC names** are called. Read-only Production catalog comparison found **7 exact names present and 19 absent**. This is name-presence only; matching argument signatures, grants, runtime behavior and row-level authorization still require separate verification. Corrects an earlier rough count in the conversation.
- Production `service_bookings` is missing the customer-selected category/duration/rate snapshot fields, estimate paise/version fields, booking idempotency key/fingerprint and `work_timer_elapsed_seconds`. Its existing `work_timer_seconds` is still integer, while the source timer migration changes it to bigint. Related source migrations are present in the Feature Branch but are not applied to Production.
- Read-only Production catalog also shows no `srk_customer_profiles` or saved-address table, no customer support message/attachment tables, and neither the customer avatar nor support Storage bucket. Existing complaint and refund-request base tables are present. The current UI therefore contains profile, saved-address and attachment flows whose complete backing schema is not yet live.
- Added Feature Branch migration `20261114201428_customer_profile_saved_addresses_private_storage.sql` (filename generated using Supabase CLI 3.1.0) to provide private customer profile and saved-address tables; authenticated customer-scoped read/save/delete RPCs; 10-address limit, per-customer write serialization and one-default-address constraint; private avatar bucket and owner-scoped policies; and a tightened support-object delete policy so linked evidence cannot be deleted by a customer. The preceding support-conversation migration remains the source for the private support bucket, upload/read helper and message/attachment schema.
- Added `supabase/tests/database/customer_profile_saved_addresses_private_storage.test.sql` with **27 pgTAP assertions** covering table/RLS grants, RPC identity and execute grants, address limit/concurrency/default constraints, private buckets and Storage policy boundaries. Plan count matches 27.
- Static verification: PostgreSQL outer-SQL parser accepted the migration and test files; pgTAP assertion/plan count is 27/27; whitespace check passed. **This is not a PostgreSQL execution or pgTAP PASS**: the resumed Vercel sandbox has no Docker/Podman, so local database startup and runtime test execution were unavailable. PL/pgSQL bodies, live Storage operations and customer browser flow remain unexecuted.
- Migration and test are on the approved Feature Branch / PR #8 only. No Supabase migration was applied, no Production database or Storage object was changed, no deploy/merge occurred, and no mobile QA was performed. Do not alter the 96-point completion counts until end-to-end evidence exists.


**स्थिति snapshot:** 14 नवम्बर 2026  
**Repository:** `shahrukhkhan12136-bot/Srk-electranic-`  
**काम की branch:** `feat/customer-login-first-dashboard-20261114`  
**Master Epic:** [Issue #3](https://github.com/shahrukhkhan12136-bot/Srk-electranic-/issues/3)  
**Requirements का source of truth:** [SRK ELECTRONIC Master Requirements](https://github.com/shahrukhkhan12136-bot/Srk-electranic-/blob/feature/platform-fee-cash-online-cycle/docs/SRK_ELECTRONIC_MASTER_REQUIREMENTS_HI.md)

> यह स्थायी hand-off / resume दस्तावेज़ है। बातचीत रुक जाए तो इसी फाइल को खोलकर स्थिति, बाकी काम और अगला क्रम समझा जा सकता है। हर अगली प्रगति पर इसे update करना है।

### 2026-11-14 — Admin Staff Portal source review follow-up
- अतिरिक्त UI source review में Staff invite और Staff email sign-in दोनों के email-validation regex में double-escaped whitespace/dot pattern मिला था, जिससे सामान्य email addresses reject हो सकते थे। दोनों patterns ठीक किए और error wording को “Email sign-in link” किया।
- Runtime regex sanity check: `support@example.com` स्वीकार और `bad-email` अस्वीकार — PASS। यह isolated JavaScript regex check है; पूरा browser/auth flow test नहीं।
- Commit: `1a7be771ef87759e57dcdcaf13540a38711a0c4d`.
- कोई migration apply, Edge Function deploy, staff invitation/account creation, production change या live data mutation नहीं हुई।

### 2026-11-14 — Admin Portal refresh duplication fix
- Role-aware refresh पहले `showState()` चलाता था, जो Main Admin/Staff के लिए data loader पहले ही चलाता है; उसके बाद refresh handler वही loader दूसरी बार भी चला देता था। इससे duplicate parallel requests और अनावश्यक backend load हो सकता था।
- Refresh अब loaded-user guard reset करके `showState()` को एक बार चलाता है; authorization और role-specific loader उसी एक flow में रहते हैं।
- Inline JavaScript syntax compile: 1 script block(s) — PASS। यह static syntax check है, browser runtime test नहीं।
- Commit: `a56a1e0f615bc15314bd49edf4f222505b1fcec2`. कोई live deployment या production बदलाव नहीं।


### 2026-11-14 — Admin Staff RBAC tracker accuracy correction
- Section 14.3 की पुरानी checklist wording को वर्तमान source implementation के अनुरूप सुधारा: Support-only RBAC foundation, session-bound permissions, assignment-scoped Staff-safe inbox, isolated Staff UI और audit source अब आंशिक रूप से implemented हैं; live/runtime acceptance अभी नहीं।
- Section 14.3 और master counts समायोजित: 66 आंशिक, 7 blocked, 23 बाकी, 0 verified complete (कुल 96)। यह feature completion का प्रतिशत नहीं है।
- कोई application code, migration, Supabase setting या live data नहीं बदला; केवल tracker documentation update है।


### 2026-11-14 — Admin Staff Support case concurrency hardening
- Source review में case closure/status update और Staff reassignment/reply के बीच race तथा उलटे row-lock order से संभावित deadlock मिला।
- Main Admin assignment अब पहले complaint/ticket row को `FOR UPDATE` lock करके closed-state जाँचता है; active Support Staff registry row पर `FOR SHARE` lock रखता है ताकि concurrent suspend/disable assignment के बीच race न करे।
- Staff customer/electrician reply और status-update RPCs अब एक consistent lock order अपनाते हैं: पहले संबंधित case row, फिर उसी case की assignment row। इससे reassignment, close और Staff mutation serialize होते हैं तथा उलटे lock order का deadlock जोखिम घटता है।
- pgTAP में 2 lock-order assertions जोड़े; plan/assertion count **53/53** static count match।
- Static source verification: पाँचों प्रभावित RPCs में case `FOR UPDATE` और assignment `FOR UPDATE` मौजूद, case lock assignment lock से पहले — PASS। PostgreSQL compile, pgTAP execution और वास्तविक concurrent transaction tests अभी नहीं चले।
- Commits: migration `9c5025e2a2608398eaa8eece4c0a6e12163f7313`; pgTAP `d60f7a5fb78772675b4352a90ec7ca0830b38d9f`.
- कोई migration apply, Edge Function deploy, production setting/data change या Staff invitation नहीं हुई।

## 1. कुल प्रगति — प्रमाण आधारित

इस tracker में Master Requirements के Section 14.1–14.8 के 89 checkbox points और Section 16 के 7 public-website points शामिल हैं: **कुल 96 मूल checklist points**।

| स्थिति | संख्या | अर्थ |
|---|---:|---|
| ✅ पूरी तरह Verified Complete | 0 | Code + backend/RLS/RPC + relevant tests + required verification evidence सभी पूरे |
| 🟡 आंशिक / काम जारी | 66 | Audit, source changes, partial implementation या test preparation मौजूद; acceptance अभी अधूरा |
| 🟠 Blocked / dependency या decision बाकी | 7 | authoritative data, approved policy, backend dependency या सुरक्षित release prerequisite बाकी |
| ⚪ बाकी / पर्याप्त प्रमाण नहीं | 23 | अभी implementation/verification का भरोसेमंद evidence उपलब्ध नहीं |
| **कुल** | **96** |  |

**महत्वपूर्ण:** 66/96 का मतलब 68.8% फीचर पूरे होना नहीं है। इसका मतलब इन बिंदुओं पर कुछ audit/source/implementation कार्य दर्ज है। **सख्त verified completion अभी 0/96 (0%) है।** किसी item को केवल UI या migration file मौजूद होने से Complete नहीं माना जाएगा।

अलग से Master Epic में बताया गया **96-item real-world test batch** final acceptance test set है; वह इस 96-point requirements checklist से अलग test gate है।

## 2. श्रेणीवार स्थिति

| Master category | मूल points | आंशिक / जारी | Blocked | बाकी | Verified Complete |
|---|---:|---:|---:|---:|---:|
| ग्राहक ऐप और वेबसाइट (Section 14.1) | 14 | 8 | 4 | 2 | 0 |
| इलेक्ट्रिशियन ऐप / पोर्टल (Section 14.2) | 14 | 11 | 0 | 3 | 0 |
| एडमिन पैनल और कंपनी संचालन (Section 14.3) | 15 | 14 | 0 | 1 | 0 |
| पेमेंट, Razorpay, Wallet और Accounting (Section 14.4) | 13 | 11 | 1 | 1 | 0 |
| Notifications और Communication (Section 14.5) | 6 | 4 | 0 | 2 | 0 |
| Security, Privacy और Data Governance (Section 14.6) | 10 | 5 | 0 | 5 | 0 |
| Backup, Reliability और Recovery (Section 14.7) | 6 | 0 | 0 | 6 | 0 |
| QA, Accessibility और Release Sign-off (Section 14.8) | 11 | 7 | 2 | 2 | 0 |
| Public Website / Landing Page (Section 16) | 7 | 6 | 0 | 1 | 0 |
| **कुल** | **96** | **66** | **7** | **23** | **0** |

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
  - स्थिति/अगला काम: Main Admin inbox और assignment-scoped Support Staff inbox/reply/status RPCs तथा अलग Staff UI source में मौजूद; SLA/escalation, attachments, PostgreSQL/pgTAP runtime और ownership-negative tests बाकी।
- **⚪ बाकी / पर्याप्त प्रमाण नहीं** — Rating moderation with reason, audit and appeal path।
  - स्थिति/अगला काम: Rating moderation/reason/appeal workflow अभी पर्याप्त source evidence से नहीं मिला।
- **🟡 आंशिक / काम जारी** — Expense entry, receipt, permitted approval, accounting heads, exports और period reports।
  - स्थिति/अगला काम: Finance expense RPC/UI मौजूद; receipts, approval, accounting heads/exports पूर्ण नहीं।
- **🟡 आंशिक / काम जारी** — Staff roles, granular permissions, least privilege और backend/RLS enforcement।
  - स्थिति/अगला काम: अलग Support-only registry/permission map, Main Admin-only lifecycle RPCs, live Auth-session-bound permission checks, assignment-scoped Staff-safe RPCs, isolated Staff login/UI और append-only activity audit source में मौजूद; केवल Support role enabled है। Migration apply, PostgreSQL compile/pgTAP execution, Edge Function deployment तथा live authorization/negative tests बाकी।
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


### 2026-11-14 — Admin phone-change finalize timeout recovery
- Audit में एक जोखिम मिला: finalization RPC के response/network failure पर Edge Function Auth phone को पुराने नंबर पर rollback कर सकती थी, जबकि Database RPC संभवतः पहले ही commit होकर profile + request को approved कर चुका हो। इससे Auth और profile अलग हो सकते थे।
- अब ambiguous finalization error पर Auth rollback नहीं होता। रिक्वेस्ट को recoverable sync_error में रखने की कोशिश होती है और Admin को queue refresh करके authoritative स्थिति जाँचने को कहा जाता है। यदि RPC पहले ही approved commit कर चुका है तो release RPC उस approved row को नहीं बदलता।
- Finalize RPC अब उसी Admin की पहले से approved रिक्वेस्ट को तभी idempotent success देता है जब confirmed Auth phone और संबंधित electrician profile phone दोनों OTP-verified नए नंबर से मेल खाते हों। अन्य mismatch पर error रहता है।
- Source-only; migration apply/deploy नहीं हुआ। वास्तविक Postgres lock/concurrency, lost-response, Auth update timeout और finalize retry परीक्षण final consolidated QA में बाकी हैं।


### 2026-11-14 — Admin phone-change claim release confirmation
- Audit में पाया कि Admin approval claim के बाद Auth read/update या finalize failure पर release RPC का परिणाम अनदेखा था। Release विफल होने पर request `processing` में अटक सकती थी, जबकि UI उसे queue में वापस आने की बात बता सकती थी।
- Release RPC अब JSON success/status लौटाती है, उसी Admin के processing claim को release करती है और पहले से released pending/sync_error state पर idempotent success देती है। अन्य अवस्था पर स्पष्ट failure देती है।
- Edge Function तीनों recovery paths में release result/error जाँचती है और केवल confirmed release पर queue में लौटने का संदेश देती है।
- Source-only; migration लागू/deploy नहीं। Postgres concurrency, lost network response, claim release failure और retry tests अंतिम consolidated QA में बाकी हैं।


### 2026-11-14 — Phone normalization consistency audit
- Audit phát hiện Auth phone và `electrician_profiles.phone` có thể lưu cùng số Ấn Độ ở định dạng khác nhau (ví dụ `+91XXXXXXXXXX` và `XXXXXXXXXX`). So sánh chỉ loại ký tự không phải số vẫn cho kết quả khác, khiến Admin recovery bị từ chối nhầm; đồng thời kiểm tra số trùng có thể bỏ sót định dạng 10/12 chữ số.
- Migration được chỉnh để so sánh canonical 10 chữ số cuối cho kiểm tra số cũ/mới, Auth/profile recovery, finalization và duplicate-number checks. Chuẩn lưu số mới vẫn là `+91` + 10 अंक.
- Source-only; migration chưa लागू. Cần compile và kiểm tra uniqueness/concurrency với dữ liệu legacy के अंतिम QA में।


### 2026-11-14 — Edge Auth phone comparison normalization
- Admin approval Edge Function पहले Auth phone और request phone को केवल non-digit हटाकर compare करती थी। Legacy local 10-digit बनाम `+91` 12-digit storage format में वही नंबर अलग समझा जा सकता था।
- `phoneDigits()` अब इस Indian-only flow में अंतिम 10 national digits compare करती है; SQL canonical comparison के अनुरूप partial-sync retry और old/new Auth checks सही format-independent comparison करेंगे।
- Source-only; deployed Edge Function पर runtime verification अंतिम consolidated QA में बाकी।


### 2026-11-14 — Phone-change OTP send failure history recovery
- Audit में पाया कि SMS send या cleanup response अनिश्चित होने पर Electrician UI error दिखाकर नया OTP बटन तुरंत फिर enable कर देती थी। इससे backend में `otp_pending` request बची होने पर duplicate/open-request retry हो सकता था।
- अब send failure के बाद UI authoritative phone-change history दोबारा load करती है। यदि history में pending request मिले तो form disabled रहता है; यदि history load की पुष्टि न हो तो नया OTP बटन सुरक्षित रूप से disabled रहता है और Dashboard Refresh करके स्थिति जाँचने को कहता है। History loader अब success/failure boolean भी लौटाता है।
- Source-only UI hardening; वास्तविक SMS/provider, network timeout और browser runtime tests अंतिम consolidated QA में बाकी हैं।
- Commit: `38d11f6f466b9a2e4519fe2b6e429755c863112f`.


### 2026-11-14 — Admin phone-change queue visibility for in-progress requests
- Audit में पाया कि Admin claim के बाद request `processing` में अटक जाए (उदाहरण: release RPC की पुष्टि न मिले), तो Admin queue उसे छिपा देती थी। इससे Admin को पता ही नहीं चलता कि किसी अनुरोध की स्थिति अटकी हुई है।
- Migration की Admin list RPC अब `pending_admin`, `sync_error` और `processing` तीनों अवस्थाएँ लौटाती है तथा `request_status` field देती है। Admin UI स्थिति स्पष्ट दिखाती है और `processing` पर दोबारा Approve/Reject बटन नहीं देती, ताकि संभावित concurrent/ambiguous कार्रवाई दोहराई न जाए।
- Source-only; migration लागू नहीं हुई। Stuck-processing recovery policy, SQL compile और Admin UI runtime tests अंतिम consolidated QA में बाकी हैं।
- Commits: migration `4d35ecc9932570d53a54d32b9ce2a4901e058a5d`; Admin UI `11286150259fac99cc777ab2f4ed8c60d1e1261c`.


### 2026-11-14 — Admin phone queue SQL delimiter verification
- Static delimiter audit में Admin queue RPC के `SECURITY DEFINER` body का closing/opening dollar-quote mismatch मिला; उसे ठीक करके `$$` delimiter पुनः स्थापित किया।
- Migration का delimiter balance और PostgreSQL compile अभी भी वास्तविक database पर अंतिम QA में verify करना बाकी है; source-only स्थिति यथावत है।
- Commit: `ec840e8b14b6a8dab6e8fa7866c107e6a12122ae`.

- अतिरिक्त static verification में JavaScript replacement-string escaping के कारण SQL delimiter correction पहले अपेक्षित रूप से लागू नहीं हुआ था; अब literal `$$` को सुरक्षित callback replacement से ठीक किया और migration में 14 balanced dollar delimiters पुनः जाँचे।
- Corrective migration commit: `04fef336894d9b22568cc7df153b7cc989c26770`.


### 2026-11-14 — Admin phone-change duplicate check canonical digits
- Admin claim RPC के duplicate-number guard में एक format mismatch मिला: candidate phone को 12 digits (+91 सहित) में रखा जा रहा था, जबकि Auth/profile values की तुलना अंतिम 10 digits से हो रही थी। इस कारण पहले से किसी दूसरे अकाउंट पर मौजूद वही भारतीय मोबाइल नंबर duplicate check से निकल सकता था।
- अब candidate number भी अंतिम 10 राष्ट्रीय digits में canonicalize होता है; Auth और electrician profile duplicate checks समान format में compare करते हैं।
- साथ में जाँचा: Admin queue RPC pending_admin, sync_error और processing recoverable states लौटाता है; phone-change request table पर RLS enabled है, browser roles के direct table grants revoke हैं, और सभी RPC execute grants केवल service_role को दिए गए हैं। Profile mapping user_id/auth_user_id दोनों को पहचानती है।
- Electrician OTP-send error path अब authoritative history refresh करता है; history न पढ़ पाने पर नया send button disabled रखता है।
- Source-only; migration लागू नहीं, Edge Function deploy नहीं। SQL compilation, Auth/profile legacy-format uniqueness, Admin queue authorization तथा OTP/provider/network failure tests अंतिम consolidated QA में बाकी हैं।
- SQL commit: e3395f956e2c68c8441e268d1a6ba571c71fa4a5.


### 2026-11-14 — Phone-change SQL dollar-quote syntax correction
- पूरे phone-change migration का static syntax audit करते समय दो PL/pgSQL functions में dollar-quote delimiters गलत मिले: srk_phone_change_cancel_send और srk_admin_release_electrician_phone_change में `as $ ... $;` था, जो PostgreSQL function body delimiter के रूप में valid नहीं है।
- दोनों को `as $$ ... $$;` में ठीक किया। अब migration में 9 function definitions और 9 matching `as $$` / `$$;` delimiters हैं; कोई malformed single-dollar opener/closer शेष नहीं। यह static delimiter check है, PostgreSQL compile/runtime test नहीं।
- 2Factor के प्रकाशित manual OTP API निर्देश custom template endpoint `/SMS/{phone}/{otp}/{template_name}` और सफल API response में `Status: Success` तथा `Details` session ID दिखाते हैं। मौजूदा integration का endpoint/response check इस documented pattern से मेल खाता है। API acceptance को handset delivery नहीं माना जाएगा; वास्तविक delivery के लिए provider callback/DLR और live approved template/account की जाँच अंतिम QA में आवश्यक है। कोई SMS नहीं भेजा और कोई API key configure नहीं की।
- Source-only; migration लागू नहीं, Edge Function deploy नहीं।
- Commits: cancel-send SQL delimiter correction `17d191a0273ef65538b6a65b502e57c3f98012ef`; Admin release SQL delimiter correction `2ca594cbcbfc439c4c62fba4b41da9e7edd17f19`.


### 2026-11-14 — Phone-change profile mapping ambiguity guard
- `srk_phone_change_prepare` पहले `user_id` या `auth_user_id` से मिलने वाली पहली electrician profile चुन लेता था। यदि legacy data में दोनों mapping अलग-अलग profile rows पर हों, तो गलत profile बदलने का जोखिम था।
- अब request बनाने से पहले matching distinct profile IDs की संख्या ठीक 1 होना अनिवार्य है। शून्य या एक से अधिक mapping होने पर request सुरक्षित रूप से रोक दी जाती है; arbitrary profile चयन नहीं होता।
- Source-only static hardening; वास्तविक database constraints/data और Postgres runtime परीक्षण अंतिम consolidated QA में बाकी हैं।
- Migration commit: 287ea9bbd4de8fa90de27320a86dac830ea96f9c.


### 2026-11-14 — Admin Portal authentication and privileged-trigger audit
- Admin login initialization में दो parallel session paths (onAuthStateChange और getSession) एक साथ showState() चला सकते थे; इससे duplicate Admin data loads और stale auth response के बाद UI state race का जोखिम था। अब Supabase auth callback के अंदर async RPC नहीं चलती; callback deferred है, generation guard stale response रोकता है, और एक ही authorized user के लिए initial data केवल एक बार load होता है।
- Admin cancellation migration audit में दो SECURITY DEFINER trigger functions के default PUBLIC execute grants मिले। srk_guard_direct_booking_cancellation() और broadcast_booking_job() पर explicit REVOKE ALL जोड़ा गया; दोनों source migrations दोबारा fetch करके बदलाव verify किए।
- अन्य जाँचे गए Admin RPC groups (area relocation, work review, cancellation decisions, customer/electrician support, KYC document path, payouts, commission/wallet, refunds, rate-tier और booking offer) में explicit PUBLIC revoke मौजूद मिला।
- Source-only; कोई migration apply/deploy नहीं हुई। PostgreSQL compile, RLS/role matrix, auth race runtime और full Admin action tests अंतिम consolidated QA में बाकी हैं।
- Commits: Admin auth/UI 778d790792a9081f074d821ff4ac4118e96e22b5; cancellation trigger revoke cd5c0d8a07350fffb6be48c1f2a9481f73342b86; dispatch trigger revoke 3cc1f33df946134dfc39a2ac316de7a1063009d.


### 2026-11-14 — Admin auth race और duplicate-action guards
- Auth event आते ही Admin auth generation तुरंत invalidate होती है; deferred UI refresh के दौरान पुराने admin-check RPC का response अब नई session state पर लागू नहीं हो सकता।
- ग्राहक booking location update और electrician application review में per-record busy guards जोड़े; double-click से duplicate concurrent updates/reviews रोके जाते हैं। इन handlers में safe error messaging भी जोड़ी गई।
- Admin direct-write audit में service_bookings पर location/status/quoted_amount और electrician_profiles पर active flag के direct updates पहचाने गए। इनकी effective RLS/column privileges और trigger protections का migration-by-migration audit जारी है; broad policy को बिना पूरी dependency जाँचे नहीं बदला।
- Source-only; browser runtime और वास्तविक RLS tests अंतिम consolidated QA में बाकी।
- Commits: auth event race guard 1927912d9751751137f445142fbc49e492d9eaac; duplicate-action guards 1a9101ea997bf6b331e01f69f1860bebabb811bf.


### 2026-11-14 — Admin RLS/column-permission audit finding
- Admin setup migration में service_bookings के लिए is_srk_admin() आधारित UPDATE policy और electrician_profiles के लिए broad FOR ALL policy मिली। इसका अर्थ है कि Admin role को इन tables पर row-level access तो सीमित है, लेकिन policy अकेले column-level सीमाएँ लागू नहीं करती।
- Admin UI वर्तमान में service_bookings पर पता/जिला/राज्य/PIN, status और quoted_amount update करता है; electrician_profiles पर active flag update करता है। Cancellation trigger सीधे cancelled status को रोकता है, लेकिन अन्य sensitive columns की सुरक्षित सीमा केवल UI validation पर नहीं छोड़ी जानी चाहिए।
- अभी broad RLS policy को बिना Customer/Electrician portal के सभी direct-write paths और required columns का पूरा dependency map बनाए नहीं बदला; गलत column grants से अन्य portals टूट सकते हैं। अगला source task: direct-write inventory पूरी करना और Admin के अनुमत update columns को सुरक्षित RPC/column grants में migrate करने की योजना बनाना।
- यह source audit है; कोई migration apply या live permission change नहीं किया गया।

- अतिरिक्त Admin hardening: इलेक्ट्रिशियन relocation request के Admin approve/reject handler में duplicate-submit guard, decision allowlist, missing-result protection और request के दौरान buttons disable/restore जोड़ा गया। Commit `75218663b0efacd4a7368caecd1a880dfc939f14`; source-only, runtime test final QA में।


### 2026-11-14 — Admin customer-support action hardening
- ग्राहक शिकायत की स्थिति/नोट सेव करने के लिए प्रति-शिकायत duplicate-submit guard, वास्तविक workflow states (`new`, `in_review`, `resolved`, `closed`) की allowlist, missing-field handling और save के दौरान button lock जोड़ा। UI select और source validation का मिलान किया।
- Customer support reply में concurrent duplicate send guard, button lock और selected thread बदलने पर गलत reply composer साफ न करने की सुरक्षा जोड़ी।
- Commits: `f940000caad10e7ccc976be823b9998badd18e79`, `6d6facb23acb3d67ad94612dbd4915300265ea55`. Source-only; runtime/database tests final consolidated QA में।


### 2026-11-14 — Admin KYC और customer thread hardening
- KYC document review में प्रति-दस्तावेज़ duplicate-submit guard, decision allowlist (`approved`, `rejected`, `needs_resubmission`), rejection/resubmission reason minimum 5 chars, 1000-char note cap, in-flight button lock और safe failure message जोड़ा।
- Customer support thread loader में request-generation guard जोड़ा ताकि पुराने धीमे response से बाद में खोली गई दूसरी शिकायत की बातचीत overwrite न हो।
- Commit `c34cb478f208752410ad1352bbdfa6c76d9560ec`; source-only, final consolidated QA में runtime verification शेष।


### 2026-11-14 — Admin logout reliability
- Logout action में duplicate-click guard, in-flight button disable, Supabase signOut error handling और उपयोगकर्ता को सुरक्षित retry संदेश जोड़ा।
- Commit `aa5d8fe909e1cc98a8ccfeb1f46eab9a1c6fba0a`; source-only change, auth session expiry/network failure runtime QA अंतिम consolidated testing में होगा।


### 2026-11-14 — Admin direct-write / database authority audit
- `admin.html` के Admin direct-write points map किए: `service_bookings` पर customer location (`address`,`district`,`state`,`pincode`) तथा booking (`status`,`quoted_amount`) updates; `electrician_profiles` पर केवल `active` toggle. बाकी sensitive operations dedicated Admin RPC / Edge Function से चलते हैं।
- Booking status/payment handlers में UI allowlists और Razorpay/manual-settlement guards मौजूद हैं; cancellation trigger direct `cancelled` status को dedicated Admin decision के बिना रोकता है। Electrician active/rate-tier activation के लिए database trigger भी मौजूद है।
- उपलब्ध migration history में service-booking और electrician-profile के मूल व्यापक Admin UPDATE policies/column grants की पूर्ण परिभाषा इस branch के tracked migration set से स्पष्ट नहीं हुई। इसलिए column-level grants या policies बदलना अभी सुरक्षित नहीं; कोई DB migration लागू/बदली नहीं। अगला कदम base schema/policy provenance और सभी app direct-write dependencies की पुष्टि के बाद restricted Admin RPC/column-grant design करना है।
- Audit source-only है; live database permissions, RLS behavior और concurrent update tests अंतिम consolidated QA में ही सत्यापित होंगे।


### 2026-11-14 — Admin electrician activation contract alignment
- Admin `toggleActive()` में approved rate-tier का canonical enum `premium_electrical_specialist` रखा और केवल tier string के बजाय `approved_rate_card_version`, `rate_tier_approved_by`, `rate_tier_approved_at` की मौजूदगी भी जाँची। यह database activation trigger के contract के अनुरूप है; backend trigger अंतिम authority बना रहता है।
- Admin source commit `f7679c00052584fbc61b7ee4ce66b8a88e3dc364`; source fetch द्वारा बदलाव verify किया। कोई database migration/apply या production setting change नहीं हुआ।
- अभी भी direct-write dependency audit बाकी है: location/booking updates और `electrician_profiles.active` के लिए सुरक्षित RPC/column-grant design तभी लागू होगा जब base policies तथा सभी app dependencies पूरी तरह map हो जाएँ।


### 2026-11-14 — Admin electrician activation direct-write fix
- Live Supabase read-only privilege audit में पुष्टि हुई कि `authenticated` को `electrician_profiles` पर केवल SELECT table privilege है; `active` column UPDATE grant नहीं है। इसलिए Admin का पुराना direct `.update({active})` काम नहीं कर सकता था।
- मौजूदा `srk_admin_set_electrician_active(uuid,boolean)` RPC की वास्तविक DB definition जाँची: यह `auth.uid()` और `is_srk_admin()` verify करता है, profile row lock करता है, OTP-linked identity, latest identity/address documents की Admin approval जाँचता है, फिर `active` बदलता है। Rate-tier activation trigger अतिरिक्त approved tier metadata enforce करता है।
- Admin UI को direct table UPDATE से हटाकर इसी audited RPC पर बदला; duplicate-click guard और UI prechecks बने रहे। Code commit `595f731080752cb2bf0c749e6b81084f4e4a862b`; source fetch द्वारा RPC call verify किया।
- Read-only DB audit में `service_bookings` के `address`,`district`,`state`,`pincode`,`status`,`quoted_amount` के UPDATE column grants तथा Admin-only UPDATE RLS policy मौजूद मिले; customer-location और booking direct updates को अभी बदलने की जरूरत का प्रमाण नहीं मिला। कोई DB schema/permission परिवर्तन या migration apply नहीं किया।


### Admin Staff RBAC — सुरक्षा निर्भरता ऑडिट (14 नवम्बर 2026)
- Read-only Supabase schema audit: `srk_admin_users` में केवल `user_id` और `created_at` हैं; यह मौजूदा Main Admin allowlist है। `is_srk_admin()` इसी table की membership को full Admin authority मानता है। इसलिए Staff को इस table में जोड़ना privilege escalation होगा; ऐसा नहीं किया गया।
- Database catalog में 73 public functions मिले; 30 function bodies सीधे `is_srk_admin()` पर निर्भर हैं। इनमें finance, refunds, payouts, KYC, booking operations, contacts और audit शामिल हैं। Role-based Staff access शुरू करने से पहले इन RPCs को permission-wise migrate करना आवश्यक है; केवल UI में buttons छिपाना पर्याप्त नहीं।
- `srk_admin_audit_events` पर client roles को table grants नहीं मिले; अभी audit listing RPC भी `is_srk_admin()` माँगता है। Existing audit capture trigger केवल चुनिंदा business entities/fields दर्ज करता है, इसलिए Staff identity/action/reason का पूरा audit अभी उपलब्ध नहीं।
- Admin Portal में customer/electrician support inbox मौजूद हैं, लेकिन Staff assignment/ownership और role-based ticket scope नहीं मिला।
- आगे का सुरक्षित क्रम: (1) अलग staff registry/role/permission schema, (2) Main Admin-only staff lifecycle RPCs, (3) permission-check helper এবং Staff-safe support RPCs, (4) सभी 30 privileged Admin RPCs की permission matrix के अनुसार समीक्षा/रूपांतरण, (5) Auth invite/disable और session revocation, (6) Admin UI + audit tests। इस audit में केवल read-only DB queries हुईं; कोई migration apply, user create, या production change नहीं हुआ।


### 2026-11-14 — Admin Staff RBAC foundation (source-only)
- अलग Staff registry, Support permission catalog/role map, session metadata और append-only Staff audit schema की migration source branch में जोड़ी।
- Main Admin की full authority अभी भी केवल `srk_admin_users` / `is_srk_admin()` से आती है; Staff को Main Admin allowlist में जोड़ने का कोई रास्ता नहीं बनाया। शुरुआती Support role को केवल support read/reply/status और सीमित booking context permissions दी गईं; finance, refund, payout, KYC, private contacts, cancellation decision, staff management और audit-read permissions नहीं दी गईं।
- सभी Staff RBAC tables पर RLS enable और browser roles के direct grants revoke किए। Permission helper SECURITY DEFINER + empty search_path के साथ active staff status और explicit role mapping जाँचता है। Staff audit पर UPDATE/DELETE/TRUNCATE रोकने वाले triggers जोड़े।
- Database pgTAP test file में tables, grants, permission boundary, helper security definition और audit immutability के checks जोड़े।
- Commits: migration `c8ea3339ed7ef59a913596e6c1df62b0078e17e6`; tests `374dff0b12751db4c02cb137f2013812a932c811`.
- यह केवल Git branch source है। Migration apply नहीं हुई, Auth staff user नहीं बना, कोई production setting या paid staging branch नहीं बदली। PostgreSQL compile और pgTAP execution अभी बाकी हैं।
- अगला काम: Main Admin-only staff lifecycle RPCs, session revoke checks, secure Auth invite/disable Edge Function और Support inbox को assignment-scoped Staff-safe RPCs में अलग करना। मौजूदा broad Admin support RPCs को अभी Staff के लिए grant नहीं किया गया।


### 2026-11-14 — Admin Staff lifecycle, sessions और Main Admin UI (source-only)
- Staff RBAC migration में Main Admin-only Staff list/status RPCs, Support invite registration RPC और Staff session register/list/revoke RPCs जोड़े। Invite registration RPC केवल `service_role` execute कर सकता है; client-supplied role स्वीकार नहीं होता और Support role fixed है।
- Staff permission helper अब current JWT `session_id` को `auth.sessions` में live session से मिलाता है और tracked revoked session को deny करता है। Suspended/Disabled Staff के tracked sessions revoke होते हैं; fresh login के बिना पुराने session को पुनः सक्रिय नहीं किया जाता।
- `admin-staff-management` Edge Function source जोड़ा: पहले Supabase Auth से वास्तविक user verify, फिर `is_srk_admin()` Main Admin check; invite के समय केवल fixed Support role, user metadata में सिर्फ display name; service-role key browser में नहीं जाती। Registry write असफल होने पर unregistered invited Auth user cleanup का प्रयास।
- Admin Portal में Main Admin-only Staff Management UI जोड़ी: Support invitation, Active/Suspend/Disable, reason-required audit, session list और per-session revoke controls।
- pgTAP test file 23 assertions तक बढ़ाई। Inline Admin JavaScript का compile-only syntax check सफल; SQL/pgTAP अभी execute नहीं हुए।
- Commits: lifecycle/session SQL `011f0eb0ec048be1887d86fbca635966407c7a64`, session list/revoke SQL `ec2125db9cd8ec75041e6ac8b503365d1b34dcc4`, Edge Function `a4143d7b246e6a7be53688f00c0801ad7b634c8c`, tests `65b3e66986f44ca899a9d788ee34280d8c3bb070`, Admin UI `a58f56e2dcb93a40d8399f50757d5f7fed979a33`.
- कोई migration apply या Edge Function deploy नहीं हुई; कोई Staff account/invitation नहीं भेजी गई। Staff login अभी जानबूझकर बंद है, क्योंकि support inbox assignment-scoped Staff-safe RPCs और UI isolation अगला dependency है।


### 2026-11-14 — Assignment-scoped Support Staff inbox और अलग Portal mode (source-only)
- Staff के लिए customer complaint और electrician support ticket की अलग assignment table बनाई। एक case का एक current owner; assignment/reassignment केवल Main Admin कर सकता है और कारण सहित audit event बनता है।
- Staff-safe RPCs बनाए: केवल signed-in Staff को सौंपे गए cases की सूची, उसी assigned case की messages, reply और सीमित status update। Staff status केवल `in_review` या `resolved` कर सकता है; `closed` / cancellation decision Main Admin के पास रहता है।
- Staff inbox responses में customer phone, electrician phone, electrician name/profile identity, address, KYC, bank/UPI और finance fields शामिल नहीं। Customer message में sender_user_id जोड़ा ताकि Staff reply का actor रिकॉर्ड रहे।
- Permission helper को और सख्त किया: Support permission तभी मिलेगी जब JWT session_id Auth के live `auth.sessions` में मौजूद हो और Staff session metadata में उसी session की active, non-revoked registration हो। Portal पहले session register करता है, फिर permission जाँचता है।
- Admin Portal में Main Admin के लिए support case assign/reassign controls जोड़े। अलग Support Staff mode में केवल दो assigned inbox cards दिखाई देते हैं; Main Admin के बाकी dashboard cards छिपते हैं। Staff के लिए email OTP sign-in path जोड़ा, जिसमें `shouldCreateUser:false` है—अज्ञात ईमेल से नया account नहीं बनेगा।
- Static verification: inline Admin JavaScript compile-only syntax check सफल; 40 pgTAP assertions और plan count match; 19 नई/संशोधित SQL functions में सभी पर explicit revoke मौजूद; Edge Function Main Admin check और fixed Support role source से verify। PostgreSQL compile/pgTAP execution अभी बाकी।
- Commits: assignment RPCs `c1aa2834d5d79d2e730786f13a9e153b7cd6f5f9`, pgTAP `5d8efc469ac7bec63d51b3ec9eb3d23acf005317`, Main Admin assignment list `a39b9ba2856f142a049aaf668b54cf1ce0ccbc7f`, assignment UI `346ef378507b1842cdbf921706ac22d4e690599c`, isolated Staff Portal `c3d4de6a61a39c85822cecd2b966e35530ebd7a8`, Staff OTP login `4220e266926a1d4f9a684ce733be02dd69d977d9`, mandatory session registration `152a01b1197388d99ff94fd283f4a8167c338748` / `43fe03fd9fa59e53dd4aab4ac1334d6ec2e195af`, Portal session-first gate `027aaf2c9ac282dbe1408672332bf70c2a3f2dea`.
- अभी कोई migration apply या Edge Function deploy नहीं हुई; कोई invitation email नहीं भेजा गया; Staff access production में enable नहीं हुआ। Source branch पर implementation आगे जारी है।


- अतिरिक्त hardening: Staff status RPC अब null status अस्वीकार करता है और बंद complaint/ticket को दोबारा खोलने नहीं देता; Main Admin बंद case assign नहीं कर सकता। Staff thread loaders में request-generation guard जोड़ा ताकि धीमे पुराने response से दूसरी खुली बातचीत overwrite न हो। Commits: `944c3fa4e0a00d8fe065251332de67695fb1582d`, `87bfe6534cf7a46b54d578829c42648cd856e8ab`, `36dd601ee628423ae3e4fd07536d03b818882dcc`, pgTAP guard test `4c05c17f07fcc98eb1594a19ab255f2e610802a6`.
- अंतिम source-only static pass: Admin inline JavaScript compile check PASS; 43/43 pgTAP plan/assertion count match; 19 SQL functions में explicit revoke मौजूद; Staff session registration mandatory; assignment ownership filter और private-contact exclusions source में मौजूद। ये compile/static checks हैं, PostgreSQL runtime या pgTAP execution नहीं।


- अतिरिक्त least-privilege सुधार: Staff inbox list में `booking.read_basic` permission भी अनिवार्य की; reply/status mutation के लिए संबंधित read + action दोनों permissions चाहिए। बंद support cases को assign/reopen नहीं किया जा सकता। Staff के नए Auth session registration पर audit event auto-record होता है; Main Admin UI में Staff activity audit history देखने का control जोड़ा।
- नवीनतम commits: Staff session audit trigger `9c6666ee945cad3d076cfcef2e27442f9c2c5ab9`, Main Admin audit reader `30b04b735fe17272abb3119500db2d71ef6df5eb`, pgTAP `c535c5ff00e397082e7d2f14ed489d3ce0ff5c1f`, Main Admin audit UI `e695d5b1dc02b0af262d4d5c6ea830fb14a01593`, read-plus-action permission `d593527ba0f195bb607a73560bbfbadc4256910d`, booking context permission `1e76f9b10055d43a626ce033d448a66a028962df`, related tests `fc95c06027dfe51c54087e44270a11985ab09ab5` / `25fcc3b853d6672e769d698b2fe9112bc78736f2`.
- Latest static verification: Admin JavaScript compile check PASS; pgTAP plan/assertions 51/51; 21 SQL functions, each with explicit revoke; Edge invite function role remains fixed to Support. Runtime SQL/pgTAP and live invite/session tests remain unexecuted because no migration was applied and no Edge Function deployed.


- अतिरिक्त source review (14-11-2026): Staff activation RPC में अब `auth.users.email_confirmed_at` सत्यापित होता है; unverified ईमेल वाले invited account को Active नहीं किया जा सकता। Electrician support status RPC में NULL status की explicit rejection भी जोड़ी, जिससे PostgreSQL की NULL boolean semantics के कारण invalid status आगे न बढ़ सके। pgTAP source assertion को verified-email activation rule से align किया। Commits: migration `5f98dad697676f4a45434492414eeca001144a15`, test `df77508eba271ab80ef2324223313450ed7a79c2`. ये source-only बदलाव हैं; migration/pgTAP runtime में नहीं चलाए गए।

- Staff invite flow के लिए optional server-only `ADMIN_PORTAL_REDIRECT_URL` support जोड़ा। Redirect URL malformed या non-localhost HTTP हो तो function fail-closed करता है; production redirect को Supabase Auth Redirect URLs allow-list में जोड़ना होगा। Env unset होने पर Supabase configured Site URL default रहेगा। Commit: `fb5501e4010736299f9763d156e5e465d42caff0`. Function deploy/configure नहीं किया गया; कोई invite email नहीं भेजी गई।


### 2026-11-14 — Staff session registration और suspension race hardening
- Source review में एक concurrency edge case मिला: Staff का session registration और Main Admin का suspend/disable एक साथ चलने पर registration status-check के बाद insert कर सकता था। ऐसी स्थिति में suspension के बाद बना tracked session, भविष्य में reactivation होने पर अनचाहे रूप से फिर valid हो सकता था।
- srk_admin_staff_register_session() अब Staff registry row पर FOR SHARE lock लेकर active status जाँचता है। इससे registration और status-change RPC एक-दूसरे के साथ serialize होते हैं: registration पहले हो तो suspension बाद में उसी session को revoke करती है; suspension पहले हो तो registration updated inactive status देखकर deny होती है।
- pgTAP source में lock/status guard assertion जोड़ा; plan/assertion count 54/54 match किया जाना है। PostgreSQL compile, pgTAP execution और वास्तविक concurrent transaction test अभी नहीं चले हैं।
- Commits: migration dc111fce9272e26195200133e97096cf18dcc0d5 (final repaired source); test fbcc2f177572b86e1aa03fdc3d178f040b79b37e. Source-only; कोई migration apply, Auth session revoke API, deploy या production change नहीं।


### 2026-11-14 — Permission-check और suspension concurrency fix
- Migration में बाद की duplicate function definition के कारण `srk_has_admin_permission()` की अंतिम definition tracked session / live `auth.sessions` validation को overwrite कर रही थी। अंतिम applied definition को ठीक किया: Staff permission अब exact JWT session, matching Auth session और non-revoked tracked session तीनों verify करती है। Main Admin का अलग authorization path जस का तस है।
- एक और TOCTOU race बंद की: permission check अब active Staff registry row पर `FOR SHARE` lock रखता है। Suspend/Disable RPC उसी row पर `FOR UPDATE` लेती है, इसलिए Staff read/write request permission check पार करके suspension के बाद जारी नहीं रह सकती। चार Staff read RPCs को VOLATILE किया ताकि वे इस transactional row lock का उपयोग कर सकें।
- pgTAP source plan/assertions अब 55/55 हैं; अभी केवल static source-count/definition verification है, pgTAP execute नहीं हुआ। PostgreSQL compile और concurrent transaction tests शेष हैं।
- Source commits: permission/session fix  d5e213271b2d9cdd20cb76ffd6ec60e30ce9c0e0; lock serialization 5c322ec787c931b3d8f59d9f77442f51c54ac65c; test ae9ae20dd7e1b06901ee1eaab74e7781f7ce6a8e. No migration apply, deployment, or production changes.


### 2026-11-14 — Staff session revoke concurrency hardening
- गहरी concurrency review में एक अतिरिक्त TOCTOU gap मिला: permission helper tracked session का non-revoked status जाँचता था, लेकिन उस session row को lock नहीं करता था। इसलिए Main Admin का explicit session revoke और उसी session से चल रही Staff request एक साथ शुरू हों तो permission check revoke commit से पहले pass कर सकता था।
- अंतिम `srk_has_admin_permission()` definition अब matching, non-revoked `srk_admin_staff_sessions` row पर `FOR SHARE` lock लेती है। Explicit revoke उसी row को update करता है, इसलिए in-flight authorized transaction पूरा होने तक revoke serialize होगा; revoke पहले commit हो तो अगली permission check deny होगी। Existing Staff registry suspension lock भी बरकरार है।
- pgTAP source plan/assertions 56/56 किए; नया assertion specifically tracked session row के `FOR SHARE` lock की जाँच करता है। Static plan/count verification अलग से करनी है; pgTAP/PostgreSQL runtime और वास्तविक concurrent transaction test अभी execute नहीं हुए।
- Source commits: migration `9439e276b1c16538bc44192455a2d455ff98664c`; test assertion refinement `24ffade70e46d5bbf1d8d9fb13cec335842610df`. कोई migration apply, deploy, Auth invite या production change नहीं।


### 2026-11-14 — Admin Staff RBAC: audit immutability और assignment constraints की test coverage
- Migration source की पुनः समीक्षा में पुष्टि की: Staff audit log पर UPDATE/DELETE के साथ BEFORE TRUNCATE trigger भी है; audit table, identity sequence और assignment table पर browser roles के direct grants revoke हैं। Assignment map में (case_type, case_id) unique constraint और सीमित case-type CHECK constraint हैं; assignment/reassignment Main Admin RPC से ही होता है और active Support staff row पर lock लेता है।
- pgTAP source में तीन अतिरिक्त assertions जोड़े: (1) audit table पर browser TRUNCATE privilege deny + truncate trigger मौजूद, (2) assignment uniqueness और case-type vocabulary constraints, (3) browser roles assignment ownership या Staff session rows को सीधे mutate/register नहीं कर सकते।
- Static source count: pgTAP plan 59 और assertion calls 59 — count match। यह केवल test-source/static check है; pgTAP execute, PostgreSQL migration compile, grants के live catalog audit और concurrent transaction tests अभी नहीं चले हैं।
- Commit: test e979596c38bcd7bce362f4853d5526ab3f6fb055. Migration source में कोई बदलाव/apply नहीं; deployment, live data या production settings नहीं बदलीं।


### 2026-11-14 — Admin Staff RBAC: RPC EXECUTE privilege boundary tests
- सभी migration RPC grant/revoke declarations पुनः जाँचे। Authenticated Staff/Admin RPCs पर PUBLIC/anon execute हटाकर authenticated को सीमित grant है; invited-user registry RPC केवल service_role को grant है; session audit trigger helper browser roles से callable नहीं है। SECURITY DEFINER functions में empty search_path static रूप से confirmed है।
- pgTAP में तीन assertions जोड़े: session/lifecycle/assignment RPC grants, Staff support RPC grants, और service_role-only invite registration + trigger-helper non-executability।
- Static test-source count: plan 62, assertions 62 — exact match। अभी pgTAP execution या live role privilege catalog verification नहीं हुआ है; इसे source-level test coverage ही माना जाए।
- Commit: test 257da4f177bb83d8a7d3dbb345b36895a6405341. कोई migration apply/deploy या production change नहीं।


### 2026-11-14 — Support assignment/thread read concurrency hardening
- गहरी lock-order review में Admin assignment और Staff authorization के बीच संभावित deadlock cycle मिला: Admin path पहले case row और फिर Staff registry lock लेता था, जबकि Staff permission helper पहले Staff registry/session locks लेता है। Assignment RPC अब active Support staff row पर FOR SHARE पहले लेती है, फिर case row और assignment row—इससे Staff authorization के साथ lock order align होता है।
- Customer और electrician message-thread read RPCs अब case row तथा उसी case की वर्तमान assignment row पर FOR SHARE लेते हैं। इससे concurrent reassignment thread-read के बीच ownership बदलकर पुरानी Staff session को message history पढ़ने नहीं देगी; read lock order case → assignment है।
- pgTAP source plan/assertions 64/64 किए: assignment में Staff→case lock order और दोनों thread readers में case→assignment shared locks के static checks जोड़े। यह अभी source/static verification है; PostgreSQL compile, pgTAP execution और वास्तविक concurrent transaction tests अभी नहीं चले हैं।
- Commits: migration 174f238105254a8be5e5d6b74009a5512feeffd4; tests d660130fca418369c34036fccdec21d81bb1c933. कोई migration apply/deploy या production change नहीं।


### 2026-11-14 — Staff inbox ownership read-race hardening
- Inbox-list RPCs में भी reassignment race मिला: message-thread readers पर locks थे, लेकिन inbox सूची query assignment बदलते समय पुराने owner को एक stale case row लौटा सकती थी। दोनों Staff inbox queries अब case और assignment rows पर FOR SHARE लेती हैं, ताकि concurrent reassignment serialize हो और stale ownership result न निकले।
- pgTAP static source plan/assertions 65/65 किए; दोनों inbox functions के `FOR SHARE OF case,assignment` clauses के लिए एक संयुक्त assertion जोड़ा। यह SQL source review है, executed database test नहीं। PostgreSQL compile, pgTAP run और concurrency runtime tests अभी pending हैं।
- Commits: migration 0c60b9266434ac0c306454cbfe90a0dcf3d4194f; tests 02f2083575c6adec759de5f8ca7dd8443422e663. Migration apply/deploy या production बदलाव नहीं हुआ।


### 2026-11-14 — Append-only audit foreign-key deletion interaction
- Schema review में एक subtle integrity conflict मिला: immutable audit trigger `UPDATE` रोकता है, लेकिन audit actor/target पर `ON DELETE SET NULL` FK user deletion के समय उन्हीं audit rows को UPDATE करने की कोशिश करता। इससे historical audit record सुरक्षित रखने के बजाय संबंधित Auth user deletion अनपेक्षित रूप से fail हो सकती थी। Audit actor/target अब historical UUID snapshots हैं, उन पर cascading/set-null FK नहीं है; immutable audit history user deletion से mutate नहीं होगी।
- pgTAP plan/assertions 66/66 किए; नया assertion audit actor/target columns पर FK न होने की जाँच करता है। अभी केवल source/static review; SQL parser, migration execution और pgTAP runtime run pending हैं।
- Commits: migration ec16ac40a587fc00520baf301e152c6b1a7de23a; tests a368df7dfb50db48c32305cda16c1ab824007273. कोई production migration apply/deploy नहीं।


### 2026-11-14 — Staff RBAC dependency audit (blocking)
- Read-only catalog inspection of the primary Supabase project `gnqhoaqatmoiwwhgzkgm` found `public.srk_booking_complaints` exists with RLS enabled, but `public.srk_electrician_support_tickets`, `public.srk_electrician_support_messages`, and `public.srk_booking_complaint_messages` were not present in the inspected production catalog. Repository code search also did not find any creation migration for the two electrician support tables. The RBAC migration currently references the electrician ticket/message tables in functions and references the customer message table when adding `sender_user_id`.
- This is a hard migration dependency gap: the RBAC migration cannot be considered executable/ready until the canonical support-ticket schema and message-table dependencies are created or the RPCs are correctly mapped to the actual canonical schema. Do not apply the migration. No speculative tables were created. Next step: inspect the full migration chain and existing support UI/RPC contracts, then design the missing canonical schema and add prerequisite migration/tests before the RBAC migration.
- Supabase docs reviewed for RLS/function security and trigger behavior. A read-only SQL probe that cast missing relations to `regclass` errored as expected; a safe catalog query confirmed only `srk_booking_complaints` among the four queried relations. No production writes were performed.


### 2026-11-14 — Support migration-chain correction और attachment FK ordering fix
- पिछले dependency-audit note में source repository के migration files पर अधूरा निष्कर्ष दर्ज हुआ था। पूर्ण migration tree/feature branch files दोबारा जाँचने पर पुष्टि हुई कि canonical source migrations मौजूद हैं: `20261113220000_customer_support_conversation_schema.sql` customer message/attachment schema बनाती है; `20261114350000_electrician_support_tickets_and_admin_inbox.sql` electrician ticket/message schema बनाती है; इनके बाद RBAC migration timestamp से सही क्रम में आती है। Production catalog में इन relations का न होना बताता है कि वे अभी वहाँ लागू नहीं हैं; यह source migration की अनुपस्थिति नहीं है। पहले note का “creation migration नहीं मिला” वाला निष्कर्ष सुधारित माना जाए।
- इस पुनः समीक्षा में customer support schema migration का वास्तविक PostgreSQL ordering defect मिला: attachment table का composite FK `(message_id, complaint_id)` जिस unique index पर निर्भर है, वह index attachment table बनने के बाद बनाया जा रहा था। PostgreSQL FK बनाते समय referenced unique key पहले से मौजूद होना चाहिए। Unique index creation को attachment table से पहले ले जाया गया।
- Fix commit: `1431577792071921a580f2ae1ca912b5595cd2f0`. Static order check PASS: unique index statement attachment table statement से पहले है।
- Support attachment pgTAP source plan/assertions 6 से 8 किए; composite unique index और validated composite FK के catalog checks जोड़े। Test commit: `5d07dee48c2cc34c830d766bceb682d62ed41012`. यह test-source/static count है, pgTAP execution नहीं।
- Customer, electrician और RBAC migrations अभी source-only हैं; migration application/deploy नहीं किया। PostgreSQL compile/pgTAP runtime और primary DB parity verification बाकी हैं। कोई production write/settings change नहीं।


### 2026-11-14 — Primary DB migration-history parity check (read-only)
- Primary project की migration history read-only पढ़ी: लागू migrations अभी `20261113081436` तक हैं; Customer support conversation (`20261113220000`), support attachment/Admin message list (`20261113230000`), Admin customer replies (`20261114300000`), Electrician tickets/inbox (`20261114350000`) और Admin Staff RBAC (`20261114390000`) अभी applied history में नहीं हैं।
- Catalog में `srk_booking_complaints` और `srk_booking_complaint_events` मौजूद तथा RLS-enabled हैं; `electrician_profiles` और `service_bookings` भी मौजूद/RLS-enabled हैं। चार नए conversation/ticket tables अनुपस्थित हैं, जो migration history के साथ consistent है। इसलिए missing tables के लिए अलग duplicate schema migration बनाने की जरूरत नहीं; मौजूदा ordered source migrations ही canonical creation path हैं।
- Read-only inspection only; कोई migration apply नहीं, कोई data/settings mutation नहीं। Support migration chain को source-level fix और tests के बाद भी runtime PostgreSQL/pgTAP verification की आवश्यकता रहेगी।


### 2026-11-14 — Electrician Support ticket security test coverage
- Electrician support migration की समीक्षा में पुष्टि की: ticket create RPC verified electrician profile (`user_id` और `auth_user_id`) से caller को जोड़ती है; optional booking तभी स्वीकार होता है जब वह उसी electrician को assigned हो; प्रति electrician 24 घंटे में अधिकतम 10 नए tickets की सीमा profile-row lock के साथ serialize होती है। Ticket/message tables पर RLS enabled है और browser roles को direct table grants नहीं दिए गए; read/write सीमित authenticated RPCs से होते हैं।
- नया pgTAP source file `supabase/tests/database/electrician_support_ticket_security.test.sql` जोड़ा। इसमें table existence/RLS, direct browser read/write denial, electrician/Admin RPC EXECUTE boundaries, ticket-row write serialization और category/status/sender-role constraints के 12 assertions हैं। Static plan/assertion count 12/12।
- Related test source counts पुनः जाँचे: Admin Staff RBAC 66/66 (इस file में has_table/has_function/has_trigger assertions सहित), Customer attachment access 8/8, Electrician ticket security 12/12। ये source-count checks हैं—pgTAP अभी execute नहीं हुआ।
- Commits: `38413db330fe92fb0f6f05d003d701bf1b00ddef` (test file); constraint coverage follow-up: `0f7792cd759fb8984521cba7876bf7538f053f5c`. कोई migration apply/deploy या Production mutation नहीं।


### 2026-11-14 — Support RPC security-definer static audit
- Customer conversation (4 functions), attachment/Admin message list (2), Main Admin customer reply (1), और Electrician support (8) migrations के सभी 15 functions `SECURITY DEFINER` हैं; प्रत्येक में `SET search_path = ''` और संबंधित explicit `REVOKE ALL ... FROM PUBLIC, anon` declaration मौजूद है।
- RBAC migration में 21 function definitions (permission helper की duplicate definition सहित), 20 SECURITY DEFINER definitions, 21 empty-search-path clauses और 21 revoke declarations मिले। यह static source audit है; runtime privilege catalog और function execution अभी सत्यापित नहीं हुए।
- यह audit source-only रहा। कोई SQL migration apply, Edge Function deploy, production setting/data change या PR merge नहीं किया।


### 2026-11-14 — Customer/Admin support message sender attribution
- Customer complaint message schema में `sender_user_id` (auth.users FK, `ON DELETE SET NULL`) जोड़ा। Customer reply RPC अब `auth.uid()` persist करती है; Main Admin reply RPC भी authenticated Admin user ID persist करती है। Staff reply RPC पहले से sender ID लिखती थी; RBAC migration का `ADD COLUMN IF NOT EXISTS` अब पहले से बने column के साथ idempotent रहता है।
- इससे customer, Main Admin और Support Staff—तीनों प्रकार के message sender का attributable record रहता है; user deletion पर पुरानी conversation rows सुरक्षित रहती हैं और केवल sender reference null होता है।
- RBAC pgTAP suite में sender column, FK delete behavior और Customer/Admin RPC sender attribution का assertion जोड़ा। Static checks: RBAC 67/67, Customer attachment access 8/8, Electrician support 12/12; सभी plan/assertion counts match।
- Source commits: customer schema/RPC `c5b478fed49993e4d7c31d9f0693772ea7db79ac`; Admin reply `de278f4a5da167697189dea10481b5b0bdcd1678`; test `536f6897a874b68a66bb8d58044dfbeab848912a` और FK assertion `be7f45be6aebac5791269046b5e323c85da09827`। Static verification only; pgTAP/SQL runtime नहीं चला। कोई Production mutation या deploy नहीं।


### 2026-11-14 — Customer Support attachments visible in Main Admin inbox
- Customer complaint में ग्राहक द्वारा upload की गई निजी फोटो/PDF पहले Customer Portal में दिखती थीं, लेकिन Main Admin conversation thread में attachments सूची/preview links उपलब्ध नहीं थे। यह end-to-end support workflow gap ठीक किया।
- नई Main-Admin-only RPC `srk_admin_list_complaint_message_attachments(uuid)` complaint existence और `is_srk_admin()` जाँचती है, attachment metadata लौटाती है, और 100 records पर सीमित है। EXECUTE केवल authenticated को; anon/PUBLIC revoke। Actual file access existing private bucket policy और 5-minute signed URLs से होता है; Staff RPC को यह capability नहीं दी।
- Admin conversation UI अब messages और attachment metadata साथ लोड करती है, message के नीचे filename/size और 5-minute signed link दिखाती है; links `noopener noreferrer` के साथ खुलते हैं।
- Support attachment pgTAP plan/assertions 8→10; static count 10/10। `admin.html`, `booking.html`, `electrician.html` inline JavaScript syntax parse checks PASS। Runtime SQL/pgTAP, signed-URL/storage runtime, browser/mobile checks अभी नहीं हुए। कोई migration apply/deploy/Production change नहीं।
- Source commits: migration `eb72c22e08c690dade6f5359b8caaed5fad3d8b5`; test `15099928ec3db53a8000f61c326fe4d798ce84aa`; Admin UI `f07ad08765b5e3647b9ce76670642163fbd6b7a6`।


### 2026-11-14 — Private Support Storage Admin-read policy verification
- Customer Support attachment access की follow-up security review में पुष्टि की कि bucket private है; Storage SELECT policy `srk_customer_support_object_access(name,true)` को call करती है; helper verified Main Admin को allow करता है और अन्य authenticated users के लिए user/complaint ownership path जाँचता है। Upload/delete policies owner-only helper (`false`) का उपयोग करती हैं।
- Attachment access pgTAP suite में policy/helper wiring का अतिरिक्त assertion जोड़ा: plan/assertions 10→11, static count 11/11। यह SQL catalog assertion source में जोड़ा गया है; वास्तविक DB पर अभी execute नहीं हुआ।
- Test commit: `f8a2a78523c6ab56f9a2e410c32ce14f77f60f15`। No schema apply, no deployment, no Production change.


### 2026-11-14 — Staff Support thread sender attribution
- Staff customer/electrician thread read RPCs अब `is_current_staff_sender` boolean लौटाते हैं (message `sender_user_id = auth.uid()`), जिससे अपना जवाब स्पष्ट रूप से “आप (Support Staff)” दिखता है और Main Admin के जवाब “SRK सहायता टीम” रहते हैं। कोई Staff/Auth user UUID browser response में expose नहीं किया गया।
- Customer और electrician Staff thread UI दोनों में sender labels सुधारे। Admin Staff RBAC pgTAP source suite plan/assertions 67→69, static count 69/69; वास्तविक pgTAP अभी execute नहीं हुआ।
- Migration source commit: `3a149f3098d2c9e0dc89a92eb0b07cb5e4e73806`; UI commit: `fbba18a2c6e9c4d9d6b4c2c67c6ad4c88230268c`; test commit: `d5468c1be988bafd7f18d64e6b1062b06d75d8f3`। No migration apply, deployment, or Production change.


### 2026-11-14 — Admin financial/cancellation permission boundary regression test
- Main Admin / Support Staff permission design की source review की: Support role में केवल 7 explicitly seeded permissions हैं — customer/electrician support read, reply, status update और सीमित `booking.read_basic`। Main Admin की अलग `is_srk_admin()` identity bypass बनी रहती है; Staff को इससे full Admin identity नहीं मिलती।
- Admin Staff RBAC pgTAP regression assertion को मजबूत किया: Support role में `finance.*`, `payment.*`, `wallet.*`, `refund.*`, `payout.*`, `cancellation.*`, `kyc.*`, staff/audit, cancellation-decision और private-contact permissions न हों।
- Test plan/assertion count 69/69 है; मौजूदा permission-boundary assertion को विस्तृत किया गया, नया assertion नहीं जोड़ा। यह source-level/static count है, pgTAP execution नहीं। PostgreSQL runtime, JWT-role integration और negative RPC execution tests अभी बाकी हैं।
- कोई migration apply, payment/refund/payout action, production setting change, deployment या PR merge नहीं किया गया।

### Refund / payout concurrency review — booking-first lock order fix (14 नवम्बर 2026)
- `srk_admin_prepare_razorpay_refund()` पहले Booking row lock करके उसके बाद Refund record lock करती है; payout settlement भी Booking → Payout क्रम रखता है।
- पहले `srk_service_reconcile_booking_refund()` उलटे क्रम में Refund row `FOR UPDATE` लेकर बाद में Booking update करती थी। Provider reconciliation और Admin refund preparation एक ही booking पर साथ चलें तो lock inversion/deadlock संभव था।
- Feature Branch migration `20261114290000_full_refund_cancellation_fee_and_wallet_reversal.sql` में reconciliation अब पहले refund से booking ID पढ़ती है (बिना row lock), फिर Booking `FOR UPDATE` lock करती है, फिर उसी booking से जुड़ा Refund row `FOR UPDATE` lock करती है। Record बदल/गायब होने पर fail-closed error।
- pgTAP source test `cancellation_fee_refund_reversal.test.sql` में booking-first lock order assertion जोड़ा; plan 24→25।
- Static source verification: test file में `plan(25)` और 25 assertion calls का exact match **25/25 PASS**; PostgreSQL compile, pgTAP execution और वास्तविक concurrent transaction test अभी नहीं चलाए गए।
- यह केवल Feature Branch source change है; कोई Production migration, refund, payout, provider API call या deployment नहीं हुआ। Admin Finance/Cancellation अभी Partial है।

### Refund provider webhook reconciliation — signed events and terminal-state protection (14 नवम्बर 2026)
- `razorpay-webhook.js` पहले केवल `payment.captured` / `order.paid` संभालता था; Refund events ignore होते थे। अब signed raw-body HMAC verification के बाद `refund.created`, `refund.processed` और `refund.failed` events पहचाने जाते हैं।
- Refund webhook handler provider refund ID, payment ID, INR currency, integer paise amount और DB refund record के payment/amount/refund ID का मिलान करता है। अस्पष्ट/गायब DB record पर 5xx देकर delivery retry माँगता है; payload/record mismatch पर business action नहीं करता और manual reconciliation संकेत देता है।
- Verified event के बाद केवल service-role RPC `srk_service_reconcile_booking_refund` call होता है। Browser/client को service-role access नहीं मिलता।
- RPC अब पहले से bound provider refund ID बदलने से मना करता है और `processed` / `failed` final states को terminal रखता है, ताकि late/out-of-order `refund.created` event किसी final refund को वापस `processing` न करे।
- Refund reconciliation lock-order test पहले से 25 था; terminal-state और provider-ID binding के 2 अतिरिक्त pgTAP source assertions जोड़े: plan/assertions **27/27** exact match।
- Source commits: migration `ed5ee9f56aadb4cfb479ed46d6ffc247e5c09946`; tests `c8001fe90b9c2250ec18e3e722214e2d9d675444`; webhook `aed7aca1f134b8929a055ae125294625ba919b1c`।
- सीमाएँ: यह provider webhook receive/reconcile path है; outbound Admin refund initiation caller, Razorpay Test Mode end-to-end, webhook duplicate-event durable inbox, PostgreSQL/pgTAP runtime और real concurrent tests अभी बाकी हैं। कोई real refund/payment, migration apply या deployment नहीं हुआ।

### Admin payout settlement + refund execution gap cross-check (14 नवम्बर 2026)
- `srk_admin_mark_electrician_payout_paid()` की source review: `auth.uid()` + `is_srk_admin()` Main Admin gate, UPI/Bank method allow-list, 4–120 char UTR/reference, booking-first `FOR UPDATE` और payout-row `FOR UPDATE`, केवल `pending` status, verified completed booking, immutable labour bill / approved legacy quote, exact payment and commission/payable ledger reconciliation। यह function पैसा transfer नहीं करता; वास्तविक बैंक/UPI transfer के बाद Admin reference दर्ज करता है। Staff के लिए payout permission नहीं है।
- Refund तैयारी में Booking → Refund → Payout lock order है; pending payout को `blocked` किया जाता है और payout-paid अवस्था में refund preparation fail-closed है। Payout settlement भी उसी Booking → Payout lock order का पालन करता है।
- अतिरिक्त cross-check में पुष्टि हुई कि मौजूदा `admin.html` में Refund initiate/retry UI नहीं है और branch में `razorpay-refund.js` / refund executor Netlify function भी मौजूद नहीं है। पुराने tracker paragraphs में executor उपलब्ध होने का दावा इस branch के वर्तमान source से मेल नहीं खाता; उसे लागू/सत्यापित न मानें। अभी जोड़ा गया `razorpay-webhook.js` केवल signed provider refund events receive/reconcile करता है; यह Razorpay Refund API call नहीं करता।
- इसलिए Refund provider lifecycle अभी **Partial / blocked** है: Admin द्वारा safe prepare RPC के बाद outbound Razorpay API call, stable idempotency-key retry, provider response persistence, Admin UI, Test Mode end-to-end और durable duplicate-event inbox बाकी हैं। कोई real refund/payment/payout, migration apply, deployment या production change नहीं हुआ।

### Main Admin Razorpay full-refund executor + Admin UI (14 नवम्बर 2026)
- razorpay-refund.js में server-side executor जोड़ा। यह Supabase Auth से bearer session verify करता है और DB के is_srk_admin() से Main Admin membership जाँचता है; client-supplied role पर भरोसा नहीं करता।
- Exact refund amount केवल srk_admin_prepare_razorpay_refund RPC से आता है। Browser को Razorpay secret या service-role key नहीं मिलती।
- Razorpay POST /v1/payments/{payment_id}/refund को X-Refund-Idempotency और उसी stable receipt key के साथ call किया जाता है। Retry में वही payment, amount, notes और key पुनः उपयोग होते हैं; अलग नया refund record नहीं बनता।
- Provider response में refund ID, payment ID, exact paise amount, INR currency और status match होने के बाद service-role-only reconciliation RPC call होता है। Provider timeout/ambiguous response को Failed mark नहीं किया जाता और payout hold release नहीं होता; retry/manual reconciliation के लिए सुरक्षित रखा जाता है। Provider 409 को in-progress माना जाता है।
- Netlify function wrapper और /api/razorpay-refund route जोड़ा।
- Admin Portal में Main Admin-only Refund card, reason field, safe retry control और Paid Razorpay booking rows में shortcut button जोड़ा। Existing Staff role UI gating इस card को Support Staff से छिपाती है; database Main Admin check अंतिम सुरक्षा है।
- Node built-in test suite जोड़ी: Main Admin gate, stable idempotency/reconciliation और ambiguous timeout safety सहित 4 test cases; npm run test:refund command उपलब्ध। JS harness में 4/4 mocked handler tests PASS (Main Admin gate, stable idempotency/reconciliation, ambiguous timeout सहित); Node CLI का वास्तविक node --test execution अभी नहीं हुआ।
- Syntax checks: Admin inline JS, refund executor JS, Netlify wrapper और test file — PASS।
- Source commits: executor 215907306e0f4ff42cec24f0d341905578248fda; Netlify wrapper ace4ba892024e9627242d54e7d25bc12ae1e6a2f; route 5f98d786a149fd84b73a97509b83dcb8ceec4371; Admin UI 99782cc7578c9fd5afb77dec7767e3015d9e2db6; tests 860fdd2e733e1adca94d4ad805157e13c8687cb9; npm test command 2329bf7e6ef2e948435653f2faa35f48f179eda2; reconciled terminal-status UI fix d48b5cd5ff073c279b7c2ae6c636863594972dc5.
- सीमाएँ: Node test suite अभी run नहीं हुई; PostgreSQL/pgTAP, Netlify runtime, Razorpay Test Mode, duplicate webhook, provider timeout recovery और complete end-to-end refund अभी pending हैं। कोई migration apply, deploy, real refund/payment/payout या Production change नहीं हुआ।

### Razorpay Webhook durable inbox + duplicate/retry recovery (14 नवम्बर 2026)
- नई source migration `20261114410000_razorpay_webhook_event_inbox.sql`: provider event inbox table, event ID primary key और signed raw-payload SHA-256 unique constraint। Payload hash uniqueness यह भी रोकती है कि वही signed body बदले हुए `x-razorpay-event-id` header के साथ दोबारा process हो।
- Inbox पर RLS enabled; `public`, `anon`, `authenticated` से direct table access revoke। Claim/complete दोनों SECURITY DEFINER RPCs empty search_path के साथ हैं और केवल service_role execute कर सकता है।
- Atomic claim में 2-minute processing lease, attempt counter और fresh claim-token fencing है। Concurrent duplicate को 503 retry response मिलता है; processed/ignored duplicate को 200 acknowledgement; expired/retryable claim canonical event row/token से दोबारा चल सकता है। पुराना worker stale claim token से नए worker का परिणाम overwrite नहीं कर सकता।
- `razorpay-webhook.js` raw-body HMAC verify करने के बाद ही event claim करता है। Provider event ID उपलब्ध हो तो use करता है; header absent/invalid/too long हो तो deterministic SHA-256 event ID fallback है। Transient failure पर inbox row retryable mark कर 500 देता है; final business mismatch/unsupported event को ignored mark करता है।
- Payment-captured और refund events दोनों durable inbox से गुजरते हैं। Refund state reconciliation की existing terminal-state/id-binding protections कायम हैं।
- Webhook unit-test source: 5 cases — invalid signature, claim+ignored completion, processed duplicate acknowledgement, active lease retry, changed header के साथ same signed-body replay। Mocked JS harness में 5/5 PASS। Refund executor suite के 4/4 mocked tests फिर PASS।
- Syntax checks: webhook, refund executor, दोनों Netlify wrappers, दोनों Node test files और Admin inline JS — PASS। pgTAP test में 15 assertions और plan 15/15 static count match; वास्तविक PostgreSQL/pgTAP runtime अभी नहीं चला।
- Razorpay refund executor अब receipt/idempotency key length 10–40 characters validate करता है (इस workflow का stored UUID-derived key 32 hex characters है)।
- सीमाएँ: migration केवल Feature Branch source है; Supabase project पर apply नहीं हुई। Razorpay Test Mode, actual Netlify runtime, real provider webhook delivery/replay, Node CLI `node --test`, PostgreSQL/pgTAP और end-to-end refund recovery अभी बाकी। कोई real payment/refund/payout, production deployment, merge या production setting change नहीं किया।
- मुख्य source commits: inbox migration e6c1a7b6bb524c4b46e0fe553df8878fa7cf01b9; role guard 69663214db40c03431990a5600403ac697e16ab9; webhook claim flow 933df9e3707a95f7ca9965f08e03d370939915c8; signed-payload replay protection d348b900bd2ea38492bbc55fafff562925431cda; pgTAP source f14cefd9bbfb521c9ea17fabdcf0a4227869d07c; webhook tests 22319579a3cacf755f986ad3174b35996d059751; test command 1cd53886c49eae7ce4c5c760ce713ce237998c88; canonical lease retry b565a99102a2f57047931d0f9095c5830fda5d04; webhook canonical completion b283527ddc5a7f35c24d49c510ede0b51759c65c; replay lease assertion b0a37ec25e83a4630dc109bee82f240d117a634a; final metadata validation a0c6cd3873fd1bffa7fe467f74b716070d7f6e26; Razorpay receipt length guard 1fdc7617733991b6ed4016689bb6dff36911a0b9।

### Refund completion के बाद Electrician payout accounting fix (14 नवम्बर 2026)
- Accounting review में एक वास्तविक source-level gap मिला: Razorpay refund preparation unpaid payout को `blocked` करता था, लेकिन successful full refund पर booking trigger केवल `pending` payout को `refunded` करता था। इसलिए refund पूरा होने के बाद refund-owned payout hold अनावश्यक रूप से blocked रह सकता था।
- `srk_create_electrician_payable()` में सुधार: booking `payment_status='refunded'` होने पर pending payout को refunded mark करता है; blocked payout को केवल तभी refunded करता है जब उसका note ठीक `Razorpay refund pending` या `Manual refund processed` हो। Unrelated Admin block और already-paid payout untouched रहते हैं। Final refunded payout note clear होता है।
- इससे Razorpay processed reconciliation और manual refund दोनों paths refund-owned hold को साफ़-साफ़ terminal `refunded` payout state में ले जाते हैं; failed Razorpay refund path पहले की तरह previous payout state/note restore करता है।
- Database static pgTAP source plan 28/28 assertions match: refund-owned blocked payout closure, unrelated Admin block preservation के source guards सहित। यह source inspection/count है; PostgreSQL/pgTAP runtime अभी execute नहीं हुआ।
- Commits: payout trigger fix `d219c740286e7eef974992c245222b1f5984730a`; test `4e0f4671b6c1f1abeaf40a734b6296a9d00bf548`।
- अभी भी source-only: कोई migration apply नहीं, कोई real/manual refund या payout नहीं, कोई production change/deploy/merge नहीं।

### Payout reconciliation test coverage और Supabase JWT role hardening (14 नवम्बर 2026)
- Electrician payout के लिए dedicated pgTAP source test जोड़ा: `supabase/tests/database/electrician_payout_reconciliation.test.sql` — 25 assertions। इसमें Main Admin-only settlement, UTR/method validation, booking→payout lock order, immutable labour bill, commission/material separation, carry-forward fee reconciliation, refund-owned payout hold closure, unrelated Admin block preservation और already-paid payout protection के source guards शामिल हैं।
- Cancellation/refund accounting pgTAP test अब 31 assertions है। इसमें तीन service-only RPCs के लिए signed JWT role claim validation भी assert किया गया है।
- Supabase guidance के अनुरूप नए accounting migrations में deprecated `auth.role()` checks हटाकर `coalesce(auth.jwt()->>'role','')='service_role'` guard किया। PR की सभी migration files में `auth.role()` का source scan दोबारा किया; कोई शेष match नहीं मिला।
- Static assertion counts: payout reconciliation 25/25; cancellation/refund accounting 31/31। ये SQL source/plan checks हैं, pgTAP/PostgreSQL runtime results नहीं।
- Commits: payout test `ec6bc3b35c977592e1d7e8ade5df8ab38621f5aa`; lock assertion correction `e8c4d906aceaba9f3f990be6d1aa2c35f5b998bc`; service JWT guard `504c90e09de1aaab0ef05bdf5279691282f1f0b3` और `c125a7d93570be28ceea39d571b0faca5fee78a6`; refund role tests `b82ec8b3dd6453a22cd36dda2574a5db11673b13`।
- कोई migration apply नहीं की गई; कोई live payment/refund/payout, deploy, production change या merge नहीं हुआ।

### Admin payout status UI polish (14 नवम्बर 2026)
- Admin payout table में pending/paid/blocked/refunded के लिए स्पष्ट Hindi labels जोड़े और blocked payout का सुरक्षित, escaped reason/note दिखाया। कोई payout action या payment behavior नहीं बदला।
- Admin inline JavaScript syntax parse check: 1/1 inline script PASS।
- Current static test source counts: payout 25/25, cancellation/refund 31/31, webhook inbox 15/15। PostgreSQL/pgTAP runtime और वास्तविक Razorpay/Netlify tests अभी शेष हैं।
- Commit: `0a2d36c1cc59e64d9247adab934e7390cbfd5ba8`।

### Admin cancellation decision lock-order hardening (14 नवम्बर 2026)
- Cancellation review में Admin decision RPC का lock order Request → Booking था, जबकि customer cancellation request पहले Booking row lock करती है। इसे एक समान Booking → Request क्रम में बदला।
- Admin RPC अब पहले request का booking ID बिना row lock पढ़ता है, Booking row को `FOR UPDATE` lock करता है, फिर Cancellation Request को `FOR UPDATE` lock करके booking relationship और pending status दोबारा validate करता है। इससे lock inversion/deadlock का जोखिम घटता है और stale/changed relationship पर fail-closed व्यवहार रहता है।
- `cancellation_fee_refund_reversal.test.sql` में Admin cancellation lock order regression assertion जोड़ा; pgTAP plan/assertion source count **32/32** match। यह static source verification है, PostgreSQL compile या pgTAP runtime execution नहीं।
- Commits: migration `823355c06a85aad224014e84cb6a1ca32c17df23`, final booking-ID revalidation `59b4eba912d61bb4f6e702415801d08e839d50e1`, test `9bc85aa40f71b524a16395715b746bdde081fcfb`।
- कोई migration apply, live data change, payment/refund/payout, deployment या PR merge नहीं हुआ।

### Cancellation lock-order follow-through — later migration override fixed (14 नवम्बर 2026)
- Follow-up audit में पता चला कि बाद की accounting migration `20261114280000_cancellation_fee_carry_forward_and_accounting.sql` उसी `srk_admin_decide_booking_cancellation` RPC को फिर से define कर रही थी और पुराने Request → Booking lock order को वापस ला रही थी। केवल पहले वाली migration सुधारना पर्याप्त नहीं था।
- Accounting migration की अंतिम/effective RPC definition भी Booking → Request lock order पर लाई गई: पहले booking ID पढ़ना, Booking row `FOR UPDATE`, फिर Request row `FOR UPDATE`, booking ID revalidation और pending-status check। Customer request path के साथ अब दोनों definitions का क्रम एक जैसा है।
- Regression test अब final effective RPC definition में `v_booking_id` lock order assert करता है। Cancellation/refund pgTAP source test plan/assertion count **32/32** match; source-level checks में दोनों migrations और अंतिम override क्रम सही पाया गया।
- Commits: final accounting migration fix `910b10182f2c58d91b730fa2497152d11525f529`; regression test `1365294fe53a6e6f3400464aeec0f7bd0703da46`।
- यह static/source verification है; PostgreSQL compile, pgTAP runtime या concurrent transaction test नहीं चला। कोई migration apply, production change, deploy, real cancellation/payment/refund या PR merge नहीं हुआ।

### Cancellation fee allocation source-booking reference fix (14 नवम्बर 2026)
- Accounting/refund source review में schema gap मिला: receipt, customer fee-item listing, online/cash settlement और full-refund reversal `srk_booking_cancellation_fee_items.source_booking_id` पढ़ रहे थे, लेकिन allocation table में यह column परिभाषित नहीं था। इससे संबंधित SQL functions runtime पर fail हो सकते थे।
- Accounting migration अब column जोड़ती है, पहले से मौजूद allocations को debt table के `source_booking_id` से backfill करती है और फिर `NOT NULL` लागू करती है। Booking creation reservation trigger debt से source booking पढ़कर हर allocation में persist करता है।
- Regression test में schema + reservation-trigger assertion जोड़ा गया। Cancellation/refund pgTAP source test plan/assertion count **33/33** match; source checks में receipt/refund references के लिए column उपलब्ध है और allocation insert इसे भरता है।
- Commits: migration `5f36545e197361194a2deff0443acbe734387672`; test `4f0483511f1e204c56513d2d81e115189375ca25`।
- केवल feature-branch source/static verification। PostgreSQL/pgTAP runtime अभी नहीं चला; कोई migration apply, production change, payment/refund या deploy नहीं हुआ।

### Razorpay refund caller branch-source parity recheck (14 नवम्बर 2026)
- पुराने tracker note में refund provider executor को “missing/unlocated” कहा गया था। Current Feature Branch को दोबारा fetch करके यह wording supersede की जाती है: `razorpay-refund.js` मौजूद है और `netlify/functions/razorpay-refund.js` wrapper भी मौजूद है; `razorpay-webhook.js` तथा उसका Netlify wrapper भी मौजूद हैं।
- Refund executor Main Admin JWT को Supabase Auth से verify करता है, `is_srk_admin` से membership जांचता है, DB prepare RPC से amount/payment record लेता है, Razorpay response के refund ID/payment ID/amount/currency/status को match करता है और service reconciliation RPC call करता है। Ambiguous network outcome पर वही idempotency key/body retry रखता है; कोई वास्तविक provider request इस audit में नहीं भेजी गई।
- यह source-level caller presence और control-flow review है, live Netlify deployment/runtime या Razorpay Test Mode verification नहीं। Production function deployment parity अभी verify नहीं है।
- इसी pass में cancellation/refund accounting source का source-booking allocation fix भी rechecked: source column/backfill/NOT NULL, reservation trigger assignment, refund reversal reference और pgTAP source assertion सभी मौजूद; test plan/assertions **33/33**।
- Supabase trigger documentation review किया गया। Supabase changelog markdown endpoint इस pass में fetch नहीं हो सका; इस code review में कोई platform feature/API migration नहीं की गई।
- कोई Production SQL, migration apply, deploy, payment/refund, PR merge या mobile QA नहीं हुआ।

### Customer Refund Request RPC — Production/Feature Branch parity audit (14 नवम्बर 2026)
- Primary Production project `gnqhoaqatmoiwwhgzkgm` पर read-only catalog inspection में `srk_customer_create_booking_refund_request(uuid,text)` मौजूद मिला। इसकी SECURITY DEFINER function में `search_path='' `, `auth.uid()` ownership check, verified-paid booking check, Booking `FOR UPDATE`, existing Razorpay/manual refund duplicate checks, per-booking request lock, rejected request retry और captured `amount_paid` snapshot मौजूद हैं। Routine grants में `authenticated` EXECUTE मिला; `anon` grant नहीं दिखा।
- Production में customer history RPC का वास्तविक नाम `srk_customer_list_booking_refund_requests()` है; यह `auth.uid()` के customer-owned rows ही लौटाता है। इसकी routine grants अलग से recheck करनी हैं।
- Production refund-request table constraints: booking_id unique, refund_record_id unique, booking/customer/decision/refund foreign keys RESTRICT, amount > 0 और <= 10,000,000, reason 20–1000 chars, admin_note <= 2000 chars, तथा status allow-list। यह Production catalog read-only evidence है।
- Feature Branch `booking.html` create RPC `srk_customer_create_booking_refund_request` call करती है और history के लिए `srk_customer_list_my_booking_refund_requests()` call करती है। Current PR #8 changed-file inventory में refund-request RPC की कोई नई migration नहीं है; exact history function नाम के लिए repository search में भी definition नहीं मिली। पहले tracker में बताई गई `20261113235900_harden_customer_cancellation_and_safe_refund_history.sql` path वर्तमान Feature Branch तथा repository default branch पर fetch नहीं हुई। इसलिए customer refund request/history का reproducible migration-chain parity **अभी सिद्ध नहीं**, भले Production RPC मौजूद हो।
- महत्वपूर्ण naming mismatch: Production `srk_customer_list_booking_refund_requests()` बनाम Feature UI `srk_customer_list_my_booking_refund_requests()`। केवल नाम बदलकर Production function copy नहीं करनी; migration में exact UI contract, ownership, grants, retry semantics और status mapping को सुरक्षित तरीके से align करना होगा।
- कोई Production data/schema परिवर्तन नहीं किया। इस pass में केवल SELECT catalog introspection हुआ; कोई refund request/payment/refund trigger नहीं किया।
- अगला implementation focus: Feature Branch migration history में customer create/list RPCs की canonical definitions जोड़ना, UI/DB names align करना, pgTAP ownership/duplicate/rejected-retry/grant tests जोड़ना, फिर Admin request inbox/decision UI और RPC integration review। Supabase CLI उपलब्ध न होने के कारण इस pass में migration file generate/commit नहीं की गई; migration filename को हाथ से invent नहीं किया।


### Customer/Admin Refund RPC parity — follow-up audit (14 नवम्बर 2026)
- Primary Production project पर read-only catalog recheck में चार RPCs मिले: `srk_customer_create_booking_refund_request(uuid,text)`, `srk_customer_list_booking_refund_requests()`, `srk_admin_list_booking_refund_requests(integer)` और `srk_admin_decide_booking_refund_request(uuid,text,text)`। चारों `SECURITY DEFINER`, `search_path=''` और ACL में केवल `postgres`, `authenticated`, `service_role` हैं; `PUBLIC` और `anon` को EXECUTE grant नहीं है। यह Production catalog evidence है, branch migration parity नहीं।
- Customer create RPC ownership (`auth.uid()`), verified-paid/payment timestamp, booking row lock, duplicate Razorpay/manual refund guards, unique booking request, rejected request retry और paid amount snapshot लागू करता है। Customer history RPC केवल `customer_user_id=auth.uid()` rows लौटाता है।
- Production Admin list RPC Main Admin authorization के बाद सीमित (1–300) queue लौटाता है; इसमें customer phone/payment context शामिल है, इसलिए इसे केवल Main Admin surface पर रखना है। Admin decision RPC row lock, Main Admin authorization और `in_review/approved/rejected` transitions लागू करता है; `processing/unknown/processed` terminal workflow पर decision रोकता है और rejected request को पहले `in_review` में reopen करना अनिवार्य है।
- Production function ACL query में ऊपर के चारों RPCs के grants अलग से जाँचे गए; `PUBLIC` / `anon` grant अनुपस्थित। Production table constraints में `booking_id` और `refund_record_id` unique, amount/reason/admin-note bounds और status allow-list मिले।
- Feature Branch पर `booking.html` अभी history के लिए `srk_customer_list_my_booking_refund_requests()` call करती है, जबकि Production canonical RPC `srk_customer_list_booking_refund_requests()` है। Feature Branch में `20261113235900_harden_customer_cancellation_and_safe_refund_history.sql` fetch नहीं हुई; `20261114110000_admin_refund_review_queue_and_decisions.sql` और उसका pgTAP test भी approved feature branch ref पर मौजूद नहीं मिले। इसलिए पुराने tracker में Admin refund queue migration/UI/test मौजूद होने का वर्णन **इस current branch snapshot के लिए सही नहीं माना जाए**; उस note को stale/unverified समझें।
- Current branch `admin.html` में केवल Razorpay provider full-refund action panel मिला; customer refund-request inbox/decision UI नहीं मिला। Production RPC मौजूद होने से Feature Branch migration chain अपने-आप सुरक्षित/पुनरुत्पाद्य नहीं बनती।
- Supabase CLI check: इस execution environment में `supabase` executable उपलब्ध नहीं (`supabase: command not found`)। Skill के अनुसार नई migration का नाम `supabase migration new <name>` से generate होना चाहिए; इसलिए filename हाथ से नहीं बनाया गया और कोई migration source file commit नहीं की गई। अगला सुरक्षित कदम CLI-enabled repository workspace उपलब्ध होने पर canonical customer history name, create/list migration और pgTAP tests बनाना; उसके बाद Main Admin-only inbox/decision UI को उसी branch contract से जोड़ना है।
- यह केवल read-only Production catalog inspection और Feature Branch source inspection है। कोई Production write, migration apply, payment/refund, deploy, merge, staff invitation या mobile QA नहीं हुआ।


### Customer Refund History RPC नाम alignment — 14 नवम्बर 2026
- पिछले read-only Production audit में canonical history RPC `srk_customer_list_booking_refund_requests()` मिला था, जबकि Customer `booking.html` दो जगह `srk_customer_list_my_booking_refund_requests()` call कर रही थी।
- दोनों UI call sites को Production canonical नाम `srk_customer_list_booking_refund_requests()` से align किया। Commit: `8f95421b6843a7f6ebdeabb3c0039a9df273c2ff`।
- यह केवल frontend RPC-name correction है। Feature Branch migration chain में create/list RPC definitions अभी भी प्रमाणित नहीं; इसलिए इसे end-to-end fix या runtime verification नहीं माना जाए। SQL migration/pgTAP test अभी नहीं जोड़े गए क्योंकि इस workspace में Supabase CLI नहीं है और skill के अनुसार migration file का नाम CLI से generate होना चाहिए।
- कोई Production change, migration apply, payment/refund, deployment, merge या mobile QA नहीं हुआ।


### Customer/Admin Refund Request अगला implementation gate — workflow और Admin role-gating recheck (14 नवम्बर 2026)
- Supabase skill दोबारा पढ़ी। इस execution container में `supabase` CLI अनुपलब्ध है (`supabase: command not found`) और repository workspace checkout भी उपलब्ध नहीं; इसलिए `supabase migration new <name>` चलाकर नई migration बनाना अभी संभव नहीं। Migration filename हाथ से नहीं बनाया गया।
- Feature Branch का `.github/workflows/supabase-schema-ci.yml` पढ़ा। यह केवल `workflow_dispatch` पर चलता है, लेकिन job condition सख्ती से `refs/heads/feature/platform-fee-cash-online-cycle` मांगती है; वर्तमान approved branch `feat/customer-login-first-dashboard-20261114` है। Workflow में केवल पाँच पुराने payment migrations hard-coded हैं, refund-request migrations नहीं। इसलिए इसे वर्तमान branch के लिए dispatch/उपयोग नहीं किया गया और इसमें कोई बदलाव नहीं किया।
- Current Feature Branch `admin.html` का role-gating source audit: `setAdminPortalMode()` Main Admin-only sections को Support Staff से छिपाता है; `showState()` पहले `is_srk_admin()` जाँचता है, अन्यथा Staff session registration और `support.customer.read` permission verify करता है। अतः मौजूदा Razorpay refund panel Staff UI में render-visible नहीं होना चाहिए। यह केवल frontend visibility control है; सुरक्षा का निर्णायक नियंत्रण backend Main Admin authorization ही रहेगा।
- इसी Admin source में `srk_admin_list_booking_refund_requests` या `srk_admin_decide_booking_refund_request` calls और Customer Refund Request inbox/decision panel नहीं मिला। मौजूदा Razorpay full-refund executor panel customer refund-request queue का विकल्प नहीं है।
- अगला सुरक्षित implementation gate: CLI-enabled approved-branch workspace उपलब्ध कराना या वर्तमान branch के लिए सुरक्षित isolated schema CI workflow को अलग से design/review करना; उसके बाद canonical customer create/list RPC migration + pgTAP, फिर Main Admin-only refund-request inbox/decision RPC/UI। कोई CI workflow dispatch, Production SQL, migration apply, payment/refund, deploy, PR merge या mobile QA नहीं हुआ।


### Refund history और Admin review — historical commit बनाम current branch snapshot का reconciliation (14 नवम्बर 2026)
- Current approved branch पर `supabase/migrations/20261114200000_customer_payment_refund_history_rpc.sql` वास्तव में मौजूद है। इसमें `srk_customer_get_payment_history(integer,integer)` authenticated `auth.uid()` के customer scope में verified payments, refund requests, Razorpay refunds और manual refunds की paginated history देता है; raw provider payload/admin notes शामिल नहीं करता। इसकी paired pgTAP file `supabase/tests/database/customer_payment_refund_history_rpc.test.sql` में plan 10 और 10 `select ok` assertions हैं (10/10 source-count match; execute/runtime नहीं हुआ)। यह migration refund request / Razorpay refund / manual refund tables को create नहीं करती; उन tables के fresh-schema provenance की कमी बनी हुई है।
- पुराने historical commit `ebf898450169fa0a94abc6bb2f3ffa88b348cd66` में Admin refund-review RPC migration वास्तव में add हुई थी, और tracker में Admin UI/CI work के historical commits दर्ज हैं। लेकिन current approved branch snapshot पर `20261114110000_admin_refund_review_queue_and_decisions.sql`, `admin_refund_review_queue.test.sql` नहीं मिलते; current `admin.html` में संबंधित RPC calls / Refund Request Inbox भी नहीं हैं। इसलिए पुरानी “Admin refund review queue — Feature Branch” entry को current branch completion न माना जाए; वह historical work/earlier snapshot का रिकॉर्ड है, current branch parity अभी अनुपस्थित है।
- Current branch Admin panel में केवल Razorpay full-refund executor मौजूद है। Staff role-gating source के अनुसार वह Main Admin-only UI में है; फिर भी future refund-review RPCs में backend Main Admin authorization अनिवार्य रहेगा, frontend hiding पर्याप्त सुरक्षा नहीं।
- अगला क्रम: refund tables की migration provenance और create/list customer RPC contract को पहले reproducible बनाना; फिर Admin review migration + pgTAP + Main Admin-only UI को current branch पर पुनः स्थापित करना; अंत में isolated schema runtime verification। कोई migration apply, workflow dispatch, Production write, provider call, deployment, merge या mobile QA नहीं हुआ।


### Customer payment/refund history RPC — SECURITY DEFINER search_path hardening (14 नवम्बर 2026)
- Source review में `srk_customer_get_payment_history(integer,integer)` SECURITY DEFINER RPC का `search_path` पहले `pg_catalog, public, auth, pg_temp` था। Function body में table references पहले से schema-qualified हैं; इसलिए unnecessary exposed-schema lookup हटाकर `set search_path = ''` किया।
- Migration commit: `7cabaea8ac07cb6b127f3fceb955a293eebdb82b`। Paired pgTAP test में empty `search_path` catalog configuration की regression assertion जोड़ी; plan 10 से 11 हुआ। Test commit: `21c8c8cf758059b96718e508ca27d3d1ac95a1d9`।
- Current branch source re-fetch checks: {"empty_search_path":true,"all_table_refs_qualified":true,"test_search_path_assertion":true,"plan_matches":true}; assertion count 11/11। यह केवल source/static verification है; PostgreSQL/pgTAP runtime नहीं चला।
- Refund request/Razorpay/manual refund base tables की migration provenance अभी भी unresolved है; इस change ने tables या RPC business logic create/modify नहीं किया। कोई Production write, migration apply, payment/refund, deploy, merge या mobile QA नहीं हुआ।


### Refund base-table dependency audit — read-only Production schema vs Feature Branch migrations (14 नवम्बर 2026)
- Current Feature Branch migrations की source scan में `20261114290000_full_refund_cancellation_fee_and_wallet_reversal.sql` तीन refund tables को पहले से मौजूद मानती है: `srk_razorpay_refunds`, `srk_booking_refund_requests`, `srk_manual_refund_entries`; यह migration स्वयं इन तीनों को CREATE नहीं करती। Payment-history RPC भी इन्हीं तीन tables पर निर्भर है। इसलिए fresh-schema provenance gap पुष्ट है।
- Production पर केवल read-only information_schema / pg_catalog SELECT से columns, constraints, indexes और triggers देखे। Table shapes का सार:
  - Request: booking/customer UUID, amount, reason, status, admin note, optional refund-record link/decider, created/updated/processed timestamps.
  - Razorpay: booking, pay_ payment ID, optional rfnd_ provider ID, rupee + integer-paise amount, INR, unique idempotency key, requested/processing/unknown/processed/failed state, provider status, reason, Admin actor, prior payout note, error and timestamps.
  - Manual: booking, manual payment entry FK, amount, external transfer reference, optional note, Admin actor and recorded timestamp.
- Production constraints/indexes में booking-level unique guards तीनों tables पर हैं; Razorpay में unique idempotency/provider refund IDs; manual entry में unique payment-entry ID; Request में unique refund-record link; reason/reference/amount/status/currency/provider-ID checks और FK ON DELETE RESTRICT मौजूद हैं।
- Dependency order महत्वपूर्ण: Request table का refund_record_id FK srk_razorpay_refunds(id) पर है; इसलिए fresh migration में Razorpay table पहले, फिर Request table बनानी होगी। Manual table का payment_entry_id FK srk_manual_payment_entries(id) पर है; उस table की Feature Branch provenance/column compatibility verify किए बिना manual refund table बनाना सुरक्षित नहीं।
- Production triggers: Manual refund entries पर srk_capture_admin_audit_event(); Razorpay refunds पर srk_capture_razorpay_refund_audit_event()। इन trigger functions और dependent audit tables/functions की Feature Branch provenance भी base-table migration से पहले जाँचना होगा। Request table पर अलग trigger इस catalog query में नहीं मिला।
- महत्वपूर्ण model caveat: Production schema में amount numeric और Razorpay amount_paise bigint दोनों हैं; इसे सीधे copy नहीं करेंगे। New booking contract में immutable labour-only bill snapshot integer paise है; refund amount exact captured online amount और billable labour cap से reconcile होगा, materials स्वतः शामिल नहीं होंगे। Legacy Production unique-per-booking constraint को भी बिना partial-refund policy approval के blindly adopt नहीं किया जाएगा।
- इस चरण में कोई DDL/migration file नहीं बनाई: Supabase CLI/workspace अभी उपलब्ध नहीं और skill के अनुसार migration filename supabase migration new से बनना चाहिए। कोई Production write, migration apply, provider/payment/refund, deployment, merge या mobile QA नहीं हुआ।
- अगला gate: Feature Branch पर srk_manual_payment_entries, audit-event table/trigger functions, service_bookings और immutable labour bill exact definitions/constraints verify करना; फिर CLI-enabled approved-branch workspace में table dependency + new labour-paise contract वाली एक coherent migration और matching pgTAP तैयार करना।


### Refund dependency audit — Manual Payment, Labour Bill और Audit chain (14 नवम्बर 2026)
- Feature Branch की recursive migration tree और relevant SQL source scan में `srk_manual_payment_entries`, `srk_booking_labour_bills`, `srk_admin_audit_events` की CREATE TABLE provenance नहीं मिली। Refund migration `20261114290000` इन objects को पहले से मौजूद मानकर `%ROWTYPE`, SELECT/INSERT और audit triggers/functions इस्तेमाल करती है। `COMPLETE_DATABASE_SETUP.sql` में भी इन SRK-specific tables की CREATE definition नहीं मिली। इसलिए केवल refund तीन tables नहीं, बल्कि उनकी core dependencies भी current migration chain में reproducibly स्थापित नहीं हैं।
- Feature Branch accounting migration `20261114280000` manual payment insert में `booking_id,payment_method,amount,payment_reference,note,recorded_by` columns use करती है; refund migration `20261114290000` उसी table से booking/payment record और amount पढ़ती है।
- Production पर read-only catalog SELECT में `srk_manual_payment_entries` का shape मिला: UUID id, booking FK, payment_method, numeric amount, payment_reference, optional note, recorded_by, recorded_at; unique booking; payment method allow-list cash/upi/bank_transfer; amount/reference/note checks; FK to service_bookings/auth.users with RESTRICT. यह Production evidence है, Feature Branch migration provenance नहीं।
- `srk_booking_labour_bills` नाम से कोई matching row `information_schema.columns` query में Production result में नहीं लौटी, जबकि current Feature Branch refund/payout/receipt functions इसे reference करती हैं। यह schema-parity blocker है: Production catalog और Feature Branch code को एक ही snapshot मानकर आगे नहीं बढ़ सकते। अगला step इस table की existence और exact schema को project catalog से अलग से resolve करना है; refund code को अभी runtime-ready नहीं मानना।
- Production `srk_admin_audit_events` table मौजूद है; fields में entity/action/actor, changed_fields, before_data/after_data और created_at हैं। Production audit trigger functions `srk_capture_admin_audit_event()` और `srk_capture_razorpay_refund_audit_event()` SECURITY DEFINER हैं और अभी `search_path=pg_catalog, public, auth, pg_temp` रखते हैं; दोनों audit table में insert करते हैं। Feature Branch migrations में इन trigger functions और audit table की CREATE provenance नहीं मिली। इन्हें blind copy नहीं करेंगे; search_path hardening और audit payload privacy/least-privilege का अलग review जरूरी है।
- `service_bookings` Production catalog में old quote/amount_paid columns और newer timer/payment columns साथ दिखे; इससे स्पष्ट है कि इस read-only Production snapshot को current Feature Branch की canonical schema definition नहीं माना जा सकता। `srk_electrician_payouts` की columns/constraints भी catalog में मौजूद हैं, लेकिन refund migration chain में उनकी base CREATE provenance अलग से verify होनी है।
- कोई migration/DDL नहीं बनाई या apply नहीं की। Supabase CLI/workspace अभी अनुपलब्ध; skill requirement के अनुसार migration filename CLI से generate किए बिना हाथ से file नहीं बनाई। कोई Production write, payment/refund, deployment, merge या mobile QA नहीं हुआ।
- अगला gate: Production में `to_regclass('public.srk_booking_labour_bills')`, relation/column catalog और branch में सभी referenced core tables (`srk_electrician_payouts`, manual payments, labour bills, audit events) की authoritative migration provenance अलग-अलग verify करना; फिर missing dependency chain को coherent, paise-based fresh-schema migrations में restore करना।


### Core schema provenance — corrective verification (14 नवम्बर 2026)
- पिछली tracker entry में labour-bill migration provenance को अधूरा बताया गया था। अब exact Feature Branch migration verify की: `20261114240000_server_authoritative_customer_approved_work_timer.sql` में `public.srk_booking_labour_bills` की वास्तविक `CREATE TABLE` definition मौजूद है (booking_id PK/FK, customer/electrician ownership FKs, category/tier/rate snapshot, rate8h_paise, elapsed_seconds, billable_minutes, labour_amount_paise और labour_amount consistency check); RLS enabled और browser roles के direct grants revoked हैं। यह Feature Branch में source-level provenance है।
- उसी table की Production existence अलग से `to_regclass('public.srk_booking_labour_bills')` से जाँची: `NULL` — Production project में यह relation अभी मौजूद नहीं है। इसलिए Feature Branch migration Production में apply नहीं हुई/या production schema drift है; current refund RPC का `srk_booking_labour_bills` reference Production में runtime failure risk है। कोई apply नहीं किया।
- Feature Branch की पूरी recursive `supabase/migrations/` सूची और GitHub code search में `CREATE TABLE` definition नहीं मिली: `srk_manual_payment_entries`, `srk_electrician_payouts`, `srk_admin_audit_events`। Current branch migrations `20261114280000`, `20261114290000`, `20261114360000` इन relations को assume/reference करती हैं। Production catalog में ये तीन relations मौजूद हैं; manual-payment schema/constraints, payout schema/constraints, audit event schema/trigger registrations read-only introspection से मिले। यह Production schema evidence है, Feature Branch migration provenance नहीं।
- Production `srk_booking_refund_requests`, `srk_razorpay_refunds`, `srk_manual_refund_entries` भी मौजूद हैं; पहले की refund tables dependency concern को current Production state के साथ अलग-अलग reconcile करना होगा। इस बार relation existence query ने confirm किया कि refund request/razorpay/manual refund tables मौजूद हैं, पर इससे Feature Branch fresh database migration chain complete सिद्ध नहीं होती।
- Production trigger catalog में `srk_capture_admin_audit_event()` triggers service_bookings, payouts, manual payments, manual refunds पर registered हैं; `srk_capture_razorpay_refund_audit_event()` Razorpay refund table पर registered है। Audit function definitions Production में SECURITY DEFINER और non-empty search_path (`pg_catalog, public, auth, pg_temp`) के साथ हैं; branch migration provenance absent है।
- निष्कर्ष: Labour bill का branch-side CREATE source मौजूद है, पर Production में table absent; manual-payment/payout/audit base-table CREATE provenance branch में absent है। इसलिए अगला implementation task fresh-schema dependency chain को पुनर्स्थापित करना होगा, लेकिन उससे पहले CLI-enabled branch workspace प्राप्त करना जरूरी है क्योंकि Supabase skill के अनुसार migration file `supabase migration new` से generate करनी है। कोई DDL/migration नहीं बनाई या apply नहीं की; कोई Production write, provider/payment/refund, deploy, merge या mobile QA नहीं।


### Financial/Refund/Audit core schema dependency restoration (14 नवम्बर 2026)
- Supabase CLI v3.1.0 को isolated Vercel sandbox workspace में उपलब्ध कराया; `supabase migration new --help` verify करके migration filename CLI से generate किया: `20261114125844_restore_financial_audit_core_schema.sql`। Supabase CLI v3 changelog (2026-11-04) के अनुसार DB commands local-first हैं और hosted changes के लिए explicit `--remote` तथा confirmation चाहिए; इस workflow में कोई hosted command नहीं चला।
- Migration को `20261114190000_customer_receipt_immutable_labour_amount.sql` और `20261114200000_customer_payment_refund_history_rpc.sql` से पहले रखा गया। इससे receipt RPC के पहले immutable `srk_booking_labour_bills` और payment-history/refund consumers के पहले manual-payment, payout, audit, Razorpay refund, refund-request और manual-refund base relations बनते हैं। बाद का `20261114240000` labour-bill `CREATE TABLE IF NOT EXISTS` definition उसी schema के साथ compatible रखी गई।
- DDL में Production catalog से verified keys/FKs/check constraints, full-refund per-booking uniqueness, provider `pay_`/`rfnd_` ID checks, idempotency uniqueness, INR/paise bounds, payout settlement checks, manual refund source-payment FK, RLS और least-privilege grants शामिल हैं। Payout SELECT केवल Main Admin या उसी electrician profile के `user_id` तक सीमित है; finance/refund/audit/labour snapshots के browser direct grants revoked हैं।
- Generic और Razorpay audit trigger functions को `search_path=''` के साथ पुनर्स्थापित किया; audit JSON केवल allow-listed financial/status fields रखता है। Audit entity-type constraint में `razorpay_refund` जोड़कर Production catalog में मिले mismatch को सुधारा, क्योंकि registered Razorpay refund trigger उसी entity type में audit event insert करता है। Booking/profile/application/manual-payment/manual-refund/payout/Razorpay refund audit triggers install किए।
- pgTAP test `supabase/tests/database/financial_audit_core_schema.test.sql`: plan/assertions **46/46**। Isolated PostgreSQL 18 test database पर migration successfully execute हुई; उसी migration को दोबारा चलाकर idempotency भी verify की; pgTAP run में कोई `not ok` नहीं और plan 46/46 matched। यह isolated DB test है, full Supabase local stack या Production runtime test नहीं।
- Fresh-database सीमा अभी शेष: Feature Branch migrations में base `service_bookings`, `electrician_profiles`, `electrician_applications`, `srk_admin_users` और `is_srk_admin()` की original CREATE provenance नहीं मिली; पहले की migrations भी इन्हें पहले से मौजूद मानती हैं। इस migration ने उन unrelated foundational objects को fabricate नहीं किया; वर्तमान core schema migration इन pre-existing application baseline dependencies पर निर्भर है। Complete empty-database replay अभी certify नहीं है।
- Production में `srk_booking_labour_bills` अभी भी absent होने की prior read-only finding कायम है। कोई migration Production में apply नहीं की, कोई Production write/payment/refund/provider call नहीं, कोई deploy/merge/mobile QA नहीं।


### Main Admin identity helper hardening + final core-schema regression (14 नवम्बर 2026)
- Production catalog में `public.is_srk_admin()` SECURITY DEFINER मिला; ACL केवल `authenticated` और `service_role` को EXECUTE देता है, लेकिन `search_path=pg_catalog, public, auth, pg_temp` था। Core-schema migration अब उसी helper का `search_path=''` करता है, `PUBLIC/anon` EXECUTE revoke करता है और `authenticated/service_role` grants स्पष्ट रखता है। Existing `srk_admin_users` membership table में केवल `user_id,created_at` है; Staff identity को इसमें कभी नहीं रखा जाएगा।
- Core schema pgTAP test में helper की SECURITY DEFINER, empty search_path और ACL assertions जोड़ीं। अंतिम plan/assertions **49/49**। Isolated PostgreSQL 18 test database पर migration दो बार execute हुई और दूसरे execution के बाद भी सभी 49 assertions pass; no `not ok` / plan mismatch।
- Migration/test files GitHub Feature Branch पर update किए। यह source-level/isolated PostgreSQL verification है؛ full Supabase migration replay, project-local stack, live auth/RLS runtime या Production verification नहीं। `service_bookings`, `electrician_profiles`, `electrician_applications`, `srk_admin_users` तथा `is_srk_admin()` की foundational CREATE provenance अभी भी repository migrations में अनुपस्थित है; ये पहले से मौजूद baseline objects के रूप में assume होते हैं।


### Refund schema parity: paise reconciliation और history index (14 नवम्बर 2026)
- Historical `feature/platform-fee-cash-online-cycle` branch की `20261114100000_reproducible_labour_only_refund_foundation.sql` को reference के रूप में compare किया। वहाँ Razorpay refund `amount` और integer `amount_paise` के बीच `amount_paise = round(amount*100)::bigint` constraint था और refund-request customer/created index था; current Feature Branch के refund consumers भी इन्हीं exact paise semantics पर निर्भर हैं।
- Read-only Production query में `srk_razorpay_refunds` पर total rows 0 और paise mismatch rows 0 मिले। Core schema migration में `srk_razorpay_refunds_amount_paise_match` constraint जोड़ा (existing relation होने पर safely replace) और `srk_booking_refund_requests(customer_user_id,created_at DESC)` index जोड़ा। Labour bill customer/electrician history indexes भी restore किए।
- pgTAP assertions 49 से बढ़ाकर **51/51** किए: paise amount reconciliation constraint और customer refund history index verify होते हैं। Isolated PostgreSQL 18 पर migration rerun + pgTAP **51/51 PASS**; कोई `not ok` या plan mismatch नहीं।
- Changes केवल approved Feature Branch source में हैं; Production catalog read-only ही रहा। No migration apply, no payment/refund/provider call, no deployment, no merge, no mobile QA।


### Audit entity constraint — latest Production catalog correction (14 नवम्बर 2026)
- नवीनतम read-only `pg_constraint` introspection में Production `srk_admin_audit_events_entity_type_check` ने `razorpay_refund` को पहले से allow-list में शामिल दिखाया। इसलिए पिछली tracker note का कथन कि Production constraint में यह value missing थी, नवीनतम catalog evidence से पुष्ट नहीं होता और उसे superseded माना जाए।
- Feature Branch migration फिर भी वही complete allow-list deterministically enforce करती है, ताकि fresh/source schema में generic audit table definition और Razorpay refund audit trigger एक-दूसरे के अनुरूप रहें। Production में कोई बदलाव नहीं किया।


### Foundational baseline provenance — consolidated setup file located (14 नवम्बर 2026)
- Current Feature Branch के `COMPLETE_DATABASE_SETUP.sql` में पहले से `service_bookings`, `electrician_applications`, `electrician_profiles`, `srk_admin_users` की CREATE definitions और `is_srk_admin()` function मौजूद हैं। `SUPABASE_SCHEMA.sql` में मूल तीन application tables भी हैं। इसलिए पिछली note का “repository में foundational CREATE provenance नहीं मिली” वाला व्यापक अर्थ सुधारें: definitions migration chain में नहीं, लेकिन consolidated SQL Editor bootstrap script में मौजूद हैं।
- Migration chain को इस project की existing setup procedure के अनुरूप `COMPLETE_DATABASE_SETUP.sql` द्वारा बनाए गए base schema के बाद चलना चाहिए। New financial/refund migration इन्हीं base objects पर निर्भर है। Full bootstrap script + पूरी migration chain का end-to-end fresh database replay अभी नहीं किया गया, इसलिए उसे अभी certify नहीं कहेंगे।
- इस baseline script में `is_srk_admin()` का मूल `search_path=public,auth` था; नई migration इसे `search_path=''` में harden करती है और Production के verified authenticated/service_role execute grants बनाए रखती है।


### Refund RPC parity inspection + CLI workspace recovery status (14 नवम्बर 2026)
- Read-only Production function-definition introspection पूरी: `srk_customer_create_booking_refund_request(uuid,text)`, `srk_customer_list_booking_refund_requests()`, `srk_admin_list_booking_refund_requests(integer)`, `srk_admin_decide_booking_refund_request(uuid,text,text)` सभी SECURITY DEFINER + `search_path=''` हैं। Customer create RPC booking ownership, verified paid state, duplicate provider/manual refund checks, rejected-request retry और booking lock लागू करता है। Customer history केवल `customer_user_id=auth.uid()` rows लौटाता है। Admin list/decision Main Admin-only हैं; list में customer contact/payment identifiers हैं, इसलिए Staff UI/RPC exposure नहीं होना चाहिए।
- Production RPCs को copy/paste नहीं किया जाएगा: current Feature Branch migration chain में इन RPC definitions की missing provenance पहले resolve करनी है; current refund model full-refund-only और partial refunds fail-closed है। Request amount / refund amount को labour-only immutable bill + captured amount से reconcile करना होगा; materials charge को बिना explicit policy के refund calculation में include/exclude नहीं मानेंगे।
- Previous Vercel sandbox session `sandbox_stopped` (HTTP 410) हो गया। Replacement CLI workspace create attempt भी Vercel API `400 bad_request` पर रुका। इसलिए इस turn में `supabase migration new` या full migration/pgTAP rerun नहीं हो सका; Supabase skill के नियम के अनुसार नया migration filename हाथ से नहीं बनाया गया और GitHub API से नया migration file नहीं बनाया।
- Latest verified source: core schema migration SHA `bdfdfcc01366a9d4a298b2107c53f1525b326bf9`; pgTAP test SHA `c042decf84ff13c2d6803a0658921e76b3e8e64a`, plan/assertions **51/51**। Earlier isolated PostgreSQL 18 run (before sandbox stopped) migration rerun + 51/51 PASS. Latest test file content re-fetched; this is not a fresh rerun of the latest workspace after shutdown.
- PR #8 latest head `a68757128484aa49afd839e3230c2297544d595b`, open/draft, `mergeable=true`, base `main`. No merge/deploy/Production write/provider payment/refund/staff invite/mobile QA.


### Customer Portal — source/RPC/Storage बनाम read-only Production parity audit (15 नवम्बर 2026)
- `booking.html` की 1,479 lines में 40 direct Supabase DB/RPC/Storage references निकाले। इनमें payment receipt/history, cancellation fee debt/items, refund requests, booking cancellation, work-start/completion approvals, live electrician location, booking work timeline, labour bill, profile, saved addresses, complaint/chat attachments, avatar/support storage शामिल हैं। Source references की सूची और संबंधित migration files cross-check कीं।
- Current approved Feature Branch में Customer Portal की migrations source मौजूद हैं: profile/saved-address/private avatar storage (`20261114201428`), complaint customer-safe projection (`20261114202250`), payment-method change RPC (`20261114202656`), support conversation schema (`20261113220000`), work timer/labour bill (`20261114240000`), append-only work timeline (`20261114260000`), Admin-only cancellation requests (`20261114270000`), cancellation fee receipt/debt/item RPCs (`20261114280000`), payment/refund history (`20261114200000`)। इन migrations से expected RPC names verify किए।
- Read-only Production catalog query (15 Nov) में अपेक्षित Customer RPCs में से कुछ ही मिले: complaint create/list, refund request create/list, work start/completion response, और customer call contacts। कई महत्वपूर्ण RPC अभी **MISSING**: payment history/receipt, payment-method change, saved-address/profile CRUD, cancellation requests/fee debt/items, work timeline/labour bill, live electrician location, complaint message list/send/attachment link आदि। इसका अर्थ source migration मौजूद होने पर भी live runtime parity नहीं है; UI feature को Production-ready नहीं माना जा सकता।
- Read-only Production `storage.buckets` query में `srk-customer-avatars` और `srk-customer-support` दोनों **नहीं मिले**। Storage objects policies में केवल electrician verification bucket policies मिलीं; Customer avatar/support bucket policies नहीं। इसलिए customer avatar upload और support attachment upload/signed URL अभी Production में काम नहीं करेंगे।
- Read-only Production columns query में `srk_customer_profiles`, `srk_customer_saved_addresses`, `srk_booking_complaint_messages`, `srk_booking_complaint_message_attachments`, `srk_booking_cancellation_requests`, `srk_booking_cancellation_fee_items`, `srk_customer_cancellation_fee_debts`, `srk_booking_labour_bills` की कोई column rows नहीं लौटीं। कुछ refund/complaint legacy relations मौजूद हैं, लेकिन इससे नई Customer schema लागू होना सिद्ध नहीं होता।
- निष्कर्ष/गेट: Customer Portal के कई UI controls वर्तमान Production schema पर असफल होंगे। सभी pending migrations की dependency/order/RLS/grants/Storage policy समीक्षा और एक coherent fresh-schema + upgrade-path verification के बाद ही release candidate बनेगा। वर्तमान audit read-only है; कोई Production migration/DDL/write, payment/refund, storage upload, deployment, merge या mobile QA नहीं हुआ।


### Customer SECURITY DEFINER search_path review — two additional hardenings (15 नवम्बर 2026)
- Customer-related migrations में SECURITY DEFINER definitions का static scan किया। Profile/address RPCs, support conversation RPCs, customer-safe complaint projection, payment-method change, cancellation RPCs और payment-history functions में `search_path=''` पहले से मौजूद था। Work-start response की final migration definition भी उसी migration में बाद में `ALTER FUNCTION ... SET search_path=''` से harden होती है।
- दो शेष definitions में अनावश्यक exposed-schema lookup मिला: append-only booking-work-event trigger `srk_reject_booking_work_event_mutation()` और customer payment receipt RPC `srk_customer_get_payment_receipt(uuid)`। दोनों के table/function references schema-qualified होने की समीक्षा के बाद Feature Branch migration definitions का `search_path` empty किया। Commits: `a0cb198557c07aca006e0a66f0ddd6a617e45e84` और `0023df058768739dddbdad5e63f9c7622f5f8f76`।
- Updated migrations का SQL parser check: work-event migration 15 statements और cancellation/accounting migration 55 statements successfully parsed। यह syntax/static parse evidence है; PostgreSQL migration execution/pgTAP runtime नहीं चला।
- Production में कोई migration apply/DDL/write नहीं हुआ। Customer Portal का live RPC/Storage parity blocker कायम है; इसे resolve किए बिना Production-ready नहीं माना जाएगा।


### Customer RPC migration-provenance gap — focused source cross-check (15 नवम्बर 2026)
- Feature Branch के सभी relevant Customer UI call sites को उनकी migration definitions से मिलाया। `srk_customer_update_my_profile` का signature (`p_full_name text, p_preferred_language text, p_avatar_path text`) और booking page call मेल खाते हैं; `srk_customer_save_my_address`, payment history/receipt, cancellation requests/fee items/debts, booking-scoped work timeline, labour bill, support message/thread/attachment RPCs के ज्ञात signatures भी call sites के अनुरूप मिले।
- लेकिन Customer UI में उपयोग होने वाले `srk_customer_create_booking_complaint`, `srk_customer_list_booking_complaints`, `srk_customer_create_booking_refund_request` और `srk_customer_list_booking_refund_requests` की CREATE FUNCTION definitions current Feature Branch की `supabase/migrations/` files या consolidated `COMPLETE_DATABASE_SETUP.sql` / `SUPABASE_SCHEMA.sql` में नहीं मिलीं। इनका Production catalog में पहले मौजूद होना source migration provenance का विकल्प नहीं है।
- इसलिए ये RPCs अभी **existing-Production-baseline dependency / fresh-replay blocker** हैं: नई/खाली Supabase database पर branch migrations अकेले चलाने से Customer complaints और refund-request flows की पूरी RPC contract पुनर्निर्मित होने का प्रमाण नहीं है। इनके exact Production definitions, ACLs, SECURITY DEFINER/search_path, ownership checks, rate limits और idempotency semantics को read-only catalog evidence से capture करके reviewed source migration/bootstrap baseline में restore करना होगा; blind copy नहीं करना है।
- कोई RPC/DDL Production में बदला नहीं गया, कोई migration apply/deploy/merge/payment/refund/storage upload नहीं किया गया। यह source-provenance audit finding है; Runtime और end-to-end verification अभी pending हैं।


### Production complaint RPC privacy/search_path delta — read-only definition comparison (15 नवम्बर 2026)
- Read-only `pg_get_functiondef`/ACL inspection से चार RPC की exact live definitions निकालीं। Refund create/list (`srk_customer_create_booking_refund_request`, `srk_customer_list_booking_refund_requests`) पहले से `SECURITY DEFINER` + `search_path=''` और `authenticated, service_role` EXECUTE ACL पर हैं।
- इसके विपरीत Production `srk_customer_create_booking_complaint` और `srk_customer_list_booking_complaints` अभी `search_path=pg_catalog, public, auth, pg_temp` के साथ `SECURITY DEFINER` हैं। Live list RPC अभी `admin_note` और complaint event के raw `note` भी लौटाता है। यह Feature Branch migration `20261114202250_customer_complaint_customer_safe_projection.sql` के intended hardened state से अलग है: migration create RPC का path empty करती है और list RPC से Admin/event notes हटाकर safe empty projection देती है।
- अतः Production complaint RPC privacy/search_path hardening अभी **pending release blocker** है; source fix मौजूद है, पर Production पर लागू नहीं। Complaint-create live count-based daily limit concurrent calls में race कर सकता है; migration review के समय atomic/race-safe enforcement भी evaluate करना है।
- Live definitions और ACL read-only तरीके से प्राप्त किए; कोई Production change/apply नहीं हुआ। Feature Branch source migration ही approved target है; बिना अलग release approval इसे Production पर लागू नहीं करना है।
