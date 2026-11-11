-- SRK ELECTRONIC: integrate timer payable snapshots with the existing 15% labour-only commission ledger.
-- Forward-only release migration. Does not move money or enable Razorpay Route transfers.

begin;

alter table public.srk_electrician_payouts
  add column if not exists settlement_mode text,
  add column if not exists commission_collection_status text not null default 'not_applicable',
  add column if not exists commission_remittance_reference text,
  add column if not exists commission_remittance_submitted_at timestamptz,
  add column if not exists commission_remittance_confirmed_at timestamptz,
  add column if not exists commission_remittance_confirmed_by uuid references auth.users(id);

alter table public.srk_electrician_payouts
  drop constraint if exists srk_electrician_payouts_settlement_mode_check,
  add constraint srk_electrician_payouts_settlement_mode_check
    check (settlement_mode is null or settlement_mode in ('legacy','cash','online')),
  drop constraint if exists srk_electrician_payouts_commission_collection_status_check,
  add constraint srk_electrician_payouts_commission_collection_status_check
    check (commission_collection_status in ('not_applicable','due','submitted','received'));

alter table public.srk_electrician_payouts
  drop constraint if exists srk_electrician_payouts_commission_remittance_shape_check,
  add constraint srk_electrician_payouts_commission_remittance_shape_check
    check (
      (commission_collection_status in ('not_applicable','due')
        and commission_remittance_submitted_at is null
        and commission_remittance_confirmed_at is null
        and commission_remittance_confirmed_by is null)
      or
      (commission_collection_status = 'submitted'
        and commission_remittance_reference is not null
        and length(btrim(commission_remittance_reference)) >= 4
        and commission_remittance_submitted_at is not null
        and commission_remittance_confirmed_at is null
        and commission_remittance_confirmed_by is null)
      or
      (commission_collection_status = 'received'
        and commission_remittance_reference is not null
        and length(btrim(commission_remittance_reference)) >= 4
        and commission_remittance_submitted_at is not null
        and commission_remittance_confirmed_at is not null
        and commission_remittance_confirmed_by is not null)
    );

create index if not exists srk_payouts_cash_commission_due_idx
  on public.srk_electrician_payouts(commission_collection_status, created_at desc)
  where settlement_mode = 'cash';

-- Timer bookings use the immutable final-bill snapshot as the source of truth.
-- Never calculate platform commission from materials or a client-submitted amount.
create or replace function public.srk_calculate_booking_commission()
returns trigger
language plpgsql
set search_path = ''
as $function$
declare
  v_labour numeric;
begin
  if new.amount_paid is not null and new.amount_paid < 0 then
    raise exception 'amount_paid cannot be negative';
  end if;

  if new.service_category_code is not null then
    new.commission_rate := 15.00;
    select ps.labour_amount into v_labour
    from public.srk_booking_payable_snapshots ps
    where ps.booking_id = new.id
    order by ps.created_at desc
    limit 1;
    if new.status = 'completed' and new.payment_status = 'paid'
       and new.amount_paid is not null and v_labour is not null then
      new.commission_amount := round(v_labour * 15.00 / 100, 2);
    else
      new.commission_amount := null;
    end if;
    return new;
  end if;

  if new.commission_rate is null or new.commission_rate < 0 or new.commission_rate > 100 then
    raise exception 'commission_rate must be between 0 and 100';
  end if;
  if new.service_charge is not null and new.service_charge < 0 then
    raise exception 'service_charge cannot be negative';
  end if;

  if new.status = 'completed' and new.payment_status = 'paid'
     and new.amount_paid is not null and new.service_charge is not null then
    new.commission_amount := round(new.service_charge * new.commission_rate / 100, 2);
  else
    new.commission_amount := null;
  end if;
  return new;
end
$function$;

create or replace function public.srk_create_electrician_payable()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_snapshot public.srk_booking_payable_snapshots%rowtype;
  v_service numeric(12,2);
  v_materials numeric(12,2);
  v_total numeric(12,2);
  v_rate numeric(7,2);
  v_commission numeric(12,2);
  v_cash boolean := false;
  v_online boolean := false;
