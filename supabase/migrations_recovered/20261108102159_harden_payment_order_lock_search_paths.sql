ALTER FUNCTION public.srk_claim_payment_order_lock(uuid)
  SET search_path = pg_catalog, public, pg_temp;
ALTER FUNCTION public.srk_release_payment_order_lock(uuid, uuid)
  SET search_path = pg_catalog, public, pg_temp;