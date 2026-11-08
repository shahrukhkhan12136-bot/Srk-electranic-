-- SRK ELECTRONIC: consolidated database setup. Run once in Supabase SQL Editor.
-- Existing rows are preserved; no table or customer/provider rows are dropped.

-- 01 — Base schema and payment tracking
-- SRK ELECTRONIC marketplace starter schema (Supabase / PostgreSQL)
-- Run in Supabase SQL Editor. Public website forms must only INSERT; never expose service-role keys.
create extension if not exists pgcrypto;

create table if not exists public.service_bookings (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  customer_name text not null,
  phone text not null check (phone ~ '^[0-9]{10}$'),
  state text not null,
  district text not null,
  pincode text not null check (pincode ~ '^[0-9]{6}$'),
  address text not null,
  service_type text not null,
  preferred_date date,
  preferred_time time,
  work_details text,
  payment_method text not null default 'Cash',
  quoted_amount numeric(12,2) check (quoted_amount is null or quoted_amount >= 0),
  status text not null default 'new' check (status in ('new','confirmed','assigned','in_progress','completed','cancelled')),
  assigned_electrician_id uuid,
  commission_rate numeric(5,2) not null default 15.00 check (commission_rate between 0 and 100),
  commission_amount numeric(12,2),
  payment_status text not null default 'unpaid' check (payment_status in ('unpaid','pending','paid','refunded','failed')),
  razorpay_order_id text unique,
  razorpay_payment_id text unique,
  payment_verified_at timestamptz
);

create table if not exists public.electrician_applications (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  full_name text not null,
  phone text not null check (phone ~ '^[0-9]{10}$'),
  state text not null,
  district text not null,
  pincode text not null check (pincode ~ '^[0-9]{6}$'),
  skills text not null,
  experience_years integer not null default 0 check (experience_years between 0 and 60),
  about text,
  verification_status text not null default 'pending' check (verification_status in ('pending','approved','rejected','suspended')),
  active boolean not null default false
);

create table if not exists public.electrician_profiles (
  id uuid primary key default gen_random_uuid(),
  application_id uuid unique references public.electrician_applications(id),
  display_name text not null,
  phone text not null check (phone ~ '^[0-9]{10}$'),
  state text not null,
  district text not null,
  pincode text not null check (pincode ~ '^[0-9]{6}$'),
  skills text[] not null default '{}',
  active boolean not null default false,
  created_at timestamptz not null default now()
);

create index if not exists bookings_location_status_idx on public.service_bookings(state, district, pincode, status);
create index if not exists electrician_location_active_idx on public.electrician_profiles(state, district, pincode, active);

alter table public.service_bookings enable row level security;
alter table public.electrician_applications enable row level security;
alter table public.electrician_profiles enable row level security;

-- Website visitors may submit a request. They cannot read, edit, or delete customer/provider records.
drop policy if exists "public can submit bookings" on public.service_bookings;
create policy "public can submit bookings" on public.service_bookings for insert to anon, authenticated with check (true);
drop policy if exists "public can apply as electrician" on public.electrician_applications;
create policy "public can apply as electrician" on public.electrician_applications for insert to anon, authenticated with check (true);

-- Do not create public SELECT policies. Admin access should be implemented with Supabase Auth
-- and a server-side role check / service-role Netlify Function. Never put service-role key in browser.

-- Job broadcast queue: every matching approved/active electrician gets an offer row.
alter table public.electrician_profiles
  add column if not exists verification_status text not null default 'pending'
  check (verification_status in ('pending','approved','rejected','suspended'));

