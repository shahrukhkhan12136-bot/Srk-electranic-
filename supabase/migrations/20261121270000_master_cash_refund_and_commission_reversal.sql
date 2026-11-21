-- SRK ELECTRONIC Master cash refund: Technician evidence, Admin finalization,
-- and reversal of already-recovered 15% cash commission.
-- Feature-branch source only. Never apply to Production without separate approval.

CREATE TABLE IF NOT EXISTS public.srk_master_cash_refund_evidence (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_id uuid NOT NULL REFERENCES public.service_bookings(id) ON DELETE RESTRICT,
  payment_id uuid NOT NULL REFERENCES public.srk_master_booking_payments(id) ON DELETE RESTRICT,
  technician_id uuid NOT NULL REFERENCES public.srk_technicians(id) ON DELETE RESTRICT,
  amount_paise bigint NOT NULL CHECK (amount_paise > 0),
  refund_reference text NOT NULL CHECK (char_length(btrim(refund_reference)) BETWEEN 4 AND 120),
  evidence_uri text,
  evidence_note text,
  status text NOT NULL DEFAULT 'submitted' CHECK (status IN ('submitted','approved','rejected')),
  submitted_by uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
  submitted_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  reviewed_by uuid REFERENCES auth.users(id) ON DELETE RESTRICT,
  reviewed_at timestamptz,
  review_note text,
  UNIQUE (booking_id, technician_id),
  CHECK (evidence_uri IS NULL OR char_length(evidence_uri) <= 1000),
  CHECK (evidence_note IS NULL OR char_length(evidence_note) <= 500),
  CHECK (review_note IS NULL OR char_length(review_note) <= 500),
  CHECK (status <> 'approved' OR (reviewed_by IS NOT NULL AND reviewed_at IS NOT NULL))
);

CREATE TABLE IF NOT EXISTS public.srk_master_technician_wallet_credits (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  technician_id uuid NOT NULL REFERENCES public.srk_technicians(id) ON DELETE RESTRICT,
  source_due_id uuid NOT NULL REFERENCES public.srk_master_technician_commission_dues(id) ON DELETE RESTRICT,
  source_booking_id uuid NOT NULL REFERENCES public.service_bookings(id) ON DELETE RESTRICT,
  amount_paise bigint NOT NULL CHECK (amount_paise > 0),
  status text NOT NULL DEFAULT 'available' CHECK (status IN ('available','requested','paid','blocked')),
  payout_reference text,
  paid_by uuid REFERENCES auth.users(id) ON DELETE RESTRICT,
  paid_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  UNIQUE (source_due_id),
  CHECK (status <> 'paid' OR (char_length(btrim(coalesce(payout_reference,''))) >= 4 AND paid_by IS NOT NULL AND paid_at IS NOT NULL))
);

ALTER TABLE public.srk_master_technician_commission_dues
  ADD COLUMN IF NOT EXISTS commission_refunded_paise bigint NOT NULL DEFAULT 0
  CHECK (commission_refunded_paise >= 0 AND commission_refunded_paise <= commission_recovered_paise);

ALTER TABLE public.srk_master_cash_refund_evidence ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.srk_master_technician_wallet_credits ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.srk_master_cash_refund_evidence, public.srk_master_technician_wallet_credits
  FROM PUBLIC, anon, authenticated;
GRANT ALL ON public.srk_master_cash_refund_evidence, public.srk_master_technician_wallet_credits
  TO service_role;

CREATE OR REPLACE FUNCTION public.srk_guard_master_cash_refund_records()
RETURNS trigger LANGUAGE plpgsql SET search_path='' AS $$
BEGIN
  RAISE EXCEPTION 'MASTER_CASH_REFUND_RECORDS_ARE_IMMUTABLE' USING ERRCODE='55000';
END;
$$;
REVOKE ALL ON FUNCTION public.srk_guard_master_cash_refund_records() FROM PUBLIC, anon, authenticated;
DROP TRIGGER IF EXISTS srk_master_cash_refund_evidence_immutable ON public.srk_master_cash_refund_evidence;
CREATE TRIGGER srk_master_cash_refund_evidence_immutable
BEFORE UPDATE OR DELETE ON public.srk_master_cash_refund_evidence
FOR EACH ROW EXECUTE FUNCTION public.srk_guard_master_cash_refund_records();
-- Review decisions are represented by a separate append-only review event rather than editing evidence.
-- Wallet-credit source rows are created once; payout lifecycle metadata may be updated by the payout RPC.

