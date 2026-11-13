-- Synthetic disposable baseline for cancellation-request intake pgTAP.
CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS pgtap;
CREATE SCHEMA IF NOT EXISTS auth;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='anon') THEN CREATE ROLE anon NOLOGIN; END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='authenticated') THEN CREATE ROLE authenticated NOLOGIN; END IF;
END $$;
CREATE TABLE IF NOT EXISTS auth.users(
 id uuid PRIMARY KEY,
 aud varchar(255) NOT NULL DEFAULT 'authenticated',
 role varchar(255) NOT NULL DEFAULT 'authenticated',
 created_at timestamptz DEFAULT now(),
 updated_at timestamptz DEFAULT now()
);
CREATE OR REPLACE FUNCTION auth.uid()
RETURNS uuid LANGUAGE sql STABLE AS $$
  SELECT nullif(current_setting('request.jwt.claim.sub',true),'')::uuid
$$;
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
