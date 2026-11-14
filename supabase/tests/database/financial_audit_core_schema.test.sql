BEGIN;
SELECT plan(51);

SELECT ok(to_regclass('public.srk_booking_labour_bills') IS NOT NULL,'immutable labour bill base table exists');
SELECT ok(to_regclass('public.srk_manual_payment_entries') IS NOT NULL,'manual payment base table exists');
SELECT ok(to_regclass('public.srk_electrician_payouts') IS NOT NULL,'electrician payout base table exists');
SELECT ok(to_regclass('public.srk_admin_audit_events') IS NOT NULL,'admin audit event base table exists');
SELECT ok(to_regclass('public.srk_razorpay_refunds') IS NOT NULL,'Razorpay refund base table exists');
SELECT ok(to_regclass('public.srk_booking_refund_requests') IS NOT NULL,'customer refund request base table exists');
SELECT ok(to_regclass('public.srk_manual_refund_entries') IS NOT NULL,'manual refund base table exists');

SELECT ok((SELECT relrowsecurity FROM pg_class WHERE oid=to_regclass('public.srk_booking_labour_bills')),'labour bill RLS enabled');
SELECT ok((SELECT relrowsecurity FROM pg_class WHERE oid=to_regclass('public.srk_manual_payment_entries')),'manual payment RLS enabled');
SELECT ok((SELECT relrowsecurity FROM pg_class WHERE oid=to_regclass('public.srk_electrician_payouts')),'payout RLS enabled');
SELECT ok((SELECT relrowsecurity FROM pg_class WHERE oid=to_regclass('public.srk_admin_audit_events')),'audit RLS enabled');
SELECT ok((SELECT relrowsecurity FROM pg_class WHERE oid=to_regclass('public.srk_razorpay_refunds')),'Razorpay refund RLS enabled');
SELECT ok((SELECT relrowsecurity FROM pg_class WHERE oid=to_regclass('public.srk_booking_refund_requests')),'refund request RLS enabled');
SELECT ok((SELECT relrowsecurity FROM pg_class WHERE oid=to_regclass('public.srk_manual_refund_entries')),'manual refund RLS enabled');

SELECT ok(NOT has_table_privilege('anon','public.srk_manual_payment_entries','SELECT'),'anonymous cannot read manual payments');
SELECT ok(NOT has_table_privilege('authenticated','public.srk_manual_payment_entries','SELECT'),'authenticated cannot directly read manual payments');
SELECT ok(has_table_privilege('authenticated','public.srk_electrician_payouts','SELECT'),'authenticated has payout SELECT grant for RLS-filtered self history');
SELECT ok(EXISTS (
  SELECT 1 FROM pg_policies
  WHERE schemaname='public' AND tablename='srk_electrician_payouts'
    AND policyname='srk_read_authorized_electrician_payouts'
    AND qual ILIKE '%is_srk_admin%' AND qual ILIKE '%electrician_profiles%'
    AND qual ILIKE '%user_id%'
),'payout SELECT policy permits only Main Admin or the owning electrician');
SELECT ok(NOT has_table_privilege('authenticated','public.srk_admin_audit_events','SELECT'),'authenticated cannot read audit events directly');
SELECT ok(NOT has_table_privilege('authenticated','public.srk_razorpay_refunds','SELECT'),'authenticated cannot read provider refund records directly');
SELECT ok(NOT has_table_privilege('authenticated','public.srk_booking_refund_requests','SELECT'),'authenticated cannot read refund requests directly');
SELECT ok(NOT has_table_privilege('authenticated','public.srk_manual_refund_entries','SELECT'),'authenticated cannot read manual refund records directly');
SELECT ok(NOT has_table_privilege('authenticated','public.srk_booking_labour_bills','SELECT'),'authenticated cannot read immutable labour bill snapshots directly');

SELECT ok(EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid='public.srk_manual_payment_entries'::regclass AND contype='u' AND pg_get_constraintdef(oid)='UNIQUE (booking_id)'),'one manual payment entry per booking');
SELECT ok(EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid='public.srk_electrician_payouts'::regclass AND contype='u' AND pg_get_constraintdef(oid)='UNIQUE (booking_id)'),'one payout row per booking');
SELECT ok(EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid='public.srk_razorpay_refunds'::regclass AND contype='u' AND pg_get_constraintdef(oid)='UNIQUE (booking_id)'),'one full Razorpay refund record per booking');
SELECT ok(EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid='public.srk_booking_refund_requests'::regclass AND contype='u' AND pg_get_constraintdef(oid)='UNIQUE (booking_id)'),'one refund request per booking');
SELECT ok(EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid='public.srk_manual_refund_entries'::regclass AND contype='u' AND pg_get_constraintdef(oid)='UNIQUE (booking_id)'),'one manual refund entry per booking');
SELECT ok(EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid='public.srk_manual_refund_entries'::regclass AND contype='u' AND pg_get_constraintdef(oid)='UNIQUE (payment_entry_id)'),'manual refund cannot be duplicated against one payment entry');
SELECT ok(EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid='public.srk_booking_refund_requests'::regclass AND contype='f' AND pg_get_constraintdef(oid) ILIKE '%REFERENCES srk_razorpay_refunds(id)%'),'refund request references the Razorpay refund row');
SELECT ok(EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid='public.srk_manual_refund_entries'::regclass AND contype='f' AND pg_get_constraintdef(oid) ILIKE '%REFERENCES srk_manual_payment_entries(id)%'),'manual refund references its source manual payment');
SELECT ok(EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid='public.srk_admin_audit_events'::regclass AND conname='srk_admin_audit_events_entity_type_check' AND pg_get_constraintdef(oid) ILIKE '%razorpay_refund%'),'audit event allow-list includes Razorpay refund events');
SELECT ok(EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid='public.srk_razorpay_refunds'::regclass AND conname='srk_razorpay_refunds_amount_paise_match' AND pg_get_constraintdef(oid) ILIKE '%amount_paise%' AND pg_get_constraintdef(oid) ILIKE '%round%'),'Razorpay amount and integer paise must reconcile');
SELECT ok(to_regclass('public.srk_booking_refund_requests_customer_created_idx') IS NOT NULL,'customer refund history has a customer/created index');

