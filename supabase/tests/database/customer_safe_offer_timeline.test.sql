begin;
select plan(12);

select has_table('private','srk_booking_offer_events','private offer event table exists');
select has_function('public','srk_customer_get_my_booking_offer_timeline',array[]::text[],'customer offer timeline RPC exists');
select has_trigger('public','job_offers','trg_srk_capture_booking_offer_event','offer lifecycle trigger exists');
select ok((select c.relrowsecurity from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='private' and c.relname='srk_booking_offer_events'),'offer event table has RLS enabled');
select ok(not has_table_privilege('authenticated','private.srk_booking_offer_events','SELECT'),'authenticated cannot read private offer events directly');
select ok(not has_table_privilege('anon','private.srk_booking_offer_events','SELECT'),'anon cannot read private offer events directly');
select ok(not exists (select 1 from pg_namespace n join pg_proc p on p.pronamespace=n.oid where n.nspname='private' and p.proname='srk_capture_booking_offer_event' and has_function_privilege('authenticated',p.oid,'EXECUTE')),'authenticated cannot execute private capture trigger function');
select ok(not exists (select 1 from pg_namespace n join pg_proc p on p.pronamespace=n.oid where n.nspname='private' and p.proname='srk_capture_booking_offer_event' and has_function_privilege('anon',p.oid,'EXECUTE')),'anon cannot execute private capture trigger function');
select ok(has_function_privilege('authenticated','public.srk_customer_get_my_booking_offer_timeline()','EXECUTE'),'authenticated can execute customer timeline RPC');
select ok(not has_function_privilege('anon','public.srk_customer_get_my_booking_offer_timeline()','EXECUTE'),'anon cannot execute customer timeline RPC');
select ok(position('customer_user_id' in pg_get_functiondef('public.srk_customer_get_my_booking_offer_timeline()'::regprocedure)) > 0,'RPC filters to customer-owned bookings');
select ok(not exists(select 1 from information_schema.columns where table_schema='private' and table_name='srk_booking_offer_events' and column_name='electrician_id'),'private event payload does not store electrician id');

select * from finish();
rollback;
