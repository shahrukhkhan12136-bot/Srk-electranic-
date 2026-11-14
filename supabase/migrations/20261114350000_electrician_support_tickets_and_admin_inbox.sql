-- Private electrician-to-Admin support tickets and message threads.
-- Source-only until the full migration set is reviewed and approved.

create table if not exists public.srk_electrician_support_tickets (
  id uuid primary key default gen_random_uuid(),
  electrician_profile_id uuid not null references public.electrician_profiles(id) on delete restrict,
  user_id uuid not null references auth.users(id) on delete restrict,
  booking_id uuid references public.service_bookings(id) on delete restrict,
  category text not null check (category in ('booking','payment_payout','kyc_account','app_technical','customer_safety','other')),
  subject text not null check (length(btrim(subject)) between 4 and 120),
  status text not null default 'open' check (status in ('open','in_review','resolved','closed')),
  admin_note text,
  created_at timestamptz not null default clock_timestamp(),
  updated_at timestamptz not null default clock_timestamp(),
  updated_by uuid references auth.users(id) on delete set null
);
create index if not exists srk_electrician_support_tickets_owner_idx
  on public.srk_electrician_support_tickets(user_id,created_at desc);
create index if not exists srk_electrician_support_tickets_status_idx
  on public.srk_electrician_support_tickets(status,created_at desc);

create table if not exists public.srk_electrician_support_messages (
  id uuid primary key default gen_random_uuid(),
  ticket_id uuid not null references public.srk_electrician_support_tickets(id) on delete restrict,
  sender_role text not null check (sender_role in ('electrician','admin')),
  sender_user_id uuid not null references auth.users(id) on delete restrict,
  body text not null check (length(btrim(body)) between 1 and 4000),
  created_at timestamptz not null default clock_timestamp()
);
create index if not exists srk_electrician_support_messages_thread_idx
  on public.srk_electrician_support_messages(ticket_id,created_at,id);

alter table public.srk_electrician_support_tickets enable row level security;
alter table public.srk_electrician_support_messages enable row level security;
revoke all on public.srk_electrician_support_tickets from public,anon,authenticated;
revoke all on public.srk_electrician_support_messages from public,anon,authenticated;

create or replace function public.srk_electrician_create_support_ticket(
  p_category text,p_subject text,p_body text,p_booking_id uuid default null
) returns uuid
language plpgsql security definer
set search_path = ''
as $function$
declare v_uid uuid:=auth.uid(); v_profile public.electrician_profiles%rowtype; v_ticket uuid;
begin
  if v_uid is null then raise exception 'AUTHENTICATION_REQUIRED' using errcode='42501'; end if;
  if p_category not in ('booking','payment_payout','kyc_account','app_technical','customer_safety','other')
     or p_subject is null or length(btrim(p_subject)) not between 4 and 120
     or p_body is null or length(btrim(p_body)) not between 20 and 4000 then
    raise exception 'INVALID_SUPPORT_TICKET' using errcode='22023';
  end if;
  select * into v_profile from public.electrician_profiles
   where user_id=v_uid and auth_user_id=v_uid for update;
  if not found then raise exception 'ELECTRICIAN_PROFILE_NOT_FOUND' using errcode='42501'; end if;
  if p_booking_id is not null and not exists(
    select 1 from public.service_bookings b
     where b.id=p_booking_id and b.assigned_electrician_id=v_profile.id
  ) then raise exception 'BOOKING_NOT_ASSIGNED_TO_YOU' using errcode='42501'; end if;
  insert into public.srk_electrician_support_tickets
    (electrician_profile_id,user_id,booking_id,category,subject)
  values(v_profile.id,v_uid,p_booking_id,p_category,btrim(p_subject))
  returning id into v_ticket;
  insert into public.srk_electrician_support_messages(ticket_id,sender_role,sender_user_id,body)
  values(v_ticket,'electrician',v_uid,btrim(p_body));
  return v_ticket;
end;
$function$;

