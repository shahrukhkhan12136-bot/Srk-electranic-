
create or replace function public.srk_admin_reconcile_razorpay_settlement(
  p_settlement_id uuid,
  p_bank_credit_amount_paise bigint,
  p_bank_credit_at timestamptz,
  p_bank_reference text,
  p_reconciliation_status text,
  p_note text
)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_row public.srk_razorpay_settlements%rowtype;
  v_actor uuid := auth.uid();
  v_verified_at timestamptz := now();
begin
  if v_actor is null or not public.srk_has_admin_permission('payouts.manage') then
    raise exception 'Not authorized to reconcile Razorpay settlements';
  end if;
  if p_settlement_id is null or p_bank_credit_amount_paise is null or p_bank_credit_amount_paise < 0 then
    raise exception 'Settlement and non-negative bank credit amount are required';
  end if;
  if p_bank_credit_at is null or length(trim(coalesce(p_bank_reference,''))) < 4 then
    raise exception 'Bank credit date and reference are required';
  end if;
  if coalesce(p_reconciliation_status,'') not in ('matched','mismatch','under_review') then
    raise exception 'Invalid reconciliation status';
  end if;
  if length(trim(coalesce(p_note,''))) < 10 then
    raise exception 'A reconciliation note of at least 10 characters is required';
  end if;

  select * into v_row
  from public.srk_razorpay_settlements
  where id = p_settlement_id
  for update;

  if not found then raise exception 'Razorpay settlement not found'; end if;
  if v_row.settlement_status <> 'processed' then
    raise exception 'Only processed Razorpay settlements can be reconciled to bank credits';
  end if;
  if p_reconciliation_status = 'matched' and
     (v_row.provider_net_amount_paise is null or v_row.provider_net_amount_paise <> p_bank_credit_amount_paise) then
    raise exception 'Bank credit does not exactly match the provider-reported net settlement amount';
  end if;
  if p_reconciliation_status = 'mismatch' and
     (v_row.provider_net_amount_paise is null or v_row.provider_net_amount_paise = p_bank_credit_amount_paise) then
    raise exception 'Mismatch status requires a known provider net amount that differs from bank credit';
  end if;

  update public.srk_razorpay_settlements
  set bank_credit_amount_paise = p_bank_credit_amount_paise,
      bank_credit_at = p_bank_credit_at,
      bank_reference = trim(p_bank_reference),
      reconciliation_status = p_reconciliation_status,
      reconciliation_note = trim(p_note),
      verified_by = v_actor,
      verified_at = v_verified_at,
      updated_at = v_verified_at
  where id = p_settlement_id;

  return jsonb_build_object(
    'success', true,
    'settlement_id', p_settlement_id,
    'reconciliation_status', p_reconciliation_status,
    'verified_at', v_verified_at
  );
end;
$$;
revoke all on function public.srk_admin_reconcile_razorpay_settlement(uuid,bigint,timestamptz,text,text,text) from public, anon;
grant execute on function public.srk_admin_reconcile_razorpay_settlement(uuid,bigint,timestamptz,text,text,text) to authenticated, service_role;
