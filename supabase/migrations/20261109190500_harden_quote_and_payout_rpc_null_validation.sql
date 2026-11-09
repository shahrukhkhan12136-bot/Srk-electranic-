-- Harden NULL handling in customer quote response and admin payout RPCs.
-- Prepared only on predeploy/verified-electrician-booking-match; not applied to Supabase.

CREATE OR REPLACE FUNCTION public.srk_customer_respond_booking_quote(
  p_booking_id uuid,
  p_response text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'public', 'auth', 'pg_temp'
AS $function$
DECLARE
  v_booking public.service_bookings%rowtype;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING errcode = '42501';
  END IF;

  IF p_booking_id IS NULL OR p_response IS NULL
     OR p_response NOT IN ('approved', 'rejected') THEN
    RAISE EXCEPTION 'Invalid quote response';
  END IF;

  SELECT *
    INTO v_booking
    FROM public.service_bookings
   WHERE id = p_booking_id
     AND customer_user_id = auth.uid()
   FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Customer booking not found';
  END IF;

  IF v_booking.status <> 'awaiting_quote_approval'
     OR v_booking.quote_status <> 'pending' THEN
    RAISE EXCEPTION 'No quote is waiting for approval';
  END IF;

  UPDATE public.service_bookings
     SET quote_status = p_response,
         quote_responded_at = now(),
         status = CASE
           WHEN p_response = 'approved' THEN 'quote_approved'
           ELSE 'quote_rejected'
         END
   WHERE id = p_booking_id;

  RETURN jsonb_build_object('success', true, 'quote_status', p_response);
END;
$function$;

CREATE OR REPLACE FUNCTION public.srk_admin_mark_electrician_payout_paid(
  p_payout_id uuid,
  p_method text,
  p_reference text,
  p_note text DEFAULT NULL::text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'public', 'auth', 'pg_temp'
AS $function$
DECLARE
  v_row public.srk_electrician_payouts%rowtype;
BEGIN
  IF auth.uid() IS NULL OR NOT public.is_srk_admin() THEN
    RAISE EXCEPTION 'Admin access required' USING errcode = '42501';
  END IF;

  IF p_payout_id IS NULL
     OR p_method IS NULL
     OR p_method NOT IN ('upi', 'bank') THEN
    RAISE EXCEPTION 'Payout method must be upi or bank';
  END IF;

  IF p_reference IS NULL OR length(trim(p_reference)) < 4 THEN
    RAISE EXCEPTION 'Valid UTR / UPI reference is required';
  END IF;

  SELECT *
    INTO v_row
    FROM public.srk_electrician_payouts
   WHERE id = p_payout_id
   FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Payout record not found';
  END IF;

  IF v_row.payout_status <> 'pending' THEN
    RAISE EXCEPTION 'Only pending payouts can be marked paid';
  END IF;

  IF NOT EXISTS (
    SELECT 1
      FROM public.service_bookings b
     WHERE b.id = v_row.booking_id
       AND b.status = 'completed'
       AND b.quote_status = 'approved'
       AND b.payment_status = 'paid'
       AND b.payment_verified_at IS NOT NULL
       AND b.razorpay_payment_id = v_row.razorpay_payment_id
       AND b.assigned_electrician_id = v_row.electrician_profile_id
       AND round(coalesce(b.amount_paid, 0), 2) =
           round(coalesce(b.service_charge, 0) + coalesce(b.materials_amount, 0), 2)
       AND round(coalesce(v_row.gross_service_amount, 0), 2) =
           round(coalesce(b.service_charge, 0), 2)
       AND round(coalesce(v_row.materials_amount, 0), 2) =
           round(coalesce(b.materials_amount, 0), 2)
       AND round(coalesce(v_row.platform_commission, 0), 2) =
           round(coalesce(b.service_charge, 0) * b.commission_rate / 100, 2)
       AND round(coalesce(v_row.electrician_payable, 0), 2) =
           round(
             coalesce(b.service_charge, 0) + coalesce(b.materials_amount, 0)
             - round(coalesce(b.service_charge, 0) * b.commission_rate / 100, 2),
             2
           )
  ) THEN
    RAISE EXCEPTION 'Booking payment or payout ledger does not match verified booking; payout blocked';
  END IF;

  UPDATE public.srk_electrician_payouts
     SET payout_status = 'paid',
         payout_method = p_method,
         payout_reference = trim(p_reference),
         payout_note = nullif(trim(p_note), ''),
         paid_by = auth.uid(),
         paid_at = now(),
         updated_at = now()
   WHERE id = p_payout_id;

  RETURN jsonb_build_object('success', true, 'payout_id', p_payout_id, 'status', 'paid');
END;
$function$;
