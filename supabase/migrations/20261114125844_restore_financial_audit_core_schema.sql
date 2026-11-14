-- Restore finance/refund/audit base relations before their first consumers.
-- Ordered before 20261114190000 and 20261114200000 because receipt/history RPCs
-- reference these relations. Feature-branch source only; do not apply to Production.

-- The receipt RPC is earlier than the work-timer migration that originally
-- introduced this immutable bill table. Keep the later IF NOT EXISTS definition compatible.
CREATE TABLE IF NOT EXISTS public.srk_booking_labour_bills (
  booking_id uuid PRIMARY KEY REFERENCES public.service_bookings(id) ON DELETE RESTRICT,
  customer_user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
  electrician_profile_id uuid NOT NULL REFERENCES public.electrician_profiles(id) ON DELETE RESTRICT,
  customer_work_category text NOT NULL CHECK (customer_work_category IN (
    'home_wiring','electrical_repair','light_fan_fitting','home_repair','other'
  )),
  approved_rate_tier text NOT NULL CHECK (approved_rate_tier IN (
    'electrical_assistant','skilled_electrician','expert_electrician',
    'premium_electrical_specialist'
  )),
  rate_card_version text NOT NULL,
  rate8h_paise bigint NOT NULL CHECK (rate8h_paise IN (89900,119900,159900,199900)),
  elapsed_seconds numeric(24,6) NOT NULL CHECK (elapsed_seconds>0),
  billable_minutes bigint NOT NULL CHECK (billable_minutes>0),
  labour_amount_paise numeric(24,0) NOT NULL CHECK (labour_amount_paise>0),
  labour_amount numeric(18,2) NOT NULL CHECK (labour_amount>0),
  created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  CHECK (labour_amount=labour_amount_paise/100.0)
);

CREATE TABLE IF NOT EXISTS public.srk_manual_payment_entries (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_id uuid NOT NULL REFERENCES public.service_bookings(id) ON DELETE RESTRICT,
  payment_method text NOT NULL CHECK (payment_method IN ('cash','upi','bank_transfer')),
  amount numeric(18,2) NOT NULL CHECK (amount>0 AND amount<=10000000),
  payment_reference text NOT NULL CHECK (char_length(btrim(payment_reference)) BETWEEN 4 AND 120),
  note text CHECK (note IS NULL OR char_length(note)<=250),
  recorded_by uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
  recorded_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT srk_manual_payment_entries_booking_id_key UNIQUE (booking_id)
);

CREATE TABLE IF NOT EXISTS public.srk_electrician_payouts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_id uuid NOT NULL REFERENCES public.service_bookings(id) ON DELETE RESTRICT,
  electrician_profile_id uuid NOT NULL REFERENCES public.electrician_profiles(id) ON DELETE RESTRICT,
  razorpay_payment_id text,
  gross_service_amount numeric(18,2) NOT NULL CHECK (gross_service_amount>=0),
  materials_amount numeric(18,2) NOT NULL CHECK (materials_amount>=0),
  platform_commission numeric(18,2) NOT NULL CHECK (platform_commission>=0),
  electrician_payable numeric(18,2) NOT NULL CHECK (electrician_payable>=0),
  payout_status text NOT NULL DEFAULT 'pending'
    CHECK (payout_status IN ('pending','paid','blocked','refunded')),
  payout_method text CHECK (payout_method IN ('upi','bank')),
  payout_reference text,
  payout_note text,
  paid_by uuid REFERENCES auth.users(id),
  paid_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT srk_electrician_payouts_booking_id_key UNIQUE (booking_id),
  CONSTRAINT srk_payout_paid_fields_check CHECK (
    payout_status<>'paid' OR (
      payout_method IS NOT NULL AND payout_reference IS NOT NULL
      AND char_length(btrim(payout_reference))>=4
      AND paid_at IS NOT NULL AND paid_by IS NOT NULL
    )
  )
);

