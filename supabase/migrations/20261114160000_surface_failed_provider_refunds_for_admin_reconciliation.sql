-- Keep a provider-declined refund visible to Admin instead of leaving its
-- customer request falsely stuck in "processing". No automatic retry is enabled:
-- a failed provider refund needs explicit Admin reconciliation/new intent.
BEGIN;

CREATE OR REPLACE FUNCTION public.srk_service_record_razorpay_refund_result(
  p_refund_record_id uuid,p_provider_refund_id text,p_provider_status text,p_error text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'pg_catalog','public','auth','pg_temp'
AS $function$
DECLARE
  v_ref public.srk_razorpay_refunds%ROWTYPE;
BEGIN
  IF auth.role() <> 'service_role' THEN
    RAISE EXCEPTION 'SERVICE_ROLE_REQUIRED' USING ERRCODE='42501';
  END IF;
  SELECT * INTO v_ref FROM public.srk_razorpay_refunds
   WHERE id=p_refund_record_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'REFUND_RECORD_NOT_FOUND' USING ERRCODE='P0002'; END IF;
  IF p_provider_refund_id IS NOT NULL AND p_provider_refund_id !~ '^rfnd_[A-Za-z0-9]+$' THEN
    RAISE EXCEPTION 'INVALID_PROVIDER_REFUND_ID' USING ERRCODE='22023';
  END IF;
  IF p_provider_status IS NOT NULL AND p_provider_status NOT IN ('pending','processed','failed') THEN
    RAISE EXCEPTION 'INVALID_PROVIDER_REFUND_STATUS' USING ERRCODE='22023';
  END IF;
  IF v_ref.refund_id IS NOT NULL AND p_provider_refund_id IS NOT NULL
     AND v_ref.refund_id<>p_provider_refund_id THEN
    RAISE EXCEPTION 'PROVIDER_REFUND_ID_CONFLICT' USING ERRCODE='55000';
  END IF;

  UPDATE public.srk_razorpay_refunds
     SET refund_id=coalesce(p_provider_refund_id,refund_id),
         provider_status=coalesce(p_provider_status,provider_status),
         status=CASE WHEN p_provider_status='failed' THEN 'failed' ELSE 'processing' END,
         last_error=left(nullif(p_error,''),500),
         updated_at=clock_timestamp()
   WHERE id=v_ref.id;

  IF p_provider_status='failed' THEN
    UPDATE public.srk_booking_refund_requests
       SET status='unknown',
           admin_note=left(concat_ws(E'\n',nullif(admin_note,''),'Provider reported refund failure; Admin reconciliation is required. ',left(coalesce(p_error,'No provider error detail.'),500)),2000),
           updated_at=clock_timestamp()
     WHERE refund_record_id=v_ref.id
       AND status IN ('approved','processing','unknown');
  END IF;

  RETURN jsonb_build_object('success',true,'refund_record_id',v_ref.id,
    'refund_id',coalesce(p_provider_refund_id,v_ref.refund_id),
    'provider_status',coalesce(p_provider_status,v_ref.provider_status),
    'internal_status',CASE WHEN p_provider_status='failed' THEN 'failed' ELSE 'processing' END,
    'customer_request_status',CASE WHEN p_provider_status='failed' THEN 'unknown' ELSE 'processing' END,
    'admin_reconciliation_required',p_provider_status='failed');
END;
$function$;

REVOKE ALL ON FUNCTION public.srk_service_record_razorpay_refund_result(uuid,text,text,text) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.srk_service_record_razorpay_refund_result(uuid,text,text,text) TO service_role;

COMMIT;
