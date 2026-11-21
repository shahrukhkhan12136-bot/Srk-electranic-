-- Admin read model for the configurable category, skill, service and rate catalogue.
CREATE OR REPLACE FUNCTION public.srk_admin_list_master_service_taxonomy()
RETURNS TABLE(
 category_code text,category_name text,category_active boolean,sort_order integer,
 skill_code text,skill_name text,skill_active boolean,requires_separate_assessment boolean
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $function$
BEGIN
 IF auth.uid() IS NULL OR NOT public.is_srk_admin() THEN
  RAISE EXCEPTION 'ADMIN_ACCESS_REQUIRED' USING ERRCODE='42501';
 END IF;
 RETURN QUERY
 SELECT c.category_code,c.display_name,c.is_active,c.sort_order,
  s.skill_code,s.display_name,s.is_active,s.requires_separate_assessment
 FROM public.srk_service_categories c
 LEFT JOIN public.srk_service_skills s ON s.category_id=c.id
 ORDER BY c.sort_order,c.category_code,s.skill_code;
END;
$function$;
REVOKE ALL ON FUNCTION public.srk_admin_list_master_service_taxonomy() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.srk_admin_list_master_service_taxonomy() TO authenticated;
COMMENT ON FUNCTION public.srk_admin_list_master_service_taxonomy() IS
 'Main Admin read-only category and skill taxonomy for the Master Service Catalogue UI.';
