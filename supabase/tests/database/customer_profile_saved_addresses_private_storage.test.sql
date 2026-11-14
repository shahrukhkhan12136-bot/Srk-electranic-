begin;
select plan(27);
select has_table('public','srk_customer_profiles','customer profile table exists');
select has_table('public','srk_customer_saved_addresses','saved address table exists');
select ok((select relrowsecurity from pg_class where oid='public.srk_customer_profiles'::regclass),'customer profile table has RLS enabled');
select ok((select relrowsecurity from pg_class where oid='public.srk_customer_saved_addresses'::regclass),'saved address table has RLS enabled');
select ok(not has_table_privilege('authenticated','public.srk_customer_profiles','SELECT') and not has_table_privilege('authenticated','public.srk_customer_saved_addresses','SELECT'),'customer private tables are not directly readable by authenticated clients');
select has_function('public','srk_customer_get_my_profile',array[]::text[],'customer profile read RPC exists');
select has_function('public','srk_customer_list_my_saved_addresses',array[]::text[],'saved address list RPC exists');
select has_function('public','srk_customer_save_my_address',array['uuid','text','text','text','text','text','text','text','double precision','double precision','boolean'],'saved address upsert RPC exists');
select has_function('public','srk_customer_delete_my_saved_address',array['uuid'],'saved address delete RPC exists');
select ok(has_function_privilege('authenticated','public.srk_customer_get_my_profile()','EXECUTE') and not has_function_privilege('anon','public.srk_customer_get_my_profile()','EXECUTE'),'profile RPC is authenticated-only');
select ok(has_function_privilege('authenticated','public.srk_customer_list_my_saved_addresses()','EXECUTE') and not has_function_privilege('anon','public.srk_customer_list_my_saved_addresses()','EXECUTE'),'saved address list RPC is authenticated-only');
select ok(has_function_privilege('authenticated','public.srk_customer_save_my_address(uuid,text,text,text,text,text,text,text,double precision,double precision,boolean)','EXECUTE') and not has_function_privilege('anon','...[truncated]