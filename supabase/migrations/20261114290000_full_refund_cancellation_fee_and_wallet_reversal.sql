-- Full-refund accounting reversal for cancellation-fee carry-forward.
-- Feature branch source only. This migration is NOT applied to any database.
-- Current refund RPCs are full-amount only; partial refunds deliberately fail closed.

alter table public.srk_cancellation_fee_ledger
  add column if not exists reversal_of_entry_id uuid
    references public.srk_cancellation_fee_ledger(id) on delete restrict;

create unique index if not exists srk_cancellation_fee_ledger_one_reversal_per_entry
  on public.srk_cancellation_fee_ledger(reversal_of_entry_id)
  where reversal_of_entry_id is not null;

create or replace function public.srk_reverse_cancellation_fees_on_full_refund()
returns trigger
language plpgsql
security definer
set search_path=''
as $$
declare
  v_refund_id uuid;
  v_refund_amount_paise bigint;
  v_item record;
  v_original public.srk_cancellation_fee_ledger%rowtype;
  v_wallet_entry public.srk_wallet_ledger%rowtype;
  v_debt_count integer:=0;
  v_wallet_id uuid;
begin
  if old.payment_status is not distinct from new.payment_status
     or new.payment_status<>'refunded' then
    return new;
  end if;

  if old.payment_status<>'paid' or coalesce(old.amount_paid,0)<=0 then
    raise exception 'ONLY_A_VERIFIED_PAID_BOOKING_CAN_BE_REFUNDED' using errcode='55000';
  end if;

  v_refund_amount_paise:=round(old.amount_paid*100)::bigint;

  if old.razorpay_payment_id is not null then
    select r.id,r.amount_paise into v_refund_id,v_refund_amount_paise
    from public.srk_razorpay_refunds r
    where r.booking_id=old.id
      and r.payment_id=old.razorpay_payment_id
      and r.status='processed'
      and r.amount_paise=round(old.amount_paid*100)::bigint
    order by r.processed_at desc nulls last,r.created_at desc
    limit 1
    for update;
    if not found then
      raise exception 'VERIFIED_FULL_RAZORPAY_REFUND_RECORD_REQUIRED' using errcode='55000';
    end if;
  else
    select r.id,round(r.amount*100)::bigint
      into v_refund_id,v_refund_amount_paise
    from public.srk_manual_refund_entries r
    where r.booking_id=old.id
      and round(r.amount,2)=round(old.amount_paid,2)
    order by r.recorded_at desc
    limit 1
    for update;
    if not found then
      raise exception 'VERIFIED_FULL_MANUAL_REFUND_RECORD_REQUIRED' using errcode='55000';
    end if;
    if v_refund_amount_paise<>round(old.amount_paid*100)::bigint then
      raise exception 'PARTIAL_REFUND_NOT_SUPPORTED_FOR_CANCELLATION_FEE_REVERSAL' using errcode='55000';
    end if;
  end if;

  for v_item in
    select i.*
    from public.srk_booking_cancellation_fee_items i
    where i.booking_id=old.id and i.status='settled'
    order by i.created_at,i.id
    for update
  loop
    if old.razorpay_payment_id is not null then
      select l.* into v_original
      from public.srk_cancellation_fee_ledger l
      where l.debt_id=v_item.debt_id
        and l.booking_id=old.id
        and l.entry_type='online_collection'
        and l.direction='credit'
        and l.status='posted'
      for update;
      if not found then
        raise exception 'ORIGINAL_ONLINE_CANCELLATION_FEE_LEDGER_ENTRY_MISSING' using errcode='55000';
      end if;

      insert into public.srk_cancellation_fee_ledger(
        debt_id,booking_id,source_booking_id,customer_user_id,
        entry_type,direction,amount_paise,status,payment_reference,
        idempotency_key,note,reversal_of_entry_id
      ) values (
        v_item.debt_id,old.id,v_item.source_booking_id,old.customer_user_id,
        'reversal','debit',v_item.amount_paise,'posted',v_refund_id::text,
        'cancel-fee:refund:online:'||v_item.debt_id::text,
        'Full Razorpay refund: reverse SRK cancellation-fee collection; reopen customer debt',
        v_original.id
      );
    else
      select l.* into v_original
      from public.srk_cancellation_fee_ledger l
      where l.debt_id=v_item.debt_id
        and l.booking_id=old.id
        and l.entry_type='cash_electrician_debit'
        and l.direction='credit'
        and l.status='posted'
      for update;
      if not found then
        raise exception 'ORIGINAL_CASH_CANCELLATION_FEE_LEDGER_ENTRY_MISSING' using errcode='55000';
      end if;

      select wl.* into v_wallet_entry
      from public.srk_wallet_ledger wl
      where wl.idempotency_key='cancel-fee:cash:electrician-debit:'||v_item.debt_id::text
        and wl.entry_type='cancellation_fee'
        and wl.direction='debit'
        and wl.status='posted'
      for update;
      if not found then
        raise exception 'ORIGINAL_ELECTRICIAN_WALLET_DEBIT_MISSING' using errcode='55000';
      end if;

      insert into public.srk_wallet_ledger(
        wallet_id,user_id,wallet_type,entry_type,direction,amount,status,
        reference_type,reference_id,provider,provider_reference,idempotency_key,
        description,posted_at
      ) values (
        v_wallet_entry.wallet_id,v_wallet_entry.user_id,'electrician',
        'cancellation_fee','credit',v_item.amount_paise/100.0,'posted',
        'cancellation_fee_refund',v_item.debt_id::text,'internal',
        v_refund_id::text,'cancel-fee:cash:refund-wallet-credit:'||v_item.debt_id::text,
        'Full customer refund: reverse the earlier SRK cancellation-fee wallet debit',
        clock_timestamp()
      );

      insert into public.srk_cancellation_fee_ledger(
        debt_id,booking_id,source_booking_id,customer_user_id,electrician_user_id,
        entry_type,direction,amount_paise,status,payment_reference,
        idempotency_key,note,reversal_of_entry_id
      ) values (
        v_item.debt_id,old.id,v_item.source_booking_id,old.customer_user_id,
        v_original.electrician_user_id,'reversal','debit',v_item.amount_paise,
        'posted',v_refund_id::text,
        'cancel-fee:refund:cash:'||v_item.debt_id::text,
        'Full cash refund: reverse SRK fee credit and restore electrician wallet debit',
        v_original.id
      );
    end if;

    update public.srk_booking_cancellation_fee_items
      set status='reversed'
      where id=v_item.id and status='settled';
    update public.srk_customer_cancellation_fee_debts
      set status='open',reserved_booking_id=null,settled_at=null,reversed_at=null
      where id=v_item.debt_id and status='settled';
    if not found then
      raise exception 'CANCELLATION_FEE_DEBT_STATE_CHANGED_DURING_REFUND' using errcode='55000';
    end if;
    v_debt_count:=v_debt_count+1;
  end loop;

  return new;
