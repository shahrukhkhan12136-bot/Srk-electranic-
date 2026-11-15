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
  v_refund_requested_paise bigint := 0;
  v_fee_allocated_paise bigint := 0;
  v_fee_settled_paise bigint := 0;
  v_fee_captured_paise bigint := 0;
  v_route_electrician_count integer := 0;
  v_route_platform_count integer := 0;
  v_fee_ledger_net_paise bigint := 0;
  v_fee_source_open_paise bigint := 0;
  v_wallet_credit_paise bigint := 0;
  v_wallet_debit_paise bigint := 0;
  v_cash_fee_expected_wallet_credit_paise bigint := 0;
  v_cash_fee_actual_wallet_credit_paise bigint := 0;
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
  v_refund_request_status text;
  v_expected_electrician_user_id uuid;
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
    and coalesce(v_booking.amount_paid,0)>0
    and (
      v_booking.razorpay_payment_id is not null
      or exists (
        select 1 from public.srk_manual_payment_entries mp
         where mp.booking_id=p_booking_id
           and round(mp.amount,2)=round(v_booking.amount_paid,2)
      )
    );
  if v_booking.payment_status in ('paid','refunded') and not v_payment_verified then
    v_exceptions := array_append(v_exceptions,'VERIFIED_PAYMENT_EVIDENCE_MISSING_OR_MISMATCHED');
  end if;
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

  if v_booking.commission_rate is null
     or v_booking.commission_rate<0 or v_booking.commission_rate>100 then
    v_exceptions := array_append(v_exceptions,'COMMISSION_RATE_MISSING_OR_INVALID');
    v_commission_paise := null;
    v_payable_paise := null;
  else
    v_commission_paise := round((v_labour_paise::numeric *
      v_booking.commission_rate / 100))::bigint;
    v_payable_paise := greatest(v_labour_paise + v_materials_paise - v_commission_paise,0);
  end if;

  select coalesce(ep.auth_user_id,ep.user_id) into v_expected_electrician_user_id
    from public.electrician_profiles ep
   where ep.id=v_booking.assigned_electrician_id;

  select * into v_payout
    from public.srk_electrician_payouts p
   where p.booking_id=p_booking_id;
  if not found and v_booking.status='completed' and v_payment_verified
     and v_booking.assigned_electrician_id is not null then
    v_exceptions := array_append(v_exceptions,'MISSING_PAYOUT_ROW');
  elsif found then
    if v_payout.electrician_profile_id is distinct from v_booking.assigned_electrician_id then
      v_exceptions := array_append(v_exceptions,'PAYOUT_ELECTRICIAN_ASSIGNMENT_MISMATCH');
    end if;
    if v_booking.status is distinct from 'completed' then
      v_exceptions := array_append(v_exceptions,'PAYOUT_EXISTS_BEFORE_BOOKING_COMPLETION');
    end if;
    if round(coalesce(v_payout.gross_service_amount,0)*100)::bigint is distinct from v_labour_paise
       or round(coalesce(v_payout.materials_amount,0)*100)::bigint is distinct from v_materials_paise
       or round(coalesce(v_payout.platform_commission,0)*100)::bigint is distinct from v_commission_paise
       or round(coalesce(v_payout.electrician_payable,0)*100)::bigint is distinct from v_payable_paise then
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
    v_refund_requested_paise := v_refund.amount_paise;
    v_refund_state := v_refund.status;
    -- Requested/processing/unknown/failed provider amounts are not cash returned
    -- to the customer. Only a provider-confirmed processed refund reduces net collection.
    if v_refund.status='processed' then
      v_refund_paise := v_refund.amount_paise;
    else
      v_refund_paise := 0;
    end if;
  end if;
  if v_refund.id is not null and v_manual_refund.id is not null then
    v_exceptions := array_append(v_exceptions,'MULTIPLE_REFUND_RECORDS');
  end if;
  if v_refund.id is not null
     and v_refund.payment_id is distinct from v_booking.razorpay_payment_id then
    v_exceptions := array_append(v_exceptions,'REFUND_PROVIDER_PAYMENT_ID_MISMATCH');
  end if;
  if v_manual_refund.id is not null and not exists(
    select 1 from public.srk_manual_payment_entries mp
     where mp.id=v_manual_refund.payment_entry_id
       and mp.booking_id=p_booking_id
       and round(mp.amount,2)=round(v_manual_refund.amount,2)
  ) then
    v_exceptions := array_append(v_exceptions,'MANUAL_REFUND_PAYMENT_EVIDENCE_MISMATCH');
  end if;
  if v_refund_paise>0 and v_refund_paise<v_collection_paise then
    v_exceptions := array_append(v_exceptions,'PARTIAL_REFUND_UNSUPPORTED');
  elsif v_refund_paise>v_collection_paise then
    v_exceptions := array_append(v_exceptions,'REFUND_EXCEEDS_VERIFIED_COLLECTION');
  end if;
  if v_refund_state in ('requested','processing','unknown') then
    v_exceptions := array_append(v_exceptions,'REFUND_PENDING_REVIEW');
  elsif v_refund_state='failed' then
    v_exceptions := array_append(v_exceptions,'REFUND_FAILED_REQUIRES_REVIEW');
  end if;
  if v_booking.payment_status='refunded' and v_refund_state not in ('processed','manual_recorded') then
    v_exceptions := array_append(v_exceptions,'REFUNDED_BOOKING_WITHOUT_FINAL_REFUND_EVIDENCE');
  elsif v_refund_state in ('processed','manual_recorded') and v_booking.payment_status<>'refunded' then
    v_exceptions := array_append(v_exceptions,'FINAL_REFUND_EVIDENCE_BOOKING_NOT_REFUNDED');
  end if;
  if v_refund_state in ('processed','manual_recorded') and v_payout.id is not null
     and v_payout.payout_status<>'refunded' then
    v_exceptions := array_append(v_exceptions,'FINAL_REFUND_PAYOUT_NOT_CLOSED');
  end if;

  select coalesce(sum(i.amount_paise) filter(where i.status in ('reserved','settled','reversed')),0)::bigint,
         coalesce(sum(i.amount_paise) filter(where i.status='settled'),0)::bigint,
         coalesce(sum(i.amount_paise) filter(where i.status in ('settled','reversed')),0)::bigint
    into v_fee_allocated_paise,v_fee_settled_paise,v_fee_captured_paise
    from public.srk_booking_cancellation_fee_items i
   where i.booking_id=p_booking_id;

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
  if v_fee_ledger_net_paise<>v_fee_settled_paise then
    v_exceptions := array_append(v_exceptions,'CANCELLATION_FEE_LEDGER_UNBALANCED');
  end if;
  if v_booking.selected_category is not null and v_payment_verified
     and v_collection_paise is distinct from (v_labour_paise+v_fee_captured_paise) then
    v_exceptions := array_append(v_exceptions,'VERIFIED_COLLECTION_DOES_NOT_MATCH_LABOUR_AND_SETTLED_FEES');
  elsif v_booking.selected_category is null and v_payment_verified
     and v_booking.quote_status='approved'
     and v_collection_paise is distinct from (v_labour_paise+v_materials_paise) then
    v_exceptions := array_append(v_exceptions,'VERIFIED_COLLECTION_DOES_NOT_MATCH_APPROVED_QUOTE');
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
        union
        select i.debt_id::text from public.srk_booking_cancellation_fee_items i
         where i.booking_id=p_booking_id
      )
    );

  -- For a manual full refund, prove the exact cash cancellation-fee wallet debit
  -- was credited back. Scope credits by the refund evidence ID so a later reuse of
  -- the same debt on another booking cannot contaminate this booking's comparison.
  if v_manual_refund.id is not null then
    select coalesce(sum(round(w.amount*100)::bigint),0)::bigint
      into v_cash_fee_expected_wallet_credit_paise
      from public.srk_booking_cancellation_fee_items i
      join public.srk_cancellation_fee_ledger l
        on l.debt_id=i.debt_id and l.booking_id=i.booking_id
       and l.entry_type='cash_electrician_debit' and l.direction='credit'
       and l.status='posted'
      join public.srk_wallet_ledger w
        on w.reference_type='cancellation_fee_item' and w.reference_id=i.id::text
       and w.wallet_type='electrician' and w.entry_type='cancellation_fee'
       and w.direction='debit' and w.status='posted'
       and w.user_id=l.electrician_user_id
       and round(w.amount*100)::bigint=i.amount_paise
     where i.booking_id=p_booking_id and i.status='reversed';

    select coalesce(sum(round(w.amount*100)::bigint),0)::bigint
      into v_cash_fee_actual_wallet_credit_paise
      from public.srk_booking_cancellation_fee_items i
      join public.srk_cancellation_fee_ledger l
        on l.debt_id=i.debt_id and l.booking_id=i.booking_id
       and l.entry_type='cash_electrician_debit' and l.direction='credit'
       and l.status='posted'
      join public.srk_wallet_ledger w
        on w.reference_type='cancellation_fee_refund' and w.reference_id=i.debt_id::text
       and w.wallet_type='electrician' and w.entry_type='cancellation_fee'
       and w.direction='credit' and w.status='posted'
       and w.user_id=l.electrician_user_id
       and w.provider_reference=v_manual_refund.id::text
       and round(w.amount*100)::bigint=i.amount_paise
     where i.booking_id=p_booking_id and i.status='reversed';

    if v_cash_fee_expected_wallet_credit_paise<>v_cash_fee_actual_wallet_credit_paise then
      v_exceptions:=array_append(v_exceptions,'CASH_FEE_WALLET_REFUND_MISMATCH');
    end if;
  end if;

  select
    coalesce(sum(t.amount_paise) filter(where t.recipient_type='electrician'),0)::bigint,
    coalesce(sum(t.amount_paise) filter(where t.recipient_type='platform_commission'),0)::bigint,
    coalesce(sum(t.amount_paise) filter(where t.recipient_type='electrician' and t.transfer_status='processed'),0)::bigint,
    coalesce(sum(t.amount_paise) filter(where t.recipient_type='electrician' and t.settlement_status='settled'),0)::bigint,
    coalesce(sum(t.amount_paise) filter(where t.recipient_type='platform_commission' and t.transfer_status='processed'),0)::bigint,
    coalesce(sum(t.amount_paise) filter(where t.recipient_type='platform_commission' and t.settlement_status='settled'),0)::bigint,
    count(*) filter(where t.recipient_type='electrician')::integer,
    count(*) filter(where t.recipient_type='platform_commission')::integer,
    coalesce(jsonb_agg(jsonb_build_object(
      'recipient_type',t.recipient_type,'recipient_user_id',t.recipient_user_id,
      'amount_paise',t.amount_paise,'transfer_status',t.transfer_status,
      'settlement_status',t.settlement_status,'transfer_id',t.transfer_id,
      'provider_payment_id',t.razorpay_payment_id,'updated_at',t.updated_at
    ) order by t.created_at,t.id),'[]'::jsonb)
  into v_route_electrician_paise,v_route_platform_paise,
       v_route_electrician_processed_paise,v_route_electrician_settled_paise,
       v_route_platform_processed_paise,v_route_platform_settled_paise,
       v_route_electrician_count,v_route_platform_count,v_route
  from public.srk_route_transfers t
  where t.booking_id=p_booking_id;

  if v_route_electrician_count>1 or v_route_platform_count>1 then
    v_exceptions := array_append(v_exceptions,'ROUTE_TRANSFER_DUPLICATE');
  end if;
  if exists(select 1 from public.srk_route_transfers t
    where t.booking_id=p_booking_id
      and (t.transfer_status='partially_reversed'
        or (t.transfer_status='reversed' or t.settlement_status='reversed')
           and v_refund_state not in ('processed','manual_recorded'))) then
    v_exceptions := array_append(v_exceptions,'ROUTE_TRANSFER_REVERSED_OR_PARTIALLY_REVERSED');
  end if;
  if v_refund_state='processed' and exists(
    select 1 from public.srk_route_transfers t
     where t.booking_id=p_booking_id and t.transfer_id is not null
       and (t.transfer_status<>'reversed' or t.settlement_status<>'reversed')
  ) then
    v_exceptions := array_append(v_exceptions,'ROUTE_TRANSFER_NOT_REVERSED_AFTER_FULL_REFUND');
  end if;
  if exists(select 1 from public.srk_route_transfers t
    where t.booking_id=p_booking_id
      and t.razorpay_payment_id is distinct from v_booking.razorpay_payment_id) then
    v_exceptions := array_append(v_exceptions,'ROUTE_PAYMENT_ID_MISMATCH');
  end if;
  if exists(select 1 from public.srk_route_transfers t
    where t.booking_id=p_booking_id and t.recipient_type='electrician'
      and t.recipient_user_id is distinct from v_expected_electrician_user_id) then
    v_exceptions := array_append(v_exceptions,'ROUTE_ELECTRICIAN_RECIPIENT_MISMATCH');
  end if;
  if v_route_electrician_paise=0 and coalesce(v_payable_paise,0)>0
     and v_booking.razorpay_payment_id is not null then
    v_exceptions := array_append(v_exceptions,'ELECTRICIAN_TRANSFER_NOT_CREATED');
  elsif v_route_electrician_paise>0 and v_route_electrician_paise is distinct from v_payable_paise then
    v_exceptions := array_append(v_exceptions,'ELECTRICIAN_ROUTE_TRANSFER_MISMATCH');
  end if;
  if v_route_platform_paise>0 and v_route_platform_paise is distinct from v_commission_paise then
    v_exceptions := array_append(v_exceptions,'PLATFORM_ROUTE_TRANSFER_MISMATCH');
  end if;
  if v_route_platform_paise=0 and coalesce(v_commission_paise,0)>0 and v_booking.razorpay_payment_id is not null then
    v_exceptions := array_append(v_exceptions,'COMMISSION_NOT_TRANSFERRED');
  elsif v_route_platform_paise>0 and v_route_platform_processed_paise<v_route_platform_paise then
    v_exceptions := array_append(v_exceptions,'COMMISSION_TRANSFER_NOT_PROCESSED');
  elsif v_route_platform_paise>0 and v_commission_paise is not null and v_route_platform_settled_paise<v_commission_paise then
    v_exceptions := array_append(v_exceptions,'COMMISSION_TRANSFER_NOT_SETTLED');
  end if;
  if v_route_electrician_paise>0 and v_route_electrician_processed_paise<v_route_electrician_paise then
    v_exceptions := array_append(v_exceptions,'ELECTRICIAN_TRANSFER_NOT_PROCESSED');
  elsif v_route_electrician_paise>0 and v_payable_paise is not null and v_route_electrician_settled_paise<v_payable_paise then
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
        union
        select i.debt_id::text from public.srk_booking_cancellation_fee_items i
         where i.booking_id=p_booking_id
      )
    );

  select r.status into v_refund_request_status
    from public.srk_booking_refund_requests r
   where r.booking_id=p_booking_id;
  if v_refund_request_status in ('requested','in_review','approved','processing','unknown') then
    v_exceptions := array_append(v_exceptions,'REFUND_REQUEST_PENDING_REVIEW');
  elsif v_refund_request_status='processed'
     and v_refund_state not in ('processed','manual_recorded') then
    v_exceptions := array_append(v_exceptions,'REFUND_REQUEST_PROCESSED_WITHOUT_FINAL_REFUND_EVIDENCE');
  end if;

  return jsonb_build_object(
    'booking_id',v_booking.id,
    'booking_status',v_booking.status,
    'payment_status',v_booking.payment_status,
    'payment_verified',v_payment_verified,
    'payment_method',v_booking.payment_method,
    'razorpay_payment_id',v_booking.razorpay_payment_id,
    'customer_collection_paise',v_collection_paise,
    'refund_paise',v_refund_paise,
    'refund_requested_or_unconfirmed_paise',v_refund_requested_paise,
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
    'cancellation_fee_historically_captured_paise',v_fee_captured_paise,
    'cancellation_fee_source_open_or_reserved_paise',v_fee_source_open_paise,
    'cancellation_fee_ledger_net_paise',v_fee_ledger_net_paise,
    'cancellation_fee_ledger_entries',v_fee_ledger,
    'wallet_posted_credit_paise',v_wallet_credit_paise,
    'wallet_posted_debit_paise',v_wallet_debit_paise,
    'cash_fee_expected_wallet_refund_credit_paise',v_cash_fee_expected_wallet_credit_paise,
    'cash_fee_actual_wallet_refund_credit_paise',v_cash_fee_actual_wallet_credit_paise,
    'wallet_posted_entries',v_wallet,
    'exceptions',to_jsonb(v_exceptions),
    'is_reconciled',cardinality(v_exceptions)=0,
    'report_generated_at',now()
  );
end;
$function$;

revoke all on function public.srk_admin_get_booking_accounting_reconciliation(uuid)
  from public,anon;
grant execute on function public.srk_admin_get_booking_accounting_reconciliation(uuid)
  to authenticated;

comment on function public.srk_admin_get_booking_accounting_reconciliation(uuid) is
  'Read-only Main Admin per-booking financial reconciliation. Never posts, transfers, or marks payouts paid.';
