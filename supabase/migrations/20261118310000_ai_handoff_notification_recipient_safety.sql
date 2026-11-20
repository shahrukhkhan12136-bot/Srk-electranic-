-- Do not send handoff alerts after resolution. Assigned alerts go only to
-- the still-active assigned Staff member with explicit read permission.

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

  -- A handoff resolved before notification delivery needs no staff alert.
  UPDATE srk_private.srk_ai_handoff_notification_outbox o
  SET delivery_status='dead',locked_until=NULL,
      last_error='Handoff is no longer active; notification suppressed',
      updated_at=clock_timestamp()
  FROM public.srk_ai_handoff_queue q
  WHERE q.id=o.handoff_id AND q.status NOT IN ('queued','assigned')
    AND o.delivery_status IN ('pending','processing');

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
    JOIN public.srk_ai_handoff_queue q ON q.id=o.handoff_id
    WHERE q.status IN ('queued','assigned')
      AND o.attempt_count<8 AND o.next_attempt_at<=clock_timestamp()
      AND (o.delivery_status='pending'
        OR (o.delivery_status='processing'
          AND (o.locked_until IS NULL OR o.locked_until<clock_timestamp())))
    ORDER BY o.created_at,o.id
    FOR UPDATE OF o SKIP LOCKED
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
    CASE WHEN q.status='assigned' THEN
      CASE WHEN q.assigned_to IS NOT NULL AND EXISTS (
        SELECT 1 FROM public.srk_admin_staff s
        WHERE s.user_id=q.assigned_to AND s.status='active'
          AND (
            EXISTS (SELECT 1 FROM public.srk_admin_role_permissions rp
              WHERE rp.role_key=s.role_key AND rp.permission_key='ai.handoff.read')
            OR EXISTS (SELECT 1 FROM public.srk_admin_staff_permission_grants g
              WHERE g.staff_user_id=s.user_id AND g.permission_key='ai.handoff.read')
          )
      ) THEN ARRAY[q.assigned_to] ELSE ARRAY[]::uuid[] END
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
  JOIN public.srk_ai_handoff_queue q ON q.id=c.handoff_id;
END;
$function$;

COMMIT;
