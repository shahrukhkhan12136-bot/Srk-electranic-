-- Service-only Master Technician wallet. Historical rows remain unchanged.
-- Feature-branch source only; never apply to Main without explicit approval.
CREATE OR REPLACE FUNCTION public.srk_guard_master_payable_service_only()
RETURNS trigger LANGUAGE plpgsql SET search_path=pg_catalog,public AS $$
BEGIN
  NEW.materials_reimbursement_paise:=0;
  NEW.total_payable_paise:=NEW.labour_payable_paise;
  RETURN NEW;
END; $$;
REVOKE ALL ON FUNCTION public.srk_guard_master_payable_service_only() FROM PUBLIC,anon,authenticated;
DROP TRIGGER IF EXISTS srk_master_payable_service_only_insert ON public.srk_master_technician_payables;
CREATE TRIGGER srk_master_payable_service_only_insert
BEFORE INSERT ON public.srk_master_technician_payables
FOR EACH ROW EXECUTE FUNCTION public.srk_guard_master_payable_service_only();

CREATE OR REPLACE FUNCTION public.srk_master_wallet_summary()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path=pg_catalog,public,auth,pg_temp AS $$
DECLARE v_uid uuid:=auth.uid(); v_tid uuid; v_out jsonb;
BEGIN
 IF v_uid IS NULL THEN RAISE EXCEPTION 'AUTH_REQUIRED' USING ERRCODE='42501'; END IF;
 SELECT id INTO v_tid FROM public.srk_technicians WHERE auth_user_id=v_uid;
 IF v_tid IS NULL THEN RAISE EXCEPTION 'TECHNICIAN_IDENTITY_NOT_LINKED' USING ERRCODE='P0002'; END IF;
 SELECT jsonb_build_object(
  'technician_id',v_tid,
  'earned_paise',coalesce(sum(p.labour_payable_paise),0),
  'pending_paise',coalesce(sum(p.labour_payable_paise) FILTER(WHERE p.payout_status='pending'),0),
  'requested_paise',coalesce(sum(p.labour_payable_paise) FILTER(WHERE p.payout_status='requested'),0),
  'paid_paise',coalesce(sum(p.labour_payable_paise) FILTER(WHERE p.payout_status='paid'),0),
  'blocked_paise',coalesce(sum(p.labour_payable_paise) FILTER(WHERE p.payout_status='blocked'),0),
  'refunded_paise',coalesce(sum(p.labour_payable_paise) FILTER(WHERE p.payout_status='refunded'),0),
  'currency','INR',
  'payables',coalesce(jsonb_agg(jsonb_build_object('payable_id',p.id,'booking_id',p.booking_id,
   'amount_paise',p.labour_payable_paise,'status',p.payout_status,'payment_method',m.payment_method,
   'created_at',p.created_at) ORDER BY p.created_at DESC) FILTER(WHERE p.id IS NOT NULL),'[]'::jsonb)
 ) INTO v_out FROM public.srk_master_technician_payables p
 JOIN public.srk_master_booking_payments m ON m.id=p.payment_id WHERE p.technician_id=v_tid;
 RETURN v_out;
END; $$;

CREATE OR REPLACE FUNCTION public.srk_technician_request_master_payout(
 p_destination_type text,p_destination_reference text,p_idempotency_key text
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path=pg_catalog,public,auth,pg_temp AS $$
DECLARE v_uid uuid:=auth.uid(); v_tid uuid; v_req uuid; v_total bigint;
BEGIN
 IF v_uid IS NULL THEN RAISE EXCEPTION 'AUTH_REQUIRED' USING ERRCODE='42501'; END IF;
 IF p_destination_type NOT IN ('upi','bank') OR char_length(btrim(coalesce(p_destination_reference,'')))<4
  OR char_length(p_destination_reference)>160 OR char_length(btrim(coalesce(p_idempotency_key,'')))<8
  OR char_length(p_idempotency_key)>120 THEN RAISE EXCEPTION 'INVALID_PAYOUT_REQUEST' USING ERRCODE='22023'; END IF;
 SELECT id INTO v_tid FROM public.srk_technicians WHERE auth_user_id=v_uid FOR UPDATE;
 IF v_tid IS NULL THEN RAISE EXCEPTION 'TECHNICIAN_IDENTITY_NOT_LINKED'; END IF;
 SELECT id INTO v_req FROM public.srk_master_payout_requests WHERE technician_id=v_tid AND idempotency_key=p_idempotency_key;
 IF v_req IS NOT NULL THEN RETURN jsonb_build_object('success',true,'already_processed',true,'request_id',v_req); END IF;
 IF EXISTS(SELECT 1 FROM public.srk_master_payout_requests WHERE technician_id=v_tid AND status IN ('requested','approved'))
  THEN RAISE EXCEPTION 'PAYOUT_REQUEST_ALREADY_OPEN'; END IF;
 SELECT coalesce(sum(labour_payable_paise),0) INTO v_total FROM public.srk_master_technician_payables
 WHERE technician_id=v_tid AND payout_status='pending';
 IF v_total<=0 THEN RAISE EXCEPTION 'NO_AVAILABLE_PAYOUT_BALANCE'; END IF;
 INSERT INTO public.srk_master_payout_requests(technician_id,auth_user_id,amount_paise,destination_type,destination_reference,idempotency_key)
 VALUES(v_tid,v_uid,v_total,p_destination_type,btrim(p_destination_reference),p_idempotency_key) RETURNING id INTO v_req;
 INSERT INTO public.srk_master_payout_request_items(payout_request_id,payable_id,amount_paise)
 SELECT v_req,id,labour_payable_paise FROM public.srk_master_technician_payables
 WHERE technician_id=v_tid AND payout_status='pending' AND labour_payable_paise>0;
 UPDATE public.srk_master_technician_payables SET payout_status='requested'
 WHERE technician_id=v_tid AND payout_status='pending' AND labour_payable_paise>0;
 RETURN jsonb_build_object('success',true,'request_id',v_req,'amount_paise',v_total,'status','requested');
END; $$;

REVOKE ALL ON FUNCTION public.srk_master_wallet_summary() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.srk_master_wallet_summary() TO authenticated;
REVOKE ALL ON FUNCTION public.srk_technician_request_master_payout(text,text,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.srk_technician_request_master_payout(text,text,text) TO authenticated;
COMMENT ON FUNCTION public.srk_master_wallet_summary() IS 'Wallet totals use service/labour net payables only.';
COMMENT ON FUNCTION public.srk_technician_request_master_payout(text,text,text) IS 'Payout requests include service/labour net payables only.';
