-- Master booking dispatch completion must move the canonical booking into Assigned.
-- Source-only Feature Branch migration; no database has been changed.
-- Legacy Electrician assignment/status behavior remains unchanged.

ALTER TABLE public.service_bookings
  DROP CONSTRAINT IF EXISTS service_bookings_assignment_status_requires_electrician;
ALTER TABLE public.service_bookings
  ADD CONSTRAINT service_bookings_assignment_status_requires_electrician CHECK (
    status <> ALL (ARRAY[
      'assigned','inspection','awaiting_quote_approval','quote_approved',
      'quote_rejected','awaiting_work_start_approval','in_progress','completed'
    ]::text[])
    OR assigned_electrician_id IS NOT NULL
    OR srk_service_category_code IS NOT NULL
  );

-- The old status guard protects legacy rows identified by selected_category.
-- Master rows use the canonical category code and receive their own guarded path.
CREATE OR REPLACE FUNCTION public.srk_guard_master_booking_status_transition()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  v_authorized boolean := false;
  v_cancel_request_id text;
BEGIN
  IF NEW.srk_service_category_code IS DISTINCT FROM OLD.srk_service_category_code
     OR NEW.srk_service_skill_code IS DISTINCT FROM OLD.srk_service_skill_code
     OR NEW.srk_service_code IS DISTINCT FROM OLD.srk_service_code
     OR NEW.srk_rate_level_code IS DISTINCT FROM OLD.srk_rate_level_code
     OR NEW.srk_rate_version_snapshot IS DISTINCT FROM OLD.srk_rate_version_snapshot
     OR NEW.srk_billing_model_snapshot IS DISTINCT FROM OLD.srk_billing_model_snapshot
     OR NEW.srk_technician_hourly_paise_snapshot IS DISTINCT FROM OLD.srk_technician_hourly_paise_snapshot
     OR NEW.srk_helper_hourly_paise_snapshot IS DISTINCT FROM OLD.srk_helper_hourly_paise_snapshot
     OR NEW.srk_fixed_labour_paise_snapshot IS DISTINCT FROM OLD.srk_fixed_labour_paise_snapshot
     OR NEW.srk_estimated_labour_paise IS DISTINCT FROM OLD.srk_estimated_labour_paise
     OR NEW.srk_duration_minutes IS DISTINCT FROM OLD.srk_duration_minutes
     OR NEW.srk_service_quantity IS DISTINCT FROM OLD.srk_service_quantity THEN
    RAISE EXCEPTION 'MASTER_BOOKING_SERVICE_AND_RATE_SNAPSHOTS_ARE_IMMUTABLE'
      USING ERRCODE='42501';
  END IF;

  IF NEW.srk_service_category_code IS NULL OR NEW.status IS NOT DISTINCT FROM OLD.status THEN
    RETURN NEW;
  END IF;

  IF NEW.status='confirmed' AND OLD.status='new' AND public.is_srk_admin() THEN
    RETURN NEW;
  END IF;

  IF NEW.status='assigned' AND OLD.status IN ('new','confirmed') THEN
    SELECT EXISTS (
      SELECT 1 FROM srk_private.work_transition_authorizations a
      WHERE a.transaction_id=pg_catalog.txid_current()
        AND a.booking_id=NEW.id AND a.target_status='assigned'
    ) INTO v_authorized;
    IF v_authorized THEN RETURN NEW; END IF;
  END IF;

  IF NEW.status IN ('awaiting_work_start_approval','assigned')
     AND (
       (NEW.status='awaiting_work_start_approval' AND OLD.status='assigned')
       OR (NEW.status='assigned' AND OLD.status='awaiting_work_start_approval'
           AND NEW.work_start_approval_status='rejected')
     ) THEN
    SELECT EXISTS (
      SELECT 1 FROM srk_private.work_timer_authorizations a
      WHERE a.transaction_id=pg_catalog.txid_current()
        AND a.booking_id=NEW.id AND a.actor_id=auth.uid()
    ) INTO v_authorized;
    IF v_authorized THEN RETURN NEW; END IF;
  END IF;

  IF NEW.status IN ('in_progress','completed') THEN
    SELECT EXISTS (
      SELECT 1 FROM srk_private.work_transition_authorizations a
      WHERE a.transaction_id=pg_catalog.txid_current()
        AND a.booking_id=NEW.id AND a.target_status=NEW.status
    ) INTO v_authorized;
    IF v_authorized THEN RETURN NEW; END IF;
  END IF;

  IF NEW.status='cancelled' THEN
    v_cancel_request_id:=pg_catalog.current_setting('srk.cancel_request_id',true);
    IF v_cancel_request_id IS NOT NULL AND EXISTS (
      SELECT 1 FROM public.srk_booking_cancellation_requests r
      WHERE r.id::text=v_cancel_request_id AND r.booking_id=NEW.id
        AND r.request_status='approved'
    ) THEN
      RETURN NEW;
    END IF;
  END IF;

  RAISE EXCEPTION 'MASTER_BOOKING_STATUS_REQUIRES_PROTECTED_WORKFLOW'
    USING ERRCODE='42501';
