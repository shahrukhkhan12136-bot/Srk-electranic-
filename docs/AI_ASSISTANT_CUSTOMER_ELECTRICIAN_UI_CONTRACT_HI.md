# SRK ELECTRONIC — Customer और Electrician AI Assistant UI Contract

**तारीख:** 18 नवम्बर 2026  
**स्थिति:** Pre-launch UI specification; अभी ऐप में visible/live widget mount नहीं किया गया है।  
**निर्भरता:** `lib/ai-assistant-client.js` और GPT-2 द्वारा प्रमाणित backend routes.

## 1. Rollout rule

- UI, copy, interaction states और app-side integration code launch से पहले तैयार होंगे।
- Production AI calls और user-facing activation launch के बाद, backend release gates पास होने पर ही होंगे।
- Default feature state `OFF`; no network request while OFF.
- AI बंद/अनुपलब्ध होने पर existing booking, payment, job acceptance, support-ticket और SOS flows unaffected रहें।
- Customer/Electrician screens में केवल उनका अपना assistant module render हो; Staff/Reports modules इस app scope में नहीं हैं।

## 2. Customer App surface

**Entry point:** Customer Help & Support area में “AI सहायता” entry. Existing support/complaint route remains available and visible.

**Module key:** `customer_support` for support questions; `booking_assistant` only for booking guidance/draft preparation.

**Allowed context:** Optional selected booking UUID only. Server verifies the signed-in customer owns the booking. Never send customer ID, role, admin flag, phone, address, payment credentials, or arbitrary booking data from the browser.

**Conversation states:**
1. Closed — no conversation request.
2. Ready — greeting, short explanation of supported topics, privacy note.
3. Sending — disable duplicate send; retain draft safely in current page memory only.
4. Answered — show assistant reply and clear “AI उत्तर” label.
5. Needs human — show “कर्मचारी से सहायता लें” action; do not claim ticket created until persisted handoff response returns an ID/status.
6. Unavailable — explain AI temporarily unavailable and keep existing support option available.
7. Disabled — show no active AI chat; existing support remains the primary route.

**Booking guidance:** AI may prepare a draft and explain the estimate. Customer must explicitly confirm through the existing booking UI; AI response never creates or confirms a booking by itself.

## 3. Electrician App surface

**Entry point:** Partner dashboard Help/Guidance area, separate from job offer accept/reject controls and SOS.

**Module key:** `electrician_assistant`.

**Allowed context:** Optional booking UUID for a job already assigned/authorized to the authenticated electrician. Server verifies assignment on every request.

**Allowed topics:** Assigned job summary, safe work guidance, app navigation and support escalation.

**Prohibited:** Other electricians' jobs, customer-private contact/address expansion, changing job status, accepting/rejecting/reassigning a job, changing rates, viewing company share before checkout, payout mutation, payment/refund actions, SOS dispatch.

**Conversation states:** Same common states as Customer App. Human handoff goes to the existing authorized support workflow; UI displays only backend-confirmed queue/reference/status.

## 4. Shared interaction and accessibility

- Hindi-first copy; preserve the app's existing language switching conventions.
- Keyboard accessible: labelled input, submit button, visible focus, Escape closes panel, Enter sends and Shift+Enter adds a line.
- Announce new replies and errors with an accessible live region.
- Provide loading, empty, retry and service-unavailable states.
- Prevent duplicate submissions using a UUID idempotency key per logical request.
- Never display raw provider/server error text, tokens, internal prompts or stack traces.
- Do not store transcripts in localStorage/sessionStorage until privacy, retention and deletion rules are approved.
- Never show fabricated “typing”, “ticket created”, “booking confirmed”, “payment successful” or “payout complete” states.

## 5. Human handoff UX

- User selects “कर्मचारी से सहायता लें” or assistant response explicitly requires a human.
- Show a short, editable sanitized summary before submission.
- Submit through the authenticated handoff client with a fresh idempotency key.
- Only after server confirms a persisted `handoff_id` and allowed status show “अनुरोध दर्ज” with returned reference/queue/status.
- On timeout or unknown response, show “स्थिति की पुष्टि नहीं हो सकी”; do not create a second request automatically. Let user retry with the same logical idempotency key or check existing support cases through the existing app flow.

## 6. Launch activation gates

Before mounting/activating either app surface:
1. GPT-2 confirms actual assistant and handoff routes, exact schemas and deployed environment.
2. Verified Supabase session token is obtained from the existing authenticated client; actor/role always derived server-side.
3. Backend ownership checks for customer-owned and electrician-assigned booking references pass.
4. Conversation and handoff persistence, idempotency, rate limits, audit, retention and kill switch are verified.
5. Sensitive action proposal/approval routes are tested; no model can approve or execute its own action.
6. Prompt-injection, cross-account isolation, abuse, provider outage and audit-write failure tests pass.
7. Product owner authorizes post-launch activation.

## 7. Explicit non-goals

This UI contract does not enable AI, create a provider account/key, create database tables or migrations, call a live API, change existing support workflows, or grant the assistant authority over booking, payment, refund, rate, payout, staff permission or SOS actions.

## Backend readiness snapshot — 18 नवम्बर 2026

- Branch में Netlify redirects और `netlify/functions/ai-assistant.js`, `netlify/functions/ai-handoff.js` scaffold मौजूद हैं।
- वर्तमान `lib/ai-server-guard.js` authenticated user और app profile से role जाँचता है, लेकिन assistant/handoff persistence, booking ownership/assignment checks, idempotency storage, audit logging, provider adapter और human-support queue अभी उपलब्ध नहीं हैं। Guard जानबूझकर हर valid request पर HTTP 503 `ai_not_enabled` लौटाता है।
- इसलिए इन paths को अभी **deploy-ready/live AI service नहीं** माना जाएगा। Client के API paths का Netlify redirect होना backend readiness का प्रमाण नहीं है।
- GPT-1 app UI mounting और feature activation को OFF रखेगा, जब तक GPT-2 वास्तविक कार्यशील contracts और सभी release gates प्रमाणित न करे। Existing customer support और electrician support flows यथावत रहेंगे।

## App-side mount preparation — 18 नवम्बर 2026

- Customer `booking.html` और Electrician `electrician.html` में shared AI client/widget/app scripts और role-specific mount slots जोड़े गए हैं।
- Customer mount authenticated और profile-ready session में अलग-अलग `customer_support` तथा `booking_assistant` modules के लिए प्रयास करता है; दोनों Customer Help & Support surface में अलग entry points हैं। Booking assistant केवल मार्गदर्शन/मसौदा देता है; booking की अंतिम पुष्टि existing Customer UI से ही होगी।
- Electrician mount केवल signed-in electrician flow में `electrician_assistant` module के लिए प्रयास करता है। Logout/account switch पर संबंधित widgets destroy किए जाते हैं।
- दोनों apps में mount helper का default kill switch कायम है: `AI_ASSISTANT_ENABLED` की explicit own-property value `true` न होने पर कोई widget render या AI network request नहीं होती। कोई live enablement/configuration नहीं जोड़ी गई।
- इसे pre-launch app integration preparation माना जाए; actual visible UI, backend integration और runtime verification checkpoints अभी complete नहीं हैं।
- Static regression test जोड़ा गया है, लेकिन इस environment में test execution नहीं हुआ; CI workflow run भी इस commit के लिए उपलब्ध नहीं मिला।
