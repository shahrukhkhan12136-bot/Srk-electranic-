-- Unified Technician identity and idempotent completed-booking ledger.
-- Feature-branch source only. Do not apply to Production without separate approval.
-- Existing electrician profile IDs are mapped to canonical Technician IDs; source rows remain intact.

CREATE TABLE IF NOT EXISTS public.srk_technicians (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  auth_user_id uuid UNIQUE REFERENCES auth.users(id) ON DELETE RESTRICT,
  primary_phone text,
  account_status text NOT NULL DEFAULT 'active'
    CHECK (account_status IN ('pending','active','suspended','rejected')),
  created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  updated_at timestamptz NOT NULL DEFAULT clock_timestamp()
);

CREATE TABLE IF NOT EXISTS public.srk_technician_profile_links (
  electrician_profile_id uuid PRIMARY KEY
    REFERENCES public.electrician_profiles(id) ON DELETE RESTRICT,
  technician_id uuid NOT NULL
    REFERENCES public.srk_technicians(id) ON DELETE RESTRICT,
  linked_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  UNIQUE (electrician_profile_id, technician_id)
);

-- One canonical identity per verified Auth user; profiles without an Auth link
-- retain a profile-scoped identity until their OTP identity is reconciled.
WITH profile_identity AS (
  SELECT
    ep.id AS profile_id,
    ep.auth_user_id,
    ep.user_id,
    ep.phone,
    COALESCE(ep.auth_user_id, ep.user_id) AS linked_user_id,
    COALESCE(ep.auth_user_id, ep.user_id, ep.id) AS identity_key
  FROM public.electrician_profiles ep
),
canonical AS (
  SELECT
    (array_agg(profile_id ORDER BY profile_id))[1] AS technician_id,
    linked_user_id AS auth_user_id,
    (array_agg(phone ORDER BY profile_id))[1] AS primary_phone,
    identity_key
  FROM profile_identity
  GROUP BY linked_user_id, identity_key
)
INSERT INTO public.srk_technicians(id, auth_user_id, primary_phone)
SELECT technician_id, auth_user_id, primary_phone
FROM canonical
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.srk_technician_profile_links(electrician_profile_id, technician_id)
SELECT ep.id, t.id
FROM public.electrician_profiles ep
JOIN public.srk_technicians t
  ON (t.auth_user_id = COALESCE(ep.auth_user_id, ep.user_id))
  OR (t.auth_user_id IS NULL AND t.id = ep.id)
ON CONFLICT (electrician_profile_id) DO NOTHING;

CREATE TABLE IF NOT EXISTS public.srk_booking_technician_assignments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_id uuid NOT NULL REFERENCES public.service_bookings(id) ON DELETE RESTRICT,
  technician_id uuid NOT NULL REFERENCES public.srk_technicians(id) ON DELETE RESTRICT,
  service_category_snapshot text NOT NULL,
  assignment_status text NOT NULL DEFAULT 'assigned'
    CHECK (assignment_status IN ('assigned','accepted','active','completed','replaced','cancelled')),
  assigned_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  accepted_at timestamptz,
  completed_at timestamptz,
  UNIQUE (booking_id, technician_id)
);

-- Backfill legacy single-electrician assignments without changing booking history.
INSERT INTO public.srk_booking_technician_assignments
  (booking_id, technician_id, service_category_snapshot, assignment_status, assigned_at)
SELECT b.id, l.technician_id,
       COALESCE(NULLIF(b.selected_category,''), NULLIF(b.service_type,''), 'legacy_electrician'),
       CASE WHEN b.status='completed' THEN 'completed' ELSE 'assigned' END,
       COALESCE(b.created_at, clock_timestamp())
FROM public.service_bookings b
JOIN public.srk_technician_profile_links l
  ON l.electrician_profile_id=b.assigned_electrician_id
WHERE b.assigned_electrician_id IS NOT NULL
ON CONFLICT (booking_id, technician_id) DO NOTHING;

