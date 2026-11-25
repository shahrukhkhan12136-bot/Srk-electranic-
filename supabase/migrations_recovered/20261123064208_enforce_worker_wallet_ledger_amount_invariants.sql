
alter table public.srk_worker_wallet_ledger
  add constraint srk_worker_wallet_ledger_amount_nonnegative
  check (amount >= 0) not valid;
alter table public.srk_worker_wallet_ledger
  validate constraint srk_worker_wallet_ledger_amount_nonnegative;

alter table public.srk_worker_wallet_ledger
  add constraint srk_worker_wallet_ledger_two_decimal_amounts
  check (amount = round(amount,2) and balance_effect = round(balance_effect,2)) not valid;
alter table public.srk_worker_wallet_ledger
  validate constraint srk_worker_wallet_ledger_two_decimal_amounts;

alter table public.srk_worker_wallet_ledger
  add constraint srk_worker_wallet_ledger_effect_matches_amount
  check (abs(balance_effect) = amount) not valid;
alter table public.srk_worker_wallet_ledger
  validate constraint srk_worker_wallet_ledger_effect_matches_amount;
