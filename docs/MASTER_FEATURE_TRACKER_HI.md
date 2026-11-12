# SRK ELECTRONIC — Master Feature Tracker & Acceptance Register

इस रजिस्टर में हर फीचर की स्थिति प्रमाण के आधार पर अपडेट होगी। खाली checkbox का अर्थ काम बाकी है। पुराने काम को बिना दोबारा जाँचे COMPLETE न करें।

## Status legend
- [ ] Not started
- [~] Scaffold/design only
- [I] Implemented in branch; runtime tests pending
- [T] Testing / blocked
- [V] Verified in Preview/test environment
- [L] Live verified in Production
- [!] Blocked / decision or provider required

## A. Customer journey
- [I] Customer authentication / OTP UI and existing booking access — verify Auth provider and full E2E.
- [ ] Profile and address management, consent and account recovery.
- [I] Service catalogue and booking foundation — verify every active service and validation.
- [ ] Booking category picker: show Helper ₹899, Ordinary ₹1,199, Skilled ₹1,599, Master ₹1,999 (8-hour customer prices); server validates category/rate and stores immutable snapshot. Customer UI/E2E pending.
- [I] PIN/district matching and offer broadcast — investigate known PIN inconsistency; negative tests.
- [T] Electrician bid/quote and customer compare/select flow.
- [T] Booking state transitions, duplicate prevention and retry/idempotency.
- [T] Accepted-booking phone visibility, strict booking ownership and privacy.
- [T] Arrival proof and customer-approved timer.
- [T] Materials itemization, separate approval and no markup.
- [T] Final invoice, receipt, Cash and Online flow.
- [ ] Customer notification preferences, rating/review, complaint UX, cancellation/refund UX.
- [ ] Data export/deletion and privacy request workflow.

## B. Electrician journey
- [I] Application, profile, offer inbox and acceptance foundation.
- [T] Document verification, Admin approval, active-state consistency.
- [T] Availability, service area and offer matching.
- [T] Bid/quote, accept/reject/expire and single-winner concurrency.
- [T] Accepted-booking customer contact visibility.
- [T] Arrival evidence, timer, materials, completion.
- [T] Cash receipt confirmation and commission remittance.
- [T] Online earnings, wallet ledger and payout evidence.
- [T] Push notification device registration, delivery and deep-link.
- [ ] Profile update, account recovery, support and data controls.

## C. Admin
- [I] Existing Admin portal and admin allow-list — verify enrollment, MFA and recovery.
- [I] Booking/electrician/finance foundations — full permission and reconciliation tests.
- [ ] Staff account provisioning, deactivation and least-privilege role matrix.
- [ ] Service/category/rate settings with effective dates, validation, preview and rollback.
- [ ] Customer/electrician support lookup with safe identity matching.
- [T] Cancellation decision and ₹99 eligibility evidence; no actual fee collection implemented.
- [T] Complaint triage, assignment, escalation and resolution SLA.
- [T] Refund approval vs execution separation; no money movement without authorization.
- [T] Cash/online reconciliation, commission and payout evidence.
- [ ] Reports, exports, retention and access audit.
- [ ] App Update & Maintenance control center.
- [ ] Backup/restore status and incident controls.

## D. Staff & Customer Support
- [ ] Staff login, MFA, individual identities and role-based access.
- [ ] Booking/customer lookup with identity verification and data minimization.
- [ ] Complaint creation, notes, ownership, status, SLA and escalation.
- [ ] Cancellation script and eligibility checklist; staff cannot impose/collect fee.
- [ ] Call-center number, IVR, queues, agent routing and concurrency design.
- [ ] Consent/privacy and call recording policy; retention and access logs.
- [ ] Call metadata linkage to customer/booking, where lawful.
- [ ] Admin oversight and audit; no refund/payout/commission/database privileges.

## E. Payments & finance
- [I] Razorpay order/payment handlers and webhook code — sandbox E2E pending.
- [T] Payment signature/capture/webhook replay/idempotency and reconciliation.
- [T] Razorpay Route setup and transfer state reconciliation; do not claim active split.
- [T] Cash paid-to-electrician confirmation and SRK commission remittance.
- [T] Labour-only 15% commission and separate materials accounting.
- [T] Refund request, Admin approval, provider refund and evidence reconciliation.
- [T] Immutable ledger, duplicate wallet identity and historical anomalies review.
- [ ] Invoice numbering, downloadable receipts and applicable tax/legal validation.
- [ ] Finance period reports and export permissions.

## F. Timer, bill and cancellation
- [I] Timer/rate/material/cash/cancellation migrations and UI exist in feature branch; Production not cut over.
- [T] Resolve migration ordering and duplicate migration identities.
- [T] Build authoritative Production-schema fixture and replay full forward migration twice.
- [T] Test RLS, triggers, legacy callers and rollback/failure behavior.
- [T] Verify server timestamps, rounding, pause/retry and concurrent requests.
- [T] Verify customer stop approval, immutable bill snapshot and paise rounding.
- [T] Verify materials revisions and separate receipt.
- [T] Verify ₹99 rule only after customer request + arrival evidence + Admin approval; collection not implemented.

