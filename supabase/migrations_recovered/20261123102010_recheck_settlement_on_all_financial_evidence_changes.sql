
CREATE OR REPLACE FUNCTION public.srk_guard_matched_razorpay_settlement()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'public'
AS $function$
BEGIN
  IF OLD.reconciliation_status = 'matched' AND (
       NEW.settlement_status IS DISTINCT FROM OLD.settlement_status
       OR NEW.gross_amount_paise IS DISTINCT FROM OLD.gross_amount_paise
       OR NEW.fee_amount_paise IS DISTINCT FROM OLD.fee_amount_paise
       OR NEW.tax_amount_paise IS DISTINCT FROM OLD.tax_amount_paise
       OR NEW.adjustment_amount_paise IS DISTINCT FROM OLD.adjustment_amount_paise
       OR NEW.provider_net_amount_paise IS DISTINCT FROM OLD.provider_net_amount_paise
       OR NEW.utr IS DISTINCT FROM OLD.utr
       OR NEW.bank_credit_amount_paise IS DISTINCT FROM OLD.bank_credit_amount_paise
       OR NEW.bank_reference IS DISTINCT FROM OLD.bank_reference
       OR NEW.bank_credit_at IS DISTINCT FROM OLD.bank_credit_at
     ) THEN
    IF NEW.settlement_status IS DISTINCT FROM 'processed'
       OR NEW.gross_amount_paise IS DISTINCT FROM OLD.gross_amount_paise
       OR NEW.fee_amount_paise IS DISTINCT FROM OLD.fee_amount_paise
       OR NEW.tax_amount_paise IS DISTINCT FROM OLD.tax_amount_paise
       OR NEW.adjustment_amount_paise IS DISTINCT FROM OLD.adjustment_amount_paise
       OR NEW.provider_net_amount_paise IS DISTINCT FROM OLD.provider_net_amount_paise
       OR NEW.utr IS DISTINCT FROM OLD.utr
       OR NEW.bank_credit_amount_paise IS DISTINCT FROM OLD.bank_credit_amount_paise
       OR NEW.bank_reference IS DISTINCT FROM OLD.bank_reference
       OR NEW.bank_credit_at IS DISTINCT FROM OLD.bank_credit_at THEN
      NEW.reconciliation_status := 'under_review';
      NEW.reconciliation_note := left(
        concat_ws(' | ', nullif(btrim(NEW.reconciliation_note), ''),
          'Re-review required: provider settlement or bank evidence changed after prior match'),
        2000
      );
      NEW.verified_by := NULL;
      NEW.verified_at := NULL;
    END IF;
  END IF;
  RETURN NEW;
END
$function$;

DROP TRIGGER IF EXISTS trg_srk_guard_matched_razorpay_settlement
ON public.srk_razorpay_settlements;

CREATE TRIGGER trg_srk_guard_matched_razorpay_settlement
BEFORE UPDATE OF settlement_status, gross_amount_paise, fee_amount_paise,
  tax_amount_paise, adjustment_amount_paise, provider_net_amount_paise,
  utr, bank_credit_amount_paise, bank_reference, bank_credit_at
ON public.srk_razorpay_settlements
FOR EACH ROW
EXECUTE FUNCTION public.srk_guard_matched_razorpay_settlement();

REVOKE ALL ON FUNCTION public.srk_guard_matched_razorpay_settlement() FROM PUBLIC, anon, authenticated;
