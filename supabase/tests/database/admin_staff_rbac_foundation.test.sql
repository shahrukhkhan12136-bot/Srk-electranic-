BEGIN;
SELECT plan(66);

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
SELECT has_function('public','srk_admin_staff_register_session',ARRAY[]::text[],'staff session registration RPC exists');
SELECT ok(
  position('for share' in lower(pg_get_functiondef('public.srk_admin_staff_register_session()'::regprocedure)))>0
  AND position('select s.status = ''active''' in pg_get_functiondef('public.srk_admin_staff_register_session()'::regprocedure))>0,
  'session registration locks the staff registry row against concurrent suspension or disable'
);
SELECT has_function('public','srk_admin_list_staff',ARRAY[]::text[],'Main Admin staff listing RPC exists');
SELECT has_function('public','srk_admin_staff_set_status',ARRAY['uuid','text','text'],'Main Admin staff status RPC exists');
SELECT has_function('public','srk_admin_staff_register_invited_user',ARRAY['uuid','text','uuid'],'service-only invited user registration RPC exists');
SELECT ok(
  position('auth.sessions' in pg_get_functiondef('public.srk_has_admin_permission(text)'::regprocedure))>0
  AND position('tracked.revoked_at is null' in pg_get_functiondef('public.srk_has_admin_permission(text)'::regprocedure))>0,
  'staff permissions require a live Auth session and reject revoked tracked sessions'
);
SELECT ok(
  position('for share' in lower(pg_get_functiondef('public.srk_has_admin_permission(text)'::regprocedure)))>0
  AND (SELECT provolatile='v' FROM pg_proc WHERE oid='public.srk_has_admin_permission(text)'::regprocedure)
  AND (SELECT bool_and(p.provolatile='v') FROM pg_proc p WHERE p.oid IN (
    'public.srk_admin_staff_list_customer_complaints()'::regprocedure,
    'public.srk_admin_staff_list_customer_messages(uuid)'::regprocedure,
    'public.srk_admin_staff_list_electrician_tickets()'::regprocedure,
    'public.srk_admin_staff_list_electrician_messages(uuid)'::regprocedure
  )),
  'Staff permission checks lock the active registry row and all Staff read RPCs permit transactional row locking'
);
SELECT ok(
  position('public.srk_admin_staff_sessions tracked' in pg_get_functiondef('public.srk_has_admin_permission(text)'::regprocedure))>0
  AND strpos(
    lower(substr(
      pg_get_functiondef('public.srk_has_admin_permission(text)'::regprocedure),
      position('public.srk_admin_staff_sessions tracked' in pg_get_functiondef('public.srk_has_admin_permission(text)'::regprocedure))
    )),
    'for share'
  )>0,
  'permission checks hold a shared lock on the tracked session so explicit revocation serializes with in-flight requests'
);
SELECT ok(
  has_function_privilege('service_role','public.srk_admin_staff_register_invited_user(uuid,text,uuid)','EXECUTE')
  AND NOT has_function_privilege('authenticated','public.srk_admin_staff_register_invited_user(uuid,text,uuid)','EXECUTE')
  AND NOT has_function_privilege('anon','public.srk_admin_staff_register_invited_user(uuid,text,uuid)','EXECUTE'),
  'invited-user registry RPC is callable only by service_role'
);
SELECT ok(
  position('public.is_srk_admin()' in pg_get_functiondef('public.srk_admin_staff_set_status(uuid,text,text)'::regprocedure))>0
  AND position('public.is_srk_admin()' in pg_get_functiondef('public.srk_admin_list_staff()'::regprocedure))>0
  AND position('email_confirmed_at' in pg_get_functiondef('public.srk_admin_staff_set_status(uuid,text,text)'::regprocedure))>0
  AND position('STAFF_EMAIL_NOT_VERIFIED' in pg_get_functiondef('public.srk_admin_staff_set_status(uuid,text,text)'::regprocedure))>0,
  'staff management remains Main Admin-only and activation requires verified email'
);
SELECT has_function('public','srk_admin_list_staff_sessions',ARRAY['uuid'],'Main Admin can list staff session metadata');
SELECT has_function('public','srk_admin_staff_revoke_session',ARRAY['uuid','text'],'Main Admin can revoke a specific staff session');


