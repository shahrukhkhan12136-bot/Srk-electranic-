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
- [x] मौजूदा Customer source में booking flow के साथ quotation से जुड़े अतिरिक्त states/actions मिले; Founder के निर्देशानुसार booking flow सुरक्षित रखना है और केवल अनावश्यक quotation विकल्प हटाने हैं।
- [x] मौजूदा Technician source में मौजूदा job/booking flow के साथ quote submission/details और quote approval से जुड़े अतिरिक्त विकल्प मिले; मूल booking/job flow सुरक्षित रखना है।
- [x] Customer app में OTP/dashboard/history, cancellation, location और Razorpay-related code के उपयोगी हिस्से मिले; नए flow से compatibility जाँच आवश्यक।
- [x] Technician app में OTP, offer accept/decline, assigned bookings, location, work status, cash confirmation और wallet/earnings UI के उपयोगी हिस्से मिले; नए flow से compatibility जाँच आवश्यक।
- [x] CI workflow अभी manual dispatch पर Customer, Electrician और Admin तीनों के Debug APK बनाता है; यह Play Store release pipeline नहीं है।
- [x] CI workflow Android project scaffolding build के समय generate करता है; reproducibility और committed Android project structure जाँचना है।
- [x] CI में Admin App build है, लेकिन इस frontend scope में Admin Android App शामिल नहीं है।
- [x] README में release signing को अभी configure/test होना बाकी बताया गया है।
- [x] Mobile branch और backend requirements branch diverged हैं (79 commits ahead, 1270 behind); wholesale merge निषिद्ध।
- [ ] पुराने web/PWA Customer और Technician flows तथा पुराने checklist से preserve/retire map पूरा करें।
- [ ] दोनों Flutter apps के सभी source files, Android config, tests, assets, API calls और dependency graph का पूर्ण inventory पूरा करें।

## 2. मौजूदा booking flow सुरक्षित रखते हुए अनावश्यक विकल्प हटाना
- [ ] Customer App से केवल quotation creation/entry, quote wait, approve/reject, quote status और quote-based amount gating हटाएँ; मौजूदा booking flow न हटाएँ।
- [ ] Technician App से केवल quote form/dialog, quote submission, quote details display, quote status और quote approval gating हटाएँ; मौजूदा assigned-job/booking actions सुरक्षित रखें।
- [ ] दोनों ऐप में customer/technician के लिए दिखने वाले quotation विकल्प, labels, buttons, routes और status mapping हटाएँ; केवल आवश्यक material itemization/customer approval रखें।
- [ ] मौजूदा booking/job lifecycle का audit करें; केवल quote approval पर निर्भर अनावश्यक inspection gating हटाएँ। मौजूदा सही status/actions सुरक्षित रखें।
- [ ] मौजूदा booking form और booking UX को आधार बनाकर केवल आवश्यक नई categories/rates/helper/duration/address विकल्प जोड़ें या सुधारें; booking form दोबारा न बनाएँ।
- [ ] मौजूदा OTP/auth, secure API client, GPS permission, notifications, payment SDK, booking/history/profile components को सुरक्षित रखें; बदलाव से पहले compatibility जाँचें।
- [ ] Backend/DB में पुराने quote data/API/RPC/migrations को इस frontend बदलाव के कारण delete न करें।
- [ ] पहले से बनी bookings/history को सुरक्षित रखें; पुराने records पर quote actions न दिखाएँ और कोई data/API/database delete न करें।

## 2A. विस्तृत booking/quotation source audit — 2026-11-21

- [x] Customer source में मौजूदा booking submit endpoint `/api/create-booking`, OTP session, customer booking list, cancel और complaint actions की पुष्टि।
- [x] Customer booking form में नाम/फोन, पता, GPS, service, date/time, payment method और optional suggested amount मौजूद हैं; इसे आधार बनाकर रखना है।
- [x] Customer booking card में quote status, labour/material total, approve/reject buttons और online payment को quote-approved status से बाँधने की पुष्टि।
- [x] Technician source में existing offer inbox, accept/decline, assigned booking, map/contact, work status, cash confirmation, earnings और wallet की पुष्टि।
- [x] Technician UI में quote details list, quote submission dialog/RPC, inspection-first action और quote-approved होने पर ही work-start action की पुष्टि।
- [x] Current mobile branch के `create-booking.js` में `quoted_amount` optional input अभी भी मौजूद है।
- [x] Current mobile branch migration `20261109_electrician_inspection_quotes_and_service_only_commission.sql` में quote columns/statuses, quote submission/customer response RPC और quote approval पर निर्भर work-start transition मौजूद हैं।
- [ ] Backend owner/GPT-2 से quote-free booking lifecycle और material-approval API contract प्राप्त करें; frontend में केवल UI छिपाकर backend transition को अनुमान से न बदलें।
- [ ] पुष्टि करें कि existing booking create endpoint और offer dispatch quote-free booking पर भी सुरक्षित रूप से काम करते हैं।
- [ ] पुष्टि करें कि customer payment calculation/verification quote status पर निर्भरता के बिना approved booking total से कैसे चलेगी।
- [ ] Legacy quote वाले पुराने bookings के read-only display और नए bookings के quote-free lifecycle को अलग रखें।
- [ ] API contract मिलने के बाद ही UI source edit करें; backend migration/RPC/production में कोई बदलाव इस frontend कार्य में नहीं होगा।

**महत्वपूर्ण dependency:** Quotation UI सिर्फ अलग स्क्रीन नहीं है। मौजूदा backend migration में booking status `assigned → inspection → awaiting_quote_approval → quote_approved → in_progress` और work-start अनुमति quote approval से जुड़ी है। इसलिए केवल buttons हटाकर status/RPC call बदलना सुरक्षित नहीं होगा। Backend contract/owner approval के बिना उस lifecycle को छेड़ना नहीं है।

## 3. Customer App — account और home
- [ ] OTP login; भारतीय mobile number validation/normalization; resend cooldown; secure session handling।
- [ ] पहली सफल login पर पूरा नाम लें; बाद की login पर सीधे Home।
- [ ] Verified mobile number booking में स्वतः उपयोग हो; दोबारा भरने/बदलने की जरूरत न हो।
- [ ] Exactly six main categories: Electrician, Plumber, Painter, AC + Fridge Technician, Motor & Pump, Cooler।
- [ ] Category tiles, accessible labels, empty/error/loading states और admin-configurable category data।
- [ ] Profile, booking history, booking details, notifications, help/support, cancellation/complaint entry points।

## 4. Customer App — मौजूदा booking flow में आवश्यक सुधार
- [ ] मौजूदा booking steps का audit करके उसी flow में आवश्यक category → service/subcategory → skill level → helper option (जहाँ लागू) → duration/quantity → address → technician count → price summary → BOOK NOW विकल्प जोड़ें/सुधारें; flow को शून्य से न बनाएँ।
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
| 2026-11-21 | Founder clarification: booking flow preservation | Checklist sections 1–4 | मौजूदा booking system को दोबारा नहीं बनाना; केवल quotation/अनावश्यक विकल्प हटाने और आवश्यक category/rate आदि सुधारने का निर्देश दर्ज | Complete (checklist correction only) |
| 2026-11-21 | Detailed booking/quote dependency audit | Customer/Technician Flutter source, `create-booking.js`, quote migration | Existing booking, offer, cancellation, complaint, payment, map, work-status और quote dependencies दर्ज; backend contract के बिना lifecycle बदलाव रोकने का blocker दर्ज | Audit recorded; source changes pending |


## 2B. विस्तृत विकल्प-दर-विकल्प Frontend Audit (2026-11-21)

**Audit scope:** केवल approved mobile feature branch के Customer Flutter app, Technician Flutter app, shared core, दोनों pubspec और Android CI workflow का source inspection। इस चरण में कोई Dart source, backend, database या production file नहीं बदली गई।

### Customer App — रखना / हटाना / बदलना

| मौजूदा विकल्प / सुविधा | निर्णय | कारण / आगे का काम |
|---|---|---|
| OTP login और verified session | रखना | मौजूदा Supabase OTP flow उपयोगी है; पहली login पर नाम लेने और बाद में सीधे Home जाने का profile flow जोड़ना बाकी है। |
| Founder banner, Home, Refresh, Logout | रखना | ब्रांडिंग और सामान्य navigation; अनावश्यक बदलाव नहीं। |
| नई बुकिंग का मौजूदा form और `/api/create-booking` submission | रखना और उसी में विस्तार | form को शून्य से नहीं बनाना; category/subcategory/level/helper/duration/technician count/rate summary उसी flow में जोड़ने हैं। |
| मौजूदा Electrical-only service dropdown | बदलना | ठीक छह main categories और उनके service/task विकल्प चाहिए; अभी केवल आठ electrical service values हैं। |
| ग्राहक का नाम हर booking पर भरना | बदलना | पहली सफल login पर नाम profile में लें; बाद की bookings में profile से स्वतः लें। |
| OTP-verified मोबाइल नंबर का editable field | बदलना | verified account phone स्वतः लें; ग्राहक से वही नंबर दोबारा भरवाना नहीं। |
| State, district, PIN, full address | रखना और बढ़ाना | locality/place field जोड़ें; GPS optional रहे; अन्य शहर का work address स्वीकार हो। |
| Optional GPS location button | रखना | GPS न देने पर manual address से booking चलनी चाहिए। |
| Preferred date/time | रखना | existing booking preference के रूप में; multi-day duration/shift rules अलग जोड़ने हैं। |
| Work details / problem description | रखना | category-specific task और अतिरिक्त निर्देश के साथ। |
| Customer suggested amount | हटाना | नई fixed/admin rates व्यवस्था में ग्राहक की शुरुआती बोली/रकम अनावश्यक है; API contract के बाद payload से भी हटाने का प्रभाव जाँचना है। |
| Customer cash/online dropdown | बदलना | technician-ID आधारित completed-booking rotation लागू होना है; ग्राहक को ऐसा payment mode चुनने न दें जो assigned technician के लिए अनुमत न हो। Backend eligibility contract आवश्यक। |
| Quotation / Counter Offer / approve / reject / quote status / quote waiting copy | हटाना | उपयोगकर्ता ने quotation system नहीं रखना कहा है। Materials की अलग itemized सूची और customer approval बनी रहेगी; उसे quotation नाम या workflow न दें। |
| Existing booking history, status, assigned technician phone/call | रखना और status labels सुधारना | useful history/contact flow; नए lifecycle status API से map होंगे। |
| Booking cancellation | रखना | मौजूदा cancel RPC और eligibility नियम backend contract से verify हों। |
| Complaint / support | रखना | complaint flow उपयोगी है; category label में “कीमत / कोटेशन” को “बिल / अतिरिक्त सामान” जैसे सही शब्द से बदलना है। |
| Completed booking payment / Razorpay verification | रखना और बदलना | verified backend success ही success दिखाए; quote-approved gating हटाने का तरीका backend lifecycle/payment contract के बाद तय होगा। |
| Payment amount source | बदलना | quoted amount पर निर्भर display के स्थान पर approved labour + approved materials + travel/other valid charges का backend-confirmed bill चाहिए। |

### Technician App — रखना / हटाना / बदलना

| मौजूदा विकल्प / सुविधा | निर्णय | कारण / आगे का काम |
|---|---|---|
| Technician OTP login | रखना | मौजूदा flow उपयोगी; role/profile eligibility के साथ सुरक्षित रखना। |
| Profile link, approval/active status | रखना और बढ़ाना | अभी linked profile और approved/active indicator है; पूरा onboarding, KYC, skills, experience और rejection reason UI बाकी है। |
| New booking offers और accept/decline | रखना | मौजूदा offer inbox/response RPC महत्वपूर्ण है; dispatch rules नए backend contract से मिलाने हैं। |
| Offer match by PIN/district | बदलना | GPS-based 30 km, verified skill, online/availability और nearest-first dispatch चाहिए; केवल PIN/district match पर्याप्त नहीं। |
| Assigned booking list | रखना और विस्तार | मौजूदा booking details, address, date/time और work notes को preserve करें। |
| Customer map/directions और assigned customer phone | रखना | उपयोगी operational controls। |
| Inspection action | बदलना | इसे quote lifecycle से स्वतंत्र सुरक्षित inspection/work-start lifecycle में map करना होगा; backend owner contract के बिना button/state न बदलें। |
| Quote details, labour/material quote, counter offer, quote status | हटाना | Technician-facing quotation feature समाप्त; material itemization/approval अलग controlled feature होगा। |
| “ग्राहक को कोटेशन भेजें” और `_QuoteSubmissionDialog` | हटाना | user-facing quote submission नहीं चाहिए; `srk_submit_booking_quote` call भी तभी हटे जब backend नया flow उपलब्ध कराए। |
| Work start केवल `quote_approved` पर | बदलना, अभी blocked | वर्तमान RPC `srk_update_booking_work_status` quote approval पर निर्भर है; frontend-only बदलाव से काम शुरू नहीं होगा। |
| Work complete action | रखना और विस्तार | completion verification, customer confirmation, timer/day logs, rating और payment calculation से जोड़ना है। |
| Cash payment confirmation | रखना और बदलना | duplicate-safe backend confirmation, customer receipt, 85/15 ledger और cash-cycle rules से जोड़ना है। |
| Earnings, wallet summary | रखना और बढ़ाना | अभी केवल paid earnings और balance का सीमित view है; 85% share, pending/requested/paid payout, cash due, UTR/history चाहिए। |
| Online/offline toggle, live GPS status, 30 km radius | जोड़ना | मौजूदा audited dashboard में उपलब्ध नहीं दिखे; backend contract और permissions आवश्यक। |
| Work timer, pause/resume, overtime, day-wise schedule | जोड़ना | मौजूदा audited screen में नहीं दिखे; authoritative timer API के बिना local-only timer न बनाएं। |
| Customer/Technician ratings | जोड़ना | दोनों तरफ rating flow आवश्यक। |

### Shared core, dependencies और build workflow

- Shared core `packages/srk_mobile_core/lib/srk_mobile_core.dart`: OTP UI, Supabase initialization और founder artwork उपलब्ध; Customer/Technician dashboards shared core में नहीं हैं। `SrkAppRole.admin` और generic Admin login code मौजूद है, पर वर्तमान deliverable में Admin Android app नहीं बनाना है। इस unused role/code को हटाने से पहले package consumers की जाँच करें।
- Customer dependencies: Flutter, shared core, `url_launcher`, `geolocator`, `razorpay_flutter`; Technician dependencies: Flutter, shared core, `url_launcher`। कोई नई dependency इस audit में नहीं जोड़ी गई।
- CI workflow Customer और Technician debug APK बनाता है; Android scaffolding हर run पर temporary `flutter create` से बनता है। Permanent Android folders, signed Release AAB और Play Store signing अभी बाकी हैं।
- CI manifest permission injection की `sed` command और workflow execution अभी वास्तविक runner पर verify नहीं हुए; workflow run/analyze/build को evidence मिलने तक **Not verified** रखें।
- दोनों app source में अभी onboarding, complete category catalog, technician GPS/online controls, job timer, multi-day decision flow और payout request screens का पूरा implementation नहीं दिखता। इन्हें “मौजूद” न मानें।

### सुरक्षित बदलाव का क्रम

1. Backend owner/GPT-2 से quote-free lifecycle, materials approval, final bill/payment eligibility और status RPC contract लें।
2. Customer और Technician source में quotation UI/API dependency हटाने का contract-backed change करें; पुराने bookings के legacy quote data को read-only compatibility दें।
3. Existing customer booking form को छह categories और लागू booking fields से बढ़ाएँ; old create-booking endpoint payload compatibility पहले जाँचें।
4. Technician offer/assigned job screens को preserve करते हुए verified GPS/availability, work timer, daily log, completion और payout views क्रमशः जोड़ें।
5. प्रत्येक source change के बाद `dart format`, `dart analyze`, relevant tests और CI evidence दर्ज करें।
6. कोई backend migration, production change, Main merge या deployment इस mobile frontend authorization के अंतर्गत नहीं है।

**स्थिति:** विकल्प audit recorded; कोई Dart source change नहीं किया गया। Quote lifecycle, payment mode eligibility और material approval अभी backend contract पर Blocked हैं।

## 2C. Backend lifecycle dependency audit और आवश्यक API contract (2026-11-21)

**अतिरिक्त source evidence (उसी approved mobile branch से):**

- [x] Root `create-booking.js` (`346e4dcefb3aa27d64cc917039a81ad986cf7798`) booking को authenticated/verified customer phone के साथ insert करता है; इसमें rate-limit check, server-side session verification और booking insert के बाद database trigger से offer queue बनने की अपेक्षा है।
- [x] इस endpoint में `quoted_amount` अभी optional है, पर वह `service_bookings` insert payload में भेजा जाता है। इसलिए Flutter से field छिपा देना और API payload/DB compatibility को बिना contract जाँचे बदल देना एक ही बात नहीं है।
- [x] Endpoint `customer_suggested_amount` भी स्वीकार करता है और booking record में लिखता है। इसे Customer UI से हटाने के बाद server/API/legacy data पर असर अलग से तय होना चाहिए; इस frontend scope में backend file नहीं बदलेगी।
- [x] Endpoint की आवश्यक fields में नाम, 10 अंकों का verified phone, state, district, 6 अंकों का PIN, address, service, preferred date/time शामिल हैं। GPS latitude/longitude दोनों साथ हों या दोनों null हों। नई locality/category/helper/duration fields के लिए backend contract चाहिए।
- [x] Booking insert का प्रारंभिक status `new`, payment status `unpaid` है; offer queue database trigger बनाता है। Endpoint response में booking ID, offers count, match level और message आते हैं।
- [x] 2026-11-09 migration (`014699d3190e45aacde4022ac7e7fa9ca4fec006`) में `srk_update_booking_work_status` केवल `inspection`, `in_progress`, `completed` स्वीकार करता है। `assigned → inspection` अनुमत है; `inspection → in_progress` नहीं। `in_progress` केवल `quote_approved` + `quote_status='approved'` से शुरू हो सकता है।
- [x] उसी migration में `service_bookings` status constraint quote-specific states को शामिल करता है और assignment-required constraint post-assignment states पर लागू है। इसीलिए UI labels हटाना lifecycle transition को स्वतः quote-free नहीं बनाता।
- [x] उसी migration में `srk_get_my_offer_details()` quote fields (`quoted_amount`, `service_charge`, `materials_amount`, `quote_status`, `quote_note`) return करता है। Technician app के offer/assigned details के लिए नया response contract या backward-compatible mapping जरूरी है।
- [ ] Current approved branch की सभी migrations/functions में Technician app द्वारा उपयोग किए जा रहे `srk_get_my_offer_price_details`, `srk_get_my_assigned_booking_quote_details`, cash confirmation और earnings/wallet RPC की exact definitions व authorization rules का पूर्ण inventory अभी बाकी है। GitHub code search के कुछ results default branch के थे; उन्हें इस branch का प्रमाण नहीं माना जाएगा।
- [ ] Backend owner/GPT-2 से नीचे दिया गया contract लिखित रूप में प्राप्त करें; तब तक quote-dependent start/payment UI change **Blocked** रहेगा।

