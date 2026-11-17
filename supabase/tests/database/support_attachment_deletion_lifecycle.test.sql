begin;
select plan(7);

select ok(
  exists (
    select 1
      from pg_proc p
     where p.oid='public.srk_customer_support_object_delete_access(text)'::regprocedure
       and p.prosecdef
       and p.provolatile='v'
  ),
  'support attachment delete guard is a volatile SECURITY DEFINER function'
);

select ok(
  has_function_privilege('authenticated','public.srk_customer_support_object_delete_access(text)','EXECUTE')
  and not has_function_privilege('anon','public.srk_customer_support_object_delete_access(text)','EXECUTE')
  and not has_function_privilege('public','public.srk_customer_support_object_delete_access(text)','EXECUTE'),
  'support attachment delete guard is callable only by authenticated users'
);

select ok(
  position('srk_customer_support_object_access(p_object_name,false)' in lower(pg_get_functiondef('public.srk_customer_support_object_delete_access(text)'::regprocedure)))>0,
  'generic deletion retains the existing Customer-owned complaint path check and does not grant Main Admin deletion'
);

select ok(
  position('for update' in lower(pg_get_functiondef('public.srk_customer_support_object_delete_access(text)'::regprocedure)))>0
  and position('storage.objects' in lower(pg_get_functiondef('public.srk_customer_support_object_delete_access(text)'::regprocedure)))>0,
  'delete guard locks the exact Storage object row before deciding whether deletion is allowed'
);

select ok(
  position('srk_booking_complaint_message_attachments' in lower(pg_get_functiondef('public.srk_customer_support_object_delete_access(text)'::regprocedure)))>0
  and position('a.storage_path=p_object_name' in lower(pg_get_functiondef('public.srk_customer_support_object_delete_access(text)'::regprocedure)))>0
  and position('return not exists' in lower(pg_get_functiondef('public.srk_customer_support_object_delete_access(text)'::regprocedure)))>0,
  'generic Storage deletion is allowed only while no attachment metadata references the object'
);

select ok(
  position('srk_customer_support_object_delete_access(name)' in lower(pg_get_expr(
    (select polqual
       from pg_policy
      where polname='srk_customer_support_delete_own'
        and polrelid='storage.objects'::regclass),
    'storage.objects'::regclass
  )))>0
  and position('srk-customer-support' in lower(pg_get_expr(
    (select polqual
       from pg_policy
      where polname='srk_customer_support_delete_own'
        and polrelid='storage.objects'::regclass),
    'storage.objects'::regclass
  )))>0,
  'support bucket DELETE policy delegates to the linked-attachment guard'
);

select ok(
  position('for update' in lower(pg_get_functiondef('public.srk_customer_link_complaint_message_attachment(uuid,uuid,text,text,text,bigint)'::regprocedure)))>0
  and position('o.owner_id=v_user_id::text' in lower(pg_get_functiondef('public.srk_customer_link_complaint_message_attachment(uuid,uuid,text,text,text,bigint)'::regprocedure)))>0
  and position('for update' in lower(pg_get_functiondef('public.srk_customer_link_complaint_message_attachment(uuid,uuid,text,text,text,bigint)'::regprocedure)))
      < position('insert into public.srk_booking_complaint_message_attachments' in lower(pg_get_functiondef('public.srk_customer_link_complaint_message_attachment(uuid,uuid,text,text,text,bigint)'::regprocedure))),
  'attachment linker locks the exact Customer-owned Storage object before inserting metadata'
);

select * from finish();
rollback;
