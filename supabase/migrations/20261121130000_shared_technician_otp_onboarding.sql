-- Shared Technician OTP-first application and KYC foundation.
-- Feature Branch source only. Do not apply to Production without separate approval.
-- Requires 20261121120000_unified_technician_identity_completion_cycle.sql.

ALTER TABLE public.srk_technicians
  ADD COLUMN IF NOT EXISTS verified_phone text,
  ADD COLUMN IF NOT EXISTS phone_verified_at timestamptz;

DO $checks$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='srk_technicians_verified_phone_format') THEN
    ALTER TABLE public.srk_technicians
      ADD CONSTRAINT srk_technicians_verified_phone_format
      CHECK (verified_phone IS NULL OR verified_phone ~ '^[0-9]{10}$');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='srk_technicians_verified_phone_timestamp_pair') THEN
    ALTER TABLE public.srk_technicians
      ADD CONSTRAINT srk_technicians_verified_phone_timestamp_pair
      CHECK ((verified_phone IS NULL) = (phone_verified_at IS NULL));
  END IF;
END;
$checks$;

CREATE UNIQUE INDEX IF NOT EXISTS srk_technicians_verified_phone_uidx
  ON public.srk_technicians(verified_phone) WHERE verified_phone IS NOT NULL;

CREATE TABLE IF NOT EXISTS public.srk_service_categories (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  category_code text NOT NULL UNIQUE CHECK (category_code ~ '^[a-z][a-z0-9_]{1,59}$'),
  display_name text NOT NULL CHECK (length(btrim(display_name)) BETWEEN 2 AND 100),
  is_active boolean NOT NULL DEFAULT true,
  sort_order integer NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  created_by uuid REFERENCES auth.users(id) ON DELETE RESTRICT
);

CREATE TABLE IF NOT EXISTS public.srk_service_skills (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  category_id uuid NOT NULL REFERENCES public.srk_service_categories(id) ON DELETE RESTRICT,
  skill_code text NOT NULL UNIQUE CHECK (skill_code ~ '^[a-z][a-z0-9_]{1,79}$'),
  display_name text NOT NULL CHECK (length(btrim(display_name)) BETWEEN 2 AND 100),
  is_active boolean NOT NULL DEFAULT true,
  requires_separate_assessment boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  created_by uuid REFERENCES auth.users(id) ON DELETE RESTRICT,
  UNIQUE (category_id, display_name)
);

INSERT INTO public.srk_service_categories(category_code,display_name,sort_order)
VALUES
 ('electrician','Electrician',1),
 ('plumber','Plumber',2),
 ('painter','Painter',3),
 ('ac_fridge_technician','AC + Fridge Technician',4),
 ('motor_pump','Motor & Pump',5),
 ('cooler','Cooler',6)
ON CONFLICT (category_code) DO NOTHING;

INSERT INTO public.srk_service_skills(category_id,skill_code,display_name,requires_separate_assessment)
SELECT c.id,v.skill_code,v.display_name,v.requires_separate_assessment
FROM (VALUES
 ('electrician','residential_wiring','Residential Wiring',false),
 ('electrician','factory_wiring','Factory / Industrial Wiring',false),
 ('plumber','residential_plumbing','Residential Plumbing',false),
 ('plumber','industrial_plumbing','Industrial Plumbing',false),
 ('painter','interior_painting','Interior Painting',false),
 ('painter','exterior_painting','Exterior Painting',false),
 ('ac_fridge_technician','ac_technician','AC Technician',true),
 ('ac_fridge_technician','fridge_technician','Fridge Technician',true),
 ('motor_pump','motor_winding','Motor Winding',false),
 ('motor_pump','pump_repair','Pump Repair',false),
 ('cooler','cooler_repair','Cooler Repair',false),
 ('cooler','cooler_motor_winding','Cooler Motor Winding',false)
) AS v(category_code,skill_code,display_name,requires_separate_assessment)
JOIN public.srk_service_categories c ON c.category_code=v.category_code
ON CONFLICT (skill_code) DO NOTHING;

CREATE TABLE IF NOT EXISTS public.srk_technician_applications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  technician_id uuid NOT NULL REFERENCES public.srk_technicians(id) ON DELETE RESTRICT,
  full_name text NOT NULL CHECK (length(btrim(full_name)) BETWEEN 2 AND 100),
  address text NOT NULL CHECK (length(btrim(address)) BETWEEN 5 AND 500),
  district text NOT NULL CHECK (length(btrim(district)) BETWEEN 2 AND 80),
  state text NOT NULL CHECK (length(btrim(state)) BETWEEN 2 AND 80),
  pincode text NOT NULL CHECK (pincode ~ '^[0-9]{6}$'),
  experience_years integer NOT NULL CHECK (experience_years BETWEEN 0 AND 60),
  about text CHECK (about IS NULL OR length(about) <= 2000),
  status text NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending','under_review','approved','rejected')),
  rejection_reason text CHECK (rejection_reason IS NULL OR length(btrim(rejection_reason)) BETWEEN 5 AND 1000),
  submitted_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  reviewed_at timestamptz,
  reviewed_by uuid REFERENCES auth.users(id) ON DELETE RESTRICT,
  created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  updated_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  CHECK ((status='rejected') = (rejection_reason IS NOT NULL)),
  CHECK ((reviewed_at IS NULL) = (reviewed_by IS NULL))
);

CREATE UNIQUE INDEX IF NOT EXISTS srk_technician_one_open_application_uidx
  ON public.srk_technician_applications(technician_id)
  WHERE status IN ('pending','under_review');
CREATE INDEX IF NOT EXISTS srk_technician_applications_review_queue_idx
  ON public.srk_technician_applications(status,submitted_at DESC);

CREATE TABLE IF NOT EXISTS public.srk_technician_application_categories (
  application_id uuid NOT NULL REFERENCES public.srk_technician_applications(id) ON DELETE RESTRICT,
  category_id uuid NOT NULL REFERENCES public.srk_service_categories(id) ON DELETE RESTRICT,
  PRIMARY KEY(application_id,category_id)
);

CREATE TABLE IF NOT EXISTS public.srk_technician_application_skills (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  application_id uuid NOT NULL REFERENCES public.srk_technician_applications(id) ON DELETE RESTRICT,
  skill_id uuid NOT NULL REFERENCES public.srk_service_skills(id) ON DELETE RESTRICT,
  review_status text NOT NULL DEFAULT 'pending'
    CHECK (review_status IN ('pending','approved','rejected','needs_resubmission')),
  admin_note text CHECK (admin_note IS NULL OR length(admin_note)<=1000),
  reviewed_at timestamptz,
  reviewed_by uuid REFERENCES auth.users(id) ON DELETE RESTRICT,
  UNIQUE(application_id,skill_id),
  CHECK ((review_status='pending' AND reviewed_at IS NULL AND reviewed_by IS NULL)
      OR (review_status<>'pending' AND reviewed_at IS NOT NULL AND reviewed_by IS NOT NULL))
);

