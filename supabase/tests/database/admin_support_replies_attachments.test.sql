begin;
select plan(12);

select ok(
 has_function_privilege('authenticated','public.srk_admin_send_booking_complaint_message(uuid,text)','EXECUTE')
 and not has_function_privilege('anon','public.srk_admin_send_booking_complaint_message(uuid,text)','EXECUTE'),
 'admin reply RPC is authenticated-only'
);
select ok(
 position('is_srk_admin()' in lower(pg_get_functiondef('public.srk_admin_send_booking_complaint_message(uuid,text)'::regprocedure)))>0,
 'admin reply RPC checks admin authorization'
);
select ok(
 position('sender_role' in lower(pg_get_functiondef('public.srk_admin_send_booking_complaint_message(uuid,text)'::regprocedure)))>0,
 'admin reply is recorded with explicit sender role'
);
select ok(
 (select relrowsecurity from pg_class where oid='public.srk_booking_complaint_message_attachments'::regclass),
 'attachment metadata table has RLS enabled'
);
select ok(
 not has_table_privilege('authenticated','public.srk_booking_complaint_message_attachments','SELECT')
 and not has_table_privilege('anon','public.srk_booking_complaint_message_attachments','SELECT'),
 'attachment metadata is not directly readable by client roles'
);
select ok(
 position('customer_user_id=v_user_id' in lower(pg_get_functiondef('public.srk_customer_link_complaint_message_attachment(uuid,uuid,text,text,text,bigint)'::regprocedure)))>0,
 'customer attachment linking verifies complaint ownership'
);
select ok(
 position('sender_user_id=v_user_id' in lower(pg_get_functiondef('public.srk_customer_link_complaint_message_attachment(uuid,uuid,text,text,text,bigint)'::regprocedure)))>0,
 'customer attachment must link to own message'
);
select ok(
 position('storage.objects' in lower(pg_get_functiondef('public.srk_customer_link_complaint_message_attachment(uuid,uuid,text,text,text,bigint)'::regprocedure)))>0,
 'customer attachment linking verifies uploaded object exists'
);
select ok(
 position('10485760' in lower(pg_get_functiondef('public.srk_customer_link_complaint_message_attachment(uuid,uuid,text,text,text,bigint)'::regprocedure)))>0,
 'attachment size is capped at 10 MiB'
);
select ok(
 has_function_privilege('authenticated','public.srk_customer_list_complaint_message_attachments(uuid)','EXECUTE')
 and not has_function_privilege('anon','public.srk_customer_list_complaint_message_attachments(uuid)','EXECUTE'),
 'customer attachment listing is authenticated-only'
);
select ok(
 has_function_privilege('authenticated','public.srk_admin_list_complaint_message_attachments(uuid)','EXECUTE')
 and not has_function_privilege('anon','public.srk_admin_list_complaint_message_attachments(uuid)','EXECUTE'),
 'admin attachment listing is authenticated-only'
);
select ok(
 exists(select 1 from pg_policies where schemaname='storage' and tablename='objects' and policyname='admin reads customer support attachments'),
 'admin can read private support objects only through admin predicate'
);

select * from finish();
rollback;
