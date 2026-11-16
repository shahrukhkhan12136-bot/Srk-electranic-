# PR #8 — Replay Risk Matrix (Source Evidence, 2026-11-16)

**Audited source ref:** `41b4b1ecc84f5ba3b753c6940ccbfe3c3ffd68d7`  
**Purpose:** Convert confirmed source dependencies into explicit replay gates. Static inspection only.

| Gate | Source evidence | Clean replay risk | Required resolution |
|---|---|---|---|
| Base schema | `COMPLETE_DATABASE_SETUP.sql` creates service_bookings, electrician_applications, electrician_profiles, job_offers and srk_admin_users | Numbered migrations assume these objects already exist | Approve exact baseline provenance and schema contract |
| Auth schema | Base setup references `auth.users`; migrations add Auth-user FKs and read phone verification fields | Plain PostgreSQL without Supabase Auth objects will fail | Use isolated local Supabase, not bare PostgreSQL |
| Admin helper | `20261108234000_combine_booking_read_policy.sql` calls `is_srk_admin()`; `20261109001000` calls it; `20261109001500` calls `srk_is_admin()` | Missing helper at first reference causes function/policy creation failure | Establish exact definitions and grants before first dependent migration |
| Customer ownership | `20261108121115_add_customer_account_booking_access.sql` adds `customer_user_id`; combined read policy consumes it | Combined policy fails if ownership column migration is later or omitted | Preserve customer ownership migration before combined read policy |
| Electrician identity | `20261109000500_harden_electrician_profile_identity_linking.sql` adds/synchronizes `auth_user_id`; GPS migration writes both identity fields | GPS migration can fail if identity column does not exist | Identity hardening must precede GPS migration |
| GPS and offer RPC | `20261109001000` adds coordinate columns and Admin approval RPC; `20261109001500` replaces approval RPC; `20261109002000` creates map-pin offer RPC | Function replacement depends on prior signatures and columns | Keep the source-established order and validate signatures |
| Quote RPC | `20261109_electrician_inspection_quotes_and_service_only_commission.sql` reads customer_user_id, location columns, and quote fields; replaces `srk_get_my_offer_details()` | Missing earlier ownership/GPS/base columns or wrong return signature causes failure | Verify full predecessor chain and RPC return-type compatibility |
| Quote status migration duplication | The quote workflow file itself ends by replacing `service_bookings_status_check` and adding assignment-state constraint; `20261109_allow_quote_approval_booking_states.sql` repeats that status/assignment-constraint work | Running both may be redundant; exact duplicate constraint DDL may fail or cause confusing lineage | Compare both complete files and remote migration history; do not delete or rename either without approval |
| Commission prerequisites (corrected after ledger check) | Production ledger records `20261108095928 add_actual_paid_amount_commission_and_status_history` before the quote workflow; live `service_bookings.amount_paid` exists with a nonnegative check. The matching historical migration file is absent from the audited PR source tree; branch instead contains a new `20261116200000_restore_service_bookings_amount_paid.sql` | Clean replay from branch source cannot reproduce the deployed introduction at its original point. The late restore file may mask missing history but does not reconstruct the exact historical chain | Recover/restore the original migration source from authoritative history; compare its full DDL before deciding whether the new late restore is redundant or retained only as a forward repair |
| Migration versions | Two files start with `20261109_` rather than 14 digits | CLI migration parser / ledger cannot reliably order them | Resolve intended versions against authoritative remote ledger |
| Local config | No `supabase/config.toml` at audited PR head | Local Supabase CLI workflow not yet reproducible | Add reviewed local configuration before claiming harness readiness |

## Authoritative Production ledger reconciliation (read-only)

The Supabase Production migration ledger was read without executing SQL changes. It reports the following relevant order:

- `20261108095928 add_actual_paid_amount_commission_and_status_history`
- `20261108121115 add_customer_account_booking_access`
- `20261108183027 add_google_maps_location_support`
- `20261108183324 expose_assigned_booking_map_pin`
- `20261109075837 electrician_inspection_quotes_and_service_only_commission`
- `20261109080400 allow_quote_approval_booking_states`

The current Production `public.service_bookings` schema also exposes `amount_paid numeric` with a nonnegative check constraint. This confirms that the earlier claim that Production first introduced `amount_paid` only after its consumers was incorrect. The verified problem is instead a **source-history gap**: the audited branch has no migration file matching the ledger's `20261108095928` introduction, while it does contain a later `20261116200000_restore_service_bookings_amount_paid.sql`.

The two quote-state blocks were compared line by line: both drop and recreate `service_bookings_status_check` with the same allowed-state list, and drop and recreate `service_bookings_assignment_status_requires_electrician` with the same assignment predicate. This is an exact repeated constraint operation in the branch source. Production ledger order places the quote workflow at `075837` and the separate state migration at `080400`, but the ledger exposes names/versions, not historical SQL bodies; it therefore confirms the deployed order, not that the Production SQL bodies were byte-identical.

The branch's GPS/map files also use `20261109001000` and `20261109002000`, while the Production ledger records corresponding names at `20261108183027` and `20261108183324`. That is another source filename/version-to-ledger mismatch to reconcile before replay.

## Important additional finding: quote-state DDL is duplicated

The quote workflow migration includes the same high-level status and assignment constraint replacement as the separate `20261109_allow_quote_approval_booking_states.sql` file. This is a separate issue from the malformed version names. A source diff and authoritative ledger check are required to decide whether one file is historical duplication, an intentional idempotent repeat, or an incomplete split.

## Safe next actions

1. Obtain an authoritative schema-only export and migration ledger from the owner-approved environment.
2. Compare the two quote-state DDL blocks and their exact constraints/expressions.
3. Establish the earliest intended version for `amount_paid` based on source history and remote ledger.
4. Resolve malformed migration filenames only after ledger comparison.
5. Build and run the disposable local Supabase harness after these gates are closed.

## Safety boundary

Production was accessed only through read-only project, migration-ledger, and table-schema inspection. No SQL was executed against Production. No migration was applied, renamed, deleted, or reordered. No test is represented as passed.
