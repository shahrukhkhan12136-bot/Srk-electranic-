-- Protect server-timed customer bookings from direct Admin/browser status edits.
-- New-category lifecycle transitions must use the protected dispatch/work/cancellation RPCs.

CREATE OR REPLACE FUNCTION public.srk_guard_new_category_booking_status_transition()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  v_authorized boolean := false;
  v_cancel_request_id text;
BEGIN
  IF NEW.status IS NOT DISTINCT FROM OLD.status
     OR OLD.selected_category IS NULL THEN
    RETURN NEW;
  END IF;

  IF NEW.selected_category IS DISTINCT FROM OLD.selected_category THEN
    RAISE EXCEPTION 'BOOKING_CATEGORY_IS_IMMUTABLE'
      USING ERRCODE='42501';
  END IF;

  IF NEW.status='confirmed' AND OLD.status='new' AND public.is_srk_admin() THEN
    RETURN NEW;
  END IF;

  IF NEW.status='assigned'
     AND OLD.status IN ('new','confirmed')
     AND NEW.assigned_electrician_id IS NOT NULL THEN
    RETURN NEW;
  END IF;

  IF NEW.status IN ('awaiting_work_start_approval','assigned')
     AND (
       (NEW.status='awaiting_work_start_approval' AND OLD.status='assigned')
       OR (NEW.status='assigned' AND OLD.status='awaiting_work_start_approval'
           AND NEW.work_start_approval_status='rejected')
     ) THEN
    SELECT EXISTS (
      SELECT 1
      FROM srk_private.work_timer_authorizations a
      WHERE a.transaction_id=pg_catalog.txid_current()
        AND a.booking_id=NEW.id
        AND a.actor_id=auth.uid()
    ) INTO v_authorized;
    IF v_authorized THEN RETURN NEW; END IF;
  END IF;

  IF NEW.status IN ('in_progress','completed') THEN
    SELECT EXISTS (
      SELECT 1
      FROM srk_private.work_transition_authorizations a
      WHERE a.transaction_id=pg_catalog.txid_current()
        AND a.booking_id=NEW.id
        AND a.target_status=NEW.status
    ) INTO v_authorized;
    IF v_authorized THEN RETURN NEW; END IF;
  END IF;

  IF NEW.status='cancelled' THEN
    v_cancel_request_id:=pg_catalog.current_setting('srk.cancel_request_id',true);
    IF v_cancel_request_id IS NOT NULL AND EXISTS (
      SELECT 1
      FROM public.srk_booking_cancellation_requests r
      WHERE r.id::text=v_cancel_request_id
        AND r.booking_id=NEW.id
        AND r.request_status='approved'
    ) THEN
      RETURN NEW;
    END IF;
  END IF;

  RAISE EXCEPTION 'NEW_CATEGORY_STATUS_REQUIRES_PROTECTED_WORKFLOW'
    USING ERRCODE='42501';
END;
$function$;

REVOKE ALL ON FUNCTION public.srk_guard_new_category_booking_status_transition()
  FROM PUBLIC,anon,authenticated;

DROP TRIGGER IF EXISTS srk_guard_new_category_booking_status_transition
  ON public.service_bookings;
CREATE TRIGGER srk_guard_new_category_booking_status_transition
  BEFORE UPDATE OF status ON public.service_bookings
  FOR EACH ROW
  EXECUTE FUNCTION public.srk_guard_new_category_booking_status_transition();

COMMENT ON FUNCTION public.srk_guard_new_category_booking_status_transition() IS
  'Prevents direct status changes to server-timed customer bookings; only protected work, dispatch, and approved cancellation transitions are allowed.';
