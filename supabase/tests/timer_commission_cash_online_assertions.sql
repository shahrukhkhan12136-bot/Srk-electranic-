-- Timer commission integration assertions; run only on disposable CI PostgreSQL.
begin;

create or replace function public.is_srk_admin()
returns boolean language sql stable as $admin_test$
  select current_setting('test.is_admin',true)='on'
$admin_test$;

do $test$
declare
  v_commission numeric(12,2);
  v_online_electrician numeric(12,2);
  v_booking_cash uuid := gen_random_uuid();
  v_booking_online uuid := gen_random_uuid();
  v_customer uuid := gen_random_uuid();
  v_electrician uuid := gen_random_uuid();
  v_profile uuid := gen_random_uuid();
  v_bill_cash uuid := gen_random_uuid();
  v_bill_online uuid := gen_random_uuid();
  v_snapshot_cash uuid := gen_random_uuid();
  v_snapshot_online uuid := gen_random_uuid();
  v_order uuid := gen_random_uuid();
  v_result jsonb;
  v_payout public.srk_electrician_payouts%rowtype;
  v_def text;
begin
  -- ₹600 labour + ₹200 approved materials: commission applies only to labour.
  v_commission := round(600::numeric * 15 / 100, 2);
  v_online_electrician := round(600::numeric + 200::numeric - v_commission, 2);
  if v_commission <> 90.00 then
    raise exception 'Expected 15%% commission of ₹90 on ₹600 labour, got %', v_commission;
  end if;
  if v_online_electrician <> 710.00 then
    raise exception 'Expected online electrician payable ₹710, got %', v_online_electrician;
  end if;
  if v_commission = round(800::numeric * 15 / 100, 2) then
    raise exception 'Commission incorrectly includes materials';
  end if;

  if not exists (
    select 1 from information_schema.columns
    where table_schema='public' and table_name='srk_electrician_payouts'
      and column_name='commission_collection_status'
  ) then raise exception 'Cash commission collection status column missing'; end if;
  if not exists (
    select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public' and p.proname='srk_electrician_submit_cash_commission_remittance'
  ) then raise exception 'Electrician cash commission remittance RPC missing'; end if;
  if not exists (
    select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public' and p.proname='srk_admin_confirm_cash_commission_remittance'
  ) then raise exception 'Admin cash commission confirmation RPC missing'; end if;

  select pg_get_functiondef(p.oid) into v_def
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.proname='srk_create_electrician_payable';
  if position('srk_cash_receipts' in v_def)=0
     or position('srk_razorpay_payments' in v_def)=0
     or position('v_snapshot.labour_amount' in v_def)=0 then
    raise exception 'Payout trigger does not bind Cash/Online evidence and snapshot labour';
  end if;
  select pg_get_functiondef(p.oid) into v_def
  from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.proname='srk_calculate_booking_commission';
  if position('15.00' in v_def)=0 or position('labour_amount' in v_def)=0 then
    raise exception 'Timer commission calculation does not use fixed 15%% labour-only basis';
  end if;

  if has_function_privilege('anon',
      'public.srk_electrician_submit_cash_commission_remittance(uuid,text)','EXECUTE') then
    raise exception 'Anonymous users must not submit cash commission remittance';
  end if;
  if has_function_privilege('anon',
      'public.srk_admin_confirm_cash_commission_remittance(uuid)','EXECUTE') then
    raise exception 'Anonymous users must not confirm commission remittance';
  end if;

  -- Synthetic identities and approved electrician.
  insert into auth.users(id,phone) values
    (v_customer,'9000000001'),(v_electrician,'9000000002');
  insert into public.electrician_profiles(id,user_id,auth_user_id,active,verification_status,display_name)
  values (v_profile,v_electrician,v_electrician,true,'approved','Commission Test Electrician');

  -- Cash path: verified customer receipt means electrician collected the full ₹800.
  insert into public.service_bookings(
    id,customer_user_id,assigned_electrician_id,status,
    service_category_code,service_category_label,hourly_rate_snapshot
  ) values (
    v_booking_cash,v_customer,v_profile,'assigned','helper','Helper',120
  );
  insert into public.srk_final_bills(
    id,booking_id,bill_version,category_code,category_label,hourly_rate,
    started_at,stopped_at,elapsed_seconds,billable_minutes,labour_amount
  ) values (
    v_bill_cash,v_booking_cash,1,'helper','Helper',120,
    timestamptz '2026-01-01 00:00:00+00',timestamptz '2026-01-01 00:05:00+00',300,5,600
  );
  update public.service_bookings
  set timer_state='stopped',final_bill_id=v_bill_cash
  where id=v_booking_cash;
  insert into public.srk_booking_payable_snapshots(
    id,booking_id,bill_id,bill_version,labour_amount,materials_amount,
    total_amount,amount_paise,currency,calculation_version,created_by
  ) values (
    v_snapshot_cash,v_booking_cash,v_bill_cash,1,600,200,800,80000,'INR','test-v1',v_customer
  );
  insert into public.srk_cash_receipts(
    payable_snapshot_id,booking_id,confirmed_by,amount_paise,currency
  ) values (v_snapshot_cash,v_booking_cash,v_electrician,80000,'INR');

  update public.service_bookings
  set status='completed',payment_status='paid',payment_method='Cash',
      amount_paid=800,payment_verified_at=clock_timestamp(),commission_rate=35
  where id=v_booking_cash;

  select * into v_payout from public.srk_electrician_payouts where booking_id=v_booking_cash;
  if not found then raise exception 'Cash booking did not create commission collection ledger row'; end if;
  if v_payout.platform_commission<>90 or v_payout.materials_amount<>200
     or v_payout.electrician_payable<>0 or v_payout.settlement_mode<>'cash'
     or v_payout.commission_collection_status<>'due' then
    raise exception 'Cash commission ledger values are wrong: %',row_to_json(v_payout);
  end if;
  if (select commission_amount from public.service_bookings where id=v_booking_cash)<>90 then
    raise exception 'Cash booking commission_amount is not ₹90 or client commission rate was not overridden';
  end if;

  -- A repeated paid update must remain idempotent (one payout/commission row).
  update public.service_bookings set amount_paid=800 where id=v_booking_cash;
  if (select count(*) from public.srk_electrician_payouts where booking_id=v_booking_cash)<>1 then
    raise exception 'Cash commission ledger duplicated on replay';
  end if;

  perform set_config('request.jwt.claim.sub',v_electrician::text,true);
  v_result := public.srk_electrician_submit_cash_commission_remittance(v_booking_cash,'CASH-UTR-9001');
  if v_result->>'status'<>'submitted' then raise exception 'Electrician cash remittance submission failed: %',v_result; end if;

  perform set_config('request.jwt.claim.sub',v_customer::text,true);
  perform set_config('test.is_admin','on',true);
  v_result := public.srk_admin_confirm_cash_commission_remittance(v_booking_cash);
  if v_result->>'status'<>'received' then raise exception 'Admin cash commission confirmation failed: %',v_result; end if;

  -- Online path: exact Razorpay capture evidence creates a platform-funded net payout.
  insert into public.service_bookings(
    id,customer_user_id,assigned_electrician_id,status,
    service_category_code,service_category_label,hourly_rate_snapshot
  ) values (
    v_booking_online,v_customer,v_profile,'assigned','helper','Helper',120
  );
  insert into public.srk_final_bills(
    id,booking_id,bill_version,category_code,category_label,hourly_rate,
    started_at,stopped_at,elapsed_seconds,billable_minutes,labour_amount
  ) values (
    v_bill_online,v_booking_online,1,'helper','Helper',120,
    timestamptz '2026-01-01 00:00:00+00',timestamptz '2026-01-01 00:05:00+00',300,5,600
  );
  update public.service_bookings
  set timer_state='stopped',final_bill_id=v_bill_online
  where id=v_booking_online;
  insert into public.srk_booking_payable_snapshots(
    id,booking_id,bill_id,bill_version,labour_amount,materials_amount,
    total_amount,amount_paise,currency,calculation_version,created_by
  ) values (
    v_snapshot_online,v_booking_online,v_bill_online,1,600,200,800,80000,'INR','test-v1',v_customer
  );
  insert into public.srk_razorpay_orders(
    id,snapshot_id,booking_id,provider_order_id,amount_paise,currency,
    status,creation_token,lease_expires_at,bound_at
  ) values (
    v_order,v_snapshot_online,v_booking_online,'order_testcommission01',80000,'INR',
    'created',gen_random_uuid(),clock_timestamp()+interval '5 minutes',clock_timestamp()
  );
  insert into public.srk_razorpay_payments(
    provider_payment_id,provider_order_id,snapshot_id,booking_id,
    amount_paise,currency,source
  ) values (
    'pay_testcommission01','order_testcommission01',v_snapshot_online,v_booking_online,
    80000,'INR','webhook'
  );
  update public.service_bookings
  set status='completed',payment_status='paid',payment_method='Online',
      amount_paid=800,razorpay_order_id='order_testcommission01',
      razorpay_payment_id='pay_testcommission01',
      payment_verified_at=clock_timestamp(),commission_rate=2
  where id=v_booking_online;

  select * into v_payout from public.srk_electrician_payouts where booking_id=v_booking_online;
  if not found then raise exception 'Online booking did not create payout ledger row'; end if;
  if v_payout.platform_commission<>90 or v_payout.electrician_payable<>710
     or v_payout.settlement_mode<>'online' or v_payout.payout_status<>'pending' then
    raise exception 'Online payout values are wrong: %',row_to_json(v_payout);
  end if;

  -- Online refund reverses a still-pending payout.
  update public.service_bookings set payment_status='refunded' where id=v_booking_online;
  select * into v_payout from public.srk_electrician_payouts where booking_id=v_booking_online;
  if v_payout.payout_status<>'refunded' then
    raise exception 'Online refund did not reverse pending electrician payout';
  end if;

  perform set_config('test.is_admin','on',true);
  v_result := public.srk_admin_commission_report();
  if (v_result->>'cash_commission_received')::numeric<>90 then
    raise exception 'Admin report does not show received Cash commission: %',v_result;
  end if;
end
$test$;

rollback;
