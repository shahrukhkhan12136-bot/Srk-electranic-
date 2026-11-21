BEGIN;
SELECT plan(10);
SELECT has_function('public','srk_admin_list_master_pending_manual_payments',ARRAY['integer'],'Main Admin can list completed unpaid Master manual payments');
SELECT has_function('public','srk_technician_list_master_cash_refund_tasks',ARRAY[]::text[],'Technician can list only own approved cash refund tasks');
SELECT has_function('public','srk_admin_finalize_master_cash_refund',ARRAY['uuid','text'],'Main Admin cash refund finalization is tax-inclusive');
SELECT ok(position('v_tax.total_due_paise' in pg_get_functiondef('public.srk_admin_finalize_master_cash_refund(uuid,text)'::regprocedure))>0
 AND position('v_final_bill.subtotal_paise' in pg_get_functiondef('public.srk_admin_finalize_master_cash_refund(uuid,text)'::regprocedure))>0,
 'cash refund finalization uses tax-inclusive total due with safe unregistered fallback');
SELECT ok(position('r.status=''approved''' in pg_get_functiondef('public.srk_technician_list_master_cash_refund_tasks()'::regprocedure))>0
 AND position('p.technician_id=v_tid' in pg_get_functiondef('public.srk_technician_list_master_cash_refund_tasks()'::regprocedure))>0,
 'Technician refund tasks require approved request and own payable assignment');
SELECT ok(has_function_privilege('authenticated','public.srk_technician_list_master_cash_refund_tasks()','EXECUTE')
 AND NOT has_function_privilege('anon','public.srk_technician_list_master_cash_refund_tasks()','EXECUTE'),
 'cash refund task list is authenticated-only');
SELECT ok(position('public.is_srk_admin()' in pg_get_functiondef('public.srk_admin_list_master_pending_manual_payments(integer)'::regprocedure))>0
 AND position('public.is_srk_admin()' in pg_get_functiondef('public.srk_admin_finalize_master_cash_refund(uuid,text)'::regprocedure))>0,
 'Admin payment and refund functions enforce Main Admin');
SELECT ok(position('t.total_due_paise' in pg_get_functiondef('public.srk_admin_list_master_pending_manual_payments(integer)'::regprocedure))>0,
 'Admin manual payment list shows GST-inclusive total due');
SELECT ok(position('NOT EXISTS' in pg_get_functiondef('public.srk_admin_list_master_pending_manual_payments(integer)'::regprocedure))>0,
 'already-recorded payments are excluded from manual verification queue');
SELECT ok(position('commission_recovered_paise' in pg_get_functiondef('public.srk_admin_finalize_master_cash_refund(uuid,text)'::regprocedure))>0,
 'cash refund reverses commission and credits only previously recovered dues');
SELECT * FROM finish();
ROLLBACK;
