-- Attach the payout reconciliation function to booking lifecycle changes.
-- Refund-owned blocked payouts remain the responsibility of the verified refund RPCs;
-- this trigger only creates/refreshes pending payouts and closes still-pending payouts.
create or replace function public.srk_create_electrician_payable()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public, pg_temp
as $$
declare
  v_service numeric(12,2);
  v_materials numeric(12,2);
  v_rate numeric(7,2);
  v_commission numeric(12,2);
  v_bill public.srk_booking_labour_bills%rowtype;
begin
  if new.payment_status = 'paid'
     and new.status = 'completed'
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

    if new.selected_category is not null then
      select * into v_bill
        from public.srk_booking_labour_bills
       where booking_id = new.id;

      if not found
         or v_bill.electrician_profile_id is distinct from new.assigned_electrician_id
         or v_bill.labour_amount <= 0 then
        raise exception 'IMMUTABLE_LABOUR_BILL_OR_ELECTRICIAN_ASSIGNMENT_MISMATCH';
      end if;

      -- The online/cash payment total is labour plus any settled carry-forward
      -- cancellation fees. Those fees belong to SRK, not to electrician earnings.
      if round(coalesce(new.amount_paid,0),2) <>
         round(v_bill.labour_amount + coalesce((
           select sum(i.amount_paise)::numeric / 100
             from public.srk_booking_cancellation_fee_items i
            where i.booking_id = new.id and i.status in ('reserved','settled')
         ),0),2) then
        raise exception 'VERIFIED_PAYMENT_DOES_NOT_MATCH_LABOUR_AND_SETTLED_FEES';
      end if;

      v_service := round(v_bill.labour_amount,2);
      v_materials := 0;
      v_rate := new.commission_rate;
    else
      -- Preserve the established legacy approved-quote payout calculation.
      if new.quote_status <> 'approved' then
        return new;
      end if;
      v_service := round(coalesce(new.service_charge,0),2);
      v_materials := round(coalesce(new.materials_amount,0),2);
      v_rate := new.commission_rate;
      if round(coalesce(new.amount_paid,0),2) <>
         round(v_service + v_materials,2) then
        raise exception 'VERIFIED_PAYMENT_DOES_NOT_MATCH_APPROVED_QUOTE_TOTAL';
      end if;
    end if;

    if v_rate is null or v_rate < 0 or v_rate > 100 then
      raise exception 'COMMISSION_RATE_MUST_BE_BETWEEN_0_AND_100';
    end if;

    v_commission := round(v_service * v_rate / 100,2);

    insert into public.srk_electrician_payouts (
      booking_id,electrician_profile_id,razorpay_payment_id,
      gross_service_amount,materials_amount,platform_commission,
      electrician_payable,payout_status
    ) values (
      new.id,new.assigned_electrician_id,new.razorpay_payment_id,
      v_service,v_materials,v_commission,
      round(v_service + v_materials - v_commission,2),'pending'
    )
    on conflict (booking_id) do update set
      electrician_profile_id = excluded.electrician_profile_id,
      razorpay_payment_id = excluded.razorpay_payment_id,
      gross_service_amount = excluded.gross_service_amount,
      materials_amount = excluded.materials_amount,
      platform_commission = excluded.platform_commission,
      electrician_payable = excluded.electrician_payable,
      updated_at = now()
    where public.srk_electrician_payouts.payout_status = 'pending';

  elsif new.payment_status = 'refunded' then
    -- Refund RPCs own the blocked-payout transition after verified provider/manual
    -- evidence. The trigger only closes a still-pending unpaid payout and never
    -- races the explicit refund finalizer or clears any Admin/refund hold.
    update public.srk_electrician_payouts
       set payout_status = 'refunded',
           payout_note = null,
           updated_at = now()
     where booking_id = new.id
       and payout_status = 'pending';
  end if;

  return new;
end;
$$;

drop trigger if exists srk_reconcile_electrician_payable on public.service_bookings;
create trigger srk_reconcile_electrician_payable
after insert or update of
  status,
  payment_status,
  assigned_electrician_id,
  payment_verified_at,
  amount_paid,
  quote_status,
  service_charge,
  materials_amount,
  commission_rate,
  razorpay_payment_id,
  selected_category
on public.service_bookings
for each row
execute function public.srk_create_electrician_payable();
