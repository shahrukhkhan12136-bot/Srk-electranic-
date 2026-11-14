-- Private customer/Admin support conversation schema and customer RPCs.
-- This migration intentionally sorts before 20261113230000_support_attachment_paths_and_admin_message_list.sql.
-- Source-only: review the full migration set before applying to any database.

create table if not exists public.srk_booking_complaint_messages (
  id uuid primary key default gen_random_uuid(),
  complaint_id uuid not null references public.srk_booking_complaints(id) on delete cascade,
  sender_role text not null check (sender_role in ('customer','admin')),
  sender_user_id uuid references auth.users(id) on delete set null,
  body text not null check (length(btrim(body)) between 1 and 4000),
  created_at timestamptz not null default now()
);

create index if not exists srk_booking_complaint_messages_thread_idx
  on public.srk_booking_complaint_messages (complaint_id, created_at, id);

-- The composite attachment FK below must reference a unique key that
-- already exists when PostgreSQL creates the attachment table.
create unique index if not exists srk_booking_complaint_messages_id_thread_uidx
  on public.srk_booking_complaint_messages (id, complaint_id);

create table if not exists public.srk_booking_complaint_message_attachments (
  id uuid primary key default gen_random_uuid(),
  complaint_id uuid not null references public.srk_booking_complaints(id) on delete cascade,
  message_id uuid not null references public.srk_booking_complaint_messages(id) on delete cascade,
  file_name text not null check (length(file_name) between 1 and 180),
  mime_type text not null check (mime_type in ('image/jpeg','image/png','image/webp','application/pdf')),
  file_size_bytes bigint not null check (file_size_bytes between 1 and 10485760),
  storage_path text not null unique,
  created_at timestamptz not null default now(),
  constraint srk_complaint_attachment_message_thread_fk
    foreign key (message_id, complaint_id)
    references public.srk_booking_complaint_messages(id, complaint_id)
    deferrable initially immediate
);


alter table public.srk_booking_complaint_messages enable row level security;
alter table public.srk_booking_complaint_message_attachments enable row level security;
revoke all on public.srk_booking_complaint_messages from public, anon, authenticated;
revoke all on public.srk_booking_complaint_message_attachments from public, anon, authenticated;

