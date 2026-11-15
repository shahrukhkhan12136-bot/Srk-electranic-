-- Restore the legacy Admin manual-payment RPC and reconcile labour/materials separately.
-- Feature-branch source only. Do not apply to Production without explicit approval.

create or replace function public.srk_admin_record_manual_payment(
  p_booking_id uuid,
  p_method text,
  p_reference text,
  p_note text default null
)
returns jsonb
language plpgsql
security definer
set search_path=''
as $function$
declare
  v_booking public.service_bookings%rowtype;
  v_payment public.srk_manual_payment_entries%rowtype;
  v_payout public.srk_electrician_payouts%rowtype;
  v_reference text:=btrim(coalesce(p_reference,''));
  v_note text:=btrim(coalesce(p_note,''));
  v_service_paise bigint;
  v_materials_paise bigint;
  v_total_paise bigint;
  v_commission_paise bigint;
  v_payable_paise bigint;
  v_service numeric(18,2);
  v_materials numeric(18,2);
  v_total numeric(18,2);
  v_commission numeric(18,2);
  v_payable numeric(18,2);
begin
  if auth.uid() is null or not public.is_srk_admin() then
    raise exception 'ADMIN_ONLY' using errcode='42501';
  end if;
  if p_booking_id is null then
    raise exception 'BOOKING_ID_REQUIRED' using errcode='22023';
  end if;
  if p_method is null or p_method not in ('cash','upi','bank_transfer') then
    raise exception 'INVALID_MANUAL_PAYMENT_METHOD' using errcode='22023';
  end if;
  if char_length(v_reference)<4 or char_length(v_reference)>120 then
    raise exception 'VALID_PAYMENT_RECEIPT_OR_UTR_REQUIRED' using errcode='22023';
  end if;
  if char_length(v_note)>250 then
    raise exception 'PAYMENT_NOTE_TOO_LONG' using errcode='22023';
  end if;

  select * into v_booking
    from public.service_bookings
   where id=p_booking_id
   for update;
  if not found then raise exception 'BOOKING_NOT_FOUND' using errcode='P0002'; end if;

  if v_booking.selected_category is not null then
    raise exception 'NEW_CATEGORY_BOOKING_USES_DEDICATED_SETTLEMENT' using errcode='55000';
  end if;
  if v_booking.status<>'completed'
     or v_booking.assigned_electrician_id is null
     or v_booking.quote_status is distinct from 'approved' then
    raise exception 'COMPLETED_ASSIGNED_APPROVED_QUOTE_REQUIRED' using errcode='55000';
  end if;
  if coalesce(v_booking.payment_status,'unpaid') not in ('unpaid','pending')
     or v_booking.payment_verified_at is not null
     or coalesce(v_booking.amount_paid,0)<>0 then
    raise exception 'BOOKING_ALREADY_HAS_PAYMENT_STATE' using errcode='55000';
  end if;
  if v_booking.razorpay_order_id is not null
     or v_booking.razorpay_payment_id is not null then
    raise exception 'RAZORPAY_BOOKING_MUST_USE_VERIFIED_ONLINE_FLOW' using errcode='55000';
  end if;
  if v_booking.service_charge is null or v_booking.service_charge<=0
     or v_booking.materials_amount is null or v_booking.materials_amount<0
     or v_booking.quoted_amount is null then
    raise exception 'APPROVED_LABOUR_AND_MATERIAL_BREAKDOWN_REQUIRED' using errcode='55000';
  end if;
  if v_booking.commission_rate is null
     or v_booking.commission_rate<0 or v_booking.commission_rate>100 then
    raise exception 'COMMISSION_RATE_MISSING_OR_INVALID' using errcode='55000';
  end if;

  v_service_paise:=round(v_booking.service_charge*100)::bigint;
  v_materials_paise:=round(v_booking.materials_amount*100)::bigint;
  v_total_paise:=v_service_paise+v_materials_paise;
  if v_total_paise<=0 or v_total_paise>1000000000
     or round(v_booking.quoted_amount*100)::bigint<>v_total_paise then
    raise exception 'APPROVED_QUOTE_TOTAL_DOES_NOT_MATCH_LABOUR_AND_MATERIALS' using errcode='55000';
  end if;

  v_commission_paise:=round(v_service_paise::numeric*v_booking.commission_rate/100)::bigint;
  v_payable_paise:=v_total_paise-v_commission_paise;
  v_service:=v_service_paise/100.0;
  v_materials:=v_materials_paise/100.0;
  v_total:=v_total_paise/100.0;
  v_commission:=v_commission_paise/100.0;
  v_payable:=v_payable_paise/100.0;

  insert into public.srk_manual_payment_entries
    (booking_id,payment_method,amount,payment_reference,note,recorded_by)
  values
    (p_booking_id,p_method,v_total,v_reference,nullif(v_note,''),auth.uid())
  returning * into v_payment;

  update public.service_bookings
     set amount_paid=v_total,
         payment_status='paid',
         payment_method=p_method,
         payment_verified_at=clock_timestamp(),
         commission_amount=v_commission
   where id=p_booking_id
     and payment_status not in ('paid','refunded')
     and payment_verified_at is null;
  if not found then
    raise exception 'BOOKING_PAYMENT_STATE_CHANGED' using errcode='40001';
  end if;

  -- Keep the exact labour/material/commission split required by the payout
  -- reconciler. Materials are passed through without platform commission.
  insert into public.srk_electrician_payouts
    (booking_id,electrician_profile_id,razorpay_payment_id,
     gross_service_amount,materials_amount,platform_commission,
     electrician_payable,payout_status)
  values
    (p_booking_id,v_booking.assigned_electrician_id,null,
     v_service,v_materials,v_commission,v_payable,'pending')
  on conflict (booking_id) do nothing;

  select * into v_payout
    from public.srk_electrician_payouts
   where booking_id=p_booking_id
   for update;
  if not found
     or v_payout.electrician_profile_id is distinct from v_booking.assigned_electrician_id
     or v_payout.payout_status<>'pending'
     or round(v_payout.gross_service_amount*100)::bigint<>v_service_paise
     or round(v_payout.materials_amount*100)::bigint<>v_materials_paise
     or round(v_payout.platform_commission*100)::bigint<>v_commission_paise
     or round(v_payout.electrician_payable*100)::bigint<>v_payable_paise
     or v_payout.razorpay_payment_id is not null then
    raise exception 'EXISTING_PAYOUT_DOES_NOT_MATCH_VERIFIED_MANUAL_PAYMENT' using errcode='55000';
  end if;

  return jsonb_build_object(
    'success',true,
    'booking_id',p_booking_id,
    'payment_entry_id',v_payment.id,
    'payment_method',p_method,
    'amount_paid',v_total,
    'labour_amount',v_service,
    'materials_amount',v_materials,
    'commission_amount',v_commission,
    'electrician_payable',v_payable,
    'payment_status','paid'
  );
