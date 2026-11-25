create or replace function public.srk_post_one_worker_earning(p_earning_id uuid)
returns void
language plpgsql
security definer
set search_path = pg_catalog, public
as $function$
declare
  v public.srk_worker_earnings%rowtype;
  v_paid text;
  v_refund_pending boolean;
  v_has_helper boolean;
  v_cash_due numeric(14,2);
  v_cash_offset numeric(14,2);
  v_wallet_credit numeric(14,2);
begin
  select e.* into v from public.srk_worker_earnings e where e.id=p_earning_id;
  if not found then return; end if;

  select payment_status into v_paid
  from public.service_bookings where id=v.booking_id;
  if lower(coalesce(v_paid,'')) not in ('paid','completed') then return; end if;

  select exists(
    select 1 from public.srk_booking_refund_requests r
    where r.booking_id=v.booking_id and r.status<>'rejected'
  ) into v_refund_pending;
  if v_refund_pending then
    update public.srk_worker_earnings
    set payout_status='held',settlement_status='held'
    where id=v.id;
    return;
  end if;

  -- Serialize wallet recovery with cash collection, payout request and Admin payout.
  perform 1 from public.srk_worker_profiles where id=v.worker_id for update;

  if v.payment_method in ('online','upi','card') then
    select greatest(0,-coalesce(sum(l.balance_effect),0))::numeric(14,2)
      into v_cash_due
    from public.srk_worker_wallet_ledger l
    where l.worker_id=v.worker_id
      and l.entry_type in ('cash_commission_due','cash_commission_collected');

    -- First recover old Cash commission; only the remainder is payout-eligible.
    v_cash_offset:=least(greatest(0,v.net_earning),coalesce(v_cash_due,0));
    v_wallet_credit:=greatest(0,v.net_earning-v_cash_offset);

    insert into public.srk_worker_wallet_ledger(
      worker_id,booking_id,earning_id,entry_type,amount,balance_effect,
      description,idempotency_key
    )
    values(
      v.worker_id,v.booking_id,v.id,'earning',v_wallet_credit,v_wallet_credit,
      'Online booking net earning after recovery of previous Cash commission; rate snapshot '
        ||to_char(v.company_commission_rate,'FM990D00')||'%',
      'earning:'||v.id::text
    )
    on conflict(idempotency_key) do nothing;

    if v_cash_offset>0 then
      insert into public.srk_worker_wallet_ledger(
        worker_id,booking_id,earning_id,entry_type,amount,balance_effect,
        description,reference_id,idempotency_key
      )
      values(
        v.worker_id,v.booking_id,v.id,'cash_commission_collected',
        v_cash_offset,v_cash_offset,
        'Prior Cash commission automatically recovered from this later Online earning',
        v.booking_id::text,
        'cash-commission-offset:'||v.id::text
      )
      on conflict(idempotency_key) do nothing;
    end if;

    update public.srk_worker_earnings
    set settlement_status='available',payout_status='pending'
    where id=v.id;

  elsif v.payment_method='cash' then
    select exists(
      select 1 from public.srk_booking_workers bw
      where bw.booking_id=v.booking_id
        and bw.worker_role='helper'
        and bw.assignment_status='completed'
    ) into v_has_helper;

    if v.worker_role='technician' and not v_has_helper then
      insert into public.srk_worker_wallet_ledger(
        worker_id,booking_id,earning_id,entry_type,amount,balance_effect,
        description,idempotency_key
      )
      values(
        v.worker_id,v.booking_id,v.id,'cash_commission_due',
        v.company_commission,-v.company_commission,
        'Cash booking company commission due; rate snapshot '
          ||to_char(v.company_commission_rate,'FM990D00')||'%',
        'cash-commission:'||v.id::text
      )
      on conflict(idempotency_key) do nothing;

      update public.srk_worker_earnings
      set settlement_status='cash_commission_due',payout_status='pending'
      where id=v.id;
    else
      update public.srk_worker_earnings
      set settlement_status='cash_split_pending',payout_status='held'
      where id=v.id;
    end if;
  end if;
