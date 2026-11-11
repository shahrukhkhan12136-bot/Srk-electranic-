# SRK ELECTRONIC — Android Apps Screen-by-Screen UI Blueprint

**स्थिति:** Owner visual direction approved; यह implementation blueprint है, implemented app का प्रमाण नहीं।  
**तारीख:** 12 नवंबर 2026  
**Scope:** केवल दो Android apps — Customer और Electrician। Admin/Staff सुरक्षित responsive web dashboards रहेंगे।

## 1. साझा Visual System

- Royal Blue primary, White/cool off-white surfaces और Gold highlights.
- साफ़ SRK ELECTRONIC branding, readable Hindi-first typography, restrained shadows, consistent rounded cards और clear status chips.
- Mobile-first: 360dp width से; horizontal overflow नहीं; कम-से-कम 48dp touch targets; system font scaling और TalkBack support.
- Splash पर owner-supplied original Founder photo, waist-up crop, face centered और पहचान अपरिवर्तित। Original source सुरक्षित रहे; केवल optimized copy बनाएं।
- Splash hierarchy: compact logo/header → Founder portrait → welcome line/tagline → वास्तविक initialization progress. अनावश्यक खाली top space नहीं।
- Reference image में दिखाए गए Lucknow, counts, ratings, wallet, earnings और sample bookings illustrative हैं; live app में hard-code न हों।
- Shared components: BrandHeader, Primary/Secondary/DestructiveButton, StatusChip, BookingCard, MoneyCard, ProfileSummary, CategoryBadge, Skeleton, EmptyState, ErrorState, OfflineBanner, ConfirmSheet.
- सभी destructive/money actions पर amount, consequence और actor स्पष्ट कर confirmation लें। Loading/error/offline states हर critical screen पर हों।

## 2. Security और Data Authority

- Supabase Auth session ही identity है। Role, category, rate, booking owner, timer timestamps और payable amount client से trusted न हों।
- RLS और server RPC/API authorization अनिवार्य; service-role key, Razorpay secret, signing key या अन्य privileged secret app में कभी नहीं।
- Booking, accept/decline, timer और payment actions idempotent हों; mutation के बाद server-confirmed state दिखे।
- Customer/electrician phone visibility booking-scoped हो: acceptance से पहले hidden; accepted/received booking के बाद दोनों full unmasked numbers देख सकें। Phone push text या logs में न हो।
- Session refresh, expiry, logout, privacy/data request और notification permission flows हों।

## 3. Shared Splash / Authentication Screens

| ID | Screen | UI और actions | Validation / states |
|---|---|---|---|
| S-01 | Splash / Welcome | Logo, Founder waist-up portrait, welcome line, tagline, real progress. | Initialization आधारित progress; offline/retry; fake infinite loader नहीं। |
| S-02 | App Identity | Customer या Electrician app context. | App role server authorization से; client role switching नहीं। |
| S-03 | Sign In | Registered mobile, OTP request, resend countdown, OTP entry. | Invalid/expired OTP, rate limit, network timeout; OTP logs में नहीं। |
| S-04 | Session Restore | Valid session resume, expired session sign-in पर. | Secure token storage; logout पर session/cache clear. |
| S-05 | Notification Permission | Permission का कारण, Allow / Not now. | Denied होने पर भी app और in-app inbox काम करें। |

## 4. Customer Android App — Screen Inventory

### C-01 Home Dashboard
- Brand header, greeting, notification badge, customer verification/profile status.
- Service location/PIN card और Change action; serviceability server-validated.
- Shortcuts: नई बुकिंग, मेरी बुकिंग, भुगतान/रसीद, सहायता.
- Recent booking card: reference, service/category, date, server status, details.
- Data: signed-in customer profile, own addresses, own bookings, unread notifications.
- States: incomplete profile, no booking, loading, partial failure, offline. कोई fabricated count/rating/balance नहीं।

