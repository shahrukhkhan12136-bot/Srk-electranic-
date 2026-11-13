-- Manual/offline refund workflow for labour-only completed bookings.
-- Transfer evidence is durably stored BEFORE the booking refund/ledger transaction.
BEGIN;

CREATE TABLE IF NOT EXISTS public.srk_manual_refund_intents (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  request_id uuid NOT NULL UNIQUE REFERENCES public.srk_booking_refund_requests(id) ON DELETE RESTRICT,
  booking_id uuid NOT NULL UNIQUE REFERENCES public.service_bookings(id) ON DELETE RESTRICT,
  payment_entry_id uuid NOT NULL UNIQUE REFERENCES public.srk_manual_payment_entries(id) ON DELETE RESTRICT,
  amount_paise bigint NOT NULL CHECK (amount_paise > 0 AND amount_paise <= 1000000000),
  status text NOT NULL DEFAULT 'prepared'
    CHECK (status IN ('prepared','paid','processed','requires_reconciliation')),
  transfer_reference text CHECK (transfer_reference IS NULL OR length(btrim(transfer_reference)) BETWEEN 4 AND 120),
  transfer_note text CHECK (transfer_note IS NULL OR length(transfer_note) <= 500),
  previous_payout_note text,
  prepared_by uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
  recorded_by uuid REFERENCES auth.users(id) ON DELETE RESTRICT,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  paid_at timestamptz,
  processed_at timestamptz,
  last_error text
);
CREATE INDEX IF NOT EXISTS srk_manual_refund_intents_status_created_idx
  ON public.srk_manual_refund_intents(status,created_at DESC);
ALTER TABLE public.srk_manual_refund_intents ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.srk_manual_refund_intents FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION public.srk_admin_prepare_manual_booking_refund(p_request_id uuid)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'pg_catalog','public','auth','pg_temp'
AS $function$
DECLARE
  v_req public.srk_booking_refund_requests%ROWTYPE;
  v_booking public.service_bookings%ROWTYPE;
  v_bill public.srk_booking_labour_bills%ROWTYPE;
  v_payment public.srk_manual_payment_entries%ROWTYPE;
  v_payout public.srk_electrician_payouts%ROWTYPE;
  v_intent public.srk_manual_refund_intents%ROWTYPE;
  v_amount bigint;
  v_prev_note text;
