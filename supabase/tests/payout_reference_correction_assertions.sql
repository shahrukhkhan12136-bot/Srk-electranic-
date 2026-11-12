-- Security and audit assertions for the Admin-only payout reference correction.
DO $test$
DECLARE
  v_oid oid := to_regprocedure('public.srk_admin_correct_electrician_payout_reference(uuid,text,text,text)');
  v_definer boolean;
  v_config text[];
  v_source text;
BEGIN
  IF v_oid IS NULL THEN
    RAISE EXCEPTION 'PAYOUT_REFERENCE_CORRECTION_RPC_MISSING';
  END IF;

  SELECT prosecdef, proconfig, prosrc
    INTO v_definer, v_config, v_source
    FROM pg_proc
   WHERE oid = v_oid;

  IF NOT v_definer THEN
    RAISE EXCEPTION 'PAYOUT_REFERENCE_CORRECTION_MUST_BE_SECURITY_DEFINER';
  END IF;
  IF NOT ('search_path=pg_catalog, public, auth, pg_temp' = ANY(coalesce(v_config, ARRAY[]::text[]))) THEN
    RAISE EXCEPTION 'PAYOUT_REFERENCE_CORRECTION_SEARCH_PATH_NOT_HARDENED';
  END IF;
  IF NOT has_function_privilege('authenticated', v_oid, 'EXECUTE')
     OR has_function_privilege('anon', v_oid, 'EXECUTE')
     THEN
    RAISE EXCEPTION 'PAYOUT_REFERENCE_CORRECTION_EXECUTE_GRANTS_INVALID';
  END IF;
  IF position('public.is_srk_admin()' in v_source) = 0
     OR position('auth.uid() IS NULL' in v_source) = 0 THEN
    RAISE EXCEPTION 'PAYOUT_REFERENCE_CORRECTION_MISSING_ADMIN_IDENTITY_GUARD';
  END IF;
  IF position('payout_status <> ''paid''' in v_source) = 0
     OR position('p_expected_reference' in v_source) = 0
     OR position('p_new_reference' in v_source) = 0 THEN
    RAISE EXCEPTION 'PAYOUT_REFERENCE_CORRECTION_MISSING_PAID_OR_COMPARE_AND_SWAP_GUARDS';
  END IF;
  IF position('public.service_bookings' in v_source) = 0
     OR position('FOR UPDATE' in upper(v_source)) = 0 THEN
    RAISE EXCEPTION 'PAYOUT_REFERENCE_CORRECTION_MISSING_BOOKING_FIRST_LOCK';
  END IF;
  IF position('UPDATE public.srk_electrician_payouts' in v_source) = 0
     OR position('UPDATE PUBLIC.SERVICE_BOOKINGS' in upper(v_source)) > 0 THEN
    RAISE EXCEPTION 'PAYOUT_REFERENCE_CORRECTION_SCOPE_INVALID';
  END IF;

  SELECT prosrc INTO v_source
    FROM pg_proc
   WHERE oid = 'public.srk_capture_admin_audit_event()'::regprocedure;
  IF position('payout_reference' in v_source) = 0
     OR position('payout_note' in v_source) = 0 THEN
    RAISE EXCEPTION 'PAYOUT_REFERENCE_CORRECTION_NOT_INCLUDED_IN_AUDIT_ALLOWLIST';
  END IF;
END
$test$;
