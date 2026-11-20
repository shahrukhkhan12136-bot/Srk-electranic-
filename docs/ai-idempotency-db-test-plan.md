# AI idempotency database test plan

Status: **test plan only — NOT EXECUTED**. GPT-1 owns implementation and execution of the combined database tests. The approved disposable CI PostgreSQL runner may be used; the existing Supabase TEST project must not be used destructively because its old data must be preserved. Do not point these tests at production.

## Required test matrix

1. **Duplicate idempotency key:** submit same actor/key/digest twice; assert one assistant message and stable exact replay.
2. **Concurrent same-key completion:** use two independent PostgreSQL sessions and a synchronization barrier; assert one completion/message, no duplicate, and deterministic replay/conflict for the second session.
3. **Exact response replay:** assert returned message ID is identical to the stored `response_message_id`, with same body; assert no latest-message query/fallback is used.
4. **Wrong actor and wrong request digest:** assert denial/conflict, zero response-body disclosure, and no writes.
5. **Invalid response link:** test missing message, message in another conversation, non-assistant sender, and conversation owned by another actor; all must fail closed without fallback.
6. **Replay after conversation closure:** complete a response, close the conversation, and assert the same actor can replay the exact stored message ID during retention; another actor is denied. No new completion is permitted on the closed conversation.
7. **Expired lease fencing:** set lease expiry to the exact boundary and just before/after it; at `lease_expires_at <= transaction_timestamp()` it is expired. Reclaim same actor/key/digest atomically, increment lease version/token, then assert the old worker cannot complete and the new token can.
8. **Failed retry semantics:** during the 7-day retention, same actor/key/digest returns the same stable failure code (no assistant body); same actor/key with a different digest returns conflict. Neither returns a successful response. Key reuse is permitted only after the failed row is deleted strictly after retention expiry.
9. **Completed retention boundary:** immediately before and exactly at `retention_expires_at`, completed response remains replayable and cannot be reclaimed/deleted. Only when `retention_expires_at < transaction_timestamp()` may cleanup delete it and later permit key reuse.
10. **Failed retention boundary:** immediately before and exactly at `retention_expires_at`, failed record remains protected and follows stable-failure/digest-conflict policy. Cleanup/reuse is allowed only strictly after expiry.
11. **Transaction rollback:** inject/force a failure after assistant insert but before idempotency finalization; assert both writes roll back.
12. **Different keys, same conversation:** use two independent sessions, same actor/conversation but different idempotency keys. Verify both lock their own idempotency row before the shared conversation row. If still open, both append distinct assistant messages in serialized order; if closed before second lock/recheck, second fails without a message.
13. **Unauthorized RPC:** attempt calls as anon, authenticated, wrong service identity; assert EXECUTE denial and no side effects.
14. **Legacy bypass:** attempt `srk_ai_finalize_idempotency(..., 'completed', ...)` and assistant `srk_ai_append_message`; both must be rejected. Confirm failed finalization and permitted user append remain correctly scoped.
15. **Migration replay/rollback:** apply migrations to clean disposable non-production database, verify constraints, grants, RLS and function definitions, then test documented rollback/re-apply.
16. **Lock order/deadlock:** run competing operations and inspect that all multi-row paths lock idempotency first then conversation; assert bounded completion/no deadlock/data corruption.

## Evidence to attach to Issue #11

- Non-production environment identifier and PostgreSQL version (no secrets).
- Migration file names and checksums/commit.
- Exact test command and test harness revision.
- Per-case pass/fail results, total counts, and sanitized logs.
- Evidence of two-session same-key and different-key concurrency, lease fencing, closed-conversation replay, retention boundary, and rollback behavior (not only SQL text matching).
- Confirmation of RLS, grants, function EXECUTE permissions, and safe function search_path.

## Execution boundary

This plan does not create or apply migrations and does not connect to a database. GPT-2 must approve the non-production target and execute/own the real transaction, concurrency, security, migration replay, and rollback tests. Static repository tests may supplement but cannot replace those tests.
