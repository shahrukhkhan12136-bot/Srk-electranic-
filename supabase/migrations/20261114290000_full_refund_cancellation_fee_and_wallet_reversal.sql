-- Full-refund accounting reversal for cancellation-fee carry-forward.
-- Feature branch source only. This migration is NOT applied to any database.
-- Current refund RPCs are full-amount only; partial refunds deliberately fail closed.
-- A debt can be reserved, refunded/reopened, and collected on a later booking.
alter table public.srk_booking_cancellation_fee_items
  drop constraint if exists srk_booking_cancellation_fee_items_debt_id_key;

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

  if exists(select 1 from public.srk_booking_cancellation_fee_items i
    where i.booking_id=old.id and i.status<>'settled') then
    raise exception 'CANCELLATION_FEE_ITEMS_NOT_SETTLED_BEFORE_REFUND' using errcode='55000';
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
        and l.amount_paise=v_item.amount_paise
        and l.customer_user_id=old.customer_user_id
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
        'cancel-fee:refund:online:'||v_original.id::text,
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
        and l.amount_paise=v_item.amount_paise
        and l.customer_user_id=old.customer_user_id
        and l.status='posted'
      for update;
      if not found then
        raise exception 'ORIGINAL_CASH_CANCELLATION_FEE_LEDGER_ENTRY_MISSING' using errcode='55000';
      end if;

      select wl.* into v_wallet_entry
      from public.srk_wallet_ledger wl
      where wl.reference_type='cancellation_fee_item'
        and wl.reference_id=v_item.id::text
        and wl.wallet_type='electrician'
        and wl.entry_type='cancellation_fee'
        and wl.direction='debit'
        and wl.amount=v_item.amount_paise/100.0
        and wl.user_id=v_original.electrician_user_id
        and wl.status='posted'
        and wl.created_at<=clock_timestamp()
      order by wl.created_at desc
      limit 1
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
        v_refund_id::text,'cancel-fee:cash:refund-wallet-credit:'||v_wallet_entry.id::text,
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
        'cancel-fee:refund:cash:'||v_original.id::text,
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

-- Refund preparation for the server-timed booking model as well as legacy quote bookings.
create or replace function public.srk_admin_prepare_razorpay_refund(
  p_booking_id uuid,p_reason text
)
returns table(
  refund_record_id uuid,booking_id uuid,payment_id text,amount_paise bigint,
  idempotency_key text,status text,previous_payout_note text
)
language plpgsql
security definer
set search_path='pg_catalog','public','auth','pg_temp'
as $$
declare
  v_booking public.service_bookings%rowtype;
  v_refund public.srk_razorpay_refunds%rowtype;
  v_payout public.srk_electrician_payouts%rowtype;
  v_labour_paise bigint;
  v_fee_paise bigint;
  v_total_paise bigint;
  v_total numeric(12,2);