## G. Android apps
- [ ] Customer Android app project, architecture, package ID and app signing plan.
- [ ] Electrician Android app project, architecture, package ID and app signing plan.
- [ ] Secure Supabase Auth session handling; no service-role secrets in app.
- [ ] Push permissions, token lifecycle, deep links and notification opt-out.
- [ ] Camera/location permissions only when needed, with consent and graceful denial.
- [ ] Offline/network failure, crash reporting and accessibility.
- [ ] Internal testing, device matrix, signed AAB, privacy/data-safety disclosures.
- [ ] Play Console listing, screenshots, policy declarations and staged release.

## H. Website, PWA and design
- [I] Customer/Electrician/Admin UI polish and responsive CSS on feature branch.
- [T] Visual QA on real mobile and desktop browsers.
- [ ] Staff PWA screens and navigation.
- [ ] Installability, manifest/icons, offline fallback and service-worker update strategy.
- [ ] Accessibility, keyboard navigation, Hindi copy review and performance.
- [ ] Founder image true background cutout asset; current CSS framing is not a cutout.

## I. Security, privacy and operations
- [I] Public table RLS enabled in current catalog snapshot; policy behavior still requires tests.
- [T] Full RLS positive/negative matrix for anon/customer/electrician/staff/admin.
- [ ] Admin MFA, recovery, session timeout, rate limiting and alerting.
- [ ] Secret inventory, rotation and environment separation.
- [ ] Privacy notice, consent, data minimization, retention/deletion and incident response.
- [ ] Backup schedule, restore drill, RPO/RTO and backup access protection.
- [ ] Logs/metrics/alerts, error monitoring and uptime checks.
- [ ] Dependency and vulnerability scanning; abuse/rate-limit tests.

## J. Delivery and maintenance
- [ ] Feature request / bug report intake and prioritization.
- [ ] Branch, review, CI, Preview and acceptance workflow.
- [ ] App version registry and release notes.
- [ ] Admin-configurable setting versioning and rollback.
- [ ] Production release checklist and owner approval record.
- [ ] Android staged rollout, crash monitoring and rollback/halt procedure.
- [ ] Disaster recovery and restore validation.

## K. Final release gates
- [ ] Every P0/P1 defect resolved or explicitly accepted by owner.
- [ ] Main Production schema parity and forward migration plan verified.
- [ ] Auth, RLS and role matrix tests pass.
- [ ] Customer/Electrician/Admin/Staff E2E flows pass.
- [ ] Razorpay Test Mode and webhook replay pass; no real-money test.
- [ ] Backup and rollback tested.
- [ ] Netlify capacity and environment variables verified.
- [ ] Android signed builds and policy review complete.
- [ ] Owner gives explicit approval for one consolidated Production release.

## Current guardrail
This register is a planning/acceptance scaffold, not a claim that unchecked features have been implemented. Main Production database, live website and Play Store must not be changed as part of documentation scaffolding.

## G.1 Electrician Android Rate Card — owner-confirmed 2026-11-11
- [ ] Rate Card list showing all four approved 8-hour Labour categories.
- [ ] Show the 8-hour work duration and only the amount payable to the electrician: Helper ₹764.15; Ordinary ₹1,019.15; Skilled ₹1,359.15; Master ₹1,699.15. Do not display the 8-hour Labour charge/gross amount, commission percentage, commission amount or deduction line anywhere in the electrician-facing Rate Card.
- [ ] Highlight the signed-in electrician's own Admin-approved assigned category and net amount from server-authoritative profile data.
- [ ] Prevent electrician self-edit/tampering of category or rate; Admin changes must be authorized, versioned and audited.
- [ ] Keep the backend Labour-only commission calculation internal; do not show the gross Labour charge or any commission details in electrician Rate Card. Exclude materials/parts from the calculation and preserve separate itemized billing.
- [ ] Keep booking immutable rate snapshots authoritative; later Rate Card changes must not rewrite existing bookings.
- [ ] Test calculation/paise rounding, RLS/API authorization, privacy, responsive/accessibility, loading/offline/error states.
- [~] Requirement documented in Blueprint and Electrician Android README; actual app remains README-only scaffold.