CREATE TABLE IF NOT EXISTS public.srk_technician_application_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  application_id uuid NOT NULL REFERENCES public.srk_technician_applications(id) ON DELETE RESTRICT,
  technician_id uuid NOT NULL REFERENCES public.srk_technicians(id) ON DELETE RESTRICT,
  actor_user_id uuid REFERENCES auth.users(id) ON DELETE RESTRICT,
  actor_role text NOT NULL CHECK (actor_role IN ('technician','admin','system')),
  event_type text NOT NULL CHECK (event_type IN ('submitted','resubmitted','under_review','skill_reviewed','approved','rejected')),
  note text CHECK (note IS NULL OR length(note)<=1000),
  snapshot jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT clock_timestamp()
);
CREATE INDEX IF NOT EXISTS srk_technician_application_events_recent_idx
  ON public.srk_technician_application_events(application_id,created_at DESC,id DESC);

CREATE TABLE IF NOT EXISTS public.srk_technician_kyc_documents (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  application_id uuid NOT NULL REFERENCES public.srk_technician_applications(id) ON DELETE RESTRICT,
  uploaded_by uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
  document_type text NOT NULL CHECK (document_type IN ('identity_proof','address_proof','skill_certificate')),
  application_skill_id uuid REFERENCES public.srk_technician_application_skills(id) ON DELETE RESTRICT,
  storage_path text NOT NULL UNIQUE CHECK (length(storage_path) BETWEEN 10 AND 255),
  file_name text NOT NULL CHECK (length(btrim(file_name)) BETWEEN 1 AND 180),
  mime_type text NOT NULL CHECK (mime_type IN ('application/pdf','image/jpeg','image/png')),
  file_size_bytes bigint NOT NULL CHECK (file_size_bytes BETWEEN 1 AND 5242880),
  review_status text NOT NULL DEFAULT 'pending'
    CHECK (review_status IN ('pending','approved','rejected','needs_resubmission')),
  admin_note text CHECK (admin_note IS NULL OR length(admin_note)<=1000),
  uploaded_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  reviewed_at timestamptz,
  reviewed_by uuid REFERENCES auth.users(id) ON DELETE RESTRICT,
  CHECK ((review_status='pending' AND reviewed_at IS NULL AND reviewed_by IS NULL)
      OR (review_status<>'pending' AND reviewed_at IS NOT NULL AND reviewed_by IS NOT NULL)),
  CHECK ((document_type='skill_certificate') OR application_skill_id IS NULL)
);
CREATE INDEX IF NOT EXISTS srk_technician_kyc_application_idx
  ON public.srk_technician_kyc_documents(application_id,document_type,uploaded_at DESC,id DESC);
CREATE INDEX IF NOT EXISTS srk_technician_kyc_review_queue_idx
  ON public.srk_technician_kyc_documents(review_status,uploaded_at DESC);

CREATE TABLE IF NOT EXISTS public.srk_technician_kyc_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  document_id uuid NOT NULL REFERENCES public.srk_technician_kyc_documents(id) ON DELETE RESTRICT,
  application_id uuid NOT NULL REFERENCES public.srk_technician_applications(id) ON DELETE RESTRICT,
  actor_user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
  actor_role text NOT NULL CHECK (actor_role IN ('technician','admin')),
  event_type text NOT NULL CHECK (event_type IN ('submitted','approved','rejected','needs_resubmission')),
  note text CHECK (note IS NULL OR length(note)<=1000),
  created_at timestamptz NOT NULL DEFAULT clock_timestamp()
);
CREATE INDEX IF NOT EXISTS srk_technician_kyc_events_document_idx
  ON public.srk_technician_kyc_events(document_id,created_at DESC,id DESC);

ALTER TABLE public.srk_service_categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.srk_service_skills ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.srk_technician_applications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.srk_technician_application_categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.srk_technician_application_skills ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.srk_technician_application_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.srk_technician_kyc_documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.srk_technician_kyc_events ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE public.srk_service_categories,public.srk_service_skills,
  public.srk_technician_applications,public.srk_technician_application_categories,
  public.srk_technician_application_skills,public.srk_technician_application_events,
  public.srk_technician_kyc_documents,public.srk_technician_kyc_events
FROM PUBLIC,anon,authenticated;
GRANT ALL ON TABLE public.srk_service_categories,public.srk_service_skills,
  public.srk_technician_applications,public.srk_technician_application_categories,
  public.srk_technician_application_skills,public.srk_technician_application_events,
  public.srk_technician_kyc_documents,public.srk_technician_kyc_events TO service_role;

CREATE OR REPLACE FUNCTION public.srk_guard_technician_history_append_only()
RETURNS trigger LANGUAGE plpgsql SET search_path='' AS $function$
BEGIN
  RAISE EXCEPTION 'TECHNICIAN_HISTORY_IS_APPEND_ONLY' USING ERRCODE='55000';
END;
$function$;
REVOKE ALL ON FUNCTION public.srk_guard_technician_history_append_only() FROM PUBLIC,anon,authenticated;

DROP TRIGGER IF EXISTS srk_technician_application_events_append_only ON public.srk_technician_application_events;
CREATE TRIGGER srk_technician_application_events_append_only
BEFORE UPDATE OR DELETE ON public.srk_technician_application_events
FOR EACH ROW EXECUTE FUNCTION public.srk_guard_technician_history_append_only();
DROP TRIGGER IF EXISTS srk_technician_kyc_events_append_only ON public.srk_technician_kyc_events;
CREATE TRIGGER srk_technician_kyc_events_append_only
BEFORE UPDATE OR DELETE ON public.srk_technician_kyc_events
FOR EACH ROW EXECUTE FUNCTION public.srk_guard_technician_history_append_only();

INSERT INTO storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
VALUES ('srk-technician-verification','srk-technician-verification',false,5242880,
  ARRAY['application/pdf','image/jpeg','image/png']::text[])
ON CONFLICT(id) DO UPDATE SET public=false,file_size_limit=EXCLUDED.file_size_limit,
  allowed_mime_types=EXCLUDED.allowed_mime_types;