create table if not exists public.job_offers (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null references public.service_bookings(id) on delete cascade,
  electrician_id uuid not null references public.electrician_profiles(id) on delete cascade,
  status text not null default 'offered' check (status in ('offered','accepted','declined','expired','cancelled')),
  match_level text not null default 'pincode' check (match_level in ('pincode','district')),
  created_at timestamptz not null default now(),
  responded_at timestamptz,
  unique (booking_id, electrician_id)
);
create index if not exists job_offers_provider_status_idx on public.job_offers(electrician_id, status, created_at desc);
create index if not exists job_offers_booking_idx on public.job_offers(booking_id, created_at desc);
alter table public.job_offers enable row level security;
-- No public read/write policies: all offer creation and access must go through authenticated server functions.



-- 02 — Admin and electrician portals
-- SRK ELECTRONIC: secure Admin + Electrician portals
-- Run AFTER SUPABASE_SCHEMA.sql in Supabase SQL Editor.
create table if not exists public.srk_admin_users (
  user_id uuid primary key references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);

alter table public.electrician_profiles
  add column if not exists user_id uuid unique references auth.users(id) on delete set null;

create index if not exists electrician_profiles_user_id_idx on public.electrician_profiles(user_id);

-- Verified Supabase phone login can claim an approved profile with the same phone number.
create or replace function public.srk_link_electrician_profile()
returns trigger language plpgsql security definer set search_path = public, auth
as $$
begin
  if new.phone is not null and coalesce(new.phone_confirmed_at, null) is not null then
    update public.electrician_profiles
       set user_id = new.id
     where regexp_replace(phone, '[^0-9]', '', 'g') = right(regexp_replace(new.phone, '[^0-9]', '', 'g'), 10)
       and verification_status = 'approved'
       and user_id is null;
  end if;
  return new;
end;
$$;
drop trigger if exists srk_link_electrician_profile_trigger on auth.users;
create trigger srk_link_electrician_profile_trigger
  after insert or update of phone, phone_confirmed_at on auth.users
  for each row execute function public.srk_link_electrician_profile();

create or replace function public.srk_is_admin()
returns boolean language sql stable security definer set search_path = public
as $$ select exists (select 1 from public.srk_admin_users a where a.user_id = auth.uid()); $$;
revoke all on function public.srk_is_admin() from public;
grant execute on function public.srk_is_admin() to authenticated;

-- Admin policies
 drop policy if exists srk_admin_read_bookings on public.service_bookings;
create policy srk_admin_read_bookings on public.service_bookings for select to authenticated using (public.srk_is_admin());
drop policy if exists srk_admin_update_bookings on public.service_bookings;
create policy srk_admin_update_bookings on public.service_bookings for update to authenticated using (public.srk_is_admin()) with check (public.srk_is_admin());
drop policy if exists srk_admin_read_applications on public.electrician_applications;
create policy srk_admin_read_applications on public.electrician_applications for select to authenticated using (public.srk_is_admin());
drop policy if exists srk_admin_update_applications on public.electrician_applications;
create policy srk_admin_update_applications on public.electrician_applications for update to authenticated using (public.srk_is_admin()) with check (public.srk_is_admin());
drop policy if exists srk_admin_manage_profiles on public.electrician_profiles;
create policy srk_admin_manage_profiles on public.electrician_profiles for all to authenticated using (public.srk_is_admin()) with check (public.srk_is_admin());
drop policy if exists srk_admin_read_offers on public.job_offers;
create policy srk_admin_read_offers on public.job_offers for select to authenticated using (public.srk_is_admin());

-- Electricians can see only their own profile, offers, and the booking attached to those offers.
drop policy if exists srk_electrician_read_own_profile on public.electrician_profiles;
create policy srk_electrician_read_own_profile on public.electrician_profiles for select to authenticated using (user_id = auth.uid());
drop policy if exists srk_electrician_read_own_offers on public.job_offers;
create policy srk_electrician_read_own_offers on public.job_offers for select to authenticated
using (exists (select 1 from public.electrician_profiles p where p.id = electrician_id and p.user_id = auth.uid()));
drop policy if exists srk_electrician_read_offered_booking on public.service_bookings;
create policy srk_electrician_read_offered_booking on public.service_bookings for select to authenticated
using (exists (select 1 from public.job_offers o join public.electrician_profiles p on p.id=o.electrician_id where o.booking_id=id and p.user_id=auth.uid()));

