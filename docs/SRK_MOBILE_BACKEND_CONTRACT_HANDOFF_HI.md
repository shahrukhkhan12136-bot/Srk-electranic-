# SRK ELECTRONIC — Customer/Technician Mobile Backend Contract Handoff

**स्थिति:** GPT-2 / Backend owner के review और लिखित API/RPC contract के लिए प्रस्ताव
**शाखा:** feature/playstore-mobile-apps-gpt1-20261121
**तैयार:** 21 नवम्बर 2026
**सीमा:** यह केवल frontend handoff document है। इससे backend, database, migrations, payment provider, production या Main branch में कोई बदलाव अधिकृत नहीं होता।

## 1. उद्देश्य और सुरक्षित मौजूदा आधार

Customer और Technician Android apps के frontend को आगे बढ़ाने के लिए backend के exact request/response contracts चाहिए। मौजूदा booking system को फिर से नहीं बनाना है। मौजूदा OTP, booking history, offer accept/decline, assigned booking, contacts, location, complaints/cancellation, payment verification और earnings जैसे उपयोगी flows को जहाँ तक संभव हो preserve करना है।

**Quotation workflow समाप्त होना है:** Customer quote create/approve/reject नहीं करेगा; Technician quote submit नहीं करेगा। Parts/materials का अलग itemized विवरण और ग्राहक की स्पष्ट स्वीकृति quotation नहीं है और आवश्यक होने पर बना रहेगा।

मौजूदा backend में work-start, cash confirmation और Razorpay create-order/verification/webhook paths quote approval पर निर्भर हैं। इसलिए नया quote-free lifecycle backend में तैयार और test होने से पहले frontend से quote actions हटाना सुरक्षित नहीं।

## 2. Service catalogue contract

Customer Dashboard पर छह top-level categories का क्रम:
1. Electrician
2. Plumber
3. Painter
4. AC + Fridge
5. Motor & Pump
6. Cooler

AC + Fridge के अंदर पहले AC या Fridge चुना जाएगा, फिर केवल उसी के संबंधित काम दिखेंगे। Helper अलग top-level category नहीं होगा; जहाँ लागू हो booking के भीतर optional helper selection होगा।

### ज्ञात subcategories
- Electrician: Wiring; Fan installation/repair; Switch/socket; Light installation; MCB/distribution board; Inverter/battery; Electrical appliance repair; Other electrical work.
- AC: Repair; Installation; Uninstallation; Servicing; Gas charging; Leakage check; Compressor; PCB.
- Fridge: Refrigerator repair; Cooling problem; Compressor; Gas/leakage; PCB/other repair.
- Motor & Pump: Domestic Tullu pump; Pump repair; Submersible pump; Winding; Capacitor; Starter; Installation/removal.
- Cooler: Cooler Repair only. Fixed labour ₹500 per cooler; parts/materials separate. Cooler motor winding is a Motor & Pump service, not part of the fixed Cooler Repair price.
- Plumber/Painter: detailed subcategory lists are not finalized in the current mobile UI. Backend must not invent IDs or expose unsupported options; owner-approved catalogue IDs are required.

### Backend must provide
- Stable category_id, subcategory_id, optional task_id, Hindi/English display labels, active flag, sort order and catalogue version.
- Technician profile skills as separately verified records: requested vs approved category, approved subcategory/task IDs, verification status, reviewer, timestamp and expiry/review status.
- Dispatch eligibility must match the exact selected category and verified skill. No silent category upgrade/downgrade.
- AC refrigerant/gas charging and sealed-system fridge repair must require the relevant specialist skill verification.
- Helper availability/skill eligibility must be represented separately; selecting helper must not bypass skill checks.
- Catalogue API response and version must be deterministic; unknown/inactive IDs must be rejected server-side.

## 3. Booking create/read contract

Preserve the existing booking flow and its useful fields, but add an explicit versioned contract for new service categories. Proposed request fields (final names to be agreed):
- category_id, subcategory_id, optional task_id
- helper_required and, if needed, helper count/type
- duration_value, duration_unit (hour/day) where supported
- motor_hp only for the HP-priced Motor & Pump winding path
- customer verified identity, address, PIN, GPS pair, preferred date/time and work notes
- payment_method only where current business rule permits the customer to choose it

