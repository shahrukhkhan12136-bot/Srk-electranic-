# SRK ELECTRONIC — AI और Rate List प्रगति (20 नवम्बर 2026)

## तय scope

- Rate List में केवल Main Admin को चारों published rate tiers अपने हिसाब से घटाने-बढ़ाने का अधिकार है। Draft/save और version-checked publish flow पहले से मौजूद है; इस workstream में नया quotation या custom electrician quote नहीं जोड़ा जाएगा।
- AI apps launch से पहले पूरी तरह OFF रहेगा। Provider account/key जोड़ना, `AI_GATEWAY_ENABLED=true` करना और live provider call करना इस चरण में निषिद्ध है।
- इस चरण का stop point: Rate List और AI की स्वीकृत pre-launch technical तैयारी के सभी code/test gates पूरे होने पर Developer Branch बनाने से ठीक पहले रुकना। Developer Branch स्वयं अभी नहीं बनानी है।

## Rate List — verified source status

- Main Admin-only rate edit, draft queue, version-checked publish/schedule और audit source मौजूद।
- Customer और Electrician अलग-अलग सुरक्षित read RPC से published catalogue पढ़ते हैं।
- Booking rate snapshot immutable है; पुराने booking rates नई catalogue से overwrite नहीं होते।
- चारों rate tiers integer paise में validate होते हैं; electrician net calculation payout-aligned 15% commission rule से जुड़ी है।
- Feature branch Node suite में rate catalogue tests पास हुए। Latest observed full feature-branch PostgreSQL replay success: run 44699164799 at commit d0770e4529f8e3c4b48a65dd529edae9e7d2493b. Isolated DB proof hosted TEST/Production DB पर migration apply होने का प्रमाण नहीं है।
- Rate List source को दोबारा implement नहीं करना; आगे केवल बची हुई isolated DB/CI evidence और Admin/Customer/Electrician acceptance checks पूरे करने हैं।

## AI — 20 नवम्बर को जोड़ा गया काम

- `lib/ai-assistant-runtime.js`: guarded assistant turn pipeline — actor-scoped idempotency reserve, conversation create, user-message append, last 12 messages read, server-only Gateway adapter, atomic assistant-response persistence, replay handling.
- `lib/ai-server-guard.js`: existing authentication/profile/booking ownership checks के बाद assistant runtime invoke करता है।
- Default OFF: `AI_GATEWAY_ENABLED` true न होने पर runtime कोई DB या provider request नहीं करता।
- `lib/ai-server-guard.js`: human handoff route authenticated checks के बाद service-role `srk_ai_request_handoff` RPC call करता है, लेकिन वही explicit release flag इसे भी बंद रखता है।
- Tests: `tests/ai-assistant-runtime.test.js` और handoff guard test जोड़े।
- Latest observed Node CI: run 44715035373, commit ab46b9b7d9fcfc6391ef5777a9c72b4d8aaf910b, 777/777 passed.
- Latest observed CI does not imply hosted Supabase, mobile device, live provider, or Production verification.

## AI के बाकी release gates

1. Human handoff notification delivery (assigned staff तक वास्तविक in-app/push/email notification) और failure/retry behavior.
2. Human approval-bound action workflow का final scope: MVP में assistant केवल informational रहेगा; कोई tool/action execution नहीं। यदि actions भविष्य में जोड़े जाएँ तो अलग secure approval DB/RPC/UI और tests पहले आवश्यक होंगे।
3. Admin handoff queue/assignment/reply/resolve end-to-end verification; staff permission matrix और audit verification.
4. Conversation/message persistence, retention, privacy और audit pgTAP/current migration replay CI को नवीनतम SHA पर फिर चलाकर प्रमाणित करना.
5. AI rate-limit/abuse/cost cap, prompt-injection, data minimization और fallback/kill-switch security tests.
6. Customer और Electrician apps में mobile UI QA; assistant disabled state और post-launch enablement behavior.
7. Final pre-launch security review और consolidated acceptance tests.

## Safety / no-go boundaries

