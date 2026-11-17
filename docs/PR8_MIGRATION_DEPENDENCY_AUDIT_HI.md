# PR #8 — Migration Replay Dependency Audit (2026-11-16)

**Audited PR head:** `41b4b1ecc84f5ba3b753c6940ccbfe3c3ffd68d7`  
**Audit type:** GitHub source inspection only. No database connection, SQL execution, migration replay, pgTAP run, deployment, payment, or Production change.

## Inventory at the audited PR head

- SQL migration files: **87**
- Database pgTAP files: **32**
- Migration filenames without the required 14-digit version prefix: **2**
  - `20261109_allow_quote_approval_booking_states.sql`
  - `20261109_electrician_inspection_quotes_and_service_only_commission.sql`
- Duplicate valid 14-digit migration versions: **0**
- `supabase/config.toml`: **absent**
- Standalone setup artifacts exist, including `COMPLETE_DATABASE_SETUP.sql`, but they are not a canonical versioned starter migration.

## Confirmed replay dependencies and blockers

### 1. Base schema is not bootstrapped by the numbered migration chain

The early migrations expect existing objects such as:

- `public.service_bookings`
- `public.electrician_applications`
- `public.electrician_profiles`
- `public.job_offers`
- `public.srk_admin_users`
- Supabase-managed `auth.users`

The consolidated setup SQL creates these base objects and enables initial RLS, but it is a standalone SQL artifact, not a numbered migration in the current chain. A clean replay therefore needs an explicitly approved baseline/bootstrap contract before numbered migrations can be considered self-contained.

### 2. Admin helper functions have distinct names and different introduction paths

- `public.srk_is_admin()` is defined in the setup SQL / legacy portal schema.
- `public.is_srk_admin()` is a separate function name, also defined in the consolidated setup SQL.
- Early migration `20261108234000_combine_booking_read_policy.sql` calls `public.is_srk_admin()`.
- `20261109001000_add_google_maps_location_support.sql` and `20261109003000_secure_commission_reporting.sql` also call `public.is_srk_admin()`.
- `20261109001500_unique_electrician_admin_identity_linking.sql` calls `public.srk_is_admin()`.

The two helpers must not be treated as aliases. Their exact approved baseline definitions, grants, and replay placement need to be established before replay.

### 3. `amount_paid` ordering — source prerequisite fixed, baseline still gated

- The base `service_bookings` definition in `COMPLETE_DATABASE_SETUP.sql` does not declare `amount_paid`.
- On this audit branch, `20261109003000_secure_commission_reporting.sql` now adds `amount_paid numeric(12,2)` with `ADD COLUMN IF NOT EXISTS` before defining the SQL-language commission/earnings functions and column grants that consume it.
- `20261116200000_restore_service_bookings_amount_paid.sql` remains as an idempotent later restoration/constraint migration.
- `20261109_electrician_inspection_quotes_and_service_only_commission.sql` defines a PL/pgSQL function that reads `NEW.amount_paid`, but does not attach it to a trigger. The early column-order concern is not established because `09003000` adds the column before its own consumers; the separate trigger-wiring defect is recorded in section 15.

This audit-branch source correction removes the identified early missing-column ordering issue in that migration. It does **not** establish that a clean replay succeeds: canonical base-table provenance, both Admin helper definitions/grants, malformed legacy filenames, duplicate-prefix history and the full trigger dependency chain remain unresolved. Do not rename/resequence migrations or infer deployed history without reconciling the authoritative migration ledger first.

### 4. Early identity / GPS / offer function chain has explicit order

Source comments and definitions establish these dependencies:

1. `20261109000500_harden_electrician_profile_identity_linking.sql` adds `electrician_profiles.auth_user_id`, synchronizes it with `user_id`, and adds a partial unique index.
2. `20261109001000_add_google_maps_location_support.sql` writes both identity columns and adds GPS columns; it must follow the identity migration.
3. `20261109001500_unique_electrician_admin_identity_linking.sql` replaces the Admin approval RPC introduced by the preceding GPS migration and switches to the `srk_is_admin()` helper.
4. `20261109002000_expose_assigned_booking_map_pin.sql` defines the initial `srk_get_my_offer_details()`.
5. The quote workflow migration drops/recreates that RPC with additional quote return columns, so the map-pin function must precede the quote workflow definition.

These are source-level dependencies; they do not prove that the deployed database has the same schema or migration history.

### 5. Migration filename and configuration gates

The two `20261109_...` filenames do not carry a 14-digit migration version. Their intended timestamps cannot safely be inferred from filename order alone. In addition, the current PR tree lacks `supabase/config.toml`. Do not rename, merge, delete, or resequence these files without reconciling the authoritative remote migration ledger and intended historical ordering.

## Recommended safe sequence

1. Obtain owner-approved baseline provenance and the authoritative remote migration-history/schema-only evidence.
2. Decide where the canonical base schema and both Admin helpers are introduced for a disposable clean install.
3. Preserve the early `amount_paid` ADD COLUMN at the start of `09003000`; resolve the separate service-only commission trigger binding with an ordered follow-up migration and focused pgTAP coverage.
4. Resolve the two malformed migration filenames against the authoritative migration ledger; do not guess timestamps.
5. Add/verify Supabase local configuration and an isolated disposable PostgreSQL/Supabase harness.
6. Only then run full migration replay and all 34 pgTAP files against the disposable target, recording actual logs and results.

## Status

**Replay is not yet verified.** This document records static dependency findings only. The 34 pgTAP files have not been executed in PostgreSQL as part of this audit. No Production SQL or migration history was changed; no merge or deployment was performed.

### 6. Payout trigger column-source order — verified from feature-branch source

The payout trigger's referenced booking columns have explicit source paths:

- `service_charge`, `materials_amount`, and `quote_status` are added by `20261109_electrician_inspection_quotes_and_service_only_commission.sql`.
- `selected_category`, `selected_duration_hours`, `selected_rate_tier`, and estimate snapshot columns are added by `20261114160000_customer_selected_rate_tier_and_server_estimate.sql`.
- The new-category payout reconciliation function is introduced in `20261114360000_new_category_electrician_payout_reconciliation.sql`.
- The subsequent payout-trigger attachment migration `20261116210000_attach_electrician_payout_reconciliation_trigger.sql` references `selected_category` and the legacy quote columns in its trigger event list.

Therefore, **within the intended feature-branch sequence**, the selected-category and quote-column source dependencies precede the payout-trigger attachment. This resolves the specific source question about where `selected_category` is introduced; it does not establish clean replay because the authoritative baseline, duplicate 20261109 version history, and complete migration-history reconciliation remain open.

Evidence boundary: GitHub source inspection only. No migration replay, PostgreSQL/pgTAP execution, Production write, or deployment was performed.

### 7. Refund-owned payout block label mismatch — unresolved high-risk finding

The payout-trigger migration closes a blocked payout only when `payout_note` is exactly `Razorpay refund pending` or `Manual refund processed`.

- Manual refund preparation in `20261115130000_admin_manual_refund_request_completion.sql` sets `Manual refund processed`, matching the new trigger.
- The durable Razorpay recovery/finalization migration `20261115120000_durable_razorpay_refund_recovery_evidence.sql` originally closed a blocked payout directly and used the note `Razorpay full refund verified; payout permanently withheld.`.
- The later trigger-attachment migration replaces that finalizer so the booking update is expected to close the payout through the trigger. However, source review of the refund migrations found the reconciliation failure path expects `Razorpay refund pending` (`20261115250000_harden_refund_reconcile_full_amount.sql`) but did not establish, in the inspected source set, the exact function that writes that label before provider reconciliation.

This creates a **potential fail-closed integration gap**: if the actual payout is blocked with a different note, the booking can be marked refunded while the trigger leaves the payout blocked; the replacement finalizer then raises `BLOCKED_PAYOUT_COULD_NOT_BE_CLOSED_AS_REFUNDED`. The transaction should roll back, but the expected successful refund completion would be unavailable until the block-label lifecycle is reconciled.

Required before runtime approval: identify and verify the exact Razorpay refund-preparation function and its blocked-note write, then make the trigger, preparation, failed-refund restoration, and finalizer use one consistent exact marker. Do not weaken the trigger to close arbitrary Admin blocks.

Evidence boundary: source inspection only; no PostgreSQL/pgTAP execution or database writes.

### 8. Correction: Razorpay refund-owned block marker is present and consistent

A deeper directory-level search located the refund-preparation function in `20261114290000_full_refund_cancellation_fee_and_wallet_reversal.sql`.

- `srk_admin_prepare_razorpay_refund(uuid,text)` changes a pending payout to `blocked` with the exact marker `Razorpay refund pending`.
- It stores the previously-read payout note in `srk_razorpay_refunds.previous_payout_note` for restoration if provider reconciliation reports failure.
- `20261115250000_harden_refund_reconcile_full_amount.sql` restores the prior note only when the payout is still blocked with that exact Razorpay marker.
- The payout-trigger migration recognizes the same exact marker and closes it to `refunded` on the booking's verified refunded transition.
- Manual refund uses the separate exact marker `Manual refund processed`, which is also recognized by the trigger.

Therefore the specific block-marker mismatch risk raised in §7 is **not supported by the full source chain** and is withdrawn. The exact Razorpay marker is consistent across preparation, failure restoration, and successful refund-trigger closure. The trigger's narrow allow-list should remain; do not broaden it to arbitrary Admin blocks.

Remaining caveat: this is static source-chain verification. Runtime transaction behavior, trigger ordering with the cancellation-fee reversal trigger, and all refund/payout pgTAP cases remain unexecuted.

### 9. Razorpay refund execution and recovery call-chain located — 16 Nov 2026

The earlier project-progress note that the trusted provider executor/caller was missing or unlocated is superseded by this full-tree inspection. The implementation exists in root modules with thin Netlify wrappers:

- `netlify/functions/razorpay-refund.js` -> `razorpay-refund.js`
- `netlify/functions/razorpay-refund-status.js` -> `razorpay-refund-status.js`
- `netlify/functions/razorpay-refund-recovery.js` -> `razorpay-refund-recovery.js`
- `netlify/functions/razorpay-webhook.js` -> `razorpay-webhook.js`

**Normal refund execution path (source-confirmed):**
1. POST endpoint requires a Bearer token; validates it through Supabase Auth `/auth/v1/user`.
2. Checks Main Admin membership using `is_srk_admin` with the user's token.
3. Calls `srk_admin_prepare_razorpay_refund` with the same user token; SQL independently checks `auth.uid()` and `is_srk_admin()`.
4. Prepared record is validated, then Razorpay refund is requested for the exact stored payment ID and paise amount, with stable receipt/idempotency key and internal refund-record note.
5. Provider response is checked against refund ID format, payment ID, exact amount, INR currency, and allowed status.
6. The service-role reconciliation RPC is called. If response/reconciliation is ambiguous, the handler leaves the payout hold in place and directs recovery through the signed webhook or Admin reconciliation; it does not create a second internal refund record.

**Webhook path (source-confirmed):**
- Verifies HMAC-SHA256 against the raw request body and compares signatures with `timingSafeEqual`.
- Claims a provider event through the service-role inbox RPC; event ID and payload hash provide replay/deduplication controls.
- For refunds, checks provider ID/payment ID/amount/currency/status and binds to the exact internal refund using the stored provider refund ID, or before that ID is stored, the internal record ID note / stable receipt.
- Calls `srk_service_reconcile_booking_refund`; failed reconciliation is surfaced as retryable webhook processing rather than silently marked complete.

**Recovery/status paths (source-confirmed):**
- Read-only status endpoint validates Main Admin and matches the provider refund to the internal record; it explicitly performs no database or payout mutation.
- Recovery endpoint validates Main Admin, finds exactly one internal record, verifies the provider refund by stored ID or complete bounded pagination, and stores immutable provider evidence via service-role RPC. Only a fresh `processed` provider observation is eligible for a separate finalization transaction.
- Evidence RPC checks service_role, Admin actor registry membership, evidence fields against supplied facts, and internal booking/payment/refund identity. Finalizer checks fresh evidence, full amount, identity, booking/refund/payout states, then uses the booking update trigger to close the exact Razorpay-owned payout hold.

**Source-level security observations:**
- Main Admin is checked at the HTTP boundary; normal preparation also repeats the check in SQL.
- Privileged reconciliation/evidence/finalization RPCs revoke execution from public/anon/authenticated and grant service_role only.
- SQL functions inspected use SECURITY DEFINER with pinned search_path.
- No live provider request, secret access, database call, or runtime test was made.

**Runtime caveats still open:** verify deployed Netlify wrappers/environment configuration; exercise signature failures, webhook retries/duplicates/out-of-order events, provider timeout after acceptance, same-key retry, and concurrent refund/payout settlement in an isolated database. Source review alone does not prove deployed configuration or transaction behavior.

### 10. Confirmed malformed SQL fragment removed on GPT-2 audit branch — 16 Nov 2026

- Exact comparison of `20261114290000_full_refund_cancellation_fee_and_wallet_reversal.sql` on the Feature Branch and GPT-2 audit branch found an orphaned duplicate fragment immediately after the first `srk_service_reconcile_booking_refund` definition and its grants. It began with a bare `then` at former line 533, without a function declaration, `DECLARE`, or opening conditional/function body. This is invalid top-level SQL and would stop migration execution if reached.
- The fragment was a partial duplicate of `srk_admin_prepare_razorpay_refund`; the complete definition earlier in the same migration (lines 192–331 before the correction) remains intact. Later complete definitions for manual refund, cancellation-fee summary, and reconciliation also remain intact.
- Removed only the orphaned fragment and its duplicate prepare-function grants from the GPT-2 audit branch. No change was made to the PR/Feature Branch, Production, or any database.
- Commit: `835d4fc538e20756dddf884184abc7d585d28633`.
- Post-edit source re-fetch verified: no standalone `then` line remains; the expected complete function declarations remain; the prepare-function execute grant appears once. This is a static structural check, **not** PostgreSQL parsing or migration execution.
- Required next verification: compare full migration diff to ensure only the orphaned block was removed, then run the migration in the approved disposable local PostgreSQL/Supabase environment after the existing baseline and duplicate-version gates are resolved.

### 11. Refund test inventory and execution status — 16 Nov 2026

Static inventory of the current audit branch found:
- Node.js provider/API tests: 4 refund executor + 9 recovery + 7 status + 13 webhook = **33 test cases** across four files.
- Database pgTAP suites: cancellation-fee reversal 44 + durable recovery evidence 35 + payout reconciliation 28 + manual refund 14 + full-amount reconciliation guard 5 = **126 planned assertions** across five SQL test files.
- Package scripts expose `npm run test:refund`, `npm run test:webhook`, and `npm test`.

**Execution result:** none of these 33 Node tests or 126 pgTAP assertions was run in this audit session. GitHub reports no Actions workflow runs for the audit fix commit; its Vercel status check is failed with a build-rate-limit/upgrade URL. A local `git clone` attempt could not resolve `github.com` from the available runtime. Do not treat test inventory, static source checks, or test source assertions as passed tests.

**Next gate:** run the four Node suites in a Node-enabled checkout, then run pgTAP against an isolated database after baseline/migration-history reconciliation. Do not dispatch the existing Production-connected workflow or create a paid Supabase branch without explicit approval.

### 12. pgTAP transaction-boundary defect corrected — 16 Nov 2026

A further static review found a real test-harness defect in `supabase/tests/database/cancellation_fee_refund_reversal.test.sql`: the file declared `plan(44)`, ran 36 assertions, called `finish()` and `rollback`, then attempted the remaining 8 assertions and a second `finish()` outside the original test transaction. This split could cause a premature plan mismatch and leave the last assertions outside the intended pgTAP transaction.

**Correction on GPT-2 audit branch only:** removed the premature first `finish()/rollback` pair. The file now contains all 44 `ok()` assertions in one transaction, followed by exactly one `finish()` and one `rollback`. Post-edit source check confirms: plan=44, assertion count=44, finish count=1, rollback count=1.

This is a static source-structure correction only. The pgTAP file has **not** been executed against PostgreSQL. PR #8 feature branch, Production and database remain unchanged.

### 13. Full database-test file structure inventory — 16 Nov 2026

Reviewed the complete current `supabase/tests/database/` tree: **34 SQL test files**. Their declared pgTAP plans total **708 assertions**. The scan checked each file's plan declaration and transaction terminators, and accounted for pgTAP schema-inspection assertions such as `has_function`, `has_table`, `has_column`, `has_trigger`, and `has_index` in addition to `ok()`.

The earlier cancellation-fee test issue was the only concrete misplaced `finish()/rollback` boundary identified and has been corrected on this audit branch. The apparent extra `rollback;` text in `customer_refund_admin_approval_gate.test.sql` is inside a multiline SQL string used to inspect a payment-ID regex, not a second SQL rollback statement.

**Important:** this is a source-structure inventory, not execution. None of the 34 SQL files / 708 planned assertions has been run against PostgreSQL in this session. Some test files depend on objects from the full migration baseline; their execution must wait for safe baseline reconstruction and an isolated database.

### 14. pgTAP plan-count checker cross-review

Inspected `tests/database-pgtap-plan-counts.test.js` against all 34 SQL files. Its assertion regex covers the assertion functions actually used in this tree: `ok`, `has_table`, `has_column`, `has_function`, `has_trigger`, and `has_index` (and also supports `is`, `isnt`, `hasnt_table`, `hasnt_column`). No other `SELECT <function>(...)` assertion API was found in the 34 files. The per-file declared plans reconcile to **708** total assertions.

The checker is therefore structurally aligned with the assertion APIs currently present in these files. It was inspected as source, not executed with Node.js in this session; this does not change the PostgreSQL/pgTAP execution limitation above.

### 15. Quote/commission trigger wiring gap found — 16 Nov 2026

A fresh cross-check of the quote/commission migration against both checked-in starter setup files found a concrete source-level wiring gap:

- `PORTAL_SCHEMA.sql` and `COMPLETE_DATABASE_SETUP.sql` install trigger `srk_booking_commission_trigger` on `public.service_bookings`.
- That trigger is `BEFORE UPDATE OF status` and calls `public.srk_calculate_commission_on_completion()`.
- The old function calculates commission from `NEW.quoted_amount * commission_rate`; the quote total includes service and materials.
- `20261109_electrician_inspection_quotes_and_service_only_commission.sql` defines a different function, `public.srk_calculate_booking_commission()`, which calculates from `service_charge` only and gates on completed + paid + `amount_paid` + service_charge.
- **But the quote migration does not create or replace any trigger to call the new function, and does not drop the old trigger.** The only references to the new function in the migration are its definition; no trigger attachment is present. The checked-in setup trigger therefore remains bound to the old function on a baseline that includes either setup file.

**Impact:** on that baseline, the advertised service-only commission function is not wired into the booking trigger; the existing trigger continues to calculate from `quoted_amount`, potentially including materials. This is a source-level finding, not a live database observation.

**Safe next action:** add an explicitly ordered follow-up migration that runs only after the quote function and `amount_paid` column exist, replaces the old trigger binding, and tests the trigger event coverage for status/payment/amount/service-charge/rate changes. Do not patch an already-applied migration in place until the authoritative remote migration lineage is resolved. No migration, setup file, Production database, or PR branch was changed for this finding.

**Additional cross-check of the impact and test coverage:**
- `20261109003000_secure_commission_reporting.sql` builds the Admin commission report by summing `service_bookings.commission_amount`.
- `20261114360000_new_category_electrician_payout_reconciliation.sql` independently computes the payout ledger's platform commission from `service_charge` (and keeps materials separate).
- `electrician_payout_reconciliation.test.sql` checks that payout-ledger formula and trigger wiring, but does not assert that `srk_booking_commission_trigger` is bound to `srk_calculate_booking_commission()`.
- Therefore the payout ledger can use labour-only commission while the Admin commission report's `commission_amount` can still be populated by the older quoted-total trigger. This is a potential reporting-versus-payout reconciliation mismatch for the setup baseline described above.

No runtime data was read; the mismatch is inferred from the checked-in function definitions and trigger bindings. A focused pgTAP assertion should verify the commission trigger's `tgfoid`, event columns, and service-only calculation, in addition to the existing payout-ledger assertions.

### 16. `amount_paid` replay blocker rechecked and withdrawn — 16 Nov 2026

A full-file re-read of `20261109003000_secure_commission_reporting.sql` confirms that its **first DDL statement adds `service_bookings.amount_paid`** using `ADD COLUMN IF NOT EXISTS`. It does so before the same migration's report/earnings RPC definitions and column-level UPDATE grant. The prior claim that this migration grants a missing column was therefore incorrect and is withdrawn.

`20261116200000_restore_service_bookings_amount_paid.sql` is a later idempotent restoration/constraint migration, not the first visible source introduction. The quote migration's PL/pgSQL function references `NEW.amount_paid`, but that function is not attached to a trigger in the quote migration; this alone does not prove an immediate replay failure.

The separate and actionable defect is the trigger-wiring gap in section 15: the old setup trigger remains bound to the old quoted-total commission function, while the new service-only commission function is unattached. The Admin report reads `commission_amount`; the payout ledger independently computes service-charge-only commission, creating a possible reporting-versus-payout mismatch.

Related GPT-2 dependency notes were corrected on the audit branch, including the former `GPT2_AMOUNT_PAID_ORDERING_BLOCKER` note (now explicitly withdrawn), quote dependency map, dependency-order note, base/RLS matrix, and runtime-test preparation record. No numbered migration or PR branch was changed. No database replay/test was performed.

**Trigger event-coverage gap also matters:** the starter trigger is `BEFORE UPDATE OF status` only. The new service-only function's result depends on `status`, `payment_status`, `amount_paid`, `service_charge`, and `commission_rate`. If the booking reaches `completed` before the payment verification update, a status-only trigger will not recalculate `commission_amount` when `payment_status`/`amount_paid` later changes. Conversely, if it reaches paid first and completion later, the status event may calculate it, but still with the old quoted-total function currently bound. The existing payout trigger is an `AFTER INSERT/UPDATE` trigger and separately computes the payout ledger from service charge; its pgTAP suite does not assert the Admin commission trigger binding or event columns. A safe follow-up should attach the new function to an explicitly defined `BEFORE INSERT OR UPDATE OF status, payment_status, amount_paid, service_charge, commission_rate` row trigger (subject to PostgreSQL syntax/trigger design review), and add pgTAP assertions for `tgfoid`, `tgtype`, and report-versus-ledger formula agreement. No such migration has been authored or executed in this audit pass.

### 17. New-category commission is not synchronized to the booking report field — 16 Nov 2026

A separate, stronger accounting mismatch was found while tracing the live server-timed/new-category path:

- `20261116210000_attach_electrician_payout_reconciliation_trigger.sql` installs `srk_create_electrician_payable()` for `AFTER INSERT OR UPDATE` on payment, completion, amount, assignment, labour/quote and category fields. For new-category bookings (`selected_category IS NOT NULL`), it reads the immutable `srk_booking_labour_bills.labour_amount`, validates `amount_paid` against labour plus settled cancellation-fee ledger entries, calculates `v_commission := round(v_service * v_rate / 100, 2)`, and writes that value to `srk_electrician_payouts.platform_commission`.
- That trigger function does **not** update `service_bookings.commission_amount`.
- `20261109003000_secure_commission_reporting.sql` builds `srk_admin_commission_report()` by summing `service_bookings.commission_amount` for all completed/paid bookings. Its `srk_get_my_earnings()` returns the same column and calculates electrician earning as `amount_paid - commission_amount`.
- The `electrician.html` UI displays these RPC values as Company Commission and electrician earnings. The payout table is fetched separately and does not replace those report figures.

**Impact:** for a new-category booking whose `commission_amount` remains NULL (the payout trigger does not populate it), the Admin aggregate commission can report zero for that booking and the electrician earnings RPC can treat the full `amount_paid` as electrician earning. Because the new-category payment check explicitly allows settled cancellation fees in `amount_paid`, that displayed earning can also include amounts belonging to SRK's cancellation-fee ledger. This can diverge from the actual payout ledger, which calculates commission from immutable labour and sets materials to zero for new-category bookings.

**Evidence boundary:** the missing assignment is confirmed by source inspection of the complete payout-trigger function and the commission-report RPC. The resulting live values are conditional on the booking's `commission_amount` not being populated by some other path; repository search found no new-category assignment to that column. No production rows or runtime behavior were inspected.

**Required safe correction:** make the single authoritative settlement path synchronize `service_bookings.commission_amount` from the same immutable labour-bill calculation (without counting settled cancellation fees as electrician earnings), or change both reporting RPCs to derive the amount from the reconciled payout/immutable bill contract. Add pgTAP assertions that compare Admin report, electrician earnings, and payout ledger for a new-category booking containing a settled cancellation fee. Do not patch an already-applied migration in place; deliver this as a correctly ordered follow-up migration after baseline/lineage reconciliation. No migration was changed for this finding.

### 18. Scope clarification for the legacy quote-trigger finding

The quote/commission migration is a historical workflow: `20261115220000_retire_live_legacy_quotation_rpcs.sql` later revokes and drops `srk_submit_booking_quote`, `srk_customer_respond_booking_quote`, and `srk_update_booking_work_status`. The older setup trigger binding remains present in the starter SQL files, and the quote migration's service-only trigger function is not attached there; however, the legacy quote RPC path is explicitly retired by the later migration. Accordingly, do not treat the legacy quote-trigger mismatch alone as proof that the current live new-category booking flow is broken.

The current live-path accounting finding is section 17: the new-category payout trigger calculates commission from the immutable labour bill and writes the payout ledger, but does not synchronize `service_bookings.commission_amount`, while the current Admin/partner commission reporting RPCs still read that booking column. That is the primary active reporting mismatch to resolve. The legacy quote trigger remains a baseline/setup cleanup item, not the main live-path defect.

**More precise reconciliation impact after reading both reporting RPC bodies:** the discrepancy is not limited to a possibly NULL commission field. For new-category bookings the payout trigger explicitly accepts `amount_paid = immutable labour + settled cancellation fees`, but writes payout `electrician_payable = labour - commission` (materials are zero). In contrast, `srk_admin_commission_report()` sums `amount_paid - commission_amount` as `total_electrician_payable` and per-partner `electrician_earning`; `srk_get_my_earnings()` uses the same `amount_paid - commission_amount` formula. Neither reporting RPC subtracts settled cancellation fees from the gross before calculating electrician earnings. Therefore, even if `commission_amount` were synchronized correctly, a booking with settled cancellation fees would still overstate electrician earnings / Admin-reported electrician payable by the settled fee total compared with the payout ledger. If `commission_amount` remains NULL, the report also understates company commission by that booking's actual labour-based commission. This is a deterministic formula mismatch for that input shape, based on source code; no live booking was inspected.

**Test coverage gap:** `admin_labour_bill_payment_accounting_bridge.test.sql` asserts that the new-category accounting bridge uses immutable labour and settled fees and that materials are zero; `electrician_payout_reconciliation.test.sql` asserts the payout formula. Neither suite asserts that `srk_admin_commission_report()` and `srk_get_my_earnings()` exclude cancellation-fee amounts from electrician earnings or reconcile to `srk_electrician_payouts.electrician_payable`. Add a regression fixture with a labour bill plus a settled cancellation fee and compare all three outputs.


### 19. Customer payment-history pgTAP transaction boundary corrected

Static review found a second test-harness boundary defect in `supabase/tests/database/customer_payment_refund_history_rpc.test.sql`:

- The file declared `plan(11)` and contained 11 assertions, but its final `search_path=""` assertion appeared **after** `finish()` and `rollback`.
- That last assertion therefore ran outside the intended pgTAP transaction and after the plan had already been finalized. The plan count itself was correct; the assertion placement was not.
- GPT-2 moved that assertion before `finish()`, leaving all 11 assertions inside the same transaction and retaining exactly one `finish()` followed by one `rollback`.
- Audit-branch-only commit: `c7445f39f2b798df7f632118f0a99cdcc92ae69e`.
- Post-edit static check: plan 11; 11 assertion calls; one finish; one rollback, in the intended order.

This is a test-file source correction only. The suite has **not** been executed against PostgreSQL/pgTAP, so no runtime pass is claimed. No PR-head, Production database, migration, or shared integration branch was changed.


### 20. `commission_amount` writer search — no active new-category writer located

A repository-wide source search for assignments to `commission_amount` found the following relevant writers:

- Starter SQL `PORTAL_SCHEMA.sql` and `COMPLETE_DATABASE_SETUP.sql` contain the legacy `srk_calculate_commission_on_completion()`, which calculates from `quoted_amount` when status first changes to completed. This is the legacy trigger path and is not the active new-category immutable-labour settlement calculation.
- `20261109_electrician_inspection_quotes_and_service_only_commission.sql` defines a different `srk_calculate_booking_commission()` body that writes from `service_charge` only. The migration does not attach the required trigger to `service_bookings`; its legacy quote RPC path is later retired by `20261115220000_retire_live_legacy_quotation_rpcs.sql`.
- `20261116210000_attach_electrician_payout_reconciliation_trigger.sql` calculates and stores the payout ledger commission, but does not assign `service_bookings.commission_amount`.
- The secure commission reporting migration reads `commission_amount`; the electrician page displays those RPC commission/earning figures alongside a separately queried payout history.

Accordingly, the source search strengthens section 17's evidence boundary: no active new-category writer for `service_bookings.commission_amount` was located in the searched repository. This is not proof about untracked code, deployed database objects, or Production data. The separate settled-cancellation-fee subtraction mismatch remains even if a commission writer is later found.

No application or migration code was changed for this finding. This is a source-search result only; no PostgreSQL test or Production query was run.


### 21. Admin payout dashboard totals are limited to the latest 300 rows

Source review of `admin.html` found that `loadPayouts()` queries `srk_electrician_payouts` ordered by `created_at DESC` with `.limit(300)`. It then calculates both the displayed pending and paid totals by summing only that returned `rows` array. The visible payout table is also built from the same limited array.

**Impact:** once the payout table contains more than 300 records, older payout records are excluded from both displayed totals and the visible list. The UI labels these values as pending/paid amounts without indicating that they cover only the latest 300 rows. The dashboard can therefore understate historical or outstanding totals; the exact difference depends on records beyond the first 300. No Production row count was queried, so whether the threshold has been crossed is unknown.

**Safe correction:** calculate authoritative pending/paid aggregates with a server-side Admin-only summary RPC (or explicitly page through all rows for the list while keeping aggregate totals independent of pagination). The UI should label any deliberately limited recent-history view as such. Add a regression test proving summary totals include records beyond the first 300 and that pagination does not alter totals.

The payout action itself calls `srk_admin_mark_electrician_payout_paid` only after a UTR/reference is entered and the Admin confirms an actual transfer; the page text explicitly says to confirm only after the transfer. This is a ledger-status recording step, not an automatic bank/UPI transfer. No bank transfer or payment was initiated during this audit.

This is a source/UI finding only. No Admin page or migration was changed, and no Production data was queried.


### 22. Electrician earnings and payout summaries also use fixed recent-row limits

Further source review found two related UI/reporting limits:

1. **Earnings RPC:** `srk_get_my_earnings()` returns only the latest 200 bookings for the authenticated, approved electrician (`LIMIT 200`). In `electrician.html`, `loadEarnings()` sums completed jobs, received amount, commission, and electrician earnings from that returned array. There is no page/cursor argument or separate all-history aggregate in this RPC/UI path. Once an electrician has more than 200 assigned bookings, the displayed earnings totals and completed/pending/refunded counts cover only the latest 200 rows.
2. **Payout status summary:** the same page separately queries `srk_electrician_payouts` for the electrician's profile with `LIMIT 100`, then calculates pending, paid, and blocked payout totals from those rows. Older payout records are not included in those displayed totals. The page does not label the totals as limited to the latest 100 records.

**Impact:** Admin payout dashboard totals (latest 300), electrician earnings totals (latest 200), and electrician payout-status totals (latest 100) are all bounded recent-history summaries, not guaranteed lifetime totals. The precise undercount, if any, depends on whether the relevant account exceeds each threshold; no live row counts were queried.

**Safe correction:** move summary totals into authenticated, owner-scoped / Admin-scoped aggregate RPCs that sum the full relevant dataset; paginate only the detail lists. Add tests with more than 100/200/300 records proving summary totals remain complete and user-scoped.

This is source/UI analysis only. No live account data was read, no database was queried, and no code or migration was changed for this finding.


### 23. Wallet access and withdrawal guardrails cross-checked — no bypass found in reviewed path

Reviewed the wallet foundation migration, wallet summary RPC, electrician UI, Admin wallet overview, and `wallet_access_security_contract.test.sql`:

