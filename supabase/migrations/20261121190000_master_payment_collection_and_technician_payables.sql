-- Master booking payment ledger and verified online/manual collection RPCs.
-- Feature-branch source only. Do not apply to TEST/Production or enable booking flags yet.

CREATE TABLE IF NOT EXISTS public.srk_master_booking_payments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_id uuid NOT NULL UNIQUE REFERENCES public.service_bookings(id) ON DELETE RESTRICT,
  final_bill_id uuid NOT NULL UNIQUE REFERENCES public.srk_booking_final_bills(id) ON DELETE RESTRICT,
  payment_method text NOT NULL CHECK(payment_method IN ('razorpay','cash','upi','bank_transfer')),
  payment_status text NOT NULL CHECK(payment_status IN ('paid','refunded')),
  amount_paise bigint NOT NULL CHECK(amount_paise>0),
  razorpay_order_id text UNIQUE CHECK(razorpay_order_id IS NULL OR razorpay_order_id ~ '^order_[A-Za-z0-9]+$'),
  razorpay_payment_id text UNIQUE CHECK(razorpay_payment_id IS NULL OR razorpay_payment_id ~ '^pay_[A-Za-z0-9]+$'),
  manual_payment_entry_id uuid REFERENCES public.srk_manual_payment_entries(id) ON DELETE RESTRICT,
  payment_reference text,
  recorded_by uuid REFERENCES auth.users(id) ON DELETE RESTRICT,
  verified_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  CHECK (
    (payment_method='razorpay' AND razorpay_order_id IS NOT NULL AND razorpay_payment_id IS NOT NULL
      AND manual_payment_entry_id IS NULL)
    OR
    (payment_method<>'razorpay' AND razorpay_order_id IS NULL AND razorpay_payment_id IS NULL
      AND manual_payment_entry_id IS NOT NULL AND payment_reference IS NOT NULL)
  )
);

CREATE TABLE IF NOT EXISTS public.srk_master_technician_payables (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_id uuid NOT NULL REFERENCES public.service_bookings(id) ON DELETE RESTRICT,
  payment_id uuid NOT NULL REFERENCES public.srk_master_booking_payments(id) ON DELETE RESTRICT,
  technician_id uuid NOT NULL REFERENCES public.srk_technicians(id) ON DELETE RESTRICT,
  labour_gross_paise bigint NOT NULL CHECK(labour_gross_paise>=0),
  company_commission_paise bigint NOT NULL CHECK(company_commission_paise>=0),
  labour_payable_paise bigint NOT NULL CHECK(labour_payable_paise=labour_gross_paise-company_commission_paise),
  materials_reimbursement_paise bigint NOT NULL DEFAULT 0 CHECK(materials_reimbursement_paise>=0),
  total_payable_paise bigint NOT NULL CHECK(total_payable_paise=labour_payable_paise+materials_reimbursement_paise),
  payout_status text NOT NULL DEFAULT 'pending' CHECK(payout_status IN ('pending','requested','paid','blocked','refunded')),
  payout_method text CHECK(payout_method IN ('upi','bank')),
  payout_reference text,
  paid_by uuid REFERENCES auth.users(id) ON DELETE RESTRICT,
  paid_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  UNIQUE(booking_id,technician_id),
  CHECK(payout_status<>'paid' OR (payout_method IS NOT NULL AND char_length(btrim(coalesce(payout_reference,'')))>=4 AND paid_by IS NOT NULL AND paid_at IS NOT NULL))
);

CREATE TABLE IF NOT EXISTS public.srk_master_payment_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_id uuid NOT NULL REFERENCES public.service_bookings(id) ON DELETE RESTRICT,
  payment_id uuid REFERENCES public.srk_master_booking_payments(id) ON DELETE RESTRICT,
  event_type text NOT NULL CHECK(event_type IN ('online_captured','manual_recorded','refund_processed')),
  amount_paise bigint NOT NULL CHECK(amount_paise>0),
  provider_reference text,
  actor_user_id uuid REFERENCES auth.users(id) ON DELETE RESTRICT,
  event_data jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT clock_timestamp()
);

ALTER TABLE public.srk_master_booking_payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.srk_master_technician_payables ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.srk_master_payment_events ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.srk_master_booking_payments,public.srk_master_technician_payables,
 public.srk_master_payment_events FROM PUBLIC,anon,authenticated;
