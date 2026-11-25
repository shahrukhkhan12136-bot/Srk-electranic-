-- Keep Master payout requests synchronized with refund holds.
-- Feature branch only; do not apply to Main without explicit approval.
CREATE OR REPLACE FUNCTION public.srk_sync_master_payout_request_on_refund()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER
SET search_path=pg_catalog,public,auth,pg_temp AS $$
BEGIN
 IF TG_OP='INSERT' AND NEW.status IN ('requested','processing','unknown') THEN
  UPDATE public.srk_master_payout_requests r
   SET status='cancelled',reviewed_at=clock_timestamp(),
    review_note=left(concat_ws(' | ',nullif(r.review_note,''),'Cancelled automatically: booking refund is being processed'),500)
   WHERE r.id IN (
    SELECT DISTINCT i.payout_request_id FROM public.srk_master_payout_request_items i
    JOIN public.srk_master_technician_payables p ON p.id=i.payable_id
    WHERE p.booking_id=NEW.booking_id
   ) AND r.status IN ('requested','approved');
 ELSIF TG_OP='UPDATE' AND NEW.status='failed' AND OLD.status IS DISTINCT FROM NEW.status THEN
  UPDATE public.srk_master_payout_requests r
   SET review_note=left(concat_ws(' | ',nullif(r.review_note,''),'Refund failed; payable released for a new payout request'),500)
   WHERE r.id IN (
    SELECT DISTINCT i.payout_request_id FROM public.srk_master_payout_request_items i
    JOIN public.srk_master_technician_payables p ON p.id=i.payable_id
    WHERE p.booking_id=NEW.booking_id
   ) AND r.status='cancelled';
 END IF;
 RETURN NEW;
END; $$;
REVOKE ALL ON FUNCTION public.srk_sync_master_payout_request_on_refund() FROM PUBLIC,anon,authenticated;
DROP TRIGGER IF EXISTS srk_sync_master_payout_request_on_refund_insert ON public.srk_razorpay_refunds;
CREATE TRIGGER srk_sync_master_payout_request_on_refund_insert AFTER INSERT ON public.srk_razorpay_refunds
FOR EACH ROW EXECUTE FUNCTION public.srk_sync_master_payout_request_on_refund();
DROP TRIGGER IF EXISTS srk_sync_master_payout_request_on_refund_failure ON public.srk_razorpay_refunds;
CREATE TRIGGER srk_sync_master_payout_request_on_refund_failure AFTER UPDATE OF status ON public.srk_razorpay_refunds
FOR EACH ROW WHEN (OLD.status IS DISTINCT FROM NEW.status AND NEW.status='failed')
EXECUTE FUNCTION public.srk_sync_master_payout_request_on_refund();
COMMENT ON FUNCTION public.srk_sync_master_payout_request_on_refund() IS
 'Cancels unpaid Master payout requests when booking refund begins; preserves history and allows a fresh request after refund failure.';
