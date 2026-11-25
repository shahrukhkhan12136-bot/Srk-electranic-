
alter table public.srk_worker_earnings add column if not exists admin_note text;

create or replace function public.srk_post_one_worker_earning(p_earning_id uuid)
returns void language plpgsql security definer
set search_path=pg_catalog,public
as $$
declare v public.srk_worker_earnings%rowtype; v_paid text; v_refund_pending boolean; v_has_helper boolean;
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

  if v.payment_method in ('online','upi','card') then
    insert into public.srk_worker_wallet_ledger(worker_id,booking_id,earning_id,entry_type,amount,balance_effect,description,idempotency_key)
    values(v.worker_id,v.booking_id,v.id,'earning',v.net_earning,v.net_earning,
      'Paid online booking net earning after 15% commission','earning:'||v.id::text)
    on conflict(idempotency_key) do nothing;
    update public.srk_worker_earnings set settlement_status='available',payout_status='pending' where id=v.id;
  elsif v.payment_method='cash' then
    select exists(select 1 from public.srk_booking_workers bw
      where bw.booking_id=v.booking_id and bw.worker_role='helper'
        and bw.assignment_status='completed') into v_has_helper;
    if v.worker_role='technician' and not v_has_helper then
      insert into public.srk_worker_wallet_ledger(worker_id,booking_id,earning_id,entry_type,amount,balance_effect,description,idempotency_key)
      values(v.worker_id,v.booking_id,v.id,'cash_commission_due',v.company_commission,-v.company_commission,
        'Cash booking company commission due from technician','cash-commission:'||v.id::text)
      on conflict(idempotency_key) do nothing;
      update public.srk_worker_earnings set settlement_status='cash_commission_due',payout_status='pending' where id=v.id;
    else
      update public.srk_worker_earnings set settlement_status='cash_split_pending',payout_status='held' where id=v.id;
    end if;
  end if;
end $$;

create or replace function public.srk_admin_settle_cash_worker_share(
 p_earning_id uuid,p_actual_cash_share numeric,p_reason text
) returns public.srk_worker_earnings
language plpgsql security definer
set search_path=pg_catalog,public,auth
as $$
declare v public.srk_worker_earnings%rowtype; v_booking_paid text; v_service_total numeric(12,2);
  v_already_allocated numeric(12,2); v_commission numeric(12,2);
begin
  if not public.srk_has_admin_permission('payouts.manage') then raise exception 'Payout management permission required'; end if;
  if p_actual_cash_share is null or p_actual_cash_share<0 or length(coalesce(p_reason,''))<10 then
    raise exception 'Valid cash share and reason are required';
  end if;
  select * into v from public.srk_worker_earnings where id=p_earning_id for update;
  if not found or v.payment_method<>'cash' or v.settlement_status<>'cash_split_pending' then
    raise exception 'Cash earning is not awaiting split settlement';
  end if;
  select b.payment_status,f.service_amount into v_booking_paid,v_service_total
  from public.service_bookings b join public.srk_booking_final_bills f on f.id=v.bill_id
  where b.id=v.booking_id;
  if v_booking_paid<>'paid' then raise exception 'Cash payment must be confirmed before settlement'; end if;
  select coalesce(sum(gross_service_earning),0) into v_already_allocated
  from public.srk_worker_earnings
  where booking_id=v.booking_id and settlement_status='cash_commission_due' and id<>v.id;
  if v_already_allocated+p_actual_cash_share>v_service_total then
    raise exception 'Cash shares exceed total labour amount';
  end if;
  v_commission:=round(p_actual_cash_share*0.15,2);
  update public.srk_worker_earnings set gross_service_earning=p_actual_cash_share,
    company_commission_rate=15.00,company_commission=v_commission,
    net_earning=p_actual_cash_share-v_commission,
    settlement_status='cash_commission_due',payout_status='pending',admin_note=p_reason,updated_at=clock_timestamp()
  where id=p_earning_id returning * into v;

  insert into public.srk_worker_wallet_ledger(worker_id,booking_id,earning_id,entry_type,amount,balance_effect,description,idempotency_key)
  values(v.worker_id,v.booking_id,v.id,'cash_commission_due',v_commission,-v_commission,
    'Admin-settled cash share commission: '||p_reason,'cash-share-commission:'||v.id::text)
  on conflict(idempotency_key) do nothing;
  return v;
end $$;

revoke all on function public.srk_admin_settle_cash_worker_share(uuid,numeric,text) from public,anon;
grant execute on function public.srk_admin_settle_cash_worker_share(uuid,numeric,text) to authenticated;
