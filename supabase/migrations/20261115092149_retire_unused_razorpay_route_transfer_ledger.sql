-- Retire the unused, empty Razorpay Route split-transfer ledger.
-- The current approved checklist uses the Admin-controlled payout workflow;
-- no current app page, Netlify function, Edge Function, database function,
-- trigger, or dependent object uses this future-only Route ledger.
-- Verified before removal: zero rows, no app/server source references, and
-- pg_stat_statements contained only DDL and audit/count reads (no writes).
-- DROP without CASCADE intentionally fails if a dependency is introduced.
drop table public.srk_route_transfers;