## A.1 Customer Booking — category and price acceptance (owner-confirmed 2026-11-11)
- [I] Customer category selector में चारों श्रेणियों के 8-hour rates दिखते हैं: Helper ₹899.00, Ordinary ₹1,199.00, Skilled ₹1,599.00, Master ₹1,999.00।
- [I] Customer category चुनता है; API और database RPC केवल Helper/Ordinary/Skilled/Master स्वीकार करते हैं। Client से भेजी कोई price/amount property RPC whitelist में स्वीकार नहीं होती।
- [I] Category code/label और authoritative hourly rate booking में immutable snapshot के रूप में store होते हैं; duration और estimated Labour snapshot अब इसी snapshot guard से सुरक्षित हैं।
- [I] Append-only effective-dated rate catalogue v1 migration Feature Branch में है; RPC current date के अनुसार category/version/rate server-side catalogue से चुनता है और booking में immutable catalogue UUID + version snapshot रखता है।
- [I] Admin-only RPC + Admin dashboard rate publisher और immutable audit history Feature Branch में जोड़े गए; कारण, actor, दर, version और effective date दर्ज होते हैं।
- [T] Real Admin-browser workflow, scheduled effective-date boundary E2E और rollback policy की जाँच बाकी; Production migration लागू नहीं हुई।
- [I] Customer price display अलग है; electrician Rate Card का gross/commission privacy rule इस customer UI change से नहीं बदला।
- [T] Responsive/accessibility, loading/error/offline states और real customer booking E2E अभी बाकी। No upfront payment.


## A.2 Customer Booking — duration selector 1–8 hours (owner-confirmed 2026-11-11)
- [I] Customer form में required single-select duration control: 1 से 8 घंटे; default duration silently select नहीं होती।
- [I] Category या duration बदलने पर ग्राहक स्क्रीन पर अनुमानित Labour amount तुरंत update होता है; booking WhatsApp summary में चुनी अवधि शामिल है।
- [I] Formula: approved 8-hour category price × selected integer hours ÷ 8; full precision रखकर final amount को paise पर half-up round किया जाता है। उदाहरण: Helper 1h ₹112.38, 2h ₹224.75, 3h ₹337.13, 8h ₹899.00; Ordinary 1h ₹149.88।
- [I] Booking API duration को integer 1–8 validate करता है; client amount स्वीकार/forward नहीं होता। Database RPC category की server-side fixed rate से amount दोबारा calculate करता है।
- [I] service_bookings.duration_hours और estimated_labour_amount_snapshot में immutable snapshot; DB check constraint amount/rate/duration consistency enforce करता है और update trigger दोनों values बदलने से रोकता है।
- [I] Booking confirmation में DB से लौटाया गया duration और server-calculated estimate दिखता है।
- [I] Rate catalogue migration `20261112150000_versioned_rate_catalogue.sql`: चारों current rates v1 के रूप में effective-dated, append-only table में seed; RLS enabled और direct client grants revoked; booking में catalogue UUID/version snapshot जुड़ा।
- [I] `20261112160000_admin_rate_catalogue_management.sql` में admin allow-list gated publish/list RPC और append-only audit log है; `admin.html` में नई दर publish करने और version history देखने का panel जुड़ा।
- [I] `20261112170000_public_customer_rate_catalogue_rpc.sql` ग्राहक को केवल चार वर्तमान प्रभावी श्रेणी-दरें पढ़ने देता है; catalogue table का direct SELECT अब भी बंद है। Customer booking UI live RPC से rate/version लेता है, estimate उसी rate से दिखाता है और RPC/error/अपूर्ण data पर booking submit बंद रखता है। Rate activation और Admin की past-date validation India business timezone `Asia/Kolkata` से होती है; UTC/session timezone mismatch से midnight पर rate देर/जल्दी लागू नहीं होगा।
- [T] Real Admin-browser workflow, scheduled effective-date boundary E2E और rollback policy बाकी।
- [I] चुने हुए 1–8 घंटे केवल शुरुआती अनुमान/बुकिंग preference हैं—timer या final bill की सीमा नहीं। Actual final Labour bill server timer के वास्तविक elapsed time पर आधारित रहेगा; selected duration समाप्त होने पर timer auto-stop नहीं होगा।
- [I] Materials अलग रहते हैं; booking के समय कोई upfront payment नहीं।
- [T] Disposable PostgreSQL CI + API/UI regressions: GitHub Actions run 43160242188 SUCCESS; 11/11 Node tests, SQL order-number/RPC assertions, duration estimate/half-up rounding/invalid-duration/immutability assertions, four migrations apply और safe replay, inline JS syntax checks।
- [T] Real browser/Android customer booking E2E, responsive/accessibility, offline/error states और live Production runtime verification अभी बाकी। Production DB/site पर कोई बदलाव नहीं किया गया।


