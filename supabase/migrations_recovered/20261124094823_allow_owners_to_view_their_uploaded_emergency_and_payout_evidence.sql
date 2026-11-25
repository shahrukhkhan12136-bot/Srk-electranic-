CREATE POLICY srk_emergency_evidence_uploader_read
ON storage.objects
FOR SELECT
TO authenticated
USING (
 bucket_id='srk-emergency-evidence'
 AND EXISTS (
  SELECT 1 FROM public.srk_emergency_evidence e
  WHERE e.storage_bucket='srk-emergency-evidence'
   AND e.storage_path=objects.name
   AND e.uploaded_by=(SELECT auth.uid())
 )
);

CREATE POLICY srk_worker_payout_evidence_owner_read
ON storage.objects
FOR SELECT
TO authenticated
USING (
 bucket_id='srk-worker-payout-evidence'
 AND EXISTS (
  SELECT 1
  FROM public.srk_worker_payout_evidence e
  JOIN public.srk_worker_payout_requests p ON p.id=e.payout_request_id
  JOIN public.srk_worker_profiles w ON w.id=p.worker_id
  WHERE e.storage_path=objects.name
   AND w.user_id=(SELECT auth.uid())
 )
);