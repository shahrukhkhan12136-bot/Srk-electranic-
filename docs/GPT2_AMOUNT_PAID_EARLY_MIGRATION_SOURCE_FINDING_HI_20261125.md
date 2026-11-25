# SRK ELECTRONIC — Follow-up: early amount_paid migration source found on isolated branch

**Audit date:** 25 November 2026  
**Target:** Main Supabase project `gnqhoaqatmoiwwhgzkgm`  
**Scope:** Read-only Git source inspection. No database or migration execution.

## Finding

A previously documented replay-order blocker has a concrete candidate source file on a separate Git branch:

- Branch: `feat/ai-rate-management-foundation-20261118`
- File: `supabase/migrations/20261109002500_restore_service_bookings_amount_paid_before_financial_grants.sql`
- File blob SHA: `d65b814dfdf85b3ef38dd054f35d9e66b161f8cc`
- Introducing commit: `a1c8ccdb9d8051031816de2b2f392836d80db606`
- Commit message: `Add amount_paid before financial column grant`
- Commit date: 18 November 2026

The SQL adds `public.service_bookings.amount_paid numeric(12,2)` with `ADD COLUMN IF NOT EXISTS`, and conditionally adds the non-negative CHECK constraint as `NOT VALID`. Its filename timestamp `20261109002500` sorts before `20261109003000_secure_commission_reporting.sql`, the earlier column-level UPDATE grant consumer identified by the prior replay audit.

## Branch-presence check

The candidate file is **absent** from each of the following refs inspected:

- `main`
- `work/mobile-customer-technician-integration-20261125`
- `work/admin-worker-payout-web-integration-20261125`
- `feature/master-customer-workday-ui-20261121`
- `feature/master-gst-accounting-20261121`

It is present on the isolated AI rate-management branch. The introducing commit is unsigned (GitHub reports `verified: false`, reason `unsigned`). No open/closed pull request with that exact head branch was found in the inspected PR listing.

## Interpretation

This is useful source-recovery evidence and refines the earlier statement that no early numbered migration was visible anywhere in the inspected source. A candidate migration does exist, and its timestamp/SQL are specifically designed to place `amount_paid` before the financial column grant.

However, it **does not clear the production replay blocker**:

1. It is not present in the current mobile or admin integration branches.
2. Its presence on one unsigned, isolated branch does not establish that it was approved, merged, deployed, or recorded in Main's 539-row migration history.
3. The exact Main remote migration version list and deployed SQL body remain unavailable in this read-only Git inspection.
4. The existing later migration `20261116200000_restore_service_bookings_amount_paid.sql` remains in other branch histories; idempotent SQL does not prove the correct remote migration-ledger history or authorize applying both entries.

## Safe next action

Preserve the candidate file and its provenance. Compare its exact version and body against the sanitized Main migration ledger and any approved migration backup. Only after that comparison should the owner/DBA decide whether it belongs in the canonical source branch or whether a different repair is needed.

**No cherry-pick, copy, rename, migration-history repair, SQL execution, merge, deploy, or Main DB write was performed.**
