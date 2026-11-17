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


## Evidence update — 17 November 2026 (source review only)

### Payout rollback fixture review
- Reviewed the two rollback fixtures in `supabase/tests/database/electrician_payout_reconciliation.test.sql` against the tracked starter table definitions and relevant migration additions.
- The fixture values visibly satisfy the starter `electrician_profiles` / `service_bookings` phone and PIN formats, booking status/payment-status domains, 0–100 commission-rate range, and payout-table uniqueness/amount requirements.
- The booking fixture's completed + paid + verified-payment state is designed to pass through the current BEFORE commission setter, AFTER payout writer, and later AFTER parity validator. The commission-only UPDATE targets the parity validator without firing the payout writer, as asserted by the test's trigger-column checks.
- The two negative behavioral cases are present in source: missing payout row and mismatched payout commission. Their rollback/preservation outcomes remain **unverified until pgTAP is executed**. This source review is not a test pass and does not establish that the actual canonical database baseline matches the starter schema.

### Remaining payout acceptance gap
- Added a positive behavioral fixture for B5: when booking and payout commission already match, a commission-only UPDATE must complete without error (`lives_ok`). The missing-payout and mismatched-payout negative cases remain alongside it.
- The payout pgTAP plan is now 52 assertions (48 `ok`, 3 `throws_ok`, 1 `lives_ok`), verified by source count. The positive case is source coverage only, not a runtime pass.
- The runtime matrix remains 60/60 Pending because no PostgreSQL/pgTAP execution has been performed.

### Fixed 15% commission invariant — source finding
- `create-booking.js` calculates the current estimate server-side and omits `commission_rate` from the insert payload, so new booking rows currently rely on the database column default.
- The starter `SUPABASE_SCHEMA.sql` defines that default as 15.00, and authenticated direct UPDATE of `commission_rate` is revoked by `20261109003000_secure_commission_reporting.sql` / later booking write closure.
- However, the payout and commission trigger functions calculate from the stored `new.commission_rate` and only reject null/out-of-range values; they do not themselves require exactly 15.00. The canonical base-schema default and any service-role write path are not proven by this source review.
- Treat exact 15% enforcement for newly created bookings as a source-level hardening item in the payout/commission workstream; preserve historical booking commission snapshots. No code or database change was made for this finding in this review.


### Fixed commission guard — implementation/source status (17 November 2026)

- Implemented in source migration `20261117130000_enforce_fixed_new_booking_commission_rate.sql`: new booking INSERTs are forced to `commission_rate = 15.00`, even if the caller supplies another value.
- Attempts to change `commission_rate` on an existing booking fail with `BOOKING_COMMISSION_RATE_IS_IMMUTABLE`; the migration does not rewrite historical booking snapshots.
- The existing commission amount calculation remains based on labour/service amount only; material amount is not included in the commission base.
- Added three pgTAP catalog/source assertions plus two behavioral assertions: fixture INSERT supplies 99% and must persist 15%; an attempted change of an existing booking snapshot to 20% must throw `BOOKING_COMMISSION_RATE_IS_IMMUTABLE`. The test plan is now 51. Test source is updated, but **no pgTAP execution has occurred**; all runtime acceptance cases remain Pending.
- The positive behavioral B5 case (commission-only update with matching payout) remains open and separate from these three catalog assertions.


### Payout parity positive-path fixture — 17 November 2026 (source-only)

- Added a third legacy approved-quote fixture with a matching booking commission and payout platform commission. A commission-only UPDATE is wrapped in `lives_ok` and must succeed.
- The fixture set now covers the positive matching case, missing-payout rejection, and mismatched-payout rejection. Source count checked: `plan(52)` = 48 `ok` + 3 `throws_ok` + 1 `lives_ok`.
- No PostgreSQL/pgTAP execution occurred; all 60 runtime acceptance checks remain Pending.


### Electrician Support Main Admin बनाम Staff RBAC — 17 November 2026 (source-only)

- पुराने electrician-support inbox RPCs (srk_admin_list/send/update_electrician_support_*) authenticated role को EXECUTE देते हैं, लेकिन function body में public.is_srk_admin() gate है; इसलिए ये Main Admin-only legacy route हैं, Staff access route नहीं।
- Staff के अलग RPCs (srk_admin_staff_*electrician*) क्रमशः support.electrician.read, support.electrician.reply, और support.electrician.update_status permissions तथा case/assignment ownership checks लगाते हैं।
- electrician_support_ticket_security.test.sql में कुल 4 नए source-contract assertions जोड़े; plan अब 16 है। इनमें exact per-operation permission gates और case/assignment lock order भी जाँचे जाते हैं। Source count verified; pgTAP execute नहीं हुआ।
- यह change runtime acceptance को pass नहीं करता; संबंधित runtime checks Pending रहते हैं।


### Razorpay Refund Recovery pagination edge cases — 17 November 2026 (source-only)

- `tests/razorpay-refund-recovery.test.js` में दो अतिरिक्त Node test cases जोड़े: (1) एक ही internal refund record से exact-match करने वाले दो provider refunds मिलें तो recovery evidence/finalization न हो; (2) pagination में अगले page पर पहले से देखा गया provider refund ID दोबारा आए तो search unstable मानकर fail-closed हो।
- ये cases `razorpay-refund-recovery.js` के मौजूदा `matches.length !== 1` और cross-page `seen` duplicate guards को exercise करने के लिए हैं; production logic में बदलाव नहीं किया गया।
- Test source जोड़ा गया है, लेकिन Node suite execute नहीं हुई। इसलिए ये runtime pass नहीं हैं और Acceptance Matrix के Pending checks नहीं बदलते।


### Razorpay Webhook event-ID collision guard — 17 November 2026 (source-only)

- `tests/razorpay-webhook-inbox.test.js` में एक नया source test जोड़ा: यदि वही provider event ID अलग signed payload के साथ दोबारा आए, तो webhook inbox का `payload_conflict` परिणाम सुरक्षित रूप से acknowledge हो, business reconciliation न चले और event को duplicate मानकर process न किया जाए।
- यह मौजूदा `srk_service_claim_razorpay_webhook_event` conflict branch और handler response contract की coverage है; production logic/SQL में कोई बदलाव नहीं किया गया।
- Node test execute नहीं हुई; इसलिए runtime pass नहीं माना गया और 60 runtime acceptance checks Pending ही हैं।


### Payout / Accounting reconciliation source audit — 17 November 2026 (read-only)

