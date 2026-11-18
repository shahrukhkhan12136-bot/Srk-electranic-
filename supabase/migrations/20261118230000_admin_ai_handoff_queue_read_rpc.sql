-- Main Admin read-only access to the private AI human-handoff queue.
-- No staff assignment, resolution, message access, or notification is enabled here.
-- Source-only; do not apply to a hosted database without explicit approval.
BEGIN;

CREATE OR REPLACE FUNCTION public.srk_admin_list_ai_handoff_queue(
  p_limit integer DEFAULT 50
)
RETURNS TABLE (
  handoff_id uuid,
  conversation_id uuid,
  owner_user_id uuid,
  module_key text,
  requested_by uuid,
  reason_code text,
  urgency text,
  summary text,
  status text,
  assigned_to uuid,
  created_at timestamptz,
  updated_at timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $function$
BEGIN
  IF auth.uid() IS NULL OR NOT public.is_srk_admin() THEN
    RAISE EXCEPTION 'ADMIN_PERMISSION_REQUIRED' USING ERRCODE='42501';
  END IF;

  IF p_limit IS NULL OR p_limit NOT BETWEEN 1 AND 100 THEN
    RAISE EXCEPTION 'INVALID_PAGE_LIMIT' USING ERRCODE='22023';
  END IF;

  RETURN QUERY
    SELECT
      q.id,
      q.conversation_id,
      c.owner_user_id,
      c.module_key,
      q.requested_by,
      q.reason_code,
      q.urgency,
      q.summary,
      q.status,
      q.assigned_to,
      q.created_at,
      q.updated_at
    FROM public.srk_ai_handoff_queue q
    JOIN public.srk_ai_conversations c ON c.id=q.conversation_id
    WHERE q.status IN ('queued','assigned')
    ORDER BY
      CASE q.urgency WHEN 'high' THEN 0 WHEN 'normal' THEN 1 ELSE 2 END,
      q.created_at ASC,
      q.id ASC
    LIMIT p_limit;
END;
$function$;

REVOKE ALL ON FUNCTION public.srk_admin_list_ai_handoff_queue(integer)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.srk_admin_list_ai_handoff_queue(integer)
  TO authenticated;

COMMIT;