begin
  if new.payment_status = 'refunded' then
    update public.srk_electrician_payouts
    set payout_status = 'refunded',
        commission_collection_status = 'not_applicable',
        commission_remittance_reference = null,
        commission_remittance_submitted_at = null,
        commission_remittance_confirmed_at = null,
        commission_remittance_confirmed_by = null,
        updated_at = now()
    where booking_id = new.id
      and payout_status in ('pending','blocked')
      and commission_collection_status <> 'received';
    return new;
  end if;

  if new.payment_status <> 'paid' or new.status <> 'completed'
     or new.assigned_electrician_id is null or new.payment_verified_at is null then
    return new;
  end if;

  select ps.* into v_snapshot
  from public.srk_booking_payable_snapshots ps
  where ps.booking_id = new.id
  order by ps.created_at desc
  limit 1;

  if found then
    if round(coalesce(new.amount_paid,0),2) <> v_snapshot.total_amount then
      raise exception 'Timer snapshot payment amount mismatch; commission ledger not created';
    end if;

    select exists (
      select 1 from public.srk_cash_receipts cr
      where cr.booking_id = new.id
        and cr.payable_snapshot_id = v_snapshot.id
        and cr.amount_paise = v_snapshot.amount_paise
        and cr.currency = v_snapshot.currency
    ) into v_cash;

    select exists (
      select 1 from public.srk_razorpay_payments rp
      where rp.booking_id = new.id
        and rp.snapshot_id = v_snapshot.id
        and rp.amount_paise = v_snapshot.amount_paise
        and rp.currency = v_snapshot.currency
    ) into v_online;

    if v_cash = v_online then
      raise exception 'Exactly one matching Cash receipt or Razorpay capture is required';
    end if;

    v_service := round(v_snapshot.labour_amount,2);
    v_materials := v_snapshot.materials_amount;
    v_total := v_snapshot.total_amount;
    v_rate := 15.00;
    v_commission := round(v_snapshot.labour_amount * 15.00 / 100,2);

    insert into public.srk_electrician_payouts (
      booking_id,electrician_profile_id,razorpay_payment_id,
      gross_service_amount,materials_amount,platform_commission,
      electrician_payable,payout_status,settlement_mode,commission_collection_status
    ) values (
      new.id,new.assigned_electrician_id,
      case when v_online then new.razorpay_payment_id else null end,
      v_service,v_materials,v_commission,
      case when v_cash then 0 else round(v_total-v_commission,2) end,
      case when v_cash then 'blocked' else 'pending' end,
      case when v_cash then 'cash' else 'online' end,
      case when v_cash then 'due' else 'not_applicable' end
    )
    on conflict (booking_id) do update set
      electrician_profile_id = excluded.electrician_profile_id,
      razorpay_payment_id = excluded.razorpay_payment_id,
      gross_service_amount = excluded.gross_service_amount,
      materials_amount = excluded.materials_amount,
      platform_commission = excluded.platform_commission,
      electrician_payable = excluded.electrician_payable,
      payout_status = excluded.payout_status,
      settlement_mode = excluded.settlement_mode,
      commission_collection_status = excluded.commission_collection_status,
      updated_at = now()
    where public.srk_electrician_payouts.payout_status in ('pending','blocked')
      and public.srk_electrician_payouts.commission_collection_status in ('not_applicable','due');
    return new;
  end if;

  -- Preserve the established quote-based payout path for legacy bookings.
  if new.quote_status = 'approved'
     and (new.razorpay_payment_id is not null or exists (
       select 1 from public.srk_manual_payment_entries e
       where e.booking_id = new.id and e.amount = round(coalesce(new.amount_paid,0),2)
     )) then
    v_service := round(coalesce(new.service_charge,0),2);
    v_materials := round(coalesce(new.materials_amount,0),2);
    v_total := round(v_service + v_materials,2);
    v_rate := new.commission_rate;
    if v_rate is null or v_rate < 0 or v_rate > 100 then
      raise exception 'Commission rate must be between 0 and 100; payout ledger not created';
    end if;
    if round(coalesce(new.amount_paid,0),2) <> v_total then
      raise exception 'Verified payment amount does not match approved quote total; payout ledger not created';
    end if;
    v_commission := round(v_service * v_rate / 100,2);

    insert into public.srk_electrician_payouts (
      booking_id,electrician_profile_id,razorpay_payment_id,
      gross_service_amount,materials_amount,platform_commission,
      electrician_payable,payout_status,settlement_mode,commission_collection_status
    ) values (
      new.id,new.assigned_electrician_id,new.razorpay_payment_id,
      v_service,v_materials,v_commission,
      round(v_service + v_materials - v_commission,2),'pending','legacy','not_applicable'
    )
    on conflict (booking_id) do update set
      electrician_profile_id = excluded.electrician_profile_id,
      razorpay_payment_id = excluded.razorpay_payment_id,
      gross_service_amount = excluded.gross_service_amount,
      materials_amount = excluded.materials_amount,
      platform_commission = excluded.platform_commission,
      electrician_payable = excluded.electrician_payable,
      updated_at = now()
    where public.srk_electrician_payouts.payout_status = 'pending';
  end if;

  return new;