create or replace function public.srk_customer_send_booking_complaint_message(
  p_complaint_id uuid,
  p_body text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_user_id uuid := auth.uid();
  v_message_id uuid;
begin
  if v_user_id is null then
    raise exception 'AUTHENTICATION_REQUIRED' using errcode = '28000';
  end if;
  if p_complaint_id is null or p_body is null
     or length(btrim(p_body)) not between 1 and 4000 then
    raise exception 'MESSAGE_MUST_BE_1_TO_4000_CHARACTERS' using errcode = '22023';
  end if;
  perform 1 from public.srk_booking_complaints c
   where c.id=p_complaint_id and c.customer_user_id=v_user_id
   for update;
  if not found then
    raise exception 'COMPLAINT_NOT_AVAILABLE' using errcode = '42501';
  end if;
  insert into public.srk_booking_complaint_messages(complaint_id,sender_role,sender_user_id,body)
  values(p_complaint_id,'customer',v_user_id,btrim(p_body))
  returning id into v_message_id;
  return v_message_id;
end;
$function$;

create or replace function public.srk_customer_list_booking_complaint_messages(
  p_complaint_id uuid
)
returns table(id uuid,sender_role text,body text,created_at timestamptz)
language plpgsql
stable
security definer
set search_path = ''
as $function$
declare
  v_user_id uuid := auth.uid();
begin
  if v_user_id is null then
    raise exception 'AUTHENTICATION_REQUIRED' using errcode = '28000';
  end if;
  if not exists(select 1 from public.srk_booking_complaints c
    where c.id=p_complaint_id and c.customer_user_id=v_user_id) then
    raise exception 'COMPLAINT_NOT_AVAILABLE' using errcode = '42501';
  end if;
  return query
    select m.id,m.sender_role,m.body,m.created_at
    from public.srk_booking_complaint_messages m
    where m.complaint_id=p_complaint_id
    order by m.created_at asc,m.id asc
    limit 200;
end;
$function$;

create or replace function public.srk_customer_link_complaint_message_attachment(
  p_complaint_id uuid,
  p_message_id uuid,
  p_storage_path text,
  p_file_name text,
  p_mime_type text,
  p_file_size_bytes bigint
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_user_id uuid := auth.uid();
  v_attachment_id uuid;
begin
  if v_user_id is null then
    raise exception 'AUTHENTICATION_REQUIRED' using errcode = '28000';
  end if;
  if p_complaint_id is null or p_message_id is null
     or p_storage_path is null
     or p_storage_path not like v_user_id::text || '/' || p_complaint_id::text || '/%'
     or p_file_name is null or length(p_file_name) not between 1 and 180
     or p_mime_type is null or p_mime_type not in ('image/jpeg','image/png','image/webp','application/pdf')
     or p_file_size_bytes is null or p_file_size_bytes not between 1 and 10485760 then
    raise exception 'INVALID_SUPPORT_ATTACHMENT' using errcode = '22023';
  end if;
  if not exists(
    select 1
      from public.srk_booking_complaints c
      join public.srk_booking_complaint_messages m
        on m.complaint_id=c.id and m.id=p_message_id
     where c.id=p_complaint_id and c.customer_user_id=v_user_id
       and m.sender_role='customer'
  ) then
    raise exception 'ATTACHMENT_NOT_ALLOWED' using errcode = '42501';
  end if;
  insert into public.srk_booking_complaint_message_attachments
    (complaint_id,message_id,file_name,mime_type,file_size_bytes,storage_path)
  values
    (p_complaint_id,p_message_id,btrim(p_file_name),p_mime_type,p_file_size_bytes,p_storage_path)
  returning id into v_attachment_id;
  return v_attachment_id;
end;
$function$;

revoke all on function public.srk_customer_send_booking_complaint_message(uuid,text) from public,anon;
grant execute on function public.srk_customer_send_booking_complaint_message(uuid,text) to authenticated;
revoke all on function public.srk_customer_list_booking_complaint_messages(uuid) from public,anon;
grant execute on function public.srk_customer_list_booking_complaint_messages(uuid) to authenticated;
revoke all on function public.srk_customer_link_complaint_message_attachment(uuid,uuid,text,text,text,bigint) from public,anon;
grant execute on function public.srk_customer_link_complaint_message_attachment(uuid,uuid,text,text,text,bigint) to authenticated;

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('srk-customer-support','srk-customer-support',false,10485760,
  array['image/jpeg','image/png','image/webp','application/pdf']::text[])
on conflict(id) do update set public=false,file_size_limit=10485760,allowed_mime_types=excluded.allowed_mime_types;

create or replace function public.srk_customer_support_object_access(
  p_object_name text,
  p_allow_admin boolean default true
)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $function$
declare
  v_user_id uuid := auth.uid();
  v_parts text[];
begin
  if v_user_id is null or p_object_name is null then
    return false;
  end if;
  v_parts := storage.foldername(p_object_name);
  if p_allow_admin and public.is_srk_admin() then
    return true;
  end if;
  if coalesce(array_length(v_parts,1),0) < 2 or v_parts[1] <> v_user_id::text then
    return false;
  end if;
  return exists(
    select 1 from public.srk_booking_complaints c
    where c.id::text=v_parts[2] and c.customer_user_id=v_user_id
  );
end;
$function$;

revoke all on function public.srk_customer_support_object_access(text,boolean) from public,anon;
grant execute on function public.srk_customer_support_object_access(text,boolean) to authenticated;

drop policy if exists srk_customer_support_upload_own on storage.objects;
create policy srk_customer_support_upload_own on storage.objects
for insert to authenticated
with check (
  bucket_id='srk-customer-support'
  and public.srk_customer_support_object_access(name,false)
);

drop policy if exists srk_customer_support_read_own_or_admin on storage.objects;
create policy srk_customer_support_read_own_or_admin on storage.objects
for select to authenticated
using (
  bucket_id='srk-customer-support'
  and public.srk_customer_support_object_access(name,true)
);

drop policy if exists srk_customer_support_delete_own on storage.objects;
create policy srk_customer_support_delete_own on storage.objects
for delete to authenticated
using (
  bucket_id='srk-customer-support'
  and public.srk_customer_support_object_access(name,false)
);