- No AI provider account/key, no live model call, no enabling feature flag before launch.
- No hosted Supabase mutation, Production migration, deployment, merge to main, payment/refund/payout, or Developer Branch creation in this phase.
- Current feature branch: `feat/ai-rate-management-foundation-20261118`.
- Current tested commit at the time of this note: `ab46b9b7d9fcfc6391ef5777a9c72b4d8aaf910b`.
- Do not repeat completed work. Update this file only when new evidence or code changes occur.
## 20 नवम्बर — AI handoff notification delivery foundation update

- `supabase/migrations/20261118290000_ai_handoff_push_subscription_ledger.sql`: AI handoff के लिए अलग per-device delivery ledger, bounded retries, RLS, और service-role-only claim/finish/completion RPCs जोड़े गए। Existing job-offer delivery ledger को reuse नहीं किया गया क्योंकि उसका foreign key केवल job-offer outbox से जुड़ा है।
- `supabase/functions/ai-handoff-push/index.ts`: staff recipient list के अनुसार subscribed devices को न्यूनतम push alert भेजने का sender जोड़ा गया। Notification में conversation text, customer identity या phone number नहीं भेजे जाते।
- `netlify/functions/deliver-ai-handoff-notifications.js`: scheduled dispatcher जोड़ा गया, लेकिन `AI_HANDOFF_PUSH_ENABLED` `true` न होने पर वह केवल disabled response देता है। Edge sender भी अलग enable flag और private secret जाँचता है।
- `supabase/migrations/20261118300000_ai_handoff_notification_lease_fencing.sql`: expired worker lease को reject करना और अंतिम attempt पर crash हुए processing event को dead-letter में डालना जोड़ा गया।
- नए Node source safeguards test और pgTAP per-device ledger test जोड़े गए। Deno configuration के साथ Edge Function type-check workflow भी जोड़ा गया।
- नवीनतम Node CI: run [44723080946](https://github.com/shahrukhkhan12136-bot/Srk-electranic-/actions/runs/44723080946), SHA `b72717b3e610092845323f5e2fc78fffb5fe32d9` — success.
- AI Edge Function Deno type-check: run [44723786498](https://github.com/shahrukhkhan12136-bot/Srk-electranic-/actions/runs/44723786498), SHA `953e83fce9912d55de6569880498cd9a9eb2337c` — success.
- AI Admin/Staff + notification outbox/ledger pgTAP: run [44723080860](https://github.com/shahrukhkhan12136-bot/Srk-electranic-/actions/runs/44723080860), उसी SHA — success.
- Full feature-branch PostgreSQL migration replay: run [44722983726](https://github.com/shahrukhkhan12136-bot/Srk-electranic-/actions/runs/44722983726), SHA `88458680a37f643c76636f155aafa03c4358f825` — success; इसमें नई migrations का replay शामिल था।
- AI idempotency PostgreSQL tests: run [44722983748](https://github.com/shahrukhkhan12136-bot/Srk-electranic-/actions/runs/44722983748) — success. Rate List booking snapshot tests: run [44722983787](https://github.com/shahrukhkhan12136-bot/Srk-electranic-/actions/runs/44722983787) — success.
- Rate Catalogue draft pgTAP का पहला प्रयास Docker host port `54322` collision के कारण शुरू होने से पहले विफल हुआ; failed-job retry run [44722983797, attempt 2](https://github.com/shahrukhkhan12136-bot/Srk-electranic-/actions/runs/44722983797) — success.
- **महत्वपूर्ण सीमा:** यह source और isolated CI foundation है। कोई hosted database migration apply नहीं हुई, Edge Function deploy नहीं हुई, VAPID/worker secret configure नहीं हुए, और वास्तविक push नहीं भेजा गया। AI और handoff push दोनों OFF हैं।

## अगला काम

1. Rate Catalogue pgTAP retry का परिणाम सत्यापित करना और यदि आवश्यक हो तो workflow concurrency/port isolation ठीक करना।
2. AI push sender का isolated mocked-provider/integration test और TypeScript/Deno validation जोड़ना; live push के बिना retry/expired-device paths जाँचना।
3. AI handoff queue, assignment, reply, resolve और notification का end-to-end acceptance coverage पूरा करना।
4. AI abuse/rate-limit/cost cap, prompt-injection, retention/privacy, fallback/kill-switch और app UI QA के शेष gates पूरा करना।
5. Rate List में पहले से मौजूद Admin-only price change flow का final acceptance check करना; scope में कोई quotation/custom quote feature नहीं जोड़ना।


## 20 नवम्बर — बिना registered device के push को सफल न मानने की सुरक्षा

- जाँच में एक edge case मिला: किसी eligible Staff account के पास कोई push subscription न होने पर device ledger खाली रहता था और पुराना completion RPC खाली ledger को सफल मान सकता था।
- `supabase/migrations/20261118320000_ai_handoff_push_requires_device_delivery.sql` में completion RPC अब कम-से-कम एक device delivery record मौजूद होने और सभी records के delivered होने—दोनों शर्तों के बिना success नहीं देता।
- `supabase/tests/database/ai_handoff_notification_outbox.test.sql` में 15वीं pgTAP assertion जोड़ी गई; workflow अब इसी 15-test plan और नई migration को replay करता है।
- नवीनतम Node CI: run [44725610383](https://github.com/shahrukhkhan12136-bot/Srk-electranic-/actions/runs/44725610383), SHA `6748497ef633d7f62307879c6bacb82d2622da15` — success.
- नई AI handoff pgTAP run [44725610293](https://github.com/shahrukhkhan12136-bot/Srk-electranic-/actions/runs/44725610293), SHA `6748497ef633d7f62307879c6bacb82d2622da15` — अभी चल रही है; 15 assertions को pass घोषित नहीं किया गया है।
- उसी code state के migration replay, Rate Catalogue security, AI idempotency और booking snapshot के अलग-अलग checks पहले के SHA `6c2df7497f0e1c1b5d678dcd724a5d0bfc294747` पर success हुए: runs [44725464542](https://github.com/shahrukhkhan12136-bot/Srk-electranic-/actions/runs/44725464542), [44725464612](https://github.com/shahrukhkhan12136-bot/Srk-electranic-/actions/runs/44725464612), [44725464728](https://github.com/shahrukhkhan12136-bot/Srk-electranic-/actions/runs/44725464728), [44725464479](https://github.com/shahrukhkhan12136-bot/Srk-electranic-/actions/runs/44725464479) — इनमें नई pgTAP assertion वाला अंतिम workflow SHA शामिल नहीं है।
- Rate List acceptance: `admin.html` में Main Admin draft save/edit, queue, version-checked publish/schedule; automated tests चारों दरों, सुरक्षित input, invalid draft rejection और Customer/Electrician के published catalogue reads को जाँचते हैं। कोई quotation feature नहीं जोड़ा गया।
- सीमा यथावत: कोई hosted DB migration, live push, VAPID secret, Edge Function deployment, AI provider key/call, Main merge या Developer Branch creation नहीं हुई। AI और push OFF हैं।


## 20 नवम्बर — AI अनुरोध सीमा और खर्च-सुरक्षा की शुरुआत

- नया migration `20261118330000_ai_request_rate_limits.sql`: service-role-only atomic Postgres RPC और निजी RLS table। शुरुआती hard limits प्रति user/per assistant module 10 requests प्रति rolling 10-minute bucket और 100 requests प्रति UTC day हैं।
- Runtime अब idempotency reservation के बाद और conversation/message/provider call से पहले capacity reserve करता है। सीमा पूरी होने पर HTTP 429 तथा Retry-After लौटता है; provider को call नहीं होता। Quota RPC fail होने पर भी request fail-closed रहती है।
- Idempotent replay दूसरी quota slot नहीं लेता; केवल नया reserved request गिना जाता है। Provider error के बाद reserved capacity वापस नहीं होती—यह abuse/cost guard का conservative व्यवहार है।
- Node CI run [44726735276](https://github.com/shahrukhkhan12136-bot/Srk-electranic-/actions/runs/44726735276), SHA `acf233730e30ea003d36962abae839dd793cca99` — success.
- AI request-limit pgTAP workflow run [44726735286](https://github.com/shahrukhkhan12136-bot/Srk-electranic-/actions/runs/44726735286), SHA `acf233730e30ea003d36962abae839dd793cca99` — queue में; 41 assertions अभी pass घोषित नहीं।
- इससे पहले उसी migration पर full PostgreSQL replay और AI/Rate List suites चल रही थीं; अंतिम SHA और परिणाम verify होने तक इन्हें final success नहीं माना जाएगा।
- AI और AI push OFF; कोई provider key/call, live push, hosted DB migration, deployment, Main merge या Developer Branch creation नहीं।


## CI परिणाम अपडेट — 20 नवम्बर

- Full feature branch PostgreSQL migration replay run [44726698016](https://github.com/shahrukhkhan12136-bot/Srk-electranic-/actions/runs/44726698016), SHA `c3b0e0ed9cd409057bc810bb6468a77265787dce` — success; baseline plus सभी migrations क्रम से replay हुईं और payout concurrency checks भी सफल हुए।
- Rate Catalogue draft/security + net-rounding pgTAP run [44726698171](https://github.com/shahrukhkhan12136-bot/Srk-electranic-/actions/runs/44726698171), SHA `c3b0e0ed9cd409057bc810bb6468a77265787dce` — 20 assertions success.
- Rate List booking snapshot pgTAP run [44726698165](https://github.com/shahrukhkhan12136-bot/Srk-electranic-/actions/runs/44726698165), SHA `c3b0e0ed9cd409057bc810bb6468a77265787dce` — success.
- AI Main Admin/Staff handoff + notification pgTAP run [44726698190](https://github.com/shahrukhkhan12136-bot/Srk-electranic-/actions/runs/44726698190), SHA `c3b0e0ed9cd409057bc810bb6468a77265787dce` — success.
- Node test run [44726899213](https://github.com/shahrukhkhan12136-bot/Srk-electranic-/actions/runs/44726899213), SHA `8462c55fbfe0c80b9833ccd9548e2e87edd63d9a` — success.
- AI request-limit pgTAP run [44726735286](https://github.com/shahrukhkhan12136-bot/Srk-electranic-/actions/runs/44726735286), SHA `acf233730e30ea003d36962abae839dd793cca99` — test SQL में malformed dollar-quote के कारण failed; migrations सफलतापूर्वक replay हुईं। Quote ठीक कर दिया गया है; rerun [44727454305](https://github.com/shahrukhkhan12136-bot/Srk-electranic-/actions/runs/44727454305) चल रही है।
- Request throttle अभी request-count limits enforce करता है; provider token usage और वास्तविक रुपये/डॉलर cost metering अभी अलग शेष कार्य है।

- अतिरिक्त runtime failure-path test भी जोड़ा: rate-limit database RPC अनुपलब्ध होने पर request fail-closed रहती है और conversation/provider work शुरू नहीं होता। Node CI run [44727154101](https://github.com/shahrukhkhan12136-bot/Srk-electranic-/actions/runs/44727154101), SHA `f43bf906b417275bb842d89b7634888e661cf553` — success.


## CI अंतिम सत्यापन — 20 नवम्बर, 17:26 IST

- AI अनुरोध सीमा का corrected pgTAP workflow run [44727454305](https://github.com/shahrukhkhan12136-bot/Srk-electranic-/actions/runs/44727454305), SHA `18ad32b1d33d1c86bf3f153dea1d1dbc94d07c57` — **success**, 41/41 assertions.
- उसी SHA पर Feature Branch Node tests run [44727454262](https://github.com/shahrukhkhan12136-bot/Srk-electranic-/actions/runs/44727454262) — **success**.
- पहले से सफल Rate List checks: Rate Catalogue draft/security 20 assertions [44726698171](https://github.com/shahrukhkhan12136-bot/Srk-electranic-/actions/runs/44726698171), booking snapshot [44726698165](https://github.com/shahrukhkhan12136-bot/Srk-electranic-/actions/runs/44726698165), और full feature-branch PostgreSQL migration replay [44726698016](https://github.com/shahrukhkhan12136-bot/Srk-electranic-/actions/runs/44726698016) — सभी success, लेकिन ये rate-limit migration के पहले वाले SHA `c3b0e0ed9cd409057bc810bb6468a77265787dce` पर हैं; इन्हें नए SHA पर rerun करना बाकी है।
- Request limit implementation एक user/module के लिए पहले request से शुरू होने वाला fixed 10-minute bucket और UTC day counter intended करता है; इसे strict rolling-window guarantee न समझें। Database function में UTC day boundary की explicit timezone handling का अलग review बाकी है।
- Gateway adapter provider response से prompt/completion/total token counts पढ़ता है, लेकिन runtime अभी इन counts को persist नहीं करता और provider/model pricing से रुपये/डॉलर cost calculate नहीं करता। इसलिए वास्तविक token/cost metering अभी पूरा नहीं है।
- AI तथा push disabled हैं। कोई live provider call, hosted DB mutation, deploy, Main merge या Developer Branch creation नहीं हुई।


## 20 नवम्बर — AI token usage ledger और prompt-injection safeguards

- नई migration `20261118340000_ai_usage_metering_ledger.sql`: provider generation attempts के लिए अलग append-only usage ledger और service-role-only `srk_ai_record_usage_event` RPC।
- Ledger में actor, conversation/request/attempt reference, module, provider/model, reported prompt/completion/total token counts और usage उपलब्ध न होने की स्थिति दर्ज होती है। User message, assistant response, prompt text, phone या अन्य conversation content इस ledger में नहीं रखा जाता।
- Usage ledger पर RLS enabled है; browser roles और service_role को direct table grants नहीं हैं। केवल SECURITY DEFINER RPC लिखता है; UPDATE/DELETE trigger से रोके जाते हैं।
- Runtime अब provider reply complete करने से पहले usage event दर्ज करता है। Provider usage metadata न दे तो fabricated zero counts के बजाय `unavailable` status रिकॉर्ड होता है। Ledger write failure पर assistant response success नहीं लौटता और idempotency request failed finalize होती है।
- Prompt में अब सभी user/history messages को untrusted data मानने, role override, hidden prompt/secret disclosure, दूसरे user के निजी data और बिना server-provided context के records/tools access का दावा न करने के स्पष्ट निर्देश हैं।
- Runtime tests: token metadata recording, no-message-content ledger payload, missing usage handling, ledger outage fail-closed, और prompt-injection string को user data के रूप में रखने के tests जोड़े।
- Node CI run [44733186672](https://github.com/shahrukhkhan12136-bot/Srk-electranic-/actions/runs/44733186672), SHA `6c562bc098e7393e769c71028ecc569a4e8b8e3c` — success.
- AI usage ledger security/persistence pgTAP plan अब 50 assertions है; run [44733186649](https://github.com/shahrukhkhan12136-bot/Srk-electranic-/actions/runs/44733186649) उसी SHA पर pending है। इसे pass घोषित नहीं किया गया है।
- Full feature-branch migration replay run [44733164959](https://github.com/shahrukhkhan12136-bot/Srk-electranic-/actions/runs/44733164959), SHA `0aeca4be9e704eb336f56c2a0b881e9d36a9a2fb` — in progress; इसमें नई usage migration शामिल है।
- **लागत सीमा:** token counts अब persist होंगे, लेकिन अभी model pricing table/version, currency conversion, INR cost calculation, daily rupee budget या per-user rupee spend cap नहीं है। वास्तविक रुपये की लागत metering अभी अधूरी है; अनुमानित pricing hardcode नहीं की गई।
- AI और push OFF; कोई provider call, hosted DB migration, deployment, Main merge या Developer Branch creation नहीं हुई।


## pgTAP test syntax correction — AI usage ledger

- First 50-assertion run [44732954321](https://github.com/shahrukhkhan12136-bot/Srk-electranic-/actions/runs/44732954321) reached assertion 47 successfully, then failed before assertion 48 because one new `throws_ok` test used a malformed dollar-quoted SQL delimiter (`$SELECT ... $`). This is test SQL syntax, not a migration/runtime failure.
- Corrected that assertion to the already-used tagged dollar quote `$q$ ... $q$` in commit `6c5cfb442168a1c7ef824bd3bab3492fca9ff454`.
- Corrected 50-assertion rerun [44733448601](https://github.com/shahrukhkhan12136-bot/Srk-electranic-/actions/runs/44733448601) is pending. Do not call the 50 pgTAP assertions passed until this run completes successfully.
- Full feature-branch migration replay including the usage-ledger migration: run [44733164959](https://github.com/shahrukhkhan12136-bot/Srk-electranic-/actions/runs/44733164959), SHA `0aeca4be9e704eb336f56c2a0b881e9d36a9a2fb` — success.