### Backend owner/GPT-2 को माँगा जाने वाला contract

1. **Booking lifecycle:** assigned job को quotation के बिना inspect/start/pause/resume/complete करने के exact allowed states, RPC/API names, parameters, return JSON, authorization, duplicate/retry behavior और error codes।
2. **Legacy compatibility:** पहले से मौजूद quote bookings किस तरह read-only रहेंगी; पुराने records को नए lifecycle में migrate/convert करना है या नहीं, यह backend owner स्पष्ट करे। Frontend स्वयं पुराने records/statuses rewrite नहीं करेगा।
3. **Materials:** technician द्वारा parts/material line items जोड़ने का API, हर item का name/quantity/unit price/tax/total, customer approval/rejection/partial change flow, approval timestamp और final bill calculation। इसे quotation/counter-offer workflow न कहा जाए।
4. **Final amount/payment:** backend-authoritative labour/rate snapshot + customer-approved materials + valid travel/other charges से final total; Customer app को payable amount और payment status किस API/RPC से मिलेगा।
5. **Cash/online eligibility:** technician-ID के verified completed-booking count पर 1st/2nd cash-or-online, 3rd online-only और फिर repeat होने वाले cycle का server-authoritative response; client-side counter नहीं।
6. **Razorpay:** order create, payment verify, webhook-confirmed status, failure/pending/refund response schema और idempotency key; केवल verified server result पर success UI।
7. **Technician money:** cash collection confirmation, 85% technician / 15% company ledger, cash due, online settlement/payout request, payout status और UTR के RPC/API contracts। मौजूदा wallet को वास्तविक bank payout न समझें।
8. **Dispatch/booking extensions:** six-category catalog, rate snapshots, technician skill/online/GPS/30 km matching, multi-day/helper/technician count और locality fields के exact accepted payload/response fields।
9. **Ownership/security:** प्रत्येक endpoint की customer/technician ownership checks, approved-active technician rules, RLS/RPC grants, rate limits और audit trail।

**इस चरण का निष्कर्ष:** Existing booking create/offer flow उपयोगी है और सुरक्षित रखना है। Quote UI को बाद में हटाया जा सकता है, लेकिन work-start और final payment का रास्ता backend contract के बिना सुरक्षित रूप से बदलना संभव नहीं। इस audit में कोई app Dart source, backend function, migration, database या production setting नहीं बदली गई।
## 2D. विस्तृत Migration / RPC / Payment audit (2026-11-21)

### Confirmed current backend contracts
- [x] Approved mobile branch में `supabase/migrations` के 21 SQL migrations सूचीबद्ध किए। उनमें booking security, offer/map, commission, wallet ledger, Razorpay Route ledger, quote workflow, contact visibility, cancellation और cash payment से जुड़े migrations की जाँच की।
- [x] `srk_get_my_offer_details()` टेक्नीशियन को offer + booking detail देता है; फोन/पता/GPS केवल assigned electrician के लिए return करने की शर्त है। इसे preserve करना है; नया quote-free response contract इसी privacy boundary को बनाए रखे।
- [x] `srk_get_my_offer_price_details()` quote-संबंधी fields लौटाता है। इसे नए customer-suggested-amount UI से अलग करना होगा; UI हटाने पर backend function को अभी delete नहीं करना है क्योंकि legacy records/other clients इसकी dependency हो सकती है।
- [x] `srk_get_my_assigned_booking_quote_details()` की अंतिम migration definition में payment method/status, GPS और address भी हैं; यह assigned approved+active electrician की bookings ही देता है। नाम quote-specific है, पर app के assigned-job details का मौजूदा data source भी यही है। Backend replacement बिना इसके UI टूटेगा।
- [x] `srk_customer_cancel_my_booking(p_booking_id)` केवल ग्राहक की अपनी unassigned `new`/`confirmed` booking cancel करता है। Customer cancel UI को preserve करें; assigned booking cancel की सुविधा अभी backend में नहीं है।
- [x] `srk_customer_get_my_booking_contacts()` और `srk_electrician_get_my_assigned_booking_contacts()` owner-linked contacts लौटाते हैं। कॉल बटन और phone visibility preserve करें।
- [x] `srk_electrician_confirm_cash_payment(p_booking_id)` केवल assigned approved+active electrician, `completed` work, approved quote और cash payment पर paid mark करता है; duplicate same booking paid होने पर idempotent success देता है। Quote-free lifecycle contract में quote approval check को backend owner द्वारा स्पष्ट रूप से replace करना होगा; frontend अकेले नहीं।
- [x] `srk_get_my_earnings()` केवल completed+paid rows पर earning दिखाता है; electrician ownership check मौजूद है। `srk_get_my_wallet_summary()` electrician payouts disabled बताता है और बैंक पेआउट को Route linked-account onboarding/live approval पर निर्भर बताता है।

### Commission और payout का महत्वपूर्ण अंतर
- [x] `srk_calculate_booking_commission()` की मौजूदा गणना `service_charge * commission_rate / 100` पर है; `materials_amount` को commission base में शामिल नहीं करती। `srk_get_my_earnings()` electrician earning को `amount_paid - commission_amount` मानता है।
- [x] Razorpay Route transfer ledger (`srk_route_transfers`) reconciliation record है; migration comment साफ कहता है कि database write अपने-आप money movement trigger नहीं करता।
 - [x] Owner clarified: 15% company commission applies only to service_charge/labour; Technician gets 85% of service_charge/labour; materials/parts are excluded (0% platform fee).
- [ ] मौजूदा wallet summary को payout request, bank transfer, UTR या paid-out history का प्रमाण न मानें। ऐसे वास्तविक payout contracts/flows इस audit में नहीं मिले।

### Razorpay payment contract (root server functions)
- [x] `create-order.js` customer session + booking ownership/verified phone check करता है; केवल `payment_method=online`, `status=completed`, `quote_status=approved` booking payable है। Amount `service_charge + materials_amount` से calculate होकर `quoted_amount` से match कराया जाता है। Per-booking order lock और pending order reuse है।
- [x] `verify-payment.js` signature HMAC verify करता है, Razorpay payment को API से fetch कर `captured`, INR, matching order और exact amount जाँचता है; payment update duplicate-safe है।
- [x] `razorpay-webhook.js` webhook signature verify करता है और captured payment/refund को reconcile करता है; paid/refund conflicts और amount mismatch अलग संभाले जाते हैं।
- [x] `create-refund.js` Admin-only refund request है; idempotency key और webhook reconciliation का उपयोग करता है। इसे Customer app का direct refund action नहीं समझें।
- [ ] इन payment functions में quote approval और quote amount checks भी मौजूद हैं। Quote-free booking lifecycle आने पर backend owner को create-order, verify-payment और webhook के तीनों paths एक साथ update/compatibility contract देना होगा।

### App-to-backend dependency map
- Customer: `service_bookings` own-row read; `srk_customer_get_my_booking_contacts`; `srk_customer_list_booking_complaints`; `srk_customer_create_booking_complaint`; `srk_customer_cancel_my_booking`; वर्तमान में `srk_customer_respond_booking_quote` (हटाने हेतु backend lifecycle replacement जरूरी); `/api/create-booking`; `/api/create-order`; `/api/verify-payment`।
- Technician: `electrician_profiles`, `job_offers`; `srk_get_my_offer_details`; `srk_get_my_offer_price_details`; `srk_get_my_assigned_booking_quote_details`; `srk_electrician_get_my_assigned_booking_contacts`; `srk_get_my_earnings`; `srk_get_my_wallet_summary`; `srk_respond_to_offer`; `srk_update_booking_work_status`; `srk_submit_booking_quote` (हटाने हेतु backend lifecycle replacement जरूरी); `srk_electrician_confirm_cash_payment`।

**Audit decision:** Booking create, offer accept/decline, assigned jobs, location/map, contacts, cancellation, complaints, verified Razorpay payment and existing earnings history को preserve करना है। केवल quote/counter-offer UI हटेगा—लेकिन पुराने quote records read-only compatibility में रह सकते हैं। New material item approval को quote workflow से अलग backend contract चाहिए। अभी कोई production/backend source बदला नहीं गया।

## 2E. मुख्य Requirements बनाम छह service categories की जाँच (2026-11-21)

**जाँचा गया source of truth:** `docs/SRK_ELECTRONIC_MASTER_REQUIREMENTS_HI.md`, branch `feature/platform-fee-cash-online-cycle`, blob SHA `dcce53e2600e46251b5fe89e7a760de2809d6017` (4,307 lines).

- [x] मुख्य दस्तावेज़ के §1 में customer booking के लिए electrician category, 1–8 घंटे की अवधि, category-specific matching और customer-selected payment method दर्ज है।
- [x] §2 में केवल चार **Electrician skill/rate tiers** दर्ज हैं: Electrical Assistant ₹899/8h, Skilled Electrician ₹1,199/8h, Expert Electrician ₹1,599/8h और Premium Electrical Specialist ₹1,999/8h। ये electrician की skill/rate tiers हैं; इन्हें चार अलग top-level service categories नहीं बनाना है।
- [x] §2 के scope में AC electrical connections, AC service/repair, cooler repair और fridge inspection/repair का कुछ काम Premium Electrical Specialist के दायरे में है। Refrigerant/gas work और sealed-system fridge repair केवल उपयुक्त trained specialist के लिए सीमित है। इस दस्तावेज़ में AC Installation, AC Repair और Fridge के अलग-अलग customer booking subflows परिभाषित नहीं हैं।
- [x] पूरे 4,307-line master requirements document में Plumber/प्लंबर/प्लम्बर, Painter/पेंटर, AC Installation, AC Repair या छह top-level service categories का स्पष्ट catalog नहीं मिला।
- [x] इसलिए अभी छह-category catalog, plumber/painter rates, AC/fridge subcategory rates या उनके booking fields को अनुमान से बनाना निषिद्ध है। दूसरे branch या पुरानी बातचीत के अधूरे संकेत को source-of-truth का विकल्प नहीं मानना है।
- [x] Existing Customer booking form, Technician offer/assigned-booking flow और booking lifecycle को preserve करना है। केवल verified requirement के अनुसार विकल्प हटाने/छाँटने हैं; booking system को rebuild नहीं करना।
- [ ] छह top-level categories और हर category के exact subcategories/rates/eligibility की owner-approved final list को master requirements में दर्ज या अलग signed-off source के रूप में link करना बाकी है।
- [ ] उस सूची के बाद हर category के customer-visible options, technician skill/onboarding options, rate/duration display और backend payload mapping का side-by-side matrix पूरा करना बाकी है।

**इस audit का निर्णय:** अभी app source में category dropdown/catalog बदलना सुरक्षित नहीं, क्योंकि authoritative master document छह-category list और plumber/painter/AC-fridge standalone flows को परिभाषित नहीं करता। यह केवल requirements gap है—इससे user द्वारा बातचीत में स्वीकृत किसी category को अस्वीकार नहीं किया जा रहा। छह-category सूची स्पष्ट होते ही उसी के आधार पर मौजूदा booking flow में न्यूनतम बदलाव किए जाएँगे। इस चरण में कोई Dart source, backend API, SQL migration, database या production setting नहीं बदली गई।


### 2E-1. बातचीत में मालिक द्वारा बताई गई छह मुख्य categories — recovered prior decision

मुख्य requirements document में catalog अधूरा है, लेकिन मालिक की 2026-11-21 की बातचीत से छह top-level categories स्पष्ट रूप से recover हुई हैं। इन्हें चार Electrician skill tiers से अलग रखना है:

1. **Electrician**
2. **Plumber**
3. **Painter**
4. **AC + Fridge Technician** — AC और Fridge एक ही top-level category के अंदर।
5. **Motor & Pump**
6. **Cooler**

**पहले से स्पष्ट booking options**
- AC + Fridge Technician चुनने पर पहले **AC** और **Fridge** विकल्प दिखेंगे।
- **AC** चुनने पर **AC Installation** और **AC Repair** दिखेंगे।
- **Fridge** चुनने पर Fridge का booking flow खुलेगा; AC Installation/Repair विकल्प Fridge के अंदर नहीं दिखेंगे।
- Helper विकल्प उसी संबंधित booking flow के अंदर रहेगा; इसे अलग top-level category या अलग booking entry नहीं बनाना है।
- AC Technician का user-approved rate ₹437/hour है; AC helper rate अभी अलग से confirm नहीं। ₹250/₹400 वाला पुराना assistant-derived उल्लेख लागू न करें। सभी labour rates से materials/parts अलग रहेंगे और customer approval के बाद ही जोड़े जाएँगे।
- Admin को future rate/commission configuration की आवश्यकता बताई गई है; पुराने bookings में उस समय लागू rate snapshot सुरक्षित रहना चाहिए।

**Rates/catalog gaps जिन्हें अनुमान से नहीं भरना है**
- Electrician के लिए बाद की owner-approved दरें §2E-2 में हैं; Master Requirements के पुराने चार tiers को नए approved price catalog पर प्राथमिकता न दें। इन्हें Electrician category के अंदर skill/rate selection के रूप में रखें, अलग top-level categories न बनाएं।
- Plumber, Painter, Motor & Pump और Cooler की approved दरें §2E-2 में दर्ज हैं। Fridge rate/helper और AC helper rate अभी verified user approval के बिना final न दिखाएँ।
- Fridge की helper applicability/rate अभी confirm नहीं; Motor & Pump, Cooler, Plumber और Painter के approved options/rates §2E-2 में दर्ज हैं।
- AC और Fridge के सभी approved sub-options §2E-2 में दिए हैं; Fridge flow में AC options नहीं दिखाने हैं।

**Implementation guardrail:** छह top-level category cards/list और ऊपर दिए गए AC/Fridge navigation को frontend में जोड़ा जा सकता है; लेकिन जिन categories के rates या sub-options final नहीं हैं, उनके लिए मनगढ़ंत rate/subcategory नहीं दिखानी है। Existing booking form/lifecycle को preserve करके category-specific fields उसी flow में न्यूनतम रूप से जोड़े जाएँ। Master Requirements document को भी बाद में इस recovered approved catalog से reconcile करना होगा।


## 2F. सुरक्षित Customer/Technician UI cleanup — लागू (2026-11-21)

- [x] Customer booking form से optional **customer suggested amount** input हटाया; request payload में `customer_suggested_amount` भेजना बंद किया। Existing `/api/create-booking` endpoint इस field को optional स्वीकार करता है, इसलिए required payload contract नहीं बदला। पुराने records/backend columns untouched हैं।
- [x] Customer booking history से legacy customer-suggested-amount display हटाया; booking list query से केवल इसी UI के लिए लिया जा रहा field हटाया।
- [x] Technician app के offer price panel से legacy customer-suggested-amount display हटाया। Existing quote/material information और booking lifecycle को अभी नहीं छेड़ा, क्योंकि work-start/payment RPCs quote approval पर निर्भर हैं।
- [x] Customer booking form में OTP-verified account phone पहले से auto-fill होता है; अब field read-only है ताकि user अलग/unverified phone number बदलकर न भेजे। Name field, address, GPS, date/time, service details और existing booking submission सुरक्षित रखे।
- [x] Source re-fetch verification: Customer SHA `fb919b0e2eb17c791d79875933cda4bbdab9b646`; Technician SHA `502657a78a42777fb21b38ab5a554554c17b905c`. Re-fetch में customer suggested amount field/display absent, technician suggested-price display absent, verified phone read-only और existing booking form मौजूद मिले।
- [x] Customer booking form से बचा हुआ stale संदेश हटाया जिसमें suggested price, quote/counter-offer और quote approval लिखा था; उसकी जगह neutral fixed-rate/material-approval guidance रखी। Payment helper text से भी quote approval wording हटाई। Re-fetch Customer SHA `d3c00aadf003732ddb3bded9b72eaffeda98d863` पर verified: stale quote/suggested-price copy absent; existing booking form intact।
- [ ] Flutter format/analyze/build/Android device tests अभी नहीं चले; source changes को compile/test evidence मिलने तक verified build न मानें।
- [ ] Quote/counter-offer UI removal अभी **Blocked** है: existing work-start, cash confirmation और Razorpay order/verify/webhook paths quote approval/amount checks पर निर्भर हैं। Backend lifecycle replacement contract मिलने के बाद ही दोनों apps से quote UI/actions हटाएँ।
- [ ] Six-category catalog को मौजूदा form में जोड़ने से पहले backend category-specific dispatch/payload support verify/contract करना बाकी है। छह categories और AC/helper flow की approved details §2E-1 में दर्ज हैं; अधूरे rates/subcategories अनुमान से नहीं भरेंगे।

**इस चरण में:** केवल Customer/Technician Flutter source और इसी feature branch की checklist बदली गई। Existing booking flow rebuild नहीं हुआ; backend, database, migrations, production settings, Admin web panel और main branch untouched हैं।


### 2E-2. पूर्व बातचीत से पुनः सत्यापित पूर्ण catalog, subcategories और दरें

यह अनुभाग §2E-1 की अधूरी/गलत दर-टिप्पणियों को **सुधारता और supersede करता है**। रकम केवल वहीं final लिखी गई है जहाँ user-approved context उपलब्ध है।

**A. छह मुख्य categories और Customer booking navigation**
1. **Electrician** — अंदर Basic, Expert Residential, Factory/Large Project और Master skill/rate level चुनें; helper उपलब्धता/rate level के अनुसार दिखे।
2. **Plumber** — अंदर Basic, Expert और Master/Industrial level; helper optional।
3. **Painter** — अंदर Basic, Expert और Master/Commercial level; helper Basic में नहीं, Expert/Master में optional।
4. **AC + Fridge Technician** — पहले AC या Fridge चुनें।
   - AC: AC Repair, Installation, Uninstallation, Servicing, Gas Charging, Leakage Check, Compressor, PCB।
   - Fridge: Refrigerator Repair, Cooling Problem, Compressor, Gas/Leakage, PCB और Other Repair।
   - AC और Fridge की skill verification अलग-अलग रहे; गैस/refrigerant और sealed-system work केवल verified trained specialist को assign हो।
5. **Motor & Pump** — Domestic Tullu Pump, Pump Repair, Submersible Pump, Winding, Capacitor, Starter, Installation/Removal।
6. **Cooler** — Cooler Repair। Motor winding का काम Cooler की ₹500 fixed labour में शामिल नहीं; वह Motor & Pump HP rate पर अलग booking/line item होगा।

**B. User-approved labour rates**
- **Electrician**
  - Basic: ₹100/hour; Basic helper rate अभी final नहीं।
  - Expert Residential: ₹1,000/8 hours; helper सहित ₹1,500/8 hours (helper add-on ₹62.50/hour)।
  - Factory/Large Project: ₹400/hour; helper सहित ₹550/hour (helper add-on ₹150/hour)।
  - Master: ₹700/hour; helper सहित ₹950/hour (helper add-on ₹250/hour)।
- **Plumber** (materials, pipe और fittings अलग)
  - Basic ₹100/hour; optional helper ₹50/hour; combined ₹150/hour।
  - Expert ₹150/hour; optional helper ₹75/hour; combined ₹225/hour।
  - Master/Industrial ₹225/hour; optional helper ₹100/hour; combined ₹325/hour।
