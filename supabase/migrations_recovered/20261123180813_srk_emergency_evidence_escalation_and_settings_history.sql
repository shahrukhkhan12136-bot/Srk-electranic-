
-- SRK ELECTRONIC: emergency response, evidence retention and settings history.
-- Additive-only migration; existing alert and operational records remain intact.
alter table public.srk_emergency_alerts
  add column if not exists acknowledged_by uuid,
  add column if not exists acknowledged_at timestamptz,
  add column if not exists response_due_at timestamptz,
  add column if not exists escalation_level integer not null default 0,
  add column if not exists decision_status text,
  add column if not exists decision_reason text,
  add column if not exists decided_by uuid,
  add column if not exists decided_at timestamptz,
  add column if not exists legal_hold boolean not null default false,
  add column if not exists legal_hold_reason text,
  add column if not exists retention_until timestamptz,
  add column if not exists closed_at timestamptz;

alter table public.srk_emergency_alerts
  drop constraint if exists srk_emergency_alerts_escalation_level_check;
alter table public.srk_emergency_alerts
  add constraint srk_emergency_alerts_escalation_level_check
  check (escalation_level >= 0);

alter table public.srk_emergency_alerts
  drop constraint if exists srk_emergency_alerts_decision_status_check;
alter table public.srk_emergency_alerts
  add constraint srk_emergency_alerts_decision_status_check
  check (decision_status is null or decision_status in ('genuine','false','insufficient_evidence'));

create table if not exists public.srk_emergency_evidence (
  id uuid primary key default gen_random_uuid(),
  alert_id uuid not null references public.srk_emergency_alerts(id) on delete restrict,
  uploaded_by uuid not null,
  uploader_role text not null check (uploader_role in ('customer','technician','helper','admin','staff')),
  evidence_type text not null check (evidence_type in ('photo','video','audio','document','other')),
  storage_bucket text not null,
  storage_path text not null,
  original_file_name text,
  mime_type text,
  file_size_bytes bigint check (file_size_bytes is null or file_size_bytes >= 0),
  captured_at timestamptz,
  created_at timestamptz not null default now(),
  is_sensitive boolean not null default true,
  legal_hold boolean not null default false,
  retention_until timestamptz,
  metadata jsonb not null default '{}'::jsonb,
  unique(storage_bucket, storage_path)
);
create index if not exists srk_emergency_evidence_alert_created_idx
  on public.srk_emergency_evidence(alert_id, created_at);

create table if not exists public.srk_emergency_escalations (
  id uuid primary key default gen_random_uuid(),
  alert_id uuid not null references public.srk_emergency_alerts(id) on delete restrict,
  escalation_level integer not null check (escalation_level > 0),
  triggered_at timestamptz not null default now(),
  response_due_at timestamptz,
  notified_role text,
  notified_user_id uuid,
  delivery_channel text check (delivery_channel is null or delivery_channel in ('in_app','push','sms','call')),
  delivery_status text not null default 'queued'
    check (delivery_status in ('queued','sent','delivered','failed','acknowledged')),
  acknowledged_at timestamptz,
  failure_reason text,
  created_at timestamptz not null default now(),
  unique(alert_id, escalation_level)
);
create index if not exists srk_emergency_escalations_due_idx
  on public.srk_emergency_escalations(response_due_at)
  where acknowledged_at is null;

create table if not exists public.srk_emergency_decision_events (
  id uuid primary key default gen_random_uuid(),
  alert_id uuid not null references public.srk_emergency_alerts(id) on delete restrict,
  decision_status text not null check (decision_status in ('genuine','false','insufficient_evidence')),
  decision_reason text not null,
  decided_by uuid not null,
  decided_at timestamptz not null default now(),
  evidence_summary text,
  created_at timestamptz not null default now()
);
create index if not exists srk_emergency_decision_events_alert_idx
  on public.srk_emergency_decision_events(alert_id, decided_at desc);

create table if not exists public.srk_emergency_legal_holds (
  id uuid primary key default gen_random_uuid(),
  alert_id uuid not null references public.srk_emergency_alerts(id) on delete restrict,
  hold_reason text not null,
  placed_by uuid not null,
  placed_at timestamptz not null default now(),
  released_by uuid,
  released_at timestamptz,
  release_reason text,
  check ((released_at is null and released_by is null) or
         (released_at is not null and released_by is not null and release_reason is not null))
);
create index if not exists srk_emergency_legal_holds_active_idx
  on public.srk_emergency_legal_holds(alert_id) where released_at is null;

create table if not exists public.srk_system_setting_history (
  id uuid primary key default gen_random_uuid(),
  setting_key text not null,
  old_value jsonb,
  new_value jsonb not null,
  changed_by uuid not null,
  change_reason text not null,
  changed_at timestamptz not null default now(),
  applies_to_new_bookings_only boolean not null default true
);
create index if not exists srk_system_setting_history_key_time_idx
  on public.srk_system_setting_history(setting_key, changed_at desc);

-- Keep sensitive evidence and administrative history inaccessible through direct client table grants.
alter table public.srk_emergency_evidence enable row level security;
alter table public.srk_emergency_escalations enable row level security;
alter table public.srk_emergency_decision_events enable row level security;
alter table public.srk_emergency_legal_holds enable row level security;
alter table public.srk_system_setting_history enable row level security;
