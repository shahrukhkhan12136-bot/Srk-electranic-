-- Paginated, customer-safe refund request history.
-- The zero-argument RPC remains for compatibility with older clients.
BEGIN;

CREATE OR REPLACE FUNCTION public.srk_customer_list_my_booking_refund_requests(
  p_limit integer,
  p_offset integer
)
RETURNS TABLE (
  id uuid,
  booking_id uuid,
  amount numeric,
  reason text,
  status text,
  created_at timestamptz,
  updated_at timestamptz,
  processed_at timestamptz
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
  SELECT r.id,r.booking_id,r.amount,r.reason,r.status,
         r.created_at,r.updated_at,r.processed_at
    FROM public.srk_booking_refund_requests r
   WHERE r.customer_user_id=v_uid
   ORDER BY r.created_at DESC,r.id DESC
   LIMIT v_limit OFFSET v_offset;
END;
$function$;

REVOKE ALL ON FUNCTION public.srk_customer_list_my_booking_refund_requests(integer,integer) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.srk_customer_list_my_booking_refund_requests(integer,integer) TO authenticated;

COMMIT;