The server must validate all IDs, duration bounds, required conditional fields and customer ownership. It must create one booking and one dispatch queue entry idempotently. It must return booking ID, normalized service details, status, server-confirmed estimate/rate snapshot, payment eligibility and clear no-eligible-technician response.

**Do not connect the new dashboard picker to live booking submission until this contract and verified-skill dispatch are implemented.** Current /api/create-booking accepts a free-text service_type and does not yet express the complete six-category/skill/helper/duration/HP contract.

## 4. Rates and pricing rules requiring server snapshots

Use only owner-confirmed rate tables. Rate and formula must be versioned/snapshotted on booking creation so later rate changes do not rewrite old bookings.

Known current owner decisions recorded in project context:
- Electrician: Basic ₹100/hour; Expert Residential ₹1,000/8 hours; Expert with helper ₹1,500/8 hours; Factory/Large Project ₹400/hour; Factory with helper ₹550/hour; Master ₹700/hour; Master with helper ₹950/hour.
- Plumber: Basic ₹100/hour + helper ₹50/hour; Expert ₹150/hour + helper ₹75/hour; Master/Industrial ₹225/hour + helper ₹100/hour. Pipe, fittings and materials excluded.
- Painter: Basic ₹700/8 hours; Expert ₹900/8 hours + helper ₹75/hour; Master/Commercial ₹1,200/8 hours + helper ₹100/hour.
- AC Technician: ₹437/hour. AC helper rate is not confirmed.
- Fridge hourly/helper rates are not owner-confirmed; do not publish/charge them as final.
- Cooler Repair: fixed labour ₹500 per cooler; no hourly overtime multiplier.
- Motor & Pump winding: fixed HP rates: 0.5 HP ₹500; 1 HP ₹600; 1.5 HP ₹700; 2 HP ₹800; 3 HP ₹900; 5 HP ₹1,000; 7.5 HP ₹1,100; 10 HP ₹1,200; 15 HP ₹1,300; 20 HP ₹1,400. Above 20 HP not confirmed. Winding is fixed HP-based, not hourly/overtime.

For each booking, backend must return labour/rate basis, unit, quantity/duration, rate version and rate snapshot; helper fee separately; materials/parts separately; estimate vs final bill distinction; currency in integer paise; all applicable charges and customer-visible explanation.

**Open owner decisions:** whether durations can exceed the booked amount/period, exact rounding for fractional hourly amounts, travel charges, minimum billable time, and any category rates not explicitly confirmed. Do not guess.

**Conflict requiring owner/backend reconciliation:** another Master Requirements document currently contains a different four-tier Electrician rate table and an older category scope. The six-category service catalogue and rates above reflect later project decisions captured in this frontend handoff. Backend owner must confirm the authoritative current rate version before implementation; do not combine the two tables.

## 5. Quote-free work lifecycle and materials approval

Proposed new lifecycle, exact statuses/RPC names to be returned by backend owner:
1. Booking created
2. Offered to eligible verified technician(s)
3. Technician accepts; single-winner assignment
4. Technician en route / arrived (only if supported by trusted location/status events)
5. Technician requests work start
6. Customer confirms start; server timer starts
7. Work may be paused/resumed only under an explicit supported contract
8. Technician submits completion request
9. Customer confirms completion, or Admin review/override follows a documented dispute path
10. Server calculates final labour and bill
11. Customer pays through the allowed payment method
12. Booking closes; receipt and ledgers reconcile

No quote/inspection/quote approval states in new bookings.

If parts/materials are needed:
- Technician submits itemized line items: item ID/name, quantity, unit, unit price, tax if applicable, line total, evidence/notes.
- Customer explicitly approves or rejects/requests correction for the material list.
- No material purchase/charge may be treated as approved without the required customer action.
- Material approvals must be independent from the labour/work-start lifecycle; they must not recreate a quotation/counter-offer flow.
- Backend returns approved/rejected/pending item states, immutable approval actor/time and approved material total.
- Materials must not be silently merged into labour.

Backend must provide state-transition RPCs, allowed transitions, authorization checks, duplicate-tap idempotency, timestamps from server, event history, timeout/dispute behavior and backward compatibility for historical quote-based bookings.

