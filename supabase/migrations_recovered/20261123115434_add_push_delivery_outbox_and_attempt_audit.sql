
create table if not exists public.srk_push_delivery_jobs (
  id uuid primary key default gen_random_uuid(),
  notification_id uuid not null unique references public.srk_app_notifications(id) on delete cascade,
  user_id uuid not null,
  status text not null default 'queued'
    check (status in ('queued','processing','sent','retry_wait','permanent_failure','cancelled')),
  attempt_count integer not null default 0 check (attempt_count >= 0),
  max_attempts integer not null default 5 check (max_attempts between 1 and 20),
  next_attempt_at timestamptz not null default now(),
  locked_at timestamptz,
  last_attempt_at timestamptz,
  sent_at timestamptz,
  last_error_code text,
  last_error_message text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint srk_push_job_processing_lock check (
    (status = 'processing' and locked_at is not null) or
    (status <> 'processing' and locked_at is null)
  )
);

create table if not exists public.srk_push_delivery_attempts (
  id uuid primary key default gen_random_uuid(),
  job_id uuid not null references public.srk_push_delivery_jobs(id) on delete cascade,
  attempt_number integer not null check (attempt_number > 0),
  outcome text not null check (outcome in ('sent','retryable_failure','permanent_failure','no_subscription')),
  provider_status_code integer,
  error_code text,
  error_message text,
  attempted_at timestamptz not null default now(),
  completed_at timestamptz,
  unique(job_id, attempt_number)
);

create index if not exists srk_push_jobs_due_idx
  on public.srk_push_delivery_jobs(next_attempt_at, created_at)
  where status in ('queued','retry_wait');
create index if not exists srk_push_jobs_user_created_idx
  on public.srk_push_delivery_jobs(user_id, created_at desc);
create index if not exists srk_push_attempts_job_time_idx
  on public.srk_push_delivery_attempts(job_id, attempted_at desc);

alter table public.srk_push_delivery_jobs enable row level security;
alter table public.srk_push_delivery_attempts enable row level security;
revoke all on public.srk_push_delivery_jobs from anon, authenticated;
revoke all on public.srk_push_delivery_attempts from anon, authenticated;
grant all on public.srk_push_delivery_jobs to service_role;
grant all on public.srk_push_delivery_attempts to service_role;

create or replace function private.srk_enqueue_push_delivery_job()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $function$
begin
  insert into public.srk_push_delivery_jobs(notification_id,user_id)
  values(new.id,new.user_id)
  on conflict(notification_id) do nothing;
  return new;
end
$function$;

revoke all on function private.srk_enqueue_push_delivery_job() from public, anon, authenticated;

drop trigger if exists srk_enqueue_push_delivery_job_trigger on public.srk_app_notifications;
create trigger srk_enqueue_push_delivery_job_trigger
after insert on public.srk_app_notifications
for each row execute function private.srk_enqueue_push_delivery_job();

comment on table public.srk_push_delivery_jobs is
'Server-only push outbox. One idempotent delivery job per in-app notification; Edge Function dispatcher integration is a separate deployment step.';
comment on table public.srk_push_delivery_attempts is
'Server-only immutable attempt history for push delivery, including provider outcome and retry diagnostics.';
