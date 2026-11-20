-- Emit a fresh durable push event for every new Staff assignment/reassignment.
-- Existing queued-event retries remain independent from assignment-event retries.
BEGIN;

ALTER TABLE srk_private.srk_ai_handoff_notification_outbox
  ADD COLUMN IF NOT EXISTS assignment_revision integer NOT NULL DEFAULT 0
    CHECK (assignment_revision >= 0);

ALTER TABLE srk_private.srk_ai_handoff_notification_outbox
  DROP CONSTRAINT IF EXISTS srk_ai_handoff_notification_outbox_handoff_id_key;

ALTER TABLE srk_private.srk_ai_handoff_notification_outbox
  ADD CONSTRAINT srk_ai_handoff_notification_outbox_handoff_revision_key
  UNIQUE (handoff_id, assignment_revision);

CREATE OR REPLACE FUNCTION private.srk_enqueue_ai_handoff_notification()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path='pg_catalog','public','srk_private','pg_temp'
AS $function$
BEGIN
  IF NEW.status='queued' THEN
    INSERT INTO srk_private.srk_ai_handoff_notification_outbox
      (handoff_id,assignment_revision)
    VALUES (NEW.id,0)
    ON CONFLICT (handoff_id,assignment_revision) DO NOTHING;
  END IF;
  RETURN NEW;
END;
$function$;

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
    -- Supersede older events that have not started delivery, avoiding a stale
    -- queued/all-Staff alert alongside the fresh assigned-Staff alert.
    UPDATE srk_private.srk_ai_handoff_notification_outbox
    SET delivery_status='dead',locked_until=NULL,
        last_error='Superseded by a newer Staff assignment',
        updated_at=clock_timestamp()
    WHERE handoff_id=NEW.id AND delivery_status='pending';

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

REVOKE ALL ON FUNCTION private.srk_enqueue_ai_handoff_assignment_notification()
  FROM PUBLIC,anon,authenticated,service_role;

DROP TRIGGER IF EXISTS trg_srk_enqueue_ai_handoff_assignment_notification
  ON public.srk_ai_handoff_queue;
CREATE TRIGGER trg_srk_enqueue_ai_handoff_assignment_notification
  AFTER UPDATE OF status,assigned_to ON public.srk_ai_handoff_queue
  FOR EACH ROW
  WHEN (NEW.status='assigned' AND
    (OLD.status IS DISTINCT FROM NEW.status
      OR OLD.assigned_to IS DISTINCT FROM NEW.assigned_to))
  EXECUTE FUNCTION private.srk_enqueue_ai_handoff_assignment_notification();

COMMIT;
