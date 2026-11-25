
alter table public.srk_worker_earnings
  drop constraint if exists srk_worker_earning_commission_valid;

alter table public.srk_worker_earnings
  add constraint srk_worker_earning_commission_valid
  check (company_commission_rate >= 0 and company_commission_rate <= 100);

create or replace function public.srk_post_one_worker_earning(p_earning_id uuid)
returns void
language plpgsql
security definer
set search_path to 'pg_catalog','public'
as $function$
declare
  v public.srk_worker_earnings%rowtype;
  v_paid text;
  v_refund_pending boolean;
  v_has_helper boolean;
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

  if v.payment_method in ('online','upi','card') then
    insert into public.srk_worker_wallet_ledger(
      worker_id,booking_id,earning_id,entry_type,amount,balance_effect,
      description,idempotency_key
    )
    values(
      v.worker_id,v.booking_id,v.id,'earning',v.net_earning,v.net_earning,
      'Online booking net earning; commission rate snapshot '
        ||to_char(v.company_commission_rate,'FM990D00')||'%',
      'earning:'||v.id::text
    )
    on conflict(idempotency_key) do nothing;

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