- Active branch के payout trigger और commission reconciliation source को फिर से cross-check किया: immutable labour bill, electrician assignment match, payment total में settled/reserved cancellation-fee ledger का मिलान, पर electrician payout से fee debt exclusion; commission केवल labour पर; refund-owned blocked hold ही refund होने पर बंद; पहले से paid payout overwrite न होना।
- `srk_set_booking_commission_before_payout()` manual payment evidence के amount और payment-method दोनों को मिलाता है; `srk_validate_booking_commission_payout_parity()` missing payout row तथा booking-vs-payout commission mismatch पर transaction रोकता है।
- New booking के लिए `aa_srk_enforce_new_booking_commission_rate` पहले 15.00% set करता है; पुराने booking commission snapshot को बदलने से रोकता है। Existing 52-check pgTAP file में 48 `ok`, 3 `throws_ok`, 1 `lives_ok` assertions का source count मिला।
- इस read-only pass में कोई नया confirmed source defect नहीं मिला; इसलिए बिना प्रमाण नया code/test जोड़कर scope नहीं बढ़ाया। SQL/pgTAP/PostgreSQL runtime execute नहीं हुआ; 52 checks source assertions मात्र हैं और runtime acceptance Pending है।


### Customer Support Staff attachment metadata RPC privilege assertion — 17 November 2026 (source-only)

- `support_attachment_staff_access.test.sql` में एक अतिरिक्त pgTAP assertion जोड़ा: `srk_admin_staff_list_customer_attachments(uuid)` का VOLATILE + SECURITY DEFINER + empty `search_path` होना, authenticated को EXECUTE मिलना, और anon/PUBLIC को EXECUTE न मिलना। इससे metadata RPC की privilege boundary भी सीधे catalog-level पर जाँची जाएगी; पहले Storage guard के लिए यह coverage थी, metadata RPC के लिए PUBLIC ACL का अलग assertion नहीं था।
- Test plan अब 11 है। यह source-only बदलाव है; PostgreSQL/pgTAP execution नहीं हुआ, इसलिए assertion अभी Pending है।


### Electrician Support legacy Admin RPC privilege boundary — 17 November 2026 (source-only)

- `electrician_support_ticket_security.test.sql` में एक अतिरिक्त catalog-level pgTAP assertion जोड़ा गया। यह चार legacy Main Admin inbox RPCs पर एक साथ जाँचता है: `SECURITY DEFINER`, खाली `search_path`, authenticated EXECUTE और anon/PUBLIC EXECUTE का अभाव।
- इससे Staff के अलग RBAC RPCs और पुराने Main Admin-only RPCs के बीच privilege boundary की जाँच अधिक पूर्ण होती है। Test plan अब 17 है।
- यह source-only assertion है; PostgreSQL/pgTAP execute नहीं हुआ। Runtime status Pending ही है।


### Customer Support Staff RPC privilege boundary — 17 November 2026 (source-only)

- `admin_staff_rbac_foundation.test.sql` में एक catalog-level pgTAP assertion जोड़ा गया। यह चार Customer Support Staff RPCs (assigned complaint list, thread read, reply, status update) के लिए `VOLATILE SECURITY DEFINER`, खाली `search_path`, authenticated EXECUTE तथा anon/PUBLIC EXECUTE निषेध जाँचता है।
- Test plan 69 से 70 हुआ। यह source assertion है; PostgreSQL/pgTAP execute नहीं हुआ और Runtime status Pending है।



### Electrician Earnings UI — commission visibility conflict found (17 November 2026, source-only audit)

- Active branch file `electrician.html` के `loadEarnings()` भाग में `srk_get_my_earnings` RPC से `commission_amount` पढ़कर UI में स्पष्ट रूप से “कंपनी कमीशन” summary और हर paid booking पर “कमीशन” दिखाया जाता है।
- यह स्वीकृत Electrician App नियम से टकराता है: Electrician को केवल उसकी 85% देय कमाई दिखनी चाहिए; 15% Company commission को किसी नाम/रूप में Electrician App में नहीं दिखाना है।
- यह GPT-1 ownership वाला Electrician App UI है। इस GPT-2B audit में `electrician.html` को बदला नहीं गया। GPT-1 owner को स्पष्ट handoff आवश्यक है; साथ में backend RPC payload में commission field की जरूरत भी पुनः जाँची जाए ताकि अनावश्यक exposure न रहे।
- यह source-level confirmed UI defect है; कोई UI/runtime test execute नहीं हुआ। इसे fix या deploy हुआ नहीं माना जाए। Runtime acceptance अभी Pending है।



### Accounting RPC privilege and payout settlement cross-check — 17 November 2026 (source-only)

- `srk_admin_commission_report()` की मूल ACL migration में `PUBLIC/anon` revoke और `authenticated` grant मिला। बाद की `CREATE OR REPLACE` पर ACL preserve होने की पुष्टि source chain से की; function body में `auth.uid()` और Main Admin gate है।
- `srk_get_my_earnings()` की मूल ACL भी `PUBLIC/anon` revoke और `authenticated` grant है; SQL query exact `electrician_profiles.user_id=auth.uid()` तथा approved profile पर सीमित है।
- लेकिन RPC return shape में `commission_amount` अभी भी शामिल है। Electrician UI इसे दिखा रहा है—इसका UI conflict ऊपर दर्ज है। API response से field हटाने पर GPT-1 UI coordination और function return-type migration की जरूरत होगी; इस audit में कोई API contract change नहीं किया।
- `srk_admin_mark_electrician_payout_paid()` Main Admin gate, booking-first फिर payout-row lock, केवल pending payout transition, verified completed/paid booking, immutable labour bill, assigned electrician match और payout amount parity जाँचता है। Function पर `PUBLIC` revoke और authenticated EXECUTE grant मौजूद है।
- ये source/migration-chain checks हैं। ACL/catalog state, lock contention, concurrent refund-vs-payout, और settlement behavior को PostgreSQL/pgTAP runtime में verify नहीं किया गया; runtime acceptance Pending है।



### Storage Support policy interaction review — 17 November 2026 (source-only, scoped)

