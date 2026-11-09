-- Secure full Razorpay refund intent and reconciliation workflow.
CREATE TABLE IF NOT EXISTS public.srk_razorpay_refunds (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_id uuid NOT NULL UNIQUE REFERENCES public.service_bookings(id) ON DELETE RESTRICT,
  payment_id text NOT NULL CHECK (payment_id ~ '^pay_[A-Za-z0-9]+$'),
  refund_id text UNIQUE CHECK (refund_id IS NULL OR refund_id ~ '^rfnd_[A-Za-z0-9]+$'),
  amount numeric(12,2) NOT NULL CHECK (amount > 0 AND amount <= 10000000),
  amount_paise bigint NOT NULL CHECK (amount_paise > 0 AND amount_paise <= 1000000000),
  currency text NOT NULL DEFAULT 'INR' CHECK (currency='INR'),
  idempotency_key text NOT NULL UNIQUE CHECK (length(idempotency_key) BETWEEN 10 AND 36),
  status text NOT NULL DEFAULT 'requested' CHECK (status IN ('requested','processing','unknown','processed','failed')),
  provider_status text,
  reason text NOT NULL CHECK (length(reason) BETWEEN 20 AND 250),
  admin_user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
  previous_payout_note text,
  last_error text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  processed_at timestamptz
);
CREATE INDEX IF NOT EXISTS srk_razorpay_refunds_status_idx ON public.srk_razorpay_refunds(status,created_at DESC);
ALTER TABLE public.srk_razorpay_refunds ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.srk_razorpay_refunds FROM PUBLIC,anon,authenticated;
GRANT SELECT,INSERT,UPDATE ON TABLE public.srk_razorpay_refunds TO service_role;

ALTER TABLE public.srk_razorpay_webhook_events
  ADD COLUMN IF NOT EXISTS razorpay_refund_id text;

ALTER TABLE public.srk_admin_audit_events
  DROP CONSTRAINT IF EXISTS srk_admin_audit_events_entity_type_check;
ALTER TABLE public.srk_admin_audit_events
  ADD CONSTRAINT srk_admin_audit_events_entity_type_check
  CHECK (entity_type IN ('booking','electrician_profile','electrician_application','manual_payment','manual_refund','electrician_payout','razorpay_refund'));

CREATE OR REPLACE FUNCTION public.srk_capture_admin_audit_event()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path=pg_catalog,public,auth,pg_temp
AS $function$
DECLARE
  v_old jsonb := CASE WHEN TG_OP='INSERT' THEN '{}'::jsonb ELSE to_jsonb(OLD) END;
  v_new jsonb := CASE WHEN TG_OP='DELETE' THEN '{}'::jsonb ELSE to_jsonb(NEW) END;
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
    WHEN 'srk_razorpay_refunds' THEN 'razorpay_refund'
    ELSE NULL END;
  IF v_entity_type IS NULL THEN IF TG_OP='DELETE' THEN RETURN OLD; ELSE RETURN NEW; END IF;
  v_allow := CASE v_entity_type
    WHEN 'booking' THEN ARRAY['status','payment_status','payment_method','amount_paid','quoted_amount','quote_status','service_charge','materials_amount','assigned_electrician_id','commission_amount']
    WHEN 'electrician_profile' THEN ARRAY['active','verification_status','auth_user_id','user_id']
    WHEN 'electrician_application' THEN ARRAY['verification_status','active']
    WHEN 'manual_payment' THEN ARRAY['booking_id','payment_method','amount']
    WHEN 'manual_refund' THEN ARRAY['booking_id','payment_entry_id','amount']
    WHEN 'electrician_payout' THEN ARRAY['booking_id','payout_status','payout_method','electrician_payable','platform_commission','paid_at']
    WHEN 'razorpay_refund' THEN ARRAY['booking_id','payment_id','refund_id','amount','status','provider_status','last_error']
    ELSE ARRAY[]::text[] END;
  v_entity_id := coalesce(nullif(v_new->>'id','')::uuid,nullif(v_old->>'id','')::uuid);
  v_booking_id := CASE WHEN v_entity_type='booking' THEN v_entity_id
    ELSE coalesce(nullif(v_new->>'booking_id','')::uuid,nullif(v_old->>'booking_id','')::uuid) END;
  IF v_entity_id IS NULL THEN IF TG_OP='DELETE' THEN RETURN OLD; ELSE RETURN NEW; END IF;
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
  VALUES (v_entity_type,v_entity_id,v_booking_id,
    CASE TG_OP WHEN 'INSERT' THEN 'created' WHEN 'UPDATE' THEN 'updated' ELSE 'deleted' END,
    v_actor,v_role,v_fields,v_before,v_after);
  IF TG_OP='DELETE' THEN RETURN OLD; ELSE RETURN NEW; END IF;
END;
$function$;

DROP TRIGGER IF EXISTS srk_audit_razorpay_refunds ON public.srk_razorpay_refunds;
CREATE TRIGGER srk_audit_razorpay_refunds AFTER INSERT OR UPDATE OR DELETE ON public.srk_razorpay_refunds
FOR EACH ROW EXECUTE FUNCTION public.srk_capture_admin_audit_event();

