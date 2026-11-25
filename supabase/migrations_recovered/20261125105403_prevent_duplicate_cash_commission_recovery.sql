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
  select payment_status into v_paid from public.service_bookings where id=v.booking_id;
  if lower(coalesce(v_paid,'')) not in ('paid','completed') then return; end if;
  select exists(select 1 from public.srk_booking_refund_requests r where r.booking_id=v.booking_id and r.status<>'rejected')
    into v_refund_pending;
  if v_refund_pending then
    update public.srk_worker_earnings set payout_status='held',settlement_status='held' where id=v.id;
    return;
  end if;

  perform 1 from public.srk_worker_profiles where id=v.worker_id for update;

  if v.payment_method in ('online','upi','card') then
    -- An earning already posted before this recovery rule must not be offset twice on retry.
    if exists(select 1 from public.srk_worker_wallet_ledger l where l.idempotency_key='earning:'||v.id::text) then
      update public.srk_worker_earnings set settlement_status='available',payout_status='pending' where id=v.id;
      return;
    end if;

    select greatest(0,-coalesce(sum(l.balance_effect),0))::numeric(14,2)
      into v_cash_due
    from public.srk_worker_wallet_ledger l
    where l.worker_id=v.worker_id
      and l.entry_type in ('cash_commission_due','cash_commission_collected');
    v_cash_offset:=least(greatest(0,v.net_earning),coalesce(v_cash_due,0));
    v_wallet_credit:=greatest(0,v.net_earning-v_cash_offset);

    insert into public.srk_worker_wallet_ledger(
      worker_id,booking_id,earning_id,entry_type,amount,balance_effect,description,idempotency_key
    ) values (
      v.worker_id,v.booking_id,v.id,'earning',v_wallet_credit,v_wallet_credit,
      'Online booking net earning after recovery of previous Cash commission; rate snapshot '||to_char(v.company_commission_rate,'FM990D00')||'%',
      'earning:'||v.id::text
    );

    if v_cash_offset>0 then
      insert into public.srk_worker_wallet_ledger(
        worker_id,booking_id,earning_id,entry_type,amount,balance_effect,description,reference_id,idempotency_key
      ) values (
        v.worker_id,v.booking_id,v.id,'cash_commission_collected',v_cash_offset,v_cash_offset,
        'Prior Cash commission automatically recovered from this later Online earning',
        v.booking_id::text,'cash-commission-offset:'||v.id::text
      ) on conflict(idempotency_key) do nothing;
    end if;
    update public.srk_worker_earnings set settlement_status='available',payout_status='pending' where id=v.id;

  elsif v.payment_method='cash' then
    select exists(
      select 1 from public.srk_booking_workers bw
      where bw.booking_id=v.booking_id and bw.worker_role='helper' and bw.assignment_status='completed'
    ) into v_has_helper;
    if v.worker_role='technician' and not v_has_helper then
      insert into public.srk_worker_wallet_ledger(
        worker_id,booking_id,earning_id,entry_type,amount,balance_effect,description,idempotency_key
      ) values (
        v.worker_id,v.booking_id,v.id,'cash_commission_due',v.company_commission,-v.company_commission,
        'Cash booking company commission due; rate snapshot '||to_char(v.company_commission_rate,'FM990D00')||'%',
        'cash-commission:'||v.id::text
      ) on conflict(idempotency_key) do nothing;
      update public.srk_worker_earnings set settlement_status='cash_commission_due',payout_status='pending' where id=v.id;
    else
      update public.srk_worker_earnings set settlement_status='cash_split_pending',payout_status='held' where id=v.id;
    end if;
  end if;
end
$function$;