end;
$$;

revoke all on function public.srk_reverse_cancellation_fees_on_full_refund() from public,anon,authenticated;
drop trigger if exists srk_reverse_cancellation_fees_on_full_refund on public.service_bookings;
create trigger srk_reverse_cancellation_fees_on_full_refund
after update of payment_status on public.service_bookings
for each row
when (old.payment_status is distinct from new.payment_status and new.payment_status='refunded')
execute function public.srk_reverse_cancellation_fees_on_full_refund();

-- Net collection excludes reversals; the source credit remains immutable.
create or replace function public.srk_admin_get_cancellation_fee_ledger_summary()
returns jsonb
language plpgsql
stable
security definer
set search_path=''
as $$
begin
  if auth.uid() is null or not public.is_srk_admin() then
    raise exception 'ADMIN_ONLY' using errcode='42501';
  end if;
  return jsonb_build_object(
    'open_debt_paise',coalesce((select sum(amount_paise) from public.srk_customer_cancellation_fee_debts where status='open'),0),
    'reserved_debt_paise',coalesce((select sum(amount_paise) from public.srk_customer_cancellation_fee_debts where status='reserved'),0),
    'settled_debt_paise',coalesce((select sum(amount_paise) from public.srk_customer_cancellation_fee_debts where status='settled'),0),
    'online_collected_paise',coalesce((
      select sum(case when l.entry_type='online_collection' then l.amount_paise else -l.amount_paise end)
      from public.srk_cancellation_fee_ledger l
      left join public.srk_cancellation_fee_ledger original on original.id=l.reversal_of_entry_id
      where l.status='posted'
        and (l.entry_type='online_collection' or (l.entry_type='reversal' and original.entry_type='online_collection'))
    ),0),
    'cash_electrician_debit_paise',coalesce((
      select sum(case when l.entry_type='cash_electrician_debit' then l.amount_paise else -l.amount_paise end)
      from public.srk_cancellation_fee_ledger l
      left join public.srk_cancellation_fee_ledger original on original.id=l.reversal_of_entry_id
      where l.status='posted'
        and (l.entry_type='cash_electrician_debit' or (l.entry_type='reversal' and original.entry_type='cash_electrician_debit'))
    ),0),
    'reversed_fee_paise',coalesce((select sum(amount_paise) from public.srk_cancellation_fee_ledger where entry_type='reversal' and status='posted'),0),
    'ledger_entries',(select count(*) from public.srk_cancellation_fee_ledger),
    'reversal_entries',(select count(*) from public.srk_cancellation_fee_ledger where entry_type='reversal')
  );
