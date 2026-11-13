-- Reproducible refund foundation for timer-based labour-only bookings.
-- Source-only until separately approved for database application.
BEGIN;

CREATE TABLE IF NOT EXISTS public.srk_razorpay_refunds (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_id uuid NOT NULL REFERENCES public.service_bookings(id) ON DELETE RESTRICT,
  payment_id text NOT NULL CHECK (payment_id ~ '^pay_[A-Za-z0-9]+$'),
  refund_id text UNIQUE CHECK (refund_id IS NULL OR refund_id ~ '^rfnd_[A-Za-z0-9]+$'),
  amount numeric(12,2) NOT NULL CHECK (amount > 0 AND amount <= 10000000),
  amount_paise bigint NOT NULL CHECK (amount_paise > 0 AND amount_paise <= 1000000000),
  currency text NOT NULL DEFAULT 'INR' CHECK (currency = 'INR'),
  idempotency_key text NOT NULL UNIQUE CHECK (length(idempotency_key) BETWEEN 10 AND 36),
  status text NOT NULL DEFAULT 'requested'
    CHECK (status IN ('requested','processing','unknown','processed','failed')),
  provider_status text,
  reason text NOT NULL CHECK (length(reason) BETWEEN 20 AND 250),
  admin_user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
  previous_payout_note text,
  last_error text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  processed_at timestamptz,
  CONSTRAINT srk_razorpay_refunds_amount_paise_match
    CHECK (amount_paise = round(amount * 100)::bigint)
);
CREATE UNIQUE INDEX IF NOT EXISTS srk_razorpay_refunds_booking_id_key
  ON public.srk_razorpay_refunds(booking_id);

CREATE TABLE IF NOT EXISTS public.srk_manual_refund_entries (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_id uuid NOT NULL REFERENCES public.service_bookings(id) ON DELETE RESTRICT,
  payment_entry_id uuid NOT NULL REFERENCES public.srk_manual_payment_entries(id) ON DELETE RESTRICT,
  amount numeric(12,2) NOT NULL CHECK (amount > 0 AND amount <= 10000000),
  refund_reference text NOT NULL CHECK (length(btrim(refund_reference)) BETWEEN 4 AND 120),
  note text CHECK (note IS NULL OR length(note) <= 250),
  recorded_by uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
  recorded_at timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX IF NOT EXISTS srk_manual_refund_entries_booking_id_key
  ON public.srk_manual_refund_entries(booking_id);
CREATE UNIQUE INDEX IF NOT EXISTS srk_manual_refund_entries_payment_entry_id_key
  ON public.srk_manual_refund_entries(payment_entry_id);

CREATE TABLE IF NOT EXISTS public.srk_booking_refund_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_id uuid NOT NULL REFERENCES public.service_bookings(id) ON DELETE RESTRICT,
  customer_user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
  amount numeric(12,2) NOT NULL CHECK (amount > 0 AND amount <= 10000000),
  reason text NOT NULL CHECK (length(btrim(reason)) BETWEEN 20 AND 1000),
  status text NOT NULL DEFAULT 'requested'
    CHECK (status IN ('requested','in_review','approved','rejected','processing','unknown','processed')),
  admin_note text CHECK (admin_note IS NULL OR length(admin_note) <= 2000),
  refund_record_id uuid UNIQUE REFERENCES public.srk_razorpay_refunds(id) ON DELETE RESTRICT,
  decided_by uuid REFERENCES auth.users(id) ON DELETE RESTRICT,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  processed_at timestamptz,
  CONSTRAINT srk_booking_refund_requests_one_per_booking UNIQUE (booking_id)
);

