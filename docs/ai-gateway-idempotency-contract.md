# AI Gateway idempotency and exact-response replay contract

Status: implementation design only. Do not apply this SQL or enable AI until the database owner reviews and approves it.

## Why this is needed

The current `srk_ai_idempotency` row stores the request digest, status, response code and conversation ID. The current reserve RPC returns those fields on replay, but not the exact assistant message created by that request. Looking up the latest assistant message in a conversation is unsafe because multiple requests can be made in the same conversation.

## Required database contract

The database owner should add:

- `response_message_id uuid NULL REFERENCES public.srk_ai_messages(id) ON DELETE RESTRICT` to `srk_ai_idempotency`.
- A service-role-only atomic completion RPC, e.g. `srk_ai_complete_idempotency`, that accepts actor ID, idempotency key, request digest, conversation ID, assistant response text and the intended successful HTTP response code.
- In one database transaction, the RPC must lock the matching `processing` idempotency row, verify the digest and actor, then lock and verify the conversation belongs to the actor and is open. It must insert exactly one `assistant` row, update the idempotency row to `completed` with HTTP response code, conversation ID and the inserted `response_message_id`, and return that message ID.
- Use one documented lock order whenever a transaction must lock both records: idempotency row first, conversation row second. Review every existing and future RPC that touches both records to ensure it does not acquire them in the reverse order. Keep transactions short and use bounded database/request timeouts so lock contention fails safely rather than hanging.
- The reservation RPC's `replay` response must include `response_message_id`. A completed row with a missing response message ID must fail closed rather than guessing.
- A replay read must fetch only that exact message ID and verify its conversation ID, sender kind (`assistant`) and conversation owner before returning the saved body. It must not select the latest assistant message as a fallback.
- Failed requests must never be replayed as successful responses. Processing reservations continue to return `processing`.
- Define the idempotency retention policy explicitly. The current reservation migration's conflict-update predicate reclaims any expired row, not only expired `processing` rows. Therefore, with the current 24-hour expiry, a completed key may stop replaying after expiry and can be reused. The database owner must explicitly approve this behavior or change the predicate/retention policy; add tests for completed, failed and abandoned-processing keys before and after expiry. Do not describe this as reclaiming only abandoned processing reservations.
- Define and test behavior for a lost client response after the atomic completion commits: the same actor/key/digest must replay the stored exact response without inserting another assistant message, for as long as the approved retention policy promises replay.

## Atomicity, concurrency and privacy requirements

Do not append an assistant message and finalize the idempotency row in two separate calls: a process crash between them could leave an unlinked answer and cause a second generation. The completion RPC must do both atomically.

The existing `srk_ai_finalize_idempotency` RPC can currently mark a request completed without an assistant message reference, and `srk_ai_append_message` can independently append an assistant message. After the new contract is approved, the database owner must decide how to retire, restrict or redefine these paths so successful AI responses cannot bypass atomic completion. Keep user-message append behavior separate if needed; do not let the server successfully complete an AI response through the old split-call sequence.

Concurrent requests using the same actor and idempotency key must serialize on the unique idempotency record. Requests using different keys in the same conversation must serialize safely on the conversation record while preserving the lock order above. Add database-level tests for same-key concurrent completion, different-key same-conversation completion, transaction rollback, and retry after a committed completion whose HTTP response was lost.

Keep prompt/request text out of the idempotency table. The assistant response remains in the private messages table under existing service-role-only access. Never return provider errors, keys, or raw provider payloads to clients. Keep all AI routes disabled until the new database contract has been deployed and verified in an approved non-production environment.

## Verification required before server wiring

- Migration tests verify the foreign key, nullability, service-role-only grants, and constraints for completed rows.
- RPC tests verify actor/key/digest matching, ownership, open-conversation checks, exact message linkage, and atomic rollback.
- Concurrency tests verify no duplicate assistant message for same-key retries and no deadlock/data corruption for different keys in one conversation.
- Replay tests verify only the stored `response_message_id` is returned, and missing/mismatched message links fail closed.
- Expiry tests verify the explicitly approved retention policy for completed, failed and abandoned-processing keys.
- Tests verify legacy finalize/append RPCs cannot bypass the approved atomic success path.
- An approved non-production integration test verifies the actual database transaction behavior. Static SQL text tests alone are not sufficient.

## Current boundary

The existing database migrations and RPCs are shared database work and are not changed by this GPT-1 feature-branch change. This document is a handoff specification only; it does not apply a migration or modify a hosted database. The AI server guard remains disabled and is not wired to the Gateway client.
