# PR #8 — Disposable Baseline Design (Review Draft)

**Source commit:** `41b4b1ecc84f5ba3b753c6940ccbfe3c3ffd68d7`  
**Status:** design-only; not executable SQL and not approved for any hosted database.

## Goal

Define a reproducible clean-install starting point for the numbered migration chain without pretending that the existing consolidated setup script is already a canonical baseline.

## Baseline object inventory from checked-in source

| Object | Existing source | Required before migrations | Status |
|---|---|---:|---|
| `public.service_bookings` | `COMPLETE_DATABASE_SETUP.sql` | Yes | Base definition exists; must reconcile with all later consumers |
| `public.electrician_applications` | `COMPLETE_DATABASE_SETUP.sql` | Yes | Base definition exists |
| `public.electrician_profiles` | `COMPLETE_DATABASE_SETUP.sql` | Yes | Base definition exists; identity extension is migration-managed |
| `public.job_offers` | `COMPLETE_DATABASE_SETUP.sql` | Yes | Base definition exists |
| `public.srk_admin_users` | `COMPLETE_DATABASE_SETUP.sql` | Yes | Base definition exists |
| `auth.users` | Supabase-managed Auth schema | Yes | Must be supplied by disposable Supabase environment |
| `public.srk_is_admin()` | Setup SQL / legacy portal schema | For dependent migrations | Exact function exists in source; versioned placement unresolved |
| `public.is_srk_admin()` | Setup SQL / consolidated setup SQL | For dependent migrations | Separate function exists in source; versioned placement unresolved |
| `pgcrypto` / `gen_random_uuid()` | Setup SQL | Yes | Extension/bootstrap requirement; local config absent |

This inventory is intentionally limited to the objects directly established by the reviewed baseline artifacts and the named migration consumers. It is not a complete catalog of all dependencies across all 87 migrations.

## Required dependency order (source-backed, provisional)

1. Start an isolated disposable Supabase/PostgreSQL environment that supplies the managed `auth` schema and roles.
2. Apply an owner-approved canonical base schema for the five public base tables above, including the initial RLS state and indexes.
3. Introduce both Admin helper functions with their exact source definitions and reviewed grants. Do not alias one function name to the other.
4. Apply customer ownership migration before the combined customer/Admin booking read policy.
5. Apply electrician identity-linking migration before GPS support that writes `auth_user_id`.
6. Apply GPS support before the later replacement of the Admin approval RPC.
7. Apply the initial assigned-offer map RPC before the quote workflow migration that replaces its return shape.
8. Resolve `amount_paid` availability before any earlier commission/quote consumer or column-level grant references it.
9. Reconcile malformed migration filenames and actual migration ledger before selecting a numbered execution order.
10. Only after all preceding gates are approved, run a full disposable replay and the complete pgTAP suite.

## Blocking decisions — do not guess

### A. Canonical base provenance

The consolidated setup SQL is a useful source artifact, but the repository does not establish that it is the exact schema used to create the current remote database or the intended clean-install baseline. Obtain owner-approved baseline provenance or a schema-only export before promoting it into a versioned baseline.

### B. Admin helper introduction

Both helper definitions exist in setup SQL, but several numbered migrations call them before any clear versioned introduction in the chain. Decide and document their canonical baseline placement and grants.

### C. `amount_paid` ordering

The base setup table does not declare `amount_paid`. The later restore migration adds it at version `20261116200000`, while earlier commission and quote sources consume it. The clean-install design must make the column available before those consumers, but its authoritative deployment lineage and intended migration history must be reconciled before changing versioned files.

### D. Migration history and filenames

The two legacy filenames beginning `20261109_` are not valid 14-digit migration versions. Their correct versions cannot be inferred from the filename text. Compare with the authoritative migration ledger before renaming, merging, deleting, or resequencing.

### E. Supabase local configuration

The audited PR tree has no `supabase/config.toml`. A supported local Supabase harness cannot be claimed ready until this configuration and required local services are reviewed.

## Validation plan after approval

- Create a disposable local Supabase project only; no hosted credentials.
- Capture tool versions and exact source commit.
- Run static migration preflight.
- Reset/replay the full chain on the disposable database.
- Run all 32 pgTAP SQL tests and collect complete logs.
- Inspect resulting schema, functions, policies, and grants against the approved contract.
- Repeat from a fresh disposable database to demonstrate reproducibility.

## Explicit non-claims

- This document does not prove PostgreSQL syntax validity.
- It does not prove a full migration replay succeeds.
- It does not prove any pgTAP test passes.
- It does not establish Production parity or authorize remote history repair.
- No SQL has been executed and no database has been changed by creating this document.
