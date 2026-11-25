-- Push subscriptions are private to the authenticated electrician account.
create table if not exists public.srk_push_subscriptions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  endpoint text not null unique,
  p256dh text not null,
  auth text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint srk_push_endpoint_length check (length(endpoint) between 1 and 2048),
  constraint srk_push_p256dh_length check (length(p256dh) between 1 and 256),
  constraint srk_push_auth_length check (length(auth) between 1 and 256)
);

create index if not exists srk_push_subscriptions_user_id_idx
  on public.srk_push_subscriptions(user_id);

alter table public.srk_push_subscriptions enable row level security;

drop policy if exists srk_push_subscriptions_select_own on public.srk_push_subscriptions;
create policy srk_push_subscriptions_select_own
  on public.srk_push_subscriptions for select to authenticated
  using (user_id = (select auth.uid()));

drop policy if exists srk_push_subscriptions_insert_own on public.srk_push_subscriptions;
create policy srk_push_subscriptions_insert_own
  on public.srk_push_subscriptions for insert to authenticated
  with check (user_id = (select auth.uid()));

drop policy if exists srk_push_subscriptions_update_own on public.srk_push_subscriptions;
create policy srk_push_subscriptions_update_own
  on public.srk_push_subscriptions for update to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

drop policy if exists srk_push_subscriptions_delete_own on public.srk_push_subscriptions;
create policy srk_push_subscriptions_delete_own
  on public.srk_push_subscriptions for delete to authenticated
  using (user_id = (select auth.uid()));

revoke all on public.srk_push_subscriptions from anon, public;
grant select, insert, update, delete on public.srk_push_subscriptions to authenticated;
