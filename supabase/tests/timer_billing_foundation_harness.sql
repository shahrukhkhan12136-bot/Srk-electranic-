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

create or replace function auth.uid()
returns uuid
language sql
stable
as $function$
  select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid
$function$;

create table if not exists public.service_bookings (
  id uuid primary key default gen_random_uuid(),
  customer_user_id uuid,
  assigned_electrician_id uuid,
  status text not null default 'assigned'
);

create table if not exists public.electrician_profiles (
  id uuid primary key,
  user_id uuid,
  auth_user_id uuid,
  active boolean not null default true,
  verification_status text not null default 'approved'
);

create table if not exists public.job_offers (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null references public.service_bookings(id),
  electrician_id uuid not null references public.electrician_profiles(id),
  status text not null
);

-- Prove that the migration's reverse FK and the bill->booking FK can coexist:
-- insert booking, insert bill referencing booking, then link booking to bill.
