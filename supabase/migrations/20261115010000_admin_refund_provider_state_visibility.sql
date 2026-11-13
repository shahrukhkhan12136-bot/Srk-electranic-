-- Admin refund queue v3 exposes the actual provider-intent state.
-- Provider-confirmed failures are reconciliation-only; uncertain outcomes retain
-- their existing idempotency key and may be queried/retried by the Admin executor.
BEGIN;

CREATE OR REPLACE FUNCTION public.srk_admin_list_booking_refund_requests_v3()
RETURNS TABLE (
  request_id uuid, booking_id uuid, customer_user_id uuid,
  customer_name text, customer_phone text, refund_amount numeric,
  reason text, request_status text, admin_note text,
  payment_method text, payment_status text, razorpay_payment_id text,
  labour_amount numeric, labour_amount_paise bigint,
  manual_refund_status text, manual_refund_reference text,
  manual_refund_amount_paise bigint,
  provider_refund_id text, provider_refund_status text,
  provider_status text, provider_last_error text,
  provider_refund_created_at timestamptz, provider_refund_updated_at timestamptz,
  created_at timestamptz, updated_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path TO 'pg_catalog','public','auth','pg_temp'
AS $function$
BEGIN
  IF auth.uid() IS NULL OR NOT public.is_srk_admin() THEN
    RAISE EXCEPTION 'ADMIN_ACCESS_REQUIRED' USING ERRCODE='42501';
  END IF;

  RETURN QUERY
  SELECT r.id,r.booking_id,r.customer_user_id,b.customer_name::text,b.phone::text,
    r.amount,r.reason,r.status,r.admin_note,b.payment_method::text,b.payment_status::text,
    b.razorpay_payment_id::text,bill.labour_amount,bill.labour_amount_paise,
    mi.status,mi.transfer_reference,mi.amount_paise,
    ri.refund_id,ri.status,ri.provider_status,ri.last_error,ri.created_at,ri.updated_at,
    r.created_at,r.updated_at
  FROM public.srk_booking_refund_requests r
  JOIN public.service_bookings b ON b.id=r.booking_id
  LEFT JOIN public.srk_booking_labour_bills bill ON bill.booking_id=r.booking_id
  LEFT JOIN public.srk_manual_refund_intents mi ON mi.request_id=r.id
  LEFT JOIN public.srk_razorpay_refunds ri
    ON ri.id=r.refund_record_id AND ri.booking_id=r.booking_id
  ORDER BY
    CASE WHEN ri.status='failed' OR ri.provider_status='failed' THEN 0
      WHEN r.status='requested' THEN 1 WHEN r.status='in_review' THEN 2
      WHEN r.status='unknown' THEN 3 WHEN r.status='processing' THEN 4 ELSE 5 END,
    r.created_at ASC;
END;
$function$;

REVOKE ALL ON FUNCTION public.srk_admin_list_booking_refund_requests_v3() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.srk_admin_list_booking_refund_requests_v3() TO authenticated;

COMMIT;
