
do $migration$
declare
  v_definition text;
  v_old_decl text := $old$
  v_company_refund numeric(12,2);
begin
$old$;
  v_new_decl text := $new$
  v_company_refund numeric(12,2);
  v_unresolved_refund boolean;
begin
$new$;
  v_old_update text := $old$
  update public.srk_worker_earnings
  set payout_status='pending',
      settlement_status=case
        when v_earning_allocated + p_worker_refund_amount >= v_earning.net_earning then 'reversed'
        when payment_method='cash' and worker_role='technician' then 'cash_commission_due'
        when payment_method='cash' and worker_role='helper' then 'cash_split_pending'
        else 'available'
      end,
      updated_at=clock_timestamp()
  where id=p_earning_id;
$old$;
  v_new_update text := $new$
  select exists(
    select 1
    from public.srk_booking_refund_requests r
    where r.booking_id=v_earning.booking_id
      and r.status<>'rejected'
      and not exists(
        select 1 from public.srk_worker_refund_allocations a
        where a.refund_request_id=r.id and a.earning_id=p_earning_id
      )
  ) into v_unresolved_refund;

  update public.srk_worker_earnings
  set payout_status=case when v_unresolved_refund then 'held' else 'pending' end,
      settlement_status=case
        when v_unresolved_refund then 'held'
        when v_earning_allocated + p_worker_refund_amount >= v_earning.net_earning then 'reversed'
        when payment_method='cash' and worker_role='technician' then 'cash_commission_due'
        when payment_method='cash' and worker_role='helper' then 'cash_split_pending'
        else 'available'
      end,
      updated_at=clock_timestamp()
  where id=p_earning_id;
$new$;
begin
  select pg_get_functiondef('public.srk_admin_resolve_worker_refund_allocation(uuid,uuid,numeric,text)'::regprocedure)
    into v_definition;
  if position(v_old_decl in v_definition)=0 or position(v_old_update in v_definition)=0 then
    raise exception 'Expected refund allocation sections not found; migration aborted';
  end if;
  v_definition:=replace(v_definition,v_old_decl,v_new_decl);
  v_definition:=replace(v_definition,v_old_update,v_new_update);
  execute v_definition;
end
$migration$;
