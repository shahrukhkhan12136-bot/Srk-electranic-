begin;
select plan(12);

select ok((select relrowsecurity from pg_class where oid='public.srk_customer_profiles'::regclass),'profile table has RLS enabled');
select ok(
  not has_table_privilege('authenticated','public.srk_customer_profiles','SELECT')
  and not has_table_privilege('authenticated','public.srk_customer_profiles','INSERT')
  and not has_table_privilege('authenticated','public.srk_customer_profiles','UPDATE')
  and not has_table_privilege('authenticated','public.srk_customer_profiles','DELETE')
  and not has_table_privilege('anon','public.srk_customer_profiles','SELECT'),
  'profile table is not directly accessible to client roles; authenticated users must use owner-scoped RPCs'
);
select ok(exists(select 1 from pg_policies where schemaname='public' and tablename='srk_customer_profiles' and policyname='customers read own profile' and qual ilike '%auth.uid%'),'profile read policy is owner-scoped');
select ok(exists(select 1 from pg_policies where schemaname='public' and tablename='srk_customer_profiles' and policyname='customers update own profile' and qual ilike '%auth.uid%' and with_check ilike '%auth.uid%'),'profile update policy checks ownership before and after update');
select ok(has_function_privilege('authenticated','public.srk_customer_get_my_profile()','EXECUTE') and not has_function_privilege('anon','public.srk_customer_get_my_profile()','EXECUTE'),'profile read RPC is authenticated-only');
select ok(has_function_privilege('authenticated','public.srk_customer_update_my_profile(text,text,text)','EXECUTE') and not has_function_privilege('anon','public.srk_customer_update_my_profile(text,text,text)','EXECUTE'),'profile update RPC is authenticated-only');
select ok(position('auth.uid()' in lower(pg_get_functiondef('public.srk_customer_get_my_profile()'::regprocedure)))>0,'profile read RPC derives user identity from auth.uid');
select ok(position('auth.users' in lower(pg_get_functiondef('public.srk_customer_get_my_profile()'::regprocedure)))>0,'verified phone is sourced from Auth user record');
select ok(position('phone' in lower(pg_get_functiondef('public.srk_customer_update_my_profile(text,text,text)'::regprocedure)))=0,'profile update RPC cannot modify phone number');
select ok((select not public from storage.buckets where id='srk-customer-avatars'),'avatar bucket is private');
select ok(exists(select 1 from pg_policies where schemaname='storage' and tablename='objects' and policyname='customers upload own avatar'),'avatar upload is owner-scoped');

select * from finish();
rollback;