## 6. Technician matching and offers

Backend must return only eligible technicians:
- exact category and verified subcategory/task skill match
- approved + active account, online/available status and no blocking active assignment
- locality/PIN/district/GPS distance and configured radius (30 km rule only if confirmed in current approved requirements)
- offer order/expiry, next candidate behavior, rejection/timeout behavior
- single-winner assignment and database-level race protection for simultaneous accept
- privacy-safe offer payload before acceptance; customer phone/address/GPS only after authorized assignment
- explicit no eligible technician outcome; never silently dispatch to another category

Technician onboarding/profile contract must include requested skills, documents, review state, approved skills, rejection reason, profile activation and unique technician ID where applicable.

## 7. Customer payment and technician money contract

The backend must reconcile the current Razorpay paths, cash confirmation, payment ledger, earnings and payout. Do not merely hide quote checks in the frontend.

Required APIs/RPCs: payment eligibility and authoritative payable amount; Razorpay order creation, signature/capture verification and webhook reconciliation; cash collection confirmation and idempotency; payment pending/failed/verified/refund/partial-refund states; customer receipt and booking/payment history; technician earnings statement, cash dues, platform fee ledger, payout request/status and actual transfer reference/UTR where enabled.

**Payment-method cycle:** Project requirements describe first two eligible bookings as Cash-eligible and the third as Online-only, with verified top-up and outstanding platform-fee rules. The exact counter scope, eligibility definition, reservation/locking and reset rules must be confirmed against the current database before implementation. Customer should see only server-returned allowed methods; do not silently change a customer selection.

**Owner clarification (21 Nov 2026):** The owner has reconfirmed that the existing split remains unchanged: **Company platform fee = 15%; Technician share = 85%**. This is the previously specified split on the full booking payment (not a newly introduced percentage or a labour-only replacement). Example: if the customer pays ₹1,000 for the booking, ₹150 is the company share and ₹850 is the technician share. The earlier 15%/85% percentage decision is therefore closed; do not ask the owner to reconfirm the percentages.

**Backend reconciliation still required:** The current Master Requirements file contains older wording that calculates the 15% fee on labour/service only and excludes materials. That older wording must be reconciled with this later owner-confirmed full-booking split; do not silently let it override the latest clarification. Backend must implement one consistent server-side ledger formula and document how helper charges, materials, tax, travel, cancellations/refunds, paise rounding, cash collections and online settlements are represented, without changing the confirmed 15%/85% split. Example values above are a simple split illustration, not a statement that every ledger component has been separately specified.

Wallet balance is not proof of bank payout. Payout must only be marked Paid after provider transfer success and a verified transfer reference.

## 8. Required backend response pack

Please return, in writing:
1. Final catalogue IDs and technician skill schema.
2. Exact Customer booking request/response JSON and validation errors.
3. Exact Technician offer/assigned-booking payloads.
4. RPC/Edge Function names, parameters, return schema and auth/ownership rules.
5. New quote-free status enum and transition table.
6. Materials itemization and customer approval API contract.
7. Server rate calculation and immutable booking rate snapshot.
8. Payment eligibility, Cash-cycle and Razorpay contract, including webhooks/refunds.
9. Commission/platform-fee formula, wallet ledger and actual payout contract.
10. Legacy quote-booking read-only compatibility strategy.
11. Unit/integration/security/race/idempotency test cases and migration sequencing plan.

## 9. Frontend guardrails until the contract is accepted

- Preserve existing booking, OTP, offer, contact, complaint, cancellation, map, payment and earnings features where currently valid.
- Do not rebuild the existing booking system from scratch.
- Do not connect category picker to booking submission yet.
- Do not remove quote-dependent UI until replacement APIs and lifecycle are implemented and tested in an approved backend feature branch.
- Do not invent plumber/painter subcategories or unconfirmed AC/fridge rates.
- Do not change database, migrations, backend functions, production settings, Main branch, live payment or deployment in this frontend task.
- No Admin Android app; Admin remains web panel.
- A feature is not complete until source, analyzer, tests, Android build and relevant end-to-end behavior are verified.

## 10. Current frontend evidence