- Wallet accounts, ledger, and bank-link tables have RLS enabled with owner-scoped SELECT policies using `auth.uid()`.
- Authenticated browser roles have SELECT only on these tables; direct INSERT/UPDATE/DELETE is revoked. Service role retains ledger mutation privileges.
- `srk_get_my_wallet_summary()` requires a non-null authenticated UID, creates/reads only that UID's wallet accounts, and returns posted-ledger balance. Electrician wallet creation is gated on an approved profile.
- Later migration `20261116130000_pin_wallet_and_receipt_rpc_search_paths.sql` sets empty search_path on the wallet summary and Admin wallet overview SECURITY DEFINER functions; this resolves the earlier foundation migration's initial `public, pg_temp` search_path setting.
- The RPC explicitly returns `topups_enabled=false` and `payouts_enabled=false`. Electrician UI describes the balance as internal ledger only and states bank linking/withdrawal are disabled until provider onboarding/approval. No withdrawal/transfer RPC is invoked from this UI path.
- Bank-link SELECT is owner-filtered; UI only requests masked account fields (bank name, last four digits, verification status, primary flag). Recent ledger UI is separately limited to 10 entries, but presents that section as recent transactions rather than lifetime totals.
- Admin wallet overview is SECURITY DEFINER and checks `auth.uid()` plus `is_srk_admin()` internally; its function execution is authenticated-callable but not anonymous.

No additional wallet access-control bypass was identified in these reviewed files. This is static source review; the 18-assertion pgTAP wallet contract has not been executed against PostgreSQL. No Production access, ledger mutation, bank transfer, or withdrawal occurred.


### 24. Admin payout settlement RPC and payout-table access reviewed

Reviewed `srk_admin_mark_electrician_payout_paid()`, payout table RLS, profile identity synchronization, payout trigger, audit trigger, and the 28-assertion `electrician_payout_reconciliation.test.sql`:

- `srk_electrician_payouts` has RLS enabled. Authenticated users have SELECT only; Main Admin can read via `is_srk_admin()`, while an electrician can read rows only when the payout's profile belongs to that authenticated user. Direct browser table mutation is revoked; service_role is the trusted mutation role.
- The payout settlement RPC independently requires authenticated Main Admin, restricts method to `upi` or `bank`, bounds reference/note lengths, locks the booking first and payout row second, and accepts only a currently pending payout.
- Before recording Paid, it rechecks completed + verified-paid booking state, electrician/profile assignment, immutable labour bill, settled cancellation-fee amount, provider/manual payment evidence, and the payout ledger's service/material/commission/payable amounts. Legacy quote bookings have a separate approved-quote reconciliation check.
- Refund and payout settlement use the same booking-first lock order. The payout trigger updates an existing row only while it remains pending and never changes an already-paid payout to refunded. This is a useful source-level race-control design; concurrency has not been exercised in a live database.
- The settlement function records method, reference, actor and timestamp; the payout table's AFTER INSERT/UPDATE/DELETE audit trigger captures payout status/reference/amount changes in the Admin audit table.
- Profile identity migration synchronizes `user_id` and `auth_user_id`, which supports the payout SELECT policy's `profile.user_id=auth.uid()` ownership check in the intended linked-profile state.

**Remaining test gap:** the existing 28 pgTAP assertions statically inspect Main Admin authorization, lock order, pending-only transition, amount/evidence reconciliation, and refund hold behavior. They do not simulate two concurrent settlement/refund transactions, prove duplicate UTR/reference handling, or verify the resulting audit-event row end-to-end. Add isolated database tests for those cases before release.

No live payout was marked paid, no bank/UPI transfer was initiated, and no Production database was queried or changed. This is static source review only; the pgTAP suite remains unexecuted.


### 25. Payout reference uniqueness is not enforced in the reviewed settlement path

The payout table definition has a plain nullable `payout_reference` text column and the Admin settlement RPC validates only nonblank length (4–120 characters). The function does not search for an existing payout with the same method/reference, and the table definition has no unique constraint/index on a normalized payout reference.

**Impact / boundary:** the same UTR/reference string can therefore be recorded on more than one payout row through this RPC. This does not prove that duplicate entries exist or that two real bank transfers were made; no live payout rows were queried. It does mean the database does not independently prevent accidental reuse or provide a uniqueness guard.

**Safe correction:** before adding a constraint, decide the provider/reference namespace and normalization rules (UPI/bank references may have different formats). Then enforce a suitable unique key, preferably scoped to payment method/provider and normalized reference, and add a pgTAP case proving a second payout cannot reuse the same reference. Handle legitimate provider-specific collisions explicitly rather than applying a blind global unique constraint.

This is static schema/function review only. No payout was modified, no payment was initiated, and no Production database was accessed.


### 26. Accounting reconciliation pgTAP suite still referenced the retired Route ledger — corrected on GPT-2 audit branch

Cross-checking the test assertions against the final Route retirement migrations found a stale test contract:

- `20261115092149_retire_unused_razorpay_route_transfer_ledger.sql` drops `public.srk_route_transfers`.
- The later Admin reconciliation migrations intentionally preserve Route response keys as zero/empty compatibility fields and explicitly state `route_ledger_retired_no_route_transfers`; they no longer query the dropped table.
- However, `accounting_reconciliation_readonly_contract.test.sql` still asserted the Route table existed and checked the old Route transfer validation, uniqueness, RLS, and service-role grants. Those assertions were incompatible with the final migration state and would fail (including `::regclass` lookups against the absent table).

**Correction:** replaced the 21 stale Route-ledger assertions with 21 checks for the intended retired-ledger contract: table absent, compatibility response keys retained, values zero/empty/false, explicit retired status, and no query or old Route settlement validation in the read-only RPC. The suite remains `plan(74)`; static recount confirms 74 assertion calls, one `finish()`, one `rollback`, and no remaining hard dependency on `srk_route_transfers`.

- Test-file commit: `ad72b30601ef401eba11e07f22997bb468576d22`
- This is a source-level correction only. pgTAP has **not** been executed against PostgreSQL; no database or Production changes were made.


### 27. Accounting reconciliation में manual payment method का मिलान अधूरा है

srk_admin_get_booking_accounting_reconciliation(uuid) में manual payment evidence जाँचते समय booking ID और amount का मिलान srk_manual_payment_entries से होता है, लेकिन payment_method का मिलान service_bookings.payment_method से नहीं किया जाता।

**प्रभाव:** यदि manual payment entry में upi और booking row में cash (या इसके उलट) दर्ज हो, तो केवल इस method mismatch के कारण reconciliation exception नहीं बनेगा। इससे रिपोर्ट भुगतान के तरीके की गलत जानकारी को पकड़ नहीं पाएगी। यह source-level संभावना है; Production डेटा नहीं देखा गया और किसी गलत रिकॉर्ड के मौजूद होने का दावा नहीं है।

**सुझाया गया सुधार:** manual entry के लिए booking ID, amount और payment method—तीनों का मिलान करें; method mismatch पर स्पष्ट exception लौटाएँ। pgTAP में एक mismatch fixture और एक matching fixture जोड़ें। Razorpay वाले मामले में केवल razorpay_payment_id की मौजूदगी को provider-side राशि सत्यापन न समझें; उसके लिए authoritative verified payment evidence अलग से आवश्यक है।

यह static source finding है। अभी migration या test बदला नहीं गया; PostgreSQL tests निष्पादित नहीं हुए। कोई Production परिवर्तन या भुगतान नहीं किया गया।


### 28. Manual payment UTR/reference पर भी duplicate रोक नहीं है

Core schema migration में srk_manual_payment_entries पर UNIQUE(booking_id) है, लेकिन payment_reference पर कोई unique constraint नहीं है। इसलिए एक booking पर एक manual payment entry सीमित है, पर एक ही UPI/Bank reference को अलग-अलग bookings में दोबारा दर्ज करने से database नहीं रोकता। Admin manual-payment RPC भी केवल method, reference की लंबाई और booking/payment state जाँचता है; दूसरे booking की समान reference खोजने का guard नहीं दिखता।

इसी प्रकार payout table में UNIQUE(booking_id) है, payout_reference पर नहीं; payout settlement RPC भी केवल method और reference की लंबाई जाँचता है, duplicate reference lookup नहीं करता।

**सुरक्षित सुधार:** UPI/Bank references के लिए provider/method के अनुरूप normalized uniqueness नीति तय करें। Cash receipt references के नियम अलग हो सकते हैं; इसलिए सभी methods पर अंधाधुंध global unique constraint न लगाएँ। Database-level unique index/constraint और concurrent duplicate-attempt pgTAP परीक्षण जोड़ें। Existing duplicate rows हों तो migration से पहले सुरक्षित reconciliation आवश्यक होगा; Production rows जाँचे नहीं गए हैं।

यह schema और function source review है। कोई migration, data change या वास्तविक भुगतान नहीं किया गया; PostgreSQL tests निष्पादित नहीं हुए।


### 29. Online payment verification: reconciliation finding का दायरा स्पष्ट

पिछले हिस्से में यह कहा गया था कि Accounting Reconciliation Razorpay payment ID की मौजूदगी को देखती है, provider से राशि दोबारा नहीं पूछती। यह बात केवल read-only reconciliation RPC के दायरे में सही है; इसे पूरे online payment flow पर लागू नहीं समझना चाहिए।

Source review में verify-payment.js ग्राहक bearer session और booking ownership जाँचता है, Razorpay API से payment retrieve करता है, captured status, exact order ID, INR currency और expected paise amount मिलाता है; तभी booking/ledger settlement करता है। razorpay-webhook.js raw-body HMAC signature जाँचता है, captured event payload में payment ID/order ID/status/currency/amount जाँचता है, और booking order से मिलान करता है। New-category flow में service-role settlement RPC भी booking/payment/amount identity स्वीकारता है।

इसलिए upstream verification मौजूद है; read-only reconciliation RPC स्वयं Razorpay API/provider evidence fetch नहीं करती। अभी तक यह source-level review है—deployed environment, live provider calls या Production records verify नहीं किए गए।


### 30. Reusable Razorpay order लौटाने से पहले booking state दोबारा lock/recheck नहीं होती

create-order.js में शुरुआती booking read के बाद findReusableOrder(booking, amount) existing order को Razorpay से fetch करता है। यदि provider order अभी created है और amount/currency match हैं, तो handler सीधे वही order लौटाता है। यह fast reuse branch srk_claim_payment_order_lock लेने और booking को दोबारा पढ़ने से पहले चलती है।

**संभावित race:** शुरुआती read के बाद और Razorpay order lookup के दौरान webhook/verify-payment booking को paid (या अन्य terminal state) कर सकता है। फिर भी reusable order branch पुराने booking snapshot से order लौटाती है; इस path में payment_status/status दोबारा verify नहीं होते। इससे ग्राहक को ऐसे order के साथ checkout दिख सकता है जिसकी booking अब payable नहीं रही। Razorpay duplicate capture को कैसे व्यवहार करेगा, यह यहाँ test नहीं किया गया; इसलिए इसे निश्चित double-charge नहीं, stale-order exposure/race condition कहा जा रहा है।

**सुझाया गया सुधार:** reusable-order fast path को भी per-booking lock के भीतर रखें, lock के बाद booking state और expected amount दोबारा पढ़ें, फिर provider order status/amount जाँचकर लौटाएँ। यदि lock न मिले तो retry response दें। verify/webhook settlement और order creation के बीच साझा booking-state guard की concurrency test जोड़ें।

यह create-order.js का static source finding है। कोई order बनाया नहीं गया, Razorpay API call नहीं की गई, और कोई Production/DB बदलाव नहीं हुआ। PostgreSQL/runtime concurrency test बाकी है।


### 31. create-order payment-lock RPC की migration definition repository में नहीं मिली

`create-order.js` दो database RPC call करता है: `srk_claim_payment_order_lock(p_booking_id)` और `srk_release_payment_order_lock(p_booking_id,p_lock_token)`। लेकिन GPT-2 audit branch के पूरे tracked file tree में इन दोनों function definitions का कोई SQL migration या root schema definition नहीं मिला। इन्हें केवल create-order.js में call-site के रूप में पाया गया। मौजूदा payment-order lock को लागू करने का दावा इसलिए source से सिद्ध नहीं है।

**प्रभाव:** यदि ये functions deployed database में किसी बाहरी/untracked setup से मौजूद नहीं हैं, तो order creation lock claim पर fail होगा; और यदि केवल claim या release में से एक उपलब्ध है तो lock lifecycle अधूरा रहेगा। इसीलिए इसे confirmed Production outage नहीं, बल्कि repository migration dependency gap / deployment prerequisite माना जाए।

**अगला कदम:** authoritative Production schema/function inventory और deployment migration history से दोनों signatures की मौजूदगी सत्यापित करें। यदि absent हों, तो reviewed migration में atomic per-booking lock token, expiry/lease, ownership-checked release और service_role-only execute grant परिभाषित करें; फिर दो concurrent create-order requests, expired lock, stale token release तथा paid booking race के PostgreSQL tests जोड़ें। Baseline/lineage और explicit approval के बिना migration न बनाएं/चलाएं।

यह repository-wide tracked-source inspection है। कोई Production function/schema query, order creation, database mutation या runtime test नहीं हुआ।


### 32. Razorpay order-link PATCH भुगतान की अंतिम स्थिति को बिना शर्त `pending` कर सकता है

`create-order.js` में lock लेने के बाद booking दोबारा पढ़ी जाती है और `findReusableOrder()` Razorpay से पुराने order का `created` status/amount/currency जाँचता है। यदि पुराना order लौटता है, तो उसके बाद `service_bookings` पर PATCH केवल `id=bookingId` से filter होता है और `razorpay_order_id` तथा `payment_status='pending'` लिखता है। PATCH predicate में `payment_status` का pending/unpaid होना, `razorpay_order_id` का उसी पुराने order से match, या payment state का पुनः सत्यापन नहीं है।

**संभावित race:** पुराने order को reusable जाँचने और PATCH के बीच उसका captured-payment webhook सफलतापूर्वक booking को Paid कर सकता है। उसके बाद create-order का unconditional PATCH `payment_status` को फिर Pending कर सकता है, जबकि `razorpay_payment_id`/`payment_verified_at` जैसे payment evidence fields row में रह सकते हैं। यह खास तौर पर पहले से मौजूद order के reuse path में संभव है; नया order ग्राहक को लौटाने से पहले ही यह race तभी बनेगी जब उसी booking/order पर कोई पहले से चल रहा provider payment event हो।

इसी परिवार का webhook legacy path भी पहले booking status/payment method/quote/amount पढ़ता है, फिर अलग PATCH करता है। उसका PATCH `id`, `razorpay_order_id` और `payment_status not.in.(paid,refunded)` से guarded है, लेकिन बीच में booking status, payment method या quote state बदलने पर उन शर्तों को database update के भीतर दोबारा लागू नहीं करता। New-category path अलग service-role settlement RPC पर निर्भर है; उसका authoritative SQL function definition tracked migrations में नहीं मिला, इसलिए उसकी atomicity का दावा यहाँ नहीं किया जा सकता।

**सुझाया गया सुधार:** order-link update को atomic conditional DB RPC/UPDATE में बदलें: lock के भीतर booking state, online method, completed/approved state, current order ID और unpaid/pending status की जाँच हो; payment final हो चुकी हो तो `pending` कभी न लिखें। Webhook और verify-payment को भी साझा atomic settlement contract पर रखें। Regression tests में (1) reusable order lookup के बाद webhook Paid, (2) refunded/paid state के बाद stale PATCH, (3) status/payment method/quote बदलना, और (4) concurrent verify + webhook शामिल हों।

यह static source review है। कोई Razorpay order/API call, Production query, payment, DB write या concurrency test नहीं किया गया।

### 33. Webhook lease expiry और claim-token fencing — निष्कर्ष का स्पष्टीकरण तथा अतिरिक्त regression test

दो मिनट की lease_expires_at अवधि समाप्त होना अपने-आप पुराने Worker का Claim Token रद्द नहीं करता। यह अवधि दूसरे Worker को Event दोबारा claim करने की अनुमति देती है। नया Claim मिलने पर claim_token बदल जाता है; completion RPC वर्तमान Token से मिलान करती है और पुराने Token को stale_claim लौटाती है। इसलिए केवल lease-expiry के बाद, लेकिन किसी नए Claim से पहले, पुरानी Completion स्वीकार होना अपने-आप में सिद्ध दोष नहीं है। पहले उठाई गई “lease expiry पर completion रोकनी चाहिए” वाली चिंता को confirmed defect नहीं माना जाए।

अतिरिक्त स्रोत-जाँच में razorpay-webhook.js का completeWebhookEvent() RPC response में success:false मिलने पर exception फेंकता है। Handler इस स्थिति में HTTP 200 सफलता नहीं देता; retryable completion का प्रयास करता है और provider retry के लिए HTTP 500 लौटाता है। इसलिए stale Claim की अस्वीकृति handler द्वारा सफलता के रूप में छिपाई नहीं जाती।

**Regression coverage जोड़ी:** tests/razorpay-webhook-inbox.test.js में नया test जोड़ा गया है, जो simulated stale_claim completion response पर handler के HTTP 500 व्यवहार और पुराने Token के दोबारा इस्तेमाल को जाँचता है।

- Test commit: 2f1068c36a11ee3b3c3dbdf282fef2610ac3c060
- Static source recount: webhook Node test cases 13 से बढ़कर **14** हुए।
- यह नया test अभी execute नहीं हुआ है। SQL/pgTAP और वास्तविक concurrent Worker behavior भी अभी untested हैं।

अगला वास्तविक test gap: दो concurrent Worker में पहला lease expire होने के बाद दूसरा Worker नया Token ले, फिर पहला Worker completion करे—इस पूरे क्रम को PostgreSQL integration test में चलाना। कोई Production query या बदलाव नहीं किया गया।
### 34. Webhook inbox SQL contract — अतिरिक्त fencing assertions

Webhook inbox के pgTAP source-contract suite में दो अतिरिक्त assertions जोड़े गए:
- Expired lease दोबारा claim होने पर नया fencing Token और नई दो-मिनट lease सेट होती है।
- पुराने Worker का Token बदल जाने पर Completion RPC नए Worker के Event को complete नहीं कर सकती।

- SQL test commit: d78577eb5ccb2c6baef8dede525115388c924f62
- Static recount: plan 17, assertion calls 17, एक finish() और एक rollback।
- ये pgTAP source assertions हैं; PostgreSQL पर execute नहीं हुए और वास्तविक दो-Worker concurrency साबित नहीं करते।

Node regression test commit: 2f1068c36a11ee3b3c3dbdf282fef2610ac3c060। Webhook Node test inventory 14 cases है, लेकिन test execution अभी नहीं हुआ।
### 35. Payment Order Lock lifecycle — release path मौजूद, DB contract अभी अनुपलब्ध

create-order.js में नया Order बनाने/reuse करने वाले locked path के लिए `srk_claim_payment_order_lock` और `srk_release_payment_order_lock` RPC बुलाए जाते हैं। Lock Token मिलने के बाद handler का finally block success, early return और thrown error—सभी exits पर release RPC का प्रयास करता है। Release request विफल होने पर error log होता है; handler उस विफलता को caller के response में अलग से नहीं दिखाता।

पूरे tracked Repository और migrations में दोनों RPC definitions की खोज से कोई SQL definition नहीं मिली। इसलिए इस source tree से इन बातों की पुष्टि नहीं हो सकी: Lock table/schema, atomic claim semantics, lock expiry/lease duration, expired-lock reclamation, token fencing, release authorization और release idempotency। यह Production DB में functions न होने का प्रमाण नहीं है; वे manually/deployed या किसी untracked source से मौजूद हो सकते हैं।

**अगला verification gate:** किसी भी migration/patch से पहले authoritative deployed schema या approved test database से दोनों function definitions पढ़ें; फिर दो concurrent create-order requests, process timeout, failed release, expired lock reclaim और stale release-token scenarios के integration tests चलाएँ। जब तक यह contract उपलब्ध न हो, नया lock implementation अनुमान से न बनाएँ।

यह source-only review है। कोई Supabase/Production query, payment order creation, database write या runtime test नहीं किया गया।
### 36. Legacy Razorpay verify/webhook settlement — eligibility snapshot और final PATCH के बीच state-race

verify-payment.js और razorpay-webhook.js के legacy-quote payment paths पहले booking पढ़कर payment method, completed status, approved quote और expected amount जाँचते हैं। इसके बाद provider/payment evidence validation के बाद अलग REST PATCH करते हैं। Final PATCH की conditional filters booking ID, Razorpay Order ID और payment_status not in (paid,refunded) तक सीमित हैं; वे उसी UPDATE के भीतर status='completed', quote_status='approved' और payment_method online होने की शर्त दोबारा लागू नहीं करते।

इसलिए initial read और final PATCH के बीच यदि booking status/quote/payment method बदलता है, तो पुराना eligibility snapshot अभी भी paid update की अनुमति दे सकता है। यह संभावित race है, किसी Production booking या वास्तविक नुकसान का प्रमाण नहीं। Captured provider payment को केवल छोड़ देना भी सुरक्षित समाधान नहीं; ऐसी स्थिति में authoritative reconciliation/refund review चाहिए।

**सुझाया गया सुधार:** legacy path को atomic DB settlement RPC में ले जाएँ जो booking row lock करके current order ID, online method, completed/approved eligibility, amount और payment/refund state एक ही transaction में जाँचे; mismatch पर स्पष्ट manual-reconciliation result दे। Verify-payment और webhook दोनों उसी RPC का उपयोग करें। pgTAP में initial read के बाद status बदलना, quote revoke/change, payment method change और concurrent verify/webhook के cases जोड़ें।

यह finding source-level race analysis है। कोई DB/Production row नहीं देखी गई; कोई payment, refund, migration या runtime concurrency test नहीं किया गया।

## 37. Verify Payment / Webhook की दो service-role RPC निर्भरताएँ — SQL definition अभी प्रमाणित नहीं

### स्रोत में उपयोग
- `verify-payment.js` के new-category रास्ते में `srk_service_role_get_booking_payment_breakdown` से immutable labour bill और cancellation-fee सहित अपेक्षित कुल राशि ली जाती है। इसके बाद `srk_service_role_record_online_booking_payment` को booking ID, Razorpay Order ID, Payment ID और paise amount के साथ बुलाया जाता है।
- `razorpay-webhook.js` का new-category payment रास्ता भी यही दोनों RPC बुलाता है। RPC settlement असफल होने पर webhook retryable error देता है; Verify Payment Admin reconciliation की जरूरत बताता है।
- जाँची गई migration `20261114360000_new_category_electrician_payout_reconciliation.sql` में payout trigger `srk_create_electrician_payable` और payout settlement function हैं, लेकिन इन दोनों online-payment RPC की definitions नहीं हैं।
- साथ में जाँची गई root setup files `SUPABASE_SCHEMA.sql`, `PORTAL_SCHEMA.sql`, `COMPLETE_DATABASE_SETUP.sql`, `ADMIN_EMAIL_LOGIN_SETUP.sql` में भी इन exact function names की definitions नहीं मिलीं। कुछ अन्य payment-related migrations केवल payment preference या दूसरे workflows संभालती हैं।

### प्रभाव / सीमा
- यह दो RPC runtime dependencies हैं। यदि ये Production/Test database में किसी अलग untracked या manually-installed SQL से उपलब्ध नहीं हैं, तो new-category online payment verification और webhook settlement fail होंगे।
- अभी यह प्रमाणित नहीं है कि deployed database में functions मौजूद नहीं हैं; Production schema query नहीं की गई। इसलिए इसे confirmed outage नहीं, बल्कि repository/replay lineage में unresolved dependency माना जाए।
- अगला सुरक्षित कदम: canonical baseline और migration lineage तय होने के बाद isolated test database में `pg_proc`/privilege/signature जाँचें; function body में booking row lock, exact order/payment/amount/currency validation, idempotency, paid/refunded conflict और ledger atomicity सत्यापित करें। उसके बाद Verify Payment और webhook के साझा settlement contract पर pgTAP तथा concurrent retry tests जोड़ें।
- अभी कोई SQL migration, Production query/write, payment attempt या refund operation नहीं किया गया।


## 38. पुराने Project Progress दस्तावेज़ और वर्तमान Branch Tree में Order-Lock migration का विरोधाभास

- Repository search में पुराने commit/document `091fccd32a71028b49800152cafdd5d9ab8fb7a2` के `docs/SRK_ELECTRONIC_PROJECT_PROGRESS_HI.md` अंश में दावा है कि Feature Branch में `20261114090000_atomic_razorpay_order_and_payment_finalization.sql` नाम का migration जोड़ा गया था। उस विवरण के अनुसार उसमें private expiring order-lock table, service-role claim/release RPC और atomic captured-payment finalizer होना था।
- लेकिन वर्तमान PR branch `feat/customer-login-first-dashboard-20261114` और GPT-2 audit branch `chore/pr8-replay-audit-20261116-v2` — दोनों की recursive Git tree सूची में यह migration filename मौजूद नहीं है। वर्तमान दोनों trees में exact RPC names `srk_claim_payment_order_lock`, `srk_release_payment_order_lock`, `srk_service_role_get_booking_payment_breakdown`, `srk_service_role_record_online_booking_payment` की कोई migration file भी नहीं मिली।
- अतः पुराने progress document का दावा वर्तमान checked-out branch content से मेल नहीं खाता। यह संभव है कि पुराना document किसी बाद में हटाए गए/अलग commit state का वर्णन करता हो; उपलब्ध evidence से कारण तय नहीं है।
- यह finding पहले के unresolved dependency निष्कर्ष को और मजबूत करती है, लेकिन Production में function अनुपस्थित होने का प्रमाण नहीं है। अगला कदम Git history/PR commit ancestry में उस migration के add/delete commits का पता लगाना और उसके बाद authorized isolated DB में actual function signatures/privileges जाँचना है।
- कोई migration restore या नया SQL patch नहीं किया गया; Production/DB query, payment या deployment नहीं हुआ।

- अतिरिक्त Git History जाँच: GitHub commit-history API में इसी exact migration path के लिए कोई commit नहीं मिला; commit search में migration filename, “atomic razorpay order payment finalization” और `srk_claim_payment_order_lock` के लिए भी कोई commit result नहीं मिला। इसलिए उपलब्ध repository history से इस migration का add/delete commit trace नहीं हो पाया।
- निष्कर्ष को सीमित रखें: इस repository में यह migration कभी commit हुई थी, ऐसा अभी प्रमाणित नहीं है। पुराने progress दस्तावेज़ का उल्लेख अकेला source है; उसे वर्तमान branch की मौजूद SQL implementation न मानें।


## 39. ग्राहक का Cash से Razorpay भुगतान विकल्प बदलने वाला RPC — Unicode literal mismatch

- Frontend `booking.html` में `srk_customer_change_payment_method` को `p_payment_method: 'Razorpay ऑनलाइन भुगतान'` भेजा जाता है।
- Migration `20261114202656_customer_change_payment_method_rpc.sql` में वही function argument की तुलना और database update के लिए `'Razorpay à¤à¤¨à¤²à¤¾à¤à¤¨ à¤­à¥à¤à¤¤à¤¾à¤¨'` literal इस्तेमाल करता दिखता है। यह frontend के सही Hindi Unicode literal से अलग mojibake text है।
- यदि repository में मौजूद SQL literal ही deployed function में है, तो RPC का input validation `INVALID_PAYMENT_METHOD_CHANGE` देगा; और update value भी गलत text होगी। इसलिए ग्राहक का Cash से Online विकल्प बदलना विफल हो सकता है। यह source-level mismatch है; deployed DB/runtime पर परीक्षण नहीं हुआ।
- Function की बाकी शर्तें उचित रूप से owner-scoped हैं: `auth.uid()`, केवल `new/confirmed`, unassigned, unpaid, zero amount, कोई order/payment ID नहीं, और पुराना method Cash; execute केवल authenticated को दिया गया है।
- सुझाया सुधार: canonical UTF-8 literal को frontend और SQL में एक समान रखें (या स्थिर ASCII enum जैसे `razorpay` अपनाएँ), फिर pgTAP में सही literal success, गलत literal rejection, दूसरे customer का booking ID, assigned/paid/order-linked booking rejection जाँचें। Migration lineage/baseline clear होने तक कोई SQL edit या replay नहीं किया गया।
- कोई Production query/write, payment, deployment या test execution नहीं हुआ।


## 40. Section 39 का सुधार — बाद की Migration ने Unicode mismatch ठीक किया है

- Section 39 में `20261114202656_customer_change_payment_method_rpc.sql` का mojibake literal देखकर संभावित live defect दर्ज किया गया था। उसी Feature Branch की आगे की Migration सूची में `20261115270000_fix_customer_payment_method_unicode_contract.sql` मिली।
- यह follow-up migration उसी RPC को `CREATE OR REPLACE` करके argument validation और stored `payment_method` दोनों में Frontend के exact UTF-8 literal `Razorpay ऑनलाइन भुगतान` का उपयोग करती है। इसलिए Feature Branch के क्रम में यदि यह follow-up migration सफलतापूर्वक लागू हुई है, तो पहले migration का Unicode mismatch बाद की migration से ठीक हो जाता है। Section 39 को अकेले वर्तमान Feature Branch की अंतिम स्थिति न माना जाए।
- `tests/customer-payment-method-enforcement.test.js` में छह Node test cases हैं; इनमें migration/dashboard exact UTF-8 contract का static assertion और uncertain RPC response UI handling का static assertion भी है। इन छह test cases को इस audit में execute नहीं किया गया।
- यह source-level correction है; deployed Database पर migration application/order या runtime behavior सत्यापित नहीं हुआ। Migration-history drift के कारण इसे Production में लागू हुआ मानना सुरक्षित नहीं है।
- कोई source code/SQL बदला नहीं गया; केवल Audit report में Section 39 की qualification जोड़ी गई है।


## 41. Admin Dashboard के दो आवश्यक RPC — वर्तमान Repository में SQL परिभाषा नहीं मिली

- `admin.html` के `saveBookingInternal()` में legacy booking को `new → confirmed` करने के लिए `srk_admin_confirm_legacy_booking(p_booking_id)` RPC call होता है।
- उसी function में नई category booking का वास्तविक Cash payment दर्ज करने के लिए `srk_admin_record_new_booking_cash_payment(p_booking_id,p_reference,p_note)` RPC call होता है। UI इन RPC failures को स्पष्ट error के रूप में दिखाता है और डेटा reload करता है।
- दोनों exact function names के लिए repository-wide GitHub code search में कोई SQL definition नहीं मिली। साथ ही root setup files `SUPABASE_SCHEMA.sql`, `PORTAL_SCHEMA.sql`, `COMPLETE_DATABASE_SETUP.sql` में भी दोनों नाम अनुपस्थित हैं। मौजूदा numbered migrations में भी exact definitions नहीं मिलीं।
- इससे Feature Branch source में दो unresolved DB dependencies बनती हैं: legacy Admin confirmation और new-category Cash settlement। यदि ये functions किसी बाहरी/manual DB setup में मौजूद न हों, तो संबंधित Admin actions fail होंगे। Production DB नहीं देखा गया, इसलिए deployed absence या live outage का दावा नहीं है।
- अलग से, legacy `srk_admin_record_manual_payment(uuid,text,text,text)` की SQL definition `20261115210000_legacy_manual_payment_and_itemized_receipt.sql` में मौजूद है; उसे इन दो missing functions के साथ न मिलाएँ।
- सुरक्षित अगला कदम: Git history/अन्य branches में दोनों definitions ढूँढना; फिर authorized isolated DB में signatures, grants, Main Admin checks, row locks, exact amount/ledger writes और idempotency verify करना। कोई नया RPC अनुमान से नहीं बनाया गया।
- कोई Production query/write, SQL edit, payment, deployment या test execution नहीं हुआ।


## 42. दूसरी Branch में पुरानी Atomic Razorpay Migration मिली — PR #8 में अनुपस्थित और API contract अलग

