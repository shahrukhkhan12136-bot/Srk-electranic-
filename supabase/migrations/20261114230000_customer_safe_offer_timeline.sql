-- Customer-safe offer lifecycle history for the Customer App.
-- Captures only public lifecycle labels; never stores/exposes electrician identifiers or contact data.
create schema if not exists private;

create table if not exists private.srk_booking_offer_events (
  id uuid primary key default gen_random_uuid(),
  offer_id uuid not null references public.job_offers(id) on delete cascade,
  booking_id uuid not null references public.service_bookings(id) on delete cascade,
  event_type text not null check (event_type in (
    'offer_created','offer_accepted','offer_declined','offer_expired','offer_cancelled'
  )),
  new_status text not null check (new_status in ('offered','accepted','declined','expired','cancelled')),
  actor_role text not null check (actor_role in ('system','electrician','admin')),
  occurred_at timestamptz not null,
  constraint srk_booking_offer_events_once_per_transition unique (offer_id,event_type)
);

create index if not exists srk_booking_offer_events_customer_timeline_idx
  on private.srk_booking_offer_events (booking_id, occurred_at, id);

alter table private.srk_booking_offer_events enable row level security;
revoke all on table private.srk_booking_offer_events from public, anon, authenticated;
revoke all on schema private from public, anon, authenticated;

create or replace function private.srk_capture_booking_offer_event()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public, private, auth, pg_temp
as $function$
declare
  v_event_type text;
  v_actor_role text := 'system';
  v_event_time timestamptz;
begin
  if tg_op = 'INSERT' then
    v_event_type := 'offer_created';
    v_event_time := coalesce(new.created_at, clock_timestamp());
  elsif tg_op = 'UPDATE' and new.status is distinct from old.status then
    v_event_type := case new.status
      when 'accepted' then 'offer_accepted'
      when 'declined' then 'offer_declined'
      when 'expired' then 'offer_expired'
      when 'cancelled' then 'offer_cancelled'
      else null
    end;
    v_event_time := coalesce(new.responded_at, clock_timestamp());
    if new.status in ('accepted','declined') then
      v_actor_role := 'electrician';
    elsif auth.uid() is not null and public.is_srk_admin() then
      v_actor_role := 'admin';
    end if;
  else
    return new;
  end if;

  if v_event_type is not null then
    insert into private.srk_booking_offer_events
      (offer_id,booking_id,event_type,new_status,actor_role,occurred_at)
    values
      (new.id,new.booking_id,v_event_type,new.status,v_actor_role,v_event_time)
    on conflict (offer_id,event_type) do nothing;
  end if;
  return new;
end;
$function$;

drop trigger if exists trg_srk_capture_booking_offer_event on public.job_offers;
create trigger trg_srk_capture_booking_offer_event
after insert or update of status on public.job_offers
for each row execute function private.srk_capture_booking_offer_event();

-- Backfill current offers. Existing final-state timestamps are approximate where the
-- legacy schema only retained responded_at; no historic intermediate transitions are invented.
insert into private.srk_booking_offer_events
  (offer_id,booking_id,event_type,new_status,actor_role,occurred_at)
select o.id,o.booking_id,'offer_created','offered','system',coalesce(o.created_at,now())
from public.job_offers o
on conflict (offer_id,event_type) do nothing;

insert into private.srk_booking_offer_events
  (offer_id,booking_id,event_type,new_status,actor_role,occurred_at)
select o.id,o.booking_id,
  case o.status
    when 'accepted' then 'offer_accepted'
    when 'declined' then 'offer_declined'
    when 'expired' then 'offer_expired'
    when 'cancelled' then 'offer_cancelled'
  end,
  o.status,
  case when o.status in ('accepted','declined') then 'electrician' else 'system' end,
  coalesce(o.responded_at,o.created_at,now())
from public.job_offers o
where o.status in ('accepted','declined','expired','cancelled')
on conflict (offer_id,event_type) do nothing;

create or replace function public.srk_customer_get_my_booking_offer_timeline()
returns table (
  event_id uuid,
  booking_id uuid,
  event_type text,
  new_status text,
  actor_role text,
  occurred_at timestamptz
)
language sql
stable
security definer
set search_path = pg_catalog, public, private, auth, pg_temp
as $function$
  select e.id,e.booking_id,e.event_type,e.new_status,e.actor_role,e.occurred_at
  from private.srk_booking_offer_events e
  join public.service_bookings b on b.id=e.booking_id
  where auth.uid() is not null
    and b.customer_user_id=auth.uid()
  order by e.occurred_at asc,e.id asc
  limit 1000;
$function$;

revoke all on function public.srk_customer_get_my_booking_offer_timeline() from public, anon;
grant execute on function public.srk_customer_get_my_booking_offer_timeline() to authenticated;
