BEGIN;
SELECT plan(13);
SELECT has_function('public','srk_technician_get_my_applications',ARRAY[]::text[],'Technician can read own shared applications');
SELECT ok(position('application_skill_id' in pg_get_functiondef('public.srk_technician_get_my_applications()'::regprocedure))>0,'own application projection includes skill IDs for KYC attachment');
SELECT ok(position('customer_decision' in pg_get_functiondef('public.srk_customer_get_technician_workdays(uuid)'::regprocedure))>0,'Customer can see the daily decision state');
SELECT has_function('public','srk_technician_get_my_presence',ARRAY[]::text[],'Technician can read own online presence');
SELECT has_function('public','srk_customer_get_master_final_bill',ARRAY['uuid'],'Customer can read own Master final bill and GST snapshot');
SELECT ok(position('technician_name' in pg_get_functiondef('public.srk_customer_get_technician_workdays(uuid)'::regprocedure))>0,'Customer workday history includes Technician display names for daily decisions');
SELECT has_function('public','srk_customer_list_master_booking_team',ARRAY['uuid'],'Customer can read assigned Master Technician team and live GPS');
SELECT ok(has_function_privilege('authenticated','public.srk_technician_get_my_presence()','EXECUTE')
 AND NOT has_function_privilege('anon','public.srk_technician_get_my_presence()','EXECUTE'),'Technician presence read is authenticated-only');
SELECT has_function('public','srk_admin_list_master_dispatch_queue',ARRAY['integer'],'Admin can monitor Master dispatch queue');
SELECT has_function('public','srk_admin_retry_master_dispatch',ARRAY['uuid'],'Admin can retry a stalled Master dispatch');
SELECT ok(position('public.is_srk_admin()' in pg_get_functiondef('public.srk_admin_list_master_dispatch_queue(integer)'::regprocedure))>0
 AND position('public.is_srk_admin()' in pg_get_functiondef('public.srk_admin_retry_master_dispatch(uuid)'::regprocedure))>0,'Admin dispatch RPCs enforce Main Admin server-side');
SELECT ok(position('public.srk_dispatch_issue_next_offer' in pg_get_functiondef('public.srk_admin_retry_master_dispatch(uuid)'::regprocedure))>0,'Admin retry uses the existing sequential dispatch engine');
SELECT ok(position('b.srk_service_category_code IS NULL' in pg_get_functiondef('public.srk_admin_retry_master_dispatch(uuid)'::regprocedure))>0,'Admin retry refuses non-Master bookings');
SELECT * FROM finish();
ROLLBACK;
