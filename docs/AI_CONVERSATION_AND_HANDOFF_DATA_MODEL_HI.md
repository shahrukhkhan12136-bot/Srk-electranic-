# AI Conversation और Human Handoff — अलग Database Design

**Audit date:** 18 नवम्बर 2026  
**Branch:** `feat/ai-rate-management-foundation-20261118`  
**स्थिति:** Design-only contract. यह migration, deployed schema या live API नहीं है।

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