CREATE TABLE IF NOT EXISTS public.srk_master_cash_refund_reviews (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  evidence_id uuid NOT NULL REFERENCES public.srk_master_cash_refund_evidence(id) ON DELETE RESTRICT,
  decision text NOT NULL CHECK (decision IN ('approved','rejected')),
  admin_user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
  note text,
  created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  UNIQUE (evidence_id),
  CHECK (note IS NULL OR char_length(note) <= 500)
);
ALTER TABLE public.srk_master_cash_refund_reviews ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.srk_master_cash_refund_reviews FROM PUBLIC, anon, authenticated;
GRANT ALL ON public.srk_master_cash_refund_reviews TO service_role;
CREATE TRIGGER srk_master_cash_refund_reviews_append_only
BEFORE UPDATE OR DELETE ON public.srk_master_cash_refund_reviews
FOR EACH ROW EXECUTE FUNCTION public.srk_guard_master_cash_refund_records();

-- Include directly-collected cash payables in refund reversal. This does not create a new
-- Technician payout: the Technician already received and then returned the customer's cash.
CREATE OR REPLACE FUNCTION public.srk_master_refund_payable_state_sync()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v_payment public.srk_master_booking_payments%rowtype;
BEGIN
 IF NEW.payment_status='refunded' AND OLD.payment_status IS DISTINCT FROM NEW.payment_status THEN
   UPDATE public.srk_master_technician_payables
      SET payout_status='refunded'
    WHERE booking_id=NEW.id AND payout_status IN ('pending','requested','blocked','cash_collected');
   UPDATE public.srk_master_booking_payments SET payment_status='refunded'
    WHERE booking_id=NEW.id AND payment_status='paid' RETURNING * INTO v_payment;
   IF FOUND THEN
     INSERT INTO public.srk_master_payment_events(
       booking_id,payment_id,event_type,amount_paise,provider_reference,event_data
     ) VALUES(
       NEW.id,v_payment.id,'refund_processed',v_payment.amount_paise,
       coalesce(v_payment.razorpay_payment_id,v_payment.payment_reference),
       jsonb_build_object('refund_status','processed','payment_method',v_payment.payment_method,
         'refund_channel',CASE WHEN v_payment.payment_method='cash'
           THEN 'technician_to_customer' ELSE 'company_payment_provider' END)
     );
   END IF;
 END IF;
 RETURN NEW;