- Branch `feature/platform-fee-cash-online-cycle` की tree में `supabase/migrations/20261114090000_atomic_razorpay_order_and_payment_finalization.sql` मिली (blob SHA `06ecb9ec99981873b9e0c157f293197ba11caae7`)। इसलिए पुरानी progress रिपोर्ट का migration-संबंधी उल्लेख दूसरी Branch के संदर्भ में सही है; इसे वर्तमान PR #8 branch में मौजूद न मानें।
- इस migration में `srk_claim_payment_order_lock(uuid)`, `srk_link_payment_order(uuid,uuid,text,bigint)`, `srk_release_payment_order_lock(uuid,uuid)`, और `srk_service_finalize_captured_payment(uuid,text,text,bigint,text)` परिभाषित हैं। यह private expiring lock, service_role-only grants और booking row lock/eligibility/amount recheck का प्रयास करती है।
- वर्तमान PR #8 के `create-order.js` में claim और release RPC call होते हैं, लेकिन `srk_link_payment_order` call नहीं होता। Order create होने के बाद file सीधे REST PATCH से `razorpay_order_id` और `payment_status='pending'` लिखती है। इसलिए दूसरी Branch की migration अकेले लागू होने पर भी उसका atomic link RPC वर्तमान JavaScript द्वारा इस्तेमाल नहीं होगा; source path lock लेकर भी final link के समय migration के row-lock + token + amount/state revalidation को bypass करता है। यह source-level integration gap है, runtime incident नहीं।
- दूसरी Branch की migration का captured-payment function `srk_service_finalize_captured_payment` है; वर्तमान PR #8 के `verify-payment.js` और `razorpay-webhook.js` इसके बजाय `srk_service_role_get_booking_payment_breakdown` और `srk_service_role_record_online_booking_payment` बुलाते हैं। इन दो नए नामों की definitions उस पुरानी migration में नहीं हैं। अतः migration को current code का पूरा समाधान नहीं माना जा सकता।
- वर्तमान PR #8 tree में यह migration अनुपस्थित है; दूसरी Branch में मौजूद होना migration lineage/PR ancestry का प्रमाण नहीं कि यह Production या PR #8 में लागू हुई। कोई cherry-pick/restore या SQL change नहीं किया गया।
- सुझाया अगला कदम: branch ancestry और intended API contract reconcile करें; फिर एक ही canonical order-link + payment-settlement RPC contract चुनकर JS और SQL को साथ align करें। Migration baseline स्पष्ट होने और authorized isolated DB उपलब्ध होने तक replay/DB test न करें।
- Production query/write, payment, deployment या merge नहीं हुआ।


## 42. Admin Dashboard के दो RPC — अन्य Branches और Git History में भी SQL परिभाषा नहीं मिली

इस जाँच में इन दोनों नामों को अलग-अलग तरीके से तलाशा गया:
- `srk_admin_confirm_legacy_booking`
- `srk_admin_record_new_booking_cash_payment`

परिणाम:
- Repository के उपलब्ध code search में दोनों के exact नाम नहीं मिले।
- दोनों नामों पर Git commit search में कोई commit नहीं मिला।
- उपलब्ध branches की सूची में पुराने Admin/payment-संबंधित branches भी जाँचे गए। विशेष रूप से `work/separate-customer-electrician-portals` की Admin booking और manual-payment migrations में इन दोनों की परिभाषा नहीं मिली।
- वहाँ `srk_admin_update_booking` और अलग manual-payment workflow मौजूद हैं, लेकिन वे इन दो RPC के समान नाम/contract नहीं हैं।

**निष्कर्ष:** उपलब्ध GitHub branches और इतिहास से इन दो RPC की SQL implementation प्रमाणित नहीं होती। यह अभी भी Repository-स्तर का निष्कर्ष है; Production Database या किसी बाहरी/manual SQL installation की जाँच नहीं हुई है। इसलिए इसे live outage या deployed absence नहीं कहा जा सकता। Admin UI के संबंधित actions के लिए implementation/contract को स्पष्ट करना आवश्यक है।


## 43. Razorpay Atomic Migration और वर्तमान JavaScript — Contract मिलान का संशोधित निष्कर्ष

Branch `feature/platform-fee-cash-online-cycle` की `20261114090000_atomic_razorpay_order_and_payment_finalization.sql` को वर्तमान root handlers के साथ प्रत्यक्ष पढ़कर मिलाया गया। इससे पहले की रिपोर्ट में इन मुख्य RPC की SQL परिभाषा न मिलने की बात अधूरी थी; इस Migration में ये परिभाषाएँ वास्तव में मौजूद हैं:

| RPC | Migration में परिभाषा | वर्तमान handler में उपयोग |
|---|---|---|
| `srk_claim_payment_order_lock(uuid)` | हाँ | `create-order.js` |
| `srk_link_payment_order(uuid,uuid,text,bigint)` | हाँ | `create-order.js` |
| `srk_release_payment_order_lock(uuid,uuid)` | हाँ | `create-order.js` finally block |
| `srk_service_finalize_captured_payment(uuid,text,text,bigint,text)` | हाँ | `verify-payment.js` और `razorpay-webhook.js` |

इसलिए इन चार RPC को “Repository में SQL definition missing” कहना सही नहीं है। इन्हें Migration में Service Role-only grants, booking row lock, lock token validation, payable-state/amount checks और captured-payment idempotency के साथ परिभाषित किया गया है। यह केवल source-level contract review है; Migration लागू होने या runtime व्यवहार का प्रमाण नहीं।

**अलग unresolved dependency:** तीनों handlers में `srk_service_get_labour_bill_for_payment(uuid)` भी इस्तेमाल होता है, लेकिन इस Atomic Migration में इसकी परिभाषा नहीं है। उपलब्ध GitHub code search से भी इसकी दूसरी परिभाषा नहीं मिली। इसलिए इसकी SQL implementation और privilege contract अलग से सत्यापित करना बाकी है।

**अतिरिक्त सावधानी:** `create-order.js` में lock claim के बाद order reuse/create होता है और फिर `srk_link_payment_order` के जरिए atomic link किया जाता है। अतः पहले की टिप्पणी कि यह handler सीधे REST PATCH से order ID लिखता है, वर्तमान पढ़े गए source के लिए गलत थी; इस रिपोर्ट में उसे वापस लिया जाता है। Reusable-order fast path अब lock के भीतर है, लेकिन provider GET के बाद booking का पुनः-पठन RPC के भीतर `srk_link_payment_order` द्वारा state/amount दोबारा जाँचा जाता है।

**स्थिति:** Migration/handler contract का source मिलान हुआ; PostgreSQL execution, pgTAP, deployment ledger और Production schema सत्यापन नहीं हुआ।


## 44. Labour Bill Payment RPC की परिभाषा मिल गई — पिछला “missing” निष्कर्ष वापस

Section 43 में `srk_service_get_labour_bill_for_payment(uuid)` को unresolved बताया गया था। Migration-by-migration पढ़ने पर यह निष्कर्ष गलत निकला। इसकी परिभाषा `supabase/migrations/20261114040000_server_authoritative_labour_timer_and_bill_snapshot.sql` में पंक्ति 745 से 768 के बीच मौजूद है।

Source-level contract:
- `SECURITY DEFINER`, `STABLE` और pinned `search_path` के साथ बनाया गया है।
- `auth.jwt()->>'role' = 'service_role'` की जाँच करता है।
- `srk_booking_labour_bills` से booking का immutable labour bill पढ़ता है और `labour_amount_paise` सहित आवश्यक fields लौटाता है।
- PUBLIC, anon और authenticated से EXECUTE revoke; केवल service_role को grant।

इसलिए वर्तमान उपलब्ध Branch source में तीनों handlers की labour-bill lookup dependency की SQL definition भी मौजूद है। Section 43 का unresolved-dependency कथन वापस लिया जाता है। अब इन चार payment RPC और labour-bill lookup RPC की repository source definition मिलती है।

**बाकी सत्यापन:** Migration ordering/replay compatibility, PostgreSQL/pgTAP execution और deployed schema verification अभी नहीं हुए हैं। यह प्रमाणित नहीं है कि ये migrations किसी live Database में लागू हैं।


## 45. Razorpay Atomic Payment migrations का क्रम और test coverage

Feature branch `feature/platform-fee-cash-online-cycle` की migration सूची में dependency order सही दिखता है:
1. `20261114000000_electrician_requested_and_approved_rate_tiers.sql`
2. `20261114010000_customer_booking_category_and_duration.sql`
3. `20261114040000_server_authoritative_labour_timer_and_bill_snapshot.sql` — `service_bookings` पर timer/rate snapshot fields और `srk_booking_labour_bills` table बनाता है; साथ में service-role-only `srk_service_get_labour_bill_for_payment(uuid)` RPC बनाता है।
4. `20261114090000_atomic_razorpay_order_and_payment_finalization.sql` — पहले वाली bill table पर निर्भर होकर order lock/link और captured-payment finalization RPC बनाता है।

इसलिए उपलब्ध फ़ाइल-क्रम में Atomic Payment migration अपने labour-bill table/RPC से पहले नहीं चलती। यह migration filename/order और source references का static निरीक्षण है; वास्तविक replay नहीं।

Test source में:
- `atomic_razorpay_order_and_payment_finalization.test.sql` RPC existence, service-role grants, unauthorized-role denial, lock/state checks, amount/currency/order checks और idempotency के source assertions रखता है।
- `atomic_razorpay_order_behavior.test.sql` 15 assertions के लिए lock contention, एक पैसे के amount mismatch, valid order link, captured payment finalization, same-payment retry idempotency, different payment ID rejection, legacy quote mismatch और authenticated-role denial को कवर करता है।
- इन tests को इस audit में execute नहीं किया गया। Test files में `srk_service_get_labour_bill_for_payment` के अलग existence/privilege/return-value assertions भी नहीं दिखे; इस RPC का grant/role contract migration source में मौजूद है, पर test coverage बढ़ाई जा सकती है।

**निष्कर्ष:** Migration file order में कोई Razorpay-to-labour-bill ordering blocker नहीं मिला। Runtime/replay, SQL parser, pgTAP और deployed database verification अभी शेष हैं।


## 46. Payment-order flow का अंतिम static review और शेष परीक्षण

`create-order.js` का क्रम दोबारा देखा:
- पहले customer session/booking ownership जाँचता है; उसके बाद `srk_claim_payment_order_lock` RPC call करता है।
- Lock मिलने के बाद booking फिर से पढ़ता और customer ownership/payment choice/completed state दोबारा जाँचता है।
- उसके बाद immutable labour bill lookup, existing Razorpay order reuse या नया order create, और अंत में `srk_link_payment_order` द्वारा DB में atomic link करता है।
- `finally` में वही booking/token pair देकर lock release की कोशिश करता है। SQL link RPC फिर से booking row lock, token expiry और exact amount जाँचता है।

इस source sequence में पुराना “order reuse lock से पहले होता है” concern लागू नहीं होता।

**दो resilience scenarios अभी व्यवहारिक रूप से test नहीं हुए:**
1. Razorpay order create request सफल हो जाए, लेकिन response या बाद का DB link request timeout हो जाए। Provider पर unused/orphan order रह सकता है; retry पर नया order बन सकता है। उपलब्ध source में ऐसा order client को तब तक return नहीं होता जब तक DB link RPC सफल न हो, इसलिए इसे confirmed duplicate charge नहीं कह रहे।
2. Order create/provider response 90-second SQL lock expiry से आगे निकल जाए तो link RPC expired token अस्वीकार करेगी। इससे provider पर unused order रह सकता है; user-facing retry/reconciliation behavior runtime test नहीं हुआ।

**Test coverage सुधार:** PR branch की `atomic_razorpay_order_and_payment_finalization.test.sql` में service-role bill lookup RPC की existence, service_role-only grant, unauthorized-role denial, pinned search_path और paise return contract के explicit assertions जोड़ने चाहिए। Audit branch में वह test file मौजूद नहीं थी, इसलिए PR/test branch को बदले बिना इस audit branch पर test edit नहीं किया गया।

**अगला सुरक्षित कदम:** इन दो timeout scenarios और bill-lookup privilege contract के लिए tests PR branch पर अलग reviewable patch में जोड़ना; फिर केवल अनुमोदित isolated test DB पर pgTAP चलाना। Production या shared integration branch पर कोई कार्रवाई नहीं की गई।


## 47. Isolated pgTAP workflow की वास्तविक सीमा और नया test gap

Feature branch में `.github/workflows/payment-order-isolated-pgtap.yml` मौजूद है। Source inspection से यह workflow:
- GitHub-hosted runner पर pinned Supabase CLI 3.1.0 से अस्थायी local Supabase stack शुरू करता है;
- `payment_order_bootstrap.sql` fixture से synthetic `service_bookings` और `srk_booking_labour_bills` tables बनाता है;
- केवल `20261114090000_atomic_razorpay_order_and_payment_finalization.sql` लागू करता है;
- दो Atomic Payment pgTAP files चलाता है और अंत में local stack बंद करता है।

**महत्वपूर्ण सीमा:** यह workflow `20261114040000_server_authoritative_labour_timer_and_bill_snapshot.sql` लागू नहीं करता। Fixture पहले से labour-bill table बना देता है। इसलिए यह Atomic migration की RPC behavior जाँच सकता है, लेकिन full dependency migration order, labour-bill lookup RPC की creation/grant, या उस RPC के actual return contract को validate नहीं करता। दोनों pgTAP files में भी `srk_service_get_labour_bill_for_payment(uuid)` का explicit assertion नहीं है।

**Workflow status:** इस audit में workflow dispatch नहीं किया गया और कोई pgTAP result उपलब्ध नहीं है। Workflow file होना successful run का प्रमाण नहीं।

**सुझाया गया सुधार:** अलग isolated workflow में पहले आवश्यक base schema/fixtures, फिर वास्तविक `20261114040000` और उसके बाद `20261114090000` क्रम से लागू करें; labour-bill RPC की existence, service_role-only grant, non-service denial और returned `labour_amount_paise` का pgTAP assertion जोड़ें। साथ ही handler के provider-timeout और expired-lock recovery scenarios को अलग mocked integration tests में कवर करें।

किसी Production database, Supabase hosted branch या shared integration branch पर कार्रवाई नहीं की गई।


## 48. Customer verify और Razorpay webhook की साझा finalization जाँच

Feature branch के मौजूदा source को फिर से पढ़ने पर:
- `verify-payment.js` ग्राहक के OTP-authenticated bearer session, booking ownership/verified phone, Razorpay signature, provider payment lookup, captured status, exact order ID, INR और approved paise amount जाँचता है। इसके बाद ही shared SQL finalizer RPC बुलाता है।
- `razorpay-webhook.js` raw request body पर Razorpay HMAC signature जाँचता है; केवल `payment.captured` और `order.paid` events स्वीकार करता है। वह captured payment entity, booking payment method/status और approved amount जाँचकर वही SQL finalizer RPC बुलाता है। Netlify wrapper इसी root handler को export करता है।
- Webhook में अलग event-inbox/deduplication table इस branch के इस handler में नहीं दिखी। लेकिन finalizer booking row को `FOR UPDATE` से lock करता है, उसी payment ID को `already_processed` मानता है और अलग payment ID को conflict करता है। इसलिए duplicate delivery का अंतिम DB write idempotent बनाया गया है; फिर भी webhook delivery/retry और verify-vs-webhook race का runtime test बाकी है।
- इस branch में इन handlers के लिए अलग Node integration test file नहीं मिली; उपलब्ध atomic SQL behavior test same-payment retry और different-payment-ID conflict को cover करता है, पर actual HTTP handler race/timeout नहीं।

**अतिरिक्त स्पष्ट जोखिम:** `create-order.js` Razorpay order POST में booking ID को receipt देता है, लेकिन request में स्पष्ट provider idempotency key नहीं दिखती। यदि Razorpay order create कर दे और client को response timeout हो जाए, तो retry पर दूसरा provider order बन सकने की संभावना है। यह duplicate captured charge सिद्ध नहीं करता; केवल duplicate/unused order risk है। Provider receipt uniqueness/idempotency का व्यवहार इस source audit से प्रमाणित नहीं हुआ।

**सुझाए गए tests:** (1) same webhook event दो बार, (2) webhook और customer verify एक साथ, (3) same payment ID दो channels से, (4) अलग payment ID उसी order पर, (5) Razorpay order POST accepted-but-response-lost, (6) DB link RPC commit-but-response-lost और (7) 90-second lock expiry। इनको mocked HTTP integration और वास्तविक isolated PostgreSQL concurrency tests में चलाना चाहिए।

यह source-only निष्कर्ष है। कोई handler test, pgTAP, Production query/write या payment request नहीं चलाया गया।


## 49. पुराने Payment Findings का Consolidated Correction — Sections 30–38

नवीनतम source re-fetch के बाद नीचे के पुराने निष्कर्षों को वर्तमान `feature/platform-fee-cash-online-cycle` branch पर लागू न माना जाए। Sections 43–48 में नया source evidence दर्ज है; यह section पुराने पाठ को स्पष्ट रूप से supersede करता है।

| पुराना हिस्सा | नया सत्यापित निष्कर्ष |
|---|---|
| 30 — reusable order lock से पहले लौटता है | गलत/पुराना। वर्तमान `create-order.js` में lock claim पहले, booking re-read बाद में, फिर reuse/create और atomic link है। |
| 31 और 35 — claim/release SQL definitions missing | गलत/पुराना। चारों payment RPC `20261114090000_atomic_razorpay_order_and_payment_finalization.sql` में परिभाषित हैं। |
| 32 — direct REST PATCH से order link | गलत/पुराना। वर्तमान handler `srk_link_payment_order` RPC call करता है; direct booking PATCH नहीं। |
| 36 — verify/webhook अलग REST PATCH settlement | गलत/पुराना। वर्तमान दोनों handlers shared `srk_service_finalize_captured_payment` RPC call करते हैं। |
| 37 — new-category payment RPC definitions missing | पुराने RPC नाम। वर्तमान handlers `srk_service_get_labour_bill_for_payment` और shared finalizer का उपयोग करते हैं; bill lookup definition migration `20261114040000` में मिली। |
| 38 — atomic migration branch tree में नहीं | गलत/पुराना branch snapshot। Current feature branch में migration मौजूद है; audit branch snapshot में इसे न पाना इसका अभाव सिद्ध नहीं करता। |

**Webhook inbox सावधानी (Sections 33–34):** उन sections में वर्णित event-inbox/claim-token flow को इस feature branch के वर्तमान `razorpay-webhook.js` पर लागू न मानें। इस branch का Netlify wrapper root `razorpay-webhook.js` export करता है; re-fetched handler में inbox claim/complete RPC calls नहीं हैं। Shared SQL finalizer duplicate captured payment ID को idempotently संभालता है, जो अलग सुरक्षा परत है। Inbox tests/दूसरे branch variant को इस handler की coverage न गिनें।

**वर्तमान शेष gaps:** वास्तविक PostgreSQL/pgTAP execution; पूरे dependency migration order का isolated test; bill-lookup RPC privilege/return assertions; handler-level mocked HTTP tests; webhook-vs-verify concurrency; Razorpay order POST accepted-but-response-lost; DB link response-lost; 90-second lock expiry।

इस correction से पहले के गलत निष्कर्ष हटाए नहीं गए हैं ताकि audit trail बना रहे, लेकिन उन्हें स्पष्ट रूप से superseded माना जाए। यह repository source review है; Production database या live provider behavior का प्रमाण नहीं।


## 50. Full dependency migration को isolated test में जोड़ने से पहले baseline blocker

Workflow/fixture के साथ वास्तविक dependency migration `20261114040000_server_authoritative_labour_timer_and_bill_snapshot.sql` और root setup files का static comparison किया। अभी इसे मौजूदा test workflow में सीधे जोड़ना सही नहीं होगा:

1. `payment_order_bootstrap.sql` केवल दो synthetic tables बनाता है: सीमित `service_bookings` और `srk_booking_labour_bills`। इसमें `electrician_profiles`, `srk_wallet_ledger`, `auth.users` test rows/relationships, कई timer/booking columns और migration द्वारा उपयोग की जाने वाली बाकी dependencies नहीं हैं।
2. `20261114040000` केवल bill table नहीं बनाती; यह existing `service_bookings`, `electrician_profiles`, `srk_wallet_ledger`, `job_offers`, Auth users तथा कई पहले से मौजूद RPC/schema contracts पर निर्भर 2,678-line migration है। इसमें wallet-ledger constraints/functions, timer authorization, profile lookup, cash-cycle और अनेक RPC भी हैं।
3. Root `SUPABASE_SCHEMA.sql` सिर्फ 93 lines का starter schema है; इसमें `srk_wallet_ledger` नहीं है और यह migration की पूरी prerequisite schema नहीं देता। `PORTAL_SCHEMA.sql` electrician profile Auth linkage जोड़ता है, लेकिन वह भी wallet ledger और सभी required columns/functions का canonical baseline नहीं है। `COMPLETE_DATABASE_SETUP.sql` में duplicated setup definitions हैं; इसे बिना lineage review canonical baseline घोषित करना उचित नहीं।
4. मौजूदा workflow के push-path filter में `20261114040000` शामिल नहीं है; इसलिए उस dependency migration में बदलाव अपने-आप इस workflow को trigger नहीं करेगा।

**सुरक्षित निष्कर्ष:** अभी synthetic fixture पर Atomic migration test उपयोगी सीमित contract test है, लेकिन full migration-chain replay नहीं। पूरा dependency migration workflow में जोड़ने से पहले एक स्पष्ट, versioned और reproducible base schema तय करना होगा—जिसमें Supabase Auth roles/schema, booking/profile/wallet/job-offer tables, आवश्यक columns, helper functions और extensions शामिल हों। उसके बाद disposable local stack पर क्रम से baseline → `20261114040000` → `20261114090000` → pgTAP चलाया जाए। Baseline तैयार किए बिना fixture में अनुमान से columns/tables जोड़ना false-green test दे सकता है।

**अगला gate:** canonical baseline चुनने के लिए migration history/root setup का table-column-function dependency matrix बनाना; फिर disposable local PostgreSQL/Supabase stack पर केवल CI runner में replay। किसी hosted Supabase project, Production, payment provider या shared branch का उपयोग नहीं। इस audit में कोई workflow dispatch या test execution नहीं हुआ।


## 51. Payment test baseline — प्रथम dependency matrix (static source pass)

Feature branch की migration list (58 SQL files) और payment flow के पहले वाले प्रमुख migrations का source review किया। नीचे केवल प्रत्यक्ष source dependencies दर्ज हैं; यह अभी complete schema manifest नहीं है।

| Migration | प्रत्यक्ष काम / dependency |
|---|---|
| 20261109010000_create_secure_wallet_ledger_foundation.sql | srk_wallet_accounts, srk_wallet_ledger, srk_wallet_bank_links बनाती है; Auth users से FK और RLS/grants जोड़ती है। |
| 20261114000000_electrician_requested_and_approved_rate_tiers.sql | पहले से मौजूद electrician_applications, electrician_profiles, Auth users पर columns/FK; rate-tier audit और private authorization table जोड़ती है। |
| 20261114010000_customer_booking_category_and_duration.sql | पहले से मौजूद service_bookings पर category/duration columns तथा Admin offer RPC अपडेट। |
| 20261114030000_verified_electrician_skills_and_category_matching.sql | electrician_applications, electrician_profiles, Auth users; skill catalog/rules/audit tables और category matching RPCs। |
| 20261114040000_server_authoritative_labour_timer_and_bill_snapshot.sql | पहले से मौजूद service_bookings, electrician_profiles, srk_wallet_ledger, job_offers, Auth users तथा कई prior RPC/columns; labour bill, timer authorization, cash-cycle tables और अनेक workflow/accounting RPCs। |
| 20261114090000_atomic_razorpay_order_and_payment_finalization.sql | पहले से मौजूद booking + immutable labour-bill contract; order-lock private table और service-only claim/link/release/finalize RPCs। |

### Test baseline में अभी स्पष्ट रूप से शामिल करने योग्य prerequisites

- Supabase local Auth schema/roles और auth.users fixture identities (केवल synthetic IDs) ताकि FK और auth.uid()/JWT-claim checks वैध रूप से जाँचे जा सकें।
- Starter booking schema में 140000–140400 द्वारा उपयोग किए जाने वाले सभी service_bookings columns, constraints और trigger dependencies। केवल payment fixture के 13 columns पर्याप्त नहीं हैं।
- electrician_applications, electrician_profiles और आवश्यक job_offers columns/relationships।
- Wallet foundation migration 090100 को 140400 से पहले लागू करना, क्योंकि 140400 सीधे srk_wallet_ledger का constraint बदलती है और ledger RPCs पढ़ती/लिखती है।
- 140400 से पहले मौजूद helper functions, private authorization schemas/tables और trigger functions जिनका उपयोग उसके body में है। हर CREATE OR REPLACE FUNCTION पहले से मौजूद table/column references को compile-time/runtime पर जाँचने के लिए पूरे baseline के साथ चलना चाहिए।
- 140400 के बाद 140900; तभी 140900 के immutable labour bill lookup और payment lock/finalizer का वास्तविक migration-order test होगा।

### Root setup पर सावधानी

SUPABASE_SCHEMA.sql में core booking/profile tables हैं, पर wallet foundation नहीं; PORTAL_SCHEMA.sql Auth-linked Admin/profile additions करता है; COMPLETE_DATABASE_SETUP.sql दोनों के duplicated/consolidated रूप रखता है। इनमें से किसी को अकेले इस feature migration chain का प्रमाणित canonical baseline नहीं माना गया। पहले exact columns, constraints, functions, schemas और migration ledger का crosswalk बनाना बाकी है।

**स्थिति:** यह matrix source-level है। Migration parser, PostgreSQL replay, pgTAP और concurrent test अभी नहीं चले। कोई Production query/write, workflow dispatch या Supabase branch creation नहीं हुई।


## 52. Labour Timer Migration — प्रत्यक्ष schema footprint का विस्तृत मिलान

Migration `20261114040000_server_authoritative_labour_timer_and_bill_snapshot.sql` (2,678 lines) को सीधे पढ़कर migration द्वारा बनाए/बदले गए objects और बाहर से अपेक्षित objects अलग किए।

### इस migration द्वारा बनाए जाने वाले मुख्य objects

- Tables: `srk_booking_labour_bills`, `srk_private.work_timer_authorizations`, `electrician_cash_cycles`, `cash_offer_reservations`।
- `service_bookings` में timer elapsed/origin और immutable rate-tier snapshot के पाँच columns; timer और snapshot validity constraints।
- `srk_wallet_ledger` पर cash-cycle संबंधी बदलाव/constraints।
- Triggers: immutable labour bill guard, server timer guard, cash-offer reservation handler और cancellation पर pre-work cash-cycle release।
- Payment-facing helper: `srk_service_get_labour_bill_for_payment(uuid)`; यह migration उसी immutable bill से payment amount पढ़ने का contract स्थापित करती है।

### Migration से पहले उपलब्ध होने वाले प्रमुख objects

इस migration में `CREATE TABLE` न मिलने के बावजूद निम्न objects को read/write/alter किया जाता है; इसलिए baseline/पूर्व migrations में इनका पूरा schema होना चाहिए:

- `public.service_bookings` — status, customer/electrician assignment, selected category, timer, completion approval, payment, quote, cancellation और refund संबंधी columns।
- `public.electrician_profiles` — profile/user linkage, verification और approved rate tier संबंधी fields।
- `public.job_offers` — booking/electrician offer और cash-cycle state।
- `public.srk_wallet_ledger` — migration इसे alter भी करती है; Wallet Foundation `20261109010000` पहले चलना चाहिए।
- `public.srk_wallet_accounts`, `public.srk_wallet_bank_links`।
- अन्य accounting/workflow relations जिनका उपयोग migration में है: `srk_booking_complaints`, `srk_manual_payment_entries`, `srk_electrician_payouts`, `srk_razorpay_refunds`, `srk_booking_refund_requests`, `srk_customer_category_skill_rules`।
- Supabase `auth.users`, `auth.uid()`, `auth.jwt()`, और Supabase roles/schema।
- पहले से मौजूद Admin/auth helper जैसे `is_srk_admin()`; साथ ही पुराने RPCs/trigger contracts जिनको migration replace या wrap करती हैं।

### Test baseline के लिए निष्कर्ष

यह migration isolated payment fixture में अकेले जोड़ने योग्य नहीं है। सही replay chain के लिए केवल table names नहीं, बल्कि ऊपर के relations के आवश्यक columns, FK targets, unique/check constraints, trigger order, grants/RLS, helper function signatures और referenced return columns भी baseline में होने चाहिए। Migration में dynamic SQL/conditional branches भी हैं; इसलिए regex-आधारित सूची पूर्ण dependency proof नहीं है।

**स्थिति:** यह विस्तृत source footprint है, PostgreSQL parser/replay नहीं। कोई test execution, Production query/write, workflow dispatch या hosted Supabase branch creation नहीं की गई। अगला audit pass हर बाहरी relation के exact referenced columns और prerequisite migration owner को crosswalk करेगा।


## 53. Prerequisite migrations का क्रम — Source Cross-check

Feature branch में उपलब्ध चार prerequisite migrations और Wallet Foundation को सीधे fetch करके क्रम/भूमिका का मिलान किया:

| क्रम | Migration | 140400 के लिए योगदान |
|---|---|---|
| 1 | `20261109010000_create_secure_wallet_ledger_foundation.sql` | `srk_wallet_accounts`, `srk_wallet_ledger`, `srk_wallet_bank_links`; Auth users और electrician profile linkage पर निर्भर। |
| 2 | `20261114000000_electrician_requested_and_approved_rate_tiers.sql` | `electrician_applications.requested_category`; `electrician_profiles` के approved rate-tier और approval audit fields/tables। |
| 3 | `20261114010000_customer_booking_category_and_duration.sql` | `service_bookings.selected_category` और `selected_duration_hours`; category/duration validation और Admin offer RPC update। |
| 4 | `20261114030000_verified_electrician_skills_and_category_matching.sql` | Applications/Profiles पर requested/approved skills और skill catalog/rules/matching infrastructure। |
| 5 | `20261114040000_server_authoritative_labour_timer_and_bill_snapshot.sql` | ऊपर की schema पर labour bill, timer, wallet cash-cycle और payment bill lookup। |
| 6 | `20261114090000_atomic_razorpay_order_and_payment_finalization.sql` | Immutable bill lookup contract पर order lock/link/release और captured payment finalizer। |

### महत्वपूर्ण सीमा

यह सूची आवश्यक feature-specific क्रम को पुष्ट करती है, पर पूर्ण replay chain अभी नहीं है। 140400 में `job_offers`, `srk_booking_complaints`, `srk_manual_payment_entries`, `srk_electrician_payouts`, `srk_razorpay_refunds`, `srk_booking_refund_requests` और `srk_customer_category_skill_rules` जैसे अतिरिक्त objects भी उपयोग होते हैं। इनके exact creator migration, prerequisite columns और function signatures का अलग crosswalk बाकी है। Root setup files में किसी object का मिलना अपने-आप migration chain में उसका सही स्थान सिद्ध नहीं करता।

`20261109010000` के wallet helper में `electrician_profiles` का `auth_user_id/user_id` linkage पढ़ा जाता है; इसलिए Wallet Foundation को चलाने से पहले profile base और ये linkage columns उपलब्ध होने चाहिए। केवल तारीख के आधार पर migrations को replay करना पर्याप्त नहीं—base schema की readiness भी जरूरी है।

**स्थिति:** Source cross-check only; no SQL execution/pgTAP. यह section 51–52 की dependency सूची को refine करता है, complete baseline certification नहीं।


## 54. अतिरिक्त Accounting/Support Tables — Creator Migration की स्थिति

Feature branch के source search और संबंधित migration files के प्रत्यक्ष निरीक्षण में यह अंतर मिला:

- `20261114200000_customer_payment_refund_history_rpc.sql` payment-history RPC बनाती है, लेकिन `srk_manual_payment_entries`, `srk_booking_refund_requests`, `srk_razorpay_refunds` और `srk_manual_refund_entries` को पहले से मौजूद मानती है। इसे इन tables का creator migration नहीं माना जा सकता।
- `20261113230000_support_attachment_paths_and_admin_message_list.sql` complaint attachment/message RPCs उपयोग करती है; `srk_booking_complaints` की base table इस migration में create नहीं होती।
- `20261109003000_secure_commission_reporting.sql` commission reporting RPCs पर केंद्रित है; यह `srk_electrician_payouts` का स्पष्ट CREATE TABLE owner नहीं मिला।
- `srk_manual_payment_entries`, `srk_electrician_payouts` और `srk_customer_category_skill_rules` के लिए इस pass में feature branch के indexed source results से निश्चित creator migration प्रमाणित नहीं हुआ। `job_offers` का base DDL root setup files में दिखता है, लेकिन canonical migration ownership अभी तय नहीं।

### निष्कर्ष / जोखिम