## A.3 Customer Booking — date-only selection (owner-confirmed 2026-11-11)
- [I] Booking form से customer time/time-slot picker हटाया; date-picker ही customer selection है।
- [I] नए booking API flow में customer-selected clock-time/slot अनिवार्य नहीं; booking date server-side validate होती है।
- [I] Date-only intent को booking API और Supabase RPC में support किया; absent time को NULL रखा जाता है, default/कल्पित समय नहीं बनाया जाता। पुराने callers द्वारा स्पष्ट रूप से भेजा गया valid time स्वीकार होता है।
- [T] अलग authorized operational scheduling workflow, past/unavailable dates, timezone/date-boundary, reschedule/cancellation और full customer-to-electrician E2E अभी बाकी हैं।
- [I] Existing bookings के historical time fields preserve; booking history में पुराने time display refs जानबूझकर रखे गए।
- [T] 1–8 hours booking preference और actual elapsed timer/final Labour bill का संयुक्त E2E अभी बाकी है।
- [I] GitHub Actions PostgreSQL 16 disposable test run 43158132227 SUCCESS: order-number, date-only RPC migration apply/replay, electrician offer RPC, numbering/immutability/uniqueness, RPC scope, PII privacy और customer/electrician/Admin inline JavaScript syntax checks पास।
- [I] API regression tests `tests/create-booking-date-only.test.js`: valid date-only booking accepted और RPC payload में `preferred_time` absent; impossible calendar date `2026-02-30` rejected before booking RPC. GitHub Actions run 43158591000 SUCCESS; Node test runner 2/2 pass.
- [T] CI disposable fixture है; Main Production Supabase पर migration लागू नहीं हुई, browser/real-device E2E नहीं हुआ।
- [I] Customer date-only UI regression `tests/customer-booking-date-only-ui.test.js`: required date picker मौजूद, booking form में time/time-slot control नहीं, API/WhatsApp payload में selected clock-time नहीं, historical records का explicit preferred_time display सुरक्षित। GitHub Actions run 43159329138 SUCCESS; combined Node regression suite 5/5 pass.
- [I] Booking API security regression `tests/create-booking-security.test.js`: non-POST reject, trusted client IP missing पर fail-closed, invalid session reject, verified Auth phone mismatch reject; सभी मामलों में booking RPC call नहीं हुई। GitHub Actions run 43159445870 SUCCESS; combined Node regression suite 9/9 pass.
- [I] Authenticated PostgreSQL RPC regression (`customer_booking_date_only_rpc_assertions.sql`): date-only booking stores NULL time, same idempotency key replays same booking, legacy explicit `14:30` time remains stored, invalid `25:99` is rejected. GitHub Actions run 43159142236 SUCCESS; numbering assertions are deliberately run first because PostgreSQL sequences are non-transactional.


## B.1 Electrician ID/Profile — own approved category badge (owner-confirmed 2026-11-11)
- [ ] Electrician के अपने Profile / Electrician ID पर उसकी Admin-approved category का स्पष्ट नाम और badge दिखे: Helper, Ordinary, Skilled या Master।
- [ ] Category केवल server-authoritative verified profile/application assignment से आए; client-supplied category/label को ignore करें।
- [ ] Electrician को अपनी category खुद edit/upgrade/downgrade करने की अनुमति न हो; Admin changes authorized, versioned और audited हों।
- [ ] Pending/rejected/suspended/inactive/missing assignment में कोई गलत default category न दिखे; सही status/error message दिखे।
- [ ] केवल signed-in electrician अपनी category देख सके; अन्य electricians की private assignment सुरक्षित रहे।
- [ ] Profile/ID badge और Rate Card highlight एक ही authoritative category source इस्तेमाल करें।
- [ ] Loading/offline/stale/error, accessibility और mobile E2E तथा RLS/authorization/tampering negative tests पास हों।
- [~] Requirement documented; actual Android/profile UI and API implementation pending.


## B.2 Electrician ID Number — permanent unique number (owner-approved 2026-11-12)
- [ ] Owner-approved format: SRK-EL-000001, SRK-EL-000002… .
- [ ] Issue automatically from server only after Admin approval and account activation.
- [ ] Unique, permanent, never reused; electrician cannot edit or choose it.
- [ ] Keep internal UUID primary key separate from readable public/display ID.
- [ ] Do not encode phone, Aadhaar, DOB or other personal information.
- [ ] Show ID number, approved category badge and current status on electrician's own ID/Profile card.
- [ ] Category changes must not change the permanent ID number; Admin changes remain audited/versioned.
- [ ] Add database uniqueness, transactional sequence/concurrency, authorization and lookup tests.
- [ ] ID alone must never authenticate a user or grant access.
- [T] Owner-approved format; server-side sequence/trigger migration, catalog/security assertions, behavior tests (approval/activation, later Auth-link addition, mismatched/duplicate Auth-link rejection, legacy user_id-only linkage, immutability, client-supplied ID rejection, deletion/recreation non-reuse, and non-cycling sequence), electrician profile ID display, and Admin partner-list search by ID/name/phone are committed to Feature Branch. CI run 43082442370 passed on PostgreSQL 16: Production-shaped profile/Auth/FK/constraints/index/RLS/audit-trigger fixture, migration/catalog/security assertions, all behavior tests, 24 simultaneous issuance transactions with 28 total unique retained IDs, plus inline JavaScript syntax checks for electrician.html/admin.html. Live Production schema/constraints were read-only inspected and found structurally compatible; Production migration remains unapplied. Live browser Preview/E2E, real Admin authorization test, and Android ID card remain pending.


