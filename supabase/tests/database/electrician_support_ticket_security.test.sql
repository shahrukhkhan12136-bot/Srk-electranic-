begin;
select plan(17);

select ok(
  to_regclass('public.srk_electrician_support_tickets') is not null
  and to_regclass('public.srk_electrician_support_messages') is not null,
  'electrician support ticket and message tables exist'
);

select ok(
  (select relrowsecurity from pg_class where oid='public.srk_electrician_support_tickets'::regclass)
  and (select relrowsecurity from pg_class where oid='public.srk_electrician_support_messages'::regclass),
  'both electrician support tables have RLS enabled'
);

select ok(
  not has_table_privilege('anon','public.srk_electrician_support_tickets','SELECT')
  and not has_table_privilege('authenticated','public.srk_electrician_support_tickets','SELECT')
  and not has_table_privilege('anon','public.srk_electrician_support_messages','SELECT')
  and not has_table_privilege('authenticated','public.srk_electrician_support_messages','SELECT'),
  'browser roles cannot directly read electrician support tables'
);

select ok(
  not has_table_privilege('authenticated','public.srk_electrician_support_tickets','INSERT')
  and not has_table_privilege('authenticated','public.srk_electrician_support_tickets','UPDATE')
  and not has_table_privilege('authenticated','public.srk_electrician_support_messages','INSERT')
  and not has_table_privilege('authenticated','public.srk_electrician_support_messages','UPDATE'),
  'browser roles cannot directly mutate electrician support tables'
);

select ok(
  has_function_privilege('authenticated','public.srk_electrician_create_support_ticket(text,text,text,uuid)','EXECUTE')
  and not has_function_privilege('anon','public.srk_electrician_create_support_ticket(text,text,text,uuid)','EXECUTE'),
  'ticket creation RPC is authenticated-only'
);

select ok(
  has_function_privilege('authenticated','public.srk_electrician_list_my_support_tickets()','EXECUTE')
  and has_function_privilege('authenticated','public.srk_electrician_list_my_support_messages(uuid)','EXECUTE')
  and not has_function_privilege('anon','public.srk_electrician_list_my_support_tickets()','EXECUTE')
  and not has_function_privilege('anon','public.srk_electrician_list_my_support_messages(uuid)','EXECUTE'),
  'electrician own-ticket read RPCs are authenticated-only'
);

select ok(
  has_function_privilege('authenticated','public.srk_electrician_send_support_message(uuid,text)','EXECUTE')
  and not has_function_privilege('anon','public.srk_electrician_send_support_message(uuid,text)','EXECUTE'),
  'electrician reply RPC is authenticated-only'
);

select ok(
  has_function_privilege('authenticated','public.srk_admin_list_electrician_support_tickets(integer)','EXECUTE')
  and has_function_privilege('authenticated','public.srk_admin_list_electrician_support_messages(uuid)','EXECUTE')
  and has_function_privilege('authenticated','public.srk_admin_send_electrician_support_message(uuid,text)','EXECUTE')
  and has_function_privilege('authenticated','public.srk_admin_update_electrician_support_ticket(uuid,text,text)','EXECUTE'),
  'Main Admin support inbox RPCs are executable by authenticated callers and enforce Admin identity internally'
);

select ok(
  not has_function_privilege('anon','public.srk_admin_list_electrician_support_tickets(integer)','EXECUTE')
  and not has_function_privilege('anon','public.srk_admin_list_electrician_support_messages(uuid)','EXECUTE')
  and not has_function_privilege('anon','public.srk_admin_send_electrician_support_message(uuid,text)','EXECUTE')
  and not has_function_privilege('anon','public.srk_admin_update_electrician_support_ticket(uuid,text,text)','EXECUTE'),
  'anonymous callers cannot execute Main Admin support inbox RPCs'
);

select ok(
  position('for update' in lower(pg_get_functiondef('public.srk_electrician_send_support_message(uuid,text)'::regprocedure)))>0
  and position('for update' in lower(pg_get_functiondef('public.srk_admin_send_electrician_support_message(uuid,text)'::regprocedure)))>0,
  'electrician and Admin message writes serialize on the ticket row'
);

select ok(
  exists (
    select 1 from pg_constraint
     where conrelid='public.srk_electrician_support_tickets'::regclass
       and contype='c'
       and pg_get_constraintdef(oid) like '%booking%'
       and pg_get_constraintdef(oid) like '%customer_safety%'
  ),
  'ticket category constraint includes only the approved electrician support categories'
);

select ok(
  exists (
    select 1 from pg_constraint
     where conrelid='public.srk_electrician_support_tickets'::regclass
       and contype='c'
       and pg_get_constraintdef(oid) like '%open%'
       and pg_get_constraintdef(oid) like '%closed%'
  )
  and exists (
    select 1 from pg_constraint
     where conrelid='public.srk_electrician_support_messages'::regclass
       and contype='c'
       and pg_get_constraintdef(oid) like '%electrician%'
       and pg_get_constraintdef(oid) like '%admin%'
  ),
  'ticket status and message sender role constraints are present'
);