- Active branch HEAD was verified as `73723d1d96cbf193bbb118ace5ad3f9b0249a74f` before this review.
- Inspected all 4 migrations that define Storage policies among the 12 storage/support-related migrations: Customer Support conversation schema, Customer private-avatar storage, linked-support-attachment deletion guard, and assigned-Staff attachment read.
- Customer Support bucket policies are bucket-scoped to `srk-customer-support`: upload checks Customer complaint ownership; read checks Customer/Main Admin or the separately added currently assigned Staff attachment helper; delete checks the row-locking unlinked-object helper. The earlier broad Customer delete policy and later unlinked-only policy are explicitly dropped before the final delete policy is created.
- Avatar read/upload/delete policies are separately scoped to `srk-customer-avatars` and Customer ownership; they do not grant access to Customer Support objects.
- No second Support-bucket DELETE policy or broader Support-bucket SELECT policy was found in these inspected policy-defining migrations. The legacy setup/schema SQL files inspected do not define `storage.objects` policies.
- Scope limitation: this was a source review of policy-defining/support-related migrations and setup/schema SQL, not a live `pg_policies` catalog dump. Therefore it does not prove that the deployed Supabase project has no manually-created or dashboard-added permissive policies. Full catalog verification and delete/read behavior remain runtime acceptance items.
- No migration or application code changed in this audit; no PostgreSQL, pgTAP, Storage API, Node test suite, or CI was executed.



### Customer + Electrician Support Staff assignment lifecycle review — 17 November 2026 (source-only)

- Branch HEAD before review: `e5dc257186a601537860b26bc632b5b9ce22af64`.
- `srk_has_admin_permission(text)` requires active Staff registry entry, exact JWT `session_id`, matching non-revoked tracked session, and a still-existing Auth session. It holds shared locks on Staff and tracked-session rows; suspension/revocation updates serialize against in-flight authorized work.
- Main Admin assignment requires active Support-role Staff, locks Staff registry first, then the complaint/ticket row, then assignment row. Closed cases cannot be assigned.
- Both Customer and Electrician Staff inboxes are restricted to currently assigned cases. Thread reads lock case then current assignment; replies and status changes use the same case-then-assignment lock order and recheck the current assignee.
- Reply paths require both read and reply permissions, reject closed cases, validate message length, and record audit events. Status paths require read and update-status permissions, validate reason/status, reject closed cases, and record audit events. Staff cannot set a case to `closed`; only `in_review` or `resolved` is accepted.
- Reassignment changes the single assignment row. Since Staff thread/list operations lock and check that row, a completed reassignment prevents the former Staff member from accessing subsequent reads/writes; already-returned data cannot be recalled.
- No source-level defect was confirmed in these reviewed lifecycle paths. This does not prove concurrent behavior without runtime testing.
- Test files currently declare: `admin_staff_rbac_foundation.test.sql` plan 69, `electrician_support_ticket_security.test.sql` plan 16, and `support_attachment_staff_access.test.sql` plan 11. These are declarations/source assertions only; none were executed in this review.
- No code, migration, permissions, or production settings changed. PostgreSQL, pgTAP, Node, Storage API, and CI remain unexecuted.



### Cancellation Fee lifecycle + Admin direct-write / refund permission cross-check — 17 November 2026 (source-only)

- Branch HEAD before this review: `8989be5001ba88dd4333a05dab9edd6b952d14ec`.
- Traced `srk_customer_cancellation_fee_debts`, `srk_booking_cancellation_fee_items`, `srk_cancellation_fee_ledger`, online collection, cash collection, cancellation release, and full-refund reversal.
- Lifecycle is internally consistent at source level: `open -> reserved` on a new booking; `reserved -> open` with item `released` if the unpaid booking is cancelled; `reserved -> settled` on verified online/cash collection; on a verified full refund, a compensating debit/reversal ledger entry is appended, item becomes `reversed`, and debt returns to `open` for a future booking. Partial refund is rejected by the current full-refund path.
- Therefore reconciliation counting item statuses `settled` + `reversed` as historically captured fees is intentional: `reversed` means the fee was previously collected and later reversed. The signed cancellation-fee ledger net should equal currently settled items. This is not a confirmed reconciliation defect.
- Cash full-refund path also requires the original electrician wallet debit, writes a matching wallet credit, and reconciliation checks expected vs actual refund credit scoped to the manual refund evidence ID.
- Admin direct-write closure provides Main-Admin-only, row-locked legacy quote and customer-location RPCs; legacy quote mutation is blocked for new-category, cancelled, approved, or paid/online bookings and enforces labour+materials split where present. Location edits record before/after audit data. Direct authenticated UPDATE grants for the guarded booking fields are revoked; the earlier migration granted only status/quoted_amount/amount_paid/payment_status, and the closure revokes those plus address/district/state/pincode.
- Refund review decision RPC is Main-Admin-only, locks the request, and enforces allowed state transitions. Manual refund RPC validates approved Customer request when present, matching manual payment evidence, full amount against immutable labour/settled fee ledger for new-category bookings, and payout state. Provider recovery finalization and reconciliation RPCs explicitly require service_role and are not executable by authenticated/anon/public.
- Source tests currently declare 44 cancellation-fee reversal assertions and 14 manual-refund completion assertions; they were not executed. No DB, pgTAP, Node, CI, or provider runtime test was run.
- No source code, migration, permission, or production setting changed in this review. This remains source-level inspection only; live ACL/catalog and transaction concurrency need final runtime acceptance.


### Razorpay Provider Refund ID one-to-one mapping guard — 17 November 2026 (source-only)

- Confirmed source-level gap: recovery evidence accepted multiple observations for the same internal refund record, but did not prevent the same provider refund ID from being attached to a different internal refund record; it also did not prevent conflicting provider IDs being recorded against one internal record before finalization.
- Added `20261117140000_enforce_unique_razorpay_refund_identity.sql`. A shared SECURITY DEFINER trigger guard protects both recovery-evidence inserts and canonical `srk_razorpay_refunds.refund_id` writes.
- Guard takes transaction-scoped advisory locks for both provider ID and internal refund-record ID, then checks both directions across the audit and canonical refund tables. This serializes concurrent claims and rejects either provider-ID reuse across records or multiple provider IDs for one record.
- Repeated append-only observations remain permitted when both the internal refund record ID and provider refund ID match. A non-null canonical provider refund ID cannot later be changed.
- Added five source/schema assertions to `durable_razorpay_refund_recovery_evidence.test.sql` (declared plan now 40). They check both triggers, two-key advisory locking, both conflict guards, and SECURITY DEFINER/search-path metadata.
- Source files committed on the active feature branch only. Migration was NOT applied; pgTAP/PostgreSQL, migration replay, concurrency, Node, CI, provider API, and production checks were NOT run. Runtime acceptance remains pending.


### Manual Refund evidence + Razorpay recovery cross-link audit — 17 November 2026 (source-only)