## Master implementation plan
- Three-panel ownership, remaining-work phases, monitoring tree, release gates और immediate execution order के लिए [REMAINING_WORK_IMPLEMENTATION_PLAN_HI.md](./REMAINING_WORK_IMPLEMENTATION_PLAN_HI.md) देखें।
- इस योजना में कोई item केवल design या code मौजूद होने से complete नहीं होगा; प्रत्येक status के लिए test/runtime evidence आवश्यक है।



## B.3 Migration Release Audit — repository inventory and CI coverage (2026-11-12)
- [I] Feature branch पर 57 SQL migrations का inventory और feature-family classification पूरा; duplicate timer/billing family और ज्ञात material divergence को अलग दर्ज किया। कोई migration delete/rename/reorder नहीं की गई। विवरण: `docs/MIGRATION_RELEASE_SEQUENCE_AUDIT_HI.md`।
- [I] Refund/Webhook CI run 43169304973 SUCCESS at commit `32f1d109`: isolated PostgreSQL 16 refund fixture, webhook ledger migration twice, refund assertions, atomic lease recovery/duplicate event/RLS-grant assertions, Node syntax and payment/webhook contract tests सभी pass।
- [I] Timer Billing SQL CI run 43169284161 SUCCESS at commit `1ac783fb`: timer/billing disposable PostgreSQL tests और Production-shaped legacy baseline assertions pass; यह सभी 57 migrations का full replay नहीं है।
- [I] Booking/order/rate workflow PR path filters सुधारे गए ताकि date, duration, versioned rate catalogue, Admin rate management, public rate RPC और electrician offer RPC के बदलाव पर समान SQL regression suite चले। इस workflow का current-HEAD run अभी verify होना बाकी है।
- [T] Full 57-migration canonical dependency graph, exact Production migration history comparison और sanitized Production-parity clean replay अभी खुले हैं। Production पर कोई migration नहीं लगी।
- [T] NO-GO for Production जारी; website deployment, live Razorpay, real-money test और Play Store release नहीं किए गए।



## B.4 Electrician Auth identity relink guard (2026-11-12)
- [I] Display-ID trigger audit में एक edge case मिला: पहले से permanent ID वाले profile का Auth identity दूसरे profile के legacy `user_id` से conflict होने पर update trigger identity-conflict check से पहले return कर सकता था।
- [I] Feature Branch migration में identity-conflict validation को permanent-ID preservation से पहले चलाया गया; conflicting relink अब SQLSTATE 23505 से reject होता है। Existing ambiguous legacy INSERT बिना ID के retained रहता है ताकि historical profile creation अनावश्यक रूप से block न हो।
- [I] Regression test जोड़ा: issued profile को दूसरे profile के Auth identity से relink करने का प्रयास reject हो और पुराना Auth link अपरिवर्तित रहे।
- [I] GitHub Actions run 43169829039 SUCCESS at commit `0b1dd1a7`: disposable PostgreSQL fixture, migration/catalog security assertions, issuance/immutability/client-supplied ID behavior, duplicate identity relink rejection और 24 concurrent ID issuance stress tests pass।
- [I] GitHub Actions run 43170444750 SUCCESS at commit `1cbad155`: वही electrician display-ID migration clean fixture पर दूसरी बार भी सुरक्षित replay हुई; migration catalog/security assertions दोबारा pass हुए, फिर behavior और 24-way concurrent issuance stress tests भी pass हुए।
- [T] यह CI disposable fixture evidence है; Production schema पर migration लागू नहीं हुई और वास्तविक Admin/Android UI E2E बाकी है।



## B.5 Production migration-history drift — read-only discovery (2026-11-12)
- [I] Production Supabase migration history read-only मिली: 78 applied entries; Feature Branch में 57 SQL migration files। केवल 7 entries में version + name दोनों exact match हैं; 16 branch filenames के migration names Production में मिलते हैं, जिनमें कई timestamp mismatch हैं।
- [I] Production में `add_assigned_electrician_cash_payment_status` नाम की दो अलग migration versions (11082515 और 11083811) दर्ज हैं; branch में एक ही file है।
- [I] Read-only schema probe: पुराने refund request/refund tables मौजूद; timer payable snapshots, Razorpay snapshot order/payment ledger, rate catalogue, rate audit, webhook event ledger, booking idempotency table और नए order/duration/rate/electrician-ID columns मौजूद नहीं मिले।
- [I] विस्तृत 78-vs-57 comparison और सुरक्षित reconciliation gate `docs/MIGRATION_RELEASE_SEQUENCE_AUDIT_HI.md` तथा सभी 78 Production history entries का row-by-row status `docs/PRODUCTION_MIGRATION_HISTORY_COMPARISON_HI.md` में दर्ज। तुलना में 7 exact version+name matches, 10 Production rows same-name/different-version और 61 Production rows बिना exact-name branch source के मिले; branch में 41 exact-name Production history entry के बिना files हैं।
- [T] यह migration drift अब सबसे बड़ा Production blocker है। किसी migration को timestamp/name अनुमान से apply, skip, rename या mark-applied नहीं करना। पहले प्रत्येक mismatch का SQL-level reconciliation और disposable Production-parity replay जरूरी है।
- [T] Production DB में कोई write/migration नहीं की गई। NO-GO for Production जारी।

