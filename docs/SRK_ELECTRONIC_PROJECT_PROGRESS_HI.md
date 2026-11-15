## 2026-11-15 — GPT-1 SOS emergency UI integration (source-only)
- उपयोगकर्ता के स्पष्ट आदेश के अनुसार Customer App और Electrician App में SOS control जोड़ा गया; तीन स्वीकृत कारण उपलब्ध हैं: ग्राहक को इलेक्ट्रिशियन से खतरा, इलेक्ट्रिशियन को ग्राहक से खतरा, मारपीट/अन्य आपात स्थिति।
- दोनों UI shared `srk_create_sos_alert` RPC को केवल `p_reason` भेजते हैं। Client booking ID, actor/user ID, details या location fields नहीं भेजता। Backend को authenticated session और active booking से actor/booking derive करना होगा; उपलब्ध/consented location का सुरक्षित server-side contract अलग से सत्यापित होना बाकी है।
- UI केवल confirmed success और case_id पर केस दर्ज दिखाता है; backend error/अनिश्चित response पर success नहीं दिखाता। पुलिस को ऐप से स्वतः कॉल/SMS नहीं जाएगा।
- GPT-2 backend RPC, authorization, Admin/Support queue, SMS/Push delivery, acknowledgement और append-only audit अभी बाकी हैं। केवल source changes; Node test/CI, DB, browser/mobile, production, merge और deployment सत्यापित/किए नहीं गए।

## 2026-11-15 — Failed refund webhook regression test

- Added a signed `refund.failed` webhook test verifying that the exact provider refund ID/payment/amount is passed to the server-side reconciliation RPC and that the webhook inbox event is completed only after reconciliation succeeds.
- Test file: `tests/razorpay-webhook-inbox.test.js`; commit `7a0ab305`.
- Static source review only; Node test execution still pending. Provider failure reconciliation remains fail-closed and does not automatically create another refund request.

## 2026-11-15 — Refund webhook / provider response reconciliation audit

- Re-audited `razorpay-refund.js`, `razorpay-webhook.js`, refund preparation/reconciliation RPCs and full-refund cancellation-fee reversal trigger.
- Repaired and consolidated the `srk_admin_prepare_razorpay_refund` function after detecting a malformed payment-ID guard introduced during the approval-gate edit. The function now has the complete anchored `pay_...` validation, NULL-safe paid-state validation, booking row lock, Main Admin approval gate, customer request row lock, immutable labour + settled cancellation-fee reconciliation, stable one-refund-per-booking behavior, payout hold, and request-to-refund-record linkage. Commit: `2b5358bd`.
- Extended `tests/razorpay-webhook-inbox.test.js` with signed `refund.processed` reconciliation and amount-mismatch fail-closed tests. Commit: `4c10468b`.
- Extended approval-gate pgTAP checks to 8 assertions. Commit: `41f11f1b`. Static checks now confirm migration function boundaries, anchored payment ID regex, approval gate located inside the function, NULL-safe payment status, booking lock, no dangling fragment; pgTAP plans/counts: Customer request 17/17, Admin queue 12/12, Approval gate 8/8.
- Source/static verification only. Node tests and pgTAP were not executed in a runtime/database. No Razorpay request, no customer refund, no Production database change, no deployment or merge. Provider unknown/failed states remain fail-closed for manual reconciliation; do not automatically create a new refund record or release payout on an ambiguous provider result.

## 2026-11-15 — Admin approval enforced before customer-requested Razorpay refund

- Hardened `srk_admin_prepare_razorpay_refund(uuid,text)` in `20261114290000_full_refund_cancellation_fee_and_wallet_reversal.sql`: when a customer refund request exists, only `approved`, `processing`, or `unknown` requests may proceed; `requested`, `in_review`, and `rejected` requests are blocked. Existing no-customer-request Admin refund flow remains available for legacy/admin-initiated cases.
- The approved customer request is linked to the prepared Razorpay refund record and moves to `processing`; idempotent retries also attach the same record. Existing reconciliation function moves linked requests to `processed` or `unknown` based on provider result.
- Added `supabase/tests/database/customer_refund_admin_approval_gate.test.sql` with 5 source/schema assertions. Commits: refund preparation guard `3871afb3`, retry-link follow-up `43061f03`, test `a24ea55b`.
- Approval-gate pgTAP test has 5 assertions; execution remains pending. Source/static verification only. No Razorpay API call, no payment/refund, no database migration application, no Production/deployment/merge changes.

## 2026-11-15 — Customer refund submission + Main Admin review queue

- Customer refund RPCs added in `20261115100000_customer_refund_request_contract.sql`; they require authenticated ownership and verified payment, serialize on the booking row, prevent duplicate refund records, permit resubmission only after rejection, and keep Admin notes out of Customer refund history. New categorized bookings require a completed booking, immutable labour bill, fully settled cancellation-fee items and exact captured-payment reconciliation. Eligibility guards use `IS DISTINCT FROM` to reject NULL payment/booking states safely.
- Main Admin refund queue and decision RPCs added in `20261115110000_admin_refund_review_queue_and_decisions.sql`. Queue exposes customer/booking/payment/reconciliation information only to Main Admin. Decision RPC locks the request and enforces `requested → in_review/approved/rejected` and `in_review → approved/rejected`, with a required 10–2000 character audit note and actor attribution. Approval/rejection does not call Razorpay or change payment status.
- Added Main Admin-only Refund Requests panel to `admin.html`; it loads requests, supports review/approve/reject, and provides a shortcut to populate the separate Razorpay full-refund form after approval. Approval is clearly described as not issuing money automatically.
- Commits: customer RPC migration `d309a206` (null-safe follow-up `98fdac5c`); customer pgTAP `70273d29` (null-safe assertion follow-up `64128829`); Admin queue migration `5b676acc`; Admin pgTAP `392d8b77`; Admin UI `1dbf1eda`.
- Re-fetched source files and verified Customer pgTAP plan 17/17 and Admin pgTAP plan 12/12, plus null-safe eligibility, Main Admin authorization, row lock, state transitions, UI queue integration and no payment-provider side effect in the decision RPC. **Static/source verification only; pgTAP, browser and provider integration tests have not run.**
- No database migration applied, no real customer request/approval/refund made, no Razorpay request sent, no Production/deployment/merge change. Mobile QA remains deferred to the consolidated final pass.

## 2026-11-15 — Customer refund request RPC contract added

- Added `supabase/migrations/20261115100000_customer_refund_request_contract.sql` with the exact Customer Portal RPC contracts: `srk_customer_create_booking_refund_request(uuid,text)` and `srk_customer_list_booking_refund_requests()`.
- Refund submission requires an authenticated customer, a booking owned by that customer, a verified positive payment, and a 20–1000 character non-null reason. The booking row is locked before checking/inserting the unique booking refund request, and existing online/manual refund records prevent a duplicate request. Only a rejected request may be resubmitted.
- For categorized bookings, submission now fails closed unless the booking is completed and has an immutable customer-owned labour bill. It computes the request amount in integer paise from final labour plus settled cancellation-fee items, rejects unsettled fee items, and requires exact equality with the verified captured payment. Materials are not added to the labour refund calculation.
- Customer refund history is owner-scoped and intentionally omits private Admin notes. Both RPCs revoke PUBLIC/anon execution and grant only authenticated execution; both SECURITY DEFINER functions use an empty search_path.
- Added `supabase/tests/database/customer_refund_request_contract.test.sql`: 16 planned source/schema assertions, with 16 assertions present (plan match PASS). Re-fetched both new files and verified the core guards and test-plan count.
- Commits: migration `d309a206`; pgTAP test `70273d29`. **Verification is source/static only**; the pgTAP test has not been executed against an isolated database. The migration has NOT been applied to Production or any database. No refund/payment was initiated. Production, deploy, merge and mobile QA remain unchanged.

## 2026-11-15 — Customer RPC contract sweep: refund workflow gate
- Static comparison of Customer RPC calls in the current `booking.html` against the inspected Feature Branch migration definitions found the core profile, saved-address, support, cancellation, work-start/completion, payment-history, receipt, fee-debt, fee-item and live-location RPC names represented in the checked migration set (some older contracts are defined by pre-existing migrations and were not changed here).
- Two refund request calls need a dedicated end-to-end contract check before treating the Customer refund workflow as complete: `booking.html` calls `srk_customer_create_booking_refund_request(p_booking_id,p_reason)` and `srk_customer_list_booking_refund_requests()`. Neither function definition appeared in the 16 current Customer-relevant migration files inspected in this sweep; the previously referenced migration path `20261113235900_harden_customer_cancellation_and_safe_refund_history.sql` could not be fetched from this Feature Branch (404). This is a migration-chain reproducibility gap to resolve, not proof that the RPCs do not exist in every environment.
- Do not enable or represent refund submission/history as verified until the exact Feature Branch function definitions, grants, underlying refund tables/constraints, and reconciliation against immutable final labour bill plus captured payment are verified. Materials must remain excluded from labour refund calculation unless separately eligible under an explicit approved policy.
- No refund RPC or financial logic was created/changed in this sweep; no payment/refund action occurred. This is source-level contract analysis only; runtime testing remains pending. Production, deployment, merge and mobile QA unchanged.

### 2026-11-15 — Avatar profile reference ownership check
- Profile update RPC already checked avatar path prefix, object presence, MIME metadata and size, but did not independently verify Storage owner_id. It now requires the referenced avatar object owner_id to equal auth.uid(), preventing a path-shaped but differently owned object from being attached to the customer profile.
- Expanded avatar object-integrity pgTAP plan from 5 to 6 assertions with an explicit owner-binding guard.
- Feature Branch commits: migration d3c332afe1d21aabb108bb7131fec2906ac09035; test d167987265585ad4fccbc8dab008feb2ad3359b2. Source/static only; PostgreSQL/pgTAP runtime and real Storage checks remain pending. No Production changes, deployment, merge or mobile QA.

### 2026-11-15 — Customer private Storage ownership hardening
- Support attachment linker previously validated the customer/complaint path prefix and message ownership but did not verify that the referenced object actually existed in the private support bucket or was owned by the authenticated customer. It now requires an exact storage.objects row for bucket srk-customer-support, matching object path and owner_id = auth.uid(), before creating the attachment record.
- Customer avatar upload policy now checks both the user-id path prefix and Storage owner_id, matching the ownership boundary already used for avatar reads/deletes.
- Expanded support attachment pgTAP structural plan from 13 to 14 and customer profile/Storage plan from 27 to 28 to guard both ownership checks.
- Feature Branch commits: support migration 4bb11ac14b6f421b844c5ae7c9f803b4d35cfa9f; support test 3f4edfa422a97177918dd0eafaf23dacd2ee002f; avatar migration 824acaad6fc65cf5897deb83561fd156679722ec; avatar test 037d6f0d15dfcc0d5ed70be20a710fece3bb5088.
- Source-level changes only. PostgreSQL/pgTAP runtime and actual Storage upload/link/download tests remain pending; no Production database or Storage policy was changed, no deployment/merge occurred, and mobile QA remains deferred.

### 2026-11-15 — Support attachment metadata NULL validation
- Customer attachment-link RPC review found the same SQL three-valued-logic edge case for MIME type and file size: `NOT IN` / `NOT BETWEEN` do not evaluate TRUE for NULL inputs, so explicit guards are required rather than relying on later table constraints.
- Added explicit `p_mime_type IS NULL` and `p_file_size_bytes IS NULL` rejection in the support attachment-link RPC and two pgTAP structural assertions (plan now 13).
- Feature Branch commits: migration `0fcabaf2fa91071cd6903b982201195126185a25`; test `b3bf509f92772473405e0fbb20d324f36214c2b1`. This is source/static coverage; PostgreSQL runtime and Storage policy tests remain pending.
- No Production database, Storage object, deployment, merge, or mobile test was changed/performed.

### 2026-11-15 — Complaint category validation edge case
- Follow-up review of the customer complaint RPC found SQL three-valued-logic behavior: `p_category NOT IN (...)` evaluates to NULL when the input category is NULL, so the validation IF could fail to reject it explicitly (depending on the table constraint).
- Added an explicit `p_category IS NULL` rejection before the allowlist check and expanded the pgTAP structural plan from 12 to 13 assertions to guard the condition.
- Feature Branch commits: migration `53dea2a66d50054501fa2e817d8c7cd77636d813`; test `cd28261c2faafbfb3ae7f0bef5a396093bf0bef2`. This is source-level/static test coverage only; pgTAP has not been executed against PostgreSQL.
- No Production database, deployment, merge, or mobile test was changed/performed.

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


### Customer complaint rate-limit concurrency hardening (15 नवम्बर 2026)
- Live Production complaint-create RPC की count-then-insert daily limit में concurrent submissions से limit पार होने का race risk पहचाना। Feature Branch migration `20261114202250_customer_complaint_customer_safe_projection.sql` में existing customer ownership/category/description checks और complaint/event inserts बनाए रखते हुए पूरा RPC body अब source में परिभाषित किया; प्रति authenticated customer `pg_advisory_xact_lock(hashtextextended(auth.uid()::text,0))` transaction lock daily count से पहले लेता है, जिससे एक ग्राहक की concurrent submissions क्रमबद्ध होती हैं।
- उसी migration में `search_path=''` और explicit authenticated-only EXECUTE ACL भी हैं। `customer_complaint_customer_safe_projection.test.sql` में pgTAP plan/assertions **10 → 12** किए; दो नए static definition assertions advisory transaction lock और authenticated identity-derived lock key verify करते हैं।
- GitHub Feature Branch commits: migration `6a1058e9`; test `f1e41dc6`. Re-fetch verification: migration में lock + empty search_path मौजूद; test में 12 plan items और 12 assertions हैं। यह अभी source-level verification है—PostgreSQL/pgTAP runtime rerun pending है क्योंकि previous isolated Vercel sandbox stopped; Production function untouched है।


### Admin Refund Recovery visibility — provider और payout evidence (15 नवम्बर 2026)
- Refund reconciliation function के source audit में पुष्टि हुई कि Razorpay timeout/ambiguous response पर provider refund record मौजूद रह सकता है जबकि provider status अभी ज्ञात नहीं; webhook के definitive `failed` event पर refund record `failed`, customer request `unknown` और पहले लगाए गए refund payout hold को original payout note सहित restore किया जाता है। `processed` पर booking को `refunded` किया जाता है और full-refund accounting trigger चलता है। Provider `pending` पर payout hold बना रहता है। ये source behavior हैं, runtime/provider verification नहीं।
- Main Admin refund queue को recovery visibility के लिए विस्तारित किया: अब provider Refund ID, provider status, internal refund-record status, last provider error, electrician payout status और payout note साथ दिखेंगे। Processing/unknown/failed स्थिति पर UI स्पष्ट निर्देश देता है कि पहले Razorpay Dashboard में उसी Refund/Payment ID का प्रमाण मिलाएँ; बिना प्रमाण नया refund/retry न करें और payout manually release न करें। Queue read-only है; कोई recovery action या provider call नहीं जोड़ा।
- Migration `20261115110000_admin_refund_review_queue_and_decisions.sql` में queue RPC को return-contract विस्तार के लिए drop/recreate किया; Main Admin authorization, SECURITY DEFINER empty search_path और authenticated-only grants कायम हैं। pgTAP source assertions **16/16 planned** हैं (provider ID/error, payout state/note और read-only behavior सहित)। Admin UI और migration/test commits: `70abb749`, `cfd905c2`, `6ecc363d` (test-plan correction अलग commit में)।
- यह source-only परिवर्तन है। pgTAP/Node tests इस चरण में execute नहीं हुए; Razorpay Dashboard/API से live status lookup नहीं किया; Production DB, wallet, payout या payment में कोई बदलाव नहीं; no deploy/merge/mobile QA। अगला कदम: provider refund lookup के लिए audited, Main Admin-only recovery workflow की आवश्यकता और provider API read-only verification contract की जाँच; definitive evidence के बिना retry/release नहीं।


### Main Admin read-only Razorpay Refund status verification — Feature Branch (15 नवम्बर 2026)
- नया backend handler `razorpay-refund-status.js`, Netlify wrapper और `/api/razorpay-refund-status` route जोड़े। Endpoint bearer session की Supabase Auth से पुष्टि करता है और `is_srk_admin` RPC से Main Admin membership जाँचता है; फिर exact Booking + internal Refund Record + payment ID मिलान करता है।
- Provider lookup केवल Razorpay GET API से: stored Refund ID होने पर `GET /v1/refunds/:id`; Refund ID न होने पर payment refund collection `GET /v1/payments/:id/refunds?count=100` में internal refund record ID / idempotency receipt से match। Payment ID, amount in paise, INR currency और refund ID/status verify किए बिना कोई status verified नहीं बताया जाता।
- Collection के पहले 100 items में match न मिलने पर endpoint साफ कहता है कि यह “refund नहीं बना” का प्रमाण नहीं; pagination/late visibility जाँचें। हर inconclusive/error/mismatch response में `safe_to_retry:false`। Provider response केवल UI में दिखता है; यह endpoint database refund status, booking payment status, cancellation fee ledger, wallet या payout में कोई बदलाव नहीं करता।
- Admin Refund Queue में “Razorpay की वास्तविक स्थिति जाँचें” read-only button जोड़ा; verified status और ARN/RRN/UTR reference (यदि उपलब्ध) दिखाता है। Netlify route और wrapper जुड़े।
- नया Node test file `tests/razorpay-refund-status.test.js`: 6 cases (missing session, non-Main Admin, exact GET lookup, no-match inconclusive, provider mismatch fail-closed, booking/payment mismatch). Static JavaScript syntax checks PASS: handler, wrapper, test और Admin inline script। **Node tests execute नहीं किए गए**; कोई live Razorpay request नहीं की गई।
- Official Razorpay API docs में refund-by-ID और payment-specific refund-list GET endpoints documented हैं: https://github.com/razorpay/markdown-docs/blob/master/api/refunds.md
- Commits: handler `edaff9e2`, wrapper `cd790ab5`, tests `3100fe1f`, Admin UI `eea86b86`, Netlify route `92d8aebb`.
- Feature Branch only; no Production DB writes, no provider POST/refund, no payout/wallet mutation, no deploy/merge/mobile QA. Next: inspect how a verified provider `processed` result can be finalized through an audited Main Admin recovery path without weakening service-role-only reconciliation or allowing a failed refund to regress automatically.


### Refund reconciliation transaction-boundary audit — recovery blocker found (15 नवम्बर 2026)
- Current Feature Branch migration `20261114290000_full_refund_cancellation_fee_and_wallet_reversal.sql` में `srk_service_reconcile_booking_refund` एक ही PostgreSQL transaction में refund row status update, customer request update और `service_bookings.payment_status='refunded'` update करता है। Booking update पर full-refund cancellation-fee/wallet reversal trigger चलता है। यदि उस trigger में ledger validation/insert fail हो, तो PostgreSQL पूरी RPC transaction rollback कर देगा; इसलिए provider का `processed` परिणाम और Refund ID भी उसी transaction में टिके रहने की गारंटी नहीं है। Webhook retry फिर उसी reconciliation path को दोबारा चलाएगा।
- इस Feature Branch में पिछली tracker entry में नामित `20261114130000_durable_razorpay_refund_provider_reconciliation.sql` path उपलब्ध नहीं मिला; वर्तमान branch के source से अलग durable provider-evidence transaction की पुष्टि नहीं हुई। उस पुराने tracker दावे को deploy-ready प्रमाण न माना जाए; branch source और migration history को फिर से मिलाना होगा।
- `srk_admin_record_manual_refund` Razorpay-linked booking को स्पष्ट रूप से reject करता है; उसे Razorpay recovery shortcut के रूप में इस्तेमाल नहीं किया जा सकता।
- निष्कर्ष: Provider GET lookup जोड़ना केवल सत्यापन है, final accounting recovery नहीं। आगे दो-चरण design चाहिए: (1) Main Admin audit note और exact Razorpay GET evidence को अलग service-role transaction में immutable recovery-audit row में persist करना; (2) उसी evidence ID से अलग locked/idempotent finalization RPC चलाना, जिसमें booking trigger/ledger fail होने पर evidence पहले से सुरक्षित रहे। Failed provider status को processed में बदलने का कोई generic/manual override नहीं होगा; केवल fresh exact provider `processed` evidence के बाद narrowly scoped recovery अनुमति पर विचार होगा। Payout release भी verified provider state और payout reconciliation rules के बिना नहीं होगा।
- यह source audit है; कोई DB migration execute/apply नहीं हुई, Production state नहीं बदली, Razorpay API call नहीं की गई, कोई payout/wallet/payment mutation नहीं। अगला implementation इसी durable two-phase boundary और audit contract पर केंद्रित होगा।


### Durable Razorpay refund recovery evidence — two-phase database source (15 नवम्बर 2026)
- Feature Branch migration `20261115120000_durable_razorpay_refund_recovery_evidence.sql` में private RLS-enabled, append-only `srk_razorpay_refund_recovery_audits` table और immutable UPDATE/DELETE rejection trigger जोड़ा। Evidence में exact internal refund/booking IDs, provider Refund ID, Payment ID, paise amount, INR currency, provider status/time, acquirer reference, SHA-256 payload hash, raw provider JSONB, Main Admin user ID और mandatory 10–2000 character audit note सुरक्षित होते हैं।
- Phase 1 service-role-only RPC `srk_service_record_razorpay_refund_recovery_evidence` internal booking/payment/refund identity, amount/currency, provider JSON fields, provider ID formats और duplicate evidence hash validate करके evidence insert करता है। Same evidence replay होने पर पहले से persisted audit ID लौटती है; hash collision/different provider facts fail closed.
- Phase 2 अलग service-role-only RPC `srk_service_finalize_razorpay_refund_from_recovery_evidence` केवल 15 मिनट के भीतर दर्ज exact provider `processed` evidence स्वीकार करता है; booking → refund → payout lock order रखता है; conflicting Refund ID, mismatched payment/amount/currency, paid payout या unblocked payout पर रोकता है; refund/request status update के बाद booking को refunded करता है ताकि मौजूदा full-refund accounting trigger चले। Trigger failure पर Phase 2 rollback होगा, पर अलग request में पहले commit हुआ Phase 1 immutable evidence बना रहेगा। Repeated completed call idempotent है।
- pgTAP test `durable_razorpay_refund_recovery_evidence.test.sql`: 16 assertions planned for RLS/private table, service-role-only RPC grants, mandatory note, provider identity/amount validation, immutable evidence, processed-only + fresh evidence gate, payout hold and separate finalization boundary.
- Commits: migration `57417ead`; test `85d64eb`; test assertion correction latest follow-up commit (see branch history).
- यह केवल Feature Branch source है। pgTAP/SQL runtime execute नहीं हुआ; migration Production या किसी database पर apply नहीं हुई। Razorpay live GET नहीं किया; API endpoint/UI अभी इस RPC pair से wire नहीं किए गए। No provider POST, no payout/wallet/payment mutation, no deploy/merge/mobile QA.
- Next: wire a Main Admin-only recovery endpoint that verifies Razorpay by GET, persists evidence through Phase 1, then invokes Phase 2 in a separate HTTP/PostgREST request; if Phase 2 fails, return the saved audit ID and keep payout blocked. Add Node tests and an explicit Admin action requiring a fresh audit note.


### Main Admin two-phase Razorpay refund recovery endpoint और UI — Feature Branch (15 नवम्बर 2026)
- नया server endpoint `razorpay-refund-recovery.js`, Netlify wrapper और `/api/razorpay-refund-recovery` route जोड़े। Endpoint पहले Supabase Auth से session user और `is_srk_admin` से Main Admin verify करता है; 10–2000 अक्षर का audit note अनिवार्य है।
- Endpoint internal refund record + booking Payment ID exact-match करता है; Razorpay से केवल GET द्वारा stored Refund ID या payment refund collection में exact provider record fetch करता है; Refund ID, Payment ID, integer paise amount, INR currency और provider status verify करता है। Provider payload का SHA-256 hash बनाकर पूरा JSON evidence, provider timestamp/acquirer reference और verified Main Admin ID Phase 1 RPC में भेजता है।
- Phase 1 RPC call और Phase 2 finalization RPC call अलग-अलग HTTP/PostgREST requests हैं, इसलिए अलग database transactions हैं। Provider status `processed` होने पर ही Phase 2 invoke होता है। Pending/failed status का प्रमाण सुरक्षित होता है पर accounting finalize नहीं होती; failed provider response payout release नहीं करता। यदि Phase 2 accounting trigger fail हो, endpoint 202 + durable Recovery Audit ID लौटाता है, `safe_to_retry:false` रखता है और नया refund नहीं बनाता।
- Main Admin Refund Queue में अलग audit note और “Verified Razorpay Refund Recovery चलाएँ” action जोड़ा। Read-only status button अलग बना रहता है। Pending accounting response पर UI audit ID दिखाता रहता है और request list refresh करके उसे मिटाता नहीं।
- Node test file `tests/razorpay-refund-recovery.test.js`: 6 cases (audit note required before provider call, Main Admin gate, evidence then separate finalization, trigger/finalization failure retains audit ID, pending status does not finalize, provider amount mismatch fail-closed). JavaScript source compile checks PASS: handler, Netlify wrapper, Node tests, Admin inline script. **Node tests execute नहीं हुए**; केवल syntax/static checks।
- Commits: endpoint `ebebdfc0`, wrapper `8a5d84b1`, route `58106097`, tests `bb382b48`, Admin UI `d24205a4` + quote fix `9f62e050` + audit-ID visibility fix `afeee2ef`.
- Feature Branch source only. pgTAP 16 assertions और Node tests runtime में नहीं चले; कोई migration apply नहीं हुई, Production DB untouched, कोई live Razorpay GET/POST नहीं, कोई payment/refund/wallet/payout mutation नहीं, no deploy/merge/mobile QA.
- अगला काम: endpoint और SQL RPC contract की cross-audit; विशेषकर provider payload hash/evidence integrity, database function privileges, booking/refund/payout lock ordering और trigger rollback semantics की जाँच; फिर उपलब्ध runtime environment में Node/pgTAP suite चलाना। UI/endpoint को production deploy या database migration apply नहीं करना।


### Refund recovery cross-audit follow-up — observation freshness (15 नवम्बर 2026)
- Cross-audit में एक idempotency edge case मिला: Razorpay का exact JSON payload दोबारा वही रहने पर केवल payload-hash uniqueness पुराना audit ID लौटा सकती थी; 15-minute freshness guard के कारण अगली सफल GET observation भी stale मानी जा सकती थी।
- Migration को साफ़ 208-line single-definition source के रूप में rewrite किया: एक table, एक Phase 1 RPC, एक Phase 2 RPC; हर network observation का UUID idempotency key है। Same HTTP retry वही audit ID देता है, लेकिन fresh Razorpay GET नया observation UUID बनाकर नया timestamped immutable evidence सुरक्षित कर सकता है।
- Phase 1 RPC signature और service_role grant/revoke को exact 13-argument signature से मिलाया। Audit actor पर auth.users FK जोड़ा और booking payment state का NULL-safe guard किया।
- pgTAP अब 17 planned assertions रखता है और exact RPC signature + observation UUID assertion जाँचता है। Static consistency: migration में table/function definitions प्रत्येक एक बार; SQL dollar-quote pairs balanced; plan 17 = assertions 17; handler/test JavaScript parse PASS.
- Production Supabase schema का read-only catalog check पुष्टि करता है कि payout status constraint में `pending`, `paid`, `blocked`, `refunded` वैध हैं और refund amount `amount_paise` तथा currency `INR` मौजूद हैं। यह catalog-only निरीक्षण है, कोई write नहीं।
- अभी भी SQL/pgTAP/Node runtime execute नहीं हुए; migration किसी DB पर apply नहीं हुई; Razorpay GET/POST, refund, wallet/payout mutation, deploy/merge और mobile QA नहीं हुआ।


- अतिरिक्त replay audit: existing full-refund accounting trigger payout को `refunded` करता है। इसलिए Phase 2 का replay अब completed booking + processed refund पर तभी idempotent success देता है जब मौजूद payout भी `refunded` हो; `paid` payout हमेशा manual reconciliation पर रोकता है। Non-replay path में payout का `blocked` होना अनिवार्य है। pgTAP plan अब 18/18 static assertions है; runtime अभी नहीं चला।


- Trigger integration audit ने एक वास्तविक edge case पकड़ा: मौजूदा `srk_create_electrician_payable` trigger केवल `pending → refunded` करता है, जबकि Razorpay refund preparation payout को `blocked` करता है। इसलिए Phase 2 अब exact locked blocked payout को केवल verified `processed` evidence और booking/accounting trigger की सफलता के बाद `refunded` करता है; update न हो तो पूरा Phase 2 rollback होगा और Phase 1 evidence सुरक्षित रहेगा। pgTAP plan 19/19 static assertions।


- अतिरिक्त actor-authentication hardening: Phase 1 RPC अब supplied audit actor UUID को `srk_admin_users.user_id` के विरुद्ध स्वयं verify करता है; केवल service-role caller होने से arbitrary user को Admin audit actor नहीं बनाया जा सकता। pgTAP plan 20/20 static assertions।


- Cancellation-fee/Wallet ledger source audit: online fee refund में मूल posted credit के विरुद्ध linked debit reversal; cash fee refund में मूल Electrician wallet debit के विरुद्ध credit और linked cancellation-fee debit reversal; debt दोबारा open तथा item reversed होता है। Source में per-original reversal unique index और wallet global idempotency key मौजूद हैं। Recovery pgTAP static plan अब 24 assertions है; runtime execution अभी बाकी।
- Trigger source audit पुष्टि करता है कि यह केवल `service_bookings.payment_status → refunded` पर चलता है और verified full-refund record तथा exact amount match माँगता है। Trigger/ledger integration के live runtime परिणाम उपलब्ध नहीं हैं।


- Commission/Customer receipt/Electrician payable cross-audit: `srk_calculate_booking_commission` कमीशन केवल `service_charge × commission_rate` पर निकालता है; materials अलग रहते हैं। `srk_create_electrician_payable` electrician payable को service + materials − commission बनाता है और verified paid/completed/approved booking पर payout row बनाता है। Admin payout settlement पुनः verified payment, approved quote, assigned electrician और सभी payout amount components का exact मिलान करता है।
- Admin commission report केवल `payment_status='paid'` और completed bookings जोड़ती है; इसलिए refunded bookings वर्तमान totals से बाहर हैं। Wallet summary केवल posted wallet-ledger rows का net balance दिखाती है।
- **अभी का Accounting Integration Gap (काम बाकी):** `srk_wallet_ledger` और `srk_route_transfers` अलग server-side records हैं; commission report और payout table से इनका एक संयुक्त per-booking reconciliation view/RPC नहीं मिला। इस कारण कंपनी commission receivable/received, Route transfer processed/settled और manual electrician payout paid का एक ही authoritative मिलान अभी उपलब्ध नहीं है। इसे implement करने से पहले तय करना होगा कि commission Route split से collect होगा या अलग settlement, और wallet ledger internal-only रहेगा या वास्तविक earning/payout postings भी रखेगा। कोई काल्पनिक wallet credit या company cash receipt नहीं बनाया जाएगा।
- pgTAP static plan अब 29 assertions है; इनमें commission-only-on-labour, materials-inclusive electrician payable, verified payout settlement, refunded exclusion और posted-only wallet balance के checks जोड़े। Runtime execution अभी नहीं हुआ।


- Accounting Reconciliation Design तैयार: `docs/SRK_ELECTRONIC_ACCOUNTING_RECONCILIATION_DESIGN_HI.md`। इसमें Customer collection/refund, Labour-only Company Commission, Electrician payable, Wallet posted ledger और Razorpay Route transfer/settlement के अलग-अलग authoritative स्रोत तथा read-only per-booking reconciliation प्रस्तावित है। किसी discrepancy पर auto-post/auto-transfer नहीं होगा।
- सुरक्षित default दर्ज: Customer top-up और Wallet cash-out disabled ही रहेंगे; Electrician payable फिलहाल payout table में रहेगा, Wallet में duplicate earning credit नहीं बनेगा; Company commission को “received” तभी दिखाएँ जब platform Route transfer provider-side settled हो। Partial refund allocation अभी unsupported/fail-closed।
- Reconciliation guard pgTAP plan ठीक करके **34 assertions / 34 planned checks** किया। ये source-level assertions हैं; runtime pgTAP अभी execute नहीं हुआ।


### 2026-11-15 — Accounting reconciliation: read-only catalog and security contract

- Production Supabase catalog को केवल read-only SQL से जाँचा: payout table की प्रति-booking uniqueness, चार अलग रकम (labour/materials/commission/payable), paid-record evidence constraint, RLS और authorized-electrician read policy सत्यापित हुए।
- Live payout settlement RPC source में Main Admin authorization, booking-first row locking, verified payment + completed booking checks और payout snapshot बनाम booking labour/materials/commission/payable का exact comparison मिला। यह केवल वास्तविक bank/UPI transfer reference मिलने के बाद payout record को Paid दर्ज करता है; RPC खुद पैसा transfer नहीं करता।
- Wallet ledger owner-read RLS और Route ledger का authenticated direct-read denial तथा bigint paise amount column catalog में सत्यापित हुए।
- Live catalog में cancellation-fee item/ledger tables उपलब्ध नहीं थीं; वे Feature Branch की नई migration chain में हैं। इसलिए अभी reconciliation SQL view/RPC बनाना रोककर schema-chain gate रखा गया है—अधूरे live schema पर अनुमानित joins नहीं बनाए जाएँगे।
- नया test: supabase/tests/database/accounting_reconciliation_readonly_contract.test.sql — 20 planned assertions; payout, wallet और Route security/data contracts। Source/static review only; pgTAP runtime अभी execute नहीं हुआ।
- Design doc में live-vs-branch boundary और implementation gate जोड़ा। कोई migration apply, financial row write, wallet posting, Route transfer, payout, provider API call, deploy, merge या mobile QA नहीं किया।


### 2026-11-15 — Accounting migration-chain source verification

- PR #8 की changed migration सूची के आधार पर financial core, cancellation-fee carry-forward, full-refund reversal और new-category electrician payable migrations के exact source definitions पढ़े।
- पुष्टि: cancellation-fee debt/item/ledger अलग records हैं; fee ledger integer paise, idempotency uniqueness, append-only guard और service_role-only table grants रखता है। New-category electrician payable immutable labour bill पर आधारित है; cancellation fee electrician earnings में नहीं जाती, materials अलग/शून्य रहते हैं और commission केवल labour पर है।
- Payout recalculation केवल pending payout को refresh कर सकता है; paid/blocked/refunded row overwrite नहीं होती। Admin payout settlement booking-first locking और source amount comparison करता है।
- Accounting security pgTAP contract को 20 से बढ़ाकर **30 assertions** किया; इसमें cancellation-fee private ledger, append-only protection और labour-only payable calculation भी शामिल है। Plan/count static check आगे फिर से किया जाएगा; runtime pgTAP अभी नहीं चला।
- Live catalog में नई fee tables अनुपस्थित होने के कारण reconciliation RPC/view को live schema पर लागू नहीं किया गया। Feature Branch source-only; कोई migration apply, financial mutation, provider action, deploy/merge या mobile QA नहीं।


### 2026-11-15 — Read-only Accounting Reconciliation RPC + Admin panel

- Feature Branch migration `20261115130000_admin_readonly_booking_accounting_reconciliation.sql` में Main Admin-only RPC `srk_admin_get_booking_accounting_reconciliation(uuid)` जोड़ी।
- RPC प्रति Booking verified customer collection/refund/net, Labour/Materials, labour-only Commission, expected electrician payable, payout snapshot, Route transfers (processed और settled अलग), cancellation-fee allocation/ledger, और posted wallet entries का read-only snapshot देता है।
- Route payment ID/recipient identity, duplicate transfer, missing payout/transfer, amount mismatch, invalid commission, partial refund, payout/refund closure, cancellation-fee ledger balance और verified collection mismatch जैसे exception codes शामिल हैं।
- RPC `SECURITY DEFINER + STABLE + fixed search_path`; anon/public execute बंद; authenticated caller को भी internal `is_srk_admin()` check पास करना अनिवार्य। Function body static scan में कोई INSERT/UPDATE/DELETE नहीं मिला।
- `admin.html` में Main Admin Booking UUID report panel जोड़ा; यह केवल RPC call और read-only display करता है।
- pgTAP contract 43 assertions तक बढ़ी; plan/count 43/43 static रूप से verified। Runtime pgTAP और browser test अभी नहीं चले।
- कोई migration apply, Production schema/data change, provider call, financial write, payout, deployment, merge या mobile QA नहीं हुआ। Live schema में cancellation-fee tables अनुपस्थित होने से migration Feature Branch source-only रखी।


