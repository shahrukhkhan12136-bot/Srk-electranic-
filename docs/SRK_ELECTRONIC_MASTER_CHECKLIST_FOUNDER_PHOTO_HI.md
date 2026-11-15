# SRK ELECTRONIC — मुख्य मास्टर चेकलिस्ट (एकीकृत स्थिति)

**अंतिम मिलान:** 15 नवम्बर 2026  
**काम की branch:** `feat/customer-login-first-dashboard-20261114`  
**Repository:** `shahrukhkhan12136-bot/Srk-electranic-`  
**स्थिति का नियम:** [x] = Feature Branch source में implement/verified; इसका अर्थ Production पर लागू होना नहीं है। Runtime/Production/owner approval को अलग स्पष्ट रखा गया है। पुरानी विस्तृत कार्य-इतिहास `docs/SRK_ELECTRONIC_PROJECT_PROGRESS_HI.md` में है। इस checklist में duplicate पुराने pending items को बार-बार नहीं दोहराया जाएगा।

---

## 1. ग्राहक (Customer) — Feature Branch implementation

- [x] Customer booking form, account/login, booking history और profile source मौजूद। Customer OTP login में भारतीय मोबाइल normalization, SMS OTP verify, 60-sec resend cooldown और existing-session redirect source regression tests PASS (`tests/customer-electrician-otp-login.test.js`, CI `43704591567`).
- [x] Booking submission idempotency और customer-selected rate tier/server estimate source मौजूद।
- [x] Saved addresses और private avatar storage source मौजूद।
- [x] Payment method change, payment history और receipt RPC source मौजूद।
- [x] Customer refund request create/history RPC; customer ownership filter और private Admin note exclusion लागू।
- [x] Cancellation-fee debt और booking fee-item history RPC; authenticated-only execution ACL source में जोड़ी।
- [x] Customer cancellation request/fee carry-forward और refund reversal workflow source मौजूद।
- [x] Customer और electrician phone numbers acceptance से पहले छिपे; acceptance/assignment के बाद full number visible; Support Staff को unrestricted phone projection नहीं। `tests/customer-electrician-phone-visibility.test.js` में दोनों दिशाओं के authenticated/assignment-scoped source regression tests PASS (latest Node CI run)।
- [ ] पुराने quotation-based customer receipt path को हटाने के बाद नए labour bill और अलग materials receipt से reconcile करना बाकी है।
- [ ] Customer payment/refund/cancellation के सभी owner/non-owner/anon और duplicate/concurrency व्यवहार isolated database में runtime verify करें।

## 2. इलेक्ट्रिशियन (Electrician) — Feature Branch implementation

- [x] Electrician offer inbox/response और sequential nearest dispatch source मौजूद। Electrician SMS OTP login, 60-sec resend cooldown और auth-session portal gating source regression tests PASS (`tests/customer-electrician-otp-login.test.js`, CI `43704591567`).
- [x] Offer acceptance पर current location/district, active status और exact Admin-approved rate tier पुनः जाँचे जाते हैं।
- [x] Availability toggle और relocation request/Admin approval source मौजूद।
- [x] पुराने quotation approval workflow को Customer और Electrician UI से हटाया गया; कोई नया quote approval नहीं दिखाया जाएगा। Backend/Admin/payment dependencies की सुरक्षित retirement GPT-2 समन्वय में बाकी है।
- [x] New-category booking का server-authoritative work timer, customer-approved start/completion और immutable labour bill source मौजूद।
- [x] Live location consent, booking-scoped access और GPS/RPC failure cleanup source मौजूद।
- [x] Electrician KYC private document bucket, upload/list/preview, Admin review/audit और activation gate source मौजूद।
- [x] Electrician support tickets/replies, profile edit, phone-change approval, earnings/wallet projections source मौजूद।
- [x] Push opt-in, service worker, safe notification click-to-offer routing source मौजूद।
- [ ] KYC/Storage/OTP/activation, dispatch race, work timer, location sharing और availability/relocation के सभी actor/ownership flows isolated environment में runtime verify करें।

