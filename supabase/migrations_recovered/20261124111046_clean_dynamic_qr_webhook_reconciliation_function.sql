
create or replace function public.srk_service_record_verified_razorpay_qr_webhook(
  p_event_id text,
  p_event_type text,
  p_event_payload jsonb,
  p_razorpay_qr_code_id text,
  p_razorpay_payment_id text default null,
  p_payment_amount_paise bigint default null,
  p_payment_currency text default null,
  p_payment_captured boolean default false
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_existing public.srk_razorpay_webhook_events%rowtype;
  v_qr public.srk_razorpay_qr_codes%rowtype;
  v_booking public.service_bookings%rowtype;
  v_bill public.srk_booking_final_bills%rowtype;
begin
  if coalesce(auth.role(),'') <> 'service_role' then
    raise exception 'SERVICE_ROLE_REQUIRED' using errcode='42501';
  end if;
  if p_event_id is null or length(p_event_id) not between 1 and 255
     or p_event_type not in ('qr_code.created','qr_code.credited','qr_code.closed')
     or jsonb_typeof(p_event_payload) <> 'object'
     or coalesce(p_razorpay_qr_code_id,'') !~ '^qr_[A-Za-z0-9]+$' then
    raise exception 'INVALID_VERIFIED_QR_WEBHOOK' using errcode='22023';
  end if;
  if p_event_type='qr_code.credited' and (
      coalesce(p_razorpay_payment_id,'') !~ '^pay_[A-Za-z0-9]+$'
      or p_payment_amount_paise is null or p_payment_amount_paise < 100
      or p_payment_currency <> 'INR' or p_payment_captured is not true
  ) then
    raise exception 'INVALID_CAPTURED_QR_PAYMENT' using errcode='22023';
  end if;

  insert into public.srk_razorpay_webhook_events(
    event_id,event_type,event_payload,razorpay_qr_code_id,
    razorpay_payment_id,payment_amount_paise,payment_currency,
    processing_status,signature_verified_at,processing_attempts,received_at,updated_at
  ) values (
    p_event_id,p_event_type,p_event_payload,p_razorpay_qr_code_id,
    p_razorpay_payment_id,p_payment_amount_paise,p_payment_currency,
    'received',clock_timestamp(),0,clock_timestamp(),clock_timestamp()
  ) on conflict(event_id) do nothing;

  if not found then
    select * into v_existing from public.srk_razorpay_webhook_events
      where event_id=p_event_id for update;
    if v_existing.event_type is distinct from p_event_type
       or v_existing.event_payload is distinct from p_event_payload then
      raise exception 'WEBHOOK_EVENT_ID_PAYLOAD_MISMATCH' using errcode='23505';
    end if;
    return jsonb_build_object('success',true,'duplicate',true,
      'status',v_existing.processing_status);
  end if;

  select * into v_qr from public.srk_razorpay_qr_codes
    where razorpay_qr_code_id=p_razorpay_qr_code_id for update;
  if not found then
    update public.srk_razorpay_webhook_events
      set processing_status='exception',reconciliation_reason='Unknown Razorpay QR code',
          updated_at=clock_timestamp()
      where event_id=p_event_id;
    return jsonb_build_object('success',true,'duplicate',false,'status','exception');
  end if;

  if p_event_type='qr_code.created' then
    if v_qr.provider_status='creating' then
      update public.srk_razorpay_qr_codes set provider_status='active',
        provider_payload=p_event_payload,updated_at=clock_timestamp() where id=v_qr.id;
    end if;
  elsif p_event_type='qr_code.closed' then
    if v_qr.provider_status not in ('paid','expired') then
      update public.srk_razorpay_qr_codes set provider_status='closed',
        closed_at=coalesce(to_timestamp(nullif(p_event_payload #>> '{payload,qr_code,entity,closed_at}','')::bigint),clock_timestamp()),
        close_reason=p_event_payload #>> '{payload,qr_code,entity,close_reason}',
        provider_payload=p_event_payload,updated_at=clock_timestamp() where id=v_qr.id;
    end if;
  elsif p_event_type='qr_code.credited' then
    if v_qr.provider_status='paid' and v_qr.razorpay_payment_id=p_razorpay_payment_id then
      update public.srk_razorpay_webhook_events set processing_status='reconciled',
        processed_at=clock_timestamp(),updated_at=clock_timestamp() where event_id=p_event_id;
      return jsonb_build_object('success',true,'duplicate_payment',true,'status','reconciled');
    end if;
    if v_qr.provider_status<>'active' then
      update public.srk_razorpay_webhook_events set processing_status='exception',
        reconciliation_reason='QR is not active at payment capture',
        updated_at=clock_timestamp() where event_id=p_event_id;
      return jsonb_build_object('success',true,'status','exception');
    end if;
    if v_qr.amount_paise<>p_payment_amount_paise then
      update public.srk_razorpay_webhook_events set processing_status='exception',
        reconciliation_reason='Captured amount does not match QR bill amount',
        updated_at=clock_timestamp() where event_id=p_event_id;
      update public.srk_razorpay_qr_codes set provider_status='reconciliation_required',
        razorpay_payment_id=p_razorpay_payment_id,
        payments_amount_received_paise=p_payment_amount_paise,
        provider_payload=p_event_payload,updated_at=clock_timestamp() where id=v_qr.id;
      return jsonb_build_object('success',true,'status','exception');
    end if;

    select * into v_booking from public.service_bookings
      where id=v_qr.booking_id for update;
    select * into v_bill from public.srk_booking_final_bills
      where id=v_qr.final_bill_id and booking_id=v_qr.booking_id for update;
    if not found or v_bill.revision_no<>v_qr.final_bill_revision
       or round(v_bill.total_amount*100)::bigint<>v_qr.amount_paise
       or v_booking.customer_user_id is distinct from v_qr.customer_user_id
       or v_booking.status<>'completed'
       or lower(coalesce(v_booking.payment_status,'')) in ('paid','completed','refunded')
       or lower(coalesce(v_booking.payment_method,'')) not in ('online','upi','card') then
      update public.srk_razorpay_webhook_events set processing_status='exception',
        reconciliation_reason='Booking or final bill snapshot is no longer payable',
        updated_at=clock_timestamp() where event_id=p_event_id;
      update public.srk_razorpay_qr_codes set provider_status='reconciliation_required',
        razorpay_payment_id=p_razorpay_payment_id,
        payments_amount_received_paise=p_payment_amount_paise,
        provider_payload=p_event_payload,updated_at=clock_timestamp() where id=v_qr.id;
      return jsonb_build_object('success',true,'status','exception');
    end if;
    if v_booking.razorpay_payment_id is not null
       and v_booking.razorpay_payment_id<>p_razorpay_payment_id then
      update public.srk_razorpay_webhook_events set processing_status='exception',
        reconciliation_reason='A different Razorpay payment is already linked to booking',
        updated_at=clock_timestamp() where event_id=p_event_id;
      return jsonb_build_object('success',true,'status','exception');
    end if;
    if exists (select 1 from public.srk_razorpay_qr_codes q
      where q.razorpay_payment_id=p_razorpay_payment_id and q.id<>v_qr.id) then
      raise exception 'RAZORPAY_PAYMENT_ALREADY_LINKED_TO_ANOTHER_QR';
    end if;

    update public.srk_razorpay_qr_codes set provider_status='paid',
      razorpay_payment_id=p_razorpay_payment_id,paid_at=clock_timestamp(),
      payments_amount_received_paise=p_payment_amount_paise,payments_count_received=1,
      provider_payload=p_event_payload,updated_at=clock_timestamp() where id=v_qr.id;

    update public.service_bookings set payment_status='paid',
      payment_method='upi',amount_paid=(p_payment_amount_paise::numeric/100),
      razorpay_payment_id=p_razorpay_payment_id,
      payment_verified_at=clock_timestamp()
      where id=v_booking.id;
  end if;

  update public.srk_razorpay_webhook_events set processing_status='reconciled',
    processed_at=clock_timestamp(),updated_at=clock_timestamp()
    where event_id=p_event_id;
  return jsonb_build_object('success',true,'duplicate',false,'status','reconciled');
end;
$$;
revoke all on function public.srk_service_record_verified_razorpay_qr_webhook(text,text,jsonb,text,text,bigint,text,boolean) from public, anon, authenticated;
grant execute on function public.srk_service_record_verified_razorpay_qr_webhook(text,text,jsonb,text,text,bigint,text,boolean) to service_role;
