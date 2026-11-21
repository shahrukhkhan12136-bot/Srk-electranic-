# SRK ELECTRONIC — Frontend Master Checklist (Hindi)

**दायरा:** केवल Customer Android App और Technician Android App  
**काम की branch:** `feature/playstore-mobile-apps-gpt1-20261121`  
**Requirements authority:** Founder के नवीनतम स्वीकृत निर्देश; पुराने UI/दस्तावेज़ से टकराव होने पर नवीनतम निर्देश लागू होंगे।  
**नियम:** इस checklist में `[x]` का अर्थ केवल उसी मद का source/test evidence उपलब्ध होना है। इससे Production readiness या Play Store approval सिद्ध नहीं होता।

## 0. सुरक्षा और काम की सीमाएँ
- [ ] हर बदलाव इसी approved frontend feature branch में करें; Main/Production पर नहीं।
- [ ] Backend, database schema, RPC, migrations, Netlify functions, payment provider settings या live data न बदलें।
- [ ] GPT-2 द्वारा आवश्यक API/RPC contract न मिलने पर संबंधित UI को स्पष्ट रूप से Blocked रखें; fake success/mock live payment न दिखाएँ।
- [ ] पुराने records, tables, columns, RPCs और migrations को dependency/impact audit तथा अलग owner approval के बिना delete/retire न करें।
- [ ] पुराने Master Checklist और project history को overwrite न करें; यह नई frontend checklist अलग रखी गई है।
- [ ] हर चरण के बाद changed files, tests, build result और शेष blockers दर्ज करें।

## 1. प्रारंभिक source audit — ज्ञात निष्कर्ष
- [x] Flutter Customer app source मौजूद: `apps/customer_app/lib/main.dart`।
- [x] Flutter Technician app source मौजूद: `apps/electrician_app/lib/main.dart`।
- [x] Shared login/core package मौजूद: `packages/srk_mobile_core`।
- [x] मौजूदा Customer source में legacy quotation states, quote response RPC और quote-आधारित booking logic मिला।
- [x] मौजूदा Technician source में quote details RPC, quote submission dialog/RPC, inspection और quote approval gating मिला।
- [x] Customer app में OTP/dashboard/history, cancellation, location और Razorpay-related code के उपयोगी हिस्से मिले; नए flow से compatibility जाँच आवश्यक।
- [x] Technician app में OTP, offer accept/decline, assigned bookings, location, work status, cash confirmation और wallet/earnings UI के उपयोगी हिस्से मिले; नए flow से compatibility जाँच आवश्यक।
- [x] CI workflow अभी manual dispatch पर Customer, Electrician और Admin तीनों के Debug APK बनाता है; यह Play Store release pipeline नहीं है।
- [x] CI workflow Android project scaffolding build के समय generate करता है; reproducibility और committed Android project structure जाँचना है।
- [x] CI में Admin App build है, लेकिन इस frontend scope में Admin Android App शामिल नहीं है।
- [x] README में release signing को अभी configure/test होना बाकी बताया गया है।
- [x] Mobile branch और backend requirements branch diverged हैं (79 commits ahead, 1270 behind); wholesale merge निषिद्ध।
- [ ] पुराने web/PWA Customer और Technician flows तथा पुराने checklist से preserve/retire map पूरा करें।
- [ ] दोनों Flutter apps के सभी source files, Android config, tests, assets, API calls और dependency graph का पूर्ण inventory पूरा करें।