CREATE INDEX IF NOT EXISTS srk_booking_refund_requests_customer_created_idx
  ON public.srk_booking_refund_requests(customer_user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS srk_booking_refund_requests_status_created_idx
  ON public.srk_booking_refund_requests(status, created_at DESC);

ALTER TABLE public.srk_razorpay_refunds ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.srk_manual_refund_entries ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.srk_booking_refund_requests ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.srk_razorpay_refunds, public.srk_manual_refund_entries,
  public.srk_booking_refund_requests FROM PUBLIC, anon, authenticated;

-- Customer can request a refund only after completed work and an approved immutable
-- labour bill. Materials are excluded. Legacy quote-only bookings require Admin review.
CREATE OR REPLACE FUNCTION public.srk_customer_create_booking_refund_request(
  p_booking_id uuid,
  p_reason text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'pg_catalog','public','auth','pg_temp'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_booking public.service_bookings%ROWTYPE;
  v_bill public.srk_booking_labour_bills%ROWTYPE;
  v_request public.srk_booking_refund_requests%ROWTYPE;
  v_manual_payment public.srk_manual_payment_entries%ROWTYPE;
  v_amount numeric(12,2);
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'AUTHENTICATION_REQUIRED' USING ERRCODE='28000';
  END IF;
  IF p_booking_id IS NULL OR p_reason IS NULL
     OR length(btrim(p_reason)) NOT BETWEEN 20 AND 1000 THEN
    RAISE EXCEPTION 'REFUND_REASON_MUST_BE_20_TO_1000_CHARACTERS' USING ERRCODE='22023';
  END IF;

  SELECT * INTO v_booking
  FROM public.service_bookings
  WHERE id=p_booking_id AND customer_user_id=v_uid
  FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'BOOKING_NOT_FOUND_OR_NOT_OWNED' USING ERRCODE='42501';
  END IF;
  IF v_booking.status <> 'completed'
     OR v_booking.payment_status <> 'paid'
     OR v_booking.payment_verified_at IS NULL
     OR v_booking.completion_approval_status <> 'approved'
     OR v_booking.selected_category IS NULL THEN
    RAISE EXCEPTION 'COMPLETED_APPROVED_LABOUR_BOOKING_REQUIRED' USING ERRCODE='55000';
  END IF;

  SELECT * INTO v_bill
  FROM public.srk_booking_labour_bills
  WHERE booking_id=p_booking_id;
  IF NOT FOUND OR v_bill.labour_amount_paise <= 0
     OR v_bill.labour_amount_paise > 1000000000
     OR v_bill.labour_amount_paise <> round(v_bill.labour_amount * 100)::numeric
     OR round(coalesce(v_booking.amount_paid,0) * 100)::bigint <> v_bill.labour_amount_paise THEN
    RAISE EXCEPTION 'PAID_AMOUNT_DOES_NOT_MATCH_IMMUTABLE_LABOUR_BILL' USING ERRCODE='55000';
  END IF;
  v_amount := v_bill.labour_amount_paise::numeric / 100;

  IF v_booking.razorpay_payment_id IS NOT NULL THEN
    IF v_booking.razorpay_payment_id !~ '^pay_[A-Za-z0-9]+$'
       OR v_booking.razorpay_order_id IS NULL THEN
      RAISE EXCEPTION 'VERIFIED_RAZORPAY_PAYMENT_REQUIRED' USING ERRCODE='55000';
    END IF;
  ELSE
    IF v_booking.razorpay_order_id IS NOT NULL THEN
      RAISE EXCEPTION 'PAYMENT_CHANNEL_REQUIRES_ADMIN_RECONCILIATION' USING ERRCODE='55000';
    END IF;
    SELECT * INTO v_manual_payment
    FROM public.srk_manual_payment_entries
    WHERE booking_id=p_booking_id
    FOR UPDATE;
    IF NOT FOUND OR round(v_manual_payment.amount * 100)::bigint <> v_bill.labour_amount_paise THEN
      RAISE EXCEPTION 'MANUAL_PAYMENT_DOES_NOT_MATCH_IMMUTABLE_LABOUR_BILL' USING ERRCODE='55000';
    END IF;
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.srk_razorpay_refunds
    WHERE booking_id=p_booking_id AND status IN ('requested','processing','unknown','processed')
  ) OR EXISTS (
    SELECT 1 FROM public.srk_manual_refund_entries WHERE booking_id=p_booking_id
  ) THEN
    RAISE EXCEPTION 'REFUND_ALREADY_EXISTS_FOR_BOOKING' USING ERRCODE='23505';
  END IF;

  SELECT * INTO v_request
  FROM public.srk_booking_refund_requests
  WHERE booking_id=p_booking_id
  FOR UPDATE;
  IF FOUND THEN
    IF v_request.status <> 'rejected' THEN
      RAISE EXCEPTION 'REFUND_REQUEST_ALREADY_SUBMITTED' USING ERRCODE='23505';
    END IF;
    UPDATE public.srk_booking_refund_requests
    SET customer_user_id=v_uid,
        amount=v_amount,
        reason=btrim(p_reason),
        status='requested',
        admin_note=NULL,
        refund_record_id=NULL,
        decided_by=NULL,
        processed_at=NULL,
        updated_at=clock_timestamp()
    WHERE id=v_request.id
    RETURNING * INTO v_request;
  ELSE
    INSERT INTO public.srk_booking_refund_requests
      (booking_id,customer_user_id,amount,reason)
    VALUES (p_booking_id,v_uid,v_amount,btrim(p_reason))
    RETURNING * INTO v_request;
  END IF;

  RETURN jsonb_build_object(
    'success',true,
    'request_id',v_request.id,
    'amount',v_request.amount,
    'status',v_request.status
  );
END;
$function$;

REVOKE ALL ON FUNCTION public.srk_customer_create_booking_refund_request(uuid,text)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.srk_customer_create_booking_refund_request(uuid,text)
  TO authenticated;

COMMIT;