END;
$$;
REVOKE ALL ON FUNCTION public.srk_master_refund_payable_state_sync() FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION public.srk_technician_submit_master_cash_refund_evidence(
  p_booking_id uuid, p_amount_paise bigint, p_refund_reference text,
  p_evidence_uri text DEFAULT NULL, p_evidence_note text DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path=pg_catalog,public,auth,pg_temp
AS $$
DECLARE v_uid uuid:=auth.uid(); v_tid uuid; v_payment public.srk_master_booking_payments%rowtype;
        v_booking public.service_bookings%rowtype; v_id uuid; v_total bigint;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'AUTH_REQUIRED' USING ERRCODE='42501'; END IF;
  IF p_booking_id IS NULL OR p_amount_paise<=0
     OR char_length(btrim(coalesce(p_refund_reference,''))) NOT BETWEEN 4 AND 120
     OR (p_evidence_uri IS NOT NULL AND char_length(p_evidence_uri)>1000)
     OR (p_evidence_note IS NOT NULL AND char_length(p_evidence_note)>500) THEN
    RAISE EXCEPTION 'INVALID_CASH_REFUND_EVIDENCE' USING ERRCODE='22023';
  END IF;
  SELECT id INTO v_tid FROM public.srk_technicians
   WHERE auth_user_id=v_uid AND account_status='active' FOR UPDATE;
  IF v_tid IS NULL THEN RAISE EXCEPTION 'ACTIVE_TECHNICIAN_IDENTITY_REQUIRED' USING ERRCODE='42501'; END IF;
  SELECT * INTO v_booking FROM public.service_bookings WHERE id=p_booking_id FOR UPDATE;
  IF NOT FOUND OR v_booking.srk_service_category_code IS NULL OR v_booking.status<>'completed'
     OR v_booking.completion_approval_status<>'approved' OR v_booking.customer_completed_at IS NULL THEN
    RAISE EXCEPTION 'COMPLETED_MASTER_BOOKING_REQUIRED' USING ERRCODE='55000';
  END IF;
  SELECT * INTO v_payment FROM public.srk_master_booking_payments
   WHERE booking_id=p_booking_id FOR UPDATE;
  IF NOT FOUND OR v_payment.payment_method<>'cash' OR v_payment.payment_status<>'paid'
     OR v_payment.amount_paise<>round(v_booking.amount_paid*100)::bigint THEN
    RAISE EXCEPTION 'VERIFIED_MASTER_CASH_PAYMENT_REQUIRED' USING ERRCODE='55000';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.srk_booking_refund_requests
    WHERE booking_id=p_booking_id AND status='approved' AND customer_user_id=v_booking.customer_user_id) THEN
    RAISE EXCEPTION 'MAIN_ADMIN_APPROVED_CUSTOMER_REFUND_REQUEST_REQUIRED' USING ERRCODE='55000';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.srk_master_technician_payables
    WHERE booking_id=p_booking_id AND payment_id=v_payment.id AND technician_id=v_tid) THEN
    RAISE EXCEPTION 'TECHNICIAN_NOT_ASSIGNED_TO_BOOKING' USING ERRCODE='42501';
  END IF;
  IF EXISTS (SELECT 1 FROM public.srk_master_cash_refund_evidence
    WHERE booking_id=p_booking_id AND technician_id=v_tid) THEN
    RAISE EXCEPTION 'TECHNICIAN_REFUND_EVIDENCE_ALREADY_SUBMITTED' USING ERRCODE='23505';
  END IF;
  SELECT coalesce(sum(amount_paise),0) INTO v_total
    FROM public.srk_master_cash_refund_evidence
   WHERE booking_id=p_booking_id AND status='submitted';
  IF v_total+p_amount_paise>v_payment.amount_paise THEN
    RAISE EXCEPTION 'REFUND_EVIDENCE_EXCEEDS_CUSTOMER_REFUND_AMOUNT' USING ERRCODE='22003';
  END IF;
  INSERT INTO public.srk_master_cash_refund_evidence(
    booking_id,payment_id,technician_id,amount_paise,refund_reference,evidence_uri,evidence_note,submitted_by
  ) VALUES (
    p_booking_id,v_payment.id,v_tid,p_amount_paise,btrim(p_refund_reference),
    nullif(btrim(coalesce(p_evidence_uri,'')),''),nullif(btrim(coalesce(p_evidence_note,'')),''),v_uid
  ) RETURNING id INTO v_id;
  RETURN jsonb_build_object('success',true,'evidence_id',v_id,'status','submitted','amount_paise',p_amount_paise);
END;
$$;