- Active branch reviewed: `chore/pr8-replay-audit-20261116-v2`; starting HEAD `10dde83e3ef976891882227df46e7c680c853bf5`.
- Rechecked the canonical refund/payment tables and the latest manual-refund and Razorpay recovery RPC definitions.
- Manual-payment evidence is unique per booking. Manual-refund evidence is unique per booking and per payment-entry ID, and both tables are revoked from PUBLIC/anon/authenticated with service-role-only table access.
- The Main Admin manual-refund RPC locks the booking, checks verified-paid status, rejects Razorpay/online bookings, locks the same-booking manual-payment evidence, compares recorded payment to booking amount, and checks the full immutable labour + settled-fee amount for new-category bookings. It then checks existing refund evidence and payout state before writing the refund, updating booking state, and closing a blocked unpaid payout.
- Customer refund request creation is ownership-scoped, locks the booking and existing request, requires verified payment, validates new-category amount against immutable labour and settled fee items, and rejects existing Razorpay/manual refund evidence. Unique booking constraints provide a second duplicate barrier.
- Razorpay recovery evidence validates provider refund ID, payment ID, amount, currency, status and payload against the internal refund record and booking payment ID. The later one-to-one mapping guard covers both provider-ID reuse and conflicting provider IDs per internal record. Recovery finalization remains service-role-only and booking/refund/payout row-locked.
- No additional source-level defect was confirmed in these specific cross-link and duplicate-prevention paths. Live constraints, ACL/catalog state, and concurrent transaction behavior remain unverified.
- Documentation correction: the prior Support test-plan counts in this matrix were stale. Correct declared plans are Admin Staff RBAC 69, Electrician Support 16, and Staff Customer Attachment 11. These are declarations/source assertions, not executed pgTAP results.
- No database or provider calls, migration replay, PostgreSQL/pgTAP, Node suite, CI, deployment, merge, or production setting changes were performed.


### Electrician payout write-surface + commission trigger ordering audit — 17 November 2026 (source-only)

- Reviewed the current payout creation/settlement trigger, commission setter, fixed-rate guard, legacy commission-trigger retirement, and Main Admin payout settlement RPC.
- Trigger source ordering is intentional: `aa_srk_enforce_new_booking_commission_rate` runs before `zz_srk_set_booking_commission_before_payout` for BEFORE events, so a new booking receives 15.00 before commission is calculated. The AFTER payout trigger then consumes that persisted-in-transaction 15.00 rate. The legacy completion-time commission trigger is explicitly detached.
- The payout creation trigger writes/refreshes only a pending payout; it does not overwrite paid or other non-pending payout states. Full-refund transitions close pending payouts and only the specifically refund-owned blocked holds.
- Main Admin payout settlement RPC validates Main Admin identity, locks booking then payout, accepts only pending payout, checks booking/payment/immutable labour and payout-ledger parity, and records paid-by/reference metadata. Direct authenticated UPDATE of booking commission fields is revoked by the reviewed security migration.
- **Unresolved evidence boundary:** the reviewed migration chain and tracked setup SQL did not provide a conclusive canonical `CREATE TABLE` + ACL/RLS/grant definition for `public.srk_electrician_payouts`. Therefore this source review cannot prove that direct table-level writes are unavailable to authenticated users or that deployed table grants match the intended RPC-only payout lifecycle. This is not proof of an exploitable grant; it is a catalog-evidence gap. Final acceptance must inspect live `pg_class`, `information_schema.role_table_grants`, `pg_policies`, and relevant function ACLs, without broadening grants.
- No migration/code change was made. No PostgreSQL catalog query, SQL/pgTAP, Node suite, CI, deployment, merge, or production setting was executed/changed.


### Booking commission + payout trigger ordering / manual settlement cross-check — 17 November 2026 (source-only)

- Cross-checked `aa_srk_enforce_new_booking_commission_rate`, `zz_srk_set_booking_commission_before_payout`, `srk_reconcile_electrician_payable`, and `zz_srk_validate_booking_commission_payout_parity`.
- BEFORE trigger names place the fixed 15.00% new-booking guard before the commission calculation trigger. The calculation uses immutable labour for new-category bookings and legacy approved service-charge labour for legacy quote bookings; materials are excluded from commission.
- AFTER trigger ordering places payout reconciliation (`srk_...`) before booking/payout commission parity validation (`zz_...`) in the same transaction. Missing payout or booking-vs-payout commission mismatch raises an exception, rolling back the booking write and trigger-side payout write together.
- Legacy Admin manual-payment RPC locks the booking, requires a completed assigned booking with approved quote, records manual payment evidence, updates payment status/method/verified timestamp, then inserts or verifies the pending payout. The BEFORE commission setter independently recomputes commission from the stored booking rate; the AFTER payout trigger upserts only a pending payout, and the parity trigger checks the result. The RPC rejects any existing payout whose profile, labour, materials, commission, payable, status, or payment ID differs from the verified manual payment evidence.
- Legacy completion-time commission trigger is detached by the retirement migration; no active duplicate legacy commission calculation trigger was identified in the reviewed migration sequence.
- No new source-level defect confirmed in these specific trigger/manual-settlement paths. This remains source evidence only; PostgreSQL trigger catalog/order, SQL compilation, rollback semantics, and concurrent execution have not been runtime-tested.
- No source migration or application code changed. No DB/pgTAP/Node suite/CI/deployment/merge/production setting was executed or changed.


### Electrician payout table grants / RLS canonical migration cross-check — 17 November 2026 (source-only)

- पहले दर्ज payout-table direct-write authorization evidence gap को tracked migration chain के canonical base definition से फिर जाँचा: `20261114125844_restore_financial_audit_core_schema.sql` में `public.srk_electrician_payouts` बनाया गया है और RLS enable किया गया है।
- उसी migration में `PUBLIC`, `anon`, और `authenticated` से table के सभी privileges revoke हैं; `service_role` को ALL और `authenticated` को केवल SELECT grant है। इससे authenticated direct INSERT/UPDATE/DELETE grant source में नहीं दिखता।
- Authenticated SELECT policy केवल `public.is_srk_admin()` या उसी user के `electrician_profiles.user_id=auth.uid()` वाले payout rows को पढ़ने देती है। इसलिए prior source-only “canonical payout table grants not established” blocker tracked migration evidence के स्तर पर resolve हुआ; यह deployed/live catalog की पुष्टि नहीं है।
- `20261114360000_new_category_electrician_payout_reconciliation.sql` में payout creation trigger function का direct EXECUTE PUBLIC/anon/authenticated से revoke है। Main Admin settlement अलग SECURITY DEFINER RPC से होता है; RPC में Main Admin gate, booking-first row locks, pending-only transition और ledger parity checks हैं।
- सीमा: migration replay के दौरान यदि payout table पहले किसी अन्य baseline से मौजूद हो तो यह migration का explicit REVOKE/GRANT block फिर भी intended ACL लागू करता है; लेकिन वास्तविक deployed `pg_class`, `role_table_grants`, `pg_policies`, function ACL और table owner का live catalog evidence अभी बाकी है। यह audit live database query नहीं था।
- कोई source code/migration बदला नहीं; केवल यह evidence note जोड़ा गया। PostgreSQL, pgTAP, Node suite, CI, migration replay, deployment या production settings execute/change नहीं किए गए। Runtime acceptance matrix के सभी 60 checks Pending हैं।


