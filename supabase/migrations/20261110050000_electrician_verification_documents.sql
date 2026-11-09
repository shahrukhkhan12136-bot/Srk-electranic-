-- Private electrician verification documents, review history and activation gate.
INSERT INTO storage.buckets (id,name,public,file_size_limit,allowed_mime_types)
VALUES (
  'srk-electrician-verification',
  'srk-electrician-verification',
  false,
  5242880,
  ARRAY['application/pdf','image/jpeg','image/png']
)
ON CONFLICT (id) DO UPDATE
SET public=false,file_size_limit=5242880,
    allowed_mime_types=ARRAY['application/pdf','image/jpeg','image/png'];

DROP POLICY IF EXISTS srk_electrician_verification_upload ON storage.objects;
CREATE POLICY srk_electrician_verification_upload
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (
  bucket_id='srk-electrician-verification'
  AND (storage.foldername(name))[1]=auth.uid()::text
  AND EXISTS (
    SELECT 1 FROM public.electrician_profiles p
    WHERE p.auth_user_id=auth.uid() AND p.user_id=auth.uid()
  )
);

DROP POLICY IF EXISTS srk_electrician_verification_read ON storage.objects;
CREATE POLICY srk_electrician_verification_read
ON storage.objects FOR SELECT TO authenticated
USING (
  bucket_id='srk-electrician-verification'
  AND (
    (storage.foldername(name))[1]=auth.uid()::text
    OR public.is_srk_admin()
  )
);

CREATE TABLE IF NOT EXISTS public.srk_electrician_verification_documents (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  electrician_profile_id uuid NOT NULL REFERENCES public.electrician_profiles(id) ON DELETE RESTRICT,
  application_id uuid REFERENCES public.electrician_applications(id) ON DELETE RESTRICT,
  document_type text NOT NULL CHECK (document_type IN ('identity_proof','address_proof','skill_certificate')),
  storage_path text NOT NULL UNIQUE,
  file_name text NOT NULL CHECK (length(file_name) BETWEEN 1 AND 180),
  mime_type text NOT NULL CHECK (mime_type IN ('application/pdf','image/jpeg','image/png')),
  file_size_bytes integer NOT NULL CHECK (file_size_bytes BETWEEN 1 AND 5242880),
  review_status text NOT NULL DEFAULT 'pending' CHECK (review_status IN ('pending','approved','rejected','needs_resubmission')),
  admin_note text CHECK (admin_note IS NULL OR length(admin_note)<=1000),
  uploaded_at timestamptz NOT NULL DEFAULT now(),
  reviewed_at timestamptz,
  reviewed_by uuid REFERENCES auth.users(id) ON DELETE RESTRICT
);
DROP POLICY IF EXISTS srk_electrician_verification_cleanup ON storage.objects;
CREATE POLICY srk_electrician_verification_cleanup
ON storage.objects FOR DELETE TO authenticated
USING (
  bucket_id='srk-electrician-verification'
  AND (storage.foldername(name))[1]=auth.uid()::text
  AND NOT EXISTS (
    SELECT 1 FROM public.srk_electrician_verification_documents d
    WHERE d.storage_path=storage.objects.name
  )
);

CREATE INDEX IF NOT EXISTS srk_electrician_docs_profile_idx
  ON public.srk_electrician_verification_documents(electrician_profile_id,document_type,uploaded_at DESC);
CREATE INDEX IF NOT EXISTS srk_electrician_docs_status_idx
  ON public.srk_electrician_verification_documents(review_status,uploaded_at DESC);
ALTER TABLE public.srk_electrician_verification_documents ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.srk_electrician_verification_documents FROM PUBLIC,anon,authenticated;

CREATE TABLE IF NOT EXISTS public.srk_electrician_verification_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  document_id uuid NOT NULL REFERENCES public.srk_electrician_verification_documents(id) ON DELETE RESTRICT,
  electrician_profile_id uuid NOT NULL REFERENCES public.electrician_profiles(id) ON DELETE RESTRICT,
  actor_user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
  actor_role text NOT NULL CHECK (actor_role IN ('electrician','admin')),
  event_type text NOT NULL CHECK (event_type IN ('uploaded','approved','rejected','needs_resubmission')),
  note text CHECK (note IS NULL OR length(note)<=1000),
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS srk_electrician_verification_events_doc_idx
  ON public.srk_electrician_verification_events(document_id,created_at ASC);