begin
  if auth.uid() is null or not public.is_srk_admin() then
    raise exception 'ADMIN_ACCESS_REQUIRED' using errcode='42501';
  end if;
  if p_booking_id is null or p_reason is null or length(btrim(p_reason)) not between 20 and 250 then
    raise exception 'REFUND_REASON_MUST_BE_20_TO_250_CHARACTERS' using errcode='22023';
  end if;

  select * into v_booking from public.service_bookings where id=p_booking_id for update;
  if not found then raise exception 'BOOKING_NOT_FOUND'; end if;
  if v_booking.payment_status<>'paid' or v_booking.payment_verified_at is null
     or v_booking.razorpay_payment_id is null or v_booking.amount_paid is null
     or v_booking.amount_paid<=0 then
    raise exception 'ONLY_VERIFIED_RAZORPAY_PAID_BOOKINGS_CAN_BE_REFUNDED';
  end if;
  if lower(coalesce(v_booking.payment_method,'')) not like '%razorpay%'
     and lower(coalesce(v_booking.payment_method,'')) not like '%online%' then
    raise exception 'BOOKING_PAYMENT_METHOD_IS_NOT_ONLINE';
  end if;
  if v_booking.razorpay_payment_id !~ '^pay_[A-Za-z0-9]+$' then
    raise exception 'INVALID_RAZORPAY_PAYMENT_ID';
  end if;

  if v_booking.selected_category is not null then
    if v_booking.status<>'completed' then raise exception 'BOOKING_NOT_COMPLETED'; end if;
    select b.labour_amount_paise into v_labour_paise
      from public.srk_booking_labour_bills b
      where b.booking_id=p_booking_id and b.customer_user_id=v_booking.customer_user_id;
    if not found or v_labour_paise is null then
      raise exception 'IMMUTABLE_LABOUR_BILL_REQUIRED';
    end if;
    select coalesce(sum(i.amount_paise),0) into v_fee_paise
      from public.srk_booking_cancellation_fee_items i
      where i.booking_id=p_booking_id and i.status='settled';
    if exists(select 1 from public.srk_booking_cancellation_fee_items i
      where i.booking_id=p_booking_id and i.status<>'settled') then
      raise exception 'CANCELLATION_FEE_ITEMS_NOT_FULLY_SETTLED';
    end if;
    v_total_paise:=v_labour_paise+v_fee_paise;
    if v_total_paise<>round(v_booking.amount_paid*100)::bigint then
      raise exception 'PAID_AMOUNT_DOES_NOT_MATCH_IMMUTABLE_LABOUR_AND_FEE_LEDGER';
    end if;
    v_total:=v_total_paise/100.0;
  else
    if v_booking.quote_status<>'approved'
       or v_booking.quoted_amount is null or v_booking.service_charge is null
       or v_booking.materials_amount is null then
      raise exception 'ONLY_VERIFIED_APPROVED_QUOTE_BOOKINGS_CAN_BE_REFUNDED';
    end if;
    v_total:=round(v_booking.amount_paid,2);
    if v_total<>round(v_booking.quoted_amount,2)
       or v_total<>round(v_booking.service_charge+v_booking.materials_amount,2) then
      raise exception 'PAID_AMOUNT_DOES_NOT_MATCH_APPROVED_QUOTE';
    end if;
    v_total_paise:=round(v_total*100)::bigint;
  end if;

  select * into v_refund from public.srk_razorpay_refunds
    where booking_id=p_booking_id for update;
  if found then
    if v_refund.status='failed' then
      raise exception 'PREVIOUS_RAZORPAY_REFUND_FAILED_RECONCILE_BEFORE_RETRY';
    end if;
    return query select v_refund.id,v_refund.booking_id,v_refund.payment_id,
      v_refund.amount_paise,v_refund.idempotency_key,v_refund.status,v_refund.previous_payout_note;
    return;
  end if;

  select * into v_payout from public.srk_electrician_payouts
    where booking_id=p_booking_id for update;
  if found then
    if v_payout.payout_status='paid' then
      raise exception 'ELECTRICIAN_PAYOUT_ALREADY_PAID_RECOVERY_REQUIRED';
    end if;
    if v_payout.payout_status<>'pending' then
      raise exception 'ELECTRICIAN_PAYOUT_NOT_PENDING_RECONCILE_FIRST';
    end if;
    update public.srk_electrician_payouts
      set payout_status='blocked',payout_note='Razorpay refund pending',updated_at=clock_timestamp()
      where id=v_payout.id;
  end if;

  insert into public.srk_razorpay_refunds(
    booking_id,payment_id,amount,amount_paise,idempotency_key,status,
    reason,admin_user_id,previous_payout_note
  ) values (
    p_booking_id,v_booking.razorpay_payment_id,v_total,v_total_paise,
    replace(gen_random_uuid()::text,'-',''),'requested',btrim(p_reason),
    auth.uid(),v_payout.payout_note
  ) returning * into v_refund;

  return query select v_refund.id,v_refund.booking_id,v_refund.payment_id,
    v_refund.amount_paise,v_refund.idempotency_key,v_refund.status,v_refund.previous_payout_note;
end;
$$;

revoke all on function public.srk_admin_prepare_razorpay_refund(uuid,text) from public,anon;
grant execute on function public.srk_admin_prepare_razorpay_refund(uuid,text) to authenticated;

-- Manual full refunds block an unpaid payout before writing the refund record.
create or replace function public.srk_admin_record_manual_refund(
  p_booking_id uuid,p_reference text,p_note text default null
)
returns jsonb
language plpgsql
security definer
set search_path='pg_catalog','public','auth','pg_temp'
as $$
declare
  v_booking public.service_bookings%rowtype;
  v_payment public.srk_manual_payment_entries%rowtype;
  v_payout public.srk_electrician_payouts%rowtype;
  v_reference text:=btrim(coalesce(p_reference,''));
