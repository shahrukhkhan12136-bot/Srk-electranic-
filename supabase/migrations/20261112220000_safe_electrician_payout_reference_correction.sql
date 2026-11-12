-- Safe correction of an already-settled electrician payout reference.
-- This does not create, reverse, or alter the financial settlement itself.
-- It only replaces a previously mistyped reference after an Admin verifies the actual transfer.

CREATE OR REPLACE FUNCTION public.srk_capture_admin_audit_event()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'public', 'auth', 'pg_temp'
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
      v_fields := array_append(v_fields,v_key);
      IF v_old ? v_key THEN v_before := v_before || jsonb_build_object(v_key,v_old->v_key); END IF;
      IF v_new ? v_key THEN v_after := v_after || jsonb_build_object(v_key,v_new->v_key); END IF;
    END IF;
  END LOOP;
  IF cardinality(v_fields)=0 THEN
    IF TG_OP='DELETE' THEN RETURN OLD; ELSE RETURN NEW; END IF;
  END IF;

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

CREATE OR REPLACE FUNCTION public.srk_admin_correct_electrician_payout_reference(
  p_payout_id uuid,
  p_expected_reference text,
  p_new_reference text,
  p_note text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'public', 'auth', 'pg_temp'
AS $function$
DECLARE
  v_booking_id uuid;
  v_row public.srk_electrician_payouts%ROWTYPE;
  v_new_reference text := pg_catalog.btrim(coalesce(p_new_reference, ''));
  v_note text := nullif(pg_catalog.btrim(p_note), '');
BEGIN
  IF auth.uid() IS NULL OR NOT public.is_srk_admin() THEN
    RAISE EXCEPTION 'Admin access required' USING errcode = '42501';
  END IF;
  IF p_payout_id IS NULL THEN
    RAISE EXCEPTION 'Payout ID is required';
  END IF;
  IF p_expected_reference IS NULL OR pg_catalog.length(pg_catalog.btrim(p_expected_reference)) < 4 THEN
    RAISE EXCEPTION 'Expected existing reference is required';
  END IF;
  IF v_new_reference !~ '^[A-Za-z0-9]{8,40}$' THEN
    RAISE EXCEPTION 'Enter a valid UTR / UPI transaction reference (8-40 letters or digits)';
  END IF;
  IF v_note IS NULL OR pg_catalog.length(v_note) < 8 OR pg_catalog.length(v_note) > 500 THEN
    RAISE EXCEPTION 'Correction note must contain 8-500 characters';
  END IF;

  -- Match the settlement RPC lock order: booking first, then payout.
  SELECT booking_id INTO v_booking_id
    FROM public.srk_electrician_payouts
   WHERE id = p_payout_id;
  IF NOT FOUND OR v_booking_id IS NULL THEN
    RAISE EXCEPTION 'Payout record not found or has no booking';
  END IF;

  PERFORM 1 FROM public.service_bookings WHERE id = v_booking_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Payout booking not found';
  END IF;

  SELECT * INTO v_row
    FROM public.srk_electrician_payouts
   WHERE id = p_payout_id
   FOR UPDATE;
  IF NOT FOUND OR v_row.booking_id IS DISTINCT FROM v_booking_id THEN
    RAISE EXCEPTION 'Payout record changed; retry the operation';
  END IF;
  IF v_row.payout_status <> 'paid' THEN
    RAISE EXCEPTION 'Only an already-paid payout reference can be corrected';
  END IF;
  IF v_row.payout_reference IS DISTINCT FROM pg_catalog.btrim(p_expected_reference) THEN
    RAISE EXCEPTION 'Existing reference changed; refresh and verify before retrying';
  END IF;
  IF v_row.payout_reference = v_new_reference THEN
    RAISE EXCEPTION 'New reference is the same as the existing reference';
  END IF;
  IF EXISTS (
    SELECT 1 FROM public.srk_electrician_payouts p
     WHERE p.id <> p_payout_id AND p.payout_reference = v_new_reference
  ) THEN
    RAISE EXCEPTION 'This transaction reference is already used by another payout';
  END IF;

  UPDATE public.srk_electrician_payouts
     SET payout_reference = v_new_reference,
         payout_note = concat_ws(E'\n', nullif(v_row.payout_note, ''), v_note),
         updated_at = pg_catalog.now()
   WHERE id = p_payout_id;

  RETURN pg_catalog.jsonb_build_object(
    'success', true,
    'payout_id', p_payout_id,
    'status', 'paid',
    'reference_corrected', true
  );
END;
$function$;

REVOKE ALL ON FUNCTION public.srk_admin_correct_electrician_payout_reference(uuid,text,text,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.srk_admin_correct_electrician_payout_reference(uuid,text,text,text) TO authenticated;
