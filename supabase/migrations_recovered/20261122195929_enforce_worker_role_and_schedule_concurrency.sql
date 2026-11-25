
create or replace function public.srk_guard_worker_session()
returns trigger
language plpgsql
set search_path = pg_catalog, public
as $$
declare
  v_worker_id uuid;
begin
  select bw.worker_id into v_worker_id
  from public.srk_booking_workers bw
  where bw.id = new.booking_worker_id;

  if v_worker_id is null then
    raise exception 'Booking worker assignment not found';
  end if;

  perform pg_advisory_xact_lock(hashtextextended(v_worker_id::text, 0));

  if new.session_status = 'running' then
    if exists (
      select 1
      from public.srk_worker_work_sessions s
      join public.srk_booking_workers bw on bw.id = s.booking_worker_id
      where bw.worker_id = v_worker_id
        and s.session_status = 'running'
        and s.id <> coalesce(new.id, '00000000-0000-0000-0000-000000000000'::uuid)
    ) then
      raise exception 'Worker already has an active work session at another booking';
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists srk_guard_worker_session_trigger on public.srk_worker_work_sessions;
create trigger srk_guard_worker_session_trigger
before insert or update of booking_worker_id, session_status
on public.srk_worker_work_sessions
for each row execute function public.srk_guard_worker_session();

create or replace function public.srk_guard_worker_schedule_overlap()
returns trigger
language plpgsql
set search_path = pg_catalog, public
as $$
begin
  perform pg_advisory_xact_lock(hashtextextended(new.worker_id::text, 0));

  if new.block_status in ('reserved','confirmed','in_progress') and exists (
    select 1
    from public.srk_worker_schedule_blocks b
    where b.worker_id = new.worker_id
      and b.block_status in ('reserved','confirmed','in_progress')
      and b.id <> coalesce(new.id, '00000000-0000-0000-0000-000000000000'::uuid)
      and tstzrange(b.starts_at,b.ends_at,'[)') && tstzrange(new.starts_at,new.ends_at,'[)')
  ) then
    raise exception 'Worker already has a conflicting scheduled assignment';
  end if;

  return new;
end;
$$;

drop trigger if exists srk_guard_worker_schedule_overlap_trigger on public.srk_worker_schedule_blocks;
create trigger srk_guard_worker_schedule_overlap_trigger
before insert or update of worker_id, starts_at, ends_at, block_status
on public.srk_worker_schedule_blocks
for each row execute function public.srk_guard_worker_schedule_overlap();

create or replace function public.srk_guard_booking_worker_role()
returns trigger
language plpgsql
set search_path = pg_catalog, public
as $$
declare
  v_worker_type text;
begin
  select worker_type into v_worker_type
  from public.srk_worker_profiles
  where id = new.worker_id;

  if v_worker_type is null or v_worker_type <> new.worker_role then
    raise exception 'Assigned worker type does not match booking role';
  end if;

  return new;
end;
$$;

drop trigger if exists srk_guard_booking_worker_role_trigger on public.srk_booking_workers;
create trigger srk_guard_booking_worker_role_trigger
before insert or update of worker_id, worker_role
on public.srk_booking_workers
for each row execute function public.srk_guard_booking_worker_role();