### C-02 Profile & Verification
- Name, registered phone, verification state, allowed profile fields.
- Address list, add/edit address, privacy, notification settings, logout/account request.
- Aadhaar या अनावश्यक sensitive data display नहीं।

### C-03 Address / Service Location
- Saved addresses, address form, PIN, district/state, optional GPS/map pin.
- Server serviceability और PIN/district validation; district silently rewrite न हो।
- GPS denied/manual entry और unserviceable address के स्पष्ट states.

### C-04 New Booking — Service & Category
- Customer-facing 8-hour Labour rates: Helper ₹899, Ordinary ₹1,199, Skilled ₹1,599, Master ₹1,999.
- इन्हें electrician net amounts न बताएं। Customer category चुनता है; app केवल category code भेजता है।
- Server active category/rate/version validate करता है; stale/missing rate पर submit रोकें।

### C-05 New Booking — Duration & Date
- Duration integer 1–8 hours; estimate = approved 8-hour category rate × selected hours ÷ 8.
- Calculation precision preserve; final paise rounding half-up.
- केवल date picker; customer clock-time/time-slot picker नहीं।
- Past/unavailable date reject; arbitrary default time assign न करें।
- Duration केवल initial preference है, timer cap नहीं; actual server-timed work final Labour तय करेगा।
- Materials अलग और itemized; upfront payment नहीं।

### C-06 Review & Submit
- Service, category, selected date, duration, server-validated Labour estimate और address summary.
- Actual approved work time से final Labour और separately approved materials की जानकारी।
- Idempotency key; duplicate tap block; booking reference server confirmation के बाद ही।

### C-07 Booking Confirmation
- Booking ID, date, service/category, status, next step, View booking.
- Electrician acceptance से पहले phone number न दिखाएं।

### C-08 My Bookings
- Active/completed/cancelled filters; server status; pagination.
- Historical records में legacy time fields सुरक्षित; नई booking में time required नहीं।
- Empty/loading/retry/offline states.

### C-09 Booking Details / Offer Selection
- Timeline, immutable category/rate snapshot, date and status.
- Eligible offers/bids only if backend allows; customer selection only among eligible offers.
- Acceptance से पहले phone hidden; acceptance/received के बाद full number visibility.

### C-10 Arrival & Work Approval
- Arrival evidence/status; work start authorize action.
- Timer तभी start हो जब server assignment, arrival evidence और customer approval validate करे।

### C-11 Live Work Timer
- Server-authoritative elapsed time and status.
- App resume/offline recovery पर server refresh; device clock billing authority नहीं।
- Customer timer stop approval; duration expiry पर auto-stop नहीं।

### C-12 Materials Proposal & Approval
- Item, quantity, unit price, line total, supplier marker and receipt evidence.
- Customer approve/reject; customer-supplied material ₹0.
- Labour और materials अलग; materials पर commission नहीं; unauthorized markup नहीं।

### C-13 Final Bill & Payment
- Server-generated Labour, separately itemized materials; unsupported taxes/fees invent न हों।
- Customer bill review/approval; उसके बाद Cash/Online path.
- No upfront payment. Online provider status server verified; Cash में customer electrician को सीधे भुगतान करता है।

### C-14 Receipt & Payment History
- Booking-linked receipt, amount, method, timestamp, verified status.
- Pending/failed/refunded distinct; केवल own transactions.

### C-15 Help / Complaint / Cancellation
- Complaint create, booking reference, description and supported attachments.
- ₹99 cancellation केवल customer-request + electrician arrival evidence + Admin approval पर। कोई automatic fee claim नहीं; Staff स्वयं impose/collect/approve नहीं करता।

### C-16 Notifications Inbox
- Booking, offer, arrival, timer, bill, payment, complaint events.
- Minimal non-sensitive push content; deep link पर session/authorization check.

### C-17 Settings / Privacy / Logout
- Language, notification preferences, terms, privacy, support, logout and data requests.
- Destructive actions confirmation; secure local session clear.

## 5. Electrician Android App — Screen Inventory

