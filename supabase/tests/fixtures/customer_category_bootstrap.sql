-- Synthetic-only baseline for customer category/duration and offer matching tests.
-- Applied exclusively to an ephemeral local Supabase stack.
CREATE TABLE public.service_bookings (
  id uuid PRIMARY KEY,
  status text NOT NULL DEFAULT 'new',
  assigned_electrician_id uuid,
  customer_user_id uuid,
  service_type text,
  state text,
  district text,
  pincode text,
  preferred_date date,
  preferred_time time,
  work_details text,
  quoted_amount numeric(12,2),
  customer_name text,
  phone text,
  address text,
  location_lat double precision,
  location_lng double precision,
  service_charge numeric(12,2),
  materials_amount numeric(12,2),
  quote_status text,
  quote_note text
);

CREATE TABLE public.electrician_profiles (
  id uuid PRIMARY KEY,
  active boolean NOT NULL DEFAULT true,
  verification_status text NOT NULL DEFAULT 'approved',
  user_id uuid,
  auth_user_id uuid,
  approved_rate_tier text,
  approved_rate_card_version text,
  rate_tier_approved_by uuid,
  rate_tier_approved_at timestamptz,
  pincode text,
  state text,
  district text
);

CREATE TABLE public.job_offers (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_id uuid NOT NULL REFERENCES public.service_bookings(id) ON DELETE CASCADE,
  electrician_id uuid NOT NULL REFERENCES public.electrician_profiles(id),
  status text NOT NULL DEFAULT 'offered' CHECK(status IN ('offered','accepted','declined','expired','cancelled')),
  match_level text NOT NULL CHECK(match_level IN ('pincode','district')),
  created_at timestamptz NOT NULL DEFAULT now(),
  responded_at timestamptz,
  UNIQUE(booking_id,electrician_id)
);

CREATE OR REPLACE FUNCTION public.is_srk_admin()
RETURNS boolean LANGUAGE sql STABLE
AS $function$
  SELECT COALESCE((current_setting('request.jwt.claims',true)::jsonb->>'role')='service_role',false);
$function$;
