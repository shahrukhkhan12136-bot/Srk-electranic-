# GPT-1 Integration Contract — AI Assistant, Human Handoff और Earnings

**Audit date:** 18 नवम्बर 2026  
**Branch:** `feat/ai-rate-management-foundation-20261118`  
**स्थिति:** नीचे AI API और handoff के formats प्रस्तावित contracts हैं, deployed endpoints नहीं। Rate rounding और earnings response के source changes इसी branch में हैं; migrations अभी apply नहीं हुईं।

## 1. वास्तविक AI endpoint की स्थिति

अभी कोई वास्तविक AI runtime endpoint मौजूद नहीं है। `netlify/functions/*ai*` route, `/api/v1/ai/*` handler, AI provider adapter, persisted conversation/action/approval/handoff store और runtime kill-switch integration नहीं मिले। इसलिए Customer/Electrician App को अभी किसी AI URL पर production request नहीं भेजनी चाहिए।

मौजूदा policy helpers में ये module keys हैं:
- Customer: `customer_support`, `booking_assistant`
- Electrician: `electrician_assistant`
- अन्य: `staff_assistant`, `reports_operations`

ये allowlist/design helpers हैं; ये अपने-आप कोई endpoint या live AI capability उपलब्ध नहीं कराते।

## 2. प्रस्तावित Assistant API (अभी लागू नहीं)

**Route:** `POST /api/v1/ai/assistant`

**Headers:**
- `Authorization: Bearer <Supabase access token>`
- `Content-Type: application/json`
- `Idempotency-Key: <UUID>` (request retry पहचानने के लिए)

**Request:**
```json
{
  "module_key": "customer_support",
  "message": "मेरी बुकिंग की स्थिति बताइए",
  "conversation_id": null,
  "context": {
    "booking_id": "booking-uuid"
  }
}
```

Electrician के लिए `module_key` = `electrician_assistant`; context में केवल booking reference दें। Server को token सत्यापित करके actor/user/role स्वयं निकालना है, फिर booking ownership/assignment जाँचनी है। Browser से भेजा गया `actor_id`, `role`, `is_admin`, approval या permission कभी authoritative नहीं होगा। Service-role key और AI provider key केवल server-side secrets रहेंगे।

**प्रस्तावित success response:**
```json
{
  "success": true,
  "request_id": "request-uuid",
  "conversation_id": "conversation-uuid",
  "module_key": "customer_support",
  "reply": "आपकी बुकिंग अभी ... स्थिति में है।",
  "action": {
    "status": "none",
    "action_id": null,
    "approval_required": false
  },
  "handoff": {
    "required": false,
    "handoff_id": null,
    "queue": null,
    "status": "not_required"
  }
}
```

संभावित error response में `success=false`, `error.code`, `error.message`, `request_id` होंगे। Authentication failure पर 401, role/module mismatch पर 403, invalid body पर 400, rate limit पर 429 और provider/service unavailable पर 503 लौटाएँ। AI unavailable होने पर existing booking/payment workflows बाधित नहीं होने चाहिए।

## 3. Human Handoff API (अभी लागू नहीं)

**Route:** `POST /api/v1/ai/handoff`

**Headers:** Assistant API जैसे verified Supabase Bearer token और `Idempotency-Key`।

**प्रस्तावित request:**
```json
{
  "module_key": "electrician_assistant",
  "conversation_id": "conversation-uuid",
  "booking_id": "booking-uuid",
  "reason_code": "needs_human_support",
  "urgency": "normal",
  "summary": "उपयोगकर्ता को इस बुकिंग पर कर्मचारी की सहायता चाहिए।"
}
```

**प्रस्तावित success response fields:**
- `success`: request स्वीकार हुई या नहीं
- `handoff_id`: नया handoff/case UUID
- `case_reference`: UI में दिखाने योग्य reference
- `queue`: निर्धारित support queue
- `status`: `queued`, `assigned`, `in_progress`, `resolved` में से persisted status
- `urgency`: स्वीकार की गई urgency
- `created_at`: server timestamp
- `conversation_id` और `booking_id`: संबंधित references

Server actor identity स्वयं निकाले; summary को sanitize करे; दूसरे Customer/Electrician की booking पर handoff रोक दे; staff visibility existing staff permissions से तय हो। जब तक persisted handoff store और route न बनें, ये response fields केवल प्रस्ताव हैं—वास्तविक handoff उपलब्ध नहीं है।

