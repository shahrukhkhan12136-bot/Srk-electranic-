BEGIN;
SELECT plan(14);

SELECT has_table('public','srk_admin_staff','separate staff registry exists');
SELECT has_table('public','srk_admin_permissions','permission catalog exists');
SELECT has_table('public','srk_admin_role_permissions','role-to-permission map exists');
SELECT has_table('public','srk_admin_staff_sessions','session metadata table exists');
SELECT has_table('public','srk_admin_staff_audit_events','staff audit table exists');
SELECT has_function('public','srk_has_admin_permission',ARRAY['text'],'permission helper exists');
SELECT ok(
  NOT has_table_privilege('anon','public.srk_admin_staff','SELECT')
  AND NOT has_table_privilege('authenticated','public.srk_admin_staff','SELECT')
  AND NOT has_table_privilege('authenticated','public.srk_admin_staff','INSERT')
  AND NOT has_table_privilege('authenticated','public.srk_admin_staff','UPDATE'),
  'staff registry is not directly accessible to browser roles'
);
SELECT ok(
  NOT has_table_privilege('anon','public.srk_admin_staff_audit_events','SELECT')
  AND NOT has_table_privilege('authenticated','public.srk_admin_staff_audit_events','SELECT')
  AND NOT has_table_privilege('authenticated','public.srk_admin_staff_audit_events','DELETE'),
  'staff audit is not directly readable or mutable by browser roles'
);
SELECT ok(
  has_function_privilege('authenticated','public.srk_has_admin_permission(text)','EXECUTE')
  AND NOT has_function_privilege('anon','public.srk_has_admin_permission(text)','EXECUTE'),
  'only authenticated users can evaluate their permission result'
);
SELECT ok(
  (SELECT count(*)=7 FROM public.srk_admin_permissions)
  AND (SELECT count(*)=7 FROM public.srk_admin_role_permissions WHERE role_key='support')
  AND (SELECT count(DISTINCT role_key)=1 FROM public.srk_admin_role_permissions),
  'only the explicitly scoped Support permission set is seeded'
);
SELECT ok(
  NOT EXISTS (
    SELECT 1 FROM public.srk_admin_role_permissions
    WHERE permission_key LIKE 'finance.%'
       OR permission_key LIKE 'refund.%'
       OR permission_key LIKE 'payout.%'
       OR permission_key LIKE 'kyc.%'
       OR permission_key IN ('staff.manage','audit.read','booking.cancel_decide','booking.read_private_contacts')
  ),
  'Support receives no finance, refund, payout, KYC, staff, audit, cancellation-decision, or private-contact permission'
);
SELECT ok(
  position('security definer' in lower(pg_get_functiondef('public.srk_has_admin_permission(text)'::regprocedure)))>0
  AND position('set search_path TO \'\'' in pg_get_functiondef('public.srk_has_admin_permission(text)'::regprocedure))>0,
  'permission helper is SECURITY DEFINER with an empty search_path'
);
SELECT ok(
  position('public.is_srk_admin()' in pg_get_functiondef('public.srk_has_admin_permission(text)'::regprocedure))>0
  AND position('s.status = ''active''' in pg_get_functiondef('public.srk_has_admin_permission(text)'::regprocedure))>0,
  'Main Admin remains separate and staff permissions require active status'
);
SELECT has_trigger('public','srk_admin_staff_audit_events','srk_admin_staff_audit_no_row_mutation','audit rows are protected against update and delete');

SELECT * FROM finish();
ROLLBACK;
