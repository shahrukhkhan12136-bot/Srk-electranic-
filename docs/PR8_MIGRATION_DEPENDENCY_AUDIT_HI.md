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


## 109. Audit-field regression tests — coverage gap review — 17 Nov 2026

Audit Branch पर मौजूद SQL tests में पुराने financial audit allow-lists और नए Razorpay recovery evidence tests की तुलना की गई।

### 109.1 पुराने Audit Log test में क्या जाँचा गया

`supabase/tests/database/financial_audit_core_schema.test.sql` (blob SHA `1d4769e3be6af072bce6474c778cc1ad31b8d1c9`) में `plan(54)` है। इसमें table existence, RLS, direct authenticated access denial, constraints, SECURITY DEFINER/search_path और audit triggers की मौजूदगी के assertions हैं।

इस test में:
- Manual Payment के लिए `payment_reference`, `note`, `recorded_by`, `recorded_at` allow-list coverage का assertion नहीं मिला।
- Manual Refund के लिए `refund_reference`, `note`, `recorded_by`, `recorded_at` coverage का assertion नहीं मिला।
- Electrician Payout के `paid_by` field का audit snapshot assertion नहीं मिला।
- Razorpay Refund के `payment_id`, `idempotency_key`, `admin_user_id`, `reason`, `last_error`, `previous_payout_note`, `processed_at`, `amount_paise`, `currency` fields का snapshot assertion नहीं मिला।

इसलिए Section 105–107 में दर्ज field omissions के विरुद्ध यह test suite regression guard नहीं बनाती। यह निष्कर्ष इस inspected test file और संबंधित inspected files तक सीमित है; इसे पूरे repository में किसी भी दूसरे test के न होने का दावा न माना जाए।

### 109.2 संबंधित tests का दायरा

- `admin_manual_refund_request_completion.test.sql` (plan 14) refund RPC authorization, locking, request state और amount guards के source contracts जाँचता है; audit snapshot field completeness नहीं।
- `legacy_manual_payment_and_itemized_receipt.test.sql` (plan 18) manual payment RPC और insert path जाँचता है; audit allow-list की पूरी field coverage नहीं।
- `refund_reconcile_full_amount_guard.test.sql` (plan 5) refund amount/reconciliation guard पर केंद्रित है; audit snapshot assertions नहीं मिले।
- `durable_razorpay_refund_recovery_evidence.test.sql` (plan 35) अलग recovery-evidence design के लिए service-role authorization, registered Admin actor, payload identity, append-only mutation guard और verified provider evidence gates के source assertions रखता है। यह पुराने `srk_admin_audit_events` के चार-field Razorpay snapshot को स्वतः ठीक या verify नहीं करता।

### 109.3 सुधार के लिए आवश्यक regression tests

1. Generic audit function के allow-list में Manual Payment/Refund और Payout के प्रत्येक आवश्यक field को स्पष्ट रूप से assert करें।
2. Razorpay Refund audit function के INSERT, UPDATE और DELETE snapshots में अनुमत fields की सूची जाँचें।
3. केवल omitted field बदलने पर expected audit event व्यवहार assert करें—विशेषकर reference/note/actor metadata।
4. संवेदनशील provider references और idempotency keys के लिए redaction policy को test करें; इन्हें बिना समीक्षा audit JSON में न जोड़ें।
5. पुराने generic audit log और नए durable recovery evidence को अलग test suites/contracts के रूप में रखें।

### 109.4 Status

- 54-assertion financial audit test का structural/security focus: **source-confirmed**.
- पुराने audit field omissions के लिए exact regression assertions का अभाव: **inspected tests में confirmed**.
- Durable Razorpay recovery evidence में actor/append-only source-contract assertions: **source-confirmed; runtime unverified**.
- कोई SQL test execute नहीं किया गया; कोई migration/source SQL बदला नहीं गया; Production/Test Supabase पर कोई बदलाव नहीं किया गया।


## 110. Audit-field regression test plan — safe coverage and behavioral assertions — 17 Nov 2026

Section 109 के निष्कर्षों के आधार पर test plan तैयार किया गया। यह योजना है; अभी test files या migration source में कोई बदलाव नहीं किया गया।

### 110.1 Field policy पहले तय हो

सभी table columns को बिना छँटाई Audit JSON में डालना सुरक्षित नहीं है। प्रस्तावित review matrix:

| Entity | Audit में आवश्यक पहचान/व्यावसायिक fields | सावधानी |
|---|---|---|
| Manual Payment | booking_id, payment_method, amount, recorded_by, recorded_at | payment_reference और note को raw रूप में रखने से पहले redaction/retention तय हो |
| Manual Refund | booking_id, payment_entry_id, amount, recorded_by, recorded_at | refund_reference और note संवेदनशील हो सकते हैं; raw snapshot स्वतः न जोड़ें |
| Electrician Payout | booking_id, payout_status, payout_method, amount fields, paid_at, paid_by | payout_reference और payout_note की redaction/length policy तय हो |
| Razorpay Refund | payment/booking linkage, refund_id, amount + paise, currency, status/provider_status, admin_user_id, processed_at | idempotency_key, last_error, reason, previous_payout_note को raw रूप में न लिखें; सुरक्षित summary/redaction तय हो |

इस matrix में “आवश्यक” का अर्थ final approval नहीं है। Owner/security review को तय करना होगा कि कौन-सा field पूर्ण, masked, hashed या केवल metadata के रूप में रखा जाए।

### 110.2 Static contract assertions

एक dedicated audit-field contract test (या मौजूदा `financial_audit_core_schema.test.sql` में अलग स्पष्ट test group) में:
1. Generic function की Manual Payment allow-list में स्वीकृत fields की मौजूदगी जाँचें।
2. Manual Refund allow-list में स्वीकृत fields की मौजूदगी जाँचें।
3. Electrician Payout allow-list में `paid_by` सहित स्वीकृत fields की मौजूदगी जाँचें।
4. Razorpay dedicated audit function में INSERT/DELETE और UPDATE branches के स्वीकृत fields की coverage जाँचें।
5. Sensitive fields के लिए raw values के बजाय approved redaction/omission contract assert करें।
6. Test plan count को assertions की वास्तविक संख्या से मिलाएँ।

### 110.3 Behavioral trigger tests — isolated PostgreSQL में

Static source matching पर्याप्त नहीं है। Isolated test database में fixtures और trigger execution से जाँचें:
- INSERT: `changed_fields`, `after_data`, actor ID/role सही हों।
- UPDATE: केवल बदले हुए allow-listed fields `before_data` और `after_data` में हों।
- UPDATE of excluded field only: approved policy के अनुसार event न बने या sanitized event बने।
- DELETE: `before_data` उपलब्ध हो और `after_data` खाली रहे।
- NULL/absent optional values: अनावश्यक event या गलत JSON key न बने।
- Admin-context और service-role-context: actor attribution अपेक्षित और विश्वसनीय हो।
- Sensitive references/notes: raw secret/token या अनावश्यक personal text audit JSON में न आए।

हर test transaction को rollback करें; production या shared Supabase database पर न चलाएँ।

### 110.4 Test execution gate

- पहले migration dependency order और clean disposable PostgreSQL baseline सत्यापित करें।
- फिर संबंधित migration replay करें।
- उसके बाद pgTAP test files execute करें और वास्तविक output/exit status सुरक्षित रखें।
- केवल source assertions या GitHub CI Node success को PostgreSQL runtime pass न कहें।

### 110.5 Status

- Test plan: **documented**.
- Migration allow-list correction: **not implemented**.
- SQL regression test changes: **not implemented**.
- PostgreSQL/pgTAP runtime: **not executed**.
- Owner approval for sensitive-field policy and isolated DB execution: **pending**.
- No Production/Test Supabase changes.


## 111. Broader repository scan — generic Audit Log बनाम durable refund evidence tests — 17 Nov 2026

Section 109 के “inspected tests” निष्कर्ष को सीमित न रहने देने के लिए Audit Branch की पूरी `supabase/tests/database/` tree में audit/payment/refund/payout नाम वाले सभी 13 SQL test files की सूची और audit-संबंधित assertions scan की गईं।

### 111.1 Scan में मिला coverage

- `financial_audit_core_schema.test.sql` (54 assertions): generic `srk_admin_audit_events` table, RLS, permissions, constraints और trigger existence। Manual Payment/Refund/Payout allow-list के प्रत्येक field तथा Razorpay dedicated four-field snapshot की completeness का explicit assertion नहीं मिला।
- `durable_razorpay_refund_recovery_evidence.test.sql` (35 assertions): अलग `srk_razorpay_refund_recovery_audits` evidence table के RLS, service-role function privileges, authorized Admin actor registry, provider payload identity/amount match, bounded Admin note, append-only mutation guard और finalize evidence gates के source contracts।
- `admin_refund_review_queue.test.sql` (16 assertions): refund decision RPC और bounded audit note का source contract; generic audit JSON field coverage नहीं।
- `cancellation_fee_refund_reversal.test.sql` (44 assertions): immutable ledger/reversal and service-role reconciliation guards; generic audit allow-list completeness नहीं।
- बाकी inspected payment/refund tests customer RPC, refund request, payment method या payout reconciliation contracts पर केंद्रित हैं; generic audit snapshot fields की पुष्टि नहीं करते।

### 111.2 महत्वपूर्ण सीमा

Durable Razorpay recovery evidence tests एक अलग table/workflow को कवर करते हैं। वे पुराने `srk_razorpay_refunds` trigger और `srk_admin_audit_events` के अधूरे snapshot को replace या validate नहीं करते। दोनों evidence systems को एक ही coverage समझना गलत होगा।

### 111.3 Updated confidence

- इस Audit Branch पर filename-filtered 13 SQL tests का scan पूरा: **source tree scan complete for this filtered set**.
- Generic Audit Log field-completeness regression gap: **confirmed within all 13 inspected files**.
- Durable recovery evidence के source-contract tests: **present; runtime unverified**.
- यह scan filename filter पर आधारित है; unrelated-named SQL tests या application-layer tests में समान assertions हो सकते हैं। इसलिए पूरे repository में हर संभव test की अनुपस्थिति का दावा नहीं है।
- No source SQL/test file modified; no SQL execution, PostgreSQL replay, provider call, or database mutation performed.


## 112. Draft regression test artifact — not runnable / approval pending — 17 Nov 2026

एक अलग static pgTAP source-contract draft बनाया गया है:

`docs/drafts/financial_audit_field_coverage_regression.draft.sql`

### Draft में शामिल 8 target assertions

- Manual Payment: `recorded_by`, `recorded_at`.
- Manual Refund: `recorded_by`, `recorded_at`.
- Electrician Payout: `paid_by`.
- Razorpay Refund: Admin actor, amount in paise, currency, processed timestamp, internal/provider status.

### सुरक्षा और execution सीमाएँ

- Draft को `supabase/tests/database/` के बाहर रखा गया है; यह मौजूदा SQL test runner में शामिल नहीं है।
- यह static `pg_get_functiondef` contract check है; fixture-based trigger execution या PostgreSQL runtime behavior नहीं जाँचता।
- Provider IDs, idempotency keys, free-text reason/error और payout notes को raw audit JSON में जोड़ने का प्रस्ताव नहीं है। उनकी masking/retention policy owner/security approval के बाद ही तय होगी।
- Draft assertions मौजूदा migration पर अभी fail हो सकती हैं; इसे runnable test suite में promote नहीं किया गया।
- No SQL migration edited, no test executed, no database/production changes.


## 113. Financial Audit read-path और service-role actor attribution — 17 Nov 2026

इस चरण में Admin UI, generic finance audit migration, durable Razorpay recovery migration और Netlify recovery handler को एक साथ cross-check किया गया।

### 113.1 Finance Audit read path

- `admin.html` (blob `4b54dbfb605e55bb086eca7f1d5be13270b78e91`) में `srk_admin_list_staff_audit_events` RPC का उपयोग मिलता है। यह Support Staff activity history है, Finance Audit Log नहीं।
- उसी UI में `srk_admin_audit_events` table या finance-audit listing RPC का read call नहीं मिला।
- Generic financial audit migration `20261114125844_restore_financial_audit_core_schema.sql` (blob `bdfdfcc01366a9d4a298b2107c53f1525b326bf9`) audit table पर authenticated SELECT revoke करता है; इस migration में finance audit read RPC/policy नहीं दिखी।
- निष्कर्ष: **जाँचे गए Admin UI और इस migration में Finance Audit Log का user-facing read path स्थापित नहीं मिला।** यह पूरे repository में किसी अन्य server/API path की अनुपस्थिति का अंतिम दावा नहीं है; आगे के server-side consumers की अलग खोज बाकी है।

### 113.2 Generic finance audit actor — service-role context

- Generic और Razorpay trigger functions `auth.uid()` को actor लेते हैं; NULL होने पर `actor_role='system'` लिखते हैं।
- Netlify recovery handler `razorpay-refund-recovery.js` (blob `2573aa5c6442ace359515f2227c5d93019534184`) पहले incoming bearer token से Auth user पढ़ता है, उसी token से `is_srk_admin` जाँचता है, और फिर service-role key से DB RPC चलाता है।
- Recovery evidence writer को यह handler स्पष्ट रूप से `p_admin_user_id=user.id` देता है। Migration `20261115120000_durable_razorpay_refund_recovery_evidence.sql` (blob `adf83de704725e791a096462eaa385b28f92c7a7`) actor को `srk_admin_users` registry में validate करता है और immutable recovery evidence row में रखता है।
- इसलिए इस विशेष recovery flow में **अलग durable evidence record पर Admin actor स्पष्ट रूप से दर्ज है**।
- Phase-2 finalizer अलग PostgREST request में service-role key से चलता है और `srk_razorpay_refunds` को update करता है। उस trigger के generic audit event में `auth.uid()` service-role context में NULL हो सकता है; ऐसी स्थिति में generic event actor `system` होगा, न कि Admin UUID। Admin UUID फिर भी अलग recovery evidence record से जुड़ा रहता है।
- यह निष्कर्ष source-level है; JWT/runtime behavior और actual audit rows DB में execute करके verify नहीं किए गए।

### 113.3 सुरक्षा निष्कर्ष और अगला आवश्यक निर्णय

1. Finance Audit Log के लिए Main Admin-only read RPC/API चाहिए, जिसमें pagination, date/entity filters और sensitive-field redaction हो; direct authenticated table SELECT न खोलें।
2. Service-role financial writes के लिए trusted actor propagation का एक consistent contract चाहिए। Caller-provided arbitrary UUID को बिना verified identity/role binding के स्वीकार न करें।
3. Recovery flow का `admin_user_id` अलग durable evidence में सुरक्षित है; इसे generic audit actor के बराबर न मानें। दोनों records के बीच recovery audit ID से correlation उपयोगी रहेगा।
4. Runtime tests में authenticated Admin RPC path और service-role backend path दोनों के actor IDs/roles जाँचें।

### सीमाएँ

- केवल Audit Branch source inspected; no database query, SQL execution, runtime JWT test, production change or deployment.
- No Finance Audit read API बनाया गया; no permissions changed.
- निष्कर्ष केवल देखे गए `admin.html`, generic audit migration, recovery handler और recovery migration पर आधारित हैं।


## 114. Finance Audit Log सुरक्षित read API — design draft — 17 Nov 2026

- मौजूदा Finance Audit table पर authenticated direct SELECT revoked है; इसे खोलने के बजाय Main Admin-only SECURITY DEFINER RPC प्रस्तावित है।
- Staff Audit RPC पहले से Main Admin gate का pattern देती है, लेकिन वह अलग Staff activity table पढ़ती है; Finance Audit RPC उससे अलग और explicit होगी।
- नया design draft `docs/drafts/finance_audit_log_read_api_design.md` में रखा गया है।
- Draft में parameterized filters, bounded 1..100 pagination, deterministic keyset cursor, explicit Main Admin gate, raw sensitive JSON redaction, direct table SELECT बंद रखने और role-based regression matrix का प्रस्ताव है।
- इसमें कोई executable SQL नहीं है; implementation या privilege changes नहीं किए गए।
- Open owner decisions: UI-visible fields, raw vs redacted before/after, lookback/retention, read-access logging.
- No SQL execution, pgTAP, migration, permission change, database mutation or deployment.


## 115. Finance Audit Read RPC — SQL और pgTAP draft — 17 Nov 2026

दो non-active draft artifacts बनाए गए:

- `docs/drafts/srk_admin_list_financial_audit_events.draft.sql`
- `docs/drafts/finance_audit_log_read_api.draft.test.sql`

### प्रस्तावित RPC का व्यवहार

- केवल authenticated Main Admin; `auth.uid()` और `public.is_srk_admin()` दोनों अनिवार्य।
- `SECURITY DEFINER` और खाली `search_path`; सभी table/function references schema-qualified।
- Filter allow-list: entity type और action; साथ में booking और actor UUID filters।
- Stable keyset pagination: `created_at DESC, id DESC`; cursor timestamp और UUID दोनों अनिवार्य।
- Page limit 1..100 तक clamp।
- केवल metadata/changed_fields लौटाता है; raw `before_data` और `after_data` return नहीं करता।
- Authenticated direct table SELECT grant नहीं जोड़ा गया; function execute authenticated role को दिया गया है, लेकिन Main Admin gate function के अंदर लागू रहता है।

### Test draft

10 static pgTAP contract assertions: function signature, SECURITY DEFINER, empty search_path, Main Admin gate, authorization error, page limit, cursor pair, raw JSON omission, direct table SELECT denial और execute grants।

### सीमाएँ / शेष काम

- दोनों files `docs/drafts/` में हैं; active migration/test directories में नहीं।
- pgTAP draft केवल catalog/source-contract checks है। इसमें anon/customer/electrician/staff/Main Admin impersonation और वास्तविक row pagination के behavioral tests अभी शामिल नहीं हैं।
- कोई migration लागू नहीं, कोई test/SQL execute नहीं, कोई CI/DB/Production change नहीं।
- Owner approval अभी भी जरूरी है: Admin को actor UUID और changed_fields दिखाना, retention/lookback, read-access monitoring, और final filter policy।
- Approval के बाद ही drafts को active migration और isolated pgTAP suite में promote किया जाए।


## 116. Finance Audit Read API — Behavioral Test Plan — 17 Nov 2026

- Section 115 के 10 static catalog/source-contract assertions वास्तविक role behavior, row disclosure, pagination sequence या filter semantics execute नहीं करते।
- इस gap को स्पष्ट करने के लिए `docs/drafts/finance_audit_log_read_api_behavioral_test_plan.md` जोड़ा गया।
- Draft में 16 behavioral scenarios हैं: anon/customer/electrician/Support Staff denial, Main Admin read, page-size boundaries, paired cursor validation, equal-timestamp tie-break, multi-filter semantics, invalid allow-list values, raw JSON secret non-disclosure, direct table SELECT denial, anon EXECUTE denial और empty/final page behavior।
- Plan synthetic-only fixtures, isolated disposable DB, rollback/cleanup, SQLSTATE evidence और complete paginated-ID comparison अनिवार्य करता है।
- Open decisions अभी भी हैं: actor UUID/changed_fields visibility, actual schema के अनुसार entity/action allow-list, retention/lookback, read-access logging और Support Staff exclusion।
- यह planning document है; कोई executable test, active migration, database operation, privilege change, CI run या deployment नहीं किया गया।
- Promotion तभी जब RPC contract/field policy owner से approve हो और isolated PostgreSQL environment में tests execute हों।


## 117. Finance Audit RPC — वास्तविक schema और Admin identity gate का मिलान — 17 Nov 2026

### 117.1 Audit table schema — exact source verification

Migration `20261114125844_restore_financial_audit_core_schema.sql` (blob `bdfdfcc01366a9d4a298b2107c53f1525b326bf9`) को पूरा पढ़ा गया।

- `srk_admin_audit_events` columns: `id uuid`, `entity_type text`, `entity_id uuid`, `booking_id uuid`, `action text`, `actor_user_id uuid`, `actor_role text`, `changed_fields text[]`, `before_data jsonb`, `after_data jsonb`, `created_at timestamptz`.
- Entity allow-list: `booking`, `electrician_profile`, `electrician_application`, `manual_payment`, `manual_refund`, `electrician_payout`, `razorpay_refund`.
- Action allow-list: `created`, `updated`, `deleted`.
- `actor_role` allow-list: `admin`, `user`, `system`.
- सभी सूचीबद्ध RPC filter values table constraints से मेल खाते हैं। लेकिन actor/entity UUID fields और JSON field visibility अभी भी owner policy decision हैं।

### 117.2 Admin identity gate — महत्वपूर्ण qualification

- `ADMIN_EMAIL_LOGIN_SETUP.sql` में `is_srk_admin()` केवल यह जाँचता है कि `auth.uid()` की row `srk_admin_users` में मौजूद है या नहीं।
- `PORTAL_SCHEMA.sql` में `srk_admin_users` का schema केवल `user_id` और `created_at` रखता है; कोई `role`/Main-Admin-vs-Support-Staff column नहीं है।
- इसलिए `is_srk_admin()` allow-list membership प्रमाणित करता है, लेकिन अकेले यह प्रमाणित नहीं करता कि Support Staff को Main Admin से अलग पहचाना जाता है।
- Draft RPC में `auth.uid() IS NOT NULL AND public.is_srk_admin()` gate है। अतः इसे अभी **allow-listed Admin-only** कहना सही है; **Main Admin-only** तभी कहा जा सकता है जब owner पुष्टि करे कि Support Staff कभी `srk_admin_users` में नहीं जोड़े जाते, या अलग authoritative Main Admin role predicate उपलब्ध हो।
- SQL draft header में यह सीमा स्पष्ट कर दी गई है। कोई permission या role schema नहीं बदला गया।

### 117.3 आवश्यक owner confirmation और test adjustment

1. Confirm करें कि Support Staff identities को `srk_admin_users` से पूरी तरह बाहर रखा जाता है या नहीं।
2. यदि Support Staff वहाँ हो सकते हैं, तो Main Admin के लिए authoritative role source/predicate तय करें; केवल email/domain या caller-supplied role पर भरोसा न करें।
3. Behavioral B04 को वास्तविक Support Staff identity के साथ चलाएँ; यदि वह allow-list में है तो वर्तमान RPC gate उसे allow करेगा — यह test अभी blocked/decision-required है।
4. B02/B03 और anon denial, Main Admin positive test, cursor/filter behavior तथा secret non-disclosure isolated DB में अभी भी आवश्यक हैं।

### Status

- Audit table column/check constraints: **source-confirmed**.
- `is_srk_admin()` semantics and allow-list table shape: **source-confirmed** from repository SQL.
- Support Staff exclusion from allow-list: **not proven**.
- No SQL execution, database query, permission change, migration, CI run or deployment.



## 118. मौजूदा Staff RBAC के साथ Finance Audit gate का मिलान — 17 Nov 2026

Section 117 के बाद Audit Branch में Staff RBAC source और उसके pgTAP contract को पढ़कर Finance Audit draft के Admin identity gate से मिलान किया गया।

### 118.1 अलग Staff registry और permission helper

- Migration `supabase/migrations/20261116100000_fix_staff_permission_helper_volatility.sql` (blob `fc99aaf9c564b348e25a72b416dd4eb746e0fad3`) में `srk_has_admin_permission(text)` की अंतिम definition है।
- Helper पहले `auth.uid()` और permission key validate करता है; फिर `public.is_srk_admin()` true होने पर Main Admin path से अनुमति देता है।
- अन्य authenticated users के लिए यह `srk_admin_staff` में active Staff row, JWT `session_id`, matching live `auth.sessions` row और non-revoked `srk_admin_staff_sessions` row जाँचता है। Registry और tracked session पर `FOR SHARE` locks लेता है।
- इसलिए source में Main Admin और Support Staff के authorization paths अलग हैं: Main Admin allow-list predicate; Staff session-bound permission map.
- Migration helper को `VOLATILE SECURITY DEFINER`, empty `search_path` के साथ परिभाषित करती है; EXECUTE authenticated को दिया गया है और PUBLIC/anon से revoke है।

### 118.2 Support permission scope

- `supabase/tests/database/admin_staff_rbac_foundation.test.sql` (blob `46305769a74ea0acbb1caf8dc4a41d322614fe3a`) का static pgTAP contract सात seeded permissions और Support role की सात mappings जाँचता है।
- उसी test में Support role के लिए `finance.%`, `payment.%`, `wallet.%`, `refund.%`, `payout.%`, `cancellation.%`, `kyc.%`, `staff.manage`, `audit.read`, cancellation-decision और private-contact permissions की अनुपस्थिति जाँची गई है।
- Test Main Admin-only Staff management और Staff audit-history RPC gates भी source-inspect करता है।
- यह मौजूदा Support role के permission-map scope का मजबूत source-level evidence है; pgTAP assertions इस pass में execute नहीं किए गए।

### 118.3 Finance Audit draft पर असर और सीमा

- मौजूदा Finance Audit draft का `auth.uid() IS NOT NULL AND public.is_srk_admin()` gate Main Admin allow-list path के अनुरूप है; Support permission map में `audit.read` न होना Staff को अलग permission-helper path पर सीमित करता है।
- लेकिन उपलब्ध source यह साबित नहीं करता कि एक ही Auth user को गलती से/जानबूझकर `srk_admin_users` और `srk_admin_staff` दोनों में रखना database constraint से असंभव है। `srk_has_admin_permission()` स्वयं `is_srk_admin()` true होने पर Staff permission map को bypass करके Main Admin path लौटाता है।
- इसलिए यह कहना सही है कि repository में अलग Main Admin/Staff authorization paths और Support के लिए finance/audit permission exclusion मौजूद हैं; लेकिन cross-registry identity exclusivity का invariant अभी source से सिद्ध नहीं।
- Finance Audit draft को इस चरण में बदला नहीं गया। Owner को पुष्टि करनी होगी कि Staff identities कभी `srk_admin_users` में नहीं रखी जातीं, या cross-registry exclusion के लिए authoritative rule/constraint देना होगा। बिना इस पुष्टि के “Support Staff हर स्थिति में Finance Audit से बाहर” का दावा नहीं किया जाएगा।

### Status

- Staff permission helper और session-bound checks: **source-confirmed**.
- Support permission map में finance/payment/refund/payout/audit permissions का अभाव: **test-source-confirmed; runtime unverified**.
- Main Admin और Staff के अलग authorization paths: **source-confirmed**.
- एक Auth identity का दोनों registries में overlap असंभव होना: **not proven**.
- No SQL/pgTAP execution, database query, permission/schema change, migration, CI run or deployment.


## 119. Cross-registry identity overlap — direct helper-path verification — 17 Nov 2026

Section 118 के बाद Staff permission helper की पूरी अंतिम definition और दोनों identity registries के उपलब्ध schema source को फिर पढ़ा गया।

### 119.1 निर्णायक source behavior

- `srk_has_admin_permission(text)` की अंतिम definition (migration `20261116100000_fix_staff_permission_helper_volatility.sql`, blob `fc99aaf9c564b348e25a72b416dd4eb746e0fad3`) में सबसे पहले `public.is_srk_admin()` जाँचा जाता है। यह true होने पर helper तुरंत `true` लौटाता है; उसके बाद ही Staff registry, active status, JWT session, live Auth session और Staff permission map जाँचे जाते हैं।
- इसलिए यदि कोई Auth identity दोनों `srk_admin_users` और `srk_admin_staff` में मौजूद हो, तो helper उसे Staff permission map से सीमित नहीं करेगा; वह Main Admin branch लेगा। यह निष्कर्ष function source से सीधे निकलता है, runtime test नहीं।
- `PORTAL_SCHEMA.sql` (blob `efc14aa623a3895ffb3841b7b0f226f2015f34b1`) में `srk_admin_users.user_id` primary key है, लेकिन वह अलग `srk_admin_staff.user_id` registry से cross-table exclusivity constraint नहीं दिखाता।
- Staff RBAC test (blob `46305769a74ea0acbb1caf8dc4a41d322614fe3a`) Support permission map में finance/payment/refund/payout/audit permissions की अनुपस्थिति जाँचता है; वह दोनों registries में एक ही user_id की अनुपस्थिति assert नहीं करता।

### 119.2 Finance Audit read RPC के लिए सुरक्षा परिणाम

- मौजूदा draft gate `auth.uid() IS NOT NULL AND public.is_srk_admin()` allow-listed Main Admin को पहचानता है।
- Support permission map में `audit.read` न होना पर्याप्त सुरक्षा सीमा नहीं है यदि वही identity Main Admin allow-list में भी दर्ज हो; Main Admin-first helper उस Staff permission map को bypass करता है।
- इसीलिए cross-registry overlap को केवल “Support के पास audit permission नहीं” कहकर बंद नहीं माना जा सकता।

### 119.3 सुरक्षित अगला निर्णय

Owner से इनमें से एक authoritative policy चुनवानी होगी:
1. **Exclusive registries:** एक Auth user दोनों registries में एक साथ नहीं हो सकता; इसे trusted DB-side invariant/controlled RPCs से enforce और test किया जाए।
2. **Explicit role precedence:** यदि overlap जानबूझकर वैध है, तो तय किया जाए कि उस identity को Main Admin माना जाएगा या Support Staff; Finance Audit gate उसी authoritative rule से बने।

किसी email/domain heuristic या client-supplied role पर भरोसा न करें। इस audit में कोई constraint, RPC, migration, permission या draft SQL नहीं बदला गया।

### Status

- Main Admin-first short-circuit in Staff helper: **source-confirmed**.
- Cross-registry exclusivity in inspected schema/test: **not found in inspected sources**.
- Overlap का runtime अस्तित्व: **unknown; no database query performed**.
- Finance Audit gate closure: **owner policy decision required**.
- No SQL/pgTAP execution, database query, permission/schema change, migration, CI run or deployment.


## 120. Staff invite lifecycle में Main Admin target exclusion — 17 Nov 2026

Section 119 के बाद पूरी RBAC foundation migration और Staff invite Edge Function की source-level जाँच की गई।

### 120.1 Design intent

- Migration `20261114390000_admin_staff_rbac_foundation.sql` (blob `5aa0f9058a56d735455f2a9944c861e8312ddb89`) के header और table comment में स्पष्ट design rule है: Main Admin identity केवल `srk_admin_users` में रहे; Staff को उसमें कभी insert न करें।
- Staff invite Edge Function (blob `c783989ca7142fce9d88270286bc916a66d22298`) caller को `auth.getUser(token)` से validate करती है, `is_srk_admin()` से inviter को authorize करती है, और role को fixed `support` रखती है।

### 120.2 Enforcement gap

- `srk_admin_staff_register_invited_user(uuid,text,uuid)` target UUID के लिए केवल non-NULL check करती है; actor UUID को `srk_admin_users` में मौजूद होना verify करती है।
- उपलब्ध function body में target `p_staff_user_id` के `srk_admin_users` में पहले से मौजूद होने की explicit rejection नहीं मिली।
- Edge Function भी invite से पहले target email/UUID को Main Admin allow-list के विरुद्ध check नहीं करती। Invite API से returned target UUID को service-role registration RPC में भेज दिया जाता है।
- `srk_admin_staff.user_id` की primary key केवल Staff table के भीतर uniqueness देती है; `srk_admin_users.user_id` के साथ cross-table exclusion नहीं।
- इसलिए “Staff को Main Admin allow-list में कभी न रखें” स्पष्ट design intent है, लेकिन inspected invite path में target-side enforcement प्रमाणित नहीं। Existing Main Admin identity को Staff invite करने का वास्तविक परिणाम runtime/DB पर जाँचा नहीं गया।

### 120.3 Security consequence and required repair design

यदि वही Auth UUID दोनों registries में आ जाए, तो Section 119 वाला Main Admin-first short-circuit Staff permission helper में उस identity को full Main Admin access देता है। इसलिए overlap रोकना केवल documentation convention नहीं, authorization boundary है।

Proposed remediation for owner review (not implemented):
1. Trusted registration RPC में actor authorization के बाद target UUID के `srk_admin_users` membership की जाँच कर overlap पर fail closed करें।
2. Invitation flow में Auth invitation भेजने से पहले existing Auth user resolution/duplicate handling सुरक्षित रूप से तय करें; केवल email string या browser role पर भरोसा न करें।
3. दोनों registry lifecycle paths के लिए race-safe invariant तय करें; केवल application pre-check पर्याप्त नहीं, यदि concurrent insert संभव हों।
4. pgTAP में target already Main Admin, ordinary Support target, duplicate invite, and concurrent cross-registry insert cases जोड़ें।

### Status

- “Staff को Main Admin allow-list में न डालें” design intent: **source-confirmed**.
- Inviter Main Admin check and fixed Support role: **source-confirmed**.
- Target-side Main Admin exclusion in inspected registration RPC/Edge Function: **not found**.
- Cross-table uniqueness/exclusion constraint: **not found in inspected schema**.
- Actual overlap in live database: **unknown; no DB query performed**.
- No code/migration/test/permission change, no invitation, no DB/CI/deployment action.


## 121. Cross-registry exclusion — सुरक्षित remediation और acceptance plan — 17 Nov 2026

Section 120 के enforcement gap के लिए केवल Edge Function में email pre-check जोड़ना पर्याप्त नहीं होगा। Auth identity UUID ही authoritative key है, और दोनों registries में concurrent writes भी संभव हैं।

### 121.1 प्रस्तावित सुरक्षा आवश्यकता

एक ही `auth.users.id` को एक समय में `srk_admin_users` और `srk_admin_staff` दोनों में मौजूद होने से database स्तर पर रोकना होगा। यह नियम इन सभी रास्तों पर लागू होना चाहिए:
- Main Admin allow-list में insert/update;
- Staff registration/invite RPC;
- किसी भी भविष्य के trusted service-role या maintenance path से registry write.

### 121.2 Implementation विकल्प — owner/DBA review आवश्यक

**विकल्प A — Canonical identity registry (सबसे स्पष्ट दीर्घकालीन मॉडल):**
- एक authoritative registry में `user_id PRIMARY KEY` और identity class (Main Admin या Staff) रखें।
- दोनों role-specific tables को उसी registry के composite key/class से बाँधें, ताकि class mismatch database constraint से असंभव हो।
- Existing identities का controlled backfill, duplicate detection और migration ordering पहले तय करें।

**विकल्प B — दोनों tables पर database-side guard:**
- दोनों registries के INSERT और identity-changing UPDATE पर एक ही UUID-keyed transaction lock लें और opposite registry में membership जाँचें।
- Direct browser writes बंद रहें; trusted write paths सीमित और documented हों।
- Transaction isolation, lock ordering, concurrent inserts और existing-row backfill के व्यवहार को PostgreSQL में साबित करना आवश्यक है। केवल RPC/Edge pre-check को invariant न मानें।

इनमें से कौन-सा मॉडल चुना जाए, यह DBA/owner की schema और migration-history समीक्षा के बाद तय हो। केवल एक registration RPC में `NOT EXISTS` जोड़ना concurrent या दूसरे write paths के विरुद्ध पर्याप्त प्रमाण नहीं है।

