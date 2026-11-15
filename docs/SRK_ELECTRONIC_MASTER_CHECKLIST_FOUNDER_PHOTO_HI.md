# SRK ELECTRONIC — मुख्य मास्टर चेकलिस्ट (एकीकृत स्थिति)

**अंतिम मिलान:** 15 नवम्बर 2026  
**काम की branch:** `feat/customer-login-first-dashboard-20261114`  
**Repository:** `shahrukhkhan12136-bot/Srk-electranic-`  
**स्थिति का नियम:** [x] = Feature Branch source में implement/verified; इसका अर्थ Production पर लागू होना नहीं है। Runtime/Production/owner approval को अलग स्पष्ट रखा गया है। पुरानी विस्तृत कार्य-इतिहास `docs/SRK_ELECTRONIC_PROJECT_PROGRESS_HI.md` में है। इस checklist में duplicate पुराने pending items को बार-बार नहीं दोहराया जाएगा।

---

## 1. ग्राहक (Customer) — Feature Branch implementation

- [x] Customer booking form, account/login, booking history और profile source मौजूद।
- [x] Booking submission idempotency और customer-selected rate tier/server estimate source मौजूद।
- [x] Saved addresses और private avatar storage source मौजूद।
- [x] Payment method change, payment history और receipt RPC source मौजूद।
- [x] Customer refund request create/history RPC; customer ownership filter और private Admin note exclusion लागू।
- [x] Cancellation-fee debt और booking fee-item history RPC; authenticated-only execution ACL source में जोड़ी।
- [x] Customer cancellation request/fee carry-forward और refund reversal workflow source मौजूद।
- [x] Customer और electrician phone numbers acceptance से पहले छिपे; acceptance के बाद full number visible; Support Staff को unrestricted phone projection नहीं।
- [x] Legacy customer receipt अब labour और materials अलग-अलग दिखाती है और total को approved quote से reconcile करती है।
- [ ] Customer payment/refund/cancellation के सभी owner/non-owner/anon और duplicate/concurrency व्यवहार isolated database में runtime verify करें।

## 2. इलेक्ट्रिशियन (Electrician) — Feature Branch implementation

- [x] Electrician offer inbox/response और sequential nearest dispatch source मौजूद।
- [x] Offer acceptance पर current location/district, active status और exact Admin-approved rate tier पुनः जाँचे जाते हैं।
- [x] Availability toggle और relocation request/Admin approval source मौजूद।
- [x] Labour quote और materials quote अलग-अलग; customer approval/rejection workflow source मौजूद।
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

- [ ] इसी exact approved portrait का binary recover करके Feature Branch में commit करें।
- [ ] वास्तविक website Welcome Screen बनाएँ/restore करें; वर्तमान `index.html` redirect को Welcome Screen की जरूरत के अनुसार ठीक करें।
- [ ] Portrait को natural proportions और professional crop के साथ Welcome Screen में integrate करें।
- [ ] Automated build/check और Vercel Preview में asset/page load verify करें।
- [ ] Owner visual acceptance लें।
- [ ] Desktop और responsive/mobile presentation final consolidated QA में verify करें।

## 7. Documentation और source consistency

- [x] README phone visibility policy owner-approved rule के अनुसार सुधारी गई।
- [ ] README endpoints, feature descriptions और all portal UI copy को latest source से अंतिम बार मिलाएँ।
- [ ] Customer, Electrician, Admin और Staff के हर visible button/action को source/API contract से one-by-one reconcile करें; कोई dead button, missing field, placeholder या stale label न छोड़े।

## 8. Test, release और approval gates

- [x] Latest available full Node test run: **87 passed / 0 failed**।
- [x] Push Deno check और local PostgreSQL Push migration/RPC runtime checks PASS।
- [ ] ऊपर सूचीबद्ध शेष Customer/Electrician/Admin/Staff/legacy-payment SQL और browser workflows के isolated runtime tests पूरे करें।
- [ ] सभी implementation और internal checks पूरे होने के बाद ही एक consolidated desktop + mobile QA pass करें; बीच में अलग mobile test नहीं।
- [ ] यदि final end-to-end testing के लिए अलग Supabase staging branch/subscription जरूरी हो, तो पहले लागत बताकर owner की स्पष्ट अनुमति लें। अभी कोई paid Development Branch न बनाएँ।
- [ ] Vercel Preview/build सफलतापूर्वक verify करें; पिछली failure `upgradeToPro=build-rate-limit` थी, इसलिए उसे application test failure या successful build न मानें।
- [ ] PR #8 को review-ready करें; owner की स्पष्ट अनुमति के बिना merge न करें।
- [ ] Owner की अलग स्पष्ट अनुमति के बिना Production migration, Auth/Storage/settings, provider refund/Route, real SMS/OTP, push send, deployment या go-live न करें।

---

## अभी का साफ निष्कर्ष

**Feature implementation:** कई मुख्य Customer, Electrician, Admin/Staff, payment/refund, KYC, timer, dispatch और Push workflows Feature Branch में implement हैं; legacy manual-payment source gap भी अभी जोड़ा गया है।  
**अभी का सबसे स्पष्ट source-level blocker:** exact approved founder portrait binary और Welcome Screen integration।  
**अभी का मुख्य verification blocker:** non-Push database/RPC/browser end-to-end runtime; Push के local PostgreSQL tests सफल हैं, लेकिन managed Supabase parity और Edge↔Netlify/provider integration बाकी है।  
**Production:** कोई migration apply, merge, deployment या live payment action नहीं किया गया है।

