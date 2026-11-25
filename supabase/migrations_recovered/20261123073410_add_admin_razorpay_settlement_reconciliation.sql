
create table if not exists public.srk_razorpay_settlement_reconciliation_history (
  id uuid primary key default gen_random_uuid(),
  settlement_id uuid not null references public.srk_razorpay_settlements(id) on delete restrict,
  actor_user_id uuid references auth.users(id) on delete set null,
  actor_type text not null check (actor_type in ('admin','service')),
  action text not null,
  before_data jsonb not null default '{}'::jsonb,
  after_data jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create index if not exists srk_razorpay_settlement_history_lookup_idx
  on public.srk_razorpay_settlement_reconciliation_history(settlement_id, created_at desc);
alter table public.srk_razorpay_settlement_reconciliation_history enable row level security;
revoke all on public.srk_razorpay_settlement_reconciliation_history from public, anon, authenticated;
grant select on public.srk_razorpay_settlement_reconciliation_history to authenticated;
grant select, insert on public.srk_razorpay_settlement_reconciliation_history to service_role;
drop policy if exists srk_razorpay_settlement_history_admin_read on public.srk_razorpay_settlement_reconciliation_history;
create policy srk_razorpay_settlement_history_admin_read
  on public.srk_razorpay_settlement_reconciliation_history for select to authenticated
  using (public.srk_has_admin_permission('payments.read'));

create or replace function public.srk_capture_razorpay_settlement_reconciliation_history()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_actor uuid := auth.uid();
begin
  insert into public.srk_razorpay_settlement_reconciliation_history
    (settlement_id, actor_user_id, actor_type, action, before_data, after_data)
  values (
    new.id,
    v_actor,
    case when v_actor is null then 'service' else 'admin' end,
    case when tg_op = 'INSERT' then 'created' else 'updated' end,
    case when tg_op = 'INSERT' then '{}'::jsonb else
      jsonb_build_object(
        'settlement_status', old.settlement_status,
        'gross_amount_paise', old.gross_amount_paise,
        'fee_amount_paise', old.fee_amount_paise,
        'tax_amount_paise', old.tax_amount_paise,
        'provider_net_amount_paise', old.provider_net_amount_paise,
        'utr', old.utr,
        'bank_credit_amount_paise', old.bank_credit_amount_paise,
        'bank_credit_at', old.bank_credit_at,
        'bank_reference', old.bank_reference,
        'reconciliation_status', old.reconciliation_status,
        'reconciliation_note', old.reconciliation_note
      ) end,
    jsonb_build_object(
      'settlement_status', new.settlement_status,
      'gross_amount_paise', new.gross_amount_paise,
      'fee_amount_paise', new.fee_amount_paise,
      'tax_amount_paise', new.tax_amount_paise,
      'provider_net_amount_paise', new.provider_net_amount_paise,
      'utr', new.utr,
      'bank_credit_amount_paise', new.bank_credit_amount_paise,
      'bank_credit_at', new.bank_credit_at,
      'bank_reference', new.bank_reference,
      'reconciliation_status', new.reconciliation_status,
      'reconciliation_note', new.reconciliation_note
    )
  );
  return new;
end;
$$;

drop trigger if exists trg_srk_razorpay_settlement_history on public.srk_razorpay_settlements;
create trigger trg_srk_razorpay_settlement_history
after insert or update on public.srk_razorpay_settlements
for each row execute function public.srk_capture_razorpay_settlement_reconciliation_history();

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
  if p_reconciliation_status not in ('matched','mismatch','under_review') then
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
      verified_at = now(),
      updated_at = now()
  where id = p_settlement_id;

  return jsonb_build_object(
    'success', true,
    'settlement_id', p_settlement_id,
    'reconciliation_status', p_reconciliation_status,
    'verified_at', now()
  );
end;
$$;

revoke all on function public.srk_admin_reconcile_razorpay_settlement(uuid,bigint,timestamptz,text,text,text) from public, anon;
grant execute on function public.srk_admin_reconcile_razorpay_settlement(uuid,bigint,timestamptz,text,text,text) to authenticated, service_role;