-- Keep the legacy electrician offer/assignment path compatible while new
-- category-neutral assignment RPCs are introduced. Every legacy assignment
-- is represented by the same canonical Technician ID used by the new ledger.
CREATE OR REPLACE FUNCTION public.srk_sync_legacy_electrician_assignment()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  v_technician_id uuid;
BEGIN
  IF NEW.assigned_electrician_id IS NULL THEN
    RETURN NEW;
  END IF;

  SELECT l.technician_id INTO v_technician_id
  FROM public.srk_technician_profile_links l
  WHERE l.electrician_profile_id=NEW.assigned_electrician_id;

  IF v_technician_id IS NULL THEN
    RAISE EXCEPTION 'LEGACY_ELECTRICIAN_PROFILE_HAS_NO_CANONICAL_TECHNICIAN_LINK'
      USING ERRCODE='23503';
  END IF;

  INSERT INTO public.srk_booking_technician_assignments
    (booking_id, technician_id, service_category_snapshot, assignment_status, assigned_at)
  VALUES (
    NEW.id, v_technician_id,
    COALESCE(NULLIF(NEW.selected_category,''), NULLIF(NEW.service_type,''), 'legacy_electrician'),
    CASE WHEN NEW.status='completed' THEN 'completed' ELSE 'assigned' END,
    clock_timestamp()
  )
  ON CONFLICT (booking_id, technician_id) DO NOTHING;

  RETURN NEW;
END;
$function$;

REVOKE ALL ON FUNCTION public.srk_sync_legacy_electrician_assignment() FROM PUBLIC,anon,authenticated;
DROP TRIGGER IF EXISTS srk_sync_legacy_electrician_assignment ON public.service_bookings;
CREATE TRIGGER srk_sync_legacy_electrician_assignment
AFTER INSERT OR UPDATE OF assigned_electrician_id ON public.service_bookings
FOR EACH ROW
EXECUTE FUNCTION public.srk_sync_legacy_electrician_assignment();

CREATE TABLE IF NOT EXISTS public.srk_technician_booking_counters (
  technician_id uuid PRIMARY KEY REFERENCES public.srk_technicians(id) ON DELETE RESTRICT,
  completed_booking_count bigint NOT NULL DEFAULT 0 CHECK (completed_booking_count >= 0),
  updated_at timestamptz NOT NULL DEFAULT clock_timestamp()
);

CREATE TABLE IF NOT EXISTS public.srk_technician_completed_booking_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  technician_id uuid NOT NULL REFERENCES public.srk_technicians(id) ON DELETE RESTRICT,
  booking_id uuid NOT NULL REFERENCES public.service_bookings(id) ON DELETE RESTRICT,
  completion_ordinal bigint NOT NULL CHECK (completion_ordinal > 0),
  customer_confirmed_at timestamptz NOT NULL,
  recorded_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  UNIQUE (technician_id, booking_id),
  UNIQUE (technician_id, completion_ordinal)
);

CREATE INDEX IF NOT EXISTS srk_booking_technician_assignments_technician_idx
  ON public.srk_booking_technician_assignments(technician_id, assignment_status, assigned_at DESC);
CREATE INDEX IF NOT EXISTS srk_technician_completion_events_booking_idx
  ON public.srk_technician_completed_booking_events(booking_id);
CREATE INDEX IF NOT EXISTS srk_technician_completion_events_recent_idx
  ON public.srk_technician_completed_booking_events(technician_id, completion_ordinal DESC);

-- Seed counters from historical completed bookings. These are backfilled only
-- from rows that have customer completion evidence and a mapped technician.
INSERT INTO public.srk_technician_booking_counters(technician_id, completed_booking_count)
SELECT e.technician_id, count(*)::bigint
FROM public.srk_technician_completed_booking_events e
GROUP BY e.technician_id
ON CONFLICT (technician_id) DO UPDATE
SET completed_booking_count = GREATEST(
      public.srk_technician_booking_counters.completed_booking_count,
      EXCLUDED.completed_booking_count
    ),
    updated_at = clock_timestamp();

