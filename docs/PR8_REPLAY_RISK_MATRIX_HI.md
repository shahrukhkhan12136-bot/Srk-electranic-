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
| Commission prerequisites | `20261109003000_secure_commission_reporting.sql` reads `amount_paid`; quote workflow trigger reads `NEW.amount_paid` | Earlier consumers can fail before later restore migration introduces the column | Reconcile canonical column introduction and deployed history before changing sequence |
| Migration versions | Two files start with `20261109_` rather than 14 digits | CLI migration parser / ledger cannot reliably order them | Resolve intended versions against authoritative remote ledger |
| Local config | No `supabase/config.toml` at audited PR head | Local Supabase CLI workflow not yet reproducible | Add reviewed local configuration before claiming harness readiness |

## Important additional finding: quote-state DDL is duplicated

The quote workflow migration includes the same high-level status and assignment constraint replacement as the separate `20261109_allow_quote_approval_booking_states.sql` file. This is a separate issue from the malformed version names. A source diff and authoritative ledger check are required to decide whether one file is historical duplication, an intentional idempotent repeat, or an incomplete split.

## Safe next actions

1. Obtain an authoritative schema-only export and migration ledger from the owner-approved environment.
2. Compare the two quote-state DDL blocks and their exact constraints/expressions.
3. Establish the earliest intended version for `amount_paid` based on source history and remote ledger.
4. Resolve malformed migration filenames only after ledger comparison.
5. Build and run the disposable local Supabase harness after these gates are closed.

## Safety boundary

No remote database was connected to or modified. No migration was applied. No migration was renamed, deleted, or reordered. No test is represented as passed.
