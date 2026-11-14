begin;
select plan(11);

select ok(
 has_function_privilege('authenticated','public.srk_customer_list_complaint_message_attachments(uuid)','EXECUTE')
 and not has_function_privilege('anon','public.srk_customer_list_complaint_message_attachments(uuid)','EXECUTE'),
 'customer attachment listing is authenticated-only'
);
select ok(
 position('customer_user_id=v_user_id' in lower(pg_get_functiondef('public.srk_customer_list_complaint_message_attachments(uuid)'::regprocedure)))>0,
 'customer attachment listing checks complaint ownership'
);
select ok(
 position('storage_path' in lower(pg_get_function_result('public.srk_customer_list_complaint_message_attachments(uuid)'::regprocedure)))>0,
 'customer receives object path only after ownership validation for signed URL creation'
);
select ok(
 has_function_privilege('authenticated','public.srk_admin_list_booking_complaint_messages(uuid)','EXECUTE')
 and not has_function_privilege('anon','public.srk_admin_list_booking_complaint_messages(uuid)','EXECUTE'),
 'admin message listing is authenticated-only'
);
select ok(
 position('is_srk_admin()' in lower(pg_get_functiondef('public.srk_admin_list_booking_complaint_messages(uuid)'::regprocedure)))>0,
 'admin message listing enforces Admin predicate'
);
select ok(
 position('limit 200' in lower(pg_get_functiondef('public.srk_admin_list_booking_complaint_messages(uuid)'::regprocedure)))>0,
 'admin message listing is bounded'
);

select ok(
  exists (
    select 1
      from pg_class i
      join pg_index x on x.indexrelid=i.oid
     where i.oid='public.srk_booking_complaint_messages_id_thread_uidx'::regclass
       and x.indisunique
       and pg_get_indexdef(i.oid) like '%(id, complaint_id)%'
  ),
  'customer message composite unique key exists for attachment thread integrity'
);

select ok(
  exists (
    select 1
      from pg_constraint c
     where c.conrelid='public.srk_booking_complaint_message_attachments'::regclass
       and c.conname='srk_complaint_attachment_message_thread_fk'
       and c.contype='f'
       and c.convalidated
  ),
  'attachment composite foreign key is present and validated'
);

select ok(
 has_function_privilege('authenticated','public.srk_admin_list_complaint_message_attachments(uuid)','EXECUTE')
 and not has_function_privilege('anon','public.srk_admin_list_complaint_message_attachments(uuid)','EXECUTE'),
 'Admin attachment listing is authenticated-only'
);
select ok(
 position('is_srk_admin()' in lower(pg_get_functiondef('public.srk_admin_list_complaint_message_attachments(uuid)'::regprocedure)))>0
 and position('limit 100' in lower(pg_get_functiondef('public.srk_admin_list_complaint_message_attachments(uuid)'::regprocedure)))>0
 and position('complaint_id=p_complaint_id' in lower(pg_get_functiondef('public.srk_admin_list_complaint_message_attachments(uuid)'::regprocedure)))>0,
 'Admin attachment listing enforces Main Admin access, complaint existence, and bounded results'
);

select ok(
 position('public.is_srk_admin()' in lower(pg_get_functiondef('public.srk_customer_support_object_access(text,boolean)'::regprocedure)))>0
 and position('srk_customer_support_object_access(name,true)' in lower(pg_get_expr((select polqual from pg_policy where polname='srk_customer_support_read_own_or_admin' and polrelid='storage.objects'::regclass),'storage.objects'::regclass)))>0,
 'private support storage read policy allows verified Main Admin while retaining owner checks'
);

select * from finish();
rollback;
