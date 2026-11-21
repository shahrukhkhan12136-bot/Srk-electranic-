-- SRK ELECTRONIC Master: two-way rating read models, public aggregates, reports and Admin review.
-- Rating submissions and hide/restore moderation remain governed by the prior migration.
CREATE TABLE IF NOT EXISTS public.srk_master_rating_reports (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 rating_id uuid NOT NULL REFERENCES public.srk_master_booking_ratings(id) ON DELETE RESTRICT,
 reporter_role text NOT NULL CHECK(reporter_role IN ('customer','technician')),
 reporter_user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
 reporter_technician_id uuid REFERENCES public.srk_technicians(id) ON DELETE RESTRICT,
 reason text NOT NULL CHECK(length(btrim(reason)) BETWEEN 5 AND 500),
 details text CHECK(details IS NULL OR length(btrim(details))<=1000),
 status text NOT NULL DEFAULT 'pending' CHECK(status IN ('pending','dismissed','actioned')),
 created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 reviewed_by uuid REFERENCES auth.users(id) ON DELETE RESTRICT,
 reviewed_at timestamptz,
 resolution_note text CHECK(resolution_note IS NULL OR length(btrim(resolution_note)) BETWEEN 5 AND 1000),
 CHECK((reporter_role='customer' AND reporter_technician_id IS NULL)
    OR (reporter_role='technician' AND reporter_technician_id IS NOT NULL)),
 CHECK((status='pending' AND reviewed_by IS NULL AND reviewed_at IS NULL AND resolution_note IS NULL)
    OR (status<>'pending' AND reviewed_by IS NOT NULL AND reviewed_at IS NOT NULL AND resolution_note IS NOT NULL))
);
CREATE UNIQUE INDEX IF NOT EXISTS srk_master_rating_reporter_once_uidx
 ON public.srk_master_rating_reports(rating_id,reporter_user_id);
CREATE INDEX IF NOT EXISTS srk_master_rating_reports_status_idx
 ON public.srk_master_rating_reports(status,created_at DESC);
ALTER TABLE public.srk_master_rating_reports ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.srk_master_rating_reports FROM PUBLIC,anon,authenticated;
GRANT ALL ON public.srk_master_rating_reports TO service_role;

CREATE TABLE IF NOT EXISTS public.srk_master_rating_report_events (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 report_id uuid NOT NULL REFERENCES public.srk_master_rating_reports(id) ON DELETE RESTRICT,
 admin_user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
 decision text NOT NULL CHECK(decision IN ('dismiss','hide_rating','restore_rating')),
 note text NOT NULL CHECK(length(btrim(note)) BETWEEN 5 AND 1000),
 before_status text NOT NULL CHECK(before_status IN ('pending','dismissed','actioned')),
 after_status text NOT NULL CHECK(after_status IN ('dismissed','actioned')),
 created_at timestamptz NOT NULL DEFAULT clock_timestamp()
);
ALTER TABLE public.srk_master_rating_report_events ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.srk_master_rating_report_events FROM PUBLIC,anon,authenticated;
GRANT ALL ON public.srk_master_rating_report_events TO service_role;
CREATE OR REPLACE FUNCTION public.srk_guard_master_rating_report_events_append_only()
RETURNS trigger LANGUAGE plpgsql SET search_path='' AS $function$
BEGIN RAISE EXCEPTION 'RATING_REPORT_HISTORY_IS_APPEND_ONLY' USING ERRCODE='55000'; END;
$function$;
REVOKE ALL ON FUNCTION public.srk_guard_master_rating_report_events_append_only() FROM PUBLIC,anon,authenticated;
DROP TRIGGER IF EXISTS srk_master_rating_report_events_append_only ON public.srk_master_rating_report_events;
CREATE TRIGGER srk_master_rating_report_events_append_only
 BEFORE UPDATE OR DELETE ON public.srk_master_rating_report_events
 FOR EACH ROW EXECUTE FUNCTION public.srk_guard_master_rating_report_events_append_only();

