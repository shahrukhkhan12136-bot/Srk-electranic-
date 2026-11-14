-- Customer refund request contract for the current Customer Portal.
-- Requests are informational until Admin review; this migration never calls a payment provider.
-- New categorized bookings are reconciled to the immutable labour bill and settled fee ledger.
create or replace function public.srk_customer_create_booking_refund_request(
  p_booking_id uuid,
  p_reason text
)
returns jsonb
language plpgsql
security definer
set search_path=''
as $function$
declare
  v_uid uuid:=auth.uid();
  v_booking public.service_bookings%rowtype;
  v_request public.srk_booking_refund_requests%rowtype;
  v_labour_paise bigint;
  v_fee_paise bigint:=0;
  v_expected_paise bigint;
begin
  if v_uid is null then
    raise exception 'AUTHENTICATION_REQUIRED' using errcode='42501';
  end if;
  if p_booking_id is null or p_reason is null
     or length(btrim(p_reason)) not between 20 and 1000 then
    raise exception 'REFUND_REASON_MUST_BE_20_TO_1000_CHARACTERS' using errcode='22023';
  end if;

  select * into v_booking
  from public.service_bookings b
  where b.id=p_booking_id and b.customer_user_id=v_uid
  for update;
  if not found then
    raise exception 'BOOKING_NOT_FOUND_OR_NOT_OWNED' using errcode='42501';
  end if;
  if v_booking.payment_status<>'paid'
     or v_booking.payment_verified_at is null
     or v_booking.amount_paid is null
     or v_booking.amount_paid<=0 then
    raise exception 'ONLY_VERIFIED_PAID_BOOKINGS_CAN_REQUEST_REFUND' using errcode='55000';
  end if;

  if v_booking.selected_category is not null then
    if v_booking.status<>'completed' then
      raise exception 'BOOKING_NOT_COMPLETED' using errcode='55000';
    end if;
    select bill.labour_amount_paise into v_labour_paise
    from public.srk_booking_labour_bills bill
    where bill.booking_id=p_booking_id
      and bill.customer_user_id=v_uid;
    if not found or v_labour_paise is null or v_labour_paise<=0 then
      raise exception 'IMMUTABLE_LABOUR_BILL_REQUIRED' using errcode='55000';
    end if;
    if exists(
      select 1 from public.srk_booking_cancellation_fee_items fee
      where fee.booking_id=p_booking_id and fee.status<>'settled'
    ) then
      raise exception 'CANCELLATION_FEE_ITEMS_NOT_FULLY_SETTLED' using errcode='55000';
    end if;
    select coalesce(sum(fee.amount_paise),0)::bigint into v_fee_paise
    from public.srk_booking_cancellation_fee_items fee
    where fee.booking_id=p_booking_id and fee.status='settled';
    v_expected_paise:=v_labour_paise+v_fee_paise;
    if v_expected_paise<>round(v_booking.amount_paid*100)::bigint then
      raise exception 'PAID_AMOUNT_DOES_NOT_MATCH_IMMUTABLE_LABOUR_AND_FEE_LEDGER' using errcode='55000';
    end if;
  else
    v_expected_paise:=round(v_booking.amount_paid*100)::bigint;
  end if;

  if exists(
    select 1 from public.srk_razorpay_refunds r
    where r.booking_id=p_booking_id
  ) then
    raise exception 'REFUND_ALREADY_EXISTS_FOR_BOOKING' using errcode='23505';
  end if;
  if exists(
    select 1 from public.srk_manual_refund_entries r
    where r.booking_id=p_booking_id
  ) then
    raise exception 'REFUND_ALREADY_RECORDED_FOR_BOOKING' using errcode='23505';
  end if;

  select * into v_request
  from public.srk_booking_refund_requests r
  where r.booking_id=p_booking_id
  for update;
  if found then
    if v_request.status<>'rejected' then
      raise exception 'REFUND_REQUEST_ALREADY_SUBMITTED' using errcode='23505';
    end if;
    update public.srk_booking_refund_requests
    set customer_user_id=v_uid,
        amount=v_expected_paise/100.0,
        reason=btrim(p_reason),
        status='requested',
        admin_note=null,
        refund_record_id=null,
        decided_by=null,
        processed_at=null,
        updated_at=clock_timestamp()
    where id=v_request.id
    returning * into v_request;
  else
    insert into public.srk_booking_refund_requests(
      booking_id,customer_user_id,amount,reason
    ) values (
      p_booking_id,v_uid,v_expected_paise/100.0,btrim(p_reason)
    ) returning * into v_request;
  end if;

  return jsonb_build_object(
    'success',true,
    'request_id',v_request.id,
    'amount',v_request.amount,
    'status',v_request.status
  );
end;
$function$;

revoke all on function public.srk_customer_create_booking_refund_request(uuid,text) from public,anon;
grant execute on function public.srk_customer_create_booking_refund_request(uuid,text) to authenticated;

-- Customer projection deliberately omits the private Admin note.
create or replace function public.srk_customer_list_booking_refund_requests()
returns table(
  id uuid,
  booking_id uuid,
  amount numeric,
  reason text,
  status text,
  created_at timestamptz,
  updated_at timestamptz,
  processed_at timestamptz
)
language plpgsql
stable
security definer
set search_path=''
as $function$
declare
  v_uid uuid:=auth.uid();
begin
  if v_uid is null then
    raise exception 'AUTHENTICATION_REQUIRED' using errcode='42501';
  end if;
  return query
  select r.id,r.booking_id,r.amount,r.reason,r.status,
         r.created_at,r.updated_at,r.processed_at
  from public.srk_booking_refund_requests r
  where r.customer_user_id=v_uid
  order by r.created_at desc,r.id desc;
end;
$function$;

revoke all on function public.srk_customer_list_booking_refund_requests() from public,anon;
grant execute on function public.srk_customer_list_booking_refund_requests() to authenticated;
