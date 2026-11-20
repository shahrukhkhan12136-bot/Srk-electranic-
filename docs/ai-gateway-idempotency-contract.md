# AI Gateway idempotency and exact-response replay contract

Status: implementation design only. Do not apply this SQL or enable AI until the database owner reviews and approves it.

## Why this is needed

The current `srk_ai_idempotency` row stores the request digest, status, response code and conversation ID. The current reserve RPC returns those fields on replay, but not the exact assistant message created by that request. Looking up the latest assistant message in a conversation is unsafe because multiple requests can be made in the same conversation.

## Required database contract

The database owner should add:

- `response_message_id uuid NULL REFERENCES public.srk_ai_messages(id) ON DELETE RESTRICT` to `srk_ai_idempotency`.
- A service-role-only atomic completion RPC, e.g. `srk_ai_complete_idempotency`, that accepts actor ID, idempotency key, request digest, conversation ID and assistant response text.
- In one database transaction, the RPC must lock the matching `processing` idempotency row, verify the digest and actor, verify the conversation belongs to the actor and is open, insert exactly one `assistant` row, update the idempotency row to `completed` with HTTP response code, conversation ID and the inserted `response_message_id`, and return that message ID.
- The reservation RPC's `replay` response must include `response_message_id`. A completed row with a missing response message ID must fail closed rather than guessing.
- A replay read must fetch only that exact message ID and verify its conversation ID, sender kind and owner before returning the saved body.
- Failed requests must never be replayed as successful responses. Processing reservations continue to return `processing`; expired reservations may be reclaimed under the existing lease rule.

## Atomicity and privacy requirements

Do not append an assistant message and finalize the idempotency row in two separate calls: a process crash between them could leave an unlinked answer and cause a second generation. The completion RPC must do both atomically.

Keep prompt/request text out of the idempotency table. The assistant response remains in the private messages table under existing service-role-only access. Never return provider errors, keys, or raw provider payloads to clients. Keep all AI routes disabled until the new database contract has been deployed and verified in an approved non-production environment.

## Current boundary

The existing database migrations and RPCs are shared database work and are not changed by this GPT-1 feature-branch change. This document is a handoff specification only; it does not apply a migration or modify a hosted database.
