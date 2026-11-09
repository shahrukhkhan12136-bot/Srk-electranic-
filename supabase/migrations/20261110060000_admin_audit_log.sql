-- Admin/system audit trail for sensitive SRK operations.
-- Stores only allowlisted status/financial fields; never names, phone, addresses, OTPs, tokens or payment references.
CREATE TABLE IF NOT EXISTS public.srk_admin_audit_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  entity_type text NOT NULL CHECK (entity_type IN ('booking','electrician_profile','electrician_application','manual_payment','manual_refund','electrician_payout')),
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
CREATE INDEX IF NOT EXISTS srk_admin_audit_created_idx ON public.srk_admin_audit_events(created_at DESC);
CREATE INDEX IF NOT EXISTS srk_admin_audit_entity_idx ON public.srk_admin_audit_events(entity_type,entity_id,created_at DESC);
CREATE INDEX IF NOT EXISTS srk_admin_audit_booking_idx ON public.srk_admin_audit_events(booking_id,created_at DESC) WHERE booking_id IS NOT NULL;
ALTER TABLE public.srk_admin_audit_events ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.srk_admin_audit_events FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION public.srk_capture_admin_audit_event()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path=pg_catalog,public,auth,pg_temp
AS $function$
DECLARE
  v_old jsonb := CASE WHEN TG_OP='INSERT' THEN '{}'::jsonb ELSE to_jsonb(OLD) END;
  v_new jsonb := CASE WHEN TG_OP='DELETE' THEN '{}'::jsonb ELSE to_jsonb(NEW) END;
  v_data jsonb;
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
  IF v_entity_type IS NULL THEN IF TG_OP='DELETE' THEN RETURN OLD; ELSE RETURN NEW; END IF; END IF;

  v_allow := CASE v_entity_type
    WHEN 'booking' THEN ARRAY['status','payment_status','payment_method','amount_paid','quoted_amount','quote_status','service_charge','materials_amount','assigned_electrician_id','commission_amount']
    WHEN 'electrician_profile' THEN ARRAY['active','verification_status','auth_user_id','user_id']
    WHEN 'electrician_application' THEN ARRAY['verification_status','active']
    WHEN 'manual_payment' THEN ARRAY['booking_id','payment_method','amount']
    WHEN 'manual_refund' THEN ARRAY['booking_id','payment_entry_id','amount']
    WHEN 'electrician_payout' THEN ARRAY['booking_id','payout_status','payout_method','electrician_payable','platform_commission','paid_at']
    ELSE ARRAY[]::text[] END;

  v_entity_id := coalesce(nullif(v_new->>'id','')::uuid,nullif(v_old->>'id','')::uuid);
  v_booking_id := CASE WHEN v_entity_type='booking' THEN v_entity_id
    ELSE coalesce(nullif(v_new->>'booking_id','')::uuid,nullif(v_old->>'booking_id','')::uuid) END;
  IF v_entity_id IS NULL THEN IF TG_OP='DELETE' THEN RETURN OLD; ELSE RETURN NEW; END IF; END IF;

  FOREACH v_key IN ARRAY v_allow LOOP
    IF v_old->v_key IS DISTINCT FROM v_new->v_key THEN
      v_fields := array_append(v_fields,v_key);
      IF v_old ? v_key THEN v_before := v_before || jsonb_build_object(v_key,v_old->v_key); END IF;
      IF v_new ? v_key THEN v_after := v_after || jsonb_build_object(v_key,v_new->v_key); END IF;
    END IF;
  END LOOP;
  IF cardinality(v_fields)=0 THEN IF TG_OP='DELETE' THEN RETURN OLD; ELSE RETURN NEW; END IF; END IF;

  v_role := CASE WHEN v_actor IS NULL THEN 'system'
    WHEN public.is_srk_admin() THEN 'admin' ELSE 'user' END;
  INSERT INTO public.srk_admin_audit_events
    (entity_type,entity_id,booking_id,action,actor_user_id,actor_role,changed_fields,before_data,after_data)
  VALUES
    (v_entity_type,v_entity_id,v_booking_id,
     CASE TG_OP WHEN 'INSERT' THEN 'created' WHEN 'UPDATE' THEN 'updated' ELSE 'deleted' END,
     v_actor,v_role,v_fields,v_before,v_after);
  IF TG_OP='DELETE' THEN RETURN OLD; ELSE RETURN NEW; END IF;
