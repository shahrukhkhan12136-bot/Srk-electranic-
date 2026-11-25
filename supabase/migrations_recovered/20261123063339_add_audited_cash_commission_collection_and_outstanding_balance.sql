
alter table public.srk_worker_wallet_ledger
  drop constraint if exists srk_worker_wallet_ledger_entry_type_check;
alter table public.srk_worker_wallet_ledger
  add constraint srk_worker_wallet_ledger_entry_type_check
  check (entry_type = any (array[
    'earning','commission','cash_commission_due','cash_commission_collected',
    'payout_requested','payout_paid','refund_adjustment','admin_adjustment','hold','release'
  ]::text[]));

create or replace function public.srk_admin_record_cash_commission_collection(
  p_worker_id uuid,
  p_amount numeric,
  p_payment_method text,
  p_payment_reference text,
  p_note text
)
returns public.srk_worker_wallet_ledger
language plpgsql
security definer
set search_path to 'pg_catalog','public','auth','pg_temp'
as $function$
declare
  v_available_due numeric(12,2);
  v_row public.srk_worker_wallet_ledger%rowtype;
begin
  if auth.uid() is null or not public.srk_has_admin_permission('payouts.manage') then
    raise exception 'Payout management permission required' using errcode='42501';
  end if;
  if p_worker_id is null or p_amount is null or p_amount<=0
     or p_payment_method not in ('upi','bank_transfer','phonepe','cash','other')
     or nullif(btrim(p_payment_reference),'') is null
     or p_note is null or length(btrim(p_note)) not between 10 and 2000 then
    raise exception 'Valid worker, amount, method, reference and note are required' using errcode='22023';
  end if;

  perform 1 from public.srk_worker_profiles where id=p_worker_id for update;
  if not found then raise exception 'Worker profile not found'; end if;

  select coalesce(sum(balance_effect),0)
    into v_available_due
  from public.srk_worker_wallet_ledger
  where worker_id=p_worker_id
    and entry_type in ('cash_commission_due','cash_commission_collected');

  if p_amount > -v_available_due then
    raise exception 'Collection exceeds outstanding cash commission due';
  end if;

  insert into public.srk_worker_wallet_ledger(
    worker_id,entry_type,amount,balance_effect,description,reference_id,idempotency_key
  )
  values(
    p_worker_id,'cash_commission_collected',p_amount,p_amount,
    'Cash commission collected by Admin via '||p_payment_method||'. '||btrim(p_note),
    btrim(p_payment_reference),
    'cash-commission-collected:'||p_worker_id::text||':'||btrim(p_payment_reference)
  )
  returning * into v_row;

  return v_row;
end
$function$;

revoke all on function public.srk_admin_record_cash_commission_collection(uuid,numeric,text,text,text) from public,anon;
grant execute on function public.srk_admin_record_cash_commission_collection(uuid,numeric,text,text,text) to authenticated;

do $migration$
declare
  v_definition text;
  v_old_cte text := $old$
  cash_dues as (
    select coalesce(sum(amount),0)::numeric(14,2) due
    from public.srk_worker_wallet_ledger
    where entry_type='cash_commission_due'
      and (created_at at time zone 'Asia/Kolkata')::date between v_start and v_end
  ),
$old$;
  v_new_cte text := $new$
  cash_dues as (
    select coalesce(sum(balance_effect),0)::numeric(14,2) outstanding
    from public.srk_worker_wallet_ledger
    where entry_type in ('cash_commission_due','cash_commission_collected')
  ),
  cash_dues_period as (
    select coalesce(sum(amount),0)::numeric(14,2) accrued
    from public.srk_worker_wallet_ledger
    where entry_type='cash_commission_due'
      and (created_at at time zone 'Asia/Kolkata')::date between v_start and v_end
  ),
$new$;
  v_old_json text := $old$
    'cash_commission_due',c.due
$old$;
  v_new_json text := $new$
    'cash_commission_due',greatest(0,-c.outstanding),
    'cash_commission_due_accrued_in_period',cp.accrued
$new$;
  v_old_from text := $old$
  from bookings b cross join earnings e cross join legacy_only l cross join shared_payouts s cross join cash_dues c cross join company_refunds cr;
$old$;
  v_new_from text := $new$
  from bookings b cross join earnings e cross join legacy_only l cross join shared_payouts s cross join cash_dues c cross join cash_dues_period cp cross join company_refunds cr;
$new$;
begin
  select pg_get_functiondef('public.srk_admin_finance_dashboard(text,date)'::regprocedure)
    into v_definition;
  if position(v_old_cte in v_definition)=0 or position(v_old_json in v_definition)=0
     or position(v_old_from in v_definition)=0 then
    raise exception 'Expected dashboard cash due sections not found; migration aborted';
  end if;
  v_definition:=replace(v_definition,v_old_cte,v_new_cte);
  v_definition:=replace(v_definition,v_old_json,v_new_json);
  v_definition:=replace(v_definition,v_old_from,v_new_from);
  execute v_definition;
end
$migration$;