- Customer Dashboard category picker exists as preview-only and does not submit a booking.
- Existing Customer booking form, old service dropdown, /api/create-booking, payment method selector, history and quote-dependent legacy actions remain in place.
- Technician offer accept/decline, assigned booking, map/contact, work status, cash confirmation and earnings/wallet remain.
- Customer suggested-amount entry/display has been removed from the current UI.
- Widget tests for six-category order, AC/Fridge task isolation and Cooler selection are committed but not yet executed.
- No Dart analyzer, Flutter test run, Android build, CI run or physical-device test has yet been verified.

## 10. Technician app — verified-skill offer and booking contract

### Current frontend evidence (read-only audit, 21 Nov 2026)
- Technician dashboard profile query currently reads only `id, display_name, state, district, pincode, active, verification_status`; it does not read a normalized approved-skill list.
- Offer list/details are loaded from `job_offers`, `srk_get_my_offer_details` and legacy price-detail RPCs. The UI displays `service_type` and work details but does not independently verify category/subcategory/task eligibility.
- The app must not treat the legacy free-text `electrician_profiles.skills` field as proof of Admin-approved category skill.
- Therefore the current frontend cannot establish that an offer is category-safe. Eligibility must be enforced by backend dispatch and every offer/assignment RPC.

### Required backend response contract (no schema or RPC change in this frontend task)
1. Technician profile response should include a server-authoritative `verified_service_skills` collection. Each entry should carry stable `category_id`, `subcategory_id`, optional `task_id` and `skill_tier_id`, plus `verification_status`, `active`, `verified_at`, optional `valid_until`, and a display/catalogue version reference.
2. Only skills with approved verification, active profile and active skill record may qualify. Pending, rejected, expired, paused or text-only skills must never qualify.
3. Offer response should include the booking's canonical `category_id`, `subcategory_id`, optional `task_id` and required `skill_tier_id`, catalogue version, and a backend eligibility/authorization result. The backend must have already matched the exact required skill to the logged-in Technician.
4. Offer inbox RPC must return only offers owned by the logged-in Technician and eligible under current verified skills. Do not rely on Flutter-side filtering as a security or dispatch control.
5. Accept RPC must re-check current profile activation, skill approval/expiry, booking state, offer expiry and single-winner race atomically. A stale or revoked skill must cause a clear rejection, not assignment.
6. Assigned-booking detail, work-start/status, material approval, completion and payment RPCs must re-check booking ownership and the required skill/authorization server-side. Hiding an ineligible card is not sufficient authorization.
7. AC and Fridge must remain separate skill IDs. AC refrigerant/gas charging and sealed-system fridge repair require the relevant specialist task skill; a general AC/Fridge category flag is insufficient.
8. Technician UI may show a read-only “आपकी सत्यापित सेवाएँ” list sourced from this response. It must not offer self-approval, skill editing, rate override or eligibility override. Skill application/review belongs to its separately authorized onboarding/Admin process.
9. No matching verified skill must produce an explicit “इस काम के लिए आपकी सत्यापित skill उपलब्ध नहीं है” / no-eligible-technician outcome from backend. Never silently fall back to another trade/category.
10. Keep the existing offer accept/decline, map, authorized customer contact, work-status, cash confirmation and earnings flows unless their replacement contract is implemented and tested. Quote-dependent lifecycle remains separately blocked as already recorded above.

### Frontend implementation gate
- Do not add a client-side category filter against free-text skills or guessed profile columns.
- Do not add a new Supabase select field or RPC name until backend publishes the exact deployed schema and response shape.
- Once the contract is available, add typed parsing, empty/loading/error states, verified-skill display, offer-to-skill match presentation and widget tests. Treat missing/unknown IDs as non-eligible and fail closed.
- Before enabling live offers, test approved, pending, rejected, expired and revoked skills; AC-vs-Fridge separation; specialist gas/sealed-system tasks; duplicate accept race; and reassignment after skill revocation.
- No backend, SQL, database, production or payment code was changed by this audit.