## 4. Rate List और Offer rounding — source fix

पुराना अंतर:
- Direct 85% half-up: `round_half_up(gross × 0.85)`
- मौजूदा payout ledger: `gross − round_half_up(gross × 0.15)`

कुछ paise tie cases में दोनों में 1 paise का अंतर आता है। उदाहरण: gross 10 paise पर direct 85% = 9 paise, लेकिन 15% commission 2 paise round होने से ledger net = 8 paise।

**Canonical rule अब existing payout ledger के अनुरूप रखा गया है:**

```text
commission_paise = floor((gross_paise * 1500 / 10000) + 0.5)
electrician_net_paise = gross_paise - commission_paise
```

नया source-only migration `20261118110000_unify_electrician_rate_rounding.sql`:
- `srk_get_my_electrician_rate_list()` को gross minus rounded 15% commission पर लाता है।
- `srk_get_my_offer_details()` के `electrician_offer_paise` को उसी formula पर लाता है।
- JavaScript Rate List helper भी उसी payout calculation को reuse करता है।
- पुरानी booking, bill या payout rows नहीं बदलता।

Tie-case results अब 10→8, 30→25, 50→42, 70→59 paise हैं। इससे Rate List, Offer और payout ledger एक ही paise amount पर सहमत होंगे। यह commission rate नहीं बदलता और 15% को दोबारा नहीं काटता।

## 5. Earnings RPC — missing payout और reconciliation

वर्तमान source definition `srk_get_my_earnings()` में response columns:
- `amount_received`
- `commission_amount`
- `electrician_earning`
- `customer_labour_gross`
- `company_share`
- `payout_amount`
- `payout_status`
- `payout_reconciliation_status`
- `payment_stage`

Verified payment पर electrician earning केवल तब लौटती है जब `payout_reconciliation_status='reconciled'` हो। Verified payment लेकिन missing payout row पर:
- `payout_reconciliation_status = "missing"`
- `electrician_earning = null` (₹0 नहीं)
- `payout_amount = null`
- `payout_status = null`

Mismatch/incomplete ledger पर भी earning/payout amount withheld रहता है और reconciliation status कारण बताता है। Customer payment receipt को अलग verified field के रूप में दिखाया जा सकता है; इससे payout complete होने का अर्थ नहीं निकलता।

नया static regression test `tests/earnings-payout-reconciliation-contract.test.js` इसी व्यवहार और unified rounding को assert करता है।

## 6. GPT-1 के लिए integration निर्देश

1. AI और handoff endpoints को अभी live न मानें; App में production calls enable न करें।
2. Customer module keys: `customer_support`, `booking_assistant`; Electrician key: `electrician_assistant`।
3. ऊपर के request/response formats को UI contract के रूप में रखें, लेकिन network integration तभी करें जब server routes, persistence, authentication, ownership checks, audit और tests लागू हों।
4. Rate List/Offer amount को RPC response से पढ़ें; browser में 85% दोबारा calculate न करें।
5. Earnings UI में `null` को ₹0 में convert न करें। `payout_reconciliation_status` अलग दिखाएँ और `missing`/mismatch पर payout को unresolved रखें।
6. कोई Production DB migration, deploy या paid AI provider setup बिना अलग explicit approval के नहीं होगा।


## 7. GPT-1 pre-launch client adapter — source added

`lib/ai-assistant-client.js` now provides the Customer/Electrician-side transport adapter for the proposed contract:
- `sendMessage()` targets the proposed assistant route and accepts only the three Customer/Electrician module keys.
- `createHandoff()` targets the proposed human-handoff route and validates the persisted handoff status before returning success.
- Both methods require a verified session access token and UUID idempotency key; browser-supplied actor/role/permission fields are not accepted.
- Context is restricted to an optional booking UUID. Provider/server error details are not forwarded to the UI.
- Adapter is disabled by default. It must remain disabled until GPT-2 confirms deployed routes, persistence, authentication, ownership checks, audit, rate limits and kill switch.

`tests/ai-assistant-client.test.js` adds source-level tests for disabled-by-default behavior, request shape, auth/idempotency headers, context allowlisting, safe failure handling and handoff status validation.

