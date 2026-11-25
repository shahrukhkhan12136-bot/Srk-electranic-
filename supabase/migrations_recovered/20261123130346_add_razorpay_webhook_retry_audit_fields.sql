ALTER TABLE public.srk_razorpay_webhook_events
  ADD COLUMN IF NOT EXISTS signature_verified_at timestamptz,
  ADD COLUMN IF NOT EXISTS processing_attempts integer NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS last_error text,
  ADD COLUMN IF NOT EXISTS next_retry_at timestamptz;

ALTER TABLE public.srk_razorpay_webhook_events
  ADD CONSTRAINT srk_razorpay_webhook_attempts_nonnegative
  CHECK (processing_attempts >= 0) NOT VALID;
ALTER TABLE public.srk_razorpay_webhook_events
  VALIDATE CONSTRAINT srk_razorpay_webhook_attempts_nonnegative;

CREATE INDEX IF NOT EXISTS srk_razorpay_webhook_retry_due_idx
ON public.srk_razorpay_webhook_events (next_retry_at, received_at)
WHERE processing_status IN ('received','processing_error');

COMMENT ON COLUMN public.srk_razorpay_webhook_events.signature_verified_at IS
'Set only by trusted webhook ingress after successful Razorpay HMAC signature verification.';
COMMENT ON COLUMN public.srk_razorpay_webhook_events.processing_attempts IS
'Number of trusted processing attempts; incremented by service-side webhook processor.';
COMMENT ON COLUMN public.srk_razorpay_webhook_events.next_retry_at IS
'Next eligible retry time for transient processing failures; null when not scheduled.';