इन tables को fixture में अनुमान से बनाना वास्तविक schema contract को छिपा सकता है। प्रत्येक table के लिए authoritative DDL, FK/unique/check constraints, RLS/policies, grants और trigger definitions ढूँढना जरूरी है। यदि वे केवल root setup scripts या किसी अन्य feature branch में हैं, तो उसे स्पष्ट baseline decision के रूप में दर्ज करना होगा—बिना Production schema export के।

**अगला कदम:** Git history और सभी relevant migration filenames/branches में इन पाँच accounting/support tables के मूल DDL का provenance trace; जब तक यह न मिले, पूर्ण migration replay को blocked रखें। कोई SQL test या Production query नहीं चली।


## 55. Creator Migration Cross-check — दो महत्वपूर्ण स्रोत मिल गए

इस pass में पहले unresolved सूची के दो हिस्सों के वास्तविक creator migrations प्रमाणित हुए:

1. `20261114030000_verified_electrician_skills_and_category_matching.sql` सीधे `srk_customer_category_skill_rules` बनाती है; साथ में `srk_electrician_skill_catalog`, `srk_customer_category_skill_rule_audit` और `srk_electrician_skill_audit` भी बनते हैं। इसलिए इस table को अब unresolved creator सूची से हटाया गया।
2. `20261114100000_reproducible_labour_only_refund_foundation.sql` सीधे `srk_razorpay_refunds`, `srk_manual_refund_entries` और `srk_booking_refund_requests` बनाती है। `20261114130000_durable_razorpay_refund_provider_reconciliation.sql` आगे `srk_razorpay_refund_events` बनाती है। `20261114200000_customer_payment_refund_history_rpc.sql` इन tables का creator नहीं, बल्कि consumer/read RPC है।

Support chain का cross-check:
- `20261113180000_customer_support_messages_and_attachments.sql` `srk_booking_complaint_messages` बनाती है।
- `20261113190000_admin_support_replies_and_attachment_linking.sql` `srk_booking_complaint_message_attachments` बनाती है।
- `20261113220000_customer_complaint_creation_rpc.sql` और `20261113230000_support_attachment_paths_and_admin_message_list.sql` complaint base table को पहले से मौजूद मानती हैं; `srk_booking_complaints` का creator इस feature branch के reviewed sources में अभी नहीं मिला।

अभी भी unresolved:
- `srk_manual_payment_entries` — creator migration प्रमाणित नहीं।
- `srk_electrician_payouts` — creator migration प्रमाणित नहीं।
- `srk_booking_complaints` — base DDL प्रमाणित नहीं; केवल related message/attachment tables के creators मिले।
- `job_offers` — base DDL `SUPABASE_SCHEMA.sql` और `COMPLETE_DATABASE_SETUP.sql` में मिला, लेकिन canonical migration baseline/ordering प्रमाणित नहीं।

ये निष्कर्ष source-level file inspection पर आधारित हैं। कोई SQL execution, PostgreSQL replay, pgTAP, Production query या write नहीं हुआ।


## 56. Manual Payment और Payout Tables — पहली निर्भरता और Baseline Gap

Feature branch के source को प्रत्यक्ष खोलकर यह क्रम सत्यापित किया:

- `20261112220000_cash_platform_fee_due_and_online_settlement.sql` शुरुआत में `srk_electrician_payouts` पर `ALTER TABLE` करता है; उसी migration में `srk_manual_payment_entries` पढ़ी/लिखी जाती है और `srk_electrician_payouts` में payout row insert/update होती है। यह दोनों tables की Creator Migration नहीं है; ये इस तारीख तक पहले से मौजूद होनी चाहिए।
- `20261114140000_manual_labour_only_refund_workflow.sql` `srk_manual_payment_entries` और `srk_electrician_payouts` को `%ROWTYPE`, SELECT और UPDATE के जरिए इस्तेमाल करती है; इसका अपना CREATE TABLE केवल `srk_manual_refund_intents` है।
- Reviewed root setup files (`SUPABASE_SCHEMA.sql`, `COMPLETE_DATABASE_SETUP.sql`, `PORTAL_SCHEMA.sql`, `ADMIN_EMAIL_LOGIN_SETUP.sql`, `PORTAL_SECURITY_UPDATE.sql`) में `srk_manual_payment_entries`, `srk_electrician_payouts` और `srk_booking_complaints` की base CREATE TABLE DDL नहीं मिली।
- `job_offers` का base CREATE TABLE `SUPABASE_SCHEMA.sql` और `COMPLETE_DATABASE_SETUP.sql` में मौजूद है; लेकिन इसे numbered migration में बदलने/लागू करने का canonical baseline अभी प्रमाणित नहीं।
- GitHub code search में इन तीन unresolved tables के explicit CREATE TABLE results नहीं मिले। Search index सीमित हो सकता है; इसलिए यह पूरे Git इतिहास या निजी/अन्य repositories में अनुपस्थिति का प्रमाण नहीं है।

### Dependency blocker

Migration chain कम-से-कम `20261112220000` तक पहुँचने से पहले `srk_electrician_payouts` और `srk_manual_payment_entries` का authoritative schema उपलब्ध होना चाहिए। इनके columns, constraints, indexes, RLS, grants और triggers बिना प्रमाण के fixture में गढ़ना उचित नहीं। `srk_booking_complaints` की base table भी support RPCs के लिए आवश्यक है।

**स्थिति:** Creator provenance अभी unresolved; full replay blocked. केवल source inspection; कोई SQL execution, test, Production query/write या workflow dispatch नहीं।


## 57. पुराने Portal Branch में दो Missing Creator Sources मिले

`work/separate-customer-electrician-portals` branch की migration सूची और files प्रत्यक्ष जाँचने पर:

1. **`srk_manual_payment_entries`** — `20261109171621_add_admin_verified_manual_payment_workflow.sql` इसे `CREATE TABLE IF NOT EXISTS` से बनाती है। DDL में `booking_id` UNIQUE/FK, payment method allow-list (`cash`,`upi`,`bank_transfer`), positive bounded amount, required payment reference, optional note, actor और timestamp हैं। Table पर RLS enable है और PUBLIC/anon/authenticated से सभी direct privileges revoke हैं। यह source candidate है; feature branch की पूरी ancestry/merge lineage अभी प्रमाणित नहीं।
2. **`srk_booking_complaints`** — `20261110040000_customer_admin_complaints.sql` इसे बनाती है; उसी file में complaint status events table भी बनती है। DDL में booking/customer FKs, category/status allow-lists, description length bounds, admin note और resolution/audit fields हैं। यह भी पुराने Portal branch का source candidate है, अभी feature branch ancestry का प्रमाण नहीं।
3. **`srk_electrician_payouts`** — पुराने Portal branch की जाँची migrations (`20261109165802`, `20261109173000`, `20261109180001`, `20261109234500`, `20261111090000`) केवल table को alter/use/harden करती हैं; इनमें base `CREATE TABLE` नहीं मिला। उसी branch के reviewed root setup files में भी base DDL नहीं मिला। इसका Creator अभी unresolved है।

### Replay implication

अब manual-payment और complaints के लिए plausible historical Creator migrations मौजूद हैं, पर उन्हें सीधे वर्तमान replay chain में जोड़ना उचित नहीं: पहले commit ancestry/merge-base और subsequent schema evolution की तुलना करनी होगी। Payout table का authoritative base DDL अभी नहीं मिला; इसलिए `20261112220000_cash_platform_fee_due_and_online_settlement.sql` की पूर्ण dependency chain अभी भी blocked है।

सभी निष्कर्ष static source inspection हैं। कोई SQL execution, PostgreSQL replay, pgTAP, Production query/write या workflow dispatch नहीं हुआ।


## 58. Portal Branch की Ancestry तुलना — Creator Files की स्थिति

GitHub compare के अनुसार `feature/platform-fee-cash-online-cycle` और `work/separate-customer-electrician-portals` **diverged** हैं। इनका common merge-base `fee88290a5c2f940b5307e76320f88ca9346e183` है; Portal branch उस base से 151 commits आगे और Feature branch 1,270 commits आगे है। इसलिए Portal branch की पुरानी migration files को वर्तमान Feature branch की लागू migration history मान लेना सुरक्षित नहीं है।

### Table creator evidence का अद्यतन

- `srk_manual_payment_entries`: Portal branch में `20261109171621_add_admin_verified_manual_payment_workflow.sql` वास्तविक `CREATE TABLE` source है, लेकिन यह Feature branch की ancestry में शामिल होने का प्रमाण नहीं है।
- `srk_booking_complaints`: Portal branch में `20261110040000_customer_admin_complaints.sql` वास्तविक `CREATE TABLE` source है, लेकिन वही ancestry सीमा लागू है।
- `srk_electrician_payouts`: Portal branch की जाँची migration files और reviewed root setup files में base creator नहीं मिला।
- Audit branch की `20261114125844_restore_financial_audit_core_schema.sql` में manual-payment और payout tables की `CREATE TABLE IF NOT EXISTS` definitions हैं। यह audit/replay preparation के दौरान जोड़ी गई restoration migration है; इसे पुराना historical creator या Feature branch में पहले से मौजूद source नहीं माना जा सकता।

### निर्णय

दो tables के historical candidate creators अब पहचाने गए, पर Feature branch की वास्तविक ancestry/production provenance साबित नहीं हुई। Payout table के लिए भी audit branch restoration DDL मौजूद है, मगर उसका मूल historical origin अब भी unresolved है। किसी भी candidate migration को बिना schema diff, ancestry और dependency-order review के replay manifest में authoritative baseline के रूप में promote न करें। No SQL execution/tests/Production access/workflow dispatch.


## 59. Payout Ledger के शुरुआती Product Commits की जाँच

Repository commit search से ये पुराने commits मिले और diff/source स्तर पर जाँचे:

- `a2a1fafd2c9d2dc09b782a4f838dec4cad3afdb6` — **Add secure admin electrician payout ledger controls**. Diff में Admin UI payout rows पढ़ती और भुगतान रिकॉर्ड करती है, लेकिन इस commit diff में payout table का `CREATE TABLE` DDL नहीं है।
- `0d2fd2ba2e97160ac3d0a82741377a45a9384310` — **Show electrician manual UPI and bank payout status**. Electrician UI `srk_electrician_payouts` पढ़ती है और `electrician_profile_id`, `electrician_payable`, `payout_status`, `payout_method`, `payout_reference`, `paid_at` fields उपयोग करती है। यह table के पहले से मौजूद होने की अपेक्षा दिखाता है, Creator नहीं बताता।
- `c75874578d4ba962ffc8b005d48e9bcd2ba592a8` — Manual UPI/Bank payout workflow documentation बताती है कि database pending payout row बनाता है और Admin बाहरी transfer के बाद UTR दर्ज करता है; यह भी schema DDL या migration provenance नहीं देता।

Commit search में `srk_create_electrician_payable`, `srk_admin_mark_electrician_payout_paid`, `srk_get_my_earnings` और payout table के exact CREATE statement के लिए कोई creator commit surfaced नहीं हुआ। Search coverage सीमित है; इसे पूरे Git history में अनुपस्थिति का निर्णायक प्रमाण न मानें।

### वर्तमान निष्कर्ष

Payout ledger पुराने product/UI contract में पहले से अपेक्षित था, लेकिन उपलब्ध commit diffs और जाँची migrations में उसका original base DDL अभी नहीं मिला। Audit branch की `20261114125844_restore_financial_audit_core_schema.sql` में payout table की restoration definition है; यह वर्तमान replay के लिए candidate schema है, historical source/provenance का प्रमाण नहीं। इस dependency को unresolved ही रखें। No SQL execution/tests/Production access/workflow dispatch.


## 60. पुराने Business-Finance और Payout-Security Branches की जाँच

अतिरिक्त branches के SQL स्रोत जाँचे:

- `feature/business-finance-dashboard` की `20261110080448_srk_business_finance_dashboard.sql` payout table का creator नहीं है; इसमें `private` schema object बनता है। `20261111043852_srk_business_finance_reporting_dates.sql` भी payout table का base DDL नहीं बनाती।
- उसी branch के `SUPABASE_SCHEMA.sql`, `COMPLETE_DATABASE_SETUP.sql`, `PORTAL_SCHEMA.sql`, `PORTAL_SECURITY_UPDATE.sql` में `srk_electrician_payouts` का कोई उल्लेख/creator नहीं मिला।
- `feature/direct-upi-commission-15` branch में `20261109160000_guard_payout_upi_profile_fields.sql` payout UPI profile fields की सुरक्षा/alteration migration के रूप में मौजूद है; यह base table creator नहीं है।
- `predeploy/verified-electrician-booking-match` में `20261109190500_harden_quote_and_payout_rpc_null_validation.sql` payout RPC validation harden करती है; base payout table creation नहीं।
- `main` branch की migration list में payout base creator नहीं दिखा; यह list inspection है, पूर्ण historical absence का प्रमाण नहीं।

### निष्कर्ष

पुराने Business-Finance, direct-UPI और predeploy branches में payout table पहले से मौजूद होने की धारणा पर आधारित migrations/RPC/UI references मिले, पर मूल `CREATE TABLE srk_electrician_payouts` migration अभी नहीं मिली। इसलिए payout schema का historical origin unresolved है। Audit branch restoration DDL को केवल reconstruction candidate मानें, verified original baseline नहीं।

सभी कार्य repository source/list inspection तक सीमित रहे। कोई SQL run/replay, pgTAP, Node test suite, Production query/write, workflow dispatch या branch merge नहीं हुआ।


## 61. पुराने Migration Branches में Payout Table Creator की विस्तृत तलाश

Payout/finance/electrician/manual-payment/commission/settlement नाम वाले migration files को अतिरिक्त पुराने branches में scan किया:

| Branch | कुल migration files | नाम के आधार पर संबंधित files जाँचीं | `CREATE TABLE public.srk_electrician_payouts` |
|---|---:|---:|---|
| `work/separate-customer-electrician-portals` | 37 | 15 | नहीं मिला |
| `feature/platform-fee-cash-online-cycle` | 58 | 10 | नहीं मिला |
| `feature/direct-upi-commission-15` | 17 | 5 | नहीं मिला |
| `safe-payment-refund-implementation` | 14 | 3 | नहीं मिला |
| `main` | 20 | 3 | नहीं मिला |

यह targeted scan है: केवल नाम से संबंधित migration files के content जाँचे गए, हर SQL file का exhaustive scan नहीं। पहले देखे गए predeploy और reference-correction migrations भी payout table को पहले से मौजूद मानकर RPC/trigger/security बदलाव करते हैं।

### Workflow dependency का अतिरिक्त संकेत

Default-branch code search में `.github/workflows/supabase-schema-ci.yml` के schema assertion में `to_regclass('public.srk_electrician_payouts') IS NULL` होने पर failure है। यह साबित करता है कि CI इस table को आवश्यक मानता है; यह table creation या historical provenance साबित नहीं करता।

### निष्कर्ष

अब तक जाँचे गए Feature, Portal, Finance, Direct-UPI, Predeploy, Safe-Payment और Main branch स्रोतों में payout ledger का मूल base-table DDL नहीं मिला। यह अभी भी unresolved dependency है। अगले चरण में नाम-आधारित targeted scan से आगे बढ़कर Git history में `srk_electrician_payouts` वाले earliest introducing commits और उसके संभावित alternate table names/DDL खोजे जाएँगे।

कोई SQL execute/replay, test suite, Production access, workflow dispatch, या merge नहीं किया गया।


## 62. GPT-2 Blocker Review — accounting bridge regression gate added

> Follow-up correction: Section 64 supersedes the initial test-first-only status. A new additive migration now adds normalized method consistency and a dedicated mismatch exception; latest test commit is `63fb2dd7507c55f242d393a1512bb16ef3576d39`. Runtime remains NOT RUN.

उपयोगकर्ता के निर्देश के अनुसार पाँच Blockers, संबंधित pgTAP और Runtime verification पर अगला pass शुरू किया गया।

### इस pass में प्रमाणित defect और test change

- `20261115150000_admin_readonly_booking_accounting_reconciliation.sql` के `srk_admin_get_booking_accounting_reconciliation(uuid)` में manual payment evidence के लिए booking ID और amount जाँचे जाते हैं, लेकिन `mp.payment_method` को `v_booking.payment_method` से compare नहीं किया जाता।
- इससे manual payment entry और booking row में Cash/UPI/Bank method अलग होने पर reconciliation exception छूट सकता है।
- Regression gate जोड़ा: `supabase/tests/database/admin_labour_bill_payment_accounting_bridge.test.sql` का pgTAP plan 15 से 16 किया और assertion जोड़ा कि function में `mp.payment_method is distinct from v_booking.payment_method` guard मौजूद हो।
- Test change commit: `4f07b9ddc90c654f6e22adc08a655358ed86400c`.

### जरूरी सीमा

यह **test-first regression guard** है, SQL defect का समाधान नहीं। मौजूदा function source में यह comparison नहीं मिला, इसलिए यह नया assertion वर्तमान schema पर fail होने की अपेक्षा रखता है, जब तक follow-up SQL fix लागू न हो। Historical migration को in-place बदलना उचित नहीं; नई ordered migration बनाने से पहले authoritative baseline और migration lineage की समीक्षा जरूरी है।

### Verification status

- Source inspection: **DONE**.
- Regression assertion added: **DONE**.
- PostgreSQL/pgTAP execution: **NOT RUN**.
- Migration replay: **NOT RUN**.
- Production query/write, workflow dispatch, deployment, merge: **NONE**.
- पाँचों Blockers: **अभी सभी का समाधान प्रमाणित नहीं**; बाकी चार की जाँच जारी है।


## 63. Commission Reporting बनाम Payout Ledger — AFTER Trigger के अनुरूप Regression Gate

पहले Section 63 में जो assertion `NEW.commission_amount := v_commission` को payout के `AFTER` Trigger function के भीतर अनिवार्य कर रहा था, वह PostgreSQL trigger semantics के अनुसार सही नहीं था: `AFTER` Trigger में `NEW` बदलने से persisted booking row नहीं बदलती। उस assertion को हटाकर जिम्मेदारियाँ अलग की गईं।

- `BEFORE` Trigger `public.srk_set_booking_commission_before_payout()` booking row के `NEW.commission_amount` को authoritative labour-only formula से सेट करता है।
- Existing `AFTER` Trigger `public.srk_create_electrician_payable()` payout ledger बनाता/सुधारता है।
- बाद का `AFTER` parity guard `public.srk_validate_booking_commission_payout_parity()` booking commission और payout ledger के `platform_commission` को compare करता है; mismatch होने पर उसी transaction को fail-closed करता है।
- Accounting reconciliation RPC भी दोनों persisted values की parity जाँचता है।
- Manual payment method mismatch होने पर BEFORE path payout finalization को reject करता है।

### नवीनतम Test gate

`supabase/tests/database/electrician_payout_reconciliation.test.sql` का plan 29 से 32 किया गया। तीन अतिरिक्त assertions:
1. Commission assignment trigger row-level `BEFORE INSERT/UPDATE` है।
2. BEFORE function वही commission formula लगाती है।
3. BEFORE function manual payment method mismatch पर fail-closed करती है और AFTER parity trigger अलग से persisted payout parity enforce करता है।

अंतिम Test commit: `dc2550277dc7f1e92fe285e8f82d782032e15a33`.

यह pgTAP source/trigger-contract test है; अभी PostgreSQL/pgTAP Runtime में execute नहीं हुआ। इसे PASS घोषित नहीं किया गया।

### GPT-2 progress snapshot

- Accounting bridge method consistency regression gate: added (plan 16).
- Payout/Admin commission reporting parity regression gate: corrected for BEFORE/AFTER semantics (plan 32).
- दोनों SQL runtime outcomes: NOT RUN.
- पाँच blockers का final disposition: OPEN / PARTIAL; सभी का समाधान नहीं हुआ।
- Migration replay और Runtime suite: NOT RUN.
- Production access/write, deployment, workflow dispatch, merge: NONE.

## 64. Additive Accounting and Commission Correction — Source Changes Committed

### 64.1 Historical Dollar-Quote defect and lineage status

`supabase/migrations/20261114270000_admin_only_cancellation_requests_and_decisions.sql` contains a malformed function terminator:

```sql
end;
$;
```

The function opens with `as $$`; its closing delimiter is malformed as `$;` and should be `$$;`.

**Lineage is CONFIRMED:** original migration creation commit `3e4a20188d8d183516fc1527e7f83777b8304ca7` used `$$;`. Defect-introducing commit `cd5c0d8a07350fffb6be48c1f2a9481f73342b86` changed `-$$;` to `+$;`. Subsequent inspected path-history commits did not alter that delimiter (full commit evidence in §66).

**Disposition: OPEN — historical file remains unchanged.** The introducing commit is identified, but the user's guardrail still requires explicit permission before editing the historical migration. A disposable replay-only correction can be prepared separately; do not rewrite the committed historical file without approval.

### 64.2 Accounting Bridge method consistency

New additive migration:
`supabase/migrations/20261117010000_reconcile_booking_commission_and_manual_payment_method.sql`

The migration preserves the full original reconciliation RPC body and adds:
- normalized, non-null comparison of manual evidence `payment_method` with booking `payment_method`;
- explicit `MANUAL_PAYMENT_METHOD_MISMATCH` exception;
- booking/payout commission parity exception `BOOKING_COMMISSION_PAYOUT_LEDGER_MISMATCH`.

Migration commits:
- Initial migration: `6b361652ee49cb36a9b8680d309b9f2ec83d8b5`
- Null/status and fail-closed corrections: `29d007145e214eb04e432ca49a6e80b47f5f5f4a`, `32b55dde9376a97e3d984da848e6eec975778b3e`
- Preserve full original reconciliation function and add parity checks: `cdb4bf4b9453f395113245a725902670e449f1f4`
- Payout-backed reports and trigger event coverage: `43c19084b5cf4a50902550a4180bc6f7a1f8c079`
- Payout ledger is the sole commission source in reports: `f3cf06df07009b8378b23e26649fea5bc8166736`

Regression test:
`supabase/tests/database/admin_labour_bill_payment_accounting_bridge.test.sql`, plan 19; latest test commit `6e7e132ac800cc99249272650daaad4f7138e2d2`.

### 64.3 Commission BEFORE/AFTER separation and parity

The same additive migration:
- adds row-level BEFORE trigger `zz_srk_set_booking_commission_before_payout` to persist `commission_amount`;
- keeps existing payout ledger writer as the AFTER trigger;
- adds a later AFTER parity validator `zz_srk_validate_booking_commission_payout_parity` which checks the persisted payout row against the booking commission and raises on mismatch;
- uses a manual payment method consistency guard before payout finalization.

Regression test:
`supabase/tests/database/electrician_payout_reconciliation.test.sql`, plan 34; latest test commit `f44ee3d78f8d7ba66e96cda6746d5777a727829d`.

### 64.4 Static verification and limitations

- GitHub file fetch confirms the additive migration and both updated pgTAP files exist on the audit branch.
- Static comparison confirms the replacement reconciliation function was reconstructed from the full existing function before applying the targeted additions.
- Test plans match static assertion inventory: Accounting Bridge plan 19 (18 `ok()` plus 1 `has_function()`); Payout Reconciliation 34/34 `ok()` assertions. Runtime remains NOT RUN.
- PostgreSQL parser: **NOT RUN**.
- Migration Replay: **NOT RUN**.
- pgTAP Runtime: **NOT RUN**.
- Full Node Runtime: **NOT RUN**.
- Five primary migration/dependency blockers: **not all resolved**; canonical baseline, helper provenance, payout/manual-payment/complaint table provenance, and migration-history reconciliation remain open.
- Production queries/writes, deployment, workflow dispatch, merge: **NONE**.



## 65. Disposable Runtime Environment Availability Check

इस turn में local execution environment को दोबारा जाँचा गया:

- `psql`: unavailable
- `postgres`: unavailable
- `docker`: unavailable
- `podman`: unavailable
- `supabase` CLI: unavailable
- Python parser/runtime modules `pglast`, `sqlparse`, `psycopg`, `psycopg2`: unavailable
- Repository `supabase/` directory में `config.toml` भी नहीं मिला।

इसलिए इस environment में PostgreSQL Parser, Migration Replay या pgTAP Runtime चलाने का सुरक्षित साधन उपलब्ध नहीं है। Production project या अधूरे historical test project पर इसे substitute नहीं किया गया। किसी GitHub workflow को dispatch नहीं किया गया।

**Runtime disposition: NOT RUN — environment unavailable.** Disposable PostgreSQL runtime स्थापित होने तक कोई PASS claim नहीं है।

## 66. Dollar-Quote Defect — Introducing Commit Identified

Path history for `supabase/migrations/20261114270000_admin_only_cancellation_requests_and_decisions.sql` was retrieved directly from GitHub.

- Original migration-creation commit: `3e4a20188d8d183516fc1527e7f83777b8304ca7` (`feat(cancellation): add admin-only cancellation request workflow`). Its added file uses the correct closing delimiter `$$;`.
- Defect-introducing commit: `cd5c0d8a07350fffb6be48c1f2a9481f73342b86` (`Revoke public execute on cancellation guard trigger function`). Its exact diff changes `-$$;` to `+$;`.
- Subsequent path-history commits `c7d262309592c32860df2d376aea074d373a16d9`, `823355c06a85aad224014e84cb6a1ca32c17df23`, `59b4eba912d61bb4f6e702415801d08e839d50e1`, and `a2a0ff7945a12af96581ffef0c71c4be38a55ede` do not contain a dollar-delimiter change.

**Lineage conclusion: CONFIRMED.** The malformed delimiter was introduced by commit `cd5c0d8a07350fffb6be48c1f2a9481f73342b86`, not by the original migration authoring commit.

**File disposition remains unchanged pending explicit historical-migration edit approval.** The user guardrail says not to change historical migrations without Lineage Approval. The introducing commit is now identified, but no historical file edit has been made in this step. The defect still blocks full parser/replay verification.

Runtime remains NOT RUN; no Production activity, deployment, workflow dispatch, or merge occurred.


## 67. Follow-up: Payout-backed reporting and trigger-order coverage

Audit-branch source commits: `43c19084b5cf4a50902550a4180bc6f7a1f8c079` (report/trigger changes) and `f3cf06df07009b8378b23e26649fea5bc8166736` (payout-ledger-only commission source).

- The AFTER parity validator's `UPDATE OF` list now includes `materials_amount`, matching the existing payout writer's update event list, and includes `commission_amount` so direct privileged edits are also checked.
- The existing payout writer trigger is named `srk_reconcile_electrician_payable`; the parity validator is named `zz_srk_validate_booking_commission_payout_parity`. PostgreSQL fires same-kind triggers alphabetically, so the intended order is payout write first, parity check second. The updated pgTAP suite asserts both trigger names/order and event coverage.
- Replaced `srk_admin_commission_report()` to keep `total_collected` as customer collection while taking payout gross, commission and electrician payable from `srk_electrician_payouts`. This excludes SRK-owned cancellation fees from electrician payable/earnings.
- Replaced `srk_get_my_earnings()` to preserve customer `amount_received` while sourcing commission and electrician payable from the payout ledger.
- Admin booking accounting reconciliation continues to check booking commission against payout `platform_commission` and reports `BOOKING_COMMISSION_PAYOUT_LEDGER_MISMATCH`.

Updated regression tests:
- `electrician_payout_reconciliation.test.sql`: plan 34, 34 `ok()` assertions, latest commit `f44ee3d78f8d7ba66e96cda6746d5777a727829d`.
- `admin_labour_bill_payment_accounting_bridge.test.sql`: plan 19, 18 `ok()` + 1 `has_function()`, latest commit `6e7e132ac800cc99249272650daaad4f7138e2d2`.
- Static test-file structure check: each file has one `finish()` and one `rollback;`. These are source checks only, not runtime results.

**Important remaining verification:** no SQL parser, PostgreSQL replay, or pgTAP runtime was available/run. Report/earnings changes have source-level regression assertions only; no runtime data fixtures have exercised booking insert/update, cancellation fee exclusion, refund reversal, or ledger reconciliation. Do not mark these flows runtime-FIXED until disposable PostgreSQL evidence exists.

## 68. Five primary blocker disposition and current verification gate

| # | File / migration evidence | Actual cause | Correction / evidence | Status |
|---|---|---|---|---|
| 1 | `20261114270000_admin_only_cancellation_requests_and_decisions.sql`; introducing commit `cd5c0d8a07350fffb6be48c1f2a9481f73342b86` | PL/pgSQL function opens with `$$` but closes with `$;` | Lineage confirmed; original creation commit `3e4a20188d8d183516fc1527e7f83777b8304ca7` was correct. Historical file remains unchanged pending explicit edit approval. | **PARTIALLY FIXED** |
| 2 | `COMPLETE_DATABASE_SETUP.sql`, `SUPABASE_SCHEMA.sql`, `PORTAL_SCHEMA.sql`; numbered migrations | Overlapping setup scripts exist, but no owner-approved canonical base-schema migration/baseline | Inventory and dependency notes recorded; baseline provenance and replay contract still missing. | **OPEN** |
| 3 | Setup SQL and early migrations `20261108234000`, `20261109001000`, `20261109001500`, `20261109003000` | `is_srk_admin()` and `srk_is_admin()` are distinct helpers with different call sites; authoritative definitions/grants/order are not established in the numbered chain | Call sites and setup-script origins identified; no approved canonical helper baseline yet. | **OPEN** |
| 4 | `srk_electrician_payouts`, `srk_manual_payment_entries`, `srk_booking_complaints`; related payout/payment migrations | Creator DDL and original constraints/grants/RLS provenance are not fully established in the current Feature migration chain | Downstream consumers and partial legacy/audit-branch evidence identified; authoritative original DDL provenance remains missing. | **OPEN** |
| 5 | Production migration ledger vs Feature Branch numbered files | 87 ledger versions and 87 branch SQL files have only 7 exact version-ID matches; 80 ledger versions lack exact branch prefixes and 78 valid branch IDs are absent from the ledger. Renumbering/consolidation is possible; this is not proof of missing SQL. | Counts recorded; requires owner-approved authoritative ledger/schema-only snapshot and explicit mapping before replay. No Production query/write performed in this step. | **OPEN** |

### Source correction disposition

- Accounting Bridge method consistency and NULL handling: additive migration source corrected; pgTAP plan 19 source assertions added. **PARTIALLY FIXED — runtime NOT RUN**.
- Commission BEFORE calculation / AFTER payout writer / AFTER parity validation: source architecture separated; payout writer trigger name precedes `zz_` parity validator alphabetically; event list now covers `materials_amount` and `commission_amount`. **PARTIALLY FIXED — runtime NOT RUN**.
- Cancellation-fee exclusion in Admin commission report and Electrician earnings: both RPCs now use payout ledger amounts for electrician payable while preserving customer collection separately. **PARTIALLY FIXED — runtime NOT RUN**.
- Financial reconciliation: Admin booking reconciliation compares `service_bookings.commission_amount` with payout `platform_commission` and reports the mismatch exception. **PARTIALLY FIXED — runtime NOT RUN**.
- Booking insert/update, cancellation-fee, refund reversal and ledger behavior have not been exercised with PostgreSQL fixtures in this environment.

### Verification results

- SQL Parser: **NOT RUN**.
- Full Migration Replay: **NOT RUN**.
- pgTAP runtime: **NOT RUN**.
- Node runtime: **NOT RUN**.
- Static source inventory only; no runtime PASS claims.
- Production changes: **NONE**.
- Deployment: **NONE**.
- Workflow dispatch: **NONE**.
- Merge: **NONE**.
- Paid Supabase branch/resource creation: **NONE**.
## 69. Audit branch relationship to PR branch

GitHub compare of `feat/customer-login-first-dashboard-20261114` (base) against `chore/pr8-replay-audit-20261116-v2` (head) reports `diverged`: audit branch is 190 commits ahead and 42 commits behind the PR branch from their merge base. This is a branch-relationship count, not 190 newly authored changes in this task. No rebase, merge, PR update, or PR-branch write was performed. The audit branch remains isolated pending owner review of the divergence.

## 70. Dollar-Quote source correction — verified on Audit Branch

