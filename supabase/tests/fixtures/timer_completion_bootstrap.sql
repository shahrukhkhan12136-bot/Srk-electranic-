-- Synthetic-only schema for server timer, immutable labour bill and completion review.
-- This fixture is applied only to an ephemeral local Supabase stack.
CREATE SCHEMA IF NOT EXISTS private;
CREATE SCHEMA IF NOT EXISTS srk_private;

CREATE TABLE public.service_bookings (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 created_at timestamptz NOT NULL DEFAULT now(),
 customer_user_id uuid,
 customer_name text,
 phone text,
 address text,
 state text,
 district text,
 pincode text,
 service_type text,
 preferred_date date,
 preferred_time time,
 work_details text,
 status text NOT NULL DEFAULT 'new',
 assigned_electrician_id uuid,
 payment_method text,
 payment_status text NOT NULL DEFAULT 'unpaid',
 amount_paid numeric(18,2) DEFAULT 0,
 payment_verified_at timestamptz,
 quoted_amount numeric(18,2),
 service_charge numeric(18,2),
 materials_amount numeric(18,2),
 quote_status text,
 quote_note text,
 commission_rate numeric(5,2) DEFAULT 15,
 commission_amount numeric(18,2),
 razorpay_order_id text,
 razorpay_payment_id text,
 work_timer_seconds integer NOT NULL DEFAULT 0,
 work_timer_running boolean NOT NULL DEFAULT false,
 work_started_at timestamptz,
 work_start_approval_status text NOT NULL DEFAULT 'not_requested',
 work_start_requested_at timestamptz,
 completion_requested_at timestamptz,
 completion_approval_status text NOT NULL DEFAULT 'not_requested',
 customer_completed_at timestamptz,
 location_lat double precision,
 location_lng double precision,
 work_timer_elapsed_seconds numeric(24,6) NOT NULL DEFAULT 0,
 work_start_origin_status text,
 labour_rate_tier_snapshot text,
 labour_rate8h_paise_snapshot bigint,
 labour_rate_card_version_snapshot text,
 selected_category text,
 selected_duration_hours smallint
);

CREATE TABLE public.electrician_profiles (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 created_at timestamptz NOT NULL DEFAULT now(),
 user_id uuid,
 auth_user_id uuid,
 display_name text,
 phone text,
 active boolean NOT NULL DEFAULT false,
 verification_status text NOT NULL DEFAULT 'pending',
 state text,
 district text,
 pincode text,
 approved_rate_tier text,
 approved_rate_card_version text,
 rate_tier_approved_by uuid,
 rate_tier_approved_at timestamptz,
 approved_skill_keys text[],
 payout_status text
);

CREATE TABLE public.job_offers (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 booking_id uuid NOT NULL REFERENCES public.service_bookings(id) ON DELETE CASCADE,
 electrician_id uuid NOT NULL REFERENCES public.electrician_profiles(id) ON DELETE CASCADE,
 status text NOT NULL DEFAULT 'offered',
 match_level text NOT NULL DEFAULT 'pincode',
 created_at timestamptz NOT NULL DEFAULT now(),
 responded_at timestamptz,
 UNIQUE(booking_id,electrician_id)
);

CREATE TABLE public.srk_wallet_ledger (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 wallet_id uuid,
 booking_id uuid,
 entry_type text NOT NULL,
 amount numeric(18,2),
 created_at timestamptz NOT NULL DEFAULT now(),
 description text
);
CREATE TABLE public.srk_wallet_accounts (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 user_id uuid,
 wallet_type text,
 balance numeric(18,2) DEFAULT 0,
 created_at timestamptz DEFAULT now()
);
CREATE TABLE public.srk_wallet_bank_links (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 wallet_id uuid,
 status text,
 verified_at timestamptz
);
CREATE TABLE public.srk_electrician_payouts (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 booking_id uuid UNIQUE,
 electrician_profile_id uuid,
 razorpay_payment_id text,
 gross_service_amount numeric(18,2),
 amount numeric(18,2),
 materials_amount numeric(18,2) DEFAULT 0,
 platform_commission numeric(18,2),
 electrician_payable numeric(18,2),
 payout_status text,
 status text,
 payout_note text,
 updated_at timestamptz DEFAULT now(),
 created_at timestamptz DEFAULT now()
);
CREATE TABLE public.srk_razorpay_refunds (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 booking_id uuid,
 amount numeric(18,2),
 status text,
 provider_refund_id text,
 idempotency_key text
);
CREATE TABLE public.srk_booking_refund_requests (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 booking_id uuid,
 amount numeric(18,2),
 status text,
 refund_record_id uuid
);
CREATE TABLE public.srk_manual_payment_entries (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 booking_id uuid,
 amount numeric(18,2),
 status text,
 payment_method text,
 created_at timestamptz DEFAULT now()
);
CREATE TABLE public.srk_booking_complaints (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 booking_id uuid,
 customer_user_id uuid,
 category text,
 description text,
 created_at timestamptz DEFAULT now()
);
CREATE TABLE public.srk_customer_category_skill_rules (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 category text,
 skill_key text,
 active boolean DEFAULT true
);
CREATE TABLE srk_private.work_transition_authorizations (
 transaction_id bigint NOT NULL,
 booking_id uuid NOT NULL,
 target_status text NOT NULL,
 PRIMARY KEY(transaction_id,booking_id,target_status)
);

-- Legacy RPC signatures exist in the live baseline and are revoked by the
-- new timer migration. Stubs model only those names/signatures for local DDL.
CREATE OR REPLACE FUNCTION public.srk_get_my_assigned_booking_quote_details()
RETURNS void LANGUAGE sql AS $function$ SELECT; $function$;
CREATE OR REPLACE FUNCTION public.srk_get_my_offer_price_details()
RETURNS void LANGUAGE sql AS $function$ SELECT; $function$;
CREATE OR REPLACE FUNCTION public.srk_submit_booking_quote(uuid,numeric,numeric,text)
RETURNS void LANGUAGE sql AS $function$ SELECT; $function$;

CREATE OR REPLACE FUNCTION public.is_srk_admin()
RETURNS boolean LANGUAGE sql STABLE
AS $function$
 SELECT COALESCE((current_setting('request.jwt.claims',true)::jsonb->>'role')='service_role',false);
$function$;
