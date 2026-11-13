-- Customer-safe, owner-scoped unified payment and refund history.
-- Keep the original RPC return signature: CREATE OR REPLACE cannot change OUT
-- columns without DROP, which would break dependent grants/views during rollout.
BEGIN;

CREATE OR REPLACE FUNCTION public.srk_customer_get_payment_history(
  p_limit integer DEFAULT 25,
  p_offset integer DEFAULT 0
)
RETURNS TABLE (
  event_id uuid,
  event_type text,
  booking_id uuid,
  amount numeric,
  status text,
  payment_method text,
  occurred_at timestamptz,
  description text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, public, auth, pg_temp
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_limit integer := least(greatest(coalesce(p_limit,25),1),50);
  v_offset integer := greatest(coalesce(p_offset,0),0);
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Customer login required' USING ERRCODE='42501';
  END IF;
  IF v_offset > 10000 THEN
    RAISE EXCEPTION 'Pagination offset is too large' USING ERRCODE='22023';
  END IF;

  RETURN QUERY
  WITH customer_bookings AS (
    SELECT b.id,b.payment_method,b.payment_status,b.amount_paid,
           b.payment_verified_at,b.created_at
    FROM public.service_bookings b
    WHERE b.customer_user_id=v_uid
  ), events AS (
    SELECT b.id AS event_id,
      'payment'::text AS event_type,b.id AS booking_id,
      b.amount_paid AS amount,
      CASE WHEN b.payment_status='refunded' THEN 'refunded'
           ELSE coalesce(nullif(b.payment_status,''),'recorded') END::text AS status,
      CASE
        WHEN lower(coalesce(b.payment_method,'')) IN ('cash','upi','card','online','razorpay','bank_transfer')
          THEN lower(b.payment_method)
        ELSE 'other'
      END::text AS payment_method,
      coalesce(b.payment_verified_at,b.created_at) AS occurred_at,
      'बुकिंग भुगतान'::text AS description
    FROM customer_bookings b
    WHERE b.payment_status IN ('paid','refunded')
      AND b.payment_verified_at IS NOT NULL
      AND coalesce(b.amount_paid,0)>0

    UNION ALL

    SELECT r.id,'refund_request'::text,r.booking_id,r.amount,r.status::text,
      NULL::text,coalesce(r.updated_at,r.created_at),
      'रिफंड अनुरोध'::text
    FROM public.srk_booking_refund_requests r
    JOIN customer_bookings b ON b.id=r.booking_id
    WHERE r.customer_user_id=v_uid

    UNION ALL

    SELECT rr.id,'refund'::text,rr.booking_id,rr.amount,rr.status::text,
      'razorpay'::text,coalesce(rr.processed_at,rr.updated_at,rr.created_at),
      'ऑनलाइन रिफंड'::text
    FROM public.srk_razorpay_refunds rr
    JOIN customer_bookings b ON b.id=rr.booking_id

    UNION ALL

    SELECT mp.id,'manual_payment'::text,mp.booking_id,mp.amount,
      'recorded'::text,
      CASE WHEN lower(coalesce(mp.payment_method,'')) IN ('cash','upi','card','bank_transfer')
        THEN lower(mp.payment_method) ELSE 'other' END::text,
      mp.recorded_at,'दर्ज किया गया भुगतान'::text
    FROM public.srk_manual_payment_entries mp
    JOIN customer_bookings b ON b.id=mp.booking_id

    UNION ALL

    SELECT mr.id,'manual_refund'::text,mp.booking_id,mr.amount,
      'recorded'::text,NULL::text,mr.recorded_at,
      'दर्ज किया गया रिफंड'::text
    FROM public.srk_manual_refund_entries mr
    JOIN public.srk_manual_payment_entries mp ON mp.id=mr.payment_entry_id
    JOIN customer_bookings b ON b.id=mp.booking_id
  )
  SELECT e.event_id,e.event_type,e.booking_id,e.amount,e.status,
         e.payment_method,e.occurred_at,e.description
  FROM events e
  ORDER BY e.occurred_at DESC NULLS LAST,e.event_id DESC
  LIMIT v_limit OFFSET v_offset;
END;
$function$;

REVOKE ALL ON FUNCTION public.srk_customer_get_payment_history(integer,integer) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.srk_customer_get_payment_history(integer,integer) TO authenticated;

COMMENT ON FUNCTION public.srk_customer_get_payment_history(integer,integer) IS
'Returns paginated payment/refund events only for auth.uid() customer bookings; preserves the original 8-column RPC contract and excludes admin notes, private provider metadata and other customers.';

COMMIT;
