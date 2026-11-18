-- Admin-verified UPI / bank-transfer settlement for new Catalogue bookings.
-- Source-only. Do not apply without approved migration/runtime validation.
BEGIN;

create or replace function public.srk_admin_record_new_booking_manual_digital_payment(
  p_booking_id uuid,p_method text,p_reference text,p_note text default null
)
returns jsonb language plpgsql security definer set search_path=''
as $$
declare
  v_booking public.service_bookings%rowtype;
  v_labour public.srk_booking_labour_bills%rowtype;
  v_profile public.electrician_profiles%rowtype;
  v_electrician_user uuid;
  v_wallet uuid;
  v_fee bigint;
  v_total bigint;
  v_reference text:=btrim(coalesce(p_reference,''));
  v_item record;
begin
  if auth.uid() is null or not public.is_srk_admin() then raise exception 'ADMIN_ONLY' using errcode='42501'; end if;
  if p_method is null or p_method not in ('upi','bank_transfer') then raise exception 'INVALID_MANUAL_DIGITAL_PAYMENT_METHOD'; end if;
  if length(v_reference)<4 or length(v_reference)>120 then raise exception 'VALID_UPI_REFERENCE_OR_BANK_UTR_REQUIRED'; end if;
  if p_note is not null and length(p_note)>250 then raise exception 'PAYMENT_NOTE_TOO_LONG'; end if;
  select * into v_booking from public.service_bookings where id=p_booking_id for update;
  if not found then raise exception 'BOOKING_NOT_FOUND'; end if;
  if v_booking.status<>'completed' or v_booking.assigned_electrician_id is null then raise exception 'COMPLETED_ASSIGNED_BOOKING_REQUIRED'; end if;
  if lower(btrim(coalesce(v_booking.payment_method,''))) not in ('upi','bank_transfer','bank transfer') then raise exception 'BOOKING_PAYMENT_METHOD_MISMATCH'; end if;
  if (p_method='upi' and lower(btrim(v_booking.payment_method))<>'upi')
     or (p_method='bank_transfer' and lower(btrim(v_booking.payment_method)) not in ('bank_transfer','bank transfer')) then
    raise exception 'BOOKING_PAYMENT_METHOD_MISMATCH';
  end if;
  if v_booking.payment_status is null or v_booking.payment_status not in ('unpaid','pending') then
    raise exception 'BOOKING_PAYMENT_STATE_NOT_PAYABLE';
  end if;
  if v_booking.payment_verified_at is not null or coalesce(v_booking.amount_paid,0)<>0
     or v_booking.razorpay_order_id is not null or v_booking.razorpay_payment_id is not null then
    raise exception 'BOOKING_HAS_EXISTING_PAYMENT_EVIDENCE';
  end if;
  -- Serialize duplicate UPI references / bank UTRs before checking the evidence table.
  perform pg_advisory_xact_lock(hashtextextended(lower(v_reference), 73119));
  if exists(select 1 from public.srk_manual_payment_entries
     where lower(btrim(payment_reference))=lower(v_reference)) then
    raise exception 'MANUAL_PAYMENT_REFERENCE_ALREADY_USED';
  end if;
  select * into v_labour from public.srk_booking_labour_bills where booking_id=p_booking_id;
  if not found then raise exception 'IMMUTABLE_LABOUR_BILL_REQUIRED'; end if;
  select coalesce(sum(amount_paise),0) into v_fee from public.srk_booking_cancellation_fee_items
    where booking_id=p_booking_id and status='reserved';
  v_total:=v_labour.labour_amount_paise+v_fee;
  if v_total<=0 or v_total>1000000000 then raise exception 'INVALID_BOOKING_TOTAL'; end if;
  if exists(select 1 from public.srk_manual_payment_entries where booking_id=p_booking_id) then raise exception 'MANUAL_PAYMENT_ALREADY_RECORDED'; end if;
  select * into v_profile from public.electrician_profiles where id=v_labour.electrician_profile_id;
  v_electrician_user:=coalesce(v_profile.auth_user_id,v_profile.user_id);
  if v_electrician_user is null then raise exception 'ELECTRICIAN_AUTH_USER_REQUIRED'; end if;
  insert into public.srk_wallet_accounts(user_id,wallet_type) values(v_electrician_user,'electrician')
    on conflict(user_id,wallet_type) do nothing;
  select id into v_wallet from public.srk_wallet_accounts where user_id=v_electrician_user and wallet_type='electrician' for update;

  insert into public.srk_manual_payment_entries(booking_id,payment_method,amount,payment_reference,note,recorded_by)
  values(p_booking_id,p_method,v_total/100.0,v_reference,nullif(btrim(coalesce(p_note,'')),''),auth.uid());
  update public.service_bookings set payment_method=case when p_method='upi' then 'UPI' else 'Bank Transfer' end,payment_status='paid',
    amount_paid=v_total/100.0,payment_verified_at=now() where id=p_booking_id;

  for v_item in select * from public.srk_booking_cancellation_fee_items
    where booking_id=p_booking_id and status='reserved' order by created_at,id for update
  loop
    -- UPI/bank funds are collected by SRK directly; no electrician cash-recovery debit applies.
    insert into public.srk_cancellation_fee_ledger(debt_id,booking_id,source_booking_id,
      customer_user_id,entry_type,direction,amount_paise,payment_reference,idempotency_key,note)
    values(v_item.debt_id,p_booking_id,v_item.source_booking_id,v_booking.customer_user_id,
      'online_collection','credit',v_item.amount_paise,v_reference,
      'cancel-fee:manual-digital:srk-credit:'||v_item.id::text,
      'Admin-verified UPI/bank transfer cancellation-fee component credited to SRK')
    on conflict(idempotency_key) do nothing;
    update public.srk_booking_cancellation_fee_items set status='settled',settled_at=now()
      where id=v_item.id and status='reserved';
    update public.srk_customer_cancellation_fee_debts set status='settled',settled_at=now()
      where id=v_item.debt_id and status='reserved';
  end loop;
  return jsonb_build_object('success',true,'booking_id',p_booking_id,
    'labour_amount_paise',v_labour.labour_amount_paise,'cancellation_fee_amount_paise',v_fee,
    'total_amount_paise',v_total,'electrician_wallet_debit_paise',0);
end;
$$;

REVOKE ALL ON FUNCTION public.srk_admin_record_new_booking_manual_digital_payment(uuid,text,text,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.srk_admin_record_new_booking_manual_digital_payment(uuid,text,text,text) TO authenticated;

COMMIT;