### Refund Recovery pgTAP source assertion correction — 17 November 2026 (source-only)

- Refund recovery migration chain को फिर cross-check किया: `20261115240000_harden_refund_recovery_full_amount.sql` अंतिम recovery finalizer में booking-first lock के बाद `srk_electrician_payouts` को `booking_id=v_booking.id` से lock करता है; full-collection amount equality भी उसी finalizer में enforce होती है।
- `durable_razorpay_refund_recovery_evidence.test.sql` में payout-lock source assertion गलती से `where id=v_payout.id` खोज रहा था, जो implementation से मेल नहीं खाता था। इसे वास्तविक `where booking_id=v_booking.id` predicate से ठीक किया। यह test-source mismatch था; production function में defect नहीं मिला।
- Test का declared plan 40 ही रखा; assertion count नहीं बदला। यह pgTAP execution नहीं है—SQL compilation, migration replay और pgTAP अभी नहीं चलाए गए।
- No database, provider API, CI, deployment, merge, या production setting changed.


### Online settlement fee-retry idempotency correction — 17 November 2026 (source-only)

- Confirmed source flaw: successful first settlement moves cancellation-fee items from `reserved` to `settled`, while the RPC previously compared retries against the now-reduced reserved-fee sum before checking the already-paid/same-payment case.
- Added `20261117150000_fix_online_settlement_fee_retry_idempotency.sql`. The revised RPC validates the booking's original Razorpay order ID before retry handling; for the same already-paid payment ID it compares the retry amount against durable `service_bookings.amount_paid` in paise and returns `already_processed=true`. A changed amount or different payment ID is rejected. New/unpaid settlement still validates immutable labour plus currently reserved fees and retains the existing fee-ledger idempotency keys.
- Extended `admin_labour_bill_payment_accounting_bridge.test.sql` from declared plan 19 to 23 with source assertions for order validation, durable amount matching, retry-before-reserved-fee-sum ordering, and changed-amount rejection.
- Source-only GitHub changes. Migration has NOT been applied; pgTAP has NOT been run. No PostgreSQL, provider API, Node suite, CI, deployment, merge, cherry-pick, or production setting changed.
- GPT-2 official checklist remains **27/39 = 69%**; this source correction is not runtime acceptance evidence. Runtime matrix remains **60/60 Pending**.


### Payout table direct-write ACL evidence boundary + Admin refund review cross-check — 17 November 2026 (source-only)

- Rechecked payout creation/settlement source and the 52-assertion declared payout pgTAP file. The test covers trigger attachment, privileged trigger execution, client EXECUTE denial for the trigger function, Main Admin checks on the settlement RPC, booking-first locking, pending-only settlement, immutable labour/assignment/commission/payable parity, and rollback fixtures.
- Confirmed test coverage gap: `electrician_payout_reconciliation.test.sql` contains no `has_table_privilege`, `pg_class.relacl`, RLS, or `pg_policies` assertion for direct table access to `public.srk_electrician_payouts`. In the inspected payout-related migration files, writes are performed by SECURITY DEFINER trigger/RPC paths, but no canonical table-level GRANT/REVOKE or policy definition for this payout table was established from those files.
- Therefore direct authenticated INSERT/UPDATE/DELETE denial and intended SELECT visibility must remain **unverified**, not assumed from function-level EXECUTE restrictions. Required evidence: owner-approved canonical baseline plus live catalog output for table ACL, RLS enabled/forced state, and all applicable policies. Do not add a speculative ACL migration before that baseline is established.
- Cross-checked Admin refund review RPCs: both require authenticated Main Admin identity internally, lock the refund-request row for decisions, enforce allowed status transitions, and only record review decisions; approval does not itself call a payment provider or issue a refund. Existing pgTAP test declares 16 assertions for RPC privilege gates and state/transition contracts; it does not replace runtime authorization checks.
- No new source defect confirmed in these inspected paths. No source migration/app code changed in this audit. No PostgreSQL catalog query, SQL compile, migration replay, pgTAP, Node suite, CI, provider API, deployment, merge, cherry-pick, or production setting executed/changed.
- GPT-2 official checklist remains **27/39 = 69%**; runtime acceptance remains **60/60 Pending**.


### Support Staff financial-permission isolation cross-check — 17 November 2026 (source-only)

- Rechecked the current Support RBAC migration and its pgTAP source. The Support role is seeded with exactly seven permissions: customer support read/reply/status, electrician support read/reply/status, and basic booking context. The permission test explicitly rejects finance, payment, wallet, refund, payout, cancellation-fee, KYC, staff-management, audit, cancellation-decision, and private-contact permissions.
- Permission helper requires an active Staff registry row, an exact extant Auth session, a non-revoked tracked Staff session, and the mapped role permission; it holds shared locks on the Staff registry/session rows so suspension/revocation serializes with in-flight authorized work. Main Admin is intentionally handled as a separate identity class.
- Customer and Electrician Staff inboxes are assignment-scoped; reply/status RPCs re-check current assignment under row locks. Staff RPCs reviewed here do not expose payout/refund actions. This is source-level confirmation, not a live Auth/session concurrency test.
- Recounted the current `admin_staff_rbac_foundation.test.sql`: declared plan **70**, actual pgTAP assertion calls **70**. The test is not executed. This count supersedes any earlier conflicting notes for the current file revision.
- Payout table direct-write ACL remains unresolved as recorded above; Staff permission isolation does not prove table ACL safety for other authenticated clients.
- No source code or migration changed. No PostgreSQL, pgTAP, Node suite, CI, deployment, merge, cherry-pick, or production setting executed/changed. GPT-2 official checklist remains **27/39 = 69%**; runtime acceptance remains **60/60 Pending**.


### Payout table canonical schema / ACL source sweep — 17 November 2026 (source-only)