DROP POLICY IF EXISTS srk_technician_kyc_owner_upload ON storage.objects;
CREATE POLICY srk_technician_kyc_owner_upload ON storage.objects
FOR INSERT TO authenticated
WITH CHECK (
  bucket_id='srk-technician-verification'
  AND (storage.foldername(name))[1]=auth.uid()::text
  AND (storage.foldername(name))[2] IN ('identity_proof','address_proof','skill_certificate')
  AND EXISTS (SELECT 1 FROM public.srk_technicians t
    WHERE t.auth_user_id=auth.uid() AND t.verified_phone IS NOT NULL)
);
DROP POLICY IF EXISTS srk_technician_kyc_owner_read ON storage.objects;
CREATE POLICY srk_technician_kyc_owner_read ON storage.objects
FOR SELECT TO authenticated
USING (
  bucket_id='srk-technician-verification'
  AND (public.is_srk_admin() OR (
    (storage.foldername(name))[1]=auth.uid()::text
    AND EXISTS (SELECT 1 FROM public.srk_technicians t
      WHERE t.auth_user_id=auth.uid() AND t.verified_phone IS NOT NULL)
  ))
);

CREATE OR REPLACE FUNCTION public.srk_technician_submit_application(
  p_full_name text,p_address text,p_district text,p_state text,p_pincode text,
  p_experience_years integer,p_about text,p_category_codes text[],p_skill_codes text[]
)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $function$
DECLARE
  v_uid uuid:=auth.uid();
  v_auth_phone text;
  v_verified_at timestamptz;
  v_phone text;
  v_technician_id uuid;
  v_application_id uuid;
  v_count integer;
  v_categories uuid[];
  v_skills uuid[];
  v_has_rejected boolean:=false;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'TECHNICIAN_LOGIN_REQUIRED' USING ERRCODE='42501'; END IF;
  SELECT u.phone,u.phone_confirmed_at INTO v_auth_phone,v_verified_at
    FROM auth.users u WHERE u.id=v_uid;
  v_phone:=right(regexp_replace(coalesce(v_auth_phone,''),'[^0-9]','','g'),10);
  IF v_verified_at IS NULL OR length(v_phone)<>10 THEN
    RAISE EXCEPTION 'OTP_VERIFIED_MOBILE_REQUIRED' USING ERRCODE='42501';
  END IF;
  IF p_full_name IS NULL OR length(btrim(p_full_name)) NOT BETWEEN 2 AND 100
     OR p_address IS NULL OR length(btrim(p_address)) NOT BETWEEN 5 AND 500
     OR p_district IS NULL OR length(btrim(p_district)) NOT BETWEEN 2 AND 80
     OR p_state IS NULL OR length(btrim(p_state)) NOT BETWEEN 2 AND 80
     OR p_pincode IS NULL OR p_pincode !~ '^[0-9]{6}$'
     OR p_experience_years IS NULL OR p_experience_years NOT BETWEEN 0 AND 60
     OR (p_about IS NOT NULL AND length(p_about)>2000)
     OR p_category_codes IS NULL OR cardinality(p_category_codes) NOT BETWEEN 1 AND 20
     OR p_skill_codes IS NULL OR cardinality(p_skill_codes)<1 THEN
    RAISE EXCEPTION 'INVALID_TECHNICIAN_APPLICATION' USING ERRCODE='22023';
  END IF;

  SELECT count(*),array_agg(c.id ORDER BY c.category_code)
    INTO v_count,v_categories
  FROM public.srk_service_categories c
  WHERE c.is_active AND c.category_code=ANY(p_category_codes);
  IF v_count<>cardinality(p_category_codes) THEN
    RAISE EXCEPTION 'UNKNOWN_DUPLICATE_OR_INACTIVE_TECHNICIAN_CATEGORY' USING ERRCODE='22023';
  END IF;

  SELECT count(*),array_agg(s.id ORDER BY s.skill_code)
    INTO v_count,v_skills
  FROM public.srk_service_skills s
  JOIN public.srk_service_categories c ON c.id=s.category_id
  WHERE s.is_active AND c.is_active
    AND s.skill_code=ANY(p_skill_codes)
    AND c.category_code=ANY(p_category_codes);
  IF v_count<>cardinality(p_skill_codes) THEN
    RAISE EXCEPTION 'UNKNOWN_DUPLICATE_OR_UNSELECTED_TECHNICIAN_SKILL' USING ERRCODE='22023';
  END IF;
  IF EXISTS (
    SELECT 1 FROM unnest(p_category_codes) AS selected(category_code)
    WHERE NOT EXISTS (
      SELECT 1 FROM public.srk_service_skills s
      JOIN public.srk_service_categories c ON c.id=s.category_id
      WHERE c.category_code=selected.category_code AND s.is_active
        AND s.skill_code=ANY(p_skill_codes)
    )
  ) THEN
    RAISE EXCEPTION 'EACH_SELECTED_CATEGORY_REQUIRES_AT_LEAST_ONE_SKILL' USING ERRCODE='22023';
  END IF;

  SELECT EXISTS (SELECT 1 FROM public.srk_technician_applications a
    WHERE a.technician_id=(SELECT t.id FROM public.srk_technicians t WHERE t.auth_user_id=v_uid)
      AND a.status='rejected') INTO v_has_rejected;

  INSERT INTO public.srk_technicians(auth_user_id,primary_phone,verified_phone,phone_verified_at,account_status)
  VALUES(v_uid,v_phone,v_phone,v_verified_at,'pending')
  ON CONFLICT(auth_user_id) DO UPDATE
    SET primary_phone=EXCLUDED.primary_phone,
        verified_phone=EXCLUDED.verified_phone,
        phone_verified_at=EXCLUDED.phone_verified_at,
        updated_at=clock_timestamp()
    WHERE public.srk_technicians.verified_phone IS NULL
       OR public.srk_technicians.verified_phone=EXCLUDED.verified_phone
  RETURNING id INTO v_technician_id;
  IF v_technician_id IS NULL THEN
    RAISE EXCEPTION 'VERIFIED_PHONE_CONFLICT_REQUIRES_ADMIN_RECONCILIATION' USING ERRCODE='23505';
  END IF;

  IF EXISTS (SELECT 1 FROM public.srk_technician_applications a
    WHERE a.technician_id=v_technician_id AND a.status IN ('pending','under_review')) THEN
    RAISE EXCEPTION 'TECHNICIAN_APPLICATION_ALREADY_UNDER_REVIEW' USING ERRCODE='23505';
  END IF;

  INSERT INTO public.srk_technician_applications
    (technician_id,full_name,address,district,state,pincode,experience_years,about,status)
  VALUES(v_technician_id,btrim(p_full_name),btrim(p_address),btrim(p_district),btrim(p_state),
    p_pincode,p_experience_years,nullif(btrim(coalesce(p_about,'')),''),'pending')
  RETURNING id INTO v_application_id;

  INSERT INTO public.srk_technician_application_categories(application_id,category_id)
    SELECT v_application_id,unnest(v_categories);
  INSERT INTO public.srk_technician_application_skills(application_id,skill_id)
    SELECT v_application_id,unnest(v_skills);

  INSERT INTO public.srk_technician_application_events
    (application_id,technician_id,actor_user_id,actor_role,event_type,snapshot)
  VALUES(v_application_id,v_technician_id,v_uid,'technician',
    CASE WHEN v_has_rejected THEN 'resubmitted' ELSE 'submitted' END,
    jsonb_build_object('category_codes',p_category_codes,'skill_codes',p_skill_codes,
      'experience_years',p_experience_years,'verified_phone',v_phone));

  RETURN jsonb_build_object('success',true,'technician_id',v_technician_id,
    'application_id',v_application_id,'status','pending');