end;
$$;

revoke all on function public.srk_admin_get_cancellation_fee_ledger_summary() from public,anon;
grant execute on function public.srk_admin_get_cancellation_fee_ledger_summary() to authenticated;

-- If a provider refund definitively fails, release the payout hold placed for it.
create or replace function public.srk_service_reconcile_booking_refund(
  p_refund_record_id uuid,
  p_provider_refund_id text,
  p_provider_status text,
  p_error text default null
)
returns jsonb
language plpgsql
security definer
set search_path=''
as $$
declare
  v_refund public.srk_razorpay_refunds%rowtype;
  v_status text;
begin
  if auth.role()<>'service_role' then
    raise exception 'SERVICE_ROLE_REQUIRED' using errcode='42501';
  end if;
  if p_refund_record_id is null
     or p_provider_status not in ('pending','processed','failed')
     or (p_provider_refund_id is not null and p_provider_refund_id !~ '^rfnd_[A-Za-z0-9]+$') then
    raise exception 'INVALID_PROVIDER_REFUND_RESULT' using errcode='22023';
  end if;
  select * into v_refund from public.srk_razorpay_refunds
    where id=p_refund_record_id for update;
  if not found then raise exception 'REFUND_RECORD_NOT_FOUND'; end if;
  if v_refund.status='processed' then
    return jsonb_build_object('success',true,'status','processed','replayed',true);
  end if;
  v_status:=case p_provider_status when 'pending' then 'processing'
    when 'processed' then 'processed' else 'failed' end;

  update public.srk_razorpay_refunds
    set refund_id=coalesce(p_provider_refund_id,refund_id),
        provider_status=p_provider_status,status=v_status,
        last_error=case when p_provider_status='failed' then left(coalesce(p_error,'Refund failed'),500) else null end,
        processed_at=case when p_provider_status='processed' then clock_timestamp() else null end,
        updated_at=clock_timestamp()
    where id=p_refund_record_id;

  update public.srk_booking_refund_requests
    set status=case when p_provider_status='processed' then 'processed'
      when p_provider_status='failed' then 'unknown' else 'processing' end,
        updated_at=clock_timestamp(),
        processed_at=case when p_provider_status='processed' then clock_timestamp() else null end
    where refund_record_id=p_refund_record_id;

  if p_provider_status='processed' then
    update public.service_bookings set payment_status='refunded'
      where id=v_refund.booking_id and payment_status='paid';
  elsif p_provider_status='failed' then
    update public.srk_electrician_payouts
      set payout_status='pending',payout_note=v_refund.previous_payout_note,
          updated_at=clock_timestamp()
      where booking_id=v_refund.booking_id
        and payout_status='blocked'
        and payout_note='Razorpay refund pending';
  end if;

  return jsonb_build_object('success',true,'status',v_status,'booking_id',v_refund.booking_id);
end;
$$;

revoke all on function public.srk_service_reconcile_booking_refund(uuid,text,text,text) from public,anon,authenticated;
grant execute on function public.srk_service_reconcile_booking_refund(uuid,text,text,text) to service_role;