select ok(
  position('public.is_srk_admin()' in pg_get_functiondef('public.srk_admin_list_electrician_support_tickets(integer)'::regprocedure))>0
  and position('public.is_srk_admin()' in pg_get_functiondef('public.srk_admin_list_electrician_support_messages(uuid)'::regprocedure))>0
  and position('public.is_srk_admin()' in pg_get_functiondef('public.srk_admin_send_electrician_support_message(uuid,text)'::regprocedure))>0
  and position('public.is_srk_admin()' in pg_get_functiondef('public.srk_admin_update_electrician_support_ticket(uuid,text,text)'::regprocedure))>0,
  'legacy electrician support inbox RPCs remain Main Admin-only'
);

select ok(
  position('support.electrician.read' in pg_get_functiondef('public.srk_admin_staff_list_electrician_tickets()'::regprocedure))>0
  and position('support.electrician.read' in pg_get_functiondef('public.srk_admin_staff_list_electrician_messages(uuid)'::regprocedure))>0
  and position('support.electrician.reply' in pg_get_functiondef('public.srk_admin_staff_send_electrician_message(uuid,text)'::regprocedure))>0
  and position('support.electrician.update_status' in pg_get_functiondef('public.srk_admin_staff_update_electrician_ticket(uuid,text,text)'::regprocedure))>0,
  'Staff electrician support RPCs enforce their separate RBAC permissions'
);

select ok(
  position('support.electrician.read' in lower(pg_get_functiondef('public.srk_admin_staff_list_electrician_tickets()'::regprocedure)))>0
  and position('booking.read_basic' in lower(pg_get_functiondef('public.srk_admin_staff_list_electrician_tickets()'::regprocedure)))>0
  and position('support.electrician.read' in lower(pg_get_functiondef('public.srk_admin_staff_list_electrician_messages(uuid)'::regprocedure)))>0
  and position('support.electrician.read' in lower(pg_get_functiondef('public.srk_admin_staff_send_electrician_message(uuid,text)'::regprocedure)))>0
  and position('support.electrician.reply' in lower(pg_get_functiondef('public.srk_admin_staff_send_electrician_message(uuid,text)'::regprocedure)))>0
  and position('support.electrician.read' in lower(pg_get_functiondef('public.srk_admin_staff_update_electrician_ticket(uuid,text,text)'::regprocedure)))>0
  and position('support.electrician.update_status' in lower(pg_get_functiondef('public.srk_admin_staff_update_electrician_ticket(uuid,text,text)'::regprocedure)))>0,
  'each Staff electrician-support operation enforces its exact read, reply, status and booking-read permission gates'
);

select ok(
  position('for share of t,a' in lower(pg_get_functiondef('public.srk_admin_staff_list_electrician_tickets()'::regprocedure)))>0
  and position('for share' in lower(pg_get_functiondef('public.srk_admin_staff_list_electrician_messages(uuid)'::regprocedure)))>0
  and position('for update' in lower(pg_get_functiondef('public.srk_admin_staff_send_electrician_message(uuid,text)'::regprocedure)))>0
  and position('for update' in lower(pg_get_functiondef('public.srk_admin_staff_update_electrician_ticket(uuid,text,text)'::regprocedure)))>0
  and position('from public.srk_electrician_support_tickets t' in lower(pg_get_functiondef('public.srk_admin_staff_send_electrician_message(uuid,text)'::regprocedure)))
      < position('from public.srk_admin_support_assignments a' in lower(pg_get_functiondef('public.srk_admin_staff_send_electrician_message(uuid,text)'::regprocedure)))
  and position('from public.srk_electrician_support_tickets t' in lower(pg_get_functiondef('public.srk_admin_staff_update_electrician_ticket(uuid,text,text)'::regprocedure)))
      < position('from public.srk_admin_support_assignments a' in lower(pg_get_functiondef('public.srk_admin_staff_update_electrician_ticket(uuid,text,text)'::regprocedure)),
  'Staff electrician support reads and writes lock case/assignment rows in the required order'
);

select ok(
  (
    select count(*)=4
      from pg_proc p
     where p.oid in (
       'public.srk_admin_list_electrician_support_tickets(integer)'::regprocedure,
       'public.srk_admin_list_electrician_support_messages(uuid)'::regprocedure,
       'public.srk_admin_send_electrician_support_message(uuid,text)'::regprocedure,
       'public.srk_admin_update_electrician_support_ticket(uuid,text,text)'::regprocedure
     )
       and p.prosecdef
       and p.provolatile in ('s','v')
       and coalesce(p.proconfig::text,'') like '%search_path=""%'
  )
  and (
    select count(*)=4
      from pg_proc p
     where p.oid in (
       'public.srk_admin_list_electrician_support_tickets(integer)'::regprocedure,
       'public.srk_admin_list_electrician_support_messages(uuid)'::regprocedure,
       'public.srk_admin_send_electrician_support_message(uuid,text)'::regprocedure,
       'public.srk_admin_update_electrician_support_ticket(uuid,text,text)'::regprocedure
     )
       and has_function_privilege('authenticated',p.oid,'EXECUTE')
       and not has_function_privilege('anon',p.oid,'EXECUTE')
       and not exists (
         select 1 from aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) acl
          where acl.grantee=0 and acl.privilege_type='EXECUTE'
       )
  ),
  'all four legacy Admin inbox RPCs use a hardened definer context and authenticated-only execution'
);

select * from finish();
rollback;
