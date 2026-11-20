# AI Gateway idempotency and exact-response replay contract

Status: **CHANGES REQUESTED — NOT APPROVED.** This is a design and test handoff only. Do not apply shared SQL migrations, change hosted Supabase, wire/enable the AI route, or deploy until the database owner gives explicit approval after reviewing the revised artifacts and test evidence.

## Scope and ownership

GPT-1 now owns the combined AI Assistant application and database work, including schema, migrations, RPCs, RLS/grants, and non-production integration tests. GPT-2 is no longer an active workstream. This ownership transfer does not authorize applying migrations to hosted projects, enabling AI, or deploying.

## Required schema and exact-response replay

Add a nullable `response_message_id uuid` reference to `public.srk_ai_messages(id)` with `ON DELETE RESTRICT`. A simple foreign key to the message primary key is necessary but is not sufficient for the application contract: replay validation must also prove all of the following before returning content:

- The idempotency row belongs to the authenticated actor and matching idempotency key.
- The stored request digest matches the retry's digest.
- The referenced message exists and its `conversation_id` equals the idempotency row's `conversation_id`.
- The referenced message has `sender_kind = 'assistant'`.
- The conversation belongs to the same actor. For a completed record, a later transition of that conversation to `closed` does **not** invalidate replay during the completed retention window; replay remains actor-scoped and returns only the exact stored message ID. The original completion still requires the conversation to be open.

Prefer a composite database constraint/foreign-key design where the existing schema permits it, or enforce the cross-row relationship inside a tightly scoped service-role RPC with explicit validation. Document the chosen enforcement mechanism. A missing, deleted, mismatched, non-assistant, or otherwise invalid response message is a fail-closed integrity error. **Never fall back to the latest message or any other message.**

The reservation/replay contract must return the exact `response_message_id` for completed records. The replay read must load only that ID and validate its conversation, sender kind, and owner before returning the saved response. It must not require the conversation to remain open after completion.

## Atomic completion RPC

The database owner should implement a service-role-only `public.srk_ai_complete_idempotency` RPC. It must perform the following in one database transaction:

1. Lock the matching idempotency row using `SELECT ... FOR UPDATE`.
2. Verify actor ID, idempotency key, request digest, `status = 'processing'`, and the current lease fencing/version token.
3. Verify the processing lease is still valid (not expired).
4. Lock the target conversation row only after the idempotency row is locked.
5. Verify conversation ownership matches the actor and conversation status is `open`.
6. Insert exactly one assistant message.
7. Update that same idempotency row to `completed`, saving `response_message_id`, `conversation_id`, `response_code`, and `completed_at`.
8. Return the exact inserted message ID and the minimum response metadata needed by the caller.

Any validation, insert, or update failure must abort the entire transaction; no orphan assistant message and no completed idempotency record may remain. The fixed lock order is **Idempotency Row → Conversation Row** in every RPC/transaction that needs both locks. Review all related RPCs for reverse-order acquisition and deadlock risk.

A completed record is immutable for the replay-retention window. A retry with the same actor/key/digest returns the exact stored response without inserting another assistant message. Wrong actor or digest must never reveal the stored response.

### Different idempotency keys targeting the same conversation

Each request first locks its own idempotency row, then locks the shared conversation row. Two different keys for the same actor/conversation therefore serialize at the conversation lock. If the conversation remains open, both valid requests may append one assistant response each in lock-acquisition order; neither may overwrite or duplicate the other's response. Each idempotency record stores its own exact message ID. If the conversation is closed before a request obtains/rechecks the conversation lock, that request fails without inserting a message. All paths retain the Idempotency Row → Conversation Row lock order.

## Retention, failed-key policy, and lease fencing

Do not use one generic 24-hour expiry to reclaim every status. Store/track separate timing semantics:

- **Processing lease:** 5 minutes. A lease is valid only while `processing_lease_expires_at > transaction_timestamp()`; at the exact expiry timestamp it is expired. Only an expired `processing` claim may be reclaimed.
- **Completed replay retention:** 7 days from `completed_at`. A completed record remains retained at the exact `retention_expires_at` timestamp. Cleanup/reuse is permitted only strictly after expiry, using `retention_expires_at < transaction_timestamp()`. A completed record must not be reset or reclaimed while `retention_expires_at >= transaction_timestamp()`.
- **Failed record retention:** 7 days from its failure timestamp. The deterministic same-key policy during retention is: same actor/key/digest returns a stable failure result (no assistant response body and no successful replay); same actor/key with a different digest returns a conflict without revealing the prior result. A failed record is never silently converted to success. After the retention boundary has strictly passed and cleanup removes the row, the key may be reused as a new reservation.