create or replace function public.srk_electrician_list_my_support_tickets()
returns table(id uuid,booking_id uuid,category text,subject text,status text,admin_note text,created_at timestamptz,updated_at timestamptz,last_message_at timestamptz)
language plpgsql stable security definer
set search_path = ''
as $function$
declare v_uid uuid:=auth.uid();
begin
 if v_uid is null then raise exception 'AUTHENTICATION_REQUIRED' using errcode='42501'; end if;
 return query select t.id,t.booking_id,t.category,t.subject,t.status,t.admin_note,t.created_at,t.updated_at,
   (select max(m.created_at) from public.srk_electrician_support_messages m where m.ticket_id=t.id)
 from public.srk_electrician_support_tickets t where t.user_id=v_uid
 order by t.updated_at desc,t.id desc limit 100;
end;
$function$;

create or replace function public.srk_electrician_list_my_support_messages(p_ticket_id uuid)
returns table(id uuid,sender_role text,body text,created_at timestamptz)
language plpgsql stable security definer
set search_path = ''
as $function$
declare v_uid uuid:=auth.uid();
begin
 if v_uid is null then raise exception 'AUTHENTICATION_REQUIRED' using errcode='42501'; end if;
 if not exists(select 1 from public.srk_electrician_support_tickets t where t.id=p_ticket_id and t.user_id=v_uid) then
  raise exception 'SUPPORT_TICKET_NOT_AVAILABLE' using errcode='42501';
 end if;
 return query select m.id,m.sender_role,m.body,m.created_at
 from public.srk_electrician_support_messages m where m.ticket_id=p_ticket_id
 order by m.created_at,m.id limit 300;
end;
$function$;

create or replace function public.srk_electrician_send_support_message(p_ticket_id uuid,p_body text)
returns uuid
language plpgsql security definer
set search_path = ''
as $function$
declare v_uid uuid:=auth.uid(); v_status text; v_id uuid;
begin
 if v_uid is null then raise exception 'AUTHENTICATION_REQUIRED' using errcode='42501'; end if;
 if p_body is null or length(btrim(p_body)) not between 1 and 4000 then
  raise exception 'MESSAGE_MUST_BE_1_TO_4000_CHARACTERS' using errcode='22023';
 end if;
 select t.status into v_status from public.srk_electrician_support_tickets t
  where t.id=p_ticket_id and t.user_id=v_uid for update;
 if not found then raise exception 'SUPPORT_TICKET_NOT_AVAILABLE' using errcode='42501'; end if;
 if v_status='closed' then raise exception 'TICKET_CLOSED' using errcode='55000'; end if;
 insert into public.srk_electrician_support_messages(ticket_id,sender_role,sender_user_id,body)
 values(p_ticket_id,'electrician',v_uid,btrim(p_body)) returning id into v_id;
 update public.srk_electrician_support_tickets set updated_at=clock_timestamp() where id=p_ticket_id;
 return v_id;
end;
$function$;

create or replace function public.srk_admin_list_electrician_support_tickets(p_limit integer default 100)
returns table(id uuid,electrician_profile_id uuid,electrician_name text,electrician_phone text,booking_id uuid,category text,subject text,status text,admin_note text,created_at timestamptz,updated_at timestamptz,last_message_at timestamptz)
language plpgsql stable security definer
set search_path = ''
as $function$
begin
 if auth.uid() is null or not public.is_srk_admin() then raise exception 'ADMIN_PERMISSION_REQUIRED' using errcode='42501'; end if;
 return query select t.id,t.electrician_profile_id,p.display_name,p.phone,t.booking_id,t.category,t.subject,t.status,t.admin_note,t.created_at,t.updated_at,
  (select max(m.created_at) from public.srk_electrician_support_messages m where m.ticket_id=t.id)
 from public.srk_electrician_support_tickets t
 join public.electrician_profiles p on p.id=t.electrician_profile_id
 order by case when t.status in ('open','in_review') then 0 else 1 end,t.updated_at desc
 limit greatest(1,least(coalesce(p_limit,100),300));
end;
$function$;