CREATE TABLE IF NOT EXISTS public.srk_admin_audit_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  entity_type text NOT NULL CHECK (entity_type IN (
    'booking','electrician_profile','electrician_application',
    'manual_payment','manual_refund','electrician_payout','razorpay_refund'
  )),
  entity_id uuid NOT NULL,
  booking_id uuid,
  action text NOT NULL CHECK (action IN ('created','updated','deleted')),
  actor_user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  actor_role text NOT NULL CHECK (actor_role IN ('admin','user','system')),
  changed_fields text[] NOT NULL DEFAULT ARRAY[]::text[],
  before_data jsonb NOT NULL DEFAULT '{}'::jsonb,
  after_data jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.srk_razorpay_refunds (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_id uuid NOT NULL REFERENCES public.service_bookings(id) ON DELETE RESTRICT,
  payment_id text NOT NULL CHECK (payment_id ~ '^pay_[A-Za-z0-9]+$'),
  refund_id text UNIQUE CHECK (refund_id IS NULL OR refund_id ~ '^rfnd_[A-Za-z0-9]+$'),
  amount numeric(18,2) NOT NULL CHECK (amount>0 AND amount<=10000000),
  amount_paise bigint NOT NULL CHECK (amount_paise>0 AND amount_paise<=1000000000),
  currency text NOT NULL DEFAULT 'INR' CHECK (currency='INR'),
  idempotency_key text NOT NULL UNIQUE CHECK (char_length(idempotency_key) BETWEEN 10 AND 36),
  status text NOT NULL DEFAULT 'requested'
    CHECK (status IN ('requested','processing','unknown','processed','failed')),
  provider_status text,
  reason text NOT NULL CHECK (char_length(reason) BETWEEN 20 AND 250),
  admin_user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
  previous_payout_note text,
  last_error text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  processed_at timestamptz,
  CONSTRAINT srk_razorpay_refunds_booking_id_key UNIQUE (booking_id)
);

CREATE TABLE IF NOT EXISTS public.srk_booking_refund_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_id uuid NOT NULL REFERENCES public.service_bookings(id) ON DELETE RESTRICT,
  customer_user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
  amount numeric(18,2) NOT NULL CHECK (amount>0 AND amount<=10000000),
  reason text NOT NULL CHECK (char_length(btrim(reason)) BETWEEN 20 AND 1000),
  status text NOT NULL DEFAULT 'requested'
    CHECK (status IN ('requested','in_review','approved','rejected','processing','unknown','processed')),
  admin_note text CHECK (admin_note IS NULL OR char_length(admin_note)<=2000),
  refund_record_id uuid UNIQUE REFERENCES public.srk_razorpay_refunds(id) ON DELETE RESTRICT,
  decided_by uuid REFERENCES auth.users(id) ON DELETE RESTRICT,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  processed_at timestamptz,
  CONSTRAINT srk_booking_refund_requests_booking_id_key UNIQUE (booking_id)
);

CREATE TABLE IF NOT EXISTS public.srk_manual_refund_entries (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_id uuid NOT NULL REFERENCES public.service_bookings(id) ON DELETE RESTRICT,
  payment_entry_id uuid NOT NULL REFERENCES public.srk_manual_payment_entries(id) ON DELETE RESTRICT,
  amount numeric(18,2) NOT NULL CHECK (amount>0 AND amount<=10000000),
  refund_reference text NOT NULL CHECK (char_length(btrim(refund_reference)) BETWEEN 4 AND 120),
  note text CHECK (note IS NULL OR char_length(note)<=250),
  recorded_by uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
  recorded_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT srk_manual_refund_entries_booking_id_key UNIQUE (booking_id),
  CONSTRAINT srk_manual_refund_entries_payment_entry_id_key UNIQUE (payment_entry_id)
);

ALTER TABLE public.srk_booking_labour_bills ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.srk_manual_payment_entries ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.srk_electrician_payouts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.srk_admin_audit_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.srk_razorpay_refunds ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.srk_booking_refund_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.srk_manual_refund_entries ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE public.srk_booking_labour_bills FROM PUBLIC,anon,authenticated;
REVOKE ALL ON TABLE public.srk_manual_payment_entries FROM PUBLIC,anon,authenticated;
REVOKE ALL ON TABLE public.srk_electrician_payouts FROM PUBLIC,anon,authenticated;
REVOKE ALL ON TABLE public.srk_admin_audit_events FROM PUBLIC,anon,authenticated;
REVOKE ALL ON TABLE public.srk_razorpay_refunds FROM PUBLIC,anon,authenticated;
REVOKE ALL ON TABLE public.srk_booking_refund_requests FROM PUBLIC,anon,authenticated;
REVOKE ALL ON TABLE public.srk_manual_refund_entries FROM PUBLIC,anon,authenticated;

GRANT ALL ON TABLE public.srk_booking_labour_bills TO service_role;
GRANT ALL ON TABLE public.srk_manual_payment_entries TO service_role;
GRANT ALL ON TABLE public.srk_electrician_payouts TO service_role;
GRANT ALL ON TABLE public.srk_admin_audit_events TO service_role;
GRANT ALL ON TABLE public.srk_razorpay_refunds TO service_role;
GRANT ALL ON TABLE public.srk_booking_refund_requests TO service_role;
GRANT ALL ON TABLE public.srk_manual_refund_entries TO service_role;
GRANT SELECT ON TABLE public.srk_electrician_payouts TO authenticated;

