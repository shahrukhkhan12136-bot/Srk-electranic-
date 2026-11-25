BEGIN;
SELECT plan(9);
SELECT has_function('public','srk_service_role_build_master_final_bill',ARRAY['uuid']::text[],
 'Master final-bill builder remains available to the trusted server path');
SELECT has_trigger('public','service_bookings','srk_master_final_bill_after_customer_completion',
 'customer completion retries automatic final-bill creation');
SELECT ok(position('pg_trigger_depth()=0' in pg_get_functiondef('public.srk_service_role_build_master_final_bill(uuid)'::regprocedure))>0,
 'trusted server call and protected trigger call are both supported');
SELECT ok(position('srk_booking_technician_labour_ledger' in pg_get_functiondef('public.srk_service_role_build_master_final_bill(uuid)'::regprocedure))>0,
 'bill total is sourced from immutable Technician labour ledger');
SELECT ok(position('VALUES(p_booking_id,v_labour,0,v_labour' in pg_get_functiondef('public.srk_service_role_build_master_final_bill(uuid)'::regprocedure))>0,
 'new bills set compatibility add-on amount to zero and subtotal to service only');
SELECT ok(position('v_bill.technician_material_reimbursement_paise<>0' in pg_get_functiondef('public.srk_service_role_build_master_final_bill(uuid)'::regprocedure))>0,
 'bill replay rejects any non-service reimbursement');
SELECT ok(position('BEFORE INSERT OR UPDATE' in (SELECT pg_get_triggerdef(t.oid) FROM pg_trigger t WHERE t.tgname='srk_master_payable_service_only_insert'))>0,
 'payable guard protects both inserts and later updates');
SELECT ok(NOT has_function_privilege('authenticated','public.srk_technician_submit_booking_materials(uuid,jsonb)','EXECUTE'),
 'obsolete submission RPC is unavailable to authenticated clients');
SELECT ok(NOT has_function_privilege('authenticated','public.srk_customer_decide_booking_materials(uuid,text,text)','EXECUTE'),
 'obsolete decision RPC is unavailable to authenticated clients');
SELECT * FROM finish();
ROLLBACK;
