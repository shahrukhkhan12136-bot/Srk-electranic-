
create table if not exists public.srk_worker_profiles (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null unique references auth.users(id) on delete restrict,
  worker_type text not null,
  worker_code text unique,
  full_name text not null,
  phone text not null,
  category_id uuid references public.srk_service_categories(id) on delete restrict,
  legacy_electrician_profile_id uuid unique
    references public.electrician_profiles(id) on delete restrict,
  verification_status text not null default 'pending',
  is_active boolean not null default false,
  is_online boolean not null default false,
  father_name text,
  date_of_birth date,
  photo_path text,
  address text,
  state text,
  district text,
  pincode text,
  location_lat double precision,
  location_lng double precision,
  service_radius_km numeric(5,2) not null default 30,
  experience_years integer not null default 0,
  has_helper boolean not null default false,
  bank_account_last4 text,
  upi_id text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint srk_worker_type_valid check (worker_type in ('technician','helper')),
  constraint srk_worker_verification_valid check (verification_status in ('pending','under_review','approved','rejected','suspended')),
  constraint srk_worker_name_valid check (length(btrim(full_name)) between 2 and 120),
  constraint srk_worker_phone_valid check (length(regexp_replace(phone,'[^0-9]','','g')) between 10 and 15),
  constraint srk_worker_radius_valid check (service_radius_km > 0 and service_radius_km <= 30),
  constraint srk_worker_experience_valid check (experience_years between 0 and 60),
  constraint srk_worker_location_lat_valid check (location_lat is null or location_lat between -90 and 90),
  constraint srk_worker_location_lng_valid check (location_lng is null or location_lng between -180 and 180),
  constraint srk_worker_legacy_link_only_technician
    check (legacy_electrician_profile_id is null or worker_type = 'technician')
);

create table if not exists public.srk_worker_skills (
  id uuid primary key default gen_random_uuid(),
  worker_id uuid not null references public.srk_worker_profiles(id) on delete restrict,
  skill_id uuid not null references public.srk_service_skills(id) on delete restrict,
  verification_status text not null default 'pending',
  reviewed_by uuid,
  reviewed_at timestamptz,
  admin_note text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint srk_worker_skill_status_valid check (verification_status in ('pending','approved','rejected')),
  constraint srk_worker_skill_unique unique(worker_id,skill_id),
  constraint srk_worker_skill_review_consistency
    check ((verification_status='pending' and reviewed_at is null) or
           (verification_status<>'pending' and reviewed_at is not null))
);

create index if not exists srk_worker_profiles_matching_idx
  on public.srk_worker_profiles(category_id, verification_status, is_active, is_online);

create index if not exists srk_worker_profiles_location_idx
  on public.srk_worker_profiles(location_lat, location_lng)
  where is_active and is_online and verification_status='approved';

create index if not exists srk_worker_skills_approved_idx
  on public.srk_worker_skills(skill_id, worker_id)
  where verification_status='approved';

alter table public.srk_worker_profiles enable row level security;
alter table public.srk_worker_skills enable row level security;

insert into public.srk_worker_profiles
  (user_id, worker_type, full_name, phone, category_id,
   legacy_electrician_profile_id, verification_status, is_active,
   state, district, pincode, location_lat, location_lng, experience_years)
select
  coalesce(ep.auth_user_id, ep.user_id),
  'technician',
  ep.display_name,
  ep.phone,
  c.id,
  ep.id,
  ep.verification_status,
  ep.active,
  ep.state,
  ep.district,
  ep.pincode,
  ep.location_lat,
  ep.location_lng,
  coalesce(ea.experience_years,0)
from public.electrician_profiles ep
left join public.electrician_applications ea on ea.id=ep.application_id
left join public.srk_service_categories c on c.category_code='electrician'
where coalesce(ep.auth_user_id,ep.user_id) is not null
on conflict (user_id) do nothing;
