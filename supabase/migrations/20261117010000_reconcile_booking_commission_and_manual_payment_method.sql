-- Follow-up correction for booking accounting consistency.
-- This is additive and intentionally does not rewrite historical migrations.
-- Commission is assigned in a BEFORE trigger; payout ledger remains in its existing AFTER trigger.
-- A later AFTER trigger validates that both persisted amounts agree.

create or replace function public.srk_set_booking_commission_before_payout()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_service numeric(12,2);
  v_rate numeric(7,2);
  v_commission numeric(12,2);
  v_bill public.srk_booking_labour_bills%rowtype;
  v_legacy srk_private.legacy_booking_financial_evidence%rowtype;
begin
  if new.payment_status = 'paid'
     and new.payment_verified_at is not null
     and new.razorpay_payment_id is null
     and exists (
       select 1
         from public.srk_manual_payment_entries e
        where e.booking_id = new.id
          and round(coalesce(e.amount,0),2) = round(coalesce(new.amount_paid,0),2)
          and lower(btrim(e.payment_method)) is distinct from lower(btrim(new.payment_method))
     ) then
    raise exception 'MANUAL_PAYMENT_METHOD_MISMATCH';
  end if;

  if new.payment_status is distinct from 'paid'
     or new.status is distinct from 'completed'
     or new.assigned_electrician_id is null
     or new.payment_verified_at is null
     or not (
       new.razorpay_payment_id is not null
       or exists (
         select 1
           from public.srk_manual_payment_entries e
          where e.booking_id = new.id
            and round(coalesce(e.amount,0),2) = round(coalesce(new.amount_paid,0),2)
            and e.payment_method is not null
            and new.payment_method is not null
            and lower(btrim(e.payment_method)) = lower(btrim(new.payment_method))
       )
     ) then
    -- Match the legacy commission trigger's state-transition contract:
    -- commission is not active unless the booking is completed and verified-paid.
    new.commission_amount := null;
    return new;
  end if;

  if new.selected_category is not null then
    select * into v_bill
      from public.srk_booking_labour_bills
     where booking_id = new.id;

    if not found
       or v_bill.electrician_profile_id is distinct from new.assigned_electrician_id
       or v_bill.labour_amount <= 0 then
      raise exception 'IMMUTABLE_LABOUR_BILL_OR_ELECTRICIAN_ASSIGNMENT_MISMATCH';
    end if;
    v_service := round(v_bill.labour_amount,2);
  else
    -- Quote-era bookings are historical only; no new commission is created.
    return new;
  end if;

  v_rate := new.commission_rate;
  if v_rate is null or v_rate < 0 or v_rate > 100 then
    raise exception 'COMMISSION_RATE_MUST_BE_BETWEEN_0_AND_100';
  end if;

  v_commission := round(v_service * v_rate / 100,2);
  new.commission_amount := v_commission;
  return new;
end;
$$;

revoke all on function public.srk_set_booking_commission_before_payout() from public, anon, authenticated;

drop trigger if exists zz_srk_set_booking_commission_before_payout on public.service_bookings;
create trigger zz_srk_set_booking_commission_before_payout
before insert or update of
  status,
  payment_status,
  assigned_electrician_id,
  payment_verified_at,
  amount_paid,
  selected_category,
  commission_rate,
  razorpay_payment_id,
  selected_category,
  payment_method
on public.service_bookings
for each row
execute function public.srk_set_booking_commission_before_payout();

-- The existing payout AFTER trigger (trg_srk_create_electrician_payable) sorts before this parity trigger.
-- This validation runs after that ledger write in the same transaction.
create or replace function public.srk_validate_booking_commission_payout_parity()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_platform_commission numeric(12,2);
begin
  if new.payment_status is distinct from 'paid'
     or new.status is distinct from 'completed'
     or new.assigned_electrician_id is null
     or new.payment_verified_at is null
     or new.selected_category is null then
    return new;
  end if;

  select round(p.platform_commission,2)
    into v_platform_commission
    from public.srk_electrician_payouts p
   where p.booking_id = new.id;

  if not found then
    raise exception 'PAYOUT_ROW_MISSING_DURING_COMMISSION_PARITY_CHECK';
  end if;

  if new.commission_amount is null
     or round(new.commission_amount,2) is distinct from v_platform_commission then
    raise exception 'BOOKING_COMMISSION_AND_PAYOUT_PLATFORM_COMMISSION_MISMATCH';
  end if;

  return new;
end;
$$;

revoke all on function public.srk_validate_booking_commission_payout_parity() from public, anon, authenticated;

drop trigger if exists zz_srk_validate_booking_commission_payout_parity on public.service_bookings;
create trigger zz_srk_validate_booking_commission_payout_parity
after insert or update of
  status,
  payment_status,
  assigned_electrician_id,
  payment_verified_at,
  amount_paid,
  selected_category,
  commission_rate,
  commission_amount,
  razorpay_payment_id,
  selected_category,
  payment_method
on public.service_bookings
for each row
execute function public.srk_validate_booking_commission_payout_parity();

