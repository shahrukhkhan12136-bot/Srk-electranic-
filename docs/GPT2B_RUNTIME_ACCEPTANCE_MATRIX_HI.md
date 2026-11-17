# GPT-2B Runtime Acceptance Matrix — SRK ELECTRONIC

**Branch:** `chore/pr8-replay-audit-20261116-v2`  
**Prepared:** 17 November 2026  
**Purpose:** Bounded, evidence-based runtime checklist. This document records test cases and required evidence; it does not claim runtime tests have passed.

## Execution boundary

- All cases are **pending runtime execution** unless a dated evidence entry is added.
- Source inspection, static pgTAP assertions, and mocked Node tests are not substitutes for PostgreSQL/pgTAP or provider-integrated tests.
- Use only an approved isolated local/test database; never execute this matrix against production.
- Use Razorpay test mode and controlled test records. Never issue a real refund or payout.
- No paid Supabase Development Branch/staging subscription, production migration, deployment, merge, or mobile QA is authorized here.
- For every run preserve commit SHA, migration state, exact command, redacted environment, test names, assertion totals, full output, and cleanup confirmation.

## Workstream A — Razorpay payments, webhooks, refunds and recovery

| ID | Runtime acceptance case | Expected result | Existing source/test coverage | Runtime |
|---|---|---|---|---|
| A1 | Invalid/missing webhook signature | HTTP 400; no DB/RPC request | `tests/razorpay-webhook-inbox.test.js` | Pending |
| A2 | Valid unsupported webhook event | Durably marked ignored and acknowledged | Node mock; `razorpay_webhook_event_inbox.test.sql` | Pending |
| A3 | Duplicate event ID/payload | Acknowledged as duplicate; no replayed business logic | Node mock; SQL source contract | Pending |
| A4 | Same signed body, changed event header | Payload-hash replay detected; no second action | Node mock | Pending |
| A5 | Another worker holds live lease | Retryable 503; no concurrent processing | Node mock; SQL source contract | Pending |
| A6 | Expired lease and stale claim token | Exactly one new claim; stale token cannot complete | SQL source contract; concurrent DB test needed | Pending |
| A7 | Captured event for Cash booking | Ignored; booking/payment unchanged | Node mock | Pending |
| A8 | Captured event for already-refunded booking | Ignored; cannot reopen/mark paid | Node mock | Pending |
| A9 | Processed refund webhook | Exact booking/payment/refund identity and full amount reconciled once | Node mock; SQL reconcile guard | Pending |
| A10 | Late pending event after terminal processed/failed state | Terminal state is not regressed | SQL function source; DB transition test needed | Pending |
| A11 | Provider/RPC transient failure and retry | Safely retryable; no duplicate payment/refund side effects | Integrated failure/retry test needed | Pending |
| A12 | Refund request: missing login/non-Main Admin | Reject before provider request | `tests/razorpay-refund-executor.test.js` | Pending |
| A13 | Retry same refund request | Same persisted record and provider idempotency key; no duplicate refund | Node mock; provider test needed | Pending |
| A14 | Provider refund remains pending | Internal processing state; booking not marked refunded | DB + provider test needed | Pending |
| A15 | Provider confirms exact full refund | Reconcile once; booking refunded; payout reversal rules enforced | SQL source; Node mock | Pending |
| A16 | Amount/payment/currency mismatch or partial refund | Fail closed; no accounting finalization | Node mock; SQL full-amount guard | Pending |
| A17 | Ambiguous provider timeout | Unknown/uncertain; not marked failed and no blind second refund | Node mock | Pending |
| A18 | Refund status lookup | GET exact stored refund ID; no provider writes/accounting RPC | `tests/razorpay-refund-status.test.js` | Pending |
| A19 | Unlinked provider refund lookup | Bind only exact internal note/receipt; same payment+amount alone insufficient | Node mock | Pending |
| A20 | More than 100 provider refunds | Paginate to exact match; stop safely when exhausted | Node mocks | Pending |
| A21 | Recovery evidence authorization and immutability | Bounded Admin note, exact provider facts, append-only evidence | `durable_razorpay_refund_recovery_evidence.test.sql` | Pending |
| A22 | Pending/failed/stale recovery evidence | Never finalize accounting; refresh stale evidence | SQL source; Node mock | Pending |
| A23 | Finalization fails after evidence saved | Preserve evidence ID; safe retry without duplicate evidence | Node mock | Pending |
| A24 | Payout already paid during refund recovery | Block automatic recovery; manual reconciliation required | SQL source | Pending |

## Workstream B — Electrician payout and accounting reconciliation