## 2. पुराने UI/flow का सुरक्षित निपटान
- [ ] Customer App से quotation creation/entry, quote wait, approve/reject, quote status और quote-based amount gating हटाएँ।
- [ ] Technician App से quote form/dialog, quote submission, quote details display, quote status और quote approval gating हटाएँ।
- [ ] दोनों ऐप में quotation शब्द/labels/buttons/routes/status mapping का पूर्ण source search करके शून्य करें।
- [ ] पुराना inspection-first booking sequence हटाएँ; नया work-start flow लागू करें।
- [ ] पुराने booking form और category assumptions को नए booking UX से बदलें; पुरानी booking UI copy न करें।
- [ ] उपयोगी OTP/auth, secure API client, GPS permission, notifications, payment SDK, history/profile components को अलग-अलग review करके ही reuse करें।
- [ ] Backend/DB में पुराने quote data/API/RPC/migrations को इस frontend बदलाव के कारण delete न करें।
- [ ] Existing legacy bookings को सुरक्षित display/migration policy मिले; नए booking flow में legacy quote actions उपलब्ध न हों।

## 3. Customer App — account और home
- [ ] OTP login; भारतीय mobile number validation/normalization; resend cooldown; secure session handling।
- [ ] पहली सफल login पर पूरा नाम लें; बाद की login पर सीधे Home।
- [ ] Verified mobile number booking में स्वतः उपयोग हो; दोबारा भरने/बदलने की जरूरत न हो।
- [ ] Exactly six main categories: Electrician, Plumber, Painter, AC + Fridge Technician, Motor & Pump, Cooler।
- [ ] Category tiles, accessible labels, empty/error/loading states और admin-configurable category data।
- [ ] Profile, booking history, booking details, notifications, help/support, cancellation/complaint entry points।

## 4. Customer App — नया booking flow
- [ ] Category → service/subcategory → skill level → helper option (जहाँ लागू) → duration/quantity → address → technician count → price summary → BOOK NOW।
- [ ] AC + Fridge में पहले AC या Fridge चुनें; AC में Installation/Repair; Fridge में उपयुक्त task list।
- [ ] Motor & Pump में task type और winding होने पर HP selection।
- [ ] Cooler में per-cooler fixed labour selection; motor winding अलग item के रूप में।
- [ ] लागू hourly services के लिए 1 hour से 50 days तक duration।
- [ ] एक booking में 1–10 technicians चुनने का विकल्प, केवल जहाँ service operationally supports it।
- [ ] GPS optional; अनुमति होने पर auto-fill, अन्यथा manual locality/place, district, state और full work address।
- [ ] Customer किसी अन्य शहर का work address चुन सके; dispatch work address पर आधारित हो, customer home/current location पर नहीं।
- [ ] कोई mandatory pre-booking T&C checkbox नहीं।
- [ ] BOOK NOW से पहले service, level, helper, hourly/fixed rate, duration/quantity, labour estimate, travel charge policy और materials exclusion स्पष्ट दिखे।
- [ ] Admin-approved rate snapshot के आधार पर price preview; पुराने booking की कीमत अपरिवर्तित।
- [ ] Booking submission idempotency, retry-safe UX और duplicate tap protection।
- [ ] Booking success केवल backend-confirmed booking ID/status मिलने पर दिखे।