begin
  if auth.uid() is null or not public.is_srk_admin() then
    raise exception 'ADMIN_ACCESS_REQUIRED' using errcode='42501';
  end if;
  if p_booking_id is null or length(v_reference) not between 4 and 120
     or (p_note is not null and length(p_note)>250) then
    raise exception 'INVALID_MANUAL_REFUND_REFERENCE_OR_NOTE' using errcode='22023';
  end if;

  select * into v_booking from public.service_bookings
    where id=p_booking_id for update;
  if not found then raise exception 'BOOKING_NOT_FOUND'; end if;
  if v_booking.payment_status<>'paid' or v_booking.payment_verified_at is null
     or coalesce(v_booking.amount_paid,0)<=0 then
    raise exception 'ONLY_VERIFIED_PAID_BOOKINGS_CAN_BE_REFUNDED';
  end if;
  if v_booking.razorpay_order_id is not null or v_booking.razorpay_payment_id is not null then
    raise exception 'RAZORPAY_REFUNDS_MUST_USE_RAZORPAY_RECONCILIATION';
  end if;

  select * into v_payment from public.srk_manual_payment_entries
    where booking_id=p_booking_id for update;
  if not found then raise exception 'MANUAL_PAYMENT_AUDIT_RECORD_NOT_FOUND'; end if;
  if round(v_booking.amount_paid,2)<>round(v_payment.amount,2) then
    raise exception 'RECORDED_PAYMENT_AMOUNT_DOES_NOT_MATCH_BOOKING_AMOUNT';
  end if;
  if exists(select 1 from public.srk_manual_refund_entries r where r.booking_id=p_booking_id) then
    raise exception 'A_REFUND_HAS_ALREADY_BEEN_RECORDED_FOR_THIS_BOOKING';
  end if;

  select * into v_payout from public.srk_electrician_payouts
    where booking_id=p_booking_id for update;
  if found then
    if v_payout.payout_status='paid' then
      raise exception 'ELECTRICIAN_PAYOUT_ALREADY_PAID_RECOVERY_REQUIRED';
    end if;
    if v_payout.payout_status='pending' then
      update public.srk_electrician_payouts
        set payout_status='blocked',payout_note='Manual refund processed',updated_at=clock_timestamp()
        where id=v_payout.id;
    elsif v_payout.payout_status<>'blocked' then
      raise exception 'ELECTRICIAN_PAYOUT_STATE_REQUIRES_ADMIN_RECONCILIATION';
    end if;
  end if;

  insert into public.srk_manual_refund_entries(
    booking_id,payment_entry_id,amount,refund_reference,note,recorded_by
  ) values (
    p_booking_id,v_payment.id,v_payment.amount,v_reference,
    nullif(btrim(coalesce(p_note,'')),''),auth.uid()
  );

  update public.service_bookings set payment_status='refunded'
    where id=p_booking_id and payment_status='paid';

  return jsonb_build_object('success',true,'booking_id',p_booking_id,
    'amount',v_payment.amount,'refund_reference',v_reference);
end;
$$;

revoke all on function public.srk_admin_record_manual_refund(uuid,text,text) from public,anon;
grant execute on function public.srk_admin_record_manual_refund(uuid,text,text) to authenticated;

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
  v_booking_id uuid;
  v_status text;
begin
  if auth.role()<>'service_role' then
    raise exception 'SERVICE_ROLE_REQUIRED' using errcode='42501';
  end if;
  if p_refund_record_id is null
     or p_provider_status is null
     or p_provider_status not in ('pending','processed','failed')
     or (p_provider_status='processed' and p_provider_refund_id is null)
     or (p_provider_refund_id is not null and p_provider_refund_id !~ '^rfnd_[A-Za-z0-9]+$') then
    raise exception 'INVALID_PROVIDER_REFUND_RESULT' using errcode='22023';
  end if;

  -- Match the booking-first lock order used by refund preparation and payout settlement.
  select booking_id into v_booking_id
    from public.srk_razorpay_refunds where id=p_refund_record_id;
  if not found or v_booking_id is null then raise exception 'REFUND_RECORD_NOT_FOUND'; end if;

  perform 1 from public.service_bookings where id=v_booking_id for update;
  if not found then raise exception 'REFUND_BOOKING_NOT_FOUND'; end if;

  select * into v_refund from public.srk_razorpay_refunds
    where id=p_refund_record_id and booking_id=v_booking_id for update;
  if not found then raise exception 'REFUND_RECORD_CHANGED_RETRY'; end if;
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
