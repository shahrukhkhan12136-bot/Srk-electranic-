
create table if not exists public.srk_worker_applications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete restrict,
  worker_type text not null,
  category_id uuid not null references public.srk_service_categories(id) on delete restrict,
  full_name text not null,
  phone text not null,
  father_name text,
  date_of_birth date,
  photo_path text,
  address text not null,
  state text not null,
  district text not null,
  pincode text not null,
  experience_years integer not null default 0,
  about text,
  status text not null default 'pending',
  reviewed_by uuid,
  reviewed_at timestamptz,
  admin_note text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint srk_worker_application_type_valid check(worker_type in ('technician','helper')),
  constraint srk_worker_application_status_valid check(status in ('pending','under_review','approved','rejected','more_info','withdrawn')),
  constraint srk_worker_application_experience_valid check(experience_years between 0 and 60),
  constraint srk_worker_application_phone_valid check(phone ~ '^[0-9]{10}$'),
  constraint srk_worker_application_pincode_valid check(pincode ~ '^[0-9]{6}$'),
  constraint srk_worker_application_unique unique(user_id,category_id,worker_type)
);

create table if not exists public.srk_worker_documents (
  id uuid primary key default gen_random_uuid(),
  worker_id uuid references public.srk_worker_profiles(id) on delete restrict,
  application_id uuid references public.srk_worker_applications(id) on delete restrict,
  document_type text not null,
  storage_path text not null,
  file_name text not null,
  mime_type text not null,
  file_size_bytes bigint not null,
  review_status text not null default 'pending',
  reviewed_by uuid,
  reviewed_at timestamptz,
  admin_note text,
  created_at timestamptz not null default now(),
  constraint srk_worker_document_owner_required check(worker_id is not null or application_id is not null),
  constraint srk_worker_document_status_valid check(review_status in ('pending','approved','rejected','more_info')),
  constraint srk_worker_document_size_valid check(file_size_bytes between 1 and 20971520)
);

create table if not exists public.srk_worker_document_events (
  id uuid primary key default gen_random_uuid(),
  document_id uuid not null references public.srk_worker_documents(id) on delete restrict,
  actor_user_id uuid not null,
  action text not null,
  note text,
  created_at timestamptz not null default now()
);

create table if not exists public.srk_admin_permissions (
  permission_code text primary key,
  description text not null
);

