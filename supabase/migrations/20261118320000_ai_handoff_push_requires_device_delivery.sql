-- Do not mark an AI handoff notification delivered when no device ledger rows exist.
-- This prevents a Staff account with no registered push device from being silently skipped.

BEGIN;

CREATE OR REPLACE FUNCTION public.srk_is_ai_handoff_subscription_delivery_complete(p_outbox_id uuid)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER
SET search_path='pg_catalog','public','srk_private','pg_temp'
AS $function$
BEGIN
  IF auth.role() IS DISTINCT FROM 'service_role' THEN
    RAISE EXCEPTION 'Service role required' USING ERRCODE='42501';
  END IF;
  RETURN EXISTS (
    SELECT 1 FROM srk_private.srk_ai_handoff_subscription_deliveries d
    WHERE d.outbox_id=p_outbox_id
  ) AND NOT EXISTS (
    SELECT 1 FROM srk_private.srk_ai_handoff_subscription_deliveries d
    WHERE d.outbox_id=p_outbox_id AND d.delivery_status<>'delivered'
  );
END;
$function$;
REVOKE ALL ON FUNCTION public.srk_is_ai_handoff_subscription_delivery_complete(uuid)
  FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.srk_is_ai_handoff_subscription_delivery_complete(uuid)
  TO service_role;

COMMIT;