- **Painter**
  - Basic ₹700/8 hours (₹87.50/hour); Basic helper नहीं।
  - Expert ₹900/8 hours (₹112.50/hour); helper ₹75/hour।
  - Master/Commercial ₹1,200/8 hours (₹150/hour); helper ₹100/hour।
- **AC Technician:** ₹437/hour approved. AC helper rate अलग से final/confirmed नहीं; ₹150/hour का पूर्व उल्लेख assistant summary में था, इसलिए इसे लागू न करें जब तक owner approval स्पष्ट न हो।
- **Fridge:** ₹150/hour और helper ₹75/hour का पूर्व उल्लेख मिला, लेकिन यह वर्तमान retrieved evidence में user-approved rate के रूप में पुष्ट नहीं; इसे final price के रूप में न दिखाएँ।
- **Motor & Pump winding:** fixed labour by HP; hourly/overtime नहीं:
  - 0.5 HP ₹500; 1 HP ₹600; 1.5 HP ₹700; 2 HP ₹800; 3 HP ₹900;
  - 5 HP ₹1,000; 7.5 HP ₹1,100; 10 HP ₹1,200; 15 HP ₹1,300; 20 HP ₹1,400.
  - Above 20 HP rate unconfirmed; अनुमान से price न दिखाएँ।
- **Cooler Repair:** ₹500 fixed labour per cooler; parts/materials separate with customer approval. Cooler motor winding अलग Motor & Pump HP rate से।
- **Materials/parts:** labour rates में शामिल नहीं; अलग itemization और customer approval के बाद ही जोड़ें।

**C. Duration and booking option placement**
- Hourly/day-based work में चुने गए skill tier और helper के आधार पर duration/total दिखे; approved rules में booking duration 1 hour से 50 days तक दर्ज है। HP winding और fixed ₹500 Cooler Repair पर hourly multiplication/overtime लागू न करें।
- Helper अलग top-level service नहीं है; वह relevant service booking के अंदर optional team add-on है। जिस level/category में helper rate confirm नहीं, वहाँ helper price/total अनुमान से न दिखाएँ।
- Technician app में वही service skills/categories दिखें जिनकी उस Technician की profile/KYC/skill verification हुई है; Customer की पूरी service catalog list हर Technician को उपलब्ध न कराएँ। AC और Fridge skill eligibility अलग जाँची जाए।
- Customer booking form में customer-suggested price नहीं होना चाहिए; rate system निर्धारित करेगा। Quote/counter-offer/approval/quote waiting screens/actions नए Customer और Technician apps में नहीं होने चाहिए। Material/parts का अलग customer approval quote नहीं है—यह अलग line-item approval है।
- Customer से cash/online चुनवाने के बजाय payment policy server-side तय होनी चाहिए; मौजूदा create-booking API अभी customer-supplied payment_method स्वीकार करता है और default cash रखता है। Backend owner से payment-method assignment contract मिलने तक इस dropdown/payload को बिना coordinated backend change के न हटाएँ/न बदलें।

**D. अभी बाकी contract/validation**
- [ ] Customer app का current single Electrical-only dropdown ऊपर के छह category navigation में बदलना है, पर मौजूदा form/booking submit flow rebuild नहीं करना।
- [ ] Technician onboarding/profile में category + subcategory skill verification और approved rate/helper capability का source-of-truth backend से चाहिए; वर्तमान Android profile केवल display_name, state, district, PIN, active और verification_status पढ़ता है।
- [ ] Existing `create-booking.js` अभी `service_type` string को स्वीकार करता है; category/subcategory/helper/duration/HP structured fields और dispatch eligibility का contract backend owner से चाहिए।
- [ ] Payment rotation rule का backend contract, booking-count scope और API-generated payment_method अभी verified नहीं; current Customer dropdown को तब तक न हटाएँ जब तक backend default/response व्यवहार तय न हो।
- [ ] Quote-free lifecycle, material approval, payment order/verification/webhook और cash confirmation के नए RPC/API contracts backend owner से चाहिए; उसके बाद ही quote screens/actions पूर्ण रूप से हटाएँ।


## 2G. Category-wise dispatch / Technician skill contract audit (2026-11-21)

### Customer booking form का वर्तमान वास्तविक रूप
- [x] Customer app में अभी एक ही Electrical-only dropdown है: Electrical Wiring, Fan Installation / Repair, Switch & Socket Repair, Light Installation, MCB / Distribution Board, Inverter / Battery, Appliance Electrical Repair, Other Electrical Work।
- [x] Booking payload केवल `service_type` string भेजता है। Category ID, subcategory ID, skill tier, helper flag/count, duration/hours/days, HP, fixed-vs-hourly pricing या rate snapshot के अलग structured fields अभी मौजूद नहीं।
- [x] Existing form की location, date/time, work details और booking submit flow usable है; इसे replace/rebuild नहीं करना है।

### Technician profile / onboarding का वर्तमान वास्तविक रूप
- [x] Android Technician app अभी `electrician_profiles` से केवल `id, display_name, state, district, pincode, active, verification_status` पढ़ता है। `skills` field fetch/display/eligibility check नहीं करता।
- [x] Android Technician app में अभी category/skill onboarding या KYC form नहीं है; logged-in linked profile का status/dashboard है।
- [x] Backend `apply-electrician.js` आवेदन में `skills` को एक free-text string (max 300 chars) के रूप में लेता है; application को approved profile बनाते समय migration इसे comma-separated `text[]` में बदलती है। यह six-category IDs, verified subcategory IDs या skill-tier capability contract नहीं है।
- [x] Base schema में `electrician_profiles.skills text[]` मौजूद है, लेकिन six-category taxonomy, per-skill verification status, helper capability, rate tier, experience proof, service radius/30km eligibility का normalized model इस inspected contract में नहीं मिला।
- [x] Technician offer UI `service_type` को plain title के रूप में दिखाता है; offer filtering या eligibility check app-side नहीं है।

### Booking-to-Technician matching audit
- [x] `create-booking.js` `service_type` को required plain string के रूप में save करता है; function trigger-created offers को केवल read करता है, duplicate offers नहीं बनाता।
- [x] Existing implementation notes `broadcast_new_booking` के लिए PIN-code match और fallback में same state/district का उल्लेख करते हैं।
- [x] Approved mobile branch के पूरे `supabase/migrations` folder में 21 migration files हैं; इनमें `broadcast_new_booking` trigger/function की actual definition मौजूद नहीं मिली। इसलिए matching query में `skills`/service type filter है या नहीं, इसकी SQL-level पुष्टि इस branch से नहीं हो सकी।
- [x] Current verified evidence के आधार पर यह कहना सुरक्षित नहीं कि six-category service booking केवल उसी category के verified Technician को dispatch होगी। वर्तमान app/booking contract में ऐसी guarantee नहीं दिखती।
- [x] `create-booking.js` response केवल total offers और पहला `match_level` लौटाता है; category-eligible Technician count या no-qualified-technician state का अलग contract नहीं है।

### UI placement decision — क्या कहाँ दिखना चाहिए
- **Customer home:** छह top-level categories केवल एक बार दिखें; Electrician के पुराने आठ task-options को home पर अलग categories न बनाएं।
- **Customer booking:** चुनी category के बाद उसी की subcategory/options दिखें। AC + Fridge पर पहले AC/Fridge selector; AC के अंदर AC tasks; Fridge के अंदर केवल fridge tasks। Helper relevant booking के अंदर optional add-on रहे, अलग home tile नहीं।
- **Electrician skill tiers:** Basic / Expert Residential / Factory-Large Project / Master जैसे rate/skill level केवल Electrician booking के अंदर आएँ; top-level category cards नहीं। अन्य trades के Basic/Expert/Master tiers उनकी अपनी category के अंदर हों।
- **Customer price input:** customer suggested amount नहीं; rate app/backend-calculated/approved rate card से आए।
- **Materials/parts:** quote/counter-offer screen नहीं; work order में अलग itemized lines + customer approval।
- **Payment method:** अभी Customer dropdown को हटाना सुरक्षित नहीं; API `payment_method` स्वीकार करती है और trigger/booking records में method इस्तेमाल होता है। Rotation/server assignment contract बनने के बाद ही UI से हटे।
- **Technician app:** सभी छह categories को हर Technician को न दिखाएँ। केवल उस व्यक्ति की approved/active profile पर दर्ज और Admin-verified category/subcategory/skill-tier वाले काम की offer दिखे। Unverified skill पर offer, price edit, work-start enable न हो।
- **Helper:** केवल उस booking/skill level में दिखे जहाँ helper allowed और rate confirmed है; helper खुद standalone Technician service/category नहीं।
- **HP/fixed jobs:** Motor & Pump HP winding में HP selection और fixed labour price दिखे; hourly duration/overtime controls न दिखें। Cooler ₹500 fixed repair में HP field न दिखे; winding अलग Motor & Pump flow/line item रहे।

### Backend owner से अनिवार्य API/RPC contract (frontend implementation से पहले)
1. Canonical category/subcategory IDs और immutable catalog/rate version; localized display labels केवल presentation हों।
2. Technician profile पर Admin-verified category/subcategory/skill tier, helper capability, KYC/approval status और active/availability flags।
3. Booking payload में category_id, subcategory_id, skill_tier_id (जहाँ लागू), helper_count/flag, duration/unit, HP (जहाँ लागू), address/GPS, preferred schedule और selected catalog/rate version।
4. Server-side dispatch केवल approved + active + available + matching skill वाले Technician को करे; पहले requested geo/PIN policy, फिर documented fallback; skill mismatch पर offer कभी न बने।
5. No qualified Technician, no coverage, paused/offline, offer expiry, re-dispatch, accept race, duplicate offer और booking cancellation के explicit response/status contracts।
6. Backend authoritative labour calculation और booking-time rate snapshot; materials/parts separate itemization + customer approval; client से भेजी amount पर भरोसा नहीं।
7. Customer payment method selection/rotation rule का server-side contract, ताकि UI dropdown हटाने के बाद API सुरक्षित रूप से सही method assign करे।
8. Quote-free lifecycle + material approval + cash confirmation + Razorpay order/verify/webhook replacement contracts, सभी एक साथ और duplicate-safe।

**Decision / रोक:** अभी six-category UI को production-like booking submit से जोड़ना सुरक्षित नहीं, क्योंकि service-to-skill dispatch guarantee प्रमाणित नहीं। इस चरण में कोई backend/SQL/production बदलाव नहीं किया गया। अगला frontend कदम केवल non-submitting catalog prototype या isolated UI component हो सकता है; live booking payload/dispatch तभी बदले जब backend owner का versioned contract उपलब्ध हो। Existing booking system और वर्तमान booking submission तब तक intact रहेंगे।


## 2H. Isolated six-category catalogue model (2026-11-21)

- [x] Added `packages/srk_mobile_core/lib/srk_service_catalog.dart` as a reusable, immutable Dart catalogue model.
- [x] Six top-level categories and approved order recorded: Electrician, Plumber, Painter, AC + Fridge, Motor & Pump, Cooler.
- [x] Included confirmed task lists and owner-approved rate entries only. Fridge rate and Motor & Pump winding above 20 HP remain explicitly unpriced pending owner confirmation.
- [x] AC + Fridge model keeps AC and Fridge as separate second-level choices; AC task list is attached only to AC.
- [x] Cooler fixed ₹500 labour and separate-parts note are recorded; winding is kept in Motor & Pump.
- [x] This is data/model preparation only: it is not imported into Customer/Technician screens, does not replace the existing booking form, does not change `service_type` payload, does not submit bookings, and does not dispatch work.
- [ ] Before UI integration: backend owner must publish the versioned category/skill/dispatch/rate contract in section 2G; confirm all pending rates; then add widget/unit tests and Flutter analyze/build.
- [ ] Before any live category booking: end-to-end test every category/subcategory against an approved matching Technician account and verify no cross-category offer.

**Validation boundary:** GitHub file creation was confirmed. Flutter SDK analysis/build and runtime rendering have not yet been run; this file must not be described as build-tested.


### Catalogue model structure refinement
- [x] Service task options और Technician skill/rate tiers को अलग-अलग fields में रखा गया है: `options` बनाम `skillLevels`। इससे Basic/Expert/Master को गलती से अलग service category या repair task नहीं दिखाया जाएगा।
- [x] Painter Helper rates में प्रति घंटा इकाई स्पष्ट की गई।
- [x] Source re-fetch में छह top-level category names, balanced braces/parentheses और intended fields की जाँच हुई। यह textual inspection है, Dart analyzer या build का विकल्प नहीं।


## 2H. Customer six-category picker prototype (2026-11-21)

- [x] Added isolated Flutter widget at `apps/customer_app/lib/service_category_picker.dart`.
- [x] Contains six top-level categories in the approved order: Electrician, Plumber, Painter, AC + Fridge, Motor & Pump, Cooler.
- [x] AC + Fridge first requires AC or Fridge selection, then shows only the matching task list.
- [x] Electrician and Motor & Pump have their current catalogue sub-options; Cooler contains Cooler Repair only.
- [x] Plumber and Painter currently remain category-level selections because detailed subcategory lists were not confirmed in the available requirements.
- [x] Widget emits catalogue IDs and labels through a callback only. It does not submit bookings, call APIs/Supabase, calculate prices, or change the existing booking form.
- [ ] Integrate into Customer home/booking only after backend confirms canonical category IDs, rate version and verified-skill dispatch contract.
- [ ] Run Dart format/analyzer and Android build in CI/device; not yet performed.

**Safety note:** This is an isolated prototype, not a live booking flow. Existing booking form, payment method and booking lifecycle remain unchanged.


## 2I. Customer Dashboard picker placement (2026-11-21)

- [x] Imported the isolated picker into Customer Dashboard and placed it below the founder banner, above the existing booking list.
- [x] Selected category/task is displayed as a preview and confirmation snackbar; callback IDs are not sent to the backend.
- [x] Existing floating “नई बुकिंग” action still opens the original `CustomerBookingFormPage`.
- [x] Existing booking form, old service dropdown, `/api/create-booking` payload, payment dropdown and booking history are preserved unchanged.
- [x] Re-fetched source confirms the picker is present and the existing booking form + submit endpoint remain present.
- [ ] Flutter format/analyze and Android build still pending; no successful build is claimed.
- [ ] Do not connect category selection to the live submit action until canonical backend category IDs, authoritative rates and verified-skill dispatch are delivered.


## 2J. Customer category picker widget tests (2026-11-21)

- [x] Added Flutter widget tests for the six-category order, AC-vs-Fridge task isolation, and Cooler Repair selection.
- [x] Test source re-fetched from the approved feature branch.
- [ ] Tests have NOT yet been executed; GitHub Actions workflow is manual-dispatch only and no workflow-dispatch action is available in this connection.
- [ ] Dart analyzer, formatter, Android debug APK builds, and device testing remain outstanding.


- [x] Corrected Cooler widget test to tap the visible कूलर रिपेयर subcategory before asserting the selection callback (49bae0c).
- [x] Checked GitHub Actions runs for this feature branch: no runs are currently listed. Test source is committed but execution is still pending.
- [ ] Plumber and Painter detailed subcategories are intentionally not invented; only their top-level categories are shown until the owner confirms their service lists.


## 2K. Safe option-removal pass (2026-11-21)

- [x] Re-inspected current Customer and Technician widgets before deleting any visible option.
- [x] Customer cancellation remains limited to `new`/`confirmed`; complaint/support remains available for non-cancelled bookings; assigned-technician contact is guarded by assigned lifecycle states. Preserve these actions.
- [x] Customer cash/online payment choice is still accepted by the current create-booking endpoint; payment rotation/technician-specific eligibility contract is not yet available. Do not remove or replace the control until the backend contract is supplied.
- [x] Customer legacy electrical service dropdown is the actual input to the existing booking form. The new six-category picker is currently preview-only and is not connected to the create-booking payload. Do not swap the form to the picker until category IDs, verified-skill dispatch, and API payload are ready.
- [x] Technician offer accept/decline, map, assigned customer contact, work completion, cash confirmation, earnings and wallet views are functional lifecycle actions; preserve them.
- [x] Quote screens/actions and quote-dependent status labels are still tied to current work-start, cash confirmation and Razorpay backend checks. They remain explicitly blocked for removal pending quote-free lifecycle + materials-approval + payment contract. No quote UI was deceptively hidden.
- [x] No additional safe-to-delete functional option was identified in this pass; no Flutter source changed. This is intentional preservation, not a missed implementation.


## 2L. Backend contract handoff prepared (2026-11-21)

- [x] Created `docs/SRK_MOBILE_BACKEND_CONTRACT_HANDOFF_HI.md` on the approved mobile frontend branch (commit 5c12919).
- [x] Handoff covers six-category catalogue IDs, verified skills, category-safe dispatch, booking payload, rate snapshots, quote-free lifecycle, materials approval, technician offers, payment/Razorpay/cash cycle, 85/15 fee-base conflict, payout and legacy compatibility.
- [x] Explicitly records unresolved rate conflicts between the older Master Requirements document and later owner decisions; no rates/formula are silently combined.
- [ ] This handoff has NOT been sent to GPT-2 or implemented in backend. Backend owner review/contract is pending.
- [ ] Frontend picker remains preview-only until verified-skill dispatch and booking payload are available.

- [x] Static source review caught and corrected Flutter test view sizing to use TestFlutterView physicalSize/devicePixelRatio properties (commit 07b915e). Test execution is still pending.


## 2M. Widget test CI wiring (2026-11-21)

- [x] Normalized both widget-test view setup blocks to use `TestFlutterView.physicalSize` and `devicePixelRatio` properties (commit 4a16073).
- [x] Added `flutter test` to the Customer app CI sequence after dependency resolution and Dart analysis, before the debug APK build (commit e696098).
- [x] Re-fetched both files and verified the test command is present in the Customer job and absent from no other app job changes.
- [ ] Workflow has not been dispatched; no test/analyzer/build result is claimed.


## 2N. Owner reconfirmation — company platform fee and technician share (2026-11-21)

- [x] Owner reconfirmed the existing split: Company platform fee **15%**, Technician share **85%**; this is not a new change.
- [x] Commission basis is service charge/labour only, not the full booking payment. Materials/parts are excluded.
- [x] Updated `docs/SRK_MOBILE_BACKEND_CONTRACT_HANDOFF_HI.md` to remove the open question about the percentage/base and explicitly supersede the older labour-only wording in the Master Requirements for this later owner decision.
- [ ] Backend must still reconcile ledger treatment for helper/material/tax/travel/refunds, rounding, cash and online settlements while preserving the confirmed 15%/85% split. No backend or payment code changed.


## 2O. Customer picker और shared catalogue का reconciliation audit (2026-11-21)

