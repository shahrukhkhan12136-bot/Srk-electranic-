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
- [ ] इसलिए user-approved 85% technician / 15% company split **पूरे customer payment** पर लागू है या labour-only पर—इसे मौजूदा backend से compatible मानना गलत होगा। Backend owner से exact formula, material treatment, cash-vs-online ledger treatment और rounding rules लिखित रूप में चाहिए।
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
- [x] The agreed basis remains the full booking payment. Illustration: ₹1,000 customer booking payment → ₹150 company share + ₹850 technician share.
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