END;
$function$;
REVOKE ALL ON FUNCTION public.srk_technician_submit_application(text,text,text,text,text,integer,text,text[],text[]) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.srk_technician_submit_application(text,text,text,text,text,integer,text,text[],text[]) TO authenticated;

CREATE OR REPLACE FUNCTION public.srk_technician_get_my_applications()
RETURNS TABLE(application_id uuid,status text,rejection_reason text,submitted_at timestamptz,
  categories jsonb,skills jsonb,kyc jsonb)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $function$
DECLARE v_uid uuid:=auth.uid(); v_technician_id uuid;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'TECHNICIAN_LOGIN_REQUIRED' USING ERRCODE='42501'; END IF;
  SELECT t.id INTO v_technician_id FROM public.srk_technicians t WHERE t.auth_user_id=v_uid;
  IF v_technician_id IS NULL THEN RETURN; END IF;
  RETURN QUERY
  SELECT a.id,a.status,a.rejection_reason,a.submitted_at,
    COALESCE((SELECT jsonb_agg(jsonb_build_object('code',c.category_code,'name',c.display_name)
      ORDER BY c.sort_order,c.category_code)
      FROM public.srk_technician_application_categories ac
      JOIN public.srk_service_categories c ON c.id=ac.category_id WHERE ac.application_id=a.id),'[]'::jsonb),
    COALESCE((SELECT jsonb_agg(jsonb_build_object('code',s.skill_code,'name',s.display_name,
      'review_status',aps.review_status,'admin_note',aps.admin_note)
      ORDER BY s.skill_code)
      FROM public.srk_technician_application_skills aps
      JOIN public.srk_service_skills s ON s.id=aps.skill_id WHERE aps.application_id=a.id),'[]'::jsonb),
    COALESCE((SELECT jsonb_agg(jsonb_build_object('id',d.id,'document_type',d.document_type,
      'file_name',d.file_name,'review_status',d.review_status,'admin_note',d.admin_note,
      'uploaded_at',d.uploaded_at,'reviewed_at',d.reviewed_at)
      ORDER BY d.uploaded_at DESC)
      FROM public.srk_technician_kyc_documents d WHERE d.application_id=a.id),'[]'::jsonb)
  FROM public.srk_technician_applications a
  WHERE a.technician_id=v_technician_id
  ORDER BY a.submitted_at DESC;
END;
$function$;
REVOKE ALL ON FUNCTION public.srk_technician_get_my_applications() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.srk_technician_get_my_applications() TO authenticated;

CREATE OR REPLACE FUNCTION public.srk_technician_submit_kyc_document(
  p_application_id uuid,p_document_type text,p_application_skill_id uuid,
  p_storage_path text,p_file_name text,p_mime_type text,p_file_size_bytes bigint
)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $function$
DECLARE
  v_uid uuid:=auth.uid(); v_technician_id uuid; v_document_id uuid;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'TECHNICIAN_LOGIN_REQUIRED' USING ERRCODE='42501'; END IF;
  IF p_application_id IS NULL OR p_document_type IS NULL OR p_document_type NOT IN ('identity_proof','address_proof','skill_certificate')
     OR p_storage_path IS NULL OR length(p_storage_path)>255
     OR left(p_storage_path,length(v_uid::text||'/'||p_document_type||'/'))<>v_uid::text||'/'||p_document_type||'/'
     OR position('..' in p_storage_path)>0 OR position(E'\\' in p_storage_path)>0
     OR p_storage_path ~ '[[:cntrl:]]'
     OR p_file_name IS NULL OR length(btrim(p_file_name)) NOT BETWEEN 1 AND 180
     OR p_file_name ~ '[[:cntrl:]]'
     OR p_mime_type IS NULL OR p_mime_type NOT IN ('application/pdf','image/jpeg','image/png')
     OR p_file_size_bytes IS NULL OR p_file_size_bytes NOT BETWEEN 1 AND 5242880 THEN
    RAISE EXCEPTION 'INVALID_TECHNICIAN_KYC_DOCUMENT' USING ERRCODE='22023';
  END IF;
  SELECT t.id INTO v_technician_id
  FROM public.srk_technicians t JOIN public.srk_technician_applications a ON a.technician_id=t.id
  WHERE t.auth_user_id=v_uid AND t.verified_phone IS NOT NULL
    AND a.id=p_application_id AND a.status IN ('pending','under_review')
  FOR UPDATE OF a;
  IF v_technician_id IS NULL THEN RAISE EXCEPTION 'OWN_PENDING_TECHNICIAN_APPLICATION_REQUIRED' USING ERRCODE='42501'; END IF;
  IF p_document_type='skill_certificate' THEN
    IF p_application_skill_id IS NULL OR NOT EXISTS (
      SELECT 1 FROM public.srk_technician_application_skills s
      WHERE s.id=p_application_skill_id AND s.application_id=p_application_id
    ) THEN RAISE EXCEPTION 'SKILL_CERTIFICATE_MUST_MATCH_APPLICATION_SKILL' USING ERRCODE='22023'; END IF;
  ELSIF p_application_skill_id IS NOT NULL THEN
    RAISE EXCEPTION 'NON_SKILL_KYC_CANNOT_LINK_SKILL' USING ERRCODE='22023';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM storage.objects o
    WHERE o.bucket_id='srk-technician-verification' AND o.name=p_storage_path) THEN
    RAISE EXCEPTION 'UPLOADED_PRIVATE_KYC_OBJECT_NOT_FOUND' USING ERRCODE='55000';
  END IF;
  INSERT INTO public.srk_technician_kyc_documents
    (application_id,uploaded_by,document_type,application_skill_id,storage_path,file_name,mime_type,file_size_bytes)
  VALUES(p_application_id,v_uid,p_document_type,p_application_skill_id,p_storage_path,
    btrim(p_file_name),p_mime_type,p_file_size_bytes)
  RETURNING id INTO v_document_id;
  INSERT INTO public.srk_technician_kyc_events(document_id,application_id,actor_user_id,actor_role,event_type)
  VALUES(v_document_id,p_application_id,v_uid,'technician','submitted');
  RETURN jsonb_build_object('success',true,'document_id',v_document_id,'review_status','pending');