### E-01 Home Dashboard
- Own profile summary, approved category badge, permanent Electrician ID, approval/active state.
- Cards: eligible new offers, accepted/in-progress work, completed work, verified earnings.
- Bottom navigation: Home, My Work, Earnings, Help, Profile.
- केवल authenticated own data; fabricated figures नहीं।

### E-02 Profile / Verification / ID
- Own name, profile, Admin-approved category, approval/active/suspended state, service area and permanent ID.
- ID format SRK-EL-000001; only after Admin approval, active account and unambiguous Auth link.
- ID permanent, unique, never reused, not an authentication credential; electrician cannot edit ID/category.
- Missing/pending/rejected/suspended states explicit; no default category.

### E-03 New Job Offers
- केवल eligible offers for active, approved electrician.
- Service, date-only booking intent, category, duration preference, safe locality and backend expiry.
- Accept/decline server action; customer phone hidden before acceptance.
- Expired/already accepted conflict पर refresh; action idempotent.

### E-04 Offer / Job Details
- Authorized offer/assigned booking details only.
- Acceptance के बाद दोनों parties full unmasked numbers देख सकते हैं; पहले नहीं।
- Assignment केवल server response से confirmed.

### E-05 My Work
- Offered, accepted, in-progress, completed, cancelled tabs.
- Server status and permitted action; pagination; no unauthorized customer PII.

### E-06 Accepted Job / Navigation
- Accepted booking scope, service and authorized address/location.
- Call action only after acceptance; map app handoff uses authorized location.

### E-07 Arrival Evidence
- “मैं पहुँच गया” action with permitted server evidence.
- Location/camera permission purpose explain; manual fallback only if backend supports.
- Arrival timestamp server-side and idempotent.

### E-08 Work Start Authorization
- Arrival status and wait for customer approval.
- Timer start only after server validates accepted offer, assignment, arrival evidence and customer authorization.

### E-09 Live Work Timer
- Server timestamps and elapsed time; resume/background re-fetch.
- Device clock tampering ineffective; selected 1–8 hours does not cap or auto-stop timer.

### E-10 Materials Proposal
- Item, quantity, price, description and receipt evidence when electrician supplies material.
- Separate Labour/materials; customer-supplied material ₹0; customer approval required; revision audit.

### E-11 Completion / Timer Stop
- Submit completion; wait for customer timer-stop approval where required.
- Waiting/approved/rejected server state; no local final settlement.

### E-12 Final Bill Preview
- Server-generated Labour and separate materials.
- No manual override; dispute/correction path only if backend supports.

### E-13 Electrician Rate Card
- केवल 8-hour duration और electrician net Labour amount:
  - Helper ₹764.15
  - Ordinary ₹1,019.15
  - Skilled ₹1,359.15
  - Master ₹1,699.15
- Signed-in electrician की own Admin-approved category highlight.
- Gross Labour charge, commission percentage/amount या deduction row/label कभी न दिखे।
- Materials excluded; hourly net, tax, incentive या extra deduction invent न करें।
- Missing category पर explicit unavailable state; no default.

### E-14 Earnings / Wallet
- Own server-confirmed ledger; pending/payable/paid/failed distinct.
- Cash: customer pays electrician directly; electrician confirms actual receipt; remits commission to SRK; Admin confirms actual receipt; cash ledger electrician_payable=0.
- Online payable/payout only paid after actual provider/bank evidence.

### E-15 Payout / Settlement
- Own payout history/status; sensitive bank data masked.
- No payout approval power unless backend explicitly authorizes.
- Safe idempotent retry.

### E-16 Notifications Inbox
- Offer, acceptance, cancellation, arrival, work authorization, material decision, bill, payment/payout, support updates.
- Customer phone or sensitive address push body में नहीं।

### E-17 Help / Complaint
- Support ticket and own ticket status; no refund/commission approval powers.

### E-18 Settings / Privacy / Logout
- Notification/language/legal/privacy/support/logout; secure token clear.

## 6. Navigation Maps

