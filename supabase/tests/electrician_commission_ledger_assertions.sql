-- Rollback-only tests for 15% SRK ELECTRONIC labour commission.
begin;
do $test$
declare
  v_customer uuid := '61000000-0000-4000-8000-000000000001';
  v_electrician uuid := '61000000-0000-4000-8000-000000000002';
  v_profile uuid := '61000000-0000-4000-8000-000000000003';
  v_booking uuid := '61000000-0000-4000-8000-000000000004';
  v_bill uuid := '61000000-0000-4000-8000-000000000005';
  v_snapshot uuid := '61000000-0000-4000-8000-000000000006';
  v_count bigint;
  v_commission numeric(12,2);
  v_net numeric(12,2);
  v_excluded numeric(12,2);
begin
  insert into auth.users(id) values (v_customer),(v_electrician);
  insert into public.electrician_profiles(id,user_id,active,verification_status)
  values (v_profile,v_electrician,true,'approved');
  insert into public.service_bookings(
    id,customer_user_id,assigned_electrician_id,status,payment_status,
    payment_method,service_category_code,service_category_label,
    hourly_rate_snapshot,timer_state
  ) values (
    v_booking,v_customer,v_profile,'completed','unpaid',
    'Cash','helper','Helper',120,'stopped'
  );
  insert into public.srk_final_bills(
    id,booking_id,bill_version,category_code,category_label,hourly_rate,
    started_at,stopped_at,elapsed_seconds,billable_minutes,labour_amount
  ) values (
    v_bill,v_booking,1,'helper','Helper',120,
    clock_timestamp()-interval '60 seconds',clock_timestamp(),60,1,600
  );
  update public.service_bookings set final_bill_id=v_bill where id=v_booking;
  insert into public.srk_booking_payable_snapshots(
    id,booking_id,bill_id,material_revision_id,bill_version,
    labour_amount,materials_amount,total_amount,amount_paise,currency,
    calculation_version,created_by
  ) values (
    v_snapshot,v_booking,v_bill,null,1,
    600,200,800,80000,'INR','commission-test-v1',v_customer
  );

  update public.service_bookings set payment_status='paid' where id=v_booking;
  select count(*),max(commission_amount),max(electrician_net_labour),max(materials_amount_excluded)
    into v_count,v_commission,v_net,v_excluded
  from public.srk_electrician_commissions where booking_id=v_booking;
  if v_count<>1 or v_commission<>90 or v_net<>510 or v_excluded<>200 then
    raise exception 'commission should be 90, electrician net labour 510, materials excluded 200; got %, %, %, %',
      v_count,v_commission,v_net,v_excluded;
  end if;

  -- Repeated unrelated update cannot create another commission row.
  update public.service_bookings set status='completed' where id=v_booking;
  select count(*) into v_count from public.srk_electrician_commissions where booking_id=v_booking;
  if v_count<>1 then raise exception 'commission ledger duplicated for one booking'; end if;

  if has_table_privilege('authenticated','public.srk_electrician_commissions','select') then
    raise exception 'authenticated role unexpectedly has direct commission ledger access';
  end if;
  if has_function_privilege('anon','public.srk_admin_list_electrician_commissions()','execute') then
    raise exception 'anon unexpectedly has Admin commission RPC access';
  end if;
end
$test$;
rollback;
