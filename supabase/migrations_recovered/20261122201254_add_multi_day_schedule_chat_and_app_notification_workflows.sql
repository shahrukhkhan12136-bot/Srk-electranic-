
create table if not exists public.srk_booking_schedule_proposals (
  id uuid primary key default gen_random_uuid(),
  booking_worker_id uuid not null references public.srk_booking_workers(id) on delete restrict,
  proposed_by uuid not null references auth.users(id) on delete restrict,
  proposed_start_at timestamptz not null,
  proposed_end_at timestamptz not null,
  status text not null default 'proposed',
  customer_response_note text,
  responded_at timestamptz,
  created_at timestamptz not null default now(),
  constraint srk_schedule_proposal_time_valid check(proposed_end_at>proposed_start_at),
  constraint srk_schedule_proposal_status_valid check(status in ('proposed','accepted','declined','cancelled','expired'))
);
create index if not exists srk_schedule_proposals_worker_status_idx
  on public.srk_booking_schedule_proposals(booking_worker_id,status,proposed_start_at);

create table if not exists public.srk_booking_schedule_events (
  id uuid primary key default gen_random_uuid(),
  proposal_id uuid not null references public.srk_booking_schedule_proposals(id) on delete restrict,
  actor_user_id uuid not null references auth.users(id) on delete restrict,
  action text not null,
  note text,
  created_at timestamptz not null default now()
);

alter table public.srk_booking_schedule_proposals enable row level security;
alter table public.srk_booking_schedule_events enable row level security;

create policy srk_schedule_proposals_participant on public.srk_booking_schedule_proposals
for select to authenticated using(
  public.is_srk_admin()
  or exists(select 1 from public.srk_booking_workers bw join public.srk_worker_profiles w on w.id=bw.worker_id
    where bw.id=booking_worker_id and w.user_id=auth.uid())
  or exists(select 1 from public.srk_booking_workers bw join public.service_bookings b on b.id=bw.booking_id
    where bw.id=booking_worker_id and b.customer_user_id=auth.uid())
);
create policy srk_schedule_events_participant on public.srk_booking_schedule_events
for select to authenticated using(
  public.is_srk_admin()
  or exists(select 1 from public.srk_booking_schedule_proposals p
    join public.srk_booking_workers bw on bw.id=p.booking_worker_id
    join public.srk_worker_profiles w on w.id=bw.worker_id
    where p.id=proposal_id and w.user_id=auth.uid())
  or exists(select 1 from public.srk_booking_schedule_proposals p
    join public.srk_booking_workers bw on bw.id=p.booking_worker_id
    join public.service_bookings b on b.id=bw.booking_id
    where p.id=proposal_id and b.customer_user_id=auth.uid())
);

create or replace function public.srk_worker_propose_next_schedule(
  p_booking_worker_id uuid,p_start_at timestamptz,p_end_at timestamptz
) returns public.srk_booking_schedule_proposals
language plpgsql security definer
set search_path=pg_catalog,public
as $$
declare v_proposal public.srk_booking_schedule_proposals%rowtype;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if p_start_at<=clock_timestamp() or p_end_at<=p_start_at then raise exception 'Future valid schedule range required'; end if;
  if not exists(select 1 from public.srk_booking_workers bw join public.srk_worker_profiles w on w.id=bw.worker_id
    where bw.id=p_booking_worker_id and w.user_id=auth.uid() and bw.assignment_status in ('accepted','assigned','working','paused')) then
    raise exception 'Only assigned worker can propose the next work schedule';
  end if;
  insert into public.srk_booking_schedule_proposals(booking_worker_id,proposed_by,proposed_start_at,proposed_end_at)
  values(p_booking_worker_id,auth.uid(),p_start_at,p_end_at) returning * into v_proposal;
  insert into public.srk_booking_schedule_events(proposal_id,actor_user_id,action)
  values(v_proposal.id,auth.uid(),'proposed');
  return v_proposal;
end $$;

create or replace function public.srk_customer_respond_schedule_proposal(
  p_proposal_id uuid,p_accept boolean,p_note text default null
) returns public.srk_booking_schedule_proposals
language plpgsql security definer
set search_path=pg_catalog,public
as $$
declare v_proposal public.srk_booking_schedule_proposals%rowtype; v_booking uuid; v_worker uuid;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  select p.* into v_proposal
  from public.srk_booking_schedule_proposals p
  join public.srk_booking_workers bw on bw.id=p.booking_worker_id
  join public.service_bookings b on b.id=bw.booking_id
  where p.id=p_proposal_id and b.customer_user_id=auth.uid()
  for update of p;
  if not found or v_proposal.status<>'proposed' then raise exception 'Proposal not found or no longer pending'; end if;

  select bw.booking_id,bw.worker_id into v_booking,v_worker
  from public.srk_booking_workers bw where bw.id=v_proposal.booking_worker_id;

  if p_accept then
    insert into public.srk_worker_schedule_blocks(worker_id,booking_worker_id,starts_at,ends_at,block_status)
    values(v_worker,v_proposal.booking_worker_id,v_proposal.proposed_start_at,v_proposal.proposed_end_at,'confirmed');
  end if;

  update public.srk_booking_schedule_proposals set status=case when p_accept then 'accepted' else 'declined' end,
    customer_response_note=p_note,responded_at=clock_timestamp()
  where id=p_proposal_id returning * into v_proposal;

  insert into public.srk_booking_schedule_events(proposal_id,actor_user_id,action,note)
  values(p_proposal_id,auth.uid(),case when p_accept then 'accepted' else 'declined' end,p_note);

  insert into public.srk_app_notifications(user_id,notification_type,title,body,related_booking_id)
  select w.user_id,'schedule_response',
    case when p_accept then 'Schedule accepted' else 'Schedule declined' end,
    case when p_accept then 'Customer accepted the proposed work schedule.' else 'Customer declined the proposed work schedule. Please propose another time.' end,
    v_booking
  from public.srk_worker_profiles w where w.id=v_worker;
  return v_proposal;