### 121.3 Invite flow सुधार

- पहले से Main Admin UUID/email को Staff invite target बनाने से fail closed करें।
- यदि Auth invite API पहले ही email भेज चुकी हो और बाद में registration असफल हो, तो partial side effect को स्पष्ट रूप से संभालें; email भेजे जाने को rollback हुआ न बताएं।
- Existing Auth user, pending invitation, duplicate Staff row और retry/idempotency के व्यवहार को स्पष्ट करें।
- Client-supplied role या metadata को authorization source न मानें; Support role server-side fixed रहे।

### 121.4 आवश्यक pgTAP / isolated PostgreSQL acceptance cases

1. पहले से Main Admin UUID को Staff registry में जोड़ना अस्वीकार हो।
2. पहले से Staff UUID को Main Admin allow-list में जोड़ना अस्वीकार हो।
3. सामान्य Auth UUID को Support के रूप में जोड़ना सफल हो; वह Main Admin permission न पाए।
4. Duplicate Staff registration स्पष्ट और सुरक्षित परिणाम दे।
5. दोनों दिशाओं में concurrent cross-registry insert में अधिकतम एक transaction सफल हो।
6. UPDATE द्वारा user_id बदलकर overlap बनाने का प्रयास अस्वीकार हो।
7. Service-role registration भी वही invariant लागू करे; service role bypass न कर सके।
8. Existing duplicate/overlap data मिलने पर migration fail-safe हो और कोई identity स्वतः promote/demote न करे।
9. Main Admin-first helper का overlap regression test हो।
10. Invite registration failure के बाद Auth invitation partial-side-effect path verify हो।

### 121.5 वर्तमान स्थिति और सीमाएँ

- यह remediation/acceptance design केवल audit documentation है।
- कोई migration SQL, trigger, constraint, RPC, Edge Function या test file नहीं बदली गई।
- कोई database query, PostgreSQL replay, pgTAP, invite, CI, deployment या merge नहीं किया गया।
- Owner/DBA को विकल्प A या B चुनना है; तब तक cross-registry exclusivity **OPEN / NOT VERIFIED** रहेगी।


## 122. Main Admin allow-list का documented manual write path — 17 Nov 2026

Section 121 के बाद Audit Branch पर Main Admin registry के setup/documentation paths की जाँच की गई।

### 122.1 Manual allow-list enrollment

- `VERCEL_DEPLOY_HINDI.md` (blob `d1e79f473e966645ca6144a257aa1fcda9733791`, line 31) स्पष्ट रूप से Supabase Auth user UUID लेकर SQL Editor में यह command चलाने को कहता है:
  `insert into public.srk_admin_users(user_id) values ('YOUR_AUTH_USER_UUID') on conflict do nothing;`
- यह owner/operator द्वारा किया जाने वाला documented manual enrollment path है; यह Staff invitation Edge Function नहीं है।
- उपलब्ध command में target UUID के `srk_admin_staff` में पहले से होने की explicit जाँच नहीं है। यदि Section 121 का invariant चुना जाता है, तो database-side guard को इस manual SQL path पर भी लागू होना होगा।

### 122.2 Historical bootstrap/schema copies

- `PORTAL_SCHEMA.sql` (blob `efc14aa623a3895ffb3841b7b0f226f2015f34b1`) और `COMPLETE_DATABASE_SETUP.sql` (blob `2b806e727f449ba18e71ad23edef805ceb2da2b5`) में `srk_admin_users` की table definition दिखती है: `user_id` primary key, `auth.users(id)` foreign key; inspected definition में `srk_admin_staff` के साथ cross-table exclusion नहीं।
- `ADMIN_EMAIL_LOGIN_SETUP.sql` (blob `dbd91b3f912b1e0946bffe6d249a85cc41dc81cd`) allow-list को सुरक्षित रखने और `is_srk_admin()` पर आधारित Admin gate दिखाता है; inspected file में Main Admin allow-list enrollment का नया controlled RPC नहीं मिला।
- ये repository setup/bootstrap files हैं। इससे यह निष्कर्ष नहीं निकाला गया कि ये सभी Production में वर्तमान/सक्रिय रूप से चलाए गए हैं।

### 122.3 Combined lifecycle conclusion

- Staff invite path: Section 120 में target Main Admin exclusion नहीं मिली।
- Main Admin documented manual enrollment path: target Staff exclusion नहीं मिली।
- दोनों registry tables में inspected schema: cross-table invariant नहीं मिला।
- इसलिए दोनों दिशाओं के write paths को सुरक्षित करने के लिए केवल Staff invite RPC patch पर्याप्त नहीं होगा। Database-level invariant या canonical identity registry सभी insert/update paths पर लागू होना चाहिए।
- Live grants, actual write callers, current Production schema और वास्तविक overlapping identities इस source audit से प्रमाणित नहीं हैं; इनके लिए अलग approved read-only/runtime verification चाहिए।

### Status

- Manual Main Admin enrollment instruction: **source-confirmed**.
- Manual command में Staff membership exclusion: **not present in inspected command**.
- Cross-registry DB constraint in inspected bootstrap schema: **not found**.
- Production execution/current live state: **unknown; not queried**.
- No SQL/schema/RPC/permission change, no database query, no invite, no CI/deployment/merge.


## 123. दोनों Registry के वास्तविक source-level write points — 17 Nov 2026

Section 122 के बाद Audit Branch पर Staff registry migration और invitation Edge Function के exact write points पुनः पढ़े गए।

### 123.1 Staff registry का write point

- Migration `supabase/migrations/20261114390000_admin_staff_rbac_foundation.sql` (blob `5aa0f9058a56d735455f2a9944c861e8312ddb89`) में `srk_admin_staff_register_invited_user(uuid,text,uuid)` ही inspected staff-invite registration function है।
- Function `p_staff_user_id` और `p_actor_admin_id` non-NULL जाँचता है, actor को `srk_admin_users` में सत्यापित करता है, और display name validate करता है।
- इसके बाद यह सीधे `srk_admin_staff` में Support / invited row insert करता है। Target `p_staff_user_id` के `srk_admin_users` में पहले से होने की जाँच नहीं करता।
- Function पर PUBLIC, anon और authenticated execute revoke है; केवल `service_role` को execute grant है।
- Migration में `srk_admin_staff` पर browser roles की direct table privileges revoke हैं। इससे browser direct writes बंद करने का intent दिखता है, लेकिन privileged/service-role और future maintenance write paths के लिए cross-table invariant फिर भी आवश्यक है।

### 123.2 Edge Function का caller

- `supabase/functions/admin-staff-management/index.ts` (blob `c783989ca7142fce9d88270286bc916a66d22298`) Bearer token से Auth user सत्यापित करता है, `is_srk_admin()` से inviter authorize करता है, और role को server-side `support` पर स्थिर रखता है।
- Function पहले `inviteUserByEmail` करता है और फिर ऊपर दिए service-role RPC को target UUID देता है।
- Edge Function में invite से पहले target email/UUID को `srk_admin_users` से मिलाने की जाँच नहीं है।
- RPC fail होने पर Edge Function Auth user cleanup का प्रयास करता है; invitation email पहले भेजी जा चुकी हो सकती है। Cleanup fail होने पर manual Main Admin review की चेतावनी देता है।
- इसलिए invitation flow में duplicate/partial-side-effect handling मौजूद है, लेकिन Main Admin target exclusion का प्रमाण नहीं है।

### 123.3 Main Admin registry और combined write coverage

- Main Admin enrollment का documented SQL insert Section 122 में दर्ज है; inspected setup/bootstrap schema में cross-table constraint नहीं मिला।
- इस source pass में Staff registration का एक explicit SQL insert point और Main Admin का एक documented manual enrollment point पहचाना गया। यह पूरे repository, deployed Edge Functions, SQL Editor history या external service-role scripts की exhaustive inventory होने का दावा नहीं है।
- चुना जाने वाला DB-level invariant दोनों tables पर लागू होना चाहिए और INSERT के साथ identity-changing UPDATE तथा service-role/owner maintenance writes को भी cover करना चाहिए। केवल Edge Function pre-check या केवल registration RPC pre-check पर्याप्त नहीं है।

### 123.4 सुरक्षित अगला acceptance gate

1. Owner/DBA पहले तय करे: canonical identity registry या दोनों tables पर race-safe DB guard.
2. Migration में existing overlap detection हो; स्वतः किसी identity को promote/demote न किया जाए।
3. दोनों दिशाओं के inserts, UPDATE, concurrent inserts और service-role path के isolated PostgreSQL/pgTAP tests हों।
4. Invite failure/cleanup और पहले से मौजूद Auth identity के retry behavior का अलग परीक्षण हो।

### Status

- Staff registration function target Main Admin exclusion absent: **source-confirmed**.
- Edge Function pre-invite target exclusion absent: **source-confirmed**.
- Main Admin manual enrollment command: **Section 122 में source-confirmed**.
- Repository-wide / Production writer inventory: **not established**.
- No SQL/schema/RPC/Edge Function change, no DB query, no invitation, no pgTAP/CI/deployment/merge.


## 124. Admin setup दस्तावेज़ों का enrollment-path cross-check — 17 Nov 2026

दोनों registry write paths की जाँच के बाद संबंधित setup दस्तावेज़ों का cross-check किया गया।

- `PORTAL_SETUP_HINDI.md` (blob `dda516ff465a09f141e803897fb71c2d7294a453`, line 12) Admin Auth user UUID को `srk_admin_users` में डालने का निर्देश देता है और exact SQL के लिए `VERCEL_DEPLOY_HINDI.md` पर भेजता है।
- `VERCEL_DEPLOY_HINDI.md` (blob `d1e79f473e966645ca6144a257aa1fcda9733791`, line 31) वही manual SQL enrollment command देता है। यह अलग दूसरा SQL writer नहीं, उसी manual path का विस्तृत निर्देश है।
- `ADMIN_EMAIL_LOGIN_SETUP.sql` (blob `dbd91b3f912b1e0946bffe6d249a85cc41dc81cd`) के inspected हिस्से में existing `srk_admin_users` row मानकर RLS और `is_srk_admin()` setup किया गया है; यह file स्वयं Admin enrollment INSERT नहीं करती।
- `PORTAL_SCHEMA.sql` (blob `efc14aa623a3895ffb3841b7b0f226f2015f34b1`) में legacy `srk_is_admin()` helper है, जबकि `ADMIN_EMAIL_LOGIN_SETUP.sql` और Staff invite Edge Function `is_srk_admin()` नाम उपयोग करते हैं। यह historical/setup naming drift है; वर्तमान live function inventory या deployment state इस static check से तय नहीं होती।
- `SUPABASE_SCHEMA.sql` (blob `8ae88a7035bc963b244f22c6c1450c22618ec88f`) में इस scan के दौरान `srk_admin_users` enrollment reference नहीं मिला।

### निष्कर्ष

Inspected setup documents में Main Admin enrollment का एक documented manual SQL path है, जिसे एक से अधिक guide refer करते हैं; `ADMIN_EMAIL_LOGIN_SETUP.sql` अलग insert path नहीं है। इससे पहले Section 123 में पहचाने गए Staff registration RPC के साथ source-level write-path map थोड़ा स्पष्ट होता है, लेकिन यह सभी external scripts, repository history, hosted functions या Production writes की exhaustive inventory नहीं है।

### Status

- Setup guide cross-reference: **source-confirmed**.
- `ADMIN_EMAIL_LOGIN_SETUP.sql` में enrollment INSERT: **inspected file में नहीं मिला**.
- Legacy/current helper naming difference: **source-confirmed**.
- No SQL/schema/RPC/document setup change, no database query, no migration replay, no invite, no CI/deployment/merge.


## 125. Legacy और current Admin helper नाम / migration prerequisite — 17 Nov 2026

Section 124 के बाद helper-function compatibility को exact source पर जाँचा गया।

### 125.1 दो अलग function names

- `PORTAL_SCHEMA.sql` (blob `efc14aa623a3895ffb3841b7b0f226f2015f34b1`, lines 33–37) `public.srk_is_admin()` बनाता है और legacy Admin RLS policies उसी नाम को call करती हैं।
- `ADMIN_EMAIL_LOGIN_SETUP.sql` (blob `dbd91b3f912b1e0946bffe6d249a85cc41dc81cd`, lines 14–18) अलग function `public.is_srk_admin()` बनाता है।
- Staff RBAC migration `20261114390000_admin_staff_rbac_foundation.sql` (blob `5aa0f9058a56d735455f2a9944c861e8312ddb89`) `public.is_srk_admin()` को कई जगह call करता है, पर inspected migration में उस function की definition नहीं है।
- Follow-up volatility migration `20261116100000_fix_staff_permission_helper_volatility.sql` (blob `fc99aaf9c564b348e25a72b416dd4eb746e0fad3`) भी `public.is_srk_admin()` को call करता है; वह भी इस helper को define नहीं करती।

### 125.2 Dependency / deployment risk

- यदि deployment sequence में `ADMIN_EMAIL_LOGIN_SETUP.sql` पहले सफलतापूर्वक चल चुका है, तो Staff migration की इस helper dependency को वह पूरा कर सकता है।
- यदि केवल `SUPABASE_SCHEMA.sql`, `PORTAL_SCHEMA.sql` और Staff migrations चलाए जाएँ, तो legacy schema में `srk_is_admin()` उपलब्ध है, लेकिन Staff migration जिस `is_srk_admin()` को call करती है वह इस inspected sequence में define नहीं होती। इससे migration function creation या बाद के calls fail हो सकते हैं, exact PostgreSQL dependency validation के अधीन।
- दोनों helpers का body समान allow-list membership check करता है, लेकिन वे अलग object names हैं; एक दूसरे का alias नहीं हैं।
- यह static source/dependency finding है। किसी वास्तविक database में कौन-सा function मौजूद है, उसका owner/grants क्या हैं, या migration किस क्रम में चल चुकी है—यहाँ query नहीं किया गया।

### 125.3 Required resolution before replay

1. Canonical Admin predicate/function name owner/DBA तय करे।
2. Migration set में उस helper की authoritative definition और dependency ordering स्पष्ट हो।
3. Legacy `srk_is_admin()` callers/policies को inventory करके compatibility/retirement plan बनाया जाए; बिना review legacy function drop न हो।
4. Clean disposable PostgreSQL replay में दोनों setup paths और Staff migrations का क्रम सत्यापित हो; missing-helper negative case और expected helper-present case के tests हों।

### Status

- Legacy `srk_is_admin()` vs current `is_srk_admin()` naming drift: **source-confirmed**.
- Staff migration calls helper without defining it in that migration: **source-confirmed**.
- Actual live DB helper availability / replay failure: **not tested; not asserted**.
- No migration/helper/RLS/grant change, no database query, no PostgreSQL replay/pgTAP, no CI/deployment/merge.

## 126. Canonical combined setup bundle में current helper की मौजूदगी — 17 Nov 2026

Section 125 के conditional migration dependency को स्पष्ट करने के लिए canonical setup bundle और उसके निर्देशों का cross-check किया गया।

### 126.1 Combined setup script का क्रम

- `COMPLETE_DATABASE_SETUP.sql` (blob `2b806e727f449ba18e71ad23edef805ceb2da2b5`, 402 lines) में शुरुआती portal section के दौरान लगभग lines 133–137 पर legacy `public.srk_is_admin()` define होता है।
- उसी combined script के बाद के Admin email-login section में लगभग lines 323–338 पर current `public.is_srk_admin()` भी define होता है।
- इसलिए इस file की पूरी सामग्री सफलतापूर्वक चलने पर दोनों नामों की definitions script में मौजूद हैं; यह Section 125 के “केवल SUPABASE_SCHEMA.sql + PORTAL_SCHEMA.sql + Staff migrations” वाले सीमित sequence से अलग स्थिति है।
- Combined script में Admin email-login block existing `srk_admin_users` row मानता है; Main Admin UUID enrollment निर्देश अलग setup steps में दिया गया है।

### 126.2 Documentation का canonical path

- `PORTAL_SETUP_HINDI.md` (blob `dda516ff465a09f141e803897fb71c2d7294a453`, line 3) कहता है कि मुख्य setup के लिए `VERCEL_DEPLOY_HINDI.md` पढ़ें और केवल `COMPLETE_DATABASE_SETUP.sql` एक बार चलाएँ।
- `VERCEL_DEPLOY_HINDI.md` (blob `d1e79f473e966645ca6144a257aa1fcda9733791`, लगभग lines 20–22) भी इसी combined file को एक बार चलाने को कहता है और उसे base schema, portal access, privacy rules, Admin email login और payment tracking का क्रमबद्ध setup बताता है।
- `README.md` (blob `ad80aa238eed5f3963c1fce1c5836c34b3ba75de`) में Database section Main Supabase project का उल्लेख करता है, पर इस migration set के लिए अलग से authoritative clean-replay order नहीं देता।
- `ADMIN_EMAIL_LOGIN_SETUP.sql` standalone विकल्प में भी `is_srk_admin()` define होता है, लेकिन वह existing Admin row मानता है और combined setup guide का मुख्य one-file path नहीं है।

### 126.3 संशोधित निष्कर्ष

- यदि documented combined setup `COMPLETE_DATABASE_SETUP.sql` पूरा सफलतापूर्वक चलाया गया हो और उसके बाद Staff migrations लागू हों, तो इस script में current `is_srk_admin()` definition मौजूद है। इसलिए Section 125 की helper dependency उस documented setup path में source-level पर पूरी हो सकती है।
- यदि migration-only clean replay में यह combined bootstrap script या कोई equivalent prior helper definition शामिल नहीं है, तो Staff migration की `is_srk_admin()` dependency अब भी unresolved prerequisite है।
- यह निष्कर्ष file contents और documentation पर आधारित है। SQL blocks का वास्तविक execution, statement-level success, migration runner ordering, live DB function inventory और clean PostgreSQL replay जाँचे नहीं गए।
- Combined setup script का मौजूद होना अपने-आप यह प्रमाणित नहीं करता कि वह Production में चला है या सभी statements सफल हुए हैं।

### 126.4 Required resolution before replay

1. Owner/DBA तय करे कि clean replay का authoritative starting point `COMPLETE_DATABASE_SETUP.sql` है या migration-only baseline।
2. यदि migration-only baseline चुना जाता है, तो `is_srk_admin()` की authoritative definition को migration dependency chain में स्पष्ट रूप से शामिल करने की योजना बने; अभी कोई helper/migration edit नहीं किया गया।
3. Disposable PostgreSQL में documented combined setup + Staff migrations और migration-only baseline दोनों के replay order की जाँच हो।
4. Replay में दोनों helper names, grants, RLS policy callers और expected function availability verify हों।

### Status

- Combined setup script में legacy और current दोनों helper definitions: **source-confirmed**.
- Setup guide का one-file canonical instruction: **source-confirmed**.
- Documented full-bundle path पर helper dependency पूरी होने की संभावना: **source-level; execution unverified**.
- Migration-only baseline पर prerequisite: **अब भी स्पष्ट रूप से दर्ज; runtime untested**.
- No SQL/schema/helper/migration change, no database query, no PostgreSQL replay/pgTAP, no CI/deployment/merge.

## 127. Staff RBAC migration timestamp और helper bootstrap के बीच क्रम — 17 Nov 2026

Section 126 के बाद Migration directory के वास्तविक timestamped filenames और Staff RBAC के आस-पास की migrations जाँची गईं।

### 127.1 Migration directory में क्रम

- Staff RBAC foundation का filename `20261114390000_admin_staff_rbac_foundation.sql` है।
- इसके ठीक बाद timestamp के अनुसार `20261114410000_razorpay_webhook_event_inbox.sql` आता है; inspected file में `is_srk_admin()` या `srk_is_admin()` का उल्लेख नहीं मिला।
- बाद की `20261116100000_fix_staff_permission_helper_volatility.sql` migration `srk_has_admin_permission(text)` को VOLATILE बनाकर फिर से define करती है और `public.is_srk_admin()` call करती है; वह भी helper definition नहीं बनाती।
- `20261116110000_pin_legacy_financial_read_rpc_search_paths.sql` अगली timestamped migration है; inspected file में इन Admin helper names का उल्लेख नहीं मिला।
- Migration tree में `COMPLETE_DATABASE_SETUP.sql` timestamped migration file नहीं है। वह repository root की अलग bootstrap/setup SQL file है।

### 127.2 Replay का व्यावहारिक अर्थ

- Migration runner की timestamp ordering अपने-आप root-level `COMPLETE_DATABASE_SETUP.sql` को पहले चलाने की गारंटी नहीं देती।
- इसलिए यदि clean replay प्रक्रिया केवल `supabase/migrations/*.sql` चलाती है, तो Staff RBAC migration से पहले `is_srk_admin()` उपलब्ध कराने वाला स्पष्ट migration-file prerequisite इस inspected sequence में स्थापित नहीं हुआ।
- यदि अलग documented bootstrap step में पूरा `COMPLETE_DATABASE_SETUP.sql` सफलतापूर्वक चलाया जाता है, तो Section 126 के अनुसार current helper definition मौजूद हो सकती है।
- उपलब्ध source से यह तय नहीं होता कि project का वास्तविक deployment/replay runner bootstrap file को migrations से पहले चलाता है या नहीं। कोई runtime failure घोषित नहीं किया जा रहा।

### 127.3 Replay gate

1. Owner/DBA एक authoritative replay recipe लिखित रूप में तय करे: bootstrap SQL पहले, फिर timestamped migrations; या migration-only baseline।
2. यदि migration-only baseline है, तो helper definition का migration-chain में स्थान तय और source-reviewed हो।
3. Disposable PostgreSQL में runner के वास्तविक क्रम से replay करें और पहली Staff migration से पहले `to_regprocedure('public.is_srk_admin()')` जैसी catalog जाँच से helper presence verify करें।
4. Replay log, migration history और helper owner/grants दर्ज किए बिना Production readiness घोषित न करें।

### Status

- Staff RBAC और follow-up migration filenames/timestamps: **source-confirmed**.
- Follow-up volatility migration helper को define नहीं करती: **source-confirmed**.
- Root bootstrap SQL का migration directory से अलग होना: **source-confirmed**.
- Actual runner order / live DB helper presence / replay outcome: **unknown; not tested**.
- No SQL/migration/helper change, no database query, no PostgreSQL replay/pgTAP, no CI/deployment/merge.

## 128. Staff RBAC से पहले की migrations में भी current Admin helper calls — 17 Nov 2026

Section 127 के बाद एक अतिरिक्त dependency scan किया गया। Repository code-search से मिले candidate paths को Audit Branch पर अलग से fetch करके सत्यापित किया गया।

### 128.1 Timestamped migrations में पहले के calls

- `20261108234000_combine_booking_read_policy.sql` (blob `d5925919ce9cb312349f5ca39916453cdc5262fa`, line 12) policy expression में `public.is_srk_admin()` call करता है।
- `20261109001000_add_google_maps_location_support.sql` (blob `465097e26a93cff333289ecd6b18db4dd373622a`, line 27) Admin check में `public.is_srk_admin()` call करता है।
- `20261109003000_secure_commission_reporting.sql` (blob `9b4ed1529ea2a6e4da4ba0804bdbc9b3612627b9`, line 19) Admin authorization में यही helper call करता है।
- `20261109010000_create_secure_wallet_ledger_foundation.sql` (blob `6b5871d6fcc10fa225a5bbb8e26911b7027e2043`, line 158) भी यही helper call करता है।
- `20261113230000_support_attachment_paths_and_admin_message_list.sql` (blob `aaeb6f0d7efe680735039a0a516bd5fcce2dafa0`, lines 57 और 98) दो functions में यही helper call करता है।
- ये सभी migrations Staff RBAC foundation `20261114390000_admin_staff_rbac_foundation.sql` से timestamp में पहले हैं। इनमें से जाँची गई files helper को स्वयं define नहीं करतीं।

### 128.2 इसका असर

- Helper dependency केवल Staff RBAC migration तक सीमित नहीं है। Migration-only clean replay में current `is_srk_admin()` की जरूरत पहले की timestamped migrations में ही सामने आती है।
- Root-level `COMPLETE_DATABASE_SETUP.sql` में current helper definition मौजूद है, इसलिए यदि documented bootstrap step पहले और सफलतापूर्वक चलता है तो यह dependency पूरी हो सकती है।
- यदि runner केवल timestamped migration directory से शुरू होता है और bootstrap SQL पहले नहीं चलती, तो पहली relevant migration पर helper dependency unresolved हो सकती है। यह source-level risk है; PostgreSQL runtime failure अभी प्रमाणित नहीं है।
- पुराना `srk_is_admin()` helper इन current-name calls का स्वतः विकल्प नहीं है; दोनों अलग function names हैं।

### 128.3 Replay के लिए नया अनिवार्य निर्णय

1. सभी migration runs से पहले `is_srk_admin()` की definition उपलब्ध कराने वाला bootstrap contract लिखित और reproducible होना चाहिए।
2. वैकल्पिक रूप से, helper को migration chain में ऐसी शुरुआती migration से उपलब्ध कराने का reviewed design बने जो पहली caller migration से पहले चले। अभी कोई migration edit नहीं किया गया।
3. Clean replay test को कम-से-कम earliest caller `20261108234000` से शुरू करके वास्तविक runner order में चलाया जाए।
4. Replay log में earliest caller से पहले helper existence, function owner/grants और policy/function creation success रिकॉर्ड हों।

### Status

- पाँच earlier timestamped migration files में current helper calls: **source-confirmed on Audit Branch**.
- उन पाँच inspected migration files में helper definition नहीं मिली: **source-confirmed for inspected files only**.
- Root setup bundle में helper definition: **Section 126 के अनुसार source-confirmed**.
- Full repository के हर SQL/PLpgSQL caller/definition की exhaustive inventory और actual clean replay: **अभी बाकी / runtime untested**.
- No SQL/schema/helper/migration change, no database query, no PostgreSQL replay/pgTAP, no CI/deployment/merge.

## 129. वास्तविक repository replay harness और CI workflow की सीमा — 17 Nov 2026

Audit Branch की recursive Git tree तथा workflow/config files की source-only जाँच की गई।

### 129.1 Supabase CLI project configuration

- Audit Branch की recursive tree में `supabase/config.toml` और `supabase/seed.sql` नहीं मिले।
- इसलिए इस repository snapshot से कोई project-local Supabase CLI configuration, seed bootstrap या पूर्ण `supabase migration up/db push` runner order प्रमाणित नहीं होता।
- `package.json` में केवल Node test scripts हैं: `test:refund`, `test:webhook`, `test:customer-payment`, और `test`। कोई migration/replay script घोषित नहीं है (blob `8a559d1daf4dac6c140a168bb71cc5da914dce58`)।

### 129.2 GitHub Actions schema workflow

Workflow `.github/workflows/supabase-schema-ci.yml` (blob `8cdd128fb69227fee82b5084f8b78634f13ffcb2`) में:
- Trigger केवल `workflow_dispatch` है।
- Job condition केवल `refs/heads/feature/platform-fee-cash-online-cycle` को अनुमति देती है; GPT-2 Audit Branch इस condition में नहीं है।
- Workflow GitHub Secret `SUPABASE_DB_URL` से remote database का schema-only dump लेती है, फिर isolated local Supabase stack में restore करती है।
- इसके बाद केवल पाँच hard-coded Feature migrations चलाती है: `20261112170000`, `20261112193000`, `20261112220000`, `20261112230000`, `20261113090000`।
- Audit Branch की recursive tree में ये पाँच exact migration paths मौजूद नहीं हैं। इसलिए इस branch पर workflow को वर्तमान migration chain का replay harness नहीं माना जा सकता।
- Workflow full `supabase/migrations/` directory को enumerate/apply नहीं करती; यह 89-file current Audit Branch migration set का clean replay नहीं है।

### 129.3 Inventory और documentation drift

- इस Audit Branch recursive tree में `supabase/migrations/` के **89 SQL files** गिने गए।
- `docs/MIGRATION_REPLAY_MANIFEST_HI.md` में 78 files तथा बाद के ऐतिहासिक sections में 87 files का उल्लेख है; वह manifest पुराने Feature Branch snapshots पर आधारित है, current Audit Branch की 89-file inventory नहीं।
- `docs/MIGRATION_DEPENDENCY_MATRIX_HI.md` का 73-file count भी पुराने Feature Branch static scan का है। इन पुराने counts को current Audit Branch count के रूप में उद्धृत न किया जाए।

### 129.4 Clean Replay के लिए निष्कर्ष

1. अभी कोई repository-local authoritative migration runner/config नहीं मिला।
2. मौजूदा Supabase schema workflow manual, branch-restricted, remote schema export पर निर्भर और hard-coded five-file test है; इसे Audit Branch पर चलाना न तो संभव/उचित सिद्ध है और न ही full clean replay।
3. पहले owner/DBA को authoritative baseline source, bootstrap contract, exact 89-file inventory और duplicate-version resolution मंजूर करना होगा।
4. उसके बाद अलग disposable local Supabase/PostgreSQL harness बनाया जाए जो Audit Branch की पूरी migration directory को निर्धारित क्रम में लागू करे; इसमें Production URL/credentials या Production data न हों।
5. किसी भी workflow edit/dispatch से पहले अलग स्पष्ट अनुमति और सुरक्षित local-only design आवश्यक है।

### Status

- Audit Branch tree: 89 SQL migration filenames — **source-count confirmed**.
- `package.json` में migration runner script नहीं — **source-confirmed**.
- `supabase/config.toml` / `supabase/seed.sql` absent from inspected recursive tree — **source-confirmed**.
- Existing schema workflow manual-only, branch-restricted, schema-dump based, five hard-coded migrations — **source-confirmed**.
- Existing workflow was not dispatched; no database contacted; no SQL, PostgreSQL replay, pgTAP, CI, deployment, merge or Production change performed.

## 130. शुरुआती Migration dependency chain — SQL body से सत्यापित — 17 Nov 2026

Audit Branch की शुरुआती sequence में पहले 18 migration bodies fetch करके SQL statements पढ़े गए। यह static source inspection है, PostgreSQL parse/replay नहीं।

### 130.1 स्पष्ट क्रम-निर्भरता

1. 20261108120608_add_public_api_rate_limiting.sql private schema, private.srk_public_api_rate_limits और public.srk_check_public_rate_limit(text,text,integer) बनाती है।
2. 20261108120658_enable_rls_public_api_rate_limits.sql उसी private table पर RLS enable करती है। स्पष्ट prerequisite: 08120608 पहले।
3. 20261108121115_add_customer_account_booking_access.sql existing public.service_bookings पर customer_user_id जोड़ती है और customer SELECT policy बनाती है।
4. 20261108234000_combine_booking_read_policy.sql उसी customer ownership column को policy में उपयोग करती है और public.is_srk_admin() call करती है। स्पष्ट prerequisites: service_bookings + 08121115 customer_user_id + Admin helper bootstrap.
5. 20261109000500_harden_electrician_profile_identity_linking.sql electrician_profiles.auth_user_id जोड़ती है; existing user_id, phone, verification_status, auth.users पर निर्भर होकर identity columns sync/guard triggers बनाती है।
6. 20261109001000_add_google_maps_location_support.sql अपनी टिप्पणी में 09000500 के बाद चलने की बात कहती है; यह auth_user_id सहित दोनों identity columns लिखती है, location columns जोड़ती है, और is_srk_admin() वाला application-review RPC परिभाषित करती है।
7. 20261109001500_unique_electrician_admin_identity_linking.sql स्पष्ट रूप से 09001000 के बाद चलने को कहती है; उसी signature का पहले वाला Admin review function drop करके JSONB-returning function बनाती है और legacy srk_is_admin() call करती है।
8. 20261109002000_expose_assigned_booking_map_pin.sql service_bookings.location_lat/location_lng को पढ़ती है; इसलिए 09001000 के location DDL के बाद आना चाहिए।
9. 20261109003000_secure_commission_reporting.sql service_bookings.amount_paid को numeric(12,2) के रूप में ADD IF NOT EXISTS करती है; इसके बाद उसी कॉलम पर report/earnings RPCs बनाती है। यह later migration 20261116200000_restore_service_bookings_amount_paid.sql से पहले ही column introduce करती है।
10. 20261109010000_create_secure_wallet_ledger_foundation.sql electrician_profiles.auth_user_id और user_id पढ़ती है; इसलिए identity-column prerequisite (09000500) जरूरी है।
11. 20261109020000_create_server_only_razorpay_route_transfer_ledger.sql existing service_bookings(id) और auth.users(id) पर FK बनाती है।
12. 20261109103038_customer_electrician_direct_call_contacts.sql service_bookings.customer_user_id तथा assigned profile/booking columns पढ़ती है; 08121115 ownership column इसका prerequisite है।
13. 20261109103143_move_customer_call_contact_lookup_to_private.sql उसी public RPC को private implementation + invoker wrapper से बदलती है; 09103038 के बाद आने वाला replacement है।

### 130.2 दो समान 8-digit version files का वास्तविक overlap

- 20261109_allow_quote_approval_booking_states.sql और 20261109_electrician_inspection_quotes_and_service_only_commission.sql दोनों service_bookings_status_check और service_bookings_assignment_status_requires_electrician को DROP/ADD करती हैं।
- बड़ी quote migration पहली ही बार इन दोनों constraints को जोड़ती है; अलग 8-digit file वही constraints फिर से DROP/ADD करती है।
- Quote migration में amount_paid, service_bookings की अन्य baseline columns, electrician_profiles, job_offers, auth.uid() और trigger/function contracts उपयोग होते हैं।
- इसलिए दोनों को source-only आधार पर अलग-अलग versioned identities मानकर replay order तय करना सुरक्षित नहीं। CLI parser behavior और remote applied history का स्वतंत्र प्रमाण अभी नहीं है। कोई rename/delete/resequence नहीं किया गया।

### 130.3 शुरुआती provisional dependency graph (execution order नहीं)

- Rate-limit table → rate-limit RLS.
- Customer booking ownership column → consolidated customer/Admin booking policy → customer call-contact RPC.
- Electrician identity column + sync/guard triggers → Google Maps/Admin approval RPC → unique-only Admin approval replacement → wallet summary.
- Google Maps location columns → assigned booking map-pin RPC.
- amount_paid introducing DDL → commission/earnings RPC consumers.
- Complaint base migration → बाद की support conversation/message/attachment migrations (बाद की पूरी chain अलग से verify करनी है).
- Push subscription base table → push outbox → delivery ledger → health/lease fencing (बाद की पूरी chain अलग से verify करनी है).

### 130.4 महत्वपूर्ण सीमा और आगे का काम

- यह Section केवल fetch की गई शुरुआती migration bodies के स्पष्ट references/DDL को map करता है; 89/89 files की पूर्ण transitive dependency graph नहीं है।
- Existing starter/base schema में service_bookings, electrician_profiles, job_offers, electrician_applications, auth.users, roles, extensions और helper functions का exact authoritative baseline अभी अलग gate है।
- is_srk_admin() और srk_is_admin() अलग function names हैं; relevant earliest callers के पहले दोनों की availability/compatibility स्पष्ट होनी चाहिए।
- अगले pass में 20261113–20261117 support, financial audit, RBAC, refund, payout, Route, push और search_path migrations की object-level prerequisites map करनी हैं।
- कोई SQL execution, PostgreSQL parser/replay, pgTAP, database query/write, CI dispatch, deployment या merge नहीं किया गया।

