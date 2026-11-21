-- Integrate recovered-commission refund credits into the existing Master payout lifecycle.
-- Feature-branch source only; no live payout or DB action is performed.

CREATE TABLE IF NOT EXISTS public.srk_master_payout_request_credits (
  payout_request_id uuid NOT NULL REFERENCES public.srk_master_payout_requests(id) ON DELETE RESTRICT,
  wallet_credit_id uuid NOT NULL REFERENCES public.srk_master_technician_wallet_credits(id) ON DELETE RESTRICT,
  amount_paise bigint NOT NULL CHECK (amount_paise > 0),
  created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  PRIMARY KEY (payout_request_id,wallet_credit_id),
  UNIQUE (wallet_credit_id)
);
ALTER TABLE public.srk_master_payout_request_credits ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.srk_master_payout_request_credits FROM PUBLIC,anon,authenticated;
GRANT ALL ON public.srk_master_payout_request_credits TO service_role;

-- Preserve the existing wallet projection and extend it with separately classified refund credits.
DO $$
BEGIN
  IF to_regprocedure('public.srk_master_wallet_summary_before_cash_refund_credits()') IS NULL THEN
    ALTER FUNCTION public.srk_master_wallet_summary() RENAME TO srk_master_wallet_summary_before_cash_refund_credits;
  END IF;
END;
$$;
CREATE OR REPLACE FUNCTION public.srk_master_wallet_summary()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path=pg_catalog,public,auth,pg_temp AS $$
DECLARE v_out jsonb; v_uid uuid:=auth.uid(); v_tid uuid;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'AUTH_REQUIRED' USING ERRCODE='42501'; END IF;
  SELECT id INTO v_tid FROM public.srk_technicians WHERE auth_user_id=v_uid;
  IF v_tid IS NULL THEN RAISE EXCEPTION 'TECHNICIAN_IDENTITY_NOT_LINKED' USING ERRCODE='P0002'; END IF;
  v_out:=public.srk_master_wallet_summary_before_cash_refund_credits();
  RETURN v_out || jsonb_build_object(
    'commission_refund_credit_available_paise',coalesce((SELECT sum(amount_paise) FROM public.srk_master_technician_wallet_credits WHERE technician_id=v_tid AND status='available'),0),
    'commission_refund_credit_requested_paise',coalesce((SELECT sum(amount_paise) FROM public.srk_master_technician_wallet_credits WHERE technician_id=v_tid AND status='requested'),0),
    'commission_refund_credit_paid_paise',coalesce((SELECT sum(amount_paise) FROM public.srk_master_technician_wallet_credits WHERE technician_id=v_tid AND status='paid'),0),
    'commission_refund_credits',coalesce((SELECT jsonb_agg(jsonb_build_object(
      'credit_id',c.id,'source_booking_id',c.source_booking_id,'source_due_id',c.source_due_id,
      'amount_paise',c.amount_paise,'status',c.status,'created_at',c.created_at,
      'payout_reference',c.payout_reference,'paid_at',c.paid_at
    ) ORDER BY c.created_at DESC) FROM public.srk_master_technician_wallet_credits c WHERE c.technician_id=v_tid),'[]'::jsonb)
  );
END;
$$;
REVOKE ALL ON FUNCTION public.srk_master_wallet_summary() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.srk_master_wallet_summary() TO authenticated;

