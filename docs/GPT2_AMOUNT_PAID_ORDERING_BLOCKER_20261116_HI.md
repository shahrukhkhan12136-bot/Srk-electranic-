# GPT-2 — Reassessment of the `amount_paid` ordering finding — 16 Nov 2026

**Branch:** `chore/pr8-replay-audit-20261116-v2` (GPT-2 audit branch)  
**PR:** #8 remains open and unmerged.  
**Scope:** source-only correction to the earlier finding. No SQL execution, database connection, migration replay/repair, DDL, deployment, or Production access.

## Corrected finding

The earlier claim that `20261109003000_secure_commission_reporting.sql` reaches a column-level GRANT before `amount_paid` exists was **incorrect**.

Full-file inspection confirms that the first DDL statement in `20261109003000_secure_commission_reporting.sql` is:

```sql
alter table public.service_bookings
  add column if not exists amount_paid numeric(12,2);
```

That statement occurs before the migration's Admin commission/earnings RPC definitions and before:

```sql
grant update (status, quoted_amount, amount_paid, payment_status)
on table public.service_bookings to authenticated;
```

Therefore this migration itself supplies the column before its own consumers. The later `20261116200000_restore_service_bookings_amount_paid.sql` is an idempotent restoration/constraint migration, not the first visible introduction.

## Related quote-function nuance

`20261109_electrician_inspection_quotes_and_service_only_commission.sql` defines `public.srk_calculate_booking_commission()`, whose PL/pgSQL body reads `NEW.amount_paid`. However, this quote migration does not attach that function to a trigger. The checked-in starter setups instead attach `srk_booking_commission_trigger` to the older `srk_calculate_commission_on_completion()` function.

The actionable source defect is therefore **commission trigger wiring**, not a proven missing-column replay failure. The old trigger calculates from `quoted_amount`; the new service-only function remains unattached. The updated main audit report documents the report-versus-payout implication and safe follow-up path.

## Status

- Starter setup files omit `amount_paid`: **SOURCE CONFIRMED**.
- `20261109003000` adds `amount_paid` before its own consumers: **SOURCE CONFIRMED**.
- `20261116200000` is later and idempotent: **SOURCE CONFIRMED**.
- Earlier missing-column GRANT blocker: **WITHDRAWN**.
- Commission trigger binding gap: **SOURCE CONFIRMED**, see main audit report section 15.
- PostgreSQL replay / pgTAP: **NOT RUN**.
- Production schema/history: **NOT ACCESSED**.
- No numbered migration, PR branch, or database changed for this reassessment.