## 3. Admin और Support Staff — Feature Branch implementation

- [x] Main Admin और Support Staff role separation तथा assigned-support-inbox source मौजूद।
- [x] Staff invitation fixed Support role और Main Admin authorization source में guarded।
- [x] Admin refund review queue, approval/decline audit और Razorpay refund recovery evidence source मौजूद।
- [x] Approved manual refund record करने का RPC/UI path मौजूद; यह केवल पहले से वास्तव में भेजे गए refund को दर्ज करता है, पैसा नहीं भेजता।
- [x] Admin cancellation decision, stage evidence, reason, fee ledger और null-input hardening source मौजूद।
- [x] Admin payout recording RPC, booking-first locks, verified payment evidence और exact payout reconciliation source मौजूद।
- [x] KYC queue/review, rate-tier approval और activation checks source मौजूद।
- [x] Admin generic booking editor direct status write नहीं करता; legacy `new → confirmed` dedicated Main-Admin RPC से होता है।
- [x] Legacy Admin manual-payment RPC `srk_admin_record_manual_payment(uuid,text,text,text)` अब मौजूद; केवल Main Admin, completed/assigned/customer-approved quote, unpaid/pending, no Razorpay IDs, exact labour + materials total, receipt evidence और payout row।
- [x] Admin booking table में labour/materials/quote-status का अलग data box; approved quote total को अलग-अलग मदों से match करना अनिवार्य।
- [x] Read-only booking accounting reconciliation RPC/UI source मौजूद।
- [ ] Admin/Staff role, support assignment, phone visibility, refund/cancellation/payout/KYC और सभी direct table-write ACL को isolated DB + browser में actor-by-actor runtime verify करें।
- [ ] Admin customer-location/profile direct-edit paths और बाकी legacy direct updates का अंतिम privilege audit पूरा करें।

## 4. Payment, billing और accounting — approved business rules

- [x] Labour और materials अलग-अलग मदें हैं; materials पर platform commission नहीं लगाया जाता।
- [x] Electrician-supplied materials के लिए itemized materials amount; customer स्वयं सामग्री खरीद सकता है; unauthorized markup नहीं।
- [x] Legacy approved quote total = `service_charge + materials_amount`; manual payment RPC इसी exact total को verify करती है।
- [x] Legacy platform commission केवल labour/service_charge पर calculate होती है; payout में labour, materials, commission और electrician payable अलग fields हैं।
- [x] New-category billing immutable server labour bill और अलग cancellation-fee ledger से reconcile होती है।
- [x] Billing paise में integer arithmetic और half-up rounding rule documented/implemented in approved calculation paths.
- [x] Manual payment evidence में unique booking, method, receipt/UTR, recorder और timestamp।
- [x] Payment और refund paths Razorpay IDs/verified provider evidence से अलग रखे गए; manual RPC Razorpay-linked booking स्वीकार नहीं करती।
- [ ] Legacy manual payment migration + pgTAP को isolated PostgreSQL में चलाएँ; duplicate/concurrent payment, rollback, payout-row trigger और customer receipt runtime verify करें।
- [ ] Legacy commission trigger और completion/accounting path का end-to-end runtime reconciliation करें।

## 5. Push Notification — implementation और उपलब्ध verification

- [x] Trusted server-side sender, live offer revalidation, private subscription ownership/RLS और least-privilege grants।
- [x] Durable outbox, per-device delivery ledger, bounded retry/backoff, lease fencing, dead-letter recovery और health RPC।
- [x] Worker, notification click routing और delivered-device preservation logic।
- [x] Full Node test suite **87/87 PASS**; focused security suites **55/55 PASS**; Push-specific source tests **37/37 PASS**।
- [x] Deno Edge Function check PASS।
- [x] चार Push migrations disposable local PostgreSQL 18.6 में apply; claim/finish, concurrent claims, lease fencing/reclaim, stale token rejection, dead-row recovery, health counts और role/RLS checks runtime PASS।
- [ ] Managed Supabase schema/role parity पुनः जाँचें; पिछली read-only inventory में `job_offers.expires_at` और `electrician_profiles.available_for_work` Production में अनुपस्थित थे।
- [ ] Isolated Edge Function ↔ Netlify scheduled worker ↔ provider delivery integration, partial provider failure, cleanup cascade और real alert-delivery verify करें।
- [ ] Worker pause → schema/trigger swap → Edge deploy → synthetic delivery → worker enable तथा rollback rehearsal करें।