DROP POLICY IF EXISTS srk_read_authorized_electrician_payouts ON public.srk_electrician_payouts;
CREATE POLICY srk_read_authorized_electrician_payouts
  ON public.srk_electrician_payouts FOR SELECT TO authenticated
  USING (
    (SELECT public.is_srk_admin())
    OR EXISTS (
      SELECT 1 FROM public.electrician_profiles ep
      WHERE ep.id=srk_electrician_payouts.electrician_profile_id
        AND ep.user_id=(SELECT auth.uid())
    )
  );

CREATE INDEX IF NOT EXISTS srk_electrician_payouts_electrician_profile_id_idx
  ON public.srk_electrician_payouts(electrician_profile_id);
CREATE INDEX IF NOT EXISTS srk_electrician_payouts_status_idx
  ON public.srk_electrician_payouts(payout_status,created_at DESC);
CREATE INDEX IF NOT EXISTS srk_electrician_payouts_paid_at_idx
  ON public.srk_electrician_payouts(paid_at DESC)
  WHERE payout_status='paid' AND paid_at IS NOT NULL;
CREATE INDEX IF NOT EXISTS srk_electrician_payouts_paid_by_idx
  ON public.srk_electrician_payouts(paid_by);
CREATE INDEX IF NOT EXISTS srk_admin_audit_booking_idx
  ON public.srk_admin_audit_events(booking_id,created_at DESC)
  WHERE booking_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS srk_admin_audit_created_idx
  ON public.srk_admin_audit_events(created_at DESC);
CREATE INDEX IF NOT EXISTS srk_admin_audit_entity_idx
  ON public.srk_admin_audit_events(entity_type,entity_id,created_at DESC);
CREATE INDEX IF NOT EXISTS srk_razorpay_refunds_status_created_idx
  ON public.srk_razorpay_refunds(status,created_at DESC);
CREATE INDEX IF NOT EXISTS srk_booking_refund_requests_status_created_idx
  ON public.srk_booking_refund_requests(status,created_at DESC);

-- Production's historical allow-list omitted razorpay_refund even though the
-- refund audit trigger emits it. Correct the check to avoid blocking refunds.
ALTER TABLE public.srk_admin_audit_events
  DROP CONSTRAINT IF EXISTS srk_admin_audit_events_entity_type_check;
ALTER TABLE public.srk_admin_audit_events
  ADD CONSTRAINT srk_admin_audit_events_entity_type_check
  CHECK (entity_type IN (
    'booking','electrician_profile','electrician_application',
    'manual_payment','manual_refund','electrician_payout','razorpay_refund'
  ));

CREATE OR REPLACE FUNCTION public.srk_capture_admin_audit_event()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path=''
AS $function$
DECLARE
  v_old jsonb := CASE WHEN TG_OP='INSERT' THEN '{}'::jsonb ELSE pg_catalog.to_jsonb(OLD) END;
  v_new jsonb := CASE WHEN TG_OP='DELETE' THEN '{}'::jsonb ELSE pg_catalog.to_jsonb(NEW) END;
  v_before jsonb := '{}'::jsonb;
  v_after jsonb := '{}'::jsonb;
  v_fields text[] := ARRAY[]::text[];
  v_key text;
  v_entity_type text;
  v_entity_id uuid;
  v_booking_id uuid;
  v_actor uuid := auth.uid();
  v_role text;
  v_allow text[];
