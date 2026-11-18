-- Require the same verified, active and dual-identity profile guard used by
-- electrician earnings and offer RPCs before exposing an electrician wallet.
-- Customer wallet behavior and all ledger rows remain unchanged.
BEGIN;

CREATE OR REPLACE FUNCTION public.srk_get_my_wallet_summary()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_customer_id uuid;
  v_electrician_id uuid;
  v_result jsonb;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING errcode='42501';
  END IF;

  INSERT INTO public.srk_wallet_accounts(user_id, wallet_type)
  VALUES (v_uid, 'customer')
  ON CONFLICT (user_id, wallet_type) DO NOTHING;

  IF EXISTS (
    SELECT 1
      FROM public.electrician_profiles ep
     WHERE ep.user_id = v_uid
       AND ep.auth_user_id = v_uid
       AND ep.verification_status = 'approved'
       AND ep.active = true
  ) THEN
    INSERT INTO public.srk_wallet_accounts(user_id, wallet_type)
    VALUES (v_uid, 'electrician')
    ON CONFLICT (user_id, wallet_type) DO NOTHING;

    SELECT wa.id INTO v_electrician_id
      FROM public.srk_wallet_accounts wa
     WHERE wa.user_id = v_uid
       AND wa.wallet_type = 'electrician';
  END IF;

  SELECT wa.id INTO v_customer_id
    FROM public.srk_wallet_accounts wa
   WHERE wa.user_id = v_uid
     AND wa.wallet_type = 'customer';

  SELECT pg_catalog.jsonb_build_object(
    'customer', pg_catalog.jsonb_build_object(
      'wallet_id', v_customer_id,
      'balance', COALESCE((
        SELECT pg_catalog.sum(
          CASE WHEN l.direction='credit' THEN l.amount ELSE -l.amount END
        )
          FROM public.srk_wallet_ledger l
         WHERE l.wallet_id=v_customer_id
           AND l.status='posted'
      ),0),
      'currency','INR',
      'topups_enabled',false,
      'note','Customer deposits are disabled until the regulated payment flow is approved.'
    ),
    'electrician', CASE WHEN v_electrician_id IS NULL THEN NULL ELSE
      pg_catalog.jsonb_build_object(
        'wallet_id', v_electrician_id,
        'balance', COALESCE((
          SELECT pg_catalog.sum(
            CASE WHEN l.direction='credit' THEN l.amount ELSE -l.amount END
          )
            FROM public.srk_wallet_ledger l
           WHERE l.wallet_id=v_electrician_id
             AND l.status='posted'
        ),0),
        'currency','INR',
        'payouts_enabled',false,
        'note','Bank payouts are disabled until Route linked-account onboarding and live approval are complete.'
      )
    END
  ) INTO v_result;

  RETURN v_result;
END;
$function$;

REVOKE ALL ON FUNCTION public.srk_get_my_wallet_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.srk_get_my_wallet_summary() TO authenticated;

COMMIT;