### दोनों स्रोतों की तुलना
- [x] `apps/customer_app/lib/service_category_picker.dart` में UI navigation model है: category/subcategory IDs, Hindi labels और AC/Fridge के task labels।
- [x] `packages/srk_mobile_core/lib/srk_service_catalog.dart` में reusable catalogue/rate presentation model है: English category/option names, descriptions, skill tiers और confirmed rate notes।
- [x] दोनों में छह top-level categories और उनका क्रम मेल खाते हैं; अभी दोनों स्वतंत्र lists हैं, एक canonical source नहीं।
- [x] Electrician के आठ task labels दोनों में लगभग समान हैं, लेकिन picker के stable subcategory IDs और shared catalogue के options के बीच explicit ID mapping नहीं है।
- [x] AC + Fridge में AC/Fridge second-level split दोनों में है; picker task labels को plain strings रखता है, जबकि shared model tasks को एक note में text के रूप में रखता है। Individual task IDs अभी नहीं हैं।
- [x] Motor & Pump के सात option labels दोनों में लगभग मेल खाते हैं; winding HP rates केवल shared catalogue में हैं, picker में HP selection/rate UI नहीं।
- [x] Cooler Repair दोनों में है; ₹500 fixed labour और parts/winding exclusions केवल shared catalogue note में हैं।
- [x] Plumber और Painter दोनों में picker तथा shared catalogue में विस्तृत service subcategories/options अभी खाली/अनुपस्थित हैं। इन्हें अनुमान से नहीं भरा गया है।
- [x] Shared catalogue में approved rate/skill tiers हैं; picker में rate/skill tiers नहीं हैं। ये अलग उद्देश्य के models हैं, पर future integration में एक versioned catalogue contract से जुड़ना चाहिए।

### सुरक्षित निष्कर्ष और अगला कदम
- [x] अभी इन दोनों models को सीधे merge या एक-दूसरे में import नहीं किया गया; backend canonical IDs और catalogue version तय नहीं हैं।
- [x] Picker को booking payload, pricing, dispatch या Technician eligibility से जोड़ना अभी सुरक्षित नहीं।
- [ ] Backend owner से canonical category/subcategory/task/skill-tier IDs, catalogue version और rate effective-date contract मिलने पर एक ही shared canonical catalogue बनाया जाए; Customer picker उसी को render करे।
- [ ] प्रत्येक task को stable ID दिया जाए; UI Hindi/English labels को ID से अलग रखा जाए। AC और Fridge tasks अलग-अलग nested रहें।
- [ ] Plumber/Painter की वास्तविक subcategory सूची owner से लेकर जोड़ी जाए; कोई task या rate अनुमान से न बनाया जाए।
- [ ] Motor & Pump winding HP choices, Cooler fixed ₹500 labour और separate materials approval को उसी canonical model में typed pricing rules के रूप में दर्शाया जाए; fixed jobs पर hourly overtime न लगे।
- [ ] Canonical model बनने के बाद tests को IDs, category order, AC/Fridge isolation, Plumber/Painter options, fixed-vs-hourly pricing metadata और unknown/unpriced options पर बढ़ाया जाए।

**स्थिति:** यह source-code inspection और documentation update है। इस चरण में Flutter UI/model source, booking submit, backend, database, payment या production behavior नहीं बदला गया। Flutter format/analyze/test/build अभी execute नहीं हुए।


## 2P. Shared catalogue test coverage और पुराने requirements की cross-check (2026-11-21)

- [x] पुराने source-of-truth Master Requirements और project progress दस्तावेज़ में Plumber/Painter के लिए कोई स्पष्ट, owner-approved विस्तृत task/subcategory catalogue इस खोज में नहीं मिला; इसलिए सूची अनुमान से नहीं बनाई गई।
- [x] Shared catalogue के लिए `packages/srk_mobile_core/test/srk_service_catalog_test.dart` में tests जोड़े: छह category order, AC/Fridge separation, Plumber/Painter task-list gap, Motor & Pump fixed HP winding rates, Cooler ₹500 fixed repair/materials note।
- [x] Flutter CI workflow में shared core के `dart analyze` के बाद `flutter test` step जोड़ा; Customer app tests पहले से अलग step में हैं।
- [ ] Shared core और Customer app tests अभी केवल workflow में wired हैं; workflow dispatch/run और test result अभी उपलब्ध नहीं।
- [ ] Tests pass होने के बाद अगला चरण canonical IDs/rate version contract के आधार पर shared catalogue को Customer picker का एकमात्र data source बनाना होगा। अभी picker को सीधे बदलना या live booking से जोड़ना सुरक्षित नहीं।
- [ ] Backend owner से Plumber/Painter की approved subcategory list मिलने तक दोनों की विस्तृत service navigation अधूरी रहेगी।

**स्थिति:** Test source और CI workflow update commit हुए हैं; Flutter SDK execution, analyzer, widget/unit test result और Android build का कोई दावा नहीं।


## 2Q. Picker/shared-catalogue parity guard (2026-11-21)

- [x] Customer picker widget tests में shared `srk_mobile_core` catalogue के साथ six category mapping और हर category के second-level option count का parity assertion जोड़ा।
- [x] इससे Electrician, AC + Fridge, Motor & Pump और Cooler के विकल्पों की संख्या तथा Plumber/Painter के अभी खाली task lists में accidental drift पकड़ा जा सकेगा।
- [x] यह guard केवल structural parity जाँचता है; display labels, task IDs, canonical backend IDs, rate-version या verified Technician skill की समानता सिद्ध नहीं करता।
- [ ] Flutter tests अभी execute नहीं हुए; GitHub Actions workflow dispatch/run और analyzer/build evidence pending है।
- [ ] Backend owner से canonical catalogue contract मिलने पर duplicated navigation data को वास्तविक shared model से replace करना है; parity test को तब ID/label/task-level contract test में बदलें।

**सीमा:** कोई live booking, payment, backend, database या dispatch behavior नहीं बदला।


## 2R. Technician app verified-skill offer contract audit (2026-11-21)
- [x] Re-fetched current Technician Flutter source. Profile query reads only `id, display_name, state, district, pincode, active, verification_status`; it does not fetch normalized verified category/subcategory/task skills.
- [x] Offer inbox/details come from existing job-offer and RPC responses; UI displays service text but does not perform verified-skill eligibility checks.
- [x] Legacy free-text `electrician_profiles.skills` is not proof of Admin-approved skill and must not be used as a client-side authorization rule.
- [x] Added backend handoff contract requiring server-authoritative verified skill IDs, expiry/active state, exact offer-to-skill matching, atomic accept re-check, and server-side authorization for assigned work/status/payment actions.
- [x] AC and Fridge remain separate; specialist AC gas/refrigerant and sealed-system fridge tasks require their exact verified task skills.
- [x] Defined fail-closed frontend behavior: unknown/missing skill IDs or unverified/expired/revoked skills cannot enable offers/work; backend must return explicit no-eligible outcome.
- [ ] Backend owner must publish exact deployed profile fields, RPC names, request/response JSON and version before Flutter adds skill parsing or profile selection fields.
- [ ] After contract publication: add typed model, verified-services read-only panel, safe offer matching display and tests for pending/rejected/expired/revoked skills, AC/Fridge isolation and accept races.
- [ ] No live offer filtering, schema/RPC changes, database, backend, production, payment or payout code was changed in this frontend audit.


## 2S. Technician verified-services UI prototype and test wiring (2026-11-21)
- [x] Added isolated typed skill parser and read-only “आपकी सत्यापित सेवाएँ” panel in `apps/electrician_app/lib/verified_services/`.
- [x] Parser requires approved status, active flag, non-empty category/subcategory IDs and labels; expired records are rejected. Unknown or incomplete records fail closed.
- [x] Added widget/model tests for approved, pending, rejected, inactive, expired, missing IDs, AC-vs-Fridge distinction and safe empty state.
- [x] Wired Technician `flutter test` into Android CI after `dart analyze`.
- [x] Kept this component isolated: no profile query, Supabase RPC, offer filtering, assignment, work-start or payment behavior changed.
- [ ] Backend must confirm exact deployed response field names and IDs before this panel is connected to live profile data.
- [ ] Flutter analyze, tests and Android APK build are not yet executed/verified.


## 2T. Technician offer-to-skill preview matching (2026-11-21)
- [x] Added a pure, isolated preview matcher for exact category/subcategory and optional task/skill-tier IDs.
- [x] Missing canonical IDs return `unknown`; mismatches return `notMatched`; exact verified-skill matches return `matched`.
- [x] Added tests for exact match, AC-vs-Fridge/trade mismatch, subcategory mismatch, specialist task/tier mismatch and missing IDs.
- [x] Exported the helper from the verified-services library barrel.
- [ ] Do not connect matcher to offer visibility or accept/decline until backend supplies canonical fields and server-side eligibility guarantees.
- [ ] No existing offer card, booking lifecycle, quote, payment, assignment or backend behavior was changed.


## 2U. Technician assigned-booking lifecycle preview audit (2026-11-21)

- [x] Re-inspected the live Technician assigned-booking card and its status actions: assigned → inspection; quote-approved → work in progress; in-progress → completed; cash confirmation remains available only for completed cash bookings not marked paid.
- [x] Confirmed the assigned-booking view also preserves map navigation, assignment-guarded customer phone, labour/material/total fields, payment state, earnings and wallet display.
- [x] Added isolated `SrkTechnicianBookingLifecyclePreview` presentation mapping for the currently deployed statuses, with unknown states represented as informational/unknown.
- [x] Explicitly marks `awaiting_quote_approval`, `quote_approved` and `quote_rejected` as legacy quote-dependent states; this prevents the prototype from implying that quote removal is already supported.
- [x] Added unit tests for current statuses, legacy-state marking, completed terminal display and unknown/missing status handling; exported the helper from the verified-services barrel.
- [ ] This helper is not connected to the live assigned-booking card and does not authorize or call any status transition.
- [ ] Do not remove quote UI or change work-start/cash/payment calls until the quote-free lifecycle, material approval and payment replacement RPCs are deployed and tested by backend owner.
- [ ] Flutter formatter, analyzer, unit/widget tests, Android build and device test remain unexecuted/unverified.

**सीमा:** यह केवल read-only presentation prototype और source audit है। Live booking actions, RPCs, status transitions, customer contact, map, cash confirmation, earnings, wallet, backend, database, payment या production में कोई बदलाव नहीं किया गया।


## 2V. Customer ↔ Technician work confirmation gap audit (2026-11-21)

### Customer app में अभी जो उपलब्ध है
- [x] Customer booking list सीधे `service_bookings` से current status/payment/quote fields पढ़ती है और assigned lifecycle states में authorized Technician contact दिखाती है।
- [x] Customer अभी केवल legacy quote pending अवस्था में quote approve/reject कर सकता है।
- [x] Customer cancellation केवल `new` / `confirmed` में उपलब्ध है; complaint/support और paid-state display सुरक्षित हैं।
- [x] Online payment केवल completed + unpaid + quote-approved booking पर उपलब्ध है; payment success server verification के बाद refresh होता है।
- [x] Customer app में अभी “काम शुरू होने की पुष्टि” या “काम पूरा होने की पुष्टि” के लिए अलग action/RPC नहीं है।

### Technician app में अभी जो उपलब्ध है
- [x] Technician assigned booking पर inspection शुरू कर सकता है; work-start केवल legacy `quote_approved` स्थिति से और completion केवल `in_progress` से भेजता है।
- [x] Cash confirmation completed + cash + unpaid card पर उपलब्ध है; backend RPC अभी quote approval भी जाँचता है।
- [x] Map, assigned customer phone, itemized service/material/total display, earnings और wallet को preserve करना आवश्यक है।

### Quote-free lifecycle के लिए अगला contract
- [ ] Backend पहले नई booking lifecycle/status enum और server-side transition table प्रकाशित करे; legacy quote bookings की read-only compatibility अलग हो।
- [ ] Technician “काम शुरू करने का अनुरोध” भेजे; Customer app में उसी booking के authorized owner को स्पष्ट start confirmation दिखे। Timer केवल server पर customer confirmation के बाद शुरू हो।
- [ ] Technician completion request भेजे; Customer app में final work summary और confirm/dispute path आए। Backend तय करे कि customer response timeout, dispute या Admin override कैसे संभलेगा।
- [ ] Materials/parts approval अलग, itemized और customer-confirmed हो; इसे quote/counter-offer status में न बदला जाए।
- [ ] हर action booking owner/assigned technician, current status, skill authorization, version/expected state और idempotency key से server पर validate हो। Duplicate taps/network retries duplicate timers, completion या charges न बनाएं।
- [ ] Customer को final bill में labour, approved materials, applicable charges, total, payment method/eligibility और receipt अलग-अलग दिखें।
- [ ] Existing cancel/complaint/contact/privacy/payment flows को transition matrix में explicitly preserve या replace किया जाए; कोई नया UI पुरानी API पर अनुमान से न बने।

**स्थिति:** दोनों ऐप के मौजूदा स्रोतों का read-only audit और requirements documentation। कोई Customer/Technician screen, RPC, database, payment या live status action नहीं बदला।

## 2W. Customer work confirmation और server timer का isolated preview (2026-11-21)

- [x] प्रस्तावित start/completion confirmation states के लिए अलग typed DTO जोड़ा; ये backend के deployed status नाम नहीं हैं।
- [x] प्रस्तावित contract में booking/request IDs, requester role, requested action, state, server timestamps, version और idempotency key शामिल हैं।
- [x] Timer preview तभी active हो सकता है जब server confirmation timestamp और server start timestamp दोनों उपलब्ध हों तथा completion timestamp न हो।
- [x] Client device clock से timer शुरू/गणना नहीं होती; duplicate request पहचान केवल समान non-empty booking ID + request ID पर आधारित है।
- [x] Unknown/missing state/action fail-closed रहते हैं; tests में timestamp gating, completion, duplicate identity, UTC parsing और unknown state शामिल हैं।
- [ ] यह DTO केवल isolated preview है; Customer या Technician की live screen, button, Supabase query/RPC अथवा status action से जुड़ा नहीं है।
- [ ] Backend से exact deployed JSON keys, enum, ownership checks, idempotency behavior, server-time semantics, timeout/dispute/Admin override और version conflict contract मिलने तक इसे live app में न जोड़ें।
- [ ] Flutter formatter, analyzer, tests, Android build और device test अभी execute/verify नहीं हुए।

**सीमा:** मौजूदा booking flow, quote compatibility, offer/assignment, map/contact, cash/online payment, earnings/wallet, backend, database और production behavior में कोई बदलाव नहीं।

## 2X. Customer confirmation और final bill का isolated UI model (2026-11-21)

- [x] Customer app में अलग read-only confirmation presentation model जोड़ा; start/completion pending, confirmed, disputed, other और unknown स्थितियाँ स्पष्ट रूप से अलग हैं।
- [x] केवल स्पष्ट प्रस्तावित pending states को “ग्राहक की पुष्टि बाकी” presentation hint मिलता है; इससे कोई button/action authorize नहीं होता।
- [x] Final bill preview में labour, customer-approved materials, other charges और server total integer paise में रखे जाते हैं।
- [x] Missing/negative रकम और breakdown mismatch को fail-closed/inconsistent दिखाने के लिए validation जोड़ी; server total को client द्वारा चुपचाप बदला नहीं जाता।
- [x] Payment eligibility केवल server का informational boolean है; हर payment request पर backend को दोबारा जाँच करनी होगी।
- [x] Tests में pending/unknown states, server timestamps, valid/mismatched/missing amounts और payment eligibility शामिल हैं।
- [ ] यह मॉडल live booking card, Customer confirmation button, bill display, receipt या Razorpay flow से जुड़ा नहीं है।
- [ ] Backend exact deployed response, amount/currency rules, approved-material semantics, tax/fee treatment, payment eligibility, receipt and dispute contracts प्रकाशित करे; तब ही integration करें।
- [ ] Flutter formatter, analyzer, tests, Android build और device test अभी execute/verify नहीं हुए।

**सीमा:** मौजूदा booking card, quote compatibility, cancellation, complaint, contact privacy, online/cash payment और booking API untouched हैं।


## 2Y. Customer + Technician shared confirmation/bill contract (2026-11-21)

- [x] Added shared preview-only DTOs in `packages/srk_mobile_core/lib/srk_work_confirmation_contract.dart`; both apps can import one source of field names and enum parsing.
- [x] Shared confirmation DTO includes booking/request IDs, actor, requested action, proposed state, version, idempotency key and server timestamps.
- [x] Timer presentation remains fail-closed: only proposed `start_confirmed` with both server confirmation and server start timestamps and no completion timestamp may be displayed as active.
- [x] Shared final-bill DTO carries labour, approved materials, other charges and server total as integer paise; amount validation requires non-negative integer amounts and exact sum equality.
- [x] Exported the contract from the shared mobile-core barrel and added six unit tests for timestamp gating, UTC normalization, unknown states and bill validation.
- [ ] DTO keys and enums are frontend proposals only, not deployed backend schema. Do not connect either app to live queries/actions until backend signs off and deploys exact JSON/RPC contracts.
- [ ] No Customer/Technician screen, booking form, existing booking lifecycle, quote compatibility, payment, cancellation, complaints, map/contact, earnings/wallet or backend/database behavior changed.
- [ ] Flutter format, analyzer, shared-core tests, Android build and device tests have not been run/verified.

**सीमा:** यह साझा डेटा-मॉडल है, live integration नहीं। सर्वर ही booking status, customer ownership, technician assignment, skills, timer, bill total और payment eligibility का अंतिम प्राधिकरण रहेगा।


## 2Z. Existing API inventory and cross-app map (2026-11-21)

- [x] Added `docs/SRK_MOBILE_API_INVENTORY_AND_CROSS_APP_MAP_HI.md` with source-audited Customer/Technician RPC and HTTP inventory, legacy quote/payment dependencies, proposed quote-free API surface, shared DTO mapping and backend rollout gates.
- [x] Clearly separates source-observed current calls from proposed, not-deployed API names.
- [ ] Backend owner must confirm actual deployed routes/schema, permissions, response/error contracts and staging evidence before frontend integration.
- [ ] No live API call, UI, booking, payment, database or production behavior changed; Flutter/Android verification remains pending.


## 2AA. Shared six-category catalogue and Customer picker unification (2026-11-21)

- [x] Shared core catalogue now owns the six category keys, Hindi display labels, icon keys, existing subcategory keys/labels, AC/Fridge task labels and existing rate data.
- [x] Added draft catalogue version `draft-2026-11-21.1`; all keys remain frontend proposal identifiers and are NOT deployed backend IDs.
- [x] Customer service picker now adapts from `packages/srk_mobile_core/lib/srk_service_catalog.dart`; its separate hard-coded category/subcategory/task list has been removed.
- [x] AC and Fridge task lists are stored separately in shared data; their task keys are scoped separately.
- [x] Plumber/Painter task lists remain empty because the owner has not confirmed their detailed tasks; unconfirmed Fridge/helper/other rates are not invented.
- [x] Existing shared rate entries, Cooler ₹500 fixed labour, Motor winding HP rates and materials-approval note remain in the shared catalogue.
- [ ] Technician verified-skill model and backend offer matching are NOT yet wired to this catalogue; backend must approve canonical IDs/version and publish exact response contract.
- [ ] Do not send these draft IDs through existing booking create API or use them for dispatch/payment until backend contract is deployed and verified.
- [ ] Run Flutter formatter, analyzer, shared-core tests, Customer widget tests and Android builds; none are claimed as executed by this source update.

**सीमा:** केवल shared presentation catalogue और Customer picker data source बदला है। Existing booking form/submit payload, booking lifecycle, Technician live screens/skill authorization, APIs, Supabase, database, payment, production और Admin में कोई बदलाव नहीं।


