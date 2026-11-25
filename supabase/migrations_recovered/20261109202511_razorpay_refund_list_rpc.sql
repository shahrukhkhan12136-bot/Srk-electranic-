CREATE OR REPLACE FUNCTION public.srk_admin_list_razorpay_refunds(p_limit integer DEFAULT 100)
RETURNS TABLE(id uuid,booking_id uuid,payment_id text,refund_id text,amount numeric,status text,provider_status text,reason text,last_error text,created_at timestamptz,updated_at timestamptz,processed_at timestamptz)
LANGUAGE plpgsql
STABLE SECURITY DEFINER
SET search_path=pg_catalog,public,auth,pg_temp
AS $function$
BEGIN
  IF auth.uid() IS NULL OR NOT public.is_srk_admin() THEN
    RAISE EXCEPTION 'Admin access required' USING ERRCODE='42501';
  END IF;
  RETURN QUERY SELECT r.id,r.booking_id,r.payment_id,r.refund_id,r.amount,r.status,r.provider_status,r.reason,r.last_error,r.created_at,r.updated_at,r.processed_at
  FROM public.srk_razorpay_refunds r ORDER BY r.created_at DESC
  LIMIT greatest(1,least(coalesce(p_limit,100),200));
END;
$function$;
REVOKE ALL ON FUNCTION public.srk_admin_list_razorpay_refunds(integer) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.srk_admin_list_razorpay_refunds(integer) TO authenticated;