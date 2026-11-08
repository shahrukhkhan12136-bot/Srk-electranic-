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
