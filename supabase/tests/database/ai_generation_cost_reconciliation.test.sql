BEGIN;
SELECT plan(11);

SELECT has_table('public','srk_ai_generation_cost_jobs',
  'private AI generation cost reconciliation queue exists');
SELECT has_column('public','srk_ai_generation_cost_jobs','generation_id',
  'queue retains the Gateway generation ID');
SELECT has_column('public','srk_ai_generation_cost_jobs','cost_usd',
  'queue stores only explicitly reported USD cost');
SELECT has_column('public','srk_ai_generation_cost_jobs','locked_until',
  'claim lease is stored for fencing');
SELECT has_function('public','srk_claim_ai_generation_cost_jobs',
  ARRAY['integer'],'service worker can claim due generation cost jobs');
SELECT has_function('public','srk_finish_ai_generation_cost_job',
  ARRAY['uuid','integer','boolean','numeric','text','timestamp with time zone','text'],
  'service worker can finish a fenced generation cost attempt');
SELECT ok(
  (SELECT relrowsecurity FROM pg_class
   WHERE oid='public.srk_ai_generation_cost_jobs'::regclass)
  AND NOT has_table_privilege('anon','public.srk_ai_generation_cost_jobs','SELECT')
  AND NOT has_table_privilege('authenticated','public.srk_ai_generation_cost_jobs','SELECT')
  AND NOT has_table_privilege('service_role','public.srk_ai_generation_cost_jobs','SELECT'),
  'generation cost queue is RLS-enabled and has no direct table reads');
SELECT ok(
  has_function_privilege('service_role',
    'public.srk_claim_ai_generation_cost_jobs(integer)','EXECUTE')
  AND has_function_privilege('service_role',
    'public.srk_finish_ai_generation_cost_job(uuid,integer,boolean,numeric,text,timestamp with time zone,text)','EXECUTE')
  AND NOT has_function_privilege('anon',
    'public.srk_claim_ai_generation_cost_jobs(integer)','EXECUTE')
  AND NOT has_function_privilege('authenticated',
    'public.srk_finish_ai_generation_cost_job(uuid,integer,boolean,numeric,text,timestamp with time zone,text)','EXECUTE'),
  'claim and finish RPCs are service-role-only');
SELECT ok(
  (SELECT prosecdef AND proconfig @> ARRAY['search_path=pg_catalog, public, pg_temp']::text[]
   FROM pg_proc WHERE oid='public.srk_claim_ai_generation_cost_jobs(integer)'::regprocedure)
  AND (SELECT prosecdef FROM pg_proc
   WHERE oid='public.srk_finish_ai_generation_cost_job(uuid,integer,boolean,numeric,text,timestamp with time zone,text)'::regprocedure),
  'worker RPCs are SECURITY DEFINER with pinned search paths');
SELECT ok(
  position('SKIP LOCKED' in upper(pg_get_functiondef(
    'public.srk_claim_ai_generation_cost_jobs(integer)'::regprocedure)))>0
  AND position('locked_until' in pg_get_functiondef(
    'public.srk_claim_ai_generation_cost_jobs(integer)'::regprocedure))>0,
  'claim uses SKIP LOCKED and bounded leases for concurrency safety');
SELECT ok(
  position('p_attempt_count' in pg_get_functiondef(
    'public.srk_finish_ai_generation_cost_job(uuid,integer,boolean,numeric,text,timestamp with time zone,text)'::regprocedure))>0
  AND position('locked_until' in pg_get_functiondef(
    'public.srk_finish_ai_generation_cost_job(uuid,integer,boolean,numeric,text,timestamp with time zone,text)'::regprocedure))>0
  AND position('vercel_ai_gateway_generation_api' in pg_get_functiondef(
    'public.srk_finish_ai_generation_cost_job(uuid,integer,boolean,numeric,text,timestamp with time zone,text)'::regprocedure))>0,
  'finish fences stale workers and accepts only the named Gateway cost source');

SELECT * FROM finish();
ROLLBACK;
