# AI Conversation और Human Handoff — अलग Database Design

**Audit date:** 18 नवम्बर 2026  
**Branch:** `feat/ai-rate-management-foundation-20261118`  
**स्थिति (18 नवम्बर 2026):** यह दस्तावेज़ मूल design और पुराने pre-migration contract का रिकॉर्ड है। AI के लिए additive source migrations और server-side guard अब branch में मौजूद हैं। नीचे के पुराने प्रस्तावित schema names/fields को वास्तविक वर्तमान schema न मानें; जहां अंतर हो, नीचे दिया implementation status और SQL migrations authoritative हैं।

## 0. वर्तमान repository implementation status

AI storage की source migrations:

- `20261118180000_private_ai_conversation_persistence.sql`: अलग AI conversation, message, idempotency, handoff queue और metadata-only audit tables; RLS; browser roles से direct table access revoke; append-only audit trigger।
- `20261118190000_ai_idempotency_reservation_rpc.sql`: actor-scoped atomic reservation RPC; service-role-only।
- `20261118200000_ai_idempotency_finalize_rpc.sql`: processing reservation को completed/failed करने का service-role-only RPC; response body store नहीं करता।
- `20261118210000_ai_message_append_rpc.sql`: owner और open conversation lock/verify करके user/assistant message append करता है; केवल service-role।
- `20261118220000_ai_handoff_request_rpc.sql`: owner conversation lock करके handoff queue row और `handoff_requested` status एक transaction में लिखता है; duplicate queued/assigned handoff पर मौजूदा queue item लौटाता है। यह agent assign या notification नहीं भेजता।

वास्तविक schema में महत्वपूर्ण अंतर:

- Conversation status `open`, `handoff_requested`, `closed` है; पुराना `handoff_pending` नाम लागू नहीं।
- Message sender field `sender_kind` है और values `user`, `assistant`, `human_agent` हैं; पुराना `sender_type/system` contract लागू नहीं। नया append RPC अभी केवल `user` और `assistant` sender स्वीकार करता है; human-agent workflow अलग से बनना है।
- Handoff table का नाम `srk_ai_handoff_queue` है; handoff status `queued`, `assigned`, `resolved`, `cancelled` हैं।
- Idempotency actor-scoped unique key `(actor_user_id,idempotency_key)` और SHA-256 digest `request_sha256` पर आधारित है। Response body store नहीं होती; reservation states में `reserved`, `conflict`, `replay`, `processing`, `failed` हैं।
- Audit table `srk_ai_audit_events` में केवल metadata fields हैं; prompt/message body या provider payload columns नहीं हैं।
- मौजूदा `lib/ai-server-guard.js` auth, profile, module, conversation ownership और booking access validate करता है; इसके बाद जानबूझकर `503 ai_not_enabled` देता है। नए message और handoff RPC अभी storage foundation हैं; AI routes अभी इनसे wired नहीं हैं, provider call नहीं होता, और human agent assignment/notification workflow अभी नहीं बना है।

**जाँच की सीमा:** migrations और tests केवल Git branch में source हैं। इस update में कोई PostgreSQL replay, hosted/live database migration, deployment या AI provider call नहीं हुआ। AI default-off रहेगा; explicit launch approval के बिना इसे enable नहीं करना है।



## 1. मौजूदा सिस्टम से अलगाव

AI conversation को इन मौजूदा tables में नहीं लिखना है:

- `srk_booking_complaint_messages`: Customer–Admin शिकायत के `complaint_id` से बँधी है।
- `srk_electrician_support_messages`: Electrician support ticket के `ticket_id` से बँधी है।
- `srk_admin_staff_audit_events`: Staff RBAC audit के लिए है, AI prompt/message store नहीं।

AI conversation, AI message, idempotency, handoff और AI audit के लिए अलग tables होंगी। Existing complaint/ticket records को AI chat के रूप में reuse या mutate नहीं करना है।

## 2. प्रस्तावित अलग tables

### `public.srk_ai_conversations`