-- Rebuild the historical event ledger with deterministic per-technician ordinals.
-- Existing completed records are retained; duplicate event keys are ignored.
WITH completed AS (
  SELECT a.technician_id, a.booking_id,
         COALESCE(b.customer_completed_at, b.completion_requested_at, b.created_at, clock_timestamp()) AS confirmed_at
  FROM public.srk_booking_technician_assignments a
  JOIN public.service_bookings b ON b.id=a.booking_id
  WHERE b.status='completed'
    AND b.completion_approval_status='approved'
    AND b.customer_completed_at IS NOT NULL
),
numbered AS (
  SELECT technician_id, booking_id, confirmed_at,
         row_number() OVER (PARTITION BY technician_id ORDER BY confirmed_at, booking_id) AS ordinal
  FROM completed
)
INSERT INTO public.srk_technician_completed_booking_events
  (technician_id, booking_id, completion_ordinal, customer_confirmed_at)
SELECT technician_id, booking_id, ordinal, confirmed_at
FROM numbered
ON CONFLICT (technician_id, booking_id) DO NOTHING;

-- Reconcile counters from the event ledger after historical backfill.
INSERT INTO public.srk_technician_booking_counters(technician_id, completed_booking_count)
SELECT technician_id, count(*)::bigint
FROM public.srk_technician_completed_booking_events
GROUP BY technician_id
ON CONFLICT (technician_id) DO UPDATE
SET completed_booking_count=EXCLUDED.completed_booking_count,
    updated_at=clock_timestamp();

ALTER TABLE public.srk_technicians ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.srk_technician_profile_links ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.srk_booking_technician_assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.srk_technician_booking_counters ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.srk_technician_completed_booking_events ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE public.srk_technicians FROM PUBLIC, anon, authenticated;
REVOKE ALL ON TABLE public.srk_technician_profile_links FROM PUBLIC, anon, authenticated;
REVOKE ALL ON TABLE public.srk_booking_technician_assignments FROM PUBLIC, anon, authenticated;
REVOKE ALL ON TABLE public.srk_technician_booking_counters FROM PUBLIC, anon, authenticated;
REVOKE ALL ON TABLE public.srk_technician_completed_booking_events FROM PUBLIC, anon, authenticated;
GRANT ALL ON TABLE public.srk_technicians TO service_role;
GRANT ALL ON TABLE public.srk_technician_profile_links TO service_role;
GRANT ALL ON TABLE public.srk_booking_technician_assignments TO service_role;
GRANT ALL ON TABLE public.srk_technician_booking_counters TO service_role;
GRANT ALL ON TABLE public.srk_technician_completed_booking_events TO service_role;

CREATE OR REPLACE FUNCTION public.srk_record_customer_confirmed_technician_completions()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  v_assignment record;
  v_ordinal bigint;
  v_online boolean;
