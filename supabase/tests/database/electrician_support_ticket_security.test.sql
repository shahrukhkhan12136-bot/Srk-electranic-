begin;
select plan(19);

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
  position('auth.uid()' in lower(pg_get_functiondef('public.srk_electrician_list_my_support_tickets()'::regprocedure)))>0
  and position('auth_user_id' in lower(pg_get_functiondef('public.srk_electrician_list_my_support_tickets()'::regprocedure)))>0,
  'electrician ticket listing binds the authenticated uid to the electrician profile auth_user_id'
);

select ok(
  position('t.user_id=v_uid' in lower(pg_get_functiondef('public.srk_electrician_list_my_support_tickets()'::regprocedure)))>0
  and position('p.user_id=v_uid' in lower(pg_get_functiondef('public.srk_electrician_list_my_support_tickets()'::regprocedure)))>0,
  'electrician ticket listing applies ticket-owner and profile-owner filters'
);

select ok(
  position('assigned_electrician_id' in lower(pg_get_functiondef('public.srk_electrician_create_support_ticket(text,text,text,uuid)'::regprocedure)))>0,
  'booking-linked tickets verify assigned_electrician_id ownership'
);

select ok(
  position('admin_note' in lower(pg_get_function_result('public.srk_electrician_list_my_support_tickets()'::regprocedure)))=0,
  'electrician ticket listing never exposes private admin_note'
);

select ok(
  position('support_ticket_not_available' in lower(pg_get_functiondef('public.srk_electrician_list_my_support_messages(uuid)'::regprocedure)))>0
  and position('t.user_id=v_uid' in lower(pg_get_functiondef('public.srk_electrician_list_my_support_messages(uuid)'::regprocedure)))>0,
  'message listing hides tickets not owned by the authenticated electrician'
);

select ok(
  position('is_srk_admin()' in lower(pg_get_functiondef('public.srk_admin_list_electrician_support_tickets(integer)'::regprocedure)))>0
  and position('is_srk_admin()' in lower(pg_get_functiondef('public.srk_admin_update_electrician_support_ticket(uuid,text,text)'::regprocedure)))>0,
  'Admin read and update RPCs explicitly enforce is_srk_admin()'
);

select ok(
  position('auth.uid()' in lower(pg_get_functiondef('public.srk_admin_list_electrician_support_tickets(integer)'::regprocedure)))>0
  and position('is_srk_admin()' in lower(pg_get_functiondef('public.srk_admin_list_electrician_support_messages(uuid)'::regprocedure)))>0,
  'Admin support RPCs require an authenticated Admin identity'
);

select * from finish();
rollback;
