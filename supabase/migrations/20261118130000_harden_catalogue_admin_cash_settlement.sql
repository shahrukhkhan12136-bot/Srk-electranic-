-- Harden new-Catalogue Admin cash settlement state and payment-evidence checks.
-- Source-only migration. Do not apply until separately approved.
BEGIN;

create or replace function public.srk_admin_record_new_booking_cash_payment(
  p_booking_id uuid,p_reference text,p_note text default null
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
  if length(v_reference)<4 or length(v_reference)>120 then raise exception 'VALID_CASH_RECEIPT_REFERENCE_REQUIRED'; end if;
  -- Share the same reference lock with the new-Catalogue UPI/bank RPC.
  perform pg_advisory_xact_lock(hashtextextended(lower(v_reference), 73119));
  if exists(select 1 from public.srk_manual_payment_entries
     where lower(btrim(payment_reference))=lower(v_reference)) then
    raise exception 'MANUAL_PAYMENT_REFERENCE_ALREADY_USED';
  end if;
  if p_note is not null and length(p_note)>250 then raise exception 'PAYMENT_NOTE_TOO_LONG'; end if;
  select * into v_booking from public.service_bookings where id=p_booking_id for update;
  if not found then raise exception 'BOOKING_NOT_FOUND'; end if;
  if v_booking.status<>'completed' or v_booking.assigned_electrician_id is null then raise exception 'COMPLETED_ASSIGNED_BOOKING_REQUIRED'; end if;
  if v_booking.selected_category is null then raise exception 'NEW_CATALOGUE_BOOKING_REQUIRED'; end if;
  if lower(coalesce(v_booking.payment_method,'')) not like '%cash%' then raise exception 'BOOKING_PAYMENT_METHOD_IS_NOT_CASH'; end if;
  if v_booking.payment_status is null or v_booking.payment_status not in ('unpaid','pending') then
    raise exception 'BOOKING_PAYMENT_STATE_NOT_PAYABLE';
  end if;
  if v_booking.payment_verified_at is not null or coalesce(v_booking.amount_paid,0)<>0
     or v_booking.razorpay_payment_id is not null then
    raise exception 'BOOKING_HAS_EXISTING_PAYMENT_EVIDENCE';
  end if;
  if v_booking.razorpay_order_id is not null or v_booking.razorpay_payment_id is not null then raise exception 'RAZORPAY_BOOKING_MUST_USE_ONLINE_VERIFICATION'; end if;
  select * into v_labour from public.srk_booking_labour_bills where booking_id=p_booking_id;
  if not found then raise exception 'IMMUTABLE_LABOUR_BILL_REQUIRED'; end if;
  if v_labour.electrician_profile_id is distinct from v_booking.assigned_electrician_id then
    raise exception 'IMMUTABLE_LABOUR_BILL_OR_ELECTRICIAN_ASSIGNMENT_MISMATCH';
  end if;
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
  values(p_booking_id,'cash',v_total/100.0,v_reference,nullif(btrim(coalesce(p_note,'')),''),auth.uid());
  update public.service_bookings set payment_method='Cash',payment_status='paid',
    amount_paid=v_total/100.0,payment_verified_at=now() where id=p_booking_id;

  for v_item in select * from public.srk_booking_cancellation_fee_items
    where booking_id=p_booking_id and status='reserved' order by created_at,id for update
  loop
    perform 1 from public.srk_customer_cancellation_fee_debts
      where id=v_item.debt_id and status='reserved'
        and reserved_booking_id=p_booking_id
        and customer_user_id=v_booking.customer_user_id
      for update;
    if not found then raise exception 'CANCELLATION_FEE_DEBT_RESERVATION_MISMATCH'; end if;
    insert into public.srk_wallet_ledger(wallet_id,user_id,wallet_type,entry_type,direction,amount,status,
      reference_type,reference_id,idempotency_key,description,posted_at)
    values(v_wallet,v_electrician_user,'electrician','cancellation_fee','debit',
      v_item.amount_paise/100.0,'posted','cancellation_fee_item',v_item.id::text,
      'cancel-fee:cash:electrician-debit:'||v_item.id::text,
      'Customer paid prior cancellation fee in cash; SRK recovery from electrician wallet',now())
    on conflict(idempotency_key) do nothing;
    insert into public.srk_cancellation_fee_ledger(debt_id,booking_id,source_booking_id,customer_user_id,
      electrician_user_id,entry_type,direction,amount_paise,idempotency_key,note)
    values(v_item.debt_id,p_booking_id,v_item.source_booking_id,v_booking.customer_user_id,
      v_electrician_user,'cash_electrician_debit','credit',v_item.amount_paise,
      'cancel-fee:cash:srk-credit:'||v_item.id::text,
      'Cash cancellation fee collected by electrician and credited to SRK receivable ledger')
    on conflict(idempotency_key) do nothing;
    update public.srk_booking_cancellation_fee_items set status='settled',settled_at=now()
      where id=v_item.id and status='reserved';
    update public.srk_customer_cancellation_fee_debts set status='settled',settled_at=now()
      where id=v_item.debt_id and status='reserved';
  end loop;
  return jsonb_build_object('success',true,'booking_id',p_booking_id,
    'labour_amount_paise',v_labour.labour_amount_paise,'cancellation_fee_amount_paise',v_fee,
    'total_amount_paise',v_total,'electrician_wallet_debit_paise',v_fee);
end;
$$;

REVOKE ALL ON FUNCTION public.srk_admin_record_new_booking_cash_payment(uuid,text,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.srk_admin_record_new_booking_cash_payment(uuid,text,text) TO authenticated;

COMMIT;
