-- SRK ELECTRONIC secure wallet ledger foundation
-- This is an internal accounting ledger only. No customer stored-value top-ups
-- or electrician payouts are enabled until the regulated provider flow is approved.

create table if not exists public.srk_wallet_accounts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete restrict,
  wallet_type text not null check (wallet_type in ('customer','electrician')),
  currency text not null default 'INR' check (currency = 'INR'),
  status text not null default 'active' check (status in ('active','restricted','closed')),
  created_at timestamptz not null default now(),
  unique (user_id, wallet_type)
);

create table if not exists public.srk_wallet_ledger (
  id uuid primary key default gen_random_uuid(),
  wallet_id uuid not null references public.srk_wallet_accounts(id) on delete restrict,
  user_id uuid not null references auth.users(id) on delete restrict,
  wallet_type text not null check (wallet_type in ('customer','electrician')),
  entry_type text not null check (entry_type in ('booking_payment','refund','earning','commission','payout','adjustment','topup')),
  direction text not null check (direction in ('credit','debit')),
  amount numeric(12,2) not null check (amount > 0),
  status text not null default 'pending' check (status in ('pending','posted','reversed','failed')),
  reference_type text,
  reference_id text,
  provider text,
  provider_reference text,
  idempotency_key text unique,
  description text,
  created_at timestamptz not null default now(),
  posted_at timestamptz
);

create index if not exists srk_wallet_ledger_user_created_idx
  on public.srk_wallet_ledger(user_id, created_at desc);
create index if not exists srk_wallet_ledger_wallet_status_idx
  on public.srk_wallet_ledger(wallet_id, status);

create table if not exists public.srk_wallet_bank_links (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete restrict,
  wallet_type text not null default 'electrician' check (wallet_type = 'electrician'),
  provider text not null default 'razorpay_route',
  provider_account_id text not null unique,
  account_holder_name text,
  bank_name text,
  account_last4 text check (account_last4 is null or account_last4 ~ '^[0-9]{4}$'),
  ifsc_masked text,
  verification_status text not null default 'pending' check (verification_status in ('pending','verified','rejected','disabled')),
  is_primary boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(user_id, provider_account_id)
);

alter table public.srk_wallet_accounts enable row level security;
alter table public.srk_wallet_ledger enable row level security;
alter table public.srk_wallet_bank_links enable row level security;

drop policy if exists srk_wallet_accounts_owner_read on public.srk_wallet_accounts;
create policy srk_wallet_accounts_owner_read on public.srk_wallet_accounts
for select to authenticated using (user_id = (select auth.uid()));

drop policy if exists srk_wallet_ledger_owner_read on public.srk_wallet_ledger;
create policy srk_wallet_ledger_owner_read on public.srk_wallet_ledger
for select to authenticated using (user_id = (select auth.uid()));

drop policy if exists srk_wallet_bank_links_owner_read on public.srk_wallet_bank_links;
create policy srk_wallet_bank_links_owner_read on public.srk_wallet_bank_links
for select to authenticated using (user_id = (select auth.uid()));

revoke all on public.srk_wallet_accounts from anon, authenticated;
revoke all on public.srk_wallet_ledger from anon, authenticated;
revoke all on public.srk_wallet_bank_links from anon, authenticated;
grant select on public.srk_wallet_accounts to authenticated;
grant select on public.srk_wallet_ledger to authenticated;
grant select on public.srk_wallet_bank_links to authenticated;
grant all on public.srk_wallet_accounts to service_role;
grant all on public.srk_wallet_ledger to service_role;
grant all on public.srk_wallet_bank_links to service_role;

create or replace function public.srk_get_my_wallet_summary()
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, auth, pg_temp
as $$
declare
  v_uid uuid := auth.uid();
  v_customer_id uuid;
  v_electrician_id uuid;
  v_result jsonb;
begin
  if v_uid is null then
    raise exception 'Authentication required';
  end if;

  insert into public.srk_wallet_accounts(user_id, wallet_type)
  values (v_uid, 'customer')
  on conflict (user_id, wallet_type) do nothing;

  if exists (
    select 1 from public.electrician_profiles ep
    where coalesce(ep.auth_user_id, ep.user_id) = v_uid
      and ep.verification_status = 'approved'
  ) then
    insert into public.srk_wallet_accounts(user_id, wallet_type)
    values (v_uid, 'electrician')
    on conflict (user_id, wallet_type) do nothing;
  end if;

  select id into v_customer_id from public.srk_wallet_accounts
  where user_id = v_uid and wallet_type = 'customer';

  select id into v_electrician_id from public.srk_wallet_accounts
  where user_id = v_uid and wallet_type = 'electrician';

  select jsonb_build_object(
    'customer', jsonb_build_object(
      'wallet_id', v_customer_id,
      'balance', coalesce((
        select sum(case when direction='credit' then amount else -amount end)
        from public.srk_wallet_ledger
        where wallet_id=v_customer_id and status='posted'
      ),0),
      'currency','INR',
      'topups_enabled',false,
      'note','Customer deposits are disabled until the regulated payment flow is approved.'
    ),
    'electrician', case when v_electrician_id is null then null else jsonb_build_object(
      'wallet_id', v_electrician_id,
      'balance', coalesce((
        select sum(case when direction='credit' then amount else -amount end)
        from public.srk_wallet_ledger
        where wallet_id=v_electrician_id and status='posted'
      ),0),
      'currency','INR',
      'payouts_enabled',false,
      'note','Bank payouts are disabled until Route linked-account onboarding and live approval are complete.'
    ) end
  ) into v_result;

  return v_result;
end;
$$;

revoke all on function public.srk_get_my_wallet_summary() from public, anon;
grant execute on function public.srk_get_my_wallet_summary() to authenticated;

create or replace function public.srk_admin_wallet_overview()
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, auth, pg_temp
as $$
declare v_result jsonb;
begin
  if auth.uid() is null or not public.is_srk_admin() then
    raise exception 'Admin access required';
  end if;

  select jsonb_build_object(
    'customer_wallets', (select count(*) from public.srk_wallet_accounts where wallet_type='customer'),
    'electrician_wallets', (select count(*) from public.srk_wallet_accounts where wallet_type='electrician'),
    'posted_ledger_credits', coalesce((select sum(amount) from public.srk_wallet_ledger where status='posted' and direction='credit'),0),
    'posted_ledger_debits', coalesce((select sum(amount) from public.srk_wallet_ledger where status='posted' and direction='debit'),0),
    'pending_entries', (select count(*) from public.srk_wallet_ledger where status='pending'),
    'verified_bank_links', (select count(*) from public.srk_wallet_bank_links where verification_status='verified')
  ) into v_result;
  return v_result;
end;
$$;

revoke all on function public.srk_admin_wallet_overview() from public, anon;
grant execute on function public.srk_admin_wallet_overview() to authenticated;

