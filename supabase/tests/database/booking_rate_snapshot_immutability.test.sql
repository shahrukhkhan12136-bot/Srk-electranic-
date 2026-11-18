begin;
select plan(8);

select has_function(
  'public',
  'srk_guard_booking_rate_snapshot_immutable',
  array[]::text[],
  'booking rate snapshot guard function exists'
);

select ok(
  exists (
    select 1
    from pg_trigger t
    join pg_class c on c.oid=t.tgrelid
    join pg_namespace n on n.oid=c.relnamespace
    where n.nspname='public'
      and c.relname='service_bookings'
      and t.tgname='srk_guard_booking_rate_snapshot_immutable'
      and not t.tgisinternal
      and (t.tgtype & 2)=2
      and (t.tgtype & 16)=16
  ),
  'write-once guard runs before updates on service_bookings'
);

select ok(
  position('selected_category' in pg_get_functiondef(
    'public.srk_guard_booking_rate_snapshot_immutable()'::regprocedure))>0
  and position('selected_duration_hours' in pg_get_functiondef(
    'public.srk_guard_booking_rate_snapshot_immutable()'::regprocedure))>0
  and position('selected_rate_tier' in pg_get_functiondef(
    'public.srk_guard_booking_rate_snapshot_immutable()'::regprocedure))>0,
  'guard protects category, duration and rate tier'
);

select ok(
  position('estimated_labour_paise' in pg_get_functiondef(
    'public.srk_guard_booking_rate_snapshot_immutable()'::regprocedure))>0
  and position('estimate_rate_card_version' in pg_get_functiondef(
    'public.srk_guard_booking_rate_snapshot_immutable()'::regprocedure))>0,
  'guard protects the immutable amount and catalogue version'
);

select ok(
  position('BOOKING_RATE_SNAPSHOT_IS_IMMUTABLE' in pg_get_functiondef(
    'public.srk_guard_booking_rate_snapshot_immutable()'::regprocedure))>0,
  'guard rejects attempts to rewrite an existing booking snapshot'
);

select ok(
  coalesce((select p.prosecdef and p.proconfig @> ARRAY['search_path=""']
    from pg_proc p
    where p.oid='public.srk_guard_booking_rate_snapshot_immutable()'::regprocedure),false),
  'guard is SECURITY DEFINER with an empty search_path'
);

select ok(
  not has_function_privilege('anon',
    'public.srk_guard_booking_rate_snapshot_immutable()','EXECUTE')
  and not has_function_privilege('authenticated',
    'public.srk_guard_booking_rate_snapshot_immutable()','EXECUTE'),
  'guard function cannot be invoked directly by client roles'
);

select ok(
  not exists (
    select 1
    from pg_proc p
    where p.oid='public.srk_guard_booking_rate_snapshot_immutable()'::regprocedure
      and p.proacl is not null
      and exists (
        select 1 from aclexplode(p.proacl) a
        where a.grantee in (0, (select oid from pg_roles where rolname='anon'),
                               (select oid from pg_roles where rolname='authenticated'))
          and a.privilege_type='EXECUTE'
      )
  ),
  'PUBLIC, anon and authenticated have no direct execute grant'
);

select * from finish();
rollback;
