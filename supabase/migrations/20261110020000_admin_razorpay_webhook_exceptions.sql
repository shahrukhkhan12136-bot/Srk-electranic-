-- Secure Admin-only access to Razorpay webhook reconciliation exceptions.
CREATE OR REPLACE FUNCTION public.srk_admin_list_razorpay_webhook_exceptions(p_limit integer DEFAULT 50)
RETURNS TABLE (
  event_id text,
  event_type text,
  razorpay_order_id text,
  razorpay_payment_id text,
  payment_amount_paise bigint,
  payment_currency text,
  processing_status text,
  reconciliation_reason text,
  received_at timestamptz,
  processed_at timestamptz,
  updated_at timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'public', 'auth', 'pg_temp'
AS $function$
BEGIN
  IF auth.uid() IS NULL OR NOT public.is_srk_admin() THEN
    RAISE EXCEPTION 'Admin permission required' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
    SELECT e.event_id, e.event_type, e.razorpay_order_id, e.razorpay_payment_id,
           e.payment_amount_paise, e.payment_currency, e.processing_status,
           e.reconciliation_reason, e.received_at, e.processed_at, e.updated_at
      FROM public.srk_razorpay_webhook_events AS e
     WHERE e.processing_status IN ('exception', 'processing_error')
     ORDER BY e.received_at DESC
     LIMIT GREATEST(1, LEAST(COALESCE(p_limit, 50), 100));
END;
$function$;

REVOKE ALL ON FUNCTION public.srk_admin_list_razorpay_webhook_exceptions(integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.srk_admin_list_razorpay_webhook_exceptions(integer) FROM anon;
GRANT EXECUTE ON FUNCTION public.srk_admin_list_razorpay_webhook_exceptions(integer) TO authenticated;
