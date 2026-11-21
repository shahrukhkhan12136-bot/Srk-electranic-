-- Master Technician wallet + payout request + settlement gate.
-- Feature-branch source only. No DB has been modified by this file.
CREATE TABLE IF NOT EXISTS public.srk_master_company_settlements (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 payment_id uuid NOT NULL REFERENCES public.srk_master_booking_payments(id) ON DELETE RESTRICT,
 settlement_reference text NOT NULL CHECK(char_length(btrim(settlement_reference)) BETWEEN 4 AND 120),
 settled_amount_paise bigint NOT NULL CHECK(settled_amount_paise>0),
 evidence_note text,
 confirmed_by uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
 confirmed_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 UNIQUE(payment_id), UNIQUE(settlement_reference)
);
CREATE TABLE IF NOT EXISTS public.srk_master_payout_requests (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 technician_id uuid NOT NULL REFERENCES public.srk_technicians(id) ON DELETE RESTRICT,
 auth_user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
 amount_paise bigint NOT NULL CHECK(amount_paise>0),
 destination_type text NOT NULL CHECK(destination_type IN ('upi','bank')),
 destination_reference text NOT NULL CHECK(char_length(btrim(destination_reference)) BETWEEN 4 AND 160),
 status text NOT NULL DEFAULT 'requested' CHECK(status IN ('requested','approved','paid','rejected','cancelled')),
 requested_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 reviewed_by uuid REFERENCES auth.users(id) ON DELETE RESTRICT,
 reviewed_at timestamptz,
 review_note text,
 transfer_reference text,
 transfer_method text CHECK(transfer_method IN ('upi','bank')),
 paid_by uuid REFERENCES auth.users(id) ON DELETE RESTRICT,
 paid_at timestamptz,
 idempotency_key text NOT NULL,
 UNIQUE(technician_id,idempotency_key),
 CHECK(status<>'paid' OR (transfer_reference IS NOT NULL AND char_length(btrim(transfer_reference))>=4 AND transfer_method IS NOT NULL AND paid_by IS NOT NULL AND paid_at IS NOT NULL))
);
CREATE UNIQUE INDEX IF NOT EXISTS srk_master_payout_transfer_reference_uidx
 ON public.srk_master_payout_requests(upper(transfer_reference)) WHERE transfer_reference IS NOT NULL;
CREATE TABLE IF NOT EXISTS public.srk_master_payout_request_items (
 payout_request_id uuid NOT NULL REFERENCES public.srk_master_payout_requests(id) ON DELETE RESTRICT,
 payable_id uuid NOT NULL REFERENCES public.srk_master_technician_payables(id) ON DELETE RESTRICT,
 amount_paise bigint NOT NULL CHECK(amount_paise>0),
 created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 PRIMARY KEY(payout_request_id,payable_id),
 UNIQUE(payable_id)
);
ALTER TABLE public.srk_master_company_settlements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.srk_master_payout_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.srk_master_payout_request_items ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.srk_master_company_settlements,public.srk_master_payout_requests,public.srk_master_payout_request_items FROM PUBLIC,anon,authenticated;
GRANT ALL ON public.srk_master_company_settlements,public.srk_master_payout_requests,public.srk_master_payout_request_items TO service_role;

