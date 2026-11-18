-- Make displayed electrician rate, job offer and payout ledger use one paise-rounding rule.
-- Canonical rule: commission = round-half-up(gross * 15%); electrician net = gross - commission.
-- This avoids a 1-paise divergence at half-paise ties between direct 85% and existing ledger.
-- SOURCE ONLY: do not apply to any database without explicit approval.
BEGIN;

CREATE OR REPLACE FUNCTION public.srk_get_my_electrician_rate_list()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=''
AS $fn$
DECLARE v_profile_id uuid; v_catalogue jsonb; v_items jsonb;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'AUTHENTICATION_REQUIRED' USING ERRCODE='42501'; END IF;
  SELECT id INTO v_profile_id FROM public.electrician_profiles
   WHERE auth_user_id=auth.uid() AND user_id=auth.uid()
     AND verification_status='approved' LIMIT 1;
  IF v_profile_id IS NULL THEN RAISE EXCEPTION 'APPROVED_ELECTRICIAN_PROFILE_REQUIRED' USING ERRCODE='42501'; END IF;
  v_catalogue:=public.srk_get_current_customer_rate_catalogue();
  IF v_catalogue IS NULL THEN RAISE EXCEPTION 'NO_ACTIVE_RATE_CATALOGUE'; END IF;
  SELECT coalesce(jsonb_agg(jsonb_build_object(
      'category_key',a.category_key,
      'customer_facing_label',CASE a.category_key
        WHEN 'electrical_assistant' THEN 'Electrical Assistant'
        WHEN 'skilled_electrician' THEN 'Skilled Electrician'
        WHEN 'expert_electrician' THEN 'Expert Electrician'
        WHEN 'premium_electrical_specialist' THEN 'Premium Electrical Specialist' END,
      'duration_hours',8,
      'electrician_rate_paise',(i.customer_rate_paise - floor((i.customer_rate_paise::numeric*1500/10000)+0.5)::bigint)
    ) ORDER BY a.category_key),'[]'::jsonb)
    INTO v_items
    FROM public.srk_electrician_approved_rate_categories a
    JOIN public.srk_rate_catalogue_items i
      ON i.rate_version_id=(v_catalogue->>'rate_version_id')::uuid
     AND i.tier_key=a.category_key
   WHERE a.electrician_profile_id=v_profile_id AND a.is_active=true;
  RETURN jsonb_build_object('rate_version_id',v_catalogue->'rate_version_id',
    'effective_at',v_catalogue->'effective_at','currency','INR','items',v_items);
END;
$fn$;

REVOKE ALL ON FUNCTION public.srk_admin_publish_rate_catalogue(jsonb,timestamptz,uuid,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.srk_admin_publish_rate_catalogue(jsonb,timestamptz,uuid,text) TO authenticated;
REVOKE ALL ON FUNCTION public.srk_get_current_customer_rate_catalogue() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.srk_get_current_customer_rate_catalogue() TO anon,authenticated,service_role;
GRANT SELECT ON TABLE public.srk_rate_catalogue_items TO service_role;
REVOKE ALL ON FUNCTION public.srk_admin_set_electrician_approved_categories(uuid,text[],text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.srk_admin_set_electrician_approved_categories(uuid,text[],text) TO authenticated;
REVOKE ALL ON FUNCTION public.srk_get_my_electrician_rate_list() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.srk_get_my_electrician_rate_list() TO authenticated;

CREATE OR REPLACE FUNCTION public.srk_get_my_offer_details()
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
      THEN (b.estimated_labour_paise - floor((b.estimated_labour_paise::numeric*1500/10000)+0.5)::bigint)
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

COMMIT;
