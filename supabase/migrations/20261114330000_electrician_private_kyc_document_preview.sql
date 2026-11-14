-- Return only the caller's own private KYC object path; Storage still enforces its SELECT policy.
CREATE OR REPLACE FUNCTION public.srk_electrician_get_my_verification_document_path(p_document_id uuid)
RETURNS text
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO 'pg_catalog','public','auth','pg_temp'
AS $function$
DECLARE v_path text;
BEGIN
  IF auth.uid() IS NULL OR p_document_id IS NULL THEN
    RAISE EXCEPTION 'Electrician login and document are required' USING ERRCODE='42501';
  END IF;
  SELECT d.storage_path INTO v_path
  FROM public.srk_electrician_verification_documents d
  JOIN public.electrician_profiles p ON p.id=d.electrician_profile_id
  WHERE d.id=p_document_id AND p.auth_user_id=auth.uid() AND p.user_id=auth.uid();
  IF v_path IS NULL THEN
    RAISE EXCEPTION 'Document not found or not owned by this electrician' USING ERRCODE='42501';
  END IF;
  RETURN v_path;
END;
$function$;
REVOKE ALL ON FUNCTION public.srk_electrician_get_my_verification_document_path(uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.srk_electrician_get_my_verification_document_path(uuid) TO authenticated;
