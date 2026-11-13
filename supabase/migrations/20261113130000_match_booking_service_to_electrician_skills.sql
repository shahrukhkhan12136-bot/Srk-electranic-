-- SRK ELECTRONIC: match booking categories to electrician skills.
-- Existing "सभी इलेक्ट्रिकल काम" profiles remain eligible for every category.
-- No existing booking, offer, or electrician profile data is rewritten.
CREATE OR REPLACE FUNCTION public.broadcast_booking_job()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'public', 'pg_temp'
AS $function$
DECLARE
  matched_count integer;
BEGIN
  -- First search same PIN code, state, district, and service skill.
  INSERT INTO public.job_offers (booking_id, electrician_id, status, match_level)
  SELECT NEW.id, e.id, 'offered', 'pincode'
  FROM public.electrician_profiles e
  WHERE e.active = true
    AND e.verification_status = 'approved'
    AND e.pincode = NEW.pincode
    AND lower(trim(e.state)) = lower(trim(NEW.state))
    AND lower(trim(e.district)) = lower(trim(NEW.district))
    AND (
      e.skills @> ARRAY[NEW.service_type]::text[]
      OR e.skills @> ARRAY['सभी इलेक्ट्रिकल काम']::text[]
    )
  ON CONFLICT (booking_id, electrician_id) DO NOTHING;

  GET DIAGNOSTICS matched_count = ROW_COUNT;

  -- If no eligible PIN match, search same state/district and skill.
  IF matched_count = 0 THEN
    INSERT INTO public.job_offers (booking_id, electrician_id, status, match_level)
    SELECT NEW.id, e.id, 'offered', 'district'
    FROM public.electrician_profiles e
    WHERE e.active = true
      AND e.verification_status = 'approved'
      AND lower(trim(e.state)) = lower(trim(NEW.state))
      AND lower(trim(e.district)) = lower(trim(NEW.district))
      AND (
        e.skills @> ARRAY[NEW.service_type]::text[]
        OR e.skills @> ARRAY['सभी इलेक्ट्रिकल काम']::text[]
      )
    ON CONFLICT (booking_id, electrician_id) DO NOTHING;
  END IF;

  RETURN NEW;
END;
$function$;
