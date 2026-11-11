-- Catalog/security assertions for permanent electrician display IDs.
-- Run after 20261112100000_permanent_electrician_display_ids.sql in an isolated fixture.

do $test$
declare
  v_function oid;
begin
  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'public'
      and table_name = 'electrician_profiles'
      and column_name = 'electrician_display_id'
      and data_type = 'text'
  ) then
    raise exception 'Missing electrician_profiles.electrician_display_id text column';
  end if;

  if not exists (
    select 1 from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public'
      and c.relname = 'electrician_display_id_seq'
      and c.relkind = 'S'
  ) then
    raise exception 'Missing permanent electrician display ID sequence';
  end if;

  if not exists (
    select 1 from pg_indexes
    where schemaname = 'public'
      and indexname = 'electrician_profiles_display_id_uidx'
      and indexdef ilike '%unique%'
  ) then
    raise exception 'Missing unique index for electrician display IDs';
  end if;

  if not (
    select c.relrowsecurity
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relname = 'electrician_profiles'
  ) then
    raise exception 'electrician_profiles must keep RLS enabled';
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'electrician_profiles'
      and cmd = 'UPDATE'
      and coalesce(qual, '') ilike '%is_srk_admin%'
      and coalesce(with_check, '') ilike '%is_srk_admin%'
  ) then
    raise exception 'Profile approval/activation must remain Admin-only under RLS';
  end if;

  if not exists (
    select 1 from pg_trigger t
    join pg_class c on c.oid = t.tgrelid
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public'
      and c.relname = 'electrician_profiles'
      and t.tgname = 'srk_assign_electrician_display_id_trigger'
      and not t.tgisinternal
  ) then
    raise exception 'Missing electrician display ID issuance trigger';
  end if;

  select p.oid into v_function
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public'
    and p.proname = 'srk_assign_electrician_display_id';

  if v_function is null then
    raise exception 'Missing electrician display ID trigger function';
  end if;

  if not (select prosecdef from pg_proc where oid = v_function) then
    raise exception 'ID trigger function must execute with its controlled owner privileges';
  end if;

  if not exists (
    select 1 from pg_proc p
    where p.oid = v_function
      and p.proconfig @> array['search_path=""']
  ) then
    raise exception 'ID trigger function must pin an empty search_path';
  end if;

  if has_sequence_privilege('anon', 'public.electrician_display_id_seq', 'USAGE')
     or has_sequence_privilege('authenticated', 'public.electrician_display_id_seq', 'USAGE') then
    raise exception 'Client roles must not be able to consume the ID sequence';
  end if;

  if has_function_privilege('anon', v_function, 'EXECUTE')
     or has_function_privilege('authenticated', v_function, 'EXECUTE') then
    raise exception 'Client roles must not execute the trigger function directly';
  end if;
end;
$test$;