For an expired `processing` row, reclaim is allowed only for the same actor/key/digest. A different digest conflicts while that row exists. Reclaim must atomically increment a monotonically increasing `lease_version` (or issue an equivalent unguessable lease token) and set a new 5-minute lease. The worker receives that version/token and completion must compare it under the idempotency row lock. Once reclaimed, an old worker's token no longer matches and its completion must fail without writes. Actor mismatch is always denied.

Specify timestamp columns/semantics (for example, `processing_lease_expires_at`, `completed_at`, `failed_at`, `retention_expires_at`, and `lease_version`) and index/cleanup behavior. Cleanup must lock rows and recheck status/expiry atomically; it must not race with in-flight completion or violate the fixed lock order. For completed/failed retention, the comparison is inclusive for retention (`retention_expires_at >= now()` means retained) and cleanup is strict (`retention_expires_at < now()`). Tests must cover immediately before, exactly at, and immediately after each boundary.

## Legacy RPC safety

- Restrict `srk_ai_finalize_idempotency` so it can finalize **failed** outcomes only; it must reject attempts to mark a record `completed`.
- Restrict `srk_ai_append_message` so it cannot insert `assistant` messages. Preserve user-message append only if the database owner confirms it is needed and safe.
- Assistant messages for successful AI responses must be inserted only by `srk_ai_complete_idempotency`.
- Verify grants, function ownership, SECURITY DEFINER/search_path behavior, RLS, and authorization so callers cannot bypass these restrictions through alternate RPC paths.

## Required database tests (must exercise real PostgreSQL behavior)

Static SQL text assertions are useful as a supplemental guard but do not satisfy this test requirement. Run the following against an approved non-production Supabase/PostgreSQL environment with real transactions and independent concurrent sessions:

| Area | Required case and expected result |
|---|---|
| Duplicate key | Same actor/key/digest cannot create two assistant messages |
| Concurrent same key | Two simultaneous completions serialize; exactly one message is inserted and the other receives exact replay/defined conflict |
| Exact replay | Retry returns the same `response_message_id` and same stored response |
| Wrong actor/digest | Denied/conflict; no message body disclosed and no write occurs |
| Invalid response link | Missing, wrong-conversation, non-assistant, or wrong-owner message fails closed; no latest-message fallback |
| Closed conversation replay | Completed response remains replayable to its actor by exact message ID after conversation closure, until retention expiry; another actor is denied |
| Expired lease/fencing | Expired claim cannot complete; after same-digest reclaim, old lease token is rejected and new token may complete |
| Failed retry | Same digest gets stable failure; different digest conflicts; neither path produces a successful replay |
| Retention boundary | Completed/failed rows are retained at the exact expiry timestamp; cleanup/reuse occurs only strictly after it; test before/at/after |
| Transaction rollback | Forced failure after message insert but before idempotency update leaves neither partial write nor completed state |
| Different keys, same conversation | Two independent sessions with different keys serialize on the conversation lock; if it remains open both append distinct messages; if closed before the second recheck, second fails cleanly |
| Unauthorized RPC | anon/authenticated or wrong service identity cannot invoke privileged completion or bypass checks |
| Legacy RPC bypass | Finalize cannot mark completed; append cannot create assistant message |
| Migration replay/rollback | Apply on clean non-production DB, verify repeatability/rollback procedure and constraints/grants/RLS |
| Lock order | Competing transactions do not acquire conversation before idempotency; exercise deadlock/race scenarios |

Capture the database version/environment, migration identifiers, test commands, pass/fail counts, and relevant sanitized logs. Do not include secrets or customer data. The database owner must approve the non-production test target and execution before any live database test.

## Security and privacy requirements

- Privileged RPCs must enforce service-role authorization and explicit actor/key/digest/ownership checks; do not trust client-supplied actor IDs without binding them to the authenticated request context.
- Verify RLS policies, table privileges, function EXECUTE grants/revokes, SECURITY DEFINER ownership, and a fixed safe `search_path`.
- Keep prompt/request text out of the idempotency table. Do not expose provider credentials, raw provider payloads, or internal errors.
- A replay must be scoped to the authenticated actor and exact stored message ID.
- No partial success is allowed: transaction failures roll back all writes.

## Review gates and current boundary

1. GPT-1 updates this design and test plan only.
2. GPT-2 reviews the revised artifacts and provides a new explicit decision.
3. Only after approval, GPT-2 implements shared migrations/RPCs and runs approved non-production transaction/concurrency/security tests.
4. GPT-1 reviews evidence and only then proposes server wiring; AI remains disabled until separately approved.

The existing shared migrations and hosted database remain unchanged by this handoff. This document does not authorize SQL execution, migration application, production deployment, or AI enablement.
