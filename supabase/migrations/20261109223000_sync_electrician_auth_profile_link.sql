-- Keep the electrician profile identity columns synchronized and align job-offer RLS
-- with the canonical user_id used by the electrician portal and its SECURITY DEFINER RPCs.
CREATE OR REPLACE FUNCTION public.srk_link_electrician_profile()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'public', 'auth', 'pg_temp'
AS $function$
BEGIN
  IF NEW.phone IS NOT NULL AND NEW.phone_confirmed_at IS NOT NULL THEN
    UPDATE public.electrician_profiles
       SET user_id = NEW.id,
           auth_user_id = NEW.id
     WHERE right(pg_catalog.regexp_replace(phone, '[^0-9]', '', 'g'), 10) =
           right(pg_catalog.regexp_replace(NEW.phone, '[^0-9]', '', 'g'), 10)
       AND verification_status = 'approved'
       AND user_id IS NULL;
  END IF;
  RETURN NEW;
END;
$function$;

DROP POLICY IF EXISTS electrician_and_admin_read_offers ON public.job_offers;
CREATE POLICY electrician_and_admin_read_offers
ON public.job_offers
FOR SELECT
TO authenticated
USING (
  (SELECT public.is_srk_admin())
  OR EXISTS (
    SELECT 1
      FROM public.electrician_profiles e
     WHERE e.id = job_offers.electrician_id
       AND (e.user_id = (SELECT auth.uid()) OR e.auth_user_id = (SELECT auth.uid()))
       AND e.active = true
       AND e.verification_status = 'approved'
  )
);