### 2026-11-15 — Accounting report evidence cross-check hardening

- Manual/cash payment को verified दिखाने से पहले exact amount वाली उसी booking की manual payment entry अनिवार्य की; evidence न मिले तो exception।
- Razorpay refund का provider payment ID और manual refund का linked payment entry/amount original booking से मिलाया।
- Cash cancellation-fee refund में wallet credit debt_id से linked होता है; report में अब fee_item_id और debt_id दोनों references शामिल हैं, इसलिए original debit और reversal credit दोनों दिखेंगे।
- Payout का electrician_profile_id assigned electrician और booking completion से cross-check किया।
- pgTAP contract अब 47 assertions; static plan/count verification pending immediate pass; runtime tests नहीं चले।
- कोई DB apply/financial write/provider call/deploy/merge/mobile QA नहीं।


- Full refund पर cancellation-fee items `reversed` होते हैं; report अब current settled ledger net और historical captured fee (settled + reversed) अलग रखती है। Customer की original captured amount का मिलान historical fee से होगा, जबकि current ledger net settled fee से। Admin UI में historical captured fee दिखती है। pgTAP plan अब 48 assertions तक बढ़ाया।


### Final static verification — Accounting Reconciliation (2026-11-15)

- Read-only RPC static checks: SECURITY DEFINER, STABLE, fixed search_path, Main Admin gate present.
- Function-body DML scan: INSERT/UPDATE/DELETE नहीं मिला।
- Refund evidence, manual payment proof, payout owner, Route payment/recipient identity, wallet reversal references और full-refund के बाद historical cancellation-fee capture की checks source में मौजूद।
- pgTAP plan/assertion count: **48/48**.
- Admin panel में historical captured cancellation fee display भी मौजूद।
- यह केवल source/static verification है। pgTAP runtime, SQL migration execution और browser runtime अभी pending हैं; कोई Production migration apply नहीं की।


### Refund lifecycle + Route reversal audit (2026-11-15)

- Razorpay refund की रकम net collection سے صرف `processed` پر کم ہوگی؛ requested/processing/unknown/failed رقم الگ unconfirmed field میں، failed پر exception۔
- Refund request workflow status کو final refund record سے cross-check کیا۔
- Route schema کے حقیقی `reversed/partially_reversed` transfer اور `reversed` settlement states کی جانچ شامل کی۔ Confirmed full refund کے بعد provider transfer ID ہونے پر transfer + settlement دونوں reversed ہونے چاہئیں، ورنہ exception۔
- Admin UI میں confirmed اور unconfirmed refund الگ دکھائے جاتے ہیں۔ Partial reversal کی exact رقم موجودہ Route schema میں محفوظ نہیں؛ report اس کی رقم invent نہیں کرتی۔
- pgTAP plan/assertions: 52؛ static verification pending immediate pass؛ runtime execution pending۔


### Static verification — Refund / Payout / Route cross-audit (2026-11-15)

- Refund net collection अब केवल Razorpay processed status पर घटता है; pending/unknown/failed amount अलग रहता है और failed refund exception है।
- Refund request status बनाम final refund evidence checks source में हैं।
- Route full/partial reversal states और confirmed full refund के बाद actual transfer ID की reversal requirement source में हैं।
- Main Admin RPC SECURITY DEFINER + STABLE + fixed empty search_path; function body में कोई INSERT/UPDATE/DELETE नहीं।
- Manual payment/refund evidence, payout electrician ownership/completion, cancellation-fee wallet debt reversal, और historical fee capture checks source में मौजूद।
- pgTAP plan/assertions 52/52 static count verified।
- Admin UI confirmed/unconfirmed refund अलग दिखाती है; dynamic content escaping esc() मौजूद।
- केवल Feature Branch source changes; no SQL apply, no runtime pgTAP, no provider call, no deployment, no merge, no mobile QA।


### Welcome Screen — Founder Photo integration (2026-11-15)

- यूज़र द्वारा इसी चैट में दी गई नई Founder portrait को `assets/srk-founder.jpg` के रूप में Feature Branch में जोड़ा।
- `welcome.html` के पुराने decorative bolt visual को Founder portrait card से बदला; responsive image sizing, cover crop, alt text और Founder badge जोड़े।
- Source verification: Welcome markup में asset path और image alt text मौजूद; पुराना bolt-wrap markup हटाया हुआ।
- Vercel Git Preview commit `a897fa0c446276d9a8937701e0dd281e59b04763` पर **READY**; build log में “Deployment completed”। Preview URL: `https://srk-electranic-likdfbyba-srk-electranic.vercel.app/welcome.html`.
- Direct browser/network fetch इस जाँच वातावरण में DNS/network failure के कारण नहीं हो सका; इसलिए image का वास्तविक browser rendering अभी visually verified नहीं है।
- Production deployment, merge और PR #8 merge नहीं किए; PR #8 Draft है।
- Founder photo replacement के लिए पुरानी saved reference image को delete नहीं किया गया; नई portrait अभी project asset में उपयोग हो रही है।


### 2026-11-15 — Founder portrait crop/pose instruction saved (pending)

- User-approved edit specification recorded: use the previously saved garden-background Founder portrait only; crop to waist-up (remove all lower body/legs), keep face/hair/shoulders visible and centered, and pose both arms naturally folded/crossed across the chest with hands resting near opposite upper arms.
- Updated per user: change/remove the garden background and use a clean premium professional portrait background. Match the Founder model/look shown in the existing three-photo Founder reference; do not paste the phone mockup or its layout into the final portrait. Keep the recognizable Founder appearance and black-shirt styling; photorealistic, no text/logo/badge/extra person.
- The three-phone UI mockup is not a Founder portrait and must never be substituted.
- Image generation could not be invoked due to the current Free-plan image-generation limit. **Pending** until generation is available; no edited image has been created or integrated yet.


### 2026-11-15 — Resume audit: Customer five-menu implementation checkpoint (14.1.2)

- User-directed sequence reaffirmed: finish remaining Customer → Electrician → Admin/Staff implementation first; then perform a complete option-by-option audit, fix gaps, run the consolidated test phase, and only then prepare go-live. No premature completion claims.
- Current approved working branch re-confirmed from PR #8: `feat/customer-login-first-dashboard-20261114` (PR remains Draft/open; no merge/deploy).
- Re-fetched current `booking.html` at branch head (blob SHA `f9740cf022b0f11cf44bf6c26d499172b8a9ab08`). All five Customer menu tabs and matching tab panels are present in source: Home, My Bookings, Payments, Help & Support, My Profile. Keyboard tab navigation/ARIA attributes and menu activation handlers are present. This supersedes the older 17.107/17.109 audit statement that no five-menu shell existed; those notes describe earlier snapshots and must not be treated as current status.
- Source also contains menu-specific data paths for payment/refund history, customer support tickets/messages/attachments, and profile/saved-address RPCs. This confirms substantial implementation, but not complete menu acceptance.
- **Still not verified:** each menu's full feature coverage, all RPC definitions/grants/RLS and attachment access on the same branch, privacy/no-store/cache behavior, every loading/empty/error/offline/retry state, accessibility/responsive behavior, and the full Customer checklist cross-dependencies (labour-only payment, lifecycle/contact visibility, cancellation/refund). Presence of tabs or RPC call names alone is not proof of secure end-to-end completion.
- Next execution: continue source-by-source contract audit of Customer menu and its RPC/migrations, close implementation gaps without production writes, then proceed in Master Checklist order through Customer booking items and Electrician/Admin/Staff. Keep all manual mobile/Desktop QA deferred to one final consolidated pass. Runtime database/provider/E2E tests remain a separate final test gate.
- No app source, DB, Auth, Storage, provider, payment, customer data, deployment, merge, or mobile QA changed in this checkpoint.


### 2026-11-15 — Customer five-menu source regression guard added

- Rechecked the current Customer dashboard source and its backend call sites. The page contains exactly five menu tabs and five matching panels; the session restore/auth-state listener is present. Menu source calls payment history/refund history, complaint list/thread/send, customer profile read/update and saved-address list RPCs.
- Added `tests/customer-five-menu-source.test.js` to the repository's existing `node --test tests/*.test.js` suite. It checks the five expected tab/panel pairs, authenticated-dashboard gating markers, required Customer RPC callers, and existence of the matching profile/support SQL migrations and database contract tests.
- Re-fetched the committed test file and booking source after commit; confirmed 5 tabs, 5 panels, auth-state handler and all listed RPC callers are present. **The test file has not yet been executed in a local/CI runtime**, so this is source/refetch verification only, not a passing test claim.
- Existing database contract test files for Customer profile/saved addresses (28 assertions), complaint safe projection (13), support attachment/Admin message access (14), and payment/refund history (11) have assertion counts matching their declared pgTAP plans. These SQL tests have not been run against a disposable database in this checkpoint.
- Remaining Customer work: inspect all RPC signatures/permissions and storage policies as one complete migration chain; reconcile current Customer booking/payment paths with approved labour-only billing and refund rules; complete feature-by-feature loading/error/empty-state and privacy review. No production DB, Auth, Storage, provider, payment, deployment, merge, or manual device QA action taken.


### 2026-11-15 — Customer backend/security source audit (अगला checkpoint)
- Customer saved-address RPCs में auth.uid()-scoping, direct table grants revoke, प्रति ग्राहक अधिकतम 10 पते, एक default address, input validation और authenticated-only execute grants source में मौजूद मिले। UI save/edit/delete/default handlers भी उन्हीं RPC contracts को call करते हैं।
- Customer avatar flow private Storage bucket, customer-folder path, MIME/size metadata verification और authenticated-only profile RPC पर आधारित है।
- Support conversation tables direct client access से बंद हैं; customer message/read/attachment-link RPC complaint ownership जाँचते हैं। Support files private bucket में हैं; delete policy केवल unlinked orphan upload हटाने देती है। Customer complaint projection Admin notes/events को null/empty रखती है।
- Payment/refund history RPC auth.uid() के booking ownership पर सीमित है और verified payment, refund request, Razorpay refund तथा manual refund events लौटाती है; Admin/provider private payload नहीं लौटाती।
- यह source-code review है; कोई SQL/pgTAP/runtime test इस चरण में execute नहीं हुआ। पहले दर्ज किए गए 28/13/14/11 assertion counts केवल test-file source declarations हैं, pass result नहीं।
- शेष audit: customer booking create/confirm path, booking ownership and phone visibility, labour/material split and duration/paise calculation; फिर Electrician तथा Admin/Staff end-to-end source review। Manual device QA अंतिम consolidated चरण तक स्थगित है। Production/database/deploy में कोई बदलाव नहीं किया गया।


### 2026-11-15 — Customer booking/refund integration audit (महत्वपूर्ण gap मिला)
- Customer booking page का refund submit handler `srk_customer_create_booking_refund_request(uuid,text)` call करता है; branch migration chain में इस RPC की definition मौजूद नहीं मिली। साथ ही page history path में `srk_customer_list_my_booking_refund_requests()` और अन्य customer history caller names का exact migration/signature alignment दोबारा जाँचना आवश्यक है। इसे अभी working UI feature नहीं माना जाएगा; यह implementation blocker है।
- Existing branch में `srk_customer_get_payment_receipt(uuid)` owner-check करता है और immutable labour bill को प्राथमिकता देता है; bill paise, amount और verified captured amount का exact match न होने पर labour amount null रखता है। Materials स्वतः receipt labour में शामिल नहीं होते।
- Existing profile/support/payment-history source audit से कोई runtime result infer नहीं किया गया। Booking creation, contact reveal timing, server-side duration billing और paise rounding का complete source chain अभी इस checkpoint में प्रमाणित नहीं हुआ है।
- अगला fix gate: refund request lifecycle को immutable labour bill + verified captured payment से reconcile करना; materials को स्वतः refund में न जोड़ना; rejected/failed request retry semantics और Admin review/status path को साथ में resolve करना। RPC नाम mismatch को blindly alias/copy नहीं करना। पहले सभी related schema, constraints, Admin RPCs और production-vs-feature migration differences inspect होंगे।
- कोई migration apply, production write, payment/refund/provider call, deployment, merge या manual device QA नहीं किया।


### 2026-11-15 — Refund contract audit correction + Admin UI gap
- पिछले checkpoint में `srk_customer_create_booking_refund_request` migration missing बताना गलत था। PR #8 की पूरी changed-file सूची देखकर Feature Branch में `20261115100000_customer_refund_request_contract.sql` मिला और पूरा source पढ़ा। इस migration में Customer create RPC मौजूद है; owner booking lock, verified paid status, immutable labour bill + settled cancellation fee exact paise reconciliation, existing refund/manual refund duplicate guard, rejected request resubmission, और authenticated-only grants हैं।
- उसी migration में Customer history RPC का canonical नाम `srk_customer_list_booking_refund_requests()` है। Current Feature Branch `booking.html` को सीधे fetch करके दोनों call sites जाँचे: वह पहले से canonical नाम call करता है; search index का पुराना excerpt stale था। इसलिए इस checkpoint में booking.html में कोई बदलाव आवश्यक नहीं था।
- Admin migration `20261115110000_admin_refund_review_queue_and_decisions.sql` में Main Admin-only queue और decision RPC मौजूद हैं; current `admin.html` में queue और decision के callers मिले।
- महत्वपूर्ण शेष integration gap: current `admin.html` में `srk_admin_prepare_razorpay_refund` का caller नहीं मिला। इसलिए approved request से provider refund preparation/execution तक Admin UI workflow पूर्ण प्रमाणित नहीं है। अलग serverless refund endpoints/recovery files की पूरी chain, auth, idempotency और provider response verification audit करनी है। Approval RPC स्वयं पैसा transfer नहीं करती—यह सही separation है।
- Customer contract pgTAP test में 17 planned assertions हैं; Admin approval gate test में 8 planned assertions घोषित हैं। ये केवल source plan declarations हैं; runtime pgTAP नहीं चला।
- कोई Production change, migration apply, payment/provider call, deployment, merge या manual device QA नहीं किया। अगला काम: Admin refund execution UI/API chain को सुरक्षित तरीके से पूरा करना, फिर Customer booking/payment/contact/duration contracts का source audit जारी रखना।


## 2026-11-15 — Refund executor wiring re-check (correction)

- Previous note that `admin.html` has no preparation/executor caller was inaccurate and is corrected here. The Main Admin Razorpay Full Refund form calls `startAdminRazorpayRefund()`, which obtains the current Supabase session token and POSTs `booking_id` + reason to `/api/razorpay-refund`.
- `netlify.toml` routes `/api/razorpay-refund` to `/.netlify/functions/razorpay-refund`; Netlify wrapper imports root `razorpay-refund.js`. The handler validates the Supabase user token, checks `is_srk_admin`, invokes `srk_admin_prepare_razorpay_refund`, checks prepared booking/payment/amount/idempotency data, sends Razorpay refund with the stored `X-Refund-Idempotency` key, then calls service-role reconciliation. Thus the Admin → API → preparation RPC → provider → reconciliation caller chain exists in source.
- Customer-approved request UI shortcut `prepareApprovedCustomerRefund()` fills the same Main Admin Full Refund form; the database preparation RPC independently blocks a customer request unless its state is `approved`, `processing`, or `unknown`. Approval itself does not send money.
- Separate status lookup and recovery handlers are wired through `/api/razorpay-refund-status` and `/api/razorpay-refund-recovery`; both revalidate Main Admin, match provider refund identity/payment/amount, and recovery records evidence before separate accounting finalization. Read-only provider status check explicitly says it does not change ledger or payout.
- Executor source regression test exists at `tests/razorpay-refund-executor.test.js`; webhook tests include processed/failed and amount-mismatch cases. **Tests have not been executed here**, and no runtime/database/provider integration is claimed.
- Remaining verification: reconcile the exact migration lineage for the provider executor/recovery functions and schema columns against all branch migrations; verify payout/fee-ledger finalization trigger ordering and failure recovery; inspect provider 4xx/timeout behavior and Admin UI refresh/status handling. Do not perform live Razorpay calls, deploy, apply migrations, or change Production during this source audit.


## 2026-11-15 — Refund ledger / payout reconciliation audit

- Reviewed `20261114290000_full_refund_cancellation_fee_and_wallet_reversal.sql` in detail. New categorized booking preparation derives full online refund from immutable labour paise plus settled cancellation-fee paise, and requires exact equality with captured `amount_paid`; any unsettled fee item or mismatch fails closed. Legacy quote flow separately validates approved quote and service+materials against captured amount.
- Full-refund trigger requires a matching processed Razorpay refund record for exact full captured amount before setting booking payment status to `refunded`. It reverses settled online cancellation-fee ledger credits and reopens the debt; for cash-collected fee it restores the earlier electrician wallet debit with an idempotent wallet credit and reverses the fee ledger. The electrician payout remains blocked after successful refund (no payout release on processed state); a definitively failed provider refund restores only a payout that is still blocked with the exact refund-pending note.
- Key remaining risk: recovery/status functions referenced by `razorpay-refund-recovery.js` (`srk_service_record_razorpay_refund_recovery_evidence`, `srk_service_finalize_razorpay_refund_from_recovery_evidence`) were not found in the migration files checked so far. Need exhaustive migration inventory/search and exact signature/schema confirmation before declaring recovery complete. If truly absent, the recovery endpoint will fail closed at evidence persistence/finalization; do not use it on a real refund until fixed.
- Webhook source currently locates a refund row by `payment_id` only and requires exactly one row; verify whether schema guarantees one refund per payment and whether provider refund IDs / partial-refund support can cause ambiguity. Current Main Admin preparation appears full-refund-only and one refund record per booking; partial refund must remain disabled unless explicitly implemented end-to-end.
- Source-only audit. No SQL migrations applied, no live DB/provider call, no runtime tests executed, no payout/refund/wallet mutation.


## 2026-11-15 — Recovery migration located; webhook matching review

- Correction to the previous progress note: the two recovery RPC definitions do exist in Feature Branch migration `20261115120000_durable_razorpay_refund_recovery_evidence.sql`. They were missed because GitHub code search covered the default branch, not this feature branch; the full PR #8 changed-file inventory exposed the migration. Do not treat these RPCs as missing.
- The migration creates a private RLS-enabled, append-only recovery evidence table. The evidence writer and finalizer are service-role-only, validate the authorized SRK Admin actor, bind provider refund/payment/amount/currency/status fields to the internal refund record, hash the provider payload, and use an observation UUID for idempotent retries. Finalization accepts only processed evidence younger than 15 minutes, checks booking/payment/refund identity and payout state, updates the booking in a separate transaction, and closes the blocked payout as refunded after the accounting trigger succeeds. A pgTAP file declares 34 assertions, but it has not been executed in this audit.
- Recovery endpoint reads provider status only (GET), records immutable evidence, then makes a separate finalization RPC call. It does not create or submit a new Razorpay refund.
- Webhook refund reconciliation validates signed webhook signature, event inbox claim, refund ID, payment ID, expected event status, INR currency and amount; it looks up internal refund rows by payment ID with limit 2 and fails closed unless exactly one row is found, then checks internal amount and any pre-existing provider refund ID before service-role reconciliation. This is conservative but relies on one internal refund record per payment; confirm the database unique constraint and keep partial/multiple refunds unsupported unless the whole chain is extended.
- Remaining review: confirm the unique constraint for `srk_razorpay_refunds.payment_id` and audit the executor's timeout/ambiguous-provider-response path, including whether it preserves the payout block and directs the Admin to status/recovery rather than allowing a duplicate refund attempt. No runtime tests executed; no migration applied, deployment, live Razorpay request, or financial mutation.


## 2026-11-15 — Refund uniqueness and ambiguous-request behavior

- Refund table schema in `20261114125844_restore_financial_audit_core_schema.sql` has a unique constraint on `booking_id` and a unique nullable provider `refund_id`; it does **not** declare `payment_id` unique. Therefore webhook lookup by payment ID is intentionally fail-closed when zero or multiple rows are returned, but the database does not independently guarantee exactly one internal refund row per payment. Existing Admin preparation does lock the booking and reuses the booking's one refund row; customer request creation also refuses a second refund record for the same booking. Do not enable partial/multiple refunds.
- Executor ambiguity handling is conservative: timeout/network failure returns `unknown` and does not call the reconciliation RPC or release payout hold; any retry is tied to the same stored idempotency key, same amount, receipt and request body, and `X-Refund-Idempotency`. Provider 409 is treated as the same operation still processing. Non-409 provider rejection is held for manual reconciliation; provider-accepted but DB-reconciliation-failed returns pending webhook reconciliation. Status and Recovery endpoints use provider GET only and explicitly prevent safe retry when provider identity is not conclusively found.
- Webhook reconciliation queries by payment ID with limit 2 and rejects anything except exactly one row; then checks exact amount and any already-stored provider refund ID before invoking the service-role RPC. This avoids guessing, but payment_id uniqueness is not a DB constraint in the reviewed core schema. A future hardening change may add a unique partial index only after verifying historical rows are duplicate-free and confirming no legitimate multi-refund model exists; no index was added without data validation.
- No code change to the executor/webhook was needed in this review. Automated tests are present for stable idempotency, timeout ambiguity, recovery evidence and webhook behavior, but have not been run. No production DB changes, migrations, provider POST, refund, payout, wallet or booking mutation were performed.


## 2026-11-15 — Admin read-only accounting reconciliation audit

- Reviewed `srk_admin_get_booking_accounting_reconciliation(uuid)`, its 52-assertion pgTAP contract, and the Main Admin UI card/caller in `admin.html`. The UI is present and invokes the RPC; output is rendered with escaped dynamic values, includes collection/refund/net, immutable labour, materials, commission, payout, Route transfer/settlement, cancellation-fee ledger, posted wallet entries and exception list. The RPC is `STABLE SECURITY DEFINER`, has an empty search_path, independently gates through `is_srk_admin()`, and its source contains no INSERT/UPDATE/DELETE financial writes. Authenticated execute permission is necessary for the in-function Admin gate; anon execute is revoked.
- Contract file's declared pgTAP plan exactly matches 52 `select ok(...)` assertions. It has not been run.
- Cross-checked payout creation and settlement: new-category electrician gross is immutable labour only; cancellation fees and materials are excluded from new-category labour; legacy approved quote keeps separate materials; commission is labour-only; settlement requires completed booking, verified payment, matching assigned electrician and exact payout amounts; paid/blocked/refunded rows are not recalculated as pending.
- Important reporting gap found: the read-only reconciliation displays total posted wallet credits/debits but does not currently assert that a cash cancellation-fee debit has its exact matching refund credit after a full refund. The refund trigger does require and create the original electrician wallet debit reversal, and the report includes linked wallet rows, but a missing/duplicate credit could be visible only by manual comparison rather than an explicit exception. Next audit should inspect wallet-ledger uniqueness and design a precise expected-vs-actual exception without treating unrelated wallet entries as this booking's cancellation-fee recovery.
- No migration applied, no payout/wallet/payment mutation, no production change and no runtime test executed.


## 2026-11-15 — Cash cancellation-fee wallet refund reconciliation improvement

- Fixed the previously recorded reporting gap in `srk_admin_get_booking_accounting_reconciliation(uuid)`: for manual full refunds, it now computes the expected electrician wallet credit from the exact original posted cash-fee wallet debit and compares it with posted refund credits linked to the same cancellation-fee debt, electrician, exact amount, and this specific manual refund evidence ID (`provider_reference`). This prevents a later reuse/refund of the same debt on another booking from being counted in this booking's reconciliation.
- A mismatch (including missing or extra/duplicate credit amount) adds `CASH_FEE_WALLET_REFUND_MISMATCH`; both expected and actual totals are included in the read-only report. It does not create, repair, or mutate any wallet entry.
- Updated the static pgTAP contract from 52 to 53 assertions; source count and declared plan match (53). Runtime pgTAP has not been executed.
- Additional payout source audit: Admin payout-paid RPC locks booking before payout, requires pending state, completed + verified-paid booking, matching assigned electrician, immutable labour bill, no reserved cancellation-fee items, and exact labour/materials/commission/payable snapshot; it only records the Admin-supplied bank/UPI reference and does not call the bank. New-category payout generation excludes cancellation fees from electrician earnings and only refreshes pending rows.
- Source review also flagged a follow-up hardening question for the next pass: explicitly prove commission_rate is non-null and within 0..100 inside the Admin payout-paid RPC itself, rather than relying on the payout-generation path. Do not mark paid until this is verified/fixed.
- No tests executed, no migrations applied, no wallet/payout/payment mutations, no provider requests, and no production changes.


## 2026-11-15 — Admin payout commission validation hardening

- Closed the payout settlement follow-up: `srk_admin_mark_electrician_payout_paid` now independently rejects a missing commission rate or any rate outside 0..100 before computing expected commission, for both new-category and legacy quote bookings. This avoids SQL NULL comparison behavior allowing an incomplete commission calculation to pass the final IF guard.
- Added a pgTAP source-contract assertion; `electrician_payout_reconciliation.test.sql` now declares 26 assertions and contains 26 `select ok(...)` checks. Not executed.
- Accounting reconciliation changes are source-only in PR #8 feature branch. No production migration apply, financial write, bank transfer, provider call, deploy or live setting change.


## 2026-11-15 — Route Transfer / Commission Refund Reconciliation Audit
- Reviewed the server-only `srk_route_transfers` ledger: unique provider payment + recipient type, unique idempotency key and provider transfer ID, integer-paise amount, separate transfer and settlement state fields, and no client table grants.
- Reviewed Admin read-only reconciliation: electrician and platform commission transfers are counted separately; provider processing and settlement totals are exposed separately; payment ID, assigned electrician, amount, duplicate rows, partial reversals and refund-related Route exceptions are checked.
- Fixed a gap: confirmed manual full refunds (`manual_recorded`) now receive the same Route reversal requirement as provider-confirmed full refunds. If a provider transfer ID exists, both `transfer_status='reversed'` and `settlement_status='reversed'` are required; otherwise `ROUTE_TRANSFER_NOT_REVERSED_AFTER_FULL_REFUND` is reported.
- Added one pgTAP contract assertion; accounting reconciliation test plan is now 54 assertions (declared plan/count checked in source only; runtime not executed).
- Audit boundary: the reviewed feature-branch changes contain the Route ledger schema and read-only reconciliation, but no verified Route transfer create/settlement/reversal executor was found in the inspected changed files. Therefore no claim is made that provider transfers or reversals are automated. Provider transfer/reversal calls must remain disabled until a separately reviewed, evidence-backed, idempotent workflow exists.
- Commission is reported as expected/ledgered/processed/settled amounts, not as cash received by the platform merely because a transfer row exists. A provider transfer marked processed is still distinct from settlement marked settled.
- No Razorpay Route API calls, transfers, reversals, payouts, wallet mutations, migrations, or production changes were executed. Runtime tests remain unrun.
- Commits: `07e2c333` (manual refund Route reversal gate), `eccddaa6` (54th assertion).


## 2026-11-15 — Admin Commission Report Label and Route Ledger Contracts
- Admin aggregate Commission Report labels were clarified: customer collection is explicitly limited to completed + paid bookings; company commission is labelled as calculated commission, not cash received; electrician amount remains a calculated payable, not proof of payout.
- Per-booking Accounting Reconciliation UI continues to show Route `transfer_status` and `settlement_status` independently, and shows processed vs settled totals separately.
- Added `tests/admin-commission-report-labels.test.js` for source-level guards covering labels, separate Route states and Main Admin / completed-paid scoping.
- Extended accounting pgTAP source contract from 54 to 56 assertions: one logical transfer per provider payment + recipient type, plus unique idempotency key and provider transfer ID.
- Source checks only. The new Node test and pgTAP suite have not been executed; no runtime pass is claimed.
- Route transfer schema is server-only with integer paise, INR, separate transfer/settlement states, one payment-recipient logical row, and unique idempotency/provider transfer identifiers. No verified provider Route executor was found; automated transfers/reversals remain unimplemented/unverified and must not be described as live.
- Commits: `46ac466c` (Admin wording), `0da7ca84` (Node source test), `e9d3c00b` (Route ledger contract assertions).


## 2026-11-15 — Customer / Electrician Booking and Contact Visibility Audit
- Booking creation source uses authenticated customer phone matching, required UUID idempotency key, validated customer-selected category/tier/duration, server-derived estimate in integer paise, and relies on the database broadcast trigger for a single offer queue rather than creating duplicate offers in the API handler.
- Sequential dispatch source sends one live offer at a time, rechecks active/available/approved electrician and exact approved rate tier before each offer, and advances on decline/expiry.
- Work lifecycle source review: electrician requests work start; customer approval snapshots Admin-approved rate tier/version and starts the server timer. Electrician completion request stops the timer; customer approval creates an immutable labour-only bill from server elapsed seconds. Customer rejection restarts the timer; dispute records a complaint and keeps booking from completing. Labour calculation uses ceil(actual seconds / 60) and integer paise half-up. Materials are excluded from the labour bill.
- Found and fixed a confirmed contact visibility mismatch: the customer contact RPC previously stopped returning the electrician's phone after work completion, and the customer UI hid the call action. It now keeps contact available after assignment, including completed/cancelled assigned bookings. Electrician offer details likewise keep the assigned customer's phone available through completed/cancelled states, while the assigned-electrician identity gate remains required. Before assignment, customer phone remains hidden from electrician and electrician phone remains hidden from customer.
- Added `tests/accepted-contact-visibility.test.js` as a source-level contract guard.
- Added/updated tests remain unexecuted. No runtime test result is claimed; no mobile QA, migration apply, production setting change, booking, payment, SMS/OTP or provider call was performed.
- Commits: `a26b81c3` (customer contact RPC), `9d2522e5` (electrician assigned-contact projection), `cb205a40` (customer call UI), `8e469b6f` (source contract test).


## 2026-11-15 — Customer Refund Lifecycle UI Alignment
- Customer refund flow audit compared the customer-facing booking card with the authoritative refund-request RPC. The server requires a categorized booking to be `completed` before accepting a refund request, but the UI previously displayed the request form for any verified-paid booking. This caused a confusing form that the server would correctly reject for an unfinished categorized booking.
- Fixed the customer UI eligibility rule: categorized bookings show the refund request only after `completed`; legacy bookings without a selected category retain the existing verified-paid eligibility. The server-side ownership, verified-payment, immutable labour bill, settled cancellation-fee and exact captured-amount checks remain authoritative and unchanged.
- Added `tests/customer-refund-ui-lifecycle.test.js` to guard the UI/server lifecycle alignment. The source test has not been executed.
- Customer can resubmit only after a rejected request; customer history remains owner-scoped and does not expose private Admin notes. Admin review decision RPC is Main Admin-gated, records audit notes, constrains state transitions, and does not itself call a payment provider or mutate booking payment status. Approved requests only preselect the existing full-refund workflow; no partial refund flow is enabled.
- No migration applied, refund/provider call, payment/wallet/payout mutation, production change, deployment or mobile QA performed. Runtime tests remain unrun.
- Commits: `6aec4e4a` (UI lifecycle gate), `5220fff2` and `68d6f72e` (test creation/correction).


## 2026-11-15 — Admin Refund Queue and Support Staff Access Audit
- Reviewed the Admin refund queue and Support Staff portal source. The refund queue displays request state, verified payment context, provider refund state/ID, payout state, recovery evidence action and Admin audit notes. The recovery action remains explicitly evidence-first; UI warns not to create a new refund or release payout while provider state is ambiguous.
- Found a UI safety issue: an approved customer request continued to show the “Razorpay Refund के लिए चुनें” action even after its provider refund record was already `processed`. The backend idempotency key would protect the provider operation, but showing a launch/retry control after confirmed processing is misleading and unnecessary. The UI now hides that action when `refund_record_status='processed'`; provider state and refund ID remain visible.
- Reviewed Support Staff access: Main Admin and Support Staff screens are separated by portal mode; Staff session registration and permission checks are required; staff invitation Edge Function independently verifies `is_srk_admin()`, accepts only the invite action, fixes role to `support`, and registers the invited identity through a service-role-only RPC. Staff inbox reads and mutations are assignment-scoped, staff permissions are checked server-side, and the RBAC migration does not project customer/electrician phone fields into Staff inboxes.
- Added `tests/admin-refund-and-staff-access.test.js` to guard processed-refund action hiding, portal separation, fixed-role Main Admin invitation, assignment scoping and absence of private phone projections. Source assertions have not been executed.
- Scope caveat: this is source-level review only. It does not prove live staff invite delivery, email confirmation, session revocation on a running deployment, or runtime RLS/RPC behavior. No Staff account was invited, no session revoked, no refund/provider request, no payout or booking mutation, no migration apply, no deployment, and no mobile QA occurred.
- Commit: `dfed74b1` (processed-refund UI guard), `a896d71f` (source-contract test).


## 2026-11-15 — Server-Timed Booking Status Bypass Found and Guarded
- A deeper Admin save-path audit found a material lifecycle bypass: the general Admin booking table wrote `service_bookings.status` directly. For new-category/server-timed bookings, an Admin could therefore attempt to set `in_progress` or `completed` without the customer-approved work-start/completion RPC and immutable final labour bill flow.
- Fixed the Admin save handler to reject direct status or quoted-rate changes for new-category bookings. Actual manual Cash payment recording remains available only through its dedicated RPC after the booking is already completed; Razorpay payments remain verified through the provider flow.
- Added a database trigger in the existing server-timed work migration. It makes the selected category immutable and requires protected authorization rows for work-start approval, timer start, and completion transitions; approved cancellation remains governed by the dedicated cancellation-request evidence path. Legacy bookings (`selected_category IS NULL`) retain their existing legacy flow.
- Added three pgTAP assertions to `customer_booking_work_timeline.test.sql` (plan now 19) for trigger existence, SECURITY DEFINER/empty search_path, and protected transition authorization. Also added a Node source-contract assertion in `tests/admin-refund-and-staff-access.test.js`.
- Static source checks confirm the Admin guard, database trigger, and regression assertions are present in the feature branch. Neither Node nor pgTAP tests have been executed; no database migration was applied.
- No production settings changed, no booking/payment/refund/payout/wallet mutation, no provider request, no deploy, and no mobile QA performed.
- Commits: `f0db58d9` (DB guard in existing migration), `76dcb381` (Admin save guard), `8b21e347` (Node contract test), `ee546d02` (pgTAP plan 19).


## 2026-11-15 — Sequential Offer Assignment Guard Tightened
- Continued checking the newly added server-timed booking status trigger against the actual sequential offer dispatcher. Found that the trigger's first version allowed `new/confirmed → assigned` whenever an electrician ID was supplied, without independently proving that the electrician had accepted the active offer. The normal RPC did validate the offer, but a direct privileged status update could bypass the sequential dispatch acceptance step.
- Tightened the trigger: a new-category booking can become `assigned` only when a matching `job_offers` row for that booking/electrician is already `accepted`.
- Updated `srk_respond_to_offer` to mark the currently offered row accepted before updating `service_bookings`. Both writes remain in the same database transaction, so any later failure rolls back the offer acceptance too. This lets the trigger validate the genuine acceptance event.
- Added two pgTAP assertions; `customer_booking_work_timeline.test.sql` plan is now 21. Tests remain source-only and unexecuted.
- No database migration applied, no live offer accepted, no booking/payment/refund/payout/wallet mutation, no production changes, no deployment, and no mobile QA.
- Commits: `e34f3f89` (trigger + offer-response hardening), `06803a71` (pgTAP assertions).


## 2026-11-15 — Electrician Offer Acceptance Revalidation
- Electrician availability, relocation और sequential dispatch source paths का मिलान किया। Dispatch समय current operating area और selected rate tier re-check करता था, लेकिन offer स्वीकार करते समय response RPC केवल profile active/available/KYC state जाँचता था।
- Offer acceptance query अब booking के live state/district से electrician का current state/district मिलाती है और customer-selected tier के साथ Admin-approved tier/card/approval metadata भी दोबारा verify करती है। पुरानी area/tier snapshot पर पड़ा stale offer अब स्वीकार नहीं होना चाहिए।
- Sequential offer dispatch pgTAP contract में 2 assertions जोड़े; घोषित plan 14 से 16। Tests अभी source-only हैं, execute नहीं किए गए।
- Commits: `d6ed91e1` (acceptance revalidation), `e3707e57` (pgTAP assertions).
- कोई migration apply नहीं, कोई वास्तविक offer accept नहीं, कोई live booking/payment/refund/payout/wallet mutation नहीं, production/deployment नहीं और mobile QA नहीं।