- Historical defect lineage remains: the malformed delimiter was introduced by commit `cd5c0d8a07350fffb6be48c1f2a9481f73342b86`.
- Corrective commit: `f3472a153b11f15acfb38e5879df027dc75a5098` (Audit Branch only).
- Corrected file: `supabase/migrations/20261114270000_admin_only_cancellation_requests_and_decisions.sql`.
- GitHub re-read Blob SHA: `892e7fcd51304ac84efb8ef4d8b251c198127526`; line 76 now ends with `$$;`; zero bare `$;` terminators remain.
- GitHub compare confirms exactly one file changed, one insertion and one deletion: `-$;` to `+$$;`.
- Dollar-quote lexical inventory: 12 `$$` tokens (balanced), 6 function terminators, zero malformed bare dollar-semicolon lines. This is a delimiter sanity check, **not** a PostgreSQL SQL parse.
- PostgreSQL SQL Parser: **NOT RUN** — no PostgreSQL parser binary/package is available in the current execution environment.
- Full Migration Replay: **NOT RUN** — no PostgreSQL server/client, Docker/Podman, or Supabase CLI is available; no disposable database was provisioned.
- pgTAP runtime: **NOT RUN**. No runtime PASS is claimed.
- Production, PR branch, deployment, merge, and workflow dispatch: **NOT TOUCHED**.


## 71. Runtime tooling re-check and safe execution decision

- Local environment re-check: `psql`, `postgres`, `pg_ctl`, Docker, Podman, Supabase CLI, `sqlfluff`, and `pg_format` are unavailable. Python modules `pglast`, `pg_query`, `sqlglot`, `sqlparse`, `psycopg`, and `psycopg2` are also unavailable.
- The repository workflow `.github/workflows/supabase-schema-ci.yml` is not a safe or applicable replay path for this audit: it is `workflow_dispatch` only, hard-gated to `refs/heads/feature/platform-fee-cash-online-cycle`, and exports schema from the configured remote Supabase database before creating its local stack. It does not target this Audit Branch or the full PR #8 migration chain. It was **not dispatched**.
- No Supabase project was queried, created, or modified. No Production connection was used. No external online SQL parser was given repository source.
- Therefore PostgreSQL parser, full migration replay, and pgTAP runtime remain **NOT RUN**. Static delimiter sanity is not a substitute for parser/replay evidence.
- Next safe execution prerequisite: provide an isolated disposable PostgreSQL/Supabase environment populated from an approved schema baseline, or an approved CI workflow that runs the Audit Branch migration chain locally without Production export. Then run parser/lint, ordered full replay, and all relevant pgTAP suites; capture raw logs and resulting commit/test evidence.


## 72. Execution-host and parser-install attempt

- Execution host has Node.js v22.16.0 and npm, but the repository `package.json` declares no PostgreSQL parser dependency and no lockfile was found at the repository root. Node/npm availability alone does not parse PostgreSQL SQL or provide a PostgreSQL server.
- Attempted to install `pglast` for a real PostgreSQL grammar parse; installation could not reach the package index because DNS/network resolution is unavailable. No package was installed and no parser result was produced.
- This confirms the parser blocker is environmental, not a successful or failed SQL parse. Parser, full replay, and pgTAP remain **NOT RUN**.
- No source migration or tests were changed in this step. No workflow was dispatched and no database was accessed.


## 72. GPT-2 baseline re-check on current Audit Branch head — 17 Nov 2026

**Read-only source evidence:** Audit Branch head before this report update: `e7c323c08236e76dae67adcfc10973f4f462e427`. No database connection or SQL execution was performed.

### Current repository inventory

- Recursive Git tree reports **89** files under `supabase/migrations/` on this Audit Branch (the earlier 87-file count is stale for this head).
- The two malformed legacy filenames remain present:
  - `20261109_allow_quote_approval_booking_states.sql`
  - `20261109_electrician_inspection_quotes_and_service_only_commission.sql`
- `supabase/config.toml` remains absent.
- Four standalone SQL setup artifacts were re-read directly from GitHub:
  - `SUPABASE_SCHEMA.sql` — Blob SHA `8ae88a7035bc963b244f22c6c1450c22618ec88f`; 4 explicit base-table definitions: service_bookings, electrician_applications, electrician_profiles, job_offers.
  - `PORTAL_SCHEMA.sql` — Blob SHA `efc14aa623a3895ffb3841b7b0f226f2015f34b1`; 1 explicit table definition (srk_admin_users), 5 function definitions, 10 policy definitions.
  - `COMPLETE_DATABASE_SETUP.sql` — Blob SHA `2b806e727f449ba18e71ad23edef805ceb2da2b5`; 5 explicit base-table definitions (the four above plus srk_admin_users), 7 function definitions, 17 policy definitions.
  - `ADMIN_EMAIL_LOGIN_SETUP.sql` — Blob SHA `dbd91b3f912b1e0946bffe6d249a85cc41dc81cd`; no table definitions, 2 function definitions, 7 policy definitions.
  
### Baseline conclusion

The source artifacts establish a **candidate legacy base**, not an approved canonical baseline. `COMPLETE_DATABASE_SETUP.sql` consolidates five base tables, but its presence does not prove equivalence to the intended clean-install schema or the deployed schema. `PORTAL_SCHEMA.sql` and `ADMIN_EMAIL_LOGIN_SETUP.sql` overlap with the consolidated setup and define Admin functions/policies on different setup paths. The helper names `srk_is_admin()` and `is_srk_admin()` remain distinct objects and must retain separately verified definitions/grants.

Therefore GPT-2 will not synthesize or apply an executable baseline by guessing. The next safe source-only task is to finish the object-by-object baseline/consumer matrix (columns, constraints, indexes, triggers, functions, policies, grants, Auth/Storage assumptions) and mark which entries are source-proven versus owner/remote-history dependent. Full replay and pgTAP remain **NOT RUN** until the baseline is approved and a disposable PostgreSQL/Supabase harness exists.

**Safety:** No Production query, remote migration-history read, database write, workflow dispatch, deployment, merge, payment, or customer/Auth data access occurred.


## 73. Source-backed dependency matrix expansion — support, finance, push, RBAC and SOS — 17 Nov 2026

**Scope:** exact Audit Branch migration files re-read from GitHub. Static DDL/reference inventory only; no PostgreSQL parser, SQL execution, database connection, migration replay, pgTAP, Production query, or deployment.

### 73.1 Complaint and support conversation chain — base complaint source located

| Order | Source | Objects introduced/changed | Required predecessors / downstream |
|---|---|---|---|
| 1 | `20261110040000_customer_admin_complaints.sql` | `srk_booking_complaints`, `srk_booking_complaint_events`; customer create/list and Admin list/update RPCs; RLS/revokes/grants | Requires `service_bookings`, `service_bookings.customer_user_id`, `auth.users`, `auth.uid()`; predecessor is customer-account booking access |
| 2 | `20261113220000_customer_support_conversation_schema.sql` | `srk_booking_complaint_messages`, `srk_booking_complaint_message_attachments`; customer message/attachment RPCs and policies | Requires `srk_booking_complaints` from 10040000, Auth, UUID generation; creates composite message/thread unique index before attachment FK |
| 3 | `20261113230000_support_attachment_paths_and_admin_message_list.sql` | Attachment path and Admin message-list RPC changes | Requires complaint, message and attachment tables plus Admin helper; Storage bucket/object-policy provenance is not established by these three table/function definitions alone |
| 4 | `20261114390000_admin_staff_rbac_foundation.sql` | Staff, permissions, role-permissions, sessions, audit events, support assignments; permission-check and support RPCs; complaint message ALTER | Requires Auth users, complaint/message schema, electrician support-ticket schema; later consumers include SOS permissions |

**Correction to earlier wording:** the claim that the complaint base table was not located is superseded. Its introducing DDL is present in `20261110040000_customer_admin_complaints.sql`. The remaining support gap is specifically the authoritative Storage bucket/object-policy contract and complete runtime permission behavior, not the complaint base table itself.

### 73.2 Financial audit core — source introduction verified

Source `20261114125844_restore_financial_audit_core_schema.sql` (Blob SHA `bdfdfcc01366a9d4a298b2107c53f1525b326bf9`) explicitly creates seven financial/audit tables:

- `srk_booking_labour_bills`
- `srk_manual_payment_entries`
- `srk_electrician_payouts`
- `srk_admin_audit_events`
- `srk_razorpay_refunds`
- `srk_booking_refund_requests`
- `srk_manual_refund_entries`

It also defines two audit-capture functions, attaches audit triggers to bookings/profiles/applications/manual payments/manual refunds/payouts/Razorpay refunds, enables/adjusts RLS and grants, and creates an authorized-electrician payout read policy. The labour-bill table references booking, Auth customer, and electrician profile; downstream receipt, refund, payout reconciliation and accounting migrations depend on this financial foundation. This verifies the current branch source introduction, not Production deployment history or schema parity.

### 73.3 Push delivery dependency chain — exact prerequisites in source

| Order | Source | Objects / changes | Explicit prerequisites |
|---|---|---|---|
| 1 | `20261111020000_add_electrician_push_subscriptions.sql` | `public.srk_push_subscriptions`, user index, RLS and owner-only subscription policy | Auth users, UUID generation |
| 2 | `20261114210000_sequential_nearest_offer_dispatch.sql` | `job_offers.expires_at`, private dispatch/candidate tables, sequential dispatch RPCs | Core booking/profile/job_offers and electrician availability/rate-tier/identity fields |
| 3 | `20261115170001_durable_push_delivery_outbox.sql` | `srk_private.srk_push_delivery_outbox`, enqueue/claim/finish RPCs, offer trigger; removes legacy synchronous push trigger and replaces subscription ACL/policies | `srk_private`, push subscriptions with id/user_id/endpoint/p256dh/auth, `job_offers.expires_at`, electrician availability and identity/approval columns |
| 4 | `20261115180001_push_subscription_delivery_ledger.sql` | `srk_private.srk_push_subscription_deliveries`, claim/finish/completion RPCs | Outbox table plus subscription id/user_id |

The outbox migration includes explicit preflight exceptions for missing prerequisites. This is source evidence of its required ordering, not proof that the full chain executes successfully. Provider delivery and real push-send behavior remain unverified and were not invoked.

### 73.4 Admin Staff RBAC and SOS chain

- `20261114390000_admin_staff_rbac_foundation.sql` creates six staff/RBAC tables and permission/session/support RPCs. Its source comment preserves Main Admin identity in `srk_admin_users`; staff are separate identities and are not inserted into the Main Admin allow-list.
- `20261115260000_sos_admin_support_alerts.sql` first inserts `support.sos.read` and `support.sos.acknowledge` permissions and maps them to the support role, then creates SOS alert/event tables and RPCs. It therefore requires the RBAC permission and role-permission tables before it runs, in addition to booking/Auth/profile prerequisites.
- SOS source comment says no SMS/Push provider is configured by this migration. No external alert was sent.

### 73.5 Remaining dependency gates after this expansion

1. **Canonical baseline provenance:** five legacy core tables are source-backed, but the approved clean-install baseline and exact Supabase platform fixture are not approved.
2. **Admin helper provenance:** `is_srk_admin()` and `srk_is_admin()` are distinct; exact definition/grant introduction and replay placement still require reconciliation.
3. **Storage:** support attachment bucket, object metadata and Storage policy baseline require a complete source/owner-approved contract.
4. **All-migration coverage:** this section expands selected high-impact clusters; it is not an exhaustive 89/89 object-level graph or a topological replay manifest.
5. **Migration history/version handling:** the two malformed legacy `20261109_*.sql` filenames and authoritative applied-history relationship remain unresolved.
6. **Runtime:** no PostgreSQL parser, full replay or pgTAP test has run. Static source inventory is not a PASS.

**Safety boundary:** Audit Branch documentation only. No migration source, PR branch, Main, Production, database, customer/Auth data, payment provider, or workflow was modified or accessed.


## 74. Financial/refund/webhook dependency chain — source re-check — 17 Nov 2026

This section records additional exact-file inspection on the Audit Branch. It is a source-order/dependency review, not SQL parsing or execution.

| Order | Migration | Source objects / role | Required earlier objects |
|---|---|---|---|
| 1 | `20261114125844_restore_financial_audit_core_schema.sql` | Financial bill, manual payment, payout, admin audit, Razorpay refund, refund request and manual refund base tables | Core booking/profile/Auth tables |
| 2 | `20261114190000_customer_receipt_immutable_labour_amount.sql` | Replaces customer receipt RPC to prefer immutable approved labour bill | `service_bookings`, `srk_booking_labour_bills` |
| 3 | `20261114200000_customer_payment_refund_history_rpc.sql` | Customer-scoped payment/refund event history RPC | Booking/payment/refund source relations and Auth |
| 4 | `20261114270000_admin_only_cancellation_requests_and_decisions.sql` | Admin-only cancellation request/decision contract | Booking, Admin identity helper, audit and wallet/payment relations |
| 5 | `20261114280000_cancellation_fee_carry_forward_and_accounting.sql` | Cancellation debt, booking fee items, append-only fee ledger; receipt/payment RPC replacements | Cancellation request table from 14270000, wallet ledger, bookings and financial base |
| 6 | `20261114290000_full_refund_cancellation_fee_and_wallet_reversal.sql` | Full-refund fee reversal and refund RPC replacements | Cancellation fee tables/ledger from 14280000 and refund/payment base |
| 7 | `20261114360000_new_category_electrician_payout_reconciliation.sql` | Replaces payout writer and paid-payout Admin RPC | Financial core payout/bill tables and booking commission/payment fields |
| 8 | `20261114410000_razorpay_webhook_event_inbox.sql` | Durable provider-event inbox and claim/complete RPCs | Auth/role grants and Razorpay webhook service integration |
| 9 | `20261115100000_customer_refund_request_contract.sql` | Customer refund request contract | Refund request base table, booking/payment relations |
| 10 | `20261115110000_admin_refund_review_queue_and_decisions.sql` | Admin refund review/decision RPC contract | Customer refund request contract and Admin helper |
| 11 | `20261115120000_durable_razorpay_refund_recovery_evidence.sql` | Immutable refund recovery evidence and two-phase recovery RPCs | `srk_razorpay_refunds`, bookings, Auth/service-role execution |
| 12 | `20261115130000_admin_manual_refund_request_completion.sql` | Admin manual refund request completion | Refund request/review contract and manual refund ledger |

### Confirmed source-level ordering notes

- The immutable receipt RPC at 14190000 consumes `srk_booking_labour_bills`, introduced by 14125844; the ordering is consistent in the numbered filenames.
- The cancellation-fee accounting migration at 14280000 consumes the cancellation request contract introduced at 14270000.
- The full-refund reversal migration at 14290000 alters cancellation-fee tables introduced at 14280000.
- The payout writer replacement at 14360000 reads the immutable labour bill and writes the payout ledger; the base payout/bill tables are introduced by 14125844.
- Refund recovery evidence at 15120000 references the refund and booking records; the financial audit core precedes it.
- These observations establish direct source references and intended lexical order only. They do not prove every intermediate function signature, trigger compatibility, grants, or replay success.

### High-risk review items retained

1. Receipt and payment-history RPC return-shape/signature compatibility across later replacements needs PostgreSQL catalog verification.
2. Cancellation fee reservation, carry-forward, full-refund reversal and wallet entries require transactional fixtures proving no double collection or double reversal.
3. Payout writer BEFORE/AFTER trigger ordering, commission source parity and cancellation-fee exclusion require runtime assertions.
4. Razorpay webhook claim-token/lease behavior and refund recovery idempotency need concurrency and retry tests; no provider request was made.
5. Admin refund decisions must remain separate from money movement; approval/review RPCs are not evidence that a refund was sent.

**Status:** static dependency evidence expanded; PostgreSQL Parser, clean replay, pgTAP and concurrency tests remain **NOT RUN**. No database or provider was contacted.


## 75. Offer dispatch, work lifecycle, availability and support dependencies — 17 Nov 2026

Six migration files were re-read directly from the Audit Branch. Blob SHA values below identify the exact source inspected.

| Migration | Blob SHA | Objects / change verified | Direct source dependencies |
|---|---|---|---|
| `20261114210000_sequential_nearest_offer_dispatch.sql` | `e56bee06fa8e4684e93cdb33938458ea4a7ed462` | Creates `srk_booking_offer_dispatch` and `srk_booking_offer_candidates`; adds `job_offers.expires_at`; dispatch, candidate-offer, response and expiry RPCs; new-booking trigger | `service_bookings`, `electrician_profiles`, `job_offers` |
| `20261114230000_recheck_electrician_current_area_before_offer.sql` | `19a380e5a0e0b21c23d166d79ade8fa64f6694f7` | Replaces `srk_dispatch_next_booking_offer` to re-check current operating area | Dispatch/candidate objects and electrician current-area fields |
| `20261114240000_server_authoritative_customer_approved_work_timer.sql` | `e84e2e0124b90b526d07f305bc9bf1e2eb6f0ebe` | Creates work timer/transition authorization tables and immutable labour bill; adds multiple work-timer, approval and rate-tier snapshot columns to bookings; replaces work/offer RPCs | Bookings, electrician profiles, `job_offers`, dispatch tables, complaint/cancellation contracts |
| `20261114250000_admin_work_dispute_review_and_immutable_history.sql` | `1bfb04b90aebeb644cdfa52096222f8d1d8175ec` | Creates `srk_booking_work_events`, capture trigger/function and Admin work-review RPC | Bookings, labour bills and complaint records |
| `20261114310000_electrician_self_availability.sql` | `24becb0ef0de0e1d3721bcdd3e22897c0c8e2fc3` | Adds `electrician_profiles.available_for_work`; creates availability event table and self-service RPC | Electrician profiles, `job_offers`, dispatch-next RPC |
| `20261114320000_booking_scoped_live_electrician_location.sql` | `70691ae383e114c7c5b0132f6b29eff6810f8155` | Creates booking-scoped live-location table, consent/start/update/stop/read RPCs and booking-transition stop trigger | Bookings and electrician profiles |
| `20261114350000_electrician_support_tickets_and_admin_inbox.sql` | `6d95af8162cddf820df9fb5ea39161d2e0594d3f` | Creates electrician support-ticket and message tables plus electrician/Admin RPC family | Electrician profiles and bookings; Admin identity helper contract |

### Dependency and behavioral findings

- The dispatch migration's source explicitly describes one active offer per booking and sequential candidate progression; the next-area-check migration replaces the dispatcher rather than creating an independent dispatch path.
- The availability RPC closes currently offered jobs when an electrician switches off availability, then calls the dispatcher to advance those bookings. This creates a direct dependency on the dispatch RPC being installed first.
- The work-timer migration replaces `srk_respond_to_offer` and uses dispatch tables/functions. Its numbered order follows the dispatch foundation.
- The dispute-review migration reads the immutable labour bill and complaint records; the work-timer and complaint foundations therefore precede it.
- The live-location migration is assignment/booking scoped and grants authenticated execution to its RPCs. Runtime proof of authorization boundaries and automatic stop behavior remains required.
- The electrician support inbox is separate from customer complaint conversations; its Admin RPCs depend on the Admin helper contract, which is still not fully traced to a canonical baseline.

### Open verification gates

1. Verify the exact column-level prerequisite set for dispatch candidate eligibility (identity, approval, operating area, coordinates, availability and selected rate tier) against a canonical baseline.
2. Verify trigger replacement/ordering for new-booking dispatch and work status transitions, including whether an old trigger remains attached after each replacement.
3. Exercise concurrent offer expiry, decline, availability-off and reassignment; static SQL cannot establish single-live-offer behavior under races.
4. Verify work timer authorization cannot be replayed, forged or reused across bookings, and that the immutable labour bill is created exactly once.
5. Verify live-location reads are limited to the assigned customer and that stop triggers cover every terminal/reassignment transition.
6. Verify support ticket Admin checks against the canonical Admin helper and test cross-electrician isolation.

**Status:** six migration sources inspected and their direct dependency edges recorded. This is not a complete 89-file graph and is not PostgreSQL parse/replay evidence. Runtime tests remain **NOT RUN**; no database, location provider or notification provider was contacted.


## 76. Legacy root schema scripts — canonical baseline provenance check — 17 Nov 2026

Four root-level SQL setup scripts were re-read from the Audit Branch. This is a source inventory only; none was executed.

| File | Blob SHA | Table declarations found | Function declarations found |
|---|---|---|---|
| `SUPABASE_SCHEMA.sql` | `8ae88a7035bc963b244f22c6c1450c22618ec88f` | `service_bookings`, `electrician_applications`, `electrician_profiles`, `job_offers` | 0 |
| `PORTAL_SCHEMA.sql` | `efc14aa623a3895ffb3841b7b0f226f2015f34b1` | `srk_admin_users` | 5 |
| `COMPLETE_DATABASE_SETUP.sql` | `2b806e727f449ba18e71ad23edef805ceb2da2b5` | The same four core tables plus `srk_admin_users` | 8 |
| `ADMIN_EMAIL_LOGIN_SETUP.sql` | `dbd91b3f912b1e0946bffe6d249a85cc41dc81cd` | 0 | 2 |

### Findings

1. `COMPLETE_DATABASE_SETUP.sql` overlaps the table declarations in `SUPABASE_SCHEMA.sql` and `PORTAL_SCHEMA.sql`; it is not an independent numbered migration and cannot be assumed safe to replay after either script.
2. `PORTAL_SCHEMA.sql` and `ADMIN_EMAIL_LOGIN_SETUP.sql` both define Admin-related function contracts. The function inventory includes `srk_is_admin()` and `is_srk_admin()` as distinct names; their existence in setup scripts does not establish which definition/grants are authoritative for a clean install.
3. The four files do not form a documented, uniquely ordered baseline chain. The branch therefore has overlapping bootstrap sources rather than a proven single canonical baseline.
4. The earlier dependency report's baseline gate remains open: the owner-approved bootstrap choice, exact platform prerequisites (Auth roles/extensions/Storage), and numbered-migration starting point must be specified before a deterministic clean replay manifest can be certified.

### Safe next step

Treat these files as historical/bootstrap candidates, not as a replay sequence. Obtain an owner-approved baseline decision and a disposable PostgreSQL/Supabase-compatible fixture; then validate duplicate object declarations and platform dependencies in that isolated environment. Do not execute these scripts against Production.

**Status:** four root scripts inventoried with exact Git blob identities. No SQL parser, PostgreSQL replay or runtime test was run. No source SQL was modified; only this Audit Branch report is being extended.


## 77. Legacy quote migration prerequisites and filename-lineage gate — 17 Nov 2026

The two legacy `20261109_*.sql` files and the starter schema were re-read directly from this Audit Branch.

| Source | Blob SHA | Source-level finding |
|---|---|---|
| `SUPABASE_SCHEMA.sql` | `8ae88a7035bc963b244f22c6c1450c22618ec88f` | Declares the four starter tables; its booking definition does not contain the later customer Auth, map-coordinate or quote-workflow fields. |
| `20261109_allow_quote_approval_booking_states.sql` | `ef4bf8b9b8a9a35bf3ddd94ea4614c7498fb1c6d` | Alters `service_bookings` status and assignment CHECK constraints; requires the booking table and its `status` / `assigned_electrician_id` columns. |
| `20261109_electrician_inspection_quotes_and_service_only_commission.sql` | `014699d3190e45aacde4022ac7e7fa9ca4fec006` | Adds quote fields and defines quote/customer/work RPCs; reads customer ownership, Auth-linked electrician identity, offer rows, booking map coordinates and existing payment/commission fields. |

### Confirmed prerequisites from source

1. The quote workflow's booking table must already have `customer_user_id`; the source-introducing customer-account migration is `20261108121115_add_customer_account_booking_access.sql`.
2. The quote RPCs require Auth-aware profile identity (`electrician_profiles.user_id`) and approval/active fields. The root starter scripts are historical candidates; the identity-linking migration and platform Auth baseline must be included in the replay fixture.
3. The offer-details RPC reads `job_offers` and booking map fields `location_lat` / `location_lng`; the starter schema supplies the offer table, while `20261109001000_add_google_maps_location_support.sql` is the source introducing the map fields.
4. The target migration defines `srk_calculate_booking_commission()` but does not attach that function to a trigger in this file. Do not infer that this function is live merely because it exists; trigger wiring must be traced separately.
5. The second filename has no full timestamp/version prefix. The pair's intended relative order cannot be certified from a normal timestamp sequence alone; preserve their source identities and obtain an owner-approved version mapping before generating a clean replay manifest.

### Current-tree correction / stale-name check

A recursive Git tree read at Audit Branch head `0a2ccc4af877b06512ad58f8394f3aa9f83522e7` returned no migration path containing `add_assigned_electrician_cash_payment_status`. Therefore the earlier note about two duplicate files with that exact name is **not reproduced in the current tree** and must not be treated as a confirmed current-branch blocker. This does not establish whether such files existed in another historical branch/commit.

### Replay decision

These findings strengthen the canonical-baseline and migration-lineage blockers. They do not authorize renaming historical files or changing migration order. A clean replay remains blocked pending an approved baseline/version mapping and a disposable Supabase-compatible PostgreSQL fixture.

**Status:** source-only prerequisite review. No migration SQL was changed, parsed or executed; no database or Production system was contacted; runtime tests remain **NOT RUN**.

## 78. Complete migration inventory and replay-manifest integrity — 17 Nov 2026

A fresh recursive Git tree read was performed at Audit Branch head `651c6ab8a6643bb3560590680e7a584e95db94d0`. The tree response was not truncated.

### Inventory evidence

- SQL files under `supabase/migrations/`: **89**.
- Lexicographically earliest filename: `20261108120608_add_public_api_rate_limiting.sql`.
- Lexicographically latest filename: `20261117010000_reconcile_booking_commission_and_manual_payment_method.sql`.
- This is a filename inventory only. Lexical order is not proof of dependency order, successful parse, or replay safety.

### Filename/version anomalies

- `supabase/migrations/20261109_allow_quote_approval_booking_states.sql` — blob `ef4bf8b9b8a9a35bf3ddd94ea4614c7498fb1c6d`; filename does not match the 14-digit timestamp plus underscore convention.
- `supabase/migrations/20261109_electrician_inspection_quotes_and_service_only_commission.sql` — blob `014699d3190e45aacde4022ac7e7fa9ca4fec006`; filename does not match the 14-digit timestamp plus underscore convention.

### Identical-content paths

- Blob `e3bdf2624c224322a6ac4c99f2ae6e77b1be4774` is referenced by both `supabase/migrations/20261115120001_fix_multi_profile_electrician_labour_bill_access.sql` and `supabase/migrations/20261115145900_fix_multi_profile_electrician_labour_bill_access.sql`. These are two migration paths with byte-identical Git blob content, not proof that either path is safe to apply twice. Replay tooling and migration-ledger behavior must be checked before treating them as independent migrations.

### Complete filename inventory (Git tree order)

1. `20261108120608_add_public_api_rate_limiting.sql`
2. `20261108120658_enable_rls_public_api_rate_limits.sql`
3. `20261108121115_add_customer_account_booking_access.sql`
4. `20261108233500_restrict_public_form_inserts.sql`
5. `20261108234000_combine_booking_read_policy.sql`
6. `20261109000500_harden_electrician_profile_identity_linking.sql`
7. `20261109001000_add_google_maps_location_support.sql`
8. `20261109001500_unique_electrician_admin_identity_linking.sql`
9. `20261109002000_expose_assigned_booking_map_pin.sql`
10. `20261109003000_secure_commission_reporting.sql`
11. `20261109010000_create_secure_wallet_ledger_foundation.sql`
12. `20261109020000_create_server_only_razorpay_route_transfer_ledger.sql`
13. `20261109103038_customer_electrician_direct_call_contacts.sql`
14. `20261109103143_move_customer_call_contact_lookup_to_private.sql`
15. `20261109_allow_quote_approval_booking_states.sql`
16. `20261109_electrician_inspection_quotes_and_service_only_commission.sql`
17. `20261110040000_customer_admin_complaints.sql`
18. `20261110140000_restore_missing_customer_booking_quote_columns.sql`
19. `20261111020000_add_electrician_push_subscriptions.sql`
20. `20261113220000_customer_support_conversation_schema.sql`
21. `20261113230000_support_attachment_paths_and_admin_message_list.sql`
22. `20261114125844_restore_financial_audit_core_schema.sql`
23. `20261114130000_harden_electrician_profile_identity_linking.sql`
24. `20261114150000_customer_booking_submission_idempotency.sql`
25. `20261114160000_customer_selected_rate_tier_and_server_estimate.sql`
26. `20261114180000_harden_customer_avatar_object_integrity.sql`
27. `20261114190000_customer_receipt_immutable_labour_amount.sql`
28. `20261114200000_customer_payment_refund_history_rpc.sql`
29. `20261114201428_customer_profile_saved_addresses_private_storage.sql`
30. `20261114202250_customer_complaint_customer_safe_projection.sql`
31. `20261114202656_customer_change_payment_method_rpc.sql`
32. `20261114210000_sequential_nearest_offer_dispatch.sql`
33. `20261114220000_admin_approved_electrician_relocation.sql`
34. `20261114230000_recheck_electrician_current_area_before_offer.sql`
35. `20261114240000_server_authoritative_customer_approved_work_timer.sql`
36. `20261114250000_admin_work_dispute_review_and_immutable_history.sql`
37. `20261114260000_fix_work_start_rpc_and_append_only_event_history.sql`
38. `20261114270000_admin_only_cancellation_requests_and_decisions.sql`
39. `20261114280000_cancellation_fee_carry_forward_and_accounting.sql`
40. `20261114290000_full_refund_cancellation_fee_and_wallet_reversal.sql`
41. `20261114300000_admin_customer_support_thread_replies.sql`
42. `20261114310000_electrician_self_availability.sql`
43. `20261114320000_booking_scoped_live_electrician_location.sql`
44. `20261114330000_electrician_private_kyc_document_preview.sql`
45. `20261114340000_electrician_self_profile_name_edit.sql`
46. `20261114350000_electrician_support_tickets_and_admin_inbox.sql`
47. `20261114360000_new_category_electrician_payout_reconciliation.sql`
48. `20261114370000_electrician_offer_details_immediate_booking_fields.sql`
49. `20261114380000_electrician_phone_change_admin_approval.sql`
50. `20261114390000_admin_staff_rbac_foundation.sql`
51. `20261114410000_razorpay_webhook_event_inbox.sql`
52. `20261115091906_retire_unused_legacy_accept_electrician_job.sql`
53. `20261115092149_retire_unused_razorpay_route_transfer_ledger.sql`
54. `20261115100000_customer_refund_request_contract.sql`
55. `20261115110000_admin_refund_review_queue_and_decisions.sql`
56. `20261115120000_durable_razorpay_refund_recovery_evidence.sql`
57. `20261115120001_fix_multi_profile_electrician_labour_bill_access.sql`
58. `20261115130000_admin_manual_refund_request_completion.sql`
59. `20261115140000_electrician_kyc_review_and_activation_gate.sql`
60. `20261115145900_fix_multi_profile_electrician_labour_bill_access.sql`
61. `20261115150000_admin_readonly_booking_accounting_reconciliation.sql`
62. `20261115160000_legacy_booking_status_write_guard.sql`
63. `20261115170000_admin_route_transfer_accounting_reconciliation.sql`
64. `20261115170001_durable_push_delivery_outbox.sql`
65. `20261115180000_admin_route_recipient_and_settlement_validation.sql`
66. `20261115180001_push_subscription_delivery_ledger.sql`
67. `20261115190000_enforce_single_primary_route_bank_link.sql`
68. `20261115190001_push_delivery_health_monitoring.sql`
69. `20261115200000_harden_financial_admin_rpc_search_path.sql`
70. `20261115200001_push_delivery_lease_fencing.sql`
71. `20261115210000_legacy_manual_payment_and_itemized_receipt.sql`
72. `20261115210001_harden_legacy_financial_read_rpc_search_paths.sql`
73. `20261115220000_retire_live_legacy_quotation_rpcs.sql`
74. `20261115230000_admin_booking_direct_write_closure.sql`
75. `20261115240000_harden_refund_recovery_full_amount.sql`
76. `20261115250000_harden_refund_reconcile_full_amount.sql`
77. `20261115260000_sos_admin_support_alerts.sql`
78. `20261115270000_fix_customer_payment_method_unicode_contract.sql`
79. `20261116100000_fix_staff_permission_helper_volatility.sql`
80. `20261116110000_pin_legacy_financial_read_rpc_search_paths.sql`
81. `20261116120000_pin_customer_call_contact_rpc_search_paths.sql`
82. `20261116130000_pin_wallet_and_receipt_rpc_search_paths.sql`
83. `20261116140000_pin_electrician_offer_details_search_path.sql`
84. `20261116150000_pin_admin_application_review_search_path.sql`
85. `20261116160000_pin_quote_and_work_status_rpc_search_paths.sql`
86. `20261116170000_pin_public_rate_limit_rpc_search_path.sql`
87. `20261116200000_restore_service_bookings_amount_paid.sql`
88. `20261116210000_attach_electrician_payout_reconciliation_trigger.sql`
89. `20261117010000_reconcile_booking_commission_and_manual_payment_method.sql`

