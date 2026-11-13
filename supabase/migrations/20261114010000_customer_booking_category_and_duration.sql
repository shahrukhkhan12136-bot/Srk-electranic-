-- Canonical customer-selected work category and booked duration.
-- Legacy bookings remain NULL and are never inferred from free-form service_type.
ALTER TABLE public.service_bookings
  ADD COLUMN IF NOT EXISTS selected_category text,
  ADD COLUMN IF NOT EXISTS selected_duration_hours smallint;

ALTER TABLE public.service_bookings
  ADD CONSTRAINT service_bookings_selected_category_valid
  CHECK (
    selected_category IS NULL OR selected_category IN (
      'home_wiring',
      'electrical_repair',
      'light_fan_fitting',
      'home_repair',
      'other'
    )
  );

ALTER TABLE public.service_bookings
  ADD CONSTRAINT service_bookings_selected_duration_hours_valid
  CHECK (
    selected_duration_hours IS NULL OR selected_duration_hours BETWEEN 1 AND 8
  );

ALTER TABLE public.service_bookings
  ADD CONSTRAINT service_bookings_category_duration_pair
  CHECK ((selected_category IS NULL) = (selected_duration_hours IS NULL));

COMMENT ON COLUMN public.service_bookings.selected_category IS
  'Canonical customer-selected work category. NULL means legacy/unclassified; never infer from service_type.';
COMMENT ON COLUMN public.service_bookings.selected_duration_hours IS
  'Customer-booked duration estimate in whole hours (1–8). Actual billing uses server-recorded elapsed time.';


-- Offer matching integration: commercial rate tier and customer work category
-- are separate dimensions; never compare or infer one from the other.
CREATE OR REPLACE FUNCTION public.srk_admin_offer_booking(p_booking_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'public', 'auth', 'pg_temp'
AS $function$
DECLARE
  v_booking public.service_bookings%ROWTYPE;
  v_match_level text;
  v_eligible integer := 0;
  v_created integer := 0;
BEGIN
  IF auth.uid() IS NULL OR NOT public.is_srk_admin() THEN
    RAISE EXCEPTION 'Admin permission required' USING ERRCODE = '42501';
  END IF;
  IF p_booking_id IS NULL THEN RAISE EXCEPTION 'Booking ID required' USING ERRCODE = '22023'; END IF;
  SELECT * INTO v_booking FROM public.service_bookings WHERE id=p_booking_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Booking not found' USING ERRCODE = 'P0002'; END IF;
  IF v_booking.assigned_electrician_id IS NOT NULL THEN
    RAISE EXCEPTION 'Booking already has an assigned electrician';
  END IF;
  IF v_booking.status NOT IN ('new','confirmed') THEN
    RAISE EXCEPTION 'Only new or confirmed bookings can be offered';
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.electrician_profiles e
    WHERE e.active=true AND e.verification_status='approved'
      AND e.auth_user_id IS NOT NULL AND e.user_id=e.auth_user_id
      AND e.approved_rate_tier IS NOT NULL
      AND e.approved_rate_card_version IS NOT NULL
      AND e.rate_tier_approved_by IS NOT NULL
      AND e.rate_tier_approved_at IS NOT NULL
      AND e.pincode=v_booking.pincode
      AND lower(trim(e.state))=lower(trim(v_booking.state))
  ) THEN
    v_match_level := 'pincode';
  ELSE
    v_match_level := 'district';
  END IF;

  WITH eligible AS (
    SELECT e.id FROM public.electrician_profiles e
    WHERE e.active=true AND e.verification_status='approved'
      AND e.auth_user_id IS NOT NULL AND e.user_id=e.auth_user_id
      AND e.approved_rate_tier IS NOT NULL
      AND e.approved_rate_card_version IS NOT NULL
      AND e.rate_tier_approved_by IS NOT NULL
      AND e.rate_tier_approved_at IS NOT NULL
      AND lower(trim(e.state))=lower(trim(v_booking.state))
      AND (
        (v_match_level='pincode' AND e.pincode=v_booking.pincode)
        OR (v_match_level='district' AND lower(trim(e.district))=lower(trim(v_booking.district)))
      )
  ), inserted AS (
    INSERT INTO public.job_offers(booking_id,electrician_id,status,match_level)
    SELECT p_booking_id,eligible.id,'offered',v_match_level
    FROM eligible ON CONFLICT(booking_id,electrician_id) DO NOTHING
    RETURNING id
  )
  SELECT (SELECT count(*) FROM eligible),(SELECT count(*) FROM inserted)
  INTO v_eligible,v_created;

  IF v_eligible=0 THEN
    RETURN jsonb_build_object('success',false,
      'message','इस PIN/जिले में कोई Active, KYC-approved और Admin rate-tier-approved इलेक्ट्रिशियन उपलब्ध नहीं है।',
      'match_level',v_match_level,'eligible_count',0,'offers_created',0);
  END IF;
  RETURN jsonb_build_object('success',true,
    'message',CASE WHEN v_match_level='pincode'
      THEN 'उसी PIN के योग्य और rate-tier-approved इलेक्ट्रिशियनों को ऑफर भेजे गए।'
      ELSE 'उसी PIN पर योग्य पार्टनर नहीं मिला; जिले के rate-tier-approved पार्टनर को ऑफर भेजे गए।' END,
    'match_level',v_match_level,'eligible_count',v_eligible,'offers_created',v_created);