## 2026-11-15 — Electrician Availability, Relocation और KYC UI Audit
- Electrician dashboard के availability toggle, private KYC upload/list/preview, self-service operating-area request, phone-change history, earnings/wallet और offer rendering paths का source review किया।
- Availability RPC केवल उसी authenticated linked profile पर काम करता है जो Admin-approved और Active हो; Offline होने पर केवल unaccepted offers बंद कर sequential queue आगे बढ़ती है। Accepted assignments को यह flow नहीं छूता।
- Relocation request में linked profile, active/approved status, अलग operating area, छह अंकों का PIN, reason length और एक pending request की unique constraint जाँची। Admin approval में profile row lock, पुराने unaccepted offers बंद करना और नए area के अनुसार dispatch आगे बढ़ाना source में मौजूद है; accepted assignments सुरक्षित रखे जाते हैं।
- KYC UI में PDF/JPG/PNG, 5 MB सीमा, per-user private object path, metadata RPC, owner-scoped document-path RPC और 60-second signed preview path जाँचे। Admin review UI में decision validation और rejection/resubmission note requirement भी जाँची।
- इस pass में कोई नया confirmed source defect नहीं मिला। यह source audit है—Supabase RLS/RPC/Storage behavior का runtime proof नहीं। Node/pgTAP/build tests execute नहीं किए गए; कोई migration apply, live KYC upload, relocation approval, availability mutation, booking/payment/refund/payout/wallet mutation, deployment या mobile QA नहीं हुआ।


## 2026-11-15 — Live Location GPS Failure Cleanup Hardening
- Live-location audit में एक privacy/lifecycle edge case मिला: browser GPS watch का error callback या server location-update RPC failure आने पर browser watch बंद हो जाता था, लेकिन server-side `is_active` location row को stop RPC से बंद नहीं किया जाता था। Customer view 90 सेकंड बाद stale location छिपा देता था, पर server state active रह सकती थी।
- `electrician.html` में साझा cleanup helper जोड़ा। GPS signal/error या update RPC failure पर browser watch clear करके `srk_electrician_stop_live_location` call होता है; server stop confirm होने पर ही local retry entry हटती है। Stop RPC fail होने पर booking local retry set में बनी रहती है ताकि Dashboard Refresh/Logout पर फिर प्रयास हो सके।
- `tests/electrician-live-location-client.test.js` में तीन source-contract assertions जोड़े: update failure cleanup, GPS error cleanup और failed-stop retry retention। Test अभी execute नहीं किया गया।
- Live-location SQL source review में booking assignment/status scoping, explicit start consent, coordinate range/accuracy checks, customer ownership, 90-second stale-read cutoff और booking transition पर coordinate clearing भी जाँचे।
- Commits: `ad3e9313` (client cleanup), `81426a92` (source test).
- कोई GPS location live साझा नहीं की गई, कोई migration apply नहीं, कोई booking/payment/refund/payout/wallet mutation नहीं, production/deployment नहीं और mobile QA नहीं।


## 2026-11-15 — Push Notification और New Job Offer Alert Audit
- Electrician dashboard में opt-in Push UI, browser permission flow, VAPID public-key config fetch, service-worker registration/subscription और subscription upsert/delete source review किया। Permission denied और unsupported/insecure browser state UI में संभाले गए हैं।
- `sw.js` में push event पर notification render और click पर same-origin URL validation मौजूद है; click Electrician dashboard खोलता है। Offer ID notification data में रखी जाती है, पर UI में specific offer deep-link/auto-open behavior प्रमाणित नहीं हुआ।
- Sequential dispatch migration में नया `job_offers` row बनता है; decline/expiry पर अगला eligible offer dispatch होता है। Netlify expiry worker हर मिनट expiry RPC चलाता है। इन reviewed feature-branch files में dispatch/expiry के बाद Push sender invocation, Web Push encryption/delivery, subscription cleanup for invalid endpoints, या offer-created event outbox/queue नहीं मिला। इसलिए dashboard subscription save होना **नया काम आने पर वास्तविक push delivery का प्रमाण नहीं** है।
- Electrician page सीधे `srk_push_subscriptions` table पर browser-side upsert/delete करता है। इस branch audit में उस table की authoritative schema/RLS/grants और production Edge Function sender implementation verify नहीं हुई; इन्हें अलग से सुरक्षित तरीके से inspect करना आवश्यक है। कोई table policy या endpoint security assumption नहीं बनाई गई।
- Confirmed gap: offer creation/next-offer dispatch को reliable notification delivery से जोड़ने वाला trusted server-side sender path feature branch में नहीं मिला। इसे पूरा मानना गलत होगा। अगला implementation चरण: subscription table का owner-scoped RLS/RPC contract, server-only VAPID secrets, durable idempotent notification outbox, accepted/expired/declined offer race checks, invalid endpoint cleanup, bounded retry और notification-click से सही offer highlight करना। यह काम feature branch में source-level design/implementation के रूप में होगा; production function deploy या real push send नहीं।
- कोई वास्तविक push notification नहीं भेजी गई, कोई subscription/table mutation, Edge Function deploy, migration apply, booking/payment/refund/payout/wallet mutation, production change या mobile QA नहीं हुआ। Runtime tests भी execute नहीं किए गए।


## 2026-11-15 — Push Notification Click-to-Offer Deep Link Hardening
- Service Worker notification-click path को harden किया: अब arbitrary payload URL नहीं खोला जाता; हमेशा उसी origin/scope के Electrician Dashboard पर navigate होता है। केवल strict UUID-format offerId query parameter के रूप में जोड़ा जाता है।
- Push payload का offerId भी UUID validation के बाद ही notification tag/data में जाता है; malformed ID से कोई offer deep link नहीं बनता। Electrician dashboard में पहले से मौजूद `focusElectricianOfferFromNotification()` query parameter से matching offer card scroll/highlight करता है; अब notification click उससे जुड़ गया।
- Service Worker cache version v7 से v8 किया ताकि updated worker activate होकर पुराने cache को replace करे।
- Existing client source test file में notification route, offerId validation और cache-version contract के assertions जोड़े। Test अभी execute नहीं किया गया।
- Commits: `47c2a07e` (service worker), `ab02b7b6` (source contract test).
- Trusted server-side Push sender, durable outbox/retry, subscription-table RLS proof और invalid endpoint cleanup अभी unresolved हैं। कोई वास्तविक push नहीं भेजी गई, Edge Function deploy नहीं, database mutation/migration apply नहीं, production change नहीं और mobile QA नहीं।


## 2026-11-15 — Push Sender Server-side Revalidation और Production Read-only Evidence
- Production Supabase project का केवल read-only निरीक्षण किया। `push-job-offer` Edge Function पहले से ACTIVE version 4 में है; `job_offers` पर INSERT/UPDATE trigger `private.srk_notify_job_offer_push()` के जरिए Vault secret पढ़कर `net.http_post` enqueue करता है। इसलिए पहले का “sender नहीं मिला” निष्कर्ष सुधारें: sender और trigger मौजूद हैं; कमी sender के authoritative revalidation, durable application-level outbox/retry और branch source parity में है।
- Production `srk_push_subscriptions` पर RLS enabled है और SELECT/INSERT/UPDATE/DELETE policies `auth.uid() = user_id` ownership scope रखती हैं। लेकिन authenticated role को अनावश्यक TRUNCATE, TRIGGER और REFERENCES grants भी मिले; RLS इन table-level privileges को रोकती नहीं। इन्हें migration द्वारा revoke करना बाकी है।
- Production trigger source सीधे Edge Function को HTTP call करता है; अलग application outbox/delivery-attempt ledger/retry worker इस निरीक्षण में नहीं मिला। `net.http_post` request queue अकेले application-level durable retry/visibility का विकल्प नहीं माना गया।
- Production deployed schema में `job_offers.expires_at` और `electrician_profiles.available_for_work` columns इस read-only column inventory में नहीं मिले, जबकि feature-branch sequential dispatch migration `expires_at` और availability checks पर निर्भर है। इसलिए Production Edge Function को branch sender से replace/deploy करना सुरक्षित नहीं; पहले schema/migration alignment और isolated test जरूरी है। कोई deploy या migration apply नहीं किया।
- Feature branch में `supabase/functions/push-job-offer/index.ts` जोड़ा: webhook secret authentication, bounded JSON body, strict payload/UUID validation, send से पहले current offer status/expiry re-read, booking अभी offerable और unassigned है इसकी जाँच, electrician active+approved+available recheck, केवल उसी user की subscriptions पर send, और malformed/404/410 endpoints cleanup। Public GET केवल VAPID public key देता है; private key/service key/webhook secret expose नहीं होते।
- `tests/push-job-offer-sender.test.js` में 6 source-contract assertions जोड़े; test execute नहीं हुआ। Function deploy नहीं हुआ और runtime integration verified नहीं है।
- अभी बाकी: migration से authenticated के TRUNCATE/TRIGGER/REFERENCES revoke; branch में owner-scoped CRUD grants/policies सुनिश्चित; durable idempotent outbox + retry/backoff/dead-letter + delivery audit; production/branch schema alignment; approved isolated environment में end-to-end tests।
- Commits: `c28dd189` (Edge Function source), `b8e16df4` (source tests)।
- कोई वास्तविक Push नहीं भेजी, कोई subscription/database write, production setting change, Edge Function deploy, migration apply, booking/payment/refund/payout/wallet mutation या mobile QA नहीं किया।


## 2026-11-15 — Durable Push Outbox और Subscription Privilege Hardening (Feature Branch)
- Migration `20261115170000_durable_push_delivery_outbox.sql` जोड़ी: `srk_push_subscriptions` पर RLS owner-scoped SELECT/INSERT/UPDATE/DELETE policies पुनःस्थापित; PUBLIC/anon/authenticated के broad grants revoke कर authenticated को केवल आवश्यक CRUD grants दिए। इससे TRUNCATE/TRIGGER/REFERENCES जैसे अनावश्यक table privileges हटते हैं।
- `srk_private.srk_push_delivery_outbox` में प्रत्येक offer के लिए unique outbox record, private grants, attempt count, lease, due time, error और terminal state जोड़े। `job_offers` INSERT पर `offered` row का outbox event enqueue होता है।
- Service-role-only claim/finish RPCs: SKIP LOCKED batch claim, 2-minute lease, max 8 attempts, capped exponential backoff और dead-letter terminal state।
- Netlify scheduled worker `deliver-push-outbox.js` प्रति मिनट अधिकतम 20 events claim करके fixed Edge Function को webhook secret के साथ भेजता और परिणाम दर्ज करता है। Worker config केवल server env से लेता है।
- छह source-contract tests `tests/push-delivery-outbox.test.js` में जोड़े। Tests execute नहीं किए गए।
- Delivery semantics अभी at-least-once हैं: sender partial failure होने पर पूरे offer event की retry होगी, इसलिए पहले सफल subscription को duplicate notification मिल सकती है। Per-subscription idempotent delivery ledger अगला hardening item है; इसे exactly-once delivery न मानें।
- Branch migration Production पर apply नहीं की गई। Production schema audit में branch की `job_offers.expires_at` और `electrician_profiles.available_for_work` columns अनुपस्थित थे; इसलिए schema parity के बिना Edge Function/worker deploy करना अभी निषिद्ध है। Existing Production trigger भी सीधे HTTP enqueue करता है; migration rollout में पुराने trigger के साथ duplicate sends रोकने की अलग योजना आवश्यक है।
- Commits: `87c0f763` (outbox migration), `c383484d` (scheduled worker), `e96c8f11` (source tests), `cccbcd7e` (previous progress), `3c912f1f` (previous checklist)।
- कोई migration apply, Edge Function/Netlify deploy, push send, production config change, database write, booking/payment/refund/payout/wallet mutation या mobile QA नहीं किया।


## 2026-11-15 — Per-subscription Push Delivery Ledger और Schema Parity Audit
- Migration `20261115180000_push_subscription_delivery_ledger.sql` जोड़ी: हर (outbox, subscription) जोड़ी के लिए unique private delivery row, attempt count, lease, retry time, delivered/dead status।
- Service-role-only RPCs target rows को `FOR UPDATE SKIP LOCKED` से claim करते हैं; प्रति subscription अधिकतम 5 प्रयास, capped exponential backoff, और terminal state check उपलब्ध है। Successful subscription deliveries अगली outbox retry में दोबारा claim नहीं होतीं। 404/410 endpoints subscription delete करके cascade cleanup होते हैं।
- Edge sender अब validated outbox ID अनिवार्य करता है, per-subscription delivery ledger से devices claim करता है, हर device का outcome दर्ज करता है और completion RPC के बाद ही `complete=true` लौटाता है। Netlify worker outbox को delivered तभी mark करता है जब सभी targets terminal हों।
- सात source-contract tests `tests/push-subscription-delivery-ledger.test.js` जोड़े। कुल source assertions मौजूद हैं; कोई test execute नहीं हुआ।
- महत्वपूर्ण सीमा: Push provider call के बाद response खो जाने/timeout होने पर delivery ambiguous हो सकती है; ऐसे case में retry duplicate notification दे सकता है। Web Push transport exactly-once guarantee नहीं देता। Ledger confirmed success को repeat नहीं करता, पर ambiguous provider outcome को exactly-once नहीं बना सकता।
- Production Supabase read-only column inventory से पुष्टि: `job_offers.expires_at` अनुपस्थित; branch migration `20261114210000_sequential_nearest_offer_dispatch.sql` इसे जोड़ती है। Production `electrician_profiles.available_for_work` अनुपस्थित; branch migration `20261114310000_electrician_self_availability.sql` इसे जोड़ती है। इसलिए deployed Production schema branch migrations से पीछे है और वर्तमान Edge sender वहाँ deploy-संगत नहीं। अन्य inspected identity columns `electrician_profiles.user_id/auth_user_id` मौजूद हैं।
- कोई migration apply, Edge Function/Netlify deploy, push send, production DB write/config change या mobile QA नहीं किया।
- Commits: `82b185ce` (ledger migration), `058c2cb4` (completion RPC), `fd0cd61c` (Edge sender integration), `51116c3f` (worker), `83c61d22` (source tests)।

- अतिरिक्त source review में malformed subscription delivery target का रास्ता भी harden किया: valid delivery row ID होने पर malformed subscription identity को retry/dead-letter state में भेजा जाता है, ताकि processing lease अनिश्चितकाल तक अटकी न रहे। संबंधित source assertion जोड़ा। Commits: `35993b2c`, `8001829c`।


## 2026-11-15 — Legacy Push Trigger का Duplicate-safe Rollout Audit
- Production Supabase की read-only catalog जाँच में `public.job_offers` पर legacy trigger `trg_srk_push_job_offer` मिला: `AFTER INSERT OR UPDATE`, function `private.srk_notify_job_offer_push()`। यह Vault से webhook secret लेकर सीधे `net.http_post` से Edge Function को पूरा row payload भेजता है; payload में नया `outbox_id` नहीं होता।
- Feature migration `20261115170000_durable_push_delivery_outbox.sql` अब उसी transaction में legacy `trg_srk_push_job_offer` को drop करती है और नया `AFTER INSERT` outbox trigger `trg_srk_enqueue_job_offer_push` बनाती है। इससे दोनों dispatch paths साथ चलने और duplicate sends होने का जोखिम rollout के समय हटता है। Legacy function को rollback/forensic reference के लिए drop नहीं किया गया; उसका trigger हटेगा तो वह निष्क्रिय रहेगा।
- पुराना trigger UPDATE पर भी call करता था; नया outbox केवल नए `offered` INSERT पर एक unique offer row बनाता है। पुराने payload को नए sender द्वारा स्वीकार न करना intentional है, क्योंकि हर sender event को outbox identity चाहिए।
- सुरक्षित rollout runbook (अभी केवल योजना): (1) isolated project में सभी आवश्यक branch schema prerequisites पहले लागू और verify करें—विशेषकर `job_offers.expires_at`, `electrician_profiles.available_for_work`, subscription table और private schema; (2) outbox + per-subscription ledger migrations transactionally apply कर trigger swap verify करें; (3) worker schedule रोककर नई Edge Function और server-only secrets deploy/verify करें; (4) test electrician devices पर एक synthetic isolated offer से single outbox row/single delivery ledger/device count जाँचें; (5) उसके बाद ही scheduled worker enable करें; (6) retries, dead-letter, old-trigger absence और logs monitor करें। Production पर कोई कदम approval से पहले नहीं।
- Rollback में पहले scheduled worker रोकना, फिर trigger swap को explicit reviewed rollback migration से पुराने trigger पर लौटाना होगा; केवल Edge Function rollback पर्याप्त नहीं होगा। Outbox rows और delivery ledger को बिना reconciliation delete नहीं करना है।
- Source-contract assertion जोड़ा कि legacy trigger drop, नए trigger creation से पहले और उसी migration में हो। Commit: `9f72f24d`; test commit: `3d4cfe13`।
- कोई production trigger/DB परिवर्तन, migration apply, Edge Function deploy, worker activation या वास्तविक push नहीं किया।


## 2026-11-15 — Push Migration Preconditions और Isolated Integration Plan
- Production read-only catalog inventory ने पुष्टि की कि subscription table में `id,user_id,endpoint,p256dh,auth` मौजूद हैं; electrician profile में `id,user_id,auth_user_id,active,verification_status` मौजूद हैं। Production में अभी भी `job_offers.expires_at` और `electrician_profiles.available_for_work` नहीं हैं। Production में private schema के अन्य functions मौजूद हैं, पर नई outbox/ledger tables नहीं हैं। कोई write नहीं किया।
- Durable outbox migration में fail-fast preflight जोड़ा: `srk_private`, push subscriptions के आवश्यक columns, `job_offers.expires_at`, `electrician_profiles.available_for_work` और electrician identity/approval columns अनुपस्थित हों तो स्पष्ट exception। इससे migration गलत क्रम/अधूरे schema पर चुपचाप आगे नहीं बढ़ेगी।
- Subscription ledger migration में outbox table और subscription `id/user_id` prerequisite guard जोड़ा। दोनों के source assertions जोड़े।
- `docs/PUSH_DELIVERY_ISOLATED_INTEGRATION_TEST_PLAN.md` में migration order, privilege checks, happy path, multiple devices, replay, partial failure, retry exhaustion, 404/410, no-subscription, stale offer, auth/body validation, parallel claims, worker timeout, monitoring, exit criteria दर्ज किए।
- यह test plan है, executed test report नहीं। Isolated project/Netlify site अभी provision नहीं किए; कोई migration apply, deploy, push या production mutation नहीं हुई।
- Commits: `77c6b476` (outbox preflight), `d58142e6` (ledger preflight), `76fedb8e` (integration plan), `82750f10` (outbox guard assertions), `dc9ba9f2` (ledger guard assertions)।


## 2026-11-15 — Push Retry/Lease Deep Audit
- SQL review में एक terminal-state bug मिला: worker/sender अगर आखिरी allowed attempt पर claim के बाद crash हो जाए तो row `processing` में फँस सकती थी, क्योंकि अगली claim में max-attempt filter उसे छोड़ देता था। अब outbox (8 attempts) और per-device ledger (5 attempts) claim RPC पहले expired exhausted leases को `dead` में बदलते हैं। Null lease भी reclaim/dead-letter logic में शामिल है।
- सभी पाँच SECURITY DEFINER RPC role guards अब `auth.role() IS DISTINCT FROM 'service_role'` हैं, जिससे NULL role भी fail-closed होगा।
- Outbox और device leases 2 से 5 मिनट किए; sequential worker batch 20 से घटाकर 3 किया ताकि serial sender calls का worst-case lease pressure कम हो। यह provisional budget है—isolated environment में वास्तविक duration/load test अभी आवश्यक है।
- Source assertions में exhausted lease recovery, null lease reclaim, service-role fail-closed guards और batch cap जोड़े।
- अभी भी कोई runtime test execute नहीं हुआ, कोई DB migration apply नहीं, कोई Edge/Netlify deployment नहीं, कोई वास्तविक push नहीं।


## 2026-11-15 — Push Worker Gateway Authentication और Regression Assertions

- Netlify Push Outbox Worker अब Supabase Edge Function request पर server-only `apikey` और `Authorization: Bearer` headers भी भेजता है; साथ में अलग `x-srk-push-secret` webhook authentication बनी रहती है। इससे Gateway JWT verification चालू होने पर request के Gateway स्तर पर अस्वीकृत होने का जोखिम संबोधित किया गया।
- Worker test में bounded batch assertion को वर्तमान `p_limit: 3` से मिलाया और Gateway headers के source assertions जोड़े।
- Sender test में malformed/expired subscription cleanup assertion को वर्तमान ledger target shape `target.subscription_id` से मिलाया।
- Commits: `befbd4ef` (worker auth), `4336445d` (worker batch assertion), `3ff43f1d` (sender cleanup assertion), `28b401a9` (gateway auth assertions).
- **सीमा:** यह source-level correction है। Node/Deno tests अभी execute नहीं हुए; Supabase Gateway/JWT behavior, Netlify schedule, provider delivery, retries और isolated integration flow अभी runtime में verify होने बाकी हैं। कोई Production migration, Edge Function deployment, Worker activation या real push नहीं किया गया।


### Push delivery monitoring, failure alerts और dead-letter recovery — 15 November 2026
- [x] Service-role-only health RPC जो Outbox और per-device Ledger के pending/processing/delivered/dead counts तथा oldest pending timestamps देता है; payload, endpoint, user ID या private error text expose नहीं करता।
- [x] Netlify worker structured healthy/degraded logs लिखता है; sender/finish/health failures अलग event names से दर्ज होते हैं।
- [x] Retry, health RPC failure या dead-letter मौजूद होने पर scheduled invocation HTTP 502 लौटाती है ताकि platform-level function monitoring में degraded run दिखे।
- [x] केवल exact dead outbox UUID पर service-role-only manual recovery RPC; delivered device rows को delivered ही रखता है और केवल dead device rows reset करता है।
- [x] Worker monitoring और guarded recovery के source-contract assertions जोड़े।
- [ ] Approved isolated DB में health counts, unauthorized RPC denial, manual recovery state transitions और delivered-row preservation execute/verify करें।
- [ ] Netlify scheduled invocation/log alert integration को test environment में verify करें; alert delivery अभी runtime में प्रमाणित नहीं।
- [ ] Node test suite execute करें; अभी source assertions लिखे हैं, run result नहीं।
 
**Safety boundary:** Health/recovery migration केवल Feature Branch में है; अभी किसी database पर apply नहीं हुई। कोई dead letter वास्तव में requeue नहीं किया, कोई push/provider call, production change, deployment, worker activation या mobile QA नहीं हुआ।


### Final Push Security Audit — Lease Fencing सुधार — 15 November 2026
- [x] Audit में stale-worker race मिला: यदि worker का lease expire हो और दूसरा worker उसी row को reclaim कर ले, तो पुराना worker देर से finish RPC करके नए worker की स्थिति overwrite कर सकता था।
- [x] नया migration `20261115200000_push_delivery_lease_fencing.sql`: Outbox और per-device finish RPC अब claimed `attempt_count` fencing token मांगते हैं; status `processing` और वही attempt count न होने पर stale result reject होता है।
- [x] Netlify worker और Edge sender अब अपने claim response का attempt count finish RPC में भेजते हैं।
- [x] Outbox और per-device fencing के source-contract assertions जोड़े।
- [ ] Node/Deno suite execute करें और concurrent reclaim + stale finish race को isolated DB में चलाकर verify करें।
- [ ] Provider call की transport-level duplicate संभावना बनी रहती है यदि पुराना worker lease expire होने के बाद भी provider request पूरा कर दे; fencing केवल stale DB completion को रोकती है, exactly-once delivery नहीं देती।

**सुरक्षा सीमा:** Migration feature branch पर ही है; अभी apply/deploy नहीं हुई। कोई production mutation, real push, worker activation या mobile QA नहीं किया गया।


## 2026-11-15 — Push RPC signature और fencing payload audit

- Original Outbox finish RPC `(uuid,boolean,text)` और per-device finish RPC `(uuid,boolean,text)` signatures की जाँच की; fencing migration पुराने signatures को ठीक उसी प्रकार drop करके `(uuid,integer,boolean,text)` versions बनाती है और नई signatures पर केवल service_role execute grant करती है।
- Outbox claim RPC `attempt_count` लौटाता है; Netlify worker उसी value को finish RPC में भेजता है। Device claim JSON प्रत्येक target में `attempt_count` देता है; Edge sender के तीनों finish paths उसी token को भेजते हैं।
- Health RPC के `outbox`/`devices` object keys worker की monitoring reads से मेल खाते हैं; referenced timestamp/status columns संबंधित table definitions में मौजूद हैं।
- Regression tests में exact legacy/new RPC signature, service-role grant और sender के सभी finish call paths के fencing-token assertions जोड़े।
- **अभी test suite execute नहीं हुई।** यह source-contract review है, SQL parser/runtime verification नहीं। अगला चरण Node suite चलाना और approved isolated PostgreSQL में migration chain, RPC grants, stale-token rejection, health/recovery transitions तथा concurrent reclaim verify करना है।
- कोई migration apply, production SQL write, Edge/Netlify deployment, worker activation या वास्तविक push नहीं किया गया।


## 2026-11-15 — Fencing RPC false-result acknowledgement correction

- Review में मिला कि नए finish RPC boolean `false` लौटाकर stale worker को reject करते हैं, पर Netlify/Edge callers केवल HTTP/RPC error check कर रहे थे। HTTP success के साथ boolean false आने पर callers गलत तरीके से delivery को acknowledged गिन सकते थे।
- Netlify worker अब finish response JSON को `true` से compare करता है; `false` या invalid body finish failure माना जाता है और retry/degraded monitoring में शामिल होता है।
- Edge sender अब per-device RPC का `data === true` check करता है; rejected stale finish sent count में शामिल नहीं होता। Malformed identity और transient provider failure finish paths भी rejection को failure गिनते हैं।
- दोनों behaviors के source-contract regression assertions जोड़े।
- Runtime Node/Deno tests और isolated SQL concurrency tests अभी execute नहीं हुए। कोई migration apply, production write, deployment या real push नहीं किया गया।


## 2026-11-15 — Push source tests executed in disposable sandbox

- Feature branch `bcf6b91dc6ab641c9684616d0f4f1445500dde96` पर disposable Vercel Sandbox में Node test runner चलाया। तीन Push test files का परिणाम **37/37 PASS** रहा: durable outbox/worker, per-subscription delivery ledger, और Edge sender source-contract assertions।
- पहले targeted run में दो assertions fail हुए थे, implementation नहीं: preflight test `available_for_work` column-name guard के वास्तविक SQL रूप से मेल नहीं खा रहा था; GET config test source में internal variable declarations को response leakage समझ रहा था। दोनों test matchers सुधारे और rerun 37/37 PASS।
- `node --check netlify/functions/deliver-push-outbox.js` सफल।
- Repository-wide `npm test`: **82 passed, 5 failed (87 total)**। शेष failures Push files में नहीं: (1) electrician customer-contact projection assertion, (2) Razorpay refund GET exact stored refund ID assertion, (3–5) three Razorpay refund webhook reconciliation assertions। इन्हें अलग-अलग investigate करना बाकी है।
- Sandbox में Deno और PostgreSQL executables उपलब्ध नहीं थे; इसलिए Edge Function typecheck, SQL parser/apply, RPC grant behavior और concurrent stale-worker reclaim test नहीं चला।
- कोई Supabase database/paid staging branch नहीं बनाया; migration apply, production write, Edge/Netlify deployment, worker activation, provider refund या real push नहीं किया। Disposable test sandbox के अलावा कोई rollout नहीं हुआ।


## 2026-11-15 — Full test suite green और Deno Edge Function check

- Disposable Vercel Sandbox में final feature-branch commit `95c4fc57ab3a8abbb70f0a98e8310ec774eb942c` checkout करके पूरे repository का `npm test` चलाया: **87 tests, 87 passed, 0 failed**।
- Push-specific तीन suites का prior isolated result **37/37 PASS** है।
- Full-suite में मिले पाँच failures code regression नहीं निकले: multiline SQL formatting पर brittle regex; provider refund verification fixture में stored-record identity note गायब; और Razorpay test fixtures में underscore वाले invalid payment IDs। Test assertions/fixtures सही किए; app/backend business logic में बदलाव नहीं किया।
- Deno `check --no-config --no-lock supabase/functions/push-job-offer/index.ts` सफल।
- `node --check` Netlify push worker, Razorpay refund status और webhook handlers पर सफल; final checkout working tree clean।
- अभी भी PostgreSQL executable/local isolated DB उपलब्ध नहीं था; इसलिए SQL migration parse/apply, actual role/grant behavior, claim→finish RPC responses और concurrent stale-worker reclaim runtime test बाकी हैं।
- Disposable sandbox बंद कर दिया। कोई Supabase branch/subscription नहीं बनाया, कोई migration apply, production write, deployment, worker activation, Razorpay provider write या वास्तविक push नहीं हुआ।


## 2026-11-15 — Full Node suite green

- Latest feature-branch snapshot पर `npm test` सफल: **87 passed / 0 failed / 87 total**।
- छह संबंधित security/regression suites का focused run: **55/55 passed**। इनमें contact visibility, Razorpay refund read-only verification, webhook reconciliation, push outbox, per-device ledger और Edge sender source contracts शामिल हैं।
- Netlify push worker JavaScript syntax check (`node --check netlify/functions/deliver-push-outbox.js`) exit code 0।
- पहले के पुराने sandbox snapshot में दिखे पाँच test failures latest branch पर दोबारा नहीं आए; stale checkout/fixture mismatch था। Razorpay refund-status test fixture में provider identity note शामिल किया गया ताकि source के exact identity-match contract को test करे।
- Deno उपलब्ध नहीं था और PostgreSQL tools भी उपलब्ध नहीं थे; Edge Function typecheck तथा migration/RPC runtime/concurrency tests अभी बाकी हैं।
- सभी tests disposable Vercel Sandbox में चलाए गए। कोई Supabase migration apply, production DB write, deployment, real push, refund/provider write, paid staging branch या mobile QA नहीं किया गया।


## 2026-11-15 — PostgreSQL runtime audit में दो Push bugs मिले और ठीक किए

- Disposable Vercel Sandbox में Deno 2.9.8 install करके `deno check --no-config --no-lock supabase/functions/push-job-offer/index.ts` चलाया: **सफल**। Netlify worker `node --check` भी सफल।
- Local throwaway PostgreSQL 18.6 database (`srk_push_isolated`) में minimal Supabase-compatible schema fixture बनाया और Push की चार migrations को क्रम से apply किया: `20261115170000`, `20261115180000`, `20261115190000`, `20261115200000`। चारों migrations `ON_ERROR_STOP` के साथ सफल। यह Supabase hosted project नहीं है।
- पहला वास्तविक RPC claim test एक SQL runtime defect पर fail हुआ: `RETURNS TABLE` के output variable `attempt_count` के कारण outbox claim function में unqualified `attempt_count` ambiguous था। `20261115170000_durable_push_delivery_outbox.sql` में update target alias `o` के साथ `o.attempt_count`, `o.delivery_status`, `o.locked_until`, `o.last_error` qualify किए। Migration re-apply के बाद claim RPC सफल।
- दूसरे logic audit में dead device rows को complete समझा जा रहा था क्योंकि ledger claim/completion केवल pending/processing rows देखते थे। इससे outbox delivered हो सकता और dead device rows operator recovery के लिए inaccessible रह जातीं। `20261115180000_push_subscription_delivery_ledger.sql` में दोनों checks अब हर device को delivered होना अनिवार्य करते हैं; dead rows outbox को retry/dead-letter path में रखती हैं।
- Updated ledger migration local PostgreSQL पर re-apply की; dead-only device state पर claim response `complete:false` और completion RPC `false` मिला। Manual recovery test में dead row `pending` हुई, जबकि पहले से delivered row `delivered` ही रही।
- Runtime tests: offer INSERT trigger ने outbox row बनाई; outbox/device claim→finish सफल; पुराने fencing attempt पर `false`, वर्तमान attempt पर `true`; outbox तथा per-device concurrent claims में दूसरे worker को `SKIP LOCKED` से 0 rows; attempt 8 outbox और attempt 5 device expired leases dead-letter हुए।
- Authorization/RLS tests: `anon` से service-role RPC denied; `srk_private` table direct read denied; authenticated owner को अपनी 2 subscriptions दिखीं, दूसरे user को 0। Health RPC ने सही counts लौटाए।
- Latest branch पर फिर `npm test`: **87 passed / 0 failed**। Deno Edge check और Netlify worker syntax check भी exit code 0।
- Remaining: वास्तविक Supabase managed schema/role parity, Edge↔Netlify scheduled integration, provider-level delivery behavior। इन्हें approved isolated staging पर ही करना है।
- कोई Supabase hosted migration apply, paid branch/subscription, production write, deployment, real push/provider call, refund या mobile QA नहीं किया।

### Repository documentation consistency — 15 November 2026
- [x] `README.md` phone-visibility section corrected to the owner-approved acceptance rule: hide both numbers before electrician acceptance; reveal full numbers to customer and accepted electrician after acceptance; no extra OTP; Admin may see both; Support Staff remains restricted.
- [x] Removed obsolete masked-calling / Exotel requirement and ambiguous assigned-only wording from the active policy section.
- [ ] Continue checking README endpoint and feature descriptions against current source before treating documentation as fully current.
- Commit: `cdb9583e167659f6601effb25ad926d76fa7bfe6` (feature branch only).
- No application behavior, database, production configuration, deployment, merge, or mobile QA changed.


### Customer Dashboard — RPC और Payment source audit (15 नवम्बर 2026)
- Feature Branch `booking.html` के Customer payment/history path में `srk_customer_get_payment_history(integer,integer)` और receipt path `srk_customer_get_payment_receipt(uuid)` की migration definitions मिलीं। Payment-history RPC में `auth.uid()` से booking ownership filter है; receipt RPC की migration में भी authenticated owner-scope दर्ज है। ये source-level निरीक्षण हैं, runtime verification नहीं।
- Refund-history UI अभी `srk_customer_list_booking_refund_requests()` call करता है, जबकि Feature Branch progress evidence में branch migration/UI का नाम `srk_customer_list_my_booking_refund_requests()` दर्ज है। यह वास्तविक नाम-असंगति है; exact migration file path इस fetch में resolve नहीं हुआ, इसलिए अभी blind rename नहीं किया। पहले branch migration chain में function signature/returns की पुनः पुष्टि जरूरी है।
- Booking submit flow `srk_customer_list_my_cancellation_fee_debts()` call करता है; GitHub code search में इस exact function की definition नहीं मिली। साथ ही booking list के अतिरिक्त cancellation fee items के लिए `srk_customer_list_booking_cancellation_fee_items()` भी call होता है, जिसकी definition इस source search में नहीं मिली। इन्हें missing साबित करने के लिए पूरी migration filename/function inventory और fresh isolated schema inspection आवश्यक है।
- Razorpay browser flow `/api/create-order` और `/api/verify-payment` को authenticated access token देता है। Server handlers token को Supabase Auth से validate करके booking के `customer_user_id` और verified phone से मिलाते हैं; create-order में completed booking, online method, amount breakdown, lock claim/release और reusable order checks हैं। verify-payment में HMAC timing-safe compare, Razorpay captured/INR/order/amount verification और new-category booking के लिए service-role settlement RPC है। यह static source review है; provider call या payment mutation नहीं किया गया।
- भुगतान source में कोई production/provider request नहीं भेजी गई। Refund submit/create RPC, refund provider execution caller और cancellation-debt RPC signatures का पूर्ण migration-to-UI parity अभी unresolved है। कोई deployment, database write या mobile QA नहीं हुआ।

**अगला सटीक काम:** Feature Branch की पूरी migration सूची से refund/cancellation-debt function signatures और dependent tables का मिलान; फिर UI RPC नाम/arguments को canonical migration contract से align करना। इसके बाद Admin refund queue/provider caller audit।