## 5. Rates और pricing display
- [ ] Electrician: Basic ₹100/hour; Basic helper rate अज्ञात — backend/admin rate मिलने तक helper price न गढ़ें।
- [ ] Electrician Expert Residential Wiring: solo ₹125/hour; helper सहित ₹187.50/hour।
- [ ] Electrician Factory/Large Project: solo ₹400/hour; helper सहित ₹550/hour।
- [ ] Electrician Master: solo ₹700/hour; helper सहित ₹950/hour।
- [ ] Plumber Basic: solo ₹100/hour; helper ₹50/hour; team ₹150/hour।
- [ ] Plumber Expert: solo ₹150/hour; helper ₹75/hour; team ₹225/hour।
- [ ] Plumber Master/Industrial: solo ₹225/hour; helper ₹100/hour; team ₹325/hour।
- [ ] Painter Basic: ₹87.50/hour; helper विकल्प अभी नहीं।
- [ ] Painter Expert: solo ₹112.50/hour; helper ₹75/hour; team ₹187.50/hour।
- [ ] Painter Master/Commercial: solo ₹150/hour; helper ₹100/hour; team ₹250/hour।
- [ ] AC: solo ₹250/hour; helper ₹150/hour; team ₹400/hour।
- [ ] Fridge: solo ₹150/hour; helper ₹75/hour।
- [ ] Motor winding fixed labour: 0.5 HP ₹500; 1 HP ₹600; 1.5 HP ₹700; 2 HP ₹800; 3 HP ₹900; 5 HP ₹1,000; 7.5 HP ₹1,100; 10 HP ₹1,200; 15 HP ₹1,300; 20 HP ₹1,400।
- [ ] Cooler repair fixed labour ₹500/cooler।
- [ ] Motor/Pump के अन्य tasks की rates Admin/backend contract से लें; अनुमान न लगाएँ।
- [ ] Parts/materials अलग itemized; customer approval के बिना charge न करें; materials पर platform commission न दिखाएँ।
- [ ] Hourly services: पहले 8 actual working hours normal rate; उसके बाद overtime 1.5x।
- [ ] Actual timer से final labour calculation; fixed Cooler/Motor winding में hourly timer/overtime नहीं।
- [ ] पुराने booking price/commission snapshots display; नई rates केवल नई bookings पर लागू।
- [ ] Money calculations paise/integer-safe; rounding backend contract से match हो।

## 6. Customer booking lifecycle और multi-day decisions
- [ ] Booking Submitted, Technician Assigned, On the Way, Arrived, Work Started, Paused, Resumed, Completed, Payment Pending/Completed, Cancelled/Complaint states।
- [ ] Customer/authorized household member arrival और completion confirm कर सके।
- [ ] Multi-day booking में daily work log और day-wise labour/attendance summary।
- [ ] प्रत्येक दिन के बाद ठीक तीन निर्णय:
  1. “कल का शेड्यूल स्वीकार करें”
  2. “काम पूरा हो गया है, अब इलेक्ट्रिशियन की जरूरत नहीं”
  3. “इनसे काम नहीं लेना है, हमें दूसरा इलेक्ट्रिशियन चाहिए”
- [ ] तीसरा निर्णय केवल भविष्य के काम के लिए technician बदलता है; project cancel नहीं करता और पुराने work/accounting records सुरक्षित रखता है।
- [ ] Cancellation, complaint, refund request और status timeline में reason/evidence दिखे।

## 7. Technician App — onboarding और dashboard
- [ ] Shared Technician Android app; एक mobile number और एक Technician ID।
- [ ] OTP login; application form: नाम, पता, provider category, skills, experience, KYC documents।
- [ ] Application states: Pending, Under Review, Approved, Rejected; Admin reason दिखे।
- [ ] Admin approval और skill verification से पहले कोई job acceptance नहीं।
- [ ] AC और Fridge skills अलग-अलग verified हों।
- [ ] Electrician, Plumber, Painter, AC/Fridge, Motor/Pump, Cooler skills और future admin-configured categories।
- [ ] Home dashboard: online/offline, available/assigned/active/completed jobs, earnings, wallet, cash due, online earnings, payout history, profile/KYC।
- [ ] Technician अपनी verified skills और service radius/status देख सके।

## 8. Technician App — availability, dispatch और GPS
- [ ] GPS city auto-detection; city बदलने पर “Welcome to [City]” सूचना।
- [ ] Online होने पर current GPS के 30 km के भीतर eligible jobs खोजें; manual city switch नहीं।
- [ ] केवल Admin-approved, online, skill-matched और available technician को offer।
- [ ] Offline technician को नए offers न मिलें; active job के दौरान बिना उचित closeout offline न हो सके।
- [ ] Assignment distance straight-line GPS; travel charge road distance से।
- [ ] पहले 3 km free; उसके बाद ₹4 प्रति अतिरिक्त road km; one-way only।
- [ ] GPS unavailable होने पर last update time/location और refresh action।
- [ ] केवल online/active job के आवश्यक समय में location tracking; user-facing disclosure और consent।
- [ ] Closest eligible technician को पहले offer; timeout/decline पर अगला closest; requested technician count पूरा होने तक sequential offers।
- [ ] Duplicate technician per booking रोकें; assignment IDs unique; concurrent acceptance सुरक्षित।
- [ ] No eligible/accepting technician होने पर स्पष्ट retry/escalation state और support contact।

