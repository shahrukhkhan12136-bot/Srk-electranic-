-- Fence AI handoff outbox completion by its active lease and recover
-- workers that disappear after consuming the final attempt.

BEGIN;

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

  UPDATE srk_private.srk_ai_handoff_notification_outbox o
  SET delivery_status='dead',locked_until=NULL,
      last_error=coalesce(o.last_error,'Notification lease expired after maximum attempts'),
      updated_at=clock_timestamp()
  WHERE o.delivery_status='processing' AND o.attempt_count>=8
    AND (o.locked_until IS NULL OR o.locked_until<=clock_timestamp());

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
     OR v_row.attempt_count IS DISTINCT FROM p_attempt_count
     OR v_row.locked_until IS NULL OR v_row.locked_until<=clock_timestamp() THEN
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

COMMIT;
