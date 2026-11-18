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
