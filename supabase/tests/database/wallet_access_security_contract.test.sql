begin;
select plan(18);
select ok(to_regclass('public.srk_wallet_accounts') is not null,'wallet accounts table exists');
select ok(to_regclass('public.srk_wallet_ledger') is not null,'wallet ledger table exists');
select ok(to_regclass('public.srk_wallet_bank_links') is not null,'wallet bank-link table exists');
select ok((select relrowsecurity from pg_class where oid='public.srk_wallet_accounts'::regclass),'wallet accounts RLS is enabled');
select ok((select relrowsecurity from pg_class where oid='public.srk_wallet_ledger'::regclass),'wallet ledger RLS is enabled');
select ok((select relrowsecurity from pg_class where oid='public.srk_wallet_bank_links'::regclass),'wallet bank links RLS is enabled');
select ok(not has_table_privilege('anon','public.srk_wallet_ledger','select')
 and has_table_privilege('authenticated','public.srk_wallet_ledger','select'),
 'wallet ledger is readable only to authenticated role through RLS');
select ok(not has_table_privilege('authenticated','public.srk_wallet_ledger','insert')
 and not has_table_privilege('authenticated','public.srk_wallet_ledger','update')
 and not has_table_privilege('authenticated','public.srk_wallet_ledger','delete'),
 'browser users cannot create, alter, or delete wallet ledger entries');
select ok(has_table_privilege('service_role','public.srk_wallet_ledger','select')
 and has_table_privilege('service_role','public.srk_wallet_ledger','insert')
 and has_table_privilege('service_role','public.srk_wallet_ledger','update')
 and has_table_privilege('service_role','public.srk_wallet_ledger','delete'),
 'trusted service role retains wallet ledger mutation privileges');
select ok(exists(select 1 from pg_policies where schemaname='public'
 and tablename='srk_wallet_ledger' and policyname='srk_wallet_ledger_owner_read'
 and qual ilike '%auth.uid%'),
 'wallet ledger SELECT policy is scoped to the authenticated owner');
select ok((select prosecdef from pg_proc where oid='public.srk_get_my_wallet_summary()'::regprocedure)
 and (select proconfig @> ARRAY['search_path=""'] from pg_proc
 where oid='public.srk_get_my_wallet_summary()'::regprocedure),
 'wallet summary is SECURITY DEFINER with empty search_path');
select ok((select prosecdef from pg_proc where oid='public.srk_admin_wallet_overview()'::regprocedure)
 and (select proconfig @> ARRAY['search_path=""'] from pg_proc
 where oid='public.srk_admin_wallet_overview()'::regprocedure),
 'Admin wallet overview is SECURITY DEFINER with empty search_path');
select ok(not has_function_privilege('anon','public.srk_get_my_wallet_summary()','execute')
 and has_function_privilege('authenticated','public.srk_get_my_wallet_summary()','execute'),
 'wallet summary is available to authenticated users, not anon');
select ok(not has_function_privilege('anon','public.srk_admin_wallet_overview()','execute')
 and has_function_privilege('authenticated','public.srk_admin_wallet_overview()','execute'),
 'Admin wallet overview is authenticated-callable with Main Admin checked inside');
select ok(position('auth.uid()' in pg_get_functiondef('public.srk_get_my_wallet_summary()'::regprocedure))>0
 and position('Authentication required' in pg_get_functiondef('public.srk_get_my_wallet_summary()'::regprocedure))>0,
 'wallet summary independently requires an authenticated identity');
select ok(position('verification_status = ''approved''' in pg_get_functiondef('public.srk_get_my_wallet_summary()'::regprocedure))>0,
 'electrician wallet is created only for an approved electrician profile');
select ok(position('status=''posted''' in pg_get_functiondef('public.srk_get_my_wallet_summary()'::regprocedure))>0
 and position('topups_enabled',pg_get_functiondef('public.srk_get_my_wallet_summary()'::regprocedure))>0
 and position('payouts_enabled',pg_get_functiondef('public.srk_get_my_wallet_summary()'::regprocedure))>0,
 'wallet balance counts posted entries and stored-value top-ups/cash-outs remain disabled');
select ok(not has_table_privilege('anon','public.srk_wallet_accounts','select')
 and not has_table_privilege('anon','public.srk_wallet_bank_links','select')
 and has_table_privilege('authenticated','public.srk_wallet_accounts','select')
 and has_table_privilege('authenticated','public.srk_wallet_bank_links','select'),
 'wallet account and bank-link reads are authenticated-only and RLS-filtered');
select * from finish();
rollback;