## 11. Technician verified-services UI prototype (21 Nov 2026)
- Added isolated typed model `SrkVerifiedServiceSkill` and read-only `SrkVerifiedServicesPanel` under `apps/electrician_app/lib/verified_services/`.
- Parser accepts only explicit `approved` + `active == true` records with non-empty category/subcategory IDs and labels; an expired `valid_until` is rejected. Unknown/missing status or IDs fail closed.
- Panel is presentation-only and explicitly states that booking eligibility is server-authoritative. It is not connected to profile query, offer inbox, accept action, assignment, work-start or payment.
- Contract field names are a proposed frontend shape only. Do not add them to Supabase queries until backend confirms deployed JSON/schema exactly.
- Added tests for approved, pending, rejected, inactive, expired, missing IDs, AC/Fridge separation and empty/non-empty panel.
- Technician CI now runs `flutter test` after `dart analyze`; execution remains pending until the workflow is actually run.


## 12. Offer-to-skill match preview helper (21 Nov 2026)
- Added a pure preview helper that compares exact canonical category/subcategory and, when present, task/tier IDs against already parsed verified skills.
- Missing canonical IDs return `unknown`; an exact mismatch returns `notMatched`; exact match returns `matched`.
- This helper is not wired into offer inbox filtering, accept/decline, assignment or work actions. It is not authorization; backend must independently enforce eligibility.
- Tests cover exact match, trade/subcategory mismatch, specialist task/tier mismatch and missing canonical IDs.


## 13. Assigned-booking lifecycle frontend audit and preview helper (21 Nov 2026)

- Current Technician assigned-booking card reads assigned, inspection, awaiting_quote_approval, quote_approved, quote_rejected, in_progress and completed records.
- Existing actions are: start inspection from assigned; start work only from quote_approved; complete work only from in_progress; confirm cash only for completed cash bookings whose payment is not paid.
- Existing card also displays booking location/map action, authorized customer phone, labour/material/quoted total, quote note, payment state, completed earnings and wallet summary. Preserve these until their replacement contracts are verified.
- Added an isolated read-only presentation mapper for the currently deployed status strings. The three quote-related states are explicitly flagged as legacy. Unknown/missing states remain unknown and do not imply an allowed action.
- Added unit tests for current-state mapping, legacy-state identification, completed terminal display and unknown/missing states.
- The helper is not wired into the live dashboard and does not define or authorize transitions. No RPC, database, payment, offer, booking or production behavior changed.
- Backend must still provide and deploy the quote-free status enum/transition table, customer work-start/completion confirmation, independent materials approval, duplicate-safe payment/cash and historical quote-booking compatibility before the frontend can safely replace current quote-dependent screens/actions.


## 14. Customer ↔ Technician start/completion confirmation gap (21 Nov 2026)

### Existing frontend evidence
- Customer app reads booking status/payment/quote fields from `service_bookings`. It can approve/reject only the legacy pending quote, cancel only new/confirmed bookings, create complaints, view assigned Technician contact and pay online only when the booking is completed, unpaid and quote-approved.
- Customer app currently has no separate customer confirmation action/RPC for work-start or work-completion.
- Technician app can move assigned → inspection; only legacy quote_approved → in_progress; and in_progress → completed. Cash confirmation remains tied to completed cash bookings and the backend's quote approval requirement.
- Preserve map navigation, authorized contacts, itemized labour/material/total visibility, cancellation restrictions, complaint/support, payment verification, earnings and wallet unless an approved replacement is implemented.

### Required quote-free cross-app contract
1. Backend publishes new lifecycle statuses and an explicit transition/authorization matrix, including compatibility for historical quote-based bookings.
2. Technician submits a work-start request; only the owning Customer can confirm it. Server starts the timer using server time only after confirmation.
3. Technician submits completion request; owning Customer receives a completion summary and can confirm or raise a dispute. Backend defines timeout, dispute and Admin override behavior before UI is built.
4. Material/parts requests are itemized and approved separately by Customer; this must not recreate quote/counter-offer states.
5. Every transition validates booking ownership, assigned Technician, active verified skill, current status/version and idempotency key server-side. Duplicate taps/retries must not duplicate timer events, completion or charges.
6. Final bill response separates labour, approved materials, other applicable charges and total; payment eligibility/method and receipt are server-authoritative.
7. Preserve or explicitly replace existing cancellation, complaints, privacy-guarded contacts, payment verification, earnings and wallet behaviors in the transition matrix.