END;
$function$;
REVOKE ALL ON FUNCTION public.srk_capture_admin_audit_event() FROM PUBLIC,anon,authenticated;

DROP TRIGGER IF EXISTS srk_audit_service_bookings ON public.service_bookings;
CREATE TRIGGER srk_audit_service_bookings AFTER INSERT OR UPDATE OR DELETE ON public.service_bookings
FOR EACH ROW EXECUTE FUNCTION public.srk_capture_admin_audit_event();
DROP TRIGGER IF EXISTS srk_audit_electrician_profiles ON public.electrician_profiles;
CREATE TRIGGER srk_audit_electrician_profiles AFTER INSERT OR UPDATE OR DELETE ON public.electrician_profiles
FOR EACH ROW EXECUTE FUNCTION public.srk_capture_admin_audit_event();
DROP TRIGGER IF EXISTS srk_audit_electrician_applications ON public.electrician_applications;
CREATE TRIGGER srk_audit_electrician_applications AFTER INSERT OR UPDATE OR DELETE ON public.electrician_applications
FOR EACH ROW EXECUTE FUNCTION public.srk_capture_admin_audit_event();
DROP TRIGGER IF EXISTS srk_audit_manual_payment_entries ON public.srk_manual_payment_entries;
CREATE TRIGGER srk_audit_manual_payment_entries AFTER INSERT OR UPDATE OR DELETE ON public.srk_manual_payment_entries
FOR EACH ROW EXECUTE FUNCTION public.srk_capture_admin_audit_event();
DROP TRIGGER IF EXISTS srk_audit_manual_refund_entries ON public.srk_manual_refund_entries;
CREATE TRIGGER srk_audit_manual_refund_entries AFTER INSERT OR UPDATE OR DELETE ON public.srk_manual_refund_entries
FOR EACH ROW EXECUTE FUNCTION public.srk_capture_admin_audit_event();
DROP TRIGGER IF EXISTS srk_audit_electrician_payouts ON public.srk_electrician_payouts;
CREATE TRIGGER srk_audit_electrician_payouts AFTER INSERT OR UPDATE OR DELETE ON public.srk_electrician_payouts
FOR EACH ROW EXECUTE FUNCTION public.srk_capture_admin_audit_event();

CREATE OR REPLACE FUNCTION public.srk_admin_list_audit_events(p_limit integer DEFAULT 100)
RETURNS TABLE (
  id uuid, entity_type text, entity_id uuid, booking_id uuid, action text,
  actor_user_id uuid, actor_role text, changed_fields text[],
  before_data jsonb, after_data jsonb, created_at timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path=pg_catalog,public,auth,pg_temp
AS $function$
BEGIN
  IF auth.uid() IS NULL OR NOT public.is_srk_admin() THEN
    RAISE EXCEPTION 'Admin access required' USING ERRCODE='42501';
  END IF;
  RETURN QUERY
  SELECT e.id,e.entity_type,e.entity_id,e.booking_id,e.action,e.actor_user_id,
         e.actor_role,e.changed_fields,e.before_data,e.after_data,e.created_at
  FROM public.srk_admin_audit_events e
  ORDER BY e.created_at DESC
  LIMIT greatest(1,least(coalesce(p_limit,100),200));
END;
$function$;
REVOKE ALL ON FUNCTION public.srk_admin_list_audit_events(integer) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.srk_admin_list_audit_events(integer) TO authenticated;