END;
$function$;

REVOKE ALL ON FUNCTION public.srk_guard_master_booking_status_transition()
  FROM PUBLIC,anon,authenticated;
DROP TRIGGER IF EXISTS srk_guard_master_booking_status_transition
  ON public.service_bookings;
CREATE TRIGGER srk_guard_master_booking_status_transition
  BEFORE UPDATE OF status,srk_service_category_code,srk_service_skill_code,
    srk_service_code,srk_rate_level_code,srk_rate_version_snapshot,
    srk_billing_model_snapshot,srk_technician_hourly_paise_snapshot,
    srk_helper_hourly_paise_snapshot,srk_fixed_labour_paise_snapshot,
    srk_estimated_labour_paise,srk_duration_minutes,srk_service_quantity
  ON public.service_bookings
  FOR EACH ROW EXECUTE FUNCTION public.srk_guard_master_booking_status_transition();

-- Once the requested number of distinct approved Technicians has accepted,
-- promote the same booking row to Assigned. No second booking is created.
CREATE OR REPLACE FUNCTION public.srk_promote_fully_assigned_master_booking()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  v_category text;
  v_booking_status text;
BEGIN
  IF NEW.status IS DISTINCT FROM 'assigned' OR OLD.status='assigned' THEN
    RETURN NEW;
  END IF;

  SELECT b.srk_service_category_code,b.status
    INTO v_category,v_booking_status
  FROM public.service_bookings b
  WHERE b.id=NEW.booking_id
  FOR UPDATE;

  IF v_category IS NULL OR v_booking_status NOT IN ('new','confirmed') THEN
    RETURN NEW;
  END IF;

  IF NEW.assigned_technician_count < NEW.required_technician_count THEN
    RAISE EXCEPTION 'MASTER_BOOKING_REQUIRED_TECHNICIAN_COUNT_NOT_MET'
      USING ERRCODE='55000';
  END IF;

  INSERT INTO srk_private.work_transition_authorizations(
    transaction_id,booking_id,target_status
  ) VALUES(pg_catalog.txid_current(),NEW.booking_id,'assigned')
  ON CONFLICT DO NOTHING;

  UPDATE public.service_bookings
    SET status='assigned'
  WHERE id=NEW.booking_id AND status IN ('new','confirmed');

  DELETE FROM srk_private.work_transition_authorizations
  WHERE transaction_id=pg_catalog.txid_current()
    AND booking_id=NEW.booking_id AND target_status='assigned';

  RETURN NEW;
END;
$function$;

REVOKE ALL ON FUNCTION public.srk_promote_fully_assigned_master_booking()
  FROM PUBLIC,anon,authenticated;
DROP TRIGGER IF EXISTS srk_promote_fully_assigned_master_booking
  ON public.srk_technician_dispatch_requests;
CREATE TRIGGER srk_promote_fully_assigned_master_booking
  AFTER UPDATE OF status ON public.srk_technician_dispatch_requests
  FOR EACH ROW EXECUTE FUNCTION public.srk_promote_fully_assigned_master_booking();

COMMENT ON FUNCTION public.srk_promote_fully_assigned_master_booking() IS
  'Promotes the existing canonical booking to Assigned only after all requested shared Technicians have accepted.';
