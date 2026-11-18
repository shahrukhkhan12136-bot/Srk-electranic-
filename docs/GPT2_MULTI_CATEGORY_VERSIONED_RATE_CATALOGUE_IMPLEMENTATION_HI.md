# Multi-category Electrician Approval + Versioned Rate Catalogue (Hindi)

**स्थिति: Feature Branch source implementation. Production migration/deployment नहीं हुआ है।** यह दस्तावेज़ design और वास्तविक source files के बीच स्पष्ट अंतर रखता है।

## 1. वास्तविक migration

\`supabase/migrations/20261118050000_versioned_rate_catalogue_and_multi_category_electricians.sql\`

इस migration में:
- \`srk_electrician_approved_rate_categories\`: एक profile के लिए अनेक Admin-approved rate tiers; प्रत्येक row में approver, approval time और active/revoked status।
- \`srk_electrician_rate_category_audit\`: append-only approval/revocation history।
- Legacy \`electrician_profiles.approved_rate_tier\` और उसके audit fields हटाए नहीं गए।
- Existing single-category approved profiles की category नए relation में backfill होती है; पुराना record जस का तस रहता है।
- Job-offer dispatch और insert guard नई multi-category relation से eligibility जाँचते हैं।
- Profile activation के लिए कम-से-कम एक active approved category जरूरी है; पुराना audited single-tier path compatibility के लिए बना रहता है।

## 2. Admin authorization

### Multiple category approval
RPC: \`public.srk_admin_set_electrician_approved_categories(uuid,text[],text)\`
- केवल authenticated \`public.is_srk_admin()\` Main Admin।
- Support Staff, Electrician, Customer और anonymous callers को अनुमति नहीं।
- Profile row \`FOR UPDATE\`; KYC \`verification_status='approved'\` होना जरूरी।
- Input केवल चार ज्ञात tier keys, duplicates निषिद्ध।
- भेजी गई पूरी सूची desired state है: हटाई गई पुरानी categories revoke होती हैं, नई/पहले revoked categories approve होती हैं।
- हर approve/revoke append-only audit में actor, reason और timestamp के साथ दर्ज होता है।
- Direct table privileges revoke हैं; केवल SECURITY DEFINER RPC writes करती है।

### Catalogue publish
RPC: \`public.srk_admin_publish_rate_catalogue(jsonb,timestamptz,uuid,text)\`
- केवल \`public.is_srk_admin()\`।
- Exactly four tier keys और positive integer paise amounts।
- Advisory transaction lock + \`p_expected_current_version_id\` optimistic concurrency।
- प्रत्येक publish नई immutable \`rate_version_id\` बनाता है; पुरानी version/item/audit update या delete नहीं होती।
- Future \`effective_at\` version schedule हो सकती है; current read केवल server \`now()\` से effective published version चुनता है।
- Publish RPC में reason और per-tier old/new audit शामिल है।

## 3. Dedicated authenticated Electrician Rate List

RPC: \`public.srk_get_my_electrician_rate_list()\`

- \`auth.uid()\` से \`electrician_profiles.auth_user_id\` और \`user_id\` दोनों का exact match।
- केवल approved linked profile।
- Categories केवल \`srk_electrician_approved_rate_categories\` की active Admin-approved rows से।
- Rates उसी current published catalogue version से।
- Return fields: \`rate_version_id\`, \`effective_at\`, currency और approved items में category, label, 8-hour duration, \`electrician_rate_paise\`।
- Customer gross, commission और company share return schema में नहीं हैं।
- Execute केवल \`authenticated\`; direct table access revoked।

UI: \`electrician.html\` में “मेरी Admin-approved Rate List” card इस RPC को authenticated Supabase session से call करता है।

## 4. Customer और Electrician एक ही version कैसे पढ़ते हैं

Customer RPC: \`public.srk_get_current_customer_rate_catalogue()\`
- Current effective published version का \`rate_version_id\` और चारों customer gross rates देता है।
- \`booking.html\` preview इसी RPC से catalogue पढ़ता है।
- \`create-booking.js\` server भी इसी RPC से rate/version पढ़कर estimate बनाता है; client-supplied amount/version authoritative नहीं।
- New booking में \`estimate_rate_card_version\` और \`estimated_labour_paise\` snapshot store होते हैं।
- Idempotent replay original booking का archived \`rate_version_id + tier\` lookup करता है; आज की दर से पुराना estimate recalculate नहीं करता।
- Electrician RPC उसी current catalogue \`rate_version_id\` से अपने approved tiers का 85% net निकालता है। इसलिए Customer gross और Electrician net एक ही version से आते हैं।

**महत्वपूर्ण शेष कार्य:** Admin web UI में version draft/preview/publish और multiple-category selector अभी इस migration/RPC से wired नहीं हैं। Publish/approval RPC backend source मौजूद है, लेकिन Admin UI integration और end-to-end verification बाकी है। Production में कोई initial catalogue seed/publish नहीं किया गया; पहली approved Admin publish के बाद ही read RPC data लौटाएगी।

## 5. 15% commission और 85% net reconciliation

एक ही labour gross पर 15% commission और 85% electrician net को दो बार deduct नहीं करना है।

Paise arithmetic:
- \`G\` = immutable customer labour gross paise।
- \`C = round_half_up(G × 15 / 100)\` = existing payout ledger commission।
- \`E = G - C\` = electrician net।
- हमेशा \`E + C = G\`।

यह rounding जानबूझकर existing \`commission_rate=15\` payout trigger के अनुरूप है। 85% को अलग से round करके फिर 15% commission घटाना नहीं है; कुछ odd paise amounts पर अलग-अलग rounding से ₹0.01 mismatch हो सकता है। उदाहरण ₹1,000: gross ₹1,000, commission ₹150, electrician ₹850। Materials और cancellation-fee amounts इस labour split का हिस्सा नहीं हैं। Cancellation fees SRK receivable हैं; electrician labour earning नहीं।

Legacy bookings में stored \`commission_rate\`, existing payout rows और immutable labour bills authoritative रहते हैं। Migration किसी historical booking, commission rate, payout row या bill को rewrite नहीं करती। यदि historical commission 15% नहीं है, उसे नए fixed split में silently convert नहीं किया जाएगा।

## 6. वास्तविक files और tests

- Migration: \`supabase/migrations/20261118050000_versioned_rate_catalogue_and_multi_category_electricians.sql\`
- Customer UI: \`booking.html\`
- Booking API: \`create-booking.js\`
- Electrician UI: \`electrician.html\`
- Net/commission rounding: \`lib/electrician-net-rate.js\`
- Rate policy helper: \`lib/commercial-rate-policy.js\`
- Snapshot helper: \`lib/booking-rate-snapshot.js\`
- Electrician list helper: \`lib/electrician-rate-view.js\`
- Tests: \`tests/versioned-rate-catalogue-multi-category.test.js\`
- Rounding tests: \`tests/electrician-net-rate.test.js\`
- Prior snapshot tests: \`tests/booking-rate-snapshot.test.js\`
- Prior rate view tests: \`tests/electrician-rate-view.test.js\`
- Existing source audit: \`docs/GPT2_BOOKING_RATE_SOURCE_AUDIT_HI.md\`

## 7. Verification limits

Source assertions and JavaScript syntax checks can be performed on this branch. They do **not** prove PostgreSQL migration validity, RLS behavior, Supabase RPC grants under deployed roles, Admin UI behavior, or live checkout/payout reconciliation. Node test suite and SQL migration execution must be run in an isolated disposable database/test environment before Production approval.

No Production DB change, migration execution, deployment, paid branch, or PR merge is authorized or performed by this work.
