CREATE OR REPLACE FUNCTION public.srk_guard_matched_razorpay_settlement()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'pg_catalog','public'
AS $function$
BEGIN
  IF OLD.reconciliation_status='matched' AND (
       NEW.settlement_status IS DISTINCT FROM 'processed'
       OR NEW.provider_net_amount_paise IS DISTINCT FROM OLD.provider_net_amount_paise
       OR NEW.bank_credit_amount_paise IS DISTINCT FROM OLD.bank_credit_amount_paise
       OR NEW.bank_reference IS DISTINCT FROM OLD.bank_reference
       OR NEW.bank_credit_at IS DISTINCT FROM OLD.bank_credit_at
     ) THEN
    IF NEW.settlement_status<>'processed'
       OR NEW.provider_net_amount_paise IS DISTINCT FROM NEW.bank_credit_amount_paise THEN
      NEW.reconciliation_status:='mismatch';
      NEW.reconciliation_note:=left(
        concat_ws(' | ',nullif(btrim(NEW.reconciliation_note),''),
          'Automatic re-review required: provider settlement or bank evidence changed after match'),
        2000
      );
      NEW.verified_by:=NULL;
      NEW.verified_at:=NULL;
    END IF;
  END IF;
  RETURN NEW;
END
$function$;

DROP TRIGGER IF EXISTS trg_srk_guard_matched_razorpay_settlement ON public.srk_razorpay_settlements;
CREATE TRIGGER trg_srk_guard_matched_razorpay_settlement
BEFORE UPDATE OF settlement_status,provider_net_amount_paise,bank_credit_amount_paise,bank_reference,bank_credit_at
ON public.srk_razorpay_settlements
FOR EACH ROW EXECUTE FUNCTION public.srk_guard_matched_razorpay_settlement();

DO $block$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conrelid='public.srk_razorpay_settlements'::regclass
      AND conname='srk_matched_settlement_amounts_equal'
  ) THEN
    ALTER TABLE public.srk_razorpay_settlements
      ADD CONSTRAINT srk_matched_settlement_amounts_equal
      CHECK (
        reconciliation_status<>'matched'
        OR (
          settlement_status='processed'
          AND provider_net_amount_paise IS NOT NULL
          AND bank_credit_amount_paise IS NOT NULL
          AND provider_net_amount_paise=bank_credit_amount_paise
        )
      );
  END IF;
END
$block$;

REVOKE ALL ON FUNCTION public.srk_guard_matched_razorpay_settlement() FROM PUBLIC,anon,authenticated;