### Replay-manifest decision

1. Keep the 89 path identities intact in the audit inventory; do not rename, delete, squash, or reorder historical migrations on this report-only step.
2. The two nonconforming legacy `20261109_*.sql` filenames remain unresolved version-lineage items (see §77).
3. The identical-content pair above requires an explicit migration-ledger and duplicate-application decision; identical blobs do not establish duplicate version IDs.
4. Generate a dependency-respecting replay manifest only after the canonical bootstrap, platform prerequisites, and legacy version mapping are approved. A sorted filename list is not a dependency graph.

**Status:** full current-tree inventory verified from GitHub; no migration SQL changed, parsed or executed; no database contacted; runtime tests remain **NOT RUN**.

## 79. Source-verified dependency edges for identity, receipts and accounting — 17 Nov 2026

This section records only dependencies supported by migration comments, DDL, or direct object references. It is a partial edge list, not a certified complete DAG.

### Explicit ordering edges

| Required order | Evidence from source | Replay implication |
|---|---|---|
| `20261109000500_harden_electrician_profile_identity_linking.sql` → `20261109001000_add_google_maps_location_support.sql` | The first migration's opening comment says it must run before the second; the second writes both identity columns. | Preserve this order; the identity columns and synchronization guard must exist before the Admin approval function writes them. |
| `20261109001000_add_google_maps_location_support.sql` → `20261109001500_unique_electrician_admin_identity_linking.sql` | The latter's opening comment says it runs after the former and replaces `srk_admin_review_application(uuid,text)`; it drops the earlier `RETURNS void` function and creates a `RETURNS jsonb` version. | Function signature replacement is order-sensitive; a replay manifest must not reverse these files. |
| `20261114125844_restore_financial_audit_core_schema.sql` → `20261114190000_customer_receipt_immutable_labour_amount.sql` | The core migration says it precedes receipt consumers and creates `srk_booking_labour_bills`; the receipt RPC reads that table. | Core relation must exist before receipt RPC is exercised. |
| `20261114125844_restore_financial_audit_core_schema.sql` → `20261114200000_customer_payment_refund_history_rpc.sql` | The core migration explicitly says it precedes history RPC consumers and creates the manual-payment/payout relations; the history RPC reads booking payment data and refund relations. | Core finance tables are prerequisites; later refund relations must also exist before runtime execution. |

### Additional direct prerequisites (source-level)

1. `20261108121115_add_customer_account_booking_access.sql` adds `service_bookings.customer_user_id` referencing `auth.users(id)`. Later customer-scoped receipt/history RPCs filter on this column. Therefore the canonical baseline must provide `service_bookings`, Auth schema/users, and the customer-account migration must precede those RPCs.
2. `20261109001000_add_google_maps_location_support.sql` adds booking/application/profile coordinate columns and replaces the Admin application-review function. Its insert/update references `electrician_profiles.user_id`, `auth_user_id`, and application/profile fields; the starter schema and identity-linking chain are prerequisites.
3. `20261114190000_customer_receipt_immutable_labour_amount.sql` reads both `service_bookings.customer_user_id` and `srk_booking_labour_bills`; the latter is created by the financial core migration. Receipt execution additionally depends on Auth identity and verified payment columns being present.
4. `20261114360000_new_category_electrician_payout_reconciliation.sql` references `srk_booking_labour_bills`, `srk_manual_payment_entries`, `srk_electrician_payouts`, and cancellation-fee items. The financial core migration creates the first three; cancellation-fee schema must be installed before the payout function is exercised.
5. `20261117010000_reconcile_booking_commission_and_manual_payment_method.sql` reads/writes the payout, manual-payment, wallet, refund and cancellation-fee accounting relations. It belongs after their schema and writer migrations; filename order alone is insufficient proof that all runtime dependencies are met.

### Important runtime-vs-creation distinction

Some PL/pgSQL function bodies contain references to relations introduced by later migrations. Successful function creation, if a parser permits deferred statement planning, would not prove that the function can execute at that point. The replay fixture must test both clean migration application and invocation of representative RPC/trigger paths after the full schema is present.

**Status:** source-read dependency edges only. No full DAG has been certified; no PostgreSQL parser or database replay was run; no SQL was executed; runtime tests remain **NOT RUN**.

## 80. Refund, cancellation-fee, wallet and payout dependency chain — 17 Nov 2026

Direct source inspection of the five finance migrations confirms these additional edges:

| Order | Migration | Direct prerequisite / reason |
|---|---|---|
| 1 | `20261109010000_create_secure_wallet_ledger_foundation.sql` | Creates `srk_wallet_accounts` and `srk_wallet_ledger`; the cancellation-fee migration alters the wallet ledger entry-type constraint and later refund logic writes wallet reversals. Also requires Auth and `electrician_profiles` baseline objects. |
| 2 | `20261114125844_restore_financial_audit_core_schema.sql` | Creates the financial core relations including `srk_razorpay_refunds`, `srk_manual_payment_entries`, `srk_electrician_payouts`, and `srk_booking_labour_bills`. It requires baseline `service_bookings`, `electrician_profiles`, Auth and UUID support. |
| 3 | `20261114270000_admin_only_cancellation_requests_and_decisions.sql` | Creates cancellation request/event tables and the approved-decision guard. Its booking/customer references require the baseline and customer identity column lineage. |
| 4 | `20261114280000_cancellation_fee_carry_forward_and_accounting.sql` | Alters `srk_wallet_ledger`; references cancellation requests from 142700; creates debt, fee-item and fee-ledger tables. Therefore wallet foundation and cancellation request migration must precede it. |
| 5 | `20261114290000_full_refund_cancellation_fee_and_wallet_reversal.sql` | Alters fee-item/fee-ledger tables from 142800 and writes `srk_wallet_ledger`; reads processed Razorpay/manual refund evidence from the financial core. Therefore 142800 and core refund tables must precede it. |
| 6 | `20261114360000_new_category_electrician_payout_reconciliation.sql` | Payout writer and paid-payout RPC read immutable labour bills, manual payment entries, payout ledger, and cancellation-fee items; therefore financial core and 142800 must precede execution of payout paths. |
| 7 | `20261117010000_reconcile_booking_commission_and_manual_payment_method.sql` | Reconciliation/report functions read payout, manual-payment, refund, cancellation-fee, wallet and booking objects. It must remain after all corresponding schema and writer migrations, including 142900 and 143600. |

### Verified ordering constraints

- `09010000 → 14280000 → 14290000` (wallet ledger creation, extension and reversal consumer).
- `14125844 → 14290000` (refund evidence tables are read by the full-refund reversal).
- `14270000 → 14280000 → 14290000` (cancellation request, debt/allocation ledger, then reversal).
- `14125844 → 14360000` and `14280000 → 14360000` (payout consumer reads core payout/bill tables and cancellation-fee items).
- `14290000 → 17010000` and `14360000 → 17010000` (final reconciliation reads reversal and payout outcomes).

### Replay risks that remain

1. These edges are source-derived, not proof of a complete graph. Earlier migrations and baseline setup still need a full object-by-object dependency pass.
2. Some migrations use `CREATE TABLE IF NOT EXISTS`, `ADD COLUMN IF NOT EXISTS`, or replace existing functions. A clean replay and an upgrade replay can behave differently; both need separate disposable-database fixtures.
3. `20261114290000` expects full-refund evidence and settled fee items before a booking transitions to refunded. Trigger ordering and actual refund writer invocation must be tested, not inferred from file order.
4. The payout migration's function definitions are not proof that the payout trigger is attached at that point; trigger attachment lineage must be separately verified.
5. No dependency manifest should be marked executable until the canonical baseline and all prerequisites are approved.

**Status:** additional source-level finance edges verified; no database or production access; no SQL parse/replay; runtime tests remain **NOT RUN**.


## 81. Canonical bootstrap compatibility and Admin-helper lineage — 17 Nov 2026

The four root setup files were compared with the earliest numbered migrations and the function names referenced by those migrations. This is a source-level compatibility audit; it does not select or apply a bootstrap.

### Root bootstrap comparison

| File | Objects/contracts established | Relevant omissions or incompatibilities |
|---|---|---|
| `SUPABASE_SCHEMA.sql` | Creates the four starter operational tables, `job_offers`, indexes and initial RLS/policies. | Does not create `srk_admin_users`, `is_srk_admin()`, or `srk_is_admin()`; does not define `amount_paid`; does not create schema `private`. |
| `PORTAL_SCHEMA.sql` | Adds `srk_admin_users`, `electrician_profiles.user_id`, portal functions and policies; defines `srk_is_admin()`. | Defines `srk_is_admin()`, not `is_srk_admin()`. It is documented as running after `SUPABASE_SCHEMA.sql`. |
| `COMPLETE_DATABASE_SETUP.sql` | Bundles the starter schema and portal setup; additionally defines `is_srk_admin()` in its Admin patch section. | Does not define `amount_paid` and does not create schema `private`; later migration 090030 adds `amount_paid`. It overlaps the separate root setup files and is not an approved migration-version baseline. |
| `ADMIN_EMAIL_LOGIN_SETUP.sql` | Adds `is_srk_admin()` and Admin policies/RPC against the existing Admin allow-list. | It assumes `srk_admin_users` and the operational tables already exist; it is a patch, not a complete bootstrap. |

### Numbered migration contracts

1. `20261108234000_combine_booking_read_policy.sql` creates a policy that calls `public.is_srk_admin()`. The numbered migration sequence does not itself establish that helper before this policy is created. A replay therefore needs an explicit, approved bootstrap prerequisite that provides the function.
2. `20261109001000_add_google_maps_location_support.sql` also calls `public.is_srk_admin()` inside the replacement Admin-review function.
3. `20261109003000_secure_commission_reporting.sql` and `20261109010000_create_secure_wallet_ledger_foundation.sql` call `public.is_srk_admin()` in privileged report/overview functions.
4. `20261109001500_unique_electrician_admin_identity_linking.sql` calls `public.srk_is_admin()`, so its prerequisite is the portal helper name, not the alternate helper used by the other migrations.
5. `20261109003000_secure_commission_reporting.sql` adds `service_bookings.amount_paid`; the root starter and consolidated setup snapshots inspected here do not define that column.
6. The first rate-limit migration `20261108120608_add_public_api_rate_limiting.sql` creates schema `private` itself and grants access to the Supabase `service_role`. Replay also depends on the Supabase platform roles and Auth schema being present; these are platform prerequisites, not objects supplied by the four root SQL files.

### Replay decision

- Do not treat `SUPABASE_SCHEMA.sql` + `PORTAL_SCHEMA.sql`, `COMPLETE_DATABASE_SETUP.sql`, or `ADMIN_EMAIL_LOGIN_SETUP.sql` as interchangeable baselines.
- Before producing an executable clean-replay manifest, the repository owner must approve one canonical bootstrap and explicitly map the Admin helper contract(s), Auth/platform prerequisites, and the initial migration boundary.
- Do not silently add aliases, rewrite historical migrations, or choose a root script by filename. Such changes would alter the bootstrap/security contract and require separate approval.
- `amount_paid` is an identified later migration addition, not a reason to hand-edit the historical root setup snapshot during this audit.

**Status:** root-file and early-migration source comparison completed; baseline remains **NOT APPROVED**; no SQL parsed or executed; no database contacted; runtime replay tests remain **NOT RUN**.


## 82. Later accounting trigger attachment and duplicate migration identity — 17 Nov 2026

A follow-up source pass checked the late amount-column restoration, payout trigger attachment, final commission bridge, and repeated migration bodies.

### Confirmed source-order edges

| Required order | Source evidence | Replay implication |
|---|---|---|
| `20261114125844_restore_financial_audit_core_schema.sql` → `20261116210000_attach_electrician_payout_reconciliation_trigger.sql` | The latter's `srk_create_electrician_payable()` reads the core payout and manual-payment tables and the immutable labour-bill table. | Finance core schema and its required bill/payment prerequisites must exist before this trigger function is installed or invoked. |
| `20261116200000_restore_service_bookings_amount_paid.sql` → `20261116210000_attach_electrician_payout_reconciliation_trigger.sql` | The trigger function reads `service_bookings.amount_paid`, and the trigger event list includes that column. | The column must exist before trigger attachment. |
| `20261116210000_attach_electrician_payout_reconciliation_trigger.sql` → `20261117010000_reconcile_booking_commission_and_manual_payment_method.sql` | The 17 Nov migration explicitly states that the payout ledger remains in its existing AFTER trigger; its AFTER parity validator reads the payout row written by that trigger. | The payout writer trigger must be attached before the parity validator can safely be exercised. |
| `20261116200000_restore_service_bookings_amount_paid.sql` → `20261117010000_reconcile_booking_commission_and_manual_payment_method.sql` | The BEFORE commission trigger and reconciliation RPC read `amount_paid`; the event list includes it. | Amount-column lineage is a hard prerequisite for the commission/payment bridge. |

The 17 Nov commission bridge uses a BEFORE trigger named `zz_srk_set_booking_commission_before_payout`, while the payout writer is an AFTER trigger named `srk_reconcile_electrician_payable`. The parity validator is an AFTER trigger named `zz_srk_validate_booking_commission_payout_parity`. PostgreSQL's alphabetical ordering within same-kind triggers supports the intended AFTER order by trigger name, but source names alone do not replace a PostgreSQL runtime fixture. The existing static test files check the intended trigger semantics; they have not been executed.

### Duplicate migration body

The current recursive Git tree contains two distinct migration paths with the same exact blob SHA:

- `20261115120001_fix_multi_profile_electrician_labour_bill_access.sql`
- `20261115145900_fix_multi_profile_electrician_labour_bill_access.sql`
- Shared blob SHA: `e3bdf2624c224322a6ac4c99f2ae6e77b1be4774`

Both paths contain the same `CREATE OR REPLACE FUNCTION public.srk_electrician_get_labour_bill(uuid)` definition and grants. The second application may be functionally idempotent at the SQL-object level, but it is still a separate migration version and may appear as a second entry in migration history. Preserve both historical paths during this audit; do not rename, delete, squash, or silently omit either version. The replay manifest must retain both identities and document the repeated body.

### Status and limits

- The source-level payout trigger attachment is now located in `20261116210000`; this closes the earlier question of where the attachment is defined, not whether its behavior passes runtime tests.
- The amount-paid restoration is explicit and idempotent, but the root bootstrap still needs owner approval.
- No PostgreSQL parser, clean replay, upgrade replay, trigger execution, or accounting fixture was run. Runtime tests remain **NOT RUN**.


## 83. SQL parser and test-runner readiness — 17 Nov 2026

The current Audit Branch test infrastructure was checked without dispatching workflows or contacting a database.

### Repository runner facts

- `package.json` declares only `razorpay` as a runtime dependency and exposes Node tests through `npm test`; it declares no PostgreSQL parser or SQL AST package.
- No `package-lock.json` is present at the repository root, so the declared Node dependency graph is not lockfile-pinned.
- No `supabase/config.toml` is present in the current tree.
- The Node test workflow runs on pushes to `feat/customer-login-first-dashboard-20261114`, pull requests targeting `main`, or manual dispatch. It was not dispatched from this audit.
- The Supabase schema workflow is `workflow_dispatch` only and has a job-level guard requiring `refs/heads/feature/platform-fee-cash-online-cycle`. It exports schema from a configured remote Supabase connection before starting a local stack; it is not a clean-replay workflow for this Audit Branch. It was not dispatched.
- The current two accounting bridge suites are present: `admin_labour_bill_payment_accounting_bridge.test.sql` declares plan 19, and `electrician_payout_reconciliation.test.sql` declares plan 34. Each has one `finish()` and one `rollback;` in the source. This is static file inspection only.

### Safe execution decision

Do not repurpose the Production-schema export workflow, do not dispatch a workflow as a substitute for an approved disposable database, and do not claim SQL parser or pgTAP success from test-file inspection. A dedicated isolated PostgreSQL/Supabase test environment, approved bootstrap, and a parser/runtime toolchain are still required.

**Status:** test infrastructure inspected; no workflow dispatched; no dependency installed; no SQL parser executed; no database connected; both accounting pgTAP suites remain **NOT RUN**.


## 84. Refund, RBAC, KYC, SOS and legacy-retirement dependency pass — 17 Nov 2026

The late migration family was compared against its referenced base relations and helper functions. Edges below are source-derived and are not a complete replay DAG.

### Confirmed dependency edges and ordering concerns

| Consumer migration | Required earlier source | Evidence / replay note |
|---|---|---|
| `20261115100000_customer_refund_request_contract.sql` | `20261114125844_restore_financial_audit_core_schema.sql`, `20261116200000_restore_service_bookings_amount_paid.sql`, `20261114280000_cancellation_fee_carry_forward_and_accounting.sql`, `20261114290000_full_refund_cancellation_fee_and_wallet_reversal.sql` | Customer request RPC reads refund request/refund evidence, manual refund, immutable labour bill, settled cancellation fee items, and the verified paid amount. The relevant tables/column and fee ledger must exist before it is called. |
| `20261115110000_admin_refund_review_queue_and_decisions.sql` | `14125844`, `14280000`, `14360000`, `15100000` | Admin queue joins refund requests, booking, labour bill, Razorpay refund and payout. Decision RPC mutates the refund request state created by the earlier contract. |
| `20261115120000_durable_razorpay_refund_recovery_evidence.sql` | `14125844`, `15110000`/existing refund relation lineage | Creates append-only recovery evidence referencing `srk_razorpay_refunds`, `service_bookings`, and `auth.users`; its writer checks `srk_admin_users` and the internal refund row. It depends on Auth/platform identity and financial core relations. |
| `20261115130000_admin_manual_refund_request_completion.sql` | `14125844`, `15100000`, `14280000`, `14290000`, `14360000` | Replaces the manual refund completion RPC and reads payment, request, labour bill, fee and payout state. Later `20261116210000` replaces the same RPC again; final definition must be taken from the later migration, not this intermediate version. |
| `20261115150000_admin_readonly_booking_accounting_reconciliation.sql` | `14125844`, `14280000`, `14290000`, `14360000`, `15100000` | Read-only report joins bill, payout, refund, manual refund, cancellation-fee and wallet ledgers. It is replaced by `15170000` and `15180000`; retain version history and use the final definition for final-state analysis. |
| `20261115170000_admin_route_transfer_accounting_reconciliation.sql` | `15150000` and `09020000` route-transfer lineage | Replaces the report contract after Route retirement and explicitly reports no live Route transfers while preserving response fields. |
| `20261115190000_enforce_single_primary_route_bank_link.sql` | Route bank-link relation and its provider/wallet columns | Performs a fail-closed duplicate check and adds a partial unique index. The exact creator of `srk_wallet_bank_links` must be present in the approved bootstrap/migration lineage; this migration does not create that table. |
| `20261115200000_harden_financial_admin_rpc_search_path.sql` | `14125844`, `14360000`, `15130000` | Uses `ALTER FUNCTION` for exact signatures of payout, manual-refund and payout-trigger functions. All signatures must already exist. |
| `20261115210000_legacy_manual_payment_and_itemized_receipt.sql` | `14125844`, `14190000`, `14360000`, `16200000` | Manual-payment RPC reads the legacy booking quote and payout contracts; receipt RPC reads immutable labour-bill and payment evidence. The later `amount_paid` restoration is a prerequisite for execution of the payment/receipt path. |
| `20261115210001_harden_legacy_financial_read_rpc_search_paths.sql` | Wallet and commission read RPC definitions from the approved bootstrap/financial lineage | Alters three exact function signatures; must not run before those functions are created. |
| `20261115220000_retire_live_legacy_quotation_rpcs.sql` | Quote RPCs and offer-details contract from the legacy quote/offer migrations | Revokes and drops named RPCs and recreates the offer-details projection. This is a destructive schema/API transition; historical booking/payment evidence is intentionally retained. |
| `20261115230000_admin_booking_direct_write_closure.sql` | Legacy booking schema, Admin identity helper and existing quote/location columns | Adds replacement Admin-only write RPCs. It assumes the underlying booking columns and `is_srk_admin()` already exist. |
| `20261115240000_harden_refund_recovery_full_amount.sql`, `20261115250000_harden_refund_reconcile_full_amount.sql` | `15120000` and the refund/payment/payout relations | Both replace service-role refund functions. Recovery finalization and provider reconciliation now enforce full-collection equality; the final definition must be sourced from these later replacements. |
| `20261115260000_sos_admin_support_alerts.sql` | `14390000_admin_staff_rbac_foundation.sql` and `service_bookings`/Auth | Inserts SOS permission and role-permission rows and creates SOS alert/event objects. RBAC permission tables must exist first. |
| `20261115270000_fix_customer_payment_method_unicode_contract.sql` | Customer booking ownership and booking payment columns from the approved baseline/early migrations | Replaces the customer payment-method RPC and checks owner, booking status, assignment, amount and provider IDs. The `amount_paid` column must exist at execution time. |

### KYC forward-reference requiring explicit replay treatment

- `20261114330000_electrician_private_kyc_document_preview.sql` creates `srk_electrician_get_my_verification_document_path(uuid)`, whose function body reads `srk_electrician_verification_documents`.
- The table is created later by `20261115140000_electrician_kyc_review_and_activation_gate.sql`.
- This is a source-level forward reference. PL/pgSQL may defer statement planning until invocation, so it is not asserted here to be a CREATE FUNCTION parse failure. However, the helper is not safely callable in the interval before the table exists. A clean replay manifest should flag this runtime availability gap; do not silently renumber or rewrite historical files.

### Other important lineage observations

- `20261115140000` establishes the private KYC document/event relations and Storage policies. It requires the earlier electrician profile identity chain and Supabase Storage platform objects/bucket prerequisites.
- `20261115260000` assumes RBAC permission catalog and role mapping tables from `14390000`; the permission rows are additive and use conflict handling.
- `20261115190000` is a partial unique index, not a table creator. Existing duplicate primary Route links cause an intentional migration failure and require owner-reviewed reconciliation; do not auto-select or delete a bank link.
- `20261115220000` drops legacy quotation RPCs. It must be treated as an API cutover after dependent clients and replacement projections are reviewed, not as a harmless additive migration.
- Several successive report/refund migrations replace the same function signatures. The replay audit must preserve every historical migration version while separately recording the final effective function body.

**Status:** late migration source dependencies reviewed; KYC forward-reference and Route index prerequisite recorded; no historical file reordered/edited; no SQL parser or database replay executed; runtime tests remain **NOT RUN**.


## 85. Current-branch migration inventory recheck — 17 Nov 2026

The recursive Git tree was fetched again at the current Audit Branch head after sections 81–84 were added.

- Tree response: `truncated=false`.
- Current migration SQL count: **89**.
- Two filenames still fail the 14-digit timestamp + underscore naming convention:
  - `20261109_allow_quote_approval_booking_states.sql`
  - `20261109_electrician_inspection_quotes_and_service_only_commission.sql`
- One pair of distinct migration paths still shares the exact same content blob:
  - `20261115120001_fix_multi_profile_electrician_labour_bill_access.sql`
  - `20261115145900_fix_multi_profile_electrician_labour_bill_access.sql`
  - Blob SHA: `e3bdf2624c224322a6ac4c99f2ae6e77b1be4774`
- The tree was not truncated, so the count and path comparison cover the complete recursive tree response at the fetched branch head.

This is an inventory check only. It does not establish a canonical bootstrap, a complete dependency DAG, a safe version remapping, or successful clean/upgrade replay. Preserve both malformed historical paths and the duplicate-content version identities until the repository owner approves a migration-lineage plan.

**Status:** current inventory rechecked; no migration path modified; PostgreSQL parse/replay and runtime tests remain **NOT RUN**.


## 86. Push delivery chain and private-schema prerequisite — 17 Nov 2026

The four durable push-delivery migrations were checked against their explicit preflight guards and the earlier schema creators.

### Confirmed dependency chain

1. `20261114160000_customer_selected_rate_tier_and_server_estimate.sql` creates schema `srk_private`; this is the required namespace prerequisite for later dispatch and push objects.
2. `20261114210000_sequential_nearest_offer_dispatch.sql` creates `srk_private.srk_booking_offer_dispatch` and `srk_private.srk_booking_offer_candidates`; it also adds `job_offers.expires_at`.
3. `20261114310000_electrician_self_availability.sql` adds `electrician_profiles.available_for_work`.
4. `20261111020000_add_electrician_push_subscriptions.sql` creates `public.srk_push_subscriptions` with `id,user_id,endpoint,p256dh,auth`. It is earlier in filename order than the dispatch and availability migrations, but the outbox consumer is later.
5. `20261115170001_durable_push_delivery_outbox.sql` has an explicit preflight for `srk_private`, the subscription table and its five required columns, `job_offers.expires_at`, and electrician identity/approval/availability columns. It then creates the durable outbox and offer-enqueue trigger.
6. `20261115180001_push_subscription_delivery_ledger.sql` preflights the outbox and subscription IDs, then creates `srk_private.srk_push_subscription_deliveries` with unique `(outbox_id,subscription_id)`.
7. `20261115190001_push_delivery_health_monitoring.sql` preflights both delivery tables before creating health and dead-letter recovery RPCs.
8. `20261115200001_push_delivery_lease_fencing.sql` preflights both tables, then replaces the two finish RPC signatures to require attempt-count fencing tokens.

### Additional source observations

- The durable outbox's subscription preflight requires the exact five columns supplied by `20261111020000`; this edge is explicit even though the subscription table is created months of migration-order earlier.
- The outbox preflight's `job_offers.expires_at` requirement points to `20261114210000`; its availability and identity requirements point to the profile migrations and `20261114310000`.
- The per-subscription delivery ledger references both `srk_private.srk_push_delivery_outbox(id)` and `public.srk_push_subscriptions(id)`; its preflight guards the outbox and subscription identity columns.
- The lease-fencing migration drops older function signatures and creates new signatures with an added attempt-count argument. Callers/workers must use the new signatures after this migration; function-signature consumers should be checked in application code before replay is declared complete.

**Status:** push-delivery prerequisite chain source-verified; no trigger execution, worker invocation, SQL parse, or database replay performed; runtime tests remain **NOT RUN**.


## 87. Push worker ↔ Edge Function ↔ RPC contract audit — 17 Nov 2026

The scheduled Netlify worker, Supabase Edge Function, three push-delivery migrations and the Node source-contract tests were read together. This is a source-level compatibility review, not execution.

### Confirmed interface matches

- Worker claim call: `srk_claim_push_delivery_outbox({p_limit:3})`; SQL returns table rows `outbox_id,payload,attempt_count`. Worker consumes those exact names.
- Worker sender payload adds `outbox_id`; Edge Function validates UUID, event type/schema/table, and offer record identity before processing.
- Edge Function claims per-device rows through `srk_claim_push_subscription_deliveries(p_outbox_id,p_user_id,p_limit)`; SQL returns `targets` containing `delivery_id,subscription_id,endpoint,p256dh,auth,attempt_count`, which matches sender consumption.
- All three per-device finish call sites pass `p_attempt_count`; lease-fencing migration replaces the old 3-argument finish signature with the new 4-argument signature and returns boolean. Worker likewise passes `p_attempt_count` and accepts completion only when the RPC returns JSON boolean `true`.
- Worker calls `srk_is_push_subscription_delivery_complete(p_outbox_id)` indirectly through the Edge Function; the Edge Function maps only strict boolean true to `complete:true`. Worker treats partial completion as retryable.
- Health RPC output keys `outbox.dead` and `devices.dead` match the worker's health summary reads.
- Legacy synchronous offer trigger is dropped in the outbox migration before the replacement AFTER INSERT trigger is created, preventing two intended dispatch paths from remaining active together.

### Operational risks still requiring isolated execution

1. Per-device claim limit is up to 100 and the Edge Function awaits all sends with `Promise.all`; there is no explicit per-send timeout in this function. The five-minute device lease therefore needs worst-case fan-out/timeout measurement in isolation. Do not assume the five-minute lease is sufficient solely from static review.
2. A provider 404/410 causes subscription deletion; the ledger row is removed by its FK cascade. Confirm the delete succeeds under the deployed service-role policy and verify the expected completion behavior in integration tests.
3. Web Push remains at-least-once where provider acceptance and network timeout are ambiguous. A stale lease/fencing token prevents stale database completion, but cannot retract a notification already accepted by the provider.
4. The worker processes up to three outbox items sequentially, while the schedule is every minute and leases are five minutes. Verify Netlify execution limits, overlap behavior, and stale-lease recovery under concurrent scheduled invocations.
5. Source-contract Node tests exist for outbox, per-device ledger and fencing, but they have not been executed in this audit environment. The pgTAP lease-fencing suite and isolated end-to-end test plan also remain **NOT RUN**.

**Status:** cross-component RPC names, argument keys, response fields, and signature transition source-verified. No Node test execution, Edge deployment, provider send, SQL parse, or database replay was performed.

## 88. Accounting pgTAP suites — assertion inventory and behavioral-coverage boundary — 17 Nov 2026

The two accounting-focused pgTAP files were re-read from the current Audit Branch and their test structure was counted directly.

### Static test structure confirmed

| Test file | Declared plan | `ok()` | `has_function()` | `finish()` | `rollback;` |
|---|---:|---:|---:|---:|---:|
| `admin_labour_bill_payment_accounting_bridge.test.sql` | 19 | 18 | 1 | 1 | 1 |
| `electrician_payout_reconciliation.test.sql` | 34 | 34 | 0 | 1 | 1 |

Both files' assertion totals match their declared plans. Each has one terminal `finish()` and one transaction rollback. This verifies source-file structure only; it does not establish that pgTAP accepts or executes the files.

### What the assertions actually establish if run

- The bridge suite checks existence and selected source-definition properties of the new-category Cash settlement RPC, Admin reconciliation, commission report, and electrician earnings function.
- The payout suite checks trigger-function existence/attachment, trigger timing and event bits, security-definer/search-path/execute-privilege metadata, BEFORE commission persistence, AFTER payout/parity validation, relevant update-column coverage, and alphabetical AFTER-trigger ordering.
- A substantial portion of the assertions inspect `pg_get_functiondef()` with substring searches. Those checks are useful source-contract guards, but they are not substitutes for exercising real INSERT/UPDATE transactions and observing resulting ledger rows.

### Behavioral coverage still missing or unproven

1. No captured test run exists; both suites remain **NOT RUN**.
2. The static suites do not currently demonstrate an end-to-end booking fixture covering insert, payment verification, payout creation, later edits, and rollback behavior.
3. Trigger recursion/ordering under actual row changes, duplicate payout protection, cancellation-fee exclusion, refund/reversal effects, and concurrent updates still require an isolated PostgreSQL test database.
4. A passing source-string assertion would not prove numeric correctness, transaction atomicity, RLS behavior, or runtime compatibility of the deployed function return shape.

**Status:** test plan arithmetic and file termination structure source-verified (19/19 and 34/34 planned assertions); PostgreSQL parser, pgTAP execution, accounting DML fixtures, concurrency tests, and clean replay remain **NOT RUN**. No Production access or database mutation performed.

## 89. Accounting trigger event coverage and transition-path review — 17 Nov 2026

The additive accounting bridge migration and the existing payout-writer migration were compared line-by-line at source level. This section records event coverage and control-flow observations; it does not simulate PostgreSQL trigger execution.

### Event coverage matrix

| Booking change | BEFORE commission trigger | AFTER payout writer | AFTER parity validator |
|---|---|---|---|
| Insert | Runs | Runs | Runs |
| Status / payment status | Runs | Runs | Runs |
| Assigned electrician / verified timestamp | Runs | Runs | Runs |
| Amount paid / quote status / service charge / commission rate | Runs | Runs | Runs |
| Razorpay payment ID / selected category | Runs | Runs | Runs |
| Payment method | Runs | Not listed as a writer event | Runs |
| Materials amount | Not listed as a BEFORE event | Runs | Runs |
| Direct commission amount edit | Not listed as a BEFORE event | Not listed as a writer event | Runs |

### Source-level conclusions

