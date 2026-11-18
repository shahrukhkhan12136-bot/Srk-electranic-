-- Align the payout-ledger trigger's manual-payment evidence with the
-- authoritative payment-verification rule (booking + amount + payment method).
-- SOURCE ONLY: do not apply to any database without explicit authorization.
-- No historical bookings, bills, payment entries or payout rows are modified.

CREATE OR REPLACE FUNCTION public.srk_create_electrician_payable()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, pg_temp
AS $$
DECLARE
  v_service numeric(12,2);
  v_materials numeric(12,2);
  v_rate numeric(7,2);
  v_commission numeric(12,2);
  v_bill public.srk_booking_labour_bills%rowtype;
BEGIN
  IF NEW.payment_status = 'paid'
     AND NEW.status = 'completed'
     AND NEW.assigned_electrician_id IS NOT NULL
     AND NEW.payment_verified_at IS NOT NULL
     AND (
       NEW.razorpay_payment_id IS NOT NULL
       OR EXISTS (
         SELECT 1
           FROM public.srk_manual_payment_entries e
          WHERE e.booking_id = NEW.id
            AND round(coalesce(e.amount,0),2) = round(coalesce(NEW.amount_paid,0),2)
            AND e.payment_method IS NOT NULL
            AND NEW.payment_method IS NOT NULL
            AND lower(btrim(e.payment_method)) = lower(btrim(NEW.payment_method))
       )
     ) THEN

    IF NEW.selected_category IS NOT NULL THEN
      SELECT * INTO v_bill
        FROM public.srk_booking_labour_bills
       WHERE booking_id = NEW.id;

      IF NOT FOUND
         OR v_bill.electrician_profile_id IS DISTINCT FROM NEW.assigned_electrician_id
         OR v_bill.labour_amount <= 0 THEN
        RAISE EXCEPTION 'IMMUTABLE_LABOUR_BILL_OR_ELECTRICIAN_ASSIGNMENT_MISMATCH';
      END IF;

      -- Customer collection includes settled cancellation fees; those fees
      -- remain SRK-owned and are excluded from electrician earnings.
      IF round(coalesce(NEW.amount_paid,0),2) <>
         round(v_bill.labour_amount + coalesce((
           SELECT sum(i.amount_paise)::numeric / 100
             FROM public.srk_booking_cancellation_fee_items i
            WHERE i.booking_id = NEW.id AND i.status IN ('reserved','settled')
         ),0),2) THEN
        RAISE EXCEPTION 'VERIFIED_PAYMENT_DOES_NOT_MATCH_LABOUR_AND_SETTLED_FEES';
      END IF;

      v_service := round(v_bill.labour_amount,2);
      v_materials := 0;
      v_rate := NEW.commission_rate;
    ELSE
      -- Preserve the established legacy approved-quote payout calculation.
      IF NEW.quote_status <> 'approved' THEN
        RETURN NEW;
      END IF;
      v_service := round(coalesce(NEW.service_charge,0),2);
      v_materials := round(coalesce(NEW.materials_amount,0),2);
      v_rate := NEW.commission_rate;
      IF round(coalesce(NEW.amount_paid,0),2) <>
         round(v_service + v_materials,2) THEN
        RAISE EXCEPTION 'VERIFIED_PAYMENT_DOES_NOT_MATCH_APPROVED_QUOTE_TOTAL';
      END IF;
    END IF;

    IF v_rate IS NULL OR v_rate < 0 OR v_rate > 100 THEN
      RAISE EXCEPTION 'COMMISSION_RATE_MUST_BE_BETWEEN_0_AND_100';
    END IF;

    v_commission := round(v_service * v_rate / 100,2);

    INSERT INTO public.srk_electrician_payouts (
      booking_id,electrician_profile_id,razorpay_payment_id,
      gross_service_amount,materials_amount,platform_commission,
      electrician_payable,payout_status
    ) VALUES (
      NEW.id,NEW.assigned_electrician_id,NEW.razorpay_payment_id,
      v_service,v_materials,v_commission,
      round(v_service + v_materials - v_commission,2),'pending'
    )
    ON CONFLICT (booking_id) DO UPDATE SET
      electrician_profile_id = EXCLUDED.electrician_profile_id,
      razorpay_payment_id = EXCLUDED.razorpay_payment_id,
      gross_service_amount = EXCLUDED.gross_service_amount,
      materials_amount = EXCLUDED.materials_amount,
      platform_commission = EXCLUDED.platform_commission,
      electrician_payable = EXCLUDED.electrician_payable,
      updated_at = now()
    WHERE public.srk_electrician_payouts.payout_status = 'pending';

  ELSIF NEW.payment_status = 'refunded' THEN
    -- Close only refund-owned holds; preserve unrelated Admin blocks and paid payouts.
    UPDATE public.srk_electrician_payouts
       SET payout_status = 'refunded',
           payout_note = NULL,
           updated_at = now()
     WHERE booking_id = NEW.id
       AND (
         payout_status = 'pending'
         OR (
           payout_status = 'blocked'
           AND payout_note IN ('Razorpay refund pending','Manual refund processed')
         )
       );
  END IF;

  RETURN NEW;
END;
$$;

-- CREATE OR REPLACE preserves the existing trigger attachment and function ACL.