-- Safe accept/decline: only the logged-in electrician can respond to their offer.
create or replace function public.srk_respond_to_offer(p_offer_id uuid, p_response text)
returns jsonb language plpgsql security definer set search_path = public
as $$
declare v_booking_id uuid; v_electrician_id uuid; v_offer_status text;
begin
  if p_response not in ('accepted','declined') then raise exception 'Invalid response'; end if;
  select o.booking_id, o.electrician_id, o.status into v_booking_id, v_electrician_id, v_offer_status
  from public.job_offers o join public.electrician_profiles p on p.id=o.electrician_id
  where o.id=p_offer_id and p.user_id=auth.uid() and p.verification_status='approved' and p.active=true
  for update of o;
  if v_booking_id is null then raise exception 'Offer not found or profile not active'; end if;
  if v_offer_status <> 'offered' then raise exception 'Offer already answered'; end if;
  if p_response='accepted' then
    update public.service_bookings set assigned_electrician_id=v_electrician_id, status='assigned'
    where id=v_booking_id and assigned_electrician_id is null and status in ('new','confirmed');
    if not found then raise exception 'This job has already been assigned'; end if;
  end if;
  update public.job_offers set status=p_response, responded_at=now() where id=p_offer_id;
  if p_response='accepted' then
    update public.job_offers set status='expired', responded_at=now()
    where booking_id=v_booking_id and id<>p_offer_id and status='offered';
  end if;
  return jsonb_build_object('success',true,'status',p_response);
end;
$$;
revoke all on function public.srk_respond_to_offer(uuid,text) from public;
grant execute on function public.srk_respond_to_offer(uuid,text) to authenticated;

-- Admin-only approval creates/updates the provider profile. Approval does not imply identity verification;
-- complete manual KYC checks before activating a provider.
create or replace function public.srk_admin_review_application(p_application_id uuid, p_decision text)
returns jsonb language plpgsql security definer set search_path = public
as $$
declare a public.electrician_applications%rowtype;
begin
  if not public.srk_is_admin() then raise exception 'Admin only'; end if;
  if p_decision not in ('approved','rejected','suspended') then raise exception 'Invalid decision'; end if;
  select * into a from public.electrician_applications where id=p_application_id for update;
  if not found then raise exception 'Application not found'; end if;
  update public.electrician_applications set verification_status=p_decision where id=p_application_id;
  if p_decision='approved' then
    insert into public.electrician_profiles(application_id,display_name,phone,state,district,pincode,skills,active,verification_status)
    values(a.id,a.full_name,a.phone,a.state,a.district,a.pincode,string_to_array(a.skills,','),false,'approved')
    on conflict(application_id) do update set display_name=excluded.display_name, phone=excluded.phone,
      state=excluded.state,district=excluded.district,pincode=excluded.pincode,skills=excluded.skills,
      verification_status='approved';
    -- Also link a phone already verified before the admin approved this application.
    update public.electrician_profiles p
       set user_id = (select u.id from auth.users u
         where u.phone_confirmed_at is not null
           and right(regexp_replace(coalesce(u.phone,''), '[^0-9]', '', 'g'), 10) = a.phone
         order by u.created_at desc limit 1)
     where p.application_id = a.id and p.user_id is null;
  else
    update public.electrician_profiles set active=false, verification_status=p_decision where application_id=p_application_id;
  end if;
  return jsonb_build_object('success',true,'decision',p_decision);
end;
$$;
revoke all on function public.srk_admin_review_application(uuid,text) from public;
grant execute on function public.srk_admin_review_application(uuid,text) to authenticated;

-- Only admins can view/manage the allowlist.
alter table public.srk_admin_users enable row level security;
drop policy if exists srk_admin_users_self_read on public.srk_admin_users;
create policy srk_admin_users_self_read on public.srk_admin_users for select to authenticated using (user_id=auth.uid());

