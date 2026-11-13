-- Static contract checks for failed-provider refund recovery visibility.
BEGIN;
SELECT plan(5);
SELECT has_function('public','srk_service_record_razorpay_refund_result',
  ARRAY['uuid','text','text','text'],'service-role refund result recorder exists');
SELECT ok(position('p_provider_status=''failed''' in pg_get_functiondef(
  'public.srk_service_record_razorpay_refund_result(uuid,text,text,text)'::regprocedure))>0,
  'provider failure has an explicit branch');
SELECT ok(position('status=''unknown''' in pg_get_functiondef(
  'public.srk_service_record_razorpay_refund_result(uuid,text,text,text)'::regprocedure))>0,
  'failed provider result moves customer request to visible Admin-review state');
SELECT ok(position('admin_note=' in pg_get_functiondef(
  'public.srk_service_record_razorpay_refund_result(uuid,text,text,text)'::regprocedure))>0,
  'failure reason is retained for Admin review');
SELECT ok(position('admin_reconciliation_required' in pg_get_functiondef(
  'public.srk_service_record_razorpay_refund_result(uuid,text,text,text)'::regprocedure))>0,
  'RPC response explicitly signals reconciliation requirement');
SELECT * FROM finish();
ROLLBACK;
