-- Allow an electrician with multiple owned profiles to read a bill
-- belonging to any of those profiles, without widening booking ownership.
CREATE OR REPLACE FUNCTION public.srk_electrician_get_labour_bill(p_booking_id uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path TO 'pg_catalog','public','auth','pg_temp'
AS $function$
DECLARE b public.srk_booking_labour_bills%ROWTYPE;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE='42501';
  END IF;

  SELECT bill.* INTO b
  FROM public.srk_booking_labour_bills bill
  WHERE bill.booking_id=p_booking_id
    AND EXISTS (
      SELECT 1
      FROM public.electrician_profiles profile
      WHERE profile.id=bill.electrician_profile_id
        AND (profile.user_id=auth.uid() OR profile.auth_user_id=auth.uid())
    );

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Final labour bill not found' USING ERRCODE='42501';
  END IF;

  RETURN jsonb_build_object(
    'booking_id',b.booking_id,
    'category',b.customer_work_category,
    'rate_tier',b.approved_rate_tier,
    'rate_card_version',b.rate_card_version,
    'rate8h_paise',b.rate8h_paise,
    'elapsed_seconds',b.elapsed_seconds,
    'billable_minutes',b.billable_minutes,
    'labour_amount_paise',b.labour_amount_paise,
    'labour_amount',b.labour_amount,
    'created_at',b.created_at
  );
END;
$function$;

REVOKE ALL ON FUNCTION public.srk_electrician_get_labour_bill(uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.srk_electrician_get_labour_bill(uuid) TO authenticated;
