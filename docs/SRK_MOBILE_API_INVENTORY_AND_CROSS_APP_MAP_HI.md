# SRK ELECTRONIC — Mobile API Inventory और Customer/Technician Mapping

तारीख: 21-11-2026  
शाखा: `feature/playstore-mobile-apps-gpt1-20261121`

## 1. उद्देश्य और सुरक्षा सीमा

यह दस्तावेज़ मौजूदा Customer और Technician ऐप में वास्तव में उपयोग हो रही API/RPC का inventory और प्रस्तावित quote-free lifecycle की API सूची देता है।

- मौजूदा API का नाम और उपयोग स्रोत कोड से पढ़ा गया है; यह live production deployment की स्वतंत्र जाँच नहीं है।
- जहाँ migration में implementation दिखता है, वहाँ उसे migration-defined behavior कहा गया है। इसे production में deployed होने का प्रमाण न मानें।
- प्रस्तावित API नाम केवल contract सुझाव हैं; backend owner की पुष्टि और deployment से पहले इन्हें frontend में कॉल न करें।
- मौजूदा booking form, offer accept/decline, map/contact, complaints, cancellation, cash/online payment, earnings/wallet को बिना replacement और compatibility audit हटाना मना है।
- कोई backend, database, migration, payment, production या Main branch परिवर्तन इस दस्तावेज़ से अधिकृत नहीं होता।

## 2. मौजूदा Customer App API/RPC

| मौजूदा स्रोत/नाम | ऐप में उपयोग | वर्तमान निर्भरता / सावधानी |
|---|---|---|
| Supabase Auth OTP | ग्राहक login/session | मौजूदा authentication सुरक्षित रखें। |
| `service_bookings` SELECT | ग्राहक की अपनी अधिकतम 50 bookings | status, payment, quote, date/time और amount fields पढ़े जाते हैं। |
| `srk_customer_get_my_booking_contacts` | नियुक्त technician का फोन | backend द्वारा authorized booking तक सीमित; privacy guard सुरक्षित रखें। |
| `srk_customer_list_booking_complaints` | ग्राहक की शिकायत सूची | complaint/support इतिहास सुरक्षित रखें। |
| `srk_customer_create_booking_complaint(p_booking_id,p_category,p_description)` | शिकायत दर्ज करना | owner validation और मौजूदा complaint categories/records सुरक्षित रखें। |
| `srk_customer_cancel_my_booking(p_booking_id)` | booking cancel | केवल own, unassigned new/confirmed booking के लिए मौजूदा सीमा सुरक्षित रखें। |
| `srk_customer_respond_booking_quote(p_booking_id,p_response)` | legacy quote approve/reject | quote-dependent; quote-free replacement और historical compatibility के पहले न हटाएँ। |
| `POST /api/create-booking` | नई booking बनाना | वर्तमान payload में customer/address/service/date/time/work/payment method/GPS है; structured category IDs अभी नहीं। |
| `POST /api/create-order` | Razorpay order | मौजूदा backend में completed, unpaid, online और quote-approved checks हैं। |
| `POST /api/verify-payment` | Razorpay payment verification | server-side signature/capture/amount verification के बाद ही paid status मानें। |

## 3. मौजूदा Technician App API/RPC

| मौजूदा स्रोत/नाम | ऐप में उपयोग | वर्तमान निर्भरता / सावधानी |
|---|---|---|
| Supabase Auth OTP | technician login/session | सुरक्षित रखें। |
| `electrician_profiles` SELECT | technician profile | वर्तमान query में id/name/state/district/PIN/active/verification status; verified service skills शामिल नहीं। |
| `job_offers` SELECT | technician के offer rows | वर्तमान query technician profile ID के आधार पर सीमित है। |
| `srk_get_my_offer_details()` | offer + booking details | वर्तमान migration में offer और booking fields देता है; contact/location fields assignment-guarded हैं। |
| `srk_get_my_offer_price_details()` | quote/price details | legacy quote-dependent data; हटाने से पहले consumer और compatibility audit जरूरी। |
| `srk_respond_to_offer(p_offer_id,p_response)` | offer accept/decline | assignment race और server-side ownership/eligibility checks backend पर रहें। |
| `srk_get_my_assigned_booking_quote_details()` | assigned booking details | नाम quote वाला है लेकिन UI booking/payment/location data भी पढ़ता है; बिना replacement न हटाएँ। |
| `srk_electrician_get_my_assigned_booking_contacts()` | assigned customer phone | assignment-guarded contact privacy सुरक्षित रखें। |
| `srk_update_booking_work_status(p_booking_id,p_status)` | inspection/start/complete | मौजूदा start transition quote approval पर निर्भर; quote-free replacement से पहले live button न बदलें। |
| `srk_submit_booking_quote(p_booking_id,p_service_charge,p_materials_amount,p_quote_note)` | technician quote submit | legacy quote workflow; केवल backend replacement + old record compatibility के बाद हटे। |
| `srk_electrician_confirm_cash_payment(p_booking_id)` | cash receipt confirmation | वर्तमान backend quote approval सहित completed/cash/unpaid शर्तें जाँचता है। |
| `srk_get_my_earnings()` | earnings list | existing amount/commission semantics की जाँच जरूरी; controlling owner rule केवल service_charge/labour पर 15% company और 85% technician है; materials पर 0% commission। |
| `srk_get_my_wallet_summary()` | wallet summary | वर्तमान implementation में payout disabled बताया गया है; UI को actual payout का दावा नहीं करना चाहिए। |

