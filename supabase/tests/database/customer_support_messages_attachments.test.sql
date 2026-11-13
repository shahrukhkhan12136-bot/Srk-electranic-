begin;
select plan(14);

select ok(
  (select relrowsecurity from pg_class where oid='public.srk_booking_complaint_messages'::regclass),
  'message table has RLS enabled'
);
select ok(
  not has_table_privilege('anon','public.srk_booking_complaint_messages','SELECT')
  and not has_table_privilege('authenticated','public.srk_booking_complaint_messages','SELECT'),
  'message table is not directly exposed to client roles'
);
select ok(
  has_function_privilege('authenticated','public.srk_customer_send_booking_complaint_message(uuid,text)','EXECUTE')
  and not has_function_privilege('anon','public.srk_customer_send_booking_complaint_message(uuid,text)','EXECUTE'),
  'send-message RPC is authenticated only'
);
select ok(
  has_function_privilege('authenticated','public.srk_customer_list_booking_complaint_messages(uuid)','EXECUTE')
  and not has_function_privilege('anon','public.srk_customer_list_booking_complaint_messages(uuid)','EXECUTE'),
  'list-message RPC is authenticated only'
);
select ok(
  position('auth.uid()' in lower(pg_get_functiondef('public.srk_customer_send_booking_complaint_message(uuid,text)'::regprocedure))) > 0,
  'send RPC derives identity from auth.uid'
);
select ok(
  position('customer_user_id = v_user_id' in lower(pg_get_functiondef('public.srk_customer_send_booking_complaint_message(uuid,text)'::regprocedure))) > 0,
  'send RPC verifies complaint ownership'
);
select ok(
  position('status <> ''closed''' in lower(pg_get_functiondef('public.srk_customer_send_booking_complaint_message(uuid,text)'::regprocedure))) > 0,
  'closed complaints reject new customer messages'
);
select ok(
  position('length(btrim(p_body)) > 4000' in lower(pg_get_functiondef('public.srk_customer_send_booking_complaint_message(uuid,text)'::regprocedure))) > 0,
  'message length is bounded'
);
select ok(
  position('customer_user_id = v_user_id' in lower(pg_get_functiondef('public.srk_customer_list_booking_complaint_messages(uuid)'::regprocedure))) > 0,
  'list RPC verifies complaint ownership before returning messages'
);
select ok(
  position('limit 200' in lower(pg_get_functiondef('public.srk_customer_list_booking_complaint_messages(uuid)'::regprocedure))) > 0,
  'message history is bounded'
);
select ok(
  (select not public from storage.buckets where id='srk-customer-support'),
  'support attachment bucket is private'
);
select ok(
  exists (select 1 from pg_policies where schemaname='storage' and tablename='objects' and policyname='customer uploads support attachments to own complaint'),
  'upload policy binds object path to customer and owned complaint'
);
select ok(
  exists (select 1 from pg_policies where schemaname='storage' and tablename='objects' and policyname='customer reads support attachments for own complaint'),
  'read policy binds object path to customer and owned complaint'
);
select ok(
  exists (select 1 from pg_policies where schemaname='storage' and tablename='objects' and policyname='customer deletes support attachments for own complaint'),
  'delete policy binds object path to customer and owned complaint'
);

select * from finish();
rollback;
