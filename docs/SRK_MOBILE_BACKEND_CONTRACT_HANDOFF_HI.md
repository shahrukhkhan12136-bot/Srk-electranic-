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