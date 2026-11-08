-- Store optional GPS coordinates for customer booking and electrician work base.
-- Coordinates are collected only after explicit browser location permission.
ALTER TABLE public.service_bookings
  ADD COLUMN IF NOT EXISTS location_lat double precision,
  ADD COLUMN IF NOT EXISTS location_lng double precision;
ALTER TABLE public.electrician_applications
  ADD COLUMN IF NOT EXISTS location_lat double precision,
  ADD COLUMN IF NOT EXISTS location_lng double precision;
ALTER TABLE public.electrician_profiles
  ADD COLUMN IF NOT EXISTS location_lat double precision,
  ADD COLUMN IF NOT EXISTS location_lng double precision;
ALTER TABLE public.service_bookings
  ADD CONSTRAINT service_bookings_location_pair_check CHECK ((location_lat IS NULL) = (location_lng IS NULL)) NOT VALID,
  ADD CONSTRAINT service_bookings_location_range_check CHECK (location_lat IS NULL OR (location_lat BETWEEN -90 AND 90 AND location_lng BETWEEN -180 AND 180)) NOT VALID;
ALTER TABLE public.electrician_applications
  ADD CONSTRAINT electrician_applications_location_pair_check CHECK ((location_lat IS NULL) = (location_lng IS NULL)) NOT VALID,
  ADD CONSTRAINT electrician_applications_location_range_check CHECK (location_lat IS NULL OR (location_lat BETWEEN -90 AND 90 AND location_lng BETWEEN -180 AND 180)) NOT VALID;
ALTER TABLE public.electrician_profiles
  ADD CONSTRAINT electrician_profiles_location_pair_check CHECK ((location_lat IS NULL) = (location_lng IS NULL)) NOT VALID,
  ADD CONSTRAINT electrician_profiles_location_range_check CHECK (location_lat IS NULL OR (location_lat BETWEEN -90 AND 90 AND location_lng BETWEEN -180 AND 180)) NOT VALID;
CREATE OR REPLACE FUNCTION public.srk_admin_review_application(p_application_id uuid, p_decision text)
 RETURNS void LANGUAGE plpgsql SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public', 'auth', 'pg_temp'
AS $function$
declare a public.electrician_applications%rowtype; linked_user uuid;
begin
  if auth.uid() is null or not public.is_srk_admin() then raise exception 'Admin only'; end if;
  if p_application_id is null or p_decision is null or p_decision not in ('approved','rejected','suspended') then raise exception 'Invalid decision'; end if;
  select * into a from public.electrician_applications where id=p_application_id for update;
  if not found then raise exception 'Application not found'; end if;
  if p_decision='approved' then
    select u.id into linked_user from auth.users u where u.phone_confirmed_at is not null
      and right(regexp_replace(coalesce(u.phone,''),'[^0-9]','','g'),10)=a.phone order by u.created_at desc limit 1;
    if linked_user is null then raise exception 'Electrician must verify this application phone by OTP before approval'; end if;
  end if;
  update public.electrician_applications set verification_status=p_decision,active=false where id=p_application_id;
  if p_decision='approved' then
    insert into public.electrician_profiles
      (application_id,display_name,phone,state,district,pincode,skills,active,verification_status,user_id,auth_user_id,location_lat,location_lng)
    values (p_application_id,a.full_name,a.phone,a.state,a.district,a.pincode,
      case when nullif(trim(a.skills),'') is null then array[]::text[] else string_to_array(a.skills,',') end,
      false,'approved',linked_user,linked_user,a.location_lat,a.location_lng)
    on conflict (application_id) do update set display_name=excluded.display_name,phone=excluded.phone,state=excluded.state,
      district=excluded.district,pincode=excluded.pincode,skills=excluded.skills,verification_status='approved',active=false,
      user_id=excluded.user_id,auth_user_id=excluded.auth_user_id,location_lat=excluded.location_lat,location_lng=excluded.location_lng;
  else
    update public.electrician_profiles set active=false,verification_status=p_decision where application_id=p_application_id;
  end if;
end;
$function$;

ALTER TABLE public.service_bookings VALIDATE CONSTRAINT service_bookings_location_pair_check;
ALTER TABLE public.service_bookings VALIDATE CONSTRAINT service_bookings_location_range_check;
ALTER TABLE public.electrician_applications VALIDATE CONSTRAINT electrician_applications_location_pair_check;
ALTER TABLE public.electrician_applications VALIDATE CONSTRAINT electrician_applications_location_range_check;
ALTER TABLE public.electrician_profiles VALIDATE CONSTRAINT electrician_profiles_location_pair_check;
ALTER TABLE public.electrician_profiles VALIDATE CONSTRAINT electrician_profiles_location_range_check;
