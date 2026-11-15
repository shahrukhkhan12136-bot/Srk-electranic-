-- Reconcile electrician identity columns and fail closed on ambiguous phone linking.
-- Feature-branch source only; do not apply to Production without approved rollout.
ALTER TABLE public.electrician_profiles
  ADD COLUMN IF NOT EXISTS auth_user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL;

DO $migration$
BEGIN
  IF EXISTS (SELECT 1 FROM public.electrician_profiles
    WHERE user_id IS NOT NULL AND auth_user_id IS NOT NULL AND user_id IS DISTINCT FROM auth_user_id) THEN
    RAISE EXCEPTION 'ELECTRICIAN_PROFILE_IDENTITY_COLUMNS_CONFLICT';
  END IF;
  IF EXISTS (SELECT auth_user_id FROM public.electrician_profiles WHERE auth_user_id IS NOT NULL
    GROUP BY auth_user_id HAVING count(*) > 1) THEN
    RAISE EXCEPTION 'DUPLICATE_ELECTRICIAN_AUTH_USER_LINKS';
  END IF;
END;
$migration$;

UPDATE public.electrician_profiles SET auth_user_id=user_id WHERE auth_user_id IS NULL AND user_id IS NOT NULL;
UPDATE public.electrician_profiles SET user_id=auth_user_id WHERE user_id IS NULL AND auth_user_id IS NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS electrician_profiles_auth_user_id_uidx
  ON public.electrician_profiles(auth_user_id) WHERE auth_user_id IS NOT NULL;

CREATE OR REPLACE FUNCTION public.srk_sync_electrician_profile_identity()
RETURNS trigger LANGUAGE plpgsql SET search_path=pg_catalog,public AS $function$
BEGIN
  IF NEW.user_id IS NOT NULL AND NEW.auth_user_id IS NOT NULL AND NEW.user_id IS DISTINCT FROM NEW.auth_user_id THEN
    RAISE EXCEPTION 'ELECTRICIAN_PROFILE_IDENTITY_COLUMNS_MUST_MATCH' USING ERRCODE='23514';
  END IF;
  IF TG_OP='INSERT' THEN
    IF NEW.user_id IS NULL THEN NEW.user_id:=NEW.auth_user_id; ELSE NEW.auth_user_id:=NEW.user_id; END IF;
  ELSIF NEW.user_id IS DISTINCT FROM OLD.user_id AND NEW.auth_user_id IS NOT DISTINCT FROM OLD.auth_user_id THEN
    NEW.auth_user_id:=NEW.user_id;
  ELSIF NEW.auth_user_id IS DISTINCT FROM OLD.auth_user_id AND NEW.user_id IS NOT DISTINCT FROM OLD.user_id THEN
    NEW.user_id:=NEW.auth_user_id;
  END IF;
  RETURN NEW;
END;
$function$;
REVOKE ALL ON FUNCTION public.srk_sync_electrician_profile_identity() FROM PUBLIC,anon,authenticated;
DROP TRIGGER IF EXISTS a_srk_sync_electrician_profile_identity ON public.electrician_profiles;
CREATE TRIGGER a_srk_sync_electrician_profile_identity
BEFORE INSERT OR UPDATE OF user_id,auth_user_id,phone,verification_status ON public.electrician_profiles
FOR EACH ROW EXECUTE FUNCTION public.srk_sync_electrician_profile_identity();

CREATE OR REPLACE FUNCTION public.srk_guard_electrician_profile_identity_link()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public,auth AS $function$
DECLARE
  v_phone text;
  v_user_phone text;
  v_confirmed_at timestamptz;
  v_profile_count integer;
  v_auth_user_count integer;
