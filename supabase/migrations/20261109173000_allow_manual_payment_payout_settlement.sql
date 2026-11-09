-- Allow verified manual Cash/UPI/Bank payments to settle electrician payout records.
-- Razorpay-backed payouts still require an exact Razorpay payment ID match.
-- Manual payouts require both booking and payout Razorpay IDs to be NULL plus
-- a matching verified manual-payment ledger entry.

CREATE OR REPLACE FUNCTION public.srk_admin_mark_electrician_payout_paid(
  p_payout_id uuid,
  p_method text,
  p_reference text,
  p_note text DEFAULT NULL
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
  IF p_method IS NULL OR p_method NOT IN ('upi','bank') THEN
    RAISE EXCEPTION 'Payout method must be upi or bank';
  END IF;
  IF p_reference IS NULL OR pg_catalog.length(pg_catalog.btrim(p_reference)) < 4 THEN
    RAISE EXCEPTION 'Valid UTR / UPI reference is required';
  END IF;

  SELECT * INTO v_row
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
       AND (
         (
           v_row.razorpay_payment_id IS NOT NULL
           AND b.razorpay_payment_id = v_row.razorpay_payment_id
         )
         OR
         (
           v_row.razorpay_payment_id IS NULL
           AND b.razorpay_payment_id IS NULL
           AND EXISTS (
             SELECT 1
               FROM public.srk_manual_payment_entries e
              WHERE e.booking_id = b.id
                AND pg_catalog.round(pg_catalog.coalesce(e.amount,0),2) =
                    pg_catalog.round(pg_catalog.coalesce(b.amount_paid,0),2)
           )
         )
       )
       AND b.assigned_electrician_id = v_row.electrician_profile_id
       AND pg_catalog.round(pg_catalog.coalesce(b.amount_paid,0),2) =
           pg_catalog.round(pg_catalog.coalesce(b.service_charge,0) + pg_catalog.coalesce(b.materials_amount,0),2)
       AND pg_catalog.round(pg_catalog.coalesce(v_row.gross_service_amount,0),2) =
           pg_catalog.round(pg_catalog.coalesce(b.service_charge,0),2)
       AND pg_catalog.round(pg_catalog.coalesce(v_row.materials_amount,0),2) =
           pg_catalog.round(pg_catalog.coalesce(b.materials_amount,0),2)
       AND pg_catalog.round(pg_catalog.coalesce(v_row.platform_commission,0),2) =
           pg_catalog.round(pg_catalog.coalesce(b.service_charge,0) * b.commission_rate / 100,2)
       AND pg_catalog.round(pg_catalog.coalesce(v_row.electrician_payable,0),2) =
           pg_catalog.round(pg_catalog.coalesce(b.service_charge,0) + pg_catalog.coalesce(b.materials_amount,0)
             - pg_catalog.round(pg_catalog.coalesce(b.service_charge,0) * b.commission_rate / 100,2),2)
  ) THEN
    RAISE EXCEPTION 'Booking payment or payout ledger does not match verified booking; payout blocked';
  END IF;

  UPDATE public.srk_electrician_payouts
     SET payout_status = 'paid',
         payout_method = p_method,
         payout_reference = pg_catalog.btrim(p_reference),
         payout_note = pg_catalog.nullif(pg_catalog.btrim(p_note),''),
         paid_by = auth.uid(),
         paid_at = pg_catalog.now(),
         updated_at = pg_catalog.now()
   WHERE id = p_payout_id;
  RETURN pg_catalog.jsonb_build_object('success', true, 'payout_id', p_payout_id, 'status', 'paid');
END;
$function$;