## 131. Support, financial base और customer RPC dependency chain — 17 Nov 2026

इस pass में Support conversation, Finance audit core, customer rate-tier, receipt/history और dispatch migrations के source bodies/DDL points पढ़े गए। यह static source-level dependency mapping है।

### 131.1 Support conversation chain

- 20261110040000_customer_admin_complaints.sql पहले srk_booking_complaints और srk_booking_complaint_events बनाती है; complaint FK service_bookings और customer/auth ownership पर निर्भर है।
- 20261113220000_customer_support_conversation_schema.sql स्पष्ट रूप से पहले complaint base की जरूरत रखती है: messages और attachments tables complaint IDs को FK करती हैं। यह composite attachment FK के लिए messages(id, complaint_id) unique index पहले बनाती है। यह storage.objects, storage.buckets और public.is_srk_admin() भी इस्तेमाल करती है।
- 20261113230000_support_attachment_paths_and_admin_message_list.sql 13220000 में बने message/attachment tables और complaint base पर निर्भर है; यह उन्हीं tables पर customer/admin listing RPCs बनाती है।
- 20261114201428_customer_profile_saved_addresses_private_storage.sql के comment और statements बताते हैं कि customer-support bucket तथा access helper पहले से मौजूद होने चाहिए; यह support bucket की broader delete policy हटाकर linked attachment protection वाली policy बनाती है।
- इसलिए provisional chain: complaint base (10040000) → support message/attachment + bucket/helper (13220000) → Admin/customer attachment listing (13230000) → avatar/saved-address migration का support delete-policy tightening (14201428).
- Storage schemas/roles/extensions और helper availability का exact baseline अलग से verify होना बाकी है।

### 131.2 Financial audit core chain

- 20261114125844_restore_financial_audit_core_schema.sql सात core relations बनाती है: srk_booking_labour_bills, srk_manual_payment_entries, srk_electrician_payouts, srk_admin_audit_events, srk_razorpay_refunds, srk_booking_refund_requests और srk_manual_refund_entries।
- उसी migration में RLS, grants, indexes, audit capture functions और service_bookings/electrician_profiles/electrician_applications तथा finance tables पर audit triggers बनते हैं।
- इसके comments में स्पष्ट है कि labour bill table को work-timer migration से पहले लाया जा रहा है और यह 14190000 receipt तथा 14200000 payment-history RPCs से पहले होना चाहिए।
- 20261114190000_customer_receipt_immutable_labour_amount.sql srk_booking_labour_bills तथा service_bookings payment fields पढ़ती है।
- 20261114200000_customer_payment_refund_history_rpc.sql srk_booking_refund_requests, srk_razorpay_refunds और srk_manual_refund_entries के साथ service_bookings पढ़ती है।
- इसलिए financial base core (14125844) → receipt (14190000) और payment/refund history (14200000) एक स्पष्ट dependency edge है।
- Base tables की FK dependencies service_bookings, electrician_profiles, auth.users और कुछ payment columns पर हैं; इनका authoritative starter schema और column contract फिर भी जरूरी है।

### 131.3 Customer rate-tier / dispatch chain

- 20261114160000_customer_selected_rate_tier_and_server_estimate.sql service_bookings, electrician_applications, electrician_profiles और job_offers पर columns/functions/triggers बदलती है; यह srk_private schema स्वयं बनाती है, फिर srk_private.electrician_rate_tier_authorizations table बनाती है।
- यह existing public.is_srk_admin() और existing private/public offer-dispatch functions को उपयोग/replace करती है। इसलिए Admin helper तथा शुरुआती offer/booking baseline objects पहले चाहिए।
- 20261114210000_sequential_nearest_offer_dispatch.sql job_offers में expires_at जोड़ती है, private dispatch/candidate tables बनाती है और broadcast_booking_job तथा offer response/expiry functions replace करती है। यह 14160000 में परिभाषित private.srk_offer_booking_to_eligible_electricians(uuid) को भी replace करती है।
- इसलिए selected-rate-tier and offer eligibility (14160000) → sequential dispatch replacement (14210000) source-level ordering dependency है।
- 20261114150000_customer_booking_submission_idempotency.sql booking request key/fingerprint columns और unique index जोड़ती है; यह service_bookings baseline पर निर्भर है।
- 20261114180000_harden_customer_avatar_object_integrity.sql customer profile/avatar storage contract को harden करती है; 14201428 में srk_customer_profiles और avatar bucket बनने के बाद इसका exact placement/compatibility runtime review माँगता है। इस pass में इसे standalone order-safe घोषित नहीं किया गया।

### 131.4 शुरुआती क्रम के लिए अभी भी खुले gates

1. Complaint base और Storage objects का approved baseline.
2. Finance core से पहले सभी referenced booking/profile/payment columns की exact definition.
3. Admin helper names (is_srk_admin vs srk_is_admin) और earliest migration availability.
4. 14180000 avatar hardening तथा 14201428 profile/storage creation का वास्तविक dependency order — source bodies का अलग targeted comparison जरूरी।
5. Offer dispatch function replacements का exact final body और triggers का replay behavior.
6. यह mapping 89/89 migrations की पूर्ण transitive dependency graph नहीं है; अभी शेष mid/late migrations का review जारी है।

No SQL, PostgreSQL replay, pgTAP, DB query/write, CI dispatch, deployment or merge performed.

## 132. Work lifecycle, refund, route, push और late financial migrations — 17 Nov 2026

इस pass में 14 Nov से 17 Nov तक की शेष मुख्य migration bodies का source-level object/DDL review किया गया। यह पूर्ण runtime replay नहीं है।

### 132.1 Work timer और append-only work events

- 20261114240000_server_authoritative_customer_approved_work_timer.sql service_bookings में timer/approval state columns, srk_private authorization tables और srk_booking_labour_bills बनाती है; साथ में booking guard, work-start/completion RPCs और labour bill RPCs बनाती है।
- 20261114125844_restore_financial_audit_core_schema.sql इससे पहले srk_booking_labour_bills को CREATE TABLE IF NOT EXISTS से बनाती है। दोनों migrations एक ही relation के creation point हैं। IF NOT EXISTS दूसरी table definition को reconcile नहीं करता; इसलिए पहले वाली definition बन जाने पर 14240000 की CREATE TABLE definition लागू नहीं होगी। Exact column parity/constraints/indexes की तुलना और एक authoritative schema तय करना आवश्यक है।
- 20261114250000_admin_work_dispute_review_and_immutable_history.sql srk_booking_work_events बनाती है और service_bookings trigger से history capture करती है।
- 20261114260000_fix_work_start_rpc_and_append_only_event_history.sql उसी event relation पर mutation/truncate guards और customer timeline RPC जोड़ती है। इसलिए 14250000 → 14260000 स्पष्ट dependency है।
- 20261114270000_admin_only_cancellation_requests_and_decisions.sql cancellation request/event tables, immutable-event trigger और service_bookings status guard जोड़ती है।
- 20261114280000_cancellation_fee_carry_forward_and_accounting.sql wallet ledger, cancellation request flow, booking/payment state और service-role payment functions पर निर्भर होकर debt/item/fee-ledger tables तथा booking triggers बनाती है।
- 20261114290000_full_refund_cancellation_fee_and_wallet_reversal.sql 14280000 के fee/debt/ledger objects और 14125844 के refund/manual refund tables पर निर्भर होकर full-refund reversal तथा refund RPCs replace करती है।
- Provisional chain: work timer/bill baseline → work events → append-only timeline → cancellation request → cancellation fee accounting → full-refund reversal.

### 132.2 Customer cancellation/payment और support RPC replacements

- 20261114300000_admin_customer_support_thread_replies.sql earlier complaint/support message tables पर Admin reply RPC जोड़ती है।
- 20261114202250_customer_complaint_customer_safe_projection.sql earlier complaint base पर customer-safe complaint projection बनाती है।
- 20261114202656_customer_change_payment_method_rpc.sql booking payment-method contract पढ़ती/बदलती है; 20261115270000 बाद में इसी RPC का Unicode/payment-method contract replacement करती है।
- 20261115100000_customer_refund_request_contract.sql refund request base और customer request/list RPC बनाती है; 20261115110000 Admin review queue/decision RPC इन्हें replace/extend करती है।
- 20261115130000_admin_manual_refund_request_completion.sql manual refund completion RPC बनाती है; 15120000 durable recovery evidence और 15240000/15250000 recovery/reconciliation hardening उससे अलग provider-recovery chain है।
- 15120000 recovery evidence table और service-only evidence/finalizer functions बनाती है; 15240000 उसी finalizer को full-amount rule से replace करती है; 15250000 refund reconcile RPC को full-amount rule से replace करती है।
- Refund request table/core refund/manual refund/payment-entry tables की dependency 14125844 financial base और 15100000 request contract पर है।

### 132.3 KYC, staff RBAC और identity baseline

- 20261115140000_electrician_kyc_review_and_activation_gate.sql KYC document/event tables, Storage object policies, upload/review RPCs तथा electrician activation और rate-tier guards बनाती/replace करती है। यह storage.objects, storage buckets, electrician_profiles, auth.users और पहले से मौजूद rate-tier guard पर निर्भर है।
- 20261114390000_admin_staff_rbac_foundation.sql staff/permissions/role map/session/audit/assignment tables, RLS और अनेक Staff RPCs बनाती है। यह earlier support complaint/message और electrician ticket tables को भी alter/read करती है।
- 20261116100000_fix_staff_permission_helper_volatility.sql Staff permission helper को VOLATILE रूप में replace करती है; यह 14390000 के बाद का patch है, पर public.is_srk_admin() bootstrap dependency बनी रहती है।
- Identity overlap/target-exclusion findings Sections 118–125 में हैं; इन migrations से live registry state प्रमाणित नहीं होती।

### 132.4 Razorpay Route ledger retire और reconciliation compatibility

- 20261109020000_create_server_only_razorpay_route_transfer_ledger.sql future Route transfer ledger बनाती है।
- 20261115092149_retire_unused_razorpay_route_transfer_ledger.sql बिना CASCADE के public.srk_route_transfers को DROP करती है।
- 20261115170000_admin_route_transfer_accounting_reconciliation.sql अपने header/body में Route ledger retired मानती है, Route response fields को zero और provider settlement verified को false लौटाती है; इसका inspected body srk_route_transfers table को query नहीं करता।
- 20261115180000_admin_route_recipient_and_settlement_validation.sql उसी reconciliation RPC को फिर replace करती है। इसके final body में route provider/recipient evidence की contract validation अलग से review होनी चाहिए; यह migration क्रम में 15170000 के बाद है।
- 20261115190000_enforce_single_primary_route_bank_link.sql wallet bank-link table पर unique index बनाती है; इससे Route provider settlement का प्रमाण नहीं मिलता।
- यह route ledger retirement और later Route reconciliation function names का deliberate compatibility design हो सकता है, पर 15180000 का पूरा body + Feature/Audit branch contract alignment owner review के बिना निष्कर्ष नहीं है।

### 132.5 Push delivery chain और duplicate migration identity

- 20261111020000_add_electrician_push_subscriptions.sql public.srk_push_subscriptions बनाती है।
- 20261115170001_durable_push_delivery_outbox.sql इसी subscription table की RLS policies बदलती है और srk_private.srk_push_delivery_outbox बनाती है; यह earlier subscription table के बिना नहीं चल सकती।
- 20261115180001_push_subscription_delivery_ledger.sql outbox delivery attempts/ledger बनाती है; 15170001 outbox इसका prerequisite है।
- 20261115190001_push_delivery_health_monitoring.sql outbox/ledger health और retry RPCs बनाती है।
- 20261115200001_push_delivery_lease_fencing.sql दो finish RPC signatures DROP/CREATE करके lease fencing जोड़ती है; यह outbox और delivery ledger दोनों के बाद चलनी चाहिए।
- Tree में 20261115120001_fix_multi_profile_electrician_labour_bill_access.sql और 20261115145900_fix_multi_profile_electrician_labour_bill_access.sql का exact Git blob समान है: e3bdf2624c224322a6ac4c99f2ae6e77b1be4774। अलग filenames/timestamps के बावजूद content identical है। Supabase CLI/remote history में दोनों कैसे दर्ज हैं, इसका प्रमाण नहीं; इसे silently deduplicate/rename नहीं किया गया।

### 132.6 Late search_path, amount_paid और payout/commission bridge

- 20261116110000 से 16170000 तक के search_path patch files पहले बने RPCs के definitions को replace/secure करते हैं; इन्हें target RPC migrations के बाद ही चलाया जा सकता है।
- 20261116200000_restore_service_bookings_amount_paid.sql amount_paid column ADD IF NOT EXISTS करती है, लेकिन 20261109003000_secure_commission_reporting.sql पहले ही यही column numeric(12,2) में add कर चुकी है। इसलिए later migration restore intent है; वह पहला introduction नहीं।
- 20261116210000_attach_electrician_payout_reconciliation_trigger.sql 14360000 के payable function को replace करती है, service_bookings trigger attach करती है, और manual refund/recovery finalizer functions को भी replace करती है। इसे financial core + payout base + earlier refund/recovery evidence migrations के बाद चाहिए।
- 20261117010000_reconcile_booking_commission_and_manual_payment_method.sql commission BEFORE trigger, payout parity AFTER trigger और accounting reconciliation/commission/earnings RPCs बनाती है। यह 16210000 के payout trigger/function body के साथ interaction की समीक्षा माँगती है; दो अलग trigger responsibilities को एक-दूसरे का विकल्प न समझें।
- 15150000, 15170000 और 15180000 एक ही reconciliation RPC signature को क्रमशः replace करते हैं; Audit Branch का late 17010000 फिर उसे replace करता है। इसलिए अंतिम RPC body migration order में सबसे बाद वाले compatible definition पर निर्भर है; Feature Branch body को Audit Branch में बिना merge review के नहीं लेना चाहिए।

### 132.7 Duplicate version / replay gates

1. दो समान 8-digit version files (Section 130) के साथ अब exact identical 14-digit migration bodies 15120001/15145900 भी दर्ज हैं। Supabase migration history semantics और duplicate version handling की पुष्टि जरूरी है।
2. srk_booking_labour_bills के दो अलग CREATE TABLE IF NOT EXISTS definitions (14125844 और 14240000) का column/constraint parity audit आवश्यक है।
3. Route ledger drop (15092149) और route-related reconciliation replacement (15170000/15180000) को final contract के रूप में owner/DBA से स्पष्ट कराना है।
4. Search-path patches और repeated RPC replacements के final function bodies का source hash/ordering matrix बनाना बाकी है।
5. No SQL, PostgreSQL parser/replay, pgTAP, DB query/write, CI dispatch, deployment or merge performed.

## 133. Audit Branch का 89-file inventory और duplicate-version matrix — 17 Nov 2026

Audit Branch के recursive Git tree को फिर से पढ़ा गया। Tree response truncated नहीं था। `supabase/migrations/` में ठीक 89 SQL files मिलीं। यह inventory केवल इस branch snapshot का है।

### 133.1 दिन-वार inventory

| Filename date prefix | SQL files |
|---|---:|
| 20261108 | 5 |
| 20261109 | 11 |
| 20261110 | 2 |
| 20261111 | 1 |
| 20261113 | 2 |
| 20261114 | 30 |
| 20261115 | 27 |
| 20261116 | 10 |
| 20261117 | 1 |
| **कुल** | **89** |

12 Nov prefix की कोई migration file इस tree में नहीं मिली। यह केवल filename inventory है, applied migration history का प्रमाण नहीं।

### 133.2 Version identity collision

Supabase migration filename convention में underscore से पहले का prefix version identity होता है। Tree में एक duplicate version prefix मिला:

| Version | File 1 | File 2 | निष्कर्ष |
|---|---|---|---|
| 20261109 | 20261109_allow_quote_approval_booking_states.sql | 20261109_electrician_inspection_quotes_and_service_only_commission.sql | दोनों का version prefix समान; अलग contents और sizes |

इसलिए 89 filenames में 88 distinct version prefixes हैं। इन दोनों files के लिए CLI parsing, migration history insertion और remote DB में applied state का प्रमाण उपलब्ध नहीं है। कोई rename, delete, timestamp change या migration-history edit नहीं किया गया।

### 133.3 Exact identical content, अलग versions

| File | Blob SHA |
|---|---|
| 20261115120001_fix_multi_profile_electrician_labour_bill_access.sql | e3bdf2624c224322a6ac4c99f2ae6e77b1be4774 |
| 20261115145900_fix_multi_profile_electrician_labour_bill_access.sql | e3bdf2624c224322a6ac4c99f2ae6e77b1be4774 |

ये दो अलग version prefixes वाली files हैं, लेकिन Git content blob एक ही है। यह duplicate version collision नहीं है; यह duplicate content है। दोनों को applied history में रखने/हटाने का निर्णय owner/DBA और Supabase migration history verification के बिना नहीं किया जाएगा।

### 133.4 Functional dependency bands — provisional, replay order नहीं

| Migration band | Source-level functional area | प्रमुख prerequisites / downstream links |
|---|---|---|
| 08–09 Nov | Rate limit, customer booking ownership, electrician identity/location, commission/wallet/Route ledger, quotes | Starter booking/profile schema, Auth, Admin helper names, identity triggers, quote constraints |
| 10–11 Nov | Complaint base, quote-column restoration, push subscription base | Booking/customer schema; push subscription base आगे push outbox की prerequisite |
| 13 Nov | Support conversations, attachments और Admin message listing | Complaint base, Storage bucket/schema, Admin helper |
| 14 Nov | Finance core, customer profile/address, rate-tier/dispatch, work timer/events, cancellation/fee/refund, KYC, Staff RBAC, webhook inbox | Booking/profile/payment baseline, Storage/Auth, finance core, support objects, Admin helper and permission model |
| 15 Nov | Refund request/recovery, manual refund, KYC activation, accounting/Route reconciliation, push outbox/ledger/health, legacy RPC retirement/hardening | Finance core, refund request/evidence, Route contract, push subscriptions, prior RPCs |
| 16 Nov | Staff helper volatility, RPC search_path patches, amount_paid restore, payout trigger | Earlier target functions and financial/payout tables |
| 17 Nov | Commission + manual payment-method bridge | Payout/commission source functions, payment-method consistency and prior reconciliation RPC |

### 133.5 Clean replay पर अभी निर्णय क्यों नहीं दिया जा सकता

1. **Baseline ambiguity:** कई शुरुआती migrations existing public tables, Auth roles, Storage objects, extensions और helper functions मानकर चलती हैं। Branch में एक authoritative clean starter schema + bootstrap recipe अभी प्रमाणित नहीं।
2. **Version collision:** 20261109 duplicate version के लिए CLI/history व्यवहार की पुष्टि नहीं।
3. **Duplicate content:** 15120001 और 15145900 का समान blob, लेकिन अलग version entries।
4. **Object definition collision:** srk_booking_labour_bills की 14125844 और 14240000 definitions का पूर्ण column/constraint parity decision बाकी।
5. **Repeated replacements:** booking accounting reconciliation, refund recovery, Admin review, dispatch, and search_path functions के final definitions को ordered signature/hash matrix में मिलाना बाकी।
6. **Branch compatibility:** PR #8 Feature Branch और Audit Branch अलग हैं; इस inventory से merge compatibility या production applied state साबित नहीं होती।

### 133.6 इस pass का सत्यापन और सीमा

- Recursive Git tree में 89/89 SQL migration paths मिले; response truncated=false था।
- Duplicate version prefix का count: 1 collision group (20261109); distinct version prefixes: 88।
- Exact identical blob group: 1 pair (15120001 और 15145900)।
- कोई migration file rename/delete/edit नहीं की गई; केवल Audit Report documentation update है।
- कोई SQL execution, PostgreSQL parser/replay, pgTAP, database query/write, CI dispatch, deployment, merge या Production action नहीं किया गया।

**स्थिति:** Source-level inventory और duplicate matrix तैयार है। इसे अभी final clean-replay approval नहीं माना जाएगा। अगला आवश्यक कदम: owner-approved baseline + duplicate-version resolution, फिर disposable local PostgreSQL/Supabase harness में full 89-file replay और pgTAP validation।

## 134. Duplicate-version body और labour-bill table parity — 17 Nov 2026

### 134.1 20261109 duplicate-version files का body comparison

दोनों files फिर से GitHub से पढ़ी गईं:

- `20261109_allow_quote_approval_booking_states.sql` — blob `ef4bf8b9b8a9a35bf3ddd94ea4614c7498fb1c6d`
- `20261109_electrician_inspection_quotes_and_service_only_commission.sql` — blob `014699d3190e45aacde4022ac7e7fa9ca4fec006`

पहली file में केवल दो booking constraints replace होते हैं:
- `service_bookings_status_check`
- `service_bookings_assignment_status_requires_electrician`

दूसरी, बड़ी file quote columns, commission trigger function, quote submit/respond/work-status RPCs, offer details RPC और grants/revokes बनाती है। इसके अंत में वही दोनों booking constraints फिर से DROP/ADD किए गए हैं, और दोनों constraint definitions पहली छोटी file से textually समान हैं।

**निष्कर्ष:** बड़ी migration के अंत में छोटी migration का constraint work दोहराया गया है। यह source-level redundancy है; पर दोनों filenames का version prefix `20261109` समान होने से migration-history identity collision भी है। केवल एक file को rename/delete करना या दूसरी को हटाना सुरक्षित रूप से तय नहीं किया जा सकता। Owner/DBA को authoritative migration version और पहले से applied history तय करनी होगी। Supabase CLI/remote history पर कोई परीक्षण नहीं हुआ।

### 134.2 srk_booking_labour_bills table definitions की parity

इन दोनों files के `CREATE TABLE IF NOT EXISTS public.srk_booking_labour_bills` blocks को अलग-अलग पढ़कर तुलना की गई:

- `20261114125844_restore_financial_audit_core_schema.sql` — blob `bdfdfcc01366a9d4a298b2107c53f1525b326bf9`
- `20261114240000_server_authoritative_customer_approved_work_timer.sql` — blob `e84e2e0124b90b526d07f305bc9bf1e2eb6f0ebe`

दोनों table definitions में columns, data types, defaults, NOT NULL constraints, primary key, foreign keys, CHECK expressions और table-level consistency check एक समान हैं। दोनों में:
- `booking_id` primary key है;
- customer और electrician profile foreign keys हैं;
- category तथा approved rate tier allow-lists समान हैं;
- rate card, rate8h, elapsed time, billable minutes, paise amount और decimal amount fields समान हैं;
- `labour_amount = labour_amount_paise / 100.0` check समान है।

**निष्कर्ष:** इस जोड़ी में table-definition drift का source-level प्रमाण नहीं मिला। पहले migration में table बन जाने पर दूसरे का `IF NOT EXISTS` उसी table को छोड़ देगा; समान definition होने के कारण यह particular duplicate create स्वयं column mismatch नहीं दिखाता। फिर भी runtime catalog/constraint parity का प्रमाण PostgreSQL replay के बिना उपलब्ध नहीं है।

### 134.3 Avatar function और customer profile/storage migration का क्रम

- `20261114180000_harden_customer_avatar_object_integrity.sql` customer profile update RPC को replace करती है और उसमें `srk_customer_profiles` तथा `storage.objects` को function body में access किया जाता है।
- `20261114201428_customer_profile_saved_addresses_private_storage.sql` बाद में customer profile table, avatar bucket और avatar storage policies बनाती है।

Function body का table access PL/pgSQL execution के समय resolve/execute होता है; केवल function definition मौजूद होने से यह साबित नहीं होता कि उससे पहले migration-time invocation हुआ। इसलिए इस source review में इसे अपने-आप clean-replay blocker घोषित नहीं किया गया। Runtime में function call केवल बाद की table/bucket migration सफल होने के बाद ही वैध होगा। कोई function call या database test नहीं किया गया।

### 134.4 सत्यापन सीमा

- ऊपर बताई गई सभी छह source files के GitHub blob SHA पढ़े गए।
- Duplicate-version body और दोनों labour-bill table definitions का static text comparison किया गया।
- कोई SQL apply, parser, PostgreSQL replay, pgTAP, database query/write, CI, deployment, merge या Production action नहीं किया गया।
- Version collision का समाधान अभी भी owner/DBA निर्णय और approved migration-history reconciliation पर निर्भर है।

## 135. RPC replacement और search_path final-definition map — 17 Nov 2026

इस pass में चुनी हुई reconciliation, refund, offer-dispatch और search_path migrations को GitHub से fetch करके function signatures और replacement targets का static map बनाया गया। यह पूरे repository का exhaustive function inventory नहीं है।

### 135.1 Booking accounting reconciliation RPC — एक signature, चार definitions

एक ही signature बार-बार replace होती है:

`public.srk_admin_get_booking_accounting_reconciliation(uuid) RETURNS jsonb`

| क्रम | Migration | Blob SHA | Source-level भूमिका |
|---|---|---|---|
| 1 | 20261115150000_admin_readonly_booking_accounting_reconciliation.sql | 07b7c3a0eefe6388410712af033fd6dc6f4a7581 | पहला read-only accounting reconciliation body |
| 2 | 20261115170000_admin_route_transfer_accounting_reconciliation.sql | 9238fde16407710c208cc3d2156526c361cf4aea | Route ledger retired मानकर zero-valued Route response fields |
| 3 | 20261115180000_admin_route_recipient_and_settlement_validation.sql | 58042f828aeb1a951b36191d68a0573cdc15fcc0 | Route recipient/provider-settlement validation contract वाला replacement |
| 4 | 20261117010000_reconcile_booking_commission_and_manual_payment_method.sql | 68189051090a51bef26a98997caf103b62ed070c | अंतिम Audit Branch source replacement; commission/payment-method consistency bridge के साथ |

**मुख्य dependency:** 17010000 का body ही इस migration chain के अंत में इस signature की अंतिम source definition है। 15170000/15180000 की Route fields और provider evidence semantics को 17010000 के JSON output के साथ line-by-line reconcile करना आवश्यक है। केवल function name समान होना behavioral compatibility का प्रमाण नहीं। Feature Branch से कोई body copy नहीं किया गया।

### 135.2 Razorpay refund recovery replacement chain

| Signature | Definition / replacement | Blob SHA |
|---|---|---|
| `srk_service_finalize_razorpay_refund_from_recovery_evidence(uuid)` | 15120000 durable evidence initial implementation | adf83de704725e791a096462eaa385b28f92c7a7 |
| वही | 15240000 full-amount verification replacement | 40ebd534cf4209e98adc8c1f44b53b9ebfc09920 |
| वही | 16210000 payout lifecycle / finalizer replacement | b12da77471d510b55f798bd089597d866d79a133 |
| `srk_service_reconcile_booking_refund(uuid,text,text,text)` | 15250000 provider reconcile full-amount replacement | 3bda81c2b827f597f639846d33967a7c88296e21 |

- 15120000 durable provider evidence table और record/finalize RPC बनाती है।
- 15240000 finalizer को केवल processed provider evidence और full verified collection amount के लिए harden करती है।
- 16210000 finalizer को फिर replace करती है और payout lifecycle integration जोड़ती है; इसलिए final body की acceptance criteria में 15240000 का full-amount guard सुरक्षित रहना चाहिए। इस pass में complete semantic equivalence का प्रमाण नहीं दिया जा रहा; dedicated body diff और test आवश्यक है।
- 15250000 provider reconciliation boundary पर full-collection equality enforce करती है।
- कोई provider call या refund operation नहीं किया गया।

### 135.3 Offer dispatch replacement

| Signature | Migration | Blob SHA | भूमिका |
|---|---|---|---|
| `private.srk_dispatch_next_booking_offer(uuid)` | 14210000_sequential_nearest_offer_dispatch.sql | e56bee06fa8e4684e93cdb33938458ea4a7ed462 | Initial sequential nearest-first dispatch |
| वही | 14230000_recheck_electrician_current_area_before_offer.sql | 19a380e5a0e0b21c23d166d79ade8fa64f6694f7 | Dispatch time पर candidate का current area दोबारा verify |

इस replacement में latest definition को dispatch से पहले electrician की वर्तमान operating area re-check करनी है। अन्य offer RPCs जैसे `srk_respond_to_offer` और `srk_expire_and_advance_booking_offers` initial dispatch migration में define हैं; इस pass में उनके बाद के replacements नहीं मिले।

### 135.4 Search-path hardening chain — exact targets

| Migration | Functions / targets | Blob SHA |
|---|---|---|
| 15200000_harden_financial_admin_rpc_search_path | `srk_admin_mark_electrician_payout_paid(uuid,text,text,text)`, `srk_admin_record_manual_refund(uuid,text,text)`, `srk_create_electrician_payable()` → empty path | 7b712106ae0d22dcb0ca4f2ab0105a519a279c64 |
| 15210001_harden_legacy_financial_read_rpc_search_paths | `srk_admin_commission_report()`, `srk_get_my_wallet_summary()`, `srk_admin_wallet_overview()` → `pg_catalog,public,auth,pg_temp` | 103bdeb80f0c2f1cf4a726bbfaa42ff5f94efd9f |
| 16110000_pin_legacy_financial_read_rpc_search_paths | वही तीन read RPCs → empty path | b8749c54c969f718a7038cbbc373a09ceed0145b |
| 16120000_pin_customer_call_contact_rpc_search_paths | private implementation और public wrapper → empty path | dd5d07f9f27c18207812f637b9f3522ecb9b8061 |
| 16130000_pin_wallet_and_receipt_rpc_search_paths | wallet summary, Admin wallet overview, `srk_get_my_earnings()`, customer receipt RPC → empty path | 59aa084dfb884823a891a88ed257054838b58fee |
| 16140000_pin_electrician_offer_details_search_path | `srk_get_my_offer_details()` → empty path | 473296998acb72288ff0aa109f94e0d3304e4fa7 |
| 16150000_pin_admin_application_review_search_path | `srk_admin_review_application(uuid,text)` → empty path | b65e88211b835d60f83429c4ce64c72ca56ebf28 |
| 16160000_pin_quote_and_work_status_rpc_search_paths | quote submit/respond/work-status RPCs → empty path, IF EXISTS | 476946396e2feed512a9092995685fbd9ef4d789 |
| 16170000_pin_public_rate_limit_rpc_search_path | public rate-limit RPC → empty path | bc2fec111f31137015b972ced489dd0ae7299913 |

**Order note:** 15210001 तीन legacy read RPCs का search_path `pg_catalog,public,auth,pg_temp` रखता है, जबकि 16110000 वही तीन targets बाद में empty path पर pin करता है। इसलिए 16110000 का बाद में चलना अपेक्षित है; timestamp order में यह क्रम मौजूद है। यह intentional hardening progression हो सकती है, पर final catalog setting PostgreSQL replay/catalog inspection से ही प्रमाणित होगी।

### 135.5 अभी शेष semantic checks

1. 17010000 accounting RPC output में 15180000 के Route recipient/provider evidence fields बचते हैं या नहीं — exact JSON-key/body diff।
2. 16210000 finalizer replacement में 15240000 के सभी full-amount guards और lock-order checks सुरक्षित हैं या नहीं — complete function-body diff।
3. Repeated Admin application review, offer details, wallet/receipt and quote/work functions के original definitions और exact replacement chronology की full chain।
4. हर `ALTER FUNCTION ... SET search_path` target के लिए सुनिश्चित करना कि function signature उससे पहले बन चुकी है; विशेषकर 16150000 का Admin application review target।
5. Disposable PostgreSQL replay में final `pg_proc.proconfig`, function signatures, grants और trigger bindings verify करना।

### 135.6 सीमा

यह source-level signature/replacement map है, runtime proof नहीं। PostgreSQL parser/replay, pgTAP, live catalog query, provider calls, SQL writes, CI, deployment, merge और Production action नहीं किए गए।

## 136. Accounting JSON contract और Refund Finalizer guard preservation — 17 Nov 2026

### 136.1 Accounting RPC: Route JSON keys final bridge में हट गए

तुलना की गई definitions:

- 15180000 Route recipient/settlement validation body — blob `58042f828aeb1a951b36191d68a0573cdc15fcc0`
- 17010000 final Audit Branch accounting/commission bridge — blob `68189051090a51bef26a98997caf103b62ed070c`

15180000 की `jsonb_build_object` response में ये Route keys मौजूद हैं:
- `route_transfer_count`
- `route_electrician_transfer_paise`
- `route_platform_commission_transfer_paise`
- `route_transfers`
- `route_provider_settlement_verified`
- `route_settlement_evidence_status`

15180000 स्पष्ट रूप से कहता है कि Route ledger retired है; इसलिए transfer values zero/empty रहें और provider settlement verified false रहे। यानी ये fields API compatibility के लिए थे, provider settlement का प्रमाण नहीं।

17010000 की final `jsonb_build_object` response में ऊपर की कोई Route key नहीं मिली। यह केवल comment/formatting बदलाव नहीं, बल्कि source-level JSON response shape change है। यदि Admin UI, report export या external consumer इन keys पर निर्भर है तो final migration के बाद वे fields गायब होंगे।

**Finding:** Route ledger को retired मानने और provider settlement को unverified रखने का safety meaning सही दिशा में है, लेकिन 17010000 ने पहले से मौजूद compatibility keys हटा दी हैं। Owner को तय करना होगा: keys को zero/empty/false के साथ restore किया जाए, या सभी consumers को नए contract पर migrate करके removal स्वीकार की जाए। इस audit में consumer-wide exhaustive search और runtime API test नहीं हुआ; इसलिए actual UI breakage घोषित नहीं है।

### 136.2 Refund Finalizer: 15240000 के मुख्य full-amount guards 16210000 में मौजूद हैं

तुलना की गई definitions:

- 15240000 initial full-amount hardening — blob `40ebd534cf4209e98adc8c1f44b53b9ebfc09920`
- 16210000 latest payout-trigger integration replacement — blob `b12da77471d510b55f798bd089597d866d79a133`

Latest 16210000 function body में निम्न guards अभी भी मौजूद हैं:

1. Provider evidence status `processed` होना चाहिए।
2. Evidence 15 मिनट से पुराना होने पर refresh-required error।
3. Booking row `FOR UPDATE` lock।
4. Provider evidence amount का booking `amount_paid` के पूरे amount से exact paise equality।
5. Refund row lock और payment ID, booking payment ID, amount, currency तथा existing provider refund ID consistency।
6. Payout row lock; payout पहले से `paid` हो तो fail closed।
7. Booking payment state केवल `paid` या `refunded` स्वीकार।
8. Existing blocked payout को trigger द्वारा refunded किए जाने के बाद दोबारा पढ़कर final state verify करना; न हो तो exception।

यह source-level guard-preservation evidence है। पूरे PL/pgSQL body का formal semantic equivalence या concurrent transaction behavior सिद्ध नहीं हुआ।