## 6. Welcome Screen और Founder Photo

**Owner-approved asset:** 15 नवम्बर 2026 को भेजी गई latest portrait — black button-up shirt, arms folded, waist-up crop, blue corporate background. पुरानी garden photo का उपयोग नहीं करना है। Attachment ID: `file_000000005f588210ac3459ffcfa3fdfe`.

- [x] Feature Branch में `assets/srk-founder.jpg` मौजूद है और `welcome.html` में `/assets/srk-founder.jpg` के रूप में wired है; `index.html` स्वागत पेज पर redirect करता है।
- [x] Welcome Screen का source implementation और responsive layout मौजूद है।
- [ ] Asset binary को owner-approved latest portrait (black button-up shirt, folded arms, waist-up crop, blue corporate background) से visually compare करके exact match स्वीकार करें; binary preview verification अभी नहीं हुई।
- [ ] Vercel Preview में asset/page load और desktop/mobile rendering verify करें।
- [ ] Automated build/check और Vercel Preview में asset/page load verify करें।
- [ ] Owner visual acceptance लें।
- [ ] Desktop और responsive/mobile presentation final consolidated QA में verify करें।

## 7. Documentation और source consistency

- [x] README phone visibility policy owner-approved rule के अनुसार सुधारी गई।
- [ ] README endpoints, feature descriptions और all portal UI copy को latest source से अंतिम बार मिलाएँ।
- [ ] Customer, Electrician, Admin और Staff के हर visible button/action को source/API contract से one-by-one reconcile करें; कोई dead button, missing field, placeholder या stale label न छोड़े।


## 8. Main Supabase Database — checklist बनाम वास्तविक Production schema audit (15 Nov 2026)

**जाँचा गया project:** `Srk electranic` — `gnqhoaqatmoiwwhgzkgm`, PostgreSQL 17.11, ACTIVE_HEALTHY. `SRK ELECTRONIC TEST` अलग project है; इसे Main DB नहीं माना। यह audit read-only catalog/table/migration inspection पर आधारित है, सिवाय नीचे दर्ज दो confirmed extra objects की removal के।

### Checklist से बाहर मिला और हटाया गया
- [x] `public.srk_route_transfers` — zero-row future-only Razorpay Route transfer ledger; current Customer/Admin/Electrician UI, Netlify/Edge functions या database functions में कोई caller नहीं; बिना CASCADE drop किया और `to_regclass` से verify किया। Main migration `20261115092149_retire_unused_razorpay_route_transfer_ledger`.
- [x] `public.accept_electrician_job(uuid)` — पुराना orphan job-acceptance SECURITY DEFINER function हटाया। Current Electrician Portal `srk_respond_to_offer` use करता है; Customer/Admin/Electrician pages, सभी 10 Netlify functions और दोनों deployed Edge Functions में इसका कोई caller नहीं मिला; database dependent object नहीं मिला; pg_stat_statements में केवल पुराने DDL statements मिले; execute ACL postgres/service_role तक सीमित थी। Drop बिना CASCADE किया और `to_regprocedure` से verify किया कि function अब मौजूद नहीं। Production migration `20261115091906_retire_unused_legacy_accept_electrician_job` दर्ज है; matching source migration Feature Branch में commit है।

