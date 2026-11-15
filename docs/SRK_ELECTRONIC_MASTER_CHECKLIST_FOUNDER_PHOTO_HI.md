# SRK ELECTRONIC — मुख्य मास्टर चेकलिस्ट (एकीकृत स्थिति)

**अंतिम मिलान:** 15 नवम्बर 2026  
**काम की branch:** `feat/customer-login-first-dashboard-20261114`  
**Repository:** `shahrukhkhan12136-bot/Srk-electranic-`  
**स्थिति का नियम:** [x] = Feature Branch source में implement/verified; इसका अर्थ Production पर लागू होना नहीं है। Runtime/Production/owner approval को अलग स्पष्ट रखा गया है। पुरानी विस्तृत कार्य-इतिहास `docs/SRK_ELECTRONIC_PROJECT_PROGRESS_HI.md` में है। इस checklist में duplicate पुराने pending items को बार-बार नहीं दोहराया जाएगा।

---

## त्वरित प्रोजेक्ट प्रगति — 15 नवम्बर 2026

- **65% पूरा:** 56 / 86 मुख्य चेकलिस्ट आइटम।
- **35% बाकी:** 30 / 86 मुख्य चेकलिस्ट आइटम।
- यह प्रतिशत ऊपर के वर्तमान 9 मुख्य sections के checkbox count पर आधारित है; यह Production readiness, समय, लागत या code completion का प्रतिशत नहीं है।
- बाकी मदों में isolated runtime/database tests, Main Production schema parity, browser/mobile visual QA और release/owner approval शामिल हैं।
- **GPT-1 का अलग कार्यक्षेत्र:** Customer (10), Electrician (10), Welcome Screen/Founder Photo (6) — कुल 28 मदों में 21 पूर्ण, 7 शेष: **75% पूरा / 25% बाकी**। यह checklist checkbox-count आधारित implementation progress है; runtime/visual QA और Production readiness अलग gates हैं। GPT-2 का प्रतिशत इससे अलग है।
- Admin Panel के शीर्ष पर पूरे प्रोजेक्ट का कार्ड और GPT-2 का अलग कार्ड पहले से दर्ज हैं; GPT-1 का प्रतिशत इस checklist/progress log में अलग दिखाया जाएगा।
- **GPT नंबर 2 का अलग कार्यक्षेत्र:** Admin/Support Staff (13), Payment/Accounting (10), Main Database audit/parity (16) — कुल 39 मदों में 27 पूर्ण, 12 शेष: **69% पूरा / 31% बाकी**। GPT-1 के Customer/Electrician कार्य इसमें शामिल नहीं हैं।
- Admin Panel में पूरे प्रोजेक्ट के कार्ड के नीचे GPT-2 का अलग प्रगति कार्ड भी दिखाया गया है।

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
- [x] पुराने quotation-based customer receipt path को नए immutable labour bill और अलग materials receipt से reconcile किया; legacy receipt labour + materials और नई category receipt labour + settled cancellation-fee ledger को अलग लौटाती है। Migration `20261115210000_legacy_manual_payment_and_itemized_receipt.sql`, source regression tests तथा Node CI 179/179 PASS। PostgreSQL/pgTAP runtime अभी अलग pending है।
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
- [x] Admin booking customer-location और legacy quote direct-edit paths का source/privilege audit पूरा: दोनों UI writes Main-Admin-only, row-locked RPCs पर बदले; location change before/after `srk_admin_audit_events` में दर्ज; `service_bookings` के authenticated direct UPDATE grants revoke किए। पूरे `admin.html` में कोई `.from(...).update(...)` direct table write शेष नहीं मिला। Profile/other legacy paths की runtime DB/browser verification अलग pending है।

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

**Owner-approved asset (नवीनतम स्पष्ट निर्देश):** असली Founder Photo वही है जिसमें Founder के पीछे हरा-भरा बगीचा है। उसी फोटो को crop करके लगाना है; चेहरा/पहचान या फोटो का रूप बदलना नहीं है। पहले दर्ज blue-background portrait वाला निर्देश अब इस स्पष्ट garden-photo निर्देश से supersede होता है। Welcome Screen का crop/layout मौजूदा Founder model/reference जैसा रहेगा।

- [x] `index.html` स्वागत पेज पर redirect करता है और Welcome Screen का responsive layout मौजूद है।
- [x] Welcome Screen का source implementation और responsive layout मौजूद है।
- [x] Owner ने हरे-भरे बगीचे वाली original Founder Photo की पहचान और उसी फोटो को मौजूदा Founder model/card में crop करने का निर्देश confirm किया।
- [ ] Library में standalone original garden-background portrait `Urban Garden Portrait.png` मिला और visual inspection किया; इसे source asset के रूप में सुरक्षित रखा है। अभी original binary को Feature Branch के `assets/` में जोड़ना, Founder card अनुपात में crop करना और Welcome Screen + Customer Login दोनों में wire करना बाकी है; collage/AI-generated substitute इस्तेमाल नहीं होगा।
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
**Founder/Welcome source status (2026-11-15 correction):** Welcome Screen और Customer Login में अभी `founder-photo-pending` placeholder है; `assets/srk-founder.jpg` collage है और approved original नहीं, इसलिए उसे display नहीं किया गया। Library की `Urban Garden Portrait.png` मूल garden portrait को branch में lossless तरीके से transfer करके दोनों screens में integrate करना बाकी है। उसके बाद exact visual match, Preview और owner acceptance होंगे।  
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


