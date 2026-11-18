BEGIN;

DROP POLICY IF EXISTS srk_read_authorized_electrician_payouts
  ON public.srk_electrician_payouts;

CREATE POLICY srk_read_authorized_electrician_payouts
  ON public.srk_electrician_payouts
  FOR SELECT
  TO authenticated
  USING (
    (SELECT public.is_srk_admin())
    OR EXISTS (
      SELECT 1
      FROM public.electrician_profiles AS ep
      WHERE ep.id = srk_electrician_payouts.electrician_profile_id
        AND ep.user_id = (SELECT auth.uid())
        AND ep.auth_user_id = (SELECT auth.uid())
        AND ep.verification_status = 'approved'
        AND ep.active = true
    )
  );

COMMIT;
