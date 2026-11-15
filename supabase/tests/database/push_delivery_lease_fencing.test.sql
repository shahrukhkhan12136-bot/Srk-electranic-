begin;
select plan(20);

select ok(to_regprocedure('public.srk_finish_push_delivery_outbox(uuid,integer,boolean,text)') is not null,
  'outbox finish RPC uses attempt-count fencing signature');
select ok(to_regprocedure('public.srk_finish_push_subscription_delivery(uuid,integer,boolean,text)') is not null,
  'per-device finish RPC uses attempt-count fencing signature');

select ok(has_function_privilege('service_role',
  'public.srk_finish_push_delivery_outbox(uuid,integer,boolean,text)','EXECUTE')
  and not has_function_privilege('authenticated',
  'public.srk_finish_push_delivery_outbox(uuid,integer,boolean,text)','EXECUTE')
  and not has_function_privilege('anon',
  'public.srk_finish_push_delivery_outbox(uuid,integer,boolean,text)','EXECUTE'),
  'outbox finish RPC is service-role-only');
select ok(has_function_privilege('service_role',
  'public.srk_finish_push_subscription_delivery(uuid,integer,boolean,text)','EXECUTE')
  and not has_function_privilege('authenticated',
  'public.srk_finish_push_subscription_delivery(uuid,integer,boolean,text)','EXECUTE')
  and not has_function_privilege('anon',
  'public.srk_finish_push_subscription_delivery(uuid,integer,boolean,text)','EXECUTE'),
  'per-device finish RPC is service-role-only');

select ok(position('v_row.attempt_count IS DISTINCT FROM p_attempt_count' in
  pg_get_functiondef('public.srk_finish_push_delivery_outbox(uuid,integer,boolean,text)'::regprocedure))>0,
  'outbox finish rejects stale worker attempt numbers');
select ok(position('v_row.attempt_count IS DISTINCT FROM p_attempt_count' in
  pg_get_functiondef('public.srk_finish_push_subscription_delivery(uuid,integer,boolean,text)'::regprocedure))>0,
  'device finish rejects stale worker attempt numbers');

select ok(position('FOR UPDATE' in upper(
  pg_get_functiondef('public.srk_finish_push_delivery_outbox(uuid,integer,boolean,text)'::regprocedure)))>0,
  'outbox finish serializes updates with a row lock');
select ok(position('FOR UPDATE' in upper(
  pg_get_functiondef('public.srk_finish_push_subscription_delivery(uuid,integer,boolean,text)'::regprocedure)))>0,
  'device finish serializes updates with a row lock');

select ok(position('v_row.delivery_status <> ''processing''' in
  pg_get_functiondef('public.srk_finish_push_delivery_outbox(uuid,integer,boolean,text)'::regprocedure))>0,
  'outbox finish only accepts a currently processing lease');
select ok(position('v_row.delivery_status <> ''processing''' in
  pg_get_functiondef('public.srk_finish_push_subscription_delivery(uuid,integer,boolean,text)'::regprocedure))>0,
  'device finish only accepts a currently processing lease');

select ok(position('delivery_status IN (''delivered'',''dead'')' in
  pg_get_functiondef('public.srk_finish_push_delivery_outbox(uuid,integer,boolean,text)'::regprocedure))>0,
  'outbox terminal rows cannot be overwritten');
select ok(position('delivery_status IN (''delivered'',''dead'')' in
  pg_get_functiondef('public.srk_finish_push_subscription_delivery(uuid,integer,boolean,text)'::regprocedure))>0,
  'device terminal rows cannot be overwritten');

select ok(position('v_row.attempt_count>=8' in
  pg_get_functiondef('public.srk_finish_push_delivery_outbox(uuid,integer,boolean,text)'::regprocedure))>0,
  'outbox exhausted attempts become dead letters');
select ok(position('v_row.attempt_count>=5' in
  pg_get_functiondef('public.srk_finish_push_subscription_delivery(uuid,integer,boolean,text)'::regprocedure))>0,
  'device exhausted attempts become dead letters');

select ok(position('least(3600,30*(2^least(v_row.attempt_count,7))::integer)' in
  pg_get_functiondef('public.srk_finish_push_delivery_outbox(uuid,integer,boolean,text)'::regprocedure))>0,
  'outbox retry uses capped exponential backoff');
select ok(position('least(1800,30*(2^least(v_row.attempt_count,6))::integer)' in
  pg_get_functiondef('public.srk_finish_push_subscription_delivery(uuid,integer,boolean,text)'::regprocedure))>0,
  'device retry uses capped exponential backoff');

select ok(position('left(coalesce(p_error,' in
  pg_get_functiondef('public.srk_finish_push_delivery_outbox(uuid,integer,boolean,text)'::regprocedure))>0,
  'outbox provider error text is bounded before persistence');
select ok(position('left(coalesce(p_error,' in
  pg_get_functiondef('public.srk_finish_push_subscription_delivery(uuid,integer,boolean,text)'::regprocedure))>0,
  'device provider error text is bounded before persistence');

select ok(coalesce((select proconfig @> ARRAY['search_path=pg_catalog, public, srk_private, pg_temp']
  from pg_proc where oid='public.srk_finish_push_delivery_outbox(uuid,integer,boolean,text)'::regprocedure),false),
  'outbox SECURITY DEFINER function pins its search_path');
select ok(coalesce((select proconfig @> ARRAY['search_path=pg_catalog, public, srk_private, pg_temp']
  from pg_proc where oid='public.srk_finish_push_subscription_delivery(uuid,integer,boolean,text)'::regprocedure),false),
  'device SECURITY DEFINER function pins its search_path');

select * from finish();
rollback;