SELECT has_table('public','srk_admin_support_assignments','support cases have a dedicated staff ownership map');
SELECT has_column('public','srk_booking_complaint_messages','sender_user_id','customer support replies retain staff sender identity');
SELECT has_function('public','srk_admin_assign_support_case',ARRAY['text','uuid','uuid','text'],'Main Admin can assign a support case');
SELECT has_function('public','srk_admin_staff_list_customer_complaints',ARRAY[]::text[],'Staff can list assigned customer complaints only');
SELECT has_function('public','srk_admin_staff_list_customer_messages',ARRAY['uuid'],'Staff can read assigned customer conversation only');
SELECT has_function('public','srk_admin_staff_send_customer_message',ARRAY['uuid','text'],'Staff can reply in assigned customer conversation');
SELECT has_function('public','srk_admin_staff_update_customer_complaint',ARRAY['uuid','text','text'],'Staff can update assigned customer complaint status');
SELECT has_function('public','srk_admin_staff_list_electrician_tickets',ARRAY[]::text[],'Staff can list assigned electrician tickets only');
SELECT has_function('public','srk_admin_staff_list_electrician_messages',ARRAY['uuid'],'Staff can read assigned electrician conversation only');
SELECT has_function('public','srk_admin_staff_send_electrician_message',ARRAY['uuid','text'],'Staff can reply in assigned electrician conversation');
SELECT has_function('public','srk_admin_staff_update_electrician_ticket',ARRAY['uuid','text','text'],'Staff can update assigned electrician ticket status');
SELECT ok(
  NOT has_table_privilege('anon','public.srk_admin_support_assignments','SELECT')
  AND NOT has_table_privilege('authenticated','public.srk_admin_support_assignments','SELECT')
  AND NOT has_table_privilege('authenticated','public.srk_admin_support_assignments','INSERT'),
  'support assignment map is not directly accessible to browser roles'
);
SELECT ok(
  position('a.assigned_staff_user_id=auth.uid()' in pg_get_functiondef('public.srk_admin_staff_list_customer_complaints()'::regprocedure))>0
  AND position('a.assigned_staff_user_id=auth.uid()' in pg_get_functiondef('public.srk_admin_staff_list_electrician_tickets()'::regprocedure))>0,
  'both Staff inboxes are filtered to the signed-in assigned owner'
);
SELECT ok(
  position('customer_phone' in pg_get_functiondef('public.srk_admin_staff_list_customer_complaints()'::regprocedure))=0
  AND position('electrician_phone' in pg_get_functiondef('public.srk_admin_staff_list_electrician_tickets()'::regprocedure))=0
  AND position('electrician_name' in pg_get_functiondef('public.srk_admin_staff_list_electrician_tickets()'::regprocedure))=0,
  'Staff-safe inboxes do not return customer phone or electrician private identity fields'
);
SELECT ok(
  position('support.customer.reply' in pg_get_functiondef('public.srk_admin_staff_send_customer_message(uuid,text)'::regprocedure))>0
  AND position('assigned_staff_user_id=v_uid' in pg_get_functiondef('public.srk_admin_staff_send_customer_message(uuid,text)'::regprocedure))>0
  AND position('support.electrician.reply' in pg_get_functiondef('public.srk_admin_staff_send_electrician_message(uuid,text)'::regprocedure))>0
  AND position('assigned_staff_user_id=v_uid' in pg_get_functiondef('public.srk_admin_staff_send_electrician_message(uuid,text)'::regprocedure))>0,
  'Staff replies require explicit reply permission and current case assignment'
);
SELECT ok(
  position('public.is_srk_admin()' in pg_get_functiondef('public.srk_admin_assign_support_case(text,uuid,uuid,text)'::regprocedure))>0,
  'only Main Admin can assign or reassign support cases'
);

SELECT has_function('public','srk_admin_list_support_assignments',ARRAY[]::text[],'Main Admin can inspect current support ownership');

