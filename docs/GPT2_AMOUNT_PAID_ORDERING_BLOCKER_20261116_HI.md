# GPT-2 — `amount_paid` migration-order blocker — 16 Nov 2026

**Branch:** `feat/customer-login-first-dashboard-20261114`  
**PR:** #8 (Draft; unmerged)  
**Review basis:** read-only GitHub source inspection at PR head `7ad22ced5824397e193a6477346d6b6d6580162e`.  
**Scope:** source dependency finding only. No SQL execution, database connection, migration replay/repair, DDL, deployment, or application-source change.

## Finding

The current branch's starter schema and migration chronology do not yet provide a safe clean-replay path for `public.service_bookings.amount_paid`.

### Evidence

1. `SUPABASE_SCHEMA.sql` creates `public.service_bookings` but its complete visible column list does not include `amount_paid`.
2. `supabase/migrations/20261109_electrician_inspection_quotes_and_service_only_commission.sql` references `NEW.amount_paid` in its commission trigger function (including negative-value validation and completed/paid commission calculation).
3. `supabase/migrations/20261109003000_secure_commission_reporting.sql`:
   - reads `amount_paid` in the Admin commission report and electrician earnings RPCs; and
   - contains the immediate column-level statement:
     `GRANT UPDATE (status, quoted_amount, amount_paid, payment_status) ON TABLE public.service_bookings TO authenticated;`
4. `supabase/migrations/20261114200000_customer_payment_refund_history_rpc.sql` later reads `b.amount_paid` for the customer payment-history projection.
5. The explicit column-introduction migration is `supabase/migrations/20261116200000_restore_service_bookings_amount_paid.sql`, at the end of the current migration sequence. It adds nullable `numeric(12,2)` and a nonnegative CHECK constraint marked `NOT VALID`.

## Why this blocks a clean replay

A column-level `GRANT UPDATE (amount_paid)` requires the column to exist when that statement executes. If a clean baseline is built from the inspected `SUPABASE_SCHEMA.sql` and does not separately introduce `amount_paid`, the earlier `20261109003000` migration reaches that GRANT before the late `20261116200000` migration can add the column.

The late `ADD COLUMN IF NOT EXISTS` does not repair an earlier migration-order failure. The function references also show downstream dependency on the column, but the immediate column-level GRANT is the decisive ordering gate.

## Safe resolution path

- Do not edit, rename, reorder, delete, replay, or repair already-numbered migrations based only on this source finding.
- Do not infer the original Production column definition from the later migration alone; it defines a nullable `numeric(12,2)` column, but the authoritative historical baseline and deployed lineage still need confirmation.
- Obtain the approved canonical starter-schema DDL and owner/DBA evidence for the intended `amount_paid` type, nullability, default, constraints, and deployment history.
- Then prepare an owner-reviewed disposable baseline/replay design that makes the column available before every consumer, and test it only in an isolated local PostgreSQL/Supabase environment with pinned tool versions.
- Keep Production untouched until a separate explicit approval and evidence-backed migration plan exist.

## Execution environment check

In the available runtime, Node.js `v22.16.0` and npm `10.9.2` are present. Docker, Podman, `psql`, PostgreSQL server, and Supabase CLI are unavailable. Therefore PostgreSQL migration replay and pgTAP execution could not be performed here.

## Status

- Starter-schema omission: **SOURCE CONFIRMED**.
- Earlier commission migration consumer and column-level GRANT: **SOURCE CONFIRMED**.
- Later explicit ADD COLUMN migration: **SOURCE CONFIRMED**.
- Clean replay failure: **HIGH-CONFIDENCE ORDERING BLOCKER if the approved baseline omits the column**; no runtime reproduction performed.
- Production schema/history: **NOT ACCESSED in this pass**.
- Migration or application changes: **NONE**.
- GPT-2 checklist: remains **27/39 (69%)**; this audit adds evidence but does not close a checklist item.
