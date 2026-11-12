# Isolated Supabase migration CI

The workflow `.github/workflows/supabase-schema-ci.yml` is intentionally **manual-only**. It exports a schema-only snapshot from the live database into the temporary GitHub Actions runner, restores that snapshot into a fresh local Supabase stack, applies the five feature-branch migrations that are newer than the production migration baseline, and runs database lint plus smoke checks.

## Data and production safety

- The workflow does not request or export table rows, Auth users, Storage objects, or payment/customer records.
- The schema dump is written only under `RUNNER_TEMP`; it is not committed or uploaded as an artifact.
- All migration application and linting happen against the temporary local Supabase stack in the GitHub runner.
- The workflow never runs `db push`, `db reset --remote`, `apply_migration`, or any production DDL.
- The workflow is manual-only because this repository is public and the export needs a database connection credential.

## Credential requirement

The workflow expects a repository Actions secret named `SUPABASE_DB_URL`.

**Do not use the production `postgres`, `supabase_admin`, `service_role`, or other privileged credential for this secret.** The live project currently has a `supabase_read_only_user` role, but it has `BYPASSRLS`; it is therefore not an acceptable least-privilege CI credential for this public repository. Do not use it here.

Before the first run, create and verify a dedicated database login intended only for schema introspection/export. It must not be a superuser, must not have `BYPASSRLS`, and must not be able to read customer/payment table rows. Confirm that it can perform a schema-only dump. Store its PostgreSQL connection URI as the GitHub Actions repository secret `SUPABASE_DB_URL` (Settings → Secrets and variables → Actions → New repository secret). Never paste the URI into chat, source files, workflow YAML, issue comments, or logs.

If a suitably restricted export role cannot be configured, do not run this workflow with a privileged production credential. We can instead use a locally executed schema export and transfer only the DDL snapshot through a private channel.

## Run

1. Confirm the restricted `SUPABASE_DB_URL` secret is configured.
2. Open GitHub → Actions → **Supabase isolated schema migration test**.
3. Choose **Run workflow** on `feature/platform-fee-cash-online-cycle`.
4. Review the run logs. A successful migration-application/lint run is not a substitute for the separate business-logic tests for cash/online settlement, refunds, idempotency, and concurrent bookings.

The five pending migrations are explicitly listed in the workflow. Update that list only after checking the live production migration history and the feature branch migration files.
