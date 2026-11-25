
create table if not exists public.srk_payment_order_locks (
  booking_id uuid primary key references public.service_bookings(id) on delete cascade,
  lock_token uuid not null,
  locked_until timestamptz not null,
  created_at timestamptz not null default now()
);

alter table public.srk_payment_order_locks enable row level security;
revoke all on public.srk_payment_order_locks from public, anon, authenticated;
grant all on public.srk_payment_order_locks to service_role;

create or replace function public.srk_claim_payment_order_lock(p_booking_id uuid)
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_token uuid := gen_random_uuid();
  v_result uuid;
begin
  insert into public.srk_payment_order_locks (booking_id, lock_token, locked_until)
  values (p_booking_id, v_token, now() + interval '5 minutes')
  on conflict (booking_id) do update
    set lock_token = excluded.lock_token,
        locked_until = excluded.locked_until,
        created_at = now()
    where public.srk_payment_order_locks.locked_until < now()
  returning lock_token into v_result;
  return v_result;
end;
$$;

create or replace function public.srk_release_payment_order_lock(p_booking_id uuid, p_lock_token uuid)
returns boolean
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_count integer;
begin
  delete from public.srk_payment_order_locks
   where booking_id = p_booking_id and lock_token = p_lock_token;
  get diagnostics v_count = row_count;
  return v_count = 1;
end;
$$;

revoke all on function public.srk_claim_payment_order_lock(uuid) from public, anon, authenticated;
revoke all on function public.srk_release_payment_order_lock(uuid, uuid) from public, anon, authenticated;
grant execute on function public.srk_claim_payment_order_lock(uuid) to service_role;
grant execute on function public.srk_release_payment_order_lock(uuid, uuid) to service_role;
