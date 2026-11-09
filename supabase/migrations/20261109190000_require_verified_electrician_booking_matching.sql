-- SRK ELECTRONIC: only OTP-linked approved/active electricians receive offers.
-- PIN-code matching is attempted first. District fallback is used only when
-- there are no eligible electricians in the booking PIN code.
-- Also keep both legacy auth linkage columns in sync because the job-offer
-- SELECT RLS policy and some older RPCs use auth_user_id.
-- This migration is prepared on a non-production Git branch and is NOT applied.

CREATE OR REPLACE FUNCTION public.srk_link_electrician_profile()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'public', 'auth', 'pg_temp'
AS $function$
BEGIN
  IF NEW.phone IS NOT NULL AND NEW.phone_confirmed_at IS NOT NULL THEN
    UPDATE public.electrician_profiles
       SET user_id = NEW.id,
           auth_user_id = NEW.id
     WHERE right(regexp_replace(phone, '[^0-9]', '', 'g'), 10) =
           right(regexp_replace(NEW.phone, '[^0-9]', '', 'g'), 10)
       AND verification_status = 'approved'
       AND (user_id IS NULL OR user_id = NEW.id)
       AND (auth_user_id IS NULL OR auth_user_id = NEW.id);
  END IF;
  RETURN NEW;
END;
$function$;

CREATE OR REPLACE FUNCTION public.broadcast_booking_job()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'public', 'pg_temp'
AS $function$
DECLARE
  matched_count integer;
BEGIN
  -- First priority: exact PIN code. Both auth linkage columns are populated
  -- only after auth.users.phone_confirmed_at is set by successful OTP.
  INSERT INTO public.job_offers
    (booking_id, electrician_id, status, match_level)
  SELECT
    NEW.id,
    e.id,
    'offered',
    'pincode'
  FROM public.electrician_profiles e
  WHERE e.active = true
    AND e.verification_status = 'approved'
    AND e.user_id IS NOT NULL
    AND e.auth_user_id IS NOT NULL
    AND e.user_id = e.auth_user_id
    AND e.pincode = NEW.pincode
  ON CONFLICT (booking_id, electrician_id)
  DO NOTHING;

  GET DIAGNOSTICS matched_count = ROW_COUNT;

  -- Only if no eligible PIN-code match exists, use same state/district.
  IF matched_count = 0 THEN
    INSERT INTO public.job_offers
      (booking_id, electrician_id, status, match_level)
    SELECT
      NEW.id,
      e.id,
      'offered',
      'district'
    FROM public.electrician_profiles e
    WHERE e.active = true
      AND e.verification_status = 'approved'
      AND e.user_id IS NOT NULL
      AND e.auth_user_id IS NOT NULL
      AND e.user_id = e.auth_user_id
      AND lower(trim(e.state)) = lower(trim(NEW.state))
      AND lower(trim(e.district)) = lower(trim(NEW.district))
    ON CONFLICT (booking_id, electrician_id)
    DO NOTHING;
  END IF;

  RETURN NEW;
END;
$function$;

COMMENT ON FUNCTION public.broadcast_booking_job() IS
'Broadcasts new bookings to OTP-linked approved and active electricians: exact PIN first, same state/district fallback only when no eligible PIN match exists.';