मुख्य fields:
- `id uuid primary key`
- `owner_user_id uuid not null references auth.users(id)`
- `actor_type text not null`: केवल `customer` या `electrician`
- `module_key text not null`: Customer के लिए `customer_support` / `booking_assistant`; Electrician के लिए `electrician_assistant`
- `status text not null`: `open`, `handoff_pending`, `closed`
- `created_at`, `updated_at`, `closed_at`

हर read/write पर owner और module authorization server से दोबारा जाँचना है। Conversation UUID जानना ownership का प्रमाण नहीं है।

### `public.srk_ai_messages`

मुख्य fields:
- `id uuid primary key`, `conversation_id uuid not null`
- `sequence_no bigint not null`
- `sender_type text not null`: `user`, `assistant`, `system`
- `body text not null` (सीमित आकार)
- `provider_request_id text null`
- `created_at timestamptz not null`

Unique key `(conversation_id, sequence_no)`; message insert केवल उसी server-side transaction से हो जो conversation owner lock/validate करे। Provider secrets, access tokens, full payment credentials या अनावश्यक personal data message body/context में persist नहीं करना है।

### `public.srk_ai_idempotency`

मुख्य fields:
- `owner_user_id`, `endpoint_key`, `idempotency_key`
- `request_hash`, `state` (`processing`, `completed`, `failed_retryable`)
- `response_status`, `response_body`, `created_at`, `expires_at`

Unique key `(owner_user_id, endpoint_key, idempotency_key)`। वही key और वही canonical request hash हो तो stored result replay हो। वही key अलग payload के साथ आए तो conflict लौटे; पुराने response को overwrite न करे। Concurrent requests row lock/unique constraint से serialize हों।

### `public.srk_ai_handoffs`

मुख्य fields:
- `id uuid primary key`, `conversation_id`, `owner_user_id`
- `booking_id uuid null` (केवल server-verified booking link)
- `queue_key text`, `reason_code text`, `urgency text`
- `summary text`, `status text` (`queued`, `assigned`, `in_progress`, `resolved`, `cancelled`)
- `assigned_staff_user_id uuid null`, timestamps

एक conversation के लिए concurrent duplicate open handoff रोकने हेतु partial unique constraint/transactional guard चाहिए। Staff assignment तभी होगा जब अलग AI-handoff permission और session-bound staff authorization उपलब्ध हो। तब तक Main Admin-only queue access रखें; मौजूदा complaint/ticket assignment को स्वतः AI handoff permission न मानें।

### `public.srk_ai_audit_events`

Append-only audit:
- actor, conversation/handoff/request IDs
- action, outcome, module key
- सीमित metadata और timestamp

Prompt/message की पूरी सामग्री, bearer token, provider key या अनावश्यक व्यक्तिगत जानकारी audit metadata में न डालें। Update/Delete को सामान्य roles से रोकें।

## 3. Database access contract

- सभी AI tables पर RLS enable; `anon` और `authenticated` को direct table access नहीं।
- Netlify server function ही server-side service-role credential रखे; browser में service-role key कभी नहीं।
- RPC/REST server operations में actor ID request body से नहीं, verified Supabase Auth token से निकले।
- Service-role-only database functions में `auth.jwt()->>'role' = 'service_role'` की पुष्टि और fixed `search_path` हो।
- हर conversation read/write पर owner, actor_type, module_key और active/approved profile status re-check हो।
- Booking context देने पर Customer के लिए booking ownership और Electrician के लिए assigned profile match अनिवार्य हो।
- Conversation IDs, booking IDs, handoff IDs को authorization bypass नहीं माना जाए।
- सभी list/read calls paginated और bounded हों; messages के लिए deterministic sequence ordering हो।

## 4. Customer onboarding का अभी का blocker

Source audit में मिला:
- `srk_customer_profiles` table `20261114201428_customer_profile_saved_addresses_private_storage.sql` में बनती है।
- Profile row explicit `srk_customer_update_my_profile()` flow से insert होती है।
- निरीक्षित migration set में हर Auth signup पर Customer profile row बनाने वाला universal trigger नहीं मिला।
- इसलिए बिना profile row वाला वास्तविक Customer मौजूदा AI guard से 403 पा सकता है।