### अन्य database objects — हटाने योग्य साबित नहीं हुए
- [x] Main DB की 25 public business tables और 2 private tables को checklist workflows से map किया। इनमें bookings, customers/electricians, offers, payments, payouts, wallets, audit, refunds, complaints, KYC, push subscriptions, area requests और work authorization शामिल हैं। कोई अन्य table/column/trigger/policy/function केवल “checklist में नाम नहीं” होने के आधार पर delete नहीं किया।
- [x] `services` और `states` dropdown/reference data हैं; `states_id_seq` उनका required sequence है। इन्हें extra नहीं माना।
- [x] `storage.*` Supabase-managed internal tables हैं; इन्हें project tables समझकर drop नहीं करना। Private `srk-electrician-verification` bucket KYC flow के लिए है।
- [x] Installed extensions में pg_net, pgcrypto, uuid-ossp, pg_stat_statements और Supabase Vault मिले; शेष catalog entries उपलब्ध लेकिन uninstalled थीं। किसी extension को extra समझकर हटाया नहीं।
- [x] `srk_wallet_bank_links`, payment locks, wallet ledger और payout tables भले खाली हों, वे wallet/payout flow से जुड़े हैं; इन्हें retained रखा। `srk_route_transfers` को ऊपर दर्ज कारणों से हटा दिया गया है।

### Main DB में checklist/Feature Branch के मुकाबले missing या पुराना schema
- [ ] Customer saved profile/address tables `srk_customer_profiles`, `srk_customer_saved_addresses` और customer support message/attachment tables अभी Main DB में नहीं मिले।
- [ ] Immutable labour bill `srk_booking_labour_bills`, cancellation fee debt/items/ledger tables अभी Main DB में नहीं मिले।
- [ ] Durable Razorpay refund recovery evidence table `srk_razorpay_refund_recovery_audits` अभी Main DB में नहीं मिली।
- [ ] KYC document-event append-only table `srk_electrician_verification_document_events` अभी Main DB में नहीं मिली; पुराने verification event table को audit data होने के कारण नहीं हटाना।
- [ ] Durable Push outbox और per-device delivery tables `srk_private.srk_push_delivery_outbox`, `srk_private.srk_push_subscription_deliveries` Main DB में नहीं मिले। Main DB में अभी पुराना `job_offers` push trigger मौजूद है; नया durable outbox rollout duplicate-safe migration/worker coordination के बिना नहीं करना।
- [ ] Main DB में `job_offers.expires_at` और `electrician_profiles.available_for_work` columns नहीं मिले; नई Push/dispatch implementation के लिए schema parity जरूरी है।
- [ ] Legacy status direct-write guard और नवीनतम itemized legacy manual-payment/receipt implementation Main DB पर लागू नहीं हैं। Existing Main DB manual-payment RPC पुरानी definition है; नई Feature Branch definition से अलग है।
- [ ] Production migration chain में नवीनतम लागू version इस audit के समय `20261115092149` (unused Route ledger retirement) है; Feature Branch की बाद की Customer/Admin/KYC/Push/payment migrations Production पर लागू नहीं।
- [ ] सभी missing migrations को dependency/order और existing production data के हिसाब से migration-by-migration reconcile करें; एक साथ blind apply नहीं। Backup/rollback और maintenance/worker sequencing review के बाद ही owner-approved Production apply।

**निष्कर्ष:** Checklist के बाहर दो confirmed unused objects मिले और हटाए गए: orphan `accept_electrician_job` function और zero-row `srk_route_transfers` table। इनके अलावा कोई दूसरा object पर्याप्त प्रमाण से extra साबित नहीं हुआ। अभी मुख्य अंतर “फालतू database” नहीं बल्कि Main DB का Feature Branch checklist से पीछे होना और कई नई आवश्यक tables/columns/RPCs का अभी apply न होना है।

## 9. Test, release और approval gates