These are client-adapter and mocked-contract tests only. They do not prove a live AI backend, actual Customer/Electrician UI, provider connection, or end-to-end handoff. No endpoint call is enabled in either app.

## 8. साझा Customer/Electrician AI UI component — source added

- `lib/ai-assistant-widget.js` में accessible chat surface, safe text-only rendering, Enter/Shift+Enter handling, sending/error states, optional human-handoff summary और backend-confirmed handoff reference rendering तैयार है।
- यह Customer `customer_support` / `booking_assistant` और Electrician `electrician_assistant` module keys तक सीमित है।
- Component default रूप से disabled है; `enabled: true`, explicit container, client और verified-session provider के बिना यह mount नहीं होता।
- Component अभी `booking.html` या `electrician.html` में mount नहीं किया गया है और कोई live endpoint call enabled नहीं है। ऐसा तभी होगा जब GPT-2 backend contract और launch gates सत्यापित हों तथा post-launch activation अधिकृत हो।
- `tests/ai-assistant-widget.test.js` disabled-default, module allowlist, configuration guard, safe rendering और handoff confirmation के source-contract checks जोड़ता है। Test suite अभी execute नहीं हुई है।
### Browser compatibility और retry safety update

- Client adapter और shared widget अब CommonJS tests के साथ browser global exports भी देते हैं: `SrkAiAssistantClient` और `SrkAiAssistantWidget`।
- Message और handoff के idempotency keys केवल उसी अपरिवर्तित payload के retry पर reuse होते हैं; उपयोगकर्ता संदेश/summary बदलता है तो नया key बनता है।
- यह source-level सुधार है; HTML pages में scripts जोड़ना/mount करना, runtime tests और live backend verification अभी शेष हैं।


### App-side AI composition preparation (18 Nov 2026)

- `lib/ai-assistant-app.js` जोड़कर Customer/Electrician app role के अनुसार module allowlist और Supabase session provider से widget composition तैयार किया गया है।
- Customer role केवल `customer_support` और `booking_assistant` modules mount कर सकता है; Electrician role केवल `electrician_assistant` module mount कर सकता है।
- यह helper केवल `AI_ASSISTANT_ENABLED === true` और HTTPS `AI_ASSISTANT_API_BASE_URL` मिलने पर mount करता है; अन्यथा कोई UI/network request नहीं होती।
- नया `tests/ai-assistant-app.test.js` disabled default, role separation, fail-closed dependencies और Supabase session-provider handoff के source-contract checks रखता है।
- अभी helper को `booking.html` या `electrician.html` में import/mount नहीं किया गया है। वास्तविक GPT-2 API routes इस branch tree में अभी नहीं मिले; proposed endpoints को live contract नहीं माना जाएगा।
- इन tests को इस commit के लिए चलाया हुआ प्रमाण उपलब्ध नहीं है। HTML runtime/mobile QA भी नहीं हुआ है। Live activation post-launch और backend verification के बाद ही होगा।


### Booking snapshot replay ordering fix (18 Nov 2026)

- `create-booking.js` में idempotency-key से पहले से सेव booking मिलने पर अब current published Rate Catalogue दोबारा लोड करने की आवश्यकता नहीं है।
- Existing booking replay पहले उसी booking का persisted `estimated_labour_paise`, `estimate_rate_card_version` और उसी version/tier का historical 8-hour rate लौटाता है।
- Current catalogue केवल नई booking insert करने से पहले पढ़ा जाता है; नई booking के लिए client rate/version पर भरोसा नहीं किया जाता।
- Race/unique-key replay path पहले की तरह persisted booking snapshot लौटाता है।
- नया source-contract test `tests/booking-rate-replay-order.test.js` replay-vs-current-catalogue ordering, persisted amount/version और new-booking server catalogue guard को जाँचता है।
- अभी यह नया test execute नहीं हुआ है; live database trigger/runtime verification और end-to-end QA बाकी हैं।


### App composition launch-guard regression coverage

- `tests/ai-assistant-app.test.js` now additionally checks that an enabled app refuses a non-HTTPS AI API base URL before creating the transport client.
- The session-provider contract is also checked: a Supabase `getSession()` error is propagated and is not converted into a fabricated or anonymous session.
- These checks remain mocked source-contract tests. They do not activate the widget, prove a deployed backend, or authorize pre-launch mounting in either HTML app.


