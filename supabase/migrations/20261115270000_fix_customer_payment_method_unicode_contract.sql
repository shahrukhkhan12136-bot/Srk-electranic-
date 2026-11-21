-- Repair the payment-method RPC's corrupted Unicode literal.
-- The Customer Portal sends this exact UTF-8 value; keep the stored value canonical.
CREATE OR REPLACE FUNCTION public.srk_customer_change_payment_method(
  p_booking_id uuid,
  p_payment_method text
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_updated_id uuid;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'AUTHENTICATION_REQUIRED' USING errcode='28000';
  END IF;

  IF p_booking_id IS NULL
     OR p_payment_method IS DISTINCT FROM 'Razorpay ऑनलाइन भुगतान' THEN
    RAISE EXCEPTION 'INVALID_PAYMENT_METHOD_CHANGE' USING errcode='22023';
  END IF;

  UPDATE public.service_bookings
     SET payment_method='Razorpay ऑनलाइन भुगतान'
   WHERE id=p_booking_id
     AND customer_user_id=v_uid
     AND status IN ('new','confirmed')
     AND assigned_electrician_id IS NULL
     AND payment_status NOT IN ('paid','refunded')
     AND coalesce(amount_paid,0)=0
     AND razorpay_order_id IS NULL
     AND razorpay_payment_id IS NULL
     AND lower(coalesce(payment_method,'')) LIKE '%cash%'
  RETURNING id INTO v_updated_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'PAYMENT_METHOD_CHANGE_NOT_ALLOWED' USING errcode='42501';
  END IF;

  RETURN true;
END;
$function$;

REVOKE ALL ON FUNCTION public.srk_customer_change_payment_method(uuid,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.srk_customer_change_payment_method(uuid,text) TO authenticated;

COMMENT ON FUNCTION public.srk_customer_change_payment_method(uuid,text) IS
  'Allows the booking owner to switch only an unassigned, unpaid new/confirmed cash booking to Razorpay preference. No payment is collected.';
