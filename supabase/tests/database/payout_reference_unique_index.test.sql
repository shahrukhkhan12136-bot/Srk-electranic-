-- Direct PostgreSQL proof that normalized payout references are unique.
-- Runs only inside the disposable full-migration-replay CI database.
BEGIN;
SELECT plan(2);

DO $test$
DECLARE
  v_electrician uuid;
  v_booking_one uuid;
  v_booking_two uuid;
  v_payout_one uuid;
  v_rejected boolean := false;
  v_error text;
BEGIN
  INSERT INTO public.electrician_profiles (
    display_name, phone, state, district, pincode, skills, active
  ) VALUES (
    'CI Payout Reference Test', '9000000001', 'Uttar Pradesh', 'Kanpur', '208001',
    ARRAY['electrical'], false
  ) RETURNING id INTO v_electrician;

  INSERT INTO public.service_bookings (
    customer_name, phone, state, district, pincode, address, service_type
  ) VALUES (
    'CI Payout Ref Customer 1', '9000000002', 'Uttar Pradesh', 'Kanpur', '208001',
    'Disposable CI fixture 1', 'Electrical'
  ) RETURNING id INTO v_booking_one;

  INSERT INTO public.service_bookings (
    customer_name, phone, state, district, pincode, address, service_type
  ) VALUES (
    'CI Payout Ref Customer 2', '9000000003', 'Uttar Pradesh', 'Kanpur', '208001',
    'Disposable CI fixture 2', 'Electrical'
  ) RETURNING id INTO v_booking_two;

  INSERT INTO public.srk_electrician_payouts (
    booking_id, electrician_profile_id, gross_service_amount, materials_amount,
    platform_commission, electrician_payable, payout_reference
  ) VALUES (
    v_booking_one, v_electrician, 100, 0, 15, 85, 'CI-UTR-DUPLICATE-001'
  ) RETURNING id INTO v_payout_one;

  BEGIN
    INSERT INTO public.srk_electrician_payouts (
      booking_id, electrician_profile_id, gross_service_amount, materials_amount,
      platform_commission, electrician_payable, payout_reference
    ) VALUES (
      v_booking_two, v_electrician, 100, 0, 15, 85, '  ci-utr-duplicate-001  '
    );
  EXCEPTION WHEN unique_violation THEN
    GET STACKED DIAGNOSTICS v_error = MESSAGE_TEXT;
    IF position('srk_electrician_payouts_unique_reference_normalized' in v_error) = 0 THEN
      RAISE EXCEPTION 'Unexpected unique violation: %', v_error;
    END IF;
    v_rejected := true;
  END;

  IF NOT v_rejected THEN
    RAISE EXCEPTION 'Duplicate normalized payout reference was accepted';
  END IF;

  IF (SELECT count(*) FROM public.srk_electrician_payouts
       WHERE lower(btrim(payout_reference)) = 'ci-utr-duplicate-001') <> 1 THEN
    RAISE EXCEPTION 'Expected exactly one payout row after duplicate rejection';
  END IF;

  RAISE NOTICE 'payout_reference_duplicate_insert_rejected=true';
  RAISE NOTICE 'payout_reference_duplicate_fixture_count=1';
END;
$test$;

SELECT ok(true, 'normalized duplicate payout reference insert is rejected');
SELECT ok(true, 'exactly one normalized payout reference remains');

ROLLBACK;