**Customer:** Splash → Sign in → Profile/Address → Home → New Booking → Service/Category → Date/Duration → Review → Confirmation → Booking Details → Offers/Selection (if enabled) → Arrival/Work Approval → Timer → Materials → Final Bill → Payment → Receipt. Home से My Bookings, Notifications, Help, Profile भी उपलब्ध।

**Electrician:** Splash → Sign in → Verification/Profile → Home → New Offers → Offer Details → Accept → Accepted Job → Arrival Evidence → Customer Work Authorization → Timer → Materials → Completion → Customer Timer-stop Approval → Final Bill → Earnings/Settlement. Home से My Work, Rate Card, Wallet, Notifications, Help, Profile.

## 7. Design Tokens — प्रारंभिक मान
- Royal Blue primary; white surfaces; gold accent; green/amber/red semantic statuses.
- Spacing 4/8/12/16/20/24/32dp; cards 16–20dp radius; hero 24dp.
- Hindi-capable system sans fallback; body 14–16sp, section 18–22sp, headline 26–32sp.
- Buttons ≥48dp; status bar, gesture bar, cutouts and keyboard safe areas.
- Final token values visual prototype/device QA के बाद lock होंगे।

## 8. Acceptance / QA Matrix

| Group | Required verification |
|---|---|
| Layout | 360/393/432dp, small height, font scaling, Hindi matras, no overflow. |
| Splash | Original photo, waist-up crop, face preserved, compact header, crisp image, offline retry. |
| Auth | OTP valid/invalid/expired, throttling, session restore/expiry/logout, role isolation. |
| RLS | Customer own data only; electrician own profile/eligible jobs only; unauthorized RPC rejected. |
| Booking | Rate tamper rejected, date-only, past date rejection, 1–8 duration, half-up rounding, idempotency, no upfront payment. |
| Contact | Hidden before acceptance; full numbers only after accepted/received; no PII in push/logs. |
| Timer | Server timestamps, arrival/customer approval, background/resume, clock tamper, no duration auto-stop. |
| Materials/Bill | Itemized approval, customer-supplied ₹0, separate Labour/materials, immutable snapshot. |
| Payments | Cash receipt and Admin confirmation; online provider verification; no false paid/payout state. |
| Rate Card/ID | Exact four net amounts, no commission/gross text, own category only, ID unique/immutable/not credential. |
| Notifications | Permission denied/granted, authorized deep links, dedupe, minimal PII, offline inbox. |
| Accessibility | TalkBack, focus order, contrast, 48dp touch targets, dynamic type, Hindi text. |
| Reliability | Offline, timeout, retry, duplicate requests, stale data, process death. |
| Release | Internal AAB, signing custody, privacy disclosures, crash smoke test, rollback, explicit owner approval. |

## 9. Architecture Decisions Still Open
1. Framework: Flutter vs Kotlin/Compose vs Capacitor/TWA — decide only after repository and PWA/backend architecture review.
2. Minimum Android SDK and supported device/OS matrix.
3. Customer/Electrician application IDs, display names, signing custody and Play Console setup.
4. Push provider/project configuration and notification permission plan.
5. Offline cache boundary, crash reporting, analytics and data retention disclosures.
6. Build pipeline, internal testing and release strategy.

No framework or app ID is selected here. Native project files must not be generated until these decisions are reviewed.


## 10. Architecture Decision Record — प्रस्ताव और निर्णय की स्थिति

**महत्वपूर्ण:** नीचे दिए गए विकल्प repository inspection पर आधारित engineering recommendations हैं; owner की अंतिम मंजूरी के बिना इन्हें चुना हुआ framework, app ID या release configuration न मानें।

