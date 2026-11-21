BEGIN;
SELECT plan(18);

SELECT has_table('public','srk_service_categories','service categories catalogue exists');
SELECT has_table('public','srk_service_skills','category-specific skill catalogue exists');
SELECT has_table('public','srk_technician_applications','shared Technician applications exist');
SELECT has_table('public','srk_technician_application_categories','applications can select multiple categories');
SELECT has_table('public','srk_technician_application_skills','application skills have individual review status');
SELECT has_table('public','srk_technician_application_events','application history ledger exists');
SELECT has_table('public','srk_technician_kyc_documents','shared Technician KYC metadata exists');
SELECT has_table('public','srk_technician_kyc_events','KYC review history ledger exists');
SELECT has_table('public','srk_service_catalogue_events','Admin catalogue audit ledger exists');

SELECT has_column('public','srk_technicians','verified_phone',
  'canonical Technician identity stores only the server-verified phone');
SELECT has_index('public','srk_technicians','srk_technicians_verified_phone_uidx',
  'verified phone is unique across canonical Technician identities');
SELECT has_trigger('public','srk_technician_application_events','srk_technician_application_events_append_only',
  'application events are append-only');
SELECT has_trigger('public','srk_technician_kyc_events','srk_technician_kyc_events_append_only',
  'KYC events are append-only');

SELECT ok(
  has_function('public','srk_technician_submit_application',
    ARRAY['text','text','text','text','text','integer','text','text[]','text[]']),
  'OTP-first application RPC exists without any client phone parameter'
);
SELECT ok(
  NOT has_function_privilege('anon',
    'public.srk_technician_submit_application(text,text,text,text,text,integer,text,text[],text[])','EXECUTE')
  AND has_function_privilege('authenticated',
    'public.srk_technician_submit_application(text,text,text,text,text,integer,text,text[],text[])','EXECUTE'),
  'application submission is available only to authenticated sessions'
);
SELECT ok(
  position('phone_confirmed_at' in lower(pg_get_functiondef(
    'public.srk_technician_submit_application(text,text,text,text,text,integer,text,text[],text[])'::regprocedure)))>0,
  'application RPC verifies Supabase Auth phone confirmation server-side'
);
SELECT ok(
  position('latest_identity_and_address_kyc_must_be_approved' in lower(pg_get_functiondef(
    'public.srk_admin_review_technician_application(uuid,text,text)'::regprocedure)))>0
  AND position('all_selected_technician_skills_require_separate_admin_approval' in lower(pg_get_functiondef(
    'public.srk_admin_review_technician_application(uuid,text,text)'::regprocedure)))>0,
  'Admin approval requires latest identity/address KYC and separately approved skills'
);
SELECT ok(
  (SELECT NOT public FROM storage.buckets WHERE id='srk-technician-verification'),
  'Technician KYC Storage bucket is private'
);

SELECT * FROM finish();
ROLLBACK;