CREATE OR REPLACE FUNCTION public.srk_admin_prepare_razorpay_refund(p_booking_id uuid,p_reason text)
RETURNS TABLE(refund_record_id uuid,booking_id uuid,payment_id text,amount_paise bigint,idempotency_key text,status text,previous_payout_note text)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path=pg_catalog,public,auth,pg_temp
AS $function$
DECLARE
  v_booking public.service_bookings%rowtype;
  v_refund public.srk_razorpay_refunds%rowtype;
  v_payout public.srk_electrician_payouts%rowtype;
  v_total numeric(12,2);
BEGIN
  IF auth.uid() IS NULL OR NOT public.is_srk_admin() THEN
    RAISE EXCEPTION 'Admin access required' USING ERRCODE='42501';
  END IF;
  IF p_booking_id IS NULL OR p_reason IS NULL OR length(btrim(p_reason)) NOT BETWEEN 20 AND 250 THEN
    RAISE EXCEPTION 'Refund reason must be 20 to 250 characters';
  END IF;
  SELECT * INTO v_booking FROM public.service_bookings WHERE id=p_booking_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Booking not found'; END IF;
  IF v_booking.payment_status<>'paid' OR v_booking.payment_verified_at IS NULL
     OR v_booking.razorpay_payment_id IS NULL OR v_booking.amount_paid IS NULL
     OR v_booking.amount_paid<=0 OR v_booking.quote_status<>'approved' THEN
    RAISE EXCEPTION 'Only verified Razorpay-paid bookings can be refunded';
  END IF;
  IF v_booking.razorpay_payment_id !~ '^pay_[A-Za-z0-9]+$' THEN
    RAISE EXCEPTION 'Invalid Razorpay payment ID';
  END IF;
  v_total:=round(v_booking.amount_paid,2);
  IF v_booking.quoted_amount IS NULL OR v_booking.service_charge IS NULL OR v_booking.materials_amount IS NULL
     OR v_total<>round(v_booking.quoted_amount,2)
     OR v_total<>round(v_booking.service_charge+v_booking.materials_amount,2) THEN
    RAISE EXCEPTION 'Paid amount does not match approved quote';
  END IF;

  SELECT * INTO v_refund FROM public.srk_razorpay_refunds WHERE booking_id=p_booking_id FOR UPDATE;
  IF FOUND THEN
    IF v_refund.status='failed' THEN RAISE EXCEPTION 'Previous Razorpay refund failed; reconcile before creating another request'; END IF;
    RETURN QUERY SELECT v_refund.id,v_refund.booking_id,v_refund.payment_id,v_refund.amount_paise,v_refund.idempotency_key,v_refund.status,v_refund.previous_payout_note;
    RETURN;
  END IF;

  SELECT * INTO v_payout FROM public.srk_electrician_payouts WHERE booking_id=p_booking_id FOR UPDATE;
  IF FOUND THEN
    IF v_payout.payout_status='paid' THEN
      RAISE EXCEPTION 'Electrician payout is already paid; recovery requires separate Admin reconciliation';
    END IF;
    IF v_payout.payout_status<>'pending' THEN
      RAISE EXCEPTION 'Electrician payout is not pending; reconcile payout before refund';
    END IF;
    UPDATE public.srk_electrician_payouts
      SET payout_status='blocked',payout_note='Razorpay refund pending',updated_at=now()
      WHERE id=v_payout.id;
  END IF;

  INSERT INTO public.srk_razorpay_refunds
    (booking_id,payment_id,amount,amount_paise,idempotency_key,status,reason,admin_user_id,previous_payout_note)
  VALUES
    (p_booking_id,v_booking.razorpay_payment_id,v_total,round(v_total*100)::bigint,
     replace(gen_random_uuid()::text,'-',''), 'requested',btrim(p_reason),auth.uid(),v_payout.payout_note)
  RETURNING * INTO v_refund;
  RETURN QUERY SELECT v_refund.id,v_refund.booking_id,v_refund.payment_id,v_refund.amount_paise,v_refund.idempotency_key,v_refund.status,v_refund.previous_payout_note;
END;
$function$;
REVOKE ALL ON FUNCTION public.srk_admin_prepare_razorpay_refund(uuid,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.srk_admin_prepare_razorpay_refund(uuid,text) TO authenticated;

CREATE OR REPLACE FUNCTION public.srk_admin_list_razorpay_refunds(p_limit integer DEFAULT 100)
RETURNS TABLE(id uuid,booking_id uuid,payment_id text,refund_id text,amount numeric,status text,provider_status text,reason text,last_error text,created_at timestamptz,updated_at timestamptz,processed_at timestamptz)
LANGUAGE plpgsql
STABLE SECURITY DEFINER
SET search_path=pg_catalog,public,auth,pg_temp
AS $function$
BEGIN
  IF auth.uid() IS NULL OR NOT public.is_srk_admin() THEN
    RAISE EXCEPTION 'Admin access required' USING ERRCODE='42501';
  END IF;
  RETURN QUERY SELECT r.id,r.booking_id,r.payment_id,r.refund_id,r.amount,r.status,r.provider_status,r.reason,r.last_error,r.created_at,r.updated_at,r.processed_at
  FROM public.srk_razorpay_refunds r ORDER BY r.created_at DESC
  LIMIT greatest(1,least(coalesce(p_limit,100),200));
END;
$function$;
REVOKE ALL ON FUNCTION public.srk_admin_list_razorpay_refunds(integer) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.srk_admin_list_razorpay_refunds(integer) TO authenticated;