### 11.1 मौजूदा repository से मिले तथ्य
- मुख्य web client plain HTML/CSS/JavaScript है; package.json में अभी केवल Razorpay server SDK dependency है, कोई React/Flutter/Capacitor/Android build setup नहीं।
- Root में Customer-facing index.html, Electrician electrician.html, Admin admin.html, manifest.webmanifest और sw.js मौजूद हैं।
- apps/customer-android/ और apps/electrician-android/ में अभी केवल README हैं; native project, Gradle wrapper, Android manifest, source screens या build workflow नहीं हैं।
- Backend Supabase Auth/DB/RLS/RPC पर आधारित है; server-side payment functions अलग हैं। Mobile client को privileged server secrets कभी नहीं मिलने चाहिए।
- Existing Service Worker एक web/PWA cache है; उसे Android native app का offline/security implementation न समझें।

### 11.2 Framework विकल्प और अनुशंसा
| विकल्प | लाभ | लागत/जोखिम | स्थिति |
|---|---|---|---|
| Capacitor + HTML/CSS/JS | मौजूदा web stack/UI का अधिक reuse; दो Android shells; कम language/tooling बदलाव; native plugins उपलब्ध | मौजूदा pages को dedicated app navigation में refactor करना होगा; native feel/performance/plugins की device QA जरूरी | पहला practical विकल्प — owner approval बाकी |
| Flutter | मजबूत native-feeling UI, polished motion/accessibility, shared Dart components | मौजूदा HTML UI reuse सीमित; नई client implementation और Dart expertise/build pipeline चाहिए; web और mobile UI दो जगह maintain होंगे | वैकल्पिक |
| Kotlin + Jetpack Compose | Android-native UX और platform integration | दो अलग app modules/clients; मौजूदा web UI reuse कम; Android-specific maintenance | वैकल्पिक |

**प्रस्ताव:** पहले Capacitor का छोटा proof-of-concept बनाकर एक Splash + एक authenticated read-only dashboard screen पर navigation, rendering, session restore और responsive performance जांचें। POC केवल Feature Branch/local/internal test में; कोई Production deployment या paid activation नहीं। यदि native feel, performance या required plugin behavior acceptance test में fail हो, तब Flutter/Kotlin पर निर्णय दोबारा खोलें। POC बनने से पहले framework final नहीं माना जाएगा।

### 11.3 Android OS और device support — प्रस्ताव
- प्रारंभिक minimum: Android 8.0 (API 26) प्रस्तावित, final नहीं।
- Target/compile SDK: release के समय Google Play की उस समय लागू target API requirement के अनुसार latest supported stable version; अभी hard-code न करें।
- Test matrix: Android 8/9 baseline compatibility (यदि API 26 चुना जाए), Android 11/12, Android 13+ notification permission, और current Android release; कम-से-कम एक low-memory device, एक mid-range device, एक बड़े display और 360dp छोटे viewport.
- Responsive acceptance widths: 360dp, 393dp, 432dp; छोटे height, gesture navigation, cutout, landscape (जहाँ समर्थित), font scale 1.0/1.3/1.5.
- Hindi glyphs/matras, system font scaling, TalkBack, contrast, focus order और 48dp touch targets अनिवार्य।

### 11.4 Application IDs और app identity — प्रस्ताव
- Customer: in.srkelectronic.customer
- Electrician: in.srkelectronic.electrician
- Display names: SRK ELECTRONIC Customer और SRK ELECTRONIC Electrician.
- ये केवल प्रस्ताव हैं। Domain ownership, Play Console availability, signing, package collision और owner approval के बाद ही स्थायी रूप से सेट करें। App publish होने के बाद application ID बदलना migration/republication जैसा जोखिम रखता है।
- दो अलग apps, दो अलग application IDs, अलग notification/deep-link routing; Admin/Staff Android app नहीं बनेगा।