### Customer cancellation/refund RPC parity — verified correction (15 नवम्बर 2026)
- Feature Branch की पूरी migration directory listing (54 SQL files) से पहले की “RPC definition नहीं मिली” वाली शंका resolve हुई। `20261114280000_cancellation_fee_carry_forward_and_accounting.sql` में `srk_customer_list_my_cancellation_fee_debts()` और `srk_customer_list_booking_cancellation_fee_items()` दोनों परिभाषित हैं; दोनों केवल `auth.uid()` के matching customer rows लौटाते हैं।
- `20261115100000_customer_refund_request_contract.sql` में `srk_customer_create_booking_refund_request(uuid,text)` और canonical `srk_customer_list_booking_refund_requests()` दोनों मौजूद हैं। Create-request में booking row lock, customer ownership, verified paid booking, immutable labour bill + fully-settled fee ledger reconciliation और duplicate refund checks हैं। History projection Admin private note को expose नहीं करती और customer ownership filter लगाती है।
- Current `booking.html` में refund history call पहले से canonical `srk_customer_list_booking_refund_requests()` है; cancellation debt और fee-item calls भी migration function names से exact match हैं। पुरानी report entries में `srk_customer_list_my_booking_refund_requests()` और missing function claims अब **stale/ superseded** हैं; वे वर्तमान branch snapshot को describe नहीं करतीं।
- ACL review में cancellation-debt और fee-item SQL SECURITY DEFINER projections के लिए explicit revoke/grant statements नहीं थे। Migration में अब दोनों functions से `PUBLIC, anon` execute revoke और केवल `authenticated` grant जोड़ा गया। यह source-level least-privilege correction है।
- `cancellation_fee_refund_reversal.test.sql` में दो pgTAP privilege assertions जोड़े और plan 40 से 42 किया: authenticated को EXECUTE मिले तथा anon/PUBLIC को न मिले। अभी SQL/pgTAP runtime execute नहीं हुआ; assertions committed source हैं, passing runtime test नहीं।
- Refund contract migration भी मौजूद है; पहले report में referenced `20261113235900_harden_customer_cancellation_and_safe_refund_history.sql` path current branch में नहीं है। सही current branch path `20261115100000_customer_refund_request_contract.sql` है।

**Verified source commits:** migration ACL correction `f4fc34e`; pgTAP assertions `298e068`. कोई Production migration apply, database write, real refund/provider request, deployment या mobile QA नहीं किया गया।


### Admin Refund Queue / Provider Recovery audit — 15 नवम्बर 2026
- Admin review migration `20261115110000_admin_refund_review_queue_and_decisions.sql` source inspected: list/decision RPCs call `is_srk_admin()`, use empty search_path, lock request row, enforce allowed state transitions and require a bounded audit note. Approval itself does not call a payment provider or mutate booking payment status.
- Razorpay refund initiator, read-only provider status lookup, and durable recovery handler inspected. Initiator verifies Supabase user + Main Admin, obtains server-computed full-refund amount, retains payout hold on ambiguous outcomes, validates provider refund identity/amount/currency/status, and reconciles through service-role RPC. Status lookup is read-only and treats first-page non-match as inconclusive. Recovery verifies Main Admin, exact payment/refund identity, stores append-only provider evidence, then finalizes in a separate DB transaction only for fresh `processed` evidence while payout remains blocked.
- **Found a missing manual-refund completion path:** Customer refund-request contract permits verified manual-payment bookings, but Admin queue offered only the Razorpay action; the existing `srk_admin_record_manual_refund` RPC did not transition an approved Customer request to `processed`. This could leave an already-refunded manual booking displayed as an approved/unresolved request.
- Added `20261115130000_admin_manual_refund_request_completion.sql`: replaces the Main-Admin-only manual refund RPC to lock and require an approved Customer request when one exists, validate matching manual payment audit, reject Razorpay-linked bookings, record actual external refund reference, mark booking refunded (triggering fee/wallet reversal), and atomically mark approved Customer request processed. It never sends money or calls a provider.
- Updated Admin refund queue: approved Razorpay-linked requests use the Razorpay workflow; approved non-Razorpay requests now show manual refund receipt/UTR and optional note fields, with explicit confirmation that actual refund must already have been sent before recording. The request status refreshes after successful RPC. Razorpay action now passes reason through escaped data attributes rather than inline JavaScript string concatenation.
- Added `supabase/tests/database/admin_manual_refund_request_completion.test.sql` (8 pgTAP assertions) for Main Admin enforcement, request lock/approval, processed transition, manual payment audit, Razorpay exclusion and grants. Static source count is 8/8 assertions matching plan; **pgTAP runtime not executed**.
- Admin review pgTAP file has 16 assertions matching plan 16; durable recovery pgTAP file has 34 assertions matching plan 34. These were source-count checks only, not executed tests.
- No real manual refund, Razorpay request/GET, webhook, payout/wallet mutation, Production database apply, deployment, merge, or mobile QA was performed. Runtime migration/pgTAP and provider sandbox integration remain pending.

**Feature Branch commits:** manual-refund migration `29da3e0`; Admin queue manual workflow `a8f41f9`, safe data-attribute reason passing `b4b1cd2`; pgTAP test `629574e`. Inline quoting follow-up `4acf07f` was superseded by the safer data-attribute implementation.

- CI status snapshot for the latest checklist commit `88cc7e7`: Vercel status is `failure` with target URL indicating `upgradeToPro=build-rate-limit`. This is a Vercel build-rate-limit/account-plan blocker, not evidence of an application test failure; no successful deployment/build verification is claimed. Recheck CI when build capacity is available.


### Razorpay refund webhook compatibility + manual payment guard — 15 नवम्बर 2026
- Official Razorpay refund webhook documentation/sample payload reviewed: `refund.created` event's sample refund entity can already have `status: "processed"`; event name alone does not guarantee `pending` status.
- Found compatibility defect in `razorpay-webhook.js`: code previously required `refund.created => pending`, so a valid signed processed refund-created payload would be permanently marked ignored by the durable inbox. Corrected accepted states: `refund.created` accepts `pending` or `processed`; `refund.processed` still requires `processed`; `refund.failed` still requires `failed`. Actual verified entity status is passed to the service reconciliation RPC.
- Added a Node test covering the documented `refund.created + processed` case, exact payment/amount reconciliation and inbox completion. Test source is committed; Node runtime not executed in this environment.
- Additional guard found in the manual refund path: the previous RPC rejected Razorpay only when provider order/payment IDs existed. A malformed or incomplete online booking could have missing IDs yet still be classified as manual. Updated the Main-Admin-only RPC to also reject payment methods containing `online` or `razorpay`; Admin UI now displays manual refund entry only for explicit non-online/non-Razorpay methods with no Razorpay payment ID.
- Expanded manual refund pgTAP source test from 8 to 9 assertions; plan and assertion count match 9/9. Runtime not executed.
- Commits: webhook compatibility fix `7a5cf82`; webhook test `60eeeb6` + assertion cleanup `8e3c185`; manual payment guard migration `146fd37`; UI guard `80c57ee`; pgTAP assertion `3ce9541` and SQL quoting correction `c8ea217`.
- No provider request, real refund, webhook delivery, database apply, payout/wallet mutation, deployment, merge, or mobile QA was performed.


### Admin payout / portal role-isolation source pass — 15 नवम्बर 2026
- Reviewed Admin payout UI and `20261114360000_new_category_electrician_payout_reconciliation.sql` Main Admin RPC. It locks booking before payout, accepts only pending payout rows, requires completed + verified-paid booking, checks assigned electrician, immutable labour bill, manual payment audit or exact Razorpay payment identity, separately reconciles cancellation-fee items, and recalculates commission/payable amounts before recording UTR/UPI/bank payment. No source-level bypass was found in this pass; no payout was recorded.
- Verified Admin portal role routing: `showState()` authorizes Main Admin via `is_srk_admin()`; otherwise it requires a registered Support Staff session and explicit `support.customer.read` permission. Staff mode loads only the assigned Support inbox and does not invoke Main Admin `loadAll()`; Main Admin-only panels are hidden in Staff mode. This is source review, not runtime role testing.
- JavaScript parse-only checks through the code runtime: `razorpay-webhook.js` PASS, `tests/razorpay-webhook-inbox.test.js` PASS, Admin inline script PASS. These are syntax checks only; no Node test execution or browser/mobile runtime QA claimed.
- Remaining Admin portal areas for next audit: booking direct-update boundaries and legacy payment recording, KYC/application approval and rate-tier activation, electrician profile/availability, support assignment/thread ACL, cancellation decision + fee ledger, wallet/commission projections, payout runtime race/reversal scenarios.


### Electrician KYC document lifecycle और Admin activation gate — 15 नवम्बर 2026
- Admin और Electrician UI audit में वास्तविक migration-to-UI gap मिला: दोनों portals KYC submit/list/admin queue/review RPCs call कर रहे थे, लेकिन Feature Branch migration inventory में KYC document table, event history, bucket/policies, submit/list/admin review RPCs और `srk_admin_set_electrician_active(uuid,boolean)` definition नहीं थी। Existing `20261114330000_electrician_private_kyc_document_preview.sql` केवल owner path lookup function define करता था और एक not-yet-created document table को reference करता था।
- Added `20261115140000_electrician_kyc_review_and_activation_gate.sql`: private 5 MB PDF/JPG/PNG Storage bucket; owner-only upload path; owner/Admin signed-preview read policy; unregistered own-object cleanup; private KYC document table and append-only audit events; electrician submit/list RPCs; Main Admin-only queue/review RPCs; 60-second preview-compatible storage ACL.
- Activation safety: latest identity proof और address proof दोनों approved होने चाहिए; optional skill certificate activation की अनिवार्य शर्त नहीं. Supabase Auth phone OTP confirmation, linked Auth/Profile IDs, Main Admin-approved rate tier और approval metadata भी आवश्यक हैं. Direct profile-table writes पर trigger gate लगाया ताकि UI/RPC bypass करके भी incomplete KYC पर Active न किया जा सके.
- Rate-tier audit trigger को भी मजबूत किया: latest identity/address documents approve हुए बिना audited rate-tier RPC भी fail closed होगा. Application approval अब भी profile को inactive रखता है; KYC और rate-tier approval के बाद ही Active संभव.
- Admin KYC review में required latest proof reject/needs-resubmission होने पर active partner को deactivate किया जाता है, availability बंद होती है, unaccepted offers decline होकर next sequential eligible electrician को advance होते हैं; accepted bookings unassigned नहीं की जातीं. Availability event audit भी दर्ज होता है.
- Added `supabase/tests/database/electrician_kyc_review_and_activation_gate.test.sql`: 21 pgTAP source assertions; plan/assertion count 21/21. SQL/pgTAP runtime अभी execute नहीं हुआ.
- Source syntax checks: Admin inline script PASS और Electrician inline script PASS. ये parse-only checks हैं; browser/storage/OTP/DB runtime tests नहीं.
- Feature Branch migration current blob `3b6f6f2`; KYC pgTAP current blob `3e53664`. No Production migration apply, Storage bucket change, real KYC upload/review, activation, deployment, merge, or mobile QA.
- Runtime isolation, private bucket policies, Admin-vs-Staff authorization, KYC review races, dispatch advancement, and activation end-to-end verification remain pending.


### Admin cancellation decision null-input hardening — 15 नवम्बर 2026
- Cancellation Admin RPC audit found a SQL three-valued-logic edge case: `IF p_decision NOT IN (...)` does not reject NULL; a NULL decision could fall through the `ELSE` branch and be treated as a rejection. Added explicit `p_decision IS NULL` guard.
- Added explicit `p_verified_stage IS NULL` rejection for approved cancellations, rather than relying on later table constraints to roll back.
- Expanded cancellation-fee/refund pgTAP source plan from 42 to 44; assertion count matches 44/44. Runtime not executed.
- Commits: cancellation RPC fix `e26889b`; pgTAP additions `086f541`.
- No booking cancellation, fee creation, wallet/payout mutation, database apply, or production action occurred.


### Razorpay refund.created terminal-status compatibility fix — 15 नवम्बर 2026
- Provider/webhook source audit में एक वास्तविक regression पकड़ा: `refund.created` payload का `status=processed` स्वीकार करने के लिए event/status mapping बदली गई थी, लेकिन reconciliation error-note में पुराना `expectedStatus` identifier रह गया था. इससे उस valid payload पर ReferenceError और webhook retry होता.
- पुराने identifier को हटाकर signed और validated refund entity के `refund.status` से failure note तय किया; `refund.created` में `pending` और `processed` स्वीकार हैं, जबकि `refund.processed`/`refund.failed` की pairing strict है.
- Regression test जोड़ा: processed status वाले `refund.created` payload को exact payment ID, refund ID और paise amount के साथ reconcile होना चाहिए.
- Commits: webhook compatibility `7a5cf82`, regression test `60eeeb6`, test assertion cleanup (branch history), undefined-variable correction `fdead4c`.
- JavaScript parse-only check: `razorpay-webhook.js` PASS; `tests/razorpay-webhook-inbox.test.js` PASS. यह Node test execution नहीं है; webhook inbox suite runtime अभी नहीं चला.
- No Razorpay API call, real refund, database apply, production deploy, merge, or mobile QA.
- शेष runtime verification: signature/replay/duplicate delivery, provider event ordering, retry after ambiguous RPC/network outcome, Main Admin/Support Staff authorization, and database reconciliation transaction tests in isolated environment.


### Admin Portal — generic booking completion guard — 15 नवम्बर 2026
- Admin Portal के generic booking Save path में एक high-impact workflow gap मिला: Main Admin किसी unfinished legacy booking को सीधे `completed` चुनकर save कर सकता था. इससे सामान्य status update के रास्ते completion-linked commission/accounting triggers चलने का जोखिम था, बिना संबंधित trusted completion workflow के.
- `admin.html` में guard जोड़ा: unfinished booking को generic Save path से Completed नहीं किया जा सकता; existing already-completed record को unchanged save करने का path बंद नहीं किया.
- `tests/admin-refund-and-staff-access.test.js` में source regression assertion जोड़ा.
- यह UI-layer hardening है, database authorization/trigger replacement नहीं. Backend completion RPC और trigger invariants की अलग source audit तथा isolated runtime test अभी बाकी हैं. JavaScript/Node test suite का runtime execution इस change के लिए अभी नहीं किया गया.
- No booking status update, commission/payout mutation, DB apply, deployment, merge, or mobile QA.


### Admin backend — legacy booking status एवं manual payment audit — 15 नवम्बर 2026
- `20261109003000_secure_commission_reporting.sql` authenticated role को `service_bookings(status, quoted_amount, amount_paid, payment_status)` column UPDATE grant देता है. नया-category guard केवल `selected_category IS NOT NULL` booking पर लागू है; legacy booking status को direct Admin table update से रोकने वाला समान DB guard इस inspected migration chain में नहीं मिला.
- Legacy `srk_update_booking_work_status` SECURITY DEFINER RPC electrician ownership और सीमित transition जाँचता है, लेकिन legacy direct UPDATE grant रहते हुए केवल RPC होने से bypass बंद नहीं होता. `srk_submit_booking_quote` और customer quote-response भी status बदलते हैं; सुरक्षित DB guard जोड़ने से पहले इन सभी trusted paths को transaction-scoped authorization से map करना आवश्यक है.
- Admin UI `srk_admin_record_manual_payment` और `srk_admin_record_new_booking_cash_payment` RPC call करता है, लेकिन इन दोनों function definitions को उपलब्ध 56 migration files तथा GitHub code search में locate नहीं किया जा सका. इसलिए payment amount matching, duplicate protection, Main Admin authorization, receipt/reference validation और audit atomicity अभी प्रमाणित नहीं हैं. इसे release-blocking source gap माना गया है; अनुमान से function या migration नहीं बनाया.
- `srk_booking_labour_bills` immutable bill trigger में authorized completion workflow, customer completion request, stopped server timer और approved rate snapshot की checks मौजूद हैं. लेकिन legacy completion path की अलग DB authorization और old commission trigger coupling अभी end-to-end map नहीं हुई.
- Electrician Portal के customer-approved work-start/completion, quote, offer-response, availability, KYC, support और push flows के source hooks मौजूद; inline JavaScript syntax PASS. यह runtime/browser/database test नहीं.
- कोई migration apply, payment entry, booking mutation, deployment, merge या mobile QA नहीं किया. अगला कार्य: manual-payment RPC का authoritative source खोजना/पुनर्स्थापित करना और legacy status updates के लिए सभी valid trusted transitions map करके database guard + regression tests बनाना.


### Follow-up — manual payment RPC और legacy/new booking guard पुनःसत्यापन — 15 नवम्बर 2026
- सभी 56 migrations दोबारा inspect करने पर पिछली खोज की एक गलती मिली: `srk_admin_record_new_booking_cash_payment(uuid,text,text)` की authoritative definition `20261114280000_cancellation_fee_carry_forward_and_accounting.sql` में मौजूद है। यह Main Admin guard, booking row lock, completed + assigned + cash-only booking, Razorpay exclusion, immutable labour bill और reserved cancellation-fee का exact paise total, unique manual-payment entry, payment evidence, तथा cancellation-fee electrician-wallet debit/SRK ledger settlement एक transaction में करती है। PUBLIC/anon EXECUTE revoke और authenticated grant है; body में Main Admin check भी है। Runtime role/concurrency tests अभी बाकी हैं.
- `srk_admin_record_manual_payment` की authoritative definition अभी भी feature-branch migrations में नहीं मिली; इसे legacy quote-based booking path का अलग release blocker मानें। पुराने निष्कर्ष में दोनों RPC missing कहना गलत था.
- `20261109003000_secure_commission_reporting.sql` authenticated को `service_bookings(status, quoted_amount, amount_paid, payment_status)` UPDATE grant देता है. New-category trigger `srk_guard_new_category_booking_status_transition` केवल selected_category वाली bookings को protected authorization workflow तक सीमित करता है; legacy rows इस trigger gate से बाहर हैं.
- New-category completion path में `srk_customer_respond_work_completion` transaction-scoped `work_transition_authorizations` से status completed करता है, immutable labour bill trigger उसी authorization और stopped timer/customer approval verify करता है. Legacy `srk_update_booking_work_status` अलग SECURITY DEFINER path है और legacy status direct update privilege के रहते database-level bypass अभी खुला है.
- अभी कोई broad trigger patch नहीं जोड़ा: legacy Admin status dropdown के हर supported transition और electrician/customer/admin RPC ownership/authorization map को पूरा करके ही सुरक्षित narrow guard बनाया जाएगा.
- Admin और Electrician inline JS syntax checks PASS; यह SQL runtime/browser test नहीं. No database apply, manual payment, booking mutation, deployment, merge or mobile QA.


### Legacy booking status transition map — source audit follow-up — 15 नवम्बर 2026
- सभी 56 migrations में `service_bookings` status writes, triggers और direct UPDATE grant का targeted scan किया। New-category trigger `srk_guard_new_category_booking_status_transition` केवल `selected_category IS NOT NULL` वाली rows को gate करता है; उसका authorization check `work_transition_authorizations`, accepted offer और approved cancellation context पर निर्भर है। यह legacy rows को cover नहीं करता.
- Legacy electrician workflow के वैध transitions: `srk_update_booking_work_status` में assigned → inspection, quote_approved + quote_status approved → in_progress, और in_progress → completed; `srk_submit_booking_quote` assigned/inspection/quote_rejected → awaiting_quote_approval; customer RPC `srk_customer_respond_booking_quote` awaiting_quote_approval → quote_approved/quote_rejected. ये SECURITY DEFINER RPCs actor/ownership checks करती हैं, पर मौजूदा broad column grant direct UPDATE bypass को अलग से बंद नहीं करता.
- Assignment workflow: accepted offer दर्ज होने के बाद `srk_respond_to_offer` booking को assigned करता है; पुराने Admin offer RPC/dispatcher path को अलग से exact actor and transition contract के साथ verify करना बाकी है. Dedicated cancellation RPC approved request context के बाद cancelled करता है; cancellation trigger direct unapproved cancellation को रोकता है.
- Admin UI generic Save में legacy booking status choices `new/confirmed/assigned/in_progress/completed` हैं; सामान्य Save अब नए completion और cancellation को रोकता है, लेकिन legacy rows पर direct `status` UPDATE अभी भी source-level privilege risk है. Selected-category rows के status/rate direct UI edits भी block हैं.
- सुरक्षित implementation अभी रोककर रखा: सभी legacy assignment/confirmation/quote/cancellation/admin transitions को transaction-scoped authorization में migrate किए बिना broad trigger लगाने से वैध flow टूट सकता है. अगला कदम legacy Admin status editor को सुरक्षित RPC transitions में बदलना और फिर DB trigger को exact per-transition authorization से जोड़ना है.
- Verification boundary: migration source scan और Admin UI source review; कोई DB apply, role/JWT runtime, browser test, booking/payment mutation, deploy, merge या mobile QA नहीं हुआ.


### Legacy booking status direct-write guard — implementation source added — 15 नवम्बर 2026
- नई migration `20261115160000_legacy_booking_status_write_guard.sql` जोड़ी: authenticated clients से `service_bookings` पर table-wide UPDATE revoke किया; केवल मौजूदा Admin quote/payment columns का explicit grant रखा, `status` direct update privilege नहीं दिया.
- नया SECURITY DEFINER RPC `srk_admin_confirm_legacy_booking(uuid)`: Main Admin check, booking row lock, केवल `selected_category IS NULL`, `status='new'`, no assigned electrician, no paid/refunded state और no Razorpay IDs; केवल `new → confirmed` transition करता है. Empty search_path, PUBLIC/anon revoke और authenticated EXECUTE grant.
- Admin generic Save अब status column सीधे update नहीं करता; quote राशि अलग update होती है और legacy `new → confirmed` के लिए dedicated RPC call होता है. अन्य status बदलाव Admin generic Save से अस्वीकार हैं; assignment, electrician work/quote, customer quote response और cancellation अपने SECURITY DEFINER workflows पर निर्भर रहते हैं.
- Regression assertions `tests/admin-refund-and-staff-access.test.js` में जोड़े; pgTAP `supabase/tests/database/legacy_booking_status_write_guard.test.sql` plan 9 (1 function check + 8 source/ACL checks) जोड़ा.
- Source verification: Admin inline JS syntax PASS; Node regression test file JS syntax PASS; migration source and UI path inspected. **Node test suite और pgTAP runtime अभी execute नहीं हुए**; कोई DB apply नहीं हुआ. Existing RPCs के runtime behavior/role permissions और production schema parity अभी verify बाकी हैं.
- Legacy `srk_admin_record_manual_payment` अभी missing है; उसका सही amount/commission/material/cancellation accounting contract पूरा verify किए बिना implementation नहीं जोड़ी.
- No production migration apply, booking/payment mutation, provider call, deploy, merge or mobile QA.


## 2026-11-15 — Legacy manual payment gap closed in feature-branch source

- Master Checklist के पुराने legacy Admin manual-payment blocker को दोबारा source से verify किया: Admin UI `srk_admin_record_manual_payment(uuid,text,text,text)` call कर रही थी, लेकिन migration chain में definition नहीं थी। अब नई migration `20261115210000_legacy_manual_payment_and_itemized_receipt.sql` में उसी signature का Main-Admin-only SECURITY DEFINER RPC जोड़ा।
- RPC केवल legacy booking पर चलता है: booking Completed, electrician assigned, customer-approved quote, labour/material breakdown present, exact quote total, valid commission rate; केवल unpaid/pending state; no payment verification timestamp; no Razorpay order/payment IDs. Booking row lock, bounded Cash/UPI/Bank Transfer method, 4–120 character receipt/UTR, 250-character note, unique manual-payment ledger entry और server timestamp शामिल हैं।
- Accounting: `amount_paid = service_charge + materials_amount`; platform commission केवल labour/service_charge पर; electrician payout row में labour, materials, commission और net payable अलग-अलग सुरक्षित। Existing conflicting/non-pending payout mismatch पर पूरा transaction fail/rollback होता है। New-category booking अपने dedicated cash-settlement RPC पर ही रहती है।
- Customer payment receipt का legacy contract ठीक किया: अब paid amount और approved quote total को labour + materials से reconcile करता है और receipt में `labour_amount` तथा `materials_amount` अलग लौटाता है। New-category immutable labour/cancellation-fee receipt path यथावत रखा।
- Admin booking table में labour/materials/quote-status का अलग data column जोड़ा; approved quote का total इन दोनों मदों के योग से अलग हो तो Save रोकता है और approved quote की रकम सीधे बदलने नहीं देता।
- Added `supabase/tests/database/legacy_manual_payment_and_itemized_receipt.test.sql`: pgTAP plan 18, source assertions 18/18. यह assertion-count/source review है; PostgreSQL pgTAP runtime अभी execute नहीं हुआ।
- Admin inline JavaScript parse check PASS. Migration SQL अभी किसी database पर apply नहीं हुई; Node/pgTAP runtime, role/JWT, payout trigger and receipt end-to-end checks pending. No payment, booking mutation, provider call, production write, deployment, merge or mobile QA.
- Commits: migration `75f831b`, fail-closed state correction `5019379`, pgTAP `6010327` + assertion correction `ea92edd`, Admin quote guard `5da117d`, Admin itemized breakdown `6d00474`.


## 2026-11-15 — Master Checklist को एक authoritative tracker में consolidate किया

- पुरानी 451-line checklist में 78 unchecked entries थीं; इनमें कई पुराने Push implementation items और एक ही final QA/approval gate अलग-अलग addenda में दोहराए गए थे। इन्हें progress history से मिलाकर duplicate नहीं दोहराने वाली 114-line authoritative Master Checklist बनाई। अब 23 स्पष्ट, non-duplicated open gates हैं; इनमें मुख्यतः founder portrait/Welcome Screen, non-Push runtime verification, managed Push parity/integration, अंतिम source consistency और owner approval हैं।
- Push implementation/runtime के verified items और legacy manual-payment implementation को checklist में complete किया; local PostgreSQL Push runtime तथा Node/Deno results का evidence boundary भी दर्ज किया। Production apply/deploy/merge/mobile QA को pending/approval-gated ही रखा।
- Legacy payment follow-up commits के बाद final migration state: `20261115210000_legacy_manual_payment_and_itemized_receipt.sql` (last correction `0e6b01d`); pgTAP file plan/assertion count 18/18; Admin inline JavaScript parse PASS. SQL/pgTAP runtime अभी नहीं चला।
- Master Checklist commit: `992ca92`; stale missing-RPC wording correction: `8adf5ca`; progress log commit this section.


### Verification boundary clarification — latest legacy-payment commits

- Current Admin inline JavaScript syntax: PASS. Legacy manual-payment pgTAP file plan/assertion count: 18/18; this is source/count validation only, not a pgTAP runtime pass.
- The full Node suite result 87/87 belongs to the earlier disposable-sandbox checkout documented above; it has **not yet been rerun after** the latest legacy-payment migration and Admin itemized-breakdown commits. Do not attribute 87/87 to current HEAD until rerun.
- Current Master Checklist is 114 lines with 23 unique, non-duplicated open gates; it was updated to distinguish implementation from runtime/approval gates. Latest checklist evidence commit: `0bdc615`.


## 2026-11-15 — Main Supabase DB बनाम Master Checklist: read-only reconciliation + one orphan cleanup

- Main project को नाम से verify किया: Srk electranic, ref gnqhoaqatmoiwwhgzkgm, PostgreSQL 17.11, ACTIVE_HEALTHY. SRK ELECTRONIC TEST अलग project है; इस cleanup में उसे छुआ नहीं।
- Main DB inventory: 25 public business tables + 2 srk_private tables; 81 prior migrations before cleanup; two deployed Edge Functions; one private electrician KYC bucket. Catalog tables, columns, foreign keys, RLS, policies, triggers, functions, migration history, extensions and function dependency/statistics inspected.
- One confirmed orphan removed: public.accept_electrician_job(uuid). No caller in current Customer/Admin/Electrician pages, all 10 Netlify functions, or both deployed Edge Functions; no dependent database object; pg_stat_statements showed only DDL history; execute ACL was limited to postgres/service_role. Dropped without CASCADE; verification to_regprocedure(...) IS NULL. Main migration version generated by Supabase: 20261115091906, name retire_unused_legacy_accept_electrician_job. Matching migration file aligned to exact applied version in Feature Branch: supabase/migrations/20261115091906_retire_unused_legacy_accept_electrician_job.sql.
- No other table/column/trigger/policy/function was deleted. services, states/its sequence, Supabase storage.* internals, KYC bucket, financial ledgers, payment locks, route transfer and wallet bank-link structures were retained: names/empty row counts alone do not prove they are extra; several are referenced by FKs, audit or server settlement paths. Available-but-uninstalled extensions were not touched; installed pg_net/pgcrypto/uuid-ossp/pg_stat_statements/Vault were retained.
- Main DB is behind Feature Branch, not bloated: saved customer profile/address and support message tables, immutable labour bill, cancellation-fee ledgers, durable refund recovery evidence, new KYC document event table, durable Push outbox/per-device ledger, job_offers.expires_at, electrician_profiles.available_for_work, latest legacy status guard and itemized manual-payment/receipt migration are missing from actual Main schema. Main has the older direct job-offer push trigger; do not roll out durable outbox until duplicate-safe worker/trigger sequencing is prepared.
- Main production DB manual-payment function exists but is an older definition; it is not the latest Feature Branch labour/material/commission/receipt implementation.
- Updated Master Checklist with explicit DB audit, deleted object, retained objects and missing schema list. Master Checklist commit: 25b7602. Cleanup source migration alignment commits: 23a7912 / bc14363.
- No rows, customer bookings, payment records, wallet balances, Auth users, KYC documents, storage files, secrets, extension, table, column, trigger, or policy were deleted or mutated. Only the single confirmed orphan function was dropped. No other Production change, deployment, provider call or mobile QA.


### Main DB audit addendum — second checklist-extraneous object removed

- Rechecked Razorpay Route ledger as a potential out-of-scope object. `public.srk_route_transfers` had 0 rows; no current Customer/Admin/Electrician HTML, any of the 10 Netlify functions, or either deployed Edge Function referenced it; no dependent app function/trigger was found; pg_stat_statements showed only DDL and count/audit reads, no transfer inserts/updates. The approved checklist uses Admin-controlled payout recording and does not implement automatic Razorpay Route split transfers.
- Removed the table with `DROP TABLE` (no CASCADE); verified `to_regclass('public.srk_route_transfers') IS NULL`. No payment/payout/wallet data was present or deleted. Migration version generated by Main Supabase: `20261115092149`, name `retire_unused_razorpay_route_transfer_ledger`; matching Feature Branch migration: `supabase/migrations/20261115092149_retire_unused_razorpay_route_transfer_ledger.sql` (commit `cd6e58c`).
- The earlier progress paragraph saying route-transfer ledger was retained is superseded by this addendum. Retained `srk_wallet_bank_links` because Electrician Portal references it and wallet summary reports verified bank-link counts.
- Current confirmed cleanup total: one orphan function + one zero-row future-only Route ledger table. Latest Production migration version: `20261115092149`. Updated checklist commits: `a3a3e87`, `a3c377b`.


## 2026-11-15 — GPT-2 repository follow-up: migration collision, Route retirement alignment, and secret-free CI

- PR #8 source audit found two Feature Branch migrations with the identical version prefix `20261115130000`: manual refund completion and read-only accounting reconciliation. Reconciliation depends on the refund, cancellation-fee, labour-bill, payout and manual-refund schema already established by earlier migrations, so it was moved after those dependencies to `20261115150000_admin_readonly_booking_accounting_reconciliation.sql`. The duplicate-version source file was removed from the branch.
- The reconciliation report and its pgTAP contract were still querying `public.srk_route_transfers`, although the Main DB audit had already confirmed that table was retired in Production at migration `20261115092149`. Removed Route-only calculations/assertions from the source report and contract. The contract now declares and contains 45 assertions. This is source/count validation only; pgTAP runtime has not been executed.
- Added `.github/workflows/node-tests.yml`: Node 20, pull-request/manual trigger, read-only contents permission, no secrets, no database connection, no deploy. This gives PR #8 a safe path to run the repository Node suite on a subsequent PR event. The new workflow has not yet been observed running; no test result is claimed.
- Reconciled stale Founder/Welcome checklist wording against current branch source: `assets/srk-founder.jpg` exists, `welcome.html` references it, and `index.html` redirects to the welcome page. Exact binary-to-owner-approved portrait visual match and Preview/owner acceptance remain unverified and pending.
- Existing `.github/workflows/supabase-schema-ci.yml` remains unsuitable for current validation: it is guarded to an obsolete branch and hardcodes only five old migrations. It was not triggered or modified; do not treat it as current branch DB verification.
- Changes committed on Feature Branch only. No Production schema/data, Auth, Storage, provider, booking, payment, payout, customer data, deployment, PR merge, or go-live action was performed. PR #8 remains unmerged.

## 2026-11-15 — GPT-1 Customer/Electrician phone-visibility regression coverage

- Customer और Electrician source flow को दोबारा पढ़ा: Electrician offer-details RPC में ग्राहक का नाम, फोन, पता और coordinates केवल उसी verified/active electrician को लौटते हैं जिसका ID booking के assigned_electrician_id से मेल खाता है। Unassigned offer में ये निजी fields NULL रहते हैं; Portal भी assignment से पहले “ग्राहक का विवरण…” placeholder दिखाता है।
- Customer direct-call lookup RPC authenticated user की auth.uid() पहचान लेकर केवल उसी customer की bookings पर चलता है जिनमें electrician assigned है; public/anon EXECUTE revoke और authenticated grant मौजूद हैं। Customer page सीधे booking row से electrician phone नहीं पढ़ता, बल्कि scoped RPC का उपयोग करता है।
- इस owner-approved rule (acceptance से पहले दोनों पक्षों के phone छिपे; assignment/acceptance के बाद दोनों को full number) के लिए regression test जोड़ा: tests/customer-electrician-phone-visibility.test.js.
- Latest Feature Branch Node workflow run 43704226538: **90 PASS / 1 FAIL**. दोनों नए phone-visibility regression tests PASS हुए। एक शेष suite failure GPT-2/Admin scope का missing source file है: supabase/migrations/20261115130000_admin_readonly_booking_accounting_reconciliation.sql; test tests/admin-commission-report-labels.test.js इसे पढ़ना चाहती है। इसे Admin/Accounting owner से reconcile करना होगा; GPT-1 ने उस migration को नहीं बदला।
- यह Node CI source-level suite है, live Supabase/browser/OTP runtime test नहीं। No production DB change, real SMS/OTP, booking/payment mutation, deployment, PR merge, or mobile QA.

## 2026-11-15 — Customer/Electrician OTP login regression audit (GPT-1)
- Customer OTP login source reviewed: Indian mobile normalization, Supabase SMS OTP request/verification, resend cooldown, busy-state guard, existing-session redirect to Customer Dashboard.
- Electrician OTP login source reviewed: phone normalization, SMS OTP request/verification, 60-second resend cooldown, auth-state-driven portal visibility.
- Added `tests/customer-electrician-otp-login.test.js` for these flows and Customer dashboard session gating.
- CI run `43704591567` on commit `fe90915`: **93 PASS / 1 FAIL**. All 3 newly added OTP/session regression tests PASS. Remaining single failure is GPT-2/Admin scope: missing `supabase/migrations/20261115130000_admin_readonly_booking_accounting_reconciliation.sql` referenced by `tests/admin-commission-report-labels.test.js`.
- No Customer/Electrician source defect requiring modification was established by this focused audit; no production configuration, database, deploy, or PR merge was changed.


## 2026-11-15 — GPT-2 accounting/UI regression correction and first green Node CI

- Feature Branch Node CI की असफलता का वास्तविक कारण मिला: `tests/admin-commission-report-labels.test.js` हटाए गए पुराने migration path `20261115130000_admin_readonly_booking_accounting_reconciliation.sql` को पढ़ रहा था और पुराने `srk_route_transfers`/Route settlement fields की अपेक्षा कर रहा था। Route ledger Main DB audit में पहले ही retire किया जा चुका था; इसलिए Admin accounting UI से Route-only section/fields हटाए और payout को manual bank/UPI UTR-recorded settlement के रूप में स्पष्ट किया।
- Regression test को current migration `20261115150000_admin_readonly_booking_accounting_reconciliation.sql` तथा current read-only ledger contract के अनुरूप किया; पूरे `tests/` folder में पुराने migration filename का कोई अन्य reference नहीं मिला।
- GitHub Actions PR run `43704748225` — commit `059f875a2de8caffa422da9b7ae98a125acbfc7b`: **96/96 Node tests PASS, 0 FAIL**. यह repository Node suite है; pgTAP, live Supabase RPC/database parity, browser E2E, Vercel Preview और mobile QA का प्रमाण नहीं। उसी commit का push run उस समय अलग से in-progress था।
- Manual refund completion migration में verified manual refund के बाद पहले से blocked unpaid electrician payout अब `refunded` होता है; transition न हो तो transaction fail-closed रहती है। इसका pgTAP contract plan/assertion count 10/10 source-level है; pgTAP runtime अभी नहीं चला।
- Accounting migration/test source में Route references हटे हैं; reconciliation RPC read-only है। No Production migration, data/Auth/Storage/settings mutation, provider refund/transfer, live SMS/OTP, push send, deployment, PR merge या go-live action किया गया। PR #8 अभी review के लिए unmerged है।

## 2026-11-15 — Customer legacy quote approval UI (GPT-1)

