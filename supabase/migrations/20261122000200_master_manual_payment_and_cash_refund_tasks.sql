-- Admin manual collection verification, Technician cash-refund task inbox,
-- and GST-inclusive cash-refund finalization.
CREATE OR REPLACE FUNCTION public.srk_admin_list_master_pending_manual_payments(p_limit integer DEFAULT 200)
RETURNS TABLE(
 booking_id uuid,customer_name text,customer_phone text,service_type text,payment_method text,
 payment_status text,total_due_paise bigint,final_bill_id uuid,created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $function$
BEGIN
 IF auth.uid() IS NULL OR NOT public.is_srk_admin() THEN RAISE EXCEPTION 'ADMIN_ACCESS_REQUIRED' USING ERRCODE='42501';END IF;
 IF p_limit IS NULL OR p_limit NOT BETWEEN 1 AND 500 THEN RAISE EXCEPTION 'INVALID_LIMIT' USING ERRCODE='22023';END IF;
 RETURN QUERY
 SELECT b.id,b.customer_name,b.phone,b.service_type,b.payment_method,b.payment_status,
  COALESCE(t.total_due_paise,f.subtotal_paise),f.id,b.created_at
 FROM public.service_bookings b
 JOIN public.srk_booking_final_bills f ON f.booking_id=b.id
 LEFT JOIN public.srk_booking_tax_snapshots t ON t.booking_id=b.id
 WHERE b.srk_service_category_code IS NOT NULL AND b.status='completed'
  AND b.completion_approval_status='approved' AND b.customer_completed_at IS NOT NULL
  AND b.payment_status IN ('unpaid','pending') AND b.payment_verified_at IS NULL
  AND COALESCE(b.amount_paid,0)=0 AND b.razorpay_order_id IS NULL AND b.razorpay_payment_id IS NULL
  AND b.payment_method IN ('cash','upi','bank_transfer')
  AND NOT EXISTS(SELECT 1 FROM public.srk_master_booking_payments m WHERE m.booking_id=b.id)
 ORDER BY b.created_at DESC LIMIT p_limit;
END;
$function$;
REVOKE ALL ON FUNCTION public.srk_admin_list_master_pending_manual_payments(integer) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.srk_admin_list_master_pending_manual_payments(integer) TO authenticated;

CREATE OR REPLACE FUNCTION public.srk_technician_list_master_cash_refund_tasks()
RETURNS TABLE(
 booking_id uuid,customer_name text,customer_phone text,customer_address text,
 amount_paise bigint,remaining_amount_paise bigint,evidence_id uuid,evidence_status text,
 refund_reference text,evidence_uri text,evidence_note text,submitted_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $function$
DECLARE v_tid uuid:=auth.uid()::uuid;
BEGIN
 SELECT t.id INTO v_tid FROM public.srk_technicians t
 WHERE t.auth_user_id=auth.uid() AND t.account_status='active';
 IF auth.uid() IS NULL OR v_tid IS NULL THEN RAISE EXCEPTION 'ACTIVE_TECHNICIAN_REQUIRED' USING ERRCODE='42501';END IF;
 RETURN QUERY
 SELECT b.id,b.customer_name,b.phone,b.address,m.amount_paise,
  greatest(m.amount_paise-COALESCE((SELECT sum(e2.amount_paise) FROM public.srk_master_cash_refund_evidence e2
    WHERE e2.booking_id=b.id AND e2.status='submitted'),0),0),
  e.id,CASE WHEN e.id IS NULL THEN 'not_submitted' ELSE COALESCE(rv.decision,e.status) END,
  e.refund_reference,e.evidence_uri,e.evidence_note,e.submitted_at
 FROM public.srk_master_technician_payables p
 JOIN public.srk_master_booking_payments m ON m.id=p.payment_id
 JOIN public.service_bookings b ON b.id=p.booking_id
 JOIN public.srk_booking_refund_requests r ON r.booking_id=b.id AND r.customer_user_id=b.customer_user_id
 LEFT JOIN public.srk_master_cash_refund_evidence e ON e.booking_id=b.id AND e.technician_id=v_tid
 LEFT JOIN public.srk_master_cash_refund_reviews rv ON rv.evidence_id=e.id
 WHERE p.technician_id=v_tid AND m.payment_method='cash' AND m.payment_status='paid'
  AND b.srk_service_category_code IS NOT NULL AND b.status='completed'
  AND b.completion_approval_status='approved' AND b.customer_completed_at IS NOT NULL
  AND b.payment_status='paid' AND r.status='approved'
  AND round(r.amount*100)::bigint=m.amount_paise
 ORDER BY b.created_at DESC;
END;
$function$;
REVOKE ALL ON FUNCTION public.srk_technician_list_master_cash_refund_tasks() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.srk_technician_list_master_cash_refund_tasks() TO authenticated;

CREATE OR REPLACE FUNCTION public.srk_admin_finalize_master_cash_refund(
 p_booking_id uuid,p_admin_note text DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $function$
DECLARE v_booking public.service_bookings%rowtype;v_payment public.srk_master_booking_payments%rowtype;
 v_request public.srk_booking_refund_requests%rowtype;v_final_bill public.srk_booking_final_bills%rowtype;
 v_tax public.srk_booking_tax_snapshots%rowtype;v_total bigint;v_count integer;v_reference text;d record;
 v_credited bigint:=0;v_credit_count integer:=0;
BEGIN
 IF auth.uid() IS NULL OR NOT public.is_srk_admin() THEN RAISE EXCEPTION 'ADMIN_ONLY' USING ERRCODE='42501';END IF;
 IF p_booking_id IS NULL OR (p_admin_note IS NOT NULL AND char_length(p_admin_note)>500) THEN
  RAISE EXCEPTION 'INVALID_REFUND_FINALIZATION_INPUT' USING ERRCODE='22023';END IF;
 SELECT * INTO v_booking FROM public.service_bookings WHERE id=p_booking_id FOR UPDATE;
 IF NOT FOUND OR v_booking.srk_service_category_code IS NULL OR v_booking.status<>'completed'
  OR v_booking.payment_status<>'paid' THEN RAISE EXCEPTION 'PAID_COMPLETED_MASTER_BOOKING_REQUIRED';END IF;
 SELECT * INTO v_payment FROM public.srk_master_booking_payments WHERE booking_id=p_booking_id FOR UPDATE;
 IF NOT FOUND OR v_payment.payment_method<>'cash' OR v_payment.payment_status<>'paid'
  OR v_payment.amount_paise<>round(v_booking.amount_paid*100)::bigint THEN
  RAISE EXCEPTION 'VERIFIED_MASTER_CASH_PAYMENT_REQUIRED';END IF;
 SELECT * INTO v_final_bill FROM public.srk_booking_final_bills WHERE id=v_payment.final_bill_id FOR SHARE;
 IF NOT FOUND THEN RAISE EXCEPTION 'MASTER_FINAL_BILL_REQUIRED';END IF;
 SELECT * INTO v_tax FROM public.srk_booking_tax_snapshots WHERE booking_id=p_booking_id FOR SHARE;
 IF COALESCE(v_tax.total_due_paise,v_final_bill.subtotal_paise)<>v_payment.amount_paise THEN
  RAISE EXCEPTION 'MASTER_FINAL_BILL_AMOUNT_MISMATCH';END IF;
 SELECT * INTO v_request FROM public.srk_booking_refund_requests WHERE booking_id=p_booking_id FOR UPDATE;
 IF NOT FOUND OR v_request.status<>'approved' OR v_request.customer_user_id<>v_booking.customer_user_id
  OR round(v_request.amount*100)::bigint<>v_payment.amount_paise THEN
  RAISE EXCEPTION 'MAIN_ADMIN_APPROVED_FULL_CUSTOMER_REFUND_REQUEST_REQUIRED';END IF;
 IF EXISTS(SELECT 1 FROM public.srk_manual_refund_entries WHERE booking_id=p_booking_id)
  OR EXISTS(SELECT 1 FROM public.srk_razorpay_refunds WHERE booking_id=p_booking_id) THEN
  RAISE EXCEPTION 'REFUND_ALREADY_RECORDED_FOR_BOOKING';END IF;
 SELECT count(*),COALESCE(sum(e.amount_paise),0),string_agg(e.refund_reference,', ' ORDER BY e.technician_id)
 INTO v_count,v_total,v_reference FROM public.srk_master_cash_refund_evidence e
 WHERE e.booking_id=p_booking_id AND e.status='submitted';
 IF v_count=0 OR v_total<>v_payment.amount_paise THEN
  RAISE EXCEPTION 'TECHNICIAN_REFUND_EVIDENCE_MUST_EQUAL_FULL_CUSTOMER_REFUND' USING ERRCODE='55000';END IF;
 IF EXISTS(SELECT 1 FROM public.srk_master_cash_refund_reviews r
  JOIN public.srk_master_cash_refund_evidence e ON e.id=r.evidence_id WHERE e.booking_id=p_booking_id) THEN
  RAISE EXCEPTION 'CASH_REFUND_EVIDENCE_ALREADY_REVIEWED';END IF;
 INSERT INTO public.srk_manual_refund_entries(booking_id,payment_entry_id,amount,refund_reference,note,recorded_by)
 VALUES(p_booking_id,v_payment.manual_payment_entry_id,v_payment.amount_paise/100.0,
  'MASTER-CASH-'||replace(p_booking_id::text,'-',''),
  left('Technician refund evidence: '||COALESCE(v_reference,'')||'; Admin: '||COALESCE(p_admin_note,''),250),auth.uid());
 FOR d IN SELECT * FROM public.srk_master_technician_commission_dues
  WHERE booking_id=p_booking_id ORDER BY technician_id FOR UPDATE
 LOOP
  IF d.commission_recovered_paise>0 THEN
   INSERT INTO public.srk_master_technician_wallet_credits(technician_id,source_due_id,source_booking_id,amount_paise)
   VALUES(d.technician_id,d.id,p_booking_id,d.commission_recovered_paise);
   v_credited:=v_credited+d.commission_recovered_paise;v_credit_count:=v_credit_count+1;
  END IF;
  UPDATE public.srk_master_technician_commission_dues SET status='refunded',
   commission_refunded_paise=d.commission_recovered_paise WHERE id=d.id;
  INSERT INTO public.srk_master_technician_commission_events(
   technician_id,booking_id,payment_id,event_type,amount_paise,source_due_id,event_data)
  VALUES(d.technician_id,d.booking_id,d.payment_id,'cash_payment_refunded',d.commission_due_paise,d.id,
   jsonb_build_object('commission_recovered_paise',d.commission_recovered_paise,
    'wallet_credit_paise',d.commission_recovered_paise,'outstanding_commission_reversed_paise',
    d.commission_due_paise-d.commission_recovered_paise,'refund_channel','technician_to_customer'));
 END LOOP;
 INSERT INTO public.srk_master_cash_refund_reviews(evidence_id,decision,admin_user_id,note)
 SELECT e.id,'approved',auth.uid(),nullif(btrim(COALESCE(p_admin_note,'')),'')
 FROM public.srk_master_cash_refund_evidence e WHERE e.booking_id=p_booking_id;
 UPDATE public.service_bookings SET payment_status='refunded'
 WHERE id=p_booking_id AND payment_status='paid';
 IF NOT FOUND THEN RAISE EXCEPTION 'BOOKING_REFUND_STATE_CHANGED' USING ERRCODE='40001';END IF;
 UPDATE public.srk_booking_refund_requests SET status='processed',
  processed_at=COALESCE(processed_at,clock_timestamp()),updated_at=clock_timestamp()
 WHERE id=v_request.id AND status='approved';
 RETURN jsonb_build_object('success',true,'booking_id',p_booking_id,'status','refunded',
  'refund_amount_paise',v_payment.amount_paise,'technician_evidence_count',v_count,
  'commission_wallet_credit_paise',v_credited,'commission_wallet_credit_count',v_credit_count,
  'customer_refund_channel','technician_to_customer');
END;
$function$;
REVOKE ALL ON FUNCTION public.srk_admin_finalize_master_cash_refund(uuid,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.srk_admin_finalize_master_cash_refund(uuid,text) TO authenticated;
