BEGIN;
SELECT plan(13);
SELECT has_column('public','electrician_profiles','user_id','legacy electrician profile identity column exists');
SELECT has_column('public','electrician_profiles','auth_user_id','Auth identity column is explicitly present');
SELECT has_index('public','electrician_profiles','electrician_profiles_auth_user_id_uidx','one Auth user cannot be linked to multiple electrician profiles');
SELECT has_trigger('public','electrician_profiles','a_srk_sync_electrician_profile_identity','identity columns are synchronized before other profile triggers');
SELECT has_trigger('public','electrician_profiles','srk_guard_electrician_profile_identity_link','profile identity links are guarded');
SELECT ok(
  position('phone_confirmed_at' IN pg_get_functiondef('public.srk_guard_electrician_profile_identity_link()'::regprocedure)) > 0
  AND position('ELECTRICIAN_PROFILE_PHONE_NOT_VERIFIED_OR_MISMATCHED' IN pg_get_functiondef('public.srk_guard_electrician_profile_identity_link()'::regprocedure)) > 0,
  'profile link requires a phone-confirmed Auth user with matching normalized phone'
);
SELECT ok(
  position('AMBIGUOUS_VERIFIED_AUTH_USERS_FOR_ELECTRICIAN_PHONE' IN pg_get_functiondef('public.srk_guard_electrician_profile_identity_link()'::regprocedure)) > 0
  AND position('v_auth_user_count<>1' IN pg_get_functiondef('public.srk_guard_electrician_profile_identity_link()'::regprocedure)) > 0,
  'profile link is rejected if multiple verified Auth users share the phone'
);
SELECT ok(
  position('AMBIGUOUS_APPROVED_ELECTRICIAN_PHONE_PROFILE' IN pg_get_functiondef('public.srk_guard_electrician_profile_identity_link()'::regprocedure)) > 0,
  'profile link fails closed when another approved profile has the same phone'
);
SELECT ok(
  position('v_profile_count=1' IN pg_get_functiondef('public.srk_link_electrician_profile()'::regprocedure)) > 0
  AND position('v_auth_user_count<>1' IN pg_get_functiondef('public.srk_link_electrician_profile()'::regprocedure)) > 0
  AND position('p.user_id IS NULL' IN pg_get_functiondef('public.srk_link_electrician_profile()'::regprocedure)) > 0
  AND position('p.auth_user_id IS NULL' IN pg_get_functiondef('public.srk_link_electrician_profile()'::regprocedure)) > 0,
  'Auth hook links only one unique approved profile to one unique verified Auth user'
);
SELECT ok(
  position('ELECTRICIAN_PROFILE_IDENTITY_COLUMNS_MUST_MATCH' IN pg_get_functiondef('public.srk_sync_electrician_profile_identity()'::regprocedure)) > 0,
  'conflicting user_id and auth_user_id values are rejected'
);

SELECT ok(
  (SELECT position('phone' IN pg_get_triggerdef(t.oid)) > 0
     AND position('verification_status' IN pg_get_triggerdef(t.oid)) > 0
   FROM pg_trigger t
   WHERE t.tgrelid='public.electrician_profiles'::regclass
     AND t.tgname='srk_guard_electrician_profile_identity_link'
     AND NOT t.tgisinternal),
  'identity guard also runs when the profile phone or approval status changes'
);


SELECT ok(
  'a_srk_sync_electrician_profile_identity' < 'srk_guard_electrician_profile_identity_link',
  'identity sync trigger sorts before the identity guard trigger'
);
SELECT ok(
  position('v_auth_user_count=1 AND v_profile_count=1' IN pg_get_functiondef('public.srk_admin_review_application(uuid,text)'::regprocedure)) > 0
  AND position('order by u.created_at desc limit 1' IN pg_get_functiondef('public.srk_admin_review_application(uuid,text)'::regprocedure)) = 0,
  'Admin approval links only when both verified Auth user and approved profile are unique'
);

SELECT * FROM finish();
ROLLBACK;