BEGIN
  IF auth.uid() IS NULL OR NOT public.is_srk_admin() THEN
    RAISE EXCEPTION 'ADMIN_ACCESS_REQUIRED' USING ERRCODE='42501';
  END IF;
  SELECT * INTO v_req FROM public.srk_booking_refund_requests
   WHERE id=p_request_id FOR UPDATE;
  IF NOT FOUND OR v_req.status NOT IN ('approved','processing','unknown') THEN
    RAISE EXCEPTION 'APPROVED_REFUND_REQUEST_REQUIRED' USING ERRCODE='55000';
  END IF;
  SELECT * INTO v_booking FROM public.service_bookings
   WHERE id=v_req.booking_id FOR UPDATE;
  IF NOT FOUND OR v_booking.customer_user_id IS DISTINCT FROM v_req.customer_user_id
     OR v_booking.status<>'completed' OR v_booking.completion_approval_status<>'approved'
     OR v_booking.payment_status<>'paid' OR v_booking.payment_verified_at IS NULL
     OR v_booking.selected_category IS NULL THEN
    RAISE EXCEPTION 'COMPLETED_VERIFIED_LABOUR_BOOKING_REQUIRED' USING ERRCODE='55000';
  END IF;
  IF v_booking.razorpay_payment_id IS NOT NULL OR v_booking.razorpay_order_id IS NOT NULL THEN
    RAISE EXCEPTION 'RAZORPAY_PAYMENT_MUST_USE_RAZORPAY_REFUND_WORKFLOW' USING ERRCODE='55000';
  END IF;
  SELECT * INTO v_bill FROM public.srk_booking_labour_bills WHERE booking_id=v_booking.id;
  IF NOT FOUND OR v_bill.labour_amount_paise<=0
     OR v_bill.labour_amount_paise<>round(v_bill.labour_amount*100)::bigint
     OR round(coalesce(v_booking.amount_paid,0)*100)::bigint<>v_bill.labour_amount_paise
     OR round(v_req.amount*100)::bigint<>v_bill.labour_amount_paise THEN
    RAISE EXCEPTION 'REFUND_AMOUNT_MUST_MATCH_IMMUTABLE_LABOUR_BILL' USING ERRCODE='55000';
  END IF;
  v_amount:=v_bill.labour_amount_paise;
  SELECT * INTO v_payment FROM public.srk_manual_payment_entries
   WHERE booking_id=v_booking.id FOR UPDATE;
  IF NOT FOUND OR round(v_payment.amount*100)::bigint<>v_amount
     OR lower(v_payment.payment_method) NOT IN ('cash','upi','bank_transfer') THEN
    RAISE EXCEPTION 'VERIFIED_MANUAL_PAYMENT_ENTRY_REQUIRED' USING ERRCODE='55000';
  END IF;
  IF EXISTS (
    SELECT 1 FROM public.srk_manual_refund_entries
     WHERE booking_id=v_booking.id OR payment_entry_id=v_payment.id
  ) THEN RAISE EXCEPTION 'MANUAL_REFUND_ALREADY_RECORDED' USING ERRCODE='23505'; END IF;

  IF v_booking.assigned_electrician_id IS NOT NULL THEN
    PERFORM pg_catalog.pg_advisory_xact_lock(
      pg_catalog.hashtextextended(v_booking.assigned_electrician_id::text,0)
    );
  END IF;
  SELECT * INTO v_intent FROM public.srk_manual_refund_intents
   WHERE request_id=v_req.id FOR UPDATE;
  IF FOUND THEN
    IF v_intent.payment_entry_id<>v_payment.id OR v_intent.amount_paise<>v_amount THEN
      RAISE EXCEPTION 'EXISTING_MANUAL_REFUND_INTENT_MISMATCH' USING ERRCODE='55000';
    END IF;
    RETURN jsonb_build_object('success',true,'already_prepared',true,
      'intent_id',v_intent.id,'status',v_intent.status,'amount_paise',v_intent.amount_paise);
  END IF;

  SELECT * INTO v_payout FROM public.srk_electrician_payouts
   WHERE booking_id=v_booking.id FOR UPDATE;
  IF FOUND THEN
    IF v_payout.payout_status='paid' THEN
      RAISE EXCEPTION 'ELECTRICIAN_PAYOUT_ALREADY_PAID_ADMIN_RECONCILIATION_REQUIRED' USING ERRCODE='55000';
    END IF;
    IF v_payout.payout_status<>'pending' THEN
      RAISE EXCEPTION 'PAYOUT_STATE_REQUIRES_ADMIN_RECONCILIATION' USING ERRCODE='55000';
    END IF;
    v_prev_note:=v_payout.payout_note;
    UPDATE public.srk_electrician_payouts SET payout_status='blocked',
      payout_note='SRK_MANUAL_REFUND:'||v_booking.id::text,
      updated_at=clock_timestamp() WHERE id=v_payout.id;
  END IF;
  IF EXISTS (
    SELECT 1 FROM public.srk_platform_fee_ledger due_entry
    JOIN public.srk_platform_fee_ledger settlement
      ON settlement.electrician_profile_id=due_entry.electrician_profile_id
     AND settlement.entry_type='cash_due_settlement'
     AND settlement.created_at>due_entry.created_at
    WHERE due_entry.booking_id=v_booking.id AND due_entry.entry_type='cash_due'
  ) THEN
    RAISE EXCEPTION 'CASH_FEE_DUE_ALREADY_SETTLED_ADMIN_RECONCILIATION_REQUIRED' USING ERRCODE='55000';
  END IF;

  INSERT INTO public.srk_manual_refund_intents
    (request_id,booking_id,payment_entry_id,amount_paise,previous_payout_note,prepared_by)
  VALUES(v_req.id,v_booking.id,v_payment.id,v_amount,v_prev_note,auth.uid())
  RETURNING * INTO v_intent;
  RETURN jsonb_build_object('success',true,'intent_id',v_intent.id,
    'status',v_intent.status,'amount_paise',v_intent.amount_paise,
    'message','Manual refund prepared. Actual transfer must be performed outside SRK ELECTRONIC.');
