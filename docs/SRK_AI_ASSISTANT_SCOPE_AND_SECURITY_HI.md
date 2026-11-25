# SRK ELECTRONIC — AI Assistant Scope, Architecture & Security Gate

**Status:** Approved scope captured; implementation and live-provider verification are NOT complete.
**Branch:** `work/srk-completion-gap-20261125`
**Authority:** “शाहरुख खान शुद्ध मास्टर चकलिष्ट” plus the user's latest explicit direction (2026-11-25).

## 1. Product boundary
SRK has one coordinated platform:
- Customer Android app
- Technician/Helper Android app (separate registration and role identity)
- New Admin web panel (the only Admin panel in the final release)
- Shared Supabase data and server-side business rules
- Role-aware AI Assistant available in the apps and Admin panel

The existing Admin panel may be retired only after the replacement has passed the full acceptance checklist, all required records/settings have been migrated or verified, and the replacement is approved for release. Do not remove the existing panel or its data during development.

## 2. AI Assistant experiences
### Customer
- Explain six active service categories, service coverage, booking steps, estimated labour-only pricing and booking status.
- Guide OTP/login, profile, location/address, booking, quote approval, completion, payment, receipt, complaint and emergency-help flows.
- Explain cash/online payment status only from verified booking/payment records.
- Create a support/complaint draft; submit only after the customer confirms.
- Never reveal technician identity/contact before booking acceptance; after acceptance, follow the platform's approved contact-visibility rule.

### Technician and Helper
- Explain registration, document verification state, approved skills, online/offline status and incoming offers.
- Guide accept/decline, work start, timer, pause reason, GPS return, resume, completion, quote, cash/online payment, earnings, commission and payout request.
- Read only the signed-in worker's own profile, bookings, timer history, earnings and payout status.
- Never fabricate offer, GPS, timer, payment, earnings or payout status.

### Staff and Admin
- Help authorized staff navigate assigned inboxes, booking queues, verification, complaints, refunds, payout review, reports and emergency response.
- Answer using only records allowed by the signed-in role and current permissions.
- Main Admin may request cross-platform summaries, audit trails and date-filtered reports.
- Staff cannot ask the assistant to elevate permissions, inspect restricted Aadhaar/bank/UPI details, or access another role's private data.

## 3. Tool/action safety
- AI text generation is not authorization. Every read/write action must call a server-side RPC/Edge Function/Netlify Function that re-checks authenticated user, role, permission, ownership, booking state and input constraints.
- Read-only tools are the default.
- Any consequential action (booking cancellation/override, worker suspension, quote/bill override, refund, payout approval/paid marking, commission/rate/settings changes, staff permission changes, emergency closure) requires a clear preview and explicit confirmation from an authorized human. High-risk actions remain Main-Admin-only.
- Never mark a payment or payout as successful based only on a user statement or AI inference. Require verified webhook/status or Admin-reviewed evidence and reference as defined by the payment workflow.
- Never generate or expose secrets, OTPs, full identity documents, bank details, or unrestricted location history in chat.
- Log assistant session, actor, role, tool name, record IDs, decision/confirmation, outcome, timestamp and safe redacted input/output metadata. Do not store unnecessary sensitive prompt content.
- If records are missing, conflicting or stale, say so and route to authorized human support; do not guess.
- Provide human handoff for complaints, disputes, safety incidents, payments and uncertain cases.

## 4. Language and response behavior
- Hindi first; support English and other configured Indian languages.
- Respond in the user's language. Ask one concise clarification when intent or booking facts are ambiguous.
- Use plain language, accessible UI, and consistent status labels across all three products.
- Emergency help must bypass ordinary FAQ flows and surface the platform's SOS workflow immediately.

## 5. Architecture proposal (no vendor spend authorized)
- Keep model credentials server-side only. Never embed model/API keys in Flutter apps, browser JavaScript, or public configuration.
- Use a server-side AI orchestration endpoint (Netlify Function or Supabase Edge Function) and the project's verified role-aware backend tools.
- Use a version-matched AI SDK/provider integration only after checking the installed package/API docs. Provider/model selection must be confirmed against current availability.
- Add rate limits, per-role quotas, request-size limits, timeout/retry policy, prompt-injection defenses, tool allowlists, redaction, and cost caps.
- Do not activate paid model usage, create paid subscriptions, or incur AI Gateway/provider charges without explicit user approval. Until credentials and budget are approved, show a clearly labelled unavailable/help fallback rather than pretending AI is connected.
- Persist only the minimum conversation context needed; define retention and deletion rules before launch.

## 6. Labour-only financial invariant
Every AI explanation, tool schema, quote, estimate, bill, receipt, payment, earnings, commission, wallet, payout, report and export must use service/labour values only. Do not create or display any separate goods/parts concept, field, option, quantity, amount or calculation. Preserve historical records only as restricted integrity data; do not surface them in new product screens or reports.

## 7. Acceptance tests before marking AI complete
- Customer cannot access worker/admin tools; worker cannot access customer/admin private data; staff tools enforce each assigned permission; Main Admin-only tools reject all other roles.
- Cross-user ID guessing and prompt-injection attempts do not disclose data or execute unauthorized tools.
- AI cannot invent booking/payment/timer/GPS/payout states when the source RPC returns empty, denied or stale data.
- Consequential actions require preview + explicit confirmation and produce audit records.
- OTP, login, account recovery, language selection, support handoff and session expiry work.
- All six active service categories and the approved service catalogue are represented correctly; Motor Winding is unavailable for new work.
- All finance-related responses and documents are service/labour-only.
- Hindi/English responses, ambiguous-intent clarification, offline/error fallback and emergency routing are tested.
- Usage limits and provider cost controls are tested before enabling live model traffic.

## 8. Current implementation audit (2026-11-25)
- No AI Assistant source files, assistant endpoints or AI-related Flutter dependencies were found in the inspected feature-branch tree.
- Customer and Technician Flutter apps exist and contain login/booking/payment-related code, but the inspected app entrypoints do not yet show an integrated AI assistant, in-app chat or SOS interface.
- Existing server-side functions include booking/push/payment and a limited Admin staff-management function; these do not constitute a complete AI agent.
- This document records the required scope and security gates only. It does not claim that an AI model, assistant UI, tool calling, or live integration has been implemented or tested.

## 9. Release gate
AI Assistant, Customer App, Technician/Helper App and the new Admin panel must be tested as one end-to-end system. No production deployment, paid provider activation, Main Supabase migration, merge, or retirement of the existing Admin panel occurs without the applicable explicit approval.
