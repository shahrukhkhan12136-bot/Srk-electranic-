
CREATE OR REPLACE FUNCTION public.srk_log_admin_entity_change()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'pg_catalog','public','auth','pg_temp'
AS $function$
DECLARE
  v_old jsonb;
  v_new jsonb;
  v_id uuid;
  v_booking uuid;
  v_changed text[];
  v_actor_role text;
  v_reason text;
  v_key text;
BEGIN
  IF auth.uid() IS NULL THEN
    IF TG_OP='DELETE' THEN RETURN OLD; ELSE RETURN NEW; END IF;
  END IF;

  IF NOT EXISTS(SELECT 1 FROM public.srk_admin_users WHERE user_id=auth.uid())
     AND NOT EXISTS(SELECT 1 FROM public.srk_admin_staff_members WHERE user_id=auth.uid() AND is_active) THEN
    IF TG_OP='DELETE' THEN RETURN OLD; ELSE RETURN NEW; END IF;
  END IF;

  v_old:=CASE WHEN TG_OP IN ('UPDATE','DELETE') THEN to_jsonb(OLD) ELSE '{}'::jsonb END;
  v_new:=CASE WHEN TG_OP IN ('INSERT','UPDATE') THEN to_jsonb(NEW) ELSE '{}'::jsonb END;

  v_key:=coalesce(
    v_new->>'setting_key',v_old->>'setting_key',
    v_new->>'role_code',v_old->>'role_code',
    CASE WHEN TG_TABLE_NAME='srk_admin_role_permissions'
      THEN coalesce(v_new->>'role_id',v_old->>'role_id','')||':'||
           coalesce(v_new->>'permission_code',v_old->>'permission_code','')
      ELSE NULL END,
    'unknown'
  );

  v_id:=coalesce(
    nullif(v_new->>'id','')::uuid,
    nullif(v_old->>'id','')::uuid,
    nullif(v_new->>'user_id','')::uuid,
    nullif(v_old->>'user_id','')::uuid,
    md5(v_key)::uuid
  );
  v_booking:=coalesce(nullif(v_new->>'booking_id','')::uuid,nullif(v_old->>'booking_id','')::uuid);
  v_actor_role:=CASE
    WHEN EXISTS(SELECT 1 FROM public.srk_admin_users WHERE user_id=auth.uid()) THEN 'super_admin'
    ELSE 'staff' END;
  v_reason:=coalesce(v_new->>'admin_note',v_new->>'change_reason',v_new->>'admin_change_reason',
    v_new->>'moderation_note',v_new->>'reason','Admin panel change');

  SELECT coalesce(array_agg(k),array[]::text[]) INTO v_changed
  FROM (
    SELECT key k FROM jsonb_object_keys(v_new) key
    UNION SELECT key k FROM jsonb_object_keys(v_old) key
  ) keys
  WHERE v_old->k IS DISTINCT FROM v_new->k;

  INSERT INTO public.srk_admin_audit_events
    (entity_type,entity_id,booking_id,action,actor_user_id,actor_role,changed_fields,before_data,after_data)
  VALUES
    (TG_ARGV[0],v_id,v_booking,TG_OP,auth.uid(),v_actor_role,v_changed,v_old,
     jsonb_set(v_new,'{admin_action_reason}',to_jsonb(v_reason),true));

  IF v_booking IS NOT NULL THEN
    INSERT INTO public.srk_booking_admin_changes
      (booking_id,admin_user_id,entity_type,entity_id,action,reason,old_values,new_values)
    VALUES(v_booking,auth.uid(),TG_ARGV[0],v_id,TG_OP,v_reason,v_old,v_new);
  END IF;

  IF TG_OP='DELETE' THEN RETURN OLD; ELSE RETURN NEW; END IF;
END
$function$;

DROP TRIGGER IF EXISTS srk_audit_service_category_admin ON public.srk_service_categories;
CREATE TRIGGER srk_audit_service_category_admin
AFTER INSERT OR UPDATE OR DELETE ON public.srk_service_categories
FOR EACH ROW EXECUTE FUNCTION public.srk_log_admin_entity_change('service_category');

DROP TRIGGER IF EXISTS srk_audit_admin_role_admin ON public.srk_admin_roles;
CREATE TRIGGER srk_audit_admin_role_admin
AFTER INSERT OR UPDATE OR DELETE ON public.srk_admin_roles
FOR EACH ROW EXECUTE FUNCTION public.srk_log_admin_entity_change('admin_role');

DROP TRIGGER IF EXISTS srk_audit_admin_user_admin ON public.srk_admin_users;
CREATE TRIGGER srk_audit_admin_user_admin
AFTER INSERT OR UPDATE OR DELETE ON public.srk_admin_users
FOR EACH ROW EXECUTE FUNCTION public.srk_log_admin_entity_change('admin_user');

DROP TRIGGER IF EXISTS srk_audit_admin_role_permission_admin ON public.srk_admin_role_permissions;
CREATE TRIGGER srk_audit_admin_role_permission_admin
AFTER INSERT OR UPDATE OR DELETE ON public.srk_admin_role_permissions
FOR EACH ROW EXECUTE FUNCTION public.srk_log_admin_entity_change('admin_role_permission');

DROP TRIGGER IF EXISTS srk_audit_booking_complaint_admin ON public.srk_booking_complaints;
CREATE TRIGGER srk_audit_booking_complaint_admin
AFTER INSERT OR UPDATE OR DELETE ON public.srk_booking_complaints
FOR EACH ROW EXECUTE FUNCTION public.srk_log_admin_entity_change('booking_complaint');

DROP TRIGGER IF EXISTS srk_audit_booking_refund_request_admin ON public.srk_booking_refund_requests;
CREATE TRIGGER srk_audit_booking_refund_request_admin
AFTER INSERT OR UPDATE OR DELETE ON public.srk_booking_refund_requests
FOR EACH ROW EXECUTE FUNCTION public.srk_log_admin_entity_change('booking_refund_request');

DROP TRIGGER IF EXISTS srk_audit_booking_schedule_proposal_admin ON public.srk_booking_schedule_proposals;
CREATE TRIGGER srk_audit_booking_schedule_proposal_admin
AFTER INSERT OR UPDATE OR DELETE ON public.srk_booking_schedule_proposals
FOR EACH ROW EXECUTE FUNCTION public.srk_log_admin_entity_change('booking_schedule_proposal');