BEGIN
  IF NEW.user_id IS NULL AND NEW.auth_user_id IS NULL THEN RETURN NEW; END IF;
  IF NEW.user_id IS NULL OR NEW.auth_user_id IS NULL OR NEW.user_id IS DISTINCT FROM NEW.auth_user_id THEN
    RAISE EXCEPTION 'ELECTRICIAN_PROFILE_IDENTITY_LINK_INCOMPLETE' USING ERRCODE='23514';
  END IF;
  SELECT u.phone,u.phone_confirmed_at INTO v_user_phone,v_confirmed_at FROM auth.users u WHERE u.id=NEW.user_id;
  v_phone:=right(regexp_replace(coalesce(NEW.phone,''),'[^0-9]','','g'),10);
  IF v_user_phone IS NULL OR v_confirmed_at IS NULL
    OR right(regexp_replace(v_user_phone,'[^0-9]','','g'),10)<>v_phone THEN
    RAISE EXCEPTION 'ELECTRICIAN_PROFILE_PHONE_NOT_VERIFIED_OR_MISMATCHED' USING ERRCODE='23514';
  END IF;
  SELECT count(*) INTO v_auth_user_count FROM auth.users u
  WHERE u.phone_confirmed_at IS NOT NULL
    AND right(regexp_replace(coalesce(u.phone,''),'[^0-9]','','g'),10)=v_phone;
  IF v_auth_user_count<>1 THEN
    RAISE EXCEPTION 'AMBIGUOUS_VERIFIED_AUTH_USERS_FOR_ELECTRICIAN_PHONE' USING ERRCODE='23514';
  END IF;
  SELECT count(*) INTO v_profile_count FROM public.electrician_profiles p
  WHERE p.id<>NEW.id AND p.verification_status='approved'
    AND right(regexp_replace(coalesce(p.phone,''),'[^0-9]','','g'),10)=v_phone;
  IF v_profile_count>0 THEN
    RAISE EXCEPTION 'AMBIGUOUS_APPROVED_ELECTRICIAN_PHONE_PROFILE' USING ERRCODE='23514';
  END IF;
  RETURN NEW;
END;
$function$;
REVOKE ALL ON FUNCTION public.srk_guard_electrician_profile_identity_link() FROM PUBLIC,anon,authenticated;
DROP TRIGGER IF EXISTS srk_guard_electrician_profile_identity_link ON public.electrician_profiles;
CREATE TRIGGER srk_guard_electrician_profile_identity_link
BEFORE INSERT OR UPDATE OF user_id,auth_user_id ON public.electrician_profiles
FOR EACH ROW EXECUTE FUNCTION public.srk_guard_electrician_profile_identity_link();

CREATE OR REPLACE FUNCTION public.srk_link_electrician_profile()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public,auth AS $function$
DECLARE v_phone text; v_profile_count integer; v_auth_user_count integer;
BEGIN
  IF NEW.phone IS NULL OR NEW.phone_confirmed_at IS NULL THEN RETURN NEW; END IF;
  v_phone:=right(regexp_replace(NEW.phone,'[^0-9]','','g'),10);
  SELECT count(*) INTO v_auth_user_count FROM auth.users u
  WHERE u.phone_confirmed_at IS NOT NULL
    AND right(regexp_replace(coalesce(u.phone,''),'[^0-9]','','g'),10)=v_phone;
  IF v_auth_user_count<>1 THEN RETURN NEW; END IF;
  SELECT count(*) INTO v_profile_count FROM public.electrician_profiles p
  WHERE p.verification_status='approved'
    AND right(regexp_replace(coalesce(p.phone,''),'[^0-9]','','g'),10)=v_phone;
  IF v_profile_count=1 THEN
    UPDATE public.electrician_profiles p SET user_id=NEW.id
    WHERE p.verification_status='approved' AND p.user_id IS NULL AND p.auth_user_id IS NULL
      AND right(regexp_replace(coalesce(p.phone,''),'[^0-9]','','g'),10)=v_phone;
  END IF;
  RETURN NEW;
END;
$function$;
REVOKE ALL ON FUNCTION public.srk_link_electrician_profile() FROM PUBLIC,anon,authenticated;