- Verified current branch HEAD before review: `853fa47a82d380199472ca4286d65c9d1c01a05d`.
- Re-read `SUPABASE_SCHEMA.sql`, `COMPLETE_DATABASE_SETUP.sql`, `PORTAL_SCHEMA.sql`, payout creation/settlement migrations, payout reconciliation trigger migration, and payout pgTAP source. No `CREATE TABLE public.srk_electrician_payouts`, `ALTER TABLE ... ENABLE ROW LEVEL SECURITY`, table-level `GRANT/REVOKE`, or `CREATE POLICY` for this table was found in these tracked files.
- Repository code searches for the exact table-creation, RLS-enable, grant, and policy strings also returned no results. The payout migrations use the table from SECURITY DEFINER trigger/RPC code, but that does not establish the table's direct client ACL or RLS state.
- Existing payout pgTAP source exercises privileged trigger/RPC behavior and fixture DML, but does not assert `has_table_privilege`, `relrowsecurity/relforcerowsecurity`, `relacl`, or applicable `pg_policies` rows for `srk_electrician_payouts`.
- Conclusion: the canonical table owner, schema definition, RLS enabled/forced state, direct authenticated/anon privileges, and any live permissive policies remain an explicit evidence blocker. No speculative DDL/ACL migration was created. Required next evidence is an owner-approved schema-only baseline or authorized read-only catalog export including table owner, ACL, RLS flags, and policies.
- No source or SQL files changed. No database connection/query, migration replay, SQL compile, pgTAP, Node suite, CI, deployment, merge, cherry-pick, or production setting changed.
- GPT-2 official checklist remains **27/39 = 69%**; runtime acceptance remains **60/60 Pending**.


### Refund identity guard + online settlement retry source/test consistency — 17 November 2026 (source-only)

- Re-read the current provider-refund identity trigger migration, the durable recovery evidence writer/finalizer, the full-amount finalizer replacement, the online settlement retry migration, and both corresponding pgTAP source files.
- Identity guard uses the same advisory-lock order for both write paths (provider refund ID, then internal refund record ID), checks both append-only recovery observations and canonical refund records, permits repeated observations only for the same mapping, and prevents reassignment of an already-populated canonical provider refund ID. Trigger helper is SECURITY DEFINER with empty search_path and direct EXECUTE is revoked from browser/service roles; trigger invocation remains the intended path.
- Recovery finalizer source still validates fresh processed evidence, full captured booking amount, booking/payment/refund cross-links, booking-first row-lock order, paid-payout stop, and blocked-payout close after the booking refund transition. No additional source-level mismatch confirmed in this pass.
- Online settlement retry checks service-role identity, exact Razorpay order, completed/online booking and non-refunded state; same-payment retry compares supplied paise against durable `amount_paid` before reading reserved fee rows, while changed amount/payment ID fails closed. New settlement still validates immutable labour + reserved fees and writes idempotent fee-ledger credits.
- Recounted both current pgTAP source files: `durable_razorpay_refund_recovery_evidence.test.sql` plan **40/40 assertions**; `admin_labour_bill_payment_accounting_bridge.test.sql` plan **23/23 assertions**. These are declared/source assertion counts only; neither test was executed.
- No source defect confirmed in the reviewed paths. Remaining evidence boundary: SQL parser/compile, complete migration replay, PostgreSQL/pgTAP runtime, transaction concurrency, provider API behavior and deployed ACL/catalog remain unverified.
- No source code or migration changed. No DB connection/query, SQL execution, pgTAP, Node suite, CI, deployment, merge, cherry-pick, or production setting changed. GPT-2 official checklist remains **27/39 = 69%**; runtime acceptance remains **60/60 Pending**.


### Razorpay Webhook Inbox + Refund Executor source/test cross-check — 17 November 2026 (source-only)

- Rechecked webhook handler, webhook inbox migration, refund executor, and their Node test sources.
- Webhook signature is verified against raw request bytes with HMAC-SHA256 and timing-safe comparison before any database request. Event claim uses provider event ID plus signed-payload hash uniqueness; same body under a changed header resolves to the canonical stored event; reused event ID with changed payload is rejected; active lease returns retry; expired/retryable claims receive a new claim token.
- Completion RPC locks the event row and only accepts the current claim token. A stale worker cannot mark the newer worker's claim complete; handler surfaces failure so provider retry can occur. Business reconciliation paths use their own booking/refund idempotency and row-locking RPCs; actual concurrent execution remains unverified.
- Refund webhook lookup requires exactly one internal record for the payment, exact amount/payment match, and—when provider ID is not already bound—matching internal refund-record note or idempotency receipt. Ambiguous or unrelated same-payment/same-amount provider refunds are not reconciled. Dedicated event/status combinations are validated before the server-side reconciliation RPC.
- Refund executor requires Main Admin before provider request, uses the stable internal idempotency key and exact prepared amount/payment, validates provider response identity/status, and leaves ambiguous network outcomes in an unknown/retryable state without marking the refund failed or releasing payout hold.
- Recounted current Node source tests: webhook inbox **15**, refund executor **4**, refund recovery **11**. These are test declarations only; no Node test suite was run.
- No additional source-level defect confirmed in this pass. Remaining evidence boundary: Node execution, SQL compilation/migration replay, PostgreSQL/pgTAP, real webhook/provider behavior, lease-expiry concurrency, and deployed ACL/catalog are unverified.
- No source code or migration changed. No database query/SQL execution, Node suite, CI, provider API, deployment, merge, cherry-pick, or production setting changed. GPT-2 official checklist remains **27/39 = 69%**; runtime acceptance remains **60/60 Pending**.


## चार GPT-2B Workstream की अलग Source-Implementation Checklist — 17 November 2026

यह checklist **Source readiness** मापती है, Runtime pass या Production readiness नहीं। हर Workstream में 8 समान-भार वाले milestones हैं। किसी milestone को तभी पूरा गिना गया है जब उसके source/contract का निरीक्षण और उपलब्ध implementation evidence मिला। जहाँ canonical schema/ACL evidence या runtime proof बाकी है, उसे पूरा नहीं गिना गया।

### A — Payment / Webhook / Refund / Recovery: 7/8 = 87.5%

| # | Source milestone | स्थिति |
|---|---|---|
| A1 | Raw-body signature validation, DB access से पहले | पूरा |
| A2 | Durable event inbox, duplicate और payload-collision guard | पूरा |
| A3 | Lease expiry / claim-token stale-worker fencing | पूरा |
| A4 | Payment/refund event identity, amount और terminal-state reconciliation guards | पूरा |
| A5 | Main Admin refund executor, stable idempotency और ambiguous-timeout handling | पूरा |
| A6 | Recovery exact note/receipt matching, pagination और ambiguity fail-closed | पूरा |
| A7 | Provider refund ID ↔ internal refund record one-to-one mapping guard | पूरा |
| A8 | Razorpay sandbox, actual webhook retry और concurrent lease/finalization runtime proof | बाकी |

### B — Payout / Accounting: 6/8 = 75%

