ALTER FUNCTION public.srk_admin_commission_report()
  SET search_path = pg_catalog, public, auth, pg_temp;

ALTER FUNCTION public.srk_admin_wallet_overview()
  SET search_path = pg_catalog, public, auth, pg_temp;

ALTER FUNCTION public.srk_get_my_wallet_summary()
  SET search_path = pg_catalog, public, auth, pg_temp;

CREATE INDEX IF NOT EXISTS srk_route_transfers_recipient_user_id_idx
  ON public.srk_route_transfers (recipient_user_id);