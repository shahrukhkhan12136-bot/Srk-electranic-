BEGIN;
SELECT plan(10);
SELECT has_column('public','srk_master_technician_payables','commission_recovery_paise','payables track cash commission recovered from later company collections');
SELECT has_table('public','srk_master_technician_commission_dues','cash commission dues are tracked per Technician and booking');
SELECT has_table('public','srk_master_technician_commission_events','cash commission and offsets have an audit trail');
SELECT has_function('public','srk_apply_master_cash_commission_and_online_offset',ARRAY[]::text[]);
SELECT has_function('public','srk_master_wallet_summary',ARRAY[]::text[]);
SELECT has_trigger('public','srk_master_technician_payables','srk_master_apply_cash_commission_online_offset','cash and online commission offset trigger is installed');
SELECT has_trigger('public','srk_master_technician_commission_events','srk_master_technician_commission_events_append_only','commission events are append-only');
SELECT ok((SELECT relrowsecurity FROM pg_class WHERE oid='public.srk_master_technician_commission_dues'::regclass),'commission dues table has RLS enabled');
SELECT ok((SELECT relrowsecurity FROM pg_class WHERE oid='public.srk_master_technician_commission_events'::regclass),'commission event table has RLS enabled');
SELECT ok(NOT has_table_privilege('authenticated','public.srk_master_technician_commission_dues','SELECT')
 AND NOT has_table_privilege('authenticated','public.srk_master_technician_commission_events','SELECT'),
 'commission ledgers cannot be read directly by clients');
SELECT * FROM finish();
ROLLBACK;