ALTER TABLE public.srk_electrician_verification_events ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.srk_electrician_verification_events FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION public.srk_electrician_submit_verification_document(
  p_document_type text,p_storage_path text,p_file_name text,p_mime_type text,p_file_size_bytes integer
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'pg_catalog','public','auth','storage','pg_temp'
AS $function$
DECLARE
  v_uid uuid:=auth.uid();
  v_profile public.electrician_profiles%rowtype;
  v_id uuid;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'Electrician login required' USING ERRCODE='42501'; END IF;
  IF p_document_type IS NULL OR p_document_type NOT IN ('identity_proof','address_proof','skill_certificate')
     OR p_storage_path IS NULL OR left(p_storage_path,pg_catalog.length(v_uid::text||'/'||p_document_type||'/')) <> v_uid::text||'/'||p_document_type||'/'
     OR p_file_name IS NULL OR length(p_file_name) NOT BETWEEN 1 AND 180
     OR p_mime_type IS NULL OR p_mime_type NOT IN ('application/pdf','image/jpeg','image/png')
     OR p_file_size_bytes IS NULL OR p_file_size_bytes NOT BETWEEN 1 AND 5242880 THEN
    RAISE EXCEPTION 'Invalid document metadata';
  END IF;
  SELECT * INTO v_profile FROM public.electrician_profiles
   WHERE auth_user_id=v_uid AND user_id=v_uid FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Linked electrician profile required' USING ERRCODE='42501'; END IF;
  -- A replacement identity/address document invalidates the previous approval until reviewed.
  IF p_document_type IN ('identity_proof','address_proof') THEN
    UPDATE public.electrician_profiles SET active=false
    WHERE id=v_profile.id AND active=true;
  END IF;
  PERFORM 1 FROM storage.objects
   WHERE bucket_id='srk-electrician-verification' AND name=p_storage_path;
  IF NOT FOUND THEN RAISE EXCEPTION 'Uploaded private document not found'; END IF;
  INSERT INTO public.srk_electrician_verification_documents
    (electrician_profile_id,application_id,document_type,storage_path,file_name,mime_type,file_size_bytes)
  VALUES
    (v_profile.id,v_profile.application_id,p_document_type,p_storage_path,
     p_file_name,p_mime_type,p_file_size_bytes)
  RETURNING id INTO v_id;
  INSERT INTO public.srk_electrician_verification_events
    (document_id,electrician_profile_id,actor_user_id,actor_role,event_type,note)
  VALUES (v_id,v_profile.id,v_uid,'electrician','uploaded','दस्तावेज़ जमा किया गया');
  RETURN v_id;
END;
$function$;

CREATE OR REPLACE FUNCTION public.srk_electrician_list_my_verification_documents()
RETURNS TABLE (
  id uuid,document_type text,file_name text,review_status text,
  admin_note text,uploaded_at timestamptz,reviewed_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path TO 'pg_catalog','public','auth','pg_temp'
AS $function$
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Electrician login required' USING ERRCODE='42501'; END IF;
  RETURN QUERY
  SELECT d.id,d.document_type,d.file_name,d.review_status,d.admin_note,d.uploaded_at,d.reviewed_at
  FROM public.srk_electrician_verification_documents d
  JOIN public.electrician_profiles p ON p.id=d.electrician_profile_id
  WHERE p.auth_user_id=auth.uid() AND p.user_id=auth.uid()
  ORDER BY d.uploaded_at DESC LIMIT 100;
END;
$function$;

CREATE OR REPLACE FUNCTION public.srk_admin_list_electrician_verification_documents(p_limit integer DEFAULT 200)
RETURNS TABLE (
  id uuid,electrician_profile_id uuid,application_id uuid,
  electrician_name text,electrician_phone text,state text,district text,pincode text,
  verification_status text,active boolean,document_type text,file_name text,
  storage_path text,mime_type text,file_size_bytes integer,review_status text,
  admin_note text,uploaded_at timestamptz,reviewed_at timestamptz,
  activity jsonb
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path TO 'pg_catalog','public','auth','pg_temp'
AS $function$
BEGIN
  IF auth.uid() IS NULL OR NOT public.is_srk_admin() THEN
    RAISE EXCEPTION 'Admin permission required' USING ERRCODE='42501';
  END IF;
  RETURN QUERY
  SELECT d.id,p.id,p.application_id,p.display_name,p.phone,p.state,p.district,p.pincode,
    p.verification_status,p.active,d.document_type,d.file_name,d.storage_path,d.mime_type,
    d.file_size_bytes,d.review_status,d.admin_note,d.uploaded_at,d.reviewed_at,
    COALESCE((SELECT jsonb_agg(jsonb_build_object(
      'actor_role',e.actor_role,'event_type',e.event_type,'note',e.note,'created_at',e.created_at)
      ORDER BY e.created_at ASC)
      FROM public.srk_electrician_verification_events e WHERE e.document_id=d.id),'[]'::jsonb)
  FROM public.srk_electrician_verification_documents d
  JOIN public.electrician_profiles p ON p.id=d.electrician_profile_id
  ORDER BY d.uploaded_at DESC
  LIMIT GREATEST(1,LEAST(COALESCE(p_limit,200),500));
END;
$function$;

CREATE OR REPLACE FUNCTION public.srk_admin_review_electrician_document(
  p_document_id uuid,p_review_status text,p_admin_note text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'pg_catalog','public','auth','pg_temp'
AS $function$
DECLARE
  v_admin uuid:=auth.uid();
  v_doc public.srk_electrician_verification_documents%rowtype;
  v_note text:=NULLIF(pg_catalog.btrim(p_admin_note),'');
BEGIN
  IF v_admin IS NULL OR NOT public.is_srk_admin() THEN
    RAISE EXCEPTION 'Admin permission required' USING ERRCODE='42501';
  END IF;
  IF p_document_id IS NULL OR p_review_status IS NULL OR p_review_status NOT IN ('approved','rejected','needs_resubmission')
     OR (p_admin_note IS NOT NULL AND length(p_admin_note)>1000) THEN
    RAISE EXCEPTION 'Invalid document review';
  END IF;
  SELECT * INTO v_doc FROM public.srk_electrician_verification_documents
   WHERE id=p_document_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Document not found'; END IF;
  IF p_review_status IN ('rejected','needs_resubmission') AND v_note IS NULL THEN
    RAISE EXCEPTION 'Reason required for rejected or resubmission status';
  END IF;
  UPDATE public.srk_electrician_verification_documents
  SET review_status=p_review_status,admin_note=v_note,reviewed_at=pg_catalog.now(),reviewed_by=v_admin
  WHERE id=p_document_id;
  IF p_review_status IN ('rejected','needs_resubmission')
     AND v_doc.document_type IN ('identity_proof','address_proof') THEN
    UPDATE public.electrician_profiles SET active=false
    WHERE id=v_doc.electrician_profile_id AND active=true;
  END IF;
  INSERT INTO public.srk_electrician_verification_events
    (document_id,electrician_profile_id,actor_user_id,actor_role,event_type,note)
  VALUES (p_document_id,v_doc.electrician_profile_id,v_admin,'admin',p_review_status,v_note);
  RETURN pg_catalog.jsonb_build_object('success',true,'document_id',p_document_id,'review_status',p_review_status);
END;
$function$;

CREATE OR REPLACE FUNCTION public.srk_admin_set_electrician_active(p_profile_id uuid,p_active boolean)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'pg_catalog','public','auth','pg_temp'
AS $function$
DECLARE v_profile public.electrician_profiles%rowtype;
BEGIN
  IF auth.uid() IS NULL OR NOT public.is_srk_admin() THEN
    RAISE EXCEPTION 'Admin permission required' USING ERRCODE='42501';
  END IF;
  IF p_profile_id IS NULL OR p_active IS NULL THEN RAISE EXCEPTION 'Profile and active state required'; END IF;
  SELECT * INTO v_profile FROM public.electrician_profiles WHERE id=p_profile_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Electrician profile not found'; END IF;
  IF p_active THEN
    -- Serialize activation with document reviews and replacement uploads.
    PERFORM 1 FROM public.srk_electrician_verification_documents
    WHERE electrician_profile_id=v_profile.id
      AND document_type IN ('identity_proof','address_proof')
    ORDER BY uploaded_at DESC FOR SHARE;
    IF v_profile.verification_status<>'approved' OR v_profile.auth_user_id IS NULL
       OR v_profile.user_id IS DISTINCT FROM v_profile.auth_user_id THEN
      RAISE EXCEPTION 'Electrician must be Admin-approved and OTP-linked before activation';
    END IF;
    IF EXISTS (
      SELECT required.doc_type
      FROM (VALUES ('identity_proof'::text),('address_proof'::text)) required(doc_type)
      LEFT JOIN LATERAL (
        SELECT d.review_status FROM public.srk_electrician_verification_documents d
        WHERE d.electrician_profile_id=v_profile.id AND d.document_type=required.doc_type
        ORDER BY d.uploaded_at DESC LIMIT 1
      ) latest ON true
      WHERE latest.review_status IS DISTINCT FROM 'approved'
    ) THEN
      RAISE EXCEPTION 'Latest identity and address proof documents must both be approved before activation';
    END IF;
  END IF;
  UPDATE public.electrician_profiles SET active=p_active WHERE id=p_profile_id;
  RETURN pg_catalog.jsonb_build_object('success',true,'active',p_active);
END;
$function$;

REVOKE ALL ON FUNCTION public.srk_electrician_submit_verification_document(text,text,text,text,integer) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.srk_electrician_submit_verification_document(text,text,text,text,integer) TO authenticated;
REVOKE ALL ON FUNCTION public.srk_electrician_list_my_verification_documents() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.srk_electrician_list_my_verification_documents() TO authenticated;
REVOKE ALL ON FUNCTION public.srk_admin_list_electrician_verification_documents(integer) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.srk_admin_list_electrician_verification_documents(integer) TO authenticated;
REVOKE ALL ON FUNCTION public.srk_admin_review_electrician_document(uuid,text,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.srk_admin_review_electrician_document(uuid,text,text) TO authenticated;
REVOKE ALL ON FUNCTION public.srk_admin_set_electrician_active(uuid,boolean) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.srk_admin_set_electrician_active(uuid,boolean) TO authenticated;

-- Remove direct profile activation privilege; Admin activation now uses the guarded RPC.
REVOKE UPDATE ON TABLE public.electrician_profiles FROM authenticated;
REVOKE UPDATE (active) ON TABLE public.electrician_profiles FROM authenticated;