CREATE OR REPLACE FUNCTION public.srk_technician_request_master_payout(
 p_destination_type text,p_destination_reference text,p_idempotency_key text
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path=pg_catalog,public,auth,pg_temp AS $$
DECLARE v_uid uuid:=auth.uid(); v_tid uuid; v_req uuid; v_total bigint; v_payables bigint; v_credits bigint;
BEGIN
 IF v_uid IS NULL THEN RAISE EXCEPTION 'AUTH_REQUIRED' USING ERRCODE='42501'; END IF;
 IF p_destination_type NOT IN ('upi','bank') OR char_length(btrim(coalesce(p_destination_reference,'')))<4
   OR char_length(p_destination_reference)>160 OR char_length(btrim(coalesce(p_idempotency_key,'')))<8
   OR char_length(p_idempotency_key)>120 THEN RAISE EXCEPTION 'INVALID_PAYOUT_REQUEST' USING ERRCODE='22023'; END IF;
 SELECT id INTO v_tid FROM public.srk_technicians WHERE auth_user_id=v_uid FOR UPDATE;
 IF v_tid IS NULL THEN RAISE EXCEPTION 'TECHNICIAN_IDENTITY_NOT_LINKED'; END IF;
 SELECT id INTO v_req FROM public.srk_master_payout_requests WHERE technician_id=v_tid AND idempotency_key=p_idempotency_key;
 IF v_req IS NOT NULL THEN RETURN jsonb_build_object('success',true,'already_processed',true,'request_id',v_req); END IF;
 IF EXISTS(SELECT 1 FROM public.srk_master_payout_requests WHERE technician_id=v_tid AND status IN ('requested','approved')) THEN
  RAISE EXCEPTION 'PAYOUT_REQUEST_ALREADY_OPEN';
 END IF;
 SELECT coalesce(sum(total_payable_paise),0) INTO v_payables FROM public.srk_master_technician_payables
  WHERE technician_id=v_tid AND payout_status='pending';
 SELECT coalesce(sum(amount_paise),0) INTO v_credits FROM public.srk_master_technician_wallet_credits
  WHERE technician_id=v_tid AND status='available';
 v_total:=v_payables+v_credits;
 IF v_total<=0 THEN RAISE EXCEPTION 'NO_AVAILABLE_PAYOUT_BALANCE'; END IF;
 INSERT INTO public.srk_master_payout_requests(technician_id,auth_user_id,amount_paise,destination_type,destination_reference,idempotency_key)
 VALUES(v_tid,v_uid,v_total,p_destination_type,btrim(p_destination_reference),p_idempotency_key) RETURNING id INTO v_req;
 INSERT INTO public.srk_master_payout_request_items(payout_request_id,payable_id,amount_paise)
 SELECT v_req,id,total_payable_paise FROM public.srk_master_technician_payables
 WHERE technician_id=v_tid AND payout_status='pending';
 UPDATE public.srk_master_technician_payables SET payout_status='requested'
 WHERE technician_id=v_tid AND payout_status='pending';
 INSERT INTO public.srk_master_payout_request_credits(payout_request_id,wallet_credit_id,amount_paise)
 SELECT v_req,id,amount_paise FROM public.srk_master_technician_wallet_credits
 WHERE technician_id=v_tid AND status='available';
 UPDATE public.srk_master_technician_wallet_credits SET status='requested'
 WHERE technician_id=v_tid AND status='available';
 RETURN jsonb_build_object('success',true,'request_id',v_req,'amount_paise',v_total,
  'payable_amount_paise',v_payables,'commission_refund_credit_paise',v_credits,'status','requested');
END;
$$;

CREATE OR REPLACE FUNCTION public.srk_admin_list_master_payout_requests()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path=pg_catalog,public,auth,pg_temp AS $$
DECLARE v_out jsonb;
BEGIN
 IF auth.uid() IS NULL OR NOT public.is_srk_admin() THEN RAISE EXCEPTION 'ADMIN_ONLY' USING ERRCODE='42501'; END IF;
 SELECT coalesce(jsonb_agg(jsonb_build_object(
  'request_id',r.id,'technician_id',r.technician_id,
  'technician_name',coalesce((SELECT ep.display_name FROM public.srk_technician_profile_links l
    JOIN public.electrician_profiles ep ON ep.id=l.electrician_profile_id
    WHERE l.technician_id=t.id ORDER BY l.linked_at LIMIT 1),t.primary_phone,'Technician'),
  'amount_paise',r.amount_paise,'destination_type',r.destination_type,'destination_reference',r.destination_reference,
  'status',r.status,'requested_at',r.requested_at,'review_note',r.review_note,
  'payable_count',(SELECT count(*) FROM public.srk_master_payout_request_items i WHERE i.payout_request_id=r.id),
  'commission_refund_credit_count',(SELECT count(*) FROM public.srk_master_payout_request_credits i WHERE i.payout_request_id=r.id),
  'commission_refund_credits',(SELECT coalesce(jsonb_agg(jsonb_build_object('credit_id',c.id,'amount_paise',c.amount_paise,
     'source_booking_id',c.source_booking_id)),'[]'::jsonb)
    FROM public.srk_master_payout_request_credits i JOIN public.srk_master_technician_wallet_credits c
      ON c.id=i.wallet_credit_id WHERE i.payout_request_id=r.id),
  'payments',(SELECT coalesce(jsonb_agg(jsonb_build_object('payment_method',m.payment_method,'payment_id',m.id,
     'amount_paise',m.amount_paise,'settlement_confirmed',EXISTS(SELECT 1 FROM public.srk_master_company_settlements s WHERE s.payment_id=m.id))),'[]'::jsonb)
    FROM public.srk_master_payout_request_items i JOIN public.srk_master_technician_payables p ON p.id=i.payable_id
    JOIN public.srk_master_booking_payments m ON m.id=p.payment_id WHERE i.payout_request_id=r.id)
 ) ORDER BY r.requested_at DESC),'[]'::jsonb) INTO v_out
 FROM public.srk_master_payout_requests r JOIN public.srk_technicians t ON t.id=r.technician_id
 WHERE r.status IN ('requested','approved');
 RETURN v_out;
END;
$$;

CREATE OR REPLACE FUNCTION public.srk_admin_review_master_payout_request(
 p_request_id uuid,p_decision text,p_review_note text DEFAULT NULL
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path=pg_catalog,public,auth,pg_temp AS $$
DECLARE r public.srk_master_payout_requests%rowtype;
BEGIN
 IF auth.uid() IS NULL OR NOT public.is_srk_admin() THEN RAISE EXCEPTION 'ADMIN_ONLY' USING ERRCODE='42501'; END IF;
 IF p_decision NOT IN ('approved','rejected') OR (p_review_note IS NOT NULL AND char_length(p_review_note)>500)
  OR (p_decision='rejected' AND char_length(btrim(coalesce(p_review_note,'')))<5) THEN
  RAISE EXCEPTION 'INVALID_PAYOUT_REVIEW_DECISION' USING ERRCODE='22023'; END IF;
 SELECT * INTO r FROM public.srk_master_payout_requests WHERE id=p_request_id FOR UPDATE;
 IF NOT FOUND OR r.status<>'requested' THEN RAISE EXCEPTION 'PAYOUT_REQUEST_NOT_PENDING_REVIEW'; END IF;
 UPDATE public.srk_master_payout_requests SET status=p_decision,reviewed_by=auth.uid(),reviewed_at=clock_timestamp(),
  review_note=nullif(btrim(coalesce(p_review_note,'')),'') WHERE id=r.id;
 IF p_decision='rejected' THEN
  UPDATE public.srk_master_technician_payables p SET payout_status='pending'
   FROM public.srk_master_payout_request_items i WHERE i.payout_request_id=r.id AND p.id=i.payable_id AND p.payout_status='requested';
  UPDATE public.srk_master_technician_wallet_credits c SET status='available'
   FROM public.srk_master_payout_request_credits i WHERE i.payout_request_id=r.id AND c.id=i.wallet_credit_id AND c.status='requested';
 END IF;
 RETURN jsonb_build_object('success',true,'request_id',r.id,'status',p_decision);
END;
$$;

CREATE OR REPLACE FUNCTION public.srk_admin_mark_master_payout_paid(
 p_request_id uuid,p_method text,p_transfer_reference text,p_note text DEFAULT NULL
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path=pg_catalog,public,auth,pg_temp AS $$
DECLARE r public.srk_master_payout_requests%rowtype; v_unsettled integer; v_payable_count integer; v_credit_count integer;
BEGIN
 IF auth.uid() IS NULL OR NOT public.is_srk_admin() THEN RAISE EXCEPTION 'ADMIN_ONLY' USING ERRCODE='42501'; END IF;
 IF p_method NOT IN ('upi','bank') OR char_length(btrim(coalesce(p_transfer_reference,'')))<4
  OR char_length(p_transfer_reference)>120 OR (p_note IS NOT NULL AND char_length(p_note)>500) THEN
  RAISE EXCEPTION 'INVALID_TRANSFER_EVIDENCE' USING ERRCODE='22023'; END IF;
 SELECT * INTO r FROM public.srk_master_payout_requests WHERE id=p_request_id FOR UPDATE;
 IF NOT FOUND OR r.status<>'approved' THEN RAISE EXCEPTION 'PAYOUT_REQUEST_MUST_BE_APPROVED_FIRST'; END IF;
 SELECT count(*) INTO v_unsettled FROM public.srk_master_payout_request_items i
 JOIN public.srk_master_technician_payables p ON p.id=i.payable_id
 JOIN public.srk_master_booking_payments m ON m.id=p.payment_id
 WHERE i.payout_request_id=r.id AND m.payment_method='razorpay'
 AND NOT EXISTS(SELECT 1 FROM public.srk_master_company_settlements s WHERE s.payment_id=m.id);
 IF v_unsettled>0 THEN RAISE EXCEPTION 'COMPANY_RAZORPAY_SETTLEMENT_NOT_CONFIRMED'; END IF;
 SELECT count(*) INTO v_payable_count FROM public.srk_master_payout_request_items i
 JOIN public.srk_master_technician_payables p ON p.id=i.payable_id
 WHERE i.payout_request_id=r.id AND p.payout_status='requested';
 SELECT count(*) INTO v_credit_count FROM public.srk_master_payout_request_credits i
 JOIN public.srk_master_technician_wallet_credits c ON c.id=i.wallet_credit_id
 WHERE i.payout_request_id=r.id AND c.status='requested';
 IF v_payable_count<>(SELECT count(*) FROM public.srk_master_payout_request_items WHERE payout_request_id=r.id)
   OR v_credit_count<>(SELECT count(*) FROM public.srk_master_payout_request_credits WHERE payout_request_id=r.id)
   OR v_payable_count+v_credit_count=0 THEN
   RAISE EXCEPTION 'PAYOUT_ITEMS_NOT_IN_REQUESTED_STATE';
 END IF;
 UPDATE public.srk_master_technician_payables p SET payout_status='paid',payout_method=p_method,
  payout_reference=btrim(p_transfer_reference),paid_by=auth.uid(),paid_at=clock_timestamp()
 FROM public.srk_master_payout_request_items i WHERE i.payout_request_id=r.id AND p.id=i.payable_id AND p.payout_status='requested';
 UPDATE public.srk_master_technician_wallet_credits c SET status='paid',payout_reference=btrim(p_transfer_reference),
  paid_by=auth.uid(),paid_at=clock_timestamp()
 FROM public.srk_master_payout_request_credits i WHERE i.payout_request_id=r.id AND c.id=i.wallet_credit_id AND c.status='requested';
 UPDATE public.srk_master_payout_requests SET status='paid',transfer_method=p_method,transfer_reference=btrim(p_transfer_reference),
  paid_by=auth.uid(),paid_at=clock_timestamp(),reviewed_by=auth.uid(),reviewed_at=clock_timestamp(),
  review_note=nullif(btrim(coalesce(p_note,'')),'') WHERE id=r.id;
 RETURN jsonb_build_object('success',true,'request_id',r.id,'status','paid',
  'payable_count',v_payable_count,'commission_refund_credit_count',v_credit_count);
END;
$$;

REVOKE ALL ON FUNCTION public.srk_technician_request_master_payout(text,text,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.srk_technician_request_master_payout(text,text,text) TO authenticated;
REVOKE ALL ON FUNCTION public.srk_admin_list_master_payout_requests() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.srk_admin_list_master_payout_requests() TO authenticated;
REVOKE ALL ON FUNCTION public.srk_admin_review_master_payout_request(uuid,text,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.srk_admin_review_master_payout_request(uuid,text,text) TO authenticated;
REVOKE ALL ON FUNCTION public.srk_admin_mark_master_payout_paid(uuid,text,text,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.srk_admin_mark_master_payout_paid(uuid,text,text,text) TO authenticated;
