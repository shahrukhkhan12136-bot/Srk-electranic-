-- Web Push subscriptions for electrician booking alerts.
-- Staged on the feature branch only; do not apply to production until end-to-end testing.
create table if not exists public.srk_push_subscriptions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  endpoint text not null unique check (length(endpoint) between 20 and 4096),
  p256dh text not null check (length(p256dh) between 20 and 256),
  auth text not null check (length(auth) between 10 and 128),
  user_agent text check (user_agent is null or length(user_agent) <= 500),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists srk_push_subscriptions_user_idx
  on public.srk_push_subscriptions(user_id);
alter table public.srk_push_subscriptions enable row level security;
revoke all on public.srk_push_subscriptions from anon;
grant select, insert, update, delete on public.srk_push_subscriptions to authenticated;
drop policy if exists "Users manage own push subscriptions" on public.srk_push_subscriptions;
create policy "Users manage own push subscriptions"
  on public.srk_push_subscriptions
  for all to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));
