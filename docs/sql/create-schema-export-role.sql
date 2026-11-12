-- SRK ELECTRONIC: least-privilege schema-only export account
-- Review before running manually in the Supabase SQL Editor as a database administrator.
-- Replace the placeholder with a unique, strong password from a password manager.
-- This role is intentionally granted NO table/column SELECT, write, ownership,
-- CREATE, replication, superuser, or BYPASSRLS privileges.

CREATE ROLE srk_schema_export_ci
  LOGIN
  PASSWORD 'REPLACE_WITH_A_UNIQUE_STRONG_PASSWORD'
  NOSUPERUSER
  NOCREATEDB
  NOCREATEROLE
  NOINHERIT
  NOREPLICATION
  NOBYPASSRLS
  CONNECTION LIMIT 1;

GRANT CONNECT ON DATABASE postgres TO srk_schema_export_ci;
GRANT USAGE ON SCHEMA public, private TO srk_schema_export_ci;

-- Make sessions read-only by default as an additional safeguard.
ALTER ROLE srk_schema_export_ci
  SET default_transaction_read_only = on;

-- Do not grant SELECT on tables, sequences, or columns.
-- The CI workflow verifies that the login cannot read rows or create/alter schema.