## 2AB. Technician verified-skill IDs का shared catalogue से read-only मिलान (2026-11-21)

- [x] Technician skill model में अलग parser `fromDraftCatalogueServerJson` जोड़ा; यह केवल exact draft catalogue version, known category/subcategory IDs और उसी subcategory के known task ID को स्वीकार करता है।
- [x] Display labels shared catalogue से लिए जाते हैं; server के पुराने/गलत labels को canonical display label नहीं माना जाता।
- [x] Unknown category/subcategory/task, missing या अलग catalogue version, pending/rejected/inactive/expired skill fail-closed रहती है।
- [x] Verified Services barrel exports को वास्तविक source file paths पर ठीक किया।
- [x] Tests जोड़े: valid AC skill + canonical label, unknown IDs, AC/Fridge task mismatch और version mismatch।
- [ ] Existing generic parser और offer matcher अभी isolated preview helpers हैं; उन्हें live Supabase profile, offer filtering/acceptance या work/payment authorization में नहीं जोड़ा गया।
- [ ] Backend canonical IDs/version, deployed JSON response और server-side revalidation contract approve करे; draft version को production में न भेजें।
- [ ] Flutter format, analyzer, Technician tests, Customer/shared-core tests और Android build अभी run/verify नहीं हुए।

**सीमा:** यह ID/label consistency check है, Technician approval/dispatch authorization नहीं। Existing offer inbox, accept/reject, assigned booking, map/contact, status, cash/online payment, earnings/wallet, Supabase, backend, database और production behavior untouched हैं।


## 2AC. Offer skill preview का shared catalogue/version से मिलान (2026-11-21)

- [x] नया `previewOfferSkillMatchAgainstDraftCatalogue` जोड़ा: offer का catalogue version, category ID, subcategory ID और उपलब्ध task ID shared draft catalogue से validate होते हैं।
- [x] केवल उसी draft version के Technician skills को preview match में माना जाता है।
- [x] अज्ञात/पुराने version पर `unknown`; ज्ञात लेकिन गलत category/subcategory/task पर `notMatched`; सही IDs और version पर ही `matched`।
- [x] जिन subcategories की task taxonomy अभी तय नहीं है, उनके task-specific offer पर fail-closed `unknown`।
- [x] Tests जोड़े: exact version match, missing/old version, unknown IDs, दूसरी subcategory का task, पुरानी skill version और unconfirmed task taxonomy।
- [ ] यह matcher live offer inbox को filter/hide नहीं करता और offer accept, dispatch, work, material या payment action को authorize नहीं करता।
- [ ] Backend canonical catalogue/version approve करके offer और verified-skill payload में वही version/IDs दे; server हर protected transition पर स्वतंत्र रूप से skill/assignment/ownership जाँचे।
- [ ] Flutter tests/analyzer/formatter/Android build अभी execute नहीं किए गए।

**सीमा:** केवल preview helper और test जोड़े। Existing offer list, accept/reject, booking lifecycle, Supabase queries/RPC, payments, database और production unchanged।

## 2AD. Customer चयन से Technician offer तक साझा Service Selection Contract (2026-11-21)

- [x] Shared Core में `SrkServiceSelection` DTO जोड़ा और `srk_mobile_core.dart` से export किया।
- [x] DTO में एक ही catalogue version, category_id, optional subcategory_id और optional task_id हैं; Hindi labels केवल display के लिए हैं।
- [x] `toJson()` backend contract के लिए versioned ID payload देता है; labels को authoritative ID की तरह नहीं भेजता।
- [x] DTO factory category → subcategory → task hierarchy को shared catalogue से validate करती है; गलत/अनजान IDs पर null।
- [x] Customer Dashboard picker अब वही DTO emit करता है; AC/Fridge tasks के IDs अलग-अलग हैं।
- [x] Technician offer preview उसी `toJson()` payload को समान-version verified skill से match करने का cross-app test रखता है।
- [ ] यह अभी preview है। Existing `/api/create-booking` payload में जोड़ना, live booking form बदलना या offer query/filter बदलना नहीं किया।
- [ ] Backend को catalogue version/IDs approve करके booking create response और offer/verified-skill payload में समान canonical fields देना होगा।
- [ ] Backend rollout, legacy booking compatibility, idempotency और server-side skill/ownership checks के बाद ही live integration।
- [ ] Flutter tests/analyzer/formatter/Android build अभी execute नहीं किए गए।

**सीमा:** Existing booking form, booking submit payload, dispatch, quote/payment lifecycle, Supabase/RPC, database और production unchanged।


- [x] विस्तृत चरणबद्ध Customer booking service-ID integration plan: `docs/SRK_CUSTOMER_BOOKING_SERVICE_ID_INTEGRATION_PLAN_HI.md` (अभी योजना; live submit payload नहीं बदला)।

## 2AE. Customer booking form में सुरक्षित category-picker placement (2026-11-21)

- [x] Dashboard से अलग category preview हटाकर picker को वास्तविक नई बुकिंग form के अंदर रखा।
- [x] Form state में `SrkServiceSelection?` draft selection रखी और चुना हुआ display name/version दिखाया।
- [x] स्पष्ट सूचना दी कि Backend मंजूरी से पहले चयन booking payload में नहीं जाएगा।
- [x] पुराना required `service_type` dropdown और उसका submit व्यवहार सुरक्षित रखा।
- [x] Existing OTP, customer/address, date/time, work details, payment method, GPS और create-booking request fields सुरक्षित।
- [ ] Backend canonical catalogue/version और staging API contract मिलने के बाद ही draft selection को submit payload से जोड़ना।
- [ ] Flutter formatter/analyzer/tests और Android build/device test अभी execute/verify नहीं किए गए।

**सीमा:** केवल picker का स्थान और form-local preview state बदला। Live API payload, booking lifecycle, dispatch, Supabase/backend/database/payment अपरिवर्तित।

## 2AF. Category बदलने पर पुराना चयन साफ करना (2026-11-21)

- [x] Picker callback nullable बनाया ताकि अधूरा parent selection स्पष्ट रूप से null भेज सके।
- [x] Category/subcategory बदलते समय पुराने completed service selection को clear किया।
- [x] नई valid hierarchy पूरी होने पर ही नया selection emit होता है।
- [x] Parent category बदलने पर stale selection reset का widget test जोड़ा।
- [ ] Flutter tests/analyzer/formatter अभी execute नहीं हुए।

**सुरक्षा:** यह केवल form preview state है; legacy booking payload और backend flow अपरिवर्तित हैं।

## 2AG. चुने हुए task का स्पष्ट visual feedback (2026-11-21)

- [x] Task selection को FilterChip selected state से highlight किया।
- [x] Subcategory बदलने पर पुराना task selection और highlight reset किया।
- [x] Category बदलने पर subcategory/task state reset सुरक्षित रखा।
- [x] Widget test में task highlight तथा subcategory बदलने पर reset assertions जोड़े।
- [ ] Flutter tests/analyzer/formatter अभी execute नहीं हुए।

**सीमा:** केवल picker UI state बदली; live booking payload या backend नहीं बदला।


## 2AH. Customer booking form और legacy submit compatibility audit (2026-11-21)

- [x] OTP session/verified phone, required customer/address fields, 6-digit PIN, work details, date/time guards और submit loading/error flow की source-level जाँच।
- [x] Cash/online payment method और optional GPS latitude/longitude pair पुराने payload में सुरक्षित पाए गए।
- [x] Legacy electrical `service_type` अभी required है; नए category picker का versioned selection submit payload में नहीं जाता।
- [x] Category/subcategory बदलने पर draft selection reset होता है; legacy dropdown को auto-map नहीं किया जाता।
- [x] Integration plan §12 में audit निष्कर्ष और Backend dependency दर्ज।
- [ ] Backend canonical catalogue/version, staging API contract और legacy dispatch compatibility के बिना structured service IDs live submit में न जोड़ें।
- [ ] Location permission permanently denied होने पर Settings मार्ग का UX सुधार अलग से विचारें; manual address fallback अभी उपलब्ध है।
- [ ] Flutter tests/analyzer/formatter/Android build/device tests इस audit में execute नहीं किए गए।

**सीमा:** यह source-level audit और documentation update है। Booking form runtime code, payload, API, Supabase, backend, database, payment, dispatch और production में कोई बदलाव नहीं।


## 2AI. Customer booking history, status, cancellation और complaint audit (2026-11-21)

### सुरक्षित/मौजूदा व्यवहार
- [x] Booking history केवल current authenticated user की `customer_user_id` rows पढ़ती है; newest-first क्रम और 50-row limit है।
- [x] Booking card में service, booking ID, status, district/state/PIN और preferred date/time दिखते हैं।
- [x] Existing statuses `new`, `confirmed`, `assigned`, `inspection`, legacy quote statuses, `in_progress`, `completed`, `cancelled` के Hindi labels मौजूद हैं; unknown status raw value के रूप में fallback होता है।
- [x] Cancellation button केवल `new` और `confirmed` पर दिखता है और `srk_customer_cancel_my_booking` RPC को booking ID देता है।
- [x] Cancellation RPC failure पर generic error आता है; UI success के बाद booking list refresh होती है।
- [x] Complaint creation में category और कम-से-कम 10 अक्षर का विवरण जाँचा जाता है; RPC `srk_customer_create_booking_complaint` के बाद complaint list refresh होती है।
- [x] Complaint list `srk_customer_list_booking_complaints` से आती है; complaint create/list दोनों booking ID के बजाय server RPC contract पर निर्भर हैं।
- [x] Technician phone केवल contact RPC से आता है और assigned/बाद की अनुमत status स्थितियों में ही UI दिखाता है।

### मिली हुई सीमाएँ / सुधार सूची
- [ ] Complaint-list RPC failure को खाली सूची में बदल दिया जाता है; ग्राहक को यह स्पष्ट नहीं होता कि शिकायतें वास्तव में शून्य हैं या load नहीं हुईं।
- [ ] Contact RPC failure भी चुपचाप ignore होता है; फोन न दिखने का कारण UI में स्पष्ट नहीं होता।
- [ ] Booking history query failure का error पूरे dashboard के लिए आता है; अलग complaint/contact load state नहीं है।
- [ ] Complaint subtitle में newline escaping जाँचकर सही line breaks सुनिश्चित करें।
- [ ] Status fallback unknown backend status को raw string दिखाता है; unknown state के लिए सुरक्षित सामान्य Hindi label और logging पर विचार करें।
- [ ] Quote approve/reject UI और quote-related statuses अभी legacy backend lifecycle पर निर्भर हैं। Quote-free backend transition matrix और historical booking compatibility के बिना इन्हें हटाना नहीं है।
- [ ] Cancellation की server-side eligibility अंतिम authority है; UI का status check security control नहीं है। Backend RPC ownership और current state पुनः जाँचे।
- [ ] इस source audit में Flutter widget tests, analyzer, formatter, Supabase integration test या Android build execute नहीं हुए।

**सीमा:** इस audit में Customer runtime code, booking lifecycle, cancellation/complaint RPC, contacts, payment, Supabase, backend, database या production नहीं बदले। निष्कर्ष source inspection पर आधारित हैं।


## 2AJ. Technician Offer Inbox और Accept/Reject compatibility audit (2026-11-21)

### मौजूदा frontend व्यवहार
- [x] Technician OTP login Supabase phone OTP से होता है।
- [x] Profile lookup current auth user ID से linked `electrician_profiles` row पढ़ता है।
- [x] केवल linked profile होने पर `job_offers` को उसी `electrician_id` से query किया जाता है; नवीनतम 100 offers पढ़े जाते हैं।
- [x] Offer detail और price detail अलग RPCs से आते हैं; Inbox में केवल `offer_status == offered` दिखता है।
- [x] Offer में service type, booking ID, district/state/PIN, date/time, work details और match level दिखते हैं।
- [x] Accept/Reject से पहले confirmation dialog है; दोनों actions `srk_respond_to_offer` RPC से होते हैं।
- [x] RPC success/failure के बाद dashboard reload होता है; race/दूसरे Technician द्वारा offer लेने पर failure message दिया जाता है।
- [x] UI PIN match और district match का label दिखाता है; वास्तविक offer eligibility Backend/RPC की जिम्मेदारी है।

### महत्वपूर्ण सीमाएँ / Backend dependencies
- [ ] Profile query में approved verified category/subcategory/task skills नहीं हैं; legacy free-text skills को authorization न मानें।
- [ ] मौजूदा offer UI में canonical `catalogue_version/category_id/subcategory_id/task_id` match display नहीं होता; वर्तमान service_type और PIN/district match label ही दिखता है।
- [ ] Frontend source से 30 km GPS matching प्रमाणित नहीं है; अभी match level PIN/district के रूप में आता है।
- [ ] `job_offers` raw rows और `srk_get_my_offer_details` response अलग sources हैं; दोनों की consistency और status mapping staging में जाँचें।
- [ ] Accept RPC को transaction में current offer status, expiry, booking state, assigned Technician, active approved verified skill, canonical catalogue version और competing accept race पुनः जाँचना चाहिए।
- [ ] Decline action भी offer ownership/status/expiry validate करे और idempotent हो।
- [ ] एक ही booking के competing offers में केवल एक acceptance सफल हो; बाकी offers server-side बंद हों।
- [ ] Offer details में customer phone/address केवल assignment/contact authorization के बाद मिले; offer preview में निजी संपर्क न आए।
- [ ] Backend canonical skill + dispatch contract और exact deployed response fields मिलने तक कोई नई Supabase column/RPC query न जोड़ें।
- [ ] Flutter tests/analyzer/formatter, Supabase staging tests और Android build/device tests इस source audit में execute नहीं हुए।

**सीमा:** केवल source inspection और दस्तावेज़ीकरण। Offer query, Accept/Reject RPC, dispatch, skill authorization, database, payment और production नहीं बदले।


## 2AK. Customer ↔ Technician नियुक्त बुकिंग और काम-पुष्टि audit (21-11-2026)

### Technician ऐप — मौजूदा live UI/RPC
- [x] नियुक्त बुकिंग `srk_get_my_assigned_booking_quote_details` RPC से लोड होती है; ग्राहक संपर्क अलग `srk_electrician_get_my_assigned_booking_contacts` RPC से जोड़ा जाता है।
- [x] UI में booking service, ID, district/state/PIN, status, map link और authorized customer phone दिखते हैं।
- [x] `assigned → inspection` के लिए Technician `srk_update_booking_work_status` चलाता है।
- [x] `quote_approved → in_progress → completed` के लिए वही RPC चलती है।
- [x] `assigned/inspection/quote_rejected` पर quote form उपलब्ध है; यह अभी legacy quote workflow है।
- [x] Completed + cash + unpaid पर Technician नकद भुगतान मिलने की पुष्टि करता है; RPC `srk_electrician_confirm_cash_payment` है।

### Customer ऐप — मौजूदा live UI/RPC
- [x] Customer केवल अपने `customer_user_id` की अधिकतम 50 नवीनतम bookings पढ़ता है।
- [x] Customer quote approve/reject `srk_customer_respond_booking_quote` से करता है।
- [x] Customer cancellation केवल `new/confirmed` status पर UI में दिखती है; Backend RPC अंतिम जाँच करता है।
- [x] Assigned lifecycle status में Customer को Technician का authorized phone दिखता है।
- [x] Online payment button केवल `completed + unpaid + quote approved` पर दिखता है; cash में Technician को नकद देने का संदेश दिखता है।
- [x] Complaint/support विकल्प non-cancelled booking पर उपलब्ध है।

### Cross-app gap / सुरक्षित rollout के लिए जरूरी
- [ ] Customer ऐप में अलग `काम शुरू करने की पुष्टि` action/RPC मौजूद नहीं।
- [ ] Customer ऐप में अलग `काम पूरा होने की पुष्टि` या `विवाद दर्ज करें` action/RPC मौजूद नहीं।
- [ ] Technician अभी सीधे `in_progress` और `completed` status बदल सकता है; ग्राहक confirmation के बिना app UI काम पूरा दिखा सकता है।
- [ ] Timer का live server-backed start/stop इस source में नहीं दिखता। केवल Technician button press को समय-गणना का प्रमाण न मानें।
- [ ] Payment eligibility और online payment अभी quote approval पर निर्भर हैं; quote-free flow deploy होने से पहले legacy payment path हटाना असुरक्षित होगा।
- [ ] Cash confirmation और earnings को नए customer-confirmed completion/final-bill state से जोड़ना होगा।
- [ ] Customer/Technician दोनों ऐप में एक साझा server-authoritative lifecycle, status/version, role authorization, idempotency और historical booking compatibility चाहिए।
- [ ] Materials/parts की itemized entry और Customer approval, work-start/completion confirmation से अलग सुरक्षित चरण हों।
- [ ] Customer completion response के लिए Backend को timeout, dispute, Admin review/override और duplicate request नीति तय करनी होगी।
- [ ] Final bill में labour, Customer-approved materials, अन्य लागू charges, total, payment method/status और receipt एक ही authoritative response से आने चाहिए।

**निर्णय:** मौजूदा Booking System को अभी न बदलें। Quote-dependent RPC/UI को तब तक सुरक्षित रखें जब तक Backend नया quote-free lifecycle और payment contract deploy करके staging में Customer तथा Technician दोनों ऐप से सत्यापित न कर दे। यह audit source-only है; runtime, RPC, database, payment और production में बदलाव नहीं हुआ। Flutter tests/analyzer/Android build execute नहीं हुए।


## 2AL. Technician कमाई, वॉलेट और service-charge commission audit (21-11-2026)

### Owner-confirmed financial rule
- [x] Company commission = केवल service charge/labour का 15%।
- [x] Technician service share = service charge/labour का 85%; materials पर commission/platform fee 0%।
- [x] Example: ₹600 service charge + ₹400 materials → Company ₹90 commission; Technician ₹510 service share; materials ₹400 separately, no company commission.
- [x] Labour/service और approved materials सहित पूरी ग्राहक booking payment split का आधार है; केवल labour पर commission नहीं।
- [x] यह नियम cash और online दोनों payment methods के लिए एक समान लागू होना चाहिए; वास्तविक collection और reconciliation method अलग हो सकता है।

### मौजूदा Technician mobile UI
- [x] `srk_get_my_earnings` से earning rows पढ़ता है।
- [x] Completed bookings की संख्या दिखाता है।
- [x] Paid + completed rows के `electrician_earning` को जोड़कर Paid कमाई दिखाता है।
- [x] `srk_get_my_wallet_summary` से internal wallet balance दिखाता है।
- [x] UI स्पष्ट करता है कि बैंक payout अभी disabled है।
- [ ] Flutter Technician ऐप में अलग Admin bank/UPI payout history list अभी नहीं दिखती; यह legacy web `electrician.html` की सुविधा से अलग है।

### मौजूदा Backend mismatch
- [ ] Migration `20261109_electrician_inspection_quotes_and_service_only_commission.sql` में `srk_calculate_booking_commission()` commission को `service_charge * commission_rate / 100` से निकालता है; materials/full customer payment base में शामिल नहीं।
  - [ ] सही 15/85 तभी होगा जब commission_amount केवल service_charge पर server-calculated हो; materials_amount commission base से बाहर रहे।