### 2026-11-15 — Customer language coverage and browser-script audit
- [x] Expanded English translations for dynamic profile, saved-address, complaint/support, OTP/login and common payment status messages.
- [x] Customer payment/booking history date formatting now follows the selected locale (`en-IN` or `hi-IN`).
- [x] Restored `booking.html` from an intact feature-branch revision after source review detected malformed string substitutions in an intermediate edit; safely reapplied the translation dictionary and localized receipt function. The corrected source contains no known malformed substitution markers.
- [x] Added regression test that parses inline JavaScript in both `booking.html` and `electrician.html`, plus electrician fixed-duration lifecycle / no-quotation source checks.
- [x] Latest-head CI run `43707448254` on `172d74b204bfd283522a4e540090cb79deca73aa` — **SUCCESS** (full Node test suite).
- [ ] Browser runtime verification of language switching and print preview remains pending; manual mobile QA remains deferred to the consolidated final pass.


### 2026-11-15 — Electrician Live Location reliability and Customer lifecycle localization
- [x] Electrician Live Location stop flow now retains a retryable Stop control when the server does not confirm the stop RPC. The browser GPS watch is cleared immediately; the UI keeps the booking's retry handle until server confirmation succeeds.
- [x] Prevent duplicate stop RPCs for the same booking while a stop request is in progress.
- [x] Added regression coverage for failed stop confirmation and retry behavior.
- [x] Expanded Customer App English translations for booking lifecycle/timeline states, refund and cancellation history, GPS/location feedback and common booking error/status messages.
- [x] CI run `43707742875` on code commit `bd1b6f1388d3f1a70cd2e069676eb6a23663cade` — **SUCCESS** (full Node test suite and inline Customer/Electrician JavaScript syntax parsing).
- [ ] Real browser GPS permission / Live Location stop retry behavior, language switching and receipt Print/PDF preview still require browser runtime verification. Final mobile QA remains deferred.


### 2026-11-15 — Customer translation gaps and Electrician GPS error handling
- [x] Added remaining Customer English translations for login/form placeholders, booking estimate text, booking map label, common payment/OTP failures and complaint feedback.
- [x] Electrician GPS live-location update now catches both returned Supabase RPC errors and thrown/network exceptions. Either failure initiates the existing safe server-side sharing-stop routine rather than leaving an unhandled rejected promise.
- [x] Updated the client regression tests to match the explicit thrown-error handling and helper-based stop flow.
- [x] Latest branch-head Node test workflows on `e549574a091071f995786b009d710e4da25160c0`: **SUCCESS** (two CI runs, full repository Node test suite).
- [ ] Browser runtime verification remains pending: actual language selector behavior, dynamic form placeholders, payment receipt print/PDF, GPS permission and live-location stop/retry.
- [ ] Final consolidated mobile QA remains deferred until implementation is complete.


### 2026-11-15 — Electrician booking refresh resilience and Welcome Screen regression coverage
- [x] Electrician profile refresh now handles thrown/network failures without exposing raw backend errors to the UI.
- [x] Offer-list refresh now shows a retry-oriented message on network/transport failures.
- [x] Per-booking live-location status and labour-bill lookups are isolated; a failure in one booking's auxiliary RPC no longer prevents the remaining booking cards from rendering.
- [x] Added regression coverage for profile/offer/live-location/bill refresh failures.
- [x] Added Welcome Screen contract test covering index redirect, Customer/Electrician/Admin role routes, founder portrait path/asset existence, alt text and reduced-motion support.
- [ ] Latest Welcome Screen + refresh regression CI run `43708433631` is in progress; verify its final result before marking tests passed.
- [ ] Browser runtime/visual portrait match remains pending; source-level asset presence is checked by the new test.


### 2026-11-15 — Customer dynamic control localization follow-up
- [x] Customer language observer now translates dynamically inserted input/textarea placeholders and title/aria-label attributes, not only visible text nodes.
- [x] Added regression assertions for applying translations to new DOM elements and the initial full-page attribute pass.
- [ ] Latest branch-head CI must confirm the new regression test; browser runtime language switching remains pending.
- [ ] Founder portrait asset is present in the feature branch, but exact approved-reference visual match still needs a browser/visual review.


### 2026-11-15 — Customer support localization completeness
- [x] Added English translations for Customer support/complaint loading, empty, validation, submission, message and attachment feedback strings.
- [x] Dynamic text translation now supports known translated prefixes, so concatenated complaint status text can be translated without losing the server-provided status value.
- [x] Added regression coverage for support messages, prefix translation and dynamic text-node rendering.
- [ ] Confirm latest branch-head CI before marking the new support localization tests passed.
- [ ] Browser runtime verification remains pending; final mobile QA remains deferred.


### 2026-11-15 — Customer old-quotation wording final cleanup
- [x] Removed the last obsolete inspection/post-inspection quotation wording from the Customer booking page, including its Hindi/English translation dictionary entry.
- [x] Static scan of Customer `booking.html` and Electrician `electrician.html` found no remaining quote/quotation/inspection legacy wording or quote-related identifiers.
- [x] Added a regression assertion preventing the retired inspection-quotation wording from returning to Customer booking copy.
- [x] Latest branch-head Node test workflows for `ef2c3fd0c6f33b52e2d9dfa5833819c6802894d1`: **SUCCESS** (full repository Node tests).
- [ ] This retires the Customer/Electrician app wording and UI only; Admin/Accounting/Payment legacy dependencies and safe database dependency retirement remain GPT-2 work.
- [ ] Browser runtime verification, Founder portrait visual match and final consolidated mobile QA remain pending.