### 11.5 Push Notification Architecture — प्रस्ताव
- Push provider: Firebase Cloud Messaging (FCM) candidate; project creation/configuration, sender identity और credentials owner approval के बाद।
- Server event → authenticated server-side dispatcher → FCM → device; client स्वयं offer/booking notification का trusted source नहीं।
- In-app Notifications Inbox database से पढ़े; push केवल alert/deep-link trigger है, source of truth नहीं।
- Android 13+ notification permission context समझाकर मांगी जाए; deny होने पर app functionality और in-app inbox चलें।
- Push payload में phone, पूरा address, payment secrets, OTP, Aadhaar या अन्य संवेदनशील data न भेजें। Generic text + opaque event/reference ID पर्याप्त।
- Deep link खोलते समय session, role, booking ownership/assignment और current status server पर दोबारा verify हों। Logout/account switch पर पुराने account के notifications/cache isolate हों।
- Duplicate/reordered push, token rotation, uninstall/reinstall, permission denied, offline device और expired session test हों। FCM delivery को guaranteed/instant न मानें।

### 11.6 Offline और local storage boundaries — प्रस्ताव
- Offline में केवल app shell, logo/assets, non-sensitive help/policy content और explicitly approved non-sensitive reference data cache करें।
- Booking create/accept/decline, timer start/stop, arrival, materials approval, final bill, payment, payout या category/ID change offline execute न हों। Network/server confirmation तक action pending/error दिखे; client-side success fabricate न हो।
- Customer/electrician PII, phone, full address, wallet/earnings, payment details या sensitive booking data को shared/public cache में न रखें। यदि कोई limited private cache आवश्यक हो तो per-account encrypted storage, expiry, logout wipe और threat review के बाद ही।
- Auth tokens केवल platform-secure storage plugin/keystore-backed storage में; plain preferences, logs, screenshots या web localStorage में long-lived secrets नहीं।
- Network वापस आने पर safe read refresh; financial/state-changing requests blind auto-replay नहीं। Server idempotency और explicit retry confirmation अनिवार्य।

### 11.7 Build, signing और release pipeline — प्रस्ताव
1. GitHub Feature Branch पर source; pull request review और required CI.
2. CI: lint/static checks, unit tests, dependency/license scan, secret scan, Android build, artifact checksum.
3. Debug build local/internal QA; release keystore केवल owner-controlled secure custody में। Keystore/password CI logs/repository/chat में कभी नहीं।
4. Internal testing track में signed AAB; tester feedback, crash-free smoke test, permissions/privacy/data-safety declarations और rollback plan.
5. Production rollout केवल अलग explicit owner approval के बाद। Play Console, signing, release और paid services की कोई खरीद/activation स्वतः नहीं।
6. Versioning: अलग Customer/Electrician version codes; release notes और backend compatibility matrix.

### 11.8 Screen action contract — सभी critical screens के लिए
हर actionable control की implementation specification में ये fields अनिवार्य हों:
- Screen ID + control ID + Hindi/English visible label.
- Actor/role और preconditions (login, approval, assignment, current booking state).
- Read source / mutation RPC or API; request fields और response contract.
- Server-side validation, authorization/RLS, idempotency key और conflict behavior.
- Loading, success, empty, offline, timeout, retry, stale-session और permission-denied states.
- Success के बाद authoritative refresh/navigation; local optimistic UI केवल reversible/non-financial interaction पर।
- Analytics/logging में PII/OTP/phone/address/financial secret न हो.
- Accessibility name, focus order, TalkBack announcement, 48dp touch target और destructive-action confirmation.

