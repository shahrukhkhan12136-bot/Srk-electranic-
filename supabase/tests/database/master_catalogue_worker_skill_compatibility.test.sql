BEGIN;
SELECT plan(7);
SELECT has_column('public','srk_service_categories','category_name',
  'legacy Worker review reads category_name from the canonical category label');
SELECT has_column('public','srk_service_skills','service_type_id',
  'legacy Worker review joins service type to the canonical skill identity');
SELECT has_column('public','srk_service_skills','skill_name',
  'legacy Worker review reads the canonical skill display name');
SELECT has_column('public','srk_service_skills','sort_order',
  'legacy Worker review has a stable skill ordering field');
SELECT ok(to_regclass('public.srk_service_types') IS NOT NULL,
  'legacy service-type relation remains available for Worker review RPCs');
SELECT ok(NOT EXISTS(
  SELECT 1 FROM public.srk_service_skills sk
  LEFT JOIN public.srk_service_categories c ON c.id=sk.category_id
  WHERE c.id IS NULL
), 'every canonical skill resolves to its category');
SELECT ok(NOT EXISTS(
  SELECT 1 FROM public.srk_service_skills sk
  JOIN public.srk_service_types st ON st.id=sk.service_type_id
  WHERE st.category_id<>sk.category_id
), 'compatibility service-type projection preserves skill category');
SELECT * FROM finish();
ROLLBACK;