- [ ] Wallet foundation internal posted ledger balance दिखाता है; customer top-up और Technician bank payout disabled हैं। Wallet balance वास्तविक bank transfer नहीं है।
- [ ] Current wallet foundation में automatic booking payment → commission → Technician wallet ledger posting का प्रमाण इस audit में नहीं मिला।
- [ ] Razorpay Route transfer ledger/reconciliation record अपने-आप actual money transfer नहीं करता।

### Backend में जरूरी सुधार — implementation से पहले contract
- [ ] Server authoritative gross amount स्पष्ट करे: customer से वास्तव में verified/collected booking total; labour + approved materials + applicable customer charges का treatment स्पष्ट हो।
- [ ] Commission base केवल service_charge हो; materials_amount को commission base से बाहर रखें। Integer paise में deterministic rounding; materials को अलग pass-through/accounting item रखें।
- [ ] Customer discount/coupon, tax/GST, travel/extra charges, refund/partial refund, failed/reversed payment और chargeback के लिए लिखित allocation rule तय हो।
- [ ] Cash और Razorpay online दोनों में paid evidence और gross amount source server-verified हो; client-provided amount पर भरोसा न हो।
- [ ] Idempotent double-entry ledger entries: customer collection, company fee, technician payable, refund/reversal और payout; हर entry booking/payment/provider reference से जुड़ी हो।
- [ ] Technician earnings view, Admin commission report, wallet ledger और payout queue एक ही authoritative 15/85 calculation use करें।
- [ ] Bank payout केवल verified linked account, provider approval, Admin authorization और वास्तविक transfer confirmation/UTR के बाद paid दिखे।
- [ ] Existing historical bookings/commission values का reconciliation plan और rollback/backfill approval अलग हो।

**सीमा:** इस चरण में केवल source audit और दस्तावेज़ीकरण हुआ। कोई commission function, migration, wallet ledger, payout, payment, Supabase या production code नहीं बदला। Flutter tests/analyzer/Android build execute नहीं हुए।


## 2AM. Customer और Technician ऐप — screen/navigation inventory audit (21-11-2026)

### Customer ऐप — मौजूदा screens/entry points
- [x] OTP authentication screen (unauthenticated state)।
- [x] मुख्य home/dashboard एक scrollable screen है; अलग bottom navigation/tab/drawer नहीं मिला।
- [x] Founder banner और “मेरी बुकिंग” सूची।
- [x] Floating “नई बुकिंग” action से अलग booking form route खुलता है।
- [x] Booking form में customer details, address, date/time, work details, GPS, cash/online और legacy electrical service dropdown है।
- [x] छह-category picker उसी form में draft/preview है; अभी वास्तविक booking payload में नहीं जाता।
- [x] Booking card में status, assigned Technician contact, legacy quote/materials, cancellation, complaint/help और conditional payment controls।
- [x] Complaint list इसी मुख्य screen पर inline दिखती है।
- [x] Refresh, logout और pull-to-refresh उपलब्ध हैं।
- [ ] अलग Profile/Account, saved addresses, notification centre, payment history, help centre/FAQ और settings screens source में नहीं मिले।
- [ ] Booking list के लिए अलग filter/search/history tabs नहीं मिले; current list latest 50 bookings query से आती है।
- [ ] Empty/error/loading states मौजूद हैं; contact/complaint fetch errors की silent fallback behavior का अलग UX सुधार बाकी है।

### Technician ऐप — मौजूदा screens/entry points
- [x] OTP authentication screen।
- [x] मुख्य dashboard एक scrollable screen है; अलग bottom navigation/tab/drawer नहीं मिला।
- [x] Technician profile status/name/location और Approved/Active badge।
- [x] Offer inbox, offer counters और Accept/Reject actions।
- [x] Offer price details inline section।
- [x] Assigned bookings, map/directions, authorized Customer contact।
- [x] Legacy inspection, quote submission, quote approval wait, work start/completion और cash confirmation actions।
- [x] Earnings summary और internal wallet balance।
- [x] Refresh, logout और pull-to-refresh।
- [ ] अलग Profile edit/KYC documents, verified-service skill management, availability/schedule, notifications, support/complaints, payout/bank account, settings screens source में नहीं मिले।
- [ ] Offer/assigned booking/earnings के अलग navigable tabs या filters नहीं मिले।
- [ ] Wallet bank payout UI disabled; current mobile screen केवल internal balance दिखाती है।

### Release readiness / जरूरी निर्णय
- [ ] पहले तय करें कि वर्तमान single-dashboard navigation ही रखना है या Customer/Technician के लिए अलग tabs बनानी हैं; अनावश्यक screens नहीं जोड़ें।
- [ ] Customer booking history, booking details, complaint/help, payment receipt और profile/account के आवश्यक minimum flows का owner-approved screen map बनाएं।
- [ ] Technician offers, assigned work, verified skills/profile, earnings/payout status और support के आवश्यक minimum flows का owner-approved screen map बनाएं।
- [ ] Notifications/push permissions, deep links, privacy policy, terms, account deletion/data request, contact/support details और Play Store listing assets का release checklist अलग पूरा करें।
- [ ] Customer का छह-category picker live submit से पहले Backend canonical IDs contract से जुड़ना चाहिए; legacy electrical service dropdown हटाना अभी असुरक्षित है।
- [ ] Quote workflow अभी legacy Backend lifecycle/payment gate से जुड़ा है; quote-free lifecycle deploy होने से पहले quote screens/actions न हटाएँ।
- [ ] इस audit में कोई screen, route, navigation, API या runtime code नहीं बदला। Flutter tests/analyzer/formatter/Android build/device testing execute नहीं हुई।

**निष्कर्ष:** वर्तमान mobile apps में मुख्य सुविधाएँ एक-एक dashboard screen पर हैं; यह पूर्ण multi-screen Play Store app होने का प्रमाण नहीं है। अगला कदम owner-approved minimum screen map और missing release requirements तय करना है।


## Owner correction — commission base clarified (21-11-2026)
**Controlling rule:** 15% commission is charged only on service charge/labour; Technician receives 85% of service charge/labour. Materials/parts carry 0% company commission/platform fee and remain outside the commission base. Example: ₹600 labour + ₹400 materials → ₹90 company commission, ₹510 technician labour share, ₹400 materials separately. This supersedes earlier full-payment commission wording in this document. No live payment code is changed by this documentation correction.


## 2AM. Commission rate/default और legacy payout trigger audit (21-11-2026)

- [x] Feature-branch migration `20261109_electrician_inspection_quotes_and_service_only_commission.sql` में `srk_calculate_booking_commission()` paid + completed booking पर `round(service_charge * commission_rate / 100, 2)` निकालता है; `materials_amount` सीधे formula में नहीं है।
- [x] Base schema snapshots `SUPABASE_SCHEMA.sql` और `COMPLETE_DATABASE_SETUP.sql` में `commission_rate` default 15.00 और 0–100 constraint दिखता है।
- [ ] Default 15.00 से यह सिद्ध नहीं होता कि हर existing/production booking पर persisted commission_rate 15 है। Historical rows और live production values की read-only reconciliation बाकी है।
- [ ] Root legacy `PORTAL_SCHEMA.sql` में पुराना trigger `quoted_amount * commission_rate / 100` करता है; वह labour + materials total को commission base बना सकता है। यह legacy snapshot है, वर्तमान deployed trigger का प्रमाण नहीं; deployed trigger/function definition की पुष्टि जरूरी है।
- [ ] एक अलग source-only branch की 18-Nov financial-visibility migration earnings view में immutable labour bill से provisional 15%/85% निकालती है, लेकिन existing commission/payout triggers को rewrite नहीं करती। इसलिए उस source migration का होना actual paid commission trigger का प्रमाण नहीं है; current approved feature branch में file उपलब्ध भी नहीं थी।
- [ ] Final acceptance test: service ₹600 + materials ₹400, rate 15% → company commission ₹90; technician labour share ₹510; materials ₹400 पर commission ₹0। साथ में 0/negative/legacy rate, cash, Razorpay, partial/full refund और duplicate webhook cases।
- [ ] No production query, SQL execution, migration, payout or payment mutation performed. Runtime code unchanged.


## 2AN. Production Supabase — commission और payout का read-only सत्यापन (21-11-2026)

- [x] Supabase project `Srk electranic` (ACTIVE_HEALTHY, primary project) पर केवल SELECT/catalog introspection की गई; कोई SQL write, migration, payment या payout action नहीं किया।
- [x] Active `guard_new_booking()` BEFORE INSERT trigger नई booking पर `commission_rate := 15.00` और `commission_amount := null` force करता है; client-supplied rate स्वीकार नहीं होता।
- [x] Active `srk_calculate_booking_commission()` trigger paid + completed booking पर `round(service_charge * commission_rate / 100, 2)` लगाता है; materials formula में नहीं हैं।
- [x] Active `srk_create_electrician_payable()` payout trigger `v_commission := round(service_charge * commission_rate / 100, 2)` और `electrician_payable := service_charge + materials_amount - commission` बनाता है। इसलिए materials पर 0% company commission और materials का पूरा amount Technician payable में शामिल है।
- [x] Live aggregate snapshot: service_bookings = 1 row, commission_rate 15.00 = 1 row, paid+completed = 1; payout ledger = 1 row, paid payout = 1।
- [x] उस snapshot में paid booking commission formula mismatch = 0, missing inputs = 0; payout commission mismatch = 0; payout payable formula mismatch = 0।
- [ ] नमूना बहुत छोटा है (केवल 1 booking/1 payout); इससे सभी भविष्य की bookings या historical population का व्यापक प्रमाण नहीं मिलता।
- [ ] Risk: commission trigger की UPDATE OF सूची में `service_charge` शामिल नहीं है (status, payment_status, amount_paid, commission_rate हैं)। यदि paid+completed booking का service_charge बाद में अलग update हुआ, commission_amount stale रह सकता है; payout trigger की सूची में service_charge/materials_amount शामिल हैं। इसे अलग backend fix के रूप में review करें, बिना अभी production बदलें।
- [ ] Example acceptance: ₹600 service + ₹400 materials → company ₹90; Technician payable ₹510 + ₹400 = ₹910; customer total ₹1,000। No materials commission.
- [x] Legacy `PORTAL_SCHEMA.sql` का quoted_amount formula active production trigger नहीं है; active trigger metadata से service_charge-only formula मिला।
- [x] No production mutation. No migration/deployment. Source/docs only.


## 2AO. Commission trigger coverage — सुधार प्रस्ताव

- [x] Production trigger issue documented: commission function uses service_charge, but trigger UPDATE OF list omits service_charge.
- [ ] New migration via Supabase CLI generator; include service_charge in UPDATE OF list.
- [ ] TEST project regression test; verify commission and payout ledger.
- [ ] Production deployment only after separate approval.
- No SQL file/code or database was changed in this step.


## 2AO. Commission trigger fix — TEST readiness और execution gate (21-11-2026)

- अलग `SRK ELECTRONIC TEST` Supabase project उपलब्ध और ACTIVE_HEALTHY है।
- Supabase CLI उपलब्ध terminal इस कार्य-सत्र में नहीं है; इसलिए `supabase migration new` चलाकर timestamped migration बनाना संभव नहीं हुआ।
- Migration file manually नहीं बनाई गई; TEST या Production database में कोई SQL/DDL execute नहीं किया गया।
- अगला कदम: approved repository terminal में CLI से migration generate करें, source review करें, फिर केवल TEST project पर apply करके service_charge-only recalculation, materials-only no-change, payment/status/rate regression और payout side effects जाँचें।
- Production बदलाव के लिए अलग explicit approval अनिवार्य है।


## 2AP. TEST database schema audit — commission test blocked (21-11-2026)

- [x] TEST project पर read-only catalog inspection किया गया।
- [x] `public` schema में केवल `electrician_profiles`, `job_offers`, `srk_push_subscriptions` मिलीं।
- [x] `service_bookings`, commission/service_charge/material columns और संबंधित booking/ledger/payout triggers नहीं मिले।
- [x] Migration history में 7 versions मिले; वर्तमान booking backend की पूरी schema chain मौजूद होने की पुष्टि नहीं हुई।
- [ ] Commission Migration से पहले TEST में approved branch की पूर्ण migration baseline सुरक्षित तरीके से स्थापित/सत्यापित करें।
- [ ] Baseline के बाद ही trigger source audit और commission/payout regression tests करें।
- [x] इस निरीक्षण में कोई DDL/DML, payment/payout परिवर्तन या Production SQL नहीं किया गया।
- [ ] Remote TEST पर `db reset --linked` का उपयोग नहीं करना है; यह destructive है।


## 2AQ. Customer dashboard — partial data-load errors visible (21-11-2026)

- [x] Booking list load failure और missing OTP session के लिए अलग user-facing संदेश जोड़ा।
- [x] Technician contact RPC failure अब silent नहीं है; booking cards फिर भी render होते हैं और Refresh का संदेश दिखता है।
- [x] Complaint list RPC failure अब silent empty-list की तरह नहीं दिखता; पिछली loaded complaint list सुरक्षित रहती है और warning दिखती है।
- [x] Refresh पर warnings reset होती हैं; successful RPC response warning हटाता है।
- [x] Existing booking SELECT, cancellation, quote/payment RPC, form payload और booking lifecycle नहीं बदले।
- Source: `apps/customer_app/lib/main.dart`, commit `7b48352e5cdfb296d3668e2bd6965ab2c72c8f2c`.
- [ ] Flutter format/analyzer/widget tests और Android build चलाना बाकी है; इस environment में ये execute नहीं हुए।


## 2AR. Production commission trigger — fresh read-only check (21-11-2026)

- [x] Active commission trigger में `service_charge` UPDATE dependency missing है; commission function service_charge × persisted rate / 100 ही करता है।
- [x] Payout trigger service_charge/materials_amount updates पर चलता है; pending payout को update करता है, paid payout को upsert filter से overwrite नहीं करता।
- [x] Aggregate-only check: 1 completed+paid booking, rate 15%; 1 paid payout; उस single payout पर service-only 15% formula match, booking-vs-payout commission mismatch 0।
- [ ] केवल एक live row का snapshot है; historical population reconciliation और paid amount edits के लिए Admin-audited reconciliation guard अभी बाकी है।
- [ ] TEST schema baseline incomplete होने के कारण trigger migration/test अभी blocked है; Production पर कोई DDL/DML नहीं हुआ।

## 2AS. Customer dashboard partial-load UX fix (21-11-2026)

- [x] Contact RPC failure अब स्पष्ट warning दिखाता है, booking list फिर भी दिखाई जाती है।
- [x] Complaint RPC failure अब empty complaint list जैसा गलत संकेत नहीं देता; warning दिखती है और पहले से loaded list रखी जाती है।
- [x] Missing auth session पर दोबारा OTP login का संदेश।
- [x] Source commit: `7b48352e5cdfb296d3668e2bd6965ab2c72c8f2c`.
- [ ] Flutter format/analyzer/widget test/Android build/device QA अभी बाकी; execute नहीं हुए।


## 2AT. Technician dashboard — optional data source failures isolated (21-11-2026)

- [x] Offer price/quote details RPC failure अब पूरे dashboard को बंद नहीं करता; अलग warning दिखती है।
- [x] Assigned booking customer-contact RPC failure पर booking details दिखाई देती हैं; contact warning अलग है।
- [x] Earnings और wallet RPC failures अब independent warnings हैं; offers और assigned bookings की उपलब्ध जानकारी दिखाई जाती है।
- [x] Core profile/offers/assigned-booking load failures अभी भी main dashboard error दिखाते हैं; core data silently fabricate नहीं होती।
- [x] Refresh पर warnings reset होती हैं।
- Source: `apps/electrician_app/lib/main.dart`, commit `c902d9687d67dcb5a11476fb2928ae98a1b01497`.
- [ ] Flutter format/analyzer/widget tests और Android build/device QA अभी execute नहीं हुए।


## 2AU. TEST migration history — approved branch version mismatch (21-11-2026)

- [x] Approved branch में 21 SQL migration files की सूची जाँची।
- [x] TEST migration history में 7 version IDs जाँचे।
- [x] TEST के 7 version IDs में approved branch की 21 migration filenames से कोई exact version match नहीं मिला।
- [x] इसे TEST baseline reconciliation blocker के रूप में दर्ज किया; कोई migration apply/repair नहीं की।
- [ ] Supabase CLI वाले approved repository environment में migration-by-migration reconciliation और सुरक्षित baseline योजना बनानी है।
- [ ] Reset या blind re-apply नहीं करना; Production untouched।


## 2AV. Android CI build readiness (21-11-2026)

- [x] CI workflow reviewed: `.github/workflows/flutter-android-ci.yml`.
- [x] Workflow is configured for manual `workflow_dispatch` only; it checks backend configuration, analyzes/tests shared core and both apps, then builds debug APKs.
- [x] Required GitHub Actions configuration names verified from workflow: Variables `SUPABASE_URL`, `SRK_API_BASE_URL`; Secret `SUPABASE_ANON_KEY`. Values are not read or exposed here.
- [ ] No workflow run/build artifact is available as verification for the latest app commits. Current connected GitHub actions do not provide a workflow-dispatch operation, so CI was not triggered from this session.
- [ ] User/repository maintainer must manually run the workflow on approved feature branch and review analyzer, tests and both APK outputs before any Play Store release claim.
- [ ] Debug APK build is not a Play Store release build; signing, release configuration, privacy/data safety review and device QA remain separate release gates.


## 2AW. Owner-provided official brand images and screen reference (21-11-2026)

- [x] इस वार्तालाप में मिली पहली image को Founder portrait, दूसरी image को SRK ELECTRONIC logo और तीसरी image को Customer/Technician app screen reference के रूप में पहचाना।
- [x] मौजूदा UI audit: shared `SrkWelcomeHeader` login/welcome header में उपयोग होता है; `SrkFounderBanner` दोनों dashboards में मौजूद है। Shared founder banner अभी `packages/srk_mobile_core/assets/founder.webp` asset पढ़ता है।
- [x] Customer dashboard में founder banner पहले से है; Technician dashboard में भी founder banner है। Technician OTP login में shared welcome header है।
- [ ] तीसरी reference image के अनुसार branded welcome/home/dashboard layout polish करना है; booking lifecycle, booking form, payment actions, navigation और existing working booking system को न बदलें।
- [ ] Logo image को shared header/banner में शामिल करना है; app launcher icon/splash treatment भी इसी logo और brand palette से align करना है।
- [ ] इस सत्र में uploaded binary images को Git repository में सीधे transfer/commit करने का supported path उपलब्ध नहीं हुआ। इसलिए नई images को assets के रूप में जोड़ने या मौजूदा `founder.webp` को बदलने का दावा नहीं किया गया; current asset को बिना पुष्टि overwrite नहीं किया।
- [ ] अगला asset step: uploaded Founder portrait और logo को repository में `packages/srk_mobile_core/assets/` में क्रमशः `founder.webp` और `srk_logo.webp` के रूप में जोड़ें; उसके बाद pubspec/header में logo wire-up और visual QA करें।
- [ ] Third image is a visual reference/mockup, not a production screen asset; use it to guide layout, not as a full-screen screenshot.