इसे ठीक करने के लिए browser role या editable `user_metadata` पर भरोसा नहीं करना है। पहले verified signup/profile lifecycle में trusted Customer marker/provisioning तय करना और पुराने accounts के लिए backfill/rollout plan बनाना होगा। जब तक यह नहीं होता, Customer AI access fail-closed रहे।

Electrician access की शर्तें: `user_id` और `auth_user_id` दोनों Auth user से match, `verification_status='approved'`, `active=true`।


### 4.1 OTP login और profile creation का verified source flow

अतिरिक्त source audit में Customer app का वास्तविक flow भी जाँचा गया:

- `booking.html` में Customer `signInWithOtp({phone})` और `verifyOtp({phone, token, type:'sms'})` से Auth session बनाता है।
- OTP success के तुरंत बाद app `syncCustomerSession()` चलाता है; Auth signup/OTP event पर कोई profile-row insert नहीं दिखा।
- `srk_customer_profiles` row अलग authenticated RPC `srk_customer_update_my_profile(text,text,text)` के insert/upsert से बनती है।
- इसलिए Auth user होना अपने-आप Customer profile होने का प्रमाण नहीं है। AI guard में Customer profile absent होने पर `403 ai_access_denied` सही fail-closed व्यवहार है; मौजूदा regression test भी इसे जाँचता है।

**Implementation decision:** जब तक trusted Customer provisioning तय न हो, AI widget को Customer profile उपलब्ध होने से पहले mount न करें और backend guard को bypass न करें। Profile auto-provisioning चाहिए तो OTP-verified Auth identity के बाद server-side provisioning trigger/RPC का additive design, existing profile fields/defaults, duplicate handling और पुराने accounts की backfill अलग से review करें। केवल `user_metadata.role`, browser-supplied role या client flag को Customer role का प्रमाण न बनाएं।

## 5. क्रमबद्ध implementation gates

1. Customer और Electrician role provisioning/identity lifecycle की पुष्टि।
2. ऊपर की अलग AI tables और service-role-only database contracts की additive migration।
3. Ownership, idempotency replay/conflict, concurrent handoff और append-only audit के database tests।
4. Netlify routes को persistence/RPC से जोड़ना; हर request पर server-side ownership checks।
5. Provider adapter, timeout/rate-limit, prompt/data minimization और kill switch।
6. Main Admin handoff queue; उसके बाद अलग permission/session tests के साथ Support Staff access।
7. CI, staging database migration/runtime tests, app E2E और explicit launch approval।

किसी भी gate के असफल होने पर API `ai_not_enabled`/safe unavailable response दे। AI बंद रहने पर booking, payment, payout और support के मौजूदा workflows चलते रहने चाहिए।

## 6. अभी की स्थिति

- यह दस्तावेज़ केवल data-model और security contract तय करता है।
- कोई AI table migration इस commit में नहीं जोड़ी गई।
- कोई migration apply नहीं हुई; Production/paid Database Branch नहीं बदली।
- AI provider call, live conversation persistence और human handoff अभी उपलब्ध नहीं हैं।
- App का default-off launch guard यथावत रहेगा।

### 4.2 Customer AI widget mount का अतिरिक्त UI audit

`syncCustomerSession()` में OTP session मिलने पर app पहले `loadCustomerProfile()` चलाता है और उसके बाद `mountCustomerAiAssistant()` को unconditional call करता है। `loadCustomerProfile()` में profile row न मिलने पर “नई प्रोफ़ाइल है” status दिखता है, लेकिन function कोई readiness result नहीं लौटाता; इसलिए वर्तमान क्रम profile अनुपस्थित होने पर भी widget mount कर सकता है। यह backend authorization bypass नहीं है—`lib/ai-server-guard.js` का server-side profile lookup ऐसे request को `403 ai_access_denied` से रोकता है—लेकिन यह UI/backend readiness mismatch है और अनावश्यक failed requests दे सकता है।

