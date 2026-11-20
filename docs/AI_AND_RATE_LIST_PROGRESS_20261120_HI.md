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
