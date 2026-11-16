-- PR #8 replay-preparation only.
-- NOT a numbered Supabase migration. Do not run against staging or Production.
-- The disposable local harness must set:
--   SET app.srk_replay_environment = 'disposable_local';
-- before executing this file in the same database session.
--
-- Required baseline objects: public.service_bookings, public.electrician_profiles,
-- public.srk_admin_users, auth.users, auth.uid(), and Supabase roles.
-- This file only restores prerequisites identified by static source inspection.

DO $guard$
BEGIN
  IF current_setting('app.srk_replay_environment', true) IS DISTINCT FROM 'disposable_local' THEN
    RAISE EXCEPTION 'REFUSING_PR8_REPLAY_PREP_OUTSIDE_DISPOSABLE_LOCAL';
  END IF;

  IF to_regclass('public.service_bookings') IS NULL
     OR to_regclass('public.electrician_profiles') IS NULL
     OR to_regclass('public.srk_admin_users') IS NULL
     OR to_regclass('auth.users') IS NULL THEN
    RAISE EXCEPTION 'PR8_REPLAY_BASELINE_INCOMPLETE';
  END IF;
END;
$guard$;

-- The commission/earnings RPC migration references amount_paid before the
-- late 20261116200000 restore migration. Match the verified legacy numeric type.
ALTER TABLE public.service_bookings
  ADD COLUMN IF NOT EXISTS amount_paid numeric(12,2);

DO $constraints$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conrelid = 'public.service_bookings'::regclass
      AND conname = 'service_bookings_amount_paid_nonnegative'
  ) THEN
    ALTER TABLE public.service_bookings
      ADD CONSTRAINT service_bookings_amount_paid_nonnegative
      CHECK (amount_paid IS NULL OR amount_paid >= 0) NOT VALID;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conrelid = 'public.service_bookings'::regclass
      AND conname = 'service_bookings_amount_paid_range'
  ) THEN
    ALTER TABLE public.service_bookings
      ADD CONSTRAINT service_bookings_amount_paid_range
      CHECK (amount_paid IS NULL OR amount_paid BETWEEN 0 AND 10000000) NOT VALID;
  END IF;
END;
$constraints$;

-- The two Admin predicates are separate names in the source tree. Define both
-- before 20261109001000 and 20261109001500 call them.
CREATE OR REPLACE FUNCTION public.is_srk_admin()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, public, auth, pg_temp
AS $function$
  SELECT EXISTS (
    SELECT 1 FROM public.srk_admin_users a
    WHERE a.user_id = auth.uid()
  );
$function$;

CREATE OR REPLACE FUNCTION public.srk_is_admin()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, public, auth, pg_temp
AS $function$
  SELECT EXISTS (
    SELECT 1 FROM public.srk_admin_users a
    WHERE a.user_id = auth.uid()
  );
$function$;

REVOKE ALL ON FUNCTION public.is_srk_admin() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.srk_is_admin() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.is_srk_admin() TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.srk_is_admin() TO authenticated, service_role;

COMMENT ON FUNCTION public.is_srk_admin() IS
  'PR #8 replay prerequisite: checks the authenticated user against srk_admin_users.';
COMMENT ON FUNCTION public.srk_is_admin() IS
  'PR #8 replay prerequisite: legacy Admin predicate retained as a distinct function name.';
