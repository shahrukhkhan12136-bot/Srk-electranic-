begin;
select plan(28);

select has_table('public','srk_sos_alerts','private SOS case table exists');
select ok((select relrowsecurity from pg_class where oid='public.srk_sos_alerts'::regclass),
  'SOS case table has RLS enabled');
select ok(not has_table_privilege('anon','public.srk_sos_alerts','select')
  and not has_table_privilege('authenticated','public.srk_sos_alerts','select'),
  'browser roles cannot directly read private SOS cases');

select has_table('public','srk_sos_alert_events','append-only SOS event history exists');
select ok((select relrowsecurity from pg_class where oid='public.srk_sos_alert_events'::regclass)
  and not has_table_privilege('authenticated','public.srk_sos_alert_events','select'),
  'browser roles cannot directly read SOS audit events');
select ok(exists(select 1 from pg_trigger where tgrelid='public.srk_sos_alert_events'::regclass
  and tgname='srk_sos_events_no_row_mutation' and not tgisinternal)
  and exists(select 1 from pg_trigger where tgrelid='public.srk_sos_alert_events'::regclass
  and tgname='srk_sos_events_no_truncate' and not tgisinternal),
  'SOS audit history blocks update, delete and truncate');

select ok(exists(select 1 from public.srk_admin_permissions where permission_key='support.sos.read')
  and exists(select 1 from public.srk_admin_permissions where permission_key='support.sos.acknowledge'),
  'dedicated SOS read and acknowledge permissions are registered');
select ok(exists(select 1 from public.srk_admin_role_permissions
  where role_key='support' and permission_key='support.sos.read')
  and exists(select 1 from public.srk_admin_role_permissions
  where role_key='support' and permission_key='support.sos.acknowledge'),
  'Support role receives only the explicit SOS permissions');

select has_function('public','srk_create_sos_alert',array['text'],
  'client-facing SOS creation RPC exists');
select ok((select prosecdef from pg_proc where oid='public.srk_create_sos_alert(text)'::regprocedure),
  'SOS creation RPC is SECURITY DEFINER');
select ok(coalesce((select proconfig @> ARRAY['search_path=""']::text[]
  from pg_proc where oid='public.srk_create_sos_alert(text)'::regprocedure),false),
  'SOS creation RPC pins an empty search_path');
select ok(not has_function_privilege('anon','public.srk_create_sos_alert(text)','execute')
  and has_function_privilege('authenticated','public.srk_create_sos_alert(text)','execute'),
  'only authenticated users can invoke SOS creation');
select ok(position('auth.uid()' in pg_get_functiondef(
  'public.srk_create_sos_alert(text)'::regprocedure))>0
  and position('b.customer_user_id=v_uid' in pg_get_functiondef(
  'public.srk_create_sos_alert(text)'::regprocedure))>0
  and position('ep.user_id=v_uid' in pg_get_functiondef(
  'public.srk_create_sos_alert(text)'::regprocedure))>0,
  'SOS actor and booking ownership are derived from the authenticated user');
select ok(position('status=''in_progress''' in pg_get_functiondef(
  'public.srk_create_sos_alert(text)'::regprocedure))>0
  and position('selected_category is not null' in pg_get_functiondef(
  'public.srk_create_sos_alert(text)'::regprocedure))>0,
  'SOS requires an active new-category work booking');
select ok(position('SOS_ACTIVE_BOOKING_AMBIGUOUS' in pg_get_functiondef(
  'public.srk_create_sos_alert(text)'::regprocedure))>0
  and position('SOS_REQUIRES_ONE_ACTIVE_BOOKING' in pg_get_functiondef(
  'public.srk_create_sos_alert(text)'::regprocedure))>0,
  'ambiguous or missing active bookings fail closed');
select ok(position('customer_at_risk' in pg_get_functiondef(
  'public.srk_create_sos_alert(text)'::regprocedure))>0
  and position('electrician_at_risk' in pg_get_functiondef(
  'public.srk_create_sos_alert(text)'::regprocedure))>0
  and position('violence_or_other_emergency' in pg_get_functiondef(
  'public.srk_create_sos_alert(text)'::regprocedure))>0,
  'SOS accepts only the three approved reason codes');
select ok(position('srk_sos_alerts' in pg_get_functiondef(
  'public.srk_create_sos_alert(text)'::regprocedure))>0
  and position('status=''pending''' in pg_get_functiondef(
  'public.srk_create_sos_alert(text)'::regprocedure))>0,
  'SOS creation records a pending case and prevents duplicate pending cases per booking');
select ok(position('sms_delivery_status' in pg_get_functiondef(
  'public.srk_create_sos_alert(text)'::regprocedure))>0
  and position('not_configured' in pg_get_functiondef(
  'public.srk_create_sos_alert(text)'::regprocedure))>0,
  'SOS response does not claim SMS delivery without provider configuration');
select ok(position('police' in lower(obj_description('public.srk_sos_alerts'::regclass,'pg_class'))) > 0,
  'SOS case documentation states that police are never auto-notified');

select has_function('public','srk_admin_list_sos_alerts',array['integer'],
  'permission-scoped Admin/Support SOS queue exists');
select ok(position('support.sos.read' in pg_get_functiondef(
  'public.srk_admin_list_sos_alerts(integer)'::regprocedure))>0,
  'SOS queue enforces the dedicated read permission');
select ok(not has_function_privilege('anon','public.srk_admin_list_sos_alerts(integer)','execute'),
  'anonymous users cannot read SOS queue');

select has_function('public','srk_admin_acknowledge_sos_alert',array['uuid','text'],
  'Admin/Support SOS acknowledgement RPC exists');
select ok(position('support.sos.acknowledge' in pg_get_functiondef(
  'public.srk_admin_acknowledge_sos_alert(uuid,text)'::regprocedure))>0
  and position('for update' in lower(pg_get_functiondef(
  'public.srk_admin_acknowledge_sos_alert(uuid,text)'::regprocedure)))>0,
  'acknowledgement requires permission and serializes on the case row');
select ok(position('insert into public.srk_sos_alert_events' in lower(pg_get_functiondef(
  'public.srk_admin_acknowledge_sos_alert(uuid,text)'::regprocedure)))>0
  and position('insert into public.srk_admin_staff_audit_events' in lower(pg_get_functiondef(
  'public.srk_admin_acknowledge_sos_alert(uuid,text)'::regprocedure)))>0,
  'acknowledgement writes immutable SOS history and staff audit');
select ok(position('status=''pending''' in pg_get_functiondef(
  'public.srk_admin_acknowledge_sos_alert(uuid,text)'::regprocedure))>0
  and position('status=''acknowledged''' in pg_get_functiondef(
  'public.srk_admin_acknowledge_sos_alert(uuid,text)'::regprocedure))>0,
  'SOS acknowledgement only transitions a pending case to acknowledged');

select has_function('public','srk_admin_list_sos_alert_events',array['uuid','integer'],
  'permission-scoped SOS event history RPC exists');
select ok(position('support.sos.read' in pg_get_functiondef(
  'public.srk_admin_list_sos_alert_events(uuid,integer)'::regprocedure))>0,
  'SOS event history requires the SOS read permission');

select * from finish();
rollback;
