begin;

do $guard$
declare
  v_bookings bigint;
  v_electricians bigint;
  v_history bigint;
begin
  select count(*) into v_bookings from public.bookings;
  select count(*) into v_electricians from public.electricians;
  select count(*) into v_history from public.booking_status_history;

  if v_bookings <> 0 or v_electricians <> 0 or v_history <> 0 then
    raise exception 'Legacy tables are not empty; aborting cleanup (bookings %, electricians %, history %)',
      v_bookings, v_electricians, v_history;
  end if;

  if exists (
    select 1
    from pg_proc p
    join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public'
      and p.prokind in ('f','p')
      and (
        pg_get_functiondef(p.oid) ilike '%public.bookings%'
        or pg_get_functiondef(p.oid) ilike '%public.electricians%'
        or pg_get_functiondef(p.oid) ilike '%public.booking_status_history%'
      )
  ) then
    raise exception 'A public function still references a legacy table; aborting cleanup';
  end if;

  if exists (
    select 1
    from information_schema.view_table_usage
    where table_schema='public'
      and table_name in ('bookings','electricians','booking_status_history')
  ) then
    raise exception 'A public view still references a legacy table; aborting cleanup';
  end if;
end
$guard$;

drop table public.booking_status_history;
drop table public.bookings;
drop table public.electricians;

commit;