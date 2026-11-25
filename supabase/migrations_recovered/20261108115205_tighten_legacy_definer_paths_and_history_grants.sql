ALTER FUNCTION public.accept_electrician_job(uuid)
  SET search_path = pg_catalog, public, auth, pg_temp;

ALTER FUNCTION public.srk_link_electrician_profile()
  SET search_path = pg_catalog, public, auth, pg_temp;

REVOKE ALL PRIVILEGES ON TABLE public.service_booking_status_history FROM anon;
REVOKE ALL PRIVILEGES ON TABLE public.service_booking_status_history FROM authenticated;
GRANT SELECT ON TABLE public.service_booking_status_history TO authenticated;
GRANT ALL PRIVILEGES ON TABLE public.service_booking_status_history TO service_role;