- [x] Feature Branch PR Node CI run `43704748225` (commit `059f875`): **96/96 PASS**। उसके बाद latest observed HEAD `a924bc3` का run `43704886935`: **97 PASS / 1 FAIL**; शेष failure GPT-1 Customer quote UI regression test के पुराने onclick-regex expectation में है (`tests/customer-quote-approval-ui.test.js`) जबकि `booking.html` में approve/reject handlers मौजूद हैं। Admin accounting tests latest run में PASS हैं। यह source-level Node suite है; pgTAP/live DB/browser E2E/Preview/mobile QA अलग बाकी हैं।
- [x] Push Deno check और local PostgreSQL Push migration/RPC runtime checks PASS।
- [ ] ऊपर सूचीबद्ध शेष Customer/Electrician/Admin/Staff/legacy-payment SQL और browser workflows के isolated runtime tests पूरे करें।
- [ ] सभी implementation और internal checks पूरे होने के बाद ही एक consolidated desktop + mobile QA pass करें; बीच में अलग mobile test नहीं।
- [ ] यदि final end-to-end testing के लिए अलग Supabase staging branch/subscription जरूरी हो, तो पहले लागत बताकर owner की स्पष्ट अनुमति लें। अभी कोई paid Development Branch न बनाएँ।
- [ ] Vercel Preview/build सफलतापूर्वक verify करें; पिछली failure `upgradeToPro=build-rate-limit` थी, इसलिए उसे application test failure या successful build न मानें।
- [ ] PR #8 को review-ready करें; owner की स्पष्ट अनुमति के बिना merge न करें।
- [ ] Owner की अलग स्पष्ट अनुमति के बिना Production migration, Auth/Storage/settings, provider refund/Route, real SMS/OTP, push send, deployment या go-live न करें।

---


## 2026-11-15 — GPT-1 Customer legacy quote approval

- [x] Customer booking query में legacy quote display के आवश्यक fields शामिल किए: labour/service charge, materials amount, total quote, quote status और note.
- [x] Pending legacy quote पर labour और materials अलग-अलग दिखाने तथा customer से explicit approve/reject response लेने का UI जोड़ा।
- [x] Existing customer-owned srk_customer_respond_booking_quote RPC integration, success refresh और error handling जोड़े।
- [x] Approved/rejected quote status customer booking card में दिखाने का source path जोड़ा।
- [ ] tests/customer-quote-approval-ui.test.js का CI execution और PASS परिणाम verify करें; अभी कोई नया CI result उपलब्ध नहीं।
- [ ] Browser/desktop runtime verification को final consolidated QA तक रोकें; mobile QA भी सभी implementation tasks के बाद ही।
- [ ] Confirm करें कि legacy quote UI newer category-based fixed-duration booking flow से अलग ही रहे।

## अभी का साफ निष्कर्ष

**Feature implementation:** कई मुख्य Customer, Electrician, Admin/Staff, payment/refund, KYC, timer, dispatch और Push workflows Feature Branch में implement हैं; legacy manual-payment source gap भी अभी जोड़ा गया है।  
**Founder/Welcome source status:** founder asset और Welcome Screen integration अब Feature Branch में मौजूद हैं; exact approved portrait से visual match और Preview/owner acceptance अभी pending हैं।  
**अभी का मुख्य verification blocker:** non-Push database/RPC/browser end-to-end runtime; Push के local PostgreSQL tests सफल हैं, लेकिन managed Supabase parity और Edge↔Netlify/provider integration बाकी है।  
**Production:** कोई migration apply, merge, deployment या live payment action नहीं किया गया है।



## 2026-11-15 — पुराने quotation workflow को हटाना
- [x] Customer App से legacy quotation fields, approval/rejection buttons, RPC response handler और quote status labels हटाए।
- [x] Electrician App से inspection-to-quotation controls, quote submission handler और legacy quote work-status handler हटाए।
- [x] Customer quotation UI regression test हटाया क्योंकि वह हटाए जा चुके feature को enforce कर रहा था।
- [ ] GPT-2 के Admin/Accounting/Payment/Refund हिस्सों से legacy quote dependencies हटाकर नए server-timed labour bill contract पर migrate करना बाकी है।
- [ ] Backend RPCs/columns/status constraints की retirement के लिए additive migration और historical paid records preservation की समीक्षा बाकी है।
- [ ] कोई Production database migration, deployment या PR merge नहीं किया गया।


## 2026-11-15 — CI blocker resolved: latest verified status (GPT-2)