### 11.9 Screen-specific action inventory supplement
| Screen IDs | मुख्य controls / actions | अनिवार्य guard |
|---|---|---|
| S-01–S-05 | Retry, Continue, Sign in, Request OTP, Verify OTP, Resend, Allow/Not now | OTP throttle/expiry; permission optional; no role switching |
| C-01–C-03 | New Booking, My Bookings, Change Location, Save Address, Help, Notifications | own profile/address only; server serviceability |
| C-04–C-07 | Select service/category, choose 1–8 hours, choose date, Review, Submit, View Booking | server rate/version, date-only, idempotency, no upfront payment |
| C-08–C-11 | Filters, View Details, eligible offer selection (if backend supports), Approve Work Start, Approve Timer Stop | only current authorized booking; server state/arrival evidence |
| C-12–C-14 | Approve/Reject Material, Review Bill, Choose Cash/Online after bill, View Receipt | materials separately approved; payment verified server-side |
| C-15–C-17 | Create Complaint, Request Cancellation, Confirm Logout, Privacy/Data Request | ₹99 only with required evidence + Admin approval; no unauthorized refund/fee action |
| E-01–E-02 | View Profile, Electrician ID, category/status, refresh | own profile only; ID/category server-authoritative |
| E-03–E-06 | View Offer, Accept, Decline, My Work, Call, Navigate | eligible offer; accepted assignment before contact visibility |
| E-07–E-09 | Mark Arrival, Wait for Customer Authorization, View Timer | server arrival evidence + customer approval; device clock not trusted |
| E-10–E-12 | Add Material, Submit Proposal, Mark Complete, View Final Bill | separate itemized materials; no local settlement/override |
| E-13–E-15 | View Rate Card, Earnings, Wallet, Payout History | show only approved 8-hour net Labour values; never commission/gross Labour |
| E-16–E-18 | Open Notification, Create Support Ticket, Settings, Logout | authorized deep link; no payout/refund/commission approval privilege |

### 11.10 Owner approval gates — अभी खुले
- [ ] Framework: Capacitor POC (recommended) / Flutter / Kotlin.
- [ ] Minimum Android API 26 proposal स्वीकार या संशोधित.
- [ ] दोनों Application IDs और display names स्वीकार या संशोधित.
- [ ] FCM candidate और Firebase project/credentials setup की अनुमति.
- [ ] Offline cache boundary और secure-storage implementation approval.
- [ ] GitHub Actions internal AAB pipeline तथा release-key custody process approval.

**Blueprint completion status:** Screen inventory, navigation, security, business rules, action inventory, edge states और QA matrix documented. Architecture recommendations documented but owner approval pending. Native apps, POC, device tests और release artifacts अभी बने नहीं हैं।


## 11. Release Guardrails / Status
- Exactly two Android apps; Admin/Staff remain secure web dashboards.
- No Production migration/deployment, paid provider activation or Play Store publication under this blueprint.
- Reference mockup data is never treated as live data.
- Backend remains authoritative for identity, pricing, booking, timer, category, ID and settlement.
- Android workspaces remain README-only; no native app/build is claimed.
- **Status:** Screen inventory, navigation, action inventory, security/business contracts, architecture options/recommendation, proposed SDK/package IDs, push/offline plan, build/release plan and QA matrix documented. Owner architecture approvals, POC, native implementation, backend integration, device QA and release remain pending.



## 12. Capacitor Customer POC — Owner approved (2026-11-12)

Owner ने Capacitor के छोटे Customer proof-of-concept को आगे बढ़ाने की अनुमति दी है। इसलिए एक isolated POC Feature Branch में जोड़ा गया है:
- Location: apps/mobile-poc/customer/
- Capacitor 8.0.0; temporary appId: in.srkelectronic.poc.customer (production package ID नहीं).
- Splash/welcome: owner-provided founder photo, centered waist-up crop, reduced top whitespace, Royal Blue / White / Gold.
- Session restore: existing Supabase Auth session को restore करके getUser() से verify करना.
- Dashboard: केवल read-only service_bookings summary; customer_user_id authenticated user से filter; RLS लागू; address, phone, payment और financial details query नहीं.
- कोई OTP/SMS अपने-आप नहीं भेजा जाता; booking create/accept, timer, materials, payment, wallet mutation और Production migration/deploy नहीं.
- CI workflow: .github/workflows/customer-mobile-poc.yml; Android debug APK generate करके 7 दिन का artifact रखेगा.

**Local static validation:** POC inline JavaScript syntax passed; required session and customer-scoped query markers checked; asset preparation and Android SDK CI configuration inspected. यह native Gradle build/CI success या physical-device validation का प्रमाण नहीं है।

**Current status:** POC source committed; CI build result, APK artifact, fresh-install/session test and real-device visual review pending. Android app architecture अभी final production decision नहीं है; Capacitor को पहले POC में evaluate किया जा रहा है।
