# GPT-2 — Current-head migration replay gate recheck — 16 Nov 2026

**Repository:** `shahrukhkhan12136-bot/Srk-electranic-`  
**Branch:** `feat/customer-login-first-dashboard-20261114`  
**PR:** #8 — OPEN / DRAFT / NOT MERGED  
**Audited head:** `b32fa84ff9c1c71c7eec4b9d47536bb6478830ab`  
**Scope:** read-only source verification. No database connection/query, SQL execution, migration replay, DDL, workflow dispatch, merge, deployment, or Production operation.

## 1. Re-verified amount_paid order gate

Current source still shows:

- `SUPABASE_SCHEMA.sql` / starter `service_bookings` definition does not declare `amount_paid`.
- `20261109003000_secure_commission_reporting.sql` reads `amount_paid` in its report RPCs and executes the immediate column-level statement:
  `GRANT UPDATE (status, quoted_amount, amount_paid, payment_status) ON TABLE public.service_bookings TO authenticated;`
- `20261116200000_restore_service_bookings_amount_paid.sql` is the explicit source introduction and adds nullable `numeric(12,2)` plus a nonnegative CHECK marked `NOT VALID`.

A column-level GRANT cannot name a missing column. Therefore, **if the approved clean-install baseline omits amount_paid**, replay reaches an earlier consumer before the late ADD COLUMN migration. This is a source-level, high-confidence ordering blocker; no runtime reproduction was performed. The late migration does not by itself prove the historical deployed column definition or repair an earlier replay failure.

## 2. Admin helper bootstrap gate

The inspected setup SQL defines the legacy `public.srk_is_admin()` helper. The consolidated setup's later Admin compatibility section also defines `public.is_srk_admin()`, which is the name called by early branch migrations, including booking-read policy, GPS, commission-reporting and wallet migrations.

The current source documentation records no separate authoritative introducing migration for `public.is_srk_admin()`. These are distinct function names and must not be treated as aliases. A canonical baseline/replay plan must specify the approved helper definition and ensure it exists before dependent policies/functions execute.

## 3. Duplicate migration version gate

The current migration tree still contains two different SQL files with the same 8-digit `20261109` prefix:

- `20261109_allow_quote_approval_booking_states.sql`
- `20261109_electrician_inspection_quotes_and_service_only_commission.sql`

Repository source history does not establish the authoritative remote Supabase migration-ledger identity/order. No rename, delete, merge, resequence, or remote history repair is authorized by this audit.

## 4. Safe decision

A clean disposable replay is **BLOCKED** until all of the following are established:

1. Approved canonical starter baseline and provenance.
2. An approved placement for `public.is_srk_admin()` before its earliest consumer.
3. A baseline/order that makes `service_bookings.amount_paid` exist before the earlier column-level GRANT and other consumers.
4. Owner/DBA-supplied sanitized evidence resolving duplicate `20261109` migration history.
5. A pinned, isolated local PostgreSQL/Supabase + pgTAP harness.

Do not use the existing remote-schema-export workflow as a substitute for a disposable local replay. Do not connect a test job to Production or use live customer/payment data.

## 5. Checklist and execution status

- GPT-2 checklist remains **27/39 = 69%**; this audit documents blockers and does not close an implementation item.
- PostgreSQL/pgTAP: **NOT RUN**.
- Production schema/history: **NOT ACCESSED in this audit**.
- PR #8 remains **OPEN / DRAFT / UNMERGED**.
- No application source, numbered SQL migration, CI workflow, database, payment provider, or deployment was changed.
