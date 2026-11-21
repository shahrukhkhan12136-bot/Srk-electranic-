-- Final quote-system retirement for the Master booking backend.
-- Historical amounts/statuses are already archived in srk_private.legacy_booking_financial_evidence.
-- Historical booking rows, verified payments, manual-payment evidence and payout ledgers are preserved.
-- Feature Branch source only. Never apply to Main/Production without a separate explicit approval.

DO $$
DECLARE r record;
BEGIN
  -- Remove any legacy commission trigger binding before dropping its function.
  FOR r IN
    SELECT t.tgname
      FROM pg_trigger t
      JOIN pg_proc p ON p.oid=t.tgfoid
     WHERE t.tgrelid='public.service_bookings'::regclass
       AND NOT t.tgisinternal
       AND p.proname='srk_calculate_booking_commission'
  LOOP
    EXECUTE format('DROP TRIGGER IF EXISTS %I ON public.service_bookings',r.tgname);
  END LOOP;
END;
$$;

DROP FUNCTION IF EXISTS public.srk_calculate_booking_commission();
DROP FUNCTION IF EXISTS public.srk_submit_booking_quote(uuid,numeric,numeric,text);
DROP FUNCTION IF EXISTS public.srk_customer_respond_booking_quote(uuid,text);
DROP FUNCTION IF EXISTS public.srk_update_booking_work_status(uuid,text);
DROP FUNCTION IF EXISTS public.srk_admin_update_legacy_booking_quote(uuid,numeric);
DROP FUNCTION IF EXISTS public.srk_admin_record_manual_payment(uuid,text,text,text);

-- Move old inspection/quotation lifecycle rows to a neutral archived state.
-- Their exact previous status is preserved in legacy_booking_financial_evidence.
UPDATE public.service_bookings
   SET status='legacy_archived'
 WHERE status IN ('inspection','awaiting_quote_approval','quote_approved','quote_rejected');

-- The live state machine no longer accepts quotation-era statuses.
ALTER TABLE public.service_bookings
  DROP CONSTRAINT IF EXISTS service_bookings_status_check;
ALTER TABLE public.service_bookings
  ADD CONSTRAINT service_bookings_status_check CHECK (
    status = ANY (ARRAY[
      'new','confirmed','assigned','awaiting_work_start_approval',
      'in_progress','completed','cancelled','legacy_archived'
    ]::text[])
  );

ALTER TABLE public.service_bookings
  DROP CONSTRAINT IF EXISTS service_bookings_assignment_status_requires_electrician;
ALTER TABLE public.service_bookings
  ADD CONSTRAINT service_bookings_assignment_status_requires_electrician CHECK (
    (status <> ALL (ARRAY['assigned','in_progress','completed']::text[]))
    OR assigned_electrician_id IS NOT NULL
  );

-- Keep only the active booking/timer/payment workflow on service_bookings.
-- The old quote-era values remain in the private archive for old receipts,
-- refunds, payout settlement and Admin reconciliation.
ALTER TABLE public.service_bookings
  DROP COLUMN IF EXISTS quoted_amount,
  DROP COLUMN IF EXISTS quote_status,
  DROP COLUMN IF EXISTS quote_note,
  DROP COLUMN IF EXISTS quote_submitted_at,
  DROP COLUMN IF EXISTS quote_responded_at,
  DROP COLUMN IF EXISTS customer_suggested_amount,
  DROP COLUMN IF EXISTS electrician_quote_kind,
  DROP COLUMN IF EXISTS service_charge,
  DROP COLUMN IF EXISTS materials_amount;

COMMENT ON TABLE srk_private.legacy_booking_financial_evidence IS
'Private, read-only historical evidence only. It is not an active quotation feature and must never be used to create, submit, approve, reject, dispatch, time, bill or price new bookings. It exists only to reconcile historical receipts, refunds, payouts and accounting.';

REVOKE ALL ON srk_private.legacy_booking_financial_evidence FROM PUBLIC,anon,authenticated;
GRANT SELECT ON srk_private.legacy_booking_financial_evidence TO service_role;

NOTIFY pgrst,'reload schema';
