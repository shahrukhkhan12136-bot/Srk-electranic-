-- Follow-up correction for booking accounting consistency.
-- This is additive and intentionally does not rewrite historical migrations.
-- Commission is assigned in a BEFORE trigger; payout ledger remains in its existing AFTER trigger.
-- A later AFTER trigger validates that both persisted amounts agree.

create or replace function public.srk_set_booking_commission_before_payout()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public, pg_temp
as $$
declare
  v_service numeric(12,2);
  v_rate numeric(7,2);
  v_commission numeric(12,2);
  v_bill public.srk_booking_labour_bills%rowtype;
begin
  if new.payment_status <> 'paid'
     or new.status <> 'completed'
     or new.assigned_electrician_id is null
     or new.payment_verified_at is null
     or not (
       new.razorpay_payment_id is not null
       or exists (
         select 1
           from public.srk_manual_payment_entries e
          where e.booking_id = new.id
            and round(coalesce(e.amount,0),2) = round(coalesce(new.amount_paid,0),2)
            and lower(btrim(coalesce(e.payment_method,''))) =
                lower(btrim(coalesce(new.payment_method,'')))
       )
     ) then
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
    if new.quote_status <> 'approved' then
      return new;
    end if;
    v_service := round(coalesce(new.service_charge,0),2);
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
  quote_status,
  service_charge,
  commission_rate,
  razorpay_payment_id,
  selected_category,
  payment_method
on public.service_bookings
for each row
execute function public.srk_set_booking_commission_before_payout();

-- The payout AFTER trigger is alphabetically earlier (srk_reconcile_...).
-- This validation runs after that ledger write in the same transaction.
create or replace function public.srk_validate_booking_commission_payout_parity()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public, pg_temp
as $$
declare
  v_platform_commission numeric(12,2);
begin
  if new.payment_status <> 'paid'
     or new.status <> 'completed'
     or new.assigned_electrician_id is null
     or new.payment_verified_at is null
     or (new.selected_category is null and new.quote_status <> 'approved') then
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
  quote_status,
  service_charge,
  commission_rate,
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
           and lower(btrim(coalesce(mp.payment_method,''))) =
               lower(btrim(coalesce(v_booking.payment_method,'')))
      )
    );

  if v_booking.payment_status in ('paid','refunded')
     and v_booking.razorpay_payment_id is null
     and exists (
       select 1 from public.srk_manual_payment_entries mp
        where mp.booking_id=p_booking_id
          and round(mp.amount,2)=round(v_booking.amount_paid,2)
          and lower(btrim(coalesce(mp.payment_method,''))) <>
              lower(btrim(coalesce(v_booking.payment_method,'')))
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
    if round(coalesce(v_booking.commission_amount,0)*100)::bigint
       is distinct from round(coalesce(v_payout.platform_commission,0)*100)::bigint then
      v_exceptions := array_append(v_exceptions,'BOOKING_COMMISSION_PAYOUT_LEDGER_MISMATCH');
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
  if v_refund_paise>0 and v_refund_paise<>v_collection_paise then
    v_exceptions := array_append(v_exceptions,'REFUND_AMOUNT_DIFFERS_FROM_VERIFIED_COLLECTION');
  end if;

  select coalesce(sum(i.amount_paise) filter (where i.status='reserved'),0)::bigint,
         coalesce(sum(i.amount_paise) filter (where i.status='settled'),0)::bigint
    into v_fee_source_open_paise,v_fee_settled_paise
    from public.srk_booking_cancellation_fee_items i
   where i.booking_id=p_booking_id;
  v_fee_allocated_paise := v_fee_source_open_paise + v_fee_settled_paise;

  select coalesce(sum(e.amount_paise) filter (where e.entry_status='posted' and e.direction='credit'),0)::bigint,
         coalesce(sum(e.amount_paise) filter (where e.entry_status='posted' and e.direction='debit'),0)::bigint
    into v_wallet_credit_paise,v_wallet_debit_paise
    from public.srk_wallet_ledger e
   where e.booking_id=p_booking_id;

  select coalesce(sum(e.amount_paise) filter (where e.entry_status='posted'),0)::bigint
    into v_fee_ledger_net_paise
    from public.srk_cancellation_fee_ledger e
   where e.booking_id=p_booking_id;

  select coalesce(sum(e.amount_paise) filter (where e.entry_status='posted' and e.direction='credit'),0)::bigint
    into v_fee_captured_paise
    from public.srk_cancellation_fee_ledger e
   where e.booking_id=p_booking_id;

  select coalesce(sum(e.amount_paise) filter (where e.entry_status='posted' and e.direction='credit'),0)::bigint
    into v_cash_fee_actual_wallet_credit_paise
    from public.srk_wallet_ledger e
   where e.booking_id=p_booking_id
     and e.idempotency_key like 'cancel-fee:cash:customer-refund:%';

  v_cash_fee_expected_wallet_credit_paise := greatest(v_fee_captured_paise-v_fee_ledger_net_paise,0);

  if v_cash_fee_actual_wallet_credit_paise<>v_cash_fee_expected_wallet_credit_paise then
    v_exceptions := array_append(v_exceptions,'CASH_CANCELLATION_FEE_WALLET_REFUND_MISMATCH');
  end if;

  select jsonb_agg(jsonb_build_object(
    'id',e.id,'entry_type',e.entry_type,'direction',e.direction,
    'amount_paise',e.amount_paise,'entry_status',e.entry_status,
    'idempotency_key',e.idempotency_key,'created_at',e.created_at
  ) order by e.created_at,e.id)
    into v_fee_ledger
    from public.srk_cancellation_fee_ledger e
   where e.booking_id=p_booking_id;

  select jsonb_agg(jsonb_build_object(
    'id',e.id,'entry_type',e.entry_type,'direction',e.direction,
    'amount_paise',e.amount_paise,'entry_status',e.entry_status,
    'idempotency_key',e.idempotency_key,'created_at',e.created_at
  ) order by e.created_at,e.id)
    into v_wallet
    from public.srk_wallet_ledger e
   where e.booking_id=p_booking_id;

  select rr.status into v_refund_request_status
    from public.srk_booking_refund_requests rr
   where rr.booking_id=p_booking_id;
  if v_refund_request_status='approved'
     and v_refund_state not in ('processed','manual_recorded') then
    v_exceptions := array_append(v_exceptions,'APPROVED_REFUND_REQUEST_PENDING_REVIEW');
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
