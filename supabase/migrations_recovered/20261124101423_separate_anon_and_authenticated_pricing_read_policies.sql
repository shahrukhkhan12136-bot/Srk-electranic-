DROP POLICY IF EXISTS srk_pricing_rules_read_active_or_admin ON public.srk_service_pricing_rules;

CREATE POLICY srk_pricing_rules_read_active_anon
ON public.srk_service_pricing_rules
FOR SELECT TO anon
USING (
 effective_from<=now()
 AND (effective_to IS NULL OR effective_to>now())
 AND EXISTS (
  SELECT 1 FROM public.srk_service_categories c
  JOIN public.srk_service_types s ON s.category_id=c.id
  WHERE c.id=srk_service_pricing_rules.category_id
   AND s.id=srk_service_pricing_rules.service_type_id
   AND c.is_active AND s.is_active
 )
);

CREATE POLICY srk_pricing_rules_read_active_or_admin
ON public.srk_service_pricing_rules
FOR SELECT TO authenticated
USING (
 public.srk_has_admin_permission('catalog.manage')
 OR (
  effective_from<=now()
  AND (effective_to IS NULL OR effective_to>now())
  AND EXISTS (
   SELECT 1 FROM public.srk_service_categories c
   JOIN public.srk_service_types s ON s.category_id=c.id
   WHERE c.id=srk_service_pricing_rules.category_id
    AND s.id=srk_service_pricing_rules.service_type_id
    AND c.is_active AND s.is_active
  )
 )
);