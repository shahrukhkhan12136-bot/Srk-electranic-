-- Re-run marker: authenticated-role RPC execution assertions are part of branch CI.
-- Disposable role/JWT execution test for authenticated customer and electrician RPCs.
-- This exercises PostgreSQL role grants and auth.uid()/auth.jwt() claims, but is
-- not a substitute for a live Supabase Auth/RLS policy test on Main Production.
begin;

do $privileges$
begin
  if has_function_privilege('anon','public.srk_create_customer_booking(jsonb,uuid)','EXECUTE') then
    raise exception 'anon must not execute customer booking creation';
  end if;
  if not has_function_privilege('authenticated','public.srk_create_customer_booking(jsonb,uuid)','EXECUTE') then
    raise exception 'authenticated must execute customer booking creation';
  end if;
  if not has_function_privilege('authenticated','public.srk_electrician_record_arrival(uuid,text)','EXECUTE') then
    raise exception 'authenticated must execute electrician arrival RPC';
  end if;
  if has_function_privilege('authenticated','public.srk_claim_razorpay_snapshot_order(uuid,uuid)','EXECUTE') then
    raise exception 'authenticated must not claim service-role Razorpay orders';
  end if;
  if not has_function_privilege('service_role','public.srk_claim_razorpay_snapshot_order(uuid,uuid)','EXECUTE') then
    raise exception 'service_role must claim Razorpay orders';
  end if;
end
$privileges$;

insert into auth.users(id,phone) values
 ('51000000-0000-4000-8000-000000000001','9000000001'),
 ('51000000-0000-4000-8000-000000000002','9000000002'),
 ('51000000-0000-4000-8000-000000000005','9000000005')
on conflict(id) do nothing;

insert into public.electrician_profiles(
 id,user_id,auth_user_id,active,verification_status,display_name,phone,state,district,pincode,skills
) values (
 '52000000-0000-4000-8000-000000000003',
 '51000000-0000-4000-8000-000000000002',
 '51000000-0000-4000-8000-000000000002',
 true,'approved','Role Test Electrician','9000000002',
 'Uttar Pradesh','Balrampur','271861',array['electrical']
);

create temporary table srk_role_test_ids(
 key text primary key,
 id uuid not null
) on commit drop;
grant all on table pg_temp.srk_role_test_ids to authenticated;

set local role authenticated;
select set_config('request.jwt.claim.sub','51000000-0000-4000-8000-000000000001',true);
select set_config('request.jwt.claims','{"phone":"9000000001"}',true);

do $customer_booking$
declare
 v_result jsonb;
 v_booking uuid;
begin
 v_result := public.srk_create_customer_booking(
  jsonb_build_object(
   'customer_name','Role Test Customer',
   'phone','9000000001',
   'state','Uttar Pradesh',
   'district','Balrampur',
   'pincode','271861',
   'address','Role test address',
   'service_type','Electrical repair',
   'preferred_date','2026-11-12',
   'preferred_time','10:00',
   'work_details','Role/JWT runtime test',
   'service_category_code','helper'
  ),
  '53000000-0000-4000-8000-000000000001'
 );
 if coalesce((v_result->>'success')::boolean,false) is not true
    or v_result->>'service_category_code'<>'helper'
    or (v_result->>'hourly_rate_snapshot')::numeric<>112.375 then
  raise exception 'authenticated customer booking RPC failed: %',v_result;
 end if;
 v_booking := (v_result->>'booking_id')::uuid;
 insert into pg_temp.srk_role_test_ids(key,id) values ('booking',v_booking);
end
$customer_booking$;
reset role;

-- Follow the real post-creation assignment sequence: insert unassigned booking,
-- create offer, then assign after the electrician accepts.
insert into public.job_offers(booking_id,electrician_id,status)
select id,'52000000-0000-4000-8000-000000000003','accepted'
from pg_temp.srk_role_test_ids where key='booking';
update public.service_bookings
set assigned_electrician_id='52000000-0000-4000-8000-000000000003',status='assigned'
where id=(select id from pg_temp.srk_role_test_ids where key='booking');

set local role authenticated;
select set_config('request.jwt.claim.sub','51000000-0000-4000-8000-000000000002',true);
select set_config('request.jwt.claims','{"phone":"9000000002"}',true);

do $electrician_timer$
declare
 v_booking uuid := (select id from pg_temp.srk_role_test_ids where key='booking');
 v_result jsonb;
 v_start uuid;
 v_stop uuid;
 v_bill uuid;
begin
 v_result := public.srk_electrician_record_arrival(v_booking,'role-arrival-key-0001');
 if coalesce((v_result->>'success')::boolean,false) is not true then
  raise exception 'authenticated electrician arrival RPC failed: %',v_result;
 end if;
 v_result := public.srk_electrician_request_timer_start(v_booking,'role-start-key-0001');
 v_start := (v_result->>'decision_id')::uuid;

 perform set_config('request.jwt.claim.sub','51000000-0000-4000-8000-000000000001',true);
 perform set_config('request.jwt.claims','{"phone":"9000000001"}',true);
 v_result := public.srk_customer_decide_timer_start(v_start,'approved');
 if v_result->>'decision'<>'approved' then
  raise exception 'authenticated customer timer-start approval failed: %',v_result;
 end if;

 perform set_config('request.jwt.claim.sub','51000000-0000-4000-8000-000000000002',true);
 perform set_config('request.jwt.claims','{"phone":"9000000002"}',true);
 v_result := public.srk_electrician_request_timer_stop(v_booking,'role-stop-key-0001');
 v_stop := (v_result->>'decision_id')::uuid;

 perform set_config('request.jwt.claim.sub','51000000-0000-4000-8000-000000000001',true);
 perform set_config('request.jwt.claims','{"phone":"9000000001"}',true);
 v_result := public.srk_customer_decide_timer_stop(v_stop,'approved');
 if v_result->>'decision'<>'approved' then
  raise exception 'authenticated customer timer-stop approval failed: %',v_result;
 end if;
 v_bill := (v_result->>'bill_id')::uuid;
 v_result := public.srk_get_booking_timer_bill_details(v_booking);
 if v_result->>'booking_id'<>v_booking::text
    or v_result->'final_bill'->>'id'<>v_bill::text
    or v_result->'final_bill'->>'category_code'<>'helper' then
  raise exception 'authenticated customer scoped bill read did not return the expected final bill: %',v_result;
 end if;

 perform set_config('request.jwt.claim.sub','51000000-0000-4000-8000-000000000005',true);
 perform set_config('request.jwt.claims','{"phone":"9000000005"}',true);
 begin
  perform public.srk_get_booking_timer_bill_details(v_booking);
  raise exception 'unrelated authenticated user unexpectedly read booking details';
 exception when insufficient_privilege then
  null;
 end;
end
$electrician_timer$;
reset role;

rollback;