### Booking snapshot replay regression coverage update

- `tests/booking-rate-replay-order.test.js` now explicitly checks the unique-key race replay path returns the persisted `estimated_labour_paise` and `estimate_rate_card_version`, and does not recalculate from the current catalogue.
- A separate source-contract check verifies new bookings persist the server-derived estimate, catalogue version, selected tier and duration.
- These are static source assertions only; the Node test suite and database runtime tests have not been executed.


### AI action approval payload-shape hardening

- `lib/ai-action-approval.js` now rejects array-shaped `action` and `approval` payloads before checking approval bindings.
- `tests/ai-action-approval.test.js` adds coverage for array-shaped action and approval values.
- This is a defensive pure-helper check only. Human identity verification, server-side approval loading, resource authorization and audit persistence remain backend responsibilities; tests have not been executed.


## 9. AI base URL validation hardening — source and regression tests

- App composition और transport client दोनों अब API base URL को strict HTTPS URL के रूप में parse करते हैं।
- Empty hostname, embedded username/password, query string, fragment और surrounding whitespace वाले URL reject होते हैं।
- Invalid URL पर transport से पहले fail-closed error आता है; fetch call नहीं होती।
- tests/ai-assistant-app.test.js और tests/ai-assistant-client.test.js में malformed URL regression cases जोड़े गए हैं।
- ये source-level/mock tests हैं; इस branch पर execution/CI evidence उपलब्ध होने तक इन्हें passed नहीं माना जाएगा।
- यह केवल pre-launch hardening है; AI routes, production mounting या live activation नहीं।


## 10. AI transport response envelope hardening

- HTTP non-success response पर client अब JSON body parse नहीं करता; केवल HTTP status से safe error code बनता है।
- Missing/malformed response object, missing `ok`/`json`, JSON parse failure, और top-level array/string/null payload fail-closed होते हैं।
- Regression tests malformed envelopes तथा 403 body non-parsing behavior cover करते हैं।
- ये mocked source tests हैं; execution/CI प्रमाण उपलब्ध नहीं है। Live AI endpoint या activation का दावा नहीं है।


## 11. AI API base URL path restriction

- App composition और transport client दोनों अब केवल HTTPS origin-root base URL स्वीकार करते हैं (उदाहरण: `https://api.example.test`)।
- Path prefix (`https://api.example.test/prefix`) अस्वीकार होता है, क्योंकि API routes absolute-root paths पर तय हैं और prefix चुपचाप हट सकता था।
- Customer/Electrician composition और transport client के URL regression tests में path-prefix rejection जोड़ा गया है।
- Tests अभी execute नहीं हुए हैं; यह pre-launch preparation है, live endpoint confirmation नहीं।


## 12. AI client input/context prototype validation

- Client entry points अब null, array या non-object request को stable `invalid_request` error से reject करते हैं।
- Context केवल plain object या null-prototype object हो सकता है; inherited `booking_id` या custom prototype values स्वीकार नहीं होते।
- `booking_id` केवल own-property से पढ़ा जाता है और UUID validation के बाद ही request में जाता है।
- Regression tests जोड़े गए हैं; execution/CI evidence अभी उपलब्ध नहीं है।

### AI activation flag prototype hardening

- App composition helper अब केवल plain config object के अपने (own) `AI_ASSISTANT_ENABLED === true` flag पर विचार करता है।
- `null`, array, custom-prototype या inherited activation flag मिलने पर composition inert रहती है।
- इससे किसी inherited/config-prototype property के कारण post-launch AI mounting अनजाने में चालू नहीं हो सकती।
- Regression tests जोड़े गए हैं; execution/CI evidence अभी उपलब्ध नहीं है।

### AI API URL config own-property guard

- Post-launch composition helper अब AI_ASSISTANT_API_BASE_URL को भी config का अपना (own) property होना अनिवार्य करता है; inherited URL से AI client नहीं बनेगा।
- Regression test Object.prototype से inherited URL देकर verify करता है कि composition fail-closed रहती है।
- यह केवल configuration hardening है; AI endpoint लागू/सत्यापित नहीं हुआ, app mounting या activation नहीं की गई। Test execution का प्रमाण अभी उपलब्ध नहीं है।

### AI client request prototype hardening

