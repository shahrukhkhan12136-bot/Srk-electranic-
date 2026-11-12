-- Runtime assertions for safe Admin-only correction of a paid payout reference.
INSERT INTO auth.users(id,phone) VALUES
 ('10000000-0000-4000-8000-000000000001','910000000001'),
 ('10000000-0000-4000-8000-000000000002','910000000002');
INSERT INTO public.service_bookings(id) VALUES
 ('20000000-0000-4000-8000-000000000001'),
 ('20000000-0000-4000-8000-000000000002'),
 ('20000000-0000-4000-8000-000000000003');
INSERT INTO public.srk_electrician_payouts
 (id,booking_id,electrician_payable,payout_status,payout_method,payout_reference,payout_note,paid_by,paid_at)
VALUES
 ('30000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001',18.50,'paid','upi','9920904161786@ybl',NULL,'10000000-0000-4000-8000-000000000001','2026-11-12T09:54:43Z'),
 ('30000000-0000-4000-8000-000000000002','20000000-0000-4000-8000-000000000002',5.00,'pending',NULL,NULL,NULL,NULL,NULL),
 ('30000000-0000-4000-8000-000000000003','20000000-0000-4000-8000-000000000003',7.00,'paid','upi','DUPLICATE123',NULL,'10000000-0000-4000-8000-000000000001','2026-11-12T09:54:43Z');

DO $test$
DECLARE
  v_result jsonb;
  v_paid_at timestamptz;
  v_amount numeric;
  v_reference text;
  v_status text;
  v_note text;
  v_audit public.srk_admin_audit_events%ROWTYPE;
  v_blocked boolean;
BEGIN
  SELECT paid_at,electrician_payable INTO v_paid_at,v_amount
    FROM public.srk_electrician_payouts
   WHERE id='30000000-0000-4000-8000-000000000001';

  PERFORM set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000001',false);
  PERFORM set_config('request.jwt.claim.is_srk_admin','true',false);
  v_result:=public.srk_admin_correct_electrician_payout_reference(
    '30000000-0000-4000-8000-000000000001',
    '9920904161786@ybl',
    '741113479944',
    'PhonePe UPI receipt verified by Admin; correcting previously mistyped payout reference.'
  );
  IF v_result->>'success'<>'true' OR v_result->>'reference_corrected'<>'true' THEN
    RAISE EXCEPTION 'PAID_REFERENCE_CORRECTION_NOT_CONFIRMED';
  END IF;

  SELECT payout_reference,payout_status,electrician_payable,paid_at,payout_note
    INTO v_reference,v_status,v_amount,v_paid_at,v_note
    FROM public.srk_electrician_payouts
   WHERE id='30000000-0000-4000-8000-000000000001';
  IF v_reference<>'741113479944' OR v_status<>'paid' OR v_amount<>18.50
     OR v_paid_at IS DISTINCT FROM '2026-11-12T09:54:43Z'::timestamptz
     OR position('PhonePe UPI receipt verified' in v_note)=0 THEN
    RAISE EXCEPTION 'CORRECTION_CHANGED_FINANCIAL_STATE_OR_FAILED_TO_SAVE_REFERENCE';
  END IF;

  SELECT * INTO v_audit
    FROM public.srk_admin_audit_events
   WHERE entity_type='electrician_payout'
     AND entity_id='30000000-0000-4000-8000-000000000001'
     AND action='updated'
   ORDER BY created_at DESC LIMIT 1;
  IF NOT FOUND OR NOT (v_audit.changed_fields @> ARRAY['payout_reference','payout_note'])
     OR v_audit.before_data->>'payout_reference'<>'9920904161786@ybl'
     OR v_audit.after_data->>'payout_reference'<>'741113479944' THEN
    RAISE EXCEPTION 'OLD_AND_NEW_REFERENCE_NOT_CAPTURED_IN_ADMIN_AUDIT';
  END IF;

  -- Non-admin caller is rejected.
  PERFORM set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000002',false);
  PERFORM set_config('request.jwt.claim.is_srk_admin','false',false);
  v_blocked:=false;
  BEGIN
    PERFORM public.srk_admin_correct_electrician_payout_reference(
      '30000000-0000-4000-8000-000000000001','741113479944','741113479945','Non-admin attempt');
  EXCEPTION WHEN OTHERS THEN v_blocked:=true;
  END;
  IF NOT v_blocked THEN RAISE EXCEPTION 'NON_ADMIN_REFERENCE_CORRECTION_WAS_ALLOWED'; END IF;

  -- Stale expected reference is rejected using compare-and-swap.
  PERFORM set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000001',false);
  PERFORM set_config('request.jwt.claim.is_srk_admin','true',false);
  v_blocked:=false;
  BEGIN
    PERFORM public.srk_admin_correct_electrician_payout_reference(
      '30000000-0000-4000-8000-000000000001','9920904161786@ybl','741113479945','Stale reference attempt');
  EXCEPTION WHEN OTHERS THEN v_blocked:=true;
  END;
  IF NOT v_blocked THEN RAISE EXCEPTION 'STALE_REFERENCE_WAS_ALLOWED'; END IF;

  -- Pending payouts cannot be corrected.
  v_blocked:=false;
  BEGIN
    PERFORM public.srk_admin_correct_electrician_payout_reference(
      '30000000-0000-4000-8000-000000000002','pending-old-ref','741113479946','Pending payout attempt');
  EXCEPTION WHEN OTHERS THEN v_blocked:=true;
  END;
  IF NOT v_blocked THEN RAISE EXCEPTION 'PENDING_PAYOUT_REFERENCE_CORRECTION_WAS_ALLOWED'; END IF;

  -- Duplicate references cannot be reused.
  v_blocked:=false;
  BEGIN
    PERFORM public.srk_admin_correct_electrician_payout_reference(
      '30000000-0000-4000-8000-000000000001','741113479944','DUPLICATE123','Duplicate reference attempt');
  EXCEPTION WHEN OTHERS THEN v_blocked:=true;
  END;
  IF NOT v_blocked THEN RAISE EXCEPTION 'DUPLICATE_REFERENCE_WAS_ALLOWED'; END IF;

  -- Malformed references are rejected.
  v_blocked:=false;
  BEGIN
    PERFORM public.srk_admin_correct_electrician_payout_reference(
      '30000000-0000-4000-8000-000000000001','741113479944','bad','Malformed reference attempt');
  EXCEPTION WHEN OTHERS THEN v_blocked:=true;
  END;
  IF NOT v_blocked THEN RAISE EXCEPTION 'MALFORMED_REFERENCE_WAS_ALLOWED'; END IF;

  IF has_function_privilege('authenticated','public.srk_admin_correct_electrician_payout_reference(uuid,text,text,text)','EXECUTE') IS NOT TRUE
     OR has_function_privilege('anon','public.srk_admin_correct_electrician_payout_reference(uuid,text,text,text)','EXECUTE') IS TRUE THEN
    RAISE EXCEPTION 'FUNCTION_EXECUTE_GRANTS_INVALID';
  END IF;
END
$test$;
