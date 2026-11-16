-- Payout lifecycle hook. The booking transition is the single point that closes
-- refund-owned payout holds; refund RPCs verify the resulting state, not repeat the write.
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
    -- Full refund closes a still-pending payout or only a blocked hold explicitly
    -- owned by a verified refund workflow. Unrelated Admin holds remain untouched.
    update public.srk_electrician_payouts
       set payout_status = 'refunded',
           payout_note = null,
           updated_at = now()
     where booking_id = new.id
       and (
         payout_status = 'pending'
         or (
           payout_status = 'blocked'
           and payout_note in ('Razorpay refund pending','Manual refund processed')
         )
       );
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
  v_request public.srk_booking_refund_requests%rowtype;
  v_labour public.srk_booking_labour_bills%rowtype;
  v_labour_paise bigint;
  v_fee_paise bigint:=0;
  v_expected_paise bigint;
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
  if v_booking.razorpay_order_id is not null or v_booking.razorpay_payment_id is not null
     or lower(coalesce(v_booking.payment_method,'')) like '%razorpay%'
     or lower(coalesce(v_booking.payment_method,'')) like '%online%' then
    raise exception 'RAZORPAY_REFUNDS_MUST_USE_RAZORPAY_RECONCILIATION';
  end if;

  select * into v_request from public.srk_booking_refund_requests
    where booking_id=p_booking_id for update;
  if found and v_request.status is distinct from 'approved' then
    raise exception 'CUSTOMER_REFUND_REQUEST_REQUIRES_MAIN_ADMIN_APPROVAL' using errcode='55000';
  end if;

  select * into v_payment from public.srk_manual_payment_entries
    where booking_id=p_booking_id for update;
  if not found then raise exception 'MANUAL_PAYMENT_AUDIT_RECORD_NOT_FOUND'; end if;
  if round(v_booking.amount_paid,2)<>round(v_payment.amount,2) then
    raise exception 'RECORDED_PAYMENT_AMOUNT_DOES_NOT_MATCH_BOOKING_AMOUNT';
  end if;

  -- New server-timed bookings must reconcile the manual refund to the same
  -- immutable labour bill and settled cancellation-fee ledger used at collection.
  -- Legacy quote bookings retain their separate historical payment evidence path.
  if v_booking.selected_category is not null then
    if v_booking.status is distinct from 'completed' then
      raise exception 'NEW_CATEGORY_REFUND_REQUIRES_COMPLETED_BOOKING';
    end if;

    select * into v_labour
      from public.srk_booking_labour_bills
     where booking_id=p_booking_id
       and customer_user_id=v_booking.customer_user_id
     for share;
    if not found or v_labour.labour_amount_paise is null
       or v_labour.labour_amount_paise<=0
       or v_labour.electrician_profile_id is distinct from v_booking.assigned_electrician_id then
      raise exception 'IMMUTABLE_LABOUR_BILL_MISSING_OR_ASSIGNMENT_MISMATCH';
    end if;

    perform 1 from public.srk_booking_cancellation_fee_items
     where booking_id=p_booking_id
     for update;
    if exists (
      select 1 from public.srk_booking_cancellation_fee_items
       where booking_id=p_booking_id and status is distinct from 'settled'
    ) then
      raise exception 'CANCELLATION_FEE_ITEMS_NOT_FULLY_SETTLED';
    end if;
    select coalesce(sum(amount_paise),0)::bigint
      into v_fee_paise
      from public.srk_booking_cancellation_fee_items
     where booking_id=p_booking_id and status='settled';

    v_labour_paise:=v_labour.labour_amount_paise;
    v_expected_paise:=v_labour_paise+v_fee_paise;
    if v_expected_paise<>round(v_booking.amount_paid*100)::bigint
       or v_expected_paise<>round(v_payment.amount*100)::bigint then
      raise exception 'MANUAL_REFUND_AMOUNT_DOES_NOT_MATCH_IMMUTABLE_LABOUR_AND_FEE_LEDGER';
    end if;
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
  if not found then
    raise exception 'BOOKING_REFUND_STATE_CHANGED' using errcode='40001';
  end if;

  -- The AFTER UPDATE booking trigger closes only a refund-owned payout hold.
  -- Re-read and verify its result; do not race the trigger with a second write.
  if v_payout.id is not null then
    select * into v_payout from public.srk_electrician_payouts where id=v_payout.id;
    if not found or v_payout.payout_status is distinct from 'refunded' then
      raise exception 'BLOCKED_PAYOUT_COULD_NOT_BE_CLOSED_AS_REFUNDED' using errcode='55000';
    end if;
  end if;

  if v_request.id is not null then
    update public.srk_booking_refund_requests
      set status='processed',processed_at=coalesce(processed_at,clock_timestamp()),
          updated_at=clock_timestamp()
      where id=v_request.id and status='approved';
  end if;

  return jsonb_build_object('success',true,'booking_id',p_booking_id,
    'amount',v_payment.amount,'refund_reference',v_reference,
    'customer_request_status',case when v_request.id is not null then 'processed' else null end);
end;
$$;