CREATE OR REPLACE FUNCTION public.srk_master_wallet_summary()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public,auth,pg_temp AS $$
DECLARE v_uid uuid:=auth.uid(); v_tid uuid; v_out jsonb;
BEGIN
 IF v_uid IS NULL THEN RAISE EXCEPTION 'AUTH_REQUIRED' USING ERRCODE='42501'; END IF;
 SELECT id INTO v_tid FROM public.srk_technicians WHERE auth_user_id=v_uid;
 IF v_tid IS NULL THEN RAISE EXCEPTION 'TECHNICIAN_IDENTITY_NOT_LINKED' USING ERRCODE='P0002'; END IF;
 SELECT jsonb_build_object(
  'technician_id',v_tid,
  'earned_paise',coalesce(sum(p.total_payable_paise),0),
  'pending_paise',coalesce(sum(p.total_payable_paise) FILTER(WHERE p.payout_status='pending'),0),
  'requested_paise',coalesce(sum(p.total_payable_paise) FILTER(WHERE p.payout_status='requested'),0),
  'paid_paise',coalesce(sum(p.total_payable_paise) FILTER(WHERE p.payout_status='paid'),0),
  'blocked_paise',coalesce(sum(p.total_payable_paise) FILTER(WHERE p.payout_status='blocked'),0),
  'refunded_paise',coalesce(sum(p.total_payable_paise) FILTER(WHERE p.payout_status='refunded'),0),
  'currency','INR',
  'payables',coalesce(jsonb_agg(jsonb_build_object('payable_id',p.id,'booking_id',p.booking_id,'amount_paise',p.total_payable_paise,'status',p.payout_status,'payment_method',m.payment_method,'created_at',p.created_at) ORDER BY p.created_at DESC) FILTER(WHERE p.id IS NOT NULL),'[]'::jsonb)
 ) INTO v_out
 FROM public.srk_master_technician_payables p
 JOIN public.srk_master_booking_payments m ON m.id=p.payment_id
 WHERE p.technician_id=v_tid;
 RETURN v_out;
END; $$;