## 4. मौजूदा lifecycle की मुख्य बाधाएँ

1. Technician assigned → inspection कर सकता है।
2. Technician work-start केवल `quote_approved` और quote status approved पर कर सकता है।
3. Completion केवल `in_progress` से किया जा सकता है।
4. Customer quote approve/reject केवल `awaiting_quote_approval` में कर सकता है।
5. Online order केवल completed + unpaid + online + quote-approved पर बनता है।
6. Cash confirmation completed + cash + unpaid के साथ quote approval भी जाँचता है।
7. Commission migration का service_charge-only आधार owner-confirmed rule से मेल खाता है: Company 15% और Technician 85% केवल labour/service charge पर; materials_amount पर commission/platform fee 0%।
8. Offer matching अभी PIN/district आधारित है; verified skill filtering या GPS radius को client-side authorization मानना गलत होगा।

## 5. प्रस्तावित quote-free API surface — backend design के लिए

नीचे दिए नाम उदाहरण हैं, deployed RPC names नहीं। Backend अपनी naming convention रख सकता है, पर response और सुरक्षा व्यवहार स्पष्ट होना चाहिए।

| प्रस्तावित क्षमता | कौन अनुरोध करेगा | आवश्यक server checks |
|---|---|---|
| Get booking lifecycle + confirmation summary | Customer और assigned Technician | booking owner/assigned technician, visible fields, legacy record compatibility |
| Request work start | assigned Technician | assignment, active verified skill, current state/version, duplicate-safe request |
| Confirm or reject work start | केवल booking का Customer | customer ownership, pending request ID, version, one-time confirmation |
| Request work completion | assigned Technician | active assignment, start confirmed, server timer/work record, idempotency |
| Confirm completion or dispute | केवल booking का Customer | customer ownership, completion request, version, duplicate-safe action |
| Get material/parts request | Customer और assigned Technician | assignment/ownership और itemized request scope |
| Request material/parts approval | assigned Technician | item, quantity, price, evidence, request idempotency |
| Approve/reject material request | केवल booking का Customer | ownership, exact request/version, immutable approval record |
| Get final bill | Customer और assigned Technician (role-specific fields) | server-calculated bill, approved material lines, tax/fee policy, currency |
| Get payment eligibility | Customer | owner, completed/confirmed status, due amount, payment state/method |
| Create payment order | Customer | server total, eligibility, idempotency, duplicate order protection |
| Verify payment / reconcile webhook | payment provider/backend | signature, captured state, amount/currency, booking/order binding, duplicate-safe ledger |
| Confirm cash received | assigned Technician; customer evidence/confirmation policy backend-defined | completed state, exact due amount, cash method, one-time ledger record |
| Get receipt | Customer; limited technician view if required | owner/assignment, immutable payment/final bill snapshot |
| Get technician earnings/wallet | logged-in Technician | ledger-derived amounts; platform fee and payout state authoritative |

## 6. दोनों ऐप में साझा data contract

एक ही backend response दोनों ऐप को देना चाहिए। Shared frontend DTO अभी केवल preview है:

### Work confirmation
- booking_id
- request_id
- requester_role
- requested_action
- state
- version
- idempotency_key
- server_requested_at
- server_confirmed_at
- server_started_at
- server_completed_at

### Final bill
- labour_amount_paise
- approved_materials_amount_paise
- other_charges_amount_paise
- total_amount_paise
- currency
- payment_status
- payment_method
- payment_eligibility
- receipt_id

