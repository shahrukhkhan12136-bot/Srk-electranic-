-- Customer-safe, idempotent work timeline contract for the new work lifecycle.
-- Historical rows are explicitly marked unknown; no synthetic events are created.

ALTER TABLE public.srk_booking_work_events
  ADD COLUMN IF NOT EXISTS actor_role text,
  ADD COLUMN IF NOT EXISTS idempotency_key text;

UPDATE public.srk_booking_work_events
SET actor_role='unknown'
WHERE actor_role IS NULL;

UPDATE public.srk_booking_work_events
SET idempotency_key='legacy-event:'||id::text
WHERE idempotency_key IS NULL;

ALTER TABLE public.srk_booking_work_events
  ALTER COLUMN actor_role SET NOT NULL,
  ALTER COLUMN idempotency_key SET NOT NULL;

ALTER TABLE public.srk_booking_work_events
  ADD CONSTRAINT srk_booking_work_events_actor_role_check
  CHECK (actor_role IN ('customer','electrician','admin','system','unknown'));

CREATE UNIQUE INDEX IF NOT EXISTS srk_booking_work_events_idempotency_key_uidx
  ON public.srk_booking_work_events(idempotency_key);

COMMENT ON COLUMN public.srk_booking_work_events.actor_role IS
  'Role of the authenticated actor at event capture time; unknown is used for historical events whose actor role cannot be proven.';
COMMENT ON COLUMN public.srk_booking_work_events.idempotency_key IS
  'Unique transaction-scoped key preventing duplicate event capture for the same booking transition in one database transaction.';

CREATE OR REPLACE FUNCTION public.srk_capture_booking_work_event()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'pg_catalog','public','auth','pg_temp'
AS $function$
DECLARE
  v_event_type text;
  v_actor uuid := auth.uid();
  v_details jsonb := '{}'::jsonb;
  v_actor_role text;
  v_event_key text;