### 2026-11-15 — Customer static English translation coverage audit
- [x] Audited all static Hindi text nodes in Customer `booking.html`; every visible Hindi text node now has an English dictionary entry (static source scan: zero unmatched nodes).
- [x] Added missing English translations for dashboard section headings, saved-address/GPS guidance, Google Maps action, tier duration labels, estimate/billing terms, separate materials approval, booking terms and Razorpay payment actions.
- [x] Added English translations for the remaining `title` and `aria-label` attributes (Electrician current location; booking status history).
- [x] Added regression assertions for representative new translation values and accessibility labels.
- [x] Latest feature branch Node test workflows on `d55c11159b865386234601df2041c998fa735d6b`: **SUCCESS** (two full repository Node test runs).
- [ ] Browser runtime language switching and visual behavior remain pending; final consolidated mobile QA remains deferred.


### 2026-11-15 — Customer dynamic English messages and dialogs
- [x] Added English dictionary entries for dynamic GPS/location feedback, payment history and refund loading/errors, complaint/status feedback, work-start approval, cancellation and booking errors, OTP/session feedback, address operations, and payment result messages.
- [x] Wrapped native `window.confirm` through the same English translation function as `window.alert`, so confirmation dialogs are localized too.
- [x] Added English copy for the full cancellation-fee policy confirmation and translated labels inside the dynamic booking confirmation summary (tier, duration, estimated labour, payment method, prior fee line items).
- [x] Added regression coverage for dynamic messages, confirmation dialogs and cancellation/booking summary text.
- [x] First test run caught a test-only wrapper-name mismatch; corrected the test. Latest branch-head runs on `3fb69b1c59858f291fd0821e658e0ee837aad5b9`: **SUCCESS** (two full repository Node test runs).
- [ ] Browser runtime language switching, dynamic backend-provided message coverage and visual QA remain pending. Final consolidated mobile QA remains deferred.


### 2026-11-15 — Electrician Push permission reliability audit
- [x] Reordered Push enable flow so browser support checks are synchronous and `Notification.requestPermission()` is requested directly from the button gesture before awaiting Supabase/account validation. This avoids losing transient browser user activation in Android Chrome and other browsers.
- [x] Added regression test that verifies permission request precedes asynchronous account validation.
- [x] Reviewed GPS start/update/stop, logout stop retries, push subscription ownership, support ticket/thread rendering and dynamic status handling. Existing GPS safeguards and support HTML escaping remain in place; no production calls or device permission prompts were performed.
- [ ] Browser/device runtime verification remains pending. Final consolidated mobile QA remains deferred.
- [!] Latest full repository Node workflow ran 120/121 tests successfully; the only failure is outside GPT-1 scope: `tests/admin-commission-report-labels.test.js` rejects a Route commission term found in current `admin.html`. This is a GPT-2 Admin Panel dependency; do not modify it from GPT-1.


### 2026-11-15 — Electrician GPS stop concurrency hardening
- [x] GPS-failure auto-stop and the manual “Location बंद करें” action now share one in-flight Set guard, preventing duplicate concurrent `srk_electrician_stop_live_location` RPCs for the same booking.
- [x] On failed server stop, the booking remains in the local retry set; successful stop clears the retry handle. Added regression coverage for shared guard and retry behavior.
- [x] Updated the existing GPS network-exception test boundary after moving the shared guard declaration. Latest branch head `c57577c9f72663cf52cfc8981d72f008d95b83ef`: **two full repository Node workflows SUCCESS**.


### 2026-11-15 — Electrician Profile, KYC, Earnings and Wallet source audit
- [x] Profile display-name update validates 2–80 characters and uses the self-service RPC; UI displays server-confirmed name.
- [x] Phone-number change is OTP-gated, time-limited, rate/attempt-aware via server flow, then waits for Admin approval; current number remains active until approval. Request history escapes user/admin text before HTML rendering.
- [x] Area-change flow validates state/district/PIN/reason, blocks duplicate pending requests in UI, and preserves the current area until Admin approval.
- [x] KYC upload allows only identity/address/skill document types, allowlisted MIME types, 1–5 MB, unique non-upsert object paths; metadata is registered via RPC. Preview obtains owner-authorized path then a 60-second signed URL; no public URL.
- [x] Earnings and payout history are distinct: client only reads RPC earnings and profile-scoped payout records; payout query failure is shown separately, not as a zero/empty payout history. Admin UTR record is distinguished from customer payment.
- [x] Wallet summary is RPC-based; bank-link and ledger queries are scoped to the signed-in user/wallet. Bank/ledger query failures are shown separately; UI explicitly states ledger balance is not proof of bank transfer. Withdrawal/transfer initiation remains disabled.
- [x] Added `tests/electrician-accounting-kyc-contract.test.js` covering profile validation, KYC upload/preview privacy, earnings/payout error handling, wallet scoping and no withdrawal actions.
- [x] Latest branch head `6b83ba1dc3423921a00d1a71564869c286cfbf22`: two full repository Node workflows **SUCCESS**.
- [ ] Browser runtime and visual verification remain pending; final consolidated mobile QA remains deferred.


### Test harness follow-up — 2026-11-15
- [x] The first run of the new KYC/earnings/wallet contract test exposed test-helper extraction/regex mistakes only; the application source was not changed for these fixes.
- [x] Corrected the helper to isolate the next function declaration and corrected the profile-finally assertion.
- [x] Latest branch head `2a7771c153b82785238256d8852e04aa540f901c`: both full repository Node workflows **SUCCESS**.


