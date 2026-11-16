begin;
select plan(5);

select has_function('public','srk_check_public_rate_limit',
  array['text','text','integer'],
  'public rate-limit RPC exists');

select ok((select prosecdef from pg_proc
  where oid='public.srk_check_public_rate_limit(text,text,integer)'::regprocedure),
  'public rate-limit RPC remains SECURITY DEFINER');

select ok(coalesce((select proconfig @> ARRAY['search_path=""'] from pg_proc
  where oid='public.srk_check_public_rate_limit(text,text,integer)'::regprocedure),false),
  'public rate-limit RPC pins an empty search_path');

select ok(has_function_privilege('service_role',
  'public.srk_check_public_rate_limit(text,text,integer)','EXECUTE'),
  'service_role can execute the rate-limit RPC');

select ok(not has_function_privilege('anon',
  'public.srk_check_public_rate_limit(text,text,integer)','EXECUTE')
  and not has_function_privilege('authenticated',
  'public.srk_check_public_rate_limit(text,text,integer)','EXECUTE'),
  'browser roles cannot execute the service-only rate-limit RPC');

select * from finish();
rollback;
