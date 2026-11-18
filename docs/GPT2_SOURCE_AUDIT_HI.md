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


## 18 नवम्बर 2026 — Booking rate snapshot contract
- `lib/booking-rate-snapshot.js` जोड़ा: यह केवल प्रकाशित और प्रभावी rate version चुनता है; Draft तथा भविष्य की effective date वाली दरें वर्तमान बुकिंग के लिए नहीं चुनता। Snapshot बनाते समय rate tier को भी दोबारा validate किया जाता है।
- नया booking snapshot rate version ID, effective timestamp, tier, 8-hour base rate, duration और labour amount को paise में रखता है। Snapshot object immutable/frozen है; पुराने booking की राशि बाद की catalogue update से पुनर्गणित नहीं होनी चाहिए।
- `tests/booking-rate-snapshot.test.js` के 6 tests स्थानीय Node.js test runner से चलाए: **6 पास, 0 फेल**। इसमें latest effective version, future/draft exclusion, immutable snapshot, no-version, duplicate effective time और invalid tier जाँचे गए।
- यह अभी pure source contract है। वास्तविक booking API अभी hard-coded rate card इस्तेमाल करता है; इस helper को production booking flow में जोड़ना, trusted server-side published catalogue storage पढ़ना और DB snapshot persistence करना बाकी है। कोई migration/DB बदलाव अनुमति के बिना नहीं किया गया।


### AI audit-event metadata foundation (source-only)
- `lib/ai-audit-event.js` और `tests/ai-audit-event.test.js` जोड़े गए।
- DTO केवल allowlisted AI module, action key, actor/record/approval/request IDs, timestamp और सीमित outcome रखता है; prompt, raw tool payload और free-form error text को output में शामिल नहीं करता।
- यह केवल pure metadata builder है। इसे production में enforce करने, append-only persistence, server-authenticated actor identity, secret redaction, retention policy और tamper resistance के लिए backend तथा database कार्य अभी बाकी हैं।
- इस test file को इस चरण में remote source में जोड़ा गया है; यहां test runner execution सत्यापित नहीं हुआ है। इसे पास हुआ घोषित न करें।


## 18 नवम्बर 2026 — Manual payment method / payout trigger parity follow-up
- `20261118100000_align_manual_payment_method_payout_trigger.sql` में मौजूदा `srk_create_electrician_payable()` को `CREATE OR REPLACE` से बदला गया है। मूल payout calculation और refund branch सुरक्षित रखे गए; manual payment evidence में booking ID, amount और normalized payment method तीनों का match अनिवार्य किया गया।
- Payout AFTER trigger की `UPDATE OF` सूची में `payment_method` जोड़ा गया, ताकि केवल payment method बदलने पर भी evidence gate दोबारा चले।
- `20261117010000_reconcile_booking_commission_and_manual_payment_method.sql` में Commission BEFORE Trigger और Commission/Payout Parity AFTER Trigger दोनों `payment_method` पर सुनते हैं; इनके fail-closed mismatch check की source assertions जोड़ी गईं।
- `tests/offer-rate-payout-reconciliation.test.js` में अतिरिक्त assertions हैं: manual payment method match, तीनों triggers की `payment_method` event coverage, payout function का मूल logic सुरक्षित रहना (केवल evidence predicate जोड़कर), और पुराने booking/bill/manual-payment records पर migration-time UPDATE न होना।
- GitHub source comparison में payout function body का normalized comparison पास हुआ: original function में केवल expected manual method evidence guard जोड़ा गया है। Original trigger event list के मुकाबले नया trigger केवल `payment_method` जोड़ता है।
- नवीनतम source commit: `ea5d450c9e8e56ecc1971a3142e0bad6cfaf8153`।
- Verification सीमा: इस turn में Node test runner, PostgreSQL parser/runtime, isolated DB, authenticated RPC या live payment E2E नहीं चलाया गया। GitHub Actions run list खाली रही; Vercel status build-rate-limit failure दिखाता है। इसलिए कोई runtime/CI pass claim नहीं है।
- Migration source-only है; इसे किसी database पर लागू नहीं किया गया। पुराने booking, bill, manual payment entry या payout rows migration द्वारा rewrite नहीं किए गए।


## 18 नवम्बर 2026 — Manual payment RPC atomicity और AI route gap audit
- `20261115210000_legacy_manual_payment_and_itemized_receipt.sql` में `srk_admin_record_manual_payment(uuid,text,text,text)` मौजूद है। यह Main Admin check करता है, booking row को `FOR UPDATE` lock करता है, केवल completed + assigned + approved legacy quote स्वीकारता है, unpaid/pending state और Razorpay IDs की अनुपस्थिति जाँचता है।
- RPC पहले manual evidence row (booking + method + amount + reference) insert करता है, फिर उसी transaction में booking पर amount/payment_status/payment_method/payment_verified_at लिखता है; उसके बाद labour, materials, commission और electrician payable वाला payout row बनाता/जाँचता है। किसी चरण में exception होने पर PostgreSQL transaction पूरे call को rollback करेगी।
- 17 नवम्बर commission BEFORE trigger manual evidence के payment method को booking method से मिलाता है; payout AFTER trigger (18 नवम्बर replacement) भी वही match जाँचता है। दोनों और parity trigger payment_method update पर सक्रिय होते हैं। इस क्रम में RPC evidence insert पहले करता है, इसलिए method gate के लिए evidence उपलब्ध रहता है।
- महत्वपूर्ण सीमा: यह RPC `selected_category IS NOT NULL` वाली नई Catalogue bookings को स्पष्ट रूप से रोकता है और dedicated settlement path माँगता है। इसलिए नए rate-catalogue bookings के लिए Admin manual settlement अभी इस RPC से उपलब्ध/सत्यापित नहीं है। इसे चुपचाप legacy RPC में मिलाना सुरक्षित नहीं होगा; अलग server-authoritative settlement contract चाहिए।
- नया source-only test `tests/manual-payment-trigger-atomicity.test.js` जोड़ा गया है: Main Admin + row lock, evidence-before-booking-update ordering, payout split consistency, तीन triggers की payment_method event coverage और नई Catalogue booking exclusion की assertions। इस turn में Node runner/SQL test नहीं चलाया गया; assertions अभी source में हैं, pass घोषित नहीं हैं।
- AI audit: tree में पाँच module policy/approval/audit pure helpers और design docs हैं, लेकिन कोई `netlify/functions/*ai*` या `api/*ai*` route नहीं मिला। अतः authenticated server API, server-side actor context, persisted approval/audit, idempotent execution और module kill-switch runtime wiring अभी शेष हैं। Browser या model से privileged actions का execution enable नहीं है।
- यह केवल GitHub source inspection/नया static test है। कोई database migration apply, SQL execution, production record update या deployment नहीं हुआ।
