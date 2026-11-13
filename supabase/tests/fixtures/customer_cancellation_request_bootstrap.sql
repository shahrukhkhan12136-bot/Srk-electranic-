-- Synthetic disposable baseline for cancellation-request intake pgTAP.
CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS pgtap;
-- Use Supabase's pre-provisioned auth schema and auth.uid() implementation.
CREATE TABLE public.service_bookings(
 id uuid PRIMARY KEY,
 customer_user_id uuid REFERENCES auth.users(id),
 status text NOT NULL,
 payment_status text DEFAULT 'unpaid',
 work_timer_running boolean DEFAULT false,
 work_timer_elapsed_seconds numeric(24,6) DEFAULT 0,
 customer_name text,
 phone text,
 service_type text,
 preferred_date date,
 preferred_time time
);
CREATE TABLE public.srk_booking_labour_bills(
 booking_id uuid PRIMARY KEY REFERENCES public.service_bookings(id)
);
CREATE OR REPLACE FUNCTION public.is_srk_admin()
RETURNS boolean LANGUAGE sql STABLE AS $$
 SELECT coalesce(current_setting('test.srk_admin',true),'false')='true'
$$;
