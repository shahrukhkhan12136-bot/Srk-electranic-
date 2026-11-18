-- Gate electrician-facing financial fields by persisted checkout/payment evidence.
-- SOURCE ONLY: do not apply to Production without separate explicit approval.
-- Preserves existing commission/payout triggers and immutable booking/bill snapshots.
-- The existing payout ledger remains the source of truth for actual post-payment payout.

BEGIN;

-- Offers: estimated_labour_paise is now the electrician's 85% net only.
-- Gross quote/service/material amounts are withheld until a persisted checkout
-- order exists or payment is verified. Browser-provided stages are never read.
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
  estimated_labour_paise bigint,
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
    CASE WHEN (
      b.payment_status='paid' AND b.payment_verified_at IS NOT NULL
      AND b.amount_paid>0 AND (
        b.razorpay_payment_id IS NOT NULL OR EXISTS (
          SELECT 1 FROM public.srk_manual_payment_entries e
          WHERE e.booking_id=b.id
            AND round(e.amount,2)=round(b.amount_paid,2)
            AND lower(btrim(e.payment_method))=lower(btrim(b.payment_method))
        )
      )
    ) OR b.razorpay_order_id IS NOT NULL
      THEN b.quoted_amount ELSE NULL END,
    b.status, b.selected_category, b.selected_rate_tier, b.selected_duration_hours,
    CASE
      WHEN b.selected_category IS NOT NULL AND b.estimated_labour_paise>0
      THEN ((b.estimated_labour_paise::numeric*8500+5000)/10000)::bigint
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
    CASE WHEN b.razorpay_order_id IS NOT NULL OR (
      b.payment_status='paid' AND b.payment_verified_at IS NOT NULL AND b.amount_paid>0
      AND (b.razorpay_payment_id IS NOT NULL OR EXISTS (
        SELECT 1 FROM public.srk_manual_payment_entries e
        WHERE e.booking_id=b.id AND round(e.amount,2)=round(b.amount_paid,2)
          AND lower(btrim(e.payment_method))=lower(btrim(b.payment_method))
      ))
    ) THEN b.service_charge ELSE NULL END,
    CASE WHEN b.razorpay_order_id IS NOT NULL OR (
      b.payment_status='paid' AND b.payment_verified_at IS NOT NULL AND b.amount_paid>0
      AND (b.razorpay_payment_id IS NOT NULL OR EXISTS (
        SELECT 1 FROM public.srk_manual_payment_entries e
        WHERE e.booking_id=b.id AND round(e.amount,2)=round(b.amount_paid,2)
          AND lower(btrim(e.payment_method))=lower(btrim(b.payment_method))
      ))
    ) THEN b.materials_amount ELSE NULL END,
    CASE WHEN b.razorpay_order_id IS NOT NULL OR (
      b.payment_status='paid' AND b.payment_verified_at IS NOT NULL AND b.amount_paid>0
      AND (b.razorpay_payment_id IS NOT NULL OR EXISTS (
        SELECT 1 FROM public.srk_manual_payment_entries e
        WHERE e.booking_id=b.id AND round(e.amount,2)=round(b.amount_paid,2)
          AND lower(btrim(e.payment_method))=lower(btrim(b.payment_method))
      ))
    ) THEN b.quote_status ELSE NULL END,
    CASE WHEN b.razorpay_order_id IS NOT NULL OR (
      b.payment_status='paid' AND b.payment_verified_at IS NOT NULL AND b.amount_paid>0
      AND (b.razorpay_payment_id IS NOT NULL OR EXISTS (
        SELECT 1 FROM public.srk_manual_payment_entries e
        WHERE e.booking_id=b.id AND round(e.amount,2)=round(b.amount_paid,2)
          AND lower(btrim(e.payment_method))=lower(btrim(b.payment_method))
      ))
    ) THEN b.quote_note ELSE NULL END
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

-- Earnings: keep the legacy return values but add payment_stage. All financial
-- values are server-derived. The payout ledger/commission_rate is NOT rewritten.
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
      WHEN checkout.started THEN coalesce(b.estimated_labour_paise,0)::numeric/100
      ELSE 0
    END AS amount_received,
    CASE
      WHEN verified.is_verified THEN coalesce(b.commission_amount,0)
      WHEN checkout.started AND b.commission_rate=15
        THEN round(coalesce(b.estimated_labour_paise,0)::numeric/100*0.15,2)
      ELSE 0
    END AS commission_amount,
    CASE
      WHEN verified.is_verified THEN coalesce(payout.electrician_payable,0)
      WHEN b.status='completed' AND NOT checkout.started AND NOT verified.is_verified
        AND b.selected_category IS NOT NULL
        THEN round(((coalesce(b.estimated_labour_paise,0)::numeric*8500+5000)/10000)/100,2)
      WHEN checkout.started AND b.commission_rate=15
        THEN round(((coalesce(b.estimated_labour_paise,0)::numeric*8500+5000)/10000)/100,2)
      ELSE 0
    END AS electrician_earning,
    CASE
      WHEN verified.is_verified THEN 'payment_verified'
      WHEN b.status='completed' AND checkout.started THEN 'checkout_started'
      WHEN b.status='completed' THEN 'completed_unpaid'
      ELSE 'not_completed'
    END AS payment_stage
  FROM public.electrician_profiles p
  JOIN public.service_bookings b ON b.assigned_electrician_id=p.id
  LEFT JOIN public.srk_electrician_payouts payout ON payout.booking_id=b.id
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
    SELECT (b.razorpay_order_id IS NOT NULL AND b.payment_status IN ('pending','created')) AS started
  ) checkout
  WHERE auth.uid() IS NOT NULL
    AND (p.user_id=auth.uid() OR p.auth_user_id=auth.uid())
    AND p.verification_status='approved'
  ORDER BY b.created_at DESC
  LIMIT 200;
$$;
REVOKE ALL ON FUNCTION public.srk_get_my_earnings() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.srk_get_my_earnings() TO authenticated;

COMMIT;
