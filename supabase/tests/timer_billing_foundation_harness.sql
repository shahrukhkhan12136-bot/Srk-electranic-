-- Disposable PostgreSQL harness for the additive timer-billing foundation migration.
-- This is intentionally a minimal synthetic baseline, NOT a replica of Production.
-- Run only in an ephemeral PostgreSQL database (GitHub Actions service container).

do $roles$
begin
  if not exists (select 1 from pg_roles where rolname = 'anon') then create role anon nologin; end if;
  if not exists (select 1 from pg_roles where rolname = 'authenticated') then create role authenticated nologin; end if;
  if not exists (select 1 from pg_roles where rolname = 'service_role') then create role service_role nologin; end if;
end
$roles$;

create schema if not exists auth;
create table if not exists auth.users (
  id uuid primary key
);

create table if not exists public.service_bookings (
  id uuid primary key default gen_random_uuid()
);

-- Prove that the migration's reverse FK and the bill->booking FK can coexist:
-- insert booking, insert bill referencing booking, then link booking to bill.
