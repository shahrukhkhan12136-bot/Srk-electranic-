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
 ('51000000-0000-4000-8000-000000000005','9000000005'),
 ('51000000-0000-4000-8000-000000000006','9000000006')
on conflict(id) do nothing;

create or replace function public.is_srk_admin()
returns boolean
language sql
stable
as $function$
 select auth.uid() = '51000000-0000-4000-8000-000000000006'::uuid
$function$;

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

 -- Legacy quote and work-status RPCs must reject timer-category bookings.
 begin
  perform public.srk_submit_booking_quote(v_booking,500,100,'must be blocked');
  raise exception 'legacy quote RPC unexpectedly accepted a timer booking';
 exception when sqlstate '55000' then
  if sqlerrm <> 'TIMER_BOOKING_REQUIRES_TIMER_BILLING' then raise; end if;
 end;
 begin
  perform public.srk_update_booking_work_status(v_booking,'inspection');
  raise exception 'legacy work-status RPC unexpectedly accepted a timer booking';
 exception when sqlstate '55000' then
  if sqlerrm <> 'TIMER_BOOKING_REQUIRES_TIMER_BILLING' then raise; end if;
 end;
 if (select count(*) from public.srk_get_my_assigned_booking_quote_details()) <> 0 then
  raise exception 'legacy quote-details RPC exposed a timer booking';
 end if;

 v_result := public.srk_electrician_request_timer_start(v_booking,'role-start-key-0001');
 v_start := (v_result->>'decision_id')::uuid;

 perform set_config('request.jwt.claim.sub','51000000-0000-4000-8000-000000000001',true);
 perform set_config('request.jwt.claims','{"phone":"9000000001"}',true);
 begin
  perform public.srk_customer_respond_booking_quote(v_booking,'approved');
  raise exception 'legacy customer quote response unexpectedly accepted a timer booking';
 exception when sqlstate '55000' then
  if sqlerrm <> 'TIMER_BOOKING_REQUIRES_TIMER_BILLING' then raise; end if;
 end;

 perform set_config('request.jwt.claim.sub','51000000-0000-4000-8000-000000000006',true);
 perform set_config('request.jwt.claims','{"phone":"9000000006"}',true);
 begin
  perform public.srk_admin_update_booking(v_booking,null,'Role test address','Balrampur','Uttar Pradesh','271861');
  raise exception 'legacy Admin update unexpectedly accepted a timer booking';
 exception when sqlstate '55000' then
  if sqlerrm <> 'TIMER_BOOKING_REQUIRES_TIMER_ADMIN_WORKFLOW' then raise; end if;
 end;

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

-- A paid/completed timer booking without an immutable payable snapshot must
-- not create a legacy quote-based payout.
do $payout_guard$
declare
 v_booking uuid := '54000000-0000-4000-8000-000000000001';
begin
 insert into public.service_bookings(
  id,customer_name,phone,state,district,pincode,address,service_type,
  customer_user_id,service_category_code,service_category_label,hourly_rate_snapshot
 ) values (
  v_booking,'Missing snapshot timer fixture','9000000001','Uttar Pradesh',
  'Balrampur','271861','Fixture address','Electrical repair',
  '51000000-0000-4000-8000-000000000001','helper','Helper',112.375
 );
 begin
  update public.service_bookings
  set assigned_electrician_id='52000000-0000-4000-8000-000000000003',
      status='completed',quote_status='approved',service_charge=10,
      materials_amount=10,amount_paid=20,payment_status='paid',
      payment_verified_at=pg_catalog.clock_timestamp(),
      razorpay_payment_id='pay_missing_snapshot'
  where id=v_booking;
  raise exception 'timer booking without payable snapshot unexpectedly became paid';
 exception when sqlstate '55000' then
  if sqlerrm <> 'TIMER_PAYABLE_SNAPSHOT_REQUIRED' then raise; end if;
 end;
 if (select payment_status from public.service_bookings where id=v_booking) <> 'unpaid' then
  raise exception 'missing-snapshot timer booking was not kept unpaid';
 end if;
 if exists (select 1 from public.srk_electrician_payouts where booking_id=v_booking) then
  raise exception 'legacy payout was created for timer booking without snapshot';
 end if;
end
$payout_guard$;

rollback;