END;
$function$;
REVOKE ALL ON FUNCTION public.srk_technician_submit_kyc_document(uuid,text,uuid,text,text,text,bigint) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.srk_technician_submit_kyc_document(uuid,text,uuid,text,text,text,bigint) TO authenticated;

CREATE OR REPLACE FUNCTION public.srk_admin_review_technician_skill(
  p_application_skill_id uuid,p_review_status text,p_admin_note text DEFAULT NULL
)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $function$
DECLARE v_skill public.srk_technician_application_skills%rowtype; v_note text:=nullif(btrim(coalesce(p_admin_note,'')),'');
BEGIN
  IF auth.uid() IS NULL OR NOT public.is_srk_admin() THEN RAISE EXCEPTION 'ADMIN_ACCESS_REQUIRED' USING ERRCODE='42501'; END IF;
  IF p_application_skill_id IS NULL OR p_review_status IS NULL OR p_review_status NOT IN ('approved','rejected','needs_resubmission')
     OR (p_review_status<>'approved' AND length(v_note) NOT BETWEEN 5 AND 1000)
     OR length(v_note)>1000 THEN RAISE EXCEPTION 'INVALID_TECHNICIAN_SKILL_REVIEW' USING ERRCODE='22023'; END IF;
  SELECT * INTO v_skill FROM public.srk_technician_application_skills
    WHERE id=p_application_skill_id FOR UPDATE;
  IF NOT FOUND OR v_skill.review_status<>'pending' THEN RAISE EXCEPTION 'PENDING_TECHNICIAN_SKILL_REVIEW_REQUIRED' USING ERRCODE='55000'; END IF;
  UPDATE public.srk_technician_application_skills SET review_status=p_review_status,
    admin_note=v_note,reviewed_at=clock_timestamp(),reviewed_by=auth.uid()
  WHERE id=v_skill.id;
  INSERT INTO public.srk_technician_application_events
    (application_id,technician_id,actor_user_id,actor_role,event_type,note,snapshot)
  SELECT v_skill.application_id,a.technician_id,auth.uid(),'admin','skill_reviewed',v_note,
    jsonb_build_object('application_skill_id',v_skill.id,'review_status',p_review_status)
  FROM public.srk_technician_applications a WHERE a.id=v_skill.application_id;
  RETURN jsonb_build_object('success',true,'application_skill_id',v_skill.id,'review_status',p_review_status);
END;
$function$;
REVOKE ALL ON FUNCTION public.srk_admin_review_technician_skill(uuid,text,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.srk_admin_review_technician_skill(uuid,text,text) TO authenticated;

CREATE OR REPLACE FUNCTION public.srk_admin_review_technician_kyc(
  p_document_id uuid,p_review_status text,p_admin_note text DEFAULT NULL
)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $function$
DECLARE v_doc public.srk_technician_kyc_documents%rowtype; v_note text:=nullif(btrim(coalesce(p_admin_note,'')),'');
BEGIN
  IF auth.uid() IS NULL OR NOT public.is_srk_admin() THEN RAISE EXCEPTION 'ADMIN_ACCESS_REQUIRED' USING ERRCODE='42501'; END IF;
  IF p_document_id IS NULL OR p_review_status IS NULL OR p_review_status NOT IN ('approved','rejected','needs_resubmission')
     OR (p_review_status<>'approved' AND length(v_note) NOT BETWEEN 5 AND 1000)
     OR length(v_note)>1000 THEN RAISE EXCEPTION 'INVALID_TECHNICIAN_KYC_REVIEW' USING ERRCODE='22023'; END IF;
  SELECT * INTO v_doc FROM public.srk_technician_kyc_documents WHERE id=p_document_id FOR UPDATE;
  IF NOT FOUND OR v_doc.review_status<>'pending' THEN RAISE EXCEPTION 'PENDING_TECHNICIAN_KYC_REVIEW_REQUIRED' USING ERRCODE='55000'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.srk_technician_applications a
    WHERE a.id=v_doc.application_id AND a.status IN ('pending','under_review')) THEN
    RAISE EXCEPTION 'OPEN_TECHNICIAN_APPLICATION_REQUIRED_FOR_KYC_REVIEW' USING ERRCODE='55000';
  END IF;
  UPDATE public.srk_technician_kyc_documents SET review_status=p_review_status,
    admin_note=v_note,reviewed_at=clock_timestamp(),reviewed_by=auth.uid()
  WHERE id=v_doc.id;
  INSERT INTO public.srk_technician_kyc_events(document_id,application_id,actor_user_id,actor_role,event_type,note)
  VALUES(v_doc.id,v_doc.application_id,auth.uid(),'admin',p_review_status,v_note);
  RETURN jsonb_build_object('success',true,'document_id',v_doc.id,'review_status',p_review_status);
