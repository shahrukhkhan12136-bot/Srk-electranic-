-- Reconcile electrician payouts for server-timed, customer-approved category bookings.
-- Keeps legacy quote payout behavior while ensuring cancellation fees never become electrician earnings.
-- Source-only until the approved migration/testing phase.

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
            where i.booking_id = new.id and i.status = 'settled'
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
    update public.srk_electrician_payouts
       set payout_status = 'refunded', updated_at = now()
     where booking_id = new.id and payout_status = 'pending';
  end if;

  return new;
end;
$$;

revoke all on function public.srk_create_electrician_payable() from public, anon, authenticated;

create or replace function public.srk_admin_mark_electrician_payout_paid(
  p_payout_id uuid,
  p_method text,
  p_reference text,
  p_note text default null
)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, auth, pg_temp
as $$
declare
  v_row public.srk_electrician_payouts%rowtype;
  v_booking public.service_bookings%rowtype;
  v_bill public.srk_booking_labour_bills%rowtype;
  v_booking_id uuid;
  v_expected_amount numeric(12,2);
  v_expected_service numeric(12,2);
  v_expected_materials numeric(12,2);
  v_expected_commission numeric(12,2);
begin
  if auth.uid() is null or not public.is_srk_admin() then
    raise exception 'Admin access required' using errcode = '42501';
  end if;
  if p_payout_id is null then raise exception 'Payout ID is required'; end if;
  if p_method is null or p_method not in ('upi','bank') then
    raise exception 'Payout method must be upi or bank';
  end if;
  if p_reference is null or length(btrim(p_reference)) < 4 or length(btrim(p_reference)) > 120 then
    raise exception 'Valid UTR / UPI reference is required';
  end if;
  if p_note is not null and length(p_note) > 250 then
    raise exception 'Payout note is too long';
  end if;

  -- Consistent booking-first lock order also used by refund settlement.
  select booking_id into v_booking_id
    from public.srk_electrician_payouts where id = p_payout_id;
  if not found or v_booking_id is null then
    raise exception 'Payout record not found or has no booking';
  end if;

  select * into v_booking
    from public.service_bookings
   where id = v_booking_id
   for update;
  if not found then raise exception 'Payout booking not found'; end if;

  select * into v_row
    from public.srk_electrician_payouts
   where id = p_payout_id
   for update;
  if not found or v_row.booking_id is distinct from v_booking_id then
    raise exception 'Payout record changed; retry the operation';
  end if;
  if v_row.payout_status <> 'pending' then
    raise exception 'Only pending payouts can be marked paid';
  end if;

  if v_booking.selected_category is not null then
    select * into v_bill
      from public.srk_booking_labour_bills
     where booking_id = v_booking.id;

    if not found then raise exception 'IMMUTABLE_LABOUR_BILL_REQUIRED'; end if;

    v_expected_service := round(v_bill.labour_amount,2);
    v_expected_materials := 0;
    v_expected_commission := round(v_expected_service * v_booking.commission_rate / 100,2);
    select v_expected_service + coalesce(sum(i.amount_paise)::numeric / 100,0)
      into v_expected_amount
      from public.srk_booking_cancellation_fee_items i
     where i.booking_id = v_booking.id and i.status = 'settled';

    if v_booking.status <> 'completed'
       or v_booking.payment_status <> 'paid'
       or v_booking.payment_verified_at is null
       or v_booking.assigned_electrician_id is distinct from v_row.electrician_profile_id
       or v_bill.electrician_profile_id is distinct from v_row.electrician_profile_id
       or round(coalesce(v_booking.amount_paid,0),2) <> round(v_expected_amount,2)
       or (
         v_booking.razorpay_payment_id is not null
         and v_booking.razorpay_payment_id is distinct from v_row.razorpay_payment_id
       )
       or (
         v_booking.razorpay_payment_id is null
         and not exists (
           select 1 from public.srk_manual_payment_entries e
            where e.booking_id = v_booking.id
              and round(coalesce(e.amount,0),2) = round(coalesce(v_booking.amount_paid,0),2)
         )
       )
       or round(coalesce(v_row.gross_service_amount,0),2) <> v_expected_service
       or round(coalesce(v_row.materials_amount,0),2) <> v_expected_materials
       or round(coalesce(v_row.platform_commission,0),2) <> v_expected_commission
       or round(coalesce(v_row.electrician_payable,0),2) <>
          round(v_expected_service + v_expected_materials - v_expected_commission,2) then
      raise exception 'Booking payment, labour bill or payout ledger does not match verified records; payout blocked';
    end if;
  else
    -- Legacy approved-quote reconciliation remains unchanged.
    if not exists (
      select 1
        from public.service_bookings b
       where b.id = v_row.booking_id
         and b.status = 'completed'
         and b.quote_status = 'approved'
         and b.payment_status = 'paid'
         and b.payment_verified_at is not null
         and (
           (v_row.razorpay_payment_id is not null and b.razorpay_payment_id = v_row.razorpay_payment_id)
           or (
             v_row.razorpay_payment_id is null
             and b.razorpay_payment_id is null
             and exists (
               select 1 from public.srk_manual_payment_entries e
                where e.booking_id = b.id
                  and round(coalesce(e.amount,0),2) = round(coalesce(b.amount_paid,0),2)
             )
           )
         )
         and b.assigned_electrician_id = v_row.electrician_profile_id
         and round(coalesce(b.amount_paid,0),2) =
             round(coalesce(b.service_charge,0) + coalesce(b.materials_amount,0),2)
         and round(coalesce(v_row.gross_service_amount,0),2) = round(coalesce(b.service_charge,0),2)
         and round(coalesce(v_row.materials_amount,0),2) = round(coalesce(b.materials_amount,0),2)
         and round(coalesce(v_row.platform_commission,0),2) =
             round(coalesce(b.service_charge,0) * b.commission_rate / 100,2)
         and round(coalesce(v_row.electrician_payable,0),2) =
             round(coalesce(b.service_charge,0) + coalesce(b.materials_amount,0)
               - round(coalesce(b.service_charge,0) * b.commission_rate / 100,2),2)
    ) then
      raise exception 'Booking payment or payout ledger does not match verified booking; payout blocked';
    end if;
  end if;

  update public.srk_electrician_payouts
     set payout_status = 'paid',
         payout_method = p_method,
         payout_reference = btrim(p_reference),
         payout_note = nullif(btrim(p_note),''),
         paid_by = auth.uid(),
         paid_at = now(),
         updated_at = now()
   where id = p_payout_id;

  return jsonb_build_object('success',true,'payout_id',p_payout_id,'status','paid');
end;
$$;

revoke all on function public.srk_admin_mark_electrician_payout_paid(uuid,text,text,text) from public, anon;
grant execute on function public.srk_admin_mark_electrician_payout_paid(uuid,text,text,text) to authenticated;
