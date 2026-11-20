-- Fence in-flight handoff push attempts against Staff reassignment.
-- The worker revalidates each recipient immediately before the external push.
-- A push already accepted by the provider cannot be recalled.
BEGIN;

CREATE OR REPLACE FUNCTION private.srk_enqueue_ai_handoff_assignment_notification()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path='pg_catalog','public','srk_private','pg_temp'
AS $function$
DECLARE
  v_revision integer;
BEGIN
  IF NEW.status='assigned'
     AND (OLD.status IS DISTINCT FROM NEW.status
       OR OLD.assigned_to IS DISTINCT FROM NEW.assigned_to) THEN
    -- Fence every older event, including a worker that has claimed it but has
    -- not yet passed the recipient revalidation immediately before sending.
    UPDATE srk_private.srk_ai_handoff_notification_outbox
    SET delivery_status='dead',locked_until=NULL,
        last_error='Superseded by a newer Staff assignment',
        updated_at=clock_timestamp()
    WHERE handoff_id=NEW.id
      AND delivery_status IN ('pending','processing');

    UPDATE srk_private.srk_ai_handoff_subscription_deliveries d
    SET delivery_status='dead',locked_until=NULL,
        last_error='Superseded by a newer Staff assignment',
        updated_at=clock_timestamp()
    FROM srk_private.srk_ai_handoff_notification_outbox o
    WHERE o.id=d.outbox_id AND o.handoff_id=NEW.id
      AND d.delivery_status IN ('pending','processing');

    SELECT coalesce(max(o.assignment_revision),-1)+1
      INTO v_revision
    FROM srk_private.srk_ai_handoff_notification_outbox o
    WHERE o.handoff_id=NEW.id;

    INSERT INTO srk_private.srk_ai_handoff_notification_outbox
      (handoff_id,assignment_revision)
    VALUES (NEW.id,v_revision)
    ON CONFLICT (handoff_id,assignment_revision) DO NOTHING;
  END IF;
  RETURN NEW;
END;
$function$;

CREATE OR REPLACE FUNCTION public.srk_authorize_ai_handoff_notification_recipient(
  p_outbox_id uuid,
  p_user_id uuid
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path='pg_catalog','public','srk_private','pg_temp'
AS $function$
DECLARE
  v_revision integer;
  v_handoff_id uuid;
  v_status text;
  v_assigned_to uuid;
BEGIN
  IF auth.role() IS DISTINCT FROM 'service_role' THEN
    RAISE EXCEPTION 'Service role required' USING ERRCODE='42501';
  END IF;
  IF p_outbox_id IS NULL OR p_user_id IS NULL THEN
    RAISE EXCEPTION 'Outbox and recipient IDs required' USING ERRCODE='22023';
  END IF;

  SELECT o.assignment_revision,o.handoff_id,q.status,q.assigned_to
    INTO v_revision,v_handoff_id,v_status,v_assigned_to
  FROM srk_private.srk_ai_handoff_notification_outbox o
  JOIN public.srk_ai_handoff_queue q ON q.id=o.handoff_id
  WHERE o.id=p_outbox_id AND o.delivery_status='processing';

  IF NOT FOUND OR v_status NOT IN ('queued','assigned') THEN
    RETURN false;
  END IF;

  IF v_status='queued' THEN
    IF v_revision<>0 THEN RETURN false; END IF;
  ELSE
    IF v_revision=0 OR v_assigned_to IS DISTINCT FROM p_user_id
       OR v_revision IS DISTINCT FROM (
         SELECT max(o.assignment_revision)
         FROM srk_private.srk_ai_handoff_notification_outbox o
         WHERE o.handoff_id=v_handoff_id
       ) THEN
      RETURN false;
    END IF;
  END IF;

  RETURN EXISTS (
    SELECT 1 FROM public.srk_admin_staff s
    WHERE s.user_id=p_user_id AND s.status='active'
      AND (
        EXISTS (SELECT 1 FROM public.srk_admin_role_permissions rp
          WHERE rp.role_key=s.role_key AND rp.permission_key='ai.handoff.read')
        OR EXISTS (SELECT 1 FROM public.srk_admin_staff_permission_grants g
          WHERE g.staff_user_id=s.user_id AND g.permission_key='ai.handoff.read')
      )
  );
END;
$function$;

REVOKE ALL ON FUNCTION public.srk_authorize_ai_handoff_notification_recipient(uuid,uuid)
  FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.srk_authorize_ai_handoff_notification_recipient(uuid,uuid)
  TO service_role;

COMMIT;