END;
$function$;
REVOKE ALL ON FUNCTION public.srk_admin_offer_booking(uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.srk_admin_offer_booking(uuid) TO authenticated;

DROP FUNCTION IF EXISTS public.srk_get_my_offer_details();
CREATE FUNCTION public.srk_get_my_offer_details()
RETURNS TABLE(
  offer_id uuid,offer_status text,match_level text,offer_created_at timestamptz,
  booking_id uuid,service_type text,state text,district text,pincode text,
  preferred_date date,preferred_time time,work_details text,quoted_amount numeric,
  booking_status text,customer_name text,customer_phone text,address text,
  location_lat double precision,location_lng double precision,
  service_charge numeric,materials_amount numeric,quote_status text,quote_note text,
  selected_category text,selected_duration_hours smallint,approved_rate_tier text
)
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path TO 'pg_catalog','public','auth','pg_temp'
AS $function$
  SELECT o.id,o.status,o.match_level,o.created_at,b.id,b.service_type,b.state,b.district,b.pincode,
    b.preferred_date,b.preferred_time,b.work_details,b.quoted_amount,b.status,
    CASE WHEN b.assigned_electrician_id=p.id AND b.status IN
      ('assigned','inspection','awaiting_quote_approval','quote_approved','in_progress','completed')
      THEN b.customer_name ELSE NULL END,
    CASE WHEN b.assigned_electrician_id=p.id AND b.status IN
      ('assigned','inspection','awaiting_quote_approval','quote_approved','in_progress','completed')
      THEN b.phone ELSE NULL END,
    CASE WHEN b.assigned_electrician_id=p.id AND b.status IN
      ('assigned','inspection','awaiting_quote_approval','quote_approved','in_progress','completed')
      THEN b.address ELSE NULL END,
    CASE WHEN b.assigned_electrician_id=p.id AND b.status IN
      ('assigned','inspection','awaiting_quote_approval','quote_approved','in_progress','completed')
      THEN b.location_lat ELSE NULL END,
    CASE WHEN b.assigned_electrician_id=p.id AND b.status IN
      ('assigned','inspection','awaiting_quote_approval','quote_approved','in_progress','completed')
      THEN b.location_lng ELSE NULL END,
    CASE WHEN b.assigned_electrician_id=p.id AND b.status IN
      ('assigned','inspection','awaiting_quote_approval','quote_approved','in_progress','completed')
      THEN b.service_charge ELSE NULL END,
    CASE WHEN b.assigned_electrician_id=p.id AND b.status IN
      ('assigned','inspection','awaiting_quote_approval','quote_approved','in_progress','completed')
      THEN b.materials_amount ELSE NULL END,
    CASE WHEN b.assigned_electrician_id=p.id AND b.status IN
      ('assigned','inspection','awaiting_quote_approval','quote_approved','in_progress','completed')
      THEN b.quote_status ELSE NULL END,
    CASE WHEN b.assigned_electrician_id=p.id AND b.status IN
      ('assigned','inspection','awaiting_quote_approval','quote_approved','in_progress','completed')
      THEN b.quote_note ELSE NULL END,
    b.selected_category,b.selected_duration_hours,p.approved_rate_tier
  FROM public.job_offers o
  JOIN public.electrician_profiles p ON p.id=o.electrician_id
  JOIN public.service_bookings b ON b.id=o.booking_id
  WHERE auth.uid() IS NOT NULL AND (p.user_id=auth.uid() OR p.auth_user_id=auth.uid())
    AND p.verification_status='approved' AND p.active=true
    AND p.approved_rate_tier IS NOT NULL AND p.approved_rate_card_version IS NOT NULL
    AND p.rate_tier_approved_by IS NOT NULL AND p.rate_tier_approved_at IS NOT NULL
  ORDER BY o.created_at DESC LIMIT 100;
$function$;
REVOKE ALL ON FUNCTION public.srk_get_my_offer_details() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.srk_get_my_offer_details() TO authenticated;
COMMENT ON FUNCTION public.srk_admin_offer_booking(uuid) IS
  'Geographic offers require active KYC and complete Admin-approved rate tier. Customer work category is a separate label.';
