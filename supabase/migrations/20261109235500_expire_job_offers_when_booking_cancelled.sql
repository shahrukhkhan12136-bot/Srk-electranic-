-- Expire all outstanding and accepted electrician offers when a booking is cancelled.
CREATE OR REPLACE FUNCTION public.srk_cancel_booking_job_offers()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'public', 'pg_temp'
AS $function$
BEGIN
  IF NEW.status = 'cancelled' AND OLD.status IS DISTINCT FROM NEW.status THEN
    UPDATE public.job_offers
       SET status = 'cancelled',
           responded_at = COALESCE(responded_at, pg_catalog.now())
     WHERE booking_id = NEW.id
       AND status IN ('offered', 'accepted');
  END IF;
  RETURN NEW;
END;
$function$;

REVOKE ALL ON FUNCTION public.srk_cancel_booking_job_offers() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.srk_cancel_booking_job_offers() FROM anon, authenticated;

DROP TRIGGER IF EXISTS srk_cancel_booking_job_offers ON public.service_bookings;
CREATE TRIGGER srk_cancel_booking_job_offers
AFTER UPDATE OF status ON public.service_bookings
FOR EACH ROW
WHEN (OLD.status IS DISTINCT FROM NEW.status AND NEW.status = 'cancelled')
EXECUTE FUNCTION public.srk_cancel_booking_job_offers();
