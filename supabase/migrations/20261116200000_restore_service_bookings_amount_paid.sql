-- Idempotent fallback for installations whose legacy baseline omitted amount_paid.
-- The PR #8 disposable replay prerequisite script uses these same constraint names.
ALTER TABLE public.service_bookings
  ADD COLUMN IF NOT EXISTS amount_paid numeric(12,2);

DO $migration$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conrelid = 'public.service_bookings'::regclass
      AND conname = 'service_bookings_amount_paid_nonnegative'
  ) THEN
    ALTER TABLE public.service_bookings
      ADD CONSTRAINT service_bookings_amount_paid_nonnegative
      CHECK (amount_paid IS NULL OR amount_paid >= 0) NOT VALID;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conrelid = 'public.service_bookings'::regclass
      AND conname = 'service_bookings_amount_paid_range'
  ) THEN
    ALTER TABLE public.service_bookings
      ADD CONSTRAINT service_bookings_amount_paid_range
      CHECK (amount_paid IS NULL OR amount_paid BETWEEN 0 AND 10000000) NOT VALID;
  END IF;
END;
$migration$;
