CREATE POLICY srk_worker_kyc_owner_read
ON storage.objects
FOR SELECT
TO authenticated
USING (
 bucket_id='srk-worker-kyc'
 AND EXISTS (
  SELECT 1
  FROM public.srk_worker_documents d
  WHERE d.storage_path=objects.name
   AND (
    EXISTS (
     SELECT 1 FROM public.srk_worker_applications a
     WHERE a.id=d.application_id AND a.user_id=(SELECT auth.uid())
    )
    OR EXISTS (
     SELECT 1 FROM public.srk_worker_profiles w
     WHERE w.id=d.worker_id AND w.user_id=(SELECT auth.uid())
    )
   )
 )
);