### 2026-11-15 — Booking Lifecycle / Offer / Timer / Completion source audit
- [x] Offer response client restricts to accepted/declined, prevents duplicate in-flight response per offer, checks explicit server success and refreshes on success/expiry.
- [x] Offer RPC source verifies the authenticated electrician identity, approved/active/available profile, state/district and approved rate tier; locks the offer and booking before assignment; checks expiry and dispatches next eligible offer.
- [x] Electrician work-start RPC requires the assigned approved active electrician, locks the booking row and allows only assigned/rejected-start states; it records request timestamp on server and leaves timer stopped pending customer approval.
- [x] Customer work-start RPC (corrected by later migration) locks a customer-owned booking, allows only approved/rejected, verifies approved electrician rate snapshot, and starts timer with `clock_timestamp()` only after customer approval. Rejection returns booking to assigned with timer stopped.
- [x] Electrician completion RPC locks assigned booking and freezes elapsed time from server clock; customer completion RPC locks customer-owned booking and permits approve/reject/dispute. Approve inserts one immutable labour bill; reject resumes timer on server clock; dispute creates complaint and keeps timer stopped.
- [x] UI timers are display-only projections of server-provided elapsed seconds/start timestamp; final bill is fetched from server RPC. No client-side timer write path found.
- [x] Added per-booking in-flight guards on Electrician start/completion and Customer start/completion decisions to prevent duplicate concurrent RPC submissions.
- [x] Added `tests/booking-lifecycle-serialization.test.js` covering client guards, state/UI transitions, server row locks, server-clock timer transitions, completion branches and offer assignment controls. All 9 targeted lifecycle tests passed in CI.
- [ ] Full repository CI remains blocked by separate existing Razorpay webhook test `matches an unpersisted provider refund by its internal refund-record note` (assertion false at `tests/razorpay-webhook-inbox.test.js:361`); lifecycle tests and inline-script parse passed in the same run. Do not mark full suite green.
- [ ] SQL pgTAP/JWT runtime tests are present in the feature branch but not executed; no Production migration or live booking/payment operation performed. Production migration parity and E2E remain pending.
- [ ] Final mobile QA remains deferred until all app/admin/backend implementation is complete.


### 2026-11-15 — Welcome Screen / Founder Photo / PWA entry audit
- [x] Verified `index.html` redirects to `welcome.html`; all three role routes (Customer, Electrician, Admin) are present.
- [x] Updated Welcome Screen to the approved blue/white premium direction, included “Smart Service... Better Life...” and retained the slogan “विश्वास की शक्ति, सेवा की पहचान।”
- [x] Found that the checked-in `assets/srk-founder.jpg` is a three-screen app collage, not the approved garden-background Founder Photo. It is no longer displayed as a portrait. No generated or unrelated face has been substituted; an accessible founder-photo slot is held until the exact approved source photo is available in the repo.
- [x] Corrected PWA `manifest.webmanifest` start_url to `./welcome.html`; bumped Service Worker cache to v9 and added Welcome, Customer, Electrician and Admin entry pages to precache.
- [x] Reworked `tests/welcome-screen-contract.test.js` to assert role routing, no collage substitution, approved text, PWA start URL and offline precache.
- [ ] Exact approved garden-background founder photo is not currently present in accessible repository or Library assets; final authentic-photo placement remains pending. Older blue-background/design-reference wording is superseded by the user's latest explicit garden-photo instruction. Do not substitute a collage, design reference, or generated/other portrait.
- [ ] Browser visual/runtime and install/offline tests pending; final mobile QA remains deferred. No deployment or Production changes.

- [x] On branch head `3ad8d575266eea757a2084db82966b0c82b04e61`, both latest CI workflows reached the repository test step: Welcome Screen/PWA tests passed (`ok 139`, `ok 140`), and the full suite reported 139/140 pass. The sole remaining failure is the unrelated Razorpay refund-note test `matches an unpersisted provider refund by its internal refund-record note`.
- [x] Updated the existing Electrician service-worker contract test from cache v8 to v9; that regression passed in the latest run.


## 2026-11-15 — GPT-1 अलग प्रगति और Founder Photo निर्देश की पुष्टि

- User clarified: authentic SRK ELECTRONIC Founder Photo is the photo with a garden/greenery in the background. Crop that exact photo and use the existing Founder model/layout; do not use the blue-background alternative or the design-model image as the identity source. Preserve the real face/identity.
- Library image search and saved-reference-image lookup returned no accessible original image bytes; the repository asset previously inspected was an app-screen collage, not a safe substitute. Therefore actual photo crop/replacement remains pending until the original garden photo asset is accessible. Do not claim photo integration is complete.
- GPT-1 progress is counted only from checklist sections 1 Customer (10), 2 Electrician (10), and 6 Welcome/Founder Photo (6): 20/28 checked = 71% complete; 8/28 = 29% remaining. GPT-2 work is excluded. This is checklist implementation progress, not Production readiness.


### 2026-11-15 — Founder photo checklist correction (latest owner instruction)
- पुराने checklist इतिहास में blue-background photo और crop working-file के बारे में लिखी बातें नवीनतम owner instruction से superseded हैं। Authoritative asset अब केवल हरे-भरे बगीचे के पीछे वाली original Founder Photo है।
- Exact original bytes अभी accessible नहीं हैं; crop तैयार नहीं है। Welcome Screen और Customer Login दोनों में गलत collage हटाकर placeholder रखा गया है।
- उसी original garden photo को existing Founder model/card ratio में crop करना है; face/identity/retouch नहीं। दोनों screens पर वही approved crop इस्तेमाल होगा।
- PWA cache version अब v11 है; पुराने v9 इतिहास को current cache state न मानें।