END;
$function$;
REVOKE ALL ON FUNCTION public.srk_admin_review_technician_kyc(uuid,text,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.srk_admin_review_technician_kyc(uuid,text,text) TO authenticated;

CREATE OR REPLACE FUNCTION public.srk_admin_review_technician_application(
  p_application_id uuid,p_decision text,p_rejection_reason text DEFAULT NULL
)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $function$
DECLARE
  v_app public.srk_technician_applications%rowtype;
  v_reason text:=nullif(btrim(coalesce(p_rejection_reason,'')),'');
  v_approved_required_docs integer;
BEGIN
  IF auth.uid() IS NULL OR NOT public.is_srk_admin() THEN RAISE EXCEPTION 'ADMIN_ACCESS_REQUIRED' USING ERRCODE='42501'; END IF;
  IF p_application_id IS NULL OR p_decision IS NULL OR p_decision NOT IN ('under_review','approved','rejected')
     OR (p_decision='rejected' AND length(v_reason) NOT BETWEEN 5 AND 1000)
     OR length(v_reason)>1000 THEN RAISE EXCEPTION 'INVALID_TECHNICIAN_APPLICATION_DECISION' USING ERRCODE='22023'; END IF;
  SELECT * INTO v_app FROM public.srk_technician_applications WHERE id=p_application_id FOR UPDATE;
  IF NOT FOUND OR v_app.status NOT IN ('pending','under_review') THEN
    RAISE EXCEPTION 'OPEN_TECHNICIAN_APPLICATION_REQUIRED' USING ERRCODE='55000';
  END IF;
  IF p_decision='approved' THEN
    SELECT count(*) INTO v_approved_required_docs
    FROM (
      SELECT DISTINCT ON (d.document_type) d.document_type,d.review_status
      FROM public.srk_technician_kyc_documents d
      WHERE d.application_id=v_app.id AND d.document_type IN ('identity_proof','address_proof')
      ORDER BY d.document_type,d.uploaded_at DESC,d.id DESC
    ) latest
    WHERE latest.review_status='approved';
    IF v_approved_required_docs<>2 THEN RAISE EXCEPTION 'LATEST_IDENTITY_AND_ADDRESS_KYC_MUST_BE_APPROVED' USING ERRCODE='55000'; END IF;
    IF EXISTS (SELECT 1 FROM public.srk_technician_application_skills s
      WHERE s.application_id=v_app.id AND s.review_status<>'approved') THEN
      RAISE EXCEPTION 'ALL_SELECTED_TECHNICIAN_SKILLS_REQUIRE_SEPARATE_ADMIN_APPROVAL' USING ERRCODE='55000';
    END IF;
  END IF;
  UPDATE public.srk_technician_applications SET status=p_decision,
    rejection_reason=CASE WHEN p_decision='rejected' THEN v_reason ELSE NULL END,
    reviewed_at=CASE WHEN p_decision IN ('approved','rejected') THEN clock_timestamp() ELSE NULL END,
    reviewed_by=CASE WHEN p_decision IN ('approved','rejected') THEN auth.uid() ELSE NULL END,
    updated_at=clock_timestamp()
  WHERE id=v_app.id;
  INSERT INTO public.srk_technician_application_events
    (application_id,technician_id,actor_user_id,actor_role,event_type,note)
  VALUES(v_app.id,v_app.technician_id,auth.uid(),'admin',p_decision,v_reason);
  IF p_decision='approved' THEN
    UPDATE public.srk_technicians SET account_status='active',updated_at=clock_timestamp()
    WHERE id=v_app.technician_id;
  ELSIF p_decision='rejected' THEN
    UPDATE public.srk_technicians SET account_status='rejected',updated_at=clock_timestamp()
    WHERE id=v_app.technician_id AND account_status='pending';
  END IF;
  RETURN jsonb_build_object('success',true,'application_id',v_app.id,'status',p_decision);
END;
$function$;
REVOKE ALL ON FUNCTION public.srk_admin_review_technician_application(uuid,text,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.srk_admin_review_technician_application(uuid,text,text) TO authenticated;

COMMENT ON TABLE public.srk_technician_applications IS
  'Category-neutral OTP-first Technician applications. Identity is derived from the verified Supabase Auth user; client-submitted phone is never accepted.';
COMMENT ON TABLE public.srk_technician_kyc_documents IS
  'Private category-neutral Technician KYC metadata. File bytes live in the private srk-technician-verification Storage bucket.';
COMMENT ON FUNCTION public.srk_technician_submit_application(text,text,text,text,text,integer,text,text[],text[]) IS
  'Creates a pending application only for the authenticated user with a confirmed Auth phone; stores normalized phone server-side and rejects duplicate verified-phone identities.';


-- Read-only catalogue projection for the shared Technician App.
CREATE OR REPLACE FUNCTION public.srk_technician_list_service_catalogue()
RETURNS TABLE(category_code text,category_name text,category_sort_order integer,
  skill_code text,skill_name text,requires_separate_assessment boolean)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $function$
  SELECT c.category_code,c.display_name,c.sort_order,s.skill_code,s.display_name,s.requires_separate_assessment
  FROM public.srk_service_categories c
  LEFT JOIN public.srk_service_skills s ON s.category_id=c.id AND s.is_active
  WHERE c.is_active
  ORDER BY c.sort_order,c.category_code,s.skill_code;
$function$;
REVOKE ALL ON FUNCTION public.srk_technician_list_service_catalogue() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.srk_technician_list_service_catalogue() TO authenticated;

-- Admin-controlled, additive catalogue management. Deactivation preserves old applications.
CREATE OR REPLACE FUNCTION public.srk_admin_upsert_service_category(
  p_category_code text,p_display_name text,p_is_active boolean DEFAULT true,p_sort_order integer DEFAULT 0
)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $function$
DECLARE v_id uuid;
BEGIN
  IF auth.uid() IS NULL OR NOT public.is_srk_admin() THEN RAISE EXCEPTION 'ADMIN_ACCESS_REQUIRED' USING ERRCODE='42501'; END IF;
  IF p_category_code IS NULL OR p_category_code !~ '^[a-z][a-z0-9_]{1,59}$'
     OR p_display_name IS NULL OR length(btrim(p_display_name)) NOT BETWEEN 2 AND 100
     OR p_is_active IS NULL OR p_sort_order IS NULL THEN
    RAISE EXCEPTION 'INVALID_SERVICE_CATEGORY' USING ERRCODE='22023';
  END IF;
  INSERT INTO public.srk_service_categories(category_code,display_name,is_active,sort_order,created_by)
  VALUES(p_category_code,btrim(p_display_name),p_is_active,p_sort_order,auth.uid())
  ON CONFLICT(category_code) DO UPDATE SET display_name=EXCLUDED.display_name,
    is_active=EXCLUDED.is_active,sort_order=EXCLUDED.sort_order
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$function$;
REVOKE ALL ON FUNCTION public.srk_admin_upsert_service_category(text,text,boolean,integer) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.srk_admin_upsert_service_category(text,text,boolean,integer) TO authenticated;

CREATE OR REPLACE FUNCTION public.srk_admin_upsert_service_skill(
  p_category_code text,p_skill_code text,p_display_name text,
  p_is_active boolean DEFAULT true,p_requires_separate_assessment boolean DEFAULT false
)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $function$
DECLARE v_category_id uuid; v_id uuid;
BEGIN
  IF auth.uid() IS NULL OR NOT public.is_srk_admin() THEN RAISE EXCEPTION 'ADMIN_ACCESS_REQUIRED' USING ERRCODE='42501'; END IF;
  IF p_category_code IS NULL OR p_skill_code IS NULL OR p_skill_code !~ '^[a-z][a-z0-9_]{1,79}$'
     OR p_display_name IS NULL OR length(btrim(p_display_name)) NOT BETWEEN 2 AND 100
     OR p_is_active IS NULL OR p_requires_separate_assessment IS NULL THEN
    RAISE EXCEPTION 'INVALID_SERVICE_SKILL' USING ERRCODE='22023';
  END IF;
  SELECT id INTO v_category_id FROM public.srk_service_categories
    WHERE category_code=p_category_code AND is_active;
  IF v_category_id IS NULL THEN RAISE EXCEPTION 'ACTIVE_SERVICE_CATEGORY_REQUIRED' USING ERRCODE='22023'; END IF;
  INSERT INTO public.srk_service_skills(category_id,skill_code,display_name,is_active,requires_separate_assessment,created_by)
  VALUES(v_category_id,p_skill_code,btrim(p_display_name),p_is_active,p_requires_separate_assessment,auth.uid())
  ON CONFLICT(skill_code) DO UPDATE SET category_id=EXCLUDED.category_id,
    display_name=EXCLUDED.display_name,is_active=EXCLUDED.is_active,
    requires_separate_assessment=EXCLUDED.requires_separate_assessment
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$function$;
REVOKE ALL ON FUNCTION public.srk_admin_upsert_service_skill(text,text,text,boolean,boolean) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.srk_admin_upsert_service_skill(text,text,text,boolean,boolean) TO authenticated;

CREATE OR REPLACE FUNCTION public.srk_admin_list_technician_applications(
  p_status text DEFAULT NULL,p_limit integer DEFAULT 100
)
RETURNS TABLE(application_id uuid,technician_id uuid,verified_phone text,full_name text,
  address text,district text,state text,pincode text,experience_years integer,
  status text,rejection_reason text,submitted_at timestamptz,
  categories jsonb,skills jsonb,kyc_documents jsonb)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $function$
BEGIN
  IF auth.uid() IS NULL OR NOT public.is_srk_admin() THEN RAISE EXCEPTION 'ADMIN_ACCESS_REQUIRED' USING ERRCODE='42501'; END IF;
  IF p_status IS NOT NULL AND p_status NOT IN ('pending','under_review','approved','rejected') THEN
    RAISE EXCEPTION 'INVALID_APPLICATION_FILTER' USING ERRCODE='22023';
  END IF;
  RETURN QUERY
  SELECT a.id,t.id,t.verified_phone,a.full_name,a.address,a.district,a.state,a.pincode,
    a.experience_years,a.status,a.rejection_reason,a.submitted_at,
    COALESCE((SELECT jsonb_agg(jsonb_build_object('code',c.category_code,'name',c.display_name)
      ORDER BY c.sort_order,c.category_code)
      FROM public.srk_technician_application_categories ac
      JOIN public.srk_service_categories c ON c.id=ac.category_id WHERE ac.application_id=a.id),'[]'::jsonb),
    COALESCE((SELECT jsonb_agg(jsonb_build_object('application_skill_id',aps.id,'code',s.skill_code,
      'name',s.display_name,'review_status',aps.review_status,'admin_note',aps.admin_note,
      'requires_separate_assessment',s.requires_separate_assessment) ORDER BY s.skill_code)
      FROM public.srk_technician_application_skills aps
      JOIN public.srk_service_skills s ON s.id=aps.skill_id WHERE aps.application_id=a.id),'[]'::jsonb),
    COALESCE((SELECT jsonb_agg(jsonb_build_object('id',d.id,'document_type',d.document_type,
      'application_skill_id',d.application_skill_id,'storage_path',d.storage_path,
      'file_name',d.file_name,'mime_type',d.mime_type,'file_size_bytes',d.file_size_bytes,
      'review_status',d.review_status,'admin_note',d.admin_note,'uploaded_at',d.uploaded_at)
      ORDER BY d.uploaded_at DESC,d.id DESC)
      FROM public.srk_technician_kyc_documents d WHERE d.application_id=a.id),'[]'::jsonb)
  FROM public.srk_technician_applications a
  JOIN public.srk_technicians t ON t.id=a.technician_id
  WHERE p_status IS NULL OR a.status=p_status
  ORDER BY a.submitted_at DESC
  LIMIT GREATEST(1,LEAST(COALESCE(p_limit,100),300));
END;
$function$;
REVOKE ALL ON FUNCTION public.srk_admin_list_technician_applications(text,integer) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.srk_admin_list_technician_applications(text,integer) TO authenticated;



-- Append-only Admin audit for category and skill catalogue changes.
CREATE TABLE IF NOT EXISTS public.srk_service_catalogue_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  actor_user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
  object_type text NOT NULL CHECK (object_type IN ('category','skill')),
  object_id uuid NOT NULL,
  action text NOT NULL CHECK (action IN ('created','updated')),
  before_data jsonb NOT NULL DEFAULT '{}'::jsonb,
  after_data jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT clock_timestamp()
);
ALTER TABLE public.srk_service_catalogue_events ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.srk_service_catalogue_events FROM PUBLIC,anon,authenticated;
GRANT ALL ON TABLE public.srk_service_catalogue_events TO service_role;
DROP TRIGGER IF EXISTS srk_service_catalogue_events_append_only ON public.srk_service_catalogue_events;
CREATE TRIGGER srk_service_catalogue_events_append_only
BEFORE UPDATE OR DELETE ON public.srk_service_catalogue_events
FOR EACH ROW EXECUTE FUNCTION public.srk_guard_technician_history_append_only();

CREATE OR REPLACE FUNCTION public.srk_admin_upsert_service_category(
  p_category_code text,p_display_name text,p_is_active boolean DEFAULT true,p_sort_order integer DEFAULT 0
)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $function$
DECLARE v_id uuid; v_before jsonb:='{}'::jsonb; v_after jsonb; v_action text:='created';
BEGIN
  IF auth.uid() IS NULL OR NOT public.is_srk_admin() THEN RAISE EXCEPTION 'ADMIN_ACCESS_REQUIRED' USING ERRCODE='42501'; END IF;
  IF p_category_code IS NULL OR p_category_code !~ '^[a-z][a-z0-9_]{1,59}$'
     OR p_display_name IS NULL OR length(btrim(p_display_name)) NOT BETWEEN 2 AND 100
     OR p_is_active IS NULL OR p_sort_order IS NULL THEN
    RAISE EXCEPTION 'INVALID_SERVICE_CATEGORY' USING ERRCODE='22023';
  END IF;
  SELECT c.id,to_jsonb(c) INTO v_id,v_before FROM public.srk_service_categories c
    WHERE c.category_code=p_category_code FOR UPDATE;
  IF v_id IS NOT NULL THEN v_action:='updated'; END IF;
  INSERT INTO public.srk_service_categories(category_code,display_name,is_active,sort_order,created_by)
  VALUES(p_category_code,btrim(p_display_name),p_is_active,p_sort_order,auth.uid())
  ON CONFLICT(category_code) DO UPDATE SET display_name=EXCLUDED.display_name,
    is_active=EXCLUDED.is_active,sort_order=EXCLUDED.sort_order
  RETURNING id,jsonb_build_object('category_code',category_code,'display_name',display_name,
    'is_active',is_active,'sort_order',sort_order,'created_at',created_at,'created_by',created_by)
    INTO v_id,v_after;
  INSERT INTO public.srk_service_catalogue_events(actor_user_id,object_type,object_id,action,before_data,after_data)
  VALUES(auth.uid(),'category',v_id,v_action,v_before,v_after);
  RETURN v_id;
END;
$function$;

CREATE OR REPLACE FUNCTION public.srk_admin_upsert_service_skill(
  p_category_code text,p_skill_code text,p_display_name text,
  p_is_active boolean DEFAULT true,p_requires_separate_assessment boolean DEFAULT false
)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $function$
DECLARE v_category_id uuid; v_id uuid; v_before jsonb:='{}'::jsonb; v_after jsonb; v_action text:='created';
BEGIN
  IF auth.uid() IS NULL OR NOT public.is_srk_admin() THEN RAISE EXCEPTION 'ADMIN_ACCESS_REQUIRED' USING ERRCODE='42501'; END IF;
  IF p_category_code IS NULL OR p_skill_code IS NULL OR p_skill_code !~ '^[a-z][a-z0-9_]{1,79}$'
     OR p_display_name IS NULL OR length(btrim(p_display_name)) NOT BETWEEN 2 AND 100
     OR p_is_active IS NULL OR p_requires_separate_assessment IS NULL THEN
    RAISE EXCEPTION 'INVALID_SERVICE_SKILL' USING ERRCODE='22023';
  END IF;
  SELECT id INTO v_category_id FROM public.srk_service_categories
    WHERE category_code=p_category_code AND is_active;
  IF v_category_id IS NULL THEN RAISE EXCEPTION 'ACTIVE_SERVICE_CATEGORY_REQUIRED' USING ERRCODE='22023'; END IF;
  SELECT s.id,to_jsonb(s) INTO v_id,v_before FROM public.srk_service_skills s
    WHERE s.skill_code=p_skill_code FOR UPDATE;
  IF v_id IS NOT NULL THEN v_action:='updated'; END IF;
  INSERT INTO public.srk_service_skills(category_id,skill_code,display_name,is_active,requires_separate_assessment,created_by)
  VALUES(v_category_id,p_skill_code,btrim(p_display_name),p_is_active,p_requires_separate_assessment,auth.uid())
  ON CONFLICT(skill_code) DO UPDATE SET category_id=EXCLUDED.category_id,
    display_name=EXCLUDED.display_name,is_active=EXCLUDED.is_active,
    requires_separate_assessment=EXCLUDED.requires_separate_assessment
  RETURNING id,jsonb_build_object('category_id',category_id,'skill_code',skill_code,
    'display_name',display_name,'is_active',is_active,
    'requires_separate_assessment',requires_separate_assessment,'created_at',created_at,'created_by',created_by)
    INTO v_id,v_after;
  INSERT INTO public.srk_service_catalogue_events(actor_user_id,object_type,object_id,action,before_data,after_data)
  VALUES(auth.uid(),'skill',v_id,v_action,v_before,v_after);
  RETURN v_id;
END;
$function$;
REVOKE ALL ON FUNCTION public.srk_admin_upsert_service_category(text,text,boolean,integer) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.srk_admin_upsert_service_category(text,text,boolean,integer) TO authenticated;
REVOKE ALL ON FUNCTION public.srk_admin_upsert_service_skill(text,text,text,boolean,boolean) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.srk_admin_upsert_service_skill(text,text,text,boolean,boolean) TO authenticated;

-- A rejected or resubmission-required skill can be reviewed again after new evidence.
CREATE OR REPLACE FUNCTION public.srk_admin_review_technician_skill(
  p_application_skill_id uuid,p_review_status text,p_admin_note text DEFAULT NULL
)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $function$
DECLARE v_skill public.srk_technician_application_skills%rowtype; v_note text:=nullif(btrim(coalesce(p_admin_note,'')),'');
BEGIN
  IF auth.uid() IS NULL OR NOT public.is_srk_admin() THEN RAISE EXCEPTION 'ADMIN_ACCESS_REQUIRED' USING ERRCODE='42501'; END IF;
  IF p_application_skill_id IS NULL OR p_review_status NOT IN ('approved','rejected','needs_resubmission')
     OR (p_review_status<>'approved' AND length(v_note) NOT BETWEEN 5 AND 1000)
     OR length(v_note)>1000 THEN RAISE EXCEPTION 'INVALID_TECHNICIAN_SKILL_REVIEW' USING ERRCODE='22023'; END IF;
  SELECT * INTO v_skill FROM public.srk_technician_application_skills
    WHERE id=p_application_skill_id FOR UPDATE;
  IF NOT FOUND OR v_skill.review_status='approved' THEN RAISE EXCEPTION 'UNAPPROVED_TECHNICIAN_SKILL_REVIEW_REQUIRED' USING ERRCODE='55000'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.srk_technician_applications a
    WHERE a.id=v_skill.application_id AND a.status IN ('pending','under_review')) THEN
    RAISE EXCEPTION 'OPEN_TECHNICIAN_APPLICATION_REQUIRED_FOR_SKILL_REVIEW' USING ERRCODE='55000';
  END IF;
  UPDATE public.srk_technician_application_skills SET review_status=p_review_status,
    admin_note=v_note,reviewed_at=clock_timestamp(),reviewed_by=auth.uid()
  WHERE id=v_skill.id;
  INSERT INTO public.srk_technician_application_events
    (application_id,technician_id,actor_user_id,actor_role,event_type,note,snapshot)
  SELECT v_skill.application_id,a.technician_id,auth.uid(),'admin','skill_reviewed',v_note,
    jsonb_build_object('application_skill_id',v_skill.id,'review_status',p_review_status)
  FROM public.srk_technician_applications a WHERE a.id=v_skill.application_id;
  RETURN jsonb_build_object('success',true,'application_skill_id',v_skill.id,'review_status',p_review_status);
END;
$function$;
REVOKE ALL ON FUNCTION public.srk_admin_review_technician_skill(uuid,text,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.srk_admin_review_technician_skill(uuid,text,text) TO authenticated;
