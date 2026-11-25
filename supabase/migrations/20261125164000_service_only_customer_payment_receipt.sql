-- Customer receipts expose service amount and verified total only.
-- Archived historical payment totals are retained without itemized charge disclosure.
-- Feature branch only; do not apply to Main without explicit approval.

CREATE OR REPLACE FUNCTION public.srk_customer_get_payment_receipt(p_booking_id uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path=pg_catalog,public,auth,pg_temp AS $$
DECLARE
 v_uid uuid:=auth.uid();
 b public.service_bookings%rowtype;
 f public.srk_booking_final_bills%rowtype;
 p public.srk_master_booking_payments%rowtype;
 v_total bigint;
 v_service bigint;
 v_fee bigint:=0;
BEGIN
 IF v_uid IS NULL THEN RAISE EXCEPTION 'CUSTOMER_LOGIN_REQUIRED' USING ERRCODE='42501'; END IF;
 IF p_booking_id IS NULL THEN RAISE EXCEPTION 'BOOKING_ID_REQUIRED' USING ERRCODE='22023'; END IF;
 SELECT * INTO b FROM public.service_bookings WHERE id=p_booking_id AND customer_user_id=v_uid;
 IF NOT FOUND THEN RAISE EXCEPTION 'BOOKING_NOT_FOUND' USING ERRCODE='42501'; END IF;
 IF b.payment_status<>'paid' OR b.payment_verified_at IS NULL OR coalesce(b.amount_paid,0)<=0 THEN
  RAISE EXCEPTION 'ONLY_VERIFIED_PAID_BOOKINGS_HAVE_A_RECEIPT' USING ERRCODE='55000';
 END IF;
 IF b.srk_service_category_code IS NOT NULL THEN
  SELECT * INTO f FROM public.srk_booking_final_bills WHERE booking_id=p_booking_id;
  SELECT * INTO p FROM public.srk_master_booking_payments WHERE booking_id=p_booking_id AND payment_status='paid';
  IF NOT EXISTS(SELECT 1 FROM public.srk_booking_tax_snapshots WHERE booking_id=p_booking_id) THEN
   RAISE EXCEPTION 'MASTER_TAX_SNAPSHOT_REQUIRED' USING ERRCODE='55000';
  END IF;
  IF p.id IS NULL OR f.id IS NULL OR p.final_bill_id<>f.id
   OR p.amount_paise<>(SELECT t.total_due_paise FROM public.srk_booking_tax_snapshots t WHERE t.booking_id=p_booking_id)
   OR round(b.amount_paid*100)::bigint<>p.amount_paise OR f.subtotal_paise<>f.labour_amount_paise THEN
   RAISE EXCEPTION 'MASTER_FINAL_BILL_PAYMENT_RECONCILIATION_FAILED' USING ERRCODE='55000';
  END IF;
  RETURN jsonb_build_object(
   'receipt_reference','SRK-PAY-'||upper(left(replace(b.id::text,'-',''),12)),
   'invoice_number',(SELECT i.invoice_number FROM public.srk_master_tax_invoices i WHERE i.payment_id=p.id),
   'taxable_value_paise',(SELECT t.taxable_value_paise FROM public.srk_booking_tax_snapshots t WHERE t.booking_id=p_booking_id),
   'cgst_paise',(SELECT t.total_cgst_paise FROM public.srk_booking_tax_snapshots t WHERE t.booking_id=p_booking_id),
   'sgst_paise',(SELECT t.total_sgst_paise FROM public.srk_booking_tax_snapshots t WHERE t.booking_id=p_booking_id),
   'igst_paise',(SELECT t.total_igst_paise FROM public.srk_booking_tax_snapshots t WHERE t.booking_id=p_booking_id),
   'total_tax_paise',(SELECT t.total_tax_paise FROM public.srk_booking_tax_snapshots t WHERE t.booking_id=p_booking_id),
   'booking_id',b.id,'customer_name',b.customer_name,'service_type',b.service_type,
   'address',b.address,'district',b.district,'state',b.state,'pincode',b.pincode,
   'booking_date',b.created_at,'payment_date',p.verified_at,'payment_method',p.payment_method,
   'payment_reference',coalesce(p.razorpay_payment_id,p.payment_reference),
   'service_amount',f.labour_amount_paise/100.0,'amount_paid',p.amount_paise/100.0,
   'cancellation_fee_amount',0,'total_amount',p.amount_paise/100.0,
   'description','सत्यापित सेवा भुगतान रसीद','document_type','payment_receipt');
 END IF;

 v_total:=round(b.amount_paid*100)::bigint;
 IF b.selected_category IS NOT NULL THEN
  SELECT labour_amount_paise INTO v_service FROM public.srk_booking_labour_bills
   WHERE booking_id=p_booking_id AND customer_user_id=v_uid;
  IF v_service IS NULL OR v_service>v_total THEN RAISE EXCEPTION 'LEGACY_PAID_AMOUNT_MISMATCH'; END IF;
  SELECT coalesce(sum(i.amount_paise),0) INTO v_fee
   FROM public.srk_booking_cancellation_fee_items i
   WHERE i.booking_id=p_booking_id AND i.status='settled';
  IF v_service+v_fee=v_total THEN
   RETURN jsonb_build_object('receipt_reference','SRK-PAY-'||upper(left(replace(b.id::text,'-',''),12)),
    'booking_id',b.id,'customer_name',b.customer_name,'service_type',b.service_type,'address',b.address,
    'district',b.district,'state',b.state,'pincode',b.pincode,'booking_date',b.created_at,
    'payment_date',b.payment_verified_at,'payment_method',lower(coalesce(b.payment_method,'other')),
    'service_amount',v_service/100.0,'amount_paid',v_total/100.0,
    'cancellation_fee_amount',v_fee/100.0,'total_amount',v_total/100.0,
    'description','सत्यापित भुगतान रसीद','document_type','payment_receipt');
  END IF;
 END IF;
 RETURN jsonb_build_object('receipt_reference','SRK-PAY-'||upper(left(replace(b.id::text,'-',''),12)),
  'booking_id',b.id,'customer_name',b.customer_name,'service_type',b.service_type,'address',b.address,
  'district',b.district,'state',b.state,'pincode',b.pincode,'booking_date',b.created_at,
  'payment_date',b.payment_verified_at,'payment_method',lower(coalesce(b.payment_method,'other')),
  'amount_paid',v_total/100.0,'total_amount',v_total/100.0,
  'description','ऐतिहासिक सत्यापित भुगतान रसीद','document_type','payment_receipt');
END; $$;
REVOKE ALL ON FUNCTION public.srk_customer_get_payment_receipt(uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.srk_customer_get_payment_receipt(uuid) TO authenticated;
NOTIFY pgrst,'reload schema';
