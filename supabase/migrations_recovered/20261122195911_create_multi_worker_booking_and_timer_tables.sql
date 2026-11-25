
create table if not exists public.srk_booking_workers (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null references public.service_bookings(id) on delete restrict,
  worker_id uuid not null references public.srk_worker_profiles(id) on delete restrict,
  worker_role text not null,
  assignment_status text not null default 'offered',
  assigned_at timestamptz not null default now(),
  accepted_at timestamptz,
  rejected_at timestamptz,
  released_at timestamptz,
  offered_by uuid,
  admin_note text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint srk_booking_worker_role_valid check (worker_role in ('technician','helper')),
  constraint srk_booking_worker_status_valid check (assignment_status in ('offered','accepted','rejected','assigned','working','paused','completed','cancelled','released')),
  constraint srk_booking_worker_unique unique(booking_id,worker_id)
);

create index if not exists srk_booking_workers_worker_status_idx
  on public.srk_booking_workers(worker_id,assignment_status);
create index if not exists srk_booking_workers_booking_idx
  on public.srk_booking_workers(booking_id,assignment_status);

create table if not exists public.srk_worker_work_sessions (
  id uuid primary key default gen_random_uuid(),
  booking_worker_id uuid not null references public.srk_booking_workers(id) on delete restrict,
  work_date date not null default (now() at time zone 'Asia/Kolkata')::date,
  session_status text not null default 'not_started',
  started_at timestamptz,
  ended_at timestamptz,
  last_resumed_at timestamptz,
  billable_seconds bigint not null default 0,
  pause_reason text,
  completion_note text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint srk_work_session_status_valid check (session_status in ('not_started','running','paused','completed','cancelled')),
  constraint srk_work_session_seconds_valid check (billable_seconds between 0 and 5184000),
  constraint srk_work_session_pause_reason_valid check (
    pause_reason is null or pause_reason in ('food_break','material','customer_permission','technical_problem','other')
  ),
  constraint srk_work_session_time_order check (
    (started_at is null or started_at <= coalesce(ended_at,'infinity'::timestamptz))
    and (last_resumed_at is null or started_at is not null)
  ),
  constraint srk_work_session_unique_day unique(booking_worker_id,work_date)
);

create unique index if not exists srk_one_running_session_per_worker
  on public.srk_worker_work_sessions(booking_worker_id)
  where session_status='running';

create index if not exists srk_worker_sessions_status_idx
  on public.srk_worker_work_sessions(session_status,work_date);

create table if not exists public.srk_worker_session_events (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null references public.srk_worker_work_sessions(id) on delete restrict,
  event_type text not null,
  event_at timestamptz not null default now(),
  actor_user_id uuid,
  pause_reason text,
  note text,
  source text not null default 'app',
  idempotency_key text unique,
  created_at timestamptz not null default now(),
  constraint srk_worker_session_event_type_valid
    check (event_type in ('started','paused','resumed','completed','cancelled','offline_sync','admin_adjusted')),
  constraint srk_worker_session_event_pause_reason_valid
    check (pause_reason is null or pause_reason in ('food_break','material','customer_permission','technical_problem','other')),
  constraint srk_worker_session_event_source_valid
    check (source in ('app','admin','offline_sync','system'))
);

create index if not exists srk_worker_session_events_timeline_idx
  on public.srk_worker_session_events(session_id,event_at);

create table if not exists public.srk_worker_schedule_blocks (
  id uuid primary key default gen_random_uuid(),
  worker_id uuid not null references public.srk_worker_profiles(id) on delete restrict,
  booking_worker_id uuid references public.srk_booking_workers(id) on delete restrict,
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  block_status text not null default 'reserved',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint srk_worker_schedule_time_valid check (ends_at > starts_at),
  constraint srk_worker_schedule_status_valid check (block_status in ('reserved','confirmed','in_progress','completed','cancelled'))
);

create index if not exists srk_worker_schedule_worker_time_idx
  on public.srk_worker_schedule_blocks(worker_id,starts_at,ends_at)
  where block_status in ('reserved','confirmed','in_progress');

alter table public.srk_booking_workers enable row level security;
alter table public.srk_worker_work_sessions enable row level security;
alter table public.srk_worker_session_events enable row level security;
alter table public.srk_worker_schedule_blocks enable row level security;
