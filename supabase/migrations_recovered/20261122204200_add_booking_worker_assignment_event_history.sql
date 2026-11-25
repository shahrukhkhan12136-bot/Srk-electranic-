
create table if not exists public.srk_booking_worker_events (
  id uuid primary key default gen_random_uuid(),
  booking_worker_id uuid not null references public.srk_booking_workers(id) on delete restrict,
  booking_id uuid not null references public.service_bookings(id) on delete restrict,
  worker_id uuid not null references public.srk_worker_profiles(id) on delete restrict,
  event_type text not null,
  actor_user_id uuid,
  reason text,
  event_at timestamptz not null default now(),
  details jsonb not null default '{}'::jsonb,
  constraint srk_booking_worker_event_type_valid check(event_type in
    ('offered','accepted','rejected','assigned','working','paused','completed','released','cancelled','timed_out'))
);
create index if not exists srk_booking_worker_events_timeline_idx
  on public.srk_booking_worker_events(booking_id,event_at);

alter table public.srk_booking_worker_events enable row level security;
create policy srk_booking_worker_events_participant_read on public.srk_booking_worker_events
for select to authenticated using(
  public.srk_has_admin_permission('bookings.manage')
  or exists(select 1 from public.service_bookings b where b.id=booking_id and b.customer_user_id=auth.uid())
  or exists(select 1 from public.srk_worker_profiles w where w.id=worker_id and w.user_id=auth.uid())
);

create or replace function public.srk_log_booking_worker_event()
returns trigger language plpgsql security definer
set search_path=pg_catalog,public,auth
as $$
declare v_event text; v_reason text;
begin
  if tg_op='INSERT' then
    v_event:=new.assignment_status;
  elsif new.assignment_status is distinct from old.assignment_status then
    v_event:=new.assignment_status;
  else
    return new;
  end if;
  v_reason:=coalesce(new.admin_note,'');
  insert into public.srk_booking_worker_events(booking_worker_id,booking_id,worker_id,event_type,actor_user_id,reason,details)
  values(new.id,new.booking_id,new.worker_id,v_event,auth.uid(),v_reason,
    jsonb_build_object('role',new.worker_role,'offer_expires_at',new.offer_expires_at,'hourly_rate_snapshot',new.hourly_rate_snapshot));
  return new;
end $$;

drop trigger if exists srk_log_booking_worker_event_trigger on public.srk_booking_workers;
create trigger srk_log_booking_worker_event_trigger after insert or update of assignment_status
on public.srk_booking_workers for each row execute function public.srk_log_booking_worker_event();

revoke all on function public.srk_log_booking_worker_event() from public,anon,authenticated;