GRANT ALL ON public.srk_master_booking_payments,public.srk_master_technician_payables,
 public.srk_master_payment_events TO service_role;

CREATE OR REPLACE FUNCTION public.srk_guard_master_payment_history()
RETURNS trigger LANGUAGE plpgsql SET search_path='' AS $$
BEGIN RAISE EXCEPTION 'MASTER_PAYMENT_HISTORY_IS_IMMUTABLE' USING ERRCODE='55000'; END; $$;
REVOKE ALL ON FUNCTION public.srk_guard_master_payment_history() FROM PUBLIC,anon,authenticated;
DROP TRIGGER IF EXISTS srk_master_payment_events_append_only ON public.srk_master_payment_events;
CREATE TRIGGER srk_master_payment_events_append_only BEFORE UPDATE OR DELETE
ON public.srk_master_payment_events FOR EACH ROW EXECUTE FUNCTION public.srk_guard_master_payment_history();

CREATE OR REPLACE FUNCTION public.srk_service_role_record_master_online_payment(
 p_booking_id uuid,p_order_id text,p_payment_id text,p_amount_paise bigint
)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path=pg_catalog,public,auth,pg_temp AS $$
DECLARE
 b public.service_bookings%rowtype; f public.srk_booking_final_bills%rowtype;
 p public.srk_master_booking_payments%rowtype; v_payment_id uuid;
 v_commission_left bigint; v_count integer; v_i integer:=0; r record;
 v_share bigint; v_materials_owner uuid;
BEGIN
 IF coalesce(auth.jwt()->>'role','')<>'service_role' THEN RAISE EXCEPTION 'SERVICE_ROLE_REQUIRED' USING ERRCODE='42501'; END IF;
 IF p_booking_id IS NULL OR p_order_id !~ '^order_[A-Za-z0-9]+$'
   OR p_payment_id !~ '^pay_[A-Za-z0-9]+$' OR p_amount_paise<100 THEN
   RAISE EXCEPTION 'INVALID_MASTER_ONLINE_PAYMENT' USING ERRCODE='22023';
 END IF;
 SELECT * INTO b FROM public.service_bookings WHERE id=p_booking_id FOR UPDATE;
 IF NOT FOUND OR b.srk_service_category_code IS NULL OR b.status<>'completed'
   OR b.completion_approval_status<>'approved' OR b.customer_completed_at IS NULL THEN
   RAISE EXCEPTION 'CUSTOMER_CONFIRMED_MASTER_COMPLETION_REQUIRED' USING ERRCODE='55000';
 END IF;
 SELECT * INTO f FROM public.srk_booking_final_bills WHERE booking_id=p_booking_id;
 IF NOT FOUND OR f.subtotal_paise<>p_amount_paise THEN RAISE EXCEPTION 'FINAL_BILL_AMOUNT_MISMATCH' USING ERRCODE='55000'; END IF;
 IF b.payment_status='refunded' THEN RAISE EXCEPTION 'PAYMENT_ALREADY_REFUNDED'; END IF;
 IF b.payment_status='paid' THEN
   SELECT * INTO p FROM public.srk_master_booking_payments WHERE booking_id=p_booking_id;
   IF FOUND AND p.razorpay_payment_id=p_payment_id AND p.razorpay_order_id=p_order_id AND p.amount_paise=p_amount_paise
     THEN RETURN jsonb_build_object('success',true,'already_processed',true,'payment_id',p.id); END IF;
   RAISE EXCEPTION 'BOOKING_ALREADY_PAID_WITH_DIFFERENT_PAYMENT';
 END IF;
 IF b.razorpay_order_id IS DISTINCT FROM p_order_id THEN RAISE EXCEPTION 'RAZORPAY_ORDER_BOOKING_MISMATCH'; END IF;

 INSERT INTO public.srk_master_booking_payments(booking_id,final_bill_id,payment_method,payment_status,
   amount_paise,razorpay_order_id,razorpay_payment_id)
 VALUES(p_booking_id,f.id,'razorpay','paid',p_amount_paise,p_order_id,p_payment_id)
 RETURNING id INTO v_payment_id;

 SELECT count(*) INTO v_count FROM (
   SELECT technician_id FROM public.srk_booking_technician_labour_ledger
    WHERE booking_id=p_booking_id GROUP BY technician_id
 ) q;
 IF v_count=0 THEN RAISE EXCEPTION 'TECHNICIAN_LEDGER_ALLOCATIONS_REQUIRED'; END IF;
 v_commission_left:=f.company_commission_paise;
 SELECT submitted_by_technician_id INTO v_materials_owner
   FROM public.srk_booking_material_requests WHERE booking_id=p_booking_id AND status='approved';
 FOR r IN
   SELECT technician_id,sum(total_labour_paise)::bigint AS gross
    FROM public.srk_booking_technician_labour_ledger
    WHERE booking_id=p_booking_id GROUP BY technician_id ORDER BY technician_id
 LOOP
   v_i:=v_i+1;
   IF v_i=v_count THEN v_share:=v_commission_left;
   ELSE
     v_share:=round(r.gross::numeric*f.company_commission_paise/f.labour_amount_paise)::bigint;
     v_share:=least(greatest(v_share,0),v_commission_left);
     v_commission_left:=v_commission_left-v_share;
   END IF;
   INSERT INTO public.srk_master_technician_payables(
    booking_id,payment_id,technician_id,labour_gross_paise,company_commission_paise,
    labour_payable_paise,materials_reimbursement_paise,total_payable_paise
   ) VALUES(p_booking_id,v_payment_id,r.technician_id,r.gross,v_share,r.gross-v_share,
    CASE WHEN r.technician_id=v_materials_owner THEN f.materials_amount_paise ELSE 0 END,
    r.gross-v_share+CASE WHEN r.technician_id=v_materials_owner THEN f.materials_amount_paise ELSE 0 END);
 END LOOP;

 INSERT INTO public.srk_master_payment_events(booking_id,payment_id,event_type,amount_paise,provider_reference,event_data)
 VALUES(p_booking_id,v_payment_id,'online_captured',p_amount_paise,p_payment_id,
   jsonb_build_object('order_id',p_order_id,'currency','INR'));
 UPDATE public.service_bookings SET payment_status='paid',amount_paid=p_amount_paise/100.0,
   razorpay_payment_id=p_payment_id,payment_verified_at=clock_timestamp()
 WHERE id=p_booking_id AND payment_status NOT IN ('paid','refunded');
 IF NOT FOUND THEN RAISE EXCEPTION 'BOOKING_PAYMENT_STATE_CHANGED' USING ERRCODE='40001'; END IF;
 RETURN jsonb_build_object('success',true,'already_processed',false,'payment_id',v_payment_id,
   'amount_paise',p_amount_paise,'commission_paise',f.company_commission_paise,
   'technician_payables_created',v_count);
