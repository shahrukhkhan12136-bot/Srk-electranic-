-- Secure full Razorpay refund intent and reconciliation workflow.
CREATE TABLE IF NOT EXISTS public.srk_razorpay_refunds (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_id uuid NOT NULL UNIQUE REFERENCES public.service_bookings(id) ON DELETE RESTRICT,
  payment_id text NOT NULL CHECK (payment_id ~ '^pay_[A-Za-z0-9]+$'),
  refund_id text UNIQUE CHECK (refund_id IS NULL OR refund_id ~ '^rfnd_[A-Za-z0-9]+$'),
  amount numeric(12,2) NOT NULL CHECK (amount > 0 AND amount <= 10000000),
  amount_paise bigint NOT NULL CHECK (amount_paise > 0 AND amount_paise <= 1000000000),
  currency text NOT NULL DEFAULT 'INR' CHECK (currency='INR'),
  idempotency_key text NOT NULL UNIQUE CHECK (length(idempotency_key) BETWEEN 10 AND 36),
  status text NOT NULL DEFAULT 'requested' CHECK (status IN ('requested','processing','unknown','processed','failed')),
  provider_status text,
  reason text NOT NULL CHECK (length(reason) BETWEEN 20 AND 250),
  admin_user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
  previous_payout_note text,
  last_error text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  processed_at timestamptz
);
CREATE INDEX IF NOT EXISTS srk_razorpay_refunds_status_idx ON public.srk_razorpay_refunds(status,created_at DESC);
ALTER TABLE public.srk_razorpay_refunds ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.srk_razorpay_refunds FROM PUBLIC,anon,authenticated;
GRANT SELECT,INSERT,UPDATE ON TABLE public.srk_razorpay_refunds TO service_role;

ALTER TABLE public.srk_razorpay_webhook_events
  ADD COLUMN IF NOT EXISTS razorpay_refund_id text;

ALTER TABLE public.srk_admin_audit_events
  DROP CONSTRAINT IF EXISTS srk_admin_audit_events_entity_type_check;
ALTER TABLE public.srk_admin_audit_events
  ADD CONSTRAINT srk_admin_audit_events_entity_type_check
  CHECK (entity_type IN ('booking','electrician_profile','electrician_application','manual_payment','manual_refund','electrician_payout','razorpay_refund'));