create table if not exists public.srk_admin_roles (
  id uuid primary key default gen_random_uuid(),
  role_code text not null unique,
  role_name text not null,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.srk_admin_role_permissions (
  role_id uuid not null references public.srk_admin_roles(id) on delete cascade,
  permission_code text not null references public.srk_admin_permissions(permission_code) on delete restrict,
  primary key(role_id,permission_code)
);

create table if not exists public.srk_admin_staff_members (
  user_id uuid primary key references auth.users(id) on delete restrict,
  role_id uuid not null references public.srk_admin_roles(id) on delete restrict,
  is_active boolean not null default true,
  invited_by uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

insert into public.srk_admin_permissions(permission_code,description) values
 ('dashboard.read','View operational dashboard'),
 ('customers.manage','Manage customer accounts'),
 ('workers.verify','Review worker applications, documents and skills'),
 ('workers.manage','Manage worker profiles and availability'),
 ('bookings.manage','Manage bookings, assignments and schedules'),
 ('payments.read','View payments and commissions'),
 ('payouts.manage','Review and pay worker payouts'),
 ('refunds.manage','Review and process refunds'),
 ('support.manage','Manage complaints and emergency cases'),
 ('catalog.manage','Manage categories, services, skills and rates'),
 ('ratings.moderate','Moderate ratings'),
 ('notifications.manage','Manage app notifications'),
 ('audit.read','Read admin audit events'),
 ('staff.manage','Manage admin staff and permissions'),
 ('system.recovery','Manage database recovery operations')
on conflict(permission_code) do update set description=excluded.description;

insert into public.srk_admin_roles(role_code,role_name) values
 ('booking_manager','Booking Manager'),
 ('worker_verification','Worker Verification'),
 ('finance_manager','Finance Manager'),
 ('support_agent','Support Agent'),
 ('catalog_manager','Service Catalog Manager'),
 ('ratings_moderator','Ratings Moderator'),
 ('system_auditor','System Auditor')
on conflict(role_code) do nothing;

insert into public.srk_admin_role_permissions(role_id,permission_code)
select r.id,v.permission_code
from public.srk_admin_roles r
join (values
 ('booking_manager','dashboard.read'),('booking_manager','bookings.manage'),('booking_manager','customers.manage'),('booking_manager','workers.manage'),
 ('worker_verification','dashboard.read'),('worker_verification','workers.verify'),('worker_verification','workers.manage'),
 ('finance_manager','dashboard.read'),('finance_manager','payments.read'),('finance_manager','payouts.manage'),('finance_manager','refunds.manage'),
 ('support_agent','dashboard.read'),('support_agent','support.manage'),
 ('catalog_manager','dashboard.read'),('catalog_manager','catalog.manage'),
 ('ratings_moderator','dashboard.read'),('ratings_moderator','ratings.moderate'),
 ('system_auditor','dashboard.read'),('system_auditor','audit.read'),('system_auditor','payments.read')
) v(role_code,permission_code) on v.role_code=r.role_code
on conflict do nothing;

create or replace function public.srk_has_admin_permission(p_permission text)
returns boolean language sql stable security definer
set search_path=pg_catalog,public,auth
as $$
  select exists(select 1 from public.srk_admin_users a where a.user_id=auth.uid())
    or exists(
      select 1 from public.srk_admin_staff_members sm
      join public.srk_admin_roles r on r.id=sm.role_id and r.is_active
      join public.srk_admin_role_permissions rp on rp.role_id=r.id
      where sm.user_id=auth.uid() and sm.is_active and rp.permission_code=p_permission
    );
$$;

create or replace function public.srk_admin_set_staff_role(p_user_id uuid,p_role_code text,p_active boolean default true)
returns public.srk_admin_staff_members
language plpgsql security definer
set search_path=pg_catalog,public,auth
as $$
declare v_role uuid; v_member public.srk_admin_staff_members%rowtype;
begin
  if not exists(select 1 from public.srk_admin_users where user_id=auth.uid()) then raise exception 'Super Admin permission required'; end if;
  select id into v_role from public.srk_admin_roles where role_code=p_role_code and is_active;
  if v_role is null then raise exception 'Admin role not found or inactive'; end if;
  insert into public.srk_admin_staff_members(user_id,role_id,is_active,invited_by)
  values(p_user_id,v_role,p_active,auth.uid())
  on conflict(user_id) do update set role_id=excluded.role_id,is_active=excluded.is_active,updated_at=clock_timestamp()
  returning * into v_member;
  return v_member;
end $$;

create table if not exists public.srk_app_notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete restrict,
  notification_type text not null,
  title text not null,
  body text not null,
  related_booking_id uuid references public.service_bookings(id) on delete restrict,
  deep_link text,
  read_at timestamptz,
  created_at timestamptz not null default now()
);
create index if not exists srk_notifications_user_unread_idx
  on public.srk_app_notifications(user_id,created_at desc) where read_at is null;

create table if not exists public.srk_booking_ratings (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null references public.service_bookings(id) on delete restrict,
  rater_user_id uuid not null references auth.users(id) on delete restrict,
  rater_role text not null,
  target_worker_id uuid references public.srk_worker_profiles(id) on delete restrict,
  target_user_id uuid references auth.users(id) on delete restrict,
  rating smallint not null,
  comment text,
  moderation_status text not null default 'pending',
  moderated_by uuid,
  moderated_at timestamptz,
  created_at timestamptz not null default now(),
  constraint srk_booking_rating_role_valid check(rater_role in ('customer','technician','helper')),
  constraint srk_booking_rating_score_valid check(rating between 1 and 5),
  constraint srk_booking_rating_target_valid check((target_worker_id is not null) or (target_user_id is not null)),
  constraint srk_booking_rating_moderation_valid check(moderation_status in ('pending','published','hidden','rejected'))
);
create unique index if not exists srk_booking_rating_unique_worker
  on public.srk_booking_ratings(booking_id,rater_user_id,target_worker_id) where target_worker_id is not null;
create unique index if not exists srk_booking_rating_unique_user
  on public.srk_booking_ratings(booking_id,rater_user_id,target_user_id) where target_user_id is not null;

create table if not exists public.srk_support_cases (
  id uuid primary key default gen_random_uuid(),
  case_number text unique,
  booking_id uuid references public.service_bookings(id) on delete restrict,
  raised_by uuid not null references auth.users(id) on delete restrict,
  raised_by_role text not null,
  category text not null,
  subject text not null,
  description text not null,
  priority text not null default 'normal',
  status text not null default 'open',
  assigned_staff uuid,
  resolution text,
  resolved_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint srk_support_role_valid check(raised_by_role in ('customer','technician','helper')),
  constraint srk_support_priority_valid check(priority in ('low','normal','high','urgent','emergency')),
  constraint srk_support_status_valid check(status in ('open','assigned','in_progress','awaiting_user','resolved','closed'))
);

create table if not exists public.srk_support_case_events (
  id uuid primary key default gen_random_uuid(),
  case_id uuid not null references public.srk_support_cases(id) on delete restrict,
  actor_user_id uuid not null,
  action text not null,
  old_status text,
  new_status text,
  note text,
  created_at timestamptz not null default now()
);

create table if not exists public.srk_support_messages (
  id uuid primary key default gen_random_uuid(),
  case_id uuid not null references public.srk_support_cases(id) on delete restrict,
  sender_user_id uuid not null references auth.users(id) on delete restrict,
  message text not null,
  attachment_path text,
  created_at timestamptz not null default now()
);

create table if not exists public.srk_emergency_alerts (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid references public.service_bookings(id) on delete restrict,
  raised_by uuid not null references auth.users(id) on delete restrict,
  raised_by_role text not null,
  alert_type text not null,
  message text,
  latitude double precision,
  longitude double precision,
  priority text not null default 'urgent',
  status text not null default 'open',
  assigned_staff uuid,
  resolved_at timestamptz,
  created_at timestamptz not null default now(),
  constraint srk_emergency_role_valid check(raised_by_role in ('customer','technician','helper')),
  constraint srk_emergency_priority_valid check(priority in ('urgent','emergency')),
  constraint srk_emergency_status_valid check(status in ('open','acknowledged','responding','resolved','false_alarm'))
);

create table if not exists public.srk_booking_location_shares (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null references public.service_bookings(id) on delete restrict,
  started_by uuid not null references auth.users(id) on delete restrict,
  started_at timestamptz not null default now(),
  ended_at timestamptz,
  constraint srk_location_share_time_valid check(ended_at is null or ended_at>=started_at)
);
create unique index if not exists srk_one_active_location_share
  on public.srk_booking_location_shares(booking_id) where ended_at is null;

create table if not exists public.srk_booking_live_locations (
  id uuid primary key default gen_random_uuid(),
  share_id uuid not null references public.srk_booking_location_shares(id) on delete restrict,
  user_id uuid not null references auth.users(id) on delete restrict,
  latitude double precision not null,
  longitude double precision not null,
  accuracy_m numeric(8,2),
  recorded_at timestamptz not null default now(),
  constraint srk_live_location_lat_valid check(latitude between -90 and 90),
  constraint srk_live_location_lng_valid check(longitude between -180 and 180)
);
create index if not exists srk_booking_live_locations_recent_idx
  on public.srk_booking_live_locations(share_id,recorded_at desc);

create table if not exists public.srk_booking_chat_rooms (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null unique references public.service_bookings(id) on delete restrict,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);
create table if not exists public.srk_booking_chat_members (
  room_id uuid not null references public.srk_booking_chat_rooms(id) on delete restrict,
  user_id uuid not null references auth.users(id) on delete restrict,
  member_role text not null,
  joined_at timestamptz not null default now(),
  left_at timestamptz,
  primary key(room_id,user_id),
  constraint srk_chat_member_role_valid check(member_role in ('customer','technician','helper','admin'))
);
create table if not exists public.srk_booking_chat_messages (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null references public.srk_booking_chat_rooms(id) on delete restrict,
  sender_user_id uuid not null references auth.users(id) on delete restrict,
  message text not null,
  attachment_path text,
  created_at timestamptz not null default now()
);
create index if not exists srk_chat_messages_room_time_idx
  on public.srk_booking_chat_messages(room_id,created_at);

create table if not exists public.srk_ai_language_test_cases (
  id uuid primary key default gen_random_uuid(),
  language_code text not null,
  language_name text not null,
  test_prompt text not null,
  expected_behavior text,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);
create table if not exists public.srk_ai_language_test_results (
  id uuid primary key default gen_random_uuid(),
  test_case_id uuid not null references public.srk_ai_language_test_cases(id) on delete restrict,
  app_type text not null,
  model_version text,
  result_status text not null,
  tester_user_id uuid,
  notes text,
  tested_at timestamptz not null default now(),
  constraint srk_ai_test_app_valid check(app_type in ('customer','technician')),
  constraint srk_ai_test_result_valid check(result_status in ('pass','fail','needs_review'))
);

-- RLS on every new sensitive table.
alter table public.srk_worker_applications enable row level security;
alter table public.srk_worker_documents enable row level security;
alter table public.srk_worker_document_events enable row level security;
alter table public.srk_admin_permissions enable row level security;
alter table public.srk_admin_roles enable row level security;
alter table public.srk_admin_role_permissions enable row level security;
alter table public.srk_admin_staff_members enable row level security;
alter table public.srk_app_notifications enable row level security;
alter table public.srk_booking_ratings enable row level security;
alter table public.srk_support_cases enable row level security;
alter table public.srk_support_case_events enable row level security;
alter table public.srk_support_messages enable row level security;
alter table public.srk_emergency_alerts enable row level security;
alter table public.srk_booking_location_shares enable row level security;
alter table public.srk_booking_live_locations enable row level security;
alter table public.srk_booking_chat_rooms enable row level security;
alter table public.srk_booking_chat_members enable row level security;
alter table public.srk_booking_chat_messages enable row level security;
alter table public.srk_ai_language_test_cases enable row level security;
alter table public.srk_ai_language_test_results enable row level security;

create policy srk_worker_application_self on public.srk_worker_applications
for select to authenticated using(user_id=auth.uid() or public.srk_has_admin_permission('workers.verify'));
create policy srk_worker_documents_owner on public.srk_worker_documents
for select to authenticated using(
  public.srk_has_admin_permission('workers.verify')
  or exists(select 1 from public.srk_worker_applications a where a.id=application_id and a.user_id=auth.uid())
  or exists(select 1 from public.srk_worker_profiles w where w.id=worker_id and w.user_id=auth.uid())
);
create policy srk_worker_document_events_admin on public.srk_worker_document_events
for select to authenticated using(public.srk_has_admin_permission('workers.verify'));
create policy srk_admin_permissions_admin on public.srk_admin_permissions
for select to authenticated using(public.is_srk_admin());
create policy srk_admin_roles_admin on public.srk_admin_roles
for select to authenticated using(public.is_srk_admin());
create policy srk_admin_role_permissions_admin on public.srk_admin_role_permissions
for select to authenticated using(public.is_srk_admin());
create policy srk_admin_staff_members_admin on public.srk_admin_staff_members
for select to authenticated using(public.is_srk_admin());
create policy srk_notifications_owner on public.srk_app_notifications
for select to authenticated using(user_id=auth.uid() or public.is_srk_admin());
create policy srk_booking_ratings_participant on public.srk_booking_ratings
for select to authenticated using(
  rater_user_id=auth.uid() or target_user_id=auth.uid()
  or exists(select 1 from public.srk_worker_profiles w where w.id=target_worker_id and w.user_id=auth.uid())
  or public.srk_has_admin_permission('ratings.moderate')
);
create policy srk_support_cases_participant on public.srk_support_cases
for select to authenticated using(raised_by=auth.uid() or assigned_staff=auth.uid() or public.srk_has_admin_permission('support.manage'));
create policy srk_support_events_participant on public.srk_support_case_events
for select to authenticated using(
  exists(select 1 from public.srk_support_cases c where c.id=case_id and c.raised_by=auth.uid())
  or public.srk_has_admin_permission('support.manage')
);
create policy srk_support_messages_participant on public.srk_support_messages
for select to authenticated using(
  exists(select 1 from public.srk_support_cases c where c.id=case_id and (c.raised_by=auth.uid() or c.assigned_staff=auth.uid()))
  or public.srk_has_admin_permission('support.manage')
);
create policy srk_emergency_alerts_participant on public.srk_emergency_alerts
for select to authenticated using(raised_by=auth.uid() or assigned_staff=auth.uid() or public.srk_has_admin_permission('support.manage'));
create policy srk_location_share_participant on public.srk_booking_location_shares
for select to authenticated using(
  public.is_srk_admin()
  or exists(select 1 from public.service_bookings b where b.id=booking_id and b.customer_user_id=auth.uid())
  or exists(select 1 from public.srk_booking_workers bw join public.srk_worker_profiles w on w.id=bw.worker_id where bw.booking_id=booking_id and w.user_id=auth.uid())
);
create policy srk_live_location_participant on public.srk_booking_live_locations
for select to authenticated using(
  exists(select 1 from public.srk_booking_location_shares sh join public.service_bookings b on b.id=sh.booking_id
    where sh.id=share_id and (b.customer_user_id=auth.uid() or public.is_srk_admin()
      or exists(select 1 from public.srk_booking_workers bw join public.srk_worker_profiles w on w.id=bw.worker_id where bw.booking_id=b.id and w.user_id=auth.uid())))
);
create policy srk_chat_rooms_participant on public.srk_booking_chat_rooms
for select to authenticated using(exists(select 1 from public.srk_booking_chat_members m where m.room_id=id and m.user_id=auth.uid() and m.left_at is null) or public.is_srk_admin());
create policy srk_chat_members_participant on public.srk_booking_chat_members
for select to authenticated using(user_id=auth.uid() or public.is_srk_admin());
create policy srk_chat_messages_participant on public.srk_booking_chat_messages
for select to authenticated using(exists(select 1 from public.srk_booking_chat_members m where m.room_id=room_id and m.user_id=auth.uid() and m.left_at is null) or public.is_srk_admin());
create policy srk_ai_language_test_cases_admin on public.srk_ai_language_test_cases
for select to authenticated using(public.srk_has_admin_permission('catalog.manage') or public.is_srk_admin());
create policy srk_ai_language_test_results_admin on public.srk_ai_language_test_results
for select to authenticated using(public.srk_has_admin_permission('catalog.manage') or public.is_srk_admin());