**Frontend gate:** Do not add Customer confirmation buttons or alter Technician status buttons against current RPCs. The exact replacement RPCs, payloads, states and error contracts must first be deployed/tested by backend owner. This audit changes no app runtime, backend, database, payment or production behavior.

## 15. Proposed work-confirmation DTO and server-timer preview (21 Nov 2026)

Frontend has added an isolated read-only DTO/test prototype only. The proposed names below are illustrative and are NOT a deployed API contract:

- Proposed fields: `booking_id`, `request_id`, `requester_role`, `requested_action`, `state`, `server_requested_at`, `server_confirmed_at`, `server_started_at`, `server_completed_at`, `version`, `idempotency_key`.
- Proposed preview states: `start_requested`, `start_confirmation_pending`, `start_confirmed`, `completion_requested`, `completion_confirmation_pending`, `completion_confirmed`, `disputed`. Unknown values fail closed.
- Frontend may present a timer as active only if server confirmation and server start timestamps both exist and server completion timestamp is absent. It does not calculate elapsed time from the device clock.
- Duplicate request recognition uses a non-empty booking ID + request ID pair only; backend must enforce idempotency transactionally.

**Backend must publish before live integration:** exact RPC names and request/response/error JSON; authoritative state enum and transition matrix; customer-owner and assigned-technician authorization; skill revalidation; server timestamp source/meaning; optimistic version conflict rules; idempotency storage/retention and retry semantics; material approval separation; completion confirmation/dispute/timeout/Admin override; and historical quote-booking compatibility.

Do not connect this prototype to Customer/Technician screens, buttons, Supabase queries or existing work-status RPCs yet. It does not authorize a transition or create a timer. Existing live booking, quote, payment, cash, map/contact, earnings and wallet paths remain untouched.

## 16. Customer confirmation and final-bill presentation preview (21 Nov 2026)

The Customer app now has an isolated read-only presentation model and tests. All field names below are proposals, not deployed schema:

- Confirmation states: `start_confirmation_pending`, `completion_confirmation_pending`, `start_confirmed`, `completion_confirmed`, `disputed`, plus other/unknown.
- Suggested final-bill fields in integer paise: `labour_amount_paise`, `approved_materials_amount_paise`, `other_charges_amount_paise`, `total_amount_paise`, `currency`, `payment_status`, `payment_method`, `payment_eligibility`, `receipt_id`.
- The UI preview may flag pending customer attention but must not enable a confirmation action without the exact deployed RPC, ownership and version checks.
- Amount breakdown is checked for non-negative integer paise and exact equality to the server-provided total. A mismatch must be surfaced for refresh/review; never silently recompute or overwrite the server total.
- Payment eligibility is informational only. Every order-creation/payment request must revalidate eligibility, amount, booking owner, current status and idempotency on the server.

**Backend must define:** exact field names/types and nullability; INR/currency and paise rounding rules; labour/material/other-charge and tax/fee semantics; proof of customer material approval; authoritative total; payment-method/status and eligibility rules; receipt identity/content; confirmation request ownership, idempotency, dispute/timeout/Admin override and historical quote compatibility.

Do not connect this model to the live Customer booking card, confirmation buttons, receipt or Razorpay flow until backend contract is deployed and verified. Existing booking, quote, cancel, complaint, contact privacy and cash/online payment paths remain untouched.


## 17. Shared Customer + Technician confirmation and final-bill DTO (21 Nov 2026)

Frontend added `packages/srk_mobile_core/lib/srk_work_confirmation_contract.dart` and exports it from the shared core barrel. Both mobile apps can consume the same proposed field model instead of maintaining separate local definitions. This is a preview DTO only, not a deployed API contract.

**Proposed confirmation fields:** `booking_id`, `request_id`, `requester_role`, `requested_action`, `state`, `version`, `idempotency_key`, `server_requested_at`, `server_confirmed_at`, `server_started_at`, `server_completed_at`.

**Proposed bill fields:** `labour_amount_paise`, `approved_materials_amount_paise`, `other_charges_amount_paise`, `total_amount_paise`, `currency`, `payment_status`, `payment_method`, `payment_eligibility`, `receipt_id`. Amounts are integer paise; frontend validation requires non-negative integer components and exact equality to the server-provided total.

