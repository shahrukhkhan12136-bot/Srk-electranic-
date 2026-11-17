begin;
select plan(10);

select ok(to_regprocedure('public.srk_get_my_earnings()') is not null,
  'electrician earnings RPC exists');
select ok((select prosecdef from pg_proc where oid='public.srk_get_my_earnings()'::regprocedure),
  'electrician earnings RPC is SECURITY DEFINER');
select ok(coalesce((select proconfig @> ARRAY['search_path=""'] from pg_proc where oid='public.srk_get_my_earnings()'::regprocedure),false),
  'electrician earnings RPC pins an empty search_path');
select ok(not has_function_privilege('anon','public.srk_get_my_earnings()','EXECUTE')
  and has_function_privilege('authenticated','public.srk_get_my_earnings()','EXECUTE'),
  'only authenticated callers receive execute permission');
select ok(position('left join public.srk_electrician_payouts po' in lower(pg_get_functiondef('public.srk_get_my_earnings()'::regprocedure)))>0,
  'earnings are joined to the canonical payout ledger');
select ok(position('po.electrician_profile_id=p.id' in lower(pg_get_functiondef('public.srk_get_my_earnings()'::regprocedure)))>0,
  'payout row must belong to the same electrician profile');
select ok(position('po.payout_status in (''pending'',''paid'',''blocked'')' in lower(pg_get_functiondef('public.srk_get_my_earnings()'::regprocedure)))>0,
  'refunded payout rows are excluded from earnings');
select ok(position('coalesce(po.platform_commission,0)' in lower(pg_get_functiondef('public.srk_get_my_earnings()'::regprocedure)))>0,
  'commission comes from payout ledger rather than customer collection');
select ok(position('coalesce(po.electrician_payable,0)' in lower(pg_get_functiondef('public.srk_get_my_earnings()'::regprocedure)))>0,
  'electrician earning comes from payout ledger payable');
select ok(position('coalesce(b.amount_paid,0)' in lower(pg_get_functiondef('public.srk_get_my_earnings()'::regprocedure)))>0
  and position('b.amount_paid-coalesce(b.commission_amount,0)' in lower(pg_get_functiondef('public.srk_get_my_earnings()'::regprocedure)))=0,
  'customer collection is retained separately and never used to calculate electrician earning');

select * from finish();
rollback;
