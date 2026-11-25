CREATE POLICY srk_pricing_rules_read_active_public
ON public.srk_service_pricing_rules
FOR SELECT TO anon,authenticated
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

CREATE POLICY srk_pricing_hp_tiers_read_active_public
ON public.srk_service_pricing_hp_tiers
FOR SELECT TO anon,authenticated
USING (
 EXISTS (
  SELECT 1 FROM public.srk_service_pricing_rules r
  JOIN public.srk_service_categories c ON c.id=r.category_id
  JOIN public.srk_service_types s ON s.id=r.service_type_id
  WHERE r.id=srk_service_pricing_hp_tiers.pricing_rule_id
   AND r.effective_from<=now()
   AND (r.effective_to IS NULL OR r.effective_to>now())
   AND c.is_active AND s.is_active
 )
);

GRANT SELECT ON TABLE public.srk_service_pricing_rules,public.srk_service_pricing_hp_tiers
TO anon,authenticated;

ALTER FUNCTION public.srk_get_public_service_pricing_options(uuid) SECURITY INVOKER;