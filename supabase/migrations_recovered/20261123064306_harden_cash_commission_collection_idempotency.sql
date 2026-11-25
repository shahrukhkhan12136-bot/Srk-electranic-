
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
set search_path = pg_catalog, public, auth, pg_temp
as $function$
declare
  v_available_due numeric(12,2);
  v_row public.srk_worker_wallet_ledger%rowtype;
  v_key text;
  v_description text;
begin
  if auth.uid() is null or not public.srk_has_admin_permission('payouts.manage') then
    raise exception 'Payout management permission required' using errcode='42501';
  end if;
  if p_worker_id is null or p_amount is null or p_amount<=0
     or p_amount<>round(p_amount,2)
     or p_payment_method not in ('upi','bank_transfer','phonepe','cash','other')
     or nullif(btrim(p_payment_reference),'') is null
     or p_note is null or length(btrim(p_note)) not between 10 and 2000 then
    raise exception 'Valid worker, positive two-decimal amount, method, reference and note are required'
      using errcode='22023';
  end if;

  perform 1 from public.srk_worker_profiles where id=p_worker_id for update;
  if not found then raise exception 'Worker profile not found'; end if;

  v_key := 'cash-commission-collected:'||p_worker_id::text||':'||btrim(p_payment_reference);
  v_description := 'Cash commission collected by Admin via '||p_payment_method||'. '||btrim(p_note);

  -- Safe retry: return the original collection only when its amount and reference match.
  select * into v_row
  from public.srk_worker_wallet_ledger
  where idempotency_key=v_key;
  if found then
    if v_row.amount<>p_amount or v_row.reference_id<>btrim(p_payment_reference)
       or v_row.entry_type<>'cash_commission_collected' then
      raise exception 'Payment reference was already used with different collection details'
        using errcode='23505';
    end if;
    return v_row;
  end if;

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
    v_description,btrim(p_payment_reference),v_key
  )
  returning * into v_row;

  return v_row;
end
$function$;

revoke all on function public.srk_admin_record_cash_commission_collection(uuid,numeric,text,text,text) from public, anon;
grant execute on function public.srk_admin_record_cash_commission_collection(uuid,numeric,text,text,text) to authenticated;