### 2026-11-16 — Customer/Electrician Booking Status Projection Reconciliation
- [x] Rechecked Customer `loadCustomerBookings`: authenticated-session gate, `customer_user_id` filter, lifecycle/timer fields and per-booking `srk_customer_get_my_booking_work_timeline` call.
- [x] Rechecked Electrician `refresh()` and `srk_get_my_offer_details`: offer/status RPC, error path, work-start/completion/dispute/completed UI branches and explicit refresh after offer/work lifecycle actions.
- [x] Confirmed final replay-order migration `20261115220000_retire_live_legacy_quotation_rpcs.sql` restores all timer fields consumed by Electrician UI (`work_timer_elapsed_seconds`, `work_started_at`, `work_timer_running`) plus start/completion approval fields. Earlier `20261114370000...` definition did not expose timer fields, but the later migration replaces it; no SQL change made.
- [x] Added `tests/customer-electrician-booking-status-sync-contract.test.js`; corrected one order-sensitive test assertion after first CI run. CI run #1211 (`43750241498`) on commit `609fd7843dc00fd3ca2e7560d3e0314b8bcec927`: **216/216 passed, 0 failed, 0 skipped** (job `132922373905`). Source-contract evidence only; no PostgreSQL or browser runtime execution.
- [ ] Cross-app automatic realtime status refresh is not established: Customer uses explicit booking refresh/actions; Electrician realtime subscription listens to `job_offers` and `electrician_profiles`, not `service_bookings`. Keep this as a runtime/scope confirmation item; do not add new realtime behavior unless it is already in the approved checklist.
- [ ] Isolated PostgreSQL role/JWT/concurrency tests, browser integration and final consolidated mobile QA remain pending. No Production access/migration, deployment, merge or staging branch was performed.


### 2026-11-16 — Customer payment-history session failure handling
- [x] Found that `loadCustomerPaymentHistory()` called `auth.getSession()` before entering its `try/catch`; a rejected auth/session transport call could escape without the normal visible retry message.
- [x] Moved session lookup into the existing guarded block; session errors now use the same safe retry state and the `finally` block always clears the busy indicator.
- [x] Added source-contract regression coverage in `tests/customer-electrician-payment-history-contract.test.js`.
- [ ] Validate this change in the next exact-head Node CI run. No browser, live auth, database, or mobile runtime claim is made.
- [ ] Similar session-lookup placement in cancellation-fee and refund-history loaders remains to be inspected separately.


### 2026-11-16 — Customer cancellation/refund history session failure handling
- [x] Moved `auth.getSession()` inside guarded `try/catch` for `loadCustomerCancellationFeeDebts()` and `loadCustomerRefundHistory()`.
- [x] Auth/session transport errors now use the existing safe retry message and `finally` clears the busy indicator.
- [x] Added source-contract regression coverage for both loaders in `tests/customer-electrician-payment-history-contract.test.js`.
- [ ] Validate these latest edits on the exact PR head with CI. No live authentication, database, browser, provider or mobile testing is claimed.


### 2026-11-16 — Customer booking-list session failure handling
- [x] Found `loadCustomerBookings()` read `auth.getSession()` before its guarded `try/catch`; a rejected session transport call could bypass the normal retry message and busy-state cleanup.
- [x] Moved session retrieval into the existing guarded block after setting the loading state. Existing catch/finally now handles rejected session calls and clears `aria-busy`.
- [x] Added source-contract regression coverage in `tests/customer-electrician-booking-status-sync-contract.test.js`.
- [ ] Validate this edit on the exact latest PR head with CI. No live auth, database, browser or mobile runtime result is claimed.


### 2026-11-16 — Electrician offer refresh isolation
- `electrician.html`: profile के वैकल्पिक panels (phone-change history, area requests, KYC, earnings, wallet, push state, support tickets) में किसी transport rejection के कारण अब मुख्य Electrician offer list की loading रुकती नहीं; हर panel क्रम से अलग try/catch में चलता है।
- Regression coverage: `tests/customer-electrician-booking-status-sync-contract.test.js` में test जोड़ा गया है कि optional panel failure के बाद भी `srk_get_my_offer_details` तक execution पहुँचता है।
- यह source-level hardening है; वास्तविक browser/network failure simulation, Supabase runtime और mobile QA अभी बाकी हैं।






### 2026-11-16 — Electrician offer refresh latency isolation


### 2026-11-16 — Customer live-location transport isolation
- Booking cards render होने के बाद Customer loader `refreshCustomerLiveLocations()` को await करता था। किसी live-location RPC का network promise reject होने पर `Promise.all` reject होकर outer booking loader catch चला जाता और पहले से render हुई booking history generic error से replace हो सकती थी।
- हर booking की live-location RPC अब अपने try/catch में है; transport failure पर केवल उसी location panel में retry संदेश आता है, booking history बनी रहती है।
- Regression test जोड़ा: per-booking location transport catch, cards-before-location ordering और loader busy-state cleanup जाँचता है।
- यह source-contract सुधार है; live GPS/provider, browser और network fault-injection परीक्षण अभी नहीं हुए।
- निरीक्षण में पाया कि optional profile panels पर rejected request संभाली जा रही थी, लेकिन हर panel को `await` करने से धीमा/लंबे समय तक pending panel मुख्य job-offer RPC को देर करा सकता था।
- `electrician.html` में optional panel loaders अब अलग-अलग promise chain में schedule होते हैं और अपने errors catch करते हैं; मुख्य offer loading इनके पूरा होने की प्रतीक्षा नहीं करती।
- Regression assertion अपडेट किया ताकि optional loaders schedule होने के बाद offer RPC तक बिना await dependency पहुँचना जाँचा जाए।
- यह source-level सुधार है; वास्तविक slow-network/browser और live Supabase परीक्षण बाकी हैं।

