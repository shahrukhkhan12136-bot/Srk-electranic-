-- Customer receipt support for the category-neutral Master final bill.
-- Historical receipt branches remain unchanged for legacy bookings.

CREATE OR REPLACE FUNCTION public.srk_customer_get_payment_receipt(p_booking_id uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path=pg_catalog,public,auth,pg_temp AS $$
DECLARE
 v_uid uuid:=auth.uid(); b public.service_bookings%rowtype;
 f public.srk_booking_final_bills%rowtype; p public.srk_master_booking_payments%rowtype;
 v_items jsonb:='[]'::jsonb; v_total bigint;
BEGIN
 IF v_uid IS NULL THEN RAISE EXCEPTION 'CUSTOMER_LOGIN_REQUIRED' USING ERRCODE='42501'; END IF;
 IF p_booking_id IS NULL THEN RAISE EXCEPTION 'BOOKING_ID_REQUIRED' USING ERRCODE='22023'; END IF;
 SELECT * INTO b FROM public.service_bookings
  WHERE id=p_booking_id AND customer_user_id=v_uid;
 IF NOT FOUND THEN RAISE EXCEPTION 'BOOKING_NOT_FOUND' USING ERRCODE='42501'; END IF;
 IF b.payment_status<>'paid' OR b.payment_verified_at IS NULL OR coalesce(b.amount_paid,0)<=0 THEN
  RAISE EXCEPTION 'ONLY_VERIFIED_PAID_BOOKINGS_HAVE_A_RECEIPT' USING ERRCODE='55000';
 END IF;
 IF b.srk_service_category_code IS NOT NULL THEN
  SELECT * INTO f FROM public.srk_booking_final_bills WHERE booking_id=p_booking_id;
  SELECT * INTO p FROM public.srk_master_booking_payments WHERE booking_id=p_booking_id AND payment_status='paid';
  IF NOT FOUND OR f.id IS NULL OR p.final_bill_id<>f.id OR p.amount_paise<>f.subtotal_paise
    OR round(b.amount_paid*100)::bigint<>f.subtotal_paise THEN
   RAISE EXCEPTION 'MASTER_FINAL_BILL_PAYMENT_RECONCILIATION_FAILED' USING ERRCODE='55000';
  END IF;
  IF f.material_request_id IS NOT NULL AND f.material_decision='approved' THEN
   SELECT coalesce(jsonb_agg(jsonb_build_object(
     'name',i.item_name,'quantity',i.quantity,'unit_price_paise',i.unit_price_paise,
     'line_total_paise',i.line_total_paise
   ) ORDER BY i.line_number),'[]'::jsonb) INTO v_items
   FROM public.srk_booking_material_request_items i WHERE i.request_id=f.material_request_id;
  END IF;
  RETURN jsonb_build_object(
   'receipt_reference','SRK-PAY-'||upper(left(replace(b.id::text,'-',''),12)),
   'booking_id',b.id,'customer_name',b.customer_name,'service_type',b.service_type,
   'address',b.address,'district',b.district,'state',b.state,'pincode',b.pincode,
   'booking_date',b.created_at,'payment_date',p.verified_at,
   'payment_method',p.payment_method,'payment_reference',coalesce(p.razorpay_payment_id,p.payment_reference),
   'amount_paid',f.subtotal_paise/100.0,'labour_amount',f.labour_amount_paise/100.0,
   'materials_amount',f.materials_amount_paise/100.0,'material_items',v_items,
   'cancellation_fee_amount',0,'cancellation_fee_items','[]'::jsonb,
   'total_amount',f.subtotal_paise/100.0,
   'description','सत्यापित भुगतान रसीद — मेहनताना और ग्राहक-मंजूर सामग्री अलग-अलग',
   'document_type','payment_receipt'
  );
 END IF;

 -- Preserve the historical single-Electrician and quote-era receipt contracts.
 IF b.selected_category IS NOT NULL THEN
  DECLARE v_bill public.srk_booking_labour_bills%rowtype; v_fee bigint:=0; v_fee_items jsonb:='[]'::jsonb;
  BEGIN
   SELECT * INTO v_bill FROM public.srk_booking_labour_bills WHERE booking_id=p_booking_id AND customer_user_id=v_uid;
   IF NOT FOUND THEN RAISE EXCEPTION 'IMMUTABLE_LABOUR_BILL_NOT_FOUND'; END IF;
   SELECT coalesce(sum(i.amount_paise),0),
    coalesce(jsonb_agg(jsonb_build_object('source_booking_id',i.source_booking_id,'amount_paise',i.amount_paise,'amount',i.amount_paise/100.0) order by i.created_at,i.id),'[]'::jsonb)
    INTO v_fee,v_fee_items FROM public.srk_booking_cancellation_fee_items i
    WHERE i.booking_id=p_booking_id AND i.status='settled';
   v_total:=v_bill.labour_amount_paise+v_fee;
   IF round(b.amount_paid*100)::bigint<>v_total THEN RAISE EXCEPTION 'LEGACY_PAID_AMOUNT_MISMATCH'; END IF;
   RETURN jsonb_build_object('receipt_reference','SRK-PAY-'||upper(left(replace(b.id::text,'-',''),12)),
    'booking_id',b.id,'customer_name',b.customer_name,'service_type',b.service_type,'address',b.address,
    'district',b.district,'state',b.state,'pincode',b.pincode,'booking_date',b.created_at,
    'payment_date',b.payment_verified_at,'payment_method',lower(coalesce(b.payment_method,'other')),
    'amount_paid',b.amount_paid,'labour_amount',v_bill.labour_amount,'materials_amount',0,
    'cancellation_fee_amount',v_fee/100.0,'cancellation_fee_items',v_fee_items,
    'total_amount',v_total/100.0,'description','सत्यापित भुगतान रसीद','document_type','payment_receipt');
  END;
 END IF;
 v_total:=round((coalesce(b.service_charge,0)+coalesce(b.materials_amount,0))*100)::bigint;
 IF v_total<=0 OR round(b.amount_paid*100)::bigint<>v_total
   OR round(coalesce(b.quoted_amount,0)*100)::bigint<>v_total THEN
  RAISE EXCEPTION 'LEGACY_QUOTE_RECEIPT_RECONCILIATION_FAILED';
 END IF;
 RETURN jsonb_build_object('receipt_reference','SRK-PAY-'||upper(left(replace(b.id::text,'-',''),12)),
  'booking_id',b.id,'customer_name',b.customer_name,'service_type',b.service_type,'address',b.address,
  'district',b.district,'state',b.state,'pincode',b.pincode,'booking_date',b.created_at,
  'payment_date',b.payment_verified_at,'payment_method',lower(coalesce(b.payment_method,'other')),
  'amount_paid',v_total/100.0,'labour_amount',round(coalesce(b.service_charge,0),2),
  'materials_amount',round(coalesce(b.materials_amount,0),2),'cancellation_fee_amount',0,
  'cancellation_fee_items','[]'::jsonb,'total_amount',v_total/100.0,
  'description','सत्यापित भुगतान रसीद — मेहनताना और सामग्री अलग-अलग','document_type','payment_receipt');
END; $$;
REVOKE ALL ON FUNCTION public.srk_customer_get_payment_receipt(uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.srk_customer_get_payment_receipt(uuid) TO authenticated;
NOTIFY pgrst,'reload schema';
