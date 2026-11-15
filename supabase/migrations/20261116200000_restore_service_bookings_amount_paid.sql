-- Restore the legacy verified-payment amount column required by financial RPCs.
-- The original setup schema omitted this column even though later migrations,
-- webhook code and accounting/receipt RPCs reference it.
ALTER TABLE public.service_bookings
  ADD COLUMN IF NOT EXISTS amount_paid numeric(12,2);

DO $migration$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conrelid = 'public.service_bookings'::regclass
      AND conname = 'service_bookings_amount_paid_nonnegative_check'
  ) THEN
    ALTER TABLE public.service_bookings
      ADD CONSTRAINT service_bookings_amount_paid_nonnegative_check
      CHECK (amount_paid IS NULL OR amount_paid >= 0) NOT VALID;
  END IF;
END
$migration$;