**Frontend safety rules:**
- Unknown enum values and missing version parse to unknown/-1; they must not enable actions.
- Timer presentation may be active only for proposed `start_confirmed` when server confirmation and server start timestamps both exist and server completion timestamp is absent. Device time is not used to create/start the timer.
- Payment eligibility is display-only; backend must revalidate owner, status, amount, method, idempotency and eligibility on every payment/order request.
- DTO is shared code only; no live Customer/Technician UI, Supabase query, RPC, booking state, payment, quote, cancellation, complaint or production behavior changed.

**Backend must confirm before integration:** exact RPC names, request/response/error JSON and nullability; canonical state/action/actor enums; owner/assigned-technician/verified-skill checks; server timestamp semantics; version conflict and transactional idempotency behavior; material approval evidence; bill/tax/fee/rounding/currency rules; authoritative payment eligibility/method; receipt contract; timeout/dispute/Admin override; and compatibility for historical quote bookings.

Tests were added in `packages/srk_mobile_core/test/srk_work_confirmation_contract_test.dart`. They have not yet been executed; analyzer/formatter/Android builds/device tests also remain unverified.


## 18. Mobile API inventory and cross-app implementation map (21 Nov 2026)

See `docs/SRK_MOBILE_API_INVENTORY_AND_CROSS_APP_MAP_HI.md` for the source-audited current Customer and Technician API/RPC inventory, quote-dependent legacy lifecycle, proposed quote-free endpoint capabilities, shared DTO fields and ordered backend rollout/acceptance gates.

This inventory is a frontend source audit, not proof that every migration is deployed in production. Proposed API names are illustrative only. Backend owner must publish exact deployed routes, request/response/error schemas, authorization, idempotency, server-time and amount/ledger semantics before frontend wiring. No backend/database/payment/production changes were made.


## 19. Shared service catalogue and draft identifier contract (21 Nov 2026)

Frontend now maintains one shared draft catalogue in `packages/srk_mobile_core/lib/srk_service_catalog.dart` and the Customer category picker adapts from it instead of keeping a second hard-coded list.

- Draft version: `draft-2026-11-21.1`.
- Six top-level keys: `electrician`, `plumber`, `painter`, `ac_fridge`, `motor_pump`, `cooler`.
- Shared data includes Hindi display labels, icon keys, known subcategory keys/labels, AC and Fridge task labels, and existing draft rate presentation.
- AC and Fridge task keys are separately scoped. Plumber/Painter task lists remain intentionally empty until the owner confirms the task taxonomy.
- Existing unconfirmed prices/helper rules remain unfilled; Fridge final rate and any other unconfirmed pricing must be supplied by the owner/Admin contract.
- These keys are frontend draft identifiers only. They are not canonical deployed backend IDs, do not authorize a Technician skill, and must not be submitted to the current booking API or used for dispatch/payment.

**Backend response required before integration:** approve a canonical catalogue version and immutable category/subcategory/task/skill-tier IDs; define localization/display labels separately from IDs; provide rate snapshot and helper/task structures with effective dates; define retired-ID compatibility for existing bookings; and return verified Technician skills using those exact IDs/version. Offer matching and every accept/work/payment transition must revalidate skills server-side.

This source change only unifies presentation data and Customer picker rendering. Existing booking submission, Technician live skill/offer screens, booking lifecycle, APIs, Supabase, database, payment and production remain unchanged. Flutter formatting, analyzer, tests and Android builds have not been executed/verified.


## 20. Technician verified-skill IDs का shared catalogue validation (21 Nov 2026)

Technician app adds a separate preview parser, `SrkVerifiedServiceSkill.fromDraftCatalogueServerJson`, that accepts a skill only when:
- `catalogue_version` exactly matches the current frontend draft version `draft-2026-11-21.1`;
- category and subcategory IDs exist in the shared draft catalogue;
- an optional task ID exists under that exact subcategory;
- existing approved + active + non-expired checks pass.

Display labels are resolved from the shared catalogue rather than trusting potentially stale server labels. Unknown IDs/version fail closed. A task key under Fridge cannot be accepted as an AC task (and vice versa). The verified-services barrel exports were also corrected to point at the actual source files.

