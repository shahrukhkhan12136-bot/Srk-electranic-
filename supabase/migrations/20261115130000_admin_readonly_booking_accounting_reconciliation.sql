-- Main Admin-only, read-only per-booking accounting reconciliation.
-- Feature Branch source only. This function never posts ledger rows, changes payout
-- state, or calls a payment provider.

create or replace function public.srk_admin_get_booking_accounting_reconciliation(
  p_booking_id uuid
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $function$
declare
  v_booking public.service_bookings%rowtype;
  v_bill public.srk_booking_labour_bills%rowtype;
  v_payout public.srk_electrician_payouts%rowtype;
  v_refund public.srk_razorpay_refunds%rowtype;
  v_manual_refund public.srk_manual_refund_entries%rowtype;
  v_labour_paise bigint := 0;
  v_materials_paise bigint := 0;
  v_commission_paise bigint := 0;
  v_payable_paise bigint := 0;
  v_collection_paise bigint := 0;
  v_refund_paise bigint := 0;
  v_fee_allocated_paise bigint := 0;
  v_fee_ledger_net_paise bigint := 0;
  v_fee_source_open_paise bigint := 0;
  v_wallet_credit_paise bigint := 0;
  v_wallet_debit_paise bigint := 0;
  v_route_electrician_paise bigint := 0;
  v_route_platform_paise bigint := 0;
  v_route_electrician_processed_paise bigint := 0;
  v_route_electrician_settled_paise bigint := 0;
  v_route_platform_processed_paise bigint := 0;
  v_route_platform_settled_paise bigint := 0;
  v_exceptions text[] := array[]::text[];
  v_route jsonb := '[]'::jsonb;
  v_fee_ledger jsonb := '[]'::jsonb;
  v_wallet jsonb := '[]'::jsonb;
  v_refund_state text := 'none';
  v_payment_verified boolean := false;
  v_expected_collection_paise bigint := 0;
  v_refund_request_status text;
begin
  if auth.uid() is null or not public.is_srk_admin() then
    raise exception 'ADMIN_ONLY' using errcode='42501';
  end if;
  if p_booking_id is null then
    raise exception 'BOOKING_ID_REQUIRED' using errcode='22023';
  end if;

  select * into v_booking
    from public.service_bookings b
   where b.id=p_booking_id;
  if not found then
    raise exception 'BOOKING_NOT_FOUND' using errcode='P0002';
  end if;

  v_payment_verified := v_booking.payment_status in ('paid','refunded')
    and v_booking.payment_verified_at is not null
    and coalesce(v_booking.amount_paid,0)>0;
  if v_payment_verified then
    v_collection_paise := round(v_booking.amount_paid*100)::bigint;
  end if;

  if v_booking.selected_category is not null then
    select * into v_bill
      from public.srk_booking_labour_bills b
     where b.booking_id=p_booking_id;
    if found then
      v_labour_paise := v_bill.labour_amount_paise::bigint;
    else
      v_exceptions := array_append(v_exceptions,'MISSING_IMMUTABLE_LABOUR_BILL');
    end if;
    v_materials_paise := 0;
  else
    v_labour_paise := round(coalesce(v_booking.service_charge,0)*100)::bigint;
    v_materials_paise := round(coalesce(v_booking.materials_amount,0)*100)::bigint;
  end if;

  v_commission_paise := round((v_labour_paise::numeric *
    coalesce(v_booking.commission_rate,0) / 100))::bigint;
  v_payable_paise := greatest(v_labour_paise + v_materials_paise - v_commission_paise,0);

  select * into v_payout
    from public.srk_electrician_payouts p
   where p.booking_id=p_booking_id;
  if not found and v_booking.status='completed' and v_payment_verified
     and v_booking.assigned_electrician_id is not null then
    v_exceptions := array_append(v_exceptions,'MISSING_PAYOUT_ROW');
  elsif found then
    if round(coalesce(v_payout.gross_service_amount,0)*100)::bigint<>v_labour_paise
       or round(coalesce(v_payout.materials_amount,0)*100)::bigint<>v_materials_paise
       or round(coalesce(v_payout.platform_commission,0)*100)::bigint<>v_commission_paise
       or round(coalesce(v_payout.electrician_payable,0)*100)::bigint<>v_payable_paise then
      v_exceptions := array_append(v_exceptions,'PAYOUT_AMOUNT_MISMATCH');
    end if;
  end if;

  select * into v_refund from public.srk_razorpay_refunds r
   where r.booking_id=p_booking_id;
  select * into v_manual_refund from public.srk_manual_refund_entries m
   where m.booking_id=p_booking_id;
  if found then
    v_refund_paise := round(v_manual_refund.amount*100)::bigint;
    v_refund_state := 'manual_recorded';
  end if;
  if v_refund.id is not null then
    v_refund_paise := v_refund.amount_paise;
    v_refund_state := v_refund.status;
  end if;
  if v_refund.id is not null and v_manual_refund.id is not null then
    v_exceptions := array_append(v_exceptions,'MULTIPLE_REFUND_RECORDS');
  end if;
  if v_refund_paise>0 and v_refund_paise<v_collection_paise then
    v_exceptions := array_append(v_exceptions,'PARTIAL_REFUND_UNSUPPORTED');
  end if;
  if v_refund_state in ('requested','processing','unknown') then
    v_exceptions := array_append(v_exceptions,'REFUND_PENDING_REVIEW');
  end if;
  if v_booking.payment_status='refunded' and v_refund_state not in ('processed','manual_recorded') then
    v_exceptions := array_append(v_exceptions,'REFUNDED_BOOKING_WITHOUT_FINAL_REFUND_EVIDENCE');
  end if;

  select coalesce(sum(i.amount_paise),0)::bigint
    into v_fee_allocated_paise
    from public.srk_booking_cancellation_fee_items i
   where i.booking_id=p_booking_id and i.status in ('reserved','settled');

  select coalesce(sum(case when l.direction='credit' then l.amount_paise else -l.amount_paise end),0)::bigint
    into v_fee_ledger_net_paise
    from public.srk_cancellation_fee_ledger l
   where l.booking_id=p_booking_id;

  select coalesce(sum(d.amount_paise),0)::bigint
    into v_fee_source_open_paise
    from public.srk_customer_cancellation_fee_debts d
   where d.source_booking_id=p_booking_id and d.status in ('open','reserved');

  if v_fee_ledger_net_paise<0 then
    v_exceptions := array_append(v_exceptions,'CANCELLATION_FEE_LEDGER_NEGATIVE_NET');
  end if;

  select
    coalesce(sum(case when w.direction='credit' then round(w.amount*100)::bigint else 0 end),0)::bigint,
    coalesce(sum(case when w.direction='debit' then round(w.amount*100)::bigint else 0 end),0)::bigint
  into v_wallet_credit_paise,v_wallet_debit_paise
  from public.srk_wallet_ledger w
  where w.status='posted'
    and (
      w.reference_id=p_booking_id::text
      or w.reference_id in (
        select i.id::text from public.srk_booking_cancellation_fee_items i
         where i.booking_id=p_booking_id
      )
    );

  select
    coalesce(sum(t.amount_paise) filter(where t.recipient_type='electrician'),0)::bigint,
    coalesce(sum(t.amount_paise) filter(where t.recipient_type='platform_commission'),0)::bigint,
    coalesce(sum(t.amount_paise) filter(where t.recipient_type='electrician' and t.transfer_status='processed'),0)::bigint,
    coalesce(sum(t.amount_paise) filter(where t.recipient_type='electrician' and t.settlement_status='settled'),0)::bigint,
    coalesce(sum(t.amount_paise) filter(where t.recipient_type='platform_commission' and t.transfer_status='processed'),0)::bigint,
    coalesce(sum(t.amount_paise) filter(where t.recipient_type='platform_commission' and t.settlement_status='settled'),0)::bigint,
    coalesce(jsonb_agg(jsonb_build_object(
      'recipient_type',t.recipient_type,'recipient_user_id',t.recipient_user_id,
      'amount_paise',t.amount_paise,'transfer_status',t.transfer_status,
      'settlement_status',t.settlement_status,'transfer_id',t.transfer_id,
      'provider_payment_id',t.razorpay_payment_id,'updated_at',t.updated_at
    ) order by t.created_at,t.id),'[]'::jsonb)
  into v_route_electrician_paise,v_route_platform_paise,
       v_route_electrician_processed_paise,v_route_electrician_settled_paise,
       v_route_platform_processed_paise,v_route_platform_settled_paise,v_route
  from public.srk_route_transfers t
  where t.booking_id=p_booking_id;

  if v_route_electrician_paise>0 and v_route_electrician_paise<>v_payable_paise then
    v_exceptions := array_append(v_exceptions,'ELECTRICIAN_ROUTE_TRANSFER_MISMATCH');
  end if;
  if v_route_platform_paise>0 and v_route_platform_paise<>v_commission_paise then
    v_exceptions := array_append(v_exceptions,'PLATFORM_ROUTE_TRANSFER_MISMATCH');
  end if;
  if v_route_platform_paise=0 and v_commission_paise>0 and v_booking.razorpay_payment_id is not null then
    v_exceptions := array_append(v_exceptions,'COMMISSION_NOT_TRANSFERRED');
  elsif v_route_platform_paise>0 and v_route_platform_settled_paise<v_commission_paise then
    v_exceptions := array_append(v_exceptions,'COMMISSION_TRANSFER_NOT_SETTLED');
  end if;
  if v_route_electrician_paise>0 and v_route_electrician_settled_paise<v_payable_paise then
    v_exceptions := array_append(v_exceptions,'ELECTRICIAN_TRANSFER_NOT_SETTLED');
  end if;

  select coalesce(jsonb_agg(jsonb_build_object(
    'entry_type',l.entry_type,'direction',l.direction,'amount_paise',l.amount_paise,
    'status',l.status,'payment_reference',l.payment_reference,'created_at',l.created_at
  ) order by l.created_at,l.id),'[]'::jsonb)
  into v_fee_ledger
  from public.srk_cancellation_fee_ledger l
  where l.booking_id=p_booking_id;

  select coalesce(jsonb_agg(jsonb_build_object(
    'wallet_type',w.wallet_type,'entry_type',w.entry_type,'direction',w.direction,
    'amount_paise',round(w.amount*100)::bigint,'status',w.status,
    'reference_type',w.reference_type,'reference_id',w.reference_id,'created_at',w.created_at
  ) order by w.created_at,w.id),'[]'::jsonb)
  into v_wallet
  from public.srk_wallet_ledger w
  where w.status='posted'
    and (
      w.reference_id=p_booking_id::text
      or w.reference_id in (
        select i.id::text from public.srk_booking_cancellation_fee_items i
         where i.booking_id=p_booking_id
      )
    );

  select r.status into v_refund_request_status
    from public.srk_booking_refund_requests r
   where r.booking_id=p_booking_id;

  return jsonb_build_object(
    'booking_id',v_booking.id,
    'booking_status',v_booking.status,
    'payment_status',v_booking.payment_status,
    'payment_verified',v_payment_verified,
    'payment_method',v_booking.payment_method,
    'razorpay_payment_id',v_booking.razorpay_payment_id,
    'customer_collection_paise',v_collection_paise,
    'refund_paise',v_refund_paise,
    'refund_status',v_refund_state,
    'customer_net_collection_paise',greatest(v_collection_paise-v_refund_paise,0),
    'customer_refund_request_status',v_refund_request_status,
    'labour_gross_paise',v_labour_paise,
    'materials_gross_paise',v_materials_paise,
    'labour_only_commission_expected_paise',v_commission_paise,
    'electrician_payable_expected_paise',v_payable_paise,
    'payout',case when v_payout.id is null then null else jsonb_build_object(
      'payout_id',v_payout.id,'status',v_payout.payout_status,
      'recorded_payable_paise',round(v_payout.electrician_payable*100)::bigint,
      'method',v_payout.payout_method,'reference',v_payout.payout_reference,
      'paid_at',v_payout.paid_at
    ) end,
    'route_transfers',v_route,
    'route_electrician_amount_paise',v_route_electrician_paise,
    'route_electrician_processed_paise',v_route_electrician_processed_paise,
    'route_electrician_settled_paise',v_route_electrician_settled_paise,
    'route_platform_commission_amount_paise',v_route_platform_paise,
    'route_platform_commission_processed_paise',v_route_platform_processed_paise,
    'route_platform_commission_settled_paise',v_route_platform_settled_paise,
    'cancellation_fee_allocated_to_booking_paise',v_fee_allocated_paise,
    'cancellation_fee_source_open_or_reserved_paise',v_fee_source_open_paise,
    'cancellation_fee_ledger_net_paise',v_fee_ledger_net_paise,
    'cancellation_fee_ledger_entries',v_fee_ledger,
    'wallet_posted_credit_paise',v_wallet_credit_paise,
    'wallet_posted_debit_paise',v_wallet_debit_paise,
    'wallet_posted_entries',v_wallet,
    'exceptions',to_jsonb(v_exceptions),
    'is_reconciled',cardinality(v_exceptions)=0,
    'report_generated_at',clock_timestamp()
  );
end;
$function$;

revoke all on function public.srk_admin_get_booking_accounting_reconciliation(uuid)
  from public,anon;
grant execute on function public.srk_admin_get_booking_accounting_reconciliation(uuid)
  to authenticated;

comment on function public.srk_admin_get_booking_accounting_reconciliation(uuid) is
  'Read-only Main Admin per-booking financial reconciliation. Never posts, transfers, or marks payouts paid.';
