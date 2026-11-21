
-- Master booking refund state follows the same existing Admin refund queue/Razorpay executor.
-- The immutable Master Final Bill replaces the old quote amount check for canonical Master bookings.
create or replace function public.srk_admin_prepare_razorpay_refund(
  p_booking_id uuid,p_reason text
)
returns table(
  refund_record_id uuid,booking_id uuid,payment_id text,amount_paise bigint,
  idempotency_key text,status text,previous_payout_note text
)
language plpgsql
security definer
set search_path=''
as $$
declare
  v_booking public.service_bookings%rowtype;
  v_refund public.srk_razorpay_refunds%rowtype;
  v_payout public.srk_electrician_payouts%rowtype;
  v_customer_request public.srk_booking_refund_requests%rowtype;
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
  if v_booking.payment_status is distinct from 'paid'
     or v_booking.payment_verified_at is null
     or v_booking.razorpay_payment_id is null
     or v_booking.amount_paid is null or v_booking.amount_paid<=0 then
    raise exception 'ONLY_VERIFIED_RAZORPAY_PAID_BOOKINGS_CAN_BE_REFUNDED';
  end if;
  if lower(coalesce(v_booking.payment_method,'')) not like '%razorpay%'
     and lower(coalesce(v_booking.payment_method,'')) not like '%online%' then
    raise exception 'BOOKING_PAYMENT_METHOD_IS_NOT_ONLINE';
  end if;
  if v_booking.razorpay_payment_id !~ '^pay_[A-Za-z0-9]+$' then
    raise exception 'INVALID_RAZORPAY_PAYMENT_ID';
  end if;

  -- A customer-submitted request must first be approved by Main Admin.
  select * into v_customer_request
  from public.srk_booking_refund_requests r
  where r.booking_id=p_booking_id
  for update;
  if found and v_customer_request.status not in ('approved','processing','unknown') then
    raise exception 'CUSTOMER_REFUND_REQUEST_REQUIRES_MAIN_ADMIN_APPROVAL' using errcode='55000';
  end if;

  if v_booking.srk_service_category_code is not null then
    if v_booking.status is distinct from 'completed' then raise exception 'BOOKING_NOT_COMPLETED'; end if;
    select f.subtotal_paise into v_total_paise
      from public.srk_booking_final_bills f
     where f.booking_id=p_booking_id;
    if not found or v_total_paise is null or v_total_paise<=0
       or v_total_paise<>round(v_booking.amount_paid*100)::bigint then
      raise exception 'PAID_AMOUNT_DOES_NOT_MATCH_MASTER_FINAL_BILL';
    end if;
    if exists(select 1 from public.srk_master_technician_payables
       where booking_id=p_booking_id and payout_status='paid') then
      raise exception 'MASTER_TECHNICIAN_PAYOUT_ALREADY_PAID_RECOVERY_REQUIRED';
    end if;
    update public.srk_master_technician_payables
       set payout_status='blocked'
     where booking_id=p_booking_id and payout_status in ('pending','requested');
    v_total:=v_total_paise/100.0;
  elsif v_booking.selected_category is not null then
    if v_booking.status is distinct from 'completed' then raise exception 'BOOKING_NOT_COMPLETED'; end if;
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
      where i.booking_id=p_booking_id and i.status is distinct from 'settled') then
      raise exception 'CANCELLATION_FEE_ITEMS_NOT_FULLY_SETTLED';
    end if;
    v_total_paise:=v_labour_paise+v_fee_paise;
    if v_total_paise<>round(v_booking.amount_paid*100)::bigint then
      raise exception 'PAID_AMOUNT_DOES_NOT_MATCH_IMMUTABLE_LABOUR_AND_FEE_LEDGER';
    end if;
    v_total:=v_total_paise/100.0;
  else
    if v_booking.quote_status is distinct from 'approved'
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
    if v_customer_request.id is not null then
      update public.srk_booking_refund_requests
      set status=case when v_refund.status='processed' then 'processed' else 'processing' end,
          refund_record_id=v_refund.id,updated_at=clock_timestamp()
      where id=v_customer_request.id;
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

  if v_customer_request.id is not null then
    update public.srk_booking_refund_requests
    set status='processing',refund_record_id=v_refund.id,updated_at=clock_timestamp()
    where id=v_customer_request.id;
  end if;

  return query select v_refund.id,v_refund.booking_id,v_refund.payment_id,
    v_refund.amount_paise,v_refund.idempotency_key,v_refund.status,v_refund.previous_payout_note;
end;
$$;

CREATE OR REPLACE FUNCTION public.srk_master_refund_payable_state_sync()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $
DECLARE v_payment public.srk_master_booking_payments%rowtype;
BEGIN
 IF NEW.payment_status='refunded' AND OLD.payment_status IS DISTINCT FROM NEW.payment_status THEN
   UPDATE public.srk_master_technician_payables SET payout_status='refunded'
    WHERE booking_id=NEW.id AND payout_status IN ('pending','requested','blocked');
   UPDATE public.srk_master_booking_payments SET payment_status='refunded'
    WHERE booking_id=NEW.id AND payment_status='paid' RETURNING * INTO v_payment;
   IF FOUND THEN
     INSERT INTO public.srk_master_payment_events(booking_id,payment_id,event_type,amount_paise,provider_reference,event_data)
     VALUES(NEW.id,v_payment.id,'refund_processed',v_payment.amount_paise,
       v_payment.razorpay_payment_id,jsonb_build_object('refund_status','processed'));
   END IF;
 END IF;
 RETURN NEW;
END; $;
REVOKE ALL ON FUNCTION public.srk_master_refund_payable_state_sync() FROM PUBLIC,anon,authenticated;
DROP TRIGGER IF EXISTS srk_master_refund_payable_state_sync ON public.service_bookings;
CREATE TRIGGER srk_master_refund_payable_state_sync
AFTER UPDATE OF payment_status ON public.service_bookings
FOR EACH ROW WHEN (OLD.payment_status IS DISTINCT FROM NEW.payment_status AND NEW.payment_status='refunded')
EXECUTE FUNCTION public.srk_master_refund_payable_state_sync();

CREATE OR REPLACE FUNCTION public.srk_master_refund_failure_release()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 IF NEW.status='failed' AND OLD.status IS DISTINCT FROM NEW.status THEN
   UPDATE public.srk_master_technician_payables SET payout_status='pending'
    WHERE booking_id=NEW.booking_id AND payout_status='blocked';
 END IF;
 RETURN NEW;
END; $$;
REVOKE ALL ON FUNCTION public.srk_master_refund_failure_release() FROM PUBLIC,anon,authenticated;
DROP TRIGGER IF EXISTS srk_master_refund_failure_release ON public.srk_razorpay_refunds;
CREATE TRIGGER srk_master_refund_failure_release
AFTER UPDATE OF status ON public.srk_razorpay_refunds
FOR EACH ROW EXECUTE FUNCTION public.srk_master_refund_failure_release();

COMMENT ON FUNCTION public.srk_admin_prepare_razorpay_refund(uuid,text) IS
 'Admin refund preparation supports legacy historical bookings and canonical Master bookings. Master refund amount is checked against immutable Master Final Bill; pending Technician payables are blocked.';
