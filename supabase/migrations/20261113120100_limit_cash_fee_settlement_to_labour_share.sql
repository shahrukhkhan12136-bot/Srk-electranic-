-- Restrict recovery of prior Cash Platform Fee dues to the labour/service share only.
-- Customer-supplied materials are never a source for Platform Fee settlement.
create or replace function public.srk_create_electrician_payable()
returns trigger
language plpgsql
security definer
set search_path to 'pg_catalog', 'public', 'auth', 'pg_temp'
as $function$
declare
  v_service numeric(12,2);
  v_materials numeric(12,2);
  v_total numeric(12,2);
  v_rate numeric(7,2);
  v_current_fee numeric(12,2);
  v_previous_due numeric(12,2);
  v_previous_settled numeric(12,2);
  v_profile_id uuid;
  v_is_cash boolean;
begin
  if new.payment_status = 'paid'
     and new.status = 'completed'
     and new.quote_status = 'approved'
     and new.assigned_electrician_id is not null
     and new.payment_verified_at is not null
     and (
       new.razorpay_payment_id is not null
       or exists (
         select 1 from public.srk_manual_payment_entries e
          where e.booking_id = new.id
            and round(coalesce(e.amount,0),2) = round(coalesce(new.amount_paid,0),2)
       )
     ) then
    v_profile_id := new.assigned_electrician_id;
    v_service := round(coalesce(new.service_charge,0),2);
    v_materials := round(coalesce(new.materials_amount,0),2);
    v_total := round(v_service + v_materials,2);
    v_rate := new.commission_rate;

    if v_rate is null or v_rate < 0 or v_rate > 100 then
      raise exception 'Platform Fee rate must be between 0 and 100';
    end if;
    if v_service <= 0 or round(coalesce(new.amount_paid,0),2) <> v_total then
      raise exception 'Verified payment amount does not match approved quote total';
    end if;

    v_current_fee := round(v_service * v_rate / 100,2);
    v_is_cash := lower(coalesce(new.payment_method,'')) like '%cash%'
                 or lower(coalesce(new.payment_method,'')) like '%नकद%';

    if v_is_cash then
      -- Use the same per-electrician transaction lock as online settlements so
      -- a concurrent cash receipt cannot be missed by the next online booking.
      perform pg_catalog.pg_advisory_xact_lock(
        pg_catalog.hashtextextended(v_profile_id::text, 0)
      );
      -- Cash is paid directly to the electrician; no SRK payout is created.
      -- The fee becomes a due balance, once per booking.
      insert into public.srk_platform_fee_ledger
        (electrician_profile_id,booking_id,entry_type,amount,idempotency_key,note,created_by)
      values
        (v_profile_id,new.id,'cash_due',v_current_fee,
         'cash_due:'||new.id::text,
         'Cash booking: labour-only Platform Fee due',auth.uid())
      on conflict (idempotency_key) do nothing;
    else
      -- Serialize financial settlement per electrician without taking a profile
      -- row lock (booking rows are already locked by the payment update).
      perform pg_catalog.pg_advisory_xact_lock(
        pg_catalog.hashtextextended(v_profile_id::text, 0)
      );

      -- A repeated webhook/update must not recalculate a previously posted split.
      if not exists (
        select 1 from public.srk_platform_fee_ledger
         where idempotency_key = 'online_fee:'||new.id::text
      ) then
        select greatest(
          coalesce(sum(case
            when entry_type in ('cash_due','cash_due_restore') then amount
            when entry_type in ('cash_due_reversal','cash_due_settlement') then -amount
            else 0 end),0),0
        ) into v_previous_due
          from public.srk_platform_fee_ledger
         where electrician_profile_id = v_profile_id;

        -- Current fee is always reserved first. Old cash dues are collected
        -- only from the remaining electrician share, so the payout never goes
        -- negative and any unpaid balance carries forward.
        v_previous_settled := least(
          coalesce(v_previous_due,0),
          greatest(v_service - v_current_fee,0)
        );

        insert into public.srk_platform_fee_ledger
          (electrician_profile_id,booking_id,entry_type,amount,idempotency_key,note,created_by)
        values
          (v_profile_id,new.id,'online_fee',v_current_fee,
           'online_fee:'||new.id::text,
           'Current booking Platform Fee collected from verified online receipt',auth.uid())
        on conflict (idempotency_key) do nothing;

        if v_previous_settled > 0 then
          insert into public.srk_platform_fee_ledger
            (electrician_profile_id,booking_id,entry_type,amount,idempotency_key,note,created_by)
          values
            (v_profile_id,new.id,'cash_due_settlement',v_previous_settled,
             'cash_due_settlement:'||new.id::text,
             'Previous cash Platform Fee due deducted from online receipt',auth.uid())
          on conflict (idempotency_key) do nothing;
        end if;

        insert into public.srk_electrician_payouts (
          booking_id,electrician_profile_id,razorpay_payment_id,
          gross_service_amount,materials_amount,platform_commission,
          previous_platform_fee_settled,electrician_payable,payout_status
        ) values (
          new.id,v_profile_id,new.razorpay_payment_id,
          v_service,v_materials,round(v_current_fee+v_previous_settled,2),
          v_previous_settled,
          greatest(round(v_total-v_current_fee-v_previous_settled,2),0),
          'pending'
        )
        on conflict (booking_id) do update set
          electrician_profile_id = excluded.electrician_profile_id,
          razorpay_payment_id = excluded.razorpay_payment_id,
          gross_service_amount = excluded.gross_service_amount,
          materials_amount = excluded.materials_amount,
          platform_commission = excluded.platform_commission,
          previous_platform_fee_settled = excluded.previous_platform_fee_settled,
          electrician_payable = excluded.electrician_payable,
          updated_at = now()
        where public.srk_electrician_payouts.payout_status = 'pending';
      end if;
    end if;

  elsif new.payment_status = 'refunded' then
    if new.assigned_electrician_id is not null then
      perform pg_catalog.pg_advisory_xact_lock(
        pg_catalog.hashtextextended(new.assigned_electrician_id::text, 0)
      );
    end if;
    -- Refund reversals are immutable and idempotent. A refunded cash booking
    -- cancels its due; an online refund restores any old cash due it had settled.
    if exists (
      select 1 from public.srk_electrician_payouts
       where booking_id = new.id and payout_status = 'paid'
    ) then
      raise exception 'Refund requires Admin reconciliation because the electrician payout is already marked paid';
    end if;

    -- The ledger currently settles old dues as a pooled balance. If any later
    -- online booking has already settled this electrician's pooled due, do not
    -- silently erase a refunded cash fee: an Admin reconciliation is required.
    if exists (
      select 1
        from public.srk_platform_fee_ledger due_entry
        join public.srk_platform_fee_ledger settlement
          on settlement.electrician_profile_id = due_entry.electrician_profile_id
         and settlement.entry_type = 'cash_due_settlement'
         and settlement.created_at > due_entry.created_at
       where due_entry.booking_id = new.id
         and due_entry.entry_type = 'cash_due'
    ) then
      raise exception 'Cash refund after a later fee settlement requires Admin reconciliation; refund blocked to protect the fee ledger';
    end if;
    insert into public.srk_platform_fee_ledger
      (electrician_profile_id,booking_id,entry_type,amount,idempotency_key,note,created_by)
    select electrician_profile_id,booking_id,'cash_due_reversal',amount,
           'cash_due_reversal:'||booking_id::text,
           'Cash booking refunded; corresponding fee due reversed',auth.uid()
      from public.srk_platform_fee_ledger
     where booking_id = new.id and entry_type = 'cash_due'
    on conflict (idempotency_key) do nothing;

    insert into public.srk_platform_fee_ledger
      (electrician_profile_id,booking_id,entry_type,amount,idempotency_key,note,created_by)
    select electrician_profile_id,booking_id,'cash_due_restore',amount,
           'cash_due_restore:'||booking_id::text,
           'Online booking refunded; previously settled cash fee due restored',auth.uid()
      from public.srk_platform_fee_ledger
     where booking_id = new.id and entry_type = 'cash_due_settlement'
    on conflict (idempotency_key) do nothing;

    insert into public.srk_platform_fee_ledger
      (electrician_profile_id,booking_id,entry_type,amount,idempotency_key,note,created_by)
    select electrician_profile_id,booking_id,'online_fee_reversal',amount,
           'online_fee_reversal:'||booking_id::text,
           'Online booking refunded; current Platform Fee reversed',auth.uid()
      from public.srk_platform_fee_ledger
     where booking_id = new.id and entry_type = 'online_fee'
    on conflict (idempotency_key) do nothing;

    update public.srk_electrician_payouts
       set payout_status = 'refunded',updated_at = now()
     where booking_id = new.id and payout_status = 'pending';
  end if;
  return new;
end;
$function$;