### 2026-11-16 — Customer/Electrician lifecycle retry cleanup coverage
- Customer work-start approval और completion response में per-booking busy guard का `finally` में release और retry guidance inspected.
- Electrician work-start/completion requests में busy guard release और refresh/retry messaging inspected.
- Customer refund/cancellation submit handlers में failure message तथा submit button का `finally` में re-enable होना inspected.
- Electrician offer response में busy guard release और response buttons का पुनः enable होना inspected.
- इन paths के source-contract regression assertions `tests/customer-electrician-booking-status-sync-contract.test.js` में जोड़े गए। यह source inspection/contract coverage है; वास्तविक network fault injection, live RPC/database और browser testing नहीं हुई।
- Exact latest commit पर CI परिणाम उपलब्ध होने तक इन tests को passed नहीं माना जाएगा।

### 2026-11-16 — Customer booking supplementary RPC resilience
- `booking.html`: Customer booking list में call contacts, refund requests, cancellation requests और cancellation-fee items के supplementary RPC अब `safeCustomerRpc` से अलग-अलग transport rejection संभालते हैं। एक supplementary request reject होने पर मुख्य owner-scoped booking list को generic load failure से overwrite नहीं किया जाएगा।
- Regression test `customer booking list survives rejected supplementary contact, refund, and cancellation RPCs` जोड़ा गया।

- अतिरिक्त जाँच: completed booking के labour-bill RPC में rejected transport पहले पूरे booking loader को रोक सकता था। अब प्रत्येक bill request अलग try/catch में है; bill अस्थायी रूप से न आए तो booking history फिर भी दिखाई देती है। उसी test file में इस failure path का source-contract assertion जोड़ा गया।
- Exact latest head पर CI अभी सत्यापित नहीं है; live browser/Supabase और mobile QA लंबित हैं।
- यह source-contract test है; browser/network fault injection, live Supabase RPC/RLS और mobile QA अभी बाकी हैं।


### 2026-11-16 — Customer payment-method change transport handling
- Customer के “Cash से Online भुगतान चुनें” action में RPC reject होने पर कोई local try/catch नहीं था; network failure unhandled rejection बन सकती थी और ग्राहक को स्पष्ट retry संदेश नहीं मिलता था।
- RPC call को try/catch में रखा, success response में `data.success` की पुष्टि जोड़ी, और transport/अनिश्चित response पर सुरक्षित retry संदेश दिया। सफल बदलाव के बाद booking history refresh होती है।
- Regression test जोड़ा गया। यह source-contract जाँच है; वास्तविक payment-method RPC, browser/network fault injection और mobile QA अभी लंबित हैं।


### Electrician Earnings और Wallet network-failure isolation
- Earnings panel में earnings RPC और Admin payout-history query एक Promise.all में थीं; किसी एक transport rejection पर पूरा loader reject होकर panel “लोड हो रहा है” पर अटक सकता था। दोनों requests को स्वतंत्र rejection handling दी; earnings उपलब्ध रहे तो payout-history failure अलग संदेश दिखाएगा।
- Wallet panel में summary RPC और bank-link / ledger queries के rejected promises panel को अधूरे loading state में छोड़ सकते थे। तीनों request paths को सुरक्षित rejection result में बदला; bank-link और ledger errors अलग-अलग दिखेंगे, उपलब्ध balance summary सुरक्षित रहेगी।
- Regression source-contract test जोड़ा। यह वास्तविक Supabase/network fault injection नहीं है; DB/RLS, browser और अंतिम mobile QA अभी लंबित हैं।


### Electrician profile/support panels — rejected transport handling
- Area-change history और KYC document history RPC को rejected network promises से सुरक्षित किया; panel अब स्पष्ट उपलब्धता/Refresh संदेश दिखाएगा।
- Support ticket list RPC rejection पर raw error text दिखाने के बजाय सुरक्षित Hindi retry संदेश देती है।
- Phone-change request history Edge Function transport rejection को संभालती है; मौजूदा सुरक्षित status/error flow बना रहता है।
- Regression source-contract test जोड़ा। वास्तविक Supabase/Edge Function/browser fault-injection और अंतिम mobile QA अभी लंबित हैं।


### Electrician Support Ticket सूची/बातचीत — त्रुटि सुधार
- Support ticket list loader में transport-safe result लाने के बाद पुराना undefined `error` variable reference बचा हुआ था; उसे हटाकर उसी result.error का उपयोग सुनिश्चित किया। यह वास्तविक source bug था जो सामान्य सफल response पर भी ReferenceError दे सकता था।
- Support thread messages RPC को rejected network promise से सुरक्षित किया; failure पर बातचीत पैनल में Retry संदेश आता है।
- Regression source-contract test जोड़ा। वास्तविक browser/network fault-injection और Supabase runtime जाँच अभी लंबित हैं।


### Electrician App — प्रारंभिक Auth Session नेटवर्क विफलता
- App initialization में `sb.auth.getSession()` के rejected promise / session error के लिए catch जोड़ा।
- विफलता पर unhandled promise rejection के बजाय login screen और स्पष्ट OTP retry संदेश दिखेगा।
- Regression source-contract test जोड़ा; वास्तविक browser/network fault injection और live Supabase auth परीक्षण अभी लंबित हैं।


### Customer App — Profile और Saved Address Auth Session Handling
- Customer Profile तथा Saved Address loaders में `auth.getSession()` अब try/catch के अंदर है और session error को स्पष्ट रूप से संभालता है।
- नेटवर्क/Session lookup विफल होने पर unhandled rejection के बजाय सुरक्षित हिंदी स्थिति संदेश दिखेगा; Saved Address selector का disabled state finally में वापस सक्रिय होगा।
- Regression source-contract test जोड़ा। वास्तविक browser/network fault-injection तथा Supabase Auth runtime परीक्षण अभी लंबित हैं।