## Refund Provider Reconciliation Hardening — 2026-11-12
- [I] नया forward-only migration `20261112190000_harden_refund_provider_reconciliation.sql`: पहले से bind हुआ Razorpay provider refund ID बदला नहीं जा सकता; अलग ID आने पर SQLSTATE `23505` के साथ reject होता है।
- [I] `processed` और `failed` terminal states सुरक्षित; failed refund पर देर से आया `pending` event ignore होता है और state/provider_status downgrade नहीं होते। Failed से उसी refund ID पर processed transition को automatic स्वीकार नहीं किया जाता; manual reconciliation आवश्यक है।
- [I] Refund regression assertions में processed record पर conflicting provider ID, failed → stale pending, failed → processed terminal conflict और provider ID immutability की जाँच जोड़ी।
- [I] Refund CI workflow में forward migration दो बार apply/replay और push + pull_request path coverage जोड़ी।
- [V] GitHub Actions run `43171211161` SUCCESS at commit `69ad1262b35bcc4766385b27eb0ad93a0875aab7`; isolated PostgreSQL 16 fixture, refund SQL assertions, webhook ledger checks, migration replay, Node syntax and handler/contract tests passed.
- [T] यह disposable CI database का प्रमाण है; Production Supabase migration लागू नहीं हुई और वास्तविक Razorpay sandbox webhook replay अभी नहीं हुआ।

## Production Migration Archive Recovery — 2026-11-12
- [T] सभी 11 repository branches के migration trees की read-only तुलना: Production history की 78 rows में 14 exact version+name source filenames, 25 same-name/different-version candidates और 39 rows के लिए कोई matching-name source नहीं मिला।
- [T] Historical branch `work/separate-customer-electrician-portals` (commit `0fe5ef479e3ce69e9b219721599ebd52f6ba73ee`) से पुराने SQL candidates recovered; Flutter, hourly-booking और current feature branches से अतिरिक्त sources मिले।
- [T] सात same-name files historical/current feature branch में byte-identical; Push subscription migration historical और current copy में materially different है।
- [T] Detailed mapping: `docs/PRODUCTION_MIGRATION_ARCHIVE_RECOVERY_HI.md`; यह candidate-source register है, Production-applied SQL की authenticity proof नहीं।
- [!] 39 Production migration rows अभी unresolved हैं; 25 timestamp-mismatch candidates का exact Production SQL से comparison बाकी है। Production remains read-only and NO-GO.

- [!] Production refund RPC का read-only `pg_get_functiondef` audit: existing implementation provider refund ID overwrite कर सकती है और failed state को late pending event से processing में downgrade कर सकती है। Forward fix feature branch पर CI verified है, Production पर लागू नहीं। Details: `docs/REFUND_RECONCILIATION_PRODUCTION_AUDIT_HI.md`.

## Refund Webhook Ambiguity + Legacy ID Binding — 2026-11-12
- [I] Production read-only schema inspection confirms `srk_razorpay_refunds` has unique `booking_id` and `refund_id`, but no unique index on `payment_id`. The webhook previously queried by `payment_id` with `limit=1`, which could select an arbitrary row if historical/abnormal duplicate payment IDs exist.
- [I] `razorpay-webhook.js` now fetches up to two payment-ID matches and returns retryable HTTP 500 when more than one refund ledger row matches; it will not reconcile an arbitrary record.
- [I] Forward migration also binds the first verified provider refund ID to legacy rows already marked `processed` but having a null `refund_id`, without changing their terminal status.
- [I] SQL regression test covers the late-ID binding. Added `tests/razorpay-webhook-refund-contract.test.js` and wired it into Refund CI to assert the ambiguity guard and ID binding contract.
- [T] Refund CI run `43172179292` SUCCESS for the prior commit containing SQL replay + SQL assertions. Newest run `43172241324` is still in progress/queued at this tracker update; do not treat the newest static contract assertion as verified until that run succeeds.
- [T] No Production changes or real Razorpay webhook calls performed.

- [V] नवीनतम Refund CI run `43172241324` SUCCESS at commit `bdae5d797b9a41fdc6bedfd811c6f9b9f90ea642`; specifically `Test Razorpay refund webhook ledger contract` passed, along with the full PostgreSQL refund suite and handler checks.