- [x] PR #8 HEAD `843e91abaecf0e72df343518aa36c593c1a89a06` पर Node CI run `43705430363` सफल: **98/98 PASS, 0 FAIL, 0 skipped**। Job log में final TAP summary सत्यापित।
- [x] पुराने Customer quote UI test-contract mismatch के बाद अब पूर्ण Node suite green है; Admin commission/accounting regression tests भी शामिल हैं और पास हुए।
- [ ] pgTAP/database contract suites को isolated PostgreSQL/Supabase test environment में execute करें; अभी इस 98/98 Node result से database runtime प्रमाणित नहीं होता।
- [ ] Managed Supabase schema/role parity, सभी Admin/Staff actor ACL, browser E2E, Vercel Preview, OTP/SMS, Push provider integration और consolidated desktop/mobile QA बाकी हैं।
- [ ] PR #8 अभी Draft है; owner की स्पष्ट अनुमति के बिना merge/deploy/Production migration नहीं।

**सत्यापन सीमा:** 98/98 केवल repository Node/mock/source regression suite है। यह live DB, pgTAP, browser, Preview, SMS/OTP, Push delivery या Production readiness का प्रमाण नहीं है।


## 2026-11-15 — Backend quotation RPC retirement (GPT-1 source change)

- [x] Additive migration `20261115220000_retire_live_legacy_quotation_rpcs.sql` जोड़ी: live legacy quotation submit/respond और inspection/work-status RPCs revoke + drop किए।
- [x] Electrician offer-details RPC से quote/inspection-only monetary projections हटाए; category, duration, rate tier, assignment-contact guard और server timer fields रखे।
- [x] Historical booking rows, quote audit columns, पुराने paid/refund/payment records और financial evidence को delete नहीं किया।
- [ ] GPT-2 Admin/Accounting owner से पुष्टि बाकी: Admin में legacy quote editing/approval UI और old-only manual payment path को retire/disable करने का सुरक्षित क्रम।
- [ ] SQL migration की isolated PostgreSQL/pgTAP runtime execution और electrician offer RPC caller contract verification बाकी।
- [ ] Status constraints/columns को अभी नहीं हटाया: पुराने paid/closed records और accounting/receipt audit इन्हें पढ़ सकते हैं। यह archival compatibility है, live quote feature नहीं।
- [ ] Production migration, PR merge, deployment या live data change नहीं किया गया।


### 2026-11-15 — quotation retirement follow-up / cross-owner blockers

- [x] Offer-details RPC contract में electrician portal के आवश्यक `offer_expires_at` और `estimated_labour_paise` fields सुरक्षित रखे; पुराने quote-only fields हटाए। Assigned-only phone/address visibility और timer fields कायम रखे।
- [x] Electrician App से आखिरी `quoted_amount` fallback हटाया; अब केवल server estimate दिखेगा, अन्यथा “श्रम अनुमान उपलब्ध नहीं”।
- [x] Regression test `tests/electrician-legacy-quotation-retirement.test.js` जोड़ा।
- [ ] GPT-2 Admin scope में `admin.html` का legacy quote editing/status control हटाना बाकी है।
- [ ] GPT-2 Payment/Accounting scope में `20261115210000_legacy_manual_payment_and_itemized_receipt.sql` और reconciliation का approved-quote dependency हटाकर नए immutable server-timed labour bill + अलग materials receipt contract से जोड़ना बाकी है। Historical paid/settled rows को audit evidence के रूप में preserve करना है।
- [ ] Legacy status CHECK constraints और quote audit columns को अभी preserve किया है; ऐतिहासिक records के लिए हैं। New quote RPCs बंद हैं। Status constraints/columns तभी हटें जब GPT-2 accounting/receipt/archive dependency audit प्रमाणित हो।
- [x] Commit `1468dfe` पर Node CI run `43705891497` सफल: **98/98 PASS, 0 FAIL** (job log TAP summary से सत्यापित)।
- [ ] इसके बाद जोड़ा गया regression test `tests/electrician-legacy-quotation-retirement.test.js` और docs updates सहित नवीनतम HEAD `80a6c7d` के Node CI runs `43705953944` / `43705950245` अभी in-progress हैं; latest-head result बाकी है।
- [ ] SQL runtime/pgTAP execution pending; no Production migration/deploy/merge.


