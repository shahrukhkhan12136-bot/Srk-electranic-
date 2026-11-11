-- Disposable Production-shaped PostgreSQL fixture for electrician display ID migration tests.
-- Mirrors the live electrician_profiles required columns, Auth foreign keys, unique indexes,
-- status/location constraints, RLS policies and existing audit trigger contract.
\set ON_ERROR_STOP on

do $roles$
begin
  if not exists (select 1 from pg_roles where rolname = 'anon') then create role anon nologin; end if;
  if not exists (select 1 from pg_roles where rolname = 'authenticated') then create role authenticated nologin; end if;
end;
$roles$;

create schema if not exists auth;
create table auth.users (id uuid primary key);
insert into auth.users(id) values
 ('00000000-0000-0000-0000-000000000001'),
 ('00000000-0000-0000-0000-000000000002'),
 ('00000000-0000-0000-0000-000000000003'),
 ('00000000-0000-0000-0000-000000000004'),
 ('00000000-0000-0000-0000-000000000005'),
 ('00000000-0000-0000-0000-000000000006'),
 ('00000000-0000-0000-0000-000000000007'),
 ('00000000-0000-0000-0000-000000000008')
on conflict do nothing;

create or replace function auth.uid()
returns uuid language sql stable as $$ select null::uuid $$;

create table public.electrician_applications (id uuid primary key default gen_random_uuid());

create table public.electrician_profiles (
  id uuid primary key default gen_random_uuid(),
  application_id uuid unique references public.electrician_applications(id),
  display_name text not null,
  phone text not null check (phone ~ '^[0-9]{10}$'),
  state text not null,
  district text not null,
  pincode text not null check (pincode ~ '^[0-9]{6}$'),
  skills text[] not null default '{}'::text[],
  active boolean not null default false,
  created_at timestamptz default now(),
  verification_status text not null default 'pending'
    check (verification_status in ('pending','approved','rejected','suspended')),
  auth_user_id uuid references auth.users(id) on delete set null,
  user_id uuid references auth.users(id) on delete set null,
  location_lat double precision,
  location_lng double precision,
  constraint electrician_profiles_location_pair_check
    check ((location_lat is null) = (location_lng is null)),
  constraint electrician_profiles_location_range_check
    check (location_lat is null or
      (location_lat between -90 and 90 and location_lng between -180 and 180))
);

create unique index electrician_auth_user_unique
  on public.electrician_profiles(auth_user_id) where auth_user_id is not null;
create index electrician_profiles_user_id_idx
  on public.electrician_profiles(user_id) where user_id is not null;
create index electrician_approved_search_idx
  on public.electrician_profiles(state,district,pincode)
  where active is true and verification_status='approved';

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

-- Existing Production AFTER trigger contract; a no-op body isolates the ID migration.
create or replace function public.srk_capture_admin_audit_event()
returns trigger language plpgsql as $audit$
begin
  return coalesce(new, old);
end;
$audit$;
create trigger srk_audit_electrician_profiles
after insert or update or delete on public.electrician_profiles
for each row execute function public.srk_capture_admin_audit_event();

-- Seed one already-approved, active, unambiguously Auth-linked legacy profile.
insert into public.electrician_profiles
  (display_name,phone,state,district,pincode,verification_status,active,user_id,auth_user_id)
values
  ('Fixture Electrician','9000000001','Uttar Pradesh','Balrampur','271861',
   'approved',true,'00000000-0000-0000-0000-000000000001',
   '00000000-0000-0000-0000-000000000001');