BEGIN
  v_entity_type := CASE TG_TABLE_NAME
    WHEN 'service_bookings' THEN 'booking'
    WHEN 'electrician_profiles' THEN 'electrician_profile'
    WHEN 'electrician_applications' THEN 'electrician_application'
    WHEN 'srk_manual_payment_entries' THEN 'manual_payment'
    WHEN 'srk_manual_refund_entries' THEN 'manual_refund'
    WHEN 'srk_electrician_payouts' THEN 'electrician_payout'
    ELSE NULL END;
  IF v_entity_type IS NULL THEN
    IF TG_OP='DELETE' THEN RETURN OLD; ELSE RETURN NEW; END IF;
  END IF;
  v_allow := CASE v_entity_type
    WHEN 'booking' THEN ARRAY['status','payment_status','payment_method','amount_paid','quoted_amount','quote_status','service_charge','materials_amount','assigned_electrician_id','commission_amount']
    WHEN 'electrician_profile' THEN ARRAY['active','verification_status','auth_user_id','user_id']
    WHEN 'electrician_application' THEN ARRAY['verification_status','active']
    WHEN 'manual_payment' THEN ARRAY['booking_id','payment_method','amount']
    WHEN 'manual_refund' THEN ARRAY['booking_id','payment_entry_id','amount']
    WHEN 'electrician_payout' THEN ARRAY['booking_id','payout_status','payout_method','payout_reference','payout_note','electrician_payable','platform_commission','paid_at']
    ELSE ARRAY[]::text[] END;
  v_entity_id := coalesce(nullif(v_new->>'id','')::uuid,nullif(v_old->>'id','')::uuid);
  v_booking_id := CASE WHEN v_entity_type='booking' THEN v_entity_id
    ELSE coalesce(nullif(v_new->>'booking_id','')::uuid,nullif(v_old->>'booking_id','')::uuid) END;
  IF v_entity_id IS NULL THEN
    IF TG_OP='DELETE' THEN RETURN OLD; ELSE RETURN NEW; END IF;
  END IF;
  FOREACH v_key IN ARRAY v_allow LOOP
    IF v_old->v_key IS DISTINCT FROM v_new->v_key THEN
      v_fields := pg_catalog.array_append(v_fields,v_key);
      IF v_old ? v_key THEN v_before := v_before || pg_catalog.jsonb_build_object(v_key,v_old->v_key); END IF;
      IF v_new ? v_key THEN v_after := v_after || pg_catalog.jsonb_build_object(v_key,v_new->v_key); END IF;
    END IF;
  END LOOP;
  IF pg_catalog.cardinality(v_fields)=0 THEN
    IF TG_OP='DELETE' THEN RETURN OLD; ELSE RETURN NEW; END IF;
  END IF;
  v_role := CASE WHEN v_actor IS NULL THEN 'system'
    WHEN public.is_srk_admin() THEN 'admin' ELSE 'user' END;
  INSERT INTO public.srk_admin_audit_events
    (entity_type,entity_id,booking_id,action,actor_user_id,actor_role,changed_fields,before_data,after_data)
  VALUES (v_entity_type,v_entity_id,v_booking_id,
    CASE TG_OP WHEN 'INSERT' THEN 'created' WHEN 'UPDATE' THEN 'updated' ELSE 'deleted' END,
    v_actor,v_role,v_fields,v_before,v_after);
  IF TG_OP='DELETE' THEN RETURN OLD; ELSE RETURN NEW; END IF;
END;
$function$;

CREATE OR REPLACE FUNCTION public.srk_capture_razorpay_refund_audit_event()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path=''
AS $function$
DECLARE
  v_entity_id uuid;
  v_booking_id uuid;
  v_before jsonb := '{}'::jsonb;
  v_after jsonb := '{}'::jsonb;
  v_fields text[] := ARRAY[]::text[];
  v_actor uuid := auth.uid();
  v_role text;
