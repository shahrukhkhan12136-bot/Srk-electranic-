-- Disposable PostgreSQL fixture for electrician display ID migration tests.
\set ON_ERROR_STOP on

do $roles$
begin
  if not exists (select 1 from pg_roles where rolname = 'anon') then create role anon nologin; end if;
  if not exists (select 1 from pg_roles where rolname = 'authenticated') then create role authenticated nologin; end if;
end;
$roles$;

create schema if not exists auth;
create or replace function auth.uid()
returns uuid language sql stable as $$ select null::uuid $$;

create table public.electrician_profiles (
  id uuid primary key default gen_random_uuid(),
  verification_status text not null default 'pending',
  active boolean not null default false,
  user_id uuid,
  auth_user_id uuid,
  electrician_display_id text
);

alter table public.electrician_profiles enable row level security;

create or replace function public.is_srk_admin()
returns boolean language sql stable as $$ select false $$;

create policy electrician_and_admin_read_profiles
  on public.electrician_profiles for select to authenticated
  using (auth_user_id = auth.uid() or user_id = auth.uid() or public.is_srk_admin());

create policy srk_admin_update_profiles
  on public.electrician_profiles for update to authenticated
  using (public.is_srk_admin())
  with check (public.is_srk_admin());

-- Existing approved + active + Auth-linked rows are backfilled by the migration.
insert into public.electrician_profiles (verification_status, active, user_id)
values ('approved', true, '00000000-0000-0000-0000-000000000001');