create or replace function public.srk_admin_list_electrician_support_messages(p_ticket_id uuid)
returns table(id uuid,sender_role text,body text,created_at timestamptz)
language plpgsql stable security definer
set search_path = ''
as $function$
begin
 if auth.uid() is null or not public.is_srk_admin() then raise exception 'ADMIN_PERMISSION_REQUIRED' using errcode='42501'; end if;
 if not exists(select 1 from public.srk_electrician_support_tickets t where t.id=p_ticket_id) then raise exception 'SUPPORT_TICKET_NOT_FOUND'; end if;
 return query select m.id,m.sender_role,m.body,m.created_at from public.srk_electrician_support_messages m
 where m.ticket_id=p_ticket_id order by m.created_at,m.id limit 300;
end;
$function$;

create or replace function public.srk_admin_send_electrician_support_message(p_ticket_id uuid,p_body text)
returns uuid
language plpgsql security definer
set search_path = ''
as $function$
declare v_uid uuid:=auth.uid(); v_id uuid;
begin
 if v_uid is null or not public.is_srk_admin() then raise exception 'ADMIN_PERMISSION_REQUIRED' using errcode='42501'; end if;
 if p_body is null or length(btrim(p_body)) not between 1 and 4000 then raise exception 'INVALID_SUPPORT_MESSAGE' using errcode='22023'; end if;
 perform 1 from public.srk_electrician_support_tickets where id=p_ticket_id for update;
 if not found then raise exception 'SUPPORT_TICKET_NOT_FOUND'; end if;
 insert into public.srk_electrician_support_messages(ticket_id,sender_role,sender_user_id,body)
 values(p_ticket_id,'admin',v_uid,btrim(p_body)) returning id into v_id;
 update public.srk_electrician_support_tickets set updated_at=clock_timestamp() where id=p_ticket_id;
 return v_id;
end;
$function$;

create or replace function public.srk_admin_update_electrician_support_ticket(p_ticket_id uuid,p_status text,p_admin_note text default null)
returns boolean
language plpgsql security definer
set search_path = ''
as $function$
declare v_uid uuid:=auth.uid();
begin
 if v_uid is null or not public.is_srk_admin() then raise exception 'ADMIN_PERMISSION_REQUIRED' using errcode='42501'; end if;
 if p_status not in ('open','in_review','resolved','closed') or (p_admin_note is not null and length(p_admin_note)>2000) then
  raise exception 'INVALID_SUPPORT_TICKET_UPDATE' using errcode='22023';
 end if;
 perform 1 from public.srk_electrician_support_tickets where id=p_ticket_id for update;
 if not found then raise exception 'SUPPORT_TICKET_NOT_FOUND'; end if;
 update public.srk_electrician_support_tickets set status=p_status,
  admin_note=case when p_admin_note is null then admin_note else nullif(btrim(p_admin_note),'') end,
  updated_at=clock_timestamp(),updated_by=v_uid where id=p_ticket_id;
 return true;
end;
$function$;

revoke all on function public.srk_electrician_create_support_ticket(text,text,text,uuid) from public,anon;
revoke all on function public.srk_electrician_list_my_support_tickets() from public,anon;
revoke all on function public.srk_electrician_list_my_support_messages(uuid) from public,anon;
revoke all on function public.srk_electrician_send_support_message(uuid,text) from public,anon;
revoke all on function public.srk_admin_list_electrician_support_tickets(integer) from public,anon;
revoke all on function public.srk_admin_list_electrician_support_messages(uuid) from public,anon;
revoke all on function public.srk_admin_send_electrician_support_message(uuid,text) from public,anon;
revoke all on function public.srk_admin_update_electrician_support_ticket(uuid,text,text) from public,anon;
grant execute on function public.srk_electrician_create_support_ticket(text,text,text,uuid) to authenticated;
grant execute on function public.srk_electrician_list_my_support_tickets() to authenticated;
grant execute on function public.srk_electrician_list_my_support_messages(uuid) to authenticated;
grant execute on function public.srk_electrician_send_support_message(uuid,text) to authenticated;
grant execute on function public.srk_admin_list_electrician_support_tickets(integer) to authenticated;
grant execute on function public.srk_admin_list_electrician_support_messages(uuid) to authenticated;
grant execute on function public.srk_admin_send_electrician_support_message(uuid,text) to authenticated;
grant execute on function public.srk_admin_update_electrician_support_ticket(uuid,text,text) to authenticated;
