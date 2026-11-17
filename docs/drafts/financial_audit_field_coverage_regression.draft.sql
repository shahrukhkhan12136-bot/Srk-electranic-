-- DRAFT ONLY — SRK ELECTRONIC financial audit field coverage regression
-- Not in supabase/tests/database and not auto-discovered by the SQL test runner.
-- Do not execute until the owner approves the audit-field classification policy
-- and the corresponding migration changes are implemented on the Audit Branch.
-- This is a STATIC pgTAP source-contract draft, not a behavioral/runtime test.

BEGIN;
CREATE EXTENSION IF NOT EXISTS pgtap;

SELECT plan(8);

-- Generic audit trigger: preserve recorder identity/time for manual evidence.
SELECT ok(
  position('WHEN ''manual_payment'' THEN ARRAY[''booking_id'',''payment_method'',''amount'',''recorded_by'',''recorded_at'']' IN
    pg_get_functiondef('public.srk_capture_admin_audit_event()'::regprocedure)) > 0,
  'manual payment audit allow-list includes approved recorder metadata'
);

SELECT ok(
  position('WHEN ''manual_refund'' THEN ARRAY[''booking_id'',''payment_entry_id'',''amount'',''recorded_by'',''recorded_at'']' IN
    pg_get_functiondef('public.srk_capture_admin_audit_event()'::regprocedure)) > 0,
  'manual refund audit allow-list includes approved recorder metadata'
);

SELECT ok(
  position('WHEN ''electrician_payout'' THEN ARRAY[''booking_id'',''payout_status'',''payout_method'',''payout_reference'',''payout_note'',''electrician_payable'',''platform_commission'',''paid_at'',''paid_by'']' IN
    pg_get_functiondef('public.srk_capture_admin_audit_event()'::regprocedure)) > 0,
  'electrician payout audit allow-list includes paid_by'
);

-- Dedicated Razorpay audit: add only reviewed, non-secret accounting/actor metadata.
-- Provider IDs, idempotency keys, free-text reasons/errors and payout notes are
-- intentionally excluded from this draft until a masking/retention policy is approved.
SELECT ok(
  position('admin_user_id' IN pg_get_functiondef('public.srk_capture_razorpay_refund_audit_event()'::regprocedure)) > 0,
  'Razorpay audit captures the verified Admin actor field'
);

SELECT ok(
  position('amount_paise' IN pg_get_functiondef('public.srk_capture_razorpay_refund_audit_event()'::regprocedure)) > 0,
  'Razorpay audit captures integer paise amount'
);

SELECT ok(
  position('currency' IN pg_get_functiondef('public.srk_capture_razorpay_refund_audit_event()'::regprocedure)) > 0,
  'Razorpay audit captures currency'
);

SELECT ok(
  position('processed_at' IN pg_get_functiondef('public.srk_capture_razorpay_refund_audit_event()'::regprocedure)) > 0,
  'Razorpay audit captures processing completion time'
);

SELECT ok(
  position('status' IN pg_get_functiondef('public.srk_capture_razorpay_refund_audit_event()'::regprocedure)) > 0
  AND position('provider_status' IN pg_get_functiondef('public.srk_capture_razorpay_refund_audit_event()'::regprocedure)) > 0,
  'Razorpay audit retains internal and provider status'
);

SELECT * FROM finish();
ROLLBACK;
