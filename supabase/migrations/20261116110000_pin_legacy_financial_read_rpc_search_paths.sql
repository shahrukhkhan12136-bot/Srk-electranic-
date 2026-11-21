-- Pin legacy financial SECURITY DEFINER read RPCs to an empty search_path.
-- Their application objects and auth helpers are fully schema-qualified.
-- This prevents objects in public or temporary schemas from shadowing trusted names.

alter function public.srk_admin_commission_report()
  set search_path = '';
alter function public.srk_get_my_wallet_summary()
  set search_path = '';
alter function public.srk_admin_wallet_overview()
  set search_path = '';