SELECT ok(
  position('p_status is null' in pg_get_functiondef('public.srk_admin_staff_update_customer_complaint(uuid,text,text)'::regprocedure))>0
  AND position('v_old_status=''closed''' in pg_get_functiondef('public.srk_admin_staff_update_customer_complaint(uuid,text,text)'::regprocedure))>0,
  'Staff cannot reopen a closed customer complaint and null status is rejected'
);
SELECT ok(
  position('p_status is null' in pg_get_functiondef('public.srk_admin_staff_update_electrician_ticket(uuid,text,text)'::regprocedure))>0
  AND position('v_old_status=''closed''' in pg_get_functiondef('public.srk_admin_staff_update_electrician_ticket(uuid,text,text)'::regprocedure))>0,
  'Staff cannot reopen a closed electrician ticket and null status is rejected'
);

SELECT ok(
  position('p_case_type is null' in pg_get_functiondef('public.srk_admin_assign_support_case(text,uuid,uuid,text)'::regprocedure))>0
  AND position('status<>''closed''' in pg_get_functiondef('public.srk_admin_assign_support_case(text,uuid,uuid,text)'::regprocedure))>0,
  'assignment rejects invalid case type and closed cases'
);

SELECT ok(
  position('support.customer.read' in pg_get_functiondef('public.srk_admin_staff_send_customer_message(uuid,text)'::regprocedure))>0
  AND position('support.customer.read' in pg_get_functiondef('public.srk_admin_staff_update_customer_complaint(uuid,text,text)'::regprocedure))>0,
  'customer support mutations also require customer read permission'
);
SELECT ok(
  position('support.electrician.read' in pg_get_functiondef('public.srk_admin_staff_send_electrician_message(uuid,text)'::regprocedure))>0
  AND position('support.electrician.read' in pg_get_functiondef('public.srk_admin_staff_update_electrician_ticket(uuid,text,text)'::regprocedure))>0,
  'electrician support mutations also require electrician read permission'
);

SELECT ok(
  position('booking.read_basic' in pg_get_functiondef('public.srk_admin_staff_list_customer_complaints()'::regprocedure))>0,
  'customer support inbox requires explicit basic booking context permission'
);
SELECT ok(
  position('booking.read_basic' in pg_get_functiondef('public.srk_admin_staff_list_electrician_tickets()'::regprocedure))>0,
  'electrician support inbox requires explicit basic booking context permission'
);

SELECT has_function('public','srk_capture_admin_staff_session_event',ARRAY[]::text[],'new Staff session audit trigger function exists');
SELECT has_trigger('public','srk_admin_staff_sessions','srk_admin_staff_session_audit_insert','new Staff sessions are recorded in the append-only audit log');

SELECT has_function('public','srk_admin_list_staff_audit_events',ARRAY['uuid','integer'],'Main Admin can review Staff activity audit history');

SELECT ok(
  position('public.is_srk_admin()' in pg_get_functiondef('public.srk_admin_list_staff_audit_events(uuid,integer)'::regprocedure))>0,
  'only Main Admin can read Staff activity audit history'
);


SELECT ok(
  position('from public.srk_booking_complaints c' in pg_get_functiondef('public.srk_admin_assign_support_case(text,uuid,uuid,text)'::regprocedure)) <
    position('from public.srk_admin_support_assignments a' in pg_get_functiondef('public.srk_admin_assign_support_case(text,uuid,uuid,text)'::regprocedure))
  AND position('for update' in lower(pg_get_functiondef('public.srk_admin_assign_support_case(text,uuid,uuid,text)'::regprocedure)))>0,
  'Main Admin assignment locks the support case before the ownership row'
);
SELECT ok(
  position('from public.srk_booking_complaints c' in pg_get_functiondef('public.srk_admin_staff_send_customer_message(uuid,text)'::regprocedure)) <
    position('from public.srk_admin_support_assignments a' in pg_get_functiondef('public.srk_admin_staff_send_customer_message(uuid,text)'::regprocedure))
  AND position('from public.srk_booking_complaints c' in pg_get_functiondef('public.srk_admin_staff_update_customer_complaint(uuid,text,text)'::regprocedure)) <
    position('from public.srk_admin_support_assignments a' in pg_get_functiondef('public.srk_admin_staff_update_customer_complaint(uuid,text,text)'::regprocedure))
  AND position('from public.srk_electrician_support_tickets t' in pg_get_functiondef('public.srk_admin_staff_send_electrician_message(uuid,text)'::regprocedure)) <
    position('from public.srk_admin_support_assignments a' in pg_get_functiondef('public.srk_admin_staff_send_electrician_message(uuid,text)'::regprocedure))
  AND position('from public.srk_electrician_support_tickets t' in pg_get_functiondef('public.srk_admin_staff_update_electrician_ticket(uuid,text,text)'::regprocedure)) <
    position('from public.srk_admin_support_assignments a' in pg_get_functiondef('public.srk_admin_staff_update_electrician_ticket(uuid,text,text)'::regprocedure)),
  'Staff replies and status changes lock case rows before assignment rows to avoid lock-order deadlocks'
);