- Customer booking loader में legacy electrician quotation के लिए आवश्यक quoted_amount, service_charge, materials_amount, quote_status, quote_note और submission timestamp fields जोड़े।
- awaiting_quote_approval + pending quote पर Customer को मेहनताना और सामान/पार्ट्स की अलग-अलग रकम, कुल रकम और electrician का विवरण दिखाने वाला approval card जोड़ा।
- Customer से explicit confirmation लेकर existing owner-scoped srk_customer_respond_booking_quote RPC को approved या rejected response भेजा जाता है। RPC success के बाद booking list reload होती है; failure पर status दर्ज होने का झूठा दावा नहीं किया जाता।
- पहले से approved/rejected quote की स्थिति भी booking card में दिखाई जाती है। यह legacy quote workflow है; newer category-based fixed-duration booking flow में यह card नहीं दिखता।
- Regression coverage जोड़ी: tests/customer-quote-approval-ui.test.js. Source commit f147c5f05489ed20c64986064f8a2f199e2f5941 और test commit b4977ad54f826951fd6430a5cd43697489ba3122.
- इस update के लिए अभी कोई नया CI result उपलब्ध नहीं है; test PASS या browser/runtime verification का दावा नहीं। Next step: CI में targeted/full Node suite verify करना और उसी के बाद quote approval UI को आगे audit करना।
- No production database/configuration change, actual quote response, booking/payment mutation, deployment, PR merge, or mobile QA.


## 2026-11-15 — CI follow-up after Customer/Electrician branch updates

- GPT-2 accounting/UI correction का successful verification commit `059f875` पर हुआ: PR run `43704748225` और push run `43704745028`, दोनों **96/96 PASS**।
- उसके बाद Feature Branch पर Customer quote UI/test changes आने से latest observed HEAD `a924bc3` का PR Node run `43704886935` **97 PASS / 1 FAIL** हुआ। Failure `tests/customer-quote-approval-ui.test.js` के assertion में है: test पुरानी inline onclick string pattern खोज रहा है, जबकि `booking.html` में quote approve/reject handlers मौजूद हैं। यह GPT-1 Customer scope का test-contract mismatch प्रतीत होता है; इसे GPT-1 owner के साथ reconcile करना है। इसे Customer runtime bug या पूरी suite green नहीं कहना है।
- Latest run में Admin accounting regression tests PASS रहे; current Admin accounting UI अब retired Route transfer fields/section नहीं दिखाता और reconciliation के नए migration path को पढ़ता है।
- PR #8 अभी Open + Draft + Unmerged है। कोई merge, Production migration, deployment या live payment/provider action नहीं किया गया।


## 2026-11-15 — GPT-2 accounting/refund source cross-check

- Read-only reconciliation function को cancellation-fee full-refund trigger और wallet ledger source से मिलाया। Cash cancellation-fee refund में trigger original electrician wallet debit को `cancellation_fee_item` reference से ढूँढता है, फिर उसी debt ID और manual refund evidence ID (`provider_reference`) से exact wallet credit लिखता है; reconciliation इसी pair/amount को compare करती है। यह source-level contract alignment है, runtime SQL execution नहीं।
- `srk_manual_refund_entries` और `srk_booking_refund_requests` दोनों पर `booking_id` unique है; manual refund एक booking पर duplicate evidence नहीं बना सकता। Manual refund RPC payment evidence/amount match, Main Admin approval (यदि request मौजूद हो), Razorpay exclusion, payout lock और final blocked→refunded close करता है।
- Current latest observed CI run `43705001425` (HEAD `e71fbd1`): **99 PASS / 1 FAIL**। केवल शेष failure GPT-1 Customer quote UI regression test की पुरानी onclick-regex expectation है; Admin accounting regression tests PASS। इसे Customer runtime defect नहीं माना गया और GPT-1-owned files नहीं बदले।
- Accounting/refund code अभी static-reviewed है; pgTAP runtime, live DB parity और browser E2E प्रमाण बाकी हैं। No Production mutation, migration apply, provider action, deployment, merge या go-live.


## 2026-11-15 — उपयोगकर्ता निर्देश: पुराना quotation workflow हटाना
- Customer App से legacy quote display/approval/rejection और quote-specific booking query fields हटाए।
- Electrician App से inspection + quote submission UI और quote RPC handlers हटाए।
- Obsolete customer quote UI test हटाया।
- यह अभी frontend retirement है; Admin, Accounting, payment, refund, payout और DB RPC/columns में legacy quote dependencies शेष हैं। उन्हें GPT-2 के साथ समन्वय कर नए fixed-duration/server-timed labour billing model पर सुरक्षित रूप से retire करना होगा।
- Historical paid records को delete नहीं किया जाएगा। Production DB/deployment/PR merge untouched.


## 2026-11-15 — नवीनतम Feature Branch Node CI पुनःसत्यापन (GPT-2)

- PR #8 के वर्तमान HEAD `843e91abaecf0e72df343518aa36c593c1a89a06` पर GitHub Actions run `43705430363` पूरा हुआ।
- Workflow job `Node test suite (no secrets, no deployment)`: **98/98 PASS, 0 FAIL, 0 skipped**। Test log में `1..98`, `# pass 98`, `# fail 0` की पुष्टि की।
- इससे पिछले Customer quote UI test mismatch का CI blocker हट गया है; Admin commission/accounting regression tests भी इसी पूर्ण suite में सफल रहे।
- यह Node/mock/source regression suite है। इससे pgTAP, live Supabase RPC/ACL, managed schema parity, browser E2E, Vercel Preview, OTP/SMS delivery या mobile QA प्रमाणित नहीं होते।
- PR #8 जाँच के समय Open + Draft + Unmerged था। कोई PR merge, Production migration, deployment, live payment/refund/payout, real SMS/OTP या push send नहीं किया गया।


## 2026-11-15 — Admin accounting UI में बचा retired Route label हटाया (GPT-2)

- 98/98 Node CI green run के बाद Admin reconciliation card के explanatory text में एक पुराना lowercase `Route settlement` label मिला था; वास्तविक Route ledger हट चुका है, इसलिए वह label भ्रामक था। इसे हटाया।
- Admin commission/accounting regression test को मजबूत किया: अब पूरा Admin page retired `Route` शब्द/field के लिए case-insensitive word-boundary check से जाँचा जाएगा। Test regex escape भी source में सही रूप से verify किया।
- Commits: Admin UI `be074d1`; test `db95b3b`, regex correction `d4f05ee`।
- इन अंतिम दो source/test edits के बाद कोई नया CI run उपलब्ध नहीं दिखा; इसलिए **98/98 परिणाम पूर्ववर्ती tested HEAD `843e91a` के लिए है**, नवीनतम Admin label correction को अभी CI में पुनः चलाना बाकी है।
- कोई Production DB, provider, payout, payment, deployment या merge action नहीं किया।


## 2026-11-15 — Backend quotation RPC retirement (GPT-1)

- New additive migration `20261115220000_retire_live_legacy_quotation_rpcs.sql` (commit `d8ec74f2ce150490b83cc0f13728079ce66f277b`) revoke/drop करती है: `srk_submit_booking_quote`, `srk_customer_respond_booking_quote`, `srk_update_booking_work_status`।
- `srk_get_my_offer_details()` से legacy quoted amount, service/material quote amount, quote status और quote note projections हटाए। Assigned-only contact visibility तथा current category/duration/rate/server-timer fields रखे।
- Historical booking/financial data और legacy audit columns untouched हैं; destructive cleanup नहीं किया।
- Admin/Accounting reconciliation और manual-payment source में पुराने quote-dependent checks मिले। ये GPT-2 ownership हैं; उन्हें बदले बिना cross-owner review के लिए pending दर्ज किया।
- SQL runtime/pgTAP और RPC caller contract verification बाकी हैं। कोई Production migration, deployment, PR merge या live booking/payment action नहीं।


## 2026-11-15 — Quotation retirement: electrician contract hardening

- Offer-details RPC migration को ठीक किया ताकि portal के आवश्यक `offer_expires_at` और `estimated_labour_paise` fields न टूटें; quote-only projections हटे।
- Contact details केवल assigned status में exposed हैं; category/rate/duration/server timer fields सुरक्षित।
- Electrician App से आखिरी legacy `quoted_amount` display fallback हटाया। अब server-calculated estimate ही दिखता है।
- Regression tests जोड़े: `tests/electrician-legacy-quotation-retirement.test.js`।
- Node CI run `43705727199` commit `b9fd6a1` पर success हुआ, लेकिन बाद के contract/UI/test commits पर runs `43705891497` और `43705887412` latest check के समय pending/in-progress थे; latest-head PASS अभी प्रमाणित नहीं।
- GPT-2 cross-owner blockers: Admin quote editing UI, legacy manual-payment approved-quote dependency, reconciliation approved-quote exception. इन्हें नए immutable server-timed labour bill और separate materials receipt से जोड़ना होगा।
- Historical quote/status audit columns तथा old booking status constraints अभी preserve हैं; कोई paid/settled record delete नहीं किया। SQL runtime/pgTAP pending. No Production migration, deployment, PR merge or live payment action.


## 2026-11-15 — Admin accounting cleanup CI green और DB contract hardening (GPT-2)

- Admin UI का stale `Route settlement` label हटाने और regression test को पूरे Admin page पर case-insensitive retired Route reference जाँचने के बाद नवीनतम उपलब्ध Node CI run `43705953944` सफल हुआ।
- Tested HEAD `80a6c7daf477bd732539a8fa7aa60928d47238a2` के job log में **100/100 PASS, 0 FAIL, 0 skipped** (TAP `1..100`) सत्यापित। इसमें Admin commission/accounting regression test और manual refund/payment suites शामिल हैं।
- Admin page source में retired standalone Route/Route commission reference अब नहीं मिला।
- अतिरिक्त DB contract hardening: `accounting_reconciliation_readonly_contract.test.sql` में SECURITY DEFINER accounting RPC के लिए empty `search_path` pin होने का pgTAP assertion जोड़ा; plan 45 से 46 किया। Commit `9ef6f5d`। यह SQL test अभी execute नहीं हुआ है; केवल source assertion count 46 verify हुआ।
- इस नए pgTAP assertion के बाद current HEAD `9ef6f5d755bd6ead9b67887daa3300b9863fa55e` पर नया CI run अभी उपलब्ध नहीं दिखा।
- सीमा: 100/100 केवल Node/mock/source regression suite है। pgTAP runtime, live Supabase ACL/RPC, managed schema parity, browser E2E और Preview अभी शेष हैं।
- PR #8 अभी Open + Draft + Unmerged है। कोई Production migration, merge, deployment, real payment/refund/payout, SMS/OTP या push send नहीं किया।


## 2026-11-15 — GPT-1 latest CI and Welcome source recheck

- Latest feature HEAD before this documentation update: `da65832bdd07ee1238d9b4c0829045d06349f95a`।
- GitHub Actions run `43705984415`, job `132787042217`: **completed / success**।
- Welcome source recheck: `index.html` redirects to `/welcome.html`; Welcome page references `/assets/srk-founder.jpg` and links to Customer, Electrician and Admin entry points.
- Founder asset is present in source reference, but exact approved portrait visual match is not verified; desktop/mobile preview remains for the final consolidated QA pass.
- Customer OTP Auth/SMS runtime, server-side abuse controls, session lifecycle, Payments/Support/Profile contracts and browser E2E remain open.
- Full quotation retirement remains incomplete until GPT-2 Admin, manual-payment and accounting dependencies are safely retired. Historical paid/settled evidence remains preserved.
- No Production migration, deployment, merge, real payment/refund/payout, SMS/OTP or push send was performed.


### CI पुनः सत्यापन — 2026-11-15 10:51 UTC

- नवीनतम HEAD `2d688adcd144e0907242bb01ca5171482248b176` पर Feature Branch Node tests run `43706094972` सफल। Job log में **100/100 PASS, 0 FAIL, 0 skipped** सत्यापित।
- यह Node test suite है; PostgreSQL/pgTAP contract के 46 assertions इस run में execute नहीं हुए। वास्तविक Supabase/PostgreSQL connection या pgTAP runner उपलब्ध न होने से database runtime verification अभी लंबित है।
- PR #8 Open + Draft + Unmerged है। Production/merge/deployment में कोई बदलाव नहीं।


## 2026-11-15 — Customer dashboard navigation regression coverage (GPT-1)

- Added `tests/customer-dashboard-menu-contract.test.js` (commit `5c202a4`).
- Regression checks cover all five accessible tabs and matching panels, Payments/Support/Profile panel routing, saved-address navigation from Profile, authenticated dashboard visibility, and expected customer support/profile RPC integration.
- This is source-contract coverage only; it does not prove live Supabase RPC/RLS/storage behavior or browser/mobile runtime.
- New test and latest branch CI result remain pending verification.


### Customer dashboard review note — 2026-11-15
- Static source review confirmed the menu-shell moves Payment History, Support and Profile cards into their respective tab panels; complaint list/create/message and profile read/update use customer-specific RPCs behind the authenticated dashboard.
- Found a remaining honest-completion gap: Profile saves the `preferred_language` value, but there is no translation/apply layer in `booking.html`; Hindi/English selection is currently preference storage only, not a working language switch.
- Added source regression coverage in `tests/customer-dashboard-menu-contract.test.js` (commit `5c202a4`). Workflow run `43706360554` was cancelled before dependency install/test execution after subsequent branch pushes; therefore the new test is **not yet verified by CI**. Do not report it as passed.
- Live Supabase RPC/RLS/storage and browser verification remain pending.


## 2026-11-15 — Customer Hindi/English language switch implementation

- Updated `booking.html` with a reversible customer UI translation dictionary and DOM translation layer (commits `1db6e6c`, `ca7d505`).
- Profile language selection now applies immediately; loading a saved profile reapplies `preferred_language`. Text inserted later into customer panels is translated while English is active.
- Added source-contract assertions to `tests/customer-dashboard-menu-contract.test.js` (commit `c28f5b0`) for reversible language state, html lang, profile restoration and mutation observer.
- Fixed whitespace preservation in the text-node translator after source review.
- Coverage is deliberately described as partial: dynamic status/error copy, receipt document, remaining untranslated content and browser runtime still need work.
- Workflow run `43706432946` was successful for the earlier menu regression commit, but it predates the final language implementation/test changes. Latest-head CI is **not yet verified**.
- No Supabase changes, production deployment, PR merge or mobile QA performed.


## 2026-11-15 — Customer dynamic message and receipt localization

- Expanded the Customer App translation dictionary for payment/refund event types and statuses, login prompts, common booking/payment states and alerts.
- Added a selected-language wrapper for customer browser alerts.
- Printable payment receipt now uses the selected UI language for receipt headings, labels, payment method, missing-value copy and date locale. Verified payment data and itemized labour/materials/cancellation fee amounts remain unchanged.
- Added regression assertions covering dynamic payment text, receipt `lang`, localized date formatting and ensuring the receipt-only helper does not leak into other functions.
- Source was restored from the last intact branch revision after detecting that an intermediate localization edit had overreached its replacement scope; the corrected commit preserves the original Customer App functions.
- Latest-head CI has not yet been returned; do not mark tests passed. Browser runtime / actual print preview remain pending.


### CI परिणाम — Customer भाषा और भुगतान रसीद
- Latest branch commit: `70f65c1acd797ec6c494f54a8067881e6d95776b`.
- GitHub Actions Node test run: `43706978870` — **SUCCESS**.
- Install और full `npm test` step सफल; customer dashboard/language/receipt regression tests भी suite में शामिल।
- इससे source-contract tests की पुष्टि होती है; browser में वास्तविक Hindi↔English toggle, popup receipt print preview, dynamic runtime copy और mobile visual QA अभी शेष हैं।


## 2026-11-15 — GPT #2 Payout / Commission / Refund reconciliation cross-check

- `supabase/migrations/20261114360000_new_category_electrician_payout_reconciliation.sql` और `supabase/tests/database/electrician_payout_reconciliation.test.sql` की source समीक्षा की।
- New-category booking में payout का Labour immutable bill से आता है; Materials = 0; platform commission केवल Labour पर round होकर निकलता है। Settled/reserved cancellation fee customer collection matching में शामिल हो सकती है, लेकिन electrician payable/commission में नहीं।
- Payout को Paid दर्ज करने से पहले Main Admin, completed + verified-paid booking, सही electrician assignment, immutable labour bill, exact commission/payable snapshot, no reserved cancellation-fee item और pending payout status जाँचे जाते हैं। Booking row पहले और payout row बाद में lock होती है। यह RPC bank/UPI transfer नहीं भेजता; Admin के दिए UTR/reference को दर्ज करता है।
- Refund review RPC केवल request state बदलता है; provider call/payment status mutation नहीं करता। Actual provider refund executor अलग lifecycle है।
- **महत्वपूर्ण source/document mismatch मिला:** `20261115150000_admin_readonly_booking_accounting_reconciliation.sql` के वर्तमान RPC body में Route transfer/settlement tables का कोई read/join/field नहीं है, जबकि इस Progress Log के पुराने Sections 10 और 11 में Route reconciliation को report में शामिल बताया गया है। इसलिए Route reconciliation को implemented/verified नहीं मानना है; इस report के दायरे से बाहर है।
- **Test-count mismatch मिला:** `supabase/tests/database/accounting_reconciliation_readonly_contract.test.sql` में वर्तमान `plan(46)` और 46 `select ok(...)` assertions हैं। पुराने दस्तावेज़ में 52 assertions लिखा है; वर्तमान source file के अनुसार 46 ही दर्ज किया जाएगा। यह static source count है, pgTAP runtime pass नहीं।
- अगला काम: Route transfer/settlement reconciliation को अलग से exact schema/order review के बाद जोड़ने का प्रस्ताव तैयार करना; पहले pgTAP runtime execution वाले isolated test environment की पुष्टि आवश्यक। कोई Production migration, transfer, refund, payout या deployment नहीं किया गया।


## 2026-11-15 — Route transfer / settlement reconciliation report extension

- नई migration `supabase/migrations/20261115170000_admin_route_transfer_accounting_reconciliation.sql` जोड़ी गई। Existing Main Admin read-only per-booking accounting RPC अब `srk_route_transfers` से transfer rows, provider transfer IDs, payment IDs, recipient types, amounts, transfer status और settlement status दिखाती है।
- Route ledger मौजूद होने पर ठीक एक electrician और एक platform-commission row अपेक्षित है; payment ID, Labour-derived electrician payable और Labour-only commission amount से मिलान होता है। Failed/reversed/partial-reversed/manual-review, unsettled, missing provider ID और manual-paid + Route-electrician transfer overlap को exception बनाया गया है।
- No Route rows को अपने-आप error नहीं माना गया, क्योंकि manual bank/UPI payout flow भी मौजूद है। यह रिपोर्ट किसी provider API को call नहीं करती, पैसे transfer/reverse नहीं करती, settlement update नहीं करती और payout Paid mark नहीं करती।
- `supabase/tests/database/accounting_reconciliation_readonly_contract.test.sql` को `plan(54)` / 54 source-contract assertions तक बढ़ाया गया। Migration function body का static inspection: कोई INSERT/UPDATE/DELETE या provider HTTP call नहीं।
- **सीमा:** यह source-level implementation और static inspection है। pgTAP/PostgreSQL runtime अभी execute नहीं हुआ; वास्तविक Razorpay Route live transfer/webhook/provider reconciliation अभी अलग से प्रमाणित होना बाकी है।
- Commits: migration `d41fd5786b5d68135f07613d881112a7d88be0cc`; pgTAP contract update `5d9e699f78b4365f5d9f4e34fc6e45c1309177b9`। कोई Production migration या transfer नहीं किया गया।

## 2026-11-15 — Customer localization completion pass and Electrician source audit

- Added English dictionary coverage for dynamic customer profile, saved-address, complaint/support, OTP/login and payment-related feedback.
- Customer payment/booking/refund history date/time rendering now selects `en-IN` or `hi-IN` based on the chosen app language.
- Payment receipt print document uses the same selected language for its title, labels, payment method, status, missing-value text, and date formatting.
- During audit, detected malformed text substitutions in an intermediate `booking.html` edit. Restored the page from the last intact feature-branch revision and safely reapplied localization changes; then added a syntax-parse regression test to compile inline browser scripts in both Customer and Electrician pages.
- Electrician App source reviewed: OTP/session gate, profile/name editing, support tickets, push-notification opt-in/out, availability controls, admin-approved area-change flow, phone-number change request with new-number OTP, KYC private document upload/preview, earnings/payout summary, wallet ledger, offer accept/decline, customer contact display only within the assigned-order rendering branch, server-timed work-start/completion lifecycle, and final labour bill display.
- Added source-contract checks to ensure the Electrician App retains the server-timed lifecycle and does not reintroduce quotation UI.
- Latest CI run `43707448254` on `172d74b204bfd283522a4e540090cb79deca73aa` — **SUCCESS**, including inline-script syntax checks and the full Node test suite.
- Browser runtime, real device notification permission behavior, actual receipt print preview, and visual verification remain pending. No live bookings, payment actions, Production settings, deployment, or mobile QA were performed.


## 2026-11-15 — GPT #2 Route transfer reconciliation source update

- Route schema migration `20261109020000_create_server_only_razorpay_route_transfer_ledger.sql` की जाँच में वास्तविक तालिका `public.srk_route_transfers` और उसके सटीक fields मिले: booking/payment IDs, recipient type, linked account, provider transfer ID, amount_paise, transfer_status और settlement_status। तालिका service_role-only है; DB writes स्वयं पैसा नहीं भेजतीं।
- नया Feature Branch migration `20261115170000_admin_route_transfer_accounting_reconciliation.sql` Admin read-only booking accounting report में Route transfer rows, count, electrician/commission amounts और status evidence जोड़ता है।
- रिपोर्ट recipient-row shape, payment ID mismatch, expected payout/commission amount mismatch, failed/reversed/manual-review state, unsettled state, missing provider transfer ID और manual-paid + Route electrician transfer overlap को exception बनाती है।
- Zero commission की स्थिति में शून्य रकम का platform transfer row अनिवार्य नहीं है; test contract में इसका source assertion जोड़ा गया।
- pgTAP source contract अब `plan(55)` और 55 assertions है। यह केवल SQL source contract है; वास्तविक PostgreSQL/pgTAP execution अभी नहीं हुआ।
- यह बदलाव केवल Feature Branch/PR #8 पर है। कोई provider API call, transfer, settlement, reversal, payout, Production migration या deployment नहीं किया गया। Route का live provider status polling/webhook और वास्तविक settlement proof अभी अलग से Not Verified हैं।
- अगला चरण: migration + test source का full review, CI result की जाँच, और PostgreSQL runtime test environment उपलब्ध होने पर pgTAP चलाना।

## 2026-11-15 — GPT #2: Route transfer reconciliation report added (Feature Branch only)

- Added migration `supabase/migrations/20261115170000_admin_route_transfer_accounting_reconciliation.sql` after inspecting the existing server-only `srk_route_transfers` schema. The Admin read-only booking report now returns Route transfer rows, transfer/settlement statuses, provider IDs, recipient types, linked-account IDs, amounts in paise, and timestamps.
- Added exception checks for recipient-row count, payment-ID mismatch, expected electrician/commission amount mismatch, failed/reversed/manual-review states, unsettled transfers, missing provider transfer IDs, and overlap between a Route electrician transfer and a manually marked-paid payout.
- The contract test now has `plan(55)` and 55 assertions, including eight Route-specific source/schema assertions. These are source-level pgTAP contract assertions only; PostgreSQL/pgTAP runtime execution is still **Not Run**.
- Important scope: the inspected Route migration creates a server-only ledger and explicitly says database writes do not move money. Repository search did not establish a live Route transfer executor, provider status polling/webhook, or end-to-end settlement lifecycle. This change reconciles recorded ledger evidence only; it does **not** activate Route transfers or prove that funds reached a bank.
- No Production migration, transfer, refund, payout, deployment, merge, or go-live was performed. PR #8 remains subject to owner review/approval.


## 2026-11-15 — Electrician Live Location stop reliability and Customer lifecycle translations

- Fixed a Live Location stop failure edge case in the Electrician App: previously, the local watch handle was deleted before the server confirmed the stop. If the RPC failed, the page could no longer present the normal Stop retry action. The revised flow clears the browser GPS watch, keeps the booking handle until the server confirms stop, and suppresses concurrent duplicate stop requests. The existing UI therefore continues to offer “Location बंद करें” for retry.
- Added a regression test for retry-handle retention and stop RPC confirmation ordering.
- Expanded Customer App English translations for booking lifecycle and timeline states, refund outcomes, cancellation fee history, location/GPS feedback, and common booking errors/statuses. The original booking and payment data remain unchanged.
- CI run `43707742875` on `bd1b6f1388d3f1a70cd2e069676eb6a23663cade` — **SUCCESS**, including the full Node test suite and parsing inline JavaScript from both app pages.
- Welcome page audit: `welcome.html` routes to Customer, Electrician and Admin login pages and references `/assets/srk-founder.jpg`; the founder image asset exists in the feature branch. Exact approved portrait visual match and desktop/mobile visual preview remain unverified.
- No Production deployment, merge, live booking, payment, GPS sharing, or Production database change was performed.
- Remaining: browser runtime verification for language switching, receipt Print/PDF, GPS permission and stop-retry flow; then one consolidated final mobile QA pass after all implementation is complete.


## 2026-11-15 — GPT #2 Route reconciliation deeper audit (open findings)

- Re-checked the exact Feature Branch files: Route ledger migration, Route reconciliation migration `20261115170000_admin_route_transfer_accounting_reconciliation.sql` and pgTAP contract. The 55-assertion plan and Route source assertions are present; this remains source inspection, not a PostgreSQL runtime result.
- Confirmed the read-only report now returns Route transfer rows/count, amount totals, recipient type, recipient user ID, linked account ID, provider transfer ID, transfer status and settlement status. It does not create or execute transfers.
- Additional fail-closed gaps found for the next patch: the report does not compare an electrician Route row's `recipient_user_id` with the booking's assigned electrician; it also does not enforce a valid `transfer_status` + `settlement_status` combination (for example, `settled` settlement paired with a non-`processed` transfer). Therefore a clean reconciliation result is not yet sufficient proof that the correct recipient received settled funds.
- Linked-account ID is returned as evidence but is not validated against an authoritative recipient-to-Route-account mapping in this report. Provider-side settlement confirmation/polling/webhook and bank receipt remain unverified; ledger fields alone are not bank proof.
- Next safe Feature Branch work: inspect the authoritative electrician-to-Route-linked-account mapping and existing transfer lifecycle source, then add recipient identity + status-transition checks and corresponding tests. If no authoritative mapping/lifecycle exists, keep the report explicitly exception/Not Verified rather than infer success.
- No live provider calls, transfers, refunds, payout changes, Production migration, deployment, merge or go-live.


## 2026-11-15 — GPT #2 Route recipient and settlement validation patch

- Existing schema inspection confirmed electrician_profiles maps the assigned profile to Auth through coalesce(auth_user_id,user_id), while srk_wallet_bank_links stores Route provider_account_id, provider, verification status and primary-link flag.
- Added Feature Branch migration 20261115180000_admin_route_recipient_and_settlement_validation.sql: Route electrician recipient Auth user must match the booking's assigned electrician; exactly one verified primary Razorpay Route bank link is required; transfer linked-account ID must match that verified account; a settled record whose transfer status is not processed is flagged.
- Added four source-contract assertions. Accounting reconciliation contract is now plan(59) with 59 select ok assertions.
- These are source-level assertions only. PostgreSQL/pgTAP runtime remains Not Run; CI status for the newest commits must be checked separately. The checks validate ledger/mapping consistency, not provider settlement or actual bank receipt.
- No Route API calls, transfers, payouts, refunds, Production changes, deployment, merge or go-live.


## 2026-11-15 — Customer translation gap pass and Electrician GPS exception handling

- Added further Customer English dictionary entries for login/form placeholders, booking estimate text, map labels, OTP/login/payment failure messages, complaint feedback and common form prompts.
- Fixed Electrician Live Location watch callback so both an explicit Supabase RPC error and a thrown network/transport exception enter the safe stop flow. This avoids leaving the GPS watch and server-side location sharing running after an unhandled rejected promise.
- Updated the GPS client regression tests for the new error path. An intermediate assertion mismatch was corrected; final latest branch-head CI succeeded.
- Latest branch head `e549574a091071f995786b009d710e4da25160c0`: GitHub Actions runs `43708098611` and `43708093433` — **SUCCESS**, full repository Node test suite.
- Browser runtime verification and visual review are still pending. No real GPS sharing, live booking, payment, production database change or production deployment was performed by this work.


## 2026-11-15 — GPT #2 Route live-lifecycle audit

- Inspected root razorpay-webhook.js and its Netlify wrapper. The webhook validates Razorpay HMAC, claims/deduplicates signed webhook events, reconciles captured payments and refunds, but supported payment events are payment.captured/order.paid and refund.created/refund.processed/refund.failed. No Route transfer/settlement event handler is present in this source.
- Repository code search and schema inspection found the server-only srk_route_transfers ledger and verified linked-account mapping table, but did not establish a Route transfer creation executor, transfer status polling, Route settlement webhook handler, reversal/partial-reversal executor, or bank-credit confirmation path. Do not equate ledger status with provider/bank truth.
- Existing project log already records that Route live transfer execution and provider status polling/webhook/reversal are not proven. This audit reconfirms that gap from the current webhook source.
- Safe next implementation boundary: add a separate server-only Route provider adapter only after approved provider API contract, secrets/environment setup, test-mode account, transfer creation/idempotency design, event types and reconciliation lifecycle are confirmed. Until then the admin report must present Route as ledger evidence / Not Verified and never auto-mark a transfer or payout paid.
- No live API calls, transfers, refunds, payouts, Production changes, deployment, merge or go-live. Latest Node CI success applies to commit e549574a091071f995786b009d710e4da25160c0; PostgreSQL/pgTAP remains Not Run.


## 2026-11-15 — Electrician refresh resilience and Welcome Screen contract

- Improved Electrician App `refresh()`: profile and offer RPC transport failures now produce actionable Hindi retry messages instead of raw errors or unhandled rejections.
- Isolated per-booking live-location-state and final-labour-bill lookups so one auxiliary RPC failure does not prevent the remaining booking cards from rendering. Missing auxiliary data can be retried on refresh.
- Added `tests/customer-dashboard-menu-contract.test.js` coverage for the refresh failure paths.
- Added `tests/welcome-screen-contract.test.js`: verifies root redirect to Welcome Screen, all three role links, founder portrait source/asset existence, descriptive alt text and reduced-motion CSS.
- CI run `43708433631` on `57cf3a7f22f31591b593a4fe96e10b1a5e6f332d` was still in progress at the time of this update; do not mark this test pass until final CI status is confirmed.
- Browser runtime and actual portrait-to-approved-reference visual match remain pending. No production deployment or live booking/payment action was performed.


## 2026-11-15 — GPT #2: Route bank-link uniqueness guard

- Schema audit found `srk_wallet_bank_links` had a unique provider-account ID and per-user/account pair, but no database constraint preventing multiple `is_primary=true` Razorpay Route electrician links for one Auth user.
- Added migration `20261115190000_enforce_single_primary_route_bank_link.sql`: partial unique index permits at most one primary Route electrician bank link per user. Migration first checks legacy duplicates and raises `DUPLICATE_PRIMARY_ROUTE_BANK_LINKS_REQUIRE_MANUAL_REVIEW` rather than silently selecting or deleting an account.
- Added one pgTAP source-contract assertion; accounting contract plan/count updated from 59 to 60.
- Important: migration is Feature Branch source only. No PostgreSQL/pgTAP runtime, existing-data duplicate preflight, Production migration, provider onboarding, or bank verification has been run. Any existing duplicate primary links require manual review before applying.
- No live money movement, deployment, merge, or go-live.


## 2026-11-15 — GPT #2: Route idempotency / retry boundary audit

- Inspected `srk_route_transfers` schema: it already has a unique `idempotency_key`, unique provider `transfer_id`, and unique `(razorpay_payment_id, recipient_type)` constraint. This prevents duplicate ledger rows for the same payment/recipient, but does not by itself prove provider-side duplicate transfer prevention.
- Confirmed schema has no Route transfer execution caller, provider status polling, transfer event webhook handling, reversal amount/reference lifecycle, or bank-credit evidence. Therefore no safe retry executor can be implemented without the approved Razorpay Route API contract, idempotency semantics, webhook event catalog, secrets and test-mode credentials.
- Added two pgTAP source-contract assertions for unique idempotency key and payment/recipient uniqueness; contract plan/count now 62.
- Retry rule for future implementation: only retry after querying provider state with the same stable idempotency key; never issue a new key on timeout/ambiguous response; any provider result conflict or missing transfer ID goes to manual review. This is a design requirement, not implemented execution behavior.
- Runtime pgTAP, live provider calls, bank settlement confirmation and Production changes remain Not Run / Not Approved. No merge, deployment or go-live.


## 2026-11-15 — Customer dynamically inserted control localization

- Customer UI language observer previously translated text nodes added later, but did not translate attributes on dynamically inserted controls. This could leave new placeholders, tooltips and accessible labels in Hindi while English was selected.
- Added shared `customerUiTranslateAttributes(root, lang)` handling for placeholder, title and aria-label attributes. It runs on the initial page when applying a language and on each newly inserted element while English is active.
- Added regression assertions in `tests/customer-dashboard-menu-contract.test.js` for the initial pass and dynamic-element observer path.
- Feature Branch commits: Customer UI `8c0a4193`; regression test `fe5de63f`. Latest CI result for this exact head is not yet available; do not mark the new assertion as passed until workflow confirmation.
- Welcome Screen review confirmed the Customer login route resolves to `customer-login.html`, whose successful OTP flow redirects to `booking.html`; root `index.html` redirects to `welcome.html`; all three role links and founder image path are present. Asset presence is covered by `tests/welcome-screen-contract.test.js`; exact portrait visual match and browser rendering remain pending.
- No Production migration, deployment, merge, payment, or live booking was performed. Mobile QA remains deferred until the consolidated final pass.


## 2026-11-15 — GPT #2: Route ledger access-control contract

- Rechecked the Route ledger foundation: RLS is enabled, all privileges are revoked from anon/authenticated, and operational select/insert/update grants are assigned to service_role only.
- Added three pgTAP source-contract assertions for RLS enabled, no direct anon/authenticated read, and service_role operational grants. Accounting contract plan/count is now 65.
- This is source-level test coverage only; no PostgreSQL/pgTAP runtime has been run. No Route API caller, transfer execution, provider settlement webhook, reversal lifecycle or bank-credit proof has been added.
- Feature Branch only. No Production migration, live provider call, money movement, deployment, merge or go-live.


## 2026-11-15 — Customer support dynamic localization pass

- Confirmed the previous Customer UI observer handled exact dictionary strings but concatenated status messages and several complaint/support states still lacked complete English mappings.
- Added translations for support complaint loading/empty/error/validation/submission, conversation states, file attachment feedback and default-address feedback.
- Extended `customerUiText` to translate dictionary prefixes and preserve the remaining dynamic suffix; the text-node language pass and mutation observer now use this shared translator.
- Added regression assertions for complaint status prefix translation and representative support messages.
- Code/test commits: `b7172dd2`, `403ef722`. New CI run is expected on the current feature branch head; confirm before treating the new assertions as passed.
- Browser runtime language switching and visual Welcome Screen portrait review remain pending. No production deployment or data mutation; consolidated mobile QA remains deferred.


## 2026-11-15 — GPT #2: Admin Refund / Payout RBAC पुनः-जाँच

- Current Feature Branch admin.html में showState() पहले is_srk_admin() जाँचता है; अन्यथा tracked Support Staff session और support.customer.read permission के बिना portal access deny होता है। Staff mode केवल assigned support inbox load करता है; Main Admin-only sections (Refund review, Razorpay refund, accounting, payout/finance) UI में छिपे रहते हैं। यह UI gating है, backend authorization का विकल्प नहीं।
- Backend source review: srk_admin_mark_electrician_payout_paid() और srk_admin_record_manual_refund() दोनों auth.uid() तथा is_srk_admin() की स्वतंत्र जाँच करते हैं। Payout RPC केवल pending payout, completed + verified-paid booking, immutable bill/legacy quote, exact commission/payable और booking-first row locks के बाद Admin द्वारा वास्तविक UTR/reference दर्ज करता है; यह स्वयं बैंक transfer नहीं करता।
- Refund review migration 20261115110000_admin_refund_review_queue_and_decisions.sql की queue/decision RPC Main Admin-only है, empty search_path और request row lock रखती है। Approval केवल review state बदलता है, provider को पैसा भेजता नहीं और booking payment status mutate नहीं करता।
- accounting_reconciliation_readonly_contract.test.sql में दो source-contract assertions जोड़े: payout settlement और manual refund record RPC दोनों independently Main Admin authorization लागू करें। Plan/count 65 से 67।
- Static review/test-source update मात्र। PostgreSQL/pgTAP runtime अभी नहीं चला; live Staff login, refund provider, payout, browser QA और production parity सत्यापित नहीं हैं। कोई वास्तविक refund/transfer, migration apply, merge या deployment नहीं।


