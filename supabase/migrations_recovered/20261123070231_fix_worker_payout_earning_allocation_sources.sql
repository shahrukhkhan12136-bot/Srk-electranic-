
create or replace function public.srk_admin_mark_worker_payout_paid(
 p_payout_id uuid,
 p_payment_method text,
 p_payment_reference text,
 p_note text default null
)
returns public.srk_worker_payout_requests
language plpgsql
security definer
set search_path to 'pg_catalog','public','auth'
as $function$
declare
 v_payout public.srk_worker_payout_requests%rowtype;
 v_available numeric(14,2);
 v_reserved numeric(14,2);
 v_left numeric(14,2);
 v_earning record;
 v_alloc numeric(14,2);
 v_total_allocated numeric(14,2):=0;
begin
 if auth.uid() is null or not public.srk_has_admin_permission('payouts.manage') then
  raise exception 'Payout management permission required' using errcode='42501';
 end if;
 if nullif(btrim(p_payment_reference),'') is null then raise exception 'UTR/transaction reference required'; end if;
 if p_payment_method not in ('upi','bank_transfer','phonepe','other') then raise exception 'Invalid payout method'; end if;

 select * into v_payout from public.srk_worker_payout_requests where id=p_payout_id for update;
 if not found or v_payout.status<>'approved' then raise exception 'Only approved payout can be marked paid'; end if;
 perform 1 from public.srk_worker_profiles where id=v_payout.worker_id for update;
 if exists(select 1 from public.srk_worker_earnings where worker_id=v_payout.worker_id and settlement_status='held') then
  raise exception 'Worker payout is held due to refund/dispute review';
 end if;

 select coalesce(sum(balance_effect),0) into v_available
 from public.srk_worker_wallet_ledger where worker_id=v_payout.worker_id;
 select coalesce(sum(coalesce(approved_amount,requested_amount)),0) into v_reserved
 from public.srk_worker_payout_requests
 where worker_id=v_payout.worker_id and id<>p_payout_id and status in ('requested','under_review','approved');
 if v_payout.approved_amount>v_available-v_reserved then
  raise exception 'Wallet balance changed; payout cannot be paid';
 end if;

 -- Only money actually payable through the online wallet is eligible:
 -- online earnings net of worker refund adjustments, plus cash-commission
 -- refunds specifically credited back to this worker. Cash job earnings
 -- themselves are already received directly by the worker and must not be
 -- paid a second time from the online wallet. Company cash-commission dues
 -- are debt entries, not earning allocations.
 v_left:=v_payout.approved_amount;
 for v_earning in
  select e.id,e.booking_id,e.worker_id,
    (
      case
       when lower(coalesce(e.payment_method,'')) in ('online','upi','card') then
        coalesce((select sum(l.balance_effect) from public.srk_worker_wallet_ledger l
          where l.earning_id=e.id and l.entry_type in ('earning','refund_adjustment')),0)
       when lower(coalesce(e.payment_method,''))='cash' then
        coalesce((select sum(l.balance_effect) from public.srk_worker_wallet_ledger l
          where l.earning_id=e.id and l.entry_type='cash_commission_refund_credit'),0)
       else 0
      end
      - coalesce((select sum(a.allocated_amount) from public.srk_worker_payout_earning_allocations a
        where a.earning_id=e.id),0)
    ) as remaining
  from public.srk_worker_earnings e
  where e.worker_id=v_payout.worker_id
  order by e.created_at,e.id
  for update
 loop
  exit when v_left<=0;
  if v_earning.remaining>0 then
   v_alloc:=least(v_left,v_earning.remaining);
   insert into public.srk_worker_payout_earning_allocations
    (payout_request_id,earning_id,booking_id,worker_id,allocated_amount)
   values(p_payout_id,v_earning.id,v_earning.booking_id,v_earning.worker_id,v_alloc);
   v_left:=v_left-v_alloc;
   v_total_allocated:=v_total_allocated+v_alloc;
  end if;
 end loop;
 if v_left>0 then
  raise exception 'Payout exceeds traceable online earnings or cash-commission refund credits; reconcile wallet before paying';
 end if;

 insert into public.srk_worker_wallet_ledger(worker_id,entry_type,amount,balance_effect,description,reference_id,idempotency_key)
 values(v_payout.worker_id,'payout_paid',v_payout.approved_amount,-v_payout.approved_amount,
  'Admin verified payout with earning-level allocation',p_payment_reference,'payout-paid:'||v_payout.id::text)
 on conflict(idempotency_key) do nothing;

 update public.srk_worker_payout_requests
 set status='paid',payment_method=p_payment_method,payment_reference=p_payment_reference,
  admin_note=coalesce(p_note,admin_note),paid_at=clock_timestamp()
 where id=p_payout_id returning * into v_payout;
 return v_payout;
end
$function$;

revoke all on function public.srk_admin_mark_worker_payout_paid(uuid,text,text,text) from public,anon;
grant execute on function public.srk_admin_mark_worker_payout_paid(uuid,text,text,text) to authenticated,service_role;
