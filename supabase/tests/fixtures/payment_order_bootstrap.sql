-- Synthetic-only baseline for atomic Razorpay order/payment migration tests.
-- This fixture is applied only to an ephemeral local Supabase stack.
CREATE TABLE public.service_bookings (
  id uuid PRIMARY KEY,
  status text NOT NULL,
  payment_method text,
  payment_status text NOT NULL DEFAULT 'unpaid',
  payment_verified_at timestamptz,
  razorpay_payment_id text,
  razorpay_order_id text,
  selected_category text,
  completion_approval_status text,
  quote_status text,
  service_charge numeric(12,2),
  materials_amount numeric(12,2),
  quoted_amount numeric(12,2),
  amount_paid numeric(12,2)
);

CREATE TABLE public.srk_booking_labour_bills (
  booking_id uuid PRIMARY KEY REFERENCES public.service_bookings(id) ON DELETE RESTRICT,
  labour_amount_paise bigint NOT NULL
);
