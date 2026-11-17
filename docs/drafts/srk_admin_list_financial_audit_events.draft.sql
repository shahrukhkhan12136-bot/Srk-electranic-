-- DRAFT ONLY — do not apply as a production migration.
-- Proposed Main Admin-only, metadata-only read API for financial audit events.
-- Kept under docs/drafts until field visibility/retention policy is approved.

CREATE OR REPLACE FUNCTION public.srk_admin_list_financial_audit_events(
  p_limit integer DEFAULT 50,
  p_before_created_at timestamptz DEFAULT NULL,
  p_before_id uuid DEFAULT NULL,
  p_entity_type text DEFAULT NULL,
  p_booking_id uuid DEFAULT NULL,
  p_actor_user_id uuid DEFAULT NULL,
  p_action text DEFAULT NULL
)
RETURNS TABLE (
  id uuid,
  entity_type text,
  entity_id uuid,
  booking_id uuid,
  action text,
  actor_user_id uuid,
  actor_role text,
  changed_fields text[],
  created_at timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $function$
BEGIN
  IF auth.uid() IS NULL OR NOT public.is_srk_admin() THEN
    RAISE EXCEPTION 'MAIN_ADMIN_ONLY' USING ERRCODE = '42501';
  END IF;

  IF (p_before_created_at IS NULL) <> (p_before_id IS NULL) THEN
    RAISE EXCEPTION 'AUDIT_CURSOR_REQUIRES_TIMESTAMP_AND_ID'
      USING ERRCODE = '22023';
  END IF;

  IF p_entity_type IS NOT NULL AND p_entity_type NOT IN (
    'booking','electrician_profile','electrician_application',
    'manual_payment','manual_refund','electrician_payout','razorpay_refund'
  ) THEN
    RAISE EXCEPTION 'INVALID_AUDIT_ENTITY_TYPE' USING ERRCODE = '22023';
  END IF;

  IF p_action IS NOT NULL AND p_action NOT IN ('created','updated','deleted') THEN
    RAISE EXCEPTION 'INVALID_AUDIT_ACTION' USING ERRCODE = '22023';
  END IF;

  RETURN QUERY
  SELECT e.id, e.entity_type, e.entity_id, e.booking_id, e.action,
         e.actor_user_id, e.actor_role, e.changed_fields, e.created_at
    FROM public.srk_admin_audit_events AS e
   WHERE (p_entity_type IS NULL OR e.entity_type = p_entity_type)
     AND (p_booking_id IS NULL OR e.booking_id = p_booking_id)
     AND (p_actor_user_id IS NULL OR e.actor_user_id = p_actor_user_id)
     AND (p_action IS NULL OR e.action = p_action)
     AND (
       p_before_created_at IS NULL
       OR (e.created_at, e.id) < (p_before_created_at, p_before_id)
     )
   ORDER BY e.created_at DESC, e.id DESC
   LIMIT GREATEST(1, LEAST(COALESCE(p_limit, 50), 100));
END;
$function$;

REVOKE ALL ON FUNCTION public.srk_admin_list_financial_audit_events(
  integer,timestamptz,uuid,text,uuid,uuid,text
) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.srk_admin_list_financial_audit_events(
  integer,timestamptz,uuid,text,uuid,uuid,text
) TO authenticated;

-- Deliberately do not grant SELECT on public.srk_admin_audit_events.
-- Deliberately do not return before_data/after_data or arbitrary JSON payloads.
