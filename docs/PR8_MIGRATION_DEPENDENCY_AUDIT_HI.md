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
