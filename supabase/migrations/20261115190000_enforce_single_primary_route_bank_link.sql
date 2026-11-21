-- Enforce at most one primary Razorpay Route electrician bank link per Auth user.
-- Fail closed if historical data already contains duplicates; do not silently pick an account.
do $$
begin
  if exists (
    select 1
      from public.srk_wallet_bank_links
     where provider='razorpay_route'
       and wallet_type='electrician'
       and is_primary=true
     group by user_id
    having count(*)>1
  ) then
    raise exception 'DUPLICATE_PRIMARY_ROUTE_BANK_LINKS_REQUIRE_MANUAL_REVIEW';
  end if;
end;
$$;

create unique index if not exists srk_wallet_bank_links_one_primary_route_electrician_uidx
  on public.srk_wallet_bank_links(user_id)
  where provider='razorpay_route'
    and wallet_type='electrician'
    and is_primary=true;

comment on index public.srk_wallet_bank_links_one_primary_route_electrician_uidx is
  'At most one primary Razorpay Route electrician linked account per Auth user; duplicate legacy rows must be manually reconciled before migration.';
