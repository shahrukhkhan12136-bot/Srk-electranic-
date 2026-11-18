-- Enforce write-once commercial estimate snapshots on service bookings.
-- Source-only migration. No existing booking or bill row is updated.
BEGIN;

CREATE OR REPLACE FUNCTION public.srk_guard_booking_rate_snapshot_immutable()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path=''
AS $fn$
BEGIN
  IF OLD.selected_category IS DISTINCT FROM NEW.selected_category
     OR OLD.selected_duration_hours IS DISTINCT FROM NEW.selected_duration_hours
     OR OLD.selected_rate_tier IS DISTINCT FROM NEW.selected_rate_tier
     OR OLD.estimated_labour_paise IS DISTINCT FROM NEW.estimated_labour_paise
     OR OLD.estimate_rate_card_version IS DISTINCT FROM NEW.estimate_rate_card_version THEN
    RAISE EXCEPTION 'BOOKING_RATE_SNAPSHOT_IS_IMMUTABLE'
      USING ERRCODE='42501';
  END IF;
  RETURN NEW;
END;
$fn$;

REVOKE ALL ON FUNCTION public.srk_guard_booking_rate_snapshot_immutable() FROM PUBLIC,anon,authenticated;

DROP TRIGGER IF EXISTS srk_guard_booking_rate_snapshot_immutable ON public.service_bookings;
CREATE TRIGGER srk_guard_booking_rate_snapshot_immutable
BEFORE UPDATE OF selected_category,selected_duration_hours,selected_rate_tier,
  estimated_labour_paise,estimate_rate_card_version
ON public.service_bookings
FOR EACH ROW
EXECUTE FUNCTION public.srk_guard_booking_rate_snapshot_immutable();

COMMIT;