### Customer App — Saved Address Save Auth Error Handling
- `saveCurrentBookingAddress()` में Auth Session lookup पहले try/catch से बाहर था; rejected promise पर unhandled rejection और button अटका रह सकता था।
- Session lookup को try/catch के भीतर रखा, sessionError स्पष्ट जाँचा, और मौजूदा finally से बटन restore होना सुनिश्चित किया।
- Regression source-contract test जोड़ा। वास्तविक browser/network fault-injection तथा Supabase Auth परीक्षण लंबित हैं।


### Customer App — Profile/Support/Payment/Booking Auth Error Checks
- Avatar upload, support message, Razorpay payment और booking submission में Auth Session lookup का returned `error` अब स्पष्ट जाँचा जाता है; केवल session data मौजूद होने पर आगे बढ़ेंगे।
- Source-contract regression coverage जोड़ी। ये source-level checks हैं; browser/network fault-injection और live Supabase Auth/provider testing अभी लंबित हैं।


### Electrician App — Push Notification बंद करने का सुरक्षित क्रम
- पहले सर्वर की `srk_push_subscriptions` endpoint row हटती है; सफल होने पर ही ब्राउज़र subscription unsubscribe होती है।
- इससे server-side delete विफल होने पर ब्राउज़र subscription को पहले बंद करके पुराना server record छोड़ने की स्थिति नहीं बनती।
- Regression source-contract test जोड़ा। वास्तविक Push provider/ब्राउज़र परीक्षण अभी लंबित हैं।


### Electrician App — Push Setup विफल होने पर नई Subscription Rollback
- Push setup में ब्राउज़र द्वारा नई Subscription बनाए जाने के बाद Supabase upsert/Auth/config चरण विफल हो, तो केवल उसी नई Subscription को best-effort unsubscribe किया जाता है।
- पहले से मौजूद Subscription को rollback में बंद नहीं किया जाता; सफल setup पर rollback reference साफ़ कर दिया जाता है।
- Regression source-contract test जोड़ा। वास्तविक browser Push और Supabase provider परीक्षण लंबित हैं।


### Customer App — Booking Submit Auth Regression Test सटीकता
- Booking submit handler में customerSb.auth.getSession() के error: sessionError को जाँचने, session मौजूद होने, Bearer access token लगाने और session error पर /api/create-booking request रोकने की वास्तविक assertions जोड़ी गईं।
- पुराना test global file में payment handler के sessionError match को booking submit के लिए पर्याप्त मान रहा था; अब test सीधे booking form के submit-handler block को जाँचता है।
- यह test coverage correction है; application source में कोई बदलाव नहीं। Source-contract test को exact current commit पर CI से चलाना बाकी है।


### Customer App — Support Thread Network Failure Isolation
- Customer शिकायत सूची लोड होने के बाद चुनी हुई शिकायत की बातचीत RPC transport rejection को अब thread loader स्वयं सुरक्षित रूप से संभालता है; इससे बातचीत का नेटवर्क failure पूरी शिकायत सूची refresh को विफल नहीं दिखाएगा।
- Attachment list की स्वतंत्र error handling और stale-thread request guard बरकरार हैं।
- Regression source-contract test जोड़ा। वास्तविक browser/network और Supabase RLS परीक्षण अभी लंबित हैं।


### Electrician App — Existing Push Subscription Re-sync
- यदि ब्राउज़र में Push Subscription मौजूद हो लेकिन पिछली बार सर्वर पर endpoint upsert विफल हुआ हो, तो पहले UI में Enable बटन बंद हो जाता था और उसी मौजूदा subscription को दोबारा register करने का रास्ता नहीं रहता था।
- अब मौजूदा browser subscription के साथ भी Enable उपलब्ध रहता है; enable handler उसी subscription को server table में फिर से upsert करता है। Disable क्रम और नई subscription rollback व्यवहार अपरिवर्तित हैं।
- Regression source-contract test जोड़ा। वास्तविक browser Push, Supabase RLS और provider delivery परीक्षण अभी लंबित हैं।


### 2026-11-16 — Electrician OTP, availability और सुरक्षित logout contract coverage
- OTP login के phone validation, resend cooldown, signInWithOtp, busy-state cleanup और send-button restoration के source-contract assertions जोड़े।
- OTP verification के SMS flow, token validation और busy-state cleanup के assertions जोड़े।
- Availability change में approved-active profile gate, explicit confirmation, self-service RPC और failure पर buttons restore होने के assertions जोड़े।
- Logout में active GPS watches clear करना, हर live-location server stop की पुष्टि, stop failure पर sign-out रोकना और Auth sign-out error handling के assertions जोड़े।
- ये source-contract tests हैं; वास्तविक SMS/Auth, availability RPC, GPS/browser तथा live Supabase actor-isolation runtime अभी लंबित हैं। इस commit पर CI run उपलब्ध नहीं है।


### 2026-11-16 — Electrician KYC duplicate-upload रोकथाम
- KYC upload handler में global in-flight guard जोड़ा; एक दस्तावेज़ अपलोड रहते दूसरा KYC upload शुरू नहीं होगा।
- अपलोड के दौरान KYC file inputs और upload/preview buttons अस्थायी रूप से disable होते हैं; completion/failure दोनों स्थितियों में उनकी पुरानी disabled state finally में restore होती है।
- Regression source-contract test जोड़ा। यह browser/storage runtime test नहीं है; वास्तविक Storage RLS, duplicate-click fault-injection और mobile QA अभी लंबित हैं।


