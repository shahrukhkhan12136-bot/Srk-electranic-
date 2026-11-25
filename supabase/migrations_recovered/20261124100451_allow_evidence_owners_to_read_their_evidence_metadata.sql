CREATE POLICY srk_emergency_evidence_uploader_read
ON public.srk_emergency_evidence
FOR SELECT TO authenticated
USING (
 uploaded_by=(SELECT auth.uid())
 OR public.srk_has_admin_permission('support.manage')
);

GRANT SELECT ON TABLE public.srk_emergency_evidence TO authenticated;

CREATE POLICY srk_worker_payout_evidence_owner_read
ON public.srk_worker_payout_evidence
FOR SELECT TO authenticated
USING (
 public.srk_has_admin_permission('payouts.manage')
 OR EXISTS (
  SELECT 1
  FROM public.srk_worker_payout_requests p
  JOIN public.srk_worker_profiles w ON w.id=p.worker_id
  WHERE p.id=srk_worker_payout_evidence.payout_request_id
   AND w.user_id=(SELECT auth.uid())
 )
);