## Refund Webhook — ambiguous payment-ID handler runtime regression (2026-11-12)
- [I] Code review confirms `razorpay-webhook.js` fetches at most two refund ledger rows for the provider payment ID and immediately returns retryable HTTP 500 with `ambiguous_refund_ledger_match` when two rows match; it does not claim the webhook event or call the reconciliation RPC for an arbitrary row.
- [I] Added `tests/razorpay-webhook-ambiguous-refund-handler.test.js`, which loads the real handler, sends a correctly HMAC-signed refund webhook, mocks a duplicate ledger response, and asserts HTTP 500/retry, exact error code, exactly one fetch, GET-only access, and no event-claim/reconciliation write.
- [I] Refund workflow now runs this runtime test on branch pushes and pull requests.
- [V] GitHub Actions run `43173098414` SUCCESS at commit `92bcbc89076c5ce97caacefe1b87ed7ccb9478c2`; the real handler runtime test passed, including HMAC verification, duplicate-row response, retryable HTTP 500, exactly one GET request and no subsequent event-ledger claim or refund reconciliation write. Full isolated PostgreSQL refund suite and all handler checks also passed. A second run `43173138238` SUCCESS at commit `f58bdcbfded900c51fb19429070dc382f44519d1`; push and pull-request path filters now both include the runtime test.
- [T] No live Razorpay webhook replay, Production database write, real-money transaction, or deployment performed.
- [T] Duplicate Production cash-payment migration investigation: `srk_get_my_assigned_cash_payment(uuid)` current Production definition matches the recovered first migration candidate, but this does not establish what the second same-name history entry did. Exact second SQL remains unresolved; no skip/no-op assumption allowed. Details: `docs/PRODUCTION_MIGRATION_ARCHIVE_RECOVERY_HI.md`.
## Production push + migration archive audit update (2026-11-12)
- [V] 11 GitHub branches के migration trees का पुनः scan: 99 unique migration paths; Production history के 78 rows में 13 exact version+name files, 26 same-name/different-version candidates और 39 unresolved rows। Refund foundation और push webhook के छह exact-path commit-history queries खाली रहे।
- [V] Read-only Production snapshot में pg_net 0.20.4, job_offers push trigger, private.srk_notify_job_offer_push(), Vault secret name PUSH_WEBHOOK_SECRET, active push-job-offer Edge Function v4 और Realtime publication में job_offers/electrician_profiles मिले। Secret values नहीं पढ़ीं।
- [V] srk_push_subscriptions पर RLS enabled और authenticated SELECT/INSERT/UPDATE/DELETE सभी policies auth.uid()-आधारित user ownership check करती हैं; UPDATE में USING तथा WITH CHECK दोनों हैं।
- [V] Push Edge Function source static review में POST shared-secret validation, bounded body, payload shape/type validation, active+approved electrician eligibility, user-linked subscriptions और expired subscription cleanup मिला। कोई live webhook/notification test नहीं किया गया।
- [T] cron.job relation इस Production project में उपलब्ध नहीं; cron jobs की स्थिति इस query से अज्ञात है।
- [T] 39 migration source rows अब भी unresolved; live catalog effects original SQL का replacement नहीं। Production release NO-GO कायम।
- [T] कोई Production schema/data/history change, Edge Function deploy, webhook, payment, या deployment नहीं किया।

## Production SECURITY DEFINER + RLS ACL audit (2026-11-12)
- [V] Public/private schemas में 61 SECURITY DEFINER functions का effective privilege audit: PUBLIC EXECUTE 0, anon EXECUTE 0। Authenticated EXECUTE वाली functions के guards का static review जारी है।
- [V] Empty search_path वाले 8 privileged functions की definitions पढ़ीं; SQL object references schema-qualified हैं। Customer/push functions auth.uid() identity/ownership जाँचती हैं, Admin refund RPCs is_srk_admin() check करती हैं, और service refund reconcile RPC service_role check करती है।
- [V] Public schema की 25/25 base tables में RLS enabled। 10 tables पर policies नहीं हैं, लेकिन anon/authenticated के table CRUD privileges false और service_role CRUD true मिले—वर्तमान state service-role-only/default-deny है।
- [T] Refund reconciliation RPC पर service_role-only ACL सही होने के बावजूद पुराने Production function body में provider refund ID overwrite और stale pending/failure ordering जोखिम अभी unresolved है; hardened migration Production में लागू नहीं।
- [T] ये catalog और function-body static checks हैं; हर authenticated RPC का adversarial multi-user runtime test और complete RLS expression register अभी बाकी है। कोई Production परिवर्तन नहीं किया।