### 136.3 Refund payout close ownership में बदलाव

15240000 में finalizer खुद blocked payout row को `refunded` करता था और payout note लिखता था।

16210000 में finalizer उस direct update के बजाय booking payment-state update के बाद AFTER UPDATE payout trigger से close होने की अपेक्षा करता है। फिर payout row re-read करके `refunded` status जाँचता है। Trigger की predicate केवल refund-owned blocked notes/status को close करने के लिए सीमित दिखती है।

**निर्भरता:** 16210000 finalizer अब payout trigger की सही attachment, firing condition और execution order पर निर्भर है। Trigger attach होने का source मौजूद है, लेकिन PostgreSQL catalog में actual trigger binding और transaction rollback behavior replay के बिना verified नहीं।

### 136.4 अगली कार्रवाई के लिए आवश्यक acceptance tests

- Accounting RPC JSON contract: 15180000 के छह Route keys 17010000 में expected policy के अनुसार उपस्थित/अनुपस्थित हों।
- Refund full amount: कम, अधिक, exact amount; stale evidence; non-processed provider status; changed payment/refund identity।
- Payout lifecycle: no payout, blocked Razorpay payout, unrelated blocked payout, pending payout, already paid payout।
- Trigger binding: booking payment_status transition पर केवल intended refund-owned blocked payout close हो।
- Failure atomicity: trigger/finalizer error पर refund state, booking state और payout state एक transaction में rollback हों।

### 136.5 सीमा

यह GitHub source-only comparison है। कोई PostgreSQL replay, pgTAP, consumer UI test, provider call, database query/write, CI, deployment, merge या Production action नहीं किया गया।


### 136. अंतिम Accounting RPC के Route API contract और Refund Finalizer Trigger handoff — 17 Nov 2026

#### 136.1 Route reconciliation JSON compatibility

तुलना किए गए source:
- Route-aware definition: `supabase/migrations/20261115180000_admin_route_recipient_and_settlement_validation.sql`, blob `58042f828aeb1a951b36191d68a0573cdc15fcc0`.
- अंतिम Audit Branch definition: `supabase/migrations/20261117010000_reconcile_booking_commission_and_manual_payment_method.sql`, blob `68189051090a51bef26a98997caf103b62ed070c`.
- Consumer: `admin.html`, blob `4b54dbfb605e55bb086eca7f1d5be13270b78e91`.
- Existing source-contract test: `tests/admin-route-settlement-warning.test.js`, blob `66ab538e2492b97c957622ed984ce8d7a3bb43ba`.

Route-aware RPC छह keys लौटाता है:
1. `route_transfer_count`
2. `route_electrician_transfer_paise`
3. `route_platform_commission_transfer_paise`
4. `route_transfers`
5. `route_provider_settlement_verified`
6. `route_settlement_evidence_status`

अंतिम `20261117010000` RPC body में इन छह में से कोई `route_*` key नहीं है। इस कारण final function पुराने Route-aware JSON contract को पूरा नहीं करता।

Admin UI सीधे तीन keys consume करता है:
- `route_transfers` — अनुपस्थित होने पर empty array.
- `route_settlement_evidence_status` — अनुपस्थित होने पर `not_independently_verified`.
- `route_provider_settlement_verified` — केवल strict boolean `true` होने पर verified दिखाता है; अनुपस्थित होने पर false-जैसा warning state.

इसलिए inspected UI path में missing fields से गलत bank-settlement confirmation नहीं बनती; उलटे Route transfer details/amount/count उपलब्ध नहीं होंगे और warning/default state दिखेगी। Existing Node contract test Route warning copy और पुरानी Route-aware migration को जाँचता है, लेकिन अंतिम `17010000` RPC में छह keys की उपस्थिति नहीं जाँचता।

**Required correction gate:** owner को तय करना है कि final RPC में छह retired/zero/empty compatibility keys वापस जोड़ी जाएँ या Admin UI contract को स्पष्ट रूप से बदलकर Route section हटाया/सीमित किया जाए। जब तक यह तय न हो, इसे API compatibility gap मानें; provider settlement का कोई दावा न करें।

#### 136.2 Refund finalizer: direct payout write से trigger-mediated close

तुलना किए गए source:
- Full-amount finalizer: `supabase/migrations/20261115240000_harden_refund_recovery_full_amount.sql`, blob `40ebd534cf4209e98adc8c1f44b53b9ebfc09920`.
- अंतिम trigger/finalizer migration: `supabase/migrations/20261116210000_attach_electrician_payout_reconciliation_trigger.sql`, blob `b12da77471d510b55f798bd089597d866d79a133`.
- Existing pgTAP source: `supabase/tests/database/durable_razorpay_refund_recovery_evidence.test.sql`, blob `370b2c5e460d1a9abfbbe53371a48f9e68788788`.

दोनों finalizer definitions में निम्न checks बने हुए हैं:
- `service_role` enforcement और recovery evidence ID validation.
- केवल `processed` provider evidence तथा 15-minute freshness window.
- Booking row `FOR UPDATE`; पूरी booking collection के बराबर refund amount.
- Refund row `FOR UPDATE`; payment ID, amount, currency और provider refund ID matching.
- Payout row `FOR UPDATE`; पहले से paid payout पर fail-closed व्यवहार.
- पहले से processed/refunded state के लिए payout state जाँच सहित idempotent replay.
- Booking को refunded करने के बाद payout को दोबारा पढ़कर final state सत्यापित करना.

मुख्य बदलाव payout closure का तरीका है:
- पुराने `15240000` finalizer ने blocked payout को सीधे `refunded` किया और अलग payout note लिखा।
- नए `16210000` migration में `srk_create_electrician_payable()` AFTER trigger booking के `payment_status` update पर चलता है। Refund transition पर यह pending payout या केवल इन exact refund-owned blocked notes — `Razorpay refund pending`, `Manual refund processed` — को `refunded` करता है और note null करता है।
- नया recovery finalizer direct payout UPDATE नहीं करता; वह booking को refunded करता है, फिर payout को दोबारा पढ़कर `refunded` न होने पर exception उठाता है।

इस source chain में Razorpay preparation का blocked marker `Razorpay refund pending` है और trigger उसी exact marker को पहचानता है। Finalizer पहले blocked payout state माँगता है; इसलिए unrelated Admin hold को स्वतः बंद करने का रास्ता नहीं दिखता।

**Runtime caveat:** Trigger execution order, transaction rollback, concurrent refund/payout updates और वास्तविक PostgreSQL behavior अभी प्रमाणित नहीं हैं। pgTAP file में संबंधित assertions लिखे हुए हैं, पर उन्हें चलाया हुआ नहीं माना जा सकता।

#### 136.3 निष्कर्ष और अगला gate

1. Route API compatibility gap वास्तविक है; UI का वर्तमान fallback चेतावनीपूर्ण है, लेकिन Route विवरण खो सकता है।
2. Refund finalizer का payout close अब trigger-mediated है; inspected source में full-amount/provider identity/locking guards बने हुए हैं।
3. अगला सुरक्षित कदम final RPC के छह Route compatibility keys और Admin UI contract पर source-level correction proposal तथा targeted regression assertions तैयार करना है।
4. कोई SQL execution, PostgreSQL replay, pgTAP run, database query/write, provider call, CI dispatch, deployment, merge या Production परिवर्तन नहीं किया गया।


### 137. Route compatibility correction proposal और Refund Trigger regression matrix — 17 Nov 2026

यह section केवल प्रस्ताव/acceptance matrix है; production migration या test file में बदलाव नहीं किया गया।

#### 137.1 नया महत्वपूर्ण static test conflict

मौजूदा pgTAP file `supabase/tests/database/durable_razorpay_refund_recovery_evidence.test.sql` (blob `370b2c5e460d1a9abfbbe53371a48f9e68788788`) के अंत में दो assertions अंतिम `srk_admin_get_booking_accounting_reconciliation(uuid)` definition में:
- `route_transfer_count`
- `route_ledger_retired_no_route_transfers`
की उपस्थिति माँगते हैं।

लेकिन अंतिम migration `20261117010000` (blob `68189051090a51bef26a98997caf103b62ed070c`) के function body में कोई `route_*` key नहीं है। इसलिए current migration chain के final catalog पर यह pgTAP assertion अपेक्षित रूप से fail हो सकती है। यह static source contradiction है; test चलाया नहीं गया है।

इसी test में अगली assertion `route_provider_settlement_verified` और false का अस्तित्व माँगती है; वह भी अंतिम RPC definition में नहीं है। इसे केवल UI fallback से पूरा नहीं माना जा सकता, क्योंकि pgTAP सीधे `pg_get_functiondef` जाँचता है।

#### 137.2 Route API के लिए प्रस्तावित न्यूनतम सुधार

Owner की स्वीकृति के बाद अंतिम RPC JSON में स्पष्ट retired compatibility contract जोड़ने का प्रस्ताव:
- `route_transfer_count = 0`
- `route_electrician_transfer_paise = 0`
- `route_platform_commission_transfer_paise = 0`
- `route_transfers = []`
- `route_provider_settlement_verified = false`
- `route_settlement_evidence_status = 'route_ledger_retired_no_route_transfers'`

इन keys को केवल compatibility fields के रूप में लौटाया जाए। किसी internal ledger status को bank/provider settlement प्रमाण न कहा जाए। यदि owner Route section को पूरी तरह हटाना चाहता है, तो वैकल्पिक रास्ता Admin UI और pgTAP/Node contract tests को एक ही नए contract के अनुरूप संशोधित करना है। दोनों में से निर्णय आवश्यक है; अभी कोई विकल्प लागू नहीं किया गया।

#### 137.3 Targeted regression acceptance matrix — Refund Trigger

Disposable PostgreSQL में बाद में चलाए जाने वाले tests के लिए न्यूनतम cases:

1. Processed provider evidence + पूरा booking amount + blocked payout note `Razorpay refund pending` → booking refunded और payout refunded.
2. Processed evidence + पूरा amount + blocked payout note `Manual refund processed` → payout refunded.
3. Blocked payout पर unrelated Admin note → trigger payout को refunded न करे; finalizer fail closed करे.
4. Payout पहले से paid → finalizer reject करे; payout state अपरिवर्तित रहे.
5. Provider evidence status processed नहीं → finalizer reject करे.
6. Evidence 15 मिनट से पुराना → finalizer reject करे.
7. Evidence amount booking collection से कम/अधिक → finalizer reject करे.
8. Payment ID, currency या refund record identity mismatch → finalizer reject करे.
9. पहले से refunded booking + processed refund + payout refunded → idempotent replay success.
10. पहले से refunded booking + payout blocked/pending/paid या कोई असंगत state → replay reject/manual reconciliation.
11. Trigger के बाद payout row अपेक्षित state में न हो → finalizer exception; पूरी transaction rollback की पुष्टि.
12. एक ही booking पर concurrent refund finalization attempts → केवल एक consistent terminal accounting state; duplicate payout transition नहीं.

हर test में केवल exception text नहीं, transaction के बाद booking, refund, request और payout rows की persisted state भी जाँची जाए। खास तौर पर rollback case में refund/request/booking updates और trigger-side payout mutation सभी rollback होने चाहिए।

#### 137.4 Scope और execution gate

- यह acceptance matrix है, executed test report नहीं।
- Existing Node test `tests/admin-route-settlement-warning.test.js` (blob `66ab538e2492b97c957622ed984ce8d7a3bb43ba`) वर्तमान में पुरानी Route-aware migration `20261115170000` पढ़ता है; इसे अंतिम RPC contract से जोड़ने वाला test प्रस्तावित है।
- कोई test file, migration, function, trigger, RLS या grant नहीं बदला गया।
- कोई SQL execution, PostgreSQL replay, pgTAP/Node test run, database query/write, provider call, CI dispatch, deployment, merge या Production action नहीं किया गया।


### 138. pgTAP Route contract assertion की exact mismatch और Trigger scope — 17 Nov 2026

#### 138.1 pgTAP में अतिरिक्त retired-ledger marker

Section 137 में बताए छह Route compatibility keys के अतिरिक्त मौजूदा pgTAP test एक सातवें literal marker को भी final function definition में खोजता है:
- `route_ledger_retired_no_route_transfers`

Test file `supabase/tests/database/durable_razorpay_refund_recovery_evidence.test.sql`, blob `370b2c5e460d1a9abfbbe53371a48f9e68788788`, अंतिम assertions में:
- `route_transfer_count` और `route_ledger_retired_no_route_transfers` दोनों माँगता है।
- `route_provider_settlement_verified` तथा `false` भी माँगता है।

अंतिम RPC `20261117010000`, blob `68189051090a51bef26a98997caf103b62ed070c`, के पूरे `jsonb_build_object` में कोई `route_*` key नहीं है। इसलिए तीनों literal expectations source-level पर पूरी नहीं होतीं। Test plan(35) है; इस समीक्षा में assertion count/plan consistency की अलग execution-based पुष्टि नहीं की गई।

**Correction options:**
1. Final RPC में retired-ledger marker सहित सातों agreed compatibility keys जोड़ें; या
2. यदि Route API contract हटाना owner का निर्णय है, तो pgTAP assertions और Admin UI को उसी नए contract के अनुसार एक साथ बदलें।

सिर्फ `false` शब्द function में कहीं और मौजूद होना Route-specific provider-verification assertion को सही नहीं बनाता; test को exact JSON key/value contract जाँचना चाहिए।

#### 138.2 Refund payout trigger का exact event scope

Migration `20261116210000_attach_electrician_payout_reconciliation_trigger.sql`, blob `b12da77471d510b55f798bd089597d866d79a133`, में `srk_reconcile_electrician_payable` trigger:
- AFTER INSERT OR UPDATE OF `status, payment_status, assigned_electrician_id, payment_verified_at, amount_paid, quote_status, service_charge, materials_amount, commission_rate, razorpay_payment_id, selected_category` पर चलता है।
- `payment_status='refunded'` branch pending payout या exact refund-owned blocked notes को refunded करता है।
- unrelated blocked notes और paid payouts को update नहीं करता।

Trigger UPDATE list में `payment_status` शामिल है, इसलिए inspected refund finalizers का booking payment-status transition trigger event को qualify करता है। Trigger list में `payment_method` नहीं है; यह इस refund-close branch के लिए आवश्यक नहीं दिखता, लेकिन अन्य payout recalculation behavior के लिए अलग समीक्षा विषय है।

**Important scope note:** Trigger का refunded branch किसी भी qualifying booking transition पर चलता है; वह स्वयं provider evidence verify नहीं करता। Provider evidence/full-amount checks finalizer RPC में हैं। इसलिए सुरक्षा इस बात पर निर्भर है कि privileged booking refund transitions केवल उचित refund workflows से हों। RLS/RPC bypass, service-role direct writes और अन्य trusted writers का पूरा inventory इस section में नहीं किया गया।

#### 138.3 निष्कर्ष

- Route mismatch अब exact सात literal test expectations तक सीमित कर दी गई है; अभी कोई contract fix लागू नहीं है।
- Refund trigger event scope inspected finalizer update से मेल खाता है; runtime concurrency/rollback और सभी privileged writers की समीक्षा बाकी है।
- कोई SQL/test execution, migration edit, database query/write, CI dispatch, deployment, merge या Production action नहीं किया गया।


### 139. Refund transition writers और Trigger-mediated payout closure का source inventory — 17 Nov 2026

यह सीमित source inventory है: inspected migrations में मिले refund-related `service_bookings.payment_status='refunded'` writers और उनके trust gates।

#### 139.1 पहचाने गए writer paths

1. **Admin manual refund — `srk_admin_record_manual_refund(uuid,text,text)`**
   - Final definition: `20261116210000_attach_electrician_payout_reconciliation_trigger.sql`, blob `b12da77471d510b55f798bd089597d866d79a133`.
   - `auth.uid()` और `is_srk_admin()` check; verified paid booking; Razorpay/online payment rejection; customer request approved gate; manual payment record/amount match; new-category immutable labour bill + settled cancellation fee parity.
   - Payout पहले से paid हो तो reject; pending हो तो exact `Manual refund processed` hold बनाता है; blocked payout पर आगे बढ़ सकता है।
   - Booking को refunded करने के बाद payout दोबारा पढ़ता है और payout refunded न हो तो exception उठाता है। इसलिए unrelated blocked note trigger द्वारा न छूटे तो function success नहीं लौटाता; transaction rollback अपेक्षित है, पर runtime पुष्टि बाकी है।

2. **Provider refund reconciliation — `srk_service_reconcile_booking_refund(uuid,text,text,text)`**
   - Defined in `20261114290000_full_refund_cancellation_fee_and_wallet_reversal.sql`, blob `c811fe2a0ae129201ca9e99c5405bbb59e831f57`; later full-amount replacement `20261115250000_harden_refund_reconcile_full_amount.sql`, blob `3bda81c2b827f597f639846d33967a7c88296e21`.
   - `service_role` JWT gate; booking-first row lock; refund record lock; provider refund ID consistency; terminal processed/failed state replay protection.
   - Processed state पर full booking collection amount match के बाद booking refunded करता है; failed state पर केवल exact `Razorpay refund pending` hold restore करता है।
   - Final runtime grants/replacement और webhook caller chain को अलग deployment/replay verification चाहिए।

3. **Recovery evidence finalizer — `srk_service_finalize_razorpay_refund_from_recovery_evidence(uuid)`**
   - Final definition in `20261116210000`, blob `b12da77471d510b55f798bd089597d866d79a133`.
   - `service_role` gate; processed और 15-minute evidence; full amount; booking/payment/refund/currency/provider refund ID consistency; booking/refund/payout locks; paid payout rejection; idempotent replay state check.
   - Booking refunded करने के बाद AFTER trigger द्वारा payout closure verify करता है; failure पर exception.

4. **Cancellation/full-refund flows — `20261114290000`**
   - Same migration contains multiple refund-related booking state transitions, cancellation-fee/wallet reversal logic and service-side reconciliation.
   - These are additional trigger entry points, not proof that all refund sources are fully inventoried. Their caller/grant matrix must be checked against the exact final migration chain.

#### 139.2 Direct-write boundary

Migration `20261115230000_admin_booking_direct_write_closure.sql`, blob `a1c1abe91e337a22576dbc05f766806699c13dcb`, revokes authenticated direct UPDATE on selected booking financial/status columns. This supports the RPC-mediated model, but it does not by itself prove that service-role, owner, SQL maintenance, or every privileged Edge Function write path is covered.

#### 139.3 Trigger safety conclusion

- The payout trigger closes only `pending` payouts or `blocked` payouts carrying exact refund-owned notes: `Razorpay refund pending` / `Manual refund processed`.
- It deliberately leaves unrelated blocked holds and already-paid payouts untouched.
- The inspected latest manual-refund and recovery-finalizer functions both re-read payout state and raise if the trigger did not close it as refunded. The provider reconciliation path uses its own service-role status handling.
- No source evidence in this limited scan shows an ordinary authenticated client direct-write path to `payment_status='refunded'`; exhaustive repository/runtime caller proof is not claimed.

#### 139.4 Remaining gates

1. Build a complete function/grant/caller matrix for every writer in `20261114290000`, later replacements, Edge Functions and webhook routes.
2. Confirm final grants and trigger bindings after a clean disposable PostgreSQL replay.
3. Add rollback tests for unrelated blocked payout note, exact refund-owned blocked note, missing payout, already-paid payout, and concurrent transitions.
4. No SQL, pgTAP/Node test, PostgreSQL replay, database query/write, provider call, CI dispatch, deployment, merge or Production action was performed in this section.


### 140. Refund RPC Grants और deployed Netlify Caller Mapping — 17 Nov 2026

यह section Audit Branch source/config inspection पर आधारित है; deployed Netlify/Supabase configuration या live ACL catalog नहीं पढ़ा गया।

#### 140.1 Function privilege chain

| RPC | Source grant evidence | Intended caller |
|---|---|---|
| `srk_admin_prepare_razorpay_refund(uuid,text)` | `20261114290000`, lines 330–331: PUBLIC/anon revoke; authenticated execute grant | Main Admin-authenticated refund endpoint |
| `srk_admin_record_manual_refund(uuid,text,text)` | `20261114290000`, lines 407–408 और later duplicate definition lines 607–608: PUBLIC/anon revoke; authenticated execute grant | Admin UI Supabase RPC call |
| `srk_service_reconcile_booking_refund(uuid,text,text,text)` | Latest full-amount replacement `20261115250000`, lines 94–95: PUBLIC/anon/authenticated revoke; service_role execute grant | Refund endpoint + signed Razorpay webhook |
| `srk_service_record_razorpay_refund_recovery_evidence(...)` | `20261115120000`, lines 135–136: PUBLIC/anon/authenticated revoke; service_role execute grant | Refund recovery server function |
| `srk_service_finalize_razorpay_refund_from_recovery_evidence(uuid)` | `20261115120000`, lines 231–232: PUBLIC/anon/authenticated revoke; service_role execute grant | Recovery server function, separate RPC request |

The latest `20261116210000` migration replaces the manual refund and recovery finalizer function bodies but does not restate their grants. In a successful ordered replay, PostgreSQL `CREATE OR REPLACE FUNCTION` preserves the existing function object's privileges; the prior explicit ACL remains the source-level grant basis. This was not verified against a live `proacl` catalog.

#### 140.2 Actual repository call sites

- `admin.html`:
  - line 649 calls `/api/razorpay-refund`.
  - line 1000 calls `/api/razorpay-refund-status`.
  - line 1024 calls `/api/razorpay-refund-recovery`.
  - line 1045 calls `sb.rpc('srk_admin_record_manual_refund', ...)` directly.
- Root `razorpay-refund.js`, blob `afd68c6c1dd33102c40f5119616aec78e8f0ae1e`:
  - verifies Supabase Auth bearer user and Main Admin predicate before refund preparation;
  - calls the authenticated prepare RPC with the user's bearer token;
  - after provider response, calls the service-only reconcile RPC using the server's service-role default token.
- Root `razorpay-refund-recovery.js`, blob `2573aa5c6442ace359515f2227c5d93019534184`:
  - verifies bearer user and Main Admin membership;
  - reads internal refund/booking records with server credentials;
  - records evidence and finalizes in two separate service-role RPC requests.
- Root `razorpay-webhook.js`, blob `d52bfb3faca85f23c553309cf842e205f4351a8b`:
  - verifies Razorpay HMAC signature;
  - calls service-only refund reconciliation using `SUPABASE_KEY` as service credential.
- `netlify.toml` sets `functions = "netlify/functions"`; the four Netlify function files are thin wrappers requiring the corresponding root handlers. Therefore the inspected root handlers are the configured Netlify function implementations, not an unreferenced duplicate copy.

#### 140.3 Security observations and limits

1. The service-only reconciliation/finalizer/evidence RPCs are not intentionally exposed to authenticated client role in the inspected migration grants.
2. The manual refund RPC is intentionally executable by authenticated role but has its own `auth.uid()` + `is_srk_admin()` check and detailed booking/payment/request validation.
3. Refund endpoint and recovery endpoint perform Auth user validation plus Main Admin check before privileged service-role operations. Webhook uses signature validation before privileged reconciliation.
4. A service-role key in server-side environment is powerful; this source review does not establish actual secret storage, deployed function version, runtime environment, or absence of key leakage elsewhere.
5. Webhook/refund endpoints share the same service-only reconciliation RPC. Row locking and terminal-state checks are present in source, but webhook retry ordering and real concurrency remain untested.
6. This caller scan covers the identified root handlers, Netlify wrappers and Admin UI call sites; it is not a formal whole-repository proof of every possible service-role/SQL owner caller.

#### 140.4 Remaining verification

- Disposable PostgreSQL replay: inspect final `proacl`/effective EXECUTE for each RPC after all replacements.
- Confirm `is_srk_admin()` and function grants in the exact documented bootstrap + migration order.
- Review all server-side environment references and deployment settings without printing or exposing secret values.
- Run isolated tests for authenticated non-admin rejection, Main Admin acceptance, service-role-only RPC denial, webhook signature rejection, replay and concurrent refund events.

No secrets were read or printed. No live Supabase ACL, deployed Netlify configuration, provider API, SQL, test, CI, deployment, merge or Production action was executed.


### 141. Refund/Webhook Node Test Coverage Matrix और stale-source gap — 17 Nov 2026

इस section में पाँच मौजूदा Node test files का source-only review किया गया। Test execution नहीं हुआ।

#### 141.1 मौजूदा focused test coverage

| Test file | Static test count | मौजूद coverage |
|---|---:|---|
| `tests/razorpay-refund-executor.test.js` | 4 | missing login, Main Admin denial before provider call, stable idempotency key + reconciliation request, ambiguous timeout पर fail-closed |
| `tests/razorpay-refund-recovery.test.js` | 9 | bounded audit note, Main Admin gate, exact evidence, separate finalization request, finalizer failure, pending status, amount mismatch, exact record binding, pagination |
| `tests/razorpay-webhook-inbox.test.js` | 14 | HMAC invalid signature, durable event claim, duplicate/replay, active lease, refunded booking protection, processed/failed refund reconciliation, amount/identity mismatch, note/receipt binding, fenced claim |
| `tests/razorpay-refund-status.test.js` | 7 | missing session, Main Admin gate, read-only provider GET, mismatch fail-closed, booking/payment ID match, pagination |
| `tests/admin-refund-and-staff-access.test.js` | 29 | Admin refund UI, Support Staff separation, manual refund source assertions, full-amount checks, Staff authorization and search-path contracts |

इन पाँच files में कुल 63 test declarations हैं; इनमें से 34 चार focused Razorpay files में हैं। यह source में declarations की गिनती है, passing test count नहीं।

#### 141.2 Permission और caller coverage

- Refund executor test Main Admin failure पर Provider call शून्य रहने की पुष्टि करता है।
- Recovery test Main Admin failure पर Provider lookup न होने की पुष्टि करता है।
- Refund-status test भी Main Admin failure पर Provider lookup रोकता है।
- Webhook test invalid HMAC पर database call रोकता है और signed refund event को exact internal record से bind करता है।
- Webhook tests processed/failed provider event को `srk_service_reconcile_booking_refund` तक route करते हैं।
- इनमें से कोई inspected Node test वास्तविक PostgreSQL `has_function_privilege`/effective ACL catalog नहीं जाँचता। Admin test में एक static grant-text assertion है, पर वह live ACL proof नहीं है।
- Service-role Authorization header को गलत/कम privilege credential से बदलकर RPC denial का end-to-end test भी इन inspected focused tests में नहीं मिला।

#### 141.3 महत्वपूर्ण stale-source test gap

`tests/admin-refund-and-staff-access.test.js`, blob `38fc1153654a640e02205d92993f074936f9c792`, manual refund assertions के लिए यह file पढ़ता है:

`supabase/migrations/20261115130000_admin_manual_refund_request_completion.sql`

लेकिन latest manual refund function body बाद में `20261116210000_attach_electrician_payout_reconciliation_trigger.sql`, blob `b12da77471d510b55f798bd089597d866d79a133`, में replace हुआ है।

इसलिए test के manual-refund source assertions पुराने definition पर केंद्रित हैं; वे latest replacement में `auth.uid()/is_srk_admin()`, exact refund-owned payout hold, booking refunded transition और post-trigger payout reread/exception को सीधे assert नहीं करते। यह test की source-target coverage कमी है, अपने-आप में runtime defect का प्रमाण नहीं।

Recovery full-amount test भी `20261115240000` definition पढ़ता है जबकि finalizer को `20261116210000` ने replace किया है। अलग final migration comparison tests की जरूरत है, ताकि final definition पर ही security/evidence/lock/trigger invariants जाँचे जाएँ।

#### 141.4 प्रस्तावित अतिरिक्त tests — अभी केवल सुझाव

1. Latest manual refund function source test: Main Admin predicate, exact hold note, unrelated blocked note पर fail-closed, payout reread और exception.
2. Final recovery finalizer source test: 15-minute evidence freshness, processed status, full amount, identity match, row-lock order, paid payout rejection, trigger result reread.
3. Final reconcile function test: final definition और service_role-only grant; processed full amount और failed/pending status behavior.
4. ACL pgTAP: anon/authenticated denial तथा service_role execute for evidence, finalizer और reconcile RPCs; authenticated manual refund के लिए explicit gate.
5. Webhook/refund integration contract: service-role header present only in server handler; bad signature या non-admin path पर no privileged RPC; duplicate/concurrent event replay.
6. Refund trigger rollback behavior: unrelated blocked note और missing/inconsistent payout पर सभी संबंधित booking/refund/request/payout writes rollback हों।

#### 141.5 निष्कर्ष और सीमा

- Existing Node tests में मजबूत request-level checks हैं, खासकर Main Admin gate, HMAC, identity matching, idempotency और replay।
- सबसे स्पष्ट coverage gap latest SQL function replacements के विरुद्ध stale migration-file assertions हैं।
- Existing Node mocks वास्तविक Postgres grants, triggers, transaction rollback, row locks या concurrent transactions प्रमाणित नहीं करते।
- `package.json` में `test:refund`, `test:webhook` और aggregate `test` scripts मौजूद हैं; इस review में कोई script execute नहीं की गई।
- कोई test file, migration, RPC, grant, database, CI workflow, deployment या Production state बदला नहीं गया।


### 142. Latest Refund Function के लिए Test Update Blueprint — 17 Nov 2026

Section 141 के stale-source निष्कर्ष को exact test structure से cross-check किया गया। यह section केवल test-update blueprint है; executable test file नहीं बदली गई।

#### 142.1 Existing test का source selection

`tests/admin-refund-and-staff-access.test.js`, blob `38fc1153654a640e02205d92993f074936f9c792`:
- Line 12 पर `20261115130000_admin_manual_refund_request_completion.sql` को `manualRefundMigration` नाम से पढ़ता है।
- Lines 94–102 में उसी पुराने file से manual refund ledger/amount assertions करता है।
- Line 104 पर `20261115240000_harden_refund_recovery_full_amount.sql` को पढ़ता है।
- Lines 106–111 में recovery finalizer की full-amount assertions पुराने replacement file पर करता है।
- Lines 113–119 में `20261115250000_harden_refund_reconcile_full_amount.sql` से provider reconciliation और service_role grant assert करता है।

लेकिन final manual refund और final recovery finalizer bodies दोनों `20261116210000_attach_electrician_payout_reconciliation_trigger.sql`, blob `b12da77471d510b55f798bd089597d866d79a133`, में फिर से `CREATE OR REPLACE FUNCTION` किए गए हैं।

#### 142.2 Recommended minimal test refactor

एक ही latest migration source को स्पष्ट नाम से पढ़ें, जैसे `refundPayoutTriggerMigration`, और पुराने migration assertions हटाने के बजाय उन्हें historical prerequisite coverage के रूप में रखें। इसके बाद final-definition assertions अलग tests में जोड़ें:

**A. Latest Manual Refund definition**
- `auth.uid() is not null` तथा `public.is_srk_admin()` gate।
- Online/Razorpay payment path पर manual refund रोकना।
- Approved customer request / immutable labour bill / settled fee ledger की मौजूदा शर्तें final definition में भी बनी हों।
- Pending payout के लिए exact `Manual refund processed` hold।
- Booking को `payment_status='refunded'` करने के बाद payout state दोबारा पढ़ना।
- Payout refunded न होने पर exception; transaction rollback runtime test अलग।

**B. Latest Recovery Finalizer definition**
- Evidence `processed` और 15-minute freshness।
- Booking full collected amount equality।
- Refund record, booking payment ID, provider refund ID और currency identity consistency।
- Booking/refund/payout row locks और already-paid payout rejection।
- Booking refunded transition के बाद payout state reread; expected refunded state न मिलने पर exception।
- Idempotent replay branch final definition से assert हो।

**C. Trigger contract**
- Trigger event definition में `payment_status` update शामिल हो।
- Exact refund-owned blocked notes ही auto-close हों:
  `Razorpay refund pending`, `Manual refund processed`.
- Unrelated blocked note और paid payout untouched रहें।
- Trigger function की test source assertion runtime rollback का विकल्प नहीं है।

**D. Provider reconciliation final definition**
- `20261115250000` final body के full-amount check और service_role grant assertions बनाए रखें।
- Test यह भी सुनिश्चित करे कि बाद की migration इसे अनजाने में replace करके full-amount guard या grant contract न हटाए।
- अंतिम ACL की authoritative जाँच disposable PostgreSQL/pgTAP में हो, source regex में नहीं।

#### 142.3 Test design सावधानी

- Regex/static tests source contract regressions पकड़ते हैं, लेकिन SQL semantics, trigger execution, transaction rollback, lock ordering या concurrent behavior सिद्ध नहीं करते।
- Function definition extraction को exact signature के `CREATE OR REPLACE FUNCTION ... $$; ` block तक सीमित रखें; पूरे migration file में कहीं भी शब्द खोजने से unrelated function का match false positive दे सकता है।
- Migration order के अनुसार final definition चुनना जरूरी है; पुरानी migration पर passing assertion अंतिम deployed function का प्रमाण नहीं है।

#### 142.4 अनुमोदन सीमा और स्थिति

- यह blueprint है, लागू code change नहीं।
- Node tests, pgTAP, SQL parser, PostgreSQL replay या database query execute नहीं किए गए।
- कोई migration, executable test, grant, trigger, CI, deployment, merge या Production state नहीं बदली गई।


### 143. Refund Payout AFTER Trigger का Exact Transition Contract — 17 Nov 2026

Final source `supabase/migrations/20261116210000_attach_electrician_payout_reconciliation_trigger.sql`, blob `b12da77471d510b55f798bd089597d866d79a133`, को trigger और दोनों refund RPC transitions के बीच cross-check किया गया।

#### 143.1 Trigger की वास्तविक शर्तें

- Function: `public.srk_create_electrician_payable()`.
- Trigger: `srk_reconcile_electrician_payable`, `AFTER INSERT OR UPDATE OF` booking status, payment_status, electrician assignment, payment verification, amount, quote status, service/material amounts, commission rate, Razorpay payment ID और selected category.
- जब `new.payment_status='refunded'` हो:
  - उसी booking का `pending` payout `refunded` होता है।
  - `blocked` payout केवल तब `refunded` होता है जब note exact `Razorpay refund pending` या `Manual refund processed` हो।
  - बदले गए payout का note NULL किया जाता है।
  - दूसरे कारण से blocked payout untouched रहता है।
  - पहले से `paid` payout इस UPDATE predicate में शामिल नहीं है।

#### 143.2 Manual Refund और Recovery Finalizer की trigger निर्भरता

- Manual Refund पहले pending payout को `blocked / Manual refund processed` करता है, फिर booking को refunded करता है और payout को दोबारा पढ़कर refunded state की पुष्टि करता है।
- Recovery Finalizer processed provider evidence, freshness, full amount और identity checks के बाद booking को refunded करता है; trigger exact refund-owned blocked hold बंद करता है; Finalizer payout state दोबारा पढ़ता है।
- दोनों RPCs trigger के बाद स्वयं दूसरी payout transition write नहीं करते। Trigger result गलत हो तो exception उठाते हैं।
- यह design duplicate competing payout writes कम करता है; transaction rollback का वास्तविक व्यवहार अभी runtime-tested नहीं है।

