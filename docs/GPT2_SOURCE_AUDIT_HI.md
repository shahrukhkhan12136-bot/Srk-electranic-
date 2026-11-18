# GPT-2 source audit — current integration gaps

**Scope:** source-only audit on `feat/ai-rate-management-foundation-20261118`; no database or production changes.

## Commercial rate and electrician 85% rate list
- The pure rate catalogue helper and 85% paise calculator exist.
- The new electrician view DTO helper limits the rate list to caller-supplied approved category keys and emits only the 85% amount, version, effective time and 8-hour duration.
- The new job-accounting DTO helper withholds all financial accounting until booking status is `completed`.
- This is not yet wired to a server API. The server must derive approved categories from the authenticated electrician profile; never accept category keys from the browser as proof of approval.
- Existing `srk_get_my_earnings()` returns gross amount and commission fields for assigned bookings without restricting those fields to completed bookings. The Electrician App's current page aggregates completed/paid rows, but the RPC response itself still carries the fields. A migration/RPC response change is required later, only after explicit DB permission.
- Existing 15% commission behavior must be traced and reconciled with the 85% split before any financial calculation is changed. Do not double-deduct or silently replace it.
- Customer rate version and electrician 85% view must share the same immutable version/snapshot.

## AI foundation
- Five module allowlists and a conservative human-approval classifier exist.
- New pure helper requires approval to match action ID, type, target, payload hash, requesting module, a non-empty approver identity and a future expiry.
- This helper is not a substitute for verified session authentication, server-side approval loading, transactionality, idempotency, authorization, or append-only audit persistence.
- No AI API route, model provider, runtime activation, database audit table, or secrets were added.

## Guardrails
- No SQL was run; no migration was created or applied; no Paid DB branch was created; no deployment or paid service was used.
- Next implementation boundary: server/API wiring and UI integration. Database changes remain blocked pending explicit user approval.


## 18 नवम्बर 2026 — Netlify/API integration trace
- `netlify.toml` में Netlify Functions का स्रोत `netlify/functions` है; मौजूदा redirects booking, electrician application और payment endpoints को root-level handlers से जोड़ते हैं। `netlify/functions/create-booking.js` केवल `../../create-booking.js` का adapter है।
- `create-booking.js` में ग्राहक की Supabase Bearer session को `/auth/v1/user` से सत्यापित किया जाता है और verified phone को booking phone से मिलाया जाता है। यह मौजूदा सुरक्षित server-side pattern है जिसे नए rate/AI endpoints में अपनाना चाहिए।
- उसी booking handler में चार customer labour rates अभी hard-coded हैं (₹899/₹1,199/₹1,599/₹1,999) और एक fixed rate-card version string है। इसलिए केवल नई pure rate-list library जोड़ने से Admin द्वारा बदली गई दरें live booking में लागू नहीं होंगी। आगे API wiring में server-side active published catalogue पढ़ना और उसी version/amount का immutable booking snapshot बनाना आवश्यक है। Browser से भेजी गई कीमत को authoritative नहीं मानना है।
- `netlify.toml` में अभी dedicated commercial-rate या AI-assistant API redirect नहीं मिला। कोई नया route इस audit में नहीं जोड़ा गया।
- AI API design के लिए existing pattern में verified user session, server-side allowlist, narrowly scoped database calls और sanitized response अपनाएँ। Service-role key केवल server environment में रहे; उसे model prompt, tool arguments, browser या logs में कभी न भेजें।
- यह source inspection है; कोई code route, database object, migration, deployment या runtime configuration नहीं बदली गई।


## 18 नवम्बर 2026 — अतिरिक्त सत्यापन
- 5 टेस्ट फाइलों में कुल 19 टेस्ट चलाए गए: **19 पास, 0 फेल**।
- 85% राशि की गणना को JavaScript floating-point multiplication से हटाकर BigInt आधारित integer arithmetic किया, ताकि बड़े वैध paise input पर rounding सटीक रहे।
- Unsafe integer सीमा वाले टेस्ट को सही किया: `Number.MAX_SAFE_INTEGER` वैध इनपुट है; उससे बड़ा मान अस्वीकार होना चाहिए।
- यह परीक्षण स्थानीय source snapshot पर चला; production API, Supabase या deployed app पर नहीं।
