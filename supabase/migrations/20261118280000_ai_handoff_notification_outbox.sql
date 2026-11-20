-- Durable notification event queue for AI handoffs.
-- This is a source-only foundation: it does not send push notifications or enable AI.
BEGIN;

CREATE TABLE IF NOT EXISTS srk_private.srk_ai_handoff_notification_outbox (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  handoff_id uuid NOT NULL UNIQUE
    REFERENCES public.srk_ai_handoff_queue(id) ON DELETE CASCADE,
  delivery_status text NOT NULL DEFAULT 'pending'
    CHECK (delivery_status IN ('pending','processing','delivered','dead')),
  attempt_count integer NOT NULL DEFAULT 0 CHECK (attempt_count >= 0),
  next_attempt_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  locked_until timestamptz,
  last_error text,
  created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  updated_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  delivered_at timestamptz
);
ALTER TABLE srk_private.srk_ai_handoff_notification_outbox ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE srk_private.srk_ai_handoff_notification_outbox
  FROM PUBLIC, anon, authenticated;
CREATE INDEX IF NOT EXISTS srk_ai_handoff_notification_due_idx
  ON srk_private.srk_ai_handoff_notification_outbox(next_attempt_at,created_at)
  WHERE delivery_status IN ('pending','processing');

CREATE OR REPLACE FUNCTION private.srk_enqueue_ai_handoff_notification()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path='pg_catalog','public','srk_private','pg_temp'
AS $function$
BEGIN
  IF NEW.status='queued' THEN
    INSERT INTO srk_private.srk_ai_handoff_notification_outbox(handoff_id)
    VALUES (NEW.id)
    ON CONFLICT (handoff_id) DO NOTHING;
  END IF;
  RETURN NEW;
END;
$function$;
REVOKE ALL ON FUNCTION private.srk_enqueue_ai_handoff_notification()
  FROM PUBLIC,anon,authenticated,service_role;
DROP TRIGGER IF EXISTS trg_srk_enqueue_ai_handoff_notification
  ON public.srk_ai_handoff_queue;
CREATE TRIGGER trg_srk_enqueue_ai_handoff_notification
  AFTER INSERT ON public.srk_ai_handoff_queue
  FOR EACH ROW EXECUTE FUNCTION private.srk_enqueue_ai_handoff_notification();

CREATE OR REPLACE FUNCTION public.srk_claim_ai_handoff_notification_outbox(
  p_limit integer DEFAULT 10
)
RETURNS TABLE(
  outbox_id uuid,
  handoff_id uuid,
  urgency text,
  created_at timestamptz,
  recipient_user_ids uuid[],
  attempt_count integer
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path='pg_catalog','public','srk_private','pg_temp'
AS $function$
BEGIN
  IF auth.role() IS DISTINCT FROM 'service_role' THEN
    RAISE EXCEPTION 'Service role required' USING ERRCODE='42501';
  END IF;
  RETURN QUERY
  WITH picked AS (
    SELECT o.id
    FROM srk_private.srk_ai_handoff_notification_outbox o
    WHERE o.attempt_count<8 AND o.next_attempt_at<=clock_timestamp()
      AND (o.delivery_status='pending'
        OR (o.delivery_status='processing'
          AND (o.locked_until IS NULL OR o.locked_until<clock_timestamp())))
    ORDER BY o.created_at,o.id
    FOR UPDATE SKIP LOCKED
    LIMIT greatest(1,least(coalesce(p_limit,10),25))
  ), claimed AS (
    UPDATE srk_private.srk_ai_handoff_notification_outbox o
    SET delivery_status='processing',attempt_count=o.attempt_count+1,
        locked_until=clock_timestamp()+interval '5 minutes',
        updated_at=clock_timestamp()
    FROM picked WHERE o.id=picked.id
    RETURNING o.id,o.handoff_id,o.attempt_count
  )
  SELECT c.id,c.handoff_id,q.urgency,q.created_at,
    CASE WHEN q.status='assigned' AND q.assigned_to IS NOT NULL
      THEN ARRAY[q.assigned_to]
      ELSE coalesce((
        SELECT array_agg(DISTINCT s.user_id ORDER BY s.user_id)
        FROM public.srk_admin_staff s
        WHERE s.status='active'
          AND (
            EXISTS (SELECT 1 FROM public.srk_admin_role_permissions rp
              WHERE rp.role_key=s.role_key AND rp.permission_key='ai.handoff.read')
            OR EXISTS (SELECT 1 FROM public.srk_admin_staff_permission_grants g
              WHERE g.staff_user_id=s.user_id AND g.permission_key='ai.handoff.read')
          )
      ),ARRAY[]::uuid[])
    END,
    c.attempt_count
  FROM claimed c
  JOIN public.srk_ai_handoff_queue q ON q.id=c.handoff_id
  WHERE q.status IN ('queued','assigned');
END;
$function$;
REVOKE ALL ON FUNCTION public.srk_claim_ai_handoff_notification_outbox(integer)
  FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.srk_claim_ai_handoff_notification_outbox(integer)
  TO service_role;

CREATE OR REPLACE FUNCTION public.srk_finish_ai_handoff_notification_outbox(
  p_outbox_id uuid,
  p_attempt_count integer,
  p_success boolean,
  p_error text DEFAULT NULL
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path='pg_catalog','public','srk_private','pg_temp'
AS $function$
DECLARE v_row srk_private.srk_ai_handoff_notification_outbox%ROWTYPE;
BEGIN
  IF auth.role() IS DISTINCT FROM 'service_role' THEN
    RAISE EXCEPTION 'Service role required' USING ERRCODE='42501';
  END IF;
  SELECT * INTO v_row
  FROM srk_private.srk_ai_handoff_notification_outbox
  WHERE id=p_outbox_id FOR UPDATE;
  IF NOT FOUND OR v_row.delivery_status<>'processing'
     OR v_row.attempt_count IS DISTINCT FROM p_attempt_count THEN
    RETURN false;
  END IF;
  IF p_success THEN
    UPDATE srk_private.srk_ai_handoff_notification_outbox
    SET delivery_status='delivered',delivered_at=clock_timestamp(),
        locked_until=NULL,last_error=NULL,updated_at=clock_timestamp()
    WHERE id=p_outbox_id;
  ELSIF v_row.attempt_count>=8 THEN
    UPDATE srk_private.srk_ai_handoff_notification_outbox
    SET delivery_status='dead',locked_until=NULL,
        last_error=left(coalesce(p_error,'AI handoff notification failed'),500),
        updated_at=clock_timestamp()
    WHERE id=p_outbox_id;
  ELSE
    UPDATE srk_private.srk_ai_handoff_notification_outbox
    SET delivery_status='pending',locked_until=NULL,
        next_attempt_at=clock_timestamp()+make_interval(
          secs=>least(3600,30*(2^least(v_row.attempt_count,7))::integer)),
        last_error=left(coalesce(p_error,'AI handoff notification failed'),500),
        updated_at=clock_timestamp()
    WHERE id=p_outbox_id;
  END IF;
  RETURN true;
END;
$function$;
REVOKE ALL ON FUNCTION public.srk_finish_ai_handoff_notification_outbox(uuid,integer,boolean,text)
  FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.srk_finish_ai_handoff_notification_outbox(uuid,integer,boolean,text)
  TO service_role;

COMMIT;