#### 143.3 प्रस्तावित Trigger Regression Cases

1. Pending payout + booking refunded → payout refunded, note NULL.
2. Blocked + `Razorpay refund pending` → refunded, note NULL.
3. Blocked + `Manual refund processed` → refunded, note NULL.
4. Blocked + unrelated Admin note → blocked और note unchanged.
5. Paid payout → paid ही रहे; Refund RPC को fail-closed होना चाहिए।
6. कोई payout row न हो → booking/refund transition पर trigger कोई payout row न बनाए।
7. Manual Refund trigger के बाद payout reread में refunded न मिले → exception और पूरे transaction की rollback assertion।
8. Recovery Finalizer trigger के बाद payout reread में refunded न मिले → exception और पूरे transaction की rollback assertion।
9. एक ही refund दोबारा finalize हो → केवल exact already-refunded + processed state idempotent replay हो।
10. Refund के समय concurrent payout state change → consistent row-lock/terminal outcome; कोई paid payout refunded न बने।

#### 143.4 Static coverage gap

Reviewed `tests/admin-refund-and-staff-access.test.js` में final trigger की exact payout predicate, तीनों payout status branches, note clearing, या trigger event columns पर direct assertions नहीं मिले। मौजूदा refund Node tests mocks/source checks हैं; वे PostgreSQL trigger execution या rollback सिद्ध नहीं करते।

इसलिए Section 142 के test blueprint में अलग trigger contract test जोड़ना चाहिए, जो final migration में:
- `AFTER INSERT OR UPDATE OF payment_status` event को assert करे;
- pending तथा दो exact blocked-note conditions assert करे;
- unrelated blocked note और paid payout exclusion assert करे;
- note NULL update assert करे।

इन source assertions के बाद भी disposable PostgreSQL/pgTAP tests में persisted payout state और rollback verify करना आवश्यक है।

#### 143.5 सीमा

यह source-level contract review है। कोई Node test, pgTAP, SQL parser, PostgreSQL replay या database query execute नहीं किया गया। कोई migration, trigger, RPC, grant, executable test, CI, deployment, merge या Production state बदली नहीं गई।


### 144. Section 143 का Coverage Correction — Existing pgTAP Trigger Tests पहले से मौजूद हैं — 17 Nov 2026

Section 143 में यह कहना कि reviewed pgTAP में final trigger की payout predicate पर direct assertions नहीं मिले, अधूरा था। Audit Branch पर पहले से मौजूद `supabase/tests/database/electrician_payout_reconciliation.test.sql` इसका सीधा coverage देता है।

#### 144.1 Existing Trigger Contract Test

File blob: `88184e2e1fb386f16d6bd339556a15a5b87275d2`; घोषित pgTAP plan: `plan(34)`.

इसमें:
- Trigger function `public.srk_create_electrician_payable()` मौजूद होने और `service_bookings` पर attach होने की जाँच।
- Trigger row-level AFTER INSERT/UPDATE hook होने की जाँच।
- Refund transition branch `new.payment_status='refunded'` की जाँच।
- Pending payout को refunded करने की source assertion।
- Blocked payout को केवल दो exact notes `Razorpay refund pending` और `Manual refund processed` पर close करने की assertion।
- `and payout_note in (...)` से unrelated Admin block बचाने की assertion।
- Refund के बाद payout note NULL करने की assertion।
- Paid payout को trigger द्वारा overwrite न करने की assertion।

इसलिए Section 143 का प्रस्तावित अलग trigger source-contract test पूरी तरह नया नहीं है। इन मुख्य predicate checks का coverage पहले से मौजूद है।

#### 144.2 Existing Refund RPC pgTAP Coverage

**Manual Refund** — `supabase/tests/database/admin_manual_refund_request_completion.test.sql`, blob `99cb0eb02e667699db27951b5b26161a89b8951b`, plan 14:
- Installed function definition में Main Admin predicate।
- Booking refunded update के बाद payout reread।
- Payout refunded न होने पर fail-closed assertion।
- Authenticated-only / anon-denied privilege assertion।
- Request approval, manual payment matching और Razorpay exclusion।

**Recovery Finalizer** — `supabase/tests/database/durable_razorpay_refund_recovery_evidence.test.sql`, blob `370b2c5e460d1a9abfbbe53371a48f9e68788788`, plan 35:
- Service-role privilege / authenticated denial।
- Processed evidence और 15-minute freshness।
- Booking refunded update के बाद payout reread और refunded-state verification।
- Full booking amount, idempotent replay और recovery evidence checks।

ये Tests `pg_get_functiondef` और privilege/catalog assertions से database में मौजूद final definitions को जाँचने के लिए लिखे गए हैं। पर इस audit में इन्हें execute नहीं किया गया; इसलिए actual test pass status उपलब्ध नहीं है।

#### 144.3 अब बची हुई वास्तविक सीमाएँ

1. `electrician_payout_reconciliation.test.sql` trigger source predicate को जाँचता है, लेकिन payout rows बनाकर सभी branches के वास्तविक persisted outcomes का integration test होने का प्रमाण इस static review से नहीं मिला।
2. Manual Refund और Recovery Finalizer pgTAP tests function body में trigger के बाद reread जाँचते हैं; transaction rollback और सभी संबंधित rows की atomic rollback का runtime assertion अलग से चाहिए।
3. Trigger definition के exact `UPDATE OF` column list की complete expected equality, concurrent refund/payout mutation और trigger ordering के वास्तविक runtime behavior की पुष्टि शेष है।
4. Existing test file में plan(34) और plan(14)/plan(35) declarations हैं; यह घोषित assertions की संख्या है, passing result नहीं।
5. Node test stale migration-source issue अब भी अलग है: `tests/admin-refund-and-staff-access.test.js` पुरानी SQL files पढ़ता है। Existing pgTAP coverage उस Node test के stale source selection को अपने-आप ठीक नहीं करती।

#### 144.4 Corrected Conclusion

- Trigger source contract के लिए नया pgTAP test शून्य से बनाने की आवश्यकता सिद्ध नहीं हुई; पहले से मौजूद 34-plan payout test मुख्य conditions cover करता है।
- बेहतर अगला कदम existing pgTAP coverage को final trigger event-column contract और आवश्यक rollback/runtime cases के विरुद्ध gap-check करना है।
- Manual Refund और Recovery Finalizer के pgTAP source/privilege checks भी पहले से मौजूद हैं; उन्हें execute किए बिना pass नहीं कहा जा सकता।
- Section 143 को इस correction के साथ पढ़ें: source assertions मौजूद हैं; runtime transition/rollback/concurrency प्रमाण अभी बाकी हैं।

कोई test execute या edit नहीं किया गया। कोई SQL, migration, database, CI, deployment, merge या Production state नहीं बदली गई।


### 145. pgTAP Test Execution Path और CI Workflow Coverage — 17 Nov 2026

इस चरण में केवल Audit Branch की `package.json` और `.github/workflows/supabase-schema-ci.yml` का static review किया गया।

#### 145.1 Package Scripts

`package.json` blob: `8a559d1daf4dac6c140a168bb71cc5da914dce58`.

Scripts:
- `test:refund` → Node test runner से `tests/razorpay-refund-executor.test.js`
- `test:webhook` → Node test runner से `tests/razorpay-webhook-inbox.test.js`
- `test:customer-payment` → Node test runner से `tests/customer-payment-method-enforcement.test.js`
- `test` → `node --test tests/*.test.js`

इन scripts में Supabase CLI, PostgreSQL migration replay, pgTAP runner या `supabase/tests/database/*.test.sql` चलाने का command नहीं है। इसलिए Node `npm test` चलने पर भी 34/14/35-plan वाले pgTAP SQL files अपने-आप execute नहीं होते।

#### 145.2 Existing GitHub Workflow

Workflow blob: `8cdd128fb69227fee82b5084f8b78634f13ffcb2`.

Static configuration से:
- Workflow केवल `workflow_dispatch` से manually शुरू होता है।
- Job केवल `refs/heads/feature/platform-fee-cash-online-cycle` पर चलता है; GPT-2 Audit Branch `chore/pr8-replay-audit-20261116-v2` इस condition में शामिल नहीं है।
- यह remote `SUPABASE_DB_URL` से schema-only export लेता है और उसे isolated local Supabase में restore करता है।
- इसके बाद केवल पाँच hard-coded Feature migrations चलाता है: 20261112170000, 20261112193000, 20261112220000, 20261112230000 और 20261113090000।
- यह Audit Branch की पूरी 89-file migration chain या database pgTAP suite execute नहीं करता।
- Workflow के नाम में migration test है, लेकिन वर्तमान steps में `supabase test db` अथवा pgTAP SQL test directory चलाने वाला step नहीं दिखा।

यह workflow dispatch नहीं किया गया। इसकी remote schema-export credential या वास्तविक Production database state की जाँच नहीं की गई।

#### 145.3 निष्कर्ष और सुरक्षित अगला कदम

1. pgTAP SQL files का मौजूद होना, उनके runnable test command या successful execution का प्रमाण नहीं है।
2. वर्तमान package scripts में pgTAP execution path नहीं मिला।
3. वर्तमान workflow Audit Branch की migration replay या पूरे pgTAP suite का विकल्प नहीं है।
4. अगला engineering काम एक अलग, स्पष्ट रूप से isolated local PostgreSQL/Supabase test path प्रस्तावित करना होगा, जिसमें पूरा ordered migration replay और pgTAP tests चलें; इसे पहले review और owner approval के बाद ही बनाया/चलाया जाए।
5. जब तक वह path स्थापित और execute न हो, migration replay, SQL parser, pgTAP और runtime assertions को **Not Run / Unverified** ही रिपोर्ट किया जाए।

कोई package script, workflow, test या migration edit नहीं किया गया। कोई CI dispatch, database connection, SQL execution, deployment, merge या Production operation नहीं हुआ।


### 146. CI Workflow का Production Schema Dependency और Local-Only Replay Gap — 17 Nov 2026

इस चरण में मौजूदा `.github/workflows/supabase-schema-ci.yml` की शेष पूरी workflow steps का static review किया गया। कोई workflow dispatch या database connection नहीं किया गया।

#### 146.1 Workflow का वास्तविक Data/Schema Flow

Workflow blob: `8cdd128fb69227fee82b5084f8b78634f13ffcb2`.

क्रम इस प्रकार है:
1. GitHub Secret `SUPABASE_DB_URL` की मौजूदगी और PostgreSQL URI format जाँचा जाता है।
2. उसी remote URL पर read-only role-check SQL चलाया जाता है।
3. उसी remote URL से `public,private` schema का dump लिया जाता है।
4. Schema dump को temporary local Supabase stack में restore किया जाता है।
5. उसके बाद पाँच hard-coded Feature migrations चलती हैं।
6. Local lint और तीन object smoke checks चलते हैं; अंत में local stack stop होती है।

इससे यह स्पष्ट है कि migration execution local isolated stack में होता है, लेकिन test baseline remote database schema से लिया जाता है। अतः यह पूरी तरह Local-Only / Zero-Remote-Dependency replay नहीं है।

#### 146.2 सुरक्षा और Coverage की सीमाएँ

- Workflow की role-check query remote database से चलती है; यह स्वयं remote connection है, भले query read-only हो।
- Schema-only dump में table rows export न करने का प्रयास है; workflow dump में COPY/INSERT statements की जाँच भी करता है। इससे Production data dump होने का प्रमाण नहीं मिलता, लेकिन schema metadata और object definitions फिर भी remote source से लिए जाते हैं।
- Temporary local Supabase stack isolated है, पर उसका starting schema Production-derived है; यह blank database से पूरी migration history replay करने के बराबर नहीं है।
- Workflow केवल पाँच Feature migrations hard-code करता है; GPT-2 Audit Branch की 89-file migration chain, duplicate version-prefix resolution, bootstrap ordering और pgTAP database suite का replay नहीं करता।
- Role-check और schema-dump commands का वास्तविक व्यवहार, credential permissions, network boundary या secret value इस static audit में independently verify नहीं किए गए।
- Workflow feature branch condition पर gated है; Audit Branch के लिए यह current execution path नहीं है।

#### 146.3 सुरक्षित Engineering Recommendation

1. एक अलग Local-Only workflow/script प्रस्तावित किया जाए, जो disposable local PostgreSQL/Supabase instance से शुरू हो और किसी remote database URL या Production secret को स्वीकार न करे।
2. पहले migration inventory और duplicate timestamp/version collision का deterministic resolution plan बनाया जाए।
3. सभी migrations को निर्धारित क्रम में replay कर SQL parser/database errors capture किए जाएँ।
4. उसके बाद pgTAP database tests उसी disposable instance पर चलें।
5. CI बदलाव को review और explicit owner approval के बाद ही बनाया या dispatch किया जाए।
6. मौजूदा remote-schema workflow को अलग नाम/उद्देश्य से रखा जाए; इसे clean-room migration replay या Production-independent test प्रमाण न कहा जाए।

#### 146.4 निष्कर्ष

मौजूदा Workflow में Local Supabase execution मौजूद है, लेकिन baseline Production-derived schema है। इसलिए इसे पूरी तरह Local-Only migration replay नहीं माना जा सकता। Audit Branch की complete clean replay और pgTAP execution अभी **Not Run / Unverified** हैं।

कोई workflow, package script, migration या test file edit नहीं की गई। कोई CI dispatch, remote database query, schema export, SQL execution, deployment, merge या Production operation नहीं हुआ।


### 147. Audit Branch Migration Inventory का Fresh Reconciliation — 17 Nov 2026

इस चरण में GitHub के Audit Branch पर `supabase/migrations/` directory की पूरी current listing दोबारा पढ़ी गई। यह filename/blob inventory review है; कोई SQL migration execute नहीं हुई।

#### 147.1 वर्तमान Inventory

- कुल SQL migration files: **89**
- अलग-अलग filename version prefixes: **88**
- Duplicate version prefix: **20261109** — दो अलग filenames उसी version से शुरू होते हैं:
  - `20261109_allow_quote_approval_booking_states.sql`
  - `20261109_electrician_inspection_quotes_and_service_only_commission.sql`
- दोनों अलग migration contents हैं; इसलिए migration history में एक ही version identifier का collision मौजूद है।
- एक अन्य pair `20261115120001_fix_multi_profile_electrician_labour_bill_access.sql` और `20261115145900_fix_multi_profile_electrician_labour_bill_access.sql` का blob SHA समान है: `e3bdf2624c224322a6ac4c99f2ae6e77b1be4774`. यह duplicate content है, पर version prefix अलग है।

#### 147.2 हाल की Migration Chain की स्थिति

Current Audit Branch listing में ये अंतिम migrations मौजूद हैं:
- `20261116100000` से `20261116170000`: Staff permission volatility तथा RPC search_path hardening।
- `20261116200000_restore_service_bookings_amount_paid.sql`
- `20261116210000_attach_electrician_payout_reconciliation_trigger.sql`
- `20261117010000_reconcile_booking_commission_and_manual_payment_method.sql`

अंतिम Accounting Bridge migration Audit Branch में मौजूद है; इसे Feature Branch पर स्वतः उपलब्ध या लागू मानना गलत होगा।

#### 147.3 Replay Ordering पर प्रभाव

1. दो `20261109` migrations का समान version-prefix collision clean replay से पहले resolve करना अनिवार्य है। सिर्फ filename sorting से यह प्रमाणित नहीं होता कि Supabase migration history दोनों को अलग-अलग स्वीकार करेगी।
2. समान content वाले दो अलग-version migrations को बिना इतिहास/उद्देश्य जाँचे हटाना या consolidate करना सुरक्षित नहीं है; उनके version records अलग हो सकते हैं।
3. पहले से दर्ज bootstrap dependency (`public.is_srk_admin()`), duplicate labour-bill table definitions, Route ledger retirement/reconciliation, refund finalizer replacements और final accounting RPC replacement को dependency graph में explicit prerequisite edges के रूप में रखना होगा।
4. Migration filenames का क्रम एक प्रारंभिक ordering है, dependency proof नहीं। प्रत्येक migration के referenced tables, functions, types, policies, triggers और grants के producer/consumer संबंध की जाँच अभी आवश्यक है।
5. `supabase/config.toml` इस Audit Branch पर उपलब्ध नहीं मिला; इसलिए इस review से CLI migration discovery/configuration behavior की पुष्टि नहीं की जा सकती।

#### 147.4 निष्कर्ष

Fresh GitHub listing ने 89 files / 88 version prefixes की inventory की पुष्टि की और यह भी दिखाया कि latest accounting bridge migration chain में शामिल है। सबसे स्पष्ट replay blocker अभी भी duplicate `20261109` version prefix है। Full dependency graph और blank-database replay अभी **Not Run / Unverified** हैं।

कोई migration file, filename, package script, workflow या test edit नहीं किया गया। कोई SQL, database, CI, deployment, merge या Production operation नहीं हुआ।


### 148. Migration Dependency Graph — प्रमुख Producer/Consumer Edges — 17 Nov 2026

इस चरण में current Audit Branch migration sources की static समीक्षा के आधार पर मुख्य dependency edges लिखे गए हैं। यह पूर्ण machine-generated graph नहीं है; कोई SQL parser, migration replay या database catalog query नहीं चलाई गई।

#### 148.1 Core Booking और Quote Workflow

- Quote/state migrations `20261109_*` सीधे `public.service_bookings` को ALTER करती हैं; इसलिए `service_bookings` और उससे जुड़े booking identity columns इस chain से पहले उपलब्ध होने चाहिए।
- Quote workflow migration `20261109_electrician_inspection_quotes_and_service_only_commission.sql` अतिरिक्त रूप से `electrician_profiles`, `job_offers`, `auth.uid()` और booking columns/functions पर निर्भर है।
- अतः यह migration किसी blank PostgreSQL database पर अकेले लागू नहीं हो सकती; application base schema तथा Supabase Auth schema prerequisites हैं।

#### 148.2 Finance Base और उसके Consumers

- `20261114125844_restore_financial_audit_core_schema.sql` finance tables बनाता है, लेकिन FK के लिए पहले से `service_bookings`, `electrician_profiles` और `auth.users` चाहिए।
- यह base `srk_booking_labour_bills`, `srk_manual_payment_entries`, `srk_electrician_payouts`, `srk_admin_audit_events`, `srk_razorpay_refunds`, `srk_booking_refund_requests` और `srk_manual_refund_entries` उपलब्ध कराता है।
- `20261114190000_customer_receipt_immutable_labour_amount.sql` तथा `20261114200000_customer_payment_refund_history_rpc.sql` इस finance base के बाद आने चाहिए; base migration स्वयं इसी consumer ordering की टिप्पणी देती है।
- बाद की refund/recovery migrations को refund tables, payout table, booking/payment columns और Admin authorization helper उपलब्ध होने चाहिए।

#### 148.3 Work, Cancellation और Refund Chain

- `20261114250000` work-dispute/history relations और `20261114260000` work-start/event guard का क्रमिक consumer है।
- `20261114270000` cancellation request/decision foundation के बाद `20261114280000` cancellation fee/debt/wallet accounting तथा `20261114290000` full refund/wallet reversal chain आती है।
- Refund request/review chain: `20261115100000` → `20261115110000` → `20261115120000`; इसके बाद manual refund completion और full-amount recovery/reconcile hardening migrations आती हैं।
- यह ordering filename और source references से समर्थित है; transaction-level replay success अभी प्रमाणित नहीं है।

#### 148.4 Staff RBAC Bootstrap Dependency

- `20261114390000_admin_staff_rbac_foundation.sql` Main Admin helper `public.is_srk_admin()` को call करता है, लेकिन यह migration स्वयं helper definition का bootstrap नहीं देती।
- पूर्व audit में `COMPLETE_DATABASE_SETUP.sql` और `ADMIN_EMAIL_LOGIN_SETUP.sql` में helper definitions/ordering देखे गए थे; ये root setup scripts timestamped migration chain के बाहर हैं।
- इसलिए migration-only clean replay में helper पहले से मौजूद होने का प्रमाण नहीं है। किसी external bootstrap को documented, versioned prerequisite बनाना होगा या migration chain को self-contained करना होगा।
- इस dependency को केवल filename sorting से हल नहीं किया जा सकता।

#### 148.5 Route, Push और अंतिम Accounting Consumers

- Route ledger foundation `20261109020000` के बाद retirement `20261115092149` और बाद के Route reconciliation/settlement migrations का क्रम है; final RPC और UI contract drift अलग से unresolved है।
- Push chain: subscription base `20261111020000` → durable outbox `20261115170001` → delivery ledger `20261115180001` → health monitoring `20261115190001` → lease fencing `20261115200001`।
- अंतिम payout trigger `20261116210000` finance payout table और booking commission/payment fields पर निर्भर है।
- अंतिम Accounting Bridge `20261117010000` finance tables के साथ cancellation fee items/ledger, wallet ledger, refund request, provider refund और payout relations पर निर्भर है; यह chain के अनेक पूर्ववर्ती domains का consumer है।

#### 148.6 Replay Blockers और अगला सुरक्षित कदम

1. Duplicate `20261109` version prefix का resolution अभी भी आवश्यक है।
2. External base schema/bootstrap की exact source, order और reproducible provisioning contract अभी unresolved है।
3. Finance base की FK prerequisites और दो labour-bill definitions की catalog-level parity अभी runtime में verify नहीं हुई।
4. `is_srk_admin()` bootstrap gap को migration-only chain में स्पष्ट रूप से resolve करना होगा।
5. Route ledger retirement के बाद कौन-सा canonical Route schema/function contract रहेगा, owner decision आवश्यक है।
6. प्रत्येक migration के लिए created/altered object और referenced object की machine-readable dependency matrix बनानी होगी; उसके बाद ही deterministic clean replay plan freeze किया जा सकता है।

**निष्कर्ष:** मुख्य dependency edges पहचाने गए हैं, लेकिन यह अभी partial source-level graph है। पूर्ण 89-file dependency graph, blank-database replay और pgTAP execution **Not Run / Unverified** हैं। कोई executable file या database state नहीं बदली गई।


### 149. 89/89 Migration Files — First-Pass Object Producer/Consumer Matrix — 17 Nov 2026

Audit Branch directory से 89 SQL migration paths की inventory लेकर सभी files के source text को पढ़कर object-level first-pass scan किया गया। यह regex-assisted source inventory और पहले के line-by-line focused reviews का संयोजन है; PostgreSQL parser/catalog नहीं। इसलिए dynamic SQL, DO blocks, function-body references और overloaded signatures के लिए इसे final dependency proof न माना जाए।

#### 149.1 Canonical External Prerequisites

| Prerequisite object/domain | First observed consumers | Dependency conclusion |
|---|---|---|
| `public.service_bookings` | शुरुआती customer access, quote/state, wallet/Route, complaint, finance, work, refund और accounting migrations | Core base schema migration से पहले मौजूद होना चाहिए |
| `public.electrician_profiles` | identity, map pin, offer dispatch, quote, KYC, work, payout, RBAC-adjacent RPCs | Core base schema prerequisite |
| `public.electrician_applications` | admin application review, relocation, rate-tier and KYC review | Core base schema prerequisite |
| `public.job_offers` | offer detail, dispatch, push outbox, selected-tier guard | Core base schema prerequisite |
| `auth.users`, `auth.uid()`, `auth.sessions` | FKs, security-definer RPCs, staff session RBAC | Supabase Auth prerequisite |
| `storage.objects` / Storage buckets | avatar, support attachment and KYC object policies | Supabase Storage prerequisite |
| `public.is_srk_admin()` | staff RBAC foundation and later Admin RPCs | Timestamped migration chain में self-contained bootstrap अभी प्रमाणित नहीं |

इससे स्पष्ट है कि 89-file directory अकेले blank PostgreSQL database के लिए self-contained migration set नहीं है। Core application schema और Supabase platform objects का reproducible bootstrap contract अलग से चाहिए।

#### 149.2 Major Producer → Consumer Matrix

| Producer / migration family | Produced objects | Important consumers |
|---|---|---|
| `20261108120608` + `20261108120658` | `private` schema, public rate-limit helper and RLS | public form/rate-limited RPC paths |
| `20261109010000` | wallet accounts, wallet ledger, bank links, wallet RPCs | cancellation fee accounting, refund reversal, accounting bridge |
| `20261109020000` | Route transfer ledger | later Route reconciliation; then retirement migration `20261115092149` |
| `20261109_*` | quote columns, booking state constraints, quote/work RPCs | `20261110140000`, work timer and later search-path hardening |
| `20261110040000` | booking complaints and complaint events | support conversation, Admin reply, Staff RBAC and customer-safe projection |
| `20261111020000` | push subscriptions | durable push outbox, delivery ledger, health monitor and lease fencing |
| `20261113220000` | support messages and attachment relations/policies | `20261113230000`, Admin replies, Staff RBAC |
| `20261114125844` | finance/refund/audit tables incl. labour bills, manual payments, payouts, refunds | receipt/history, work timer, cancellation fee, refund and accounting chain |
| `20261114140000` family / `20261114390000` | Staff/RBAC relations and permission helpers | later permission volatility fix and Staff/Admin support paths |
| `20261114210000` | offer dispatch and private dispatch helpers | relocation/current-area recheck and push outbox trigger |
| `20261114240000` | work timer, labour bill guard and work lifecycle RPCs | work event history, payout creation and labour-bill access |
| `20261114250000` | work events and review RPC | `20261114260000` append-only guards/timeline |
| `20261114270000` | cancellation requests/events and decision RPC | `20261114280000` fee/debt/ledger accounting; `20261114290000` full refund reversal |
| `20261114280000` | cancellation fee debts, items and ledger | full refund reversal, manual payment/refund, final reconciliation |
| `20261114360000` | electrician payable creator and Admin payout RPC | payout trigger/reconciliation and final Accounting Bridge |
| `20261114410000` | Razorpay webhook event inbox and claim/complete RPCs | webhook handler/retry flow |
| `20261115100000` → `20261115110000` | customer refund request contract → Admin review/decision | durable provider recovery evidence and manual refund completion |
| `20261115120000` | durable Razorpay recovery audit/evidence and finalizer | `20261115240000`, `20261116210000` |
| `20261115170001` → `15180001` → `15190001` → `15200001` | push outbox → delivery ledger → health/retry → lease fencing | durable push worker lifecycle |
| `20261115150000` → `15170000` → `15180000` | successive accounting reconciliation RPC replacements | Admin UI and final `20261117010000` bridge |
| `20261116210000` | final payout trigger and refund function replacements | booking completion/refund lifecycle and final Accounting Bridge |
| `20261117010000` | final booking accounting reconciliation and report RPCs | Admin accounting read path; consumes finance, wallet, cancellation and refund ledgers |

#### 149.3 High-Risk Ordering / Replay Findings

1. **Core-schema gap:** early migrations alter/use `service_bookings`, `electrician_profiles`, `electrician_applications`, `job_offers` before any such core-table creation is visible in this 89-file inventory. A base-schema bootstrap is mandatory.
2. **Admin helper bootstrap:** Staff RBAC migration references `is_srk_admin()`; helper definition is not introduced by that migration. Root setup SQL is outside timestamped migrations, so clean replay depends on undocumented external ordering unless formalized.
3. **Duplicate version prefix:** the two `20261109` filenames remain a migration-history collision risk.
4. **Duplicate labour-bill patch:** `20261115120001` and `20261115145900` have identical blob SHA `e3bdf2624c224322a6ac4c99f2ae6e77b1be4774`; replay applies same function replacement twice under distinct versions.
5. **Labour-bill table producer overlap:** `20261114125844` and `20261114240000` both contain `CREATE TABLE IF NOT EXISTS srk_booking_labour_bills`. IF NOT EXISTS does not reconcile differing definitions; schema parity must be checked against a real catalog or exact DDL comparison.
6. **Route create/retire/consumer chain:** Route ledger is created then retired before later Route reconciliation migrations. Later RPC/UI contract and whether Route remains an active accounting domain need one owner-approved canonical decision.
7. **Function replacement chronology:** quote/work RPCs, receipt RPC, refund finalizer, payout creator and accounting reconciliation RPC are replaced in later migrations. Tests must target the final definition, not only earlier migration source.
8. **Push chain prerequisites:** delivery outbox expects push subscription and job-offer schema; delivery ledger/health/lease functions consume earlier outbox/ledger objects. The sequence is coherent at source level but has not been replayed.
9. **Final Accounting Bridge is a broad consumer:** it references manual payment, labour bill, payout, provider/manual refund, cancellation fee, wallet, refund request and booking relations. Its function body cannot be considered validated from migration ordering alone.

#### 149.4 Coverage and Limits

- Inventory count: 89 SQL files; 88 distinct version prefixes; duplicate `20261109` remains.
- The first-pass scan is not a SQL parser. It can over-report identifiers in comments/PLpgSQL variables and miss dynamic references, trigger-body calls, grants, policies, extension-provided objects and runtime-only dependencies.
- No `supabase/config.toml` was found in the branch inventory; migration runner/config behavior remains unknown.
- No SQL parser, PostgreSQL catalog inspection, clean database replay, pgTAP, CI workflow, deployment, or Production/Test database operation was run.
- No migration file was changed; this section changes only the Audit Report.

**स्थिति:** 89/89 file paths का first-pass source inventory दर्ज है। यह dependency graph का आधार है, लेकिन replay-ready sign-off नहीं। अगला कदम duplicate/version/bootstrap और duplicate DDL को owner-approved remediation list में बदलना, फिर isolated local PostgreSQL replay के लिए explicit prerequisites तय करना है।


### 150. Migration Replay Remediation Priority — Evidence-Based Triage — 17 Nov 2026

Section 149 के बाद छह high-risk items की source-level पुनःजाँच की गई। इस section का उद्देश्य बदलाव लागू करना नहीं, बल्कि clean replay से पहले blockers का क्रम और आवश्यक owner decision स्पष्ट करना है।

#### 150.1 Confirmed Source Facts

1. **Duplicate version prefix:** `20261109_allow_quote_approval_booking_states.sql` और `20261109_electrician_inspection_quotes_and_service_only_commission.sql` दोनों का migration version prefix `20261109` है। दोनों अलग-अलग बदलाव करते हैं: पहली booking status constraints बदलती है; दूसरी quote/work columns, RPCs और constraints जोड़ती है। इनमें से किसी को हटाना या rename करना सुरक्षित रूप से स्वतः तय नहीं किया जा सकता।
2. **Labour-bill table DDL parity:** `20261114125844_restore_financial_audit_core_schema.sql` और `20261114240000_server_authoritative_customer_approved_work_timer.sql` में `CREATE TABLE IF NOT EXISTS public.srk_booking_labour_bills` का पूरा extracted DDL इस source comparison में byte-for-byte समान मिला। इसलिए इस जोड़ी के table-column/constraint definition में source-level drift नहीं मिला। यह live catalog parity या पूरी migration success का प्रमाण नहीं है।
3. **Identical repeated patch:** `20261115120001_fix_multi_profile_electrician_labour_bill_access.sql` और `20261115145900_fix_multi_profile_electrician_labour_bill_access.sql` का Git blob SHA समान है: `e3bdf2624c224322a6ac4c99f2ae6e77b1be4774`. दोनों एक ही function replacement और grants दोहराते हैं। यह duplicate content है, लेकिन इनके version prefixes अलग हैं; इसे duplicate version collision न समझें।
4. **Admin helper bootstrap:** Staff RBAC migration `public.is_srk_admin()` पर निर्भर है; helper timestamped migration set में self-contained रूप से define होता नहीं दिखा। Root setup SQL से external bootstrap की निर्भरता अभी documented migration prerequisite नहीं है।
5. **External base schema:** शुरुआती migrations `service_bookings`, `electrician_profiles`, `electrician_applications`, `job_offers` और Supabase Auth/Storage objects को पहले से मौजूद मानती हैं। इन core objects का पूर्ण producer इस 89-file migration directory में नहीं मिला।
6. **Route contract:** Route ledger creation और retirement, फिर बाद के reconciliation RPC/UI consumers के बीच canonical product/schema contract अभी owner decision माँगता है।

#### 150.2 Priority Order Before Any Shared-Branch Integration

| Priority | Item | Required safe resolution | Gate |
|---|---|---|---|
| P0 | Core schema + Supabase Auth/Storage bootstrap | Versioned, reproducible prerequisite source and exact ordering documented; confirm which schema is authoritative | No blank replay until proven |
| P0 | Duplicate `20261109` version | Owner selects canonical migration history; preserve both functional changes and document any rename/version-history implications | No migration renaming without approval |
| P0 | `is_srk_admin()` bootstrap | Put helper in a deterministic prerequisite or migration before first consumer; reconcile with root setup scripts | Staff RBAC chain not replay-ready until resolved |
| P1 | Route ledger retirement/consumer contract | Product owner chooses active/retired Route accounting model; align final RPC, UI fields and tests | Do not merge conflicting Route contracts |
| P1 | Repeated labour-bill access patch | Decide whether one copy is retained or both remain as historical no-op replacements; update migration history plan consistently | Avoid silent deletion/renumbering |
| P2 | Function replacement and test target chronology | Tests must inspect final definitions, especially refund finalizer, payout trigger and accounting RPC | Static tests alone are insufficient |
| P2 | Full replay + pgTAP | Only after P0/P1 decisions, in isolated disposable local DB with prerequisites and documented runner | No shared/Production DB |

#### 150.3 Safe Next Execution Plan

- Step A: collect the authoritative base schema/bootstrap sources and list every object they provision; do not infer that a setup guide is executable or complete merely because it exists.
- Step B: ask the repository owner to approve a version-history strategy for the two `20261109` files. Preserve both bodies and their intent.
- Step C: establish the authoritative `is_srk_admin()` definition and make its provisioning order deterministic.
- Step D: obtain an explicit Route ledger lifecycle decision and reconcile SQL/UI/test contracts.
- Step E: prepare an isolated local replay checklist with exact CLI/config/version assumptions; do not execute until approved.
- Step F: run parser/replay and pgTAP only in that disposable local environment; capture complete logs and distinguish parser, replay, and behavioral-test outcomes.
- Step G: after GPT-1/GPT-2 findings are reconciled, create an integration branch from an agreed base and apply reviewed commits deliberately; do not merge divergent audit branches wholesale.

#### 150.4 Scope / Status

- Two `20261109` migration files: version-prefix collision confirmed by exact filenames.
- Labour-bill table DDL: exact source text matched in both producers.
- Repeated labour-bill access patch: identical Git blob confirmed.
- Core schema, helper bootstrap and Route contract: unresolved.
- No SQL migration was edited, renamed, removed or applied.
- No PostgreSQL instance, SQL parser, pgTAP, CI workflow, deployment, shared Test DB or Production DB was used.

**निर्णय:** अभी shared/integration branch बनाना उचित नहीं। पहले P0 decisions और reproducible bootstrap स्पष्ट हों। उसके बाद ही isolated replay, और फिर controlled integration की अनुमति पर विचार किया जाए।