## 2026-11-15 — GPT-1 latest-head CI and Welcome source recheck

- [x] Latest feature HEAD `da65832bdd07ee1238d9b4c0829045d06349f95a` पर Node CI run `43705984415` completed successfully; job `132787042217` conclusion `success`।
- [x] Welcome Screen source recheck: `index.html` सीधे `/welcome.html` पर भेजता है; Welcome page में founder asset `/assets/srk-founder.jpg` और Customer, Electrician, Admin role links मौजूद हैं।
- [ ] Founder photo का approved original से exact visual match अभी भी सत्यापित नहीं; desktop/mobile visual preview final consolidated QA में।
- [ ] Customer OTP का real Auth/SMS, abuse controls और browser session lifecycle runtime test बाकी।
- [ ] Customer Payments/Support/Profile contracts, Electrician final source checks, SQL/pgTAP runtime और सभी browser workflows बाकी।
- [ ] पुराने quotation workflow का पूर्ण retirement अभी GPT-2 Admin/Payment/Accounting blockers के कारण अधूरा है।
- [ ] Production migration, deployment और PR merge नहीं किया गया।


## 2026-11-15 — Customer dashboard menu contract regression

- [x] Five customer dashboard menu tabs (Home, My Bookings, Payments, Help & Support, My Profile) और उनके matching panel/ARIA wiring के लिए regression test जोड़ा।
- [x] Payments, Support और Profile content को संबंधित tab panel में route करने वाले menu-shell contract के लिए test जोड़ा।
- [x] Support और Profile के customer-authenticated dashboard gate तथा expected customer RPC integration के source contract checks जोड़े।
- [ ] नया Node regression test और पूरा CI run execute होकर PASS होना बाकी।
- [ ] वास्तविक Supabase RPC/RLS/storage/browser workflow और final consolidated mobile QA अभी pending।

- [x] Profile language preference now applies a reversible Hindi/English translation layer to the main Customer Login, Dashboard, Support/Profile and booking form labels/help text; the selected preference is restored from the customer profile. Remaining dynamic status/error strings, payment receipt and complete visual QA still need coverage, so full-page localization is not yet marked complete.
- [ ] Node CI run `43706360554` for the newly added menu regression was cancelled before test steps executed when later branch commits arrived; latest full-suite PASS is not yet established for the new test.


### 2026-11-15 — Hindi / English customer UI implementation
- [x] Added customer-facing Hindi/English dictionary and reversible DOM text translation in `booking.html`.
- [x] Language selection applies immediately; saved profile preference is reapplied after profile load.
- [x] Dynamic text nodes inserted into customer panels are translated while English is selected.
- [x] Added regression assertions for language apply, document lang, profile preference restore and mutation observer.
- [ ] Latest CI after these language implementation changes is still pending; earlier run `43706432946` passed before the latest language code/test commit and is not evidence for the current HEAD.
- [ ] Dynamic status/error messages, payment receipt, complete page localization and real browser language-toggle testing remain pending.


### 2026-11-15 — Customer dynamic messages and payment receipt localization
- [x] Added translations for common payment/refund statuses, login/payment prompts, booking/payment messages and common customer alerts.
- [x] Customer browser alerts now pass through the selected-language translation helper.
- [x] Printable verified-payment receipt now uses the selected Hindi/English language, matching HTML `lang`, localized labels and locale-formatted dates.
- [x] Added regression assertions for dynamic payment strings, receipt language, date locale and translator scoping.
- [ ] Remaining non-payment dynamic content and any unmapped server-provided free-text descriptions still need full coverage.
- [x] Latest-head Node CI passed on commit `70f65c1` (run `43706978870`; install + full `npm test` successful). Browser runtime verification remains pending.
