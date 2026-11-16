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