-- When an admin marks a booking completed, record the agreed 15% commission.
create or replace function public.srk_calculate_commission_on_completion()
returns trigger language plpgsql set search_path = public
as $$
begin
  if new.status='completed' and old.status is distinct from 'completed' and new.quoted_amount is not null then
    new.commission_amount := round(new.quoted_amount * new.commission_rate / 100, 2);
  end if;
  return new;
end;
$$;
drop trigger if exists srk_booking_commission_trigger on public.service_bookings;
create trigger srk_booking_commission_trigger
before update of status on public.service_bookings
for each row execute function public.srk_calculate_commission_on_completion();



-- 03 — Customer privacy hardening
-- SRK ELECTRONIC security update (run AFTER SUPABASE_SCHEMA.sql and PORTAL_SCHEMA.sql)
-- Purpose: prevent every electrician who receives an offer from seeing the customer's
-- full name, phone number, and exact street address before the job is assigned to them.

-- Remove the older policy that exposed the complete booking row to every offered electrician.
drop policy if exists srk_electrician_read_offered_booking on public.service_bookings;

-- Return a safe offer summary for the logged-in electrician only.
-- Customer contact details and exact address are returned only after this electrician wins
-- the assignment. SECURITY DEFINER is narrowly scoped and checks auth.uid() explicitly.
create or replace function public.srk_get_my_offer_details()
returns table (
  offer_id uuid,
  offer_status text,
  match_level text,
  offer_created_at timestamptz,
  booking_id uuid,
  service_type text,
  state text,
  district text,
  pincode text,
  preferred_date date,
  preferred_time time,
  work_details text,
  quoted_amount numeric,
  booking_status text,
  customer_name text,
  customer_phone text,
  address text
)
language sql
stable
security definer
set search_path = public, auth
as $$
  select
    o.id,
    o.status,
    o.match_level,
    o.created_at,
    b.id,
    b.service_type,
    b.state,
    b.district,
    b.pincode,
    b.preferred_date,
    b.preferred_time,
    b.work_details,
    b.quoted_amount,
    b.status,
    case when b.assigned_electrician_id = p.id then b.customer_name else null end,
    case when b.assigned_electrician_id = p.id then b.phone else null end,
    case when b.assigned_electrician_id = p.id then b.address else null end
  from public.job_offers o
  join public.electrician_profiles p on p.id = o.electrician_id
  join public.service_bookings b on b.id = o.booking_id
  where p.user_id = auth.uid()
    and p.verification_status = 'approved'
    and p.active = true
  order by o.created_at desc
  limit 100;
$$;
revoke all on function public.srk_get_my_offer_details() from public;
grant execute on function public.srk_get_my_offer_details() to authenticated;

-- Keep the job-offer table private; access goes through the checked RPC above.
-- The existing own-offer policy may remain for offer metadata, but it grants no booking PII.



-- 04 — Admin email login compatibility
-- SRK ELECTRONIC: Admin access patch for the EXISTING project
-- Run once in Supabase SQL Editor while signed in as project owner.
-- This uses the existing srk_admin_users row created for your Auth user.

-- Ensure the admin allow-list table is protected.
ALTER TABLE public.srk_admin_users ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS srk_admin_users_self_read ON public.srk_admin_users;
CREATE POLICY srk_admin_users_self_read ON public.srk_admin_users
  FOR SELECT TO authenticated USING (user_id = auth.uid());

-- Admin check used by the website after email/password login.
CREATE OR REPLACE FUNCTION public.is_srk_admin()
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public, auth AS $$
  SELECT EXISTS (SELECT 1 FROM public.srk_admin_users WHERE user_id = auth.uid());
$$;
REVOKE ALL ON FUNCTION public.is_srk_admin() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.is_srk_admin() TO authenticated;

