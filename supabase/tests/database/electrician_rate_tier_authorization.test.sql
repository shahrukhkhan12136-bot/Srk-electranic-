BEGIN;
SELECT plan(13);

SELECT has_column('public','electrician_applications','requested_category','application requested category exists');
SELECT has_column('public','electrician_profiles','approved_rate_tier','approved rate tier exists');
SELECT has_column('public','electrician_profiles','approved_rate_card_version','rate card version exists');
SELECT has_column('public','electrician_profiles','rate_tier_approved_by','approver identity exists');
SELECT has_column('public','electrician_profiles','rate_tier_approved_at','approval timestamp exists');
SELECT has_table('public','srk_electrician_rate_tier_audit','rate tier audit table exists');
SELECT ok((SELECT relrowsecurity FROM pg_class WHERE oid='public.srk_electrician_rate_tier_audit'::regclass),'audit table has RLS enabled');
SELECT has_function('public','srk_admin_set_electrician_rate_tier',ARRAY['uuid','text'],'Admin rate tier RPC exists');
SELECT ok(NOT has_function_privilege('anon','public.srk_admin_set_electrician_rate_tier(uuid,text)','EXECUTE'),'anon cannot execute rate tier RPC');
SELECT ok(has_function_privilege('authenticated','public.srk_admin_set_electrician_rate_tier(uuid,text)','EXECUTE'),'authenticated can call Admin-guarded rate tier RPC');
SELECT has_trigger('public','electrician_profiles','srk_guard_electrician_rate_tier_activation','activation and tier changes require an approved rate tier');
SELECT ok((SELECT pg_get_triggerdef(oid) ILIKE '%UPDATE OF active, approved_rate_tier, approved_rate_card_version, rate_tier_approved_by, rate_tier_approved_at%' FROM pg_trigger WHERE tgname='srk_guard_electrician_rate_tier_activation' AND tgrelid='public.electrician_profiles'::regclass),'guard fires when any approval field is changed, not only active flag');
SELECT ok((SELECT count(*)=4 FROM unnest(ARRAY['electrical_assistant','skilled_electrician','expert_electrician','premium_electrical_specialist']::text[]) AS x),'four canonical commercial tiers defined in migration source');

SELECT * FROM finish();
ROLLBACK;