BEGIN
  IF TG_OP='DELETE' THEN
    v_entity_id:=OLD.id; v_booking_id:=OLD.booking_id;
    v_before:=pg_catalog.jsonb_build_object('refund_id',OLD.refund_id,'amount',OLD.amount,'status',OLD.status,'provider_status',OLD.provider_status);
    v_fields:=ARRAY['refund_id','amount','status','provider_status'];
  ELSIF TG_OP='INSERT' THEN
    v_entity_id:=NEW.id; v_booking_id:=NEW.booking_id;
    v_after:=pg_catalog.jsonb_build_object('refund_id',NEW.refund_id,'amount',NEW.amount,'status',NEW.status,'provider_status',NEW.provider_status);
    v_fields:=ARRAY['refund_id','amount','status','provider_status'];
  ELSE
    v_entity_id:=NEW.id; v_booking_id:=NEW.booking_id;
    IF OLD.refund_id IS DISTINCT FROM NEW.refund_id THEN
      v_fields:=pg_catalog.array_append(v_fields,'refund_id');
      v_before:=v_before||pg_catalog.jsonb_build_object('refund_id',OLD.refund_id);
      v_after:=v_after||pg_catalog.jsonb_build_object('refund_id',NEW.refund_id);
    END IF;
    IF OLD.amount IS DISTINCT FROM NEW.amount THEN
      v_fields:=pg_catalog.array_append(v_fields,'amount');
      v_before:=v_before||pg_catalog.jsonb_build_object('amount',OLD.amount);
      v_after:=v_after||pg_catalog.jsonb_build_object('amount',NEW.amount);
    END IF;
    IF OLD.status IS DISTINCT FROM NEW.status THEN
      v_fields:=pg_catalog.array_append(v_fields,'status');
      v_before:=v_before||pg_catalog.jsonb_build_object('status',OLD.status);
      v_after:=v_after||pg_catalog.jsonb_build_object('status',NEW.status);
    END IF;
    IF OLD.provider_status IS DISTINCT FROM NEW.provider_status THEN
      v_fields:=pg_catalog.array_append(v_fields,'provider_status');
      v_before:=v_before||pg_catalog.jsonb_build_object('provider_status',OLD.provider_status);
      v_after:=v_after||pg_catalog.jsonb_build_object('provider_status',NEW.provider_status);
    END IF;
  END IF;
  IF pg_catalog.cardinality(v_fields)>0 THEN
    v_role:=CASE WHEN v_actor IS NULL THEN 'system'
      WHEN public.is_srk_admin() THEN 'admin' ELSE 'user' END;
    INSERT INTO public.srk_admin_audit_events
      (entity_type,entity_id,booking_id,action,actor_user_id,actor_role,changed_fields,before_data,after_data)
    VALUES ('razorpay_refund',v_entity_id,v_booking_id,
      CASE TG_OP WHEN 'INSERT' THEN 'created' WHEN 'UPDATE' THEN 'updated' ELSE 'deleted' END,
      v_actor,v_role,v_fields,v_before,v_after);
  END IF;
  IF TG_OP='DELETE' THEN RETURN OLD; ELSE RETURN NEW; END IF;
END;
$function$;

REVOKE ALL ON FUNCTION public.srk_capture_admin_audit_event() FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.srk_capture_razorpay_refund_audit_event() FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.srk_capture_admin_audit_event() TO service_role;
GRANT EXECUTE ON FUNCTION public.srk_capture_razorpay_refund_audit_event() TO service_role;

DROP TRIGGER IF EXISTS srk_audit_service_bookings ON public.service_bookings;
CREATE TRIGGER srk_audit_service_bookings AFTER INSERT OR UPDATE OR DELETE
  ON public.service_bookings FOR EACH ROW EXECUTE FUNCTION public.srk_capture_admin_audit_event();
DROP TRIGGER IF EXISTS srk_audit_electrician_profiles ON public.electrician_profiles;
CREATE TRIGGER srk_audit_electrician_profiles AFTER INSERT OR UPDATE OR DELETE
  ON public.electrician_profiles FOR EACH ROW EXECUTE FUNCTION public.srk_capture_admin_audit_event();
DROP TRIGGER IF EXISTS srk_audit_electrician_applications ON public.electrician_applications;
CREATE TRIGGER srk_audit_electrician_applications AFTER INSERT OR UPDATE OR DELETE
  ON public.electrician_applications FOR EACH ROW EXECUTE FUNCTION public.srk_capture_admin_audit_event();
DROP TRIGGER IF EXISTS srk_audit_manual_payment_entries ON public.srk_manual_payment_entries;
CREATE TRIGGER srk_audit_manual_payment_entries AFTER INSERT OR UPDATE OR DELETE
  ON public.srk_manual_payment_entries FOR EACH ROW EXECUTE FUNCTION public.srk_capture_admin_audit_event();
DROP TRIGGER IF EXISTS srk_audit_manual_refund_entries ON public.srk_manual_refund_entries;
CREATE TRIGGER srk_audit_manual_refund_entries AFTER INSERT OR UPDATE OR DELETE
  ON public.srk_manual_refund_entries FOR EACH ROW EXECUTE FUNCTION public.srk_capture_admin_audit_event();
DROP TRIGGER IF EXISTS srk_audit_electrician_payouts ON public.srk_electrician_payouts;
CREATE TRIGGER srk_audit_electrician_payouts AFTER INSERT OR UPDATE OR DELETE
  ON public.srk_electrician_payouts FOR EACH ROW EXECUTE FUNCTION public.srk_capture_admin_audit_event();
DROP TRIGGER IF EXISTS srk_audit_razorpay_refunds ON public.srk_razorpay_refunds;
CREATE TRIGGER srk_audit_razorpay_refunds AFTER INSERT OR UPDATE OR DELETE
  ON public.srk_razorpay_refunds FOR EACH ROW EXECUTE FUNCTION public.srk_capture_razorpay_refund_audit_event();

