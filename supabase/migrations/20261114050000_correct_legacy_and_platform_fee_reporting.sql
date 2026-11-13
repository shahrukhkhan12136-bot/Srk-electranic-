-- Keep legacy commission and the new labour Platform Fee distinct in both
-- electrician earnings and Admin reporting. This corrects the UI/RPC contract
-- without changing any historical booking or ledger rows.

DROP FUNCTION IF EXISTS public.srk_get_my_earnings();

CREATE FUNCTION public.srk_get_my_earnings()
RETURNS TABLE(
  booking_id uuid,
  service_type text,
  booking_created_at timestamptz,
  booking_status text,
  payment_status text,
  amount_received numeric,
  commission_amount numeric,
  electrician_earning numeric,
  platform_fee_amount numeric,
  legacy_commission_amount numeric
)
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path TO 'pg_catalog','public','auth','pg_temp'
AS $function$
  SELECT
    b.id,
    b.service_type,
    b.created_at,
    b.status,
    b.payment_status,
    coalesce(b.amount_paid,0),
    CASE WHEN b.selected_category IS NOT NULL
      THEN coalesce(lb.platform_fee_amount,0)
      ELSE coalesce(b.commission_amount,0) END,
    CASE WHEN b.status='completed' AND b.payment_status='paid'
      THEN CASE WHEN b.selected_category IS NOT NULL
        THEN coalesce(lb.electrician_payable,0)
        ELSE greatest(coalesce(b.amount_paid,0)-coalesce(b.commission_amount,0),0) END
      ELSE 0 END,
    CASE WHEN b.selected_category IS NOT NULL
      THEN coalesce(lb.platform_fee_amount,0) ELSE 0 END,
    CASE WHEN b.selected_category IS NULL
      THEN coalesce(b.commission_amount,0) ELSE 0 END
  FROM public.electrician_profiles p
  JOIN public.service_bookings b ON b.assigned_electrician_id=p.id
  LEFT JOIN public.srk_booking_labour_bills lb ON lb.booking_id=b.id
  WHERE (p.user_id=auth.uid() OR p.auth_user_id=auth.uid())
    AND p.verification_status='approved'
  ORDER BY b.created_at DESC
  LIMIT 200;
$function$;

REVOKE ALL ON FUNCTION public.srk_get_my_earnings() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.srk_get_my_earnings() TO authenticated;

CREATE OR REPLACE FUNCTION public.srk_admin_commission_report()
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'pg_catalog','public','auth','pg_temp'
AS $function$
DECLARE v_result jsonb;
BEGIN
  IF auth.uid() IS NULL OR NOT public.is_srk_admin() THEN
    RAISE EXCEPTION 'Admin access required' USING ERRCODE='42501';
  END IF;

  WITH paid_completed AS (
    SELECT
      b.assigned_electrician_id,
      coalesce(b.amount_paid,0)::numeric AS gross,
      CASE WHEN b.selected_category IS NOT NULL
        THEN coalesce(lb.platform_fee_amount,0)::numeric ELSE 0::numeric END AS platform_fee,
      CASE WHEN b.selected_category IS NULL
        THEN coalesce(b.commission_amount,0)::numeric ELSE 0::numeric END AS legacy_commission
    FROM public.service_bookings b
    LEFT JOIN public.srk_booking_labour_bills lb ON lb.booking_id=b.id
    WHERE b.status='completed' AND b.payment_status='paid'
  ), totals AS (
    SELECT
      coalesce(sum(gross),0)::numeric AS collected,
      coalesce(sum(platform_fee),0)::numeric AS platform_fee,
      coalesce(sum(legacy_commission),0)::numeric AS legacy_commission,
      coalesce(sum(platform_fee+legacy_commission),0)::numeric AS total_commission,
      coalesce(sum(gross-platform_fee-legacy_commission),0)::numeric AS payable
    FROM paid_completed
  ), partners AS (
    SELECT
      p.id AS electrician_id,
      p.display_name,
      count(pc.*)::integer AS paid_completed_jobs,
      coalesce(sum(pc.gross),0)::numeric AS gross_received,
      coalesce(sum(pc.platform_fee+pc.legacy_commission),0)::numeric AS company_commission,
      coalesce(sum(pc.legacy_commission),0)::numeric AS legacy_commission,
      coalesce(sum(pc.platform_fee),0)::numeric AS platform_fee,
      coalesce(sum(pc.gross-pc.platform_fee-pc.legacy_commission),0)::numeric AS electrician_earning
    FROM public.electrician_profiles p
    LEFT JOIN paid_completed pc ON pc.assigned_electrician_id=p.id
    GROUP BY p.id,p.display_name
    ORDER BY p.display_name
  )
  SELECT jsonb_build_object(
    'total_collected',t.collected,
    'total_commission',t.total_commission,
    'total_platform_fee',t.platform_fee,
    'total_legacy_commission',t.legacy_commission,
    'total_electrician_payable',t.payable,
    'partners',coalesce((SELECT jsonb_agg(to_jsonb(partners)) FROM partners),'[]'::jsonb)
  ) INTO v_result FROM totals t;
  RETURN v_result;
END;
$function$;

REVOKE ALL ON FUNCTION public.srk_admin_commission_report() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.srk_admin_commission_report() TO authenticated;