END; $$;

CREATE OR REPLACE FUNCTION public.srk_admin_record_master_manual_payment(
 p_booking_id uuid,p_method text,p_reference text,p_note text DEFAULT NULL
)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path=pg_catalog,public,auth,pg_temp AS $$
DECLARE b public.service_bookings%rowtype; f public.srk_booking_final_bills%rowtype;
 v_entry uuid; v_payment uuid; r record; v_count integer; v_i integer:=0; v_left bigint; v_share bigint;
 v_materials_owner uuid;
BEGIN
 IF auth.uid() IS NULL OR NOT public.is_srk_admin() THEN RAISE EXCEPTION 'ADMIN_ONLY' USING ERRCODE='42501'; END IF;
 IF p_method NOT IN ('cash','upi','bank_transfer') OR char_length(btrim(coalesce(p_reference,'')))<4
   OR char_length(p_reference)>120 OR (p_note IS NOT NULL AND char_length(p_note)>250) THEN
   RAISE EXCEPTION 'INVALID_MANUAL_PAYMENT_EVIDENCE' USING ERRCODE='22023';
 END IF;
 SELECT * INTO b FROM public.service_bookings WHERE id=p_booking_id FOR UPDATE;
 IF NOT FOUND OR b.srk_service_category_code IS NULL OR b.status<>'completed'
   OR b.completion_approval_status<>'approved' OR b.customer_completed_at IS NULL THEN
   RAISE EXCEPTION 'CUSTOMER_CONFIRMED_MASTER_COMPLETION_REQUIRED' USING ERRCODE='55000';
 END IF;
 SELECT * INTO f FROM public.srk_booking_final_bills WHERE booking_id=p_booking_id;
 IF NOT FOUND THEN RAISE EXCEPTION 'MASTER_FINAL_BILL_REQUIRED'; END IF;
 IF b.payment_status NOT IN ('unpaid','pending') OR b.payment_verified_at IS NOT NULL
   OR coalesce(b.amount_paid,0)<>0 OR b.razorpay_order_id IS NOT NULL OR b.razorpay_payment_id IS NOT NULL THEN
   RAISE EXCEPTION 'BOOKING_ALREADY_HAS_PAYMENT_STATE';
 END IF;
 INSERT INTO public.srk_manual_payment_entries(booking_id,payment_method,amount,payment_reference,note,recorded_by)
 VALUES(p_booking_id,p_method,f.subtotal_paise/100.0,p_reference,nullif(btrim(coalesce(p_note,'')),''),auth.uid())
 RETURNING id INTO v_entry;
 INSERT INTO public.srk_master_booking_payments(booking_id,final_bill_id,payment_method,payment_status,
  amount_paise,manual_payment_entry_id,payment_reference,recorded_by)
 VALUES(p_booking_id,f.id,p_method,'paid',f.subtotal_paise,v_entry,p_reference,auth.uid())
 RETURNING id INTO v_payment;
 SELECT count(*) INTO v_count FROM (SELECT technician_id FROM public.srk_booking_technician_labour_ledger
  WHERE booking_id=p_booking_id GROUP BY technician_id) q;
 v_left:=f.company_commission_paise;
 SELECT submitted_by_technician_id INTO v_materials_owner FROM public.srk_booking_material_requests
  WHERE booking_id=p_booking_id AND status='approved';
 FOR r IN SELECT technician_id,sum(total_labour_paise)::bigint gross
  FROM public.srk_booking_technician_labour_ledger WHERE booking_id=p_booking_id
  GROUP BY technician_id ORDER BY technician_id
 LOOP
  v_i:=v_i+1;
  IF v_i=v_count THEN v_share:=v_left;
  ELSE v_share:=least(round(r.gross::numeric*f.company_commission_paise/f.labour_amount_paise)::bigint,v_left);v_left:=v_left-v_share; END IF;
  INSERT INTO public.srk_master_technician_payables(booking_id,payment_id,technician_id,labour_gross_paise,
   company_commission_paise,labour_payable_paise,materials_reimbursement_paise,total_payable_paise)
  VALUES(p_booking_id,v_payment,r.technician_id,r.gross,v_share,r.gross-v_share,
   CASE WHEN r.technician_id=v_materials_owner THEN f.materials_amount_paise ELSE 0 END,
   r.gross-v_share+CASE WHEN r.technician_id=v_materials_owner THEN f.materials_amount_paise ELSE 0 END);
 END LOOP;
 INSERT INTO public.srk_master_payment_events(booking_id,payment_id,event_type,amount_paise,provider_reference,actor_user_id)
 VALUES(p_booking_id,v_payment,'manual_recorded',f.subtotal_paise,p_reference,auth.uid());
 UPDATE public.service_bookings SET payment_status='paid',amount_paid=f.subtotal_paise/100.0,
  payment_method=p_method,payment_verified_at=clock_timestamp()
 WHERE id=p_booking_id AND payment_status IN ('unpaid','pending');
 IF NOT FOUND THEN RAISE EXCEPTION 'BOOKING_PAYMENT_STATE_CHANGED'; END IF;
 RETURN jsonb_build_object('success',true,'booking_id',p_booking_id,'payment_id',v_payment,
  'payment_entry_id',v_entry,'amount_paise',f.subtotal_paise,'technician_payables_created',v_count);
END; $$;

REVOKE ALL ON FUNCTION public.srk_service_role_record_master_online_payment(uuid,text,text,bigint) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.srk_service_role_record_master_online_payment(uuid,text,text,bigint) TO service_role;
REVOKE ALL ON FUNCTION public.srk_admin_record_master_manual_payment(uuid,text,text,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.srk_admin_record_master_manual_payment(uuid,text,text,text) TO authenticated;

COMMENT ON TABLE public.srk_master_technician_payables IS
 'Per-Technician payable snapshots for Master bookings. Company commission is allocated across assigned Technicians; approved materials reimburse the submitting Technician.';
COMMENT ON TABLE public.srk_master_booking_payments IS
 'Verified Master booking collection records, independent of legacy single-Electrician payout records.';