-- Manual payment evidence must agree with the booking's payment method as well as amount.
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
  v_fee_ledger_net_paise bigint := 0;
  v_fee_source_open_paise bigint := 0;
  v_wallet_credit_paise bigint := 0;
  v_wallet_debit_paise bigint := 0;
  v_cash_fee_expected_wallet_credit_paise bigint := 0;
  v_cash_fee_actual_wallet_credit_paise bigint := 0;
  v_exceptions text[] := array[]::text[];
  v_fee_ledger jsonb := '[]'::jsonb;
  v_wallet jsonb := '[]'::jsonb;
  v_refund_state text := 'none';
  v_payment_verified boolean := false;
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
    and coalesce(v_booking.amount_paid,0)>0
    and (
      v_booking.razorpay_payment_id is not null
      or exists (
        select 1 from public.srk_manual_payment_entries mp
         where mp.booking_id=p_booking_id
           and round(mp.amount,2)=round(v_booking.amount_paid,2)
           and mp.payment_method is not null
           and v_booking.payment_method is not null
           and lower(btrim(mp.payment_method)) = lower(btrim(v_booking.payment_method))
      )
    );
  if v_booking.payment_status in ('paid','refunded')
     and v_booking.razorpay_payment_id is null
     and exists (
       select 1 from public.srk_manual_payment_entries mp
        where mp.booking_id=p_booking_id
          and round(mp.amount,2)=round(v_booking.amount_paid,2)
          and lower(btrim(mp.payment_method)) is distinct from lower(btrim(v_booking.payment_method))
     ) then
    v_exceptions := array_append(v_exceptions,'MANUAL_PAYMENT_METHOD_MISMATCH');
  end if;
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
    SELECT * INTO v_legacy FROM srk_private.legacy_booking_financial_evidence
     WHERE booking_id=p_booking_id;
    IF FOUND THEN
      v_labour_paise:=round(coalesce(v_legacy.service_charge,0)*100)::bigint;
      v_materials_paise:=round(coalesce(v_legacy.materials_amount,0)*100)::bigint;
    ELSE
      v_exceptions:=array_append(v_exceptions,'MISSING_ARCHIVED_HISTORICAL_FINANCIAL_EVIDENCE');
    END IF;
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

  if v_payout.id is not null and (
       v_booking.commission_amount is null
       or round(v_booking.commission_amount*100)::bigint
          is distinct from round(v_payout.platform_commission*100)::bigint
     ) then
    v_exceptions := array_append(v_exceptions,'BOOKING_COMMISSION_PAYOUT_LEDGER_MISMATCH');
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
    v_exceptions := array_append(v_exceptions,'VERIFIED_COLLECTION_DOES_NOT_MATCH_ARCHIVED_HISTORICAL_EVIDENCE');
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
    'route_transfer_count', 0,
    'route_electrician_transfer_paise', 0,
    'route_platform_commission_transfer_paise', 0,
    'route_transfers', '[]'::jsonb,
    'route_provider_settlement_verified', false,
    'route_settlement_evidence_status', 'route_ledger_retired_no_route_transfers',
    'payout',case when v_payout.id is null then null else jsonb_build_object(
      'payout_id',v_payout.id,'status',v_payout.payout_status,
      'recorded_payable_paise',round(v_payout.electrician_payable*100)::bigint,
      'method',v_payout.payout_method,'reference',v_payout.payout_reference,
      'paid_at',v_payout.paid_at
    ) end,
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


-- Reporting must use the payout ledger as the authoritative electrician amount.
-- amount_paid remains customer collection and can include SRK-owned cancellation fees.
create or replace function public.srk_admin_commission_report()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_result jsonb;
begin
  if auth.uid() is null or not public.is_srk_admin() then
    raise exception 'Admin access required' using errcode = '42501';
  end if;

  with paid_completed as (
    select b.assigned_electrician_id,
           coalesce(b.amount_paid,0)::numeric as customer_collected,
           coalesce(p.gross_service_amount,0) + coalesce(p.materials_amount,0) as payout_gross,
           coalesce(p.platform_commission,0)::numeric as commission,
           coalesce(p.electrician_payable,0)::numeric as electrician_payable
    from public.service_bookings b
    left join public.srk_electrician_payouts p on p.booking_id=b.id
    where b.status='completed' and b.payment_status='paid'
  ),
  totals as (
    select coalesce(sum(customer_collected),0)::numeric as collected,
           coalesce(sum(commission),0)::numeric as commission,
           coalesce(sum(electrician_payable),0)::numeric as payable
    from paid_completed
  ),
  partners as (
    select p.id as electrician_id,
           p.display_name,
           count(pc.*)::integer as paid_completed_jobs,
           coalesce(sum(pc.payout_gross),0)::numeric as gross_received,
           coalesce(sum(pc.commission),0)::numeric as company_commission,
           coalesce(sum(pc.electrician_payable),0)::numeric as electrician_earning
    from public.electrician_profiles p
    left join paid_completed pc on pc.assigned_electrician_id=p.id
    group by p.id,p.display_name
    order by p.display_name
  )
  select jsonb_build_object(
    'total_collected',t.collected,
    'total_commission',t.commission,
    'total_electrician_payable',t.payable,
    'partners',coalesce((select jsonb_agg(to_jsonb(partners)) from partners),'[]'::jsonb)
  ) into v_result
  from totals t;

  return v_result;
end;
$$;

create or replace function public.srk_get_my_earnings()
returns table (
  booking_id uuid,
  service_type text,
  booking_created_at timestamptz,
  booking_status text,
  payment_status text,
  amount_received numeric,
  commission_amount numeric,
  electrician_earning numeric
)
language sql
stable
security definer
set search_path = ''
as $$
  select b.id, b.service_type, b.created_at, b.status, b.payment_status,
         coalesce(b.amount_paid,0),
         coalesce(p.platform_commission,0),
         case when b.status='completed' and b.payment_status='paid'
              then coalesce(p.electrician_payable,0)
              else 0 end
  from public.electrician_profiles ep
  join public.service_bookings b on b.assigned_electrician_id=ep.id
  left join public.srk_electrician_payouts p on p.booking_id=b.id
  where ep.user_id=auth.uid() and ep.verification_status='approved'
  order by b.created_at desc
  limit 200;
$$;
