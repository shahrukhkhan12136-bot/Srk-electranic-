begin;
select plan(21);
select has_table('public','srk_electrician_verification_documents','private electrician KYC document table exists');
select has_table('public','srk_electrician_verification_document_events','append-only KYC audit table exists');
select has_function('public','srk_electrician_submit_verification_document',array['text','text','text','text','bigint'],'electrician KYC submit RPC exists');
select has_function('public','srk_electrician_list_my_verification_documents',array[]::text[],'electrician KYC owner projection exists');
select has_function('public','srk_admin_list_electrician_verification_documents',array['integer'],'Main Admin KYC queue exists');
select has_function('public','srk_admin_review_electrician_document',array['uuid','text','text'],'Main Admin KYC review RPC exists');
select has_function('public','srk_admin_set_electrician_active',array['uuid','boolean'],'Main Admin activation RPC exists');
select has_function('public','srk_electrician_can_delete_unregistered_kyc_object',array['text'],'safe orphan-object cleanup helper exists');
select has_trigger('public','electrician_profiles','srk_guard_electrician_kyc_before_activation','profile activation is guarded by OTP and latest required KYC');
select has_trigger('public','electrician_profiles','srk_guard_electrician_rate_tier_activation','rate tier changes are guarded by audited Admin RPC and KYC');
select ok(has_function_privilege('authenticated','public.srk_electrician_submit_verification_document(text,text,text,text,bigint)','EXECUTE')
  and not has_function_privilege('anon','public.srk_electrician_submit_verification_document(text,text,text,text,bigint)','EXECUTE'),
  'KYC submit RPC is authenticated-only');
select ok(has_function_privilege('authenticated','public.srk_electrician_list_my_verification_documents()','EXECUTE')
  and not has_function_privilege('anon','public.srk_electrician_list_my_verification_documents()','EXECUTE'),
  'KYC owner projection is authenticated-only');
select ok(has_function_privilege('authenticated','public.srk_admin_list_electrician_verification_documents(integer)','EXECUTE')
  and not has_function_privilege('anon','public.srk_admin_list_electrician_verification_documents(integer)','EXECUTE'),
  'Admin KYC queue RPC is authenticated-only with Main Admin check inside');
select ok(has_function_privilege('authenticated','public.srk_admin_review_electrician_document(uuid,text,text)','EXECUTE')
  and not has_function_privilege('anon','public.srk_admin_review_electrician_document(uuid,text,text)','EXECUTE'),
  'KYC review RPC is authenticated-only with Main Admin check inside');
select ok(has_function_privilege('authenticated','public.srk_admin_set_electrician_active(uuid,boolean)','EXECUTE')
  and not has_function_privilege('anon','public.srk_admin_set_electrician_active(uuid,boolean)','EXECUTE'),
  'activation RPC is authenticated-only with Main Admin check inside');
select ok(not has_table_privilege('authenticated','public.srk_electrician_verification_documents','SELECT')
  and not has_table_privilege('anon','public.srk_electrician_verification_documents','SELECT'),
  'KYC document table has no direct client SELECT');
select ok(exists(select 1 from storage.buckets where id='srk-electrician-verification' and public is false
  and file_size_limit=5242880),
  'KYC Storage bucket is private and limited to 5 MB');
select ok(exists(select 1 from pg_policies where schemaname='storage' and tablename='objects' and policyname='srk_electrician_kyc_owner_upload')
  and exists(select 1 from pg_policies where schemaname='storage' and tablename='objects' and policyname='srk_electrician_kyc_owner_or_admin_read')
  and exists(select 1 from pg_policies where schemaname='storage' and tablename='objects' and policyname='srk_electrician_kyc_owner_delete_unregistered'),
  'Storage policies cover owner upload, owner/Admin read and unregistered-only cleanup');
select ok(position('LATEST_IDENTITY_AND_ADDRESS_KYC_DOCUMENTS_MUST_BE_APPROVED' in
  pg_get_functiondef('public.srk_admin_set_electrician_active(uuid,boolean)'::regprocedure))>0,
  'Admin activation RPC requires latest identity and address proofs approved');
select ok(position('LATEST_IDENTITY_AND_ADDRESS_KYC_DOCUMENTS_MUST_BE_APPROVED_BEFORE_RATE_TIER' in
  pg_get_functiondef('public.srk_guard_electrician_rate_tier_activation()'::regprocedure))>0,
  'rate tier cannot be assigned before latest required KYC documents are approved');
select ok(position('public.is_srk_admin()' in
  pg_get_functiondef('public.srk_admin_review_electrician_document(uuid,text,text)'::regprocedure))>0,
  'KYC review is restricted to Main Admin, not Support Staff');
select * from finish();
rollback;
