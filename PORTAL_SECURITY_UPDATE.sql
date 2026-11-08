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
