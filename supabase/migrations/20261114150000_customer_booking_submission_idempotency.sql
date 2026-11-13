-- Idempotent customer booking submissions: retries must return the original booking,
-- not create a second booking and duplicate electrician offers.
ALTER TABLE public.service_bookings
  ADD COLUMN IF NOT EXISTS customer_request_key uuid,
  ADD COLUMN IF NOT EXISTS customer_request_fingerprint text;

ALTER TABLE public.service_bookings
  ADD CONSTRAINT service_bookings_customer_request_fingerprint_valid
  CHECK (
    (customer_request_key IS NULL AND customer_request_fingerprint IS NULL)
    OR
    (customer_request_key IS NOT NULL AND customer_request_fingerprint IS NOT NULL
      AND customer_request_fingerprint ~ '^[a-f0-9]{64}
  );

CREATE UNIQUE INDEX IF NOT EXISTS service_bookings_customer_request_key_uidx
  ON public.service_bookings(customer_request_key)
  WHERE customer_request_key IS NOT NULL;

COMMENT ON COLUMN public.service_bookings.customer_request_key IS
  'Client-generated UUID idempotency key. Repeated identical submissions return the original booking.';
COMMENT ON COLUMN public.service_bookings.customer_request_fingerprint IS
  'SHA-256 fingerprint of normalized booking payload, used to reject accidental key reuse with changed booking details.';
)
  );

CREATE UNIQUE INDEX IF NOT EXISTS service_bookings_customer_request_key_uidx
  ON public.service_bookings(customer_request_key)
  WHERE customer_request_key IS NOT NULL;

COMMENT ON COLUMN public.service_bookings.customer_request_key IS
  'Client-generated UUID idempotency key. Repeated identical submissions return the original booking.';
COMMENT ON COLUMN public.service_bookings.customer_request_fingerprint IS
  'SHA-256 fingerprint of normalized booking payload, used to reject accidental key reuse with changed booking details.';