SELECT ok((SELECT prosecdef FROM pg_proc WHERE oid='public.is_srk_admin()'::regprocedure),'Main Admin identity helper remains SECURITY DEFINER');
SELECT ok((SELECT proconfig @> ARRAY['search_path=""'] FROM pg_proc WHERE oid='public.is_srk_admin()'::regprocedure),'Main Admin identity helper has empty search_path');
SELECT ok(NOT has_function_privilege('anon','public.is_srk_admin()','EXECUTE') AND has_function_privilege('authenticated','public.is_srk_admin()','EXECUTE'),'Main Admin identity helper is callable only by authenticated/service roles');
SELECT ok((SELECT prosecdef FROM pg_proc WHERE oid='public.srk_capture_admin_audit_event()'::regprocedure),'generic audit trigger is SECURITY DEFINER');
SELECT ok((SELECT proconfig @> ARRAY['search_path=""'] FROM pg_proc WHERE oid='public.srk_capture_admin_audit_event()'::regprocedure),'generic audit trigger has empty search_path');
SELECT ok(NOT has_function_privilege('anon','public.srk_capture_admin_audit_event()','EXECUTE'),'anon cannot directly execute generic audit trigger');
SELECT ok(NOT has_function_privilege('authenticated','public.srk_capture_admin_audit_event()','EXECUTE'),'authenticated cannot directly execute generic audit trigger');
SELECT ok((SELECT prosecdef FROM pg_proc WHERE oid='public.srk_capture_razorpay_refund_audit_event()'::regprocedure),'Razorpay audit trigger is SECURITY DEFINER');
SELECT ok((SELECT proconfig @> ARRAY['search_path=""'] FROM pg_proc WHERE oid='public.srk_capture_razorpay_refund_audit_event()'::regprocedure),'Razorpay audit trigger has empty search_path');
SELECT ok(NOT has_function_privilege('anon','public.srk_capture_razorpay_refund_audit_event()','EXECUTE'),'anon cannot directly execute Razorpay audit trigger');

SELECT ok(EXISTS (SELECT 1 FROM pg_trigger WHERE tgname='srk_audit_service_bookings' AND tgrelid='public.service_bookings'::regclass AND NOT tgisinternal AND tgfoid='public.srk_capture_admin_audit_event()'::regprocedure),'service booking audit trigger installed');
SELECT ok(EXISTS (SELECT 1 FROM pg_trigger WHERE tgname='srk_audit_electrician_profiles' AND tgrelid='public.electrician_profiles'::regclass AND NOT tgisinternal AND tgfoid='public.srk_capture_admin_audit_event()'::regprocedure),'electrician profile audit trigger installed');
SELECT ok(EXISTS (SELECT 1 FROM pg_trigger WHERE tgname='srk_audit_electrician_applications' AND tgrelid='public.electrician_applications'::regclass AND NOT tgisinternal AND tgfoid='public.srk_capture_admin_audit_event()'::regprocedure),'electrician application audit trigger installed');
SELECT ok(EXISTS (SELECT 1 FROM pg_trigger WHERE tgname='srk_audit_manual_payment_entries' AND tgrelid='public.srk_manual_payment_entries'::regclass AND NOT tgisinternal AND tgfoid='public.srk_capture_admin_audit_event()'::regprocedure),'manual payment audit trigger installed');
SELECT ok(EXISTS (SELECT 1 FROM pg_trigger WHERE tgname='srk_audit_manual_refund_entries' AND tgrelid='public.srk_manual_refund_entries'::regclass AND NOT tgisinternal AND tgfoid='public.srk_capture_admin_audit_event()'::regprocedure),'manual refund audit trigger installed');
SELECT ok(EXISTS (SELECT 1 FROM pg_trigger WHERE tgname='srk_audit_electrician_payouts' AND tgrelid='public.srk_electrician_payouts'::regclass AND NOT tgisinternal AND tgfoid='public.srk_capture_admin_audit_event()'::regprocedure),'payout audit trigger installed');
SELECT ok(EXISTS (SELECT 1 FROM pg_trigger WHERE tgname='srk_audit_razorpay_refunds' AND tgrelid='public.srk_razorpay_refunds'::regclass AND NOT tgisinternal AND tgfoid='public.srk_capture_razorpay_refund_audit_event()'::regprocedure),'Razorpay refund audit trigger installed');

SELECT * FROM finish();
ROLLBACK;