end
$function$;

-- Ensure the established booking triggers invoke the snapshot-aware commission functions.
drop trigger if exists srk_calculate_booking_commission on public.service_bookings;
create trigger srk_calculate_booking_commission
before insert or update of status,payment_status,amount_paid,commission_rate
on public.service_bookings
for each row execute function public.srk_calculate_booking_commission();

drop trigger if exists trg_srk_create_electrician_payable on public.service_bookings;
create trigger trg_srk_create_electrician_payable
after insert or update of payment_status,status,quote_status,service_charge,materials_amount,
  assigned_electrician_id,payment_verified_at,razorpay_payment_id,amount_paid
on public.service_bookings
for each row execute function public.srk_create_electrician_payable();

-- Electrician submits a traceable remittance reference for Cash commission.
create or replace function public.srk_electrician_submit_cash_commission_remittance(
  p_booking_id uuid,
  p_reference text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_uid uuid := auth.uid();
  v_payout public.srk_electrician_payouts%rowtype;
begin
  if v_uid is null then raise exception 'AUTHENTICATION_REQUIRED' using errcode='28000'; end if;
  if p_booking_id is null or p_reference is null
     or length(btrim(p_reference)) < 4 or length(btrim(p_reference)) > 120 then
    raise exception 'VALID_BOOKING_AND_REMITTANCE_REFERENCE_REQUIRED' using errcode='22023';
  end if;

  update public.srk_electrician_payouts p
  set commission_collection_status = 'submitted',
      commission_remittance_reference = btrim(p_reference),
      commission_remittance_submitted_at = clock_timestamp(),
      updated_at = clock_timestamp()
  where p.booking_id = p_booking_id
    and p.settlement_mode = 'cash'
    and p.commission_collection_status = 'due'
    and exists (
      select 1 from public.electrician_profiles ep
      where ep.id = p.electrician_profile_id
        and (ep.user_id = v_uid or ep.auth_user_id = v_uid)
        and ep.active = true and ep.verification_status = 'approved'
    )
  returning p.* into v_payout;

  if not found then raise exception 'CASH_COMMISSION_REMITTANCE_NOT_AVAILABLE' using errcode='55000'; end if;

  return jsonb_build_object(
    'success',true,'booking_id',v_payout.booking_id,
    'commission_amount',v_payout.platform_commission,
    'status',v_payout.commission_collection_status,
    'reference',v_payout.commission_remittance_reference,
    'submitted_at',v_payout.commission_remittance_submitted_at
  );
end
$function$;

create or replace function public.srk_admin_confirm_cash_commission_remittance(
  p_booking_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_uid uuid := auth.uid();
  v_payout public.srk_electrician_payouts%rowtype;
begin
  if v_uid is null or not public.is_srk_admin() then
    raise exception 'ADMIN_ACCESS_REQUIRED' using errcode='42501';
  end if;

  update public.srk_electrician_payouts p
  set commission_collection_status = 'received',
      commission_remittance_confirmed_at = clock_timestamp(),
      commission_remittance_confirmed_by = v_uid,
      updated_at = clock_timestamp()
  where p.booking_id = p_booking_id
    and p.settlement_mode = 'cash'
    and p.commission_collection_status = 'submitted'
  returning p.* into v_payout;

  if not found then raise exception 'CASH_COMMISSION_SUBMISSION_NOT_FOUND' using errcode='55000'; end if;

  return jsonb_build_object(
    'success',true,'booking_id',v_payout.booking_id,
    'commission_amount',v_payout.platform_commission,
    'status',v_payout.commission_collection_status,
    'confirmed_at',v_payout.commission_remittance_confirmed_at
  );
end
$function$;

revoke all on function public.srk_electrician_submit_cash_commission_remittance(uuid,text) from public,anon;
revoke all on function public.srk_admin_confirm_cash_commission_remittance(uuid) from public,anon;
grant execute on function public.srk_electrician_submit_cash_commission_remittance(uuid,text) to authenticated;
grant execute on function public.srk_admin_confirm_cash_commission_remittance(uuid) to authenticated;

-- Preserve existing report keys and add explicit Cash remittance + Online payout totals.
create or replace function public.srk_admin_commission_report()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_result jsonb;
begin
  if auth.uid() is null or not public.is_srk_admin() then
    raise exception 'Admin access required' using errcode = '42501';
  end if;

  with paid_completed as (
    select assigned_electrician_id,
           coalesce(amount_paid,0)::numeric as gross,
           coalesce(commission_amount,0)::numeric as commission
    from public.service_bookings
    where status = 'completed' and payment_status = 'paid'
  ),
  totals as (
    select coalesce(sum(gross),0)::numeric as collected,
           coalesce(sum(commission),0)::numeric as commission,
           coalesce(sum(gross-commission),0)::numeric as payable
    from paid_completed
  ),
  partners as (
    select p.id as electrician_id,
           p.display_name,
           count(pc.*)::integer as paid_completed_jobs,
           coalesce(sum(pc.gross),0)::numeric as gross_received,
           coalesce(sum(pc.commission),0)::numeric as company_commission,
           coalesce(sum(pc.gross-pc.commission),0)::numeric as electrician_earning
    from public.electrician_profiles p
    left join paid_completed pc on pc.assigned_electrician_id = p.id
    group by p.id,p.display_name
    order by p.display_name
  ),
  cash_status as (
    select
      coalesce(sum(platform_commission) filter (where commission_collection_status='due'),0) as cash_commission_due,
      coalesce(sum(platform_commission) filter (where commission_collection_status='submitted'),0) as cash_commission_submitted,
      coalesce(sum(platform_commission) filter (where commission_collection_status='received'),0) as cash_commission_received
    from public.srk_electrician_payouts
    where settlement_mode='cash'
  ),
  online_status as (
    select
      coalesce(sum(electrician_payable) filter (where payout_status='pending'),0) as online_electrician_payout_pending,
      count(*) filter (where payout_status='pending')::integer as online_payout_count
    from public.srk_electrician_payouts
    where settlement_mode='online'
  )
  select jsonb_build_object(
    'total_collected',t.collected,
    'total_commission',t.commission,
    'total_electrician_payable',t.payable,
    'cash_commission_due',cs.cash_commission_due,
    'cash_commission_submitted',cs.cash_commission_submitted,
    'cash_commission_received',cs.cash_commission_received,
    'online_electrician_payout_pending',os.online_electrician_payout_pending,
    'online_payout_count',os.online_payout_count,
    'partners',coalesce((select jsonb_agg(to_jsonb(partners)) from partners),'[]'::jsonb)
  ) into v_result
  from totals t cross join cash_status cs cross join online_status os;

  return v_result;
end;
$function$;

revoke all on function public.srk_admin_commission_report() from public,anon;
grant execute on function public.srk_admin_commission_report() to authenticated;

commit;
