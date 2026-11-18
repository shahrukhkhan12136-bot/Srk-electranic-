begin;
select plan(12);

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

-- Exercise the trigger against a real row, not only its function definition.
insert into public.service_bookings(
  id,selected_category,selected_duration_hours,selected_rate_tier,
  estimated_labour_paise,estimate_rate_card_version,booking_status
) values (
  '00000000-0000-4000-8000-000000000001',
  'electrical_assistant',8,'electrical_assistant',120000,NULL,'pending'
);

select throws_ok(
  $q$update public.service_bookings
      set selected_category='expert_electrician'
    where id='00000000-0000-4000-8000-000000000001$q$,
  '42501',
  'BOOKING_RATE_SNAPSHOT_IS_IMMUTABLE',
  'changing the saved category is rejected'
);

select throws_ok(
  $q$update public.service_bookings
      set estimated_labour_paise=999999
    where id='00000000-0000-4000-8000-000000000001$q$,
  '42501',
  'BOOKING_RATE_SNAPSHOT_IS_IMMUTABLE',
  'changing the saved amount is rejected'
);

select is(
  (select selected_category from public.service_bookings
    where id='00000000-0000-4000-8000-000000000001'),
  'electrical_assistant',
  'rejected snapshot changes leave the original category intact'
);

select lives_ok(
  $q$update public.service_bookings
      set booking_status='confirmed'
    where id='00000000-0000-4000-8000-000000000001$q$,
  'non-snapshot booking fields remain updateable'
);

select * from finish();
rollback;