create or replace function public.srk_service_finalize_razorpay_refund_from_recovery_evidence(p_recovery_audit_id uuid)
returns jsonb language plpgsql security definer set search_path=''
as $$
declare
  v_audit public.srk_razorpay_refund_recovery_audits%rowtype;
  v_refund public.srk_razorpay_refunds%rowtype;
  v_booking public.service_bookings%rowtype;
  v_payout public.srk_electrician_payouts%rowtype;
  v_has_payout boolean:=false;
begin
  if coalesce(auth.jwt()->>'role','') <> 'service_role' then
    raise exception 'SERVICE_ROLE_REQUIRED' using errcode='42501';
  end if;
  if p_recovery_audit_id is null then raise exception 'RECOVERY_EVIDENCE_ID_REQUIRED' using errcode='22023'; end if;

  select * into v_audit from public.srk_razorpay_refund_recovery_audits where id=p_recovery_audit_id;
  if not found then raise exception 'RECOVERY_EVIDENCE_NOT_FOUND'; end if;
  if v_audit.provider_status is distinct from 'processed' then
    raise exception 'ONLY_VERIFIED_PROCESSED_PROVIDER_EVIDENCE_CAN_FINALIZE' using errcode='55000';
  end if;
  if v_audit.recorded_at < clock_timestamp()-interval '15 minutes' then
    raise exception 'RECOVERY_EVIDENCE_TOO_OLD_REFRESH_PROVIDER_STATUS' using errcode='55000';
  end if;

  select * into v_booking from public.service_bookings where id=v_audit.booking_id for update;
  if not found then raise exception 'REFUND_BOOKING_NOT_FOUND'; end if;
  if v_audit.amount_paise is distinct from round(v_booking.amount_paid*100)::bigint then
    raise exception 'RECOVERY_REFUND_AMOUNT_DOES_NOT_MATCH_FULL_BOOKING_COLLECTION' using errcode='55000';
  end if;
  select * into v_refund from public.srk_razorpay_refunds
    where id=v_audit.refund_record_id and booking_id=v_booking.id for update;
  if not found then raise exception 'REFUND_RECORD_CHANGED_RETRY'; end if;

  if v_refund.payment_id is distinct from v_audit.payment_id
     or v_booking.razorpay_payment_id is distinct from v_audit.payment_id
     or v_refund.amount_paise is distinct from v_audit.amount_paise
     or v_refund.currency is distinct from v_audit.currency
     or (v_refund.refund_id is not null and v_refund.refund_id is distinct from v_audit.provider_refund_id) then
    raise exception 'RECOVERY_EVIDENCE_NO_LONGER_MATCHES_REFUND_RECORD' using errcode='55000';
  end if;

  select * into v_payout from public.srk_electrician_payouts where booking_id=v_booking.id for update;
  v_has_payout:=found;
  if v_has_payout and v_payout.payout_status='paid' then
    raise exception 'ELECTRICIAN_PAYOUT_ALREADY_PAID_MANUAL_RECONCILIATION_REQUIRED' using errcode='55000';
  end if;
  if v_booking.payment_status is distinct from 'paid' and v_booking.payment_status is distinct from 'refunded' then
    raise exception 'BOOKING_PAYMENT_STATE_NOT_RECOVERABLE' using errcode='55000';
  end if;

  -- A completed refund trigger moves its payout to refunded; allow only that exact replay state.
  if v_booking.payment_status='refunded' and v_refund.status='processed' then
    if v_has_payout and v_payout.payout_status is distinct from 'refunded' then
      raise exception 'REFUNDED_BOOKING_PAYOUT_STATE_REQUIRES_MANUAL_RECONCILIATION' using errcode='55000';
    end if;
    return jsonb_build_object('success',true,'status','processed','replayed',true,
      'booking_id',v_booking.id,'refund_record_id',v_refund.id,'recovery_audit_id',v_audit.id);
  end if;

  if v_has_payout and v_payout.payout_status is distinct from 'blocked' then
    raise exception 'ELECTRICIAN_PAYOUT_MUST_REMAIN_BLOCKED_DURING_REFUND_RECOVERY' using errcode='55000';
  end if;

  update public.srk_razorpay_refunds set refund_id=v_audit.provider_refund_id,
    provider_status='processed',status='processed',last_error=null,
    processed_at=coalesce(processed_at,clock_timestamp()),updated_at=clock_timestamp()
  where id=v_refund.id;

  update public.srk_booking_refund_requests set status='processed',refund_record_id=v_refund.id,
    processed_at=coalesce(processed_at,clock_timestamp()),updated_at=clock_timestamp()
  where booking_id=v_booking.id;

  if v_booking.payment_status='paid' then
    update public.service_bookings set payment_status='refunded'
    where id=v_booking.id and payment_status='paid';
  end if;

  -- The AFTER UPDATE booking trigger closes the Razorpay-owned blocked hold
  -- after the processed provider evidence and booking state have been verified.
  -- Re-read the row and fail closed if an unrelated hold prevented that transition.
  if v_has_payout then
    select * into v_payout from public.srk_electrician_payouts where id=v_payout.id;
    if not found or v_payout.payout_status is distinct from 'refunded' then
      raise exception 'BLOCKED_PAYOUT_COULD_NOT_BE_CLOSED_AS_REFUNDED' using errcode='55000';
    end if;
  end if;

  return jsonb_build_object('success',true,'status','processed','replayed',false,
    'booking_id',v_booking.id,'refund_record_id',v_refund.id,'recovery_audit_id',v_audit.id);
end;
$$;