## 2AX. Owner brand image files prepared (21-11-2026)

- [x] User-provided Founder portrait optimized as WebP at 1200×1108.
- [x] User-provided SRK ELECTRONIC logo and Hindi tagline optimized as WebP at 1400×933.
- [x] Prepared ZIP bundle with repository target paths: `packages/srk_mobile_core/assets/founder.webp` and `packages/srk_mobile_core/assets/srk_logo.webp`.
- [ ] Binary ZIP/image upload into GitHub repository is not supported by the connected repository file-write action in this session; files have not yet been committed to the branch.
- [ ] After adding assets to branch, verify Founder portrait displays in existing banner, add logo to shared welcome header and dashboard brand area, then run Flutter tests/build and device visual QA.
- [ ] Existing app currently references `packages/srk_mobile_core/assets/founder.webp`; do not replace/assume the checked-in file changed until the prepared asset is committed and visually checked.

## 2AY. Owner clarification — Customer booking sequence (21-11-2026)

**यह Founder का नवीनतम स्पष्ट निर्देश है।** पहले से मौजूद सही booking system को आधार बनाकर इसी क्रम में booking UI व्यवस्थित करें; मौजूदा booking lifecycle, API/backend, payment और पुराने records को बिना अलग review/approval बदले नहीं।

- [ ] Login पर ग्राहक मोबाइल नंबर दर्ज करके OTP verify करे।
- [ ] पहली सफल verification के बाद ग्राहक का नाम लेकर सुरक्षित करें; नाम पहले से उपलब्ध हो तो दोबारा अनावश्यक रूप से न पूछें।
- [ ] नाम save होने के बाद Customer Home खोलें; Home पर छह service categories दिखाई दें।
- [ ] ग्राहक category चुने; चुनी category के अनुसार उसके task/service विकल्प खुलें (उदाहरण: Electrician → Wiring या Repairing)।
- [ ] Task चुनने के बाद लागू होने पर कितने Electrician और कितने Helper चाहिए, उनकी संख्या चुनने दें।
- [ ] लागू service के लिए duration चुनने दें: घंटे से लेकर अधिकतम 50 दिन तक। Fixed-price tasks में लागू न होने पर duration control न दिखाएँ।
- [ ] चुने गए task, technician/helper संख्या और duration के आधार पर उपलब्ध Admin-approved rate से amount अपने-आप calculate करके ग्राहक को दिखाएँ।
- [ ] Amount summary के बाद work address का चरण आए; GPS से address auto-fill वैकल्पिक सुविधा हो और manual address entry भी उपलब्ध रहे।
- [ ] OTP से verified mobile number booking में login session से स्वतः आए; booking form में ग्राहक से वही phone number दोबारा न भरवाएँ।
- [ ] Address और बाकी आवश्यक विवरण पूरे होने के बाद ग्राहक BOOK NOW/booking submit करे; success केवल backend-confirmed booking ID/status मिलने पर दिखे।
- [ ] Existing booking form, dispatch और lifecycle का regression test करें; यह क्रम लागू करते समय पहले से काम कर रही booking functionality न टूटे।
- [ ] Rates/worker limits/task applicability backend/Admin-approved contract से verify करें; कोई rate, helper fee या operational capacity अनुमान से न जोड़ें।

**Scope clarification:** इस तारीख के Founder निर्देश से category → task → electrician/helper count → duration (जहाँ लागू) → automatic amount → address → booking submission वाला customer flow वर्तमान frontend checklist में शामिल है। पहले के “future-only” नोट को इस स्पष्ट booking-flow निर्देश के विरुद्ध लागू न करें; फिर भी इस दस्तावेज़ी बदलाव से कोई backend/database/payment implementation स्वतः अधिकृत नहीं होती।

## 2AZ. Owner scope correction — पुराने booking form का replacement और gap audit (21-11-2026)

**नवीनतम Founder निर्देश पुराने booking form को बनाए रखने वाला नहीं है।** पुराने booking form का flow हटाकर नीचे दिया नया customer booking flow मुख्य और एकमात्र नया-booking entry flow होगा। पुराने सिस्टम की केवल वे सुविधाएँ/तकनीकी हिस्से रखे जाएँ जो नए flow में उपयोगी और API contract के अनुकूल हों। यह पुराने booking records/history को delete करने की अनुमति नहीं है।

### A. वर्तमान source में मिला पुराना booking form — audit
- [x] `apps/customer_app/lib/main.dart` में `CustomerBookingFormPage` पुराना form है; यह OTP session check के बाद `/api/create-booking` endpoint को submit करता है।
- [x] पुराने form में customer name, OTP-linked phone (read-only), state, district, PIN code, full address, optional GPS coordinates, work details, payment method, preferred date और preferred time fields हैं।
- [x] पुराने form में अलग पुराना Electrical service dropdown (`Electrical Wiring`, fan, switch/socket, light, MCB, inverter, appliance repair, other) अभी भी mandatory है।
- [x] उसी form में नया छह-category `SrkServiceCategoryPicker` भी दिखता है, लेकिन code साफ कहता है कि यह preview-only है; selection पुराने `_service` field/booking payload को replace नहीं करता।
- [x] पुराने form में नया category selection backend को भेजा नहीं जाता; submit payload अभी पुराने `service_type` string को भेजता है।
- [x] पुराने form में automatic rate/amount calculation, technician count, helper count और 1-hour-to-50-day duration selection implemented नहीं हैं।
- [x] वर्तमान category picker और shared catalogue में छह top-level categories तथा category/subcategory/task selection का draft source/test मौजूद है; IDs को code स्वयं draft/local proposal बताता है, deployed canonical backend IDs नहीं।
- [x] Customer dashboard में booking history/list, refresh, cancellation action, complaint/support flow, technician contact display और Razorpay order/payment verification code मौजूद है; इन्हें नए form replacement के दौरान बिना जरूरत न हटाएँ।
- [x] Booking success UI backend response में success और booking ID मिलने के बाद दिखती है; यही server-confirmed success principle नए form में सुरक्षित रखना है।
- [ ] पुराने `/api/create-booking` endpoint का नए category/task/team/duration/rate/address payload स्वीकार करना, server-side validation, canonical ID mapping और dispatch compatibility Backend owner से verify करें।
- [ ] पुराने quote/inspection/payment state dependencies का backend contract audit करें; quote UI/lifecycle को केवल safe backend transition तय होने पर हटाएँ। पुराने booking records को read-only history में सुरक्षित रखें।

### B. नया Customer booking flow — controlling sequence
- [ ] Login: mobile number + OTP verification।
- [ ] पहली सफल login पर customer name save; पहले से saved name को दोबारा अनावश्यक रूप से न पूछें।
- [ ] Home पर छह categories।
- [ ] Category चुनने पर केवल उसी category के applicable subcategory/task choices।
- [ ] Task के बाद जहाँ लागू हो technician/electrician count और helper count।
- [ ] जहाँ hourly/day-based service लागू हो वहाँ duration: 1 hour से अधिकतम 50 days; fixed-price tasks में duration control न दिखे।
- [ ] Selected category/task, skill/rate, worker/helper count और duration के आधार पर approved rate से amount auto-calculate और स्पष्ट price summary।
- [ ] Amount summary के बाद work address: GPS auto-fill optional + manual full address; current GPS और work address को एक न मानें।
- [ ] Verified phone login session से स्वतः; booking form में phone दोबारा type/edit न करवाएँ।
- [ ] आवश्यक जानकारी जाँचने के बाद BOOK NOW; success केवल backend-confirmed booking ID/status पर।
- [ ] पुराना electrical-only mandatory dropdown, पुराना duplicate service selection और preview-only warning नए form में नहीं रहने चाहिए।
- [ ] नया flow सभी छह categories और हर लागू task के लिए end-to-end tested हो।

### C. पुराने सिस्टम से क्या रखना है / क्या बदलना है
**रखना और नए flow में फिर से उपयोग करना (compatibility review के बाद):**
- [ ] OTP-authenticated Supabase session और verified phone identity।
- [ ] Customer name profile/session से लेना और जरूरत पड़ने पर पहली बार save करना।
- [ ] State, district, PIN code, full work address तथा optional GPS capture।
- [ ] काम के बारे में optional extra instructions/notes।
- [ ] Backend-confirmed booking submission, error handling, retry-safe/duplicate-submit protection और booking ID confirmation।
- [ ] Existing booking history, booking details/status, refresh, cancellation rules, complaint/support, technician contact, payment status/receipt और verified Razorpay flow।
- [ ] Existing materials/parts itemization और customer approval rule; materials पर platform commission 0%।
- [ ] Existing secure API authentication; service-role key app में नहीं लाना।

**पुराने नए-booking UI से हटाना/replace करना:**
- [ ] पुराना electrical-only `_services` dropdown और उससे जुड़ा mandatory `_service` validation।
- [ ] पुराने `service_type` free/legacy label को नए canonical category/subcategory/task identity से replace करना; API contract मिलने तक इसे live submit न करें।
- [ ] Form के ऊपर preview-only category picker + नीचे पुराने form का दोहरा selection हटाकर एक integrated category-to-task selection।
- [ ] पुराने fixed preferred date/time को नए duration-based flow के साथ reconcile करें; actual booking start/schedule field तभी रखें जब owner-approved flow और backend contract इसकी जरूरत बताए।
- [ ] Customer name/phone को हर booking में फिर से भरने के बजाय verified account से auto-populate; phone read-only/hidden, name saved profile से।
- [ ] Amount summary को अनुमानित static text से नहीं, approved rate calculation से दिखाएँ।

### D. अभी स्पष्ट रूप से missing / blocked — अनुमान नहीं लगाना
- [ ] हर category के subcategory/task का final owner-approved catalogue और canonical backend IDs।
- [ ] किस service में skill level, electrician count, helper count और duration लागू है; fixed-price vs hourly/day-based task mapping।
- [ ] प्रत्येक combination की Admin-approved rates, minimum/maximum worker limits, helper rate और rounding rule।
- [ ] 50-day duration का unit/selection UX, overnight/day boundary, break/lunch/overtime और multi-day schedule behavior।
- [ ] Backend API/RPC payload/response contract: category/task IDs, worker/helper count, duration, price snapshot, address/GPS, booking idempotency key, booking ID/status।
- [ ] Multi-worker dispatch, capacity, sequential offers और partial assignment/failure behavior की backend पुष्टि।
- [ ] Booking payment कब देय होगा और नया price estimate बनाम final labour/material amount कैसे दिखेगा; Razorpay को केवल verified server order/confirmation के साथ रखें।
- [ ] Existing backend status/quote dependency का quote-free नई booking के लिए सुरक्षित विकल्प और legacy bookings के लिए अलग read-only behavior।
- [ ] सभी gaps clear होने के बाद old form replace करें; फिर Flutter tests, analyzer, Android build और वास्तविक mobile visual/flow QA चलाएँ।

**इस audit का परिणाम:** वर्तमान source में नया category picker मौजूद है, लेकिन अभी पुराना form ही वास्तविक booking submit करता है। इसलिए काम केवल पुराने form के कुछ fields बदलना नहीं है; पुराने mandatory electrical dropdown और preview-only picker को हटाकर पूरे booking entry flow को नए sequence से बनाना होगा। उपयोगी auth/address/GPS/submit/history/support/payment capabilities को अलग से सुरक्षित रखना है। इस documentation update में app code, backend, database, API, payment या पुराने records नहीं बदले गए।



## 2BA. Booking API contract audit — current backend compatibility (21-11-2026)

### Existing `create-booking.js` verified behavior
- [x] Endpoint requires POST and checks the Supabase configuration server-side.
- [x] Endpoint enforces public booking rate limiting before processing the request.
- [x] Endpoint verifies the Supabase Bearer session, requires `phone_confirmed_at`, and checks that the submitted 10-digit booking phone matches the verified account phone.
- [x] Current required request fields are: `customer_name`, `phone`, `state`, `district`, `pincode`, `address`, `service_type`, `preferred_date`, and `preferred_time`.
- [x] Optional accepted fields include `location_lat`, `location_lng`, `work_details`, `payment_method`, `quoted_amount`, and `customer_suggested_amount`.
- [x] Current insert targets `service_bookings`, sets `status: "new"` and `payment_status: "unpaid"`, and associates `customer_user_id` from the verified session.
- [x] Dispatch currently relies on the database `broadcast_new_booking` trigger; the function reads the resulting `job_offers` and returns `booking_id`, offer count, match level and a server message.
- [x] API does not currently read or validate `catalogue_version`, `category_id`, `subcategory_id`, `task_id`, electrician count, helper count, duration, rate calculation or a server price snapshot.
- [x] API requires a preferred date and time; a duration-only request from the new flow will not satisfy current validation.
- [ ] Do not send the draft selection contract to this API and assume it is supported: current API ignores those fields and still requires legacy `service_type` plus date/time.
- [ ] Before connecting the new UI, backend owner must define and approve the versioned request/response contract, authoritative catalogue IDs, rate/price snapshot, team/duration validation, scheduling semantics and dispatch handling.
- [ ] Preserve current auth, rate limiting, server-only credentials, database trigger dispatch and booking success confirmation when backend contract is deliberately upgraded.
- [ ] Test idempotency/duplicate-submit behavior end-to-end; this handler's source does not itself show an Idempotency-Key check, so do not claim API-level idempotency until verified in the database/API path.

**Audit conclusion:** The existing endpoint is secure-session-aware and already creates legacy bookings/offers, but it is not compatible with the newly requested structured category/task + team size + duration + automatic pricing payload. A frontend-only switch would either fail validation or create incomplete legacy bookings. Therefore the next safe implementation stage is to design the integrated customer UI against an explicit API contract, while keeping submit disabled/not connected until the backend contract is approved. No API, database, payment, or app source code was changed in this audit.


## 2BB. Owner clarification — skill-matched technician selection (21-11-2026)

**नवीनतम Founder निर्देश:** ग्राहक पहले service category और उसके बाद उसी category का काम/task चुनेगा। इसके बाद केवल उस काम के लिए योग्य और उपलब्ध Electrician/Technician विकल्प दिखाए जाएँ।

- [ ] Category → task चयन के बाद eligible technician list दिखाएँ; unrelated category या task के technician को सूची में न दिखाएँ।
- [ ] Technician profile/card में पहले से निर्धारित सभी विशेषताएँ, verified skills, वह कौन-कौन से काम कर सकता है, अनुभव और अन्य मौजूदा approved profile details सुरक्षित रखें और दिखाएँ।
- [ ] मौजूदा technician skills/verification fields या profile attributes को हटाएँ, rename करें या संकुचित न करें; पहले source/data mapping audit करें।
- [ ] Eligibility केवल verified/admin-approved skills और चुने हुए task की mapping पर आधारित हो; केवल profile text या self-declared skill से qualification न मानें।
- [ ] यदि किसी task के लिए कोई योग्य/उपलब्ध technician नहीं है, तो स्पष्ट unavailable state दिखाएँ; गलत व्यक्ति को विकल्प के रूप में न दिखाएँ।
- [ ] Customer द्वारा technician चुनने का विकल्प केवल तभी लागू करें जब dispatch/backend contract इसे सुरक्षित रूप से support करे; अन्यथा मौजूदा eligible dispatch behavior बनाए रखें।
- [ ] Existing booking history, profile, skill verification, availability, dispatch and assignment behavior का regression test करें।

**सीमा:** यह requirement frontend checklist में दर्ज है। मौजूदा API/dispatch contract और technician skill data की जाँच के बिना backend eligibility logic या assignment behavior न बदलें।


## 2BC. Owner correction — booking selection order: category → skill level → capabilities → task (21-11-2026)

**यह निर्देश 2BB के क्रम को स्पष्ट/सुधारता है।** ग्राहक पहले task नहीं चुनेगा और task के आधार पर technician list से शुरुआत नहीं होगी।

नया customer selection क्रम:

1. ग्राहक छह मुख्य service categories में से category चुनेगा (उदाहरण: Electrician या Plumber)।
2. चुनी हुई category के अंदर उसके उपलब्ध skill levels दिखेंगे: **Basic, Expert, Master** (जहाँ उस category में ये levels स्वीकृत हैं)। उदाहरण के लिए Electrician के अंदर तीन स्तर और Plumber के अंदर तीन स्तर।
3. ग्राहक Basic / Expert / Master में से अपना स्तर चुनेगा।
4. चुने हुए स्तर की पूरी approved विशेषताएँ/profile विवरण दिखेंगे।
5. उसी स्तर के व्यक्ति को कौन-कौन से काम आते हैं, उसकी पूरी approved skills/task list दिखाई जाएगी; कोई मौजूदा विशेषता या काम हटाया/छिपाया नहीं जाएगा।
6. ग्राहक दिखाई गई सूची में से अपना आवश्यक काम/task चुनेगा।
7. इसके बाद उसी चुने हुए category + skill level + task के अनुसार लागू helper choice, duration/quantity, rate/amount summary, address और booking steps आगे चलेंगे।
8. बुकिंग/dispatch केवल चुने हुए स्तर और task के लिए पात्र, verified और उपलब्ध technician तक ही जाएगी। किसी दूसरे level या असंबंधित skill वाले व्यक्ति को उस booking के लिए न दिखाएँ/assign करें।

- [ ] UI navigation और state model को इसी क्रम में लागू करें: category → skill level → capability/profile → task → बाकी booking विवरण।
- [ ] Existing category, skill-level, technician-profile, verified-skills और task data का mapping audit करें; कोई feature/attribute delete या simplify न करें।
- [ ] AC + Fridge, Motor & Pump, Cooler जैसी categories में जहाँ Basic/Expert/Master स्तर लागू नहीं हैं, वहाँ मनमाने स्तर न बनाएँ; उनके स्वीकृत category-specific विकल्प ही दिखाएँ।
- [ ] Booking payload और dispatch eligibility इस क्रम के सभी selected IDs/verified skill relationships को backend contract से validate करें; contract upgrade के बिना live submit/dispatch behavior न बदलें।

**यह 2BB की पहले लिखी category → task → technician-list वाली व्याख्या को supersede करता है।** 2BB की profile विशेषताएँ और verified skill संरक्षण की शर्तें लागू रहेंगी।


## 2BD. Owner clarification — Electrician rate-list visibility and overtime (21-11-2026)

**नवीनतम Founder निर्देश:**