## 9. Technician App — job execution
- [ ] Assigned job detail में service, level, helper, work address, distance/travel, duration और customer instructions।
- [ ] On the Way, Arrived, Work Started, Paused, Resumed, Completed actions backend-authoritative।
- [ ] Timer केवल actual work start पर शुरू; GPS अकेले work proof नहीं।
- [ ] Customer confirmation + GPS evidence + timer + audit trail का combined verification।
- [ ] Break/pause/resume और day-wise time entries।
- [ ] 8 actual working hours के बाद 1.5x overtime; daily calculation स्पष्ट।
- [ ] Customer को live work status/timer और अनुमानित/final bill view।
- [ ] Additional parts/materials itemization और customer approval; quote/quotation workflow नहीं।
- [ ] Customer rating और Technician rating दोनों।
- [ ] Completed event idempotent; duplicate completion से count/earning दोबारा न बढ़े।

## 10. Payment UI — Customer और Technician
- [ ] Customer full booking amount Razorpay से pay करे; payment success केवल verified Razorpay/backend confirmation के बाद।
- [ ] Razorpay settlement company bank account में provider schedule के अनुसार; लगभग 2 दिन को guaranteed promise न करें।
- [ ] Technician share 85%, company share 15%; Admin बदल सके, कुल 100% enforce हो।
- [ ] Commission और technician share booking पर snapshot हों; बाद की rate/commission change पुराने booking को न बदले।
- [ ] Technician payout manual; app में total earned, 85% share, paid, pending, requested, payout status और UTR।
- [ ] Payout request create/status/history UI; duplicate request/payout protection backend enforced।
- [ ] Cash/online mode rotation: प्रत्येक Technician ID पर सभी categories मिलाकर केवल verified Completed Bookings count हों; 1st/2nd cash या online, 3rd online-only; यही 3-booking cycle दोहरती है।
- [ ] Cancelled, rejected, pending, accepted या incomplete booking count न हो।
- [ ] Cash collection, cash due और online earnings अलग दिखें; backend contract से reconcile।
- [ ] Razorpay secret/webhook secret/service_role key कभी mobile app में न रखें।
- [ ] Refund/payment failure/pending states स्पष्ट; client-side success का झूठा दावा नहीं।

## 11. API contract और GPT-2 dependencies
- [ ] GPT-2 से नवीनतम API/RPC contract, payloads, response schema, auth rules और error codes प्राप्त करें।
- [ ] Category/rate catalog और rate snapshots।
- [ ] Booking create/update/cancel/complaint तथा multi-technician assignment।
- [ ] Technician onboarding/KYC/approval/skills/availability/dispatch।
- [ ] GPS consent/location update/distance/travel charge।
- [ ] Work timer, pause/resume, daily logs, completion verification और ratings।
- [ ] Materials itemization/customer approval।
- [ ] Razorpay order/create/verify/webhook status और payout request/status।
- [ ] Completed-only booking counter/payment mode eligibility।
- [ ] Notifications, customer/technician history, support and audit projections।
- [ ] हर API call में ownership, authorization, retry/idempotency और offline/error behaviour verify करें।
- [ ] Contract unavailable होने पर feature को Blocked चिह्नित करें; fake/mock backend response को production feature न मानें।

