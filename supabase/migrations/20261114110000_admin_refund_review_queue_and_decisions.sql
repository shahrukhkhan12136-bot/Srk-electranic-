-- Admin refund review queue and guarded decision workflow.
-- No provider refund is initiated by these RPCs.
BEGIN;

CREATE OR REPLACE FUNCTION public.srk_admin_list_booking_refund_requests()
RETURNS TABLE (
  request_id uuid,
  booking_id uuid,
  customer_user_id uuid,
  customer_name text,
  customer_phone text,
  refund_amount numeric,
  reason text,
  request_status text,
  admin_note text,
  payment_method text,
  payment_status text,
  razorpay_payment_id text,
  labour_amount numeric,
  labour_amount_paise bigint,
  created_at timestamptz,
  updated_at timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO 'pg_catalog','public','auth','pg_temp'
AS $function$
BEGIN
  IF auth.uid() IS NULL OR NOT public.is_srk_admin() THEN
    RAISE EXCEPTION 'ADMIN_ACCESS_REQUIRED' USING ERRCODE='42501';
  END IF;

  RETURN QUERY
  SELECT r.id, r.booking_id, r.customer_user_id,
         b.customer_name::text, b.phone::text,
         r.amount, r.reason, r.status, r.admin_note,
         b.payment_method::text, b.payment_status::text,
         b.razorpay_payment_id::text,
         bill.labour_amount, bill.labour_amount_paise,
         r.created_at, r.updated_at
    FROM public.srk_booking_refund_requests r
    JOIN public.service_bookings b ON b.id=r.booking_id
    LEFT JOIN public.srk_booking_labour_bills bill ON bill.booking_id=r.booking_id
   ORDER BY
     CASE r.status WHEN 'requested' THEN 0 WHEN 'in_review' THEN 1
       WHEN 'unknown' THEN 2 WHEN 'processing' THEN 3 ELSE 4 END,
     r.created_at ASC
   LIMIT 300;
END;
$function$;

CREATE OR REPLACE FUNCTION public.srk_admin_decide_booking_refund_request(
  p_request_id uuid,
  p_decision text,
  p_admin_note text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'pg_catalog','public','auth','pg_temp'
AS $function$
DECLARE
  v_request public.srk_booking_refund_requests%ROWTYPE;
  v_decision text := lower(btrim(coalesce(p_decision,'')));
  v_note text := btrim(coalesce(p_admin_note,''));
BEGIN
  IF auth.uid() IS NULL OR NOT public.is_srk_admin() THEN
    RAISE EXCEPTION 'ADMIN_ACCESS_REQUIRED' USING ERRCODE='42501';
  END IF;
  IF p_request_id IS NULL OR v_decision NOT IN ('in_review','approved','rejected') THEN
    RAISE EXCEPTION 'INVALID_REFUND_REVIEW_ACTION' USING ERRCODE='22023';
  END IF;
  IF length(v_note) < 10 OR length(v_note) > 2000 THEN
    RAISE EXCEPTION 'ADMIN_NOTE_MUST_BE_10_TO_2000_CHARACTERS' USING ERRCODE='22023';
  END IF;

  SELECT * INTO v_request
    FROM public.srk_booking_refund_requests
   WHERE id=p_request_id
   FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'REFUND_REQUEST_NOT_FOUND' USING ERRCODE='P0002';
  END IF;

  IF v_request.status='requested' AND v_decision='in_review' THEN
    NULL;
  ELSIF v_request.status='in_review' AND v_decision IN ('approved','rejected') THEN
    NULL;
  ELSE
    RAISE EXCEPTION 'INVALID_REFUND_STATUS_TRANSITION: % -> %',v_request.status,v_decision
      USING ERRCODE='55000';
  END IF;

  UPDATE public.srk_booking_refund_requests
     SET status=v_decision,
         admin_note=v_note,
         decided_by=auth.uid(),
         updated_at=clock_timestamp()
   WHERE id=p_request_id;

  RETURN jsonb_build_object('success',true,'request_id',p_request_id,'status',v_decision);
END;
$function$;

REVOKE ALL ON FUNCTION public.srk_admin_list_booking_refund_requests() FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.srk_admin_decide_booking_refund_request(uuid,text,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.srk_admin_list_booking_refund_requests() TO authenticated;
GRANT EXECUTE ON FUNCTION public.srk_admin_decide_booking_refund_request(uuid,text,text) TO authenticated;

COMMIT;