## 2026-11-15 — Customer booking copy: retired quotation wording removed

- Customer booking page में बचा हुआ Hindi copy और उसका English translation dictionary entry हटाया; अब page केवल selected electrician tier/duration/rate आधारित शुरुआती estimate और server-recorded actual labour time बताता है।
- Customer regression test जोड़ा ताकि inspection/post-inspection quotation वाली पुरानी wording दोबारा न लौटे।
- Static scan: `booking.html` और `electrician.html` में quote/quotation/inspection terms और quote-related identifiers का कोई match नहीं मिला।
- इस cleanup के दौरान एक CI run में test ने सही तरीके से बची हुई Hindi dictionary string पकड़ी; वह string हटाई गई। उसके बाद latest code SHA `ef2c3fd0c6f33b52e2d9dfa5833819c6802894d1` पर दो full Node test workflows **SUCCESS** हुए।
- Customer/Electrician UI wording cleanup मात्र; Admin/Accounting/Payment/database legacy dependencies GPT-2 के दायरे में हैं। No Production changes, merge, deployment or data deletion. Browser runtime and final mobile QA remain pending.


## 2026-11-15 — GPT #2: Financial SECURITY DEFINER search_path hardening

- Admin source audit में दो financial mutation RPCs मिले जिनका authorization Main Admin-only था, लेकिन function-level search_path में public/auth और pg_temp शामिल थे: `srk_admin_mark_electrician_payout_paid(uuid,text,text,text)` और `srk_admin_record_manual_refund(uuid,text,text)`। दोनों functions के application objects पहले से schema-qualified हैं।
- नई Feature Branch migration `20261115200000_harden_financial_admin_rpc_search_path.sql` दोनों RPCs का search_path खाली करती है; PostgreSQL का implicit pg_catalog resolution बना रहता है। इससे SECURITY DEFINER execution के दौरान writable/public schemas search path से हटते हैं। Existing function bodies, authorization, grants और business logic नहीं बदले।
- Accounting source-contract test में दोनों functions के empty search_path की दो pgTAP assertions जोड़ीं; plan/count 67 से 69।
- Static source review only: migration apply या PostgreSQL/pgTAP runtime नहीं हुआ। Apply से पहले staging DB पर function execution/smoke test आवश्यक। कोई real payout/refund, merge या deployment नहीं।


## 2026-11-15 — Customer App static English translation audit

- Customer `booking.html` के static visible Hindi text nodes और `title` / `aria-label` attributes का source audit किया। सभी static Hindi text nodes के लिए English dictionary entry मौजूद है; scan में कोई unmatched visible Hindi text node नहीं मिला।
- Dashboard section headings, saved-address/GPS instructions, Google Maps action, electrician tier duration labels, estimate and billing terms, separate materials approval, booking terms तथा Razorpay payment actions की translations जोड़ीं।
- शेष दो accessibility/title labels — Electrician current location और booking status history — भी translate किए।
- Regression test में representative static translations और accessibility labels के assertions जोड़े।
- Feature branch head `d55c11159b865386234601df2041c998fa735d6b` पर दो full Node test workflows **SUCCESS** हुए।
- यह static/source-level coverage है; browser में वास्तविक language switching, dynamic runtime rendering और visual review अभी बाकी हैं। Final consolidated mobile QA deferred है। No Production change, merge or deployment.


## 2026-11-15 — GPT #2: Route settlement evidence fail-closed warning

- Route ledger/reconciliation audit में पुष्टि हुई कि वर्तमान application source में Route transfer provider settlement webhook/polling और recipient bank-credit evidence path मौजूद नहीं है। इसलिए `transfer_status='processed'` और `settlement_status='settled'` अपने आप वास्तविक बैंक भुगतान का प्रमाण नहीं हैं।
- Feature Branch accounting reconciliation RPC अब किसी भी Route ledger row पर `ROUTE_PROVIDER_SETTLEMENT_NOT_INDEPENDENTLY_VERIFIED` exception जोड़ती है और response में `route_provider_settlement_verified=false` तथा `route_settlement_evidence_status='not_independently_verified'` लौटाती है। कोई Route row न होने पर status `no_route_transfer_ledger_rows` रहता है।
- Accounting source-contract test में दो assertions जोड़े; plan/count 69 से 71। यह केवल source-level contract है; PostgreSQL/pgTAP runtime अभी Not Run है।
- Admin HTML में अभी Route-specific result rendering नहीं मिला; RPC का JSON response सीधे/किस रूप में प्रदर्शित होता है, browser runtime से सत्यापित नहीं। अगला कदम Admin reconciliation renderer में exception/status को स्पष्ट Hindi warning के रूप में दिखाना और Node regression test जोड़ना है।
- No provider calls, bank checks, transfers, payouts, Production DB changes, deployment, merge or go-live.


## 2026-11-15 — Customer App dynamic English messages and confirmation dialogs

- Customer App के dynamic GPS/location feedback, payment/refund history loading and error states, complaint status, work-start approval, cancellation/booking errors, OTP/session messages, saved-address actions और payment outcomes के लिए English dictionary coverage बढ़ाई।
- `window.confirm` को भी `customerUiText` translation wrapper से जोड़ा; अब English mode में confirmation dialogs भी translate होते हैं, केवल alerts नहीं।
- Cancellation-fee policy confirmation का पूरा English text जोड़ा। Booking confirmation के dynamic summary में Tier, Duration, Estimated labour, Payment method और prior-fee line-item wording translate करने के fallback replacements जोड़े।
- Dynamic messages, confirm wrapper और cancellation/booking summary के regression tests जोड़े। शुरुआती CI run में test-only wrapper variable नाम mismatch मिला; उसे ठीक किया। Latest branch SHA `3fb69b1c59858f291fd0821e658e0ee837aad5b9` पर दो full Node test workflows **SUCCESS** हुए।
- Browser runtime language switching, backend से आने वाले अज्ञात dynamic message variants और visual QA अभी pending हैं। Final consolidated mobile QA deferred है। No Production changes, merge or deployment.


## 2026-11-15 — GPT #2: Admin Route settlement warning UI

- Admin booking accounting reconciliation renderer में Razorpay Route Transfers का अलग section जोड़ा। हर Route row के साथ recipient type, amount, transfer status, settlement status और provider transfer ID दिखता है।
- स्पष्ट Hindi warning जोड़ी: ledger का `processed/settled` status बैंक में रकम पहुँचने का प्रमाण नहीं; स्वतंत्र provider settlement या bank-credit evidence के बिना भुगतान confirmed नहीं माना जाएगा। UI केवल RPC के `route_provider_settlement_verified` को true होने पर पुष्टि दिखा सकता है; वर्तमान RPC इसे false लौटाता है।
- Node regression test `tests/admin-route-settlement-warning.test.js` जोड़ा; migration response contract और Admin warning/rendering दोनों जाँचता है।
- अगला सत्यापन: नवीनतम branch-head Node CI पूरा होने पर इस test सहित परिणाम देखें। PostgreSQL/pgTAP runtime अभी Not Run है; browser visual/runtime QA भी बाकी है।
- No live Route transfer/provider call, bank-credit verification, payout mutation, Production migration, deployment, merge or go-live.


## 2026-11-15 — Electrician Push permission reliability audit

- Electrician App के Push Notification enable flow में browser permission request को async Supabase account/profile validation से पहले लाया। अब button click के तुरंत बाद synchronous support checks और `Notification.requestPermission()` होते हैं; उसके बाद approved Active electrician account validation और subscription save चलता है। इससे Android Chrome में user-gesture activation खोने की संभावना घटती है।
- Regression test जोड़ा: permission request async account validation से पहले होनी चाहिए।
- GPS start/update/stop, GPS failure पर server stop, logout retry handling, Push subscription ownership और Support ticket/thread rendering का source audit किया। मौजूदा GPS safeguards और support HTML escaping ठीक मिले। कोई real device permission prompt या Production call नहीं किया।
- Latest full repository run में 121 में से 120 tests pass हुए; एक failure GPT-1 scope से बाहर Admin test `tests/admin-commission-report-labels.test.js` में है, जो current `admin.html` में Route commission term देखकर fail हो रहा है। यह GPT-2 Admin Panel dependency है; GPT-1 ने Admin source नहीं बदला।
- Browser/device runtime verification pending; final consolidated mobile QA deferred. No Production changes, merge or deployment.


## 2026-11-15 — Admin commission test scope correction

- नवीनतम CI में 121 Node tests में 120 पास और 1 fail मिला। कारण: aggregate commission report का पुराना test पूरे Admin HTML में Route शब्द रोक रहा था, जबकि अलग accounting reconciliation panel में Route Transfers का नया section वैध रूप से जोड़ा गया है।
- `tests/admin-commission-report-labels.test.js` को केवल aggregate कमीशन रिपोर्ट के HTML section तक सीमित किया; read-only accounting reconciliation migration पर retired Route-field assertions यथावत हैं।
- Test correction commit: `0f0dd20510c845c51c0e66d0664ca14287bbcb19`. इसके बाद का नया CI run अभी प्रतीक्षित है। PostgreSQL/pgTAP runtime और browser/device QA अभी Not Run हैं।


## 2026-11-15 — Electrician GPS stop concurrency hardening

- GPS signal/update failure से automatic server-stop और electrician के manual “Location बंद करें” action अब एक ही `electricianLocationStopBusy` guard साझा करते हैं। इससे एक booking पर duplicate concurrent `srk_electrician_stop_live_location` calls नहीं होंगी।
- Stop RPC fail होने पर booking retry handle में बनी रहती है; server confirmation सफल होने पर ही handle हटता है। Shared guard और retry behavior के regression tests जोड़े।
- Guard declaration move होने के बाद existing GPS network-exception test की source boundary भी update की। Latest branch head `c57577c9f72663cf52cfc8981d72f008d95b83ef` पर दोनों full repository Node workflows **SUCCESS** हुए।
- Browser/device runtime check और final consolidated mobile QA अभी pending हैं। No Production changes, merge or deployment.


## 2026-11-15 — Manual Refund fail-closed contract coverage

- Manual refund RPC का source audit: केवल Main Admin; verified-paid booking; Razorpay/online भुगतान को manual path से रोकता है; उपलब्ध Customer refund request approved होना आवश्यक; original manual payment audit amount से exact match; duplicate manual refund रोकता है; payout state/booking row locks और final refunded state transition लागू हैं।
- Manual refund तथा payout mutation SECURITY DEFINER RPC का empty search_path hardening migration पहले से मौजूद है; pgTAP contract में दोनों के empty path assertions मौजूद हैं।
- तीन अतिरिक्त pgTAP assertions जोड़े: Razorpay/online exclusion, approved request gate, और manual payment evidence amount match। Test plan 71 से 74 हुआ। Commit: 803a7f3e28037d8fcc8b686e84e75716e4730cbf.
- Runtime PostgreSQL/pgTAP execution अभी उपलब्ध नहीं; assertions केवल source में जोड़े गए हैं, इन्हें पास घोषित नहीं किया गया।
- Latest CI failure अब Customer Dashboard live-location network exception contract test में है (GPT-1 क्षेत्र); Admin commission report test पिछली CI failure में सुधार के बाद आगे बढ़ा। PR #8 खुला Draft है; merge/deploy नहीं किया।


## 2026-11-15 — Refund executor/status/recovery source audit and CI

- Latest Node CI on commit `6b83ba1dc3423921a00d1a71564869c286cfbf22` सफल: Push run `43710114587` और PR run `43710118567` दोनों success। पिछला Customer Dashboard test failure और Admin commission report test failure अब नवीनतम CI में नहीं हैं।
- Razorpay refund executor, read-only status lookup और durable recovery endpoint का source audit: bearer token Supabase Auth से verify; Main Admin membership DB RPC से verify; refund record/payment ID/amount/currency/idempotency identity checks; ambiguous timeout पर नया refund ID नहीं बनता; status lookup provider GET-only है; recovery provider evidence को पहले append-only audit में save कर अलग accounting-finalization चरण चलाती है।
- Refund reconciliation RPC service-role-only है, booking-first row lock लेती है, provider refund ID mismatch रोकती है और processed/failed terminal state को late event से regress नहीं होने देती। Definitive provider failure पर पहले से लगाया payout hold release करने का नियम source में मौजूद है; इसे केवल verified provider `failed` state पर लागू माना जाए।
- यह source review और Node CI है; PostgreSQL/pgTAP runtime, live Razorpay sandbox/provider calls, browser E2E और Production DB parity सत्यापित नहीं हुए। कोई वास्तविक refund/payout, DB deployment, merge या production deployment नहीं किया गया।


## 2026-11-15 — Electrician Profile, KYC, Earnings और Wallet audit

- Profile display-name update में 2–80 characters validation और self-service RPC confirmation जाँचा।
- Phone change flow OTP के बाद Admin approval पर निर्भर है; OTP expiry/attempt failure के बाद authoritative request history refresh होती है और मौजूदा नंबर approval तक चालू रहता है। Phone और area request history में user/admin-provided text HTML escaping से render होता है। Area change में state/district/PIN/reason validation, pending request guard और approval तक current area retention की पुष्टि की।
- KYC में केवल identity/address/skill types, allowlisted MIME, 1–5 MB, unique non-upsert object key और metadata RPC हैं। Document preview owner-authorized RPC path से 60-second signed URL लेता है; public URL नहीं।
- Earnings RPC और electrician-profile-scoped payout rows अलग हैं। Payout query fail होने पर UI शून्य/empty payout history नहीं दिखाता; स्पष्ट error देता है। Customer payment और Admin UTR-confirmed payout को अलग दिखाया गया है।
- Wallet summary RPC से है; bank-link query signed-in user-scoped और ledger query user + wallet scoped है। दोनों query failures अलग दिखते हैं। UI स्पष्ट करता है कि ledger balance बैंक ट्रांसफर का प्रमाण नहीं; withdrawal/transfer initiate करने वाला action मौजूद नहीं है।
- इन contracts के लिए `tests/electrician-accounting-kyc-contract.test.js` जोड़ा। Latest branch SHA `6b83ba1dc3423921a00d1a71564869c286cfbf22` पर दो full repository Node workflows **SUCCESS** हुए।
- Browser runtime/visual QA अभी pending; final consolidated mobile QA deferred है। No Production changes, merge or deployment.


### Test harness follow-up — 2026-11-15

- नए KYC/earnings/wallet contract test के पहले runs में केवल test helper के source-boundary extraction और regex escaping की गलतियाँ मिलीं; app source में कोई बदलाव आवश्यक नहीं हुआ।
- Test helper को अगले function declaration तक सीमित किया और profile `finally` assertion ठीक की।
- Latest branch head `2a7771c153b82785238256d8852e04aa540f901c` पर दोनों full repository Node workflows **SUCCESS** हुए।


## 2026-11-15 — Admin Dashboard पर Project Progress Card

- Main Admin dashboard के शीर्ष पर प्रोजेक्ट प्रगति कार्ड जोड़ा।
- मुख्य मास्टर चेकलिस्ट के वर्तमान 9 sections में 54 पूर्ण और 32 शेष आइटम: 63% पूरा / 37% बाकी।
- गणना का दायरा स्पष्ट किया: यह checklist-item count है; Production readiness, elapsed time या code completion का प्रतिशत नहीं।
- बाकी मदों में isolated runtime/database tests, Main Production schema parity, browser/mobile visual QA और release/owner approval शामिल हैं।
- Support Staff view में कार्ड नहीं दिखेगा; Admin portal के मौजूदा role-gating के कारण यह केवल Main Admin view में दिखेगा।
- Checklist के summary section में भी यही गणना दर्ज की। नई checklist स्थिति आने पर कार्ड और दस्तावेज़ का प्रतिशत फिर से अपडेट करना होगा।
- यह Feature Branch UI/documentation change है; Production deploy नहीं किया गया।


## 2026-11-15 — Booking Lifecycle / Offer / Timer / Completion review

### Source review findings
- Offer response client only accepts `accepted` / `declined`, guards duplicate pending submissions per offer, checks explicit server success and refreshes the offer list on success/expiry. Server RPC checks auth identity against the electrician profile, approved/active/available state, booking location and approved rate tier; locks the offer and booking rows before assigning, validates expiry, and dispatches the next eligible offer after decline/expiry.
- Electrician start request is limited to the assigned active approved electrician and locks the booking row. Server moves booking to `awaiting_work_start_approval`, stores request timestamp using `clock_timestamp()`, and keeps timer stopped until customer action.
- Later corrective migration `20261114260000_fix_work_start_rpc_and_append_only_event_history.sql` supplies the effective customer start RPC: customer-owned row lock, only approve/reject responses, Admin-approved rate snapshot check, timer starts with server `clock_timestamp()` only on approval; rejection returns booking to assigned and timer remains stopped.
- Electrician completion request locks the assigned booking and freezes elapsed seconds from server timestamps. Customer completion decision locks customer-owned booking; approve inserts immutable labour bill, reject resumes timer with server clock, dispute records a complaint and keeps timer stopped. Server calculates billable minutes and paise amount; UI does not submit timer or final amount writes.
- Customer and Electrician timer elements only project server elapsed seconds/start timestamp for display. The final bill is retrieved through the Electrician server RPC.

### Changes made
- Added per-booking in-flight guards to Electrician start/completion requests and Customer start/completion decisions. Guard releases in `finally`, including RPC errors, allowing safe retry after refresh/current-state review.
- Added `tests/booking-lifecycle-serialization.test.js` with nine source-contract tests covering offer controls, both apps' duplicate-submit guards, customer approve/reject/dispute, server row locks, server clock, completion branches and timer display-only behavior.
- All nine targeted lifecycle tests passed in CI; inline script parsing also passed.

### CI / release status
- Full repository CI is currently failing on a separate Razorpay webhook regression test: `matches an unpersisted provider refund by its internal refund-record note`, assertion false at `tests/razorpay-webhook-inbox.test.js:361`. This is outside the lifecycle changes; do not mark full suite green until repaired/re-run.
- pgTAP SQL tests are present but were not executed; no Production migration, live booking, payment, or deployment action occurred.
- Production migration parity and end-to-end testing remain pending. Keep the no-paid-staging-branch rule: only discuss staging cost/approval when implementation is complete and consolidated E2E is next. Final mobile QA remains deferred.


## 2026-11-15 — GPT-2 कार्यक्षेत्र प्रतिशत अलग दिखाना

- User clarification: प्रतिशत केवल GPT-2 की अपनी जिम्मेदारी का दिखना चाहिए; GPT-1 Customer/Electrician काम को इसमें नहीं जोड़ना।
- गणना का scope: Master Checklist section 3 Admin/Support Staff (11 done, 2 pending), section 4 Payment/Accounting (8 done, 2 pending), section 8 Main DB audit/parity (7 done, 9 pending)।
- कुल 39 मदों में 26 पूर्ण और 13 शेष: **67% पूरा / 33% बाकी** (rounded)।
- Admin Panel में पूरे प्रोजेक्ट के 63% कार्ड से अलग GPT-2 का 67% progress card जोड़ा।
- यह Feature Branch checklist implementation/audit progress है; Production rollout, isolated runtime verification और owner-approved release अलग gates हैं।
- आगे GPT-2 scope की checklist बदलने पर प्रतिशत 26/39 के पुराने मान से नहीं, नई checkbox count से दोबारा निकालना होगा।


## 2026-11-15 — GPT-2 प्रगति का विभागवार विवरण

- Admin Panel के GPT-2 प्रगति कार्ड में विभागवार प्रतिशत जोड़े।
- Admin/Support Staff: 11/13 = 85%; Payment/Accounting: 8/10 = 80%; Main Database audit/parity: 7/16 = 44%।
- संयुक्त स्थिति: 26/39 = 67% पूरा, 13/39 = 33% बाकी।
- GPT-1 के Customer/Electrician कार्य इस गणना से बाहर हैं।


## 2026-11-15 — Welcome Screen / Founder Photo / PWA audit

- Reviewed `welcome.html`, `index.html`, `manifest.webmanifest`, `sw.js` and welcome-screen contract tests. Customer, Electrician and Admin login routes are all present, and index redirects to the Welcome Screen.
- Corrected the PWA start URL from `./customer-login.html` to `./welcome.html`; bumped the service-worker cache to v9 and added Welcome, Customer, Electrician and Admin entry pages to the offline precache list.
- Refined the Welcome Screen to a blue/white premium theme, added “Smart Service... Better Life...” and retained the approved slogan.
- Important asset audit: checked-in `assets/srk-founder.jpg` is a collage of three app screens, not the approved blue-background Founder Photo. Removed it from the portrait display and preserved an accessible Founder Photo slot. Did not substitute the second/design-reference image or an older generated portrait.
- The exact approved blue-background Founder Photo is not currently accessible in the repository or Library file list. Its original upload is referenced in prior project context (first blue-background image = actual Founder Photo; second image = design model), but the image bytes are not available to this work session. Authentic photo integration is therefore still pending; do not claim it is complete or ask for unrelated photos.
- Added Welcome Screen regression coverage for all role routes, collage exclusion, copy, PWA start URL and offline precache.
- Browser visual/runtime and PWA offline checks remain pending; no deployment or Production change was made. Final mobile QA remains deferred.


### Welcome Screen CI follow-up — 2026-11-15
- Fixed the Welcome Screen test harness to use string assertions for URL paths (avoids an invalid regular-expression delimiter issue).
- Updated `tests/electrician-live-location-client.test.js` to expect the intentionally bumped service-worker cache `srk-electronic-v9`.
- Latest CI on code head `3ad8d575266eea757a2084db82966b0c82b04e61`: Welcome Screen role/photo-slot test **PASS** (`ok 139`); PWA launch/offline-precache test **PASS** (`ok 140`); lifecycle and GPS contracts also pass. Repository test summary: **139 passed / 1 failed**.
- The sole full-suite failure remains the unrelated Razorpay refund-note test `matches an unpersisted provider refund by its internal refund-record note`. No false full-suite green claim.
- Exact approved blue-background Founder Photo remains unavailable in the accessible repository/Library; no unrelated collage/model/older portrait was substituted. Final original-photo integration still needs the previously approved photo asset.

## 2026-11-15 — Refund Webhook टेस्ट fixture सुधार
- GitHub Actions में Refund Webhook regression test की विफलता का कारण test fixture का provider refund ID `rfnd_note_match` था; Razorpay ID validator केवल `rfnd_` के बाद alphanumeric अक्षर स्वीकार करता है।
- Refund webhook टेस्ट में दोनों provider IDs को वैध प्रारूप में सुधारा: `rfnd_notematch123` और `pay_notematch123` (prefix के बाद केवल alphanumeric अक्षर); पिछली बार payment ID में underscore छूट गया था। Production handler और उसकी सुरक्षा जाँच में कोई बदलाव/ढील नहीं दी।
- बदलाव Feature Branch / Draft PR #8 में commit `42de563f4cc8b276f9a7105474135d36555991bd` पर है। नवीनतम CI run अभी उपलब्ध नहीं; pass होने का दावा नहीं।
- GPT-2 कार्यक्षेत्र प्रगति अपरिवर्तित: 26/39 = 67% पूरा, 13/39 = 33% शेष।


## 2026-11-15 — GPT-1 progress + authentic garden Founder Photo clarification

- User clarified that the authentic Founder Photo is the original photo with a green garden in the background. Use this exact photo, crop it to match the existing Founder model/layout, and preserve the person's real face/identity. This supersedes the older blue-background-photo note.
- Do not use the design-reference/model image as the founder identity source, and do not substitute the checked-in app-screen collage.
- Checked saved reference images and Library image search; the original garden-photo binary is not accessible in this work session. Actual crop/asset replacement therefore remains pending; no false completion claim.
- GPT-1 progress is separately counted from Master Checklist sections Customer (10), Electrician (10), and Welcome/Founder Photo (6): **19/26 = 73% complete; 7/26 = 27% remaining**. GPT-2 tasks excluded. This is implementation checklist progress, not Production readiness.
- Going forward, report GPT-1 and GPT-2 percentages separately in progress updates; update the counts when checklist items change.


## 2026-11-15 — GPT-2 Admin booking direct-write privilege closure

- Source audit में Admin UI के दो direct `service_bookings` writes मिले: customer address/district/state/PIN edit और legacy `quoted_amount` edit।
- Migration `20261115230000_admin_booking_direct_write_closure.sql` में दोनों के लिए अलग Main-Admin-only SECURITY DEFINER RPC जोड़े; दोनों booking row को `FOR UPDATE` lock करते हैं।
- Location RPC address/district/state/PIN validate करती है और बदलाव का before/after `srk_admin_audit_events` में सुरक्षित करती है।
- Legacy quote RPC नई-category, cancelled, paid/online और customer-approved quote बदलाव रोकती है; labour + materials total का exact paise मिलान करती है।
- Admin UI को दोनों RPC पर बदला और `service_bookings` के authenticated direct UPDATE grants revoke किए। Admin page source scan में कोई `.from(...).update(...)` direct write नहीं बचा।
- Regression test `tests/admin-booking-direct-write-closure.test.js` जोड़ा; CI अभी इस नए commit पर चलना बाकी है। PostgreSQL runtime/pgTAP और browser verification नहीं किए गए।
- GPT-2 checkbox count अब **27/39 = 69% पूरा; 12/39 = 31% शेष**। Admin/Support Staff: **12/13 = 92%**। यह Feature Branch source progress है, Production readiness नहीं।
- कोई Production migration, merge या deployment नहीं किया गया।


## 2026-11-15 — Founder Photo identity confirmed; crop prepared

- User confirmed the black-shirt portrait with the green garden background is the authentic saved SRK ELECTRONIC Founder Photo.
- Prepared a crop to match the existing Founder card aspect ratio while preserving the original person, clothing and garden background.
- The image binary has not yet been committed to `assets/srk-founder.jpg`; the Welcome Screen placeholder remains intentionally in place. No substitute collage or generated portrait was used.
- GPT-1 current section checkbox count: 20/28 = 71% complete; 8/28 = 29% remaining. Asset integration, Preview/runtime visual QA and final consolidated mobile QA remain pending. No merge or Production deployment.


### GPT-2 Admin direct-write closure — CI follow-up (15 Nov 2026)
- Existing Admin source-contract test was updated to require the guarded quote RPC rather than the retired direct `.update()` call.
- Latest full Node CI on commit `b7c50d118d25ec628e96814b2fe435bcb886b7db` — **SUCCESS** (run `43712832090`). This confirms Node/source regression coverage only; PostgreSQL runtime and browser verification remain pending.
- GPT-2: **27/39 = 69% complete; 12/39 = 31% remaining**. Overall checklist after the same checkbox change: **55/86 = 64% complete; 31/86 = 36% remaining**.


### Push delivery lease fencing — test coverage added (15 Nov 2026)
- Reviewed the final push lease-fencing migration for both outbox-level and per-device delivery completion.
- Added pgTAP contract `supabase/tests/database/push_delivery_lease_fencing.test.sql` with **20 assertions**: service-role-only execution, stale attempt rejection, processing-state requirement, row locks, terminal-state protection, retry ceilings, bounded error storage, capped exponential backoff and pinned search paths.
- Added Node regression contract `tests/push-delivery-lease-fencing.test.js`. Full Node CI passed on commit `b4beff9661e506412cf31d4049db478263e15716` (run `43713340539`).
- PostgreSQL/pgTAP runtime execution is still pending in an isolated database; Node CI does not execute this SQL test. No production DB access/migration, push send, merge or deployment performed.
- GPT-2 checklist percentage remains **27/39 = 69% complete; 12/39 = 31% remaining**. This is additional test coverage, not a completed database-parity checkbox.


### Database pgTAP test-plan audit — 15 Nov 2026
- Feature Branch के सभी **27** `supabase/tests/database/*.test.sql` files की assertion-count जाँच की। हर file में ठीक एक `plan(n)` है और pgTAP assertion calls की संख्या उससे मेल खाती है।
- इस audit को repeatable बनाने के लिए `tests/database-pgtap-plan-counts.test.js` जोड़ा; यह भविष्य में plan/assertion mismatch को Node CI में पकड़ता है।
- Full Node CI commit `0149c87a44f81c824e90617e17dce215516c1e22` पर **SUCCESS**, run `43715758599`।
- यह source-level count validation है; इससे PostgreSQL/pgTAP runtime assertions के पास होने का दावा नहीं है। अलग isolated DB runtime अभी pending है।
- GPT-2 checklist progress अभी भी **27/39 = 69% complete; 12/39 = 31% remaining**; कोई Production migration या release action नहीं किया।


### Supabase migration-version collision audit and correction — 15 Nov 2026
- पूरे Feature Branch के 66 migration SQL filenames की version-prefix जाँच में चार नई duplicate pairs मिलीं: `20261115170000`, `20261115180000`, `20261115190000`, `20261115200000` (हर pair में Admin/Route और Push migration टकरा रही थीं)।
- चार Push migrations को unique second-level versions पर rename किया: `20261115170001_durable_push_delivery_outbox.sql`, `20261115180001_push_subscription_delivery_ledger.sql`, `20261115190001_push_delivery_health_monitoring.sql`, `20261115200001_push_delivery_lease_fencing.sql`; original SQL content जस का तस रखा। Push lease Node test को नए path पर अपडेट किया।
- अब नई duplicate collision नहीं बची; केवल पुरानी `20261109` pair शेष है: `20261109_allow_quote_approval_booking_states.sql` और `20261109_electrician_inspection_quotes_and_service_only_commission.sql`। ये पुराने version से जुड़े होने के कारण Production migration history देखकर ही resolve होंगे; इन्हें rename नहीं किया।
- `tests/database-migration-version-uniqueness.test.js` जोड़ा: नए duplicate versions CI में fail होंगे और पुराने `20261109` collision को स्पष्ट allowlist में track किया गया है।
- नवीनतम commit `3418ef8c13030395868fd443edab962411ec496f` पर CI run शुरू हुआ; परिणाम verify होना बाकी है। इससे पहले migration rename वाले intermediate commits पर CI fail हुआ क्योंकि Node test अभी पुराने path को refer कर रहा था; path ठीक कर दिया गया।
- कोई Production migration, DB change, merge या deployment नहीं किया गया। GPT-2 checklist percentage **69%** ही है; migration file renaming अतिरिक्त quality work है, checklist completion checkbox नहीं।


### Push migration filename references + CI verification — 15 Nov 2026
- Rename के बाद CI ने दो पुराने source-test paths पकड़े (`push-delivery-outbox.test.js`, `push-subscription-delivery-ledger.test.js`); दोनों में outbox/subscription/health/lease migration references नए unique filenames पर अपडेट किए।
- Final Feature Branch head `45bf7dd411b99d06d76215411076613879c44af5` पर दोनों Node CI runs **SUCCESS**: `43716184006`, `43716181744`।
- Migration version audit: 66 SQL migration files में अब केवल पुरानी `20261109` duplicate pair बची है; नई चार Push migration versions unique हैं। `20261109` pair का Production history मिलान किए बिना कोई rename नहीं होगा।
- Node CI source tests सफल हैं; PostgreSQL/pgTAP runtime और वास्तविक Production migration status का independent verification अभी अलग pending है।
- GPT-2 checklist progress **69% (27/39)** अपरिवर्तित; कोई Production change, merge या deployment नहीं।


### 2026-11-15 — Electrician multi-profile labour bill access correction
- Static review found that `srk_electrician_get_labour_bill(uuid)` selected only the newest electrician profile owned by the signed-in user. If an older owned profile held the booking assignment, that legitimate electrician could not read the final bill.
- Added migration `20261115145900_fix_multi_profile_electrician_labour_bill_access.sql`: bill lookup is now scoped to the requested booking and uses an `EXISTS` ownership check against the exact bill's `electrician_profile_id`, accepting either `user_id` or `auth_user_id`. This does not broaden access to another electrician's profile or bill. Authenticated-only execute grant is preserved.
- Added a Node source-contract regression test and one pgTAP structural assertion (server timer test plan increased to 20).
- First CI attempt exposed a migration timestamp collision with an existing refund migration; the new migration was moved to unique timestamp `20261115145900` and the colliding draft file was removed. The earlier CI failure was caused by that duplicate-version guard, not by the RPC regression assertion. Final CI for the corrected unique timestamp is awaiting confirmation.
- Static/source change only. No pgTAP execution, no live Supabase migration, no production change, no deployment, no merge. Checklist 14.1.10 remains In Progress until runtime DB/RPC verification is complete.


### Legacy financial RPC search_path hardening + migration collision follow-up — 15 Nov 2026
- तीन legacy `SECURITY DEFINER` financial read RPCs (`srk_admin_commission_report`, `srk_get_my_wallet_summary`, `srk_admin_wallet_overview`) के लिए नया Feature Branch migration `20261115210001_harden_legacy_financial_read_rpc_search_paths.sql` जोड़ा; trusted path `pg_catalog, public, auth, pg_temp` pin किया।
- 6 assertions वाला pgTAP contract और Node regression test जोड़ा। PostgreSQL runtime test अभी execute नहीं हुआ; Node CI source-contract coverage है।
- Migration version audit ने अतिरिक्त पुराने duplicate timestamps भी पकड़े: `20261115120000` और `20261115130000`; संबंधित multi-profile labour-bill access migrations को unique version prefixes पर रखा और source-test file reference update किया।
- अब 69 migration SQL files में केवल पुरानी `20261109` duplicate pair शेष है; उसे Production migration history जाँचे बिना नहीं बदला। CI ने वर्तमान PR head `df13cccbc91fceb4c03c377346e2d0e9dfc3b033` पर **SUCCESS** दिया (run `43716754914` और `43716757418`)।
- GPT-2 checklist count अभी **27/39 = 69% complete; 12/39 = 31% remaining** है। ये अतिरिक्त security/test सुधार हैं, कोई नया checklist checkbox पूरा नहीं हुआ। PR #8 Draft/Open/Unmerged; Production DB में इस काम से कोई बदलाव नहीं।


### CI पुनःपुष्टि — 2026-11-15
- Multi-profile electrician bill RPC regression test को canonical migration path `20261115145900_fix_multi_profile_electrician_labour_bill_access.sql` से align किया; पहले test fixture में पुराना timestamp/path बचा हुआ था।
- Latest PR head `e013bbbf6a60c979fa3185a961fb03517ca4a54f` पर GitHub Actions run `43716991931` / job `132820552196` — **Node test suite SUCCESS**; dependencies install और `npm test` दोनों सफल।
- pgTAP test file में नया multi-profile ownership structural assertion मौजूद है और plan 20 है; वास्तविक PostgreSQL/pgTAP execution अभी नहीं हुआ।
- Migration केवल Feature Branch में है। Production Supabase, merge और deployment में कोई बदलाव नहीं।


### सुरक्षित Database Test Environment की जाँच — 2026-11-15
- Supabase organization में दो ACTIVE_HEALTHY projects मिले: `Srk electranic` और `SRK ELECTRONIC TEST`।
- मौजूदा `SRK ELECTRONIC TEST` project की migration history में केवल electrician push-notification परीक्षण से जुड़ी 7 migrations हैं; इसमें Customer Booking / Work Timer / Labour Bill lifecycle का पूर्ण test schema प्रमाणित नहीं है।
- इसलिए इसे इस RPC migration के लिए उपयुक्त runtime test database मानकर कोई SQL/migration लागू नहीं की। Production project पर भी कोई परीक्षण या schema परिवर्तन नहीं किया।
- सुरक्षित अगला कदम: सभी implementation पूर्ण होने पर, पहले से तय प्रक्रिया के अनुसार, पूर्ण schema वाला approved isolated test environment उपलब्ध/स्वीकृत होने पर pgTAP और role-based RPC tests चलाना। अभी कोई नया paid Supabase branch/project नहीं बनाया।

### GPT-2 Admin legacy quote controls retired — 15 Nov 2026
- Admin booking table से editable quoted-amount input हटाया; पुराने labour/materials/total/quote status अब केवल read-only historical values हैं।
- Admin save flow से quote amount validation/update RPC call हटाई; पुरानी नई booking को Confirm करने वाला dedicated RPC और सुरक्षित manual-payment flows यथावत रखे। नई category booking का server-timed workflow नहीं बदला।
- Regression test अब सुनिश्चित करता है कि Admin UI में legacy quote mutation RPC या editable amount input वापस न आए; backend legacy RPC को historical compatibility के लिए guarded रखा, drop नहीं किया।
- Feature Branch source change; Node CI pending. PostgreSQL/pgTAP, browser runtime और Production migration नहीं किए। Historical paid/settled records सुरक्षित रखे गए।
- GPT-2 checklist item 3.1.7 (Admin legacy quote editing/status control) का UI हिस्सा बंद; accounting/receipt dependency audit अलग शेष है।