## 12. Play Store release readiness
- [ ] स्थायी Android project scaffolding repository में committed और reproducible।
- [ ] Customer और Technician के unique application IDs, app labels, launcher icons, splash screens।
- [ ] Release keystore सुरक्षित रूप से external secrets में; signing config source में secret-free।
- [ ] Debug और Release build अलग; Play Store के लिए signed AAB।
- [ ] Version code/name policy; package IDs स्थिर।
- [ ] Android permissions केवल आवश्यक; location/notifications/media permissions का स्पष्ट disclosure।
- [ ] Privacy policy, data safety declaration, account deletion/contact/support details।
- [ ] App links/deep links, network security, HTTPS-only API।
- [ ] Crash reporting/logging में OTP, tokens, phone/address, payment secrets न आएँ।
- [ ] Accessibility, responsive layouts, Hindi copy, font scaling, TalkBack, contrast।
- [ ] Unit/widget/integration tests; API contract tests; critical end-to-end tests।
- [ ] Physical Android device tests: low network, denied GPS, app restart, OTP expiry, payment pending/failure, duplicate taps।
- [ ] Play internal testing track, pre-launch report, policy review और owner acceptance।
- [ ] Release artifact checksum, build provenance और rollback/version notes।

## 13. Quality, security और regression
- [ ] Customer और Technician roles की cross-access रोकें; केवल server-authorized data।
- [ ] Secure token storage/session expiry/logout।
- [ ] No hard-coded secrets; no sensitive PII in logs/screenshots/notifications।
- [ ] API timeout/retry/backoff; safe empty/loading/error states; duplicate submission protection।
- [ ] Booking lifecycle state transition guard; invalid transition UI से रोकें और backend rejection handle करें।
- [ ] No dead buttons, placeholder labels, fake success, unreachable screens।
- [ ] All visible controls manually audited against real API contract।
- [ ] Regression tests: OTP, history, profile, cancellation, complaint, location, notifications, payment।
- [ ] Build/analyze/test evidence प्रत्येक चरण के बाद दर्ज।

## 14. विरासत और shared platform preservation
- [ ] Existing Data Recovery, Staff Management, AI Assistant, Digital Services और Admin web panel को इस mobile task में अनावश्यक रूप से न बदलें।
- [ ] Staff Management पहले से completed बताया गया है; इसे दोबारा implement न करें।
- [ ] Digital Services और Admin web panel अलग existing scope हैं; Admin Android App इस वर्तमान frontend delivery का हिस्सा नहीं।
- [ ] Emergency Controls — Main Admin restricted, safeguards और immutable audit।
- [ ] Security — RLS/RPC, privacy, storage, retention, observability, performance, accessibility और cross-role regression।
- [ ] Backup & Recovery — existing system preserve/verify; daily backup, retention, encryption, off-site copy, restore runbook/drill जैसी क्षमताओं को audit करके gaps दर्ज करें; बिना evidence implemented न मानें।
- [ ] नए mobile UI से पुराने data recovery/backup/security controls कमजोर न हों।

## 15. अंतिम acceptance gates
- [ ] नवीनतम requirements बनाम screens/API का traceability matrix complete।
- [ ] Customer App source + tests + signed AAB verified।
- [ ] Technician App source + tests + signed AAB verified।
- [ ] सभी quotation UI/API references नए app source में शून्य; legacy backend objects सुरक्षित जब तक अलग retirement approval न मिले।
- [ ] All blockers resolved or explicitly accepted by owner.
- [ ] Owner demo/acceptance; no production deployment without separate authorization.

## प्रगति लॉग
| तारीख | चरण | बदली गई फाइलें | टेस्ट/Build प्रमाण | स्थिति |
|---|---|---|---|---|
| 2026-11-21 | प्रारंभिक source audit | कोई app source file नहीं बदली | GitHub source inspection; build अभी नहीं चलाया | In progress |\n| 2026-11-21 | CI scope correction | `.github/workflows/flutter-android-ci.yml` | Workflow re-fetched; Customer + Technician steps मौजूद, Admin references अनुपस्थित; CI run/build अभी नहीं किया | Complete (scope edit only) |