**Not authorization:** This parser is not connected to live profile data, offer filtering, offer acceptance, work status, material approval, cash/online payment or payouts. Existing generic skill parsing and offer-match helper remain preview-only. Client matching must never hide/authorize an offer; backend must independently verify active approved skills, booking ownership, assignment, expiry, canonical catalogue version and all state transitions.

**Backend response required:** approve immutable canonical IDs/version and exact JSON contract; specify skill granularity for category/subcategory/task/tier, expiry/revocation semantics, and transactional revalidation on offer read/accept and each protected work/payment action. The current draft version is not a production identifier. No Supabase, backend, database, payment or production change was made. Flutter formatter/analyzer/tests/Android build have not been executed or verified.


## 21. Offer-to-skill preview matching against shared catalogue (21 Nov 2026)

Added `previewOfferSkillMatchAgainstDraftCatalogue` as a separate read-only preview helper.

It requires the offer's `catalogue_version` to equal the shared draft version and validates category/subcategory IDs against the shared catalogue. If the offer includes a task ID, it must exist under that exact subcategory. A task-specific offer against a subcategory whose task taxonomy is not yet defined returns `unknown`, not a false positive. Only Technician skill records carrying the same draft catalogue version are considered for a match.

Preview result semantics:
- `matched`: known category/subcategory/task and version align with a same-version parsed Technician skill;
- `notMatched`: known IDs do not align with any same-version skill;
- `unknown`: missing/old catalogue version or task taxonomy not yet defined.

This helper is not connected to live offer filtering/hiding, acceptance, dispatch, work status, material approval, payment or payouts. It must not be used as authorization. Backend remains authoritative and must independently validate active approved skill, current catalogue version, offer eligibility, assignment, ownership, expiry/revocation and state version atomically at each protected action. No live API/Supabase/backend/database/payment/production behavior changed. Tests, formatter, analyzer and Android build have not been executed.

## 22. Shared Customer → Booking → Technician service identity DTO (21 Nov 2026)

Frontend added `packages/srk_mobile_core/lib/srk_service_selection_contract.dart` with `SrkServiceSelection`, exported from `srk_mobile_core.dart`.

The Customer Dashboard picker emits this DTO as a preview selection. The Technician preview matcher consumes the same versioned identifier shape when comparing an offer with a verified skill. This gives both apps one frontend contract rather than separate label-based representations.

Proposed payload shape:
```json
{
  "catalogue_version": "draft-2026-11-21.1",
  "category_id": "ac_fridge",
  "subcategory_id": "ac",
  "task_id": "gas_charging"
}
```

Rules:
- `category_id` is required; `subcategory_id` and `task_id` are conditional.
- `task_id` must belong to the exact selected subcategory; AC task IDs cannot be used for Fridge and vice versa.
- The frontend factory rejects unknown or mismatched hierarchy IDs.
- Labels are display-only; backend resolves authoritative labels and active state from its own catalogue.
- The current version and IDs are frontend draft identifiers only. Backend must explicitly approve/map a canonical version before production accepts them.
- Backend booking creation must validate the version and every ID, snapshot the resolved service identity on the booking, and return the normalized identity.
- Dispatch must copy the exact booking identity into the offer. Technician verified skills and offer must use the same backend-approved version and IDs.
- The server must independently re-check approved/active/unexpired skill, assignment, booking ownership, current state/version and idempotency on accept and every protected work/material/payment transition.

**Not integrated:** Customer Dashboard picker still previews only. Existing `POST /api/create-booking` payload and booking form remain unchanged; no new Supabase query/RPC, offer filtering, dispatch, payment or production behavior was added. Do not send this draft version to production until backend approval and coordinated rollout.


## 23. Customer booking service identity rollout plan

Detailed staged rollout and backend acceptance gates are documented in `docs/SRK_CUSTOMER_BOOKING_SERVICE_ID_INTEGRATION_PLAN_HI.md`. It records the current legacy create-booking payload, proposed additional structured fields, normalized booking response, immutable booking-to-offer snapshot, legacy compatibility, staging gates and rollback requirements. Draft IDs must not be sent to production before backend approval. No live API/backend/database/payment changes were made.