- [ ] Electrician की rate list में सभी छह service categories की लागू rates दिखाई जाएँ।
- [ ] हर rate को 8 घंटे के काम के आधार पर दिखाएँ; electrician को केवल उसका payable **85% हिस्सा** दिखे।
- [ ] Electrician की सामान्य rate list/profile में कंपनी का 15% हिस्सा या उसका अलग commission amount न दिखाएँ।
- [ ] Rate list के ऊपर स्पष्ट सूचना रहे: **“ओवरटाइम: 8 घंटे के बाद प्रति अतिरिक्त घंटा सामान्य लागू दर का 1.5 गुना (डेढ़ गुना)”**।
- [ ] Overtime rate भी electrician को मिलने वाले हिस्से के रूप में प्रदर्शित हो; rate calculation approved service rate और 85% technician share के अनुरूप हो। कोई नई/अनुमानित rate न बनाएँ।
- [ ] काम पूरा होने पर final work/accounting detail में पूरा हिसाब दिखे: कुल काम के घंटे, पहले 8 घंटे का हिसाब, 8 घंटे के बाद के overtime घंटे और दर, electrician का 85% हिस्सा, कंपनी का 15% हिस्सा तथा लागू अन्य मदें अलग-अलग।
- [ ] Fixed-price tasks पर overtime लागू न करें, जब तक उस task के लिए अलग approved rule न हो।
- [ ] छहों categories की 8-hour payable rates और overtime payable rates को approved catalogue/backend rate snapshot से लें; जहाँ rate या overtime applicability स्पष्ट/स्वीकृत नहीं है वहाँ अनुमान न दिखाएँ।
- [ ] Customer-facing gross price, technician-facing 85% payable rate और completion-time full accounting को अलग-अलग views/permissions में रखें। Technician को completion accounting से पहले company share expose न करें।
- [ ] Rounding, helper inclusion, fixed-price exceptions और overtime base-rate calculation backend contract से verify करें; frontend में commission/payment calculation स्वयं authoritative न बनाएँ।

**सीमा:** यह display/accounting requirement है। इसे checklist में दर्ज करने से live rate calculation, wallet credit, commission settlement, payment flow या backend contract नहीं बदलता। Implementation से पहले छह categories के 8-hour gross rates, 85% display values और overtime calculation basis का approved rate snapshot सत्यापित करना होगा।


## 2BE. Electrician app implementation audit — onboarding, approval, wallet and rate visibility (21-11-2026)

### Current Flutter source findings
- [x] `apps/electrician_app/lib/main.dart` already has mobile OTP login and an authenticated dashboard.
- [x] Dashboard currently loads an existing `electrician_profiles` row and existing offers, assigned bookings, earnings and wallet summary.
- [x] When no profile row exists, the current UI shows a profile-link/approval message; it does **not** provide the requested full application form.
- [x] Current dashboard derives Active from `verification_status == 'approved' && active == true`; preserve this server-authoritative gate.
- [x] Current profile query only reads `id, display_name, state, district, pincode, active, verification_status`; it does not currently display the full approved profile, a Technician ID label, or a complete verified skill checklist.
- [x] Existing wallet UI is read-only summary via `srk_get_my_wallet_summary`; it does not implement technician-initiated UPI/bank top-up or verification.
- [x] Existing earnings/quote detail UI can expose service/material amounts and quote details before the completion accounting view; audit and separate technician-facing 85% rate display from completion-time full accounting.
- [x] Existing electrician application schema in `COMPLETE_DATABASE_SETUP.sql` has `full_name`, `phone`, `state`, `district`, `pincode`, free-text `skills`, `experience_years`, `about`, `verification_status` and `active`; it does not contain the requested mandatory Aadhaar verification state, structured Basic/Commercial/Master skill selections, per-task approval records, or optional document-upload metadata.
- [x] Existing admin approval routine creates/links a profile from the application and keeps the profile inactive initially; retain this approval/activation safety gate.
- [ ] Add the requested application/dashboard/profile UI only against a verified, owner-approved application/KYC/skill contract. The current schema cannot safely persist mandatory Aadhaar verification or structured per-level/per-task selections.
- [ ] Do not collect Aadhaar number/image into an unapproved field, free-text skills string, app logs, or local insecure storage. Aadhaar verification must use an approved secure verification flow/provider and store only the minimum approved verification result/reference.
- [ ] Define secure document upload storage, private access policies, file limits/types, and admin review behavior before enabling uploads.
- [ ] Define structured skill IDs for Electrician → Basic / Commercial / Master → individual tasks, plus admin verification status for each selected task; self-selected tasks must not become dispatch-eligible before admin approval.
- [ ] Define Technician ID source and approved profile fields; do not generate a fake local ID.
- [ ] Define wallet top-up provider/flow and server-verified UPI/bank ownership contract. Do not credit wallet based on a typed UPI ID, bank details, screenshot, or client-side success.
- [ ] Implement technician-visible rate list only from approved six-category rate snapshots, displaying the electrician's 85% payable share and the approved 1.5x overtime share after 8 hours. Do not invent missing rates or expose company commission in the pre-completion rate-list view.
- [ ] At completion, show the server-authoritative full accounting breakdown, including gross service amount, electrician 85%, company 15%, overtime and separately approved material/other items.
- [ ] Gate offers, job acceptance and work actions to server-approved active profile and verified skill/task eligibility; frontend visibility alone is not authorization.
- [ ] Preserve existing OTP, offer response, assigned booking, work status, earnings and wallet summary behavior while implementing the approved onboarding flow.

**Implementation decision:** The current Flutter app is not yet compliant with the newly clarified electrician onboarding flow. A frontend-only form cannot safely complete the requirement because the existing application contract lacks mandatory Aadhaar verification and structured skill/task approval, and the wallet has no verified technician top-up flow. Do not fake submission, KYC, approval, Technician ID, wallet credit, or task eligibility. First prepare the UI against a versioned approved contract; backend/database/payment changes remain outside this frontend branch scope unless separately authorized.


## 2BF. Electrician level catalogue reconciliation — prevent incorrect skill/rate mapping (21-11-2026)

### Owner-approved UI level names
- Electrician skill selection must present exactly these three top-level levels: **Basic, Commercial, Master**.
- Each level must expand to its own complete task checklist. Electrician selects every task they can perform; selected tasks remain self-declared until Electric Admin verifies them and approves them individually (or approves an explicitly defined verified group).
- Customer-facing Electrician selection must use only admin-approved level + task combinations. The customer's selected task must match an active electrician's approved skill/task mapping.

### Existing catalogue mismatch found during source audit
- Current `packages/srk_mobile_core/lib/srk_service_catalog.dart` lists Electrician rate levels as **Basic, Expert Residential, Factory / Large Project, Master** (four entries), which does not match the owner's latest three-level naming.
- Do not silently rename, merge, discard, or reassign the existing Expert Residential / Factory-Large Project rates to Commercial. Their intended mapping and the Commercial 8-hour base rate must be confirmed against the approved rate schedule before displaying or calculating a Commercial rate.
- Do not invent missing task lists for Basic / Commercial / Master. First map every existing Electrician task to the intended level(s) and retain all existing task capabilities; if a task is approved for more than one level, represent that explicitly.
- Electrician's technician-facing rate list must show the approved 85% payable amount for each applicable category on an 8-hour basis and 1.5x overtime after 8 hours, only where the underlying approved rate and overtime basis are known. Never expose the company's 15% in the pre-completion rate-list view.

### Safe implementation sequence
- [ ] Reconcile the three owner-approved level names with the four legacy catalogue rate entries without losing any approved rate or capability.
- [ ] Build a complete level → task checklist from approved task data; no guessed or blank placeholder tasks presented as real skills.
- [ ] Store selected skills as structured IDs only after an approved backend contract exists; preserve per-task admin verification and activation gates.
- [ ] Display the electrician's 85% 8-hour and overtime rates only from a versioned approved rate snapshot; show full gross/85%/15% accounting only in the authorized completion-time view.
- [ ] Add regression tests for legacy profiles, all three levels, multi-level tasks, admin approval, inactive gating, and rate visibility permissions.

**Scope and safety:** This finding is documentation/audit only. No rate values, task mappings, backend schema, dispatch eligibility, wallet balance, KYC status, or payment behavior were changed. Do not claim the application form or skill workflow is implemented until the secure server contract and UI are both complete.


## 2BG. Service-wise skill-level counts follow the existing catalogue (21-11-2026)

**यह निर्देश 2BF में लिखी गई एक समान तीन-स्तरीय धारणा को स्पष्ट रूप से supersede करता है।** किसी एक सर्विस के उदाहरण को सभी सर्विस पर लागू नहीं करना है। Registration, customer selection और technician profile में हर category के skill-level विकल्पों की संख्या और नाम मौजूदा `srk_service_catalog.dart` से ही लिए जाएँगे।

Current catalogue audit:
- Electrician: 4 existing skill levels — Basic, Expert Residential, Factory / Large Project, Master.
- Plumber: 3 existing skill levels — Basic, Expert, Master / Industrial.
- Painter: 3 existing skill levels — Basic, Expert, Master / Commercial.
- Other service categories: retain their own existing catalogue structure and option counts; do not force them into a shared count.

Implementation rules:
- Read each category's actual `skillLevels` list dynamically; do not hardcode one universal number of levels.
- Preserve all existing level names, rates, helper notes, task options and service-specific differences. Do not rename, merge, remove, duplicate or invent entries.
- Where task-to-level mapping is not explicitly present in the catalogue or approved contract, do not guess it. Keep the existing customer/service selection data intact while recording the mapping gap for later approved work.
- Any new example supplied by the owner explains the intended interaction only; it does not override existing catalogue data unless the owner explicitly requests a catalogue change.
- This correction is a source-of-truth clarification; it does not modify rates, database schema, dispatch rules, payment behavior or production data.


## 2BH. Existing web frontend integration audit — retain catalogue-driven counts (21-11-2026)

Source files inspected on the feature branch:
- `packages/srk_mobile_core/lib/srk_service_catalog.dart`: contains the service categories and each category's own `skillLevels` list. This remains the source of truth for level count, names, rates and helper notes.
- `index.html`: current customer page still has a short legacy service dropdown (घर की वायरिंग, इलेक्ट्रिकल रिपेयर, लाइट / फैन फिटिंग, होम रिपेयरिंग, अन्य) rather than the complete catalogue-driven flow. The current electrician registration form has one generic skills dropdown and sends the application through the legacy WhatsApp flow.
- `electrician.html`: current partner page provides OTP login, dashboard, earnings, wallet summary, job offers and work-status actions; the inspected page does not yet provide the new in-app application/profile skill checklist.
- `netlify/functions/apply-electrician.js`: legacy application API accepts a single free-text `skills` field and stores pending/inactive applications. It has no structured per-category/per-level/per-task selection or Aadhaar verification contract.

Implementation direction:
- Customer and partner UIs must render each category's existing levels from the shared catalogue, not hardcode a common number of levels.
- Preserve the existing OTP, customer booking, electrician offer, quote approval, work-status, earnings and payment paths while replacing only the obsolete selection/application presentation in a staged, tested manner.
- The current legacy application API cannot safely accept mandatory Aadhaar KYC or structured verified skills. Do not send Aadhaar images/numbers through WhatsApp or the legacy API, and do not display an application as submitted/verified unless the secure server workflow confirms it.
- The shared Dart catalogue is currently documented as presentation-only; it is not automatically available to the legacy HTML pages. A tested shared web-compatible catalogue adapter or an approved API response is required before wiring the full dynamic selection flow. Do not manually duplicate partial lists into HTML.
- No source code, database, production settings, booking, payment, or KYC behavior was changed by this audit.

## 2BI. Electrician — Expert Electrician के अंदर दो Wiring विकल्प

Founder की पुष्टि के अनुसार Electrician की service options सूची में **Expert Electrician (एक्सपर्ट इलेक्ट्रीशियन)** parent option रहेगा। उसके अंदर ये दो child options होंगे:

1. **Normal Wiring — नॉर्मल वायरिंग (घर / दुकान):** बिना Helper ₹1,000 प्रति 8 घंटे; Helper सहित ₹1,500 प्रति 8 घंटे।
2. **Project Wiring — प्रोजेक्ट वायरिंग (बड़ी फैक्ट्री / कंपनी / औद्योगिक भवन):** बिना Helper ₹400 प्रति घंटा; Helper सहित ₹550 प्रति घंटा।

- [x] Shared catalogue में parent ID `expert_electrician` और child IDs `normal_wiring`, `factory_large_project_wiring` दर्ज।
- [x] दोनों child options के अपने अलग-अलग approved rates और helper rates दर्ज; किसी एक का rate दूसरे पर लागू नहीं होगा।
- [x] Existing skillLevels — Basic, Expert Residential, Factory / Large Project, Master — और उनकी task lists/rates ज्यों की त्यों रखी गई हैं। यह parent-child service option structure उन चार skill-level entries को merge या rename नहीं करता।
- [ ] Customer UI में Expert Electrician खोलने पर दोनों child options, उनके सही विवरण और अलग rates दिखाना — UI implementation/test बाकी।
- [ ] Booking submit, dispatch eligibility और backend IDs से इन local option IDs को जोड़ना बाकी; यह catalogue/presentation data है, live booking behavior नहीं।

## 2BJ. Owner-approved Electrician — चारों स्तरों की काम सूची (21-11-2026)

Founder ने चारों स्तरों के नमूना कामों को स्वीकार करके सूची में सेव करने को कहा है। Shared catalogue में हर स्तर के `tasks` अलग दर्ज किए गए हैं:

- **Basic:** बल्ब/LED, ट्यूब लाइट, पंखा लगाना/उतारना, स्विच-सॉकेट, होल्डर-बोर्ड, छोटी वायरिंग सुधारना, एक्सटेंशन बोर्ड, डोर बेल, सामान्य खराबी जाँच और छोटे घरेलू इलेक्ट्रिकल काम (10)।
- **Expert Residential:** घर की नई वायरिंग, पुरानी वायरिंग बदलना, MCB/डिस्ट्रीब्यूशन बोर्ड, इन्वर्टर-बैटरी कनेक्शन, अर्थिंग जाँच, खराबी खोजना, मोटर-पंप कनेक्शन, दुकान/ऑफिस वायरिंग और लोड के अनुसार वायर/MCB चयन (9)।
- **Factory / Large Project:** फैक्ट्री की पूरी वायरिंग, बड़ी कंपनी की वायरिंग, औद्योगिक भवन वायरिंग, थ्री-फेज सिस्टम, बड़े डिस्ट्रीब्यूशन पैनल, इंडस्ट्रियल मोटर कंट्रोल पैनल, स्टार-डेल्टा स्टार्टर, ऑटोमैटिक कंट्रोल पैनल, बड़े लोड की खराबी जाँच और प्रोजेक्ट टीम का काम (10)।
- **Master:** बड़े प्रोजेक्ट की योजना/निगरानी, जटिल सिस्टम निरीक्षण, औद्योगिक पैनल की तकनीकी जाँच, बड़े लोड/सप्लाई जाँच, ऑटोमेशन निरीक्षण, इलेक्ट्रिकल ड्राइंग/डिजाइन समझना, सुरक्षा/गुणवत्ता जाँच, टीम प्रबंधन, टेस्टिंग/कमीशनिंग और तकनीकी समस्या समाधान/सुपरविजन (10)।

- [x] चारों मौजूदा skill-level entries को बरकरार रखते हुए प्रत्येक के लिए अलग task list shared catalogue में दर्ज।
- [x] Electrician → Electrical Wiring के अंदर `normal_wiring` और `factory_large_project_wiring` विकल्प catalogue में मौजूद।
- [ ] Customer UI में level चुनने के बाद उसी level की task list दिखाना और Wiring चुनने पर उसके दो विकल्प दिखाना — UI implementation/test बाकी।
- [ ] Technician application में भी चारों स्तरों की अलग task checklist तथा admin द्वारा task-wise verification — secure backend contract/UI implementation बाकी।
- [ ] यह catalogue presentation data है; booking payload, dispatch eligibility, rates, backend schema या production behavior इस commit से नहीं बदले।
- [ ] Factory/industrial/high-load कार्यों के लिए उपयुक्त योग्यता, प्रशिक्षण और सुरक्षित कार्य-प्रक्रिया आवश्यक है।

## 2BL. Timer — मिनट के हिसाब से बिल और Lunch Auto-Resume (21-11-2026)

Founder के नवीनतम निर्देश; पुराने Pause/Resume या timer व्यवहार के उल्लेख से टकराव होने पर यही नियम लागू होंगे:

- [ ] Customer booking के समय चुने गए कारीगर/skill level का केवल प्रति घंटे का रेट दिखे — छोटा/Basic कारीगर हो या बड़ा/Expert/Master कारीगर; 8 घंटे का package amount इस hourly-rate display की जगह न दिखे।
- [ ] Timer वास्तविक काम के मिनट गिने; सेवा शुल्क वास्तविक active minutes के आधार पर निकले, केवल पूरे घंटे के आधार पर नहीं। गणना का आधार: लागू hourly rate ÷ 60 × billable working minutes।
- [ ] सामान्य Pause और Resume बटन/विकल्प नहीं होंगे।
- [ ] Technician के पास **Lunch** बटन होगा। Lunch दबाने पर काम का timer अपने आप ठीक 1 घंटे के लिए रुकेगा।
- [ ] Lunch शुरू होने के 1 घंटे बाद timer अपने आप फिर चालू होगा; Technician को Resume दबाने की जरूरत नहीं होगी।
- [ ] Lunch के दौरान का 1 घंटा billable working minutes में शामिल न हो।
- [ ] Customer और Technician दोनों को timer/status सही दिखे; Lunch शुरू होने और auto-resume होने का समय रिकॉर्ड हो।
- [ ] Lunch auto-resume, app बंद/नेटवर्क बंद होने या device time बदलने पर भी server-authoritative समय से सुरक्षित तरीके से चले; client clock को billing authority न मानें।
- [ ] प्रति-मिनट रकम की rounding/paise policy backend contract से तय और test हो; frontend अनुमान से rounding rule न बनाए।
- [ ] पुराने checklist में मौजूद सामान्य Pause/Resume UI requirements इस नवीनतम Lunch-only नियम से superseded हैं; उन्हें लागू न करें।
- [ ] वास्तविक Customer/Technician Timer UI, server-side minute calculation, Lunch auto-resume और boundary tests अभी implementation/test के लिए बाकी हैं।

## 2BK. Work Timer — केवल प्रति घंटे का रेट दिखाना (21-11-2026)

Founder के निर्देश के अनुसार काम के live Timer के पास किसी भी wiring विकल्प में 8 घंटे का package amount नहीं दिखेगा। Timer पर केवल प्रति घंटे का लागू रेट दिखे:

- **Normal Wiring, बिना Helper:** ₹125 प्रति घंटा (मौजूदा ₹1,000 / 8 घंटे का hourly equivalent)।
- **Normal Wiring, Helper सहित:** ₹187.50 प्रति घंटा (मौजूदा ₹1,500 / 8 घंटे का hourly equivalent; इसमें ₹62.50 प्रति घंटा Helper हिस्सा शामिल)।
- **Project Wiring, बिना Helper:** ₹400 प्रति घंटा।
- **Project Wiring, Helper सहित:** ₹550 प्रति घंटा।

- [x] Shared catalogue में चारों rate variants के लिए अलग `timerHourlyAmount` display metadata दर्ज।
- [x] मौजूदा 8-hour base package amounts और project hourly rates सुरक्षित; booking/billing की मूल दर या server calculation इस display instruction से नहीं बदली।
- [ ] Customer और Electrician के live Timer UI में केवल चुने गए wiring option/helper selection का `timerHourlyAmount` दिखाना; 8-hour amount छिपाना — UI implementation और test बाकी।
- [ ] Final bill server-authoritative calculation से ही बने; timer पर दिखने वाला hourly text केवल display है, client-side billing authority नहीं।