BEGIN
  IF NEW.status IS DISTINCT FROM 'completed'
     OR NEW.completion_approval_status IS DISTINCT FROM 'approved'
     OR NEW.customer_completed_at IS NULL THEN
    RETURN NEW;
  END IF;

  -- Do not recount an already confirmed completion if another booking field changes.
  IF OLD.status='completed'
     AND OLD.completion_approval_status='approved'
     AND OLD.customer_completed_at IS NOT NULL THEN
    RETURN NEW;
  END IF;

  v_online := lower(btrim(COALESCE(NEW.payment_method,''))) LIKE '%razorpay%'
          OR lower(btrim(COALESCE(NEW.payment_method,''))) LIKE '%online%'
          OR lower(btrim(COALESCE(NEW.payment_method,''))) LIKE '%ऑनलाइन%';

  -- Lock and process technician IDs in stable order to avoid cross-booking deadlocks.
  FOR v_assignment IN
    SELECT a.technician_id
    FROM public.srk_booking_technician_assignments a
    WHERE a.booking_id=NEW.id
      AND a.assignment_status NOT IN ('replaced','cancelled')
    ORDER BY a.technician_id
  LOOP
    IF EXISTS (
      SELECT 1 FROM public.srk_technician_completed_booking_events e
      WHERE e.technician_id=v_assignment.technician_id AND e.booking_id=NEW.id
    ) THEN
      CONTINUE;
    END IF;

    INSERT INTO public.srk_technician_booking_counters(technician_id,completed_booking_count)
    VALUES (v_assignment.technician_id,0)
    ON CONFLICT (technician_id) DO NOTHING;

    UPDATE public.srk_technician_booking_counters
       SET completed_booking_count=completed_booking_count+1,
           updated_at=clock_timestamp()
     WHERE technician_id=v_assignment.technician_id
     RETURNING completed_booking_count INTO v_ordinal;

    -- 3rd, 6th, 9th... completed jobs require an online payment method.
    -- Raising here rolls back the completion transition and counter atomically.
    IF mod(v_ordinal,3)=0 AND NOT v_online THEN
      RAISE EXCEPTION 'TECHNICIAN_EVERY_THIRD_COMPLETED_BOOKING_REQUIRES_ONLINE_PAYMENT'
        USING ERRCODE='23514';
    END IF;

    INSERT INTO public.srk_technician_completed_booking_events
      (technician_id,booking_id,completion_ordinal,customer_confirmed_at)
    VALUES
      (v_assignment.technician_id,NEW.id,v_ordinal,NEW.customer_completed_at)
    ON CONFLICT (technician_id,booking_id) DO NOTHING;

    UPDATE public.srk_booking_technician_assignments
       SET assignment_status='completed',completed_at=NEW.customer_completed_at
     WHERE booking_id=NEW.id AND technician_id=v_assignment.technician_id;
  END LOOP;

  IF NOT EXISTS (
    SELECT 1 FROM public.srk_booking_technician_assignments a
    WHERE a.booking_id=NEW.id AND a.assignment_status NOT IN ('replaced','cancelled')
  ) THEN
    RAISE EXCEPTION 'COMPLETED_BOOKING_REQUIRES_AT_LEAST_ONE_TECHNICIAN_ASSIGNMENT'
      USING ERRCODE='23514';
  END IF;

  RETURN NEW;
END;
$function$;

REVOKE ALL ON FUNCTION public.srk_record_customer_confirmed_technician_completions() FROM PUBLIC,anon,authenticated;

DROP TRIGGER IF EXISTS srk_record_customer_confirmed_technician_completions ON public.service_bookings;
CREATE TRIGGER srk_record_customer_confirmed_technician_completions
AFTER UPDATE OF status, completion_approval_status, customer_completed_at
ON public.service_bookings
FOR EACH ROW
EXECUTE FUNCTION public.srk_record_customer_confirmed_technician_completions();

CREATE OR REPLACE FUNCTION public.srk_technician_get_completed_booking_count(p_technician_id uuid)
RETURNS TABLE(completed_booking_count bigint, next_completion_requires_online boolean)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE v_count bigint;
BEGIN
  IF auth.uid() IS NULL OR p_technician_id IS NULL THEN
    RAISE EXCEPTION 'AUTHENTICATION_REQUIRED' USING ERRCODE='42501';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.srk_technicians t
    WHERE t.id=p_technician_id AND t.auth_user_id=auth.uid()
  ) AND NOT public.is_srk_admin() THEN
    RAISE EXCEPTION 'TECHNICIAN_OR_ADMIN_ACCESS_REQUIRED' USING ERRCODE='42501';
  END IF;

  SELECT COALESCE(c.completed_booking_count,0)
    INTO v_count
  FROM public.srk_technician_booking_counters c
  WHERE c.technician_id=p_technician_id;

  v_count := COALESCE(v_count,0);
  RETURN QUERY SELECT v_count, mod(v_count+1,3)=0;
END;
$function$;

REVOKE ALL ON FUNCTION public.srk_technician_get_completed_booking_count(uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.srk_technician_get_completed_booking_count(uuid) TO authenticated,service_role;
