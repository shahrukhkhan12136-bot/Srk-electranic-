# AI idempotency database test plan

Status: **test plan only — NOT EXECUTED**. GPT-2 owns implementation and execution of shared database tests. The test target must be explicitly approved as non-production. Do not point these tests at production.

## Required test matrix

1. Duplicate idempotency key: submit same actor/key/digest twice; assert one assistant message and stable exact replay.
2. Concurrent same-key completion: use two independent PostgreSQL sessions and a synchronization barrier; assert one completion/message, no duplicate, and deterministic replay/conflict for the second session.
3. Exact response replay: assert returned message ID is identical to the stored `response_message_id`, with same body; assert no latest-message query/fallback is used.
4. Wrong actor and wrong request digest: assert denial/conflict, zero response-body disclosure, and no writes.
5. Invalid response link: test missing message, message in another conversation, non-assistant sender, and conversation owned by another actor; all must fail closed without fallback.
6. Expired processing lease: set lease to >5 minutes old and assert completion is rejected with no message or completed status.
7. Failed retry: assert failed record never becomes a successful replay; verify the documented same-key failure/new-key behavior.
8. Retention: test completed and failed rows before, at, and after 7 days; ensure neither is reclaimed inside retention. Test processing lease before/at/after 5 minutes.
9. Transaction rollback: inject/force a failure after assistant insert but before idempotency finalization; assert both writes roll back.
10. Unauthorized RPC: attempt calls as anon, authenticated, wrong service identity; assert EXECUTE denial and no side effects.
11. Legacy bypass: attempt `srk_ai_finalize_idempotency(..., 'completed', ...)` and assistant `srk_ai_append_message`; both must be rejected. Confirm failed finalization and permitted user append remain correctly scoped.
12. Migration replay/rollback: apply migrations to clean disposable non-production database, verify constraints, grants, RLS and function definitions, then test documented rollback/re-apply.
13. Lock order/deadlock: run competing operations and inspect that all multi-row paths lock idempotency first then conversation; assert bounded completion/no deadlock/data corruption.

## Evidence to attach to Issue #11

- Non-production environment identifier and PostgreSQL version (no secrets).
- Migration file names and checksums/commit.
- Exact test command and test harness revision.
- Per-case pass/fail results, total counts, and sanitized logs.
- Evidence of two-session concurrency and rollback behavior (not only SQL text matching).
- Confirmation of RLS, grants, function EXECUTE permissions, and safe function search_path.

## Execution boundary

This plan does not create or apply migrations and does not connect to a database. GPT-2 must approve the non-production target and execute/own the real transaction, concurrency, security, migration replay, and rollback tests. Static repository tests may supplement but cannot replace those tests.
