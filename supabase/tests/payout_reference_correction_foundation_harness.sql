-- Minimal isolated PostgreSQL fixture for payout reference correction tests.
DO $roles$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='anon') THEN CREATE ROLE anon NOLOGIN; END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='authenticated') THEN CREATE ROLE authenticated NOLOGIN; END IF;
END
$roles$;

CREATE SCHEMA auth;
CREATE TABLE auth.users(id uuid PRIMARY KEY, phone text);
CREATE OR REPLACE FUNCTION auth.uid()
RETURNS uuid LANGUAGE sql STABLE
AS $fn$
  SELECT nullif(current_setting('request.jwt.claim.sub', true), '')::uuid
$fn$;

CREATE OR REPLACE FUNCTION public.is_srk_admin()
RETURNS boolean LANGUAGE sql STABLE
AS $fn$
  SELECT coalesce(nullif(current_setting('request.jwt.claim.is_srk_admin', true), '')::boolean, false)
$fn$;

CREATE TABLE public.service_bookings(id uuid PRIMARY KEY);
CREATE TABLE public.srk_electrician_payouts(
  id uuid PRIMARY KEY,
  booking_id uuid NOT NULL,
  electrician_profile_id uuid,
  razorpay_payment_id text,
  gross_service_amount numeric NOT NULL DEFAULT 0,
  materials_amount numeric NOT NULL DEFAULT 0,
  platform_commission numeric NOT NULL DEFAULT 0,
  electrician_payable numeric NOT NULL DEFAULT 0,
  payout_status text NOT NULL,
  payout_method text,
  payout_reference text,
  payout_note text,
  paid_by uuid,
  paid_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE public.srk_admin_audit_events(
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  entity_type text NOT NULL,
  entity_id uuid NOT NULL,
  booking_id uuid,
  action text NOT NULL,
  actor_user_id uuid,
  actor_role text NOT NULL,
  changed_fields text[] NOT NULL,
  before_data jsonb NOT NULL,
  after_data jsonb NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- The migration replaces this function body while preserving the attached trigger.
CREATE OR REPLACE FUNCTION public.srk_capture_admin_audit_event()
RETURNS trigger LANGUAGE plpgsql AS $fn$
BEGIN
  RETURN NEW;
END
$fn$;
CREATE TRIGGER srk_audit_electrician_payouts
AFTER INSERT OR UPDATE OR DELETE ON public.srk_electrician_payouts
FOR EACH ROW EXECUTE FUNCTION public.srk_capture_admin_audit_event();

GRANT USAGE ON SCHEMA public, auth TO anon, authenticated;
GRANT EXECUTE ON FUNCTION auth.uid() TO anon, authenticated;