end $$;

create or replace function public.srk_create_booking_chat_room(p_booking_id uuid)
returns uuid
language plpgsql security definer
set search_path=pg_catalog,public
as $$
declare v_room uuid; v_customer uuid;
begin
  if not public.srk_has_admin_permission('bookings.manage') then raise exception 'Booking management permission required'; end if;
  select customer_user_id into v_customer from public.service_bookings where id=p_booking_id;
  if not found then raise exception 'Booking not found'; end if;
  insert into public.srk_booking_chat_rooms(booking_id) values(p_booking_id)
  on conflict(booking_id) do update set is_active=true returning id into v_room;
  if v_customer is not null then
    insert into public.srk_booking_chat_members(room_id,user_id,member_role)
    values(v_room,v_customer,'customer') on conflict(room_id,user_id) do update set left_at=null;
  end if;
  insert into public.srk_booking_chat_members(room_id,user_id,member_role)
  select v_room,w.user_id,w.worker_type from public.srk_booking_workers bw
  join public.srk_worker_profiles w on w.id=bw.worker_id
  where bw.booking_id=p_booking_id and bw.assignment_status in ('accepted','assigned','working','paused')
  on conflict(room_id,user_id) do update set left_at=null;
  return v_room;
end $$;

create or replace function public.srk_on_booking_assignment_notification()
returns trigger language plpgsql security definer
set search_path=pg_catalog,public
as $$
declare v_user uuid; v_customer uuid; v_order text;
begin
  select user_id into v_user from public.srk_worker_profiles where id=new.worker_id;
  select customer_user_id,order_number into v_customer,v_order from public.service_bookings where id=new.booking_id;
  if tg_op='INSERT' then
    insert into public.srk_app_notifications(user_id,notification_type,title,body,related_booking_id)
    values(v_user,'booking_offer','New booking offer','You have received a new service booking offer: '||coalesce(v_order,''),new.booking_id);
  elsif new.assignment_status is distinct from old.assignment_status then
    if v_customer is not null then
      insert into public.srk_app_notifications(user_id,notification_type,title,body,related_booking_id)
      values(v_customer,'worker_response','Worker response',
        case when new.assignment_status='accepted' then 'A worker accepted your booking.' else 'A worker declined the booking offer.' end,new.booking_id);
    end if;
  end if;
  return new;
end $$;

drop trigger if exists srk_booking_assignment_notification_trigger on public.srk_booking_workers;
create trigger srk_booking_assignment_notification_trigger
after insert or update of assignment_status on public.srk_booking_workers
for each row execute function public.srk_on_booking_assignment_notification();

create or replace function public.srk_on_emergency_notification()
returns trigger language plpgsql security definer
set search_path=pg_catalog,public
as $$
begin
  insert into public.srk_app_notifications(user_id,notification_type,title,body,related_booking_id)
  select user_id,'emergency_alert','Emergency Alert','An emergency alert requires Admin attention.',new.booking_id
  from public.srk_admin_users;
  return new;
end $$;
drop trigger if exists srk_emergency_notification_trigger on public.srk_emergency_alerts;
create trigger srk_emergency_notification_trigger after insert on public.srk_emergency_alerts
for each row execute function public.srk_on_emergency_notification();

create or replace function public.srk_on_booking_status_notification()
returns trigger language plpgsql security definer
set search_path=pg_catalog,public
as $$
begin
  if new.status is distinct from old.status and new.customer_user_id is not null then
    insert into public.srk_app_notifications(user_id,notification_type,title,body,related_booking_id)
    values(new.customer_user_id,'booking_status','Booking status updated',
      'Your booking status is now: '||new.status,new.id);
  end if;
  if new.payment_status is distinct from old.payment_status and new.customer_user_id is not null then
    insert into public.srk_app_notifications(user_id,notification_type,title,body,related_booking_id)
    values(new.customer_user_id,'payment_status','Payment status updated',
      'Your payment status is now: '||new.payment_status,new.id);
  end if;
  return new;
end $$;
drop trigger if exists srk_booking_status_notification_trigger on public.service_bookings;
create trigger srk_booking_status_notification_trigger after update of status,payment_status
on public.service_bookings for each row execute function public.srk_on_booking_status_notification();

revoke all on function public.srk_worker_propose_next_schedule(uuid,timestamptz,timestamptz) from public,anon;
revoke all on function public.srk_customer_respond_schedule_proposal(uuid,boolean,text) from public,anon;
revoke all on function public.srk_create_booking_chat_room(uuid) from public,anon;
grant execute on function public.srk_worker_propose_next_schedule(uuid,timestamptz,timestamptz) to authenticated;
grant execute on function public.srk_customer_respond_schedule_proposal(uuid,boolean,text) to authenticated;
grant execute on function public.srk_create_booking_chat_room(uuid) to authenticated;