-- Admin-only read/update access to the operational tables.
ALTER TABLE public.service_bookings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.electrician_applications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.electrician_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.job_offers ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS srk_admin_read_bookings ON public.service_bookings;
CREATE POLICY srk_admin_read_bookings ON public.service_bookings
  FOR SELECT TO authenticated USING (public.is_srk_admin());
DROP POLICY IF EXISTS srk_admin_update_bookings ON public.service_bookings;
CREATE POLICY srk_admin_update_bookings ON public.service_bookings
  FOR UPDATE TO authenticated USING (public.is_srk_admin()) WITH CHECK (public.is_srk_admin());

DROP POLICY IF EXISTS srk_admin_read_applications ON public.electrician_applications;
CREATE POLICY srk_admin_read_applications ON public.electrician_applications
  FOR SELECT TO authenticated USING (public.is_srk_admin());
DROP POLICY IF EXISTS srk_admin_update_applications ON public.electrician_applications;
CREATE POLICY srk_admin_update_applications ON public.electrician_applications
  FOR UPDATE TO authenticated USING (public.is_srk_admin()) WITH CHECK (public.is_srk_admin());

DROP POLICY IF EXISTS srk_admin_manage_profiles ON public.electrician_profiles;
CREATE POLICY srk_admin_manage_profiles ON public.electrician_profiles
  FOR ALL TO authenticated USING (public.is_srk_admin()) WITH CHECK (public.is_srk_admin());
DROP POLICY IF EXISTS srk_admin_read_offers ON public.job_offers;
CREATE POLICY srk_admin_read_offers ON public.job_offers
  FOR SELECT TO authenticated USING (public.is_srk_admin());

-- Admin-only application review RPC; creates an inactive profile on approval.
CREATE OR REPLACE FUNCTION public.srk_admin_review_application(p_application_id uuid, p_decision text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, auth AS $$
DECLARE a public.electrician_applications%rowtype;
BEGIN
  IF NOT public.is_srk_admin() THEN RAISE EXCEPTION 'Admin only'; END IF;
  IF p_decision NOT IN ('approved','rejected','suspended') THEN RAISE EXCEPTION 'Invalid decision'; END IF;
  SELECT * INTO a FROM public.electrician_applications WHERE id=p_application_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Application not found'; END IF;
  UPDATE public.electrician_applications SET verification_status=p_decision WHERE id=p_application_id;
  IF p_decision='approved' THEN
    INSERT INTO public.electrician_profiles(application_id,display_name,phone,state,district,pincode,skills,active,verification_status)
    VALUES(a.id,a.full_name,a.phone,a.state,a.district,a.pincode,string_to_array(coalesce(a.skills,''),','),false,'approved')
    ON CONFLICT (application_id) DO UPDATE SET display_name=EXCLUDED.display_name, phone=EXCLUDED.phone,
      state=EXCLUDED.state, district=EXCLUDED.district, pincode=EXCLUDED.pincode, skills=EXCLUDED.skills,
      verification_status='approved', active=false;
    UPDATE public.electrician_profiles p
       SET user_id = (SELECT u.id FROM auth.users u
         WHERE u.phone_confirmed_at IS NOT NULL
           AND right(regexp_replace(coalesce(u.phone,''), '[^0-9]', '', 'g'), 10) = a.phone
         ORDER BY u.created_at DESC LIMIT 1)
     WHERE p.application_id = a.id AND p.user_id IS NULL;
  ELSE
    UPDATE public.electrician_profiles SET active=false, verification_status=p_decision WHERE application_id=p_application_id;
  END IF;
  RETURN jsonb_build_object('success',true,'decision',p_decision);
END; $$;
REVOKE ALL ON FUNCTION public.srk_admin_review_application(uuid,text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.srk_admin_review_application(uuid,text) TO authenticated;

-- Verify the allow-list entry exists (SQL Editor may show false for auth.uid();
-- this query checks the actual stored row directly).
SELECT user_id, created_at FROM public.srk_admin_users ORDER BY created_at DESC;


