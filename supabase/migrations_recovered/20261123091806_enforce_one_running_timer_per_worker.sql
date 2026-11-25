
alter table public.srk_worker_work_sessions
  add column if not exists worker_id uuid;

update public.srk_worker_work_sessions s
set worker_id=bw.worker_id
from public.srk_booking_workers bw
where bw.id=s.booking_worker_id and s.worker_id is null;

do $$
begin
  if exists(select 1 from public.srk_worker_work_sessions where worker_id is null) then
    raise exception 'Cannot enforce worker timer uniqueness: found session without linked worker';
  end if;
end $$;

alter table public.srk_worker_work_sessions
  alter column worker_id set not null;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conrelid='public.srk_worker_work_sessions'::regclass
      and conname='srk_worker_work_sessions_worker_id_fkey'
  ) then
    alter table public.srk_worker_work_sessions
      add constraint srk_worker_work_sessions_worker_id_fkey
      foreign key(worker_id) references public.srk_worker_profiles(id);
  end if;
end $$;

create index if not exists srk_worker_work_sessions_worker_id_idx
  on public.srk_worker_work_sessions(worker_id);

create or replace function public.srk_set_work_session_worker()
returns trigger
language plpgsql
security definer
set search_path=pg_catalog,public
as $$
declare v_worker_id uuid;
begin
  select worker_id into v_worker_id
  from public.srk_booking_workers
  where id=new.booking_worker_id;
  if v_worker_id is null then
    raise exception 'Booking assignment not found';
  end if;
  if new.worker_id is not null and new.worker_id<>v_worker_id then
    raise exception 'Session worker must match booking assignment';
  end if;
  new.worker_id:=v_worker_id;
  return new;
end;
$$;

drop trigger if exists srk_set_work_session_worker_trg on public.srk_worker_work_sessions;
create trigger srk_set_work_session_worker_trg
before insert or update of booking_worker_id,worker_id
on public.srk_worker_work_sessions
for each row execute function public.srk_set_work_session_worker();

create unique index if not exists srk_one_running_session_per_worker
  on public.srk_worker_work_sessions(worker_id)
  where session_status='running';

