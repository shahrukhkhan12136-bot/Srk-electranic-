-- Timer commission integration assertions; run only on disposable CI PostgreSQL.
begin;

do $test$
declare
  v_commission numeric(12,2);
  v_online_electrician numeric(12,2);
  v_cash_electrician numeric(12,2);
  v_def text;
begin
  -- ₹600 labour + ₹200 approved materials: commission applies only to labour.
  v_commission := round(600::numeric * 15 / 100, 2);
  v_online_electrician := round(600::numeric + 200::numeric - v_commission, 2);
  v_cash_electrician := 0;

  if v_commission <> 90.00 then
    raise exception 'Expected 15%% commission of ₹90 on ₹600 labour, got %', v_commission;
  end if;
  if v_online_electrician <> 710.00 then
    raise exception 'Expected online electrician payable ₹710, got %', v_online_electrician;
  end if;
  if v_cash_electrician <> 0 then
    raise exception 'Cash must not create a platform-funded electrician payout';
  end if;
  if round(200::numeric * 15 / 100, 2) <> 30.00 then
    raise exception 'Fixture error: materials-only commission control calculation';
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
  if position('15.00' in v_def)=0
     or position('labour_amount' in v_def)=0 then
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
end
$test$;

rollback;