CREATE OR REPLACE FUNCTION public.srk_admin_finalize_master_cash_refund(
  p_booking_id uuid, p_admin_note text DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path=pg_catalog,public,auth,pg_temp
AS $$
DECLARE v_booking public.service_bookings%rowtype; v_payment public.srk_master_booking_payments%rowtype;
        v_request public.srk_booking_refund_requests%rowtype; v_final_bill public.srk_booking_final_bills%rowtype;
        v_total bigint; v_count integer; v_reference text; d record; v_credited bigint:=0; v_credit_count integer:=0;
BEGIN
  IF auth.uid() IS NULL OR NOT public.is_srk_admin() THEN RAISE EXCEPTION 'ADMIN_ONLY' USING ERRCODE='42501'; END IF;
  IF p_booking_id IS NULL OR (p_admin_note IS NOT NULL AND char_length(p_admin_note)>500) THEN
    RAISE EXCEPTION 'INVALID_REFUND_FINALIZATION_INPUT' USING ERRCODE='22023';
  END IF;
  SELECT * INTO v_booking FROM public.service_bookings WHERE id=p_booking_id FOR UPDATE;
  IF NOT FOUND OR v_booking.srk_service_category_code IS NULL OR v_booking.status<>'completed'
     OR v_booking.payment_status<>'paid' THEN RAISE EXCEPTION 'PAID_COMPLETED_MASTER_BOOKING_REQUIRED'; END IF;
  SELECT * INTO v_payment FROM public.srk_master_booking_payments WHERE booking_id=p_booking_id FOR UPDATE;
  IF NOT FOUND OR v_payment.payment_method<>'cash' OR v_payment.payment_status<>'paid'
     OR v_payment.amount_paise<>round(v_booking.amount_paid*100)::bigint THEN
    RAISE EXCEPTION 'VERIFIED_MASTER_CASH_PAYMENT_REQUIRED';
  END IF;
  SELECT * INTO v_final_bill FROM public.srk_booking_final_bills WHERE id=v_payment.final_bill_id FOR SHARE;
  IF NOT FOUND OR v_final_bill.subtotal_paise<>v_payment.amount_paise THEN
    RAISE EXCEPTION 'MASTER_FINAL_BILL_AMOUNT_MISMATCH';
  END IF;
  SELECT * INTO v_request FROM public.srk_booking_refund_requests
   WHERE booking_id=p_booking_id FOR UPDATE;
  IF NOT FOUND OR v_request.status<>'approved' OR v_request.customer_user_id<>v_booking.customer_user_id
     OR round(v_request.amount*100)::bigint<>v_payment.amount_paise THEN
    RAISE EXCEPTION 'MAIN_ADMIN_APPROVED_FULL_CUSTOMER_REFUND_REQUEST_REQUIRED';
  END IF;
  IF EXISTS (SELECT 1 FROM public.srk_manual_refund_entries WHERE booking_id=p_booking_id)
     OR EXISTS (SELECT 1 FROM public.srk_razorpay_refunds WHERE booking_id=p_booking_id) THEN
    RAISE EXCEPTION 'REFUND_ALREADY_RECORDED_FOR_BOOKING';
  END IF;
  SELECT count(*),coalesce(sum(e.amount_paise),0),
         string_agg(e.refund_reference,', ' ORDER BY e.technician_id)
    INTO v_count,v_total,v_reference
    FROM public.srk_master_cash_refund_evidence e
   WHERE e.booking_id=p_booking_id AND e.status='submitted';
  IF v_count=0 OR v_total<>v_payment.amount_paise THEN
    RAISE EXCEPTION 'TECHNICIAN_REFUND_EVIDENCE_MUST_EQUAL_FULL_CUSTOMER_REFUND'
      USING ERRCODE='55000';
  END IF;
  IF EXISTS (SELECT 1 FROM public.srk_master_cash_refund_reviews r
    JOIN public.srk_master_cash_refund_evidence e ON e.id=r.evidence_id
    WHERE e.booking_id=p_booking_id) THEN
    RAISE EXCEPTION 'CASH_REFUND_EVIDENCE_ALREADY_REVIEWED';
  END IF;

  -- The existing cancellation-fee refund trigger requires the established
  -- manual-refund audit row. Reuse it as a compatibility record; the evidence
  -- above proves that Technician(s), not SRK, returned the cash to Customer.
  INSERT INTO public.srk_manual_refund_entries(
    booking_id,payment_entry_id,amount,refund_reference,note,recorded_by
  ) VALUES (
    p_booking_id,v_payment.manual_payment_entry_id,v_payment.amount_paise/100.0,
    'MASTER-CASH-'||replace(p_booking_id::text,'-',''),
    left('Technician refund evidence: '||coalesce(v_reference,'')||'; Admin: '||coalesce(p_admin_note,''),250),
    auth.uid()
  );

  FOR d IN
    SELECT * FROM public.srk_master_technician_commission_dues
     WHERE booking_id=p_booking_id ORDER BY technician_id FOR UPDATE
  LOOP
    IF d.commission_recovered_paise>0 THEN
      INSERT INTO public.srk_master_technician_wallet_credits(
        technician_id,source_due_id,source_booking_id,amount_paise
      ) VALUES(d.technician_id,d.id,p_booking_id,d.commission_recovered_paise);
      v_credited:=v_credited+d.commission_recovered_paise;
      v_credit_count:=v_credit_count+1;
    END IF;
    UPDATE public.srk_master_technician_commission_dues
       SET status='refunded',commission_refunded_paise=d.commission_recovered_paise
     WHERE id=d.id;
    INSERT INTO public.srk_master_technician_commission_events(
      technician_id,booking_id,payment_id,event_type,amount_paise,source_due_id,event_data
    ) VALUES(
      d.technician_id,d.booking_id,d.payment_id,'cash_payment_refunded',d.commission_due_paise,d.id,
      jsonb_build_object('commission_recovered_paise',d.commission_recovered_paise,
        'wallet_credit_paise',d.commission_recovered_paise,'outstanding_commission_reversed_paise',
        d.commission_due_paise-d.commission_recovered_paise,'refund_channel','technician_to_customer')
    );
  END LOOP;

  INSERT INTO public.srk_master_cash_refund_reviews(evidence_id,decision,admin_user_id,note)
  SELECT e.id,'approved',auth.uid(),nullif(btrim(coalesce(p_admin_note,'')),'')
    FROM public.srk_master_cash_refund_evidence e WHERE e.booking_id=p_booking_id;
-- Submitted evidence remains immutable; the separate review rows carry Admin decisions.

  UPDATE public.service_bookings SET payment_status='refunded'
   WHERE id=p_booking_id AND payment_status='paid';
  IF NOT FOUND THEN RAISE EXCEPTION 'BOOKING_REFUND_STATE_CHANGED' USING ERRCODE='40001'; END IF;
  UPDATE public.srk_booking_refund_requests
     SET status='processed',processed_at=coalesce(processed_at,clock_timestamp()),updated_at=clock_timestamp()
   WHERE id=v_request.id AND status='approved';

  RETURN jsonb_build_object('success',true,'booking_id',p_booking_id,'status','refunded',
    'refund_amount_paise',v_payment.amount_paise,'technician_evidence_count',v_count,
    'commission_wallet_credit_paise',v_credited,'commission_wallet_credit_count',v_credit_count,
    'customer_refund_channel','technician_to_customer');
END;
$$;

REVOKE ALL ON FUNCTION public.srk_technician_submit_master_cash_refund_evidence(uuid,bigint,text,text,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.srk_technician_submit_master_cash_refund_evidence(uuid,bigint,text,text,text) TO authenticated;
REVOKE ALL ON FUNCTION public.srk_admin_finalize_master_cash_refund(uuid,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.srk_admin_finalize_master_cash_refund(uuid,text) TO authenticated;

CREATE OR REPLACE FUNCTION public.srk_admin_list_master_cash_refunds()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public,auth,pg_temp AS $$
BEGIN
  IF auth.uid() IS NULL OR NOT public.is_srk_admin() THEN RAISE EXCEPTION 'ADMIN_ONLY' USING ERRCODE='42501'; END IF;
  RETURN coalesce((
    SELECT jsonb_agg(jsonb_build_object(
      'booking_id',b.id,'customer_id',b.customer_user_id,'amount_paise',m.amount_paise,
      'payment_status',m.payment_status,'refund_request_status',r.status,
      'technician_evidence',(SELECT jsonb_agg(jsonb_build_object(
        'evidence_id',e.id,'technician_id',e.technician_id,'amount_paise',e.amount_paise,
        'refund_reference',e.refund_reference,'evidence_uri',e.evidence_uri,
        'evidence_note',e.evidence_note,'status',coalesce((SELECT rv.decision FROM public.srk_master_cash_refund_reviews rv WHERE rv.evidence_id=e.id),'submitted'),'submitted_at',e.submitted_at
      ) ORDER BY e.submitted_at) FROM public.srk_master_cash_refund_evidence e WHERE e.booking_id=b.id)
    ) ORDER BY b.created_at DESC)
    FROM public.service_bookings b
    JOIN public.srk_master_booking_payments m ON m.booking_id=b.id
    LEFT JOIN public.srk_booking_refund_requests r ON r.booking_id=b.id
    WHERE m.payment_method='cash' AND (r.status IN ('approved','processed')
      OR EXISTS(SELECT 1 FROM public.srk_master_cash_refund_evidence e WHERE e.booking_id=b.id))
  ),'[]'::jsonb);
END;
$$;
REVOKE ALL ON FUNCTION public.srk_admin_list_master_cash_refunds() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.srk_admin_list_master_cash_refunds() TO authenticated;

COMMENT ON TABLE public.srk_master_cash_refund_evidence IS
 'Per-Technician evidence that cash was returned directly to the Customer; Admin finalization alone marks the Master booking refunded.';
COMMENT ON TABLE public.srk_master_technician_wallet_credits IS
 'Append-only source credits for commission already recovered from a Technician before a cash-booking refund. Payout integration is handled by a follow-up migration.';