### 151. External Bootstrap Sources — Consolidated Setup Reconciliation — 17 Nov 2026

Section 149 के "core schema external prerequisite" और Admin helper bootstrap को root-level setup files के विरुद्ध दोबारा जाँचा गया। इस जाँच से एक महत्वपूर्ण स्पष्टता मिलती है: prerequisites repository में मौजूद हैं, लेकिन timestamped 89-file migration chain के अंदर नहीं हैं।

#### 151.1 Confirmed Bootstrap Chain

- `SUPABASE_SCHEMA.sql` (blob `8ae88a7035bc963b244f22c6c1450c22618ec88f`) में `service_bookings`, `electrician_applications`, `electrician_profiles` और शुरुआती marketplace schema की definitions मौजूद हैं।
- `PORTAL_SCHEMA.sql` (blob `efc14aa623a3895ffb3841b7b0f226f2015f34b1`) स्पष्ट रूप से `SUPABASE_SCHEMA.sql` के बाद चलने को कहता है; यह `srk_admin_users`, Auth profile-link trigger, `srk_is_admin()`, offer RPC और `job_offers` आधारित policies/functions देता है।
- `COMPLETE_DATABASE_SETUP.sql` (blob `2b806e727f449ba18e71ad23edef805ceb2da2b5`) consolidated setup है। इसमें क्रमशः base schema, Admin/Electrician portal, secure offer details और Admin email-login compatibility sections मौजूद हैं।
- Consolidated file में `service_bookings`, `electrician_applications`, `electrician_profiles`, `job_offers`, `srk_admin_users`, `srk_is_admin()` और `is_srk_admin()` definitions मिलीं। इसलिए इस file को पूरा और सफलतापूर्वक चलाने पर source-level bootstrap मौजूद होने का आधार मिलता है।
- `ADMIN_EMAIL_LOGIN_SETUP.sql` (blob `dbd91b3f912b1e0946bffe6d249a85cc41dc81cd`) अलग compatibility patch है; यह `srk_admin_users` और operational tables पहले से मौजूद मानता है तथा `is_srk_admin()` बनाता है।
- `PORTAL_SETUP_HINDI.md` consolidated setup को एक बार चलाने और `VERCEL_DEPLOY_HINDI.md` देखने का निर्देश देता है।

#### 151.2 Corrected Interpretation

1. Core tables और helper functions repository से अनुपस्थित नहीं हैं; वे root-level setup SQL में उपलब्ध हैं।
2. समस्या यह है कि ये files `supabase/migrations/` की timestamped 89-file chain का हिस्सा नहीं हैं। इसलिए केवल उस directory को blank database पर replay करना पर्याप्त नहीं।
3. Repository documentation consolidated setup को एक बार चलाने का रास्ता देती है, लेकिन इस audit ने उस script को execute नहीं किया और न यह प्रमाणित किया कि हर existing environment ने वही exact version पहले से चलाया है।
4. Migration-only replay contract चाहिए तो base setup को versioned, deterministic prerequisite बनाना होगा या runner को explicitly documented bootstrap phase देनी होगी। Existing Production/Test database पर setup script दोबारा चलाने की सलाह इस audit से नहीं दी जा रही।
5. `srk_is_admin()` और `is_srk_admin()` दो अलग helper names हैं; consolidated setup में दोनों मौजूद हैं। Staff RBAC का consumer `is_srk_admin()` है। इनका semantic equivalence केवल नाम या समान allow-list query से assume नहीं करना चाहिए।

#### 151.3 Replay Gate Update

- External bootstrap source identified: **Yes**.
- Root consolidated setup source order inspected: **Yes, static only**.
- Actual setup execution / transaction success: **Not Run**.
- Existing database bootstrap state: **Not queried**.
- Timestamped migration chain self-contained without bootstrap: **No**.
- Safe next step: owner-approved disposable local environment में bootstrap-plus-migrations का documented sequence और compatibility review तैयार करना; किसी shared/Production DB पर प्रयोग नहीं।

**सुधार:** पहले के Sections 149–150 में "external base schema/bootstrap" को unresolved कहा गया था। अब repository source identified है; unresolved हिस्सा source की उपलब्धता नहीं, बल्कि उसका reproducible versioned replay contract और वास्तविक environment state है।


### 152. Disposable Local Replay — Prerequisite and Runbook Readiness Review — 17 Nov 2026

इस section में repository के setup guide, root bootstrap SQL, package scripts और वर्तमान schema workflow को मिलाकर देखा गया है। उद्देश्य सुरक्षित local-only replay की तैयारी है; कोई command execute नहीं की गई।

#### 152.1 Repository Evidence

- `PORTAL_SETUP_HINDI.md` कहता है कि मुख्य setup के लिए `VERCEL_DEPLOY_HINDI.md` पढ़ें और `COMPLETE_DATABASE_SETUP.sql` एक बार चलाएँ।
- `VERCEL_DEPLOY_HINDI.md` में इस consolidated SQL को Supabase SQL Editor में चलाने का निर्देश है। यह owner-operated existing project setup guide है; disposable local migration replay का runbook नहीं।
- `COMPLETE_DATABASE_SETUP.sql` अपने भीतर base schema, portal/RBAC, privacy hardening, secure offer details और Admin email-login compatibility sections समेटता है। इसके भीतर कुछ objects timestamped migrations में फिर से ALTER/replace होते हैं; इसलिए इसे migrations से पहले seed मानकर पूरी chain चलाने की compatibility अभी सिद्ध नहीं।
- `package.json` में केवल Node test scripts हैं (`test`, `test:refund`, `test:webhook`, `test:customer-payment`); कोई migration replay, pgTAP या SQL parser script नहीं।
- `supabase/config.toml` Audit Branch पर पहले की inventory में नहीं मिला। CLI project configuration, database settings, seed path और migration schema configuration स्पष्ट नहीं।
- `.github/workflows/supabase-schema-ci.yml` केवल `workflow_dispatch` पर है और केवल `feature/platform-fee-cash-online-cycle` ref पर job चलाता है। यह remote `SUPABASE_DB_URL` से schema-only export लेकर local stack में restore करता है, फिर पाँच hard-coded Feature-branch migrations चलाता है। यह Audit Branch की 89-file clean replay नहीं है; इसे dispatch नहीं किया गया।
- `README.md` साफ कहता है कि Feature schema की Main Supabase parity और isolated database tests अलग release gates हैं। इस audit ने Main/Test database को query नहीं किया।

#### 152.2 दो अलग Replay Tracks को न मिलाएँ

| Track | उद्देश्य | वर्तमान स्थिति |
|---|---|---|
| A. Bootstrap compatibility | `COMPLETE_DATABASE_SETUP.sql` से बने baseline और timestamped migrations के overlap/ordering को समझना | Static source review उपलब्ध; local execution नहीं |
| B. Migration-only clean replay | स्पष्ट base prerequisite के बाद 89 migrations को blank disposable DB पर क्रम से लागू करना | अभी blocked: base contract, duplicate version और migration runner/config अनसुलझे |
| C. Existing Main DB parity | मौजूदा Main schema और intended migration state का सुरक्षित अंतर निकालना | अलग owner-approved read-only process चाहिए; इस audit में नहीं किया |

Track A को Track B का सफल विकल्प न मानें। Existing Main DB से schema export करना भी blank-database clean replay नहीं है और remote credentials/permissions के अलग जोखिम रखता है।

#### 152.3 Local-Only Runbook — Approval से पहले आवश्यक Gates

1. Disposable isolated environment की सीमा लिखित हो: local Supabase/Docker project, throwaway volume/database, कोई remote `--linked`, `--remote`, Production/Test URL या वास्तविक secrets नहीं।
2. Supabase CLI और PostgreSQL versions pin किए जाएँ; `supabase/config.toml` तथा migration/seed configuration owner-approved हों।
3. Base schema का एक canonical starting point चुना जाए: consolidated setup SQL या versioned bootstrap migration। दोनों को बिना compatibility review के लगातार लागू न करें।
4. Bootstrap baseline और प्रत्येक migration के बीच duplicate object, constraint, trigger, policy, function signature और grant overlap की preflight सूची बने।
5. दो `20261109` version prefixes का owner-approved resolution और migration history policy तय हो।
6. `is_srk_admin()` की authoritative definition और Staff RBAC से पहले उसका provisioning सुनिश्चित हो।
7. pgTAP install/extension और test runner का reproducible तरीका तय हो; Node source tests को database tests न गिनें।
8. Replay logs में हर migration का exact filename, start/end result, error और final schema checks दर्ज हों। किसी failure पर आगे की migrations रोकें; आंशिक state को success न कहें।
9. सफल parser, successful migration replay, pgTAP assertions और application-level tests को अलग-अलग status में report करें।

#### 152.4 निषिद्ध Shortcut

- मौजूदा CI workflow को Audit Branch पर चलाने के लिए branch condition बदलना या remote secret जोड़ना इस audit की अनुमति में नहीं है।
- Production/Main या shared Test DB पर `db push`, `db reset`, SQL Editor setup script, schema export, migration apply या test execution नहीं।
- `COMPLETE_DATABASE_SETUP.sql` को किसी existing database पर दोबारा चलाने की सिफारिश नहीं; documented guide का "एक बार" निर्देश बना रहता है।
- बिना owner approval migration filenames rename/delete/reorder नहीं किए जाएँगे।

**निष्कर्ष:** Local replay की तैयारी के लिए source evidence पर्याप्त रूप से संकलित है, लेकिन अभी executable clean-replay runbook स्वीकृत/सिद्ध नहीं। सबसे पहले canonical bootstrap baseline, duplicate version strategy, CLI config और pgTAP runner तय होने चाहिए। इस section में केवल Audit Report बदली गई; कोई workflow, migration, database या secret नहीं।


### 153. Duplicate Migration Content and Version Collision — Resolution Design — 17 Nov 2026

इस section में पहले पहचाने गए दो migration anomalies की exact source files दोबारा पढ़कर तुलना की गई है। यह static GitHub source review है; migration history या PostgreSQL catalog query नहीं की गई।

#### 153.1 दो 20261109 Version Files — अलग काम, साझा prerequisite

- `20261109_allow_quote_approval_booking_states.sql` (blob `ef4bf8b9b8a9a35bf3ddd94ea4614c7498fb1c6d`) मौजूदा `public.service_bookings` पर status और assigned-electrician constraints drop/recreate करती है।
- `20261109_electrician_inspection_quotes_and_service_only_commission.sql` (blob `014699d3190e45aacde4022ac7e7fa9ca4fec006`) उसी table पर quote/work columns और constraints जोड़ती है तथा commission/quote RPC definitions बनाती है।
- दोनों files अलग SQL हैं; समान version prefix होने के कारण migration tooling/history में collision risk है। दूसरी file के functions और constraints को table तथा referenced columns/profiles के पहले से मौजूद होने की जरूरत है।
- पहले file की status constraint सूची quote workflow states को स्वीकार करती है। दूसरे file की quote RPC इन्हीं states और columns का उपयोग करती है। इसलिए केवल filename sort देखकर सुरक्षित ordering सिद्ध नहीं होती।

**Resolution design:** owner तय करे कि कौन-सा version prefix canonical होगा। उसके बाद migration history policy और clean-install sequence को disposable local database में जाँचने के लिए अलग change प्रस्तावित हो। बिना approval filename rename, timestamp change या migration-history repair नहीं।

#### 153.2 समान Blob वाली दो Labour-Bill Access Migrations

- `20261115120001_fix_multi_profile_electrician_labour_bill_access.sql` और `20261115145900_fix_multi_profile_electrician_labour_bill_access.sql` दोनों का blob SHA `e3bdf2624c224322a6ac4c99f2ae6e77b1be4774` है।
- दोनों exact same `srk_electrician_get_labour_bill(uuid)` function body तथा वही REVOKE/GRANT statements रखती हैं।
- अलग version prefixes के साथ समान SQL replay करने पर function definition और grants दोबारा लागू होंगे; पर यह duplicate file migration history में अलग entry है। इसे harmless मानने से पहले CLI history और migration runner behavior की पुष्टि जरूरी है।

**Resolution design:** दोनों entries को बिना history review के हटाएँ या rename न करें। पहले disposable database पर pinned Supabase CLI version में migration listing/history behavior का परीक्षण हो; उसके बाद owner-approved forward-only cleanup plan बने। Existing deployed databases की history को blind edit न करें।

#### 153.3 Canonical Replay Order के लिए अभी आवश्यक प्रमाण

1. Bootstrap baseline में `service_bookings`, `electrician_profiles` और quote-related prerequisites का exact schema snapshot।
2. दोनों 20261109 files के लिए migration-tool version-prefix acceptance और recorded history behavior।
3. दोनों labour-bill duplicate files के लिए migration history और idempotency result।
4. Clean disposable DB पर एक migration failure के बाद stop/rollback behavior।
5. Replay के बाद constraints, function signatures और grants का catalog-level comparison।

**स्थिति:** Source-level collision evidence confirmed; clean replay compatibility, recorded migration history और live schema state unverified। इस section में केवल Audit Report बदली गई। कोई migration, application code, database, CI workflow या shared branch नहीं बदली गई।


### 154. `is_srk_admin()` Bootstrap और Admin RBAC — Source-Level Reconciliation — 17 Nov 2026

इस section में Audit Branch पर मौजूद consolidated setup, Admin email-login setup और शुरुआती migration dependency को मिलाया गया है। यह static source review है; किसी database catalog या live Auth user state को query नहीं किया गया।

#### 154.1 Authoritative Source का अंतर

- `COMPLETE_DATABASE_SETUP.sql` में Admin portal section के अंतर्गत `public.srk_admin_users` table बनाई जाती है। इसमें `user_id` primary key है और `auth.users(id)` पर FK है।
- उसी consolidated setup में `public.is_srk_admin()` की definition भी मौजूद है। यह `srk_admin_users` में `auth.uid()` की मौजूदगी जाँचती है; function `STABLE SECURITY DEFINER` है और execute grant authenticated को दिया गया है।
- `ADMIN_EMAIL_LOGIN_SETUP.sql` table को पहले से मौजूद मानती है, RLS/self-read policy लगाती है और `is_srk_admin()` को फिर से define करती है। यह standalone blank-database bootstrap नहीं है; file header भी existing project और existing allow-list row की अपेक्षा बताता है।
- `supabase/migrations/20261109003000_secure_commission_reporting.sql` में `srk_admin_commission_report()` बनाते समय `public.is_srk_admin()` call होता है। इस migration के source में helper या `srk_admin_users` table create नहीं होती।

#### 154.2 Dependency निष्कर्ष

1. यदि clean replay केवल timestamped migration files से शुरू होता है, तो शुरुआती Admin-gated migrations को `is_srk_admin()` और `srk_admin_users` की पहले से उपलब्ध definition चाहिए। इस source review में वह prerequisite इसी migration chain के शुरुआती हिस्से में स्थापित होता हुआ नहीं मिला।
2. Repository में consolidated setup SQL मौजूद है और उसमें ये definitions हैं; इसलिए prerequisite source अनुपलब्ध नहीं है। लेकिन यह file timestamped migration chain के बाहर है और उसकी पूरी सामग्री बाद की migrations से overlap करती है।
3. `ADMIN_EMAIL_LOGIN_SETUP.sql` को migration chain का substitute नहीं मान सकते: यह existing table/row और existing project schema पर निर्भर है।
4. Staff RBAC की `srk_has_admin_permission()` व्यवस्था, Main Admin के `is_srk_admin()` path को पहले जाँचती है। इसलिए दोनों identity systems के overlap और precedence का प्रश्न अलग से बना रहता है; helper bootstrap उपलब्ध होना उस authorization design risk को हल नहीं करता।

#### 154.3 सुरक्षित समाधान प्रस्ताव

- Owner एक canonical baseline चुने: versioned bootstrap migration या documented, version-pinned baseline snapshot। दोनों setup SQL files को migrations से पहले अंधाधुंध चलाना स्वीकार्य नहीं।
- Baseline में `auth.users` reference, `srk_admin_users`, `is_srk_admin()`, required grants और policies का exact contract दर्ज हो।
- शुरुआती Admin-gated migrations की dependency manifest बने और clean disposable database पर उसी baseline से replay सत्यापित हो।
- Main Admin और Support Staff identity overlap के लिए अलग DB invariant/pgTAP design तथा owner decision आवश्यक रहे।
- Existing database में setup SQL दोबारा न चलाएँ; migration history या allow-list rows को अनुमान से न बदलें।

**स्थिति:** Helper/table definitions repository source में confirmed; migration-only bootstrap gap source-level पर confirmed; live database में helper/allow-list की मौजूदगी, migration history और Staff/Main Admin overlap unverified। इस section में केवल Audit Report बदली गई। कोई SQL, migration, Auth user, database, CI या branch integration नहीं की गई।


### 155. GPT-2 Final Migration Readiness Checklist — 17 Nov 2026

यह checklist अब तक के source-level findings को execution gates में बदलती है। इसका अर्थ यह नहीं कि replay या tests चल चुके हैं। सभी अनसुलझे runtime items को स्पष्ट रूप से blocked/unverified रखा गया है।

#### A. Source Inventory और Version Integrity

- [x] Audit Branch पर 89 SQL migration files और 88 distinct version prefixes की inventory दर्ज।
- [x] Duplicate `20261109` version prefix वाली दोनों अलग SQL files पहचानी गईं।
- [x] समान blob SHA वाली दो labour-bill access migrations पहचानी गईं।
- [ ] Owner-approved version collision strategy और migration history policy।
- [ ] Pinned Supabase CLI पर duplicate-prefix और duplicate-content behavior का disposable replay evidence।

#### B. Bootstrap और Schema Baseline

- [x] `COMPLETE_DATABASE_SETUP.sql` में base tables, `srk_admin_users` और `is_srk_admin()` definitions की पहचान।
- [x] शुरुआती Admin-gated migration में helper dependency की पहचान।
- [ ] Canonical bootstrap source तय हो: versioned baseline या documented snapshot।
- [ ] Bootstrap और timestamped migrations के overlap की object-by-object compatibility review।
- [ ] Supabase CLI/PostgreSQL version pin तथा स्पष्ट `supabase/config.toml`/seed contract।
- [ ] Blank disposable database पर bootstrap baseline का सफल निर्माण और catalog snapshot।

#### C. Dependency और Contract Gates

- [x] Booking quote/status dependency का source-level संबंध दर्ज।
- [x] Labour-bill duplicate migration pair का exact blob match दर्ज।
- [x] Refund lifecycle, Route ledger retirement/reconciliation और push outbox/ledger/lease chain की पूर्व sections में समीक्षा।
- [x] Final accounting RPC और payout/refund trigger source chronology की समीक्षा।
- [ ] प्रत्येक producer/consumer edge का complete 89-file dependency matrix और owner sign-off।
- [ ] Duplicate table/function/constraint/policy/trigger/grant definitions का catalog-level comparison।
- [ ] Route product contract तथा provider-settlement evidence का owner decision।
- [ ] Manual refund blocked-payout note preservation और final accounting JSON/UI/test contract का resolution।

#### D. Runtime Test Gates

- [ ] SQL parser सभी 89 files पर।
- [ ] सभी 89 migrations का clean replay, निर्धारित क्रम में, disposable local DB पर।
- [ ] pgTAP suite discovery, reproducible runner और actual execution।
- [ ] Main Admin बनाम Support Staff overlap/permission boundary tests।
- [ ] Refund hold, recovery finalizer, payout trigger, idempotency, rollback और concurrency tests।
- [ ] Accounting/payment ledger reconciliation tests।
- [ ] Final schema, function ACL, RLS policy और trigger catalog assertions।

#### E. Safety और Release Controls

- [x] यह GPT-2 audit Audit Branch तक सीमित रही; कोई shared branch/merge नहीं।
- [x] इस audit में Production या shared Test DB को query/modify नहीं किया गया।
- [x] CI workflow dispatch, deployment, migration apply और database reset नहीं किए गए।
- [ ] Disposable local environment की explicit owner approval और verified remote-disconnected configuration।
- [ ] GPT-1 handover के साथ findings का line-by-line reconciliation।
- [ ] दोनों audits के बाद अलग Integration Branch, conflict review और owner approval।

#### Readiness Verdict

<**Source audit:** substantial / ongoing reconciliation complete for documented areas.  
**Migration execution readiness:** BLOCKED — canonical bootstrap, duplicate version policy, pinned runner/config और complete dependency proof बाकी।  
**PostgreSQL/pgTAP runtime verification:** NOT RUN.  
**Shared integration branch:** NOT READY.  
**PR #8:** OPEN / Draft / Unmerged रखना उचित है।>

**अगला सुरक्षित चरण:** GPT-1 की final handover report के साथ इस checklist का reconciliation, फिर owner के सामने केवल शेष blockers और उनके निर्णय रखना। कोई migration, application code, database, CI workflow या shared branch इस section में नहीं बदली गई।


### 156. GPT-1 / GPT-2 Audit Reconciliation — Handover Cross-Check — 17 Nov 2026

यह reconciliation GPT-1 द्वारा साझा की गई handover report/commit list और GPT-2 की Audit Branch source findings को साथ रखती है। GPT-1 के सभी commits इस pass में स्वतंत्र रूप से fetch/verify नहीं किए गए; इसलिए GPT-1 execution outcomes को **handover-reported** कहा गया है, independently re-run नहीं।

#### 156.1 GPT-1 से प्राप्त Handover Status

- GPT-1 ने Admin Panel, Accounting, Payment History, Refund और Payout security audit अपने हिस्से में लिया।
- GPT-1 handover के अनुसार 31 SQL test files में घोषित static assertion count और संबंधित plan(N) मेल खाते हैं।
- GPT-1 handover के अनुसार Node tests, Vercel और Netlify Deploy Preview सफल रहे। इनका scope और commit mapping इस reconciliation में दोबारा execute नहीं किया गया।
- GPT-1 handover स्पष्ट करता है कि वास्तविक PostgreSQL migration replay और pgTAP execution नहीं हुए।
- GPT-1 handover में Refund/Payment ledger reconciliation, Route provider evidence, Main-vs-PR RPC drift तथा migration dependency ordering को शेष जोखिम बताया गया।

#### 156.2 दोनों Audits में मेल खाते महत्वपूर्ण Blockers

1. **Migration / runtime proof:** GPT-2 को canonical bootstrap, duplicate version policy, full dependency proof और clean PostgreSQL replay चाहिए। GPT-1 handover भी वास्तविक PostgreSQL replay/pgTAP को Not Run बताता है।
2. **Refund / payout:** GPT-2 source review में Manual Refund द्वारा पहले से blocked payout note overwrite होने का जोखिम है। GPT-1 handover भी पुराने blocked payout note को preserve करने की जरूरत बताता है।
3. **Route settlement:** GPT-2 source review में internal Route ledger rows को provider/bank settlement evidence नहीं माना गया। GPT-1 handover भी actual provider evidence के बिना settlement को verified न मानने की चेतावनी देता है।
4. **Accounting RPC parity:** GPT-2 ने final accounting RPC और UI/test के Route fields में mismatch दर्ज किया। GPT-1 handover Main Supabase और PR #8 RPC overload/deployment drift को unresolved बताता है।
5. **Release gate:** दोनों handovers से यह निष्कर्ष निकलता है कि static tests/CI success वास्तविक database replay, provider settlement या accounting reconciliation का विकल्प नहीं हैं।

#### 156.3 GPT-2 के आगे बढ़ने से पहले आवश्यक संयुक्त निर्णय

- [ ] GPT-1 के सभी handover commits और उनके branch/path mapping को GitHub पर स्वतंत्र रूप से verify करना।
- [ ] GPT-1 के Node/Vercel/Netlify results को exact commit और workflow run से map करना।
- [ ] Manual Refund payout-note preservation का एक canonical behavior तय करना।
- [ ] Route ledger का product contract और provider-settlement evidence source तय करना।
- [ ] Final accounting RPC JSON contract को Admin UI, API और pgTAP tests से एकसमान करना।
- [ ] Bootstrap + duplicate migration policy पर owner approval।
- [ ] Disposable, remote-disconnected PostgreSQL environment में replay/pgTAP के लिए अलग explicit approval।

#### 156.4 संयुक्त Readiness Verdict

**GPT-1 handover:** substantial source audit and handover-reported CI/test outcomes; runtime PostgreSQL/pgTAP not run.  
**GPT-2 audit:** substantial source-level migration/dependency review; clean replay not run.  
**Shared integration branch:** NOT READY — unresolved contracts and runtime gates remain.  
**PR #8:** OPEN / Draft / Unmerged रखना उचित है।

इस reconciliation में केवल Audit Branch की यह documentation file बदली गई। कोई source migration, application code, CI workflow, database, provider payment/refund या shared branch नहीं बदली गई।


### 157. GPT-1 Handover Commit और CI Status Cross-Check — 17 Nov 2026

इस pass में GPT-1 handover में दिए गए 11 commit SHAs को GitHub commit endpoint से जाँचा गया। 10 commits मिले; एक SHA `4638c7277c62cdf3fb23cd1899b8683775c4807d` पर GitHub ने “No commit found” लौटाया। इसलिए उस entry का सत्यापन बाकी है।

#### 157.1 मिले हुए commits और बदली हुई files

| Commit (short SHA) | GitHub commit title | मिली हुई file |
|---|---|---|
| `3adc082e` | Fix refund decision RPC parameter rename migration | `supabase/migrations/20261115110000_admin_refund_review_queue_and_decisions.sql` |
| `695ee2e6` | Test refund decision RPC parameter contract | `supabase/tests/database/admin_refund_review_queue.test.sql` |
| `75cd9ae3` | Calculate payout summaries across all records | `admin.html` |
| `689e3ea6` | Use paise precision for payout summary totals | `admin.html` |
| `03c5a6a5` | Fix payment history pgTAP assertion order | `supabase/tests/database/customer_payment_refund_history_rpc.test.sql` |
| `37d05b7d` | Close blocked electrician payout after verified refund | `supabase/migrations/20261115250000_harden_refund_reconcile_full_amount.sql` |
| `5b55e04c` | Repair blocked payout on refund replay | `supabase/migrations/20261115250000_harden_refund_reconcile_full_amount.sql` |
| `ac0d2f94` | Test payout closure on processed refund | `supabase/tests/database/refund_reconcile_full_amount_guard.test.sql` |
| `69d4d988` | Cover replay repair of processed refund payout | `supabase/tests/database/refund_reconcile_full_amount_guard.test.sql` |
| `f89a9ad0` | Restore Route settlement evidence fields in accounting RPC | `supabase/migrations/20261115180000_admin_route_recipient_and_settlement_validation.sql` |

ये commit records उन file paths और titles की पुष्टि करते हैं; इससे अपने-आप यह सिद्ध नहीं होता कि ये सभी commits वर्तमान GPT-2 Audit Branch में शामिल हैं या उनकी पूरी code behavior सही है।

#### 157.2 CI / Deploy status cross-check

- ऊपर के सभी 10 मिले commits पर GitHub combined status में **Vercel = success** और **Netlify Deploy Preview = success** मिला।
- GitHub Actions workflow-run endpoint पर Node test workflow **success** केवल इन चार जाँचे गए commits के लिए मिला: `3adc082e`, `695ee2e6`, `ac0d2f94`, `69d4d988`।
- शेष छह मिले commits के लिए इस endpoint ने Node workflow run नहीं लौटाया; इसलिए उनके लिए Node test success का दावा नहीं किया जा रहा।
- Deploy Preview / Vercel success को PostgreSQL migration replay, pgTAP execution या provider-side payment settlement का प्रमाण नहीं माना जा सकता।

#### 157.3 शेष सत्यापन

- [ ] Missing SHA `4638c7277c62cdf3fb23cd1899b8683775c4807d` का सही commit SHA GPT-1 से पुनः प्राप्त करना।
- [ ] सभी 10 मिले commits का Feature Branch / Audit Branch ancestry और current inclusion अलग से verify करना।
- [ ] GPT-1 द्वारा बताए गए 31 SQL test files के exact inventory/plan counts को स्वतंत्र रूप से पुनः जाँचना।
- [ ] PostgreSQL replay और pgTAP execution के लिए अलग disposable local test evidence प्राप्त करना।

**Cross-check verdict:** GPT-1 handover के 10/11 commit references GitHub पर मिले और उन सभी पर Vercel/Netlify statuses success हैं। Node workflow success का evidence 4/11 listed SHAs पर मिला। यह CI cross-check है, database/runtime sign-off नहीं। PR #8 OPEN / Draft / Unmerged ही रहे।


### 158. GPT-1 Commit Ancestry: Feature Branch बनाम GPT-2 Audit Branch — 17 Nov 2026

GitHub compare endpoint से Section 157 में मिले सभी 10 commits की दोनों branches के विरुद्ध ancestry जाँची गई।

#### 158.1 परिणाम

- **Feature Branch `feat/customer-login-first-dashboard-20261114`: 10/10 commits ancestry में मिले।** हर compare में merge-base ठीक वही GPT-1 commit SHA था और `ahead_by=0` रहा। इसका अर्थ है कि ये commits Feature Branch की history में शामिल हैं।
- **GPT-2 Audit Branch `chore/pr8-replay-audit-20261116-v2`: 0/10 commits ancestry में मिले।** हर compare का status `diverged` रहा; common merge base `dc8b4f723ac7ae896eeb516336dd4b28577390b5` था। इसलिए GPT-1 के commits Audit Branch में सीधे शामिल नहीं हैं।
- यह ancestry check है; समान code/content किसी अलग commit से मौजूद हो सकता है। इसे तय करने के लिए अलग file/blob-level comparison चाहिए।

#### 158.2 व्यावहारिक निष्कर्ष

1. GPT-1 का audited काम Feature Branch history पर है।
2. GPT-2 का migration/dependency report अलग Audit Branch पर है।
3. दोनों branches को सीधे merge या cherry-pick करना अभी उचित नहीं; duplicate migrations, overlapping changes और contract drift का पहले file-level reconciliation जरूरी है।
4. Missing GPT-1 SHA `4638c7277c62cdf3fb23cd1899b8683775c4807d` अभी भी verify नहीं हुआ है।

**Verification scope:** 10 known commit SHAs × 2 branches = 20 compare checks; सभी 20 सफलतापूर्वक लौटे। कोई branch बदली नहीं गई, कोई merge/cherry-pick नहीं किया गया और कोई database/CI operation नहीं हुआ।

**Verdict:** GPT-1 Feature Branch में, GPT-2 Audit Branch में। संयुक्त Integration Branch अभी HOLD पर रहे।


## 159. GPT-1 Feature Branch बनाम GPT-2 Audit Branch — File/Blob तुलना

**तुलना की तारीख:** 17 नवंबर 2026  
**Repository:** `shahrukhkhan12136-bot/Srk-electranic-`  
**Feature Branch:** `feat/customer-login-first-dashboard-20261114`  
**Audit Branch:** `chore/pr8-replay-audit-20261116-v2`

### तुलना का परिणाम

GitHub से दोनों शाखाओं की वर्तमान फाइलें अलग-अलग fetch करके Blob SHA और पूरी UTF-8 सामग्री की तुलना की गई। कुल 7 अलग-अलग paths जाँचे गए:

| File path | Feature Branch Blob SHA | Audit Branch Blob SHA | परिणाम |
|---|---|---|---|
| `supabase/migrations/20261115110000_admin_refund_review_queue_and_decisions.sql` | `2324ba93bb3a046966df01ca1023a61597727076` | `900c5e63c2628a21280f3b8bcdabf46cadb3b9ed` | अलग सामग्री |
| `supabase/tests/database/admin_refund_review_queue.test.sql` | `2bb9d1b2549b1450b39e53c84e71203b342ebc75` | `70e039ffe2347976fa970c0a7b0535e861e9fde4` | अलग सामग्री |
| `admin.html` | `6b29511a1ecfab93b5689dff23012078091e57fc` | `4b54dbfb605e55bb086eca7f1d5be13270b78e91` | अलग सामग्री |
| `supabase/tests/database/customer_payment_refund_history_rpc.test.sql` | `de1b3a072f0848c27f39ea578584562a68e48d3e` | `de1b3a072f0848c27f39ea578584562a68e48d3e` | बिल्कुल समान |
| `supabase/migrations/20261115250000_harden_refund_reconcile_full_amount.sql` | `56d300abc8495d1c5c5371d60bc0321650623db5` | `3bda81c2b827f597f639846d33967a7c88296e21` | अलग सामग्री |
| `supabase/tests/database/refund_reconcile_full_amount_guard.test.sql` | `a81dcc344db145533be6ec239d47270f30da1c6f` | `fd5b7ceb8e612b588fac1a7ade8d7035388ca2bc` | अलग सामग्री |
| `supabase/migrations/20261115180000_admin_route_recipient_and_settlement_validation.sql` | `31e04cf24d6f7f5e71d8dc28159878e01688103c` | `58042f828aeb1a951b36191d68a0573cdc15fcc0` | अलग सामग्री |

### निष्कर्ष

- 7 में से 1 फाइल दोनों शाखाओं में Blob SHA और पूरी सामग्री के स्तर पर समान है।
- 6 फाइलों में सामग्री अलग है। केवल समान path होना समान implementation का प्रमाण नहीं है।
- इस जाँच में दोनों शाखाओं पर कोई फाइल बदली नहीं गई।
- कोई cherry-pick, merge, SQL execution, database replay, CI dispatch या deployment नहीं किया गया।
- अगला सुरक्षित कदम: अलग सामग्री वाली 6 फाइलों का line-level/diff review करके यह पहचानना कि कौन-से बदलाव Feature Branch में हैं, कौन-से Audit Branch में हैं, और क्या किसी बदलाव का समकक्ष रूप पहले से मौजूद है। बिना review के किसी फाइल को overwrite या copy नहीं करना है।

**स्थिति:** Static file/blob comparison complete; semantic diff review pending; integration/merge readiness अभी स्वीकृत नहीं।


## 160. छह अलग फाइलों का Static Diff Review — महत्वपूर्ण अंतर

**तारीख:** 17 नवंबर 2026  
**तुलना:** Feature Branch `feat/customer-login-first-dashboard-20261114` बनाम Audit Branch `chore/pr8-replay-audit-20261116-v2`

### A. Refund review RPC migration और test

- Feature Branch migration में `srk_admin_decide_booking_refund_request(uuid,text,text)` को दोबारा बनाने से पहले `drop function if exists` जोड़ा गया है। टिप्पणी के अनुसार इसका उद्देश्य पुराने input parameter नाम `p_status` से नए `p_decision` नाम पर PostgreSQL replay/replace समस्या से बचना है।
- Audit Branch की उसी migration में यह अतिरिक्त DROP मौजूद नहीं है।
- Feature Branch test में RPC argument name `p_decision` के लिए अतिरिक्त assertion है; Audit Branch test में यह assertion नहीं है।
- दोनों शाखाओं के test plan और assertion संख्या अलग हैं; test execute नहीं किया गया। केवल source-level test text देखा गया है।

