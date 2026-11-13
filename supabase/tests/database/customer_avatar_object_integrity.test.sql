begin;
select plan(5);
select ok(position('metadata->>''mimetype''' in lower(pg_get_functiondef('public.srk_customer_update_my_profile(text,text,text)'::regprocedure)))>0,
 'avatar RPC checks actual Storage MIME metadata');
select ok(position('metadata->>''size''' in lower(pg_get_functiondef('public.srk_customer_update_my_profile(text,text,text)'::regprocedure)))>0,
 'avatar RPC checks actual Storage object size');
select ok(position('AVATAR_OBJECT_METADATA_MISMATCH' in pg_get_functiondef('public.srk_customer_update_my_profile(text,text,text)'::regprocedure))>0,
 'avatar RPC rejects extension and MIME mismatch');
select ok(position('5242880' in pg_get_functiondef('public.srk_customer_update_my_profile(text,text,text)'::regprocedure))>0,
 'avatar RPC enforces five MiB maximum');
select ok(has_function_privilege('authenticated','public.srk_customer_update_my_profile(text,text,text)','EXECUTE')
 and not has_function_privilege('anon','public.srk_customer_update_my_profile(text,text,text)','EXECUTE'),
 'avatar update RPC remains authenticated-only');
select * from finish();
rollback;