Backend exact field types, nullability, enums और errors प्रकाशित करे। सभी रकम integer paise में हों; server total authoritative हो। Frontend केवल mismatch दिखाए, total को चुपचाप recompute/overwrite न करे।

## 7. Backend implementation order / acceptance gates

1. **Schema + read contract:** canonical category/subcategory/task IDs, booking lifecycle enum, version, audit timestamps; historical bookings पढ़ने की compatibility।
2. **Authorization matrix:** customer owner, assigned technician, verified active skills, Admin override और role-specific data visibility।
3. **Start confirmation:** technician request → customer confirmation → server timestamp से timer start; idempotency और version conflict।
4. **Materials:** itemized request → customer approval/rejection; approval evidence और price snapshot; quote/counter-offer से अलग।
5. **Completion confirmation:** technician completion request → customer confirm/dispute; timeout, dispute resolution और Admin override policy।
6. **Final bill:** labour, approved materials, other charges, taxes/fees, total, currency/rounding और immutable snapshot।
7. **Payment:** online order, verification/webhook, cash confirmation, refund/reconciliation और receipt; duplicate-safe ledger।
8. **Earnings/commission:** owner-approved 15% company / 85% technician on service_charge/labour only; materials/parts are excluded (0% platform fee). Define rounding, refund, tax, travel, helper, cash and online settlement treatment. Razorpay settlement/transfer must not be represented as instant payout unless actually completed.
9. **Offer skill matching:** verified skill server-side filtering and atomic accept re-check; no client-only filtering.
10. **Compatibility & rollout:** historical quote bookings, old RPC consumers, rollback plan, staging tests, RLS/permissions and production deployment evidence.
11. **Only after backend deployment:** frontend integration, contract tests, device tests, then release build.

## 8. Required backend response package

Backend owner से हर endpoint/RPC के लिए यह package चाहिए:
- exact RPC/HTTP route and HTTP method
- request JSON/parameter names, types, nullability and validation
- response JSON and stable enum values
- error codes/messages and retryable vs terminal errors
- authenticated role and row-level ownership/assignment checks
- idempotency key scope, uniqueness and retention
- optimistic version behavior and conflict response
- server timestamp definition
- amount/currency/rounding and ledger side effects
- audit log and webhook behavior where relevant
- migration/deployment version and staging test evidence

## 9. Frontend integration status

- Shared confirmation/final-bill DTO exists in `packages/srk_mobile_core/lib/srk_work_confirmation_contract.dart`.
- DTO is exported from `srk_mobile_core.dart`; it is not connected to live Supabase queries or UI.
- Customer and Technician existing API calls remain unchanged.
- No backend/database/payment/production changes were made.
- Flutter tests, analyzer, formatter, APK build and device tests have not yet been executed/verified.

## 9. Shared Customer → Booking → Technician service identity

A shared frontend DTO now exists at `packages/srk_mobile_core/lib/srk_service_selection_contract.dart`:

```json
{
  "catalogue_version": "draft-2026-11-21.1",
  "category_id": "ac_fridge",
  "subcategory_id": "ac",
  "task_id": "gas_charging"
}
```

- Customer Dashboard picker emits this DTO for preview; its IDs come from the shared service catalogue.
- Technician offer-skill preview compares the same versioned IDs with a same-version parsed verified skill.
- Category/subcategory/task hierarchy is validated; labels are display-only.
- The draft version and IDs are not production/backend-approved identifiers.
- Existing `POST /api/create-booking` does not receive these fields yet. Live booking form, create-booking payload, offer query and dispatch remain unchanged.
- Backend contract required: approve a canonical catalogue version; validate and snapshot selection at booking creation; return normalized identity; copy exact identity to offers; publish verified skills with same IDs/version; enforce skill/assignment/ownership checks server-side on every protected transition.


## 10. Booking service identity rollout reference

See `docs/SRK_CUSTOMER_BOOKING_SERVICE_ID_INTEGRATION_PLAN_HI.md` for the exact current Customer create-booking payload, proposed structured fields, backend response/offer propagation, legacy booking compatibility, rollout gates and acceptance checklist. Existing live payload and API calls remain unchanged until backend contract approval and staging evidence.


## Owner correction — commission base clarified (21-11-2026)
**Controlling rule:** 15% commission is charged only on service charge/labour; Technician receives 85% of service charge/labour. Materials/parts carry 0% company commission/platform fee and remain outside the commission base. Example: ₹600 labour + ₹400 materials → ₹90 company commission, ₹510 technician labour share, ₹400 materials separately. This supersedes earlier full-payment commission wording in this document. No live payment code is changed by this documentation correction.