**Review point:** migration ordering और पुराने overload/signature की वास्तविक स्थिति को migration history के साथ जाँचना होगा; अभी DROP को लागू या हटाने का निर्णय नहीं।

### B. Refund reconciliation migration और guard test

यह सबसे महत्वपूर्ण behavioral divergence है:

- Feature Branch में payout row को booking → refund → payout lock order में lock किया गया है।
- Feature Branch processed refund पर अप्रत्याशित payout states को manual reconciliation के लिए रोकता है; केवल refund-pending blocked payout को refunded करता है और स्थायी audit note लिखता है।
- Audit Branch का संस्करण processed refund के बाद refund-owned blocked payout को pending स्थिति और `previous_payout_note` पर लौटाने वाला रास्ता रखता है।
- Feature Branch का guard test 10 assertions रखता है, जिसमें payout-state guard, payout lock और historical repair शामिल हैं। Audit Branch test में 5 assertions हैं और ये अतिरिक्त guards शामिल नहीं हैं।

**Review point:** दोनों व्यवहारों में आर्थिक/लेजर परिणाम अलग हैं। Trigger behavior, पुराने blocked payout state और refund lifecycle के साथ मिलाकर अलग से जाँचना जरूरी है। कोई भी संस्करण अभी runtime-सत्यापित नहीं है।

### C. Route recipient और settlement reconciliation migration

- Feature Branch का संस्करण `srk_route_transfers` ledger पढ़ता है और recipient, amount, payment ID, transfer status, settlement status तथा provider ID की जाँच करता है।
- Audit Branch का संस्करण बताता है कि Route ledger पहले retire हो चुका है; इसलिए response keys को खाली/zero रखता है और provider settlement का अनुमान नहीं लगाता।
- दोनों संस्करणों में यह अंतर सिर्फ formatting का नहीं, बल्कि उपलब्ध schema और evidence model का है।

**Review point:** पहले दोनों branches की migration history में `srk_route_transfers` के create/alter/retire क्रम को सत्यापित करना होगा। जब तक table lifecycle और provider evidence का स्रोत प्रमाणित न हो, Feature Branch के ledger queries को replay-safe या Audit Branch के retired-table निर्णय को अंतिम नहीं कहा जा सकता।

### D. Admin UI payout summary और Route display

- Feature Branch payout summary के लिए payout rows को 1000-row pages में पढ़कर पूरे dataset का total जोड़ता है और paise में rounding करता है।
- Audit Branch उपलब्ध `data` array से सीधे total बनाता है। यदि upstream query सीमित rows लौटाती है तो summary अधूरी हो सकती है; query limit का अलग सत्यापन बाकी है।
- Feature Branch UI Route transfer ledger details दिखाने की कोशिश करता है; Audit Branch Route ledger retired बताकर independent settlement confirmation बाकी दिखाता है।

**Review point:** UI summary की completeness upstream query/pagination पर निर्भर है। Route display को migration और वास्तविक provider evidence के साथ align करना होगा।

### E. शेष फाइलें

- `customer_payment_refund_history_rpc.test.sql` दोनों शाखाओं में बिल्कुल समान है (Section 159 में Blob SHA दर्ज है)।
- ऊपर A–D में बताए गए छह paths में से यह समान test एकमात्र समान path है; बाकी पाँच paths में source differences हैं।

### निर्णय और अगला सुरक्षित कदम

1. अभी किसी भी source file को overwrite, copy, cherry-pick या merge नहीं करना है।
2. अगली जाँच migration history पर केंद्रित होगी: Route ledger lifecycle, refund/payout trigger ordering, RPC signature history और संबंधित schema definitions।
3. उसके बाद ही source-level recommendation बनाई जाएगी।
4. कोई SQL execution, database replay, pgTAP, CI dispatch, deployment या production/shared database operation नहीं किया गया।

**स्थिति:** Static diff review दर्ज; schema-history verification pending; integration/merge readiness अभी स्वीकृत नहीं।


## 161. Migration History Gate — Route Ledger Retirement और बाद के RPC का विरोधाभास

**तारीख:** 17 नवंबर 2026  
**जाँची गई शाखाएँ:** Feature Branch और GPT-2 Audit Branch

### 1. Route ledger का migration क्रम प्रमाणित

दोनों branches में ये migrations और समान Blob SHA मिले:

| क्रम | Migration | Blob SHA | स्रोत में प्रभाव |
|---|---|---|---|
| 1 | `20261109020000_create_server_only_razorpay_route_transfer_ledger.sql` | `cc7ac608877c8fcf629c51720e8c7f1620f55f71` | `public.srk_route_transfers` बनाती है |
| 2 | `20261115092149_retire_unused_razorpay_route_transfer_ledger.sql` | `b6b0fd06c78b40a9b9fe3fdf0dae9faf16ee9bc2` | `drop table public.srk_route_transfers;` चलाती है |

Master Checklist भी Main DB का नवीनतम लागू migration version `20261115092149` बताती है और Route ledger retirement दर्ज करती है। यह दस्तावेज़ी/Repository evidence है; इस चरण में कोई DB query नहीं चलाई गई।

### 2. Feature Branch में बाद की RPC migrations फिर retired table पढ़ती हैं

- `20261115170000_admin_route_transfer_accounting_reconciliation.sql` — Feature Branch Blob `943dd52e21281e5a41e6b85332dc320d740ad4c7`; इसमें `srk_route_transfers` के कई SELECT references हैं।
- `20261115180000_admin_route_recipient_and_settlement_validation.sql` — Feature Branch Blob `31e04cf24d6f7f5e71d8dc28159878e01688103c`; इसमें भी Route ledger के SELECT references और recipient/settlement validation हैं।
- दोनों migrations की timestamp/version retirement migration `20261115092149` के बाद की है। इस क्रम में table को दोबारा बनाने वाली कोई migration इन जाँचे गए files में नहीं मिली।

### 3. Audit Branch का संस्करण

उन्हीं दोनों paths के Audit Branch versions:

- `20261115170000_admin_route_transfer_accounting_reconciliation.sql` — Blob `9238fde16407710c208cc3d2156526c361cf4aea`
- `20261115180000_admin_route_recipient_and_settlement_validation.sql` — Blob `58042f828aeb1a951b36191d68a0573cdc15fcc0`

इनमें `srk_route_transfers` का कोई reference नहीं है। Response compatibility के लिए Route fields zero/empty रखे गए हैं और retired ledger से provider settlement infer नहीं किया गया।

### 4. तकनीकी निष्कर्ष

- Migration chain में Route ledger पहले create, फिर drop है।
- Feature Branch के बाद के PL/pgSQL RPC source में उसी dropped relation को पढ़ने वाले statements मौजूद हैं। इसलिए उन RPCs के invoke होने पर missing-relation runtime failure का जोखिम है।
- PL/pgSQL statements के runtime planning/validation का वास्तविक व्यवहार इस audit में database पर execute करके नहीं जाँचा गया। अतः इसे runtime-confirmed failure नहीं, बल्कि स्पष्ट source/schema-history incompatibility माना जाए।
- Audit Branch का retired-ledger implementation migration history के साथ अधिक संगत है।

### 5. शेष dependency प्रश्न

Refund/payout chain के लिए payout base table, refund table और trigger definitions की migration provenance अभी पूरी तरह स्थापित नहीं हुई। Feature Branch के refund reconciliation में payout row locking और refund-owned blocked payout को refunded करने का logic है; Audit Branch में historical blocked payout को previous state पर लौटाने का logic है। इन दोनों में निर्णय लेने से पहले संबंधित trigger/function source और `previous_payout_note` field provenance की अलग जाँच आवश्यक है।

**अगला सुरक्षित कदम:** Feature/Audit Branch में refund/payout base schema और trigger migrations की exact source provenance खोजना; कोई migration apply या database operation नहीं करना।

**सीमा:** कोई SQL execution, migration replay, pgTAP, CI dispatch, deployment, merge या cherry-pick नहीं किया गया।


## 162. Refund/Payout Base Schema और Audit Trigger Provenance — Corrective Verification

**तारीख:** 17 नवंबर 2026  
**जाँची गई शाखाएँ:** Feature Branch और GPT-2 Audit Branch  
**Scope:** केवल GitHub source/migration inspection; कोई database operation नहीं।

### 1. Section 161 की provenance finding का सुधार

पहले की जाँच में srk_electrician_payouts, srk_manual_payment_entries और srk_admin_audit_events की CREATE provenance नहीं मिली थी। अब दोनों branches में exact migration path मिला:

- supabase/migrations/20261114125844_restore_financial_audit_core_schema.sql
- Feature Branch Blob SHA: bdfdfcc01366a9d4a298b2107c53f1525b326bf9
- GPT-2 Audit Branch Blob SHA: bdfdfcc01366a9d4a298b2107c53f1525b326bf9

दोनों branches पर पूरा file content और Blob SHA समान है। इसलिए Section 161 की यह धारणा कि इन tables की branch-side CREATE provenance अनुपस्थित है, इस migration के संदर्भ में गलत/अधूरी थी। यह migration 14 नवम्बर के क्रम में है और बाद के refund/history consumers से पहले आती है।

### 2. Base tables और मुख्य constraints

उसी migration में निम्न definitions मिलीं:

- srk_manual_payment_entries: booking FK, payment method allow-list, amount/reference checks और प्रति booking UNIQUE constraint।
- srk_electrician_payouts: booking/electrician FKs, gross/materials/commission/payable amounts, payout states pending/paid/blocked/refunded, प्रति booking UNIQUE constraint और Paid status के लिए method/reference/paid_at/paid_by अनिवार्य check।
- srk_razorpay_refunds: provider payment/refund ID format checks, INR, unique idempotency key, refund status allow-list, प्रति booking UNIQUE constraint और amount_paise = round(amount*100) check।
- srk_booking_refund_requests: customer/booking FKs, refund state allow-list, Razorpay refund record FK और प्रति booking UNIQUE constraint।
- srk_manual_refund_entries: manual payment entry FK, refund reference checks, प्रति booking तथा प्रति payment entry UNIQUE constraints।
- srk_admin_audit_events: entity/action/actor allow-lists और before/after JSON audit fields।
- srk_booking_labour_bills की एक प्रारंभिक definition भी इसी migration में है; बाद की timer migration की CREATE TABLE IF NOT EXISTS definition के साथ compatibility source में अपेक्षित रखी गई है।

### 3. previous_payout_note का source प्रमाण

srk_razorpay_refunds की CREATE TABLE definition में previous_payout_note text column स्पष्ट रूप से मौजूद है। Refund preparation function में payout की मौजूदा payout_note इस column में रखी जाती है, जब payout को refund-pending स्थिति में block किया जाता है। Reconciliation के failed path में payout अभी भी blocked और note अभी भी refund-owned marker होने पर पुराना note वापस लगाया जाता है।

इसलिए previous_payout_note केवल बाद की migration में अनुमान से उपयोग किया गया field नहीं है; इसकी base definition इसी migration में है। यह source-level finding है, किसी live database में column existence का नया प्रमाण नहीं।

### 4. Audit trigger provenance

उसी migration में दो SECURITY DEFINER trigger functions और trigger registrations मौजूद हैं:

- srk_capture_admin_audit_event(): manual payment, manual refund और electrician payout सहित allow-listed financial fields का audit event बनाता है।
- srk_capture_razorpay_refund_audit_event(): Razorpay refund ID, amount, status और provider status में बदलाव का audit event बनाता है।
- srk_audit_manual_payment_entries, srk_audit_manual_refund_entries, srk_audit_electrician_payouts और srk_audit_razorpay_refunds triggers संबंधित tables पर INSERT/UPDATE/DELETE के लिए register किए गए हैं।
- दोनों trigger functions में SET search_path='' है; direct EXECUTE को PUBLIC/anon/authenticated से revoke करके service_role को grant किया गया है।

### 5. अब भी शेष सीमाएँ

- यह migration CREATE TABLE IF NOT EXISTS का उपयोग करती है। पहले से मौजूद table का incompatible shape हो तो यह statement अपने-आप उसे migrate/repair नहीं करेगा; deployed schema parity अलग से जाँचना आवश्यक है।
- Migration की foreign keys service_bookings, electrician_profiles, auth.users और trigger function में is_srk_admin() जैसे baseline objects पर निर्भर हैं। इस migration से उन सभी foundational objects की पूरी empty-database provenance सिद्ध नहीं होती।
- 20261114290000_full_refund_cancellation_fee_and_wallet_reversal.sql दोनों branches में refund preparation/reconciliation functions में payout lock और refund-owned blocked marker का उपयोग करती है। Feature/Audit के बाद के hardening migration versions में payout state handling का अंतर अलग static review का विषय बना रहेगा; इस provenance check से कोई business behavior चुनकर लागू नहीं किया गया।
- कोई SQL execution, migration replay, pgTAP, production introspection, CI dispatch, deployment, merge या cherry-pick नहीं हुआ।

**निष्कर्ष:** Refund/payout core tables, previous_payout_note और संबंधित audit triggers की Feature Branch source provenance मिल गई और दोनों branches पर समान है। Section 161 की missing-provenance टिप्पणी को इस migration के लिए supersede किया जाए। फिर भी complete empty-database replay या live schema parity प्रमाणित नहीं है।



## 163. Refund/Payout State Transition और Trigger Ordering — Static Branch Comparison

**तारीख:** 17 नवंबर 2026  
**Scope:** Feature Branch बनाम GPT-2 Audit Branch; केवल source inspection। कोई SQL/DB execution नहीं।

### 1. दोनों branches में समान core migration

`20261114290000_full_refund_cancellation_fee_and_wallet_reversal.sql` दोनों branches में मौजूद है, लेकिन Blob SHA अलग है:

- Feature Branch: `901512e832279d51ab9278c6ea6522df2a30978c` (821 lines)
- Audit Branch: `c811fe2a0ae129201ca9e99c5405bbb59e831f57` (733 lines)

दोनों versions में refund preparation के समय booking/refund/payout rows पर locking, payout को refund-pending marker के साथ blocked करना, तथा provider reconciliation function मौजूद है। Feature version में उसी migration के भीतर संबंधित functions के अतिरिक्त/दोहराए गए definitions भी हैं; इसे केवल line count से correctness का प्रमाण न माना जाए।

### 2. सबसे बड़ा state-transition अंतर

- Feature Branch की `20261115250000_harden_refund_reconcile_full_amount.sql` (`56d300abc8495d1c5c5371d60bc0321650623db5`) verified full refund पर payout को सीधे `refunded` करती है; failed/non-final path में refund-owned blocked payout को `pending` और `previous_payout_note` पर वापस करती है।
- Audit Branch की उसी migration (`3bda81c2b827f597f639846d33967a7c88296e21`) में reconciliation payout को सीधे close नहीं करती; refund-owned marker के लिए prior payout status/note restore path है।
- दोनों branches में `20261115240000_harden_refund_recovery_full_amount.sql` समान Blob `40ebd534cf4209e98adc8c1f44b53b9ebfc09920` है। यह recovery evidence से verified processed refund के बाद payout को refunded करने की अपेक्षा करता है।

### 3. Audit Branch में नया booking-trigger lifecycle

Audit Branch में अतिरिक्त migration:

`20261116210000_attach_electrician_payout_reconciliation_trigger.sql`  
Blob: `b12da77471d510b55f798bd089597d866d79a133`

इसमें `srk_create_electrician_payable()` को `service_bookings` पर AFTER INSERT/UPDATE trigger से जोड़ा गया है। Trigger का `payment_status='refunded'` path:
- pending payout को refunded करता है;
- blocked payout को तभी refunded करता है जब `payout_note` refund-owned markers `Razorpay refund pending` या `Manual refund processed` में से हो;
- अन्य unrelated blocked holds को नहीं बदलता।

इसी Audit Branch migration में manual refund और recovery finalization functions booking को refunded करने के बाद payout row दोबारा पढ़कर trigger-produced `refunded` state verify करते हैं। इससे refund RPC और booking lifecycle trigger के बीच एक स्पष्ट single-writer pattern दिखता है।

यह migration Feature Branch में उसी path पर नहीं मिली (GitHub contents API ने उस ref/path के लिए 404 लौटाया)। अतः यह अंतर branch-specific है; इसे Feature Branch में मौजूद मानना गलत होगा।

### 4. Audit-trigger interaction

दोनों branches की समान core audit migration `20261114125844_restore_financial_audit_core_schema.sql` में payout और refund tables के AFTER INSERT/UPDATE/DELETE audit triggers registered हैं। इसलिए payout lifecycle trigger द्वारा payout update होने पर payout audit trigger भी source के अनुसार fire होना अपेक्षित है। यह source-level trigger registration का निष्कर्ष है; trigger execution order/actual audit rows को DB में चलाकर सत्यापित नहीं किया गया।

### 5. Static review verdict

- Audit Branch में booking payment-status transition payout closure का केंद्रीय स्थान है; refund RPC उसके परिणाम को verify करती है।
- Feature Branch में reconciliation migration सीधे payout state बदलती है और Audit Branch वाला booking trigger migration अनुपस्थित है। दोनों approaches को मिलाकर/चुनकर लागू करने से पहले पूरी migration chain और tests का review आवश्यक है।
- Manual refund completion migration `20261115130000_admin_manual_refund_request_completion.sql` दोनों branches में समान Blob `51f3b13adc80e117cc62f05b0e70ae795ee0f9fd` है; वह भी payout closure logic रखती है। Audit Branch के नए trigger migration में उसी function का replacement version booking trigger के बाद payout re-read/verification करता है। इसलिए migration timestamp order और final function definition महत्वपूर्ण हैं।
- यह source-level comparison है, runtime proof नहीं। कोई SQL parser, pgTAP, PostgreSQL replay, DB introspection, CI dispatch, deployment, merge या cherry-pick नहीं हुआ।

**अगला सुरक्षित कदम:** trigger migration के बाद effective RPC definitions, grants/search_path और refund state-machine tests की branch-wise तुलना; कोई DB operation नहीं।



## 164. Effective Refund RPC, Permissions और Test Coverage — Trigger Migration के बाद

**तारीख:** 17 नवंबर 2026  
**Scope:** दोनों branches की exact migration/test files का static comparison; कोई database execution नहीं।

### 1. Effective definition का क्रम

Audit Branch में `20261116210000_attach_electrician_payout_reconciliation_trigger.sql` बाद की migration है और यह तीन महत्वपूर्ण definitions दोबारा बनाती है:
- `srk_create_electrician_payable()` trigger function;
- `srk_admin_record_manual_refund(uuid,text,text)`;
- `srk_service_finalize_razorpay_refund_from_recovery_evidence(uuid)`.

इसलिए Audit Branch की अंतिम manual-refund और recovery definitions को पहले की `20261115130000` और `20261115240000` definitions से अलग पढ़ना जरूरी है। बाद की migration के manual/recovery functions booking को `refunded` करने के बाद payout दोबारा पढ़कर trigger-produced state verify करते हैं।

Feature Branch में यह trigger migration path नहीं मिला (contents API पर 404); वहाँ manual-refund function की पुरानी definition payout को स्वयं `refunded` करती है और recovery migration भी payout को स्वयं close करती है।

### 2. Reconciliation RPC का अंतर

दोनों branches की `20261115250000_harden_refund_reconcile_full_amount.sql` अलग है:

- Feature Branch Blob `56d300abc8495d1c5c5371d60bc0321650623db5`: processed refund पर payout को सीधे refunded करने, blocked payout की जाँच/repair करने और failed refund पर previous payout state लौटाने का logic रखती है।
- Audit Branch Blob `3bda81c2b827f597f639846d33967a7c88296e21`: processed result पर booking का `payment_status='refunded'` करती है; Audit Branch के बाद वाले booking trigger से payout closure अपेक्षित है। Failed result पर केवल Razorpay refund marker वाले blocked payout को pending और `previous_payout_note` पर लौटाती है।

Audit Branch के इस reconciliation RPC में booking update के बाद payout state को दोबारा पढ़कर verify करने वाला check नहीं है। यह बाद की manual/recovery functions के मुकाबले अलग fail-closed व्यवहार है। इसे runtime defect घोषित नहीं किया गया है; transaction और trigger behavior DB में execute नहीं किया गया।

### 3. Function security और grants

Static source में:
- Manual refund RPC: `SECURITY DEFINER`, fixed search_path `pg_catalog, public, auth, pg_temp`; PUBLIC/anon revoke और authenticated grant।
- Recovery finalizer: `SECURITY DEFINER`, empty search_path; PUBLIC/anon/authenticated revoke और केवल service_role grant।
- Provider reconciliation RPC: `SECURITY DEFINER`, empty search_path; PUBLIC/anon/authenticated revoke और केवल service_role grant।
- Trigger function: `SECURITY DEFINER`, search_path `pg_catalog, public, pg_temp`; इसे table trigger से invoke किया जाता है।

यह migration text में लिखे grants/guards का प्रमाण है; live database privileges या deployed `pg_proc` configuration का नहीं।

### 4. Tests में branch-wise अंतर

`refund_reconcile_full_amount_guard.test.sql`:
- Feature Branch Blob `a81dcc344db145533be6ec239d47270f30da1c6f`: `plan(10)`; direct payout closure, historical blocked payout repair और service_role-only privilege सहित assertions।
- Audit Branch Blob `fd5b7ceb8e612b588fac1a7ade8d7035388ca2bc`: `plan(5)`; RPC existence, full-amount comparison, integer-paise check, booking lock और service_role-only privilege assertions।

Audit Branch का यह test payout trigger के refund-owned blocked hold closure, unrelated blocked hold preservation, या booking update के बाद payout state की पुष्टि नहीं करता। इसीलिए trigger migration के लिए focused regression coverage अभी स्पष्ट रूप से अधूरी है।

`admin_refund_review_queue.test.sql` भी branches में अलग है: Feature `plan(17)`, Audit `plan(16)`; दोनों में authenticated-only RPC grants और empty search_path assertions मौजूद हैं। यह test trigger lifecycle को प्रमाणित नहीं करता।

### 5. निष्कर्ष / अगला सुरक्षित कदम

- Audit Branch की अंतिम manual-refund और recovery RPC definitions trigger-aware हैं।
- Audit Branch का provider reconciliation RPC trigger पर निर्भर है, लेकिन उसी RPC में payout post-condition assertion नहीं है।
- Audit Branch के refund reconciliation test में trigger-specific regression assertions अनुपस्थित हैं।
- अगला सुरक्षित कदम केवल Audit Branch पर test-source प्रस्ताव/coverage gap दर्ज करना और migration dependency ordering को static रूप से पुनः जाँचना है। कोई test चलाना, SQL बदलना, database access, CI dispatch, deployment, merge या cherry-pick नहीं हुआ।

**Verdict:** Source-level permissions स्पष्ट हैं; live grants, effective deployed definitions और trigger runtime behavior अभी अप्रमाणित हैं। Trigger regression coverage जोड़ने से पहले owner approval और test design review आवश्यक है।



## 165. Trigger Regression Test Proposal और Migration Ordering Gate

**तारीख:** 17 नवंबर 2026  
**Scope:** केवल documentation में test-design proposal; कोई SQL test file या migration बदली/चलाई नहीं गई।

### 1. प्रस्तावित Regression Test Cases

Audit Branch की `20261116210000_attach_electrician_payout_reconciliation_trigger.sql` के लिए अलग focused test file प्रस्तावित है। इसे लिखने/चलाने से पहले owner approval और fixture/schema review आवश्यक है।

| Case | Setup / Action | अपेक्षित परिणाम |
|---|---|---|
| Pending payout | booking का payment_status paid से refunded | संबंधित pending payout refunded हो |
| Refund-owned Razorpay hold | payout blocked और note `Razorpay refund pending`; booking refunded | payout refunded हो और note clear हो |
| Refund-owned manual hold | payout blocked और note `Manual refund processed`; booking refunded | payout refunded हो और note clear हो |
| Unrelated Admin hold | payout blocked लेकिन note कोई अलग Admin reason | payout blocked और note जस का तस रहे |
| Already paid payout | payout paid; booking refunded transition | paid payout अपने-आप overwrite न हो |
| Reconciliation post-condition | processed provider result से booking refunded | RPC response से पहले payout state refunded सत्यापित हो; mismatch पर fail closed |
| Failed provider result | refund failed; payout Razorpay marker के साथ blocked | previous payout status/note restore हों; unrelated hold न बदले |
| Replay/idempotency | वही processed result दोबारा | state regress न हो; final booking/payout state consistent रहे |

ये अपेक्षित behavioral assertions हैं, मौजूदा test pass होने का दावा नहीं। विशेष रूप से paid payout, concurrent settlement और transaction rollback behavior को isolated PostgreSQL test में verify करना होगा; इस चरण में कोई execution नहीं हुआ।

### 2. मौजूदा Test File में न्यूनतम अतिरिक्त Static Assertions

मौजूदा `refund_reconcile_full_amount_guard.test.sql` अभी पाँच assertions तक सीमित है। इसमें trigger function की source definition/trigger registration, refund-owned marker allowlist, unrelated blocked hold preservation, और provider reconciliation के बाद payout post-condition के लिए coverage नहीं है। केवल function text की substring जाँच behavioral proof नहीं होगी; isolated fixtures के साथ transactional behavior tests अधिक मजबूत होंगे।

### 3. Migration Ordering Gate

Audit Branch के source timestamps के अनुसार:
1. `20261115250000_harden_refund_reconcile_full_amount.sql` provider reconciliation RPC परिभाषित करती है।
2. `20261116210000_attach_electrician_payout_reconciliation_trigger.sql` बाद में trigger attach करती है और manual-refund/recovery RPCs को फिर से परिभाषित करती है।
3. इसलिए final function body migration order पर निर्भर है; पहले की RPC definitions को अंतिम effective definition नहीं मानना चाहिए।
4. Financial audit core trigger migration पहले से मौजूद है; payout table पर उसके audit triggers का registration source-level है, runtime audit event evidence नहीं।

Migration filename timestamp क्रम केवल intended ordering बताता है। वास्तविक clean replay, dependency resolution, duplicate trigger behavior और final catalog definitions अभी execute/introspect नहीं हुए।

### 4. Gate / निर्णय

- अभी केवल test proposal दस्तावेज़ीकृत है; SQL test या migration source edit नहीं।
- अगली implementation से पहले owner की स्पष्ट अनुमति, schema fixtures, expected transaction semantics और isolated disposable PostgreSQL environment आवश्यक हैं।
- तब तक कोई SQL execution, pgTAP, DB query, CI dispatch, deployment, merge या cherry-pick नहीं होगा।

**Verdict:** Audit Branch में trigger-aware test coverage का स्पष्ट gap है। Proposed cases implementation checklist हैं, verification results नहीं।



## 166. Trigger Attachment और Refund RPC Call-Path का Static Cross-Check

**तारीख:** 17 नवंबर 2026  
**स्रोत:** Audit Branch migration `20261116210000_attach_electrician_payout_reconciliation_trigger.sql` (Blob `b12da77471d510b55f798bd089597d866d79a133`)  
**सीमा:** केवल source पढ़ना; कोई SQL/DB/test execution नहीं।

### 1. Trigger Registration और Conditions

Migration `public.srk_create_electrician_payable()` को परिभाषित करती है और `public.service_bookings` पर `srk_reconcile_electrician_payable` नाम का AFTER ROW trigger बनाती है। Trigger INSERT तथा निम्न columns के UPDATE पर चलता है: `status`, `payment_status`, `assigned_electrician_id`, `payment_verified_at`, `amount_paid`, `quote_status`, `service_charge`, `materials_amount`, `commission_rate`, `razorpay_payment_id`, `selected_category`।

Refund closure branch केवल तब चलती है जब trigger को मिलने वाली नई booking row में `payment_status='refunded'` हो। वह उसी booking के payout में:
- `pending` को `refunded` करती है;
- `blocked` को तभी `refunded` करती है जब `payout_note` ठीक `Razorpay refund pending` या `Manual refund processed` हो;
- अन्य payout states और unrelated blocked notes को इस branch से नहीं बदलती।

ये trigger-body के static conditions हैं; database में trigger enabled/attached होने या runtime behavior का स्वतंत्र प्रमाण नहीं।

### 2. तीन RPC Call-Paths की तुलना

| RPC | Booking transition | Trigger के बाद payout check |
|---|---|---|
| `srk_admin_record_manual_refund` | manual refund entry के बाद paid booking को refunded करता है | payout row पहले से मौजूद हो तो दोबारा पढ़कर refunded न होने पर exception |
| `srk_service_finalize_razorpay_refund_from_recovery_evidence` | verified recovery evidence के बाद paid booking को refunded करता है | payout मौजूद हो तो दोबारा पढ़कर refunded न होने पर exception; processed replay में भी payout state जाँचता है |
| `srk_service_reconcile_booking_refund` | provider status processed होने पर paid booking को refunded करता है | उसी function body में payout को दोबारा पढ़कर verify नहीं करता |

इसलिए तीसरे RPC का success response अकेले payout closure का post-condition प्रमाणित नहीं करता। यह source-level coverage gap है; इसे runtime failure नहीं कहा जा रहा।

### 3. Regression Matrix के लिए सटीक अतिरिक्त Assertions

Section 165 के प्रस्ताव को इस static review से निम्न assertions के साथ refine किया जाना चाहिए:
1. Trigger name, timing, row-level scope और UPDATE column list मौजूद हों।
2. `pending` payout refund transition पर `refunded` हो।
3. दोनों exact refund-owned blocked notes बंद हों।
4. अलग blocked note और `paid` payout अपरिवर्तित रहें।
5. Manual refund और recovery RPC payout post-condition fail-closed रखें।
6. Provider reconciliation में trigger के बाद payout post-condition को transactional test में assert किया जाए; केवल RPC JSON success को पर्याप्त न माना जाए।
7. Recovery processed replay में booking और payout दोनों की consistent final state जाँची जाए।

### 4. निष्कर्ष

Trigger migration के भीतर manual refund और recovery RPCs trigger result को re-read करके जाँचती हैं; provider reconciliation RPC में वैसी explicit payout post-condition नहीं है। अगला सुरक्षित कदम इसी अंतर को owner review के लिए रखना है। Test file में बदलाव, pgTAP run, migration replay, DB query, CI, deployment, merge या cherry-pick नहीं किया गया।

**Verdict:** Static call-path review पूरा; trigger registration और payout lifecycle runtime verification अभी बाकी है।



## 167. Existing Payout Test और Financial Audit Trail Coverage Cross-Check

**तारीख:** 17 नवंबर 2026  
**Scope:** मौजूदा SQL test/migration source का static review; कोई test या database command नहीं चलाया गया।

### 1. महत्वपूर्ण अपडेट: Payout Trigger के कुछ प्रस्तावित Cases पहले से Static Test में हैं

Audit Branch की `supabase/tests/database/electrician_payout_reconciliation.test.sql` (Blob `88184e2e1fb386f16d6bd339556a15a5b87275d2`) पहले से:
- `srk_create_electrician_payable()` की मौजूदगी और `service_bookings` पर row-level AFTER INSERT/UPDATE attachment जाँचती है।
- trigger function की SECURITY DEFINER/search_path और direct client EXECUTE restrictions जाँचती है।
- function text में pending payout closure, दोनों refund-owned blocked notes, unrelated Admin block preservation, note clearing और paid payout overwrite न होने की शर्तें जाँचती है।
- payout ledger और commission parity validator के trigger ordering की static जाँच करती है।

इसलिए Section 165 में दिए गए trigger registration तथा source-condition cases पूरी तरह नए नहीं हैं। वे मौजूदा test के static assertions से काफी हद तक overlap करते हैं। मौजूदा file का test plan 34 है; इसे चलाया नहीं गया और इसके pass होने का दावा नहीं है।

### 2. Financial Audit Trigger की Source-Level पुष्टि

Migration `20261114125844_restore_financial_audit_core_schema.sql` (Blob `bdfdfcc01366a9d4a298b2107c53f1525b326bf9`) में:
- `srk_audit_electrician_payouts` payout table पर INSERT/UPDATE/DELETE audit trigger जोड़ता है।
- `srk_audit_razorpay_refunds` Razorpay refund table पर अलग audit trigger जोड़ता है।
- Generic audit allow-list में payout के लिए `payout_status`, `payout_note`, `payout_method`, `payout_reference`, `electrician_payable`, `platform_commission`, `paid_at` आदि शामिल हैं।
- Razorpay refund audit function `refund_id`, `amount`, `status`, `provider_status` में बदलाव दर्ज करने के लिए event बनाती है।
- Audit event actor के लिए `auth.uid()` null होने पर `system` role चुनती है; Admin identity मिलने पर `admin`, अन्यथा `user`।

यह source में audit-trigger wiring और field allow-list का प्रमाण है; वास्तविक audit rows insert होने या rollback/commit के बाद सुरक्षित रहने का runtime प्रमाण नहीं।

### 3. अभी वास्तविक Coverage Gap क्या बचता है?

मौजूदा payout test function source और trigger catalog की static जाँच करता है। यह अलग से साबित नहीं करता कि:
1. Refund transaction में payout trigger update से सही `electrician_payout` audit event row बनती है।
2. Razorpay refund status change पर expected `razorpay_refund` audit event बनती है।
3. Audit event में before/after values और changed_fields ठीक दर्ज होते हैं।
4. Provider reconciliation द्वारा booking refunded करने के बाद payout trigger closure और payout audit event एक ही transaction में सफल होते हैं।
5. किसी downstream exception पर booking, payout और audit events एक साथ rollback होते हैं।

अतः अगला उपयोगी test design अब generic trigger assertions दोहराने के बजाय audit-event behavioral assertions पर केंद्रित होना चाहिए, साथ ही provider reconciliation RPC का payout post-condition gap अलग रखा जाए।

### 4. Verdict

मौजूदा Audit Branch में payout trigger और payout/refund audit trigger की static coverage पहले से मौजूद है। वास्तविक कमी runtime behavioral evidence और provider reconciliation payout post-condition coverage की है। कोई test file या migration बदली नहीं गई; कोई pgTAP, DB query, replay, CI, deployment, merge या cherry-pick नहीं हुआ।



## 168. Refund Audit Event Coverage और Provider Reconciliation Replay Gap

**तारीख:** 17 नवंबर 2026  
**Scope:** Audit Branch की मौजूदा test/migration definitions का static cross-check; कोई SQL या database execution नहीं।

### 1. मौजूदा Tests वास्तव में क्या जाँचते हैं?

