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
