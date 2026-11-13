-- Synthetic-only baseline for customer payment and refund history RPC tests.
-- This fixture is loaded only into an ephemeral local Supabase stack.
CREATE TABLE public.service_bookings (
 id uuid PRIMARY KEY,
 customer_user_id uuid NOT NULL,
 payment_method text,
 payment_status text,
 amount_paid numeric(18,2),
 payment_verified_at timestamptz,
 created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE public.srk_booking_refund_requests (
 id uuid PRIMARY KEY,
 booking_id uuid NOT NULL REFERENCES public.service_bookings(id),
 customer_user_id uuid NOT NULL,
 amount numeric(18,2) NOT NULL,
 reason text NOT NULL,
 status text NOT NULL,
 created_at timestamptz NOT NULL DEFAULT now(),
 updated_at timestamptz,
 processed_at timestamptz
);
CREATE TABLE public.srk_razorpay_refunds (
 id uuid PRIMARY KEY,
 booking_id uuid NOT NULL REFERENCES public.service_bookings(id),
 amount numeric(18,2) NOT NULL,
 status text NOT NULL,
 created_at timestamptz NOT NULL DEFAULT now(),
 updated_at timestamptz,
 processed_at timestamptz
);
CREATE TABLE public.srk_manual_payment_entries (
 id uuid PRIMARY KEY,
 booking_id uuid NOT NULL REFERENCES public.service_bookings(id),
 amount numeric(18,2) NOT NULL,
 payment_method text,
 recorded_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE public.srk_manual_refund_entries (
 id uuid PRIMARY KEY,
 payment_entry_id uuid NOT NULL REFERENCES public.srk_manual_payment_entries(id),
 amount numeric(18,2) NOT NULL,
 recorded_at timestamptz NOT NULL DEFAULT now()
);
