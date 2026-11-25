alter table public.srk_booking_chat_messages
  add constraint srk_chat_message_length_valid
  check (length(btrim(message)) between 1 and 5000) not valid,
  add constraint srk_chat_attachment_path_valid
  check (
    attachment_path is null
    or (
      length(attachment_path) between 1 and 1000
      and left(attachment_path,1) <> '/'
      and strpos(attachment_path,'..') = 0
      and strpos(attachment_path,'://') = 0
    )
  ) not valid;

alter table public.srk_booking_live_locations
  add constraint srk_live_location_accuracy_valid
  check (accuracy_m is null or accuracy_m between 0 and 100000) not valid;

alter table public.srk_booking_chat_messages validate constraint srk_chat_message_length_valid;
alter table public.srk_booking_chat_messages validate constraint srk_chat_attachment_path_valid;
alter table public.srk_booking_live_locations validate constraint srk_live_location_accuracy_valid;

create unique index srk_one_active_location_share_per_booking
  on public.srk_booking_location_shares(booking_id)
  where ended_at is null;

create or replace function public.srk_send_booking_chat_message(
  p_room_id uuid,p_message text,p_attachment_path text default null
)
returns public.srk_booking_chat_messages
language plpgsql security definer
set search_path = pg_catalog, public, auth
as $function$
declare
  v_msg public.srk_booking_chat_messages%rowtype;
  v_message text := nullif(btrim(p_message), '');
  v_attachment text := nullif(btrim(p_attachment_path), '');
begin
  if auth.uid() is null then raise exception 'Authentication required' using errcode='42501'; end if;
  if p_room_id is null or v_message is null or length(v_message)>5000 then
    raise exception 'Chat message must contain 1 to 5000 characters';
  end if;
  if v_attachment is not null and (
    length(v_attachment)>1000 or left(v_attachment,1)='/'
    or strpos(v_attachment,'..')>0 or strpos(v_attachment,'://')>0
  ) then raise exception 'Invalid attachment storage path'; end if;
  if not exists(
    select 1 from public.srk_booking_chat_members m
    join public.srk_booking_chat_rooms r on r.id=m.room_id
    where m.room_id=p_room_id and m.user_id=auth.uid()
      and m.left_at is null and r.is_active
  ) then raise exception 'You are not an active member of this booking chat' using errcode='42501'; end if;
  insert into public.srk_booking_chat_messages(room_id,sender_user_id,message,attachment_path)
  values(p_room_id,auth.uid(),v_message,v_attachment) returning * into v_msg;
  return v_msg;
end
$function$;

create or replace function public.srk_start_booking_location_share(p_booking_id uuid)
returns public.srk_booking_location_shares
language plpgsql security definer
set search_path = pg_catalog, public, auth
as $function$
declare v_share public.srk_booking_location_shares%rowtype;
begin
  if auth.uid() is null then raise exception 'Authentication required' using errcode='42501'; end if;
  if p_booking_id is null or not (
    exists(select 1 from public.service_bookings b where b.id=p_booking_id
      and b.customer_user_id=auth.uid() and b.status in ('assigned','in_progress'))
    or exists(select 1 from public.srk_booking_workers bw
      join public.srk_worker_profiles w on w.id=bw.worker_id
      where bw.booking_id=p_booking_id and w.user_id=auth.uid()
        and bw.assignment_status in ('accepted','assigned','working','paused'))
  ) then raise exception 'Only active booking participants can share live location' using errcode='42501'; end if;
  insert into public.srk_booking_location_shares(booking_id,started_by)
  values(p_booking_id,auth.uid())
  on conflict (booking_id) where ended_at is null
  do update set booking_id=excluded.booking_id
  returning * into v_share;
  return v_share;
end
$function$;

create or replace function public.srk_record_booking_live_location(
  p_share_id uuid,p_latitude double precision,p_longitude double precision,p_accuracy_m numeric default null
)
returns uuid
language plpgsql security definer
set search_path = pg_catalog, public, auth
as $function$
declare v_booking uuid; v_id uuid;
begin
  if auth.uid() is null then raise exception 'Authentication required' using errcode='42501'; end if;
  if p_share_id is null or p_latitude is null or p_latitude < -90 or p_latitude > 90
     or p_longitude is null or p_longitude < -180 or p_longitude > 180
     or (p_accuracy_m is not null and (p_accuracy_m < 0 or p_accuracy_m > 100000)) then
    raise exception 'Valid latitude, longitude and location accuracy are required';
  end if;
  select sh.booking_id into v_booking from public.srk_booking_location_shares sh
  where sh.id=p_share_id and sh.ended_at is null;
  if not found then raise exception 'Location sharing is not active'; end if;
  if not (
    exists(select 1 from public.service_bookings b where b.id=v_booking
      and b.customer_user_id=auth.uid() and b.status in ('assigned','in_progress'))
    or exists(select 1 from public.srk_booking_workers bw
      join public.srk_worker_profiles w on w.id=bw.worker_id
      where bw.booking_id=v_booking and w.user_id=auth.uid()
        and bw.assignment_status in ('accepted','assigned','working','paused'))
  ) then raise exception 'Not authorized to share this booking location' using errcode='42501'; end if;
  insert into public.srk_booking_live_locations(share_id,user_id,latitude,longitude,accuracy_m)
  values(p_share_id,auth.uid(),p_latitude,p_longitude,p_accuracy_m)
  returning id into v_id;
  return v_id;
end
$function$;

revoke all on function public.srk_send_booking_chat_message(uuid,text,text) from public,anon;
grant execute on function public.srk_send_booking_chat_message(uuid,text,text) to authenticated;
revoke all on function public.srk_start_booking_location_share(uuid) from public,anon;
grant execute on function public.srk_start_booking_location_share(uuid) to authenticated;
revoke all on function public.srk_record_booking_live_location(uuid,double precision,double precision,numeric) from public,anon;
grant execute on function public.srk_record_booking_live_location(uuid,double precision,double precision,numeric) to authenticated;