SELECT ok(
  NOT has_table_privilege('anon','public.srk_admin_staff_audit_events','TRUNCATE')
  AND NOT has_table_privilege('authenticated','public.srk_admin_staff_audit_events','TRUNCATE')
  AND EXISTS (
    SELECT 1 FROM pg_trigger
     WHERE tgrelid='public.srk_admin_staff_audit_events'::regclass
       AND tgname='srk_admin_staff_audit_no_truncate'
       AND NOT tgisinternal
  ),
  'audit log denies browser TRUNCATE privilege and has a truncate guard trigger'
);

SELECT ok(
  EXISTS (
    SELECT 1 FROM pg_constraint
     WHERE conrelid='public.srk_admin_support_assignments'::regclass
       AND contype='u'
       AND pg_get_constraintdef(oid) ILIKE 'UNIQUE (case_type, case_id)%'
  )
  AND EXISTS (
    SELECT 1 FROM pg_constraint
     WHERE conrelid='public.srk_admin_support_assignments'::regclass
       AND conname='srk_admin_support_assignments_case_type_check'
       AND pg_get_constraintdef(oid) ILIKE '%customer_complaint%'
       AND pg_get_constraintdef(oid) ILIKE '%electrician_ticket%'
  ),
  'assignment table enforces one owner per case and a closed case-type vocabulary'
);

SELECT ok(
  NOT has_table_privilege('anon','public.srk_admin_support_assignments','UPDATE')
  AND NOT has_table_privilege('authenticated','public.srk_admin_support_assignments','UPDATE')
  AND NOT has_table_privilege('anon','public.srk_admin_staff_sessions','INSERT')
  AND NOT has_table_privilege('authenticated','public.srk_admin_staff_sessions','INSERT'),
  'browser roles cannot mutate assignment ownership or directly register Staff sessions'
);


SELECT ok(
  has_function_privilege('authenticated','public.srk_admin_staff_register_session()','EXECUTE')
  AND NOT has_function_privilege('anon','public.srk_admin_staff_register_session()','EXECUTE')
  AND has_function_privilege('authenticated','public.srk_admin_staff_set_status(uuid,text,text)','EXECUTE')
  AND NOT has_function_privilege('anon','public.srk_admin_staff_set_status(uuid,text,text)','EXECUTE')
  AND has_function_privilege('authenticated','public.srk_admin_assign_support_case(text,uuid,uuid,text)','EXECUTE')
  AND NOT has_function_privilege('anon','public.srk_admin_assign_support_case(text,uuid,uuid,text)','EXECUTE'),
  'authenticated-only RPC grants are present for session, Main Admin lifecycle, and assignment functions'
);

SELECT ok(
  has_function_privilege('authenticated','public.srk_admin_staff_list_customer_complaints()','EXECUTE')
  AND has_function_privilege('authenticated','public.srk_admin_staff_send_customer_message(uuid,text)','EXECUTE')
  AND has_function_privilege('authenticated','public.srk_admin_staff_update_customer_complaint(uuid,text,text)','EXECUTE')
  AND has_function_privilege('authenticated','public.srk_admin_staff_list_electrician_tickets()','EXECUTE')
  AND has_function_privilege('authenticated','public.srk_admin_staff_send_electrician_message(uuid,text)','EXECUTE')
  AND has_function_privilege('authenticated','public.srk_admin_staff_update_electrician_ticket(uuid,text,text)','EXECUTE')
  AND NOT has_function_privilege('anon','public.srk_admin_staff_list_customer_complaints()','EXECUTE')
  AND NOT has_function_privilege('anon','public.srk_admin_staff_list_electrician_tickets()','EXECUTE'),
  'Staff support RPCs are executable by authenticated users but not anonymous users'
);