BEGIN
  IF TG_OP='INSERT' THEN
    v_event_type := 'booking_created';
    v_actor_role := CASE WHEN v_actor IS NULL THEN 'system' WHEN public.is_srk_admin() THEN 'admin' WHEN NEW.customer_user_id=v_actor THEN 'customer' WHEN EXISTS(SELECT 1 FROM public.electrician_profiles ep WHERE ep.id=NEW.assigned_electrician_id AND (ep.user_id=v_actor OR ep.auth_user_id=v_actor)) THEN 'electrician' ELSE 'unknown' END;
    v_event_key := 'tx:'||pg_catalog.txid_current()::text||':booking:'||NEW.id::text||':event:'||v_event_type;
    INSERT INTO public.srk_booking_work_events(
      booking_id, actor_id, actor_role, event_type, idempotency_key, new_status, new_timer_running,
      new_work_started_at, new_elapsed_seconds, new_start_approval_status,
      new_completion_approval_status, completion_requested_at
    ) VALUES (
      NEW.id, v_actor, v_actor_role, v_event_type, v_event_key, NEW.status, NEW.work_timer_running,
      NEW.work_started_at, COALESCE(NEW.work_timer_elapsed_seconds,0),
      NEW.work_start_approval_status, NEW.completion_approval_status,
      NEW.completion_requested_at
    ) ON CONFLICT (idempotency_key) DO NOTHING;
    RETURN NEW;
  END IF;

  IF OLD.status IS NOT DISTINCT FROM NEW.status
     AND OLD.work_timer_running IS NOT DISTINCT FROM NEW.work_timer_running
     AND OLD.work_started_at IS NOT DISTINCT FROM NEW.work_started_at
     AND OLD.work_timer_elapsed_seconds IS NOT DISTINCT FROM NEW.work_timer_elapsed_seconds
     AND OLD.work_start_approval_status IS NOT DISTINCT FROM NEW.work_start_approval_status
     AND OLD.completion_approval_status IS NOT DISTINCT FROM NEW.completion_approval_status
     AND OLD.completion_requested_at IS NOT DISTINCT FROM NEW.completion_requested_at THEN
    RETURN NEW;
  END IF;

  v_event_type := CASE
    WHEN OLD.work_start_approval_status IS DISTINCT FROM NEW.work_start_approval_status
      AND NEW.work_start_approval_status='pending' THEN 'work_start_requested'
    WHEN OLD.work_start_approval_status IS DISTINCT FROM NEW.work_start_approval_status
      AND NEW.work_start_approval_status='approved' THEN 'work_start_approved'
    WHEN OLD.work_start_approval_status IS DISTINCT FROM NEW.work_start_approval_status
      AND NEW.work_start_approval_status='rejected' THEN 'work_start_rejected'
    WHEN OLD.completion_requested_at IS DISTINCT FROM NEW.completion_requested_at
      AND NEW.completion_requested_at IS NOT NULL THEN 'work_completion_requested'
    WHEN OLD.completion_approval_status IS DISTINCT FROM NEW.completion_approval_status
      AND NEW.completion_approval_status='rejected' THEN 'work_completion_rejected'
    WHEN OLD.completion_approval_status IS DISTINCT FROM NEW.completion_approval_status
      AND NEW.completion_approval_status='disputed' THEN 'work_completion_disputed'
    WHEN OLD.completion_approval_status IS DISTINCT FROM NEW.completion_approval_status
      AND NEW.completion_approval_status='approved'
      AND public.is_srk_admin() THEN 'work_completion_admin_approved'
    WHEN OLD.completion_approval_status IS DISTINCT FROM NEW.completion_approval_status
      AND NEW.completion_approval_status='approved' THEN 'work_completion_customer_approved'
    WHEN OLD.work_timer_running IS DISTINCT FROM NEW.work_timer_running
      AND NEW.work_timer_running IS TRUE THEN 'work_timer_started'
    ELSE 'booking_work_state_changed'
  END;

  v_actor_role := CASE WHEN v_actor IS NULL THEN 'system' WHEN public.is_srk_admin() THEN 'admin' WHEN NEW.customer_user_id=v_actor THEN 'customer' WHEN EXISTS(SELECT 1 FROM public.electrician_profiles ep WHERE ep.id=NEW.assigned_electrician_id AND (ep.user_id=v_actor OR ep.auth_user_id=v_actor)) THEN 'electrician' ELSE 'unknown' END;
  v_event_key := 'tx:'||pg_catalog.txid_current()::text||':booking:'||NEW.id::text||':event:'||v_event_type;

  IF v_event_type='work_completion_admin_approved' THEN
    SELECT a.details INTO v_details
    FROM srk_private.work_event_details_authorizations a
    WHERE a.transaction_id=pg_catalog.txid_current()
      AND a.booking_id=NEW.id AND a.actor_id=v_actor
      AND a.event_type=v_event_type;
    v_details := COALESCE(v_details,'{}'::jsonb);
  END IF;

  INSERT INTO public.srk_booking_work_events(
    booking_id, actor_id, actor_role, event_type, idempotency_key,
    old_status, new_status,
    old_timer_running, new_timer_running,
    old_work_started_at, new_work_started_at,
    old_elapsed_seconds, new_elapsed_seconds,
    old_start_approval_status, new_start_approval_status,
    old_completion_approval_status, new_completion_approval_status,
    completion_requested_at, details
  ) VALUES (
    NEW.id, v_actor, v_actor_role, v_event_type, v_event_key,
    OLD.status, NEW.status,
    OLD.work_timer_running, NEW.work_timer_running,
    OLD.work_started_at, NEW.work_started_at,
    OLD.work_timer_elapsed_seconds, NEW.work_timer_elapsed_seconds,
    OLD.work_start_approval_status, NEW.work_start_approval_status,
    OLD.completion_approval_status, NEW.completion_approval_status,
    NEW.completion_requested_at, v_details
  ) ON CONFLICT (idempotency_key) DO NOTHING;
  RETURN NEW;
END;
$function$;

CREATE OR REPLACE FUNCTION public.srk_customer_get_my_booking_work_timeline()
RETURNS TABLE(
  booking_id uuid,
  event_id bigint,
  event_type text,
  actor_role text,
  old_status text,
  new_status text,
  occurred_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path TO 'pg_catalog','public','auth','pg_temp'
AS $function$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE='42501';
  END IF;
  RETURN QUERY
  SELECT e.booking_id,e.id,e.event_type,e.actor_role,e.old_status,e.new_status,e.occurred_at
  FROM public.srk_booking_work_events e
  JOIN public.service_bookings b ON b.id=e.booking_id
  WHERE b.customer_user_id=auth.uid()
  ORDER BY e.booking_id,e.occurred_at,e.id;
END;
$function$;
REVOKE ALL ON FUNCTION public.srk_customer_get_my_booking_work_timeline() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.srk_customer_get_my_booking_work_timeline() TO authenticated;