## RLS expression + refund integrity follow-up (2026-11-12)
- [V] Current public RLS expressions reviewed: Admin guard, customer booking ownership, electrician profile identity and active/approved offer ownership, wallet/payout owner reads, active-only public services/states, explicit Route-transfer deny-all, service-role-only payment locks/status history.
- [T] `srk_electrician_payouts` owner policy checks `electrician_profiles.user_id` only, unlike profile/offer policies accepting `user_id OR auth_user_id`. Current Production has 1 electrician profile and 0 payout rows; identity mapping edge case remains a potential read mismatch, not an observed incident.
- [V] Refund constraints/indexes: one Razorpay refund row per booking, one refund request per booking, unique provider refund ID/idempotency key; manual refund is also one per booking/payment entry. Multiple partial refunds per booking are not currently supported.
- [T] `service_bookings.razorpay_order_id` has partial unique index; `razorpay_payment_id` has no unique index/constraint. Current Production has 1 booking, no non-null payment ID, and 0 refund rows. Consider unique payment ID enforcement only after parity-DB/backfill validation.
- [T] Legacy `srk_admin_prepare_razorpay_refund(uuid,text)` remains authenticated-executable and Admin-guarded alongside the newer refund-request preparation RPC; distinct code paths need call-site inventory and consolidation plan.
- [T] Refund audit trigger captures refund_id, amount, status, provider_status changes, but not reason/last_error/processed_at. Audit sufficiency review pending.
- [T] No live refund/provider/webhook tests or Production changes. Static review only; Production NO-GO remains.

## Confirmed Timer Cash Refund Production drift (2026-11-12)
- [V] Production Admin refund-list RPC omits `is_timer_booking`; `has_manual_payment` checks only `srk_manual_payment_entries`, not timer `srk_cash_receipts`.
- [V] Production does not contain `srk_admin_finalize_timer_cash_refund(uuid,text,text)` and migration history has no `20261111160015` timer snapshot refund migration.
- [V] Feature branch `20261111160015_timer_snapshot_refund_support.sql` contains the intended timer refund entry table, extended Admin list RPC and timer-cash finalize RPC. The current Admin UI expects this contract and conditionally calls the missing RPC.
- [!] Timer Cash refund workflow is not production-ready; current UI/database contract mismatch. No live refund rows or customer impact were observed. Do not patch Production directly; recover migration lineage and validate ordered dependencies on a disposable Production-parity DB.
- [ ] Check all timer release migrations and cash receipt/snapshot/payout dependencies against Production, then add this migration to the full migration disposition matrix.
- [V] Dependency inventory further confirms Production has none of the timer snapshot/cash receipt/payment ledger relations (`srk_booking_payable_snapshots`, `srk_cash_receipts`, `srk_razorpay_payments`, `srk_timer_cash_refund_entries`) and no timer/snapshot/payable/service-category columns on `service_bookings` by those expected names. No `2026111116%` timer release migration history rows. This is a broader Production-vs-feature timer foundation gap, not only a missing refund RPC; do not apply the refund migration in isolation.

### Timer migration chain — release blocker (2026-11-12)
- Mapped all 16 Timer-related migration files and their dependencies. The ordered release chain 16000 → 16001 → 16002 → 16003 → 16007 → 16010 → 16012 → 16013 → 16015 depends on the Timer foundation tables, booking columns, cash receipt/payment ledger and payout extensions.
- Production has none of the Timer tables (timer decisions, final bills, materials/revisions/approvals, payable snapshots, payment webhook events, cash receipts, booking audit events, final bill adjustments, timer cash refunds, Razorpay payment ledger) and no timer/category columns on service_bookings; payout timer extensions also absent.
- Earlier and release-copy migration SQL mostly matches, but 15000 and 16012 differ materially. Release copy 16012 requires an immutable payable snapshot for timer bookings and changes payout trigger wiring. Do not apply 15000 as a substitute.
- 16015 cannot be applied alone. Admin UI currently expects timer refund fields/RPC absent in Production; broader timer foundation must be designed, replayed and tested in disposable parity DB first.
- Read-only audit only; no Production changes or deployment.


### Extended Timer release-chain / CI review (2026-11-12)
- Corrected full release scope: Timer release migrations span 16000–16015. Additional files 16004–16014 cover server-authoritative booking creation, labour precision, customer-approved material revisions, Razorpay order/payment ledger, cash intent/receipt confirmation, cancellation decisions, and customer call contacts after assignment.
- 16004 initially requires preferred_time; later 20261112130000 makes it optional and 20261112140000 adds duration_hours 1–8 and estimated labour snapshot. Combined release replay must include these later migrations and assert final date-only UI/RPC behavior. No arbitrary default time.
- Existing timer-billing CI replays 16000–16014 twice on a disposable Production-shaped baseline and verifies legacy payout preservation, but does not include 16015 in that same parity loop. Refund workflow separately tests 16015 on a synthetic refund harness. Integrated timer+refund+date-only/duration parity replay remains required.
- 16014 preserves customer access to electrician phone after accepted assignment even after completion; keep consistent with approved contact policy.
- Production remains without Timer foundation. All work remains read-only against Production; no deployment.