| ID | Runtime acceptance case | Expected result | Existing source/test coverage | Runtime |
|---|---|---|---|---|
| B1 | Eligible completed booking | Exactly one payout row with correct electrician, gross, materials, commission and payable | `electrician_payout_reconciliation.test.sql` | Pending |
| B2 | Duplicate payout-trigger replay | No duplicate row; totals unchanged | SQL source assertions; DB replay needed | Pending |
| B3 | Commission-only update with missing payout | Expected parity exception; transaction rolls back | Two added pgTAP fixture cases | Pending |
| B4 | Commission-only update with mismatched payout commission | Expected parity exception; payout row unchanged | Two added pgTAP fixture cases | Pending |
| B5 | Commission-only update with matching payout | Booking and payout commission remain equal | Positive DB fixture needed | Pending |
| B6 | Materials change | Commission remains service-labour-only | SQL source assertions; DB fixture needed | Pending |
| B7 | Refund pending | Payout blocked and cannot be paid | SQL source | Pending |
| B8 | Refund processed | Unpaid payout reversed/closed per refund lifecycle | SQL source; DB lifecycle needed | Pending |
| B9 | Refund failed | Only refund-specific blocked payout restored to prior allowed state | SQL source; DB lifecycle needed | Pending |
| B10 | Refund after payout already paid | No automatic clawback; manual reconciliation required | SQL source | Pending |
| B11 | Admin payout settlement | Main Admin only; pending/completed/matching bill; valid UPI/bank reference | SQL source assertions | Pending |
| B12 | Concurrent settlement attempts | Row locks allow only one settlement; no double payment | Concurrent DB test needed | Pending |
| B13 | Paise rounding boundaries | Integer-paise half-up rule consistently applied | Boundary-value DB tests needed | Pending |
| B14 | Refund/payout race | Booking-first locks prevent inconsistent terminal states | Concurrent DB test needed | Pending |

## Workstream C — Customer Support, complaints and attachments

| ID | Runtime acceptance case | Expected result | Existing source/test coverage | Runtime |
|---|---|---|---|---|
| C1 | Customer reads own complaint | Own complaint and safe projection only | Customer Support Node/SQL contracts | Pending |
| C2 | Customer reads another customer's complaint | Denied; no message/attachment metadata leak | SQL source contract; DB role test needed | Pending |
| C3 | Complaint rate-limit boundary | Per-customer configured cap enforced | Advisory-lock SQL source contract | Pending |
| C4 | Two concurrent submissions at cap | Exactly one succeeds; total never exceeds 10 | Concurrent DB test needed | Pending |
| C5 | Customer links owned pending attachment | Only valid owned object and matching complaint can link | SQL source contract | Pending |
| C6 | Generic delete after attachment linked | Denied; unlinked pending upload cleanup remains allowed | `support_attachment_deletion_lifecycle.test.sql` | Pending |
| C7 | Attachment link/delete race | Locks serialize operations; linked object cannot be deleted | Concurrent Storage/DB test needed | Pending |
| C8 | Customer downloads own linked attachment | Allowed through private bucket policy | SQL source; Storage integration needed | Pending |
| C9 | Unrelated/anonymous user downloads attachment | Denied | SQL source; Storage integration needed | Pending |
| C10 | Complaint/message cascade and Storage object | Verify documented orphan-object behavior; no automatic cleanup assumed | Known residual | Pending |

## Workstream D — Electrician Support, Staff/RBAC and attachment access

| ID | Runtime acceptance case | Expected result | Existing source/test coverage | Runtime |
|---|---|---|---|---|
| D1 | Electrician reads own ticket | Own ticket visible | `electrician_support_ticket_security.test.sql` | Pending |
| D2 | Electrician A reads/replies to B's ticket | Denied | SQL source; DB role test needed | Pending |
| D3 | Ticket count at 9th/10th/11th boundary | Configured cap enforced; excess denied | DB test needed | Pending |
| D4 | Concurrent ticket submissions at cap | Count remains within configured cap | Concurrent DB test needed | Pending |
| D5 | Ticket linked to booking | Booking belongs to creator/authorized electrician | SQL source; DB test needed | Pending |
| D6 | Reply to closed ticket | Rejected | SQL source; DB test needed | Pending |
| D7 | Active Staff assigned to Customer Complaint | Can read thread and linked attachments | `support_attachment_staff_access.test.sql` | Pending |
| D8 | Unassigned/reassigned complaint | Unassigned and former assignee denied; current assignee allowed | SQL source; assignment race needed | Pending |
| D9 | Suspended/disabled Staff or revoked session | Denied on next request | SQL source; auth/session integration needed | Pending |
| D10 | Staff attachment upload/delete | Denied | SQL source; Storage integration needed | Pending |
| D11 | Main Admin and Customer attachment access | Admin policy preserved; Customer sees own attachments only | SQL source; Storage integration needed | Pending |
| D12 | Staff loses assignment after prior download | New requests denied; previously downloaded bytes cannot be remotely recalled | Documented platform limitation | Pending |

## Required execution order

1. Confirm isolated local/test database and exact migration chain; no production connection.
2. Replay all migrations from an empty database and resolve fresh-install/schema prerequisites.
3. Run pgTAP suites in dependency order: webhook inbox → refund evidence/reconciliation → payout reconciliation → Customer Support → Electrician Support/Staff attachment.
4. Run Node webhook/refund/recovery and support contract tests against controlled mocks.
5. Run Razorpay test-mode and private Supabase Storage integration tests; verify no provider writes occur on read-only/denied paths.
6. Run concurrency tests separately and preserve logs.
7. Only after all implementation is complete, perform the single consolidated final mobile QA pass.

## Evidence log

No PostgreSQL, pgTAP, provider-integrated, Storage-integrated, or concurrency runtime result is recorded at creation time. Add dated evidence only after the exact command is executed and output inspected.

**Status:** Matrix prepared; runtime execution pending. This document does not change the official GPT-2 delivery percentage.
