-- Align offer display to the direct 85% rate-list rule and separate
-- customer payment verification from payout-ledger reconciliation.
-- SOURCE ONLY: do not apply to any database without explicit authorization.
-- Existing booking snapshots, immutable labour bills, commission rules and
-- payout-ledger rows are read-only in this migration.
BEGIN;

DROP FUNCTION IF EXISTS public.srk_get_my_offer_details();
CREATE FUNCTION public.srk_get_my_offer_details()
RETURNS TABLE(
  offer_id uuid,
  offer_status text,
  match_level text,
  offer_created_at timestamptz,
  offer_expires_at timestamptz,
  booking_id uuid,
  service_type text,
  state text,
  district text,
  pincode text,
  work_details text,
  quoted_amount numeric,
  booking_status text,
  selected_category text,
  selected_rate_tier text,
  selected_duration_hours smallint,
  estimate_rate_card_version text,
  electrician_offer_paise bigint,
  work_start_approval_status text,
  completion_approval_status text,
  customer_name text,
  customer_phone text,
  address text,
  location_lat double precision,
  location_lng double precision,
  service_charge numeric,
  materials_amount numeric,
  quote_status text,
  quote_note text
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO 'pg_catalog','public','auth','pg_temp'
AS $function$
  SELECT
    o.id, o.status, o.match_level, o.created_at, o.expires_at,
    b.id, b.service_type, b.state, b.district, b.pincode, b.work_details,
    CASE WHEN b.status='completed' AND ((
      b.payment_status='paid' AND b.payment_verified_at IS NOT NULL
      AND b.amount_paid>0 AND (
        b.razorpay_payment_id IS NOT NULL OR EXISTS (
          SELECT 1 FROM public.srk_manual_payment_entries e
          WHERE e.booking_id=b.id
            AND round(e.amount,2)=round(b.amount_paid,2)
            AND lower(btrim(e.payment_method))=lower(btrim(b.payment_method))
        )
      )
    ) OR (b.razorpay_order_id IS NOT NULL AND b.payment_status='pending'))
      THEN b.quoted_amount ELSE NULL END,
    b.status, b.selected_category, b.selected_rate_tier, b.selected_duration_hours,
    b.estimate_rate_card_version,
    CASE
      WHEN b.selected_category IS NOT NULL AND b.selected_rate_tier IS NOT NULL
       AND b.selected_duration_hours BETWEEN 1 AND 8
       AND b.estimate_rate_card_version IS NOT NULL AND b.estimated_labour_paise>0
      THEN floor((b.estimated_labour_paise::numeric*8500/10000)+0.5)::bigint
      ELSE NULL
    END,
    b.work_start_approval_status, b.completion_approval_status,
    CASE WHEN b.assigned_electrician_id=p.id AND b.status IN (
      'assigned','inspection','awaiting_quote_approval','quote_approved',
      'quote_rejected','awaiting_work_start_approval','in_progress','completed','cancelled'
    ) THEN b.customer_name ELSE NULL END,
    CASE WHEN b.assigned_electrician_id=p.id AND b.status IN (
      'assigned','inspection','awaiting_quote_approval','quote_approved',
      'quote_rejected','awaiting_work_start_approval','in_progress','completed','cancelled'
    ) THEN b.phone ELSE NULL END,
    CASE WHEN b.assigned_electrician_id=p.id AND b.status IN (
      'assigned','inspection','awaiting_quote_approval','quote_approved',
      'quote_rejected','awaiting_work_start_approval','in_progress','completed','cancelled'
    ) THEN b.address ELSE NULL END,
    CASE WHEN b.assigned_electrician_id=p.id AND b.status IN (
      'assigned','inspection','awaiting_quote_approval','quote_approved',
      'quote_rejected','awaiting_work_start_approval','in_progress','completed','cancelled'
    ) THEN b.location_lat ELSE NULL END,
    CASE WHEN b.assigned_electrician_id=p.id AND b.status IN (
      'assigned','inspection','awaiting_quote_approval','quote_approved',
      'quote_rejected','awaiting_work_start_approval','in_progress','completed','cancelled'
    ) THEN b.location_lng ELSE NULL END,
    CASE WHEN b.status='completed' AND ((b.razorpay_order_id IS NOT NULL AND b.payment_status='pending') OR (
      b.payment_status='paid' AND b.payment_verified_at IS NOT NULL AND b.amount_paid>0
      AND (b.razorpay_payment_id IS NOT NULL OR EXISTS (
        SELECT 1 FROM public.srk_manual_payment_entries e
        WHERE e.booking_id=b.id AND round(e.amount,2)=round(b.amount_paid,2)
          AND lower(btrim(e.payment_method))=lower(btrim(b.payment_method))
      ))
    )) THEN b.service_charge ELSE NULL END,
    CASE WHEN b.status='completed' AND ((b.razorpay_order_id IS NOT NULL AND b.payment_status='pending') OR (
      b.payment_status='paid' AND b.payment_verified_at IS NOT NULL AND b.amount_paid>0
      AND (b.razorpay_payment_id IS NOT NULL OR EXISTS (
        SELECT 1 FROM public.srk_manual_payment_entries e
        WHERE e.booking_id=b.id AND round(e.amount,2)=round(b.amount_paid,2)
          AND lower(btrim(e.payment_method))=lower(btrim(b.payment_method))
      ))
    )) THEN b.materials_amount ELSE NULL END,
    CASE WHEN b.status='completed' AND ((b.razorpay_order_id IS NOT NULL AND b.payment_status='pending') OR (
      b.payment_status='paid' AND b.payment_verified_at IS NOT NULL AND b.amount_paid>0
      AND (b.razorpay_payment_id IS NOT NULL OR EXISTS (
        SELECT 1 FROM public.srk_manual_payment_entries e
        WHERE e.booking_id=b.id AND round(e.amount,2)=round(b.amount_paid,2)
          AND lower(btrim(e.payment_method))=lower(btrim(b.payment_method))
      ))
    )) THEN b.quote_status ELSE NULL END,
    CASE WHEN b.status='completed' AND ((b.razorpay_order_id IS NOT NULL AND b.payment_status='pending') OR (
      b.payment_status='paid' AND b.payment_verified_at IS NOT NULL AND b.amount_paid>0
      AND (b.razorpay_payment_id IS NOT NULL OR EXISTS (
        SELECT 1 FROM public.srk_manual_payment_entries e
        WHERE e.booking_id=b.id AND round(e.amount,2)=round(b.amount_paid,2)
          AND lower(btrim(e.payment_method))=lower(btrim(b.payment_method))
      ))
    )) THEN b.quote_note ELSE NULL END
  FROM public.job_offers o
  JOIN public.electrician_profiles p ON p.id=o.electrician_id
  JOIN public.service_bookings b ON b.id=o.booking_id
  WHERE auth.uid() IS NOT NULL
    AND (p.user_id=auth.uid() OR p.auth_user_id=auth.uid())
    AND p.verification_status='approved' AND p.active=true
  ORDER BY o.created_at DESC
  LIMIT 100;
$function$;
REVOKE ALL ON FUNCTION public.srk_get_my_offer_details() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.srk_get_my_offer_details() TO authenticated;

DROP FUNCTION IF EXISTS public.srk_get_my_earnings();
CREATE FUNCTION public.srk_get_my_earnings()
RETURNS TABLE (
  booking_id uuid,
  service_type text,
  booking_created_at timestamptz,
  booking_status text,
  payment_status text,
  amount_received numeric,
  commission_amount numeric,
  electrician_earning numeric,
  customer_labour_gross numeric,
  company_share numeric,
  payout_amount numeric,
  payout_status text,
  payout_reconciliation_status text,
  payment_stage text
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, public, auth, pg_temp
AS $$
  SELECT
    b.id,
    b.service_type,
    b.created_at,
    b.status,
    b.payment_status,
    CASE
      WHEN verified.is_verified THEN coalesce(b.amount_paid,0)
      ELSE 0
    END AS amount_received,
    CASE
      WHEN verified.is_verified AND payout_check.reconciliation_status='reconciled' THEN payout.platform_commission
      WHEN verified.is_verified THEN NULL
      WHEN checkout.started AND b.commission_rate=15
        THEN (floor((round(coalesce(bill.labour_amount,0)*100)*1500+5000)/10000)/100)
      ELSE 0
    END AS commission_amount,
    CASE
      WHEN verified.is_verified AND payout_check.reconciliation_status='reconciled' THEN payout.electrician_payable
      WHEN verified.is_verified THEN NULL
      WHEN b.status='completed' AND b.payment_status IS DISTINCT FROM 'refunded'
        AND b.payment_status IS DISTINCT FROM 'paid' AND NOT checkout.started
        AND NOT verified.is_verified AND b.selected_category IS NOT NULL AND bill.labour_amount IS NOT NULL
        THEN (round(coalesce(bill.labour_amount,0),2)-(floor((round(coalesce(bill.labour_amount,0)*100)*1500+5000)/10000)/100))
      WHEN checkout.started AND b.commission_rate=15 AND bill.labour_amount IS NOT NULL
        THEN (round(coalesce(bill.labour_amount,0),2)-(floor((round(coalesce(bill.labour_amount,0)*100)*1500+5000)/10000)/100))
      ELSE 0
    END AS electrician_earning,
    CASE
      WHEN verified.is_verified AND bill.labour_amount IS NOT NULL THEN bill.labour_amount
      WHEN checkout.started AND b.selected_category IS NOT NULL AND b.commission_rate=15 AND bill.labour_amount IS NOT NULL THEN bill.labour_amount
      ELSE NULL
    END AS customer_labour_gross,
    CASE
      WHEN verified.is_verified AND payout_check.reconciliation_status='reconciled' THEN payout.platform_commission
      WHEN verified.is_verified THEN NULL
      WHEN checkout.started AND b.commission_rate=15 THEN (floor((round(coalesce(bill.labour_amount,0)*100)*1500+5000)/10000)/100)
      ELSE NULL
    END AS company_share,
    CASE WHEN verified.is_verified AND payout_check.reconciliation_status='reconciled' THEN payout.electrician_payable ELSE NULL END AS payout_amount,
    CASE WHEN verified.is_verified THEN payout.payout_status ELSE NULL END AS payout_status,
    payout_check.reconciliation_status AS payout_reconciliation_status,
    CASE
      WHEN verified.is_verified THEN 'payment_verified'
      WHEN b.status='completed' AND b.payment_status='refunded' THEN 'refunded'
      WHEN b.status='completed' AND b.payment_status='paid' AND NOT verified.is_verified THEN 'payment_verification_required'
      WHEN b.status='completed' AND checkout.started
        AND (b.selected_category IS NULL OR bill.labour_amount IS NULL OR b.commission_rate IS DISTINCT FROM 15) THEN 'checkout_reconciliation_required'
      WHEN b.status='completed' AND checkout.started THEN 'checkout_started'
      WHEN b.status='completed' THEN 'completed_unpaid'
      ELSE 'not_completed'
    END AS payment_stage
  FROM public.electrician_profiles p
  JOIN public.service_bookings b ON b.assigned_electrician_id=p.id
  LEFT JOIN public.srk_electrician_payouts payout ON payout.booking_id=b.id
  LEFT JOIN public.srk_booking_labour_bills bill ON bill.booking_id=b.id
  CROSS JOIN LATERAL (
    SELECT (
      b.payment_status='paid'
      AND b.payment_verified_at IS NOT NULL
      AND coalesce(b.amount_paid,0)>0
      AND (
        b.razorpay_payment_id IS NOT NULL
        OR EXISTS (
          SELECT 1 FROM public.srk_manual_payment_entries e
          WHERE e.booking_id=b.id
            AND round(coalesce(e.amount,0),2)=round(coalesce(b.amount_paid,0),2)
            AND e.payment_method IS NOT NULL AND b.payment_method IS NOT NULL
            AND lower(btrim(e.payment_method))=lower(btrim(b.payment_method))
        )
      )
    ) AS is_verified
  ) verified
  CROSS JOIN LATERAL (
    SELECT (b.status='completed' AND b.razorpay_order_id IS NOT NULL AND b.payment_status='pending') AS started
  ) checkout
  CROSS JOIN LATERAL (
    SELECT CASE
      WHEN NOT verified.is_verified THEN 'not_applicable'
      WHEN payout.booking_id IS NULL THEN 'missing'
      WHEN payout.electrician_profile_id IS DISTINCT FROM b.assigned_electrician_id THEN 'electrician_mismatch'
      WHEN payout.gross_service_amount IS NULL OR payout.platform_commission IS NULL
        OR payout.electrician_payable IS NULL OR payout.payout_status IS NULL THEN 'incomplete'
      WHEN b.selected_category IS NOT NULL AND b.commission_rate IS DISTINCT FROM 15
        THEN 'commission_rate_mismatch'
      WHEN b.selected_category IS NOT NULL AND (
        bill.booking_id IS NULL
        OR round(payout.gross_service_amount,2) IS DISTINCT FROM round(bill.labour_amount,2)
      ) THEN 'bill_mismatch'
      WHEN b.commission_amount IS NULL OR round(payout.platform_commission,2) IS DISTINCT FROM round(b.commission_amount,2)
        THEN 'commission_mismatch'
      WHEN round(payout.electrician_payable,2) IS DISTINCT FROM
        round(payout.gross_service_amount+coalesce(payout.materials_amount,0)-payout.platform_commission,2)
        THEN 'amount_mismatch'
      ELSE 'reconciled'
    END AS reconciliation_status
  ) payout_check
  WHERE auth.uid() IS NOT NULL
    AND (p.user_id=auth.uid() OR p.auth_user_id=auth.uid())
    AND p.verification_status='approved'
  ORDER BY b.created_at DESC
  LIMIT 200;
$$;
REVOKE ALL ON FUNCTION public.srk_get_my_earnings() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.srk_get_my_earnings() TO authenticated;

COMMIT;
