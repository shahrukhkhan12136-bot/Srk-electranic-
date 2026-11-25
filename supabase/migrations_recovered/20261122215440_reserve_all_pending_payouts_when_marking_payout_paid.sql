
create or replace function public.srk_admin_mark_worker_payout_paid(
  p_payout_id uuid,
  p_payment_method text,
  p_payment_reference text,
  p_note text default null
)
returns public.srk_worker_payout_requests
language plpgsql
security definer
set search_path = pg_catalog, public, auth
as $function$
declare
  v_payout public.srk_worker_payout_requests%rowtype;
  v_available numeric(12,2);
  v_reserved numeric(12,2);
begin
  if not public.srk_has_admin_permission('payouts.manage') then
    raise exception 'Payout management permission required';
  end if;
  if nullif(btrim(p_payment_reference),'') is null then
    raise exception 'UTR/transaction reference required';
  end if;
  if p_payment_method not in ('upi','bank_transfer','phonepe','other') then
    raise exception 'Invalid payout method';
  end if;

  select * into v_payout
  from public.srk_worker_payout_requests
  where id=p_payout_id
  for update;

  if not found or v_payout.status<>'approved' then
    raise exception 'Only approved payout can be marked paid';
  end if;

  perform 1 from public.srk_worker_profiles
  where id=v_payout.worker_id
  for update;

  if exists (
    select 1 from public.srk_worker_earnings
    where worker_id=v_payout.worker_id
      and settlement_status='held'
  ) then
    raise exception 'Worker payout is held due to refund/dispute review';
  end if;

  select coalesce(sum(balance_effect),0)
  into v_available
  from public.srk_worker_wallet_ledger
  where worker_id=v_payout.worker_id;

  select coalesce(sum(coalesce(approved_amount,requested_amount)),0)
  into v_reserved
  from public.srk_worker_payout_requests
  where worker_id=v_payout.worker_id
    and id<>p_payout_id
    and status in ('requested','under_review','approved');

  if v_payout.approved_amount>v_available-v_reserved then
    raise exception 'Wallet balance changed; payout cannot be paid';
  end if;

  insert into public.srk_worker_wallet_ledger(
    worker_id,entry_type,amount,balance_effect,description,reference_id,idempotency_key
  )
  values(
    v_payout.worker_id,'payout_paid',v_payout.approved_amount,-v_payout.approved_amount,
    'Admin verified payout',p_payment_reference,'payout-paid:'||v_payout.id::text
  )
  on conflict(idempotency_key) do nothing;

  update public.srk_worker_payout_requests
  set status='paid',payment_method=p_payment_method,
      payment_reference=p_payment_reference,
      admin_note=coalesce(p_note,admin_note),
      paid_at=clock_timestamp()
  where id=p_payout_id
  returning * into v_payout;

  return v_payout;
end
$function$;