**Required UI correction:** profile loader को explicit readiness (`true` केवल authenticated user की profile row सफलतापूर्वक मिलने पर) लौटानी चाहिए। `syncCustomerSession()` केवल readiness true होने पर Customer AI widget mount करे; missing profile, profile lookup error, session change या logout पर widget destroy/unmount रहे। सफल `srk_customer_update_my_profile()` के बाद profile दोबारा load/verify करके ही widget mount हो। Tests में profile-present, profile-missing, lookup-error और logout/session-change cases cover हों। OTP के बाद स्वतः profile create करने का कोई अनुमान न लगाया जाए।

### 4.3 Profile-readiness guard का implementation verification (18 नवम्बर 2026)

पिछले UI audit के बाद source implementation दोबारा verify किया गया:

- `loadCustomerProfile()` अब केवल authenticated session के लिए profile row सफलतापूर्वक मिलने पर readiness `true` देता है; missing row, lookup error या session unavailable होने पर `false` रहता है।
- `syncCustomerSession()` readiness true होने पर ही Customer AI widget mount करता है; अन्यथा widget destroy रहता है।
- Profile save के बाद भी loader से profile दोबारा fetch/verify किया जाता है; dashboard visible और profile verified होने पर ही widget mount होता है।
- `lib/ai-server-guard.js` अभी भी हर request पर Customer profile या approved+active Electrician profile server-side जाँचता है और अंत में `503 ai_not_enabled` देता है। UI readiness check backend authorization का विकल्प नहीं है।
- Regression coverage `tests/ai-assistant-app.test.js` में जोड़ी गई; branch CI run `44262276362` में 619 tests सफल, 0 failed रहे।

**शेष निर्णय:** OTP verification के बाद Customer profile स्वतः बनानी है या मौजूदा explicit profile-save flow ही रखना है—यह product/onboarding निर्णय अभी खुला है। वर्तमान व्यवहार fail-closed है; इस audit में signup trigger, profile schema या database migration नहीं बदली गई।


## 7. Finalized pre-migration contract — 18 नवम्बर 2026

यह section implementation review के लिए canonical contract है; यह SQL migration नहीं है और इसे किसी database पर apply नहीं किया गया है।

### 7.1 Table ownership और constraints

1. `srk_ai_conversations`
   - Primary key UUID; owner Auth user से जुड़ा होगा।
   - `actor_type` केवल `customer` / `electrician`; `module_key` actor के allowlisted modules में ही।
   - Status केवल `open`, `handoff_pending`, `closed`; timestamps server-generated।
   - प्रत्येक request पर owner, active profile और module authorization पुनः जाँचना होगा; UUID अकेले अनुमति नहीं है।

2. `srk_ai_messages`
   - Conversation FK के साथ `sequence_no` positive bigint; unique (`conversation_id`, `sequence_no`)।
   - Sender केवल `user` / `assistant` / `system`; body non-empty और bounded (अधिकतम 8,000 characters)।
   - Sequence allocation conversation row lock लेकर उसी transaction में हो; client sequence स्वीकार न हो।
   - Provider request ID वैकल्पिक diagnostic reference है, secret या raw provider payload नहीं।

3. `srk_ai_idempotency`
   - Unique (`owner_user_id`, `endpoint_key`, `idempotency_key`); request hash canonical validated request का SHA-256।
   - Key length bounded और endpoint allowlisted; response body bounded JSONB, secrets/credentials निषिद्ध।
   - Same key + same hash + completed => original status/body replay; same key + different hash => conflict; processing => bounded retry/processing response; retryable failure => केवल defined retry policy से पुनः प्रयास।
   - Expiry cleanup केवल retention window के बाद; active processing row कभी cleanup नहीं। Concurrent insert unique constraint और row lock से serialize हों।

4. `srk_ai_handoffs`
   - Conversation और owner दोनों से जुड़ा; queue/reason/urgency/status allowlisted।
   - एक conversation पर एक समय में अधिकतम एक open handoff (queued/assigned/in_progress)।
   - Staff assignment तब तक बंद रहेगा जब तक अलग staff permission और session authorization लागू व tested न हो; प्रारंभिक queue Main Admin-only।

