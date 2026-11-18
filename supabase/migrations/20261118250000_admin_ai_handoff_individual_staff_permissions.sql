-- Per-person AI handoff permission grants.
-- This migration adds permission administration only. It does not grant access by default,
-- expose the queue to Staff, assign conversations, or enable the AI assistant.
BEGIN;

INSERT INTO public.srk_admin_permissions(permission_key,description) VALUES
 ('ai.handoff.read','Read AI handoff conversations explicitly assigned to this staff member'),
 ('ai.handoff.reply','Reply only within AI handoff conversations explicitly assigned to this staff member'),
 ('ai.handoff.resolve','Resolve only AI handoff conversations explicitly assigned to this staff member')
ON CONFLICT (permission_key) DO NOTHING;

CREATE TABLE IF NOT EXISTS public.srk_admin_staff_permission_grants (
  staff_user_id uuid NOT NULL REFERENCES public.srk_admin_staff(user_id) ON DELETE RESTRICT,
  permission_key text NOT NULL REFERENCES public.srk_admin_permissions(permission_key) ON DELETE RESTRICT,
  granted_by uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
  granted_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  PRIMARY KEY (staff_user_id,permission_key),
  CONSTRAINT srk_admin_staff_permission_ai_only CHECK (
    permission_key IN ('ai.handoff.read','ai.handoff.reply','ai.handoff.resolve')
  )
);
ALTER TABLE public.srk_admin_staff_permission_grants ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.srk_admin_staff_permission_grants FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION public.srk_has_admin_permission(p_permission_key text)
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path=''
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_session_id uuid;
BEGIN
  IF v_uid IS NULL OR p_permission_key IS NULL OR length(p_permission_key)>100 THEN
    RETURN false;
  END IF;
  IF public.is_srk_admin() THEN
    RETURN true;
  END IF;
  IF coalesce(auth.jwt()->>'session_id','') !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN
    RETURN false;
  END IF;
  v_session_id := (auth.jwt()->>'session_id')::uuid;

  PERFORM 1 FROM public.srk_admin_staff s
   WHERE s.user_id=v_uid AND s.status='active'
   FOR SHARE;
  IF NOT FOUND THEN RETURN false; END IF;

  PERFORM 1 FROM public.srk_admin_staff_sessions tracked
   WHERE tracked.auth_session_id=v_session_id
     AND tracked.staff_user_id=v_uid
     AND tracked.revoked_at IS NULL
   FOR SHARE;
  IF NOT FOUND THEN RETURN false; END IF;

  IF NOT EXISTS (
    SELECT 1 FROM auth.sessions auth_s
     WHERE auth_s.id=v_session_id AND auth_s.user_id=v_uid
  ) THEN RETURN false; END IF;

  RETURN EXISTS (
    SELECT 1
      FROM public.srk_admin_staff s
      JOIN public.srk_admin_role_permissions rp ON rp.role_key=s.role_key
     WHERE s.user_id=v_uid AND s.status='active'
       AND rp.permission_key=p_permission_key
  ) OR (
    p_permission_key IN ('ai.handoff.read','ai.handoff.reply','ai.handoff.resolve')
    AND EXISTS (
      SELECT 1 FROM public.srk_admin_staff_permission_grants g
       WHERE g.staff_user_id=v_uid AND g.permission_key=p_permission_key
    )
  );
END;
$function$;
REVOKE ALL ON FUNCTION public.srk_has_admin_permission(text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.srk_has_admin_permission(text) TO authenticated;

CREATE OR REPLACE FUNCTION public.srk_admin_set_staff_ai_handoff_permission(
  p_staff_user_id uuid,
  p_permission_key text,
  p_granted boolean,
  p_reason text
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path=''
AS $function$
DECLARE
  v_actor uuid := auth.uid();
  v_staff_status text;
BEGIN
  IF v_actor IS NULL OR NOT public.is_srk_admin() THEN
    RAISE EXCEPTION 'MAIN_ADMIN_ONLY' USING ERRCODE='42501';
  END IF;
  IF p_staff_user_id IS NULL
     OR p_permission_key IS NULL
     OR p_permission_key NOT IN ('ai.handoff.read','ai.handoff.reply','ai.handoff.resolve')
     OR p_granted IS NULL
     OR length(btrim(coalesce(p_reason,''))) NOT BETWEEN 5 AND 500 THEN
    RAISE EXCEPTION 'INVALID_AI_HANDOFF_PERMISSION' USING ERRCODE='22023';
  END IF;

  SELECT s.status INTO v_staff_status
    FROM public.srk_admin_staff s
   WHERE s.user_id=p_staff_user_id
   FOR UPDATE;
  IF NOT FOUND OR v_staff_status<>'active' THEN
    RAISE EXCEPTION 'AI_HANDOFF_STAFF_NOT_ACTIVE' USING ERRCODE='22023';
  END IF;

  IF p_granted THEN
    INSERT INTO public.srk_admin_staff_permission_grants
      (staff_user_id,permission_key,granted_by)
    VALUES (p_staff_user_id,p_permission_key,v_actor)
    ON CONFLICT (staff_user_id,permission_key) DO UPDATE
      SET granted_by=EXCLUDED.granted_by,granted_at=clock_timestamp();
  ELSE
    DELETE FROM public.srk_admin_staff_permission_grants
     WHERE staff_user_id=p_staff_user_id AND permission_key=p_permission_key;
  END IF;

  INSERT INTO public.srk_admin_staff_audit_events
    (actor_user_id,target_user_id,action,outcome,details)
  VALUES
    (v_actor,p_staff_user_id,
     CASE WHEN p_granted THEN 'staff.ai_handoff.permission.granted'
          ELSE 'staff.ai_handoff.permission.revoked' END,
     'success',
     jsonb_build_object('permission_key',p_permission_key,'reason',left(p_reason,500)));

  RETURN true;
END;
$function$;
REVOKE ALL ON FUNCTION public.srk_admin_set_staff_ai_handoff_permission(uuid,text,boolean,text)
  FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.srk_admin_set_staff_ai_handoff_permission(uuid,text,boolean,text)
  TO authenticated;

COMMIT;