CREATE OR REPLACE FUNCTION public.srk_customer_list_master_rating_tasks()
RETURNS TABLE(
 booking_id uuid,technician_id uuid,rating_id uuid,stars smallint,review_text text,
 rating_created_at timestamptz,technician_average numeric,technician_rating_count bigint,
 subject_rating_id uuid,subject_rating_stars smallint,subject_rating_text text,subject_rating_created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $function$
BEGIN
 IF auth.uid() IS NULL THEN RAISE EXCEPTION 'CUSTOMER_LOGIN_REQUIRED' USING ERRCODE='42501'; END IF;
 RETURN QUERY
 SELECT b.id,a.technician_id,r.id,r.stars,r.review_text,r.created_at,
  COALESCE((SELECT round(avg(p.stars)::numeric,2) FROM public.srk_master_booking_ratings p
   WHERE p.target_technician_id=a.technician_id AND p.reviewer_role='customer' AND p.moderation_status='published'),0),
  (SELECT count(*) FROM public.srk_master_booking_ratings p
   WHERE p.target_technician_id=a.technician_id AND p.reviewer_role='customer' AND p.moderation_status='published'),
  sr.id,sr.stars,sr.review_text,sr.created_at
 FROM public.service_bookings b
 JOIN public.srk_booking_technician_assignments a ON a.booking_id=b.id AND a.assignment_status='completed'
 LEFT JOIN public.srk_master_booking_ratings r ON r.booking_id=b.id
  AND r.target_technician_id=a.technician_id AND r.reviewer_role='customer'
 LEFT JOIN public.srk_master_booking_ratings sr ON sr.booking_id=b.id
  AND sr.target_user_id=b.customer_user_id AND sr.reviewer_role='technician'
 WHERE b.customer_user_id=auth.uid() AND b.status='completed'
  AND b.completion_approval_status='approved' AND b.customer_completed_at IS NOT NULL
 ORDER BY b.customer_completed_at DESC,a.technician_id;
END;
$function$;
REVOKE ALL ON FUNCTION public.srk_customer_list_master_rating_tasks() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.srk_customer_list_master_rating_tasks() TO authenticated;

CREATE OR REPLACE FUNCTION public.srk_technician_list_master_rating_tasks()
RETURNS TABLE(
 booking_id uuid,rating_id uuid,stars smallint,review_text text,
 rating_created_at timestamptz,customer_average numeric,customer_rating_count bigint,
 subject_rating_id uuid,subject_rating_stars smallint,subject_rating_text text,subject_rating_created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $function$
DECLARE v_tid uuid;
BEGIN
 IF auth.uid() IS NULL THEN RAISE EXCEPTION 'TECHNICIAN_LOGIN_REQUIRED' USING ERRCODE='42501'; END IF;
 SELECT t.id INTO v_tid FROM public.srk_technicians t
 WHERE t.auth_user_id=auth.uid() AND t.account_status='active';
 IF v_tid IS NULL THEN RAISE EXCEPTION 'ACTIVE_TECHNICIAN_REQUIRED' USING ERRCODE='42501'; END IF;
 RETURN QUERY
 SELECT b.id,r.id,r.stars,r.review_text,r.created_at,
  COALESCE((SELECT round(avg(p.stars)::numeric,2) FROM public.srk_master_booking_ratings p
   WHERE p.target_user_id=b.customer_user_id AND p.reviewer_role='technician' AND p.moderation_status='published'),0),
  (SELECT count(*) FROM public.srk_master_booking_ratings p
   WHERE p.target_user_id=b.customer_user_id AND p.reviewer_role='technician' AND p.moderation_status='published'),
  cr.id,cr.stars,cr.review_text,cr.created_at
 FROM public.service_bookings b
 JOIN public.srk_booking_technician_assignments a ON a.booking_id=b.id AND a.technician_id=v_tid AND a.assignment_status='completed'
 LEFT JOIN public.srk_master_booking_ratings r ON r.booking_id=b.id
  AND r.reviewer_technician_id=v_tid AND r.reviewer_role='technician'
 LEFT JOIN public.srk_master_booking_ratings cr ON cr.booking_id=b.id
  AND cr.target_technician_id=v_tid AND cr.reviewer_role='customer'
 WHERE b.status='completed' AND b.completion_approval_status='approved'
  AND b.customer_completed_at IS NOT NULL
 ORDER BY b.customer_completed_at DESC;
END;
$function$;
REVOKE ALL ON FUNCTION public.srk_technician_list_master_rating_tasks() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.srk_technician_list_master_rating_tasks() TO authenticated;

CREATE OR REPLACE FUNCTION public.srk_master_technician_rating_summary(p_technician_id uuid)
RETURNS TABLE(average_stars numeric,rating_count bigint)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $function$
BEGIN
 IF auth.uid() IS NULL THEN RAISE EXCEPTION 'LOGIN_REQUIRED' USING ERRCODE='42501'; END IF;
 IF p_technician_id IS NULL THEN RAISE EXCEPTION 'TECHNICIAN_ID_REQUIRED' USING ERRCODE='22023'; END IF;
 RETURN QUERY SELECT COALESCE(round(avg(r.stars)::numeric,2),0),count(*)
 FROM public.srk_master_booking_ratings r
 WHERE r.target_technician_id=p_technician_id AND r.reviewer_role='customer' AND r.moderation_status='published';
END;
$function$;
REVOKE ALL ON FUNCTION public.srk_master_technician_rating_summary(uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.srk_master_technician_rating_summary(uuid) TO authenticated;

CREATE OR REPLACE FUNCTION public.srk_master_report_booking_rating(
 p_rating_id uuid,p_reason text,p_details text DEFAULT NULL
) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $function$
DECLARE v_uid uuid:=auth.uid(); v_tid uuid; v_rating public.srk_master_booking_ratings%rowtype; v_id uuid; v_role text;
BEGIN
 IF v_uid IS NULL THEN RAISE EXCEPTION 'LOGIN_REQUIRED' USING ERRCODE='42501'; END IF;
 IF p_rating_id IS NULL OR p_reason IS NULL OR length(btrim(p_reason)) NOT BETWEEN 5 AND 500
  OR (p_details IS NOT NULL AND length(btrim(p_details))>1000) THEN
  RAISE EXCEPTION 'INVALID_RATING_REPORT' USING ERRCODE='22023';
 END IF;
 SELECT * INTO v_rating FROM public.srk_master_booking_ratings WHERE id=p_rating_id AND moderation_status='published';
 IF NOT FOUND THEN RAISE EXCEPTION 'PUBLISHED_RATING_REQUIRED' USING ERRCODE='55000'; END IF;
 SELECT t.id INTO v_tid FROM public.srk_technicians t WHERE t.auth_user_id=v_uid AND t.account_status='active';
 IF v_rating.reviewer_role='technician' AND v_rating.target_user_id=v_uid THEN
  v_role:='customer'; v_tid:=NULL;
 ELSIF v_rating.reviewer_role='customer' AND v_rating.target_technician_id=v_tid AND v_tid IS NOT NULL THEN
  v_role:='technician';
 ELSE
  RAISE EXCEPTION 'ONLY_RATING_SUBJECT_CAN_REPORT' USING ERRCODE='42501';
 END IF;
 INSERT INTO public.srk_master_rating_reports(rating_id,reporter_role,reporter_user_id,reporter_technician_id,reason,details)
 VALUES(p_rating_id,v_role,v_uid,v_tid,btrim(p_reason),nullif(btrim(coalesce(p_details,'')),''))
 RETURNING id INTO v_id;
 RETURN v_id;
END;
$function$;
REVOKE ALL ON FUNCTION public.srk_master_report_booking_rating(uuid,text,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.srk_master_report_booking_rating(uuid,text,text) TO authenticated;

CREATE OR REPLACE FUNCTION public.srk_admin_list_master_booking_ratings(p_limit integer DEFAULT 200)
RETURNS TABLE(
 rating_id uuid,booking_id uuid,reviewer_role text,reviewer_user_id uuid,reviewer_technician_id uuid,
 target_user_id uuid,target_technician_id uuid,stars smallint,review_text text,
 moderation_status text,created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $function$
BEGIN
 IF auth.uid() IS NULL OR NOT public.is_srk_admin() THEN RAISE EXCEPTION 'ADMIN_ACCESS_REQUIRED' USING ERRCODE='42501'; END IF;
 IF p_limit IS NULL OR p_limit NOT BETWEEN 1 AND 500 THEN RAISE EXCEPTION 'INVALID_LIMIT' USING ERRCODE='22023'; END IF;
 RETURN QUERY SELECT r.id,r.booking_id,r.reviewer_role,r.reviewer_user_id,r.reviewer_technician_id,
  r.target_user_id,r.target_technician_id,r.stars,r.review_text,r.moderation_status,r.created_at
 FROM public.srk_master_booking_ratings r ORDER BY r.created_at DESC LIMIT p_limit;
END;
$function$;
REVOKE ALL ON FUNCTION public.srk_admin_list_master_booking_ratings(integer) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.srk_admin_list_master_booking_ratings(integer) TO authenticated;

CREATE OR REPLACE FUNCTION public.srk_admin_list_master_rating_reports(p_limit integer DEFAULT 200)
RETURNS TABLE(
 report_id uuid,rating_id uuid,booking_id uuid,reporter_role text,reporter_user_id uuid,
 reason text,details text,status text,created_at timestamptz,resolution_note text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $function$
BEGIN
 IF auth.uid() IS NULL OR NOT public.is_srk_admin() THEN RAISE EXCEPTION 'ADMIN_ACCESS_REQUIRED' USING ERRCODE='42501'; END IF;
 IF p_limit IS NULL OR p_limit NOT BETWEEN 1 AND 500 THEN RAISE EXCEPTION 'INVALID_LIMIT' USING ERRCODE='22023'; END IF;
 RETURN QUERY SELECT q.id,q.rating_id,r.booking_id,q.reporter_role,q.reporter_user_id,
  q.reason,q.details,q.status,q.created_at,q.resolution_note
 FROM public.srk_master_rating_reports q
 JOIN public.srk_master_booking_ratings r ON r.id=q.rating_id
 ORDER BY q.created_at DESC LIMIT p_limit;
END;
$function$;
REVOKE ALL ON FUNCTION public.srk_admin_list_master_rating_reports(integer) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.srk_admin_list_master_rating_reports(integer) TO authenticated;

CREATE OR REPLACE FUNCTION public.srk_admin_resolve_master_rating_report(
 p_report_id uuid,p_decision text,p_note text
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $function$
DECLARE q public.srk_master_rating_reports%rowtype; r public.srk_master_booking_ratings%rowtype; v_after text;
BEGIN
 IF auth.uid() IS NULL OR NOT public.is_srk_admin() THEN RAISE EXCEPTION 'ADMIN_ACCESS_REQUIRED' USING ERRCODE='42501'; END IF;
 IF p_report_id IS NULL OR p_decision IS NULL OR p_decision NOT IN ('dismiss','hide_rating','restore_rating')
  OR p_note IS NULL OR length(btrim(p_note)) NOT BETWEEN 5 AND 1000 THEN
  RAISE EXCEPTION 'INVALID_RATING_REPORT_DECISION' USING ERRCODE='22023';
 END IF;
 SELECT * INTO q FROM public.srk_master_rating_reports WHERE id=p_report_id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'RATING_REPORT_NOT_FOUND' USING ERRCODE='P0002'; END IF;
 IF q.status<>'pending' THEN RAISE EXCEPTION 'RATING_REPORT_ALREADY_RESOLVED' USING ERRCODE='55000'; END IF;
 SELECT * INTO r FROM public.srk_master_booking_ratings WHERE id=q.rating_id FOR UPDATE;
 IF p_decision='hide_rating' AND r.moderation_status='published' THEN
  PERFORM public.srk_admin_moderate_master_rating(r.id,'hide',btrim(p_note));
 ELSIF p_decision='restore_rating' AND r.moderation_status='hidden' THEN
  PERFORM public.srk_admin_moderate_master_rating(r.id,'restore',btrim(p_note));
 ELSIF p_decision IN ('hide_rating','restore_rating') THEN
  RAISE EXCEPTION 'RATING_NOT_IN_EXPECTED_MODERATION_STATE' USING ERRCODE='55000';
 END IF;
 v_after:=CASE WHEN p_decision='dismiss' THEN 'dismissed' ELSE 'actioned' END;
 UPDATE public.srk_master_rating_reports SET status=v_after,reviewed_by=auth.uid(),
  reviewed_at=clock_timestamp(),resolution_note=btrim(p_note) WHERE id=q.id;
 INSERT INTO public.srk_master_rating_report_events(report_id,admin_user_id,decision,note,before_status,after_status)
 VALUES(q.id,auth.uid(),p_decision,btrim(p_note),q.status,v_after);
 RETURN jsonb_build_object('success',true,'report_id',q.id,'status',v_after);
END;
$function$;
REVOKE ALL ON FUNCTION public.srk_admin_resolve_master_rating_report(uuid,text,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.srk_admin_resolve_master_rating_report(uuid,text,text) TO authenticated;