5. `srk_ai_audit_events`
   - Append-only; event type/outcome allowlisted, actor/module/correlation IDs और सीमित sanitized metadata।
   - सामान्य roles को SELECT/INSERT/UPDATE/DELETE direct grants नहीं। केवल trusted server-side writer; UPDATE/DELETE/TRUNCATE निषिद्ध।
   - Audit write failure पर sensitive action fail closed; message text और credentials audit metadata में नहीं।

### 7.2 API transaction order

- Auth session verify → server-side actor/profile/module authorization → bounded input validation → canonical request hash → idempotency claim.
- Conversation owner/actor/module row lock और booking ownership/assignment re-check → user message + assistant result + audit events atomic transaction में persist।
- External model call database transaction/row lock के भीतर नहीं चलेगा। पहले idempotency claim `processing` commit; provider call bounded timeout के साथ; फिर result persist और idempotency `completed` mark। Crash recovery के लिए processing lease/expiry और retry policy अलग से implement/test होगी।
- Provider timeout या unknown outcome पर नया key बनाकर automatic duplicate call नहीं; same key status/retry contract लागू होगा।
- Handoff create, conversation status update और audit event एक database transaction में; response में persisted handoff ID/status मिलने के बाद ही UI success दिखाए।
- Booking context केवल server द्वारा fetched record से; Customer owner match और Electrician assignment match प्रत्येक request पर अनिवार्य।

### 7.3 Database security / rollout gates

- सभी AI tables पर RLS enabled; `anon` और `authenticated` को direct table privileges नहीं। Browser से AI tables पर direct REST access नहीं।
- Dedicated SECURITY DEFINER RPCs में `SET search_path = ''`, schema-qualified object references, explicit service-role assertion, strict EXECUTE grants और bounded result sets।
- Service-role assertion के साथ actor identity को verified Auth JWT से Netlify handler निकाले; request body/model output से actor ID कभी स्वीकार न हो।
- Foreign keys, CHECK constraints, partial unique open-handoff index, idempotency unique index, audit append-only enforcement और grants की catalog-level database tests हों।
- Migration additive हो; मौजूदा complaint/support messages, booking/payment/rate tables या पुराने workflows को reuse/alter न करे।
- पहले disposable/staging database पर full migration replay और negative permission tests; उसके बाद अलग explicit approval। इस branch update से कोई migration apply, deployment, paid database branch या production change नहीं होगा।

### 7.4 शेष product/engineering निर्णय

- Customer OTP के बाद profile auto-provisioning बनाम explicit profile-save flow।
- Provider/vendor, data retention, deletion/export policy और model-call budget।
- Processing lease duration, retry/backoff, provider idempotency support और stuck-request recovery।
- Main Admin handoff queue के बाद Support Staff permission boundary।
- इन निर्णयों और staging tests के बिना AI feature flag OFF और server guard का `503 ai_not_enabled` व्यवहार कायम रहेगा।


### 0.1 Main Admin handoff queue read RPC (18 नवम्बर 2026)

- नई source migration `20261118230000_admin_ai_handoff_queue_read_rpc.sql` में `srk_admin_list_ai_handoff_queue(integer)` जोड़ा गया है।
- यह केवल authenticated Main Admin (`auth.uid()` + `public.is_srk_admin()`) को queued/assigned handoff metadata पढ़ने देता है; सीमा 1–100 rows है।
- सूची में high urgency पहले, फिर oldest request और stable ID ordering है। Conversation owner/module सहित queue summary दिखती है।
- RPC read-only है: यह assign, resolve, cancel, messages पढ़ने या notification भेजने का अधिकार नहीं देता। PUBLIC/anon execute revoked; authenticated execute केवल function के Main Admin check के पीछे है।
- Support Staff role/permission source अभी repository में प्रमाणित नहीं मिला; इसलिए staff assignment और staff access बंद हैं।
- यह केवल Git branch source है; hosted migration, deployment और AI enablement नहीं हुए।