| # | Source milestone | स्थिति |
|---|---|---|
| B1 | Payout creation trigger, pending-only upsert और paid-row preservation | पूरा |
| B2 | New booking पर fixed 15% commission तथा historical snapshot immutability | पूरा |
| B3 | Labour-only commission, materials exclusion और integer-paise accounting rules | पूरा |
| B4 | Refund pending/processed/failed और paid-payout lifecycle guards | पूरा |
| B5 | Main Admin payout settlement authorization, booking-first locks और ledger parity | पूरा |
| B6 | Manual-payment evidence तथा read-only booking accounting reconciliation checks | पूरा |
| B7 | Canonical payout table DDL, owner, RLS और direct ACL का authoritative evidence | बाकी — schema/ACL blocker |
| B8 | PostgreSQL/pgTAP execution, concurrent settlement/refund race और rounding-boundary runtime proof | बाकी |

### C — Customer Support / Complaints / Attachments: 6/8 = 75%

| # | Source milestone | स्थिति |
|---|---|---|
| C1 | Customer-owned complaint access और safe projection | पूरा |
| C2 | Complaint thread read/reply/status source guards | पूरा |
| C3 | Customer-owned Storage path और complaint/message attachment linking checks | पूरा |
| C4 | Linked attachment generic-delete रोकना और link/delete को row-lock से serialize करना | पूरा — source guard |
| C5 | वर्तमान assigned Staff के लिए attachment read और bounded metadata RPC | पूरा |
| C6 | Support bucket बनाम avatar policy interaction का migration-source review | पूरा |
| C7 | Canonical legacy Admin helper/table और live Storage policy catalog की authoritative पुष्टि | बाकी — schema/catalog blocker |
| C8 | PostgreSQL/pgTAP, वास्तविक Storage download/delete और concurrent link/delete runtime proof | बाकी |

### D — Electrician Support / Staff / RBAC: 6/8 = 75%

| # | Source milestone | स्थिति |
|---|---|---|
| D1 | Electrician-owned ticket access और दूसरे Electrician के ticket isolation | पूरा |
| D2 | Support Staff role permissions और financial/admin permission isolation | पूरा |
| D3 | Assigned-ticket-only list/read/reply/status और reassignment checks | पूरा |
| D4 | Case/assignment row-lock order, closed-ticket guards और Staff session/suspension checks | पूरा |
| D5 | Assigned Staff attachment access boundary और metadata RPC source guards | पूरा |
| D6 | SQL contract assertions तथा Main Admin बनाम Staff RPC privilege boundary source review | पूरा |
| D7 | Canonical legacy Admin helper/table baseline और live ACL/RLS catalog confirmation | बाकी — schema/catalog blocker |
| D8 | PostgreSQL/pgTAP, real Auth session, assignment race और Storage actor runtime proof | बाकी |

### वर्तमान गणना

| Workstream | पूरे milestones | कुल | Source readiness |
|---|---:|---:|---:|
| A — Payment/Webhook/Refund | 7 | 8 | **87.5%** |
| B — Payout/Accounting | 6 | 8 | **75%** |
| C — Customer Support | 6 | 8 | **75%** |
| D — Electrician Support/Staff | 6 | 8 | **75%** |
| **चारों का समान-भार औसत** | **25** | **32** | **78.125% ≈ 78%** |

**महत्वपूर्ण सीमा:** यह 8×4 source milestone checklist पर आधारित नया, स्पष्ट denominator है; इसे पुरानी 50% गणना के साथ सीधी तुलना तभी समझें जब पुरानी गणना का denominator भी यही था। यह आधिकारिक GPT-2 delivery checklist को नहीं बदलता: वह **27/39 = 69%** ही है। Runtime Acceptance Matrix अब भी **60/60 Pending** है; कोई PostgreSQL/pgTAP/provider/Storage runtime pass दर्ज नहीं हुआ। GPT-1 के Electrician App में commission visibility वाला handoff भी अलग से खुला है और इस GPT-2B गणना में शामिल नहीं है।


### Payout और Accounting lifecycle cross-check — 17 November 2026 (source-only)

- सक्रिय audit branch HEAD इस समीक्षा के समय `8d49054d92b7182f2084980771112c1db14233f3` था। समीक्षा में payout creation/settlement migration, commission/manual-payment consistency migration, online settlement retry migration, read-only accounting reconciliation RPC और उनके pgTAP contracts फिर से cross-check किए।
- New-category payout immutable labour bill और उसी assigned electrician से बनता है; captured amount को labour + reserved/settled cancellation-fee items से मिलाया जाता है। Cancellation fees payout gross/payable में शामिल नहीं होतीं। Existing payout upsert केवल `pending` row पर लागू होता है; paid/blocked rows को overwrite नहीं करता।
- BEFORE commission trigger manual-payment evidence के amount और normalized payment method दोनों को मिलाता है, फिर labour-only commission लिखता है। AFTER payout trigger पहले payout ledger लिखता है और बाद का parity trigger missing payout या booking commission बनाम payout commission mismatch पर पूरी transaction रोकता है। Alphabetical trigger order source में स्पष्ट है।
- Main Admin payout settlement booking row पहले और payout row बाद में lock करता है; केवल pending payout स्वीकारता है; completed/verified payment, immutable labour bill, electrician assignment, settled fee total, commission और payable ledger parity पुनः जाँचता है। Reserved fee बची होने पर settlement रोकता है।
- Online payment settlement का retry original Razorpay order और durable `amount_paid` snapshot से validate होता है; पहले से settled fee rows को दोबारा reserved मानकर गलत retry failure नहीं करता। अलग payment ID या बदली हुई amount reject होती है।
- Accounting RPC read-only और Main Admin-gated है। Manual payment evidence में amount तथा normalized payment-method match, immutable labour, payout ledger, cancellation-fee ledger net, refund evidence और refund के बाद payout closure को exceptions में reconcile करता है। यह source inspection है, live accounting data verification नहीं।
- इस pass में नया source-level defect प्रमाणित नहीं हुआ। खुला blocker वही है: `srk_electrician_payouts` का canonical table owner/schema, RLS enabled/forced state, direct authenticated/anon ACL और सभी live policies का authoritative catalog evidence उपलब्ध नहीं है। Legacy `is_srk_admin()` helper की migration-chain provenance भी अलग documented blocker है।
- `electrician_payout_reconciliation.test.sql` का declared plan 52 और `admin_labour_bill_payment_accounting_bridge.test.sql` का plan 23 है; ये source assertions हैं, executed results नहीं। SQL compile, migration replay, PostgreSQL/pgTAP, concurrent refund-vs-settlement race, live ACL/catalog और provider runtime अभी unverified हैं।
- कोई database query/SQL execution, Node suite, pgTAP, CI, provider API, deployment, merge, cherry-pick या Production setting execute/change नहीं की गई। GPT-2 official checklist **27/39 = 69%** ही है; Runtime Acceptance **60/60 Pending** ही है।