### 2026-11-16 — Customer Profile avatar upload की uncertain-save cleanup
- Avatar upload के बाद profile update RPC का transport response reject होने पर नया private Storage object orphan रह सकता था।
- अब ऐसे uncertain result पर owner profile दोबारा पढ़ा जाता है; केवल तभी नया object हटता है जब authoritative profile में वही avatar path सेव न हो। Re-read विफल हो तो object delete नहीं किया जाता, ताकि सफल server-side save का avatar टूटे नहीं।
- Source-contract regression test जोड़ा। वास्तविक Supabase Storage/RPC fault-injection और browser validation अभी लंबित हैं।


### 2026-11-16 — Customer Support attachment uncertain-link cleanup
- Support message में फ़ाइल upload होने के बाद attachment-link RPC का network response reject हो सकता था, जबकि Database में link सफलतापूर्वक commit हो चुका हो। पुराने catch में Storage object तुरंत delete हो जाता और committed attachment record टूटी हुई फ़ाइल की ओर संकेत कर सकता था।
- अब cleanup से पहले complaint के authoritative attachment records दोबारा पढ़े जाते हैं। Object केवल सफल read में उसका link अनुपस्थित मिलने पर हटेगा; read विफल/अनिश्चित हो तो object सुरक्षित रखा जाएगा।
- Source-contract regression test जोड़ा। वास्तविक Supabase RPC/Storage fault-injection, RLS और browser परीक्षण अभी लंबित हैं।


### 2026-11-16 — Customer Saved Address default update refresh-result handling
- `loadCustomerSavedAddresses()` अपनी त्रुटि स्वयं दिखाकर लौटता था, लेकिन `makeSelectedAddressDefault()` उसके बाद सफलता संदेश लिख देता था। इससे सूची रीफ़्रेश विफल होने पर भी उपयोगकर्ता को सफल refresh का गलत संकेत मिल सकता था।
- Loader अब success/failure boolean लौटाता है। Default-address mutation के बाद refresh विफल हो तो UI स्पष्ट करता है कि update request सफल रही, लेकिन सूची रीफ़्रेश नहीं हुई; सफलता का गलत संदेश नहीं दिखता।
- Source-contract regression test जोड़ा। वास्तविक Supabase RPC/browser fault-injection अभी लंबित है।


### 2026-11-16 — Customer Saved Address delete uncertain-result reconciliation
- Delete RPC का response network में खो जाने पर ऐप बिना जाँच के “पता नहीं हट सका” दिखा सकता था, जबकि server पर deletion commit हो चुका हो। सफल delete के बाद सूची refresh विफल होने पर भी पुराना code success message दिखा देता था।
- अब successful RPC के बाद refresh result जाँचा जाता है। Rejected/uncertain RPC पर authoritative saved-address list दोबारा पढ़ी जाती है: पता अनुपस्थित हो तो deletion confirmed, मौजूद हो तो retry guidance, और read भी विफल हो तो स्थिति स्पष्ट न होने का सुरक्षित संदेश।
- Source-contract regression test जोड़ा। वास्तविक Supabase RPC/network fault-injection और browser परीक्षण लंबित हैं।


### 2026-11-16 — Customer Refund/Cancellation uncertain-response reconciliation
- Refund request RPC या cancellation request RPC का network response reject होने पर पहले UI generic failure दिखा सकती थी, जबकि server transaction commit हो चुका हो सकता था। Blind retry से duplicate/गलत धारणा का जोखिम था।
- अब catch path संबंधित owner-scoped list RPC पढ़ता है। Refund के लिए booking_id पर मौजूद request और उसका सुरक्षित status दिखता है; cancellation के लिए उसी booking का pending request खोजा जाता है। पुष्ट request मिलने पर refresh किया जाता है और कोई दूसरा write स्वतः नहीं भेजा जाता। List read भी विफल हो तो परिणाम स्पष्ट न होने का संदेश दिया जाता है।
- दोनों flows के source-contract regression tests जोड़े। वास्तविक Supabase transport fault-injection, browser और RLS परीक्षण लंबित हैं।


### 2026-11-16 — Customer Support complaint uncertain-response reconciliation
- Complaint create RPC का response network में reject हो सकता है जबकि server पर complaint commit हो चुकी हो। पहले UI सीधे failure दिखाती और blind retry से duplicate complaint बन सकती थी।
- अब catch path owner-scoped `srk_customer_list_booking_complaints` पढ़कर booking, category और exact description से matching complaint खोजता है। Match मिलने पर reference दिखता है, complaint list refresh होती है और कोई दूसरा create RPC नहीं भेजा जाता। List read भी विफल हो तो परिणाम अनिश्चित बताकर पहले सूची जाँचने को कहा जाता है। Daily limit error का अलग संदेश बरकरार है।
- Source-contract regression test जोड़ा; वास्तविक Supabase/network fault-injection और browser परीक्षण लंबित हैं।


### 2026-11-16 — Electrician Support ticket/message uncertain-response reconciliation
- Support ticket create या reply RPC का response खो जाने पर UI सीधे failure दिखा सकती थी, जबकि server write commit हो चुका हो।
- अब create से पहले owner-scoped ticket ID snapshot और reply से पहले thread message ID snapshot लिया जाता है। RPC response reject होने पर नई IDs, ticket metadata और exact electrician message body मिलाकर committed write खोजा जाता है। पुष्टि मिलने पर सफलता/refresh; नहीं मिलने या read विफल होने पर duplicate से बचने के लिए पहले Refresh करने की सलाह। Preflight list उपलब्ध न हो तो write भेजा ही नहीं जाता।
- दो source-contract regression tests जोड़े; live Supabase transport fault-injection और browser tests लंबित हैं।