1. The BEFORE function writes `service_bookings.commission_amount` only after the booking is in the paid/completed/assigned/verified state and payment evidence is accepted. For selected-category bookings it requires the immutable labour bill to match the assigned electrician; for legacy bookings it requires an approved quote.
2. The existing AFTER payout writer independently calculates payout values and upserts only a pending payout row. Its trigger includes the fields that affect payout calculation, including `materials_amount`.
3. The parity validator is a later-named AFTER trigger. It checks the payout row exists and compares the booking commission with the payout ledger's `platform_commission`. Because PostgreSQL orders same-kind triggers alphabetically by trigger name, the source naming intends the payout writer to run before the `zz_` parity validator.
4. A payment-method-only edit invokes the BEFORE consistency guard and AFTER parity validator, but not the payout writer. The commission formula itself does not depend on payment method; this is coherent at source level provided the existing payout row is already present for an eligible paid booking.
5. A materials-only edit invokes the payout writer and parity validator but not the BEFORE commission trigger. This matches the legacy payout calculation where materials affect payable, not platform commission; selected-category payouts explicitly set materials to zero.
6. A direct commission-only edit invokes the parity validator but neither the BEFORE commission setter nor payout writer. The parity check is intended to reject divergence rather than silently rewrite either ledger value.
7. A transition to `payment_status='refunded'` is covered by the payout writer's payment-status event and its refund branch; both commission and parity functions return without treating the refunded booking as a newly payable completion.

### Remaining risks / evidence boundary

- The event matrix is inferred from the declared trigger column lists; actual PostgreSQL event firing and same-transaction rollback behavior are not yet executed.
- The payment-method-only path assumes an eligible payout row already exists. A malformed pre-existing paid booking without a payout row is not repaired by that event alone; the parity trigger should fail the update rather than silently manufacture a payout.
- The payout writer's upsert updates only rows whose existing status is `pending`. Blocked, paid, or refunded rows are deliberately not rewritten by the eligible-payment branch; verify each lifecycle transition with isolated fixtures.
- The current static pgTAP checks inspect trigger metadata and function source but do not exercise every event-matrix row as real DML.
- No SQL parser, PostgreSQL replay, pgTAP run, refund fixture, concurrent update, or payout lifecycle integration test was executed.

**Status:** trigger column lists, source control-flow gates, and intended alphabetical AFTER-trigger ordering source-verified. Runtime event behavior and all database tests remain **NOT RUN**. No Production or PR-branch changes performed.

## 90. Commission-report missing-payout visibility gap — 17 Nov 2026

The report functions were reviewed against the per-booking reconciliation RPC.

### Source evidence

- `srk_admin_commission_report()` builds `paid_completed` from every `service_bookings` row with `status='completed'` and `payment_status='paid'`, then uses a **LEFT JOIN** to `srk_electrician_payouts`.
- Commission, payout gross, and electrician payable are all `coalesce(...,0)`. Therefore a completed/paid booking with no payout row contributes zero commission and zero payable to aggregate totals; it is not excluded or surfaced as an exception in this report payload.
- `srk_get_my_earnings()` also LEFT JOINs the payout ledger and coalesces missing commission/payable to zero. The electrician view therefore cannot distinguish a legitimate zero amount from a missing payout row using these returned columns alone.
- In contrast, `srk_admin_get_booking_accounting_reconciliation(uuid)` explicitly appends `MISSING_PAYOUT_ROW` for an eligible completed, payment-verified booking without a payout record.

### Finding and recommended treatment

This is a **reporting visibility gap**, not proof that a payout row is currently missing. A missing ledger row is silently represented as zero in the aggregate and electrician earnings result, while the detailed Admin reconciliation can detect it.

Before calling the accounting reports fully reconciled, the owner should choose a compatible visibility contract, for example:
1. Add a missing-payout count / exception summary to the Admin report without changing the existing JSON keys; and
2. Decide whether the electrician earnings response should expose a separate reconciliation-warning field or rely on a controlled support workflow.

Do not silently replace LEFT JOIN with INNER JOIN: that would hide affected bookings from reports rather than make the inconsistency visible. No application response contract or historical migration was changed in this audit step.

**Status:** report join and coalesce behavior source-verified against the detailed reconciliation function. No database fixtures, SQL execution, or runtime report comparison performed. Finding requires owner/product approval before implementation; no Production or PR-branch changes performed.

## 91. Bootstrap SQL versus numbered-lineage admin-helper contract — 17 Nov 2026

The four root-level setup scripts and the numbered admin/RBAC migrations were compared to determine whether any one root script can safely be treated as the canonical baseline.

### Source evidence

1. `SUPABASE_SCHEMA.sql` defines the starter customer/provider tables and policies, but it does not define either `public.srk_is_admin()` or `public.is_srk_admin()`.
2. `PORTAL_SCHEMA.sql` creates `srk_admin_users`, defines `public.srk_is_admin()`, and uses that helper in its Admin RLS policies and its first version of `srk_admin_review_application(uuid,text)`.
3. `ADMIN_EMAIL_LOGIN_SETUP.sql` instead defines `public.is_srk_admin()` and recreates the Admin policies and application-review RPC using that name.
4. `COMPLETE_DATABASE_SETUP.sql` contains the portal setup and then appends the email-login compatibility patch. Its final script therefore defines both helper names and replaces the earlier application-review function with a version that calls `is_srk_admin()`.
5. The numbered lineage is written against `public.is_srk_admin()`: for example, `20261114390000_admin_staff_rbac_foundation.sql` and `20261115230000_admin_booking_direct_write_closure.sql` call it in privileged paths. The later `20261116150000_pin_admin_application_review_search_path.sql` also alters the application-review function.
6. At the source level, both bootstrap helper bodies currently test membership in the same `srk_admin_users` table against `auth.uid()`. Thus the naming split is not, by itself, proof of different authorization outcomes today.

### Finding

**No single root SQL file is demonstrated to be a canonical, numbered-migration-compatible schema baseline.** In particular, running `PORTAL_SCHEMA.sql` after the starter schema supplies `srk_is_admin()` but not the `is_srk_admin()` dependency used by later numbered admin/RBAC migrations. The consolidated setup happens to include the compatibility helper, but it is a manually assembled bootstrap artifact, not a verified replay baseline for the current migration directory.

There is also a maintenance hazard: the portal and email-login scripts each recreate similarly named Admin policies and the same application-review RPC against different helper names. Applying or editing these scripts independently can leave the project with multiple policy/helper paths whose future definitions may drift. Do not assume that duplicate policy names or helper aliases are interchangeable without checking the actual deployed policy catalog and migration order.

### Required baseline decision

- Declare one authoritative schema/bootstrap strategy (preferably the ordered numbered migration lineage after its filename/dependency issues are resolved).
- Treat the root setup SQL files as legacy/manual bootstrap artifacts unless an owner-approved, reproducible import/replay procedure proves otherwise.
- If both helper names must remain for compatibility, document one as a deliberate alias and test identical ownership, grants, volatility, search path, and call-site behavior.
- Do not rename/drop helper functions, policies, or root scripts as part of this audit. No RLS or database changes were made.

**Status:** helper definitions and call sites source-verified in the four root scripts and named numbered migrations. No clean database replay, catalog inspection, SQL parser run, or live RLS behavior test was performed. Canonical baseline remains **UNRESOLVED**.

## 92. Numbered migration chain has an external core-schema prerequisite — 17 Nov 2026

The first numbered migrations were checked for whether they establish the core marketplace tables themselves or assume those tables already exist.

### Source evidence

- The first migration, `20261108120608_add_public_api_rate_limiting.sql`, creates the `private` schema, its rate-limit table, and a service-role-only function. It does not create the marketplace's core public tables.
- The next relevant migration, `20261108121115_add_customer_account_booking_access.sql`, immediately alters `public.service_bookings`, adds a foreign key to `auth.users`, creates an index, and installs a customer SELECT policy.
- `20261108233500_restrict_public_form_inserts.sql` alters policies and privileges on both `public.service_bookings` and `public.electrician_applications`.
- `20261109000500_harden_electrician_profile_identity_linking.sql` alters `public.electrician_profiles` and references its existing `user_id`, `phone`, and `verification_status` columns.
- `20261109002000_expose_assigned_booking_map_pin.sql` joins `job_offers`, `electrician_profiles`, and `service_bookings`.
- The root-level `SUPABASE_SCHEMA.sql` contains the initial `CREATE TABLE` definitions for `service_bookings`, `electrician_applications`, and `electrician_profiles`, and later creates `job_offers`. These base definitions are not represented as an initial numbered migration in the inspected migration directory.

### Finding

**The numbered migration directory is not a self-contained empty-database bootstrap.** At minimum, the chain expects a pre-existing core schema before migration `20261108121115`; later migrations also expect the root-script tables and columns. Therefore, applying the numbered files to an empty PostgreSQL/Supabase database in filename order is not a valid clean-replay test unless a documented, versioned baseline is applied first.

This is a concrete dependency blocker, not merely a tooling limitation. It also explains why choosing `SUPABASE_SCHEMA.sql` or `COMPLETE_DATABASE_SETUP.sql` as a baseline without proving their exact historical alignment would be unsafe: they are mutable root scripts and may already include objects or policies that later migrations expect to create or replace.

### Required next step

1. Establish the exact baseline schema version that existed immediately before `20261108120608`.
2. Capture it as an immutable, owner-approved baseline artifact or reconstruct it from authoritative migration history.
3. Replay the numbered migrations from that baseline in an isolated PostgreSQL environment.
4. Record the first failure and dependency graph; do not patch historical migration identities merely to make replay pass.

**Status:** prerequisite is source-verified from the first migration files and root starter schema. No database was initialized, no SQL was executed, and no runtime replay was attempted. Canonical baseline and clean replay remain **BLOCKED / UNRESOLVED**.



## 93. Git commit history narrows the earliest available bootstrap candidate, but does not prove it was applied — 17 Nov 2026

The GitHub path histories for the three root setup artifacts and the first two numbered migrations were checked to establish their earliest recorded repository presence.

### Commit-history evidence

- `SUPABASE_SCHEMA.sql`, `PORTAL_SCHEMA.sql`, and `COMPLETE_DATABASE_SETUP.sql` all first appear in the same repository commit:
  `c4b6a46f22553e57638cdae844ec33d09bf8da2c`, dated **2026-11-08 04:15:50 UTC**.
- The first rate-limiting migration, `20261108120608_add_public_api_rate_limiting.sql`, first appears in commit `7c13153393efbef7ab2150a5068d59e59358c847`, dated **2026-11-08 12:07:14 UTC**.
- The customer-booking-access migration, `20261108121115_add_customer_account_booking_access.sql`, first appears in commit `c8144e4eabc4434603844f48aac335aada90fe1a`, dated **2026-11-08 12:12:02 UTC**.
- Thus, the three setup artifacts were present in repository history about eight hours before the first numbered migration file was committed. This is consistent with a possible pre-migration bootstrap stage.

### Finding and limits

This history **narrows the earliest available repository bootstrap candidate** to the root setup artifacts as they existed in commit `c4b6a46f22553e57638cdae844ec33d09bf8da2c`. It does **not** establish that any one of those files was executed against the database, that its schema matched the database immediately before migration `20261108120608`, or that the three scripts were intended to be applied in any particular combination/order.

The candidate set itself is not a canonical answer: `SUPABASE_SCHEMA.sql` is the starter public schema; `PORTAL_SCHEMA.sql` layers portal objects and the `srk_is_admin()` helper; `COMPLETE_DATABASE_SETUP.sql` is a consolidated artifact whose Admin helper/policy definitions differ from the standalone portal path as recorded in §91. A Git timestamp is provenance for repository availability, not deployment or database-execution evidence.

### Safe next step

- Preserve commit `c4b6a46f22553e57638cdae844ec33d09bf8da2c` as the earliest repository bootstrap snapshot for comparison only.
- Obtain the owner-approved pre-migration schema-only export or migration-ledger evidence for the actual target database.
- Compare that authoritative snapshot object-by-object with the three files at the above commit before designating a baseline.
- Until that evidence is available, do not choose or apply one root script as the canonical replay baseline.

**Status:** earliest Git introduction commits and timestamps are source-history verified. Actual execution/application provenance and schema equivalence remain **UNVERIFIED**. No source SQL, database, Production environment, or migration history was changed.


## 94. Earliest bootstrap snapshot object inventory — 17 Nov 2026

The root setup files were fetched at their earliest common repository commit `c4b6a46f22553e57638cdae844ec33d09bf8da2c`, rather than using their current mutable versions. This establishes exactly what the repository snapshot contained before the first numbered migrations were committed.

### Immutable snapshot and object inventory

| File at commit `c4b6a46` | Blob SHA | Source-level objects |
|---|---|---|
| `SUPABASE_SCHEMA.sql` | `8ae88a7035bc963b244f22c6c1450c22618ec88f` | Creates `service_bookings`, `electrician_applications`, `electrician_profiles`, and `job_offers`; adds `electrician_profiles.verification_status`; indexes and RLS setup |
| `PORTAL_SCHEMA.sql` | `efc14aa623a3895ffb3841b7b0f226f2015f34b1` | Creates `srk_admin_users`; adds `electrician_profiles.user_id`; defines profile-link trigger, `srk_is_admin()`, offer-response, application-review and commission functions; creates Admin/electrician policies |
| `COMPLETE_DATABASE_SETUP.sql` | `2b806e727f449ba18e71ad23edef805ceb2da2b5` | Consolidated copy of base and portal setup; additionally contains `srk_get_my_offer_details()` and `is_srk_admin()` compatibility path |
| `ADMIN_EMAIL_LOGIN_SETUP.sql` | `dbd91b3f912b1e0946bffe6d249a85cc41dc81cd` | Does not create base tables; expects `srk_admin_users` and operational tables to exist; defines `is_srk_admin()` and replaces Admin policies/application-review RPC |

### Dependency interpretation

1. `SUPABASE_SCHEMA.sql` is the only one of these files that creates the four core marketplace tables from scratch. It is the lowest-level root schema candidate in this snapshot.
2. `PORTAL_SCHEMA.sql` explicitly documents that it must run **after** `SUPABASE_SCHEMA.sql`. It depends on the starter tables and additionally assumes Supabase Auth's `auth.users` exists.
3. `ADMIN_EMAIL_LOGIN_SETUP.sql` is a patch, not a standalone bootstrap. It assumes the admin allow-list and marketplace tables already exist.
4. `COMPLETE_DATABASE_SETUP.sql` is a consolidated alternative to applying the base and portal scripts separately; it must not be blindly run in addition to both constituent scripts as a separate migration step.
5. The base file already creates `job_offers` and adds `electrician_profiles.verification_status`. This confirms that at least some later numbered migrations' references to these objects are compatible with a pre-existing starter-schema model, but it does not prove that the actual database was initialized from this exact blob.

### Finding

The earliest Git snapshot supports a **candidate dependency order** of `SUPABASE_SCHEMA.sql` followed by `PORTAL_SCHEMA.sql`, with `ADMIN_EMAIL_LOGIN_SETUP.sql` treated as an optional later compatibility patch. `COMPLETE_DATABASE_SETUP.sql` is a bundled alternative, not an additional step.

This is stronger provenance and object-level evidence than the current-file comparison alone, but it is still only repository evidence. It does not establish which script was executed, whether it completed successfully, or whether the target database had subsequent manual changes before migration `20261108120608`.

### Replay decision

- Use the immutable blobs above as comparison inputs only.
- Do not apply any of these scripts to Production or an existing project.
- For a future isolated replay, require owner approval of one baseline strategy and compare its complete schema/object definitions against an authoritative pre-migration schema-only export first.
- Continue to treat clean replay as blocked until that authoritative equivalence check is available.

**Status:** all four file blobs and source-level object inventories at the earliest common commit are verified. The base-versus-portal dependency order is documented in the source comments and corroborated by object references. Actual database execution history remains **UNVERIFIED**; no SQL or database was changed.


## 95. GPT-1 handover और GPT-2 Audit Branch का cross-workstream reconciliation — 17 Nov 2026

GPT-1 द्वारा दिए गए handover को PR #8 के live GitHub head और GPT-2 Audit Branch के source files से मिलाया गया। यह section केवल source/history/status evidence दर्ज करता है; कोई SQL runtime, provider settlement, database migration या deployment action नहीं किया गया।

### 95.1 PR head और CI/deploy status

- PR #8 वर्तमान में **OPEN / DRAFT / UNMERGED** है; head branch `feat/customer-login-first-dashboard-20261114`, head commit `4638c7277c62cdf3fb23cd1899b8683775c480d1` है।
- उसी commit के GitHub commit statuses में **Vercel = success** और **Netlify Deploy Preview = success** दर्ज हैं।
- उसी commit के GitHub Actions workflow run `44025615076` में **Feature Branch Node tests = success** है।
- Netlify check-runs में redirect/header processing checks भी success हैं।
- PR discussion में पहले के Vercel deployment-limit failures मौजूद हैं; वे पुराने attempts हैं। वर्तमान head के ऊपर का status success है। इसलिए handover का current-status दावा सही है, पर पुराने failures को इतिहास से मिटाया नहीं जाना चाहिए।
- ये CI/deploy statuses PostgreSQL migration replay, pgTAP execution, live Route settlement या payment-provider evidence का प्रमाण नहीं हैं।

### 95.2 दोनों branches का Git graph — direct merge/replay सुरक्षित नहीं

`chore/pr8-replay-audit-20261116-v2` को base और PR feature branch को head रखकर GitHub compare result:

- Audit Branch HEAD: `af8060bf6ad010cbd75d4eaf056e6601bfffe309`
- Feature Branch HEAD: `4638c7277c62cdf3fb23cd1899b8683775c480d1`
- Merge base: `dc8b4f723ac7ae896eeb516336dd4b28577390b5`
- Feature branch: Audit Branch से **57 commits ahead** और **222 commits behind**; compare status **diverged**।

इसलिए دونوں branches को एक-दूसरे का simple superset नहीं माना जा सकता। पूरा branch merge, blanket cherry-pick या branch reset बिना file-by-file reconciliation और owner approval के नहीं करना चाहिए। GPT-2 का यह audit report Feature Branch पर मौजूद नहीं है; GPT-2 का accounting bridge migration भी Feature Branch पर नहीं मिला।

### 95.3 Manual Refund — blocked payout note overwrite की पुष्टि

दोनों branches पर `supabase/migrations/20261115130000_admin_manual_refund_request_completion.sql` का समान blob SHA है:

`51f3b13adc80e117cc62f05b0e70ae795ee0f9fd`

Source inspection से:

- पहले से `blocked` payout को function अलग-अलग reason/note के साथ preserve नहीं करता।
- Refund completion पर function सीधे `payout_status='refunded'` और `payout_note='Manual refund completed'` लिखता है।
- अतः पहले से blocked payout का पुराना `payout_note` overwrite हो जाता है। GPT-1 handover का यह review point **CONFIRMED** है।
- यदि payout पहले `pending` हो तो function पहले `Manual refund processed` note लिखता है और फिर completion पर उसे `Manual refund completed` से बदलता है। यह transition note भी final record में सुरक्षित नहीं रहता।

**स्थिति:** behavior review आवश्यक है। कोई SQL fix इस reconciliation pass में नहीं किया गया। अपेक्षित audit policy तय हो: पुराना block reason immutable/history field में रखा जाए या final note में मूल reason को स्पष्ट रूप से carry किया जाए। केवल note को छोड़ देना भी पर्याप्त नहीं, क्योंकि status transition का audit trail चाहिए।

### 95.4 Manual Refund test contract में Audit Branch stale assertion

- Feature Branch test blob: `2db704e98a59cc7291a586370a5be5275eca2e12`
- Audit Branch test blob: `99cb0eb02e667699db27951b5b26161a89b8951b`
- Feature Branch test अब function के direct payout update contract को जांचता है: `payout_status='refunded'` और blocked payout closure failure guard।
- Audit Branch test में पुरानी अपेक्षा है कि booking update trigger payout बंद करेगा और function बाद में payout row को दोबारा SELECT करके verify करेगा। वही अपेक्षित SELECT source function में मौजूद नहीं है; migration source दोनों branches में समान है।

इसलिए Audit Branch का manual-refund test assertion source implementation के साथ **STALE / INCONSISTENT** है। Feature Branch वाला नया test contract source के वर्तमान direct-update path के अधिक अनुरूप है, पर दोनों suites को PostgreSQL पर चलाए बिना runtime pass नहीं कहा जा सकता।

### 95.5 Razorpay refund recovery — Feature Branch में अतिरिक्त replay repair

Migration `20261115250000_harden_refund_reconcile_full_amount.sql` दोनों branches पर अलग है:

- Feature Branch blob: `0bdae500bcfda3721d8de4371695be08ba8e5f36`
- Audit Branch blob: `3bda81c2b827f597f639846d33967a7c88296e21`

Feature Branch में अतिरिक्त logic है जो पहले से `processed` refund को replay करते समय ऐतिहासिक `blocked` payout को `refunded` में repair करता है, बशर्ते block note अपेक्षित `Razorpay refund pending` हो। Audit Branch की version में यह repair path नहीं है।

इसी प्रकार संबंधित test files भी अलग हैं:

- Feature Branch test blob: `52f5e13981cf5a80d0ac4f2033429a04037c36c6`
- Audit Branch test blob: `fd5b7ceb8e612b588fac1a7ade8d7035388ca2bc`

Feature Branch test में payout close/replay-repair और fail-closed state assertions शामिल हैं; Audit Branch का test छोटा, पुराना five-assertion contract है। यह Feature Branch का substantive correction है जिसे GPT-2 के future audit baseline में review करके लाना होगा; इसे स्वतः स्वीकार या cherry-pick नहीं किया गया।

### 95.6 Route Settlement — दोनों branches के RPC contracts में महत्वपूर्ण टकराव

Accounting reconciliation test files अलग हैं:

- Feature Branch blob: `7b76ce5a20be5c42d76094b937d42fbb6bd22d08`
- Audit Branch blob: `110be3942aaec522ebcaa1d3d34643daea1450c4`

Feature Branch test में final RPC के वास्तविक Route settlement evidence fields, transfer rows/count और recipient/payment/amount/state validation अपेक्षित हैं। Commit `4638c727...` की नई 75वीं assertion यह जांचती है कि Admin UI के लिए `route_provider_settlement_verified` और `route_settlement_evidence_status` fields लौटते हैं।

Audit Branch के test contract में इसके विपरीत retired-ledger compatibility response अपेक्षित है: `route_ledger_retired_no_route_transfers`, खाली `route_transfers`, zero count और zero transfer amounts। यह केवल assertion naming का अंतर नहीं; दोनों branches Route ledger के व्यवहार पर अलग product/schema contract मानती हैं।

**स्थिति:** Route Settlement contract को owner/product decision और वास्तविक Razorpay Route transfer/provider settlement evidence के साथ resolve करना जरूरी है। केवल static JSON key assertion वास्तविक provider settlement का प्रमाण नहीं है। कोई provider API, bank transfer या live ledger जांच इस review में नहीं हुई।

### 95.7 GPT-2 Accounting Bridge और PR Feature scope

- GPT-2 का additive migration `20261117010000_reconcile_booking_commission_and_manual_payment_method.sql` Audit Branch पर मौजूद है; Feature Branch fetch में यह file नहीं मिली।
- इस migration में BEFORE commission assignment, AFTER payout writer parity validation, manual payment-method consistency और reconciliation RPC parity checks शामिल हैं।
- इसे Feature Branch में स्वतः copy करना सुरक्षित नहीं है: दोनों branches diverged हैं और Feature Branch में payout/refund/Route functions के अलग versions हैं। Trigger ordering, payout writer behavior, refund reversal और Route accounting के साथ संयुक्त review जरूरी है।
- GPT-1 handover के 31 SQL test files और static plan/assertion count match को handover claim के रूप में दर्ज किया गया है; इस pass में सभी 31 files का count दोबारा independently नहीं चलाया गया। PostgreSQL/pgTAP runtime execution अभी भी **NOT RUN** है।

### 95.8 संयुक्त निष्कर्ष और सुरक्षित अगला कदम

| विषय | Reconciliation स्थिति |
|---|---|
| PR #8 head / open-draft state | GitHub verified |
| Current Node / Vercel / Netlify statuses | Current head पर success verified |
| Branch graph | Diverged; direct merge unsafe |
| Manual Refund old payout_note | Overwrite confirmed; correction pending |
| Manual Refund test | Audit Branch assertion stale; Feature test newer |
| Razorpay refund replay repair | Feature-only substantive addition; review/port pending |
| Route Settlement | Conflicting branch contracts; product/provider evidence decision pending |
| GPT-2 commission/payment bridge | Audit-only; cross-branch integration review pending |
| Clean migration replay / pgTAP runtime | Blocked / not executed |
| Production / Test Supabase changes | None performed by this reconciliation |

**Release gate:** PR #8 को Draft ही रखें। Branch contracts को resolve करें, manual refund block-reason audit behavior तय करें, GPT-2 accounting bridge को Feature Branch के current source के विरुद्ध integrate/review करें, और owner-approved isolated PostgreSQL baseline पर complete migration replay तथा pgTAP runtime pass मिलने तक merge/production release न करें।

**Safety record:** इस reconciliation में केवल GitHub source, commit graph, PR metadata, statuses और test/migration text पढ़े गए। कोई source SQL edit, branch merge, workflow dispatch, Supabase query/migration, provider refund, payout, bank transfer या deployment action नहीं किया गया।


## 96. Manual Refund audit-trail policy और Route settlement evidence boundary — 17 Nov 2026

यह follow-up केवल दोनों branch के source और test contract का अतिरिक्त static review है। कोई SQL runtime, provider API, bank transfer, database या deployment action नहीं किया गया।

### 96.1 Manual Refund payout-note overwrite — exact write sequence

दोनों branches पर migration `supabase/migrations/20261115130000_admin_manual_refund_request_completion.sql` का blob समान है: `51f3b13adc80e117cc62f05b0e70ae795ee0f9fd`।

Function का source sequence:
1. यदि payout पहले `pending` है, तो पहले `payout_status='blocked'` और `payout_note='Manual refund processed'` लिखता है।
2. Refund evidence insert और booking को `refunded` करने के बाद, उसी payout पर `payout_status='refunded'` और `payout_note='Manual refund completed'` लिखता है।
3. यदि payout पहले से `blocked` था, तो step 1 नहीं चलता; फिर भी step 2 उसका पुराना note overwrite कर देता है।

इससे दो अलग audit facts खोते हैं: (a) पहले से blocked payout का मूल reason, और (b) pending से blocked होकर refund-finalized होने का intermediate transition। यह source-level confirmed behavior है, runtime reproduction नहीं।

**Recommended contract (implementation से पहले owner approval):** payout status transition का append-only audit event सुरक्षित किया जाए, जिसमें payout ID, booking ID, prior status, prior note, new status, new note, actor, timestamp और refund evidence reference हों। Final `payout_note` को अकेले history store न माना जाए। पहले से blocked payout को बिना उसके मूल reason को history में सुरक्षित किए close न किया जाए। इस change के साथ pgTAP assertions हों जो पहले से blocked और pending — दोनों paths में पुराना note तथा transition event सुरक्षित होने की पुष्टि करें। कोई schema/function edit इस section में नहीं किया गया।

### 96.2 Route settlement — Feature Branch का अधिक सटीक contract

Feature Branch की migration `20261115180000_admin_route_recipient_and_settlement_validation.sql` का blob SHA `58042f828aeb1a951b36191d68a0573cdc15fcc0` है। इसमें `srk_route_transfers` से transfer rows/count पढ़े जाते हैं और recipient, linked account, payment ID, amount, transfer state तथा settlement state की validations हैं। Test blob SHA `7b76ce5a20be5c42d76094b937d42fbb6bd22d08` इन contracts को assert करता है।

महत्वपूर्ण सीमा: Feature Branch का source स्वयं `route_provider_settlement_verified=false` और `ROUTE_PROVIDER_SETTLEMENT_NOT_INDEPENDENTLY_VERIFIED` लौटाता है। इसलिए यह **Route ledger evidence और consistency validation** है; यह बैंक/provider द्वारा वास्तविक settlement का प्रमाण नहीं है। Admin UI में settlement evidence keys होना भी provider verification सिद्ध नहीं करता।

Audit Branch की read-only reconciliation migration `20261115170000_admin_route_transfer_accounting_reconciliation.sql` (blob `9238fde16407710c208cc3d2156526c361cf4aea`) Route ledger को retired मानती है और transfer rows query नहीं करती। अतः दोनों branch contracts का वास्तविक अंतर है:
- Feature: Route ledger मौजूद होने पर internal transfer records और state checks पढ़ता है, लेकिन independent provider settlement को unverified बताता है।
- Audit: retired ledger compatibility response और zero Route transfers बताता है।

**Owner decision required:** क्या PR #8 में Route transfers सक्रिय/समर्थित feature हैं, या Route ledger retired है और manual payout authoritative है? इस निर्णय के बाद schema, migration order, RPC JSON contract, Admin UI, service-role writer और tests को एक ही contract में align करना होगा। वास्तविक provider settlement verification अलग evidence source और process से ही आ सकती है। कोई provider/bank check नहीं किया गया।

### 96.3 Cross-branch test scope reminder

Feature Branch में `supabase/tests/database/accounting_reconciliation_readonly_contract.test.sql` का Route test contract मौजूद है; Audit Branch के पुराने accounting contract में retired-ledger assumptions हैं। Static source assertions किसी भी branch में SQL function compile, actual table availability, RLS/grants, pgTAP pass या live settlement prove नहीं करतीं। PostgreSQL replay और pgTAP runtime अब भी release gate हैं।

### 96.4 स्थिति

- Manual Refund note/history behavior: **source-level confirmed issue; fix not applied**.
- Route ledger product contract: **owner decision required**.
- Provider settlement: **not independently verified**.
- SQL runtime / pgTAP: **not run**.
- Feature Branch / Main / Supabase / Production: **unchanged by this follow-up**.


## 97. Accounting Bridge बनाम Feature Route RPC — function replacement compatibility gate — 17 Nov 2026

इस section में GPT-2 Audit Branch पर मौजूद accounting bridge migration और उसके tests का source-level review किया गया। कोई migration execute, SQL parser, pgTAP runtime या branch integration नहीं की गई।

### 97.1 Exact source identity

- Migration: `supabase/migrations/20261117010000_reconcile_booking_commission_and_manual_payment_method.sql`
- Audit Branch blob SHA: `68189051090a51bef26a98997caf103b62ed070c`
- Test: `supabase/tests/database/admin_labour_bill_payment_accounting_bridge.test.sql`
- Test blob SHA: `7db3d4e5bec75100acc6f892bbcdfe7f29f0f3b7`
- Companion payout test: `supabase/tests/database/electrician_payout_reconciliation.test.sql`
- Companion test blob SHA: `88184e2e1fb386f16d6bd339556a15a5b87275d2`
- यह migration GPT-2 Audit Branch पर है; Feature Branch पर इसी path की मौजूदगी इस review में स्थापित नहीं हुई।

### 97.2 BEFORE commission / AFTER payout parity — static contract

Bridge migration में `zz_srk_set_booking_commission_before_payout` BEFORE trigger immutable labour bill या approved quote से commission निकालकर `service_bookings.commission_amount` सेट करता है। Existing payout writer को बदलने के बजाय `zz_srk_validate_booking_commission_payout_parity` AFTER trigger payout ledger में लिखी commission से persisted booking commission का मिलान करता है।

Companion test में trigger existence, BEFORE/AFTER timing flags, payout writer और parity validator के alphabetical trigger order, और commission formula की static assertions हैं। यह सही intended ordering का source/test contract है; PostgreSQL catalog में वास्तविक trigger execution order अभी runtime पर प्रमाणित नहीं है।

### 97.3 HIGH PRIORITY: accounting RPC replacement Feature Route fields मिटा सकता है

Bridge migration केवल नया helper जोड़ती नहीं है; यह उसी signature वाली function को पूरा `CREATE OR REPLACE` करती है:

`public.srk_admin_get_booking_accounting_reconciliation(uuid)`

Bridge की replacement body के JSON response में payout, refund, cancellation-fee और wallet reconciliation fields हैं, लेकिन Feature Branch के Route contract वाले keys/fields — `route_transfers`, `route_transfer_count`, `route_provider_settlement_verified`, `route_settlement_evidence_status` — शामिल नहीं हैं।

Feature Branch का accounting reconciliation contract इन्हीं Route fields को Admin UI के लिए सुरक्षित रखता है और transfer evidence/consistency checks करता है। इसलिए यदि GPT-2 bridge migration को Feature Branch में सीधे cherry-pick/merge किया जाए और यह replacement बाद में लागू हो, तो Feature Route reconciliation JSON contract हट सकता है, भले ही Route migration पहले लागू हो चुकी हो।