end;
$function$;

revoke all on function public.srk_admin_record_manual_payment(uuid,text,text,text) from public,anon;
grant execute on function public.srk_admin_record_manual_payment(uuid,text,text,text) to authenticated;

-- Correct the legacy receipt contract: approved labour and itemized materials
-- form the total; platform commission is calculated only on labour.
create or replace function public.srk_customer_get_payment_receipt(p_booking_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path=''
as $function$
declare
  v_uid uuid:=auth.uid();
  v_booking public.service_bookings%rowtype;
  v_bill public.srk_booking_labour_bills%rowtype;
  v_fee_paise bigint:=0;
  v_fee_items jsonb:='[]'::jsonb;
  v_total_paise bigint;
  v_labour_paise bigint;
  v_materials_paise bigint;
begin
  if v_uid is null then raise exception 'Customer login required' using errcode='42501'; end if;
  if p_booking_id is null then raise exception 'Booking ID required' using errcode='22023'; end if;
  select * into v_booking from public.service_bookings
   where id=p_booking_id and customer_user_id=v_uid;
  if not found then raise exception 'Booking not found' using errcode='42501'; end if;
  if v_booking.payment_status<>'paid' or v_booking.payment_verified_at is null
     or coalesce(v_booking.amount_paid,0)<=0 then
    raise exception 'Only verified paid bookings have a payment receipt' using errcode='55000';
  end if;

  if v_booking.selected_category is not null then
    select * into v_bill from public.srk_booking_labour_bills
     where booking_id=p_booking_id and customer_user_id=v_uid;
    if not found then raise exception 'Immutable labour bill not found' using errcode='55000'; end if;
    select coalesce(sum(i.amount_paise),0),
      coalesce(jsonb_agg(jsonb_build_object('source_booking_id',i.source_booking_id,
        'amount_paise',i.amount_paise,'amount',i.amount_paise/100.0) order by i.created_at,i.id),'[]'::jsonb)
      into v_fee_paise,v_fee_items
      from public.srk_booking_cancellation_fee_items i
     where i.booking_id=p_booking_id and i.status='settled';
    v_total_paise:=v_bill.labour_amount_paise+v_fee_paise;
    if round(v_booking.amount_paid*100)::bigint<>v_total_paise then
      raise exception 'Paid amount does not match immutable labour and cancellation fee ledger' using errcode='55000';
    end if;
    return jsonb_build_object(
      'receipt_reference','SRK-PAY-'||upper(left(replace(v_booking.id::text,'-',''),12)),
      'booking_id',v_booking.id,'customer_name',v_booking.customer_name,
      'service_type',v_booking.service_type,'address',v_booking.address,
      'district',v_booking.district,'state',v_booking.state,'pincode',v_booking.pincode,
      'booking_date',v_booking.created_at,'payment_date',v_booking.payment_verified_at,
      'payment_method',case when lower(coalesce(v_booking.payment_method,'')) in
        ('cash','upi','card','online','razorpay','bank_transfer','bank transfer')
        then lower(v_booking.payment_method) else 'other' end,
      'amount_paid',round(v_booking.amount_paid,2),
      'labour_amount',v_bill.labour_amount,
      'materials_amount',0,
      'cancellation_fee_amount',v_fee_paise/100.0,
      'cancellation_fee_items',v_fee_items,
      'total_amount',v_total_paise/100.0,
      'description','सत्यापित भुगतान रसीद — मेहनताना और पुरानी cancellation fee अलग-अलग',
      'document_type','payment_receipt'
    );
  end if;

  v_labour_paise:=round(coalesce(v_booking.service_charge,0)*100)::bigint;
  v_materials_paise:=round(coalesce(v_booking.materials_amount,0)*100)::bigint;
  v_total_paise:=v_labour_paise+v_materials_paise;
  if v_labour_paise<=0
     or round(v_booking.amount_paid*100)::bigint<>v_total_paise
     or round(coalesce(v_booking.quoted_amount,0)*100)::bigint<>v_total_paise then
    raise exception 'Payment receipt does not reconcile to approved labour and materials' using errcode='55000';
  end if;

  return jsonb_build_object(
    'receipt_reference','SRK-PAY-'||upper(left(replace(v_booking.id::text,'-',''),12)),
    'booking_id',v_booking.id,'customer_name',v_booking.customer_name,
    'service_type',v_booking.service_type,'address',v_booking.address,
    'district',v_booking.district,'state',v_booking.state,'pincode',v_booking.pincode,
    'booking_date',v_booking.created_at,'payment_date',v_booking.payment_verified_at,
    'payment_method',case when lower(coalesce(v_booking.payment_method,'')) in
      ('cash','upi','card','online','razorpay','bank_transfer','bank transfer')
      then lower(v_booking.payment_method) else 'other' end,
    'amount_paid',v_total_paise/100.0,
    'labour_amount',v_labour_paise/100.0,
    'materials_amount',v_materials_paise/100.0,
    'cancellation_fee_amount',0,
    'cancellation_fee_items','[]'::jsonb,
    'total_amount',v_total_paise/100.0,
    'description','सत्यापित भुगतान रसीद — मेहनताना और सामग्री अलग-अलग',
    'document_type','payment_receipt'
  );
end;
$function$;

revoke all on function public.srk_customer_get_payment_receipt(uuid) from public,anon;
grant execute on function public.srk_customer_get_payment_receipt(uuid) to authenticated;

notify pgrst,'reload schema';