### Support Staff Assigned / Unassigned / Reassigned access cross-check — 17 November 2026 (source-only)

- Customer Complaint और Electrician Ticket दोनों के लिए Staff inbox RPC केवल `srk_admin_support_assignments` में मौजूदा `assigned_staff_user_id=auth.uid()` वाली case rows लौटाते हैं; unassigned case assignment join में नहीं आता, और दूसरे Staff की assigned case inbox में नहीं आती। दोनों inbox bounded (100) हैं और case + assignment rows पर `FOR SHARE` लेते हैं।
- Thread-read RPC पहले case row और फिर उसी Staff की current assignment row `FOR SHARE` lock करते हैं। इसलिए reassignment पहले commit हो तो पुराने Staff को `SUPPORT_CASE_NOT_ASSIGNED_TO_YOU` मिलता है; thread-read पहले lock ले तो reassignment उस transaction के समाप्त होने तक serialize होती है।
- Reply और status-update RPC पहले case row `FOR UPDATE`, फिर current assignment row `FOR UPDATE` lock करते हैं। Reply के लिए read + reply permission, status change के लिए read + update_status permission आवश्यक हैं। Closed cases पर reply/status update रोकते हैं; Staff closed complaint/ticket को reopen नहीं कर सकता। Messages में sender identity सुरक्षित होती है और Staff activity audit event लिखा जाता है।
- Main Admin assignment/reassignment RPC अलग से `public.is_srk_admin()` जाँचता है, active Support-role Staff row को `FOR SHARE` lock करता है, फिर case `FOR UPDATE` और assignment row `FOR UPDATE` लेता है। Unassigned case पर पहली assignment insert और existing assignment पर owner बदलना एक ही unique(case_type,case_id) row के upsert से होता है। Closed या invalid case तथा inactive/non-Support Staff reject होते हैं; reason और previous/new Staff IDs audit event में दर्ज होते हैं।
- Permission helper active Staff registry, exact live Auth session, non-revoked tracked Staff session और role permission जाँचता है; registry/session locks suspension या explicit session revocation के साथ serialize होते हैं। Assignment map पर browser roles को direct SELECT/INSERT/UPDATE access नहीं दिया गया।
- Attachment access भी current assignment दोबारा जाँचता है; signed URL के बजाय authenticated Storage download इस्तेमाल होता है ताकि reassignment के बाद अगली download request RLS से पुनः जाँची जाए। पहले से डाउनलोड की गई फ़ाइल को वापस नहीं लिया जा सकता—यह documented सीमा है।
- Source contract test `admin_staff_rbac_foundation.test.sql` में `plan(70)` और 70 assertion calls की पुनः गिनती की गई। यह test source में है, execute नहीं हुआ। संबंधित attachment Staff-access test का plan 11 है; Node contract test और Storage/SQL runtime भी नहीं चलाए गए।
- इस source pass में Assigned/Unassigned/Reassigned paths पर कोई नया source-level defect प्रमाणित नहीं हुआ। वास्तविक concurrent reassignment race, live RLS/ACL catalog, SQL compile/migration replay, pgTAP, Storage API और Staff sessions का runtime व्यवहार अभी unverified है।
- कोई DB query/SQL execution, Node suite, pgTAP, CI, deployment, merge, cherry-pick या Production setting execute/change नहीं की गई। GPT-2 official checklist **27/39 = 69%** और Runtime Acceptance **60/60 Pending** अपरिवर्तित हैं।


### Razorpay Refund state machine and payout rollback cross-check — 17 November 2026 (source-only)

- Latest full-amount reconciliation RPC को refund preparation, booking payment transition और payout settlement के साथ फिर से cross-check किया। RPC केवल service_role स्वीकारता है; booking row पहले और refund row बाद में `FOR UPDATE` lock होती है; processed result के लिए provider refund ID तथा internal refund amount का locked booking के captured full amount से exact integer-paise match आवश्यक है।
- Provider status mapping: `pending -> processing`, `processed -> processed`, `failed -> failed`; `processed` और `failed` refund-record states terminal हैं, इसलिए देर से आने वाला उल्टा event final state को regress नहीं करता। पहले से bound provider refund ID बदला नहीं जा सकता।
- Preparation में केवल verified paid booking और पूरा captured amount स्वीकार होता है। Pending refund के दौरान केवल pending electrician payout को `Razorpay refund pending` note के साथ block किया जाता है; पहले से paid payout को बदलने के बजाय recovery-required error मिलता है।
- Provider refund `failed` होने पर केवल वही payout row वापस `pending` होती है जिसका hold-note इसी refund flow का है; पुराना payout note restore होता है। अन्य Admin/manual holds untouched रहते हैं। Failed refund record पर automatic reuse बंद है; नया attempt करने से पहले reconciliation आवश्यक है।
- Provider refund `processed` होने पर booking payment status `refunded` में जाता है। Attached full-refund trigger processed full Razorpay/manual refund evidence verify करता है, settled cancellation-fee entries की compensating reversal जोड़ता है, cash collection की दशा में Electrician wallet debit reverse करता है, fee item को `reversed` और customer debt को `open` करता है। यह partial refund को fail-closed रखता है।
- Source test recount: `cancellation_fee_refund_reversal.test.sql` plan 44/44; `refund_reconcile_full_amount_guard.test.sql` 5/5; `admin_refund_review_queue.test.sql` 16/16; `customer_refund_request_contract.test.sql` 17/17; `admin_manual_refund_request_completion.test.sql` 14/14; `razorpay_webhook_event_inbox.test.sql` 17/17; `accounting_reconciliation_readonly_contract.test.sql` 74/74। ये assertion declarations हैं, executed pgTAP results नहीं।
- इस source review में नया confirmed source defect नहीं मिला। Provider की वास्तविक state transitions, delayed/out-of-order events, concurrent refund-vs-settlement, payout rollback और wallet/cancellation-fee reversal का PostgreSQL/pgTAP तथा provider runtime proof अभी बाकी है।
- कोई Database query/SQL execution, pgTAP, Node suite, CI, provider API, deployment, merge, cherry-pick या Production setting execute/change नहीं की गई। GPT-2 official checklist **27/39 = 69%**; Runtime Acceptance **60/60 Pending** अपरिवर्तित हैं।