**Required integration rule:** इस bridge को Feature Branch में तभी integrate किया जाए जब एक संयुक्त RPC body तैयार हो जो दोनों पक्षों के आवश्यक accounting fields और Route validation logic को साथ रखे; उसके बाद Admin UI contract tests और pgTAP assertions उसी final function body के विरुद्ध अपडेट हों। केवल migration filename या commit order से इसे सुरक्षित integration न मानें। Audit Branch पर भी यह bridge वर्तमान Route-retired contract के साथ ही समझा जाए।

### 97.4 Manual payment evidence behavior — review point

BEFORE trigger matching amount के साथ manual payment method की case/whitespace-normalized equality जाँचता है और mismatch मिलने पर `MANUAL_PAYMENT_METHOD_MISMATCH` raise करता है। लेकिन commission finalization path में valid matching manual evidence या Razorpay payment ID न मिलने पर trigger `return new` करता है; इस trigger से अकेले यह सिद्ध नहीं होता कि पूरा payment/payout workflow fail-closed है। Existing payout writer, payment-verification RPC और caller path के साथ end-to-end isolated tests जरूरी हैं।

### 97.5 स्थिति और gate

- BEFORE commission / AFTER payout parity design: **static source/test contract मिला; runtime unverified**.
- Bridge RPC बनाम Feature Route JSON: **confirmed replacement compatibility hazard**.
- Direct cherry-pick/merge: **न करें; unified RPC contract पहले आवश्यक**.
- Manual payment evidence: **trigger-level mismatch guard मौजूद; complete workflow fail-closed behavior अभी runtime में सिद्ध नहीं**.
- PostgreSQL clean replay और pgTAP: **not run**.
- Feature Branch, Main, Supabase और Production: **इस review में unchanged**.


## 98. Accounting Bridge pgTAP files — assertion nature and behavioral coverage gap — 17 Nov 2026

दोनों Accounting Bridge test files को पूरा पढ़कर assertion-by-assertion scope review किया गया। यह test-source review है; tests execute नहीं किए गए।

### 98.1 Labour Bill Accounting Bridge test

File: `supabase/tests/database/admin_labour_bill_payment_accounting_bridge.test.sql`
Blob SHA: `7db3d4e5bec75100acc6f892bbcdfe7f29f0f3b7`
Declared plan: `19`.

इस file के 19 checks में function existence और `pg_get_functiondef` के source-text substring checks हैं। वे Admin Cash RPC में Main Admin guard, booking lock, Cash-only guard, immutable labour bill, amount formula, receipt/wallet writes; reconciliation/receipt source fields; manual payment method comparison; तथा commission report/payout-ledger references की उपस्थिति जाँचते हैं।

इस file में test fixture के रूप में booking/payment rows insert करके RPC invoke करने, expected SQLSTATE verify करने, या actual ledger rows/amounts compare करने वाले behavioral scenarios नहीं हैं। इसलिए 19/19 pass होने पर भी वह source text contract की पुष्टि होगी, payment flow की वास्तविक सफलता/विफलता की नहीं।

### 98.2 Electrician Payout Reconciliation test

File: `supabase/tests/database/electrician_payout_reconciliation.test.sql`
Blob SHA: `88184e2e1fb386f16d6bd339556a15a5b87275d2`
Declared plan: `34`.

इस file में trigger attachment/timing, SECURITY DEFINER/search_path/privileges, Admin payout RPC के source guards, payout formula, refund transition branches, BEFORE/AFTER trigger presence, और trigger-name ordering की catalog/source assertions हैं। ये महत्वपूर्ण structural contracts हैं।

लेकिन यह भी actual booking बनाकर payment verification, payout row creation, refund transition, paid-payout preservation, concurrent settlement या rollback behavior execute नहीं करती। खासकर alphabetical AFTER trigger ordering का assertion catalog names की min/max तुलना है; actual transaction behavior का runtime proof नहीं।

### 98.3 Required isolated behavioral test matrix

Owner-approved isolated PostgreSQL baseline उपलब्ध होने पर कम-से-कम ये behavior cases जोड़ें:

1. Valid Cash manual evidence + matching booking method → booking commission और payout ledger commission समान।
2. Amount match लेकिन payment method mismatch → transaction fail; कोई payout/ledger side effect न बचे।
3. Manual evidence method या booking method NULL → fail-closed expected behavior स्पष्ट रूप से assert हो।
4. Valid Razorpay payment evidence → commission और payout parity।
5. Missing immutable labour bill / wrong electrician assignment / invalid commission rate → expected error और rollback।
6. Existing pending payout पर full refund → refund-owned transition; unrelated Admin-blocked और already-paid payout untouched।
7. दो concurrent Admin payout attempts → केवल एक successful settlement; duplicate ledger/payment नहीं।
8. Commission/payout parity validator failure → उसी transaction में payout writer का side effect rollback हो।

इन tests को वास्तविक pgTAP fixtures और SQLSTATE/row assertions के रूप में लिखें; केवल `pg_get_functiondef` substring assertions पर्याप्त नहीं हैं।

### 98.4 Release gate

- दोनों test files का static assertion scope: **reviewed**.
- वास्तविक pgTAP pass/fail: **unknown — not run**.
- Behavioral payment/payout/refund matrix: **not present in these two files; required**.
- Isolated DB baseline और clean migration replay: **अब भी prerequisite**.
- कोई SQL source, Feature Branch, Main, Supabase या Production बदलाव इस review में नहीं किया गया।


## 99. Manual payment NULL-method evidence can pass payout writer — static source finding — 17 Nov 2026

### 99.1 संबंधित source और blob

- Payout writer: `supabase/migrations/20261114360000_new_category_electrician_payout_reconciliation.sql` — blob `5412f1c9cc628f919aa915dd82cf4bc80cb048d3`.
- Trigger re-attachment / same writer body: `supabase/migrations/20261116210000_attach_electrician_payout_reconciliation_trigger.sql` — blob `b12da77471d510b55f798bd089597d866d79a133`.
- BEFORE commission + payment-method guard: `supabase/migrations/20261117010000_reconcile_booking_commission_and_manual_payment_method.sql` — blob `68189051090a51bef26a98997caf103b62ed070c`.
- Manual-payment bridge test: `supabase/tests/database/admin_labour_bill_payment_accounting_bridge.test.sql` — blob `7db3d4e5bec75100acc6f892bbcdfe7f29f0f3b7`.
- Payout reconciliation test: `supabase/tests/database/electrician_payout_reconciliation.test.sql` — blob `88184e2e1fb386f16d6bd339556a15a5b87275d2`.

### 99.2 Exact control-flow gap

Payout writer `srk_create_electrician_payable()` accepts manual evidence when a row exists for the booking and its amount matches `amount_paid`. Its EXISTS condition does **not** require `payment_method` to be non-NULL or equal to the booking's `payment_method`.

The BEFORE trigger `srk_set_booking_commission_before_payout()` has two relevant paths:
- It raises `MANUAL_PAYMENT_METHOD_MISMATCH` when a same-amount manual row has a method distinct from the booking method.
- For commission finalization, it only treats manual evidence as valid when both methods are non-NULL and normalized-equal; otherwise it returns NEW without setting commission.

If both the manual evidence method and booking method are NULL, `IS DISTINCT FROM` is false, so the mismatch exception does not fire. The valid-evidence EXISTS is also false because of the explicit non-NULL predicates. However, the AFTER payout writer's amount-only EXISTS is true. Thus the payout writer can proceed despite the absence of a valid method match. Depending on prior commission state and the parity validator, the later AFTER parity check may reject the transaction; that does not turn the payout writer's own evidence predicate into a fail-closed method check.

If one method is NULL and the other is non-NULL, the BEFORE mismatch guard should raise for a same-amount manual row. The specific uncovered case is both NULL (and any writer invocation not preceded by the intended BEFORE trigger, which must be checked against the actual installed schema).

### 99.3 Required correction and tests

Recommended correction: make the payout writer's manual-evidence predicate identical to the commission trigger/reconciliation contract:
- evidence method IS NOT NULL;
- booking method IS NOT NULL;
- `lower(btrim(e.payment_method)) = lower(btrim(new.payment_method))`;
- amount matches the verified booking amount.

Do not silently treat missing method as valid. Decide explicitly whether a NULL method is rejected with a stable exception or leaves payment unverified and blocks payout creation.

Add behavioral cases for (a) both methods NULL, (b) evidence method NULL / booking method set, (c) evidence method set / booking method NULL, (d) normalized equal values, and (e) normalized unequal values. Assert payout row absence/presence, commission parity, and full transaction rollback.

Existing tests assert that the BEFORE function contains a mismatch token and that reconciliation contains a method comparison, but do not execute these NULL combinations. Section 98 records the broader static-vs-runtime limitation.

### 99.4 Confidence and gate

- Static control-flow gap in payout writer predicate: **confirmed by source**.
- Whether the full installed trigger chain always prevents a committed inconsistent payout: **not runtime verified**.
- Fix: **not applied**; requires isolated PostgreSQL test and owner-approved source correction.
- No Feature Branch, Main, Supabase, Production or payment data changed.


## 100. NULL manual-method path may retain stale commission and pass parity — conditional static finding — 17 Nov 2026

Section 99 के NULL-method gap को BEFORE/AFTER trigger के पूरे source order के साथ और संकीर्ण रूप से जाँचा गया।

### 100.1 Control-flow

Migration `20261117010000_reconcile_booking_commission_and_manual_payment_method.sql`:
- BEFORE trigger `zz_srk_set_booking_commission_before_payout` manual evidence को valid तभी मानता है जब दोनों methods non-NULL और normalized-equal हों।
- यदि methods दोनों NULL हों, mismatch check का `IS DISTINCT FROM` false होता है और valid-evidence check false; function `return new` कर देता है। इस branch में वह `commission_amount` को NULL या किसी नए मान पर reset नहीं करता।
- PostgreSQL UPDATE में untouched column का पुराना value NEW row में बना रहता है; इसलिए पहले से मौजूद `commission_amount` इस early-return path में stale value के रूप में रह सकता है।
- AFTER trigger `srk_reconcile_electrician_payable` amount-only manual evidence predicate से payout row बना सकता है।
- उसके बाद alphabetically later `zz_srk_validate_booking_commission_payout_parity` payout commission और booking `commission_amount` compare करता है। यदि stale commission पुराने/वर्तमान computed commission के बराबर है, तो parity check इस अकेले कारण से fail नहीं होगा।

### 100.2 Risk statement

इसलिए दोनों payment methods NULL होने पर यह केवल संभावित “commission NULL रह गया, parity fail हो गई” मामला नहीं है। यदि booking row में पहले से matching non-NULL commission_amount है, और बाकी labour bill/payment/booking preconditions valid हैं, तो source control-flow payout writer को चलने देता है और parity assertion भी समान numeric commission के कारण pass कर सकती है।

यह source-level conditional path है; इसे live/isolated database में execute नहीं किया गया। Existing data में ऐसा prior commission state है या नहीं, इसकी जाँच नहीं की गई।

### 100.3 Recommended fail-closed correction

- Commission BEFORE trigger में manual evidence absent/invalid होने पर stale `commission_amount` को preserve न करें; payment transition को स्पष्ट exception से रोकें या commission reset करके payout writer को रोकने वाला एक consistent state contract लागू करें।
- Payout writer में manual evidence predicate को भी method non-NULL + normalized equality से बाँधें।
- AFTER parity validator में manual payment evidence validity अलग से assert करें; केवल दो commission numbers बराबर होना payment evidence का विकल्प नहीं है।
- Regression tests में पुराने matching `commission_amount` वाले booking पर दोनों methods NULL रखकर payment-paid transition चलाएँ; transaction rollback और payout row absence assert करें। साथ में NULL/non-NULL asymmetric और normalized-equal/unequal cases भी शामिल हों।

### 100.4 Status

- BEFORE early-return stale-value preservation: **source से confirmed**.
- AFTER payout + parity conditional path: **source से confirmed**.
- Actual committed inconsistent row in an installed database: **not proven; runtime test required**.
- Fix or data mutation: **not performed**.
- No Feature Branch, Main, Supabase or Production changes.


## 101. NULL-method trigger path की intended Admin RPC reachability सीमा — 17 Nov 2026

Section 100 के conditional NULL-method path को official legacy Admin manual-payment entry point के विरुद्ध cross-check किया गया।

### 101.1 Intended RPC guard

Migration `20261115210000_legacy_manual_payment_and_itemized_receipt.sql`, function `srk_admin_record_manual_payment(uuid,text,text,text)`:
- Authenticated Main Admin check करता है।
- `p_method` NULL होने पर `INVALID_MANUAL_PAYMENT_METHOD` देता है; allowed values केवल `cash`, `upi`, `bank_transfer` हैं।
- पहले booking को `FOR UPDATE` lock करता है और existing payment state को unpaid/pending तथा unverified होना आवश्यक करता है।
- उसी transaction में manual evidence row insert करता है, फिर booking पर `payment_method=p_method`, `payment_status='paid'`, `payment_verified_at=clock_timestamp()` और commission update करता है।
- Payout row insert/verify भी उसी RPC transaction में करता है।

### 101.2 Impact on Section 100

इसलिए Section 100 का दोनों-methods-NULL वाला path इस official Admin manual-payment RPC के सामान्य उपयोग से उत्पन्न नहीं होना चाहिए। यह अब भी legacy/pre-existing malformed data, किसी अन्य privileged write path, या direct database maintenance path के लिए source-level guard gap है; intended RPC द्वारा सामान्य user/admin input से सिद्ध exploit नहीं है।

### 101.3 Status and required test

- Official Admin RPC rejects NULL method and writes evidence + booking + payout in one transaction: **source-confirmed**.
- Section 100 conditional trigger path: **source-confirmed**, but its reachability through official RPC is **not supported**.
- Runtime proof that no alternate writer can create this state: **not available**.
- No code changes to payment RPC, no data changes, and no database execution performed.

Audit recommendation: add a regression test asserting NULL `p_method` is rejected with `INVALID_MANUAL_PAYMENT_METHOD`, and separately test a pre-existing paid booking with both method fields NULL to ensure later updates fail closed rather than relying on a stale commission value.


## 102. payment_method-only UPDATE पर payout writer दोबारा नहीं चलता — 17 Nov 2026

तीनों trigger event lists का cross-check:
- BEFORE commission trigger `zz_srk_set_booking_commission_before_payout` की `UPDATE OF` list में `payment_method` शामिल है।
- Commission parity AFTER trigger `zz_srk_validate_booking_commission_payout_parity` की `UPDATE OF` list में भी `payment_method` शामिल है।
- Payout writer AFTER trigger `srk_reconcile_electrician_payable` की `UPDATE OF` list में `payment_method` शामिल **नहीं** है।

अर्थात केवल `service_bookings.payment_method` बदलने वाला UPDATE BEFORE evidence guard और parity check चलाता है, लेकिन payout writer फिर से नहीं चलता। BEFORE guard सामान्यतः existing manual evidence method mismatch पर exception देता है। दोनों evidence/booking methods NULL होने पर उसका `IS DISTINCT FROM` mismatch guard false होता है; parity validator फिर भी केवल commission-vs-payout amount देखता है, manual evidence method validity नहीं।

यह Section 100 की reachability nuance को मजबूत करता है: legacy/pre-existing NULL-method state में केवल booking method field का update payout writer द्वारा repair/reconcile नहीं होगा; और parity trigger payment-method validity को स्वतंत्र रूप से assert नहीं करता।

### Status

- Trigger event-list asymmetry: **source-confirmed**.
- सामान्य Admin RPC से NULL-method creation: **official RPC guard द्वारा रोका गया** (Section 101).
- Existing malformed NULL-method row पर payment_method-only update से invalid evidence स्वतः repair होना: **नहीं; source में ऐसा mechanism नहीं**.
- Actual row mutation/commit या runtime behavior: **not tested**.
- No source fix, data update, or database execution performed.

Recommendation: payment-method validity assertion को parity validator में भी जोड़ें, और payout writer trigger को `payment_method` updates पर attach करने की जरूरत है या नहीं—product/data contract के अनुसार तय करें। यदि attach किया जाए तो upsert side effects और paid/blocked/refunded payout guards के regression tests अनिवार्य हैं।


## 103. Official legacy manual-payment RPC vs payout trigger amount parity — source alignment confirmed — 17 Nov 2026

Migration `20261115210000_legacy_manual_payment_and_itemized_receipt.sql` के `srk_admin_record_manual_payment(uuid,text,text,text)` को payout writer और commission bridge के साथ cross-check किया गया।

### 103.1 Calculation alignment

- RPC केवल legacy approved-quote booking स्वीकार करता है; `selected_category IS NOT NULL` पर dedicated settlement की ओर रोकता है।
- यह service और materials को paise में round करके total बनाता है और `quoted_amount` से exact match माँगता है।
- Commission केवल service/labour पर calculate होती है; materials पर platform commission नहीं लगाया जाता।
- RPC booking को paid/verified और method-set करता है, फिर payout insert करता है; उसी booking UPDATE पर payout AFTER trigger भी चल सकता है।
- Payout trigger legacy approved quote के लिए service + materials total validate करता है, commission service amount पर calculate करता है और electrician payable = service + materials - commission लिखता है।
- RPC की commission/payable calculation और trigger की 2-decimal calculation source में समान formula पर आधारित हैं। RPC बाद में payout row को electrician, status pending, service, materials, commission, payable और Razorpay ID NULL के विरुद्ध verify करता है।
- Existing payout mismatch होने पर RPC exception उठाता है; transaction atomicity के कारण payment evidence/booking update/payout changes rollback होने चाहिए। यह PostgreSQL runtime में अभी execute नहीं किया गया।

### 103.2 Trigger ordering / side-effect boundary

- `srk_reconcile_electrician_payable` AFTER trigger booking UPDATE पर payout upsert करता है।
- RPC का explicit payout INSERT `ON CONFLICT (booking_id) DO NOTHING` है; इसके बाद row lock करके expected values जाँची जाती हैं।
- Trigger का conflict UPDATE केवल `payout_status='pending'` पर होता है। Paid/blocked/refunded rows को यह upsert overwrite नहीं करता।
- Parity AFTER trigger alphabetically बाद में चलता है और booking commission को payout platform commission से compare करता है।

### 103.3 Status

- Official legacy RPC input guards and amount formulas: **source-confirmed**.
- RPC/trigger calculation contract alignment: **source-confirmed**.
- Existing payout mismatch rejection path: **source-confirmed**.
- Transaction rollback, concurrent RPC calls, and trigger execution order in an actual PostgreSQL instance: **not runtime-verified**.
- No source changes, DB execution, or payment/payout mutation performed.

यह finding Section 99–102 के NULL-method/alternate-write-path caveats को सीमित करती है: official RPC का सामान्य valid manual-payment path method, evidence, booking और payout को एक coherent transaction में बाँधता है; remaining uncertainty alternate privileged paths, legacy rows, concurrency और actual runtime proof की है।


## 104. Manual Payment evidence table access and audit trail — source review — 17 Nov 2026

Migration `20261114125844_restore_financial_audit_core_schema.sql` में `srk_manual_payment_entries` की schema, grants, RLS और audit trigger जाँचे गए।

### 104.1 Table constraints and direct access

- `booking_id` पर UNIQUE constraint है: प्रति booking एक manual-payment evidence row.
- `payment_method` NOT NULL और allowed values `cash`, `upi`, `bank_transfer` तक सीमित हैं.
- Amount positive और maximum ₹1,00,00,000 तक constrained है; payment reference trimmed length 4–120; note maximum 250 characters.
- `recorded_by` और `recorded_at` evidence provenance देते हैं.
- RLS enabled है; `PUBLIC`, `anon`, `authenticated` से table privileges revoke हैं; table privileges केवल `service_role` को grant हैं.
- इसलिए सामान्य authenticated client को इस table पर direct SELECT/INSERT/UPDATE/DELETE privilege नहीं मिलता; Admin RPC SECURITY DEFINER path से insert करता है.

### 104.2 Audit evidence

- `srk_audit_manual_payment_entries` AFTER INSERT/UPDATE/DELETE trigger `srk_capture_admin_audit_event()` चलाता है.
- Audit function manual-payment के `booking_id`, `payment_method`, `amount` में बदलाव पहचानता है और `before_data`, `after_data`, `changed_fields`, actor, role, action तथा booking/entity IDs को `srk_admin_audit_events` में लिखता है.
- Trigger INSERT/UPDATE/DELETE तीनों पर लगा है; इसलिए privileged service-role mutation पर भी audit event बनना चाहिए, बशर्ते trigger मौजूद हो और transaction commit हो.
- Table स्वयं append-only नहीं है: service_role को ALL grant है और UPDATE/DELETE को रोकने वाला अलग immutable trigger इस migration में नहीं मिला. इसलिए यह audit-tracked है, database-enforced immutable नहीं.
- Audit trail उसी transaction का हिस्सा है; privileged actor अगर audit table या trigger को bypass/disable कर सके तो यह अकेला tamper-proof external ledger नहीं है.

### 104.3 निष्कर्ष और सीमा

- Authenticated direct table access restriction: **source-confirmed**.
- One-row-per-booking and field validation: **source-confirmed**.
- UPDATE/DELETE before/after audit capture: **source-confirmed**.
- Immutable/append-only enforcement against service_role: **not present in reviewed migration**.
- Runtime grants/RLS, trigger execution and transaction behavior: **not tested against PostgreSQL**.
- No SQL execution, database change, or payment mutation performed.

सुझाव: यदि business requirement manual-payment evidence को immutable बनाना है, तो service-role writer को केवल controlled RPC तक सीमित रखें और correction के लिए append-only correction/reversal event model अपनाएँ; केवल mutable row + same-database audit trigger को tamper-proof न मानें।


## 105. Manual Payment audit allow-list omits reference, note and recorder — source-confirmed gap — 17 Nov 2026

Migration `20261114125844_restore_financial_audit_core_schema.sql` में manual-payment audit allow-list की table columns से तुलना की गई।

### 105.1 Exact mismatch

`srk_manual_payment_entries` में ये fields हैं:
- `booking_id`
- `payment_method`
- `amount`
- `payment_reference`
- `note`
- `recorded_by`
- `recorded_at`

लेकिन `srk_capture_admin_audit_event()` के `manual_payment` allow-list में केवल:
`booking_id, payment_method, amount`
हैं।

### 105.2 Consequence

- Insert audit event में payment reference, note और recorder identity snapshot नहीं होते.
- यदि किसी privileged writer द्वारा केवल `payment_reference`, `note`, `recorded_by` या `recorded_at` बदला जाए, तो allow-list loop में कोई changed field नहीं मिलेगा.
- Function `cardinality(v_fields)=0` पर लौट जाता है; इसलिए ऐसे field-only UPDATE के लिए audit event नहीं बनेगा.
- यह Section 104 के निष्कर्ष को और सीमित करता है: trigger मौजूद है, लेकिन manual-payment evidence का complete field history capture नहीं करता.

### 105.3 Recommended correction and status

- Allow-list में `payment_reference`, `note`, `recorded_by`, `recorded_at` शामिल करने पर विचार करें.
- Payment reference में संवेदनशील provider/card/bank data आ सकता है; इसे audit JSON में रखने से पहले allowed format और redaction policy तय करें. केवल approved reference token/last-four या keyed digest रखना बेहतर हो सकता है; पूरा sensitive credential audit में न रखें.
- Recorder identity और timestamp को कम-से-कम insert event में preserve करें.
- Tests: INSERT snapshot coverage; reference-only UPDATE; note-only UPDATE; recorder-only UPDATE; DELETE before snapshot; ensure redaction and no secret leakage.
- Allow-list omission and zero-event path: **source-confirmed**.
- Actual trigger behavior and audit row contents: **not PostgreSQL runtime-tested**.
- No SQL changes, database execution, or payment mutation performed.

यह audit completeness issue है; इससे अपने-आप unauthorized payment mutation सिद्ध नहीं होता। Direct authenticated table privileges पहले से revoked हैं, लेकिन privileged service-role path पर audit completeness आवश्यक है।



## 106. Manual Refund और Payout audit allow-list की अधूरी field coverage — source-confirmed — 17 Nov 2026

Migration `20261114125844_restore_financial_audit_core_schema.sql` में `srk_capture_admin_audit_event()` की allow-list को संबंधित table definitions और trigger attachments से cross-check किया गया।

### 106.1 Manual Refund evidence

`srk_manual_refund_entries` में `booking_id`, `payment_entry_id`, `amount`, `refund_reference`, `note`, `recorded_by`, `recorded_at` हैं। लेकिन `manual_refund` allow-list केवल `booking_id`, `payment_entry_id`, `amount` capture करती है।

परिणाम:
- INSERT snapshot में refund reference, note, recorder और recorded timestamp नहीं आते।
- इन चार में से किसी field का अकेला UPDATE होने पर allow-list loop में कोई बदलाव नहीं मिलता; function zero changed fields पर लौट जाता है और audit event नहीं लिखता।
- Manual refund entry पर AFTER INSERT/UPDATE/DELETE trigger मौजूद है, लेकिन trigger का होना complete field coverage की गारंटी नहीं देता।

### 106.2 Electrician Payout evidence

Payout table में `paid_by` मौजूद है, पर `electrician_payout` allow-list में `paid_by` नहीं है। `paid_at` capture होता है, लेकिन किस authenticated user ने payout को paid mark किया, उसका row-level `paid_by` value snapshot में नहीं आता। इससे payout status transition का actor और payout record का business approver/processor अलग-अलग होने पर पूरा संदर्भ उपलब्ध नहीं रहता।

### 106.3 Access boundary और risk qualification

- तीनों tables पर authenticated direct privileges revoked हैं और service_role को ALL grant है; reviewed migration के अनुसार सामान्य client direct write path restricted है।
- ये findings audit completeness और privileged-write traceability की हैं; अपने-आप unauthorized refund या payout सिद्ध नहीं करतीं।
- Audit event में पूरा `refund_reference` या payment reference जोड़ने से पहले secret/credential redaction policy तय होनी चाहिए। Recorder/paid_by UUID और timestamp को सुरक्षित रूप से preserve करना उपयोगी है।
- Manual refund और payout audit triggers तथा allow-list की मौजूदगी source में confirm है; actual PostgreSQL trigger execution और event JSON runtime में verify नहीं हुए।

### 106.4 Recommended regression tests

1. Manual refund INSERT snapshot में approved/sanitized reference, note policy, `recorded_by` और `recorded_at` की coverage जाँचें।
2. Refund reference-only, note-only और recorder-only UPDATE पर expected audit behavior जाँचें।
3. Payout को paid mark करने पर `paid_by`, `paid_at`, status और reference का audit snapshot जाँचें।
4. Sensitive reference values audit JSON में leak न हों, इसकी redaction assertion जोड़ें।
5. DELETE before-snapshot में approved fields preserve हों और unrelated secret columns न आएँ।

### 106.5 Status

- Manual refund allow-list omission: **source-confirmed**.
- Payout `paid_by` omission: **source-confirmed**.
- Trigger attachment for manual refund and payout: **source-confirmed**.
- Actual audit event contents / runtime behavior: **not PostgreSQL runtime-tested**.
- No migration edit, database execution, refund, payout, or production change performed.


## 107. Razorpay Refund audit snapshot में operational provenance fields छूटे — source-confirmed — 17 Nov 2026

उसी migration में `srk_capture_razorpay_refund_audit_event()` को `srk_razorpay_refunds` की पूरी table definition के विरुद्ध जाँचा गया।

### 107.1 Table और audit snapshot का अंतर

Refund table में `payment_id`, `refund_id`, `amount`, `amount_paise`, `currency`, `idempotency_key`, `status`, `provider_status`, `reason`, `admin_user_id`, `previous_payout_note`, `last_error`, `created_at`, `updated_at`, `processed_at` हैं।

लेकिन dedicated Razorpay audit function INSERT/DELETE snapshot में केवल `refund_id`, `amount`, `status`, `provider_status` रखता है; UPDATE में भी केवल इन्हीं चार fields के बदलाव जाँचे जाते हैं।

### 107.2 Consequence

- Refund record किस payment ID और idempotency key से जुड़ा था, किस Admin ने refund शुरू किया, किस कारण से किया, और failure का operational error क्या था—ये details audit snapshot में नहीं आतीं।
- `payment_id`, `reason`, `admin_user_id`, `last_error`, `previous_payout_note`, `processed_at` या `idempotency_key` का अकेला UPDATE audit event नहीं बनाएगा, क्योंकि dedicated function केवल चार fields compare करता है।
- `amount_paise`, currency और timestamps भी explicit snapshot में नहीं हैं; amount numeric snapshot मौजूद है, पर paise integer parity को audit JSON से स्वतंत्र रूप से reconstruct नहीं किया जा सकता।
- यह omission existing trigger की अनुपस्थिति नहीं है: dedicated AFTER INSERT/UPDATE/DELETE trigger मौजूद है। कमी उसके field coverage में है।

### 107.3 Safe audit design

- `admin_user_id`, `payment_id`, `amount_paise`, currency, status/provider_status और processed timestamp को audit में शामिल करने पर विचार करें।
- `idempotency_key` और provider/payment references को पूरा store करने से पहले exposure policy तय करें; आवश्यकता हो तो redacted value या keyed digest रखें।
- `reason` तथा `last_error` में व्यक्तिगत/संवेदनशील data हो सकता है; bounded और sanitized representation ही रखें।
- INSERT, state transition, failure, replay और DELETE के लिए before/after regression tests बनाएं।

### 107.4 Status

- Dedicated Razorpay audit function की चार-field सीमा: **source-confirmed**.
- Trigger attachment और table field inventory: **source-confirmed**.
- Actual audit JSON contents / runtime execution: **not PostgreSQL runtime-tested**.
- No migration edit, provider call, refund, database execution, or production change performed.


## 108. Audit Log read-access और actor attribution — source-level qualification — 17 Nov 2026

Migration `20261114125844_restore_financial_audit_core_schema.sql` में `srk_admin_audit_events` की access policy और दोनों audit trigger functions की actor पहचान जाँची गई।

### 108.1 Audit Log read access

- Table पर RLS enabled है।
- `PUBLIC`, `anon`, `authenticated` से सभी table privileges revoke हैं।
- `service_role` को ALL grant है।
- इस migration में `srk_admin_audit_events` के लिए authenticated SELECT grant या SELECT policy नहीं बनाई गई है।

इसका अर्थ है कि सामान्य authenticated Admin client सीधे इस table को पढ़ नहीं सकता। यह अपने-आप security vulnerability नहीं है—यह सुरक्षित server-side access design भी हो सकता है—लेकिन Admin UI को Audit Log दिखाने के लिए अलग, सुरक्षित backend/RPC read path आवश्यक होगा। इस migration में ऐसा read RPC परिभाषित नहीं दिखता। पूरे repository के सभी API/server endpoints की जाँच इस section में नहीं की गई; इसलिए Admin UI की वास्तविक उपलब्धता अभी **unverified** है।

### 108.2 Actor attribution का service-role जोखिम

दोनों trigger functions actor के लिए `auth.uid()` लेते हैं। यदि कोई trusted backend service-role context से write करता है और उसमें authenticated user JWT context उपलब्ध नहीं है, तो `auth.uid()` NULL हो सकता है और event `system` actor के रूप में दर्ज होगा। इससे वास्तविक initiating Admin की पहचान खो सकती है।

यह conditional finding है: हर service-role call में auth.uid() NULL ही होगा, ऐसा runtime में सिद्ध नहीं किया गया। Backend यदि verified actor ID अलग से pass/propagate करता है, तो स्थिति अलग हो सकती है; reviewed trigger interface में ऐसा explicit actor parameter नहीं है।

### 108.3 आवश्यक design और tests

1. Admin-only server-side read endpoint/RPC की पुष्टि करें; caller identity server पर verify हो और सामान्य users को audit rows न मिलें।
2. Service-role writes में initiating Admin ID को trusted server context से audit तक पहुँचाने का स्पष्ट तरीका तय करें; client-supplied arbitrary actor ID स्वीकार न करें।
3. Admin, electrician, customer और unauthenticated service-role scenarios में actor_user_id/actor_role तथा read authorization के tests जोड़ें।
4. Audit table पर direct UPDATE/DELETE केवल service_role को उपलब्ध है; इसलिए append-only protection और privileged tampering controls अलग से तय करें।

### 108.4 Status

- RLS, revoke/grant और authenticated direct read restriction: **source-confirmed**.
- इस migration में audit read RPC/policy का अभाव: **source-confirmed within this migration only**.
- वास्तविक Admin UI read path: **not yet verified across repository**.
- service-role actor NULL scenario: **conditional; runtime not tested**.
- No SQL migration edit, database query, or production change performed.