CREATE OR REPLACE FUNCTION public.srk_technician_request_master_payout(
 p_destination_type text,p_destination_reference text,p_idempotency_key text
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public,auth,pg_temp AS $$
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
 IF EXISTS(SELECT 1 FROM public.srk_master_payout_requests WHERE technician_id=v_tid AND status IN ('requested','approved')) THEN
  RAISE EXCEPTION 'PAYOUT_REQUEST_ALREADY_OPEN';
 END IF;
 SELECT coalesce(sum(total_payable_paise),0) INTO v_total FROM public.srk_master_technician_payables
 WHERE technician_id=v_tid AND payout_status='pending';
 IF v_total<=0 THEN RAISE EXCEPTION 'NO_AVAILABLE_PAYOUT_BALANCE'; END IF;
 INSERT INTO public.srk_master_payout_requests(technician_id,auth_user_id,amount_paise,destination_type,destination_reference,idempotency_key)
 VALUES(v_tid,v_uid,v_total,p_destination_type,btrim(p_destination_reference),p_idempotency_key) RETURNING id INTO v_req;
 INSERT INTO public.srk_master_payout_request_items(payout_request_id,payable_id,amount_paise)
 SELECT v_req,id,total_payable_paise FROM public.srk_master_technician_payables
 WHERE technician_id=v_tid AND payout_status='pending';
 UPDATE public.srk_master_technician_payables SET payout_status='requested'
 WHERE technician_id=v_tid AND payout_status='pending';
 RETURN jsonb_build_object('success',true,'request_id',v_req,'amount_paise',v_total,'status','requested');
END; $$;

CREATE OR REPLACE FUNCTION public.srk_admin_confirm_master_company_settlement(
 p_payment_id uuid,p_settlement_reference text,p_settled_amount_paise bigint,p_evidence_note text DEFAULT NULL
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public,auth,pg_temp AS $$
DECLARE v_payment public.srk_master_booking_payments%rowtype; v_id uuid;
BEGIN
 IF auth.uid() IS NULL OR NOT public.is_srk_admin() THEN RAISE EXCEPTION 'ADMIN_ONLY' USING ERRCODE='42501'; END IF;
 IF char_length(btrim(coalesce(p_settlement_reference,'')))<4 OR char_length(p_settlement_reference)>120
  OR p_settled_amount_paise<=0 OR (p_evidence_note IS NOT NULL AND char_length(p_evidence_note)>500) THEN
  RAISE EXCEPTION 'INVALID_SETTLEMENT_EVIDENCE' USING ERRCODE='22023'; END IF;
 SELECT * INTO v_payment FROM public.srk_master_booking_payments WHERE id=p_payment_id FOR UPDATE;
 IF NOT FOUND OR v_payment.payment_status<>'paid' OR v_payment.payment_method<>'razorpay' THEN
  RAISE EXCEPTION 'VERIFIED_RAZORPAY_PAYMENT_REQUIRED'; END IF;
 IF p_settled_amount_paise<v_payment.amount_paise THEN RAISE EXCEPTION 'SETTLEMENT_AMOUNT_BELOW_COLLECTION'; END IF;
 INSERT INTO public.srk_master_company_settlements(payment_id,settlement_reference,settled_amount_paise,evidence_note,confirmed_by)
 VALUES(p_payment_id,btrim(p_settlement_reference),p_settled_amount_paise,nullif(btrim(p_evidence_note),''),auth.uid())
 ON CONFLICT(payment_id) DO NOTHING RETURNING id INTO v_id;
 IF v_id IS NULL THEN RAISE EXCEPTION 'SETTLEMENT_ALREADY_RECORDED'; END IF;
 RETURN jsonb_build_object('success',true,'settlement_id',v_id,'payment_id',p_payment_id);
END; $$;

CREATE OR REPLACE FUNCTION public.srk_admin_list_master_payout_requests()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public,auth,pg_temp AS $$
DECLARE v_out jsonb;
BEGIN
 IF auth.uid() IS NULL OR NOT public.is_srk_admin() THEN RAISE EXCEPTION 'ADMIN_ONLY' USING ERRCODE='42501'; END IF;
 SELECT coalesce(jsonb_agg(jsonb_build_object(
  'request_id',r.id,'technician_id',r.technician_id,'technician_name',coalesce(ep.display_name,t.primary_phone,'Technician'),
  'amount_paise',r.amount_paise,'destination_type',r.destination_type,'destination_reference',r.destination_reference,
  'status',r.status,'requested_at',r.requested_at,'review_note',r.review_note,
  'payable_count',(SELECT count(*) FROM public.srk_master_payout_request_items i WHERE i.payout_request_id=r.id),
  'payments',(SELECT jsonb_agg(jsonb_build_object('payment_method',m.payment_method,'payment_id',m.id,'settlement_confirmed',EXISTS(SELECT 1 FROM public.srk_master_company_settlements s WHERE s.payment_id=m.id))) FROM public.srk_master_payout_request_items i JOIN public.srk_master_technician_payables p ON p.id=i.payable_id JOIN public.srk_master_booking_payments m ON m.id=p.payment_id WHERE i.payout_request_id=r.id)
 ) ORDER BY r.requested_at DESC),'[]'::jsonb) INTO v_out
 FROM public.srk_master_payout_requests r
 JOIN public.srk_technicians t ON t.id=r.technician_id
 LEFT JOIN public.srk_technician_profile_links l ON l.technician_id=t.id
 LEFT JOIN public.electrician_profiles ep ON ep.id=l.electrician_profile_id
 WHERE r.status IN ('requested','approved');
 RETURN v_out;
END; $$;

CREATE OR REPLACE FUNCTION public.srk_admin_review_master_payout_request(
 p_request_id uuid,p_decision text,p_review_note text DEFAULT NULL
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public,auth,pg_temp AS $
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
 END IF;
 RETURN jsonb_build_object('success',true,'request_id',r.id,'status',p_decision);
END; $;

CREATE OR REPLACE FUNCTION public.srk_admin_mark_master_payout_paid(
 p_request_id uuid,p_method text,p_transfer_reference text,p_note text DEFAULT NULL
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public,auth,pg_temp AS $$
DECLARE r public.srk_master_payout_requests%rowtype; v_unsettled integer; v_count integer;
BEGIN
 IF auth.uid() IS NULL OR NOT public.is_srk_admin() THEN RAISE EXCEPTION 'ADMIN_ONLY' USING ERRCODE='42501'; END IF;
 IF p_method NOT IN ('upi','bank') OR char_length(btrim(coalesce(p_transfer_reference,'')))<4
  OR char_length(p_transfer_reference)>120 OR (p_note IS NOT NULL AND char_length(p_note)>500) THEN
  RAISE EXCEPTION 'INVALID_TRANSFER_EVIDENCE' USING ERRCODE='22023'; END IF;
 SELECT * INTO r FROM public.srk_master_payout_requests WHERE id=p_request_id FOR UPDATE;
 IF NOT FOUND OR r.status NOT IN ('requested','approved') THEN RAISE EXCEPTION 'PAYOUT_REQUEST_NOT_OPEN'; END IF;
 SELECT count(*) INTO v_unsettled FROM public.srk_master_payout_request_items i
 JOIN public.srk_master_technician_payables p ON p.id=i.payable_id
 JOIN public.srk_master_booking_payments m ON m.id=p.payment_id
 WHERE i.payout_request_id=r.id AND m.payment_method='razorpay'
 AND NOT EXISTS(SELECT 1 FROM public.srk_master_company_settlements s WHERE s.payment_id=m.id);
 IF v_unsettled>0 THEN RAISE EXCEPTION 'COMPANY_RAZORPAY_SETTLEMENT_NOT_CONFIRMED'; END IF;
 SELECT count(*) INTO v_count FROM public.srk_master_payout_request_items WHERE payout_request_id=r.id;
 IF v_count=0 THEN RAISE EXCEPTION 'PAYOUT_REQUEST_HAS_NO_ITEMS'; END IF;
 IF (SELECT count(*) FROM public.srk_master_payout_request_items i JOIN public.srk_master_technician_payables p ON p.id=i.payable_id WHERE i.payout_request_id=r.id AND p.payout_status='requested')<>v_count THEN
  RAISE EXCEPTION 'PAYOUT_ITEMS_NOT_IN_REQUESTED_STATE'; END IF;
 UPDATE public.srk_master_technician_payables p SET payout_status='paid',payout_method=p_method,
  payout_reference=btrim(p_transfer_reference),paid_by=auth.uid(),paid_at=clock_timestamp()
 FROM public.srk_master_payout_request_items i WHERE i.payout_request_id=r.id AND p.id=i.payable_id AND p.payout_status='requested';
 IF NOT FOUND THEN RAISE EXCEPTION 'PAYOUT_ITEMS_NOT_IN_REQUESTED_STATE'; END IF;
 UPDATE public.srk_master_payout_requests SET status='paid',transfer_method=p_method,transfer_reference=btrim(p_transfer_reference),
  paid_by=auth.uid(),paid_at=clock_timestamp(),reviewed_by=auth.uid(),reviewed_at=clock_timestamp(),
  review_note=nullif(btrim(coalesce(p_note,'')),'') WHERE id=r.id;
 RETURN jsonb_build_object('success',true,'request_id',r.id,'status','paid','payable_count',v_count);
END; $$;

REVOKE ALL ON FUNCTION public.srk_master_wallet_summary() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.srk_master_wallet_summary() TO authenticated;
REVOKE ALL ON FUNCTION public.srk_technician_request_master_payout(text,text,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.srk_technician_request_master_payout(text,text,text) TO authenticated;
REVOKE ALL ON FUNCTION public.srk_admin_confirm_master_company_settlement(uuid,text,bigint,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.srk_admin_confirm_master_company_settlement(uuid,text,bigint,text) TO authenticated;
REVOKE ALL ON FUNCTION public.srk_admin_list_master_payout_requests() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.srk_admin_list_master_payout_requests() TO authenticated;
REVOKE ALL ON FUNCTION public.srk_admin_review_master_payout_request(uuid,text,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.srk_admin_review_master_payout_request(uuid,text,text) TO authenticated;
REVOKE ALL ON FUNCTION public.srk_admin_mark_master_payout_paid(uuid,text,text,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.srk_admin_mark_master_payout_paid(uuid,text,text,text) TO authenticated;
