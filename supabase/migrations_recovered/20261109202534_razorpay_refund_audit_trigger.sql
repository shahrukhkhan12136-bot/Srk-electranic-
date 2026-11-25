CREATE OR REPLACE FUNCTION public.srk_capture_razorpay_refund_audit_event()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path=pg_catalog,public,auth,pg_temp
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
    v_entity_id := OLD.id;
    v_booking_id := OLD.booking_id;
    v_before := jsonb_build_object('refund_id',OLD.refund_id,'amount',OLD.amount,'status',OLD.status,'provider_status',OLD.provider_status);
    v_fields := ARRAY['refund_id','amount','status','provider_status'];
  ELSIF TG_OP='INSERT' THEN
    v_entity_id := NEW.id;
    v_booking_id := NEW.booking_id;
    v_after := jsonb_build_object('refund_id',NEW.refund_id,'amount',NEW.amount,'status',NEW.status,'provider_status',NEW.provider_status);
    v_fields := ARRAY['refund_id','amount','status','provider_status'];
  ELSE
    v_entity_id := NEW.id;
    v_booking_id := NEW.booking_id;
    IF OLD.refund_id IS DISTINCT FROM NEW.refund_id THEN
      v_fields := array_append(v_fields,'refund_id');
      v_before := v_before || jsonb_build_object('refund_id',OLD.refund_id);
      v_after := v_after || jsonb_build_object('refund_id',NEW.refund_id);
    END IF;
    IF OLD.amount IS DISTINCT FROM NEW.amount THEN
      v_fields := array_append(v_fields,'amount');
      v_before := v_before || jsonb_build_object('amount',OLD.amount);
      v_after := v_after || jsonb_build_object('amount',NEW.amount);
    END IF;
    IF OLD.status IS DISTINCT FROM NEW.status THEN
      v_fields := array_append(v_fields,'status');
      v_before := v_before || jsonb_build_object('status',OLD.status);
      v_after := v_after || jsonb_build_object('status',NEW.status);
    END IF;
    IF OLD.provider_status IS DISTINCT FROM NEW.provider_status THEN
      v_fields := array_append(v_fields,'provider_status');
      v_before := v_before || jsonb_build_object('provider_status',OLD.provider_status);
      v_after := v_after || jsonb_build_object('provider_status',NEW.provider_status);
    END IF;
  END IF;
  IF cardinality(v_fields)>0 THEN
    v_role := CASE WHEN v_actor IS NULL THEN 'system'
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
REVOKE ALL ON FUNCTION public.srk_capture_razorpay_refund_audit_event() FROM PUBLIC,anon,authenticated;

DROP TRIGGER IF EXISTS srk_audit_razorpay_refunds ON public.srk_razorpay_refunds;
CREATE TRIGGER srk_audit_razorpay_refunds AFTER INSERT OR UPDATE OR DELETE ON public.srk_razorpay_refunds
FOR EACH ROW EXECUTE FUNCTION public.srk_capture_razorpay_refund_audit_event();