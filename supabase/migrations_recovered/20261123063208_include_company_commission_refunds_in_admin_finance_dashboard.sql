
do $migration$
declare
  v_definition text;
  v_old_cte text := $old$
  cash_dues as (
    select coalesce(sum(amount),0)::numeric(14,2) due
    from public.srk_worker_wallet_ledger
    where entry_type='cash_commission_due'
      and (created_at at time zone 'Asia/Kolkata')::date between v_start and v_end
  )
$old$;
  v_new_cte text := $new$
  cash_dues as (
    select coalesce(sum(amount),0)::numeric(14,2) due
    from public.srk_worker_wallet_ledger
    where entry_type='cash_commission_due'
      and (created_at at time zone 'Asia/Kolkata')::date between v_start and v_end
  ),
  company_refunds as (
    select coalesce(sum(commission_refund_amount),0)::numeric(14,2) refunded
    from public.srk_company_commission_refund_reconciliations
    where (recorded_at at time zone 'Asia/Kolkata')::date between v_start and v_end
  )
$new$;
  v_old_json text := $old$
    'platform_commission',(select coalesce(sum(commission),0)::numeric(14,2) from paid_jobs),
    'worker_net_earnings',e.worker_net,
$old$;
  v_new_json text := $new$
    'platform_commission',(select coalesce(sum(commission),0)::numeric(14,2) from paid_jobs),
    'platform_commission_refunded',cr.refunded,
    'platform_commission_net',((select coalesce(sum(commission),0)::numeric(14,2) from paid_jobs)-cr.refunded),
    'worker_net_earnings',e.worker_net,
$new$;
  v_old_from text := $old$
  from bookings b cross join earnings e cross join legacy_only l cross join shared_payouts s cross join cash_dues c;
$old$;
  v_new_from text := $new$
  from bookings b cross join earnings e cross join legacy_only l cross join shared_payouts s cross join cash_dues c cross join company_refunds cr;
$new$;
begin
  select pg_get_functiondef('public.srk_admin_finance_dashboard(text,date)'::regprocedure)
    into v_definition;
  if position(v_old_cte in v_definition)=0
     or position(v_old_json in v_definition)=0
     or position(v_old_from in v_definition)=0 then
    raise exception 'Expected finance dashboard sections not found; migration aborted';
  end if;
  v_definition:=replace(v_definition,v_old_cte,v_new_cte);
  v_definition:=replace(v_definition,v_old_json,v_new_json);
  v_definition:=replace(v_definition,v_old_from,v_new_from);
  execute v_definition;
end
$migration$;
