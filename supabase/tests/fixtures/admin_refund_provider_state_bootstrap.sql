-- Minimal synthetic baseline for the Admin refund queue v3 contract test.
-- Disposable local database only; no production credentials or customer records.
CREATE TABLE public.service_bookings (
  id uuid PRIMARY KEY,
  customer_name text,
  phone text,
  payment_method text,
  payment_status text,
  razorpay_payment_id text
);
CREATE TABLE public.srk_booking_refund_requests (
  id uuid PRIMARY KEY,
  booking_id uuid NOT NULL,
  customer_user_id uuid,
  amount numeric(12,2),
  reason text,
  status text,
  admin_note text,
  refund_record_id uuid,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);
CREATE TABLE public.srk_booking_labour_bills (
  booking_id uuid PRIMARY KEY,
  labour_amount numeric(12,2),
  labour_amount_paise bigint
);
CREATE TABLE public.srk_manual_refund_intents (
  request_id uuid PRIMARY KEY,
  status text,
  transfer_reference text,
  amount_paise bigint
);
CREATE TABLE public.srk_razorpay_refunds (
  id uuid PRIMARY KEY,
  booking_id uuid NOT NULL,
  refund_id text,
  status text,
  provider_status text,
  last_error text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);
CREATE OR REPLACE FUNCTION public.is_srk_admin()
RETURNS boolean LANGUAGE sql STABLE AS $$ SELECT false $$;