SELECT ok(
  has_function_privilege('service_role','public.srk_admin_staff_register_invited_user(uuid,text,uuid)','EXECUTE')
  AND NOT has_function_privilege('authenticated','public.srk_admin_staff_register_invited_user(uuid,text,uuid)','EXECUTE')
  AND NOT has_function_privilege('anon','public.srk_admin_staff_register_invited_user(uuid,text,uuid)','EXECUTE')
  AND NOT has_function_privilege('authenticated','public.srk_capture_admin_staff_session_event()','EXECUTE')
  AND NOT has_function_privilege('anon','public.srk_capture_admin_staff_session_event()','EXECUTE'),
  'invite-registration is service-role-only and trigger helper cannot be invoked by browser roles'
);


SELECT ok(
  position('from public.srk_admin_staff s' in pg_get_functiondef('public.srk_admin_assign_support_case(text,uuid,uuid,text)'::regprocedure)) <
    position('from public.srk_booking_complaints c' in pg_get_functiondef('public.srk_admin_assign_support_case(text,uuid,uuid,text)'::regprocedure))
  AND position('for share' in lower(pg_get_functiondef('public.srk_admin_assign_support_case(text,uuid,uuid,text)'::regprocedure))) <
    position('for update' in lower(pg_get_functiondef('public.srk_admin_assign_support_case(text,uuid,uuid,text)'::regprocedure)),
  'Main Admin assignment takes the active staff lock before the case lock to match Staff authorization lock order'
);

SELECT ok(
  position('from public.srk_booking_complaints c' in pg_get_functiondef('public.srk_admin_staff_list_customer_messages(uuid)'::regprocedure)) <
    position('from public.srk_admin_support_assignments a' in pg_get_functiondef('public.srk_admin_staff_list_customer_messages(uuid)'::regprocedure))
  AND position('for share' in lower(pg_get_functiondef('public.srk_admin_staff_list_customer_messages(uuid)'::regprocedure))) > 0
  AND position('from public.srk_electrician_support_tickets t' in pg_get_functiondef('public.srk_admin_staff_list_electrician_messages(uuid)'::regprocedure)) <
    position('from public.srk_admin_support_assignments a' in pg_get_functiondef('public.srk_admin_staff_list_electrician_messages(uuid)'::regprocedure))
  AND position('for share' in lower(pg_get_functiondef('public.srk_admin_staff_list_electrician_messages(uuid)'::regprocedure))) > 0,
  'Staff thread readers lock the case and current assignment so reassignment serializes with message access'
);

SELECT ok(
  position('for share of c,a' in lower(pg_get_functiondef('public.srk_admin_staff_list_customer_complaints()'::regprocedure)))>0
  AND position('for share of t,a' in lower(pg_get_functiondef('public.srk_admin_staff_list_electrician_tickets()'::regprocedure)))>0,
  'Staff inbox list reads lock both case and ownership rows so concurrent reassignment cannot return stale assigned cases'
);

SELECT ok(
  NOT EXISTS (
    SELECT 1
      FROM pg_constraint c
     WHERE c.conrelid='public.srk_admin_staff_audit_events'::regclass
       AND c.contype='f'
       AND (
         'actor_user_id'::text = ANY (
           SELECT a.attname::text FROM pg_attribute a
            WHERE a.attrelid=c.conrelid AND a.attnum=ANY(c.conkey)
         )
         OR
         'target_user_id'::text = ANY (
           SELECT a.attname::text FROM pg_attribute a
            WHERE a.attrelid=c.conrelid AND a.attnum=ANY(c.conkey)
         )
       )
  ),
  'immutable audit actor and target UUIDs have no ON DELETE SET NULL foreign keys that would mutate historical rows'
);

SELECT * FROM finish();
ROLLBACK;
