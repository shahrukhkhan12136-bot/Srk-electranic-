-- Pin remaining legacy wallet and customer receipt SECURITY DEFINER RPCs.
-- Their table, helper and auth references are schema-qualified; pg_catalog
-- remains implicitly available for built-in operators and functions.
alter function public.srk_get_my_wallet_summary()
  set search_path = '';
alter function public.srk_admin_wallet_overview()
  set search_path = '';
alter function public.srk_get_my_earnings()
  set search_path = '';
alter function public.srk_customer_get_payment_receipt(uuid)
  set search_path = '';
