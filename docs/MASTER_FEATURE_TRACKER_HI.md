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
- [I] `20261112170000_public_customer_rate_catalogue_rpc.sql` ग्राहक को केवल चार वर्तमान प्रभावी श्रेणी-दरें पढ़ने देता है; catalogue table का direct SELECT अब भी बंद है। Customer booking UI live RPC से rate/version लेता है, estimate उसी rate से दिखाता है और RPC/error/अपूर्ण data पर booking submit बंद रखता है।
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
