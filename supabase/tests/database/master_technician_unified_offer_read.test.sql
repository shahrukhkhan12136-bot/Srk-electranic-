BEGIN;
SELECT plan(7);
SELECT has_function('public','srk_get_my_offer_details',ARRAY[]::text[],
 'Shared Technician App has one unified offer feed');
SELECT ok(
 has_function_privilege('authenticated','public.srk_get_my_offer_details()','EXECUTE')
 AND NOT has_function_privilege('anon','public.srk_get_my_offer_details()','EXECUTE'),
 'unified offer feed is authenticated-only'
);
SELECT ok(
 position('public.srk_technician_dispatch_offers' in pg_get_functiondef('public.srk_get_my_offer_details()'::regprocedure))>0,
 'unified feed includes Master dispatch offers'
);
SELECT ok(
 position('public.job_offers' in pg_get_functiondef('public.srk_get_my_offer_details()'::regprocedure))>0,
 'unified feed preserves legacy Electrician offers'
);
SELECT ok(
 position('a.assignment_status IN (''accepted'',''active'',''completed'')' in pg_get_functiondef('public.srk_get_my_offer_details()'::regprocedure))>0,
 'Master customer details require an accepted assignment'
);
SELECT ok(
 position('b.srk_service_category_code' in pg_get_functiondef('public.srk_get_my_offer_details()'::regprocedure))>0
 AND position('workday_id' in pg_get_functiondef('public.srk_get_my_offer_details()'::regprocedure))>0,
 'Master service snapshots and Technician workday status are exposed'
);
SELECT ok(
 position('p.verification_status=''approved''' in pg_get_functiondef('public.srk_get_my_offer_details()'::regprocedure))>0
 AND position('t.account_status=''active''' in pg_get_functiondef('public.srk_get_my_offer_details()'::regprocedure))>0,
 'only approved active legacy and Master Technicians see their own offers'
);
SELECT * FROM finish();
ROLLBACK;