end
$function$;

create or replace function public.srk_worker_get_my_booking_financial_details(p_booking_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = pg_catalog, public, auth
as $function$
declare v_worker uuid; v_result jsonb;
begin
  if auth.uid() is null then raise exception 'Authentication required' using errcode='42501'; end if;
  select wp.id into v_worker from public.srk_worker_profiles wp where wp.user_id=auth.uid() limit 1;
  if v_worker is null then raise exception 'Worker profile not found' using errcode='42501'; end if;
  if not exists(select 1 from public.srk_worker_earnings e where e.booking_id=p_booking_id and e.worker_id=v_worker) then
    raise exception 'This booking has no earning record for the signed-in worker' using errcode='42501';
  end if;
  select jsonb_build_object(
    'booking_id',b.id,'bill_number',fb.bill_number,'bill_status',fb.status,
    'booking_status',b.status,'payment_status',b.payment_status,
    'payment_method',case when lower(b.payment_method) in ('upi','card') then 'online' else lower(b.payment_method) end,
    'customer_paid_amount',case when lower(coalesce(b.payment_status,'')) in ('paid','completed') then coalesce(b.amount_paid,fb.total_amount,0) else coalesce(b.amount_paid,0) end,
    'bill_total',fb.total_amount,'labour_total',fb.service_amount,
    'discount_amount',fb.discount_amount,'tax_amount',fb.tax_amount,
    'cancellation_fee_amount',fb.cancellation_fee_amount,
    'commission_rate',e.company_commission_rate,
    'company_commission_total',coalesce((select sum(x.company_commission) from public.srk_worker_earnings x where x.booking_id=b.id),0),
    'worker_earnings_total',coalesce((select sum(x.net_earning) from public.srk_worker_earnings x where x.booking_id=b.id),0),
    'my_worker_role',e.worker_role,'my_gross_allocation',e.gross_service_earning,
    'my_company_commission',e.company_commission,'my_net_earning',e.net_earning,
    'my_settlement_status',e.settlement_status,'my_payout_status',e.payout_status,
    'my_wallet_credit',coalesce((select sum(l.balance_effect) from public.srk_worker_wallet_ledger l where l.earning_id=e.id and l.entry_type in ('earning','refund_adjustment')),0),
    'my_cash_commission_due',coalesce((select -sum(l.balance_effect) from public.srk_worker_wallet_ledger l where l.earning_id=e.id and l.entry_type='cash_commission_due'),0),
    'my_cash_commission_recovered',coalesce((select sum(l.amount) from public.srk_worker_wallet_ledger l where l.earning_id=e.id and l.idempotency_key='cash-commission-offset:'||e.id::text),0),
    'cash_commission_outstanding',greatest(0,-coalesce((select sum(l.balance_effect) from public.srk_worker_wallet_ledger l where l.worker_id=v_worker and l.entry_type in ('cash_commission_due','cash_commission_collected')),0)),
    'bill_items',coalesce((select jsonb_agg(jsonb_build_object('item_type',i.item_type,'description',i.description,'quantity',i.quantity,'unit',i.unit,'unit_price',i.unit_price,'line_total',i.line_total) order by i.created_at,i.id) from public.srk_booking_final_bill_items i where i.bill_id=fb.id and lower(i.item_type)<>'material'),'[]'::jsonb)
  ) into v_result
  from public.srk_worker_earnings e
  join public.service_bookings b on b.id=e.booking_id
  join public.srk_booking_final_bills fb on fb.id=e.bill_id
  where e.booking_id=p_booking_id and e.worker_id=v_worker
  order by e.created_at desc limit 1;
  return v_result;
end
$function$;
revoke all on function public.srk_worker_get_my_booking_financial_details(uuid) from public,anon;
grant execute on function public.srk_worker_get_my_booking_financial_details(uuid) to authenticated;