-- Harden legacy SECURITY DEFINER financial read RPCs against search_path shadowing.
-- All application tables and authorization helpers in these functions are schema-qualified.
ALTER FUNCTION public.srk_admin_commission_report()
  SET search_path = pg_catalog, public, auth, pg_temp;

ALTER FUNCTION public.srk_get_my_wallet_summary()
  SET search_path = pg_catalog, public, auth, pg_temp;

ALTER FUNCTION public.srk_admin_wallet_overview()
  SET search_path = pg_catalog, public, auth, pg_temp;