END;
$function$;

CREATE OR REPLACE FUNCTION public.srk_admin_record_manual_refund_transfer(
  p_request_id uuid,p_transfer_reference text,p_note text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'pg_catalog','public','auth','pg_temp'
AS $function$
DECLARE
  v_intent public.srk_manual_refund_intents%ROWTYPE;
  v_req public.srk_booking_refund_requests%ROWTYPE;
  v_ref text:=btrim(coalesce(p_transfer_reference,''));
BEGIN
  IF auth.uid() IS NULL OR NOT public.is_srk_admin() THEN
    RAISE EXCEPTION 'ADMIN_ACCESS_REQUIRED' USING ERRCODE='42501';
  END IF;
  IF length(v_ref) NOT BETWEEN 4 AND 120 OR (p_note IS NOT NULL AND length(p_note)>500) THEN
    RAISE EXCEPTION 'VALID_TRANSFER_REFERENCE_AND_NOTE_REQUIRED' USING ERRCODE='22023';
  END IF;
  SELECT * INTO v_req FROM public.srk_booking_refund_requests
   WHERE id=p_request_id FOR UPDATE;
  IF NOT FOUND OR v_req.status NOT IN ('approved','processing','unknown') THEN
    RAISE EXCEPTION 'APPROVED_REFUND_REQUEST_REQUIRED' USING ERRCODE='55000';
  END IF;
  SELECT * INTO v_intent FROM public.srk_manual_refund_intents
   WHERE request_id=p_request_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'PREPARE_MANUAL_REFUND_FIRST' USING ERRCODE='55000'; END IF;
  IF v_intent.status='paid' OR v_intent.status='processed' THEN
    IF v_intent.transfer_reference IS DISTINCT FROM v_ref THEN
      RAISE EXCEPTION 'TRANSFER_REFERENCE_CONFLICT' USING ERRCODE='55000';
    END IF;
    RETURN jsonb_build_object('success',true,'already_recorded',true,
      'intent_id',v_intent.id,'status',v_intent.status);
  END IF;
  IF v_intent.status<>'prepared' THEN
    RAISE EXCEPTION 'MANUAL_REFUND_REQUIRES_RECONCILIATION' USING ERRCODE='55000';
  END IF;
  UPDATE public.srk_manual_refund_intents
     SET status='paid',transfer_reference=v_ref,transfer_note=nullif(btrim(p_note),''),
         recorded_by=auth.uid(),paid_at=clock_timestamp(),last_error=NULL
   WHERE id=v_intent.id;
  UPDATE public.srk_booking_refund_requests
     SET status='processing',updated_at=clock_timestamp()
   WHERE id=p_request_id;
  RETURN jsonb_build_object('success',true,'intent_id',v_intent.id,
    'status','paid','amount_paise',v_intent.amount_paise,
    'message','Transfer evidence durably recorded; booking/ledger finalization is a separate step.');
END;
$function$;

CREATE OR REPLACE FUNCTION public.srk_admin_finalize_manual_booking_refund(p_request_id uuid)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'pg_catalog','public','auth','pg_temp'
AS $function$
DECLARE
  v_req public.srk_booking_refund_requests%ROWTYPE;
  v_intent public.srk_manual_refund_intents%ROWTYPE;
  v_booking public.service_bookings%ROWTYPE;
  v_bill public.srk_booking_labour_bills%ROWTYPE;
  v_payout public.srk_electrician_payouts%ROWTYPE;
BEGIN
  IF auth.uid() IS NULL OR NOT public.is_srk_admin() THEN
    RAISE EXCEPTION 'ADMIN_ACCESS_REQUIRED' USING ERRCODE='42501';
  END IF;
  SELECT * INTO v_req FROM public.srk_booking_refund_requests
   WHERE id=p_request_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'REFUND_REQUEST_NOT_FOUND' USING ERRCODE='P0002'; END IF;
  SELECT * INTO v_intent FROM public.srk_manual_refund_intents
   WHERE request_id=p_request_id FOR UPDATE;
  IF NOT FOUND OR v_intent.status NOT IN ('paid','processed') THEN
    RAISE EXCEPTION 'MANUAL_REFUND_TRANSFER_MUST_BE_RECORDED_FIRST' USING ERRCODE='55000';
  END IF;
  SELECT * INTO v_booking FROM public.service_bookings
   WHERE id=v_intent.booking_id FOR UPDATE;
  IF NOT FOUND OR v_booking.razorpay_payment_id IS NOT NULL
     OR v_booking.razorpay_order_id IS NOT NULL
     OR v_booking.payment_status NOT IN ('paid','refunded') THEN
    RAISE EXCEPTION 'MANUAL_REFUND_BOOKING_PAYMENT_STATE_MISMATCH' USING ERRCODE='55000';
  END IF;
  SELECT * INTO v_bill FROM public.srk_booking_labour_bills WHERE booking_id=v_booking.id;
  IF NOT FOUND OR v_bill.labour_amount_paise<>v_intent.amount_paise
     OR round(coalesce(v_booking.amount_paid,0)*100)::bigint<>v_intent.amount_paise THEN
    RAISE EXCEPTION 'MANUAL_REFUND_LABOUR_BILL_CHANGED' USING ERRCODE='55000';
  END IF;
  IF v_booking.assigned_electrician_id IS NOT NULL THEN
    PERFORM pg_catalog.pg_advisory_xact_lock(
      pg_catalog.hashtextextended(v_booking.assigned_electrician_id::text,0)
    );
  END IF;
  SELECT * INTO v_payout FROM public.srk_electrician_payouts
   WHERE booking_id=v_booking.id FOR UPDATE;
  IF FOUND THEN
    IF v_payout.payout_status='paid' THEN
      UPDATE public.srk_manual_refund_intents SET status='requires_reconciliation',
        last_error='Electrician payout is already paid; refund/ledger requires manual reconciliation.',
        updated_at=clock_timestamp() WHERE id=v_intent.id;
      UPDATE public.srk_booking_refund_requests SET status='unknown',updated_at=clock_timestamp()
       WHERE id=v_req.id;
      RETURN jsonb_build_object('success',false,'requires_reconciliation',true,
        'status','requires_reconciliation','reason','ELECTRICIAN_PAYOUT_ALREADY_PAID');
    END IF;
    IF v_payout.payout_status<>'blocked'
       OR v_payout.payout_note IS DISTINCT FROM 'SRK_MANUAL_REFUND:'||v_booking.id::text THEN
      UPDATE public.srk_manual_refund_intents SET status='requires_reconciliation',
        last_error='Payout block marker changed; Admin reconciliation required.',
        updated_at=clock_timestamp() WHERE id=v_intent.id;
      UPDATE public.srk_booking_refund_requests SET status='unknown',updated_at=clock_timestamp()
       WHERE id=v_req.id;
      RETURN jsonb_build_object('success',false,'requires_reconciliation',true,
        'status','requires_reconciliation','reason','PAYOUT_BLOCK_MARKER_MISMATCH');
    END IF;
    -- Restore only the pending state that this refund preparation itself blocked.
    UPDATE public.srk_electrician_payouts
       SET payout_status='pending',payout_note=v_intent.previous_payout_note,
           updated_at=clock_timestamp()
     WHERE id=v_payout.id;
  END IF;

  IF v_booking.payment_status<>'refunded' THEN
    UPDATE public.service_bookings SET payment_status='refunded' WHERE id=v_booking.id;
  END IF;
  INSERT INTO public.srk_manual_refund_entries
    (booking_id,payment_entry_id,amount,refund_reference,note,recorded_by)
  VALUES(v_intent.booking_id,v_intent.payment_entry_id,
    v_intent.amount_paise::numeric/100,v_intent.transfer_reference,
    left(coalesce(v_intent.transfer_note,'Manual labour-only refund'),250),v_intent.recorded_by)
  ON CONFLICT (booking_id) DO NOTHING;
  UPDATE public.srk_manual_refund_intents
     SET status='processed',processed_at=coalesce(processed_at,clock_timestamp()),
         updated_at=clock_timestamp(),last_error=NULL
   WHERE id=v_intent.id;
  UPDATE public.srk_booking_refund_requests
     SET status='processed',processed_at=coalesce(processed_at,clock_timestamp()),
         updated_at=clock_timestamp()
   WHERE id=v_req.id;
  RETURN jsonb_build_object('success',true,'status','processed',
    'intent_id',v_intent.id,'amount_paise',v_intent.amount_paise);
END;
$function$;

CREATE OR REPLACE FUNCTION public.srk_admin_list_booking_refund_requests_v2()
RETURNS TABLE (
  request_id uuid,booking_id uuid,customer_user_id uuid,customer_name text,
  customer_phone text,refund_amount numeric,reason text,request_status text,
  admin_note text,payment_method text,payment_status text,razorpay_payment_id text,
  labour_amount numeric,labour_amount_paise bigint,manual_refund_status text,
  manual_refund_reference text,manual_refund_amount_paise bigint,
  created_at timestamptz,updated_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path TO 'pg_catalog','public','auth','pg_temp'
AS $function$
BEGIN
  IF auth.uid() IS NULL OR NOT public.is_srk_admin() THEN
    RAISE EXCEPTION 'ADMIN_ACCESS_REQUIRED' USING ERRCODE='42501';
  END IF;
  RETURN QUERY
  SELECT r.id,r.booking_id,r.customer_user_id,b.customer_name::text,b.phone::text,
    r.amount,r.reason,r.status,r.admin_note,b.payment_method::text,b.payment_status::text,
    b.razorpay_payment_id::text,bill.labour_amount,bill.labour_amount_paise,
    mi.status,mi.transfer_reference,mi.amount_paise,r.created_at,r.updated_at
  FROM public.srk_booking_refund_requests r
  JOIN public.service_bookings b ON b.id=r.booking_id
  LEFT JOIN public.srk_booking_labour_bills bill ON bill.booking_id=r.booking_id
  LEFT JOIN public.srk_manual_refund_intents mi ON mi.request_id=r.id
  ORDER BY CASE r.status WHEN 'requested' THEN 0 WHEN 'in_review' THEN 1
    WHEN 'unknown' THEN 2 WHEN 'processing' THEN 3 ELSE 4 END,r.created_at ASC
  LIMIT 300;
END;
$function$;

REVOKE ALL ON FUNCTION public.srk_admin_prepare_manual_booking_refund(uuid) FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.srk_admin_record_manual_refund_transfer(uuid,text,text) FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.srk_admin_finalize_manual_booking_refund(uuid) FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.srk_admin_list_booking_refund_requests_v2() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.srk_admin_prepare_manual_booking_refund(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.srk_admin_record_manual_refund_transfer(uuid,text,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.srk_admin_finalize_manual_booking_refund(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.srk_admin_list_booking_refund_requests_v2() TO authenticated;

COMMIT;
