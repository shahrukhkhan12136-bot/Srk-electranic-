-- SRK ELECTRONIC Master: Admin skill-level queue for approved Technician skills.
-- Read-only queue; level assignment continues through the audited existing Admin RPC.
CREATE OR REPLACE FUNCTION public.srk_admin_list_master_skill_level_options()
RETURNS TABLE(
 application_skill_id uuid,
 technician_id uuid,
 technician_name text,
 category_code text,
 category_name text,
 skill_code text,
 skill_name text,
 approved_level_code text,
 available_levels jsonb
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $function$
BEGIN
 IF auth.uid() IS NULL OR NOT public.is_srk_admin() THEN
  RAISE EXCEPTION 'ADMIN_ACCESS_REQUIRED' USING ERRCODE='42501';
 END IF;
 RETURN QUERY
 SELECT
  aps.id,
  a.technician_id,
  a.full_name,
  c.category_code,
  c.display_name,
  s.skill_code,
  s.display_name,
  aps.approved_level_code,
  COALESCE((
   SELECT jsonb_agg(jsonb_build_object('level_code',r.level_code,'level_label',r.level_label) ORDER BY r.level_label)
   FROM public.srk_service_offerings o
   JOIN public.srk_service_rates r ON r.service_code=o.service_code
   WHERE o.category_code=c.category_code AND o.skill_code=s.skill_code AND o.is_active
    AND r.status='active' AND r.effective_from<=clock_timestamp()
    AND (r.effective_to IS NULL OR r.effective_to>clock_timestamp())
  ),'[]'::jsonb)
 FROM public.srk_technician_application_skills aps
 JOIN public.srk_technician_applications a ON a.id=aps.application_id
 JOIN public.srk_service_skills s ON s.id=aps.skill_id
 JOIN public.srk_service_categories c ON c.id=s.category_id
 WHERE a.status='approved' AND aps.review_status='approved'
 ORDER BY a.full_name,c.sort_order,c.display_name,s.display_name;
END;
$function$;
REVOKE ALL ON FUNCTION public.srk_admin_list_master_skill_level_options() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.srk_admin_list_master_skill_level_options() TO authenticated;
COMMENT ON FUNCTION public.srk_admin_list_master_skill_level_options() IS
 'Main Admin read-only queue of approved Technician skills and currently active eligible rate levels; assignment is audited by srk_admin_set_technician_skill_level.';
