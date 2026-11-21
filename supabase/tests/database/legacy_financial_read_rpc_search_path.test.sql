begin;
select plan(6);

select ok(to_regprocedure('public.srk_admin_commission_report()') is not null,
  'legacy admin commission report exists');
select ok((select prosecdef from pg_proc where oid='public.srk_admin_commission_report()'::regprocedure),
  'legacy admin commission report remains SECURITY DEFINER');
select ok(coalesce((select proconfig @> ARRAY['search_path=pg_catalog, public, auth, pg_temp']
  from pg_proc where oid='public.srk_admin_commission_report()'::regprocedure),false),
  'legacy admin commission report pins a trusted search_path');

select ok((select prosecdef from pg_proc where oid='public.srk_get_my_wallet_summary()'::regprocedure)
  and (select proconfig @> ARRAY['search_path=pg_catalog, public, auth, pg_temp']
  from pg_proc where oid='public.srk_get_my_wallet_summary()'::regprocedure),
  'customer/electrician wallet summary is SECURITY DEFINER with pinned search_path');

select ok((select prosecdef from pg_proc where oid='public.srk_admin_wallet_overview()'::regprocedure)
  and (select proconfig @> ARRAY['search_path=pg_catalog, public, auth, pg_temp']
  from pg_proc where oid='public.srk_admin_wallet_overview()'::regprocedure),
  'admin wallet overview is SECURITY DEFINER with pinned search_path');

select ok(has_function_privilege('authenticated','public.srk_admin_wallet_overview()','EXECUTE')
  and not has_function_privilege('anon','public.srk_admin_wallet_overview()','EXECUTE'),
  'admin wallet overview is not executable by anon');

select * from finish();
rollback;