- `financial_audit_core_schema.test.sql` (Blob `1d4769e3be6af072bce6474c778cc1ad31b8d1c9`, `plan(54)`) audit tables, RLS, grants, function security और payout/refund audit triggers की catalog presence जाँचती है। इसमें वास्तविक payout/refund row mutate करके generated audit event के `before_data`, `after_data`, `changed_fields` या rollback का behavioral assertion नहीं दिखा।
- `refund_reconcile_full_amount_guard.test.sql` (Blob `fd5b7ceb8e612b588fac1a7ade8d7035388ca2bc`, `plan(5)`) RPC existence, full amount guard, booking lock और service_role grant जाँचती है। इसमें provider reconciliation के बाद payout post-condition या processed replay की जाँच नहीं है।
- `admin_manual_refund_request_completion.test.sql` (Blob `99cb0eb02e667699db27951b5b26161a89b8951b`, `plan(14)`) manual refund path में booking transition के बाद payout re-read/verification का static assertion रखती है।
- `durable_razorpay_refund_recovery_evidence.test.sql` (Blob `370b2c5e460d1a9abfbbe53371a48f9e68788788`, `plan(35)`) recovery finalizer के payout re-read, refunded state, processed replay और recovery audit evidence पर static checks रखती है।

### 2. Provider Reconciliation में विशेष Replay Gap

Migration `20261115250000_harden_refund_reconcile_full_amount.sql` (Blob `3bda81c2b827f597f639846d33967a7c88296e21`) में:
1. RPC booking row lock करती है, फिर refund row lock करती है।
2. पहले से `processed` या `failed` refund record मिलने पर early return करती है।
3. नए `processed` result पर booking को `refunded` करती है, जिससे payout trigger चलना अपेक्षित है।
4. लेकिन उस booking update के बाद payout को दोबारा पढ़कर `refunded` होने की explicit पुष्टि नहीं करती।
5. पहले से `processed` record के replay पर early return के कारण booking/payout consistency की पुनः जाँच भी नहीं होती।
6. `failed` branch refund-owned blocked payout को सीधे `pending` करती है; payout audit trigger source में मौजूद है, लेकिन generated audit row test में assert नहीं है।

यह source-level post-condition और replay-verification gap है; इससे runtime failure सिद्ध नहीं होता।

### 3. अगली Test Design के लिए केंद्रित Assertions

1. Processed reconciliation के बाद booking `refunded` और payout `refunded` दोनों verify हों।
2. पहले से processed refund के replay पर payout mismatch हो तो success response बिना consistency check के न मिले।
3. Failed reconciliation में केवल Razorpay-owned blocked payout restore हो; unrelated Admin hold न बदले।
4. Payout state change पर एक audit event बने, सही entity/booking IDs, action, changed_fields और before/after state सहित।
5. Refund status transition पर Razorpay refund audit event बने, सही old/new status के साथ।
6. Transaction के भीतर बाद की forced failure होने पर business rows और संबंधित audit events साथ rollback हों।
7. Idempotent replay पर duplicate audit event न बने जब कोई tracked field वास्तव में बदली न हो।

ये proposed behavioral assertions हैं, अभी test implementation या pass results नहीं।

### 4. Verdict

Audit schema/trigger catalog coverage मौजूद है; वास्तविक audit event row behavior और provider reconciliation payout post-condition/replay coverage नहीं। अगला सुरक्षित कदम इन assertions को owner review के लिए देना है। कोई SQL/test file या migration बदली नहीं गई; pgTAP, DB query, replay, CI, deployment, merge या cherry-pick नहीं हुआ।



## 169. Booking → Payout → Razorpay Audit Event Chain: Expected Behavioral Evidence

**तारीख:** 17 नवंबर 2026  
**Scope:** Audit trigger source और refund lifecycle का static cross-check; documentation-only।

### 1. तीन अलग Audit Entities अपेक्षित हैं

Audit core migration `20261114125844_restore_financial_audit_core_schema.sql` (Blob `bdfdfcc01366a9d4a298b2107c53f1525b326bf9`) के अनुसार:

- **Booking:** `service_bookings.payment_status` में `paid → refunded` बदलाव पर `entity_type='booking'`, `changed_fields` में `payment_status`, और before/after JSON में दोनों status।
- **Electrician Payout:** booking trigger द्वारा payout `pending` या refund-owned `blocked` से `refunded` करने पर `entity_type='electrician_payout'`; `changed_fields` में बदले हुए payout fields, सामान्यतः `payout_status` और यदि साफ हुआ हो तो `payout_note`।
- **Razorpay Refund:** refund record `processing → processed` होने पर `entity_type='razorpay_refund'`; बदले हुए `refund_id`, `status`, `provider_status` fields के exact before/after values।

तीनों events अलग-अलग rows हैं; इन्हें एक event समझकर केवल count=1 assert नहीं करना चाहिए। Audit rows के आपसी timestamp/order पर निर्भर रहने के बजाय entity, entity_id, booking_id और field values से assert करना चाहिए।

### 2. Source में दिखने वाला No-op व्यवहार

- Generic audit trigger allow-list में न आने वाले columns के बदलाव पर event नहीं बनाता।
- Generic UPDATE में allow-listed fields में कोई वास्तविक बदलाव न हो तो event नहीं बनता।
- Razorpay UPDATE में `refund_id`, `amount`, `status`, `provider_status` में कोई बदलाव न हो तो event नहीं बनता।
- Actor उपलब्ध न होने पर trigger `actor_role='system'` लिखता है; इसलिए service-role reconciliation test में system actor expectation की पुष्टि होनी चाहिए।

### 3. Proposed Behavioral Test Matrix

| Scenario | अपेक्षित प्रमाण |
|---|---|
| Processed provider result | Booking, payout और Razorpay refund के सही audit rows |
| Refund-owned blocked payout | पुराना blocked note और नया refunded state सही before/after में |
| Unrelated Admin hold | payout status/note जस का तस; payout audit update event नहीं |
| No-op UPDATE | tracked field न बदले तो नया audit event नहीं |
| Late duplicate processed result | business state स्थिर; कोई अनावश्यक duplicate update event नहीं |
| Forced transaction failure | उसी transaction के business changes और audit rows दोनों rollback |
| Failed provider result | केवल matching refund-owned hold restore; payout before/after audit row सही |

### 4. महत्वपूर्ण सीमा

यह अपेक्षित event chain source code से निकला test design है, observed runtime result नहीं। Provider reconciliation migration `20261115250000_harden_refund_reconcile_full_amount.sql` में processed branch booking update के बाद payout post-condition re-read नहीं करती; Section 168 का यह gap कायम है। इसीलिए test को केवल audit rows नहीं, booking/payout final state भी स्वतंत्र रूप से assert करना चाहिए।

**Verdict:** तीन-entity audit chain के लिए अलग behavioral assertions आवश्यक हैं। कोई migration या test file नहीं बदली गई; कोई SQL, pgTAP, DB query, replay, CI, deployment, merge या cherry-pick नहीं किया गया।



## 170. PostgreSQL Trigger Firing Order और Audit Timestamp Assumptions

**तारीख:** 17 नवंबर 2026  
**Scope:** Audit और payout trigger definitions का static ordering review; कोई database execution नहीं।

### 1. एक ही Booking UPDATE पर दो AFTER Triggers

Audit core migration (Blob `bdfdfcc01366a9d4a298b2107c53f1525b326bf9`) में:
- `srk_audit_service_bookings`: `AFTER INSERT OR UPDATE OR DELETE`
- यह `srk_capture_admin_audit_event()` चलाता है।

Payout reconciliation migration (Blob `b12da77471d510b55f798bd089597d866d79a133`) में:
- `srk_reconcile_electrician_payable`: `AFTER INSERT OR UPDATE OF ... payment_status ...`
- यह `srk_create_electrician_payable()` चलाता है।

दोनों Booking table पर AFTER UPDATE event में भाग लेते हैं। PostgreSQL में एक ही event/timing के समान-स्तर के triggers नाम के alphabetical क्रम में fire होते हैं। इन नामों में `srk_audit_service_bookings` पहले और `srk_reconcile_electrician_payable` बाद में आता है।

इसका अर्थ: Booking audit trigger पहले booking का `paid → refunded` event लिख सकता है; उसके बाद payout reconciliation trigger payout row बदलता है, और उस payout row का अपना audit trigger payout event लिखता है। यह क्रम source definitions से निकला है; runtime trace नहीं।

### 2. Test Design पर असर

- Audit rows का insertion order या `created_at` timestamp business transition order का प्रमाण न माना जाए।
- Test को तीनों entity rows को `entity_type + entity_id + booking_id` से खोजकर उनके JSON snapshots और changed_fields independently assert करने चाहिए।
- Payout audit event booking trigger के nested payout UPDATE से आता है; उसे booking audit row में मिलाकर न जाँचा जाए।
- यदि trigger names बदले जाएँ, ordering assumption बदल सकती है; इसलिए test correctness को alphabetical order पर निर्भर नहीं बनाना चाहिए।
- Transaction rollback test में booking, payout और सभी generated audit rows की atomic rollback जाँची जाए।

### 3. अतिरिक्त सीमा

Audit triggers `AFTER INSERT OR UPDATE OR DELETE` हैं और generic audit function allow-listed fields में वास्तविक बदलाव न होने पर event छोड़ देता है। Payout trigger booking update के अंदर payout row update करता है; इसलिए nested update के audit event को भी अलग assertion चाहिए।

**Verdict:** Source में booking और payout audit chain के trigger definitions मौजूद हैं। Firing order का निष्कर्ष PostgreSQL trigger semantics और trigger names पर आधारित static analysis है; कोई runtime order, timestamp behavior या audit-row output verify नहीं हुआ। कोई SQL/test/migration file नहीं बदली गई; DB query, pgTAP, replay, CI, deployment, merge या cherry-pick नहीं हुआ।



## 171. Audit Transaction Atomicity और created_at Ordering की सीमा

**तारीख:** 17 नवंबर 2026  
**Scope:** Audit table defaults और trigger-insert behavior का static review; कोई transaction execute नहीं किया गया।

### 1. Audit Rows उसी Database Transaction का हिस्सा हैं

Audit functions सीधे `srk_admin_audit_events` में INSERT करती हैं। ये INSERT संबंधित table के AFTER ROW trigger के भीतर होता है; कोई अलग connection या asynchronous queue source में नहीं दिखती।

इसलिए सामान्य PostgreSQL transaction semantics के अनुसार:
- Business row update और trigger-generated audit row एक ही transaction में commit होते हैं।
- उसी transaction में बाद में exception उठे और transaction rollback हो, तो business changes और audit rows दोनों rollback होने चाहिए।
- Recovery finalizer में booking update के बाद payout state verify की जाती है; verification exception होने पर पहले बने booking/payout/refund audit rows भी उसी transaction के साथ rollback होने चाहिए।

यह PostgreSQL transactional behavior से निकला निष्कर्ष है, इस repository पर चलाया गया runtime test नहीं।

### 2. created_at से Trigger Order तय नहीं किया जा सकता

Audit table में `created_at timestamptz NOT NULL DEFAULT now()` है। PostgreSQL में `now()` transaction-start timestamp देता है; इसलिए एक transaction के भीतर बने booking, payout और Razorpay audit events के timestamps समान हो सकते हैं।

Test और Admin reporting को:
- केवल `created_at` के आधार पर trigger order तय नहीं करना चाहिए।
- `entity_type`, `entity_id`, `booking_id`, `action`, `changed_fields`, `before_data`, `after_data` को मुख्य evidence बनाना चाहिए।
- अगर भविष्य में strict per-event ordering चाहिए, तो अलग monotonic sequence/ordinal design की आवश्यकता पर विचार करना होगा; अभी ऐसी सुविधा मौजूद होने का दावा नहीं है।

### 3. सुझाए गए Atomicity Assertions

1. एक सफल refund transaction में booking, payout और Razorpay refund audit rows commit हों।
2. Finalizer के payout post-condition पर जानबूझकर failure उत्पन्न करने वाले isolated test में booking/refund/payout business state और सभी उसी transaction के audit rows rollback हों।
3. उसी transaction में audit insert failure हो तो business state silently commit न हो।
4. एक transaction के अंदर बने audit rows का `created_at` समान होना स्वीकार्य हो; test किसी निश्चित timestamp order की माँग न करे।

### 4. Verdict

Source में audit writes synchronous trigger inserts हैं और table timestamp default `now()` है। इससे atomicity तथा timestamp-order test requirements स्पष्ट होते हैं। अभी atomicity को इस repository पर execute करके प्रमाणित नहीं किया गया है। कोई SQL/test/migration file नहीं बदली गई; कोई DB query, pgTAP, replay, CI, deployment, merge या cherry-pick नहीं हुआ।



## 172. Audit Table Access, Index Coverage और Retention/Immutability सीमा

**तारीख:** 17 नवंबर 2026  
**Scope:** Audit core migration में table grants, RLS और indexes का static inspection।

### 1. Read/Write Access

Migration में `srk_admin_audit_events` पर RLS enable है और PUBLIC, anon तथा authenticated से सभी table privileges revoke किए गए हैं। उसी migration में `service_role` को `ALL` grant है। इस source definition के अनुसार सामान्य authenticated client को सीधे audit table पढ़ने/लिखने का grant नहीं मिलता; service_role privileged है।

महत्वपूर्ण सीमा: `ALL` privilege का अर्थ केवल append/INSERT नहीं है। इस migration के आधार पर service_role के लिए UPDATE/DELETE भी privilege set में शामिल हैं। इसलिए इसे tamper-proof या strictly append-only audit store कहना सही नहीं होगा। यह source-level grant review है; deployed DB privileges verify नहीं किए गए।

### 2. उपलब्ध Indexes और Query Paths

Migration में ये उपयोगी indexes हैं:
- `(booking_id, created_at DESC)`, केवल non-null booking_id rows के लिए।
- `(entity_type, entity_id, created_at DESC)`।
- `(created_at DESC)`।
- Refund status और created_at पर अलग operational index।

इनसे booking timeline, entity history और recent-event queries के लिए स्पष्ट index paths मिलते हैं।

### 3. शेष Design Questions

- `actor_user_id` पर कोई dedicated index इस migration में नहीं मिला। यदि Admin UI में actor-wise audit search आवश्यक हो, तो query plan/volume के आधार पर अलग index की जरूरत जाँची जाए।
- इस migration में audit-event retention, archival या purge policy परिभाषित नहीं है। इसे स्वतः अनंत retention का प्रमाण न मानें; अन्य migrations/operational policy अलग हो सकती है।
- यदि audit history को privileged service_role compromise के विरुद्ध tamper-evident बनाना आवश्यक है, तो वर्तमान table grants अकेले वह guarantee नहीं देते। अलग append-only/externally anchored design का threat-model review चाहिए।

### 4. Verdict

Authenticated client access पर revoke/RLS controls और मुख्य booking/entity/time indexes source में मौजूद हैं। लेकिन service_role को broad table privileges दिए गए हैं; actor-wise index और retention policy इस migration में नहीं दिखते। कोई grant, policy, index या retention setting बदली नहीं गई; कोई live DB privilege inspection, query plan, DB query, test, replay, CI, deployment, merge या cherry-pick नहीं हुआ।



## 173. Audit Actor Identity और Service-Role Attribution की सीमा

**तारीख:** 17 नवंबर 2026  
**Scope:** Audit core migration में actor resolution, role classification और user deletion behavior का static source review। कोई JWT/session या database execution नहीं किया गया।

### 1. Actor पहचान कहाँ से आती है

Migration `20261114125844_restore_financial_audit_core_schema.sql` में दोनों trigger functions:
- `srk_capture_admin_audit_event()`
- `srk_capture_razorpay_refund_audit_event()`

`auth.uid()` से `actor_user_id` लेते हैं। फिर:
- actor UUID NULL हो तो `actor_role='system'`
- actor UUID मौजूद हो और `public.is_srk_admin()` true हो तो `admin'`
- अन्यथा `user'`

यह पहचान source में request/JWT context से आती है; trigger function का `SECURITY DEFINER` होना अपने-आप वास्तविक व्यक्ति की पहचान नहीं बनाता।

### 2. Service-role और backend workflow की सावधानी

यदि backend/service-role request में ऐसा user subject उपलब्ध नहीं है जिससे `auth.uid()` UUID दे सके, तो audit row `actor_user_id=NULL` और `actor_role='system'` के रूप में दर्ज होगी। यह तकनीकी service actor और वास्तविक initiating Admin के बीच अंतर नहीं बताती।

इसलिए:
- Service-role workflow द्वारा किए गए परिवर्तन को स्वतः किसी Admin के नाम से attribute न किया जाए।
- यदि किसी Admin ने backend action शुरू किया है, तो initiating Admin ID को सुरक्षित, server-validated तरीके से audit context तक पहुँचाने की आवश्यकता अलग से design/test की जानी चाहिए।
- Client द्वारा भेजे गए मनमाने actor ID को trusted identity नहीं मानना चाहिए।

यह conditional source-level risk है; कोई live JWT, service-role request या deployed audit row जाँची नहीं गई।

### 3. User deletion का प्रभाव

Audit table में `actor_user_id` का foreign key `auth.users(id)` से जुड़ा है और `ON DELETE SET NULL` है। अतः संबंधित Auth user हटने पर पुरानी audit row में actor UUID NULL हो सकता है। `actor_role` अलग text field है, इसलिए वह अपनी मौजूदा value रख सकती है; लेकिन उस row से मूल user की UUID identity फिर उपलब्ध नहीं रहेगी।

यदि compliance या investigation के लिए actor identity को लंबे समय तक स्थिर रखना आवश्यक है, तो retention और pseudonymous actor-reference policy पर अलग design review चाहिए। इस audit में कोई schema change प्रस्तावित या लागू नहीं किया गया।

### 4. सुझाए गए Verification Assertions

1. Authenticated Admin द्वारा किए गए परिवर्तन में अपेक्षित Admin UUID और `admin` role दर्ज हों।
2. सामान्य authenticated user परिवर्तन में सही UUID और `user` role दर्ज हो।
3. बिना user subject वाले trusted backend/service-role workflow का अपेक्षित `system` attribution स्पष्ट रूप से test हो।
4. Backend workflow में initiating Admin की पहचान आवश्यक हो तो वह केवल server-validated context से आए; client-supplied arbitrary UUID स्वीकार न हो।
5. Auth user deletion के बाद `actor_user_id` के NULL होने और `actor_role` के बने रहने का behavior policy के अनुरूप test हो।

### 5. Verdict

Source में actor attribution `auth.uid()` और `is_srk_admin()` पर आधारित है। Service-role/backend request में user subject न होने पर audit actor `system` हो सकता है; Auth user deletion पर actor foreign key NULL हो सकती है। इन परिस्थितियों का runtime behavior और deployed configuration verify नहीं किया गया है। कोई SQL/test/migration, grant, policy या database setting नहीं बदली गई; कोई DB query, pgTAP, replay, CI, deployment, merge या cherry-pick नहीं हुआ।



## 174. Main Admin और Support Staff Audit Streams का अंतर

**तारीख:** 17 नवंबर 2026  
**Scope:** Audit Branch में Main Admin allow-list, Support Staff RBAC और दोनों audit tables के source-level संबंध की जाँच। कोई database operation या runtime test नहीं किया गया।

### 1. Staff अलग Identity Class है

Migration `20261114390000_admin_staff_rbac_foundation.sql` स्पष्ट करती है कि Main Admin की पहचान `srk_admin_users` में रहती है और Support Staff को उस सूची में नहीं जोड़ा जाता। Staff के लिए अलग `srk_admin_staff`, `srk_admin_permissions` और `srk_admin_role_permissions` संरचनाएँ हैं। Permission helper पहले Main Admin जाँचता है; उसके बाद active staff और role-permission mapping जाँचता है।

### 2. दो अलग Audit Tables

- Financial/general audit: `srk_admin_audit_events`; actor role केवल `admin`, `user`, `system` में वर्गीकृत होता है।
- Staff RBAC audit: `srk_admin_staff_audit_events`; इसमें actor UUID, target UUID, action, outcome और details अलग से रखे जाते हैं। Staff audit table पर immutable guard और actor/target indexes भी migration में परिभाषित हैं।

इसलिए Support Staff द्वारा किया गया ऐसा बदलाव जो general audit trigger से गुजरता है, `is_srk_admin()` false होने पर `user` role के रूप में दिख सकता है; Staff-specific activity का विस्तृत रिकॉर्ड अलग Staff audit stream में होना चाहिए। General audit role field अकेले Support Staff को सामान्य ग्राहक से अलग नहीं पहचानती।

### 3. Reporting और Investigation के लिए प्रभाव

- Main Admin की वित्तीय कार्रवाई और Support Staff की support कार्रवाई को केवल `actor_role` से अलग-अलग न समझें।
- Staff investigation में `srk_admin_staff_audit_events` के actor/target/action/outcome/details को साथ पढ़ना आवश्यक है।
- दोनों audit streams के बीच correlation चाहिए तो actor UUID और संबंधित business entity/reference को स्पष्ट रूप से जोड़ने वाला report/query contract चाहिए; केवल timestamp से संबंध या क्रम सिद्ध नहीं होता।
- Staff audit table के immutable guard का दावा source definition पर आधारित है; trigger bypass या privileged database owner के विरुद्ध runtime/tamper-resistance test नहीं किया गया।

### 4. सुझाए गए Verification Assertions

1. Main Admin action general audit में `actor_role='admin'` और सही actor UUID दे।
2. Support Staff action Staff-specific audit में सही actor/target/action/outcome दर्ज करे।
3. Support Staff द्वारा general audited entity बदलने पर `actor_role='user'` की अपेक्षा स्पष्ट हो और रिपोर्टिंग इसे ग्राहक कार्रवाई न समझे।
4. Main Admin द्वारा Staff audit history पढ़ने की अनुमति और non-Admin denial behavior test हो।
5. दोनों audit streams की correlation entity/actor identifiers से हो, केवल timestamp ordering से नहीं।

### 5. Verdict

Audit Branch में Main Admin और Support Staff की identity तथा audit streams अलग परिभाषित हैं। General audit का `admin/user/system` role field Support Staff को अलग label नहीं करता; Staff-specific events के लिए अलग table मौजूद है। इन दोनों streams की वास्तविक runtime completeness, cross-stream correlation और immutable behavior execute करके verify नहीं किए गए। कोई SQL/test/migration, permission, policy या database setting नहीं बदली गई; कोई DB query, pgTAP, replay, CI, deployment, merge या cherry-pick नहीं हुआ।



## 175. Staff Audit Append-Only Guard और Invite Actor Attribution

**तारीख:** 17 नवंबर 2026  
**Scope:** Support Staff audit guard, audit event insertion call paths और service-role invite RPC का static source review।

### 1. Append-Only Guard

Migration `20261114390000_admin_staff_rbac_foundation.sql` में:
- `BEFORE UPDATE OR DELETE` row trigger सभी row mutation को `ADMIN_STAFF_AUDIT_IS_APPEND_ONLY` exception से रोकता है।
- `BEFORE TRUNCATE` statement trigger भी वही exception देता है।
- Browser roles `PUBLIC`, `anon`, `authenticated` के direct table और sequence privileges revoke किए गए हैं।
- Audit rows केवल insert करने वाले trusted SECURITY DEFINER workflows से लिखे जाने का design है।

यह database-level guard सामान्य UPDATE/DELETE/TRUNCATE को रोकने का source evidence है; इसे database owner/superuser या trigger-disabling privileged operator के विरुद्ध absolute tamper-proof guarantee नहीं कहा जा सकता। कोई privileged bypass execute नहीं किया गया।

### 2. Event Coverage की Source सूची

Migration में staff status change, invite, session revoke/register, support case assignment, customer/electrician reply और status update के लिए explicit audit INSERT दिखाई देते हैं। इन inserts का business operation के साथ एक transaction में होना PostgreSQL function execution model से अपेक्षित है, लेकिन rollback behavior का runtime proof उपलब्ध नहीं है।

### 3. Invite Actor Attribution का विशेष ध्यान

`srk_admin_staff_register_invited_user(uuid,text,uuid)` केवल `service_role` को EXECUTE grant देता है। Function `p_actor_admin_id` को `srk_admin_users` में मौजूद होने की जाँच करता है और उसी UUID को invite audit के `actor_user_id` में लिखता है।

यह check पुष्टि करता है कि UUID किसी Main Admin record का है; यह अकेले यह प्रमाणित नहीं करता कि उसी Admin ने वर्तमान invite request वास्तव में शुरू की थी। वास्तविक attribution इस बात पर निर्भर है कि service-role-only Edge Function caller को कैसे authenticate करती है और actor UUID स्वयं trusted server-side session से लेती है या नहीं। Edge Function का implementation और runtime request flow इस चरण में सत्यापित नहीं किया गया। इसलिए client-provided actor UUID को बिना server-side binding के भरोसेमंद नहीं मानना चाहिए।

### 4. सुझाए गए Verification Assertions

1. Staff audit row पर UPDATE और DELETE असफल हों।
2. Staff audit table पर TRUNCATE असफल हो।
3. सामान्य staff RPC में business change और audit insert साथ rollback हों।
4. Invite Edge Function authenticated Main Admin session से actor UUID निकाले; arbitrary request-body UUID स्वीकार न हो।
5. Service-role invite function का direct invocation केवल trusted server path से हो और actor attribution का evidence सुरक्षित रहे।
6. हर audited action में actor, target, action, outcome और न्यूनतम आवश्यक details सही हों; credentials या access tokens कभी न लिखे जाएँ।

### 5. Verdict

Staff audit table पर row mutation और truncate रोकने वाले triggers मौजूद हैं। कई staff workflows में explicit audit inserts भी हैं। Invite RPC का actor UUID parameter केवल Main Admin registry membership से validate होता है; वास्तविक initiating Admin की पहचान server-side Edge Function flow पर निर्भर है, जिसे अभी verify नहीं किया गया। Append-only protection privileged database owner के विरुद्ध absolute नहीं है। कोई SQL/test/migration, grant, policy या database setting नहीं बदली गई; कोई DB query, pgTAP, replay, CI, deployment, merge या cherry-pick नहीं हुआ।



## 176. Staff Invite Edge Function — Trusted Admin Actor Verification

**तारीख:** 17 नवंबर 2026  
**Scope:** `supabase/functions/admin-staff-management/index.ts` और संबंधित source-level test assertions का static review।

### 1. Main Admin की पहचान server-side verify होती है

Edge Function:
- Bearer token अनिवार्य करता है।
- `userClient.auth.getUser(token)` से Supabase Auth के विरुद्ध token/user सत्यापित करता है।
- उसी authenticated user context से `userClient.rpc("is_srk_admin")` चलाता है और केवल `true` पर आगे बढ़ता है।
- Browser के `user_metadata`/`app_metadata` को authorization source नहीं मानता।

### 2. Actor UUID request body से नहीं आता

Invite registration RPC को `p_actor_admin_id: authData.user.id` दिया जाता है। Request body से actor/admin ID, role या is_admin flag नहीं पढ़ा जाता। Role server-side fixed `support` है। इससे पिछले section में उठी actor-attribution चिंता के लिए source-level समाधान मिलता है: Edge Function पहले trusted Auth user और Main Admin status verify करती है, फिर उसी verified user ID को service-role RPC तक भेजती है।

### 3. Service-role का सीमित उपयोग और failure path

Service-role client केवल server-side Auth invitation और registry registration के लिए बनाया जाता है। Registry registration विफल होने पर function नव-निर्मित Auth user को हटाने का प्रयास करता है और response में बताता है कि invitation email पहले ही भेजा गया हो सकता है। यह cleanup email को वापस नहीं ले सकता; इसलिए failure पर manual Main Admin review की चेतावनी उचित है।

### 4. उपलब्ध Test Evidence की सीमा

`tests/admin-refund-and-staff-access.test.js` में static source assertions मौजूद हैं जो Bearer token, `auth.getUser(token)`, `is_srk_admin`, `authData.user.id`, fixed Support role और failed registration cleanup को जाँचने के लिए लिखे गए हैं। यह test file source assertions का प्रमाण है; इस audit चरण में Node tests चलाए नहीं गए। Database pgTAP file में भी service-role-only registration grant और function existence के assertions मौजूद हैं, पर pgTAP execute नहीं किया गया।

### 5. शेष Runtime Verification

1. Edge Function deployment में सही secrets और JWT verification configuration मौजूद हों।
2. Non-Admin, expired token और missing token पर invitation न बने।
3. Valid Main Admin invite में audit actor UUID वास्तविक authenticated Main Admin से मेल खाए।
4. Auth invitation सफल लेकिन registry insert विफल होने पर cleanup outcome और पहले से भेजे गए email का handling सत्यापित हो।
5. Concurrent duplicate invitation और retry behavior नियंत्रित हो।

### 6. Verdict

Static source review के अनुसार Edge Function verified Bearer user और Main Admin RPC check के बाद ही invite flow चलाती है; actor ID verified `authData.user.id` से आती है, client body से नहीं। इससे invite actor attribution का source-level design संतोषजनक दिखता है। Deployment configuration, actual requests, audit rows और failure/retry runtime behavior अभी सत्यापित नहीं हैं। कोई function, migration, test, secret, permission या database setting नहीं बदली गई; कोई test/pgTAP/DB query/replay/CI/deployment/merge/cherry-pick नहीं हुआ।



## 177. Staff Invite Audit Row — Actor/Target, Atomicity और Failure Evidence

**तारीख:** 17 नवंबर 2026  
**Scope:** Staff RBAC migration में invite-registration RPC और Staff audit table का static source review।

### 1. Invite event का audit payload

`srk_admin_staff_register_invited_user(uuid,text,uuid)`:
- `p_actor_admin_id` और `p_staff_user_id` दोनों null न होने की जाँच करता है।
- Actor UUID को `srk_admin_users.user_id` में मौजूद होना आवश्यक करता है।
- Staff row को fixed `support` role और `invited` status के साथ insert करता है; `invited_by` में वही actor UUID रखता है।
- उसी RPC में `srk_admin_staff_audit_events` पर `staff.invited` / `success` event insert करता है। Audit details में `role_key: support` दर्ज है।

### 2. Transaction boundary

दोनों SQL inserts एक ही PostgreSQL function invocation के भीतर हैं। सामान्य PostgreSQL transaction semantics के अनुसार, यदि दूसरी insert fail होकर exception उठाती है तो पहली insert भी उसी transaction में rollback होगी। यह source-level/transaction-semantics निष्कर्ष है; कोई database execution या rollback test नहीं किया गया।

Auth invitation इससे पहले Edge Function के Supabase Auth Admin API call में बनती है, इसलिए Auth invitation और database registry/audit एक single cross-system transaction नहीं हैं। DB registration failure पर Edge Function Auth user delete करने का best-effort प्रयास करती है; email पहले जा चुकी हो सकती है।

### 3. Audit query support और append-only controls

- Audit table में `actor_user_id`, `target_user_id`, `action`, `outcome`, `details`, `created_at` fields हैं।
- Actor और target दोनों के लिए descending `created_at` indexes हैं।
- Browser roles को table/sequence के direct privileges revoke किए गए हैं।
- UPDATE, DELETE और TRUNCATE रोकने वाले append-only triggers migration में परिभाषित हैं।

### 4. शेष Evidence Gap

- RPC actor ID को `srk_admin_users` membership से validate करता है, पर अकेले SQL function यह सिद्ध नहीं करता कि caller की वर्तमान Auth identity वही actor है। यह भरोसा service-role-only grant और Edge Function के पहले किए गए `getUser(token)` + `is_srk_admin()` checks पर निर्भर है।
- `staff.invited` success event registry insert के साथ बनता है; invalid request, denied Edge Function request, Auth invite failure, या registration failure के लिए इसी RPC में अलग `denied/failed` audit event नहीं दिखता।
- Auth invitation email delivery और cleanup outcome की durable audit event इस RPC में नहीं है।
- Actual audit rows, DB privileges, trigger enforcement और rollback behavior live database में सत्यापित नहीं हुए।

### 5. Verdict

Invite success path में actor, target, action और fixed Support role का audit event source code में स्पष्ट है; actor/target lookup indexes भी मौजूद हैं। Database registry insert और success audit insert एक RPC transaction में साथ रहते हैं, लेकिन Auth invitation अलग system operation है। Denied/failed invite attempts और email delivery/cleanup के लिए durable event coverage शेष है। कोई source file, migration, test, permission या database setting नहीं बदली गई; कोई test/pgTAP/DB query/replay/CI/deployment/merge/cherry-pick नहीं हुआ।



## 178. Staff RBAC Audit Writers — Actor Attribution और Event Coverage Matrix

**तारीख:** 17 नवंबर 2026  
**Scope:** Staff RBAC foundation migration के सभी नौ audit-insert call sites का static review।

### 1. Main Admin द्वारा किए जाने वाले बदलाव

- **Staff status:** `srk_admin_staff_set_status` में actor `auth.uid()` से आता है और Main Admin check अनिवार्य है। Event में पुराना/नया status और reason दर्ज होता है। Suspend/disable पर active sessions revoke किए जाते हैं।
- **Support assignment:** `srk_admin_assign_support_case` में actor `auth.uid()` है और Main Admin check अनिवार्य है। Event में case type/id, previous assignee, new assignee और reason दर्ज होते हैं।
- **Session revoke:** `srk_admin_staff_revoke_session` में actor `auth.uid()` और Main Admin check है। Event में session record ID और reason दर्ज होते हैं।
- **Staff invite:** अलग service-role-only RPC event लिखता है; actor Edge Function से verified Main Admin UUID के रूप में आता है (Sections 176–177)।

### 2. Support Staff द्वारा किए जाने वाले बदलाव

- Customer reply और status update में actor `auth.uid()` है; permission तथा case assignment checks के बाद success event लिखा जाता है।
- Electrician reply और status update में भी actor `auth.uid()` है; संबंधित permission और assignment checks के बाद success event लिखा जाता है।
- Session registration trigger में actor और target दोनों नए session row के `staff_user_id` से आते हैं; यह session creation event है, Main Admin action नहीं।

### 3. Audit Read Access

`srk_admin_list_staff_audit_events` Main Admin-only है। यह दिए गए staff UUID के actor या target होने वाले events लौटाता है, नवीनतम पहले, और limit को 1–300 तक सीमित करता है। इसलिए इसे पूरे system की global audit export न समझें; यह एक चुने हुए staff identity से जुड़े events का view है।

### 4. Coverage Gap

इन नौ insert call sites में दर्ज events success events हैं। Permission denial, invalid request, missing assignment, closed case, failed invitation, या अन्य rejected attempts के लिए अलग `denied`/`failed` event इन inspected RPC bodies में नहीं मिला। Database exception पर उसी transaction के success-side writes rollback होंगे; इसलिए rejected attempt का durable audit record स्वतः नहीं बनता। इसके लिए अलग सुरक्षित logging path की आवश्यकता हो सकती है, जिसमें sensitive message body/token जैसे data न लिखे जाएँ।

### 5. Verdict

सफल Staff/Admin workflow events में actor attribution अधिकांशतः current authenticated user (`auth.uid()`) से जुड़ी है; invite path verified Edge Function actor ID का उपयोग करता है। Session registration event स्वयं Staff identity को actor बताता है। Success-path event coverage उपयोगी है, लेकिन denied/failed security attempts की durable audit coverage शेष gap है। यह source-level review है; live audit rows या deployed privileges verify नहीं हुए। कोई source file, migration, test, permission या database setting नहीं बदली गई; कोई test/pgTAP/DB query/replay/CI/deployment/merge/cherry-pick नहीं हुआ।