### Timer RPC documentation signature correction — 2026-11-15
- Static review में `srk_customer_respond_work_completion` की वास्तविक signature `(uuid,text,text)` और उसी function के COMMENT statement की पुरानी signature `(uuid,text)` मिली।
- Feature-branch migration में COMMENT signature को वास्तविक तीन arguments से मिलाया और Node source-contract regression test जोड़ा।
- यह केवल migration comment metadata + regression test का source correction है; कोई database migration apply नहीं की गई।
- इस नए commit के लिए CI result आने तक इसे test-success नहीं माना जाएगा। pgTAP / वास्तविक role-based RPC runtime verification अभी बाकी है।

### GPT-2 Admin legacy quote UI retirement — CI follow-up (15 Nov 2026)
- First CI run exposed two stale assertions in `tests/admin-refund-and-staff-access.test.js` that still required the retired Admin quote-edit call and old `quoted` comparison; the implementation itself was not the cause. Updated both tests to assert read-only historical quote behavior and the protected new-category status guard.
- Latest PR-head Node CI run `43717448107` (commit `75a1630a5e2ee0518c5f76b1571d1cec620ecb14`) completed **SUCCESS**; the full repository Node test suite passed. No PostgreSQL/pgTAP runtime or browser E2E was part of this run.
- Admin `admin.html` no longer renders an editable legacy quote amount or calls `srk_admin_update_legacy_booking_quote`; historical amount/labour/materials/status remain visible read-only. Dedicated legacy new→confirmed Main Admin RPC and manual-payment paths remain. Backend legacy quote RPC is retained with its existing guards for historical compatibility; no schema or historical paid rows were deleted/rewritten.
- GPT-2 checklist remains **27/39 = 69% complete; 12/39 = 31% remaining**; this closes the Admin UI control removal source item but does not close the legacy accounting/receipt dependency or runtime verification gates. PR #8 remains Draft/Open/Unmerged; no Production DB, deployment or merge action.


### नवीनतम CI और अतिरिक्त static security review — 2026-11-15
- नवीनतम branch head `5fb6eda05d5c7a88208a1751c662e97eaef25f49` पर GitHub Actions Node test suite run `43717500688` SUCCESS हुआ; dependency install और repository Node tests दोनों सफल।
- उसी branch head पर completion RPC का COMMENT अब वास्तविक `(uuid,text,text)` signature से मेल खाता है; regression assertion मौजूद है।
- Timer / completion RPCs में authenticated caller checks, customer ownership checks, assigned electrician profile ownership checks, booking row locking (`FOR UPDATE`), server-side timestamps और authenticated-only execute grants का source-level पुनरीक्षण किया।
- Multi-profile labour bill patch exact requested booking bill के `electrician_profile_id` के स्वामित्व की जाँच करता है; केवल authenticated user's `user_id` या `auth_user_id` वाले उसी profile का bill लौटाता है।
- यह static/source review है; pgTAP runtime execution, real DB role-based RPC verification और end-to-end lifecycle test अभी नहीं हुए। कोई migration apply / production deploy नहीं किया गया।


### Timer / Completion / Dispute audit continuation — 2026-11-15
- Branch पर Timer, Customer completion approval, Customer/Electrician labour-bill read RPC, Admin work-review RPC और append-only event-history migration को पुनः पढ़ा।
- नवीनतम उपलब्ध GitHub Actions run `43717598697` का job `132822385439` completed **SUCCESS**: dependency install और पूरा repository Node test suite सफल।
- pgTAP file में plan 20 और 20 assertions का static count मेल खाता है; इसमें anonymous RPC execute denial, half-up integer-paise formula, dispute reason और exact owned electrician-profile bill access के source checks शामिल हैं।
- Customer bill RPC customer_user_id से सीमित है; Electrician bill RPC का later migration requested booking के bill पर exact electrician_profile_id ownership जाँचता है। Admin work-review RPC admin gate के पीछे है; work-event table पर direct browser-role access revoked और mutation/truncate रोकने वाले triggers हैं।
- वास्तविक PostgreSQL/pgTAP execution और अलग-अलग Customer/Electrician/Admin role से RPC runtime परीक्षण अब भी शेष हैं; test project में पूरा workflow schema प्रमाणित नहीं है। कोई migration apply, production change, merge या deployment नहीं किया।
- GPT-1 Checklist 14.1.10 की अनुमानित source-work प्रगति **93%** बनी हुई है; runtime/E2E gates पास होने से पहले इसे complete नहीं माना जाएगा।

### GPT-2 Labour Bill ↔ Payment ↔ Accounting bridge audit — 15 Nov 2026
- Admin save path को दोबारा trace किया: नई `selected_category` booking वास्तविक Cash receipt के बाद dedicated `srk_admin_record_new_booking_cash_payment(uuid,text,text)` RPC पर जाती है; पुरानी booking अलग legacy `srk_admin_record_manual_payment(uuid,text,text,text)` RPC पर जाती है। नई booking पर legacy RPC स्पष्ट रूप से reject करता है।
- New-category Cash RPC Main Admin authorization, completed + assigned booking, Cash-only payment preference, booking row lock और immutable labour bill अनिवार्य करती है। कुल collection = immutable labour paise + reserved cancellation-fee paise; materials अलग से नहीं जोड़े जाते। Manual receipt entry और server payment timestamp दर्ज होते हैं; cancellation fee wallet debit तथा SRK ledger credit अलग idempotency keys से settle होते हैं।
- Read-only Admin reconciliation नई category में immutable bill से labour पढ़ती है, materials = 0 रखती है और verified collection को labour + settled cancellation fees से मिलाती है। Customer receipt owner-scoped immutable bill पढ़ती है, केवल settled fee items जोड़ती है और materials = 0 दिखाती है।
- Legacy manual-payment और receipt branches अभी भी पुराने approved quote तथा अलग labour/materials breakdown पर निर्भर हैं। इन्हें नई booking flow में उपयोग नहीं किया जाता; historical paid/settled records और पुराने unpaid legacy cases के लिए इन्हें बिना archival/dependency proof के हटाना सुरक्षित नहीं होगा।
- नया pgTAP source-contract test `supabase/tests/database/admin_labour_bill_payment_accounting_bridge.test.sql` जोड़ा: **15 assertions; plan count = 15**। इसमें Main Admin/row-lock/Cash-only/bill/fee/idempotency, Admin reconciliation, customer receipt और legacy isolation contracts शामिल हैं।
- यह source audit + test authoring है; pgTAP/PostgreSQL runtime, concurrent transaction, browser receipt print/PDF और वास्तविक role-based DB tests अभी नहीं चले। कोई Production migration, payment, refund, payout, merge या deployment नहीं किया।
- GPT-2 checklist count नहीं बदला: **27/39 = 69% पूरा; 12/39 = 31% बाकी**। यह अतिरिक्त dependency/test coverage है, checklist item acceptance नहीं।

### Labour Bill ↔ Accounting bridge — CI follow-up (15 Nov 2026)
- Code/test commit `12d92746fab47cdd8af0392835c6379a32c6f439` का Feature Branch Node CI run `43718088072` SUCCESS: **153/153 Node tests PASS**।
- यह Node suite है; नया pgTAP file `admin_labour_bill_payment_accounting_bridge.test.sql` PostgreSQL में execute नहीं हुआ। PR के बाद का documentation-only HEAD `06e5659db44b36da60763ce12e6b7d10fd899cee` पर अलग CI run उपलब्ध नहीं था।
- कोई checklist checkbox close नहीं किया; GPT-2 स्थिति **27/39 = 69%** ही है। PR #8 Draft/Open/Unmerged है।


### GPT-1 Timer RPC search_path runtime defect correction — 2026-11-15
- Static audit में migration `20261114260000_fix_work_start_rpc_and_append_only_event_history.sql` का final `ALTER FUNCTION ... SET search_path = ''` मिला, जबकि Customer start/completion SECURITY DEFINER RPCs के body में `srk_private.work_timer_authorizations` और `srk_private.work_transition_authorizations` references unqualified हैं। Empty search_path में ये references resolve नहीं होते और RPC runtime पर fail हो सकते थे।
- दोनों RPCs का search_path अब fixed trusted list `pg_catalog, public, auth, srk_private, pg_temp` किया; कोई dynamic/user-controlled schema नहीं जोड़ा। Regression test जोड़ा ताकि private authorization schema भविष्य में search_path से न हटे।
- यह source migration + Node regression test correction है; Database पर migration apply नहीं हुई। CI run की प्रतीक्षा है; pgTAP/runtime role tests अब भी बाकी हैं।

- Follow-up CI run `43718294235` में 154 में से 153 tests पास हुए; नया regression assertion regex over-escaped होने से fail हुआ, SQL source correction नहीं। Assertion को stable literal contract checks में बदला; corrected test के लिए CI फिर चल रहा है।

- अतिरिक्त hardening: fixed search_path में `public` रखना अनावश्यक object-shadowing surface बना सकता था। अब दोनों SECURITY DEFINER RPCs के सभी `srk_private` table references fully-qualified हैं और final `search_path = ''` है; regression test उसी least-privilege contract को verify करता है।

### GPT-2 New-category manual refund ↔ Labour Bill reconciliation — 15 Nov 2026
- Refund chain audit में Customer request और Razorpay preparation पहले से immutable labour bill + settled cancellation-fee ledger से exact full amount मिलाते थे; manual Admin refund finalizer में यह explicit new-category cross-check missing था।
- `srk_admin_record_manual_refund(uuid,text,text)` में new-category branch जोड़ी: booking completed हो; customer-owned immutable bill मौजूद हो; bill electrician profile current assigned electrician से match करे; cancellation-fee items row-lock हों और सभी settled हों; refund amount bill labour + settled fees के बराबर हो और booking तथा original manual-payment evidence दोनों से exact match करे।
- Legacy quote-based manual refund path अलग रखा; online/Razorpay payment को manual refund से रोकने वाला guard, approved customer request gate, payout block→refunded closure और fee-reversal trigger नहीं बदले।
- pgTAP `admin_manual_refund_request_completion.test.sql` को 10 से **14 assertions** तक बढ़ाया; plan count **14/14**। Node regression test में new-category bill, assignment, settled-fee और exact-amount guards जोड़े।
- Feature Branch Node CI run `43718479171` SUCCESS: **155/155 Node tests PASS**। PostgreSQL/pgTAP runtime, concurrent DB transaction, वास्तविक manual refund या wallet/ledger reversal test अभी नहीं चला।
- यह अतिरिक्त refund compatibility/security fix है; checklist checkbox अभी close नहीं किया। GPT-2 **27/39 = 69% पूरा; 12/39 = 31% बाकी**। PR #8 Draft/Open/Unmerged; कोई Production DB change, provider refund, merge या deployment नहीं।

### GPT-2 Refund Recovery identity tests and CI follow-up — 15 Nov 2026
- `razorpay-refund-recovery.js` के उस path के लिए दो Node regression tests जोड़े जहाँ internal Refund ID अभी persist नहीं हुआ: exact `notes.srk_refund_record_id` से provider refund match होना चाहिए; समान Payment ID + amount वाला unrelated refund बिना exact note/receipt match के अस्वीकार होना चाहिए।
- Feature Branch run `43718823062` / PR run `43718826650`: कुल **157 tests में 156 PASS, 1 FAIL**। दोनों नए Refund Recovery tests PASS हुए।
- शेष failure `tests/booking-lifecycle-serialization.test.js` के test 31 में है: test `srk_customer_respond_work_start(uuid,text)` के लिए `SET search_path = ''` अपेक्षित करता है, जबकि संबंधित migration में explicit fixed path `pg_catalog, public, auth, srk_private, pg_temp` है। यह GPT-1 Work Timer क्षेत्र है; GPT-2 ने उसकी migration/test फाइल नहीं बदली। इसे GPT-1 के साथ review करना होगा; CI को पूर्ण PASS नहीं कहा जा सकता।
- Refund ID absent होने पर provider list की पहली 100 entries में exact match न मिले तो endpoint `safe_to_retry=false` देता है और “refund नहीं हुआ” नहीं मानता। Pagination/late visibility की जाँच अलग operational limitation बनी हुई है; कोई नया refund अपने-आप नहीं बनाया जाता।
- GPT-2 checklist अभी **27/39 = 69% पूरा; 12/39 = 31% बाकी**। यह test-only coverage है, checklist acceptance नहीं। कोई Production DB, provider refund, payout, merge या deployment नहीं किया।


## 2026-11-15 — Founder portrait integration (GPT-1)
- उपयोगकर्ता के स्पष्ट निर्देश पर पहले से अपलोड की गई स्वीकृत founder image `assets/srk-founder.jpg` को `welcome.html` के Founder card में वास्तविक `<img>` के रूप में जोड़ा गया। फोटो को AI से बदला/रीटच नहीं किया; card के `.88` aspect-ratio में CSS `object-fit: cover` से crop-fit किया गया है।
- PWA service worker cache version `srk-electronic-v10` किया और founder image को offline asset list में शामिल किया।
- `tests/welcome-screen-contract.test.js` में वास्तविक फोटो reference और cache inclusion के contract assertions जोड़े।
- यह feature branch पर source integration है; PR #8 अभी unmerged है, इसलिए production/live website पर फोटो दिखना अभी deployment/merge के बाद ही संभव होगा। Browser/mobile visual QA अभी pending है; consolidated final mobile QA सभी implementation के बाद ही होगा।

### GPT-2 Refund Recovery pagination hardening — 15 Nov 2026
- Razorpay payment refund-list endpoint में `count` और `skip` pagination supported है; अधिकतम 100 refunds प्रति page। अब Refund Recovery और read-only Refund Status दोनों `skip=0,100,...,900` तक bounded pages जाँचते हैं।
- हर page पर exact Payment ID, amount, INR currency और internal refund-record note अथवा idempotency receipt match आवश्यक है। सभी उपलब्ध pages scan किए बिना unmatched refund को final “not found” नहीं कहा जाता।
- Page overlap/duplicate IDs, malformed response या 1,000-record bound पूरा हो जाने पर lookup unresolved रहता है; कोई evidence finalization, नया refund, retry या payout release नहीं होता।
- Regression tests में दूसरे page पर exact match और पूरे उपलब्ध pages में no-match दोनों शामिल हैं। Feature Branch Node CI run `43719423933` सफल: **159/159 PASS**। PR run `43719428584` भी सफल।
- यह source/test coverage है; Razorpay live account pagination, PostgreSQL/pgTAP runtime, concurrent provider list mutation और Production DB अभी validate नहीं हुए।
- GPT-2 checklist **27/39 = 69% पूरा; 12/39 = 31% बाकी**—इस quality hardening से checklist count नहीं बदला।

## 2026-11-15 — GPT-1 CI follow-up correction
- ऊपर दर्ज Work Timer CI failure का कारण migration में fixed search_path configuration नहीं, बल्कि regression test की over-escaped JavaScript regular expressions थीं। Test को literal source assertions से ठीक किया गया; migration की अंतिम hardening configuration search_path = '' ही रखी गई।
- Feature Branch CI run #622 (5a6f5e0585a3448be87b22c5124cc10281686a00) SUCCESS हुआ। यह Node test suite (no secrets, no deployment) है; इससे PostgreSQL runtime/pgTAP या mobile/browser visual QA pass होने का दावा नहीं किया जा रहा।
- server_authoritative_work_timer.test.sql में plan(20) और 20 test assertions का static count मेल खाता है। pgTAP को database पर चलाना अभी बाकी है।
- Founder photo integration के source-contract/cache tests सहित branch Node CI अब green है। PR #8 अभी unmerged है; production deployment नहीं किया गया।
- Work Timer / completion / dispute acceptance अभी runtime DB, role-based RPC, booking-to-bill E2E और consolidated mobile QA के बिना incomplete है।

### GPT-2 Refund Recovery full-amount finalization guard — 15 Nov 2026
- New migration `20261115240000_harden_refund_recovery_full_amount.sql` strengthens `srk_service_finalize_razorpay_refund_from_recovery_evidence(uuid)`: after locking the booking, provider-evidence `amount_paise` must equal `round(service_bookings.amount_paid*100)` or it raises `RECOVERY_REFUND_AMOUNT_DOES_NOT_MATCH_FULL_BOOKING_COLLECTION`. Partial/stale evidence cannot be promoted to full-refund booking state.
- `supabase/tests/database/durable_razorpay_refund_recovery_evidence.test.sql` updated to plan 35; exact plan/assertion count verified 35/35 by source count. PostgreSQL/pgTAP runtime has not been executed.
- An initial migration timestamp collided with GPT-1's `20261115210000` migration. GPT-2 renamed its migration to unique version `20261115240000`; current migration-tree audit shows only the known `20261109` legacy duplicate pair remains.
- Latest PR #8 Node CI on shared head `16a51906ea55bf009f2935e2892eab90a72ef105`: **158/160 PASS, 2 FAIL**. Both failures are GPT-1 Booking Lifecycle source assertions (tests 25/26) still expecting the old `p.id=b.assigned_electrician_id` and `p.user_id/auth_user_id` predicate form after GPT-1's multi-profile authorization change. GPT-2 did not edit GPT-1 files. Migration-version uniqueness test now passes.
- GPT-2 scope remains **27/39 = 69% complete; 12/39 = 31% remaining**. This is additional source hardening, not a checklist item closure. No Production DB migration, real provider refund, payout, PR merge or deployment occurred.
- Follow-up Node regression test `tests/admin-refund-and-staff-access.test.js` now verifies the recovery migration locks the booking, compares evidence amount to the full `amount_paid` in paise, raises the explicit mismatch error, and still matches provider refund amount to audit evidence.
- Latest Feature Branch Node CI run `43720166061` on commit `6758f9a246d5ff4bf3715ccc26c2d5cf432b1421` succeeded: **161/161 PASS**. The earlier 158/160 result was transient; GPT-1 subsequently corrected the two lifecycle test expectations, and a later shared-branch run passed 160/160 before this additional GPT-2 test.
- Isolated PostgreSQL/pgTAP runtime is still blocked: existing `.github/workflows/supabase-schema-ci.yml` only permits dispatch on old branch `feature/platform-fee-cash-online-cycle`, exports a production schema via `SUPABASE_DB_URL`, and applies only five hard-coded older migrations. No production secret was used and workflow was not dispatched. The repository has no `supabase/config.toml`; current migrations depend on a pre-existing schema and legacy version collision `20261109`, so a safe disposable baseline/schema fixture and migration replay plan must be prepared before claiming DB runtime coverage.
- Latest Node CI is source-level regression coverage only; PostgreSQL/pgTAP runtime remains pending. PR #8 remains Draft/Open/Unmerged; no Production DB access/migration, real refund, payout, merge or deployment.

## 2026-11-15 — GPT-1 Timer और Dispute source audit

- Feature Branch पर server-authoritative work timer migration, admin work-event/review migration, customer-safe timeline migration और multi-profile electrician bill access migration दोबारा पढ़ीं।
- pgTAP source-plan मिलान: `server_authoritative_work_timer.test.sql` में 20 planned assertions और 20 assertion calls; `admin_work_dispute_review.test.sql` में 12 planned assertions और 12 assertion calls। यह केवल source count है, pgTAP execution/pass नहीं।
- Booking lifecycle Node contract test में customer ownership + row locks, server timestamps, completion approve/reject/dispute branches, immutable bill access और empty search_path/private authorization checks मौजूद हैं। Node suite का पिछला CI #654 PASS था; इस audit के बाद कोई नया CI परिणाम दावा नहीं किया जा रहा।
- मुख्य functional gap की पुष्टि: `srk_admin_get_booking_work_review(uuid)` केवल booking/events/bill/complaints पढ़ता है। Dispute स्वीकार/निर्णय, rework निर्देश, refund/adjustment या final resolution दर्ज करने वाला Admin decision RPC/state transition इस checked migration set में मौजूद नहीं है। इसलिए dispute review को read-only और अधूरा माना जाएगा; कोई व्यावसायिक निर्णय/राशि नियम अनुमान से नहीं जोड़ा गया।
- सुरक्षा सीमाएँ: work-event table browser roles से सीधे unreadable है; append-only row mutation/truncate triggers मौजूद हैं; customer timeline event snapshots नहीं लौटाती।
- **केवल source/static audit**: PostgreSQL/pgTAP runtime, role-based RPC tests और booking-to-dispute E2E अभी नहीं चले। कोई migration database पर लागू नहीं की गई; Production, PR merge, deployment और mobile QA नहीं बदले।


### GPT-2 Provider Refund Reconciliation full-amount guard — 15 Nov 2026
- Refund chain audit में एक अतिरिक्त defense gap मिला: Netlify executor और signed webhook provider amount को internal refund record से मिलाते थे, और recovery finalizer full booking collection जाँचता था; लेकिन trusted SQL reconciliation RPC स्वयं processed result पर booking के पूरे captured amount से अलग जाँच नहीं करता था।
- नई source migration `20261115250000_harden_refund_reconcile_full_amount.sql` में booking row को पहले lock करके `srk_razorpay_refunds.amount_paise` की तुलना `round(service_bookings.amount_paid*100)` से की। Processed refund partial/zero/mismatched collection हो तो `PROVIDER_REFUND_AMOUNT_DOES_NOT_MATCH_FULL_BOOKING_COLLECTION` से transaction रुकता है; pending/failed state handling और failed refund पर payout hold release logic अपरिवर्तित हैं।
- नया pgTAP contract `refund_reconcile_full_amount_guard.test.sql`: plan 5 और पाँच assertion calls; source count 5/5। Node regression test `admin-refund-and-staff-access.test.js` में SQL full-amount guard, booking lock और service-role grant की जाँच जोड़ी।
- नया commit chain: migration `a08e6992c2accfb8a6f7a423c27b1d8fc3a9ace1`; pgTAP `fccc4eb6930743509b7ce7c383de7b1e7c7d326f`; Node test `eb7c0ff6480adc947d77abc871292ac228dd2af6`.
- शुरुआती status snapshot में Node run उपलब्ध नहीं था; बाद में GitHub Actions run `43720719042` (PR) / `43720713268` (push) उसी अंतिम commit `feba12934237c06c036741e67d0fb6f3f8586839` पर SUCCESS मिला: **162/162 Node tests PASS**। यह source-level Node suite है; pgTAP अभी वास्तविक PostgreSQL पर execute नहीं हुआ। Vercel का अलग build-rate-limit status deployment/build limitation है, Node test failure नहीं।
- GPT-2 checklist **27/39 = 69% पूरा; 12/39 = 31% बाकी**—यह अतिरिक्त सुरक्षा hardening है, checklist closure नहीं। PR #8 Draft/Open/Unmerged; कोई Production DB migration, provider refund, payout, merge या deployment नहीं किया।


## 2026-11-15 — Timer authorization schema qualification follow-up

- Base timer migration में private authorization tables के 12 INSERT/DELETE references की जाँच की; सभी references schema-qualified `srk_private.work_timer_authorizations` या `srk_private.work_transition_authorizations` हैं। पहले test coverage केवल customer work-start/completion fix migration पर थी।
- `tests/booking-lifecycle-serialization.test.js` में base timer migration के INSERT/DELETE schema qualification और unqualified table-name rejection के assertions जोड़े। Commit: `09313ee5`। यह source test addition है; Node test execution अभी प्रमाणित नहीं है।
- Dispute complaint insert में `category='service_quality'` है और Customer UI में यह category मौजूद है। लेकिन इस Feature Branch audit में complaint base-table CREATE migration/schema और required columns/constraints नहीं मिले; इसलिए insert compatibility अभी unverified है। कोई अनुमानित schema या migration नहीं जोड़ी।
- Admin work-review RPC केवल read-only review देता है; अंतिम dispute decision/rework/financial adjustment का RPC नहीं मिला। निर्णय के व्यावसायिक परिणाम अभी स्पष्ट नहीं हैं, इसलिए कोई स्वतः bill, timer restart, refund या payout बदलाव लागू नहीं किया।
- कोई database migration लागू नहीं की गई; Production, PR merge, deployment और mobile QA अपरिवर्तित। PostgreSQL/pgTAP, Node runtime और E2E execution बाकी हैं।


## 2026-11-15 — Timer/complaint audit clarification

- Follow-up review confirmed the base timer migration already had all 12 private authorization INSERT/DELETE references qualified with the `srk_private` schema. Commit `1c97a923` did not change the SQL blob; it must not be counted as a SQL fix. The meaningful change is the added Node source-contract assertions in `09313ee5`.
- Located the Customer complaint contract migration `20261114202250_customer_complaint_customer_safe_projection.sql`: allowed categories include `service_quality`, and complaint creation uses `booking_id, customer_user_id, category, description`, matching the timer dispute insert at the column/category level. The base CREATE TABLE definition and its full constraints were not present among the inspected PR-changed migrations, so full schema compatibility remains unverified.
- Support conversation schema adds customer/Admin messages and attachments, and Admin can send replies; this is not a dispute-resolution decision workflow. No reviewed function was found to record an Admin finding, rework order, or financial adjustment for a completion dispute.
- No production or database changes. Runtime tests, migration-chain validation, and final dispute decision policy remain pending.


## 2026-11-15 — GPT-1 timer/dispute UI audit (continued)
- Electrician App review found that the completion-request button remained visible while a booking was in `disputed` state, even though the separate dispute message said to wait for Admin review.
- Fixed the client condition so the completion/timer action is hidden for both `pending` and `disputed` completion states. Customer rejection remains eligible to resume normal work flow according to the server RPC.
- Added a source-contract assertion to prevent the disputed-state completion action from reappearing.
- Commits: `ec1d02286cb74c184f105bef2e199adceb191e6a` (Electrician UI), `a3be062ab70770f79542841fc66f225764735765` (contract test).
- This is a source-level fix only. No migrations were applied, no database was changed, and no live deployment or manual mobile test was performed. Automated tests/CI have not yet been run for these commits.
- Remaining blocker: Admin dispute resolution outcomes and any resulting timer/financial behavior require explicit business rules and GPT-2 coordination; do not implement assumptions.


## 2026-11-15 — GPT-2 Refund ↔ Payout lock-order और settlement audit (source-only)

- Feature Branch migration `20261114360000_new_category_electrician_payout_reconciliation.sql` में Admin payout RPC पहले booking row lock (`FOR UPDATE`) और फिर payout row lock लेता है; केवल `pending` payout को Paid दर्ज कर सकता है। यह वास्तविक बैंक transfer नहीं करता—Admin द्वारा बाहर भुगतान के बाद UTR/reference दर्ज होता है।
- New-category payout के लिए completed booking, verified payment, immutable labour bill और electrician assignment मिलते हैं; settled cancellation fees को booking collection में जोड़ा जाता है, पर electrician payable/commission base से अलग रखा जाता है। कोई reserved fee बची हो तो payout reject होता है।
- Refund reconciliation migration `20261115250000_harden_refund_reconcile_full_amount.sql` और recovery finalizer `20261115240000_harden_refund_recovery_full_amount.sql` भी booking-first lock लेते हैं। Processed refund केवल पूरे captured booking amount के बराबर evidence पर स्वीकार होता है; refund hold से unrelated Admin-blocked या पहले से paid payout को स्वतः release/overwrite नहीं किया जाता।
- Source review से booking-first lock order दोनों paths में consistent दिखा; इससे intended serialization contract स्पष्ट है, लेकिन concurrent payout-vs-refund race का PostgreSQL runtime प्रमाण नहीं है। Double-submit, refund-after-payout, trigger execution और rollback behavior अभी isolated PostgreSQL/pgTAP में चलाना बाकी है।
- Node test file में full-amount reconcile/recovery guards के source assertions मौजूद हैं; ये SQL execution का विकल्प नहीं। Current PR #8 head `63c95b0bd4c2cade65f2aafd7a2618516c3a9a8e` का latest Node CI run `43721372919` failed हुआ: test 33 `booking-lifecycle-serialization.test.js` base Timer migration के schema-qualified INSERT को गलत Migration में ढूँढ रहा है। GPT-2 ने GPT-1 की shared test/migration files नहीं बदलीं।
- Checklist counts अपरिवर्तित: GPT-2 **27/39 = 69%**, 12 शेष। PR #8 Draft/Open/Unmerged; कोई Production DB change, real refund/transfer, merge या deployment नहीं।


## 2026-11-15 — Disposable PostgreSQL baseline feasibility review

- Feature Branch के recursive Git tree में कुल 71 SQL migration files मिलीं।
- `COMPLETE_DATABASE_SETUP.sql` में केवल 5 base tables (`service_bookings`, `electrician_applications`, `electrician_profiles`, `job_offers`, `srk_admin_users`) हैं; यह 71 migrations के पूरे dependency baseline का प्रमाण नहीं है। `SUPABASE_SCHEMA.sql` में 4 tables और `PORTAL_SCHEMA.sql` मुख्यतः auth.users तथा portal linkage पर निर्भर है।
- मौजूदा `.github/workflows/supabase-schema-ci.yml` पुराने branch ref पर gated है, `SUPABASE_DB_URL` secret मांगता है और Production से schema dump करता है; यह नई feature branch के लिए isolated-from-scratch migration harness नहीं है। इसे trigger नहीं किया गया। कोई production secret, schema export या database access नहीं हुआ।
- निष्कर्ष: अभी disposable PostgreSQL/pgTAP baseline को reproducible और complete कहना संभव नहीं। अगला सुरक्षित कदम migrations की dependency graph और Supabase platform prerequisites (auth/storage/extensions/roles) को catalog करके अलग local-only fixture बनाना है; उसके बाद ही ephemeral PostgreSQL CI जोड़ना उचित होगा।
- कोई migration/test file या workflow बदली नहीं गई; केवल यह feasibility finding progress log में दर्ज है। GPT-2 checklist **27/39 = 69%** अपरिवर्तित। PR #8 Draft/Open/Unmerged; Production पर कोई बदलाव नहीं।


## 2026-11-15 — Migration dependency graph और local-test prerequisites (source inventory)

- सभी 71 `supabase/migrations/*.sql` फ़ाइलों की सूची निकाली और शुरुआती, वित्तीय-core, customer/storage, dispatch/work-timer, payout/RBAC, refund, route और push-delivery migration समूहों के प्रमुख table/function declarations तथा platform references का नमूना audit किया।
- यह migration folder अकेले self-contained baseline नहीं है: शुरुआती migrations पहले से मौजूद `public.service_bookings`, `public.electrician_profiles`, `public.electrician_applications`, `public.job_offers` जैसी tables पर `ALTER TABLE`/policies/functions लगाती हैं। पुराने consolidated setup में केवल 5 tables हैं और उससे सभी नए columns, indexes, triggers, constraints और helper schemas का parity सिद्ध नहीं होता।
- Local fixture को Supabase platform objects की जरूरत होगी: `auth.users`, `auth.uid()`, कम-से-कम `anon/authenticated/service_role` roles, `storage` schema/objects और private schemas/permissions; कुछ customer avatar/address migrations Storage objects को reference करती हैं। वास्तविक local harness में exact object contracts को source से पूरा enumerate करना बाकी है।
- दो पुराने migration filenames का version prefix `20261109` साझा है। मौजूदा Node guard इसे explicit approved legacy collision के रूप में allowlist करता है और स्पष्ट करता है कि production migration-history reconciliation अभी बाकी है। इसे चुपचाप rename नहीं किया जाएगा, क्योंकि deployed history प्रभावित हो सकती है।
- Repository में 33 pgTAP SQL contract files मौजूद हैं; Node test केवल उनके `plan()` बनाम assertion-call counts जाँचता है, PostgreSQL पर उन्हें execute नहीं करता। इसलिए अभी SQL runtime correctness का दावा नहीं।
- इस चरण में कोई migration, fixture, CI workflow या GPT-1 shared file नहीं बदली गई। केवल source inventory; GPT-2 checklist **27/39 = 69%** अपरिवर्तित। Production/secret access नहीं।
- अगला कदम: minimal base schema को स्पष्ट dependency order में अलग local-only fixture के रूप में डिजाइन करना, Supabase platform stubs को test-only रखना, फिर disposable PostgreSQL में migrations और pgTAP execute करने से पहले clean-room replay का dry-run।


## 2026-11-15 — Isolated PostgreSQL baseline design और local runtime availability

- नया डिज़ाइन दस्तावेज़ `docs/LOCAL_POSTGRES_BASELINE_DESIGN_HI.md` जोड़ा। इसमें disposable-only PostgreSQL bootstrap, Auth/Storage test doubles, legacy application baseline, explicit migration replay, duplicate-version stop condition, pgTAP execution और CI isolation के acceptance gates दर्ज हैं।
- Baseline को छह layers में अलग रखा: PostgreSQL roles/extensions/schemas, Auth, Storage, legacy application tables, migration replay और वास्तविक pgTAP execution। किसी table/column को अनुमान से जोड़ने के बजाय पहले source-backed dependency manifest बनाने का नियम रखा।
- Local environment जाँच में `psql`, `postgres`, `docker`, `podman` और `pg_virtualenv` उपलब्ध नहीं मिले; इसलिए इस session में disposable PostgreSQL/pgTAP runtime चलाना संभव नहीं। कोई fake runtime PASS या SQL execution दावा नहीं।
- PR #8 फिर से जाँचा: Open, Draft, Unmerged; head `92667b07b41006e084dafa1c99a50e8f1136373a`। कोई merge/deploy नहीं।
- केवल नया Hindi design document commit किया; कोई migration, fixture, workflow, Production DB या GPT-1 shared source file नहीं बदली। GPT-2 checklist **27/39 = 69%** अपरिवर्तित।
- अगला कदम: सभी migration SQL और pgTAP tests से exact table/column/platform-object dependency manifest निकालना; उसके बाद ही executable fixture या CI service पर काम।


## 2026-11-15 — SOS accidental-tap protection requirement approved
- उपयोगकर्ता ने Active Work स्क्रीन के लिए स्पष्ट SOS confirmation flow मंजूर किया: SOS control पर पहला tap केवल तीन स्वीकृत कारण दिखाएगा; कारण चुनने के बाद अलग “SOS भेजें” button दबाने पर ही alert/case बनेगा। केवल पहला tap या कारण चयन कोई alert/SMS नहीं भेजेगा।
- SOS button काम शुरू होने से काम पूरा/बुकिंग रद्द होने तक Active Work screen पर रहेगा।
- कोई अतिरिक्त user-entered booking ID/details/location field नहीं। Booking और actor context authenticated active booking/session से server-side निर्धारित होगा। उपलब्ध location ली जा सकती है; location unavailable/permission denied होने पर SOS block नहीं होगा।
- Requirement document updated: `docs/SRK_ELECTRONIC_SOS_EMERGENCY_ALERT_REQUIREMENT_20261115.md`; commit `5d4296e9`।
- **स्थिति: requirement/documentation approved; Customer/Electrician UI code change और test update अभी बाकी।** कोई Node/runtime test, DB migration, production change, merge या deployment इस update में नहीं किया गया।


## 2026-11-15 — 71 migrations का dependency inventory (प्रारंभिक)

- Feature Branch के सभी 71 SQL migration files का source fetch करके शुरुआती application-table dependencies, later migration-created tables और Supabase platform references का पहला inventory बनाया।
- मुख्य pre-existing table candidates: `service_bookings`, `electrician_applications`, `electrician_profiles`, `job_offers`; आगे के code में `srk_admin_users`, `srk_booking_complaints`, `srk_booking_complaint_events`, `srk_push_subscriptions` भी पहले से मौजूद schema dependencies के रूप में संदर्भित हैं। इनके exact DDL/columns/constraints की line-by-line पुष्टि अगला चरण है।
- इस chain में बनाए जाने वाले financial, customer/support, dispatch/work-event, RBAC, refund, webhook और push-ledger tables को baseline में duplicate न करने का नियम दर्ज किया।
- Auth/Storage roles, schemas और helper contracts को अलग test-only platform bootstrap में रखने की जरूरत दर्ज की। SQL regex scan में CTE/PLpgSQL aliases false positives दे सकते हैं; इसलिए inventory को प्रारंभिक working list कहा गया है, final schema contract नहीं।
- नया दस्तावेज़: `docs/MIGRATION_DEPENDENCY_INVENTORY_HI.md`। कोई migration, test, workflow या GPT-1 shared source file नहीं बदली। Production/secret access नहीं; SQL runtime/pgTAP अभी execute नहीं हुआ।
- GPT-2 checklist **27/39 = 69%** अपरिवर्तित। अगला कदम: इन baseline tables के exact column/key/constraint contracts को source statements से निकालना।