- `sendMessage()` अब केवल plain object या null-prototype request स्वीकार करता है।
- `moduleKey`, `message`, `accessToken` और `idempotencyKey` चारों own properties होना अनिवार्य हैं; inherited credentials या idempotency values से request नहीं बनेगी।
- Regression tests inherited request fields और custom prototype को fetch से पहले reject करते हैं।
- यह source-level बदलाव है; test execution/CI evidence अभी उपलब्ध नहीं है।

### AI optional request fields prototype hardening

- `sendMessage()` में optional `context` और `conversationId` केवल own properties से पढ़े जाते हैं; inherited values को अनदेखा किया जाता है।
- `createHandoff()` अब मूल request के plain-object/null-prototype होने की पुष्टि करता है और optional `context`, `conversationId`, `reasonCode`, `urgency`, `summary` own properties से ही पढ़ता है।
- Regression test `Object.prototype` में inherited context/conversation values डालकर verify करता है कि वे request body में नहीं जातीं।
- Tests अभी execute नहीं हुए हैं; यह pre-launch source hardening है, live API integration नहीं।
- अतिरिक्त regression test: handoff custom-prototype request को network call से पहले रोकता है; inherited `context`, `reasonCode`, `urgency` को request body में शामिल नहीं करता।

### AI widget teardown safety

- Customer/Electrician widget में session token resolve होने के बाद, AI message या human-handoff request भेजने से पहले `destroyed` state दोबारा जाँची जाती है।
- यदि app component हट चुका हो और session lookup बाद में resolve हो, तो कोई नया AI network request शुरू नहीं होगा।
- दोनों request paths के लिए regression assertion जोड़ा गया। Tests अभी execute नहीं हुए हैं।

### AI app-role allowlist hardening

- App composition अब `APP_MODULES_BY_ROLE` में role lookup के लिए own-property check करता है। `__proto__`, `constructor`, `toString`, `hasOwnProperty` जैसे inherited object names किसी app role की तरह स्वीकार नहीं होंगे।
- Regression test इन चार prototype property names को invalid role के रूप में जाँचता है। Tests अभी execute नहीं हुए हैं।

### AI widget idempotency-key failure recovery

- Message और human-handoff दोनों flows में injected `createId()` अब `try` के अंदर चलता है। अगर key factory exception दे, widget generic safe error path लेता है और `finally` में busy state/control recovery होती है; uncaught exception से UI permanently disabled नहीं रहनी चाहिए।
- Regression source assertions जोड़े गए हैं। Runtime tests अभी execute नहीं हुए हैं।

### AI widget idempotency key validation और retry recovery

- पिछली hardening में key factory error catch हो रहा था, लेकिन key बनाते समय pending message/summary पहले सेट होने से retry में नया key न बनने का edge case था। अब UUID key पहले बनती और validate होती है; उसके बाद ही pending text/summary commit होता है। Missing key पर retry factory दोबारा चलती है।
- Message और handoff दोनों में UUID format client contract के अनुरूप validate होता है। Regression assertions अपडेट किए गए हैं। Runtime tests अभी execute नहीं हुए हैं।


### AI profile-backed role detection — customer onboarding dependency (18 Nov 2026)

- Current source guard derives Customer access from exactly one row in `srk_customer_profiles` and Electrician access from exactly one approved/active `electrician_profiles` row whose `user_id` and `auth_user_id` both match the authenticated Supabase user.
- The Customer profile table is created by `20261114201428_customer_profile_saved_addresses_private_storage.sql`, but its profile row is inserted by the explicit `srk_customer_update_my_profile()` RPC in `20261114180000_harden_customer_avatar_object_integrity.sql`. The inspected Customer UI calls that RPC from the profile-save flow; no universal Auth-signup trigger or mandatory profile-row creation was found in the inspected source.
- Therefore a legitimate Customer who has not saved their profile may be denied AI access (403). This is fail-closed, but it is not yet a complete Customer role registry. Do not loosen this by trusting browser role or unverified user metadata. Before enabling Customer AI, implement/verify a server-trusted Customer account marker or guaranteed profile provisioning at account creation, and test existing users without profile rows.
- Electrician lookup additionally requires `active=true`, `verification_status=approved`, and both identity columns matching Auth. Staff/Admin remain denied until a dedicated DB-backed permission check is integrated.
- AI remains disabled (`ai_not_enabled`); no live route, persistence or provider is claimed.
