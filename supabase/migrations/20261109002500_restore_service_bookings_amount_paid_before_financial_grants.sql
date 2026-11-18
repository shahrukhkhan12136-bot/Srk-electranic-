-- Ensure the financial column exists before 20261109003000 grants column-level UPDATE.
-- The later 20261116200000 restoration remains idempotent for existing histories.
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
END;
$migration$;
