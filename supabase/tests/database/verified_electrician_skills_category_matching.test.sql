BEGIN;
SELECT plan(21);

SELECT has_column('public','electrician_applications','requested_skill_keys','applications store canonical requested skills');
SELECT has_column('public','electrician_profiles','requested_skill_keys','profiles retain applicant-declared skills');
SELECT has_column('public','electrician_profiles','approved_skill_keys','profiles store separately Admin-verified skills');
SELECT has_table('public','srk_electrician_skill_catalog','canonical electrician skill catalog exists');
SELECT has_table('public','srk_customer_category_skill_rules','Admin-configurable customer category mapping exists');
SELECT has_table('public','srk_electrician_skill_audit','verified skill audit exists');
SELECT has_table('public','srk_customer_category_skill_rule_audit','category mapping audit exists');

SELECT ok((SELECT relrowsecurity FROM pg_class WHERE oid='public.srk_electrician_skill_catalog'::regclass),'skill catalog RLS enabled');
SELECT ok((SELECT relrowsecurity FROM pg_class WHERE oid='public.srk_customer_category_skill_rules'::regclass),'category mapping RLS enabled');

SELECT has_function('public','srk_admin_set_electrician_skills',ARRAY['uuid','text[]'],'Admin skill verification RPC exists');
SELECT has_function('public','srk_admin_set_category_skill_rules',ARRAY['text','text[]'],'Admin category mapping RPC exists');

SELECT ok(
  pg_get_functiondef('public.srk_admin_offer_booking(uuid)'::regprocedure) ILIKE '%srk_customer_category_skill_rules%'
  AND pg_get_functiondef('public.srk_admin_offer_booking(uuid)'::regprocedure) ILIKE '%e.approved_skill_keys%',
  'offer matching requires a category rule and an Admin-verified skill'
);
SELECT ok(
  pg_get_functiondef('public.srk_admin_offer_booking(uuid)'::regprocedure) ILIKE '%category_skill_mapping_missing%'
  AND pg_get_functiondef('public.srk_admin_offer_booking(uuid)'::regprocedure) ILIKE '%no_verified_skill_match%',
  'missing category mapping and missing verified skill fail closed'
);
SELECT ok(
  pg_get_functiondef('public.srk_admin_offer_booking(uuid)'::regprocedure) NOT ILIKE '%e.skills%'
  AND pg_get_functiondef('public.srk_admin_offer_booking(uuid)'::regprocedure) NOT ILIKE '%a.skills%',
  'free-text skills are never used for automatic eligibility'
);
SELECT ok(
  pg_get_functiondef('public.srk_admin_offer_booking(uuid)'::regprocedure) ILIKE '%approved_rate_tier IS NOT NULL%'
  AND pg_get_functiondef('public.srk_admin_offer_booking(uuid)'::regprocedure) ILIKE '%rate_tier_approved_at IS NOT NULL%',
  'verified skill matching still requires the complete Admin-approved rate tier'
);
SELECT ok(
  pg_get_functiondef('public.srk_admin_set_electrician_skills(uuid,text[])') ILIKE '%v_new <@ v_profile.requested_skill_keys%'
  AND pg_get_functiondef('public.srk_admin_set_electrician_skills(uuid,text[])') ILIKE '%verification_status<>''approved''%',
  'Admin can verify only applicant-declared skills after KYC approval'
);
SELECT ok(
  pg_get_functiondef('public.srk_guard_electrician_approved_skills()') ILIKE '%electrician_skill_authorizations%'
  AND (SELECT prosecdef FROM pg_proc WHERE oid='public.srk_guard_electrician_approved_skills()'::regprocedure),
  'direct profile skill edits are blocked by a SECURITY DEFINER authorization guard'
);
SELECT ok(
  pg_get_functiondef('public.srk_admin_review_application(uuid,text)') ILIKE '%a.requested_skill_keys%'
  AND pg_get_functiondef('public.srk_admin_review_application(uuid,text)') ILIKE '%ARRAY[]::text[]%',
  'KYC approval copies requested skills but approves none automatically'
);
SELECT ok(
  pg_get_functiondef('public.srk_admin_set_electrician_skills(uuid,text[])') ILIKE '%srk_electrician_skill_audit%',
  'Admin verified skill changes are audited'
);
SELECT ok(
  pg_get_functiondef('public.srk_admin_set_category_skill_rules(text,text[])') ILIKE '%srk_customer_category_skill_rule_audit%',
  'category mapping changes are audited'
);
SELECT ok(
  pg_get_functiondef('public.srk_get_my_offer_details()') ILIKE '%p.approved_skill_keys%'
  AND pg_get_functiondef('public.srk_get_my_offer_details()') ILIKE '%b.selected_category%',
  'electrician offer details include own verified skills and customer work category'
);
SELECT ok(
  pg_get_functiondef('public.srk_validate_electrician_requested_skills()') ILIKE '%srk_electrician_skill_catalog%'
  AND pg_get_functiondef('public.srk_validate_electrician_requested_skills()') ILIKE '%cardinality(NEW.requested_skill_keys)>20%',
  'application skill declarations are allowlisted and capped'
);
SELECT ok(
  NOT has_table_privilege('anon','public.srk_customer_category_skill_rules','SELECT')
  AND NOT has_table_privilege('authenticated','public.srk_customer_category_skill_rules','INSERT')
  AND NOT has_table_privilege('authenticated','public.srk_customer_category_skill_rules','UPDATE')
  AND NOT has_table_privilege('authenticated','public.srk_customer_category_skill_rules','DELETE'),
  'category mapping cannot be changed directly through Data API'
);
SELECT ok(
  EXISTS(SELECT 1 FROM pg_trigger WHERE tgname='srk_guard_electrician_approved_skills' AND NOT tgisinternal),
  'approved skill guard trigger is installed'
);

SELECT * FROM finish();
ROLLBACK;
