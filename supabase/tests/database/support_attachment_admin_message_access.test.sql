begin;
select plan(8);

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

select * from finish();
rollback;
