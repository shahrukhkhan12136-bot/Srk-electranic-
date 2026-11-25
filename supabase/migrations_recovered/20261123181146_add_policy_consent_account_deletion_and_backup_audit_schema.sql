
create table if not exists public.srk_policy_documents (
  id uuid primary key default gen_random_uuid(),
  policy_type text not null check (policy_type in ('terms','privacy')),
  audience_role text not null check (audience_role in ('customer','technician','helper')),
  language_code text not null default 'hi',
  version text not null,
  title text not null,
  body text not null,
  status text not null default 'draft' check (status in ('draft','published','retired')),
  effective_at timestamptz,
  created_by uuid,
  created_at timestamptz not null default now(),
  unique(policy_type,audience_role,language_code,version)
);
create unique index if not exists srk_policy_one_published_version
  on public.srk_policy_documents(policy_type,audience_role,language_code)
  where status='published';

create table if not exists public.srk_policy_consents (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null,
  audience_role text not null check (audience_role in ('customer','technician','helper')),
  policy_document_id uuid not null references public.srk_policy_documents(id) on delete restrict,
  accepted boolean not null,
  accepted_at timestamptz not null default now(),
  policy_version text not null,
  ip_address inet,
  user_agent text,
  created_at timestamptz not null default now(),
  unique(user_id,audience_role,policy_document_id)
);
create index if not exists srk_policy_consents_user_time_idx
  on public.srk_policy_consents(user_id,audience_role,accepted_at desc);

create table if not exists public.srk_account_deletion_requests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null,
  account_role text not null check (account_role in ('customer','technician','helper')),
  request_reason text,
  status text not null default 'requested'
    check (status in ('requested','under_review','approved','rejected','processing','completed','on_hold')),
  requested_at timestamptz not null default now(),
  reviewed_by uuid,
  reviewed_at timestamptz,
  review_reason text,
  completed_at timestamptz,
  retention_explanation text,
  legal_hold boolean not null default false,
  created_at timestamptz not null default now()
);
create index if not exists srk_account_deletion_user_idx
  on public.srk_account_deletion_requests(user_id,requested_at desc);

create table if not exists public.srk_backup_runs (
  id uuid primary key default gen_random_uuid(),
  backup_kind text not null check (backup_kind in ('database','storage','full')),
  started_at timestamptz not null default now(),
  completed_at timestamptz,
  status text not null default 'queued'
    check (status in ('queued','running','succeeded','failed','verified')),
  retention_until timestamptz,
  storage_reference text,
  checksum text,
  size_bytes bigint check (size_bytes is null or size_bytes>=0),
  restore_tested_at timestamptz,
  restore_test_status text check (restore_test_status is null or restore_test_status in ('passed','failed','not_run')),
  failure_reason text,
  created_at timestamptz not null default now()
);
create index if not exists srk_backup_runs_retention_idx
  on public.srk_backup_runs(retention_until);
create index if not exists srk_backup_runs_status_idx
  on public.srk_backup_runs(status,started_at desc);

alter table public.srk_policy_documents enable row level security;
alter table public.srk_policy_consents enable row level security;
alter table public.srk_account_deletion_requests enable row level security;
alter table public.srk_backup_runs enable row level security;