## 2026-11-15 — Core baseline DDL contract extraction (source-backed, partial)

- Added `docs/CORE_BASELINE_DDL_CONTRACT_HI.md`.
- `SUPABASE_SCHEMA.sql` और `PORTAL_SCHEMA.sql` की वास्तविक CREATE TABLE definitions से पाँच legacy objects की base contract दर्ज की: `service_bookings`, `electrician_applications`, `electrician_profiles`, `job_offers`, और `srk_admin_users`. Columns, types, null/default, primary/foreign keys, base checks, indexes और RLS/policy notes अलग-अलग दर्ज हैं।
- Booking workflow की दो `20261109` migrations और Maps coordinate migration के अतिरिक्त बदलाव अलग layer में दर्शाए; legacy base DDL को final schema नहीं कहा।
- `srk_booking_complaints`, `srk_booking_complaint_events`, और `srk_push_subscriptions` की exact authoritative CREATE definitions अभी नहीं मिलीं; इनके लिए कोई columns/keys अनुमान से नहीं बनाए।
- `COMPLETE_DATABASE_SETUP.sql` को बिना reconciliation पूरा baseline मानने से स्पष्ट रूप से रोका; migration version collision पर rename/reorder नहीं किया।
- Commit: `414b1420c07c92b08ff0feb274e916c9645ebc4b`.
- Source-only documentation; कोई migration/test/runtime/Production DB/provider/merge/deployment action नहीं। PostgreSQL और pgTAP runtime अभी असत्यापित।
- GPT-2 checklist unchanged: 27/39 = 69%; 12/39 remaining.


### 2026-11-15 — Core baseline dependency audit विस्तार
- `docs/CORE_BASELINE_DDL_CONTRACT_HI.md` में complaint base tables और push subscription base की source-backed dependency जानकारी जोड़ी।
- Branch migration tree में `srk_booking_complaints`, `srk_booking_complaint_events` और `srk_push_subscriptions` की base `CREATE TABLE` definitions नहीं मिलीं; इसलिए इनके पूरे DDL को unresolved रखा गया, अनुमान से fixture नहीं बनाया।
- Complaint RPC से आवश्यक columns और ownership/rate-limit contract दर्ज किया; complaint messages/attachments को migration-created child tables के रूप में अलग पहचाना।
- Push outbox migration से subscription के पाँच required columns तथा RLS/grants/own-row policies दर्ज किए; private outbox और per-subscription delivery ledger को अलग migration-created objects के रूप में पहचाना।
- केवल दस्तावेज़ बदले; कोई SQL migration, test, production DB, payment, push send या deployment नहीं किया। PostgreSQL/pgTAP runtime अब भी बाकी है।
- GPT-2 checklist अपरिवर्तित: **27/39 = 69%**, **12/39 = 31% शेष**।


### 2026-11-15 — Legacy baseline cross-check
- `COMPLETE_DATABASE_SETUP.sql`, `SUPABASE_SCHEMA.sql` और `PORTAL_SCHEMA.sql` में complaint base और push subscription base की `CREATE TABLE` definitions नहीं मिलीं।
- GitHub code search में भी इन तीनों base tables के लिए भरोसेमंद DDL source नहीं मिला। `COMPLETE_DATABASE_SETUP.sql` को पूर्ण baseline मानना इसलिए गलत होगा; यह मुख्य booking/application/profile/job-offer/admin objects तक सीमित है।
- निष्कर्ष: complaint और push base tables के लिए वास्तविक schema source अभी unresolved है। Column types, defaults, PK/FK, constraints और मूल RLS policies अनुमान से नहीं जोड़े जाएँगे। Production schema/secret का उपयोग नहीं किया गया।
- दस्तावेज़ी audit जारी; कोई checklist item बंद नहीं हुआ। GPT-2: **27/39 = 69%**, शेष **12/39 = 31%**।


### 2026-11-15 — Complaint/Push consumer column contract विस्तार
- Complaint conversation, attachment, Admin reply और customer-safe projection migrations को line-level पर पढ़कर base complaint table के required consumer columns दर्ज किए: `id`, `customer_user_id` और complaint create/list RPC में प्रयुक्त booking/category/description/status/timestamp fields।
- Complaint event INSERT के छह explicit columns दर्ज किए।
- Push subscription के पाँच required consumer columns की सीमा दोबारा स्पष्ट की; SQL types, keys, uniqueness और base RLS अभी authoritative source के बिना unresolved हैं।
- यह केवल source-consumer contract है, complete DDL नहीं; कोई fixture/SQL/production change नहीं किया।
- GPT-2 checklist अपरिवर्तित: **27/39 = 69%**, **12/39 = 31% शेष**।


### 2026-11-15 — Historical branches से Complaint और Push base DDL recovery
- सभी उपलब्ध historical branch migration trees में खोजने पर Complaint base DDL मिला: `work/separate-customer-electrician-portals/supabase/migrations/20261110040000_customer_admin_complaints.sql`। इसमें complaints और complaint_events की columns, types, PK/FK, CHECK constraints, indexes, RLS और ACL posture स्पष्ट है।
- Push base DDL मिला: `feature/production-push-notifications/supabase/migrations/20261111090000_add_electrician_push_subscriptions.sql`। इसमें पूर्ण subscription table, Auth FK, unique endpoint, length checks, user index और own-row RLS/ACL स्पष्ट हैं।
- पहले current-branch-only audit में इन्हें unresolved बताया गया था; अब historical repository source recovery के बाद DDL source-backed है। यह historical migration को current release में सीधे replay करने की अनुमति नहीं है।
- दोनों स्रोतों का विवरण `docs/CORE_BASELINE_DDL_CONTRACT_HI.md` में दर्ज किया। अभी भी exact baseline assembly, historical/current migration overlap और dependency order का audit बाकी है।
- कोई Production/database access या बदलाव नहीं; कोई migration apply नहीं; PostgreSQL/pgTAP runtime अभी execute नहीं हुआ।
- GPT-2 checklist अपरिवर्तित: **27/39 = 69%**, **12/39 = 31% शेष**।


### 2026-11-15 — पाँच core base table DDL स्रोतों का historical mapping
- पुराने repository commit `08e5ff8abc1cf2a5e2ae656a951f8f4d8863247b` में `SUPABASE_SCHEMA.sql`, `PORTAL_SCHEMA.sql` और consolidated setup की जाँच की।
- `service_bookings`, `electrician_applications`, `electrician_profiles`, `job_offers`, `srk_admin_users` के historical starter DDL source paths और मुख्य column/constraint contracts दस्तावेज़ में दर्ज किए।
- स्पष्ट किया कि पुरानी `CREATE TABLE IF NOT EXISTS` setup files current Production/Feature Branch parity export नहीं हैं; वे timer, bill, refund, payout, wallet, support और अन्य बाद के contracts का पूरा आधार नहीं देतीं।
- अगला तकनीकी कदम: current branch की सभी migrations को dependency graph में रखना, historical base sources के साथ object-by-object diff बनाना, और unresolved/duplicate timestamp blockers दर्ज करना। बिना इस reconciliation के disposable DB को parity-ready नहीं कहेंगे।
- कोई database/Production access या बदलाव नहीं; कोई migration apply नहीं; PostgreSQL/pgTAP runtime अभी execute नहीं हुआ।
- GPT-2 checklist अपरिवर्तित: **27/39 = 69%**, **12/39 = 31% शेष**।


### 2026-11-15 — 71 migrations का static dependency blocker audit
- Current Feature Branch में 71 migration SQL files गिने; duplicate version prefix `20261109` वाली दो files मिलीं। Rename/history repair नहीं किया।
- Starter schema और migration consumers के बीच दो महत्वपूर्ण unresolved prerequisites मिले: `service_bookings.amount_paid` (quote/commission migration इसे पढ़ता है, लेकिन repository में authoritative add-column/base DDL नहीं मिला) और `electrician_profiles.auth_user_id` (Google Maps approval migration इसे लिखता है, लेकिन authoritative add-column/base DDL नहीं मिला)।
- `customer_user_id` और GPS `location_lat/location_lng` के लिए संबंधित migration source पहचाने; `customer_suggested_amount/electrician_quote_kind` restoration migration amount_paid का विकल्प नहीं है।
- Findings और safe next steps `docs/CORE_BASELINE_DDL_CONTRACT_HI.md` में दर्ज किए। Complete disposable parity baseline अभी blocked है; production history या schema में कोई बदलाव नहीं।
- कोई migration execute नहीं हुई; PostgreSQL/pgTAP runtime अभी नहीं चला।
- GPT-2 checklist अपरिवर्तित: **27/39 = 69%**, **12/39 = 31% शेष**।


## 2026-11-15 — GPT-1 SOS UI CI verification completed

- SOS UI requirement document को successful rerun result के साथ अपडेट किया; commit `18e041e7d7bf3aec4d7f0de7e538bf5ec51424f1`।
- Workflow run `43726275569` के latest rerun attempt में Node test job `132849770691` सफल: **163/163 pass, 0 fail, 0 cancelled**।
- SOS दो-चरणीय UI contract test सहित Customer/Electrician source assertions पास हुए; पुराने SOS booking/details selector references दोनों app files में नहीं मिले।
- GPT-1 का SOS UI source + Node contract verification पूरा। Browser/mobile visual QA consolidated final mobile QA चरण तक स्थगित है।
- SOS का वास्तविक database RPC, Admin/Support acknowledgement queue, SMS/Push delivery और end-to-end alert अभी GPT-2 backend integration के बिना पूरा नहीं माना जाएगा।
- कोई production DB, merge, deployment या mobile QA इस चरण में नहीं किया गया।


## 2026-11-15 — GPT-1 SOS integration gate और documentation reconciliation
- GPT-1 ने Customer/Electrician SOS source और Node contract को पुनः पढ़ा: दोनों में तीन स्वीकृत reason codes, अलग अंतिम “SOS भेजें”, cancel/discard और केवल `p_reason` के साथ `srk_create_sos_alert` RPC call मौजूद है। SOS control Active Work `in_progress` स्थिति तक सीमित है।
- Latest recorded CI run `43726275569`, job `132849770691`: **163/163 Node tests पास**। यह source/Node verification है; browser/mobile runtime या live backend delivery नहीं।
- SOS requirement document में पुराना विरोधाभासी वाक्य सुधारा और GPT-1/GPT-2 integration gate दर्ज किया; commit `038f9da4096f7df16b9d5a16cb9ded2aa957b3cb`।
- GPT-2 backend RPC, Admin/Support queue/acknowledgement, SMS/Push delivery और live E2E के लिए इस pass में सत्यापित evidence नहीं मिला; उन्हें pending ही रखा गया है। GPT-1 अगला कदम GPT-2 के वास्तविक contract/commit मिलने पर request/response और failure-state integration मिलाना है।
- कोई Production DB/provider action, merge/deploy या mobile QA नहीं किया गया।


## 2026-11-15 — GPT-1 Customer/Electrician/Welcome regression verification
- Latest documentation commit `7b23a2c4e7ef6012413957f4553acf44a9fab7b6` पर Feature Branch Node workflow run `43727009844` सफल रहा; job `132851037444` completed/success। Logs में **163 tests, 163 pass, 0 fail, 0 cancelled, 0 skipped** सत्यापित हुए।
- उसी run में Welcome Screen contract tests 162 और 163 पास हुए: approved founder photo reference/role routes और PWA start_url/offline cache entries की source assertions। `assets/srk-founder.jpg` branch में मौजूद है (blob SHA `b3e06e17aa8eedb9a8eb40ebc9e59088ebe9e11f`); `welcome.html` इसे `/assets/srk-founder.jpg` से लोड करता है और `sw.js` v10 cache में शामिल करता है।
- Customer/Electrician timer UI source दोबारा जाँचा: दोनों apps accumulated server seconds + server `work_started_at` से display timer बनाते हैं; हर सेकंड UI refresh होता है। इसे अनुमानित display के रूप में दिखाया गया है, अंतिम बिल server-recorded duration से ही बनेगा।
- यह source/Node regression verification है; वास्तविक browser rendering, image crop का visual approval, mobile device, database/pgTAP और full E2E runtime अभी नहीं जाँचे गए। इन्हें final consolidated QA में रखा गया है।
- कोई Production DB, merge या deployment नहीं किया गया।


## 2026-11-15 — Latest PR-head Node CI and historical DDL cross-check
- PR #8 के वर्तमान head `7b23a2c4e7ef6012413957f4553acf44a9fab7b6` पर Feature Branch Node workflow run `43727009844` सफल हुआ। Job `132851037444` में **163/163 tests pass, 0 fail, 0 cancelled**। यह Node/source test suite है; PostgreSQL/pgTAP, browser/mobile visual QA या Production parity का प्रमाण नहीं है।
- Historical `COMPLETE_DATABASE_SETUP.sql` और `SUPABASE_SCHEMA.sql` को पढ़कर पुष्टि की कि starter `service_bookings` definition में `amount_paid` नहीं है; `PORTAL_SCHEMA.sql` में `electrician_profiles.user_id` है, `auth_user_id` की add-column definition नहीं मिली।
- पाँच उपलब्ध historical feature/work branches में उसी Google Maps migration path और consolidated setup को cross-check किया: कोई `auth_user_id` add-column DDL या `amount_paid` base DDL नहीं मिला। यह खोज अभी भी अन्य historical commits/schema exports में source मिलने की संभावना को पूरी तरह समाप्त नहीं करती; दोनों dependencies unresolved रहेंगी।
- कोई schema/migration apply, Production access, merge, deploy या provider payment/refund action नहीं किया।
- GPT-2 checklist अपरिवर्तित: **27/39 = 69%**, **12/39 = 31% शेष**।


## 2026-11-15 — Core-column dependency cross-branch follow-up
- पाँच उपलब्ध historical feature/work branches में `COMPLETE_DATABASE_SETUP.sql` और Google Maps migration के समान paths cross-check किए; `service_bookings.amount_paid` तथा `electrician_profiles.auth_user_id` के authoritative ADD COLUMN/base DDL नहीं मिले।
- अतिरिक्त consumer मिला: `20261109010000_create_secure_wallet_ledger_foundation.sql` में wallet ownership resolution `coalesce(ep.auth_user_id, ep.user_id)` पढ़ता है। `amount_paid` को commission migration पढ़ती है, negative-value guard और column UPDATE grant में भी इस्तेमाल करती है।
- समान historical branch copies को स्वतंत्र provenance नहीं माना; exact column type/nullability/default/constraints/indexes/ownership अभी unresolved हैं। अनुमान से migration या fixture नहीं बनाया। Contract audit `docs/CORE_BASELINE_DDL_CONTRACT_HI.md` में बढ़ाया।
- PR-head Node run `43727009844` का परिणाम 163/163 pass है, लेकिन यह commit `7b23a2c4e7ef6012413957f4553acf44a9fab7b` पर था; उसके बाद documentation-only commits आए हैं, इसलिए इसे नए head की CI validation नहीं कहा जाएगा।
- कोई Production DB access, migration apply, merge/deploy या live provider action नहीं हुआ।
- GPT-2 checklist अपरिवर्तित: **27/39 = 69%**, **12/39 = 31% शेष**।


## 2026-11-15 — GPT-1 active-work UI regression guard added
- Customer और Electrician दोनों ऐप में timer/SOS panel की मौजूदा visibility conditions source से जाँचीं: Customer `status==='in_progress'`; Electrician `booking_status==='in_progress'`; completion review/dispute में Electrician timer action छिपा रहता है।
- इसी महत्वपूर्ण business rule के लिए Node contract test जोड़ा: Customer/Electrician SOS और timer केवल active in-progress booking पर render हों; Electrician completion-pending/disputed अवस्थाओं में completion timer action न दिखे।
- Test change commit: `70cca079e60f21aafba9db9c323a5336c410f886`। इस commit के लिए नया CI run अभी उपलब्ध नहीं मिला; इसलिए नया assertion PASS घोषित नहीं है। पिछले सत्यापित CI run में 163/163 tests पास थे।
- कोई app runtime, browser/mobile QA, DB/pgTAP, Production DB, merge या deployment नहीं किया गया। अगला कदम इस नए contract test का CI परिणाम सत्यापित करना है।


## 2026-11-15 — 71-migration static inventory and provisional dependency phases
- Current PR-head Git tree को recursive रूप से पढ़कर 71 SQL migration filenames/version prefixes की पूर्ण सूची निकाली; duplicate `20261109` prefix की दोनों files पुष्टि कीं। कोई unversioned migration file नहीं मिली।
- `docs/MIGRATION_REPLAY_MANIFEST_HI.md` बनाया: सभी 71 files का filename/version-sorted inventory, provisional dependency phases, hard blockers और safe next steps दर्ज हैं। यह executable replay order नहीं है; object-level dependency graph अभी बाकी है।
- PR #8 latest head `758fda100f9cf2e8a389347af0c79e6662fbd160` खुला Draft/Unmerged है। इस docs commit पर Vercel status `failure` दिखा और target URL build-rate-limit/upgrade notice है; इसे successful deployment/build नहीं माना गया। इस नवीनतम docs commit के लिए नया Node workflow run उपलब्ध नहीं मिला। पिछला 163/163 pass run `7b23a2c4e7ef6012413957f4553acf44a9fab7b` पर था।
- कोई SQL execute/apply, Production DB access, migration history edit, merge, deployment या provider refund/transfer नहीं किया।
- GPT-2 checklist अपरिवर्तित: **27/39 = 69%**, **12/39 = 31% शेष**।


## 2026-11-15 — GPT-1 active-work timer/SOS contract follow-up
- Customer और Electrician के वर्तमान HTML source को फिर से पढ़ा: दोनों timer display server के `work_started_at` + accumulated seconds से बनाते हैं और UI हर सेकंड refresh होती है; यह client display है, bill calculation नहीं।
- Customer SOS panel तथा Electrician SOS panel दोनों केवल चुनी category वाले `in_progress` काम पर दिखते हैं। Electrician completion request pending/disputed अवस्था में timer/completion action छिपा रहता है। नया regression assertion commit `70cca079e60f21aafba9db9c323a5336c410f886` में मौजूद है।
- महत्वपूर्ण backend integration gate: दोनों UI submit handlers अभी `srk_create_sos_alert` को केवल `{p_reason}` भेजते हैं। UI booking-card ID को RPC में नहीं भेजती। यह तभी सुरक्षित/सही है जब GPT-2 का backend authenticated actor और सही active booking को स्पष्ट, unambiguous तरीके से derive करे; अन्यथा multiple active bookings में case association अस्पष्ट हो सकती है। GPT-2 के वास्तविक SQL/RPC contract और response को देखे बिना signature बदलना या backend success मानना उचित नहीं।
- इस follow-up में code/DB नहीं बदला। PR #8 Draft/Open है; इस test commit के लिए नया Actions run उपलब्ध नहीं मिला।
- GPT-1 का उपलब्ध implementation checklist denominator अभी भी Customer 10 + Electrician 10 + Welcome/Founder 6 = 26 items है; latest recorded count **19/26 = 73%**, **7/26 शेष**। यह implementation checklist progress है, release readiness नहीं; नए regression assertion को अलग checklist item मानकर denominator नहीं बढ़ाया।
- अगला resume point: GPT-2 के `srk_create_sos_alert` SQL/RPC implementation को fetch करके authenticated actor/booking resolution, response schema और failure behavior का exact मिलान; फिर Customer/Electrician UI contract test चलने का CI evidence सत्यापित करना। Mobile QA अभी भी अंतिम consolidated pass के लिए deferred है।


## 2026-11-15 — 71 SQL migrations: object-level static scan
- सभी 71 migration files को SQL text स्तर पर scan करके CREATE/ALTER table targets, functions और triggers का migration-wise inventory तैयार किया। मुख्य dependency clusters: wallet ledger → cancellation fee accounting; complaint base → support messages → RBAC; financial audit base → payout/refund/reconciliation; push subscription/outbox → delivery ledger → health/lease fencing।
- `docs/MIGRATION_REPLAY_MANIFEST_HI.md` में object-change audit, provisional dependency clusters और unresolved ordering questions जोड़े। यह अभी static text scan है—PostgreSQL parser/runtime, pgTAP या full transitive dependency graph नहीं।
- Hard blockers कायम: duplicate `20261109` prefix; authoritative `service_bookings.amount_paid` और `electrician_profiles.auth_user_id` DDL अनुपलब्ध; complaint base DDL वर्तमान 71-file tree से बाहर और historical source को baseline में reconcile करना बाकी।
- कोई SQL execute/apply, Production DB access, migration rename/history repair, merge/deploy या live payment/refund/payout/push action नहीं किया।
- GPT-2 checklist अपरिवर्तित: **27/39 = 69%**, **12/39 = 31% शेष**।


## 2026-11-15 — GPT-1 Founder collage safety correction
- Feature Branch में `assets/srk-founder.jpg` को वास्तविक फोटो समझकर visually inspect किया: यह तीन mobile/app screenshots का collage है, original garden-background founder portrait नहीं। इसलिए इसे Founder portrait के रूप में दिखाना गलत था।
- `welcome.html` से collage image हटाकर उसी Founder card/layout में स्पष्ट temporary photo-slot रखा; किसी अन्य व्यक्ति/AI/generated image का substitution नहीं किया।
- `sw.js` cache version v10 से v11 किया और collage asset को offline precache से हटाया, ताकि पुराने installed PWA cache में भी गलत Founder image pinned न रहे।
- `tests/welcome-screen-contract.test.js` अपडेट किया: अब test सुनिश्चित करता है कि collage Founder portrait की तरह render न हो और pending-photo slot मौजूद हो।
- Commits: Welcome UI `ab9f704c21e0ad9a46b5e5080147db352f0a8b73`; Service Worker `96f6af8622879463c3848c93f1327d160094d4d6`; test `1919eee94e1109bb33f3e9e2814ffe3987dd99ed`। इस test commit पर अभी नया CI run उपलब्ध नहीं; PASS घोषित नहीं है।
- Original garden-background photo bytes इस session के Library/current files/reference images में नहीं मिलीं। अतः वास्तविक photo crop/integration अभी pending है; उपयोगकर्ता द्वारा भेजी गई exact photo के बिना substitute नहीं बनेगा। GPT-1 checklist नवीनतम source count **20/28 = 71%**, **8/28 शेष** ही रहेगा।
- PR #8 Draft/Open है; कोई merge, production deployment, database change या mobile QA नहीं किया।
- SOS cross-check: PR #8 changed-file list में अभी SOS backend migration/RPC या Admin/Support queue/SMS implementation नहीं है। GPT-1 UI `srk_create_sos_alert` को केवल `p_reason` भेजती है; GPT-2 backend contract उपलब्ध होने पर integration review बाकी है।


## 2026-11-15 — Customer Login founder-image consistency correction
- अतिरिक्त source audit में पाया कि Welcome Screen से गलत collage हटाने के बाद भी `customer-login.html` उसी `/assets/srk-founder.jpg` collage को Founder portrait के रूप में दिखा रहा था।
- Customer Login पर भी उसी Founder block/layout में सुरक्षित temporary photo-slot लगाया; गलत collage का उपयोग बंद किया। `tests/welcome-screen-contract.test.js` में Customer Login पर भी यही guard जोड़ा।
- Commits: Login UI `d5f48bf4ab70bca2a31ff18d40c5157fbc40844d`; regression test `ccd7a2346503d0c69d67def9120a0171ce8ccceb`। नया CI run अभी उपलब्ध नहीं; test PASS घोषित नहीं है।
- Source re-fetch के बाद जाँचे गए invariants: login placeholder मौजूद; login में collage image reference नहीं; Welcome placeholder मौजूद; Welcome में collage reference नहीं; PWA v11 और founder collage offline precache से बाहर।
- GPT-1 checklist **20/28 = 71%**, **8/28 शेष** — अभी checklist denominator/count में बदलाव नहीं। असली garden-background founder photo उपलब्ध होने पर ही दोनों screens में उसी crop का integration होगा।


## 2026-11-15 — PWA cache-version regression CI correction
- नए Founder-guard test commit `ccd7a2346503d0c69d67def9120a0171ce8ccceb` पर Node CI run `43728237766` चला। कुल 164 में 163 tests पास और 1 fail हुआ।
- Failure `tests/electrician-live-location-client.test.js` की stale assertion थी: वह Service Worker cache को `srk-electronic-v10` अपेक्षित कर रही थी, जबकि Founder collage हटाने के लिए वैध cache bump v11 किया गया था। यह app runtime failure नहीं, test expectation mismatch था।
- Assertion को v11 के अनुरूप ठीक किया; commit `e17d917781d8e8865f5ceaad3639ef100e4a8598`। इस correction के बाद CI run की प्रतीक्षा है; अभी PASS नहीं कहा जा सकता।


## 2026-11-15 — Older schema/branch provenance re-check
- Older finance/portal branches और `SUPABASE_SCHEMA.sql`, `PORTAL_SCHEMA.sql`, `COMPLETE_DATABASE_SETUP.sql` को cross-check किया। तीनों schema snapshots में `service_bookings.amount_paid` और `electrician_profiles.auth_user_id` की base column definition नहीं मिली।
- Finance branch की पुरानी quote migration `service_charge`, `materials_amount`, quote fields और `work_started_at` जोड़ती है, पर `amount_paid` नहीं; उसी migration के trigger/functions `amount_paid` पढ़ते हैं। Portal branch की manual-payment migration भी `amount_paid` UPDATE/validate करती है, पर column create नहीं करती।
- Portal branch की `20261109223000_sync_electrician_auth_profile_link.sql` `auth_user_id` में value लिखती और उसे lookup में इस्तेमाल करती है, पर column add नहीं करती। Direct electrician assignment migration भी उसे pre-existing मानती है।
- पुराने branches में duplicate `20261109` migrations अलग versioned filenames से मौजूद थीं; यह history clue है, current migration ledger repair का प्रमाणित तरीका नहीं।
- निष्कर्ष: `amount_paid` और `auth_user_id` के exact type/nullability/default/constraint/index contracts अभी भी authoritative source से unresolved हैं। कोई अनुमानित DDL नहीं जोड़ा गया। विवरण `docs/MIGRATION_REPLAY_MANIFEST_HI.md` के Section 5.7 में दर्ज।
- GPT-2 checklist अपरिवर्तित: **27/39 = 69%**, **12/39 शेष**। कोई database execution, Production access, migration rename, merge या deploy नहीं किया।


## 2026-11-15 — Founder Photo checklist instruction consistency
- Master checklist के Section 6 और पुराने contradictory historical wording को latest owner instruction के अनुरूप reconcile किया: approved photo केवल garden-background original है; blue-background/design-reference instruction superseded है।
- Checklist से गलत दावा हटाया कि original crop working file में तैयार है। अब साफ लिखा है कि original binary/crop दोनों pending हैं और वही crop Welcome Screen तथा Customer Login दोनों में लगना है।
- Master checklist commit `d606344e3235f05ab9f8405882b790ddab1f4cd0`। Re-fetch verification: master garden-photo instruction correct; false crop claim absent; Welcome और Customer Login दोनों में placeholder और collage-reference absent; Service Worker cache v11।
- GPT-1 progress **20/28 = 71%** अपरिवर्तित; यह documentation consistency fix है, नया checklist completion नहीं।


## 2026-11-15 — अतिरिक्त feature/fix branch consumer audit
- Flutter cash-payment migration `20261110235000` `amount_paid` write करती है और electrician identity के लिए `user_id/auth_user_id` दोनों पढ़ती है; कोई base-column DDL नहीं मिला।
- Category/hourly booking migration profile/booking के कई अन्य columns जोड़ती है, लेकिन `amount_paid` या `auth_user_id` नहीं; `auth_user_id` को पहले से मौजूद मानती है। Direct UPI report migration भी `amount_paid` update करती है, create नहीं करती।
- Google Maps migration केवल GPS coordinate columns जोड़ती है; उसी RPC में `auth_user_id` insert/update होता है। इससे usage सिद्ध है, column creation नहीं।
- Manifest Section 5.8 में cross-branch findings दर्ज। दोनों exact column contracts अब भी unresolved; कोई अनुमानित DDL नहीं जोड़ा।
- GPT-2 checklist **27/39 = 69%**, **12/39 शेष**।


## 2026-11-15 — Founder/cache regression fix CI verification
- Branch head `afbc1e756d88acc687106ee30be0f8d2a6289710` के PR #8 merge-check workflow `43728524339` सफल हुआ। Job `132855625792` में `npm test`: **164 tests, 164 pass, 0 fail**। Workflow ने PR merge commit `e322826b2ec5d5928ad84800c2182f9e335b08c0` checkout किया, जिसमें branch head शामिल था। पहले `e17d917...` पर run न दिखने की स्थिति अब इस newer branch-head check से supersede है।
- यह Node source/contract test suite है; PostgreSQL runtime, browser/visual QA, mobile QA, Vercel Preview या Production deployment का प्रमाण नहीं। Commit status में Vercel check अभी `failure` है और target बताता है `build-rate-limit`; इसलिए Preview build उपलब्ध/सफल घोषित नहीं है।
- SOS integration audit: Feature Branch के recursive tree में SOS-specific backend migration नहीं मिली और repository code search में `srk_create_sos_alert` implementation नहीं मिला। Customer/Electrician UI RPC call में केवल `p_reason` भेजते हैं। इसलिए secure booking/actor derivation और Admin/Support delivery अभी GPT-2 backend contract से verify नहीं हो सकते; GPT-1 client signature को अनुमान से नहीं बदलेगा।
- GPT-1 checklist progress **20/28 = 71%** ही है; CI verification ने existing source checklist count नहीं बदला।


## 2026-11-15 — GPT-2 object-level migration dependency sample + latest PR checks
- Current PR head re-verified: `7ce68ced66f6f7aa4a8211b125c0e20d75cda5bb`; recursive Git tree still contains 71 SQL migrations.
- A focused SQL-text scan of 14 high-impact migrations confirmed concrete dependency edges: wallet foundation creates wallet accounts/ledger/bank links; cancellation accounting alters/uses wallet ledger and depends on cancellation requests plus bookings; work-timer depends on bookings/electrician profiles and immutable labour bills; financial audit foundation creates labour bills, manual payments, payouts and refund/audit records; payout reconciliation functions consume that foundation; RBAC creates staff/permission/session/support-assignment objects and consumes complaint/message/ticket contracts; refund recovery depends on refund records and bookings; push outbox consumes job offers/subscriptions, then subscription delivery ledger and lease fencing extend that chain.
- This is a focused static scan of 14 files, not a complete transitive dependency graph or PostgreSQL parser/runtime. Exact execution order still must account for functions/triggers/policies and the unresolved baseline columns. No migration was applied.
- Latest PR-head Node workflow run `43728664954` completed successfully; the Node test job and all listed steps passed. Test count was not extracted in this check, so no numeric count is asserted here. This is not PostgreSQL/pgTAP or browser/mobile QA.
- Latest commit combined status: Netlify Deploy Preview is `success` at https://deploy-preview-8--srk-electronic-india.netlify.app; Vercel is `failure` with the free daily deployment limit notice. The Netlify preview success does not mean Production deployment. PR #8 remains Draft/Open/Unmerged.
- GPT-2 checklist remains **27/39 = 69%**, **12/39 = 31% शेष**; this audit/CI work does not close an implementation checklist item. No Production DB access, merge, production deployment, provider payment/refund/transfer, SMS/OTP or real push action occurred.


## 2026-11-15 — GPT-1 SOS contract consistency correction
- Progress document का पुराना पैरामीटर विवरण वर्तमान Customer/Electrician source और `tests/sos-two-step-ui-contract.test.js` से मेल नहीं खाता था। इसे ठीक किया गया: दोनों clients केवल `p_reason` भेजते हैं।
- Backend RPC definition, authenticated actor/active-booking derivation, Admin/Support queue और SMS/Push delivery अभी Feature Branch में सत्यापित नहीं हैं; इसलिए SOS end-to-end को अधूरा ही माना जाएगा।
- यह केवल documentation correction है; कोई runtime, database, deployment या production परिवर्तन नहीं किया गया।



## 2026-11-15 — GPT-1 README और SOS contract coverage update
- README के पुराने notification/status दावों को source और Main DB audit के अनुसार सुधारा: Push का source implementation मौजूद है, लेकिन provider/worker delivery और Main schema parity अभी सत्यापित नहीं; SMS/WhatsApp को सक्रिय नहीं बताया गया।
- README में स्पष्ट किया कि Feature Branch के नए Customer profile/address/support, immutable labour bill, cancellation-fee, refund-recovery और durable Push objects को Main Supabase में उपलब्ध नहीं मानना चाहिए; migration parity और isolated runtime tests अलग release gates हैं।
- Customer/Electrician SOS दो-चरणीय UI के लिए नया source contract test जोड़ा: active-work visibility, केवल तीन approved reasons, अलग final-send + confirmation, cancel पर selection discard, reason-only RPC payload और unconfirmed case पर success न दिखाना।
- SOS contract test: `tests/sos-two-step-ui-contract.test.js`; commits: test creation `6eb3a4f23b351d4028d3a06574d4079cf59a14c8`, assertion correction `e0ccdd74d4767aea23848a7cb46b01890e3f419f`; README correction `542dd281a9d8815ddb67a3dbd3a805043562b0e7`.
- Test file और README को branch से re-fetch करके content verify किया। इस नए test का CI run अभी उपलब्ध नहीं मिला; इसे PASS नहीं कहा जा रहा। SOS backend RPC/authorization/Admin queue/SMS/Push end-to-end अभी GPT-2 contract पर निर्भर है।
- GPT-1 checklist **20/28 = 71%** अपरिवर्तित; documentation/test coverage update को feature completion नहीं गिना गया। Founder garden photo, Vercel Preview, final runtime/browser/mobile QA और owner acceptance अभी pending हैं।
- कोई merge, Production deploy, database migration apply या paid service/staging creation नहीं की गई।


## 2026-11-15 — GPT-1 Customer navigation और SOS two-step correction
- Customer Profile के “सेव किए गए पते प्रबंधित करें” बटन से booking form Home tab के अंदर hidden हो सकता था। अब यह पहले Home tab activate करता है, फिर अगले animation frame में booking form और saved-address selector पर scroll/focus करता है। Commit: `de4cba4cfeb9f34c3f52c82ceeb6efb1c40600fd`.
- स्वीकृत SOS flow ठीक दो स्पष्ट user steps का है: SOS विकल्प खोलना/कारण चुनना, फिर अलग “SOS भेजें” बटन। पुराने अतिरिक्त browser confirm modal को Customer और Electrician submit handlers से हटाया; अंतिम बटन स्वयं explicit consent action है। Commits: Customer `e0d8185f00a36ce63e75e2feb5b6f1e6d09e9b8c`, Electrician `d40ef63f5433522d38f2ca34cc37992f71ec75d9`.
- SOS source contract test को अतिरिक्त modal के बजाय exact two-step flow verify करने के लिए बदला। Commit: `3075d10a5e4fb0e723ccadcf2f91962bc0f46fc1`.
- Updated source files re-fetch करके verify किए: दोनों SOS handlers reason-only RPC payload रखते हैं और extra confirm modal नहीं है। Customer saved-address navigation fix भी source में verify है। Node/CI/browser/mobile runtime test अभी इस नए commit पर प्रमाणित नहीं; कोई PASS दावा नहीं। Backend RPC/authorization/Admin queue/SMS/Push end-to-end GPT-2 dependency है।
- GPT-1 checklist **20/28 = 71%** अपरिवर्तित; ये source/contract alignment fixes हैं, नए checklist item completion नहीं। कोई merge, Production deploy, migration apply या paid staging creation नहीं।


## 2026-11-15 — Customer immediate-booking form correction
- Customer booking submit handler में पुराने `date`/`time` DOM fields पढ़े जा रहे थे, जबकि वर्तमान form में ये fields मौजूद नहीं हैं और `create-booking.js` स्पष्ट रूप से immediate-service dispatch करता है (`preferred_date`/`preferred_time` = `null`)। इससे submit के समय JavaScript null-element error होकर booking रुक सकती थी।
- पुराने date/time validation और nonexistent field focus को हटाया गया; immediate booking payload/idempotency/auth flow जस का तस रखा गया।
- Regression test `tests/customer-immediate-booking-contract.test.js` जोड़ा गया, जो nonexistent date/time reads और API contract mismatch को रोकता है।
- Commits: UI correction `b2e2fd9bb5b9faa06629d99f90657e44100d927a`; regression test `108caea1766fc85a4a881eb7077d337d85d65f74`.
- Source change verified by re-fetch. New CI run not yet visible; no browser/mobile runtime test, DB change, merge